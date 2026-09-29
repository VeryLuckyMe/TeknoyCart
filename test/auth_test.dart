import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/services/auth_service.dart';
import 'package:teknoycart/features/auth/views/widgets/auth_form_fields.dart';

/// Pure-logic unit tests for AuthService and Auth Form UX utilities.
/// These test domain validation, student ID formatting, and form guard logic
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

  group('StudentIdInputFormatter & UX Validation Tests', () {
    late StudentIdInputFormatter formatter;

    setUp(() {
      formatter = StudentIdInputFormatter();
    });

    test('should format raw digits into ##-####-### standard automatically', () {
      final input = const TextEditingValue(text: '211029315');
      final output = formatter.formatEditUpdate(TextEditingValue.empty, input);
      expect(output.text, '21-1029-315');
    });

    test('should format partial digits correctly as typed', () {
      // 2 digits
      var output = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '21'),
      );
      expect(output.text, '21');

      // 3 digits -> inserts first dash
      output = formatter.formatEditUpdate(
        const TextEditingValue(text: '21'),
        const TextEditingValue(text: '211'),
      );
      expect(output.text, '21-1');

      // 6 digits -> "21-1234"
      output = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '211234'),
      );
      expect(output.text, '21-1234');

      // 7 digits -> "21-1234-5"
      output = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '2112345'),
      );
      expect(output.text, '21-1234-5');
    });

    test('should strip non-digit characters gracefully', () {
      final input = const TextEditingValue(text: '21-ABC-1234-XYZ-567');
      final output = formatter.formatEditUpdate(TextEditingValue.empty, input);
      expect(output.text, '21-1234-567');
    });

    test('should cap student ID at 9 total digits', () {
      final input = const TextEditingValue(text: '21123456789999');
      final output = formatter.formatEditUpdate(TextEditingValue.empty, input);
      expect(output.text, '21-1234-567');
    });

    test('CIT-U Student ID regex validates formatted IDs', () {
      final regex = RegExp(r'^\d{2}-\d{4}-\d{3}$');
      expect(regex.hasMatch('21-1029-315'), isTrue);
      expect(regex.hasMatch('19-4567-890'), isTrue);
      expect(regex.hasMatch('211029315'), isFalse);
      expect(regex.hasMatch('21-102-315'), isFalse);
      expect(regex.hasMatch('21-1029-31'), isFalse);
    });

    test('citDepartmentOptions contains all 8 CIT colleges and high school levels', () {
      final codes = citDepartmentOptions.map((o) => o.code).toList();
      expect(codes.contains('CCS'), isTrue);
      expect(codes.contains('CEA'), isTrue);
      expect(codes.contains('CASE'), isTrue);
      expect(codes.contains('CMBA'), isTrue);
      expect(codes.contains('CNAHS'), isTrue);
      expect(codes.contains('CCJ'), isTrue);
      expect(codes.contains('JHS'), isTrue);
      expect(codes.contains('SHS'), isTrue);
      expect(citDepartmentOptions.length, 8);

      final jhs = citDepartmentOptions.firstWhere((o) => o.code == 'JHS');
      expect(jhs.name, 'Junior High School');
      expect(jhs.fullTitle, 'JHS — Junior High School');

      final shs = citDepartmentOptions.firstWhere((o) => o.code == 'SHS');
      expect(shs.name, 'Senior High School');
      expect(shs.fullTitle, 'SHS — Senior High School');
    });
  });

  group('Ponytail Audit & Profile Enrichment Tests', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService();
    });

    test('strict seller verification role predicates (Ponytail Audit)', () {
      // 1. Unverified seller application (pending seller)
      final pendingSeller = Profile(
        id: 'user-1',
        username: 'pending_vendor',
        email: 'seller@cit.edu',
        role: 'SELLER',
        isSellerVerified: false,
        createdAt: DateTime.now(),
      );
      expect(pendingSeller.isSeller, isFalse, reason: 'Pending seller must not have active seller privileges');
      expect(pendingSeller.isPendingSeller, isTrue);
      expect(pendingSeller.isBuyer, isTrue, reason: 'Pending seller must operate in buyer mode');

      // 2. Verified vendor
      final verifiedSeller = Profile(
        id: 'user-2',
        username: 'approved_vendor',
        email: 'vendor@cit.edu',
        role: 'SELLER',
        isSellerVerified: true,
        createdAt: DateTime.now(),
      );
      expect(verifiedSeller.isSeller, isTrue);
      expect(verifiedSeller.isPendingSeller, isFalse);
      expect(verifiedSeller.isBuyer, isFalse);

      // 3. Regular student buyer
      final studentBuyer = Profile(
        id: 'user-3',
        username: 'regular_buyer',
        email: 'student@cit.edu',
        role: 'BUYER',
        isSellerVerified: false,
        createdAt: DateTime.now(),
      );
      expect(studentBuyer.isSeller, isFalse);
      expect(studentBuyer.isPendingSeller, isFalse);
      expect(studentBuyer.isBuyer, isTrue);
    });

    test('getEnrichedProfile falls back gracefully when DB call errors', () async {
      final baseProfile = Profile(
        id: 'non-existent-user-id',
        username: 'fallback_user',
        email: 'fallback@cit.edu',
        role: 'BUYER',
        isSellerVerified: false,
        createdAt: DateTime.now(),
      );
      final enriched = await authService.getEnrichedProfile(baseProfile);
      expect(enriched.id, baseProfile.id);
      expect(enriched.username, baseProfile.username);
      expect(enriched.role, baseProfile.role);
    });
  });
}

