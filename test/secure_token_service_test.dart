import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/services/secure_token_service.dart';

String _jwt(Map<String, dynamic> payload) {
  String segment(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${segment({'alg': 'HS256', 'typ': 'JWT'})}.${segment(payload)}.signature';
}

void main() {
  group('SecureTokenService.isJwtUsable', () {
    final now = DateTime.utc(2026, 10, 29, 12, 0, 0);

    test('accepts a JWT whose exp is comfortably in the future', () {
      final token = _jwt({
        'sub': 'user-1',
        'exp': now.add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000,
      });

      expect(SecureTokenService.isJwtUsable(token, now: now), isTrue);
    });

    test('rejects an expired JWT', () {
      final token = _jwt({
        'sub': 'user-1',
        'exp': now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch ~/ 1000,
      });

      expect(SecureTokenService.isJwtUsable(token, now: now), isFalse);
    });

    test('rejects a JWT expiring inside the 30-second safety leeway', () {
      final token = _jwt({
        'exp': now.add(const Duration(seconds: 10)).millisecondsSinceEpoch ~/ 1000,
      });

      expect(SecureTokenService.isJwtUsable(token, now: now), isFalse);
    });

    test('rejects tokens without an exp claim', () {
      expect(SecureTokenService.isJwtUsable(_jwt({'sub': 'user-1'}), now: now), isFalse);
    });

    test('rejects opaque or malformed tokens without throwing', () {
      expect(SecureTokenService.isJwtUsable(null), isFalse);
      expect(SecureTokenService.isJwtUsable(''), isFalse);
      expect(SecureTokenService.isJwtUsable('not-a-jwt'), isFalse);
      expect(SecureTokenService.isJwtUsable('a.b.c'), isFalse);
    });
  });
}
