import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/services/auth_service.dart';
import 'package:teknoycart/features/chat/services/presence_service.dart';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/core/supabase_client.dart';

/// Provider exposing the single instance of AuthService.
final authServiceProvider = Provider<AuthService>((ref) {
  final service = AuthService();
  ref.onDispose(() => service.dispose());
  return service;
});

final authStateProvider = Provider<AsyncValue<Profile?>>((ref) {
  return ref.watch(authNotifierProvider);
});

class AuthNotifier extends StateNotifier<AsyncValue<Profile?>> {
  final AuthService _authService;
  StreamSubscription<Profile?>? _authSubscription;
  RealtimeChannel? _verifChannel;

  AuthNotifier(this._authService) : super(const AsyncValue.data(null)) {
    // Sync initial state
    final existingUser = _authService.currentUser;
    state = AsyncValue.data(existingUser);
    if (existingUser != null) {
      PresenceService.instance.startHeartbeat(existingUser.id);
      _subscribeToVerificationChanges(existingUser.id);
      _authService.getEnrichedProfile(existingUser).then((enriched) {
        if (mounted) {
          state = AsyncValue.data(enriched);
        }
      });
    }

    // Auto-sync state and manage heartbeat for all auth changes (including auto-login / session restore)
    _authSubscription = _authService.authStateChanges.listen((user) async {
      if (user != null) {
        state = AsyncValue.data(user);
        PresenceService.instance.startHeartbeat(user.id);
        _subscribeToVerificationChanges(user.id);
        final enriched = await _authService.getEnrichedProfile(user);
        if (mounted) {
          state = AsyncValue.data(enriched);
        }
      } else {
        _verifChannel?.unsubscribe();
        _verifChannel = null;
        state = const AsyncValue.data(null);
        PresenceService.instance.stopHeartbeat();
      }
    });
  }

  void _subscribeToVerificationChanges(String userId) {
    _verifChannel?.unsubscribe();
    try {
      _verifChannel = SupabaseConfig.client
          .channel('user_verif_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'seller_verifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              refreshProfile();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('VERIF_REALTIME_ERROR: $e');
    }
  }

  /// Refreshes the user's role and verification status from the database.
  Future<void> refreshProfile() async {
    final current = state.valueOrNull ?? _authService.currentUser;
    if (current != null) {
      final enriched = await _authService.getEnrichedProfile(current);
      if (mounted) {
        state = AsyncValue.data(enriched);
      }
    }
  }

  /// Sign in user with error handling and loading indicators.
  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.signIn(email: email, password: password);
      final enriched = await _authService.getEnrichedProfile(user);
      state = AsyncValue.data(enriched);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
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
    String? storeName,
    String? sellerType,   // 'STUDENT' or 'ORG'
    String? orgContact,   // contact number for ORG sellers
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
        storeName: storeName,
        sellerType: sellerType,
        orgContact: orgContact,
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
    _verifChannel?.unsubscribe();
    _authSubscription?.cancel();
    super.dispose();
  }
}

/// Global provider for AuthNotifier state management.
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<Profile?>>((ref) {
  final service = ref.watch(authServiceProvider);
  return AuthNotifier(service);
});
