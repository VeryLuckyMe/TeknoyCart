import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service responsible for FCM device token registration, pre-logout unregistration,
/// cold-start notification navigation routing, and foreground push events.
class FcmService {
  static final FcmService _singleton = FcmService._internal();
  static FcmService get instance => _singleton;

  final SupabaseClient? _customClient;
  String? _cachedToken;
  Map<String, dynamic>? _pendingPayload;

  final StreamController<Map<String, dynamic>> _foregroundNotificationsController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onForegroundNotification =>
      _foregroundNotificationsController.stream;

  FcmService._internal({SupabaseClient? client})
      : _customClient = client;

  SupabaseClient? get _supabase {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  factory FcmService.forTesting(SupabaseClient client) {
    return FcmService._internal(client: client);
  }

  /// The currently active FCM device token in this session.
  String? get cachedToken => _cachedToken;

  /// Registers or refreshes the FCM device token in the database.
  /// Uses upsert on conflict(token) to gracefully transfer ownership on shared campus devices.
  Future<bool> registerToken(String token, {String platform = 'ANDROID'}) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return false;

    _cachedToken = trimmed;
    final client = _supabase;
    if (client == null) {
      debugPrint('[FCM] Supabase not initialized. Token cached: $trimmed');
      return false;
    }

    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[FCM] No authenticated user. Token cached for deferred sync: $trimmed');
      return false;
    }

    try {
      await client.from('user_fcm_tokens').upsert(
        {
          'user_id': userId,
          'token': trimmed,
          'platform': platform,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'token',
      );
      debugPrint('[FCM] Successfully registered device token for user: $userId');
      return true;
    } catch (e) {
      debugPrint('[FCM] Warning: Failed to sync device token to Supabase: $e');
      return false;
    }
  }

  /// Unregisters the cached device token from the database.
  /// MUST be called BEFORE `supabase.auth.signOut()` to satisfy RLS policy `(auth.uid() = user_id)`.
  Future<bool> unregisterToken() async {
    final token = _cachedToken;
    if (token == null) {
      return true;
    }

    final client = _supabase;
    if (client == null) {
      _cachedToken = null;
      return true;
    }

    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      _cachedToken = null;
      return true;
    }

    try {
      await client.from('user_fcm_tokens').delete().eq('token', token);
      debugPrint('[FCM] Device token removed successfully for user: $userId');
      _cachedToken = null;
      return true;
    } catch (e) {
      debugPrint('[FCM] Warning: Failed to unregister device token: $e');
      _cachedToken = null;
      return false;
    }
  }

  /// Queues a notification payload received during a cold start before authentication or navigation was mounted.
  void queueNotificationPayload(Map<String, dynamic> payload) {
    _pendingPayload = Map<String, dynamic>.from(payload);
    debugPrint('[FCM] Cold-start payload queued: $_pendingPayload');
  }

  /// Consumes and clears any pending cold-start notification payload.
  Map<String, dynamic>? consumePendingPayload() {
    final payload = _pendingPayload;
    _pendingPayload = null;
    return payload;
  }

  /// Dispatches a foreground notification event to listeners.
  void dispatchForegroundNotification(Map<String, dynamic> payload) {
    if (!_foregroundNotificationsController.isClosed) {
      _foregroundNotificationsController.add(payload);
    }
  }

  /// Disposes internal stream controllers.
  void dispose() {
    _foregroundNotificationsController.close();
  }
}
