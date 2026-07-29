import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/features/auth/services/auth_service.dart';

/// Pure-logic unit tests for AuthService.
/// These only test the domain validation and input guard logic
/// (which fires BEFORE any Supabase network call).
/// No Supabase initialization required.
void main() {
  group('Auth Service & Domain Filtering Tests', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService();
    });

    // ── Email domain validation (pure logic, no network required) ──
    test('should correctly validate valid CIT-U institutional domains', () {
      expect(authService.isValidCituEmail('student@cit.edu'), isTrue);
      expect(authService.isValidCituEmail('john.doe@cit.edu'), isTrue);
      expect(authService.isValidCituEmail('ADMIN@CIT.EDU'), isTrue);
    });

    test('should reject non-institutional domain email addresses for CIT-U validator', () {
      expect(authService.isValidCituEmail('hacker@gmail.com'), isFalse);
      expect(authService.isValidCituEmail('student@yahoo.com'), isFalse);
      expect(authService.isValidCituEmail('admin@cit.edu.fake.com'), isFalse);
    });

    test('should validate general email syntax for sellers', () {
      expect(authService.isValidGeneralEmail('store@gmail.com'), isTrue);
      expect(authService.isValidGeneralEmail('ccs.merch@cit.edu'), isTrue);
      expect(authService.isValidGeneralEmail('notanemail'), isFalse);
    });

    // ── Domain guard — throws FormatException BEFORE Supabase call ──
    test('signing in with invalid email syntax should throw FormatException immediately', () {
      expect(
        () => authService.signIn(email: 'invalid-email-format', password: 'password123'),
        throwsA(isA<FormatException>()),
      );
    });

    test('registering a BUYER with non-CIT-U email should throw FormatException immediately', () {
      expect(
        () => authService.signUp(
          email: 'user@gmail.com',
          username: 'hacker',
          password: 'password123',
          role: 'BUYER',
          studentId: '22-1234-567',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('registering a SELLER with GMail address should pass domain validation check', () {
      expect(
        authService.isValidGeneralEmail('ccs.merch.citu@gmail.com'),
        isTrue,
      );
    });

    test('registering with empty username should throw FormatException', () {
      expect(
        () => authService.signUp(
          email: 'student@cit.edu',
          username: '',
          password: 'password123',
          role: 'BUYER',
          studentId: '22-1234-567',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('registering with short password should throw FormatException', () {
      expect(
        () => authService.signUp(
          email: 'student@cit.edu',
          username: 'wildcat',
          password: '123',
          role: 'BUYER',
          studentId: '22-1234-567',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
