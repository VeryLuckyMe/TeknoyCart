import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/services/secure_token_service.dart';
import 'package:teknoycart/core/supabase_client.dart';

final secureStorageMemory = <String, String>{};

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
    test('getBearerToken falls back to stored tokens when no live Supabase session exists', () async {
      expect(SupabaseConfig.client.auth.currentSession, isNull);

      await SecureTokenService.saveTokens(
        accessToken: 'stored_access_token_abc',
        backendToken: 'stored_backend_token_123',
      );

      final token = await SecureTokenService.getBearerToken();
      // When live session is null, returns stored token
      expect(token, equals('stored_backend_token_123'));
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
