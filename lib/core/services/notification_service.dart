import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_item.dart';

class NotificationService {
  final SupabaseClient _client;
  RealtimeChannel? _subscriptionChannel;

  NotificationService(this._client);

  /// Fetch notifications for [userId], ordered newest first.
  /// Throws on network failure so Riverpod can transition to AsyncError.
  Future<List<NotificationItem>> getNotifications({
    required String userId,
    int limit = 50,
  }) async {
    final response = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map((item) => NotificationItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Exact unread count directly from Postgres (not capped by the 50-row query limit).
  Future<int> getUnreadCount(String userId) async {
    final response = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false)
        .count(CountOption.exact);

    return response.count;
  }

  /// Mark single notification as read
  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  /// Mark all unread notifications as read for current user
  Future<void> markAllAsRead(String userId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  /// Subscribe to Realtime notifications channel for this user.
  /// Fires [onNewNotification] for inserts and [onReconnect] when reconnected.
  void subscribeToRealtimeNotifications({
    required String userId,
    required void Function(NotificationItem notification) onNewNotification,
    VoidCallback? onReconnect,
  }) {
    unsubscribe();

    bool hasConnectedOnce = false;

    _subscriptionChannel = _client
        .channel('public:notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
              onNewNotification(NotificationItem.fromJson(newRecord));
            }
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            if (hasConnectedOnce) {
              // Reconnection event: trigger refetch of missed notifications
              onReconnect?.call();
            } else {
              hasConnectedOnce = true;
            }
          }
        });
  }

  /// Clean teardown
  void unsubscribe() {
    if (_subscriptionChannel != null) {
      _client.removeChannel(_subscriptionChannel!);
      _subscriptionChannel = null;
    }
  }
}
