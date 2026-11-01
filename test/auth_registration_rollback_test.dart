import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/features/auth/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService Sign Up Domain and Input Validation', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService();
    });

    test('SELLER with valid Gmail address passes email validation', () {
      expect(authService.isValidGeneralEmail('mikeljoshx@gmail.com'), isTrue);
    });

    test('SELLER with valid CIT-U email passes email validation', () {
      expect(authService.isValidGeneralEmail('seller@cit.edu'), isTrue);
    });

    test('BUYER with Gmail is rejected before hitting network', () {
      expect(
        () => authService.signUp(
          email: 'buyer@gmail.com',
          username: 'Test Buyer',
          password: 'Password1234!',
          role: 'BUYER',
          studentId: '22-1234-567',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('Student ID format is strictly validated (##-####-###)', () {
      expect(
        () => authService.signUp(
          email: 'seller@gmail.com',
          username: 'Test Seller',
          password: 'Password1234!',
          role: 'SELLER',
          studentId: 'invalid-id',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
