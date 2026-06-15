import 'dart:async';
import 'package:teknoycart/core/supabase_client.dart';

/// Heartbeat-based presence service.
/// Periodically updates the current user's `last_seen_at` timestamp
/// in the `users` table so other clients can determine online status.
class PresenceService {
  static PresenceService? _instance;
  Timer? _heartbeatTimer;
  bool _isRunning = false;
  String? _currentUserId;

  /// Heartbeat interval — how often we ping the server
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  /// Threshold for considering a user "online" — if their last_seen_at
  /// is within this duration from now, they are online. (Increased to 10 mins to handle clock drifts).
  static const Duration onlineThreshold = Duration(minutes: 10);

  PresenceService._();

  /// Singleton instance
  static PresenceService get instance {
    _instance ??= PresenceService._();
    return _instance!;
  }

  /// Start the heartbeat timer for the given user.
  /// Call this after successful login.
  void startHeartbeat(String userId) {
    // Send an immediate heartbeat to force-update status instantly
    _sendHeartbeat(userId);

    if (_isRunning) return;
    _isRunning = true;
    _currentUserId = userId;

    // Then send periodically
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _sendHeartbeat(userId);
    });

    print('PRESENCE: Heartbeat started for user $userId (every ${_heartbeatInterval.inSeconds}s)');
  }

  /// Stop the heartbeat timer and immediately mark user as offline.
  /// Call this on logout or app dispose.
  Future<void> stopHeartbeat() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isRunning = false;

    // Immediately clear last_seen_at so the user appears offline right away
    if (_currentUserId != null) {
      try {
        await SupabaseConfig.client
            .from('users')
            .update({'last_seen_at': null})
            .eq('user_id', _currentUserId!);
        print('PRESENCE: Cleared last_seen_at for $_currentUserId');
      } catch (e) {
        print('PRESENCE_CLEAR_ERROR: $e');
      }
    }
    _currentUserId = null;
    print('PRESENCE: Heartbeat stopped');
  }

  /// Send a single heartbeat — updates last_seen_at to NOW() on the server.
  Future<void> _sendHeartbeat(String userId) async {
    try {
      await SupabaseConfig.client
          .from('users')
          .update({'last_seen_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', userId);
      // Uncomment for debug:
      // print('PRESENCE: Heartbeat sent for $userId at ${DateTime.now().toUtc()}');
    } catch (e) {
      print('PRESENCE_HEARTBEAT_ERROR: $e');
    }
  }

  /// Check if a specific user is currently online.
  /// Returns true if their last_seen_at is within the [onlineThreshold].
  static Future<bool> isUserOnline(String userId) async {
    try {
      final result = await SupabaseConfig.client
          .from('users')
          .select('last_seen_at')
          .eq('user_id', userId)
          .maybeSingle();

      if (result == null || result['last_seen_at'] == null) return false;

      final lastSeen = DateTime.tryParse(result['last_seen_at'] as String);
      if (lastSeen == null) return false;

      final diff = DateTime.now().toUtc().difference(lastSeen.toUtc());
      print('PRESENCE: User $userId last seen at: $lastSeen (UTC), local now: ${DateTime.now().toUtc()} (UTC), diff: ${diff.inSeconds}s, threshold: ${onlineThreshold.inSeconds}s');
      return diff < onlineThreshold;
    } catch (e) {
      print('PRESENCE_CHECK_ERROR: $e');
      return false;
    }
  }
}
