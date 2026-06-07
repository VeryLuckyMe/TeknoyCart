import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/services/auth_service.dart';
import 'package:teknoycart/features/chat/services/presence_service.dart';

/// Provider exposing the single instance of AuthService.
final authServiceProvider = Provider<AuthService>((ref) {
  final service = AuthService();
  ref.onDispose(() => service.dispose());
  return service;
});

final authStateProvider = StreamProvider<Profile?>((ref) async* {
  final service = ref.watch(authServiceProvider);
  yield service.currentUser;
  yield* service.authStateChanges;
});

class AuthNotifier extends StateNotifier<AsyncValue<Profile?>> {
  final AuthService _authService;
  StreamSubscription<Profile?>? _authSubscription;

  AuthNotifier(this._authService) : super(const AsyncValue.data(null)) {
    // Sync initial state
    final existingUser = _authService.currentUser;
    state = AsyncValue.data(existingUser);
    if (existingUser != null) {
      PresenceService.instance.startHeartbeat(existingUser.id);
    }

    // Auto-sync state and manage heartbeat for all auth changes (including auto-login / session restore)
    _authSubscription = _authService.authStateChanges.listen((user) {
      state = AsyncValue.data(user);
      if (user != null) {
        PresenceService.instance.startHeartbeat(user.id);
      } else {
        PresenceService.instance.stopHeartbeat();
      }
    });
  }

  /// Sign in user with error handling and loading indicators.
  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.signIn(email: email, password: password);
      state = AsyncValue.data(user);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Register user with error handling and loading indicators.
  Future<void> register({
    required String email,
    required String username,
    required String password,
    required String role,
    required String studentId,
    String? department,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _authService.signUp(
        email: email,
        username: username,
        password: password,
        role: role,
        studentId: studentId,
        department: department,
      );
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Logs out and resets user session state.
  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      await _authService.signOut();
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

/// Global provider for AuthNotifier state management.
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<Profile?>>((ref) {
  final service = ref.watch(authServiceProvider);
  return AuthNotifier(service);
});
