import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/features/auth/services/auth_service.dart';

void main() {
  group('AuthService Unit Tests', () {
    test('password length policy enforces minimum 12 characters', () {
      expect(AuthService.minPasswordLength, equals(12));
      expect(AuthService.isValidPasswordLength('12345678901'), isFalse);
      expect(AuthService.isValidPasswordLength('123456789012'), isTrue);
      expect(AuthService.isValidPasswordLength('TeknoyWildcat2026!'), isTrue);
    });

    test('isRegistering defaults to false', () {
      final service = AuthService();
      expect(service.isRegistering, isFalse);
    });

    test('validates institutional and general email addresses', () {
      final service = AuthService();

      expect(service.isValidCituEmail(' Student@CIT.EDU '), isTrue);
      expect(service.isValidCituEmail('student@cit.edu.ph'), isFalse);
      expect(service.isValidGeneralEmail('student@example.com'), isTrue);
      expect(service.isValidGeneralEmail('not-an-email'), isFalse);
    });

    test('validates password length at the boundary', () {
      expect(AuthService.isValidPasswordLength(''), isFalse);
      expect(AuthService.isValidPasswordLength('12345678901'), isFalse);
      expect(AuthService.isValidPasswordLength('123456789012'), isTrue);
    });
  });
}

