import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/auth/services/auth_service.dart';
import 'package:teknoycart/features/auth/models/profile.dart';

class MockFailingAuthService extends AuthService {
  bool deleteCalled = false;
  final Exception? errorToThrow;

  MockFailingAuthService({this.errorToThrow});

  @override
  Future<void> deleteAccount() async {
    deleteCalled = true;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
  }

  @override
  Profile? get currentUser => null;

  @override
  Stream<Profile?> get authStateChanges => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthNotifier Account Deletion Tests', () {
    test('deleteAccount calls service and sets state to null on success', () async {
      final mockService = MockFailingAuthService();
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);

      await notifier.deleteAccount();

      expect(mockService.deleteCalled, isTrue);
      expect(container.read(authNotifierProvider).valueOrNull, isNull);
    });

    test('deleteAccount rethrows error and preserves error state on failure', () async {
      final mockService = MockFailingAuthService(
        errorToThrow: Exception('CANNOT_DELETE_ACTIVE_ORDERS: Cannot delete account while you have active transactions'),
      );
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);

      expect(
        () => notifier.deleteAccount(),
        throwsA(isA<Exception>()),
      );
      expect(mockService.deleteCalled, isTrue);
    });
  });
}

