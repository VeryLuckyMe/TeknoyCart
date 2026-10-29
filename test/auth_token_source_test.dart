import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/services/secure_token_service.dart';
import 'package:teknoycart/core/supabase_client.dart';

final secureStorageMemory = <String, String>{};

String _jwtWithExpiry(Duration fromNow) {
  String segment(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${segment({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${segment({'exp': DateTime.now().add(fromNow).millisecondsSinceEpoch ~/ 1000})}.'
      'signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{};
        }
        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        final key = methodCall.arguments?['key'] as String?;
        if (methodCall.method == 'read') {
          return secureStorageMemory[key];
        }
        if (methodCall.method == 'write') {
          secureStorageMemory[key!] = methodCall.arguments['value'] as String;
          return null;
        }
        if (methodCall.method == 'delete') {
          secureStorageMemory.remove(key);
          return null;
        }
        if (methodCall.method == 'deleteAll') {
          secureStorageMemory.clear();
          return null;
        }
        return null;
      },
    );

    await SupabaseConfig.initialize();
  });

  setUp(() {
    secureStorageMemory.clear();
  });

  tearDown(() async {
    await SecureTokenService.clearTokens();
  });

  group('SecureTokenService - Token Source Hierarchy (Finding H5, H11)', () {
    test('getBearerToken prefers a non-expired backend JWT over the stored access token', () async {
      expect(SupabaseConfig.client.auth.currentSession, isNull);

      final backendJwt = _jwtWithExpiry(const Duration(hours: 1));
      await SecureTokenService.saveTokens(
        accessToken: 'stored_access_token_abc',
        backendToken: backendJwt,
      );

      final token = await SecureTokenService.getBearerToken();
      // Spring Boot validates its own JWT, so it must win over the Supabase token.
      expect(token, equals(backendJwt));
    });

    test('getBearerToken falls back to the stored access token when no live session exists',
        () async {
      expect(SupabaseConfig.client.auth.currentSession, isNull);

      await SecureTokenService.saveTokens(
        accessToken: 'stored_access_token_abc',
        backendToken: 'stored_backend_token_123',
      );

      final token = await SecureTokenService.getBearerToken();
      // Opaque backend tokens cannot be checked for expiry, so the stored
      // Supabase access token remains the fallback.
      expect(token, equals('stored_access_token_abc'));
    });

    test('getBearerToken returns null when neither live session nor stored tokens exist', () async {
      await SecureTokenService.clearTokens();
      final token = await SecureTokenService.getBearerToken();
      expect(token, isNull);
    });

    test('clearTokens clears stored access, refresh, and backend tokens', () async {
      await SecureTokenService.saveTokens(
        accessToken: 'acc_1',
        refreshToken: 'ref_1',
        backendToken: 'back_1',
      );

      expect(await SecureTokenService.getBackendToken(), equals('back_1'));
      expect(await SecureTokenService.getRefreshToken(), equals('ref_1'));

      await SecureTokenService.clearTokens();

      expect(await SecureTokenService.getBackendToken(), isNull);
      expect(await SecureTokenService.getRefreshToken(), isNull);
      expect(await SecureTokenService.getBearerToken(), isNull);
    });
  });
}
