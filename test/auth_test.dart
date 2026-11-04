import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/services/auth_service.dart';
import 'package:teknoycart/features/auth/views/widgets/auth_form_fields.dart';
import 'package:teknoycart/features/auth/utils/student_id.dart';

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

    test('registering with a password shorter than 12 should throw FormatException', () {
      expect(
        () => authService.signUp(
          email: 'student@cit.edu',
          username: 'wildcat',
          password: 'password123', // 11 characters
          role: 'BUYER',
          studentId: '22-1234-567',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('password policy accepts exactly 12 characters and rejects 11', () {
      expect(AuthService.isValidPasswordLength('password123'), isFalse); // 11
      expect(AuthService.isValidPasswordLength('password1234'), isTrue); // 12
    });
  });

  group('Student ID input, validation and catalogue rules', () {
    const formatter = StudentIdInputFormatter();

    TextEditingValue typed(String text) => TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );

    test('never inserts a dash the user did not type', () {
      // Regression: the old formatter emitted `21-` after two digits, which
      // mangled faculty / other grade level IDs such as `2004-3732`.
      expect(formatter.formatEditUpdate(TextEditingValue.empty, typed('2')).text, '2');
      expect(formatter.formatEditUpdate(typed('2'), typed('21')).text, '21');
      expect(formatter.formatEditUpdate(typed('21'), typed('211')).text, '211');
      expect(formatter.formatEditUpdate(typed('2004'), typed('2004-')).text, '2004-');
    });

    test('keeps user-typed dashes in place', () {
      expect(
        formatter.formatEditUpdate(TextEditingValue.empty, typed('21-1029-315')).text,
        '21-1029-315',
      );
      expect(
        formatter.formatEditUpdate(TextEditingValue.empty, typed('2004-3732')).text,
        '2004-3732',
      );
    });

    test('strips invalid characters and duplicate dashes', () {
      expect(
        formatter.formatEditUpdate(TextEditingValue.empty, typed('21-ABC-1029-XYZ-315')).text,
        '21-1029-315',
      );
      expect(
        formatter.formatEditUpdate(TextEditingValue.empty, typed('--21--1029')).text,
        '21-1029',
      );
    });

    test('caps the digit count at 12', () {
      expect(
        formatter.formatEditUpdate(TextEditingValue.empty, typed('2110293159999')).text,
        '211029315999',
      );
    });

    test('preserves the caret instead of jumping to the end', () {
      // Caret in the middle of `21-1029-315`, user types `9`.
      final result = formatter.formatEditUpdate(
        typed('21-1029-315'),
        const TextEditingValue(
          text: '21-91029-315',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      expect(result.text, '21-91029-315');
      expect(result.selection.baseOffset, 4);
    });

    test('backspace keeps every remaining digit (no corruption)', () {
      // Deleting the `1` at index 2 used to shift the whole number around.
      final result = formatter.formatEditUpdate(
        typed('21-3456-789'),
        const TextEditingValue(
          text: '2-3456-789',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      expect(result.text, '2-3456-789');
      expect(result.selection.baseOffset, 1);
    });

    test('isValid accepts both collegiate and faculty ID shapes', () {
      expect(StudentIdRules.isValid('21-1029-315'), isTrue);
      expect(StudentIdRules.isValid('211029315'), isTrue);
      expect(StudentIdRules.isValid('2004-3732'), isTrue);
      expect(StudentIdRules.isValid('20043732'), isTrue);
      expect(StudentIdRules.isValid('12345'), isFalse); // 5 digits
      expect(StudentIdRules.isValid('invalid-id'), isFalse);
      expect(StudentIdRules.isValid(''), isFalse);
    });

    test('digitsOf normalises for uniqueness comparisons', () {
      expect(StudentIdRules.digitsOf('21-1029-315'), '211029315');
      expect(StudentIdRules.digitsOf('2004-3732'), '20043732');
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

