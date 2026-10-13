import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_item.dart';
import '../services/notification_service.dart';
import '../supabase_client.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Singleton provider for NotificationService.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(SupabaseConfig.client);
});

/// Dedicated exact unread badge count provider.
/// Solves the 50-row pagination limit by issuing an exact count query from Postgres
/// and maintaining parity on realtime increments, local reads, and rollbacks.
class UnreadCountNotifier extends StateNotifier<int> {
  final NotificationService _service;
  final String? _userId;

  UnreadCountNotifier(this._service, this._userId) : super(0) {
    final uid = _userId;
    if (uid != null && uid.isNotEmpty) {
      fetchExactCount();
    }
  }

  Future<void> fetchExactCount() async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) return;
    try {
      final count = await _service.getUnreadCount(uid);
      if (mounted) {
        state = count;
      }
    } catch (_) {}
  }

  void increment() => state = state + 1;
  void decrement() => state = state > 0 ? state - 1 : 0;
  void reset() => state = 0;
  void setCount(int value) => state = value;
}

final unreadCountNotifierProvider =
    StateNotifierProvider<UnreadCountNotifier, int>((ref) {
  final service = ref.watch(notificationServiceProvider);
  final profile = ref.watch(authStateProvider).valueOrNull;
  return UnreadCountNotifier(service, profile?.id);
});

/// Public reactive unread count badge provider.
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(unreadCountNotifierProvider);
});

/// Main Notification state notifier managing list lifecycle, realtime buffering,
/// and granular per-item rollbacks.
class NotificationNotifier extends AsyncNotifier<List<NotificationItem>> {
  final List<NotificationItem> _incomingBuffer = [];

  @override
  Future<List<NotificationItem>> build() async {
    final profile = ref.watch(authStateProvider).valueOrNull;
    final service = ref.read(notificationServiceProvider);

    // 1. Teardown any existing subscription immediately (prevents channel leaks on logout/relogin)
    service.unsubscribe();

    // Register disposal hook tied to this notifier's lifetime
    ref.onDispose(() {
      service.unsubscribe();
    });

    if (profile == null || profile.id.isEmpty) {
      return [];
    }

    _incomingBuffer.clear();

    // 2. Subscribe to Realtime FIRST with local buffer to prevent missing inserts during initial fetch
    service.subscribeToRealtimeNotifications(
      userId: profile.id,
      onNewNotification: (newItem) {
        if (state.isLoading) {
          // Buffer incoming items while fetch is in-flight
          _incomingBuffer.add(newItem);
        } else {
          final current = state.value ?? [];
          if (!current.any((it) => it.id == newItem.id)) {
            state = AsyncData([newItem, ...current]);
            if (!newItem.isRead) {
              ref.read(unreadCountNotifierProvider.notifier).increment();
            }
          }
        }
      },
      onReconnect: () {
        // Lens 3 Reconnection: refetch to catch any inserts during network drop
        refresh();
      },
    );

    // 3. Fetch initial 50 records
    final fetched = await service.getNotifications(userId: profile.id);

    // 4. Merge buffered realtime items with fetched items, deduping by id
    final Map<String, NotificationItem> merged = {
      for (final item in _incomingBuffer) item.id: item,
    };
    for (final item in fetched) {
      merged.putIfAbsent(item.id, () => item);
    }
    _incomingBuffer.clear();

    final result = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return result;
  }

  /// Mark single notification as read with granular per-item rollback.
  /// Does NOT clobber concurrent realtime items if the network call fails.
  Future<void> markAsRead(String notificationId) async {
    final current = state.value ?? [];
    final targetIndex = current.indexWhere((it) => it.id == notificationId);
    if (targetIndex == -1 || current[targetIndex].isRead) return;

    // 1. Optimistic update
    state = AsyncData(
      current.map((it) => it.id == notificationId ? it.copyWith(isRead: true) : it).toList(),
    );
    ref.read(unreadCountNotifierProvider.notifier).decrement();

    // 2. Remote update
    try {
      await ref.read(notificationServiceProvider).markAsRead(notificationId);
    } catch (e) {
      // 3. Rollback ONLY the specific affected item
      state.whenData((latestList) {
        state = AsyncData(
          latestList.map((it) => it.id == notificationId ? it.copyWith(isRead: false) : it).toList(),
        );
      });
      ref.read(unreadCountNotifierProvider.notifier).increment();
      rethrow;
    }
  }

  /// Mark all notifications as read with granular rollback of previously unread items.
  Future<void> markAllAsRead() async {
    final profile = ref.read(authStateProvider).valueOrNull;
    if (profile == null) return;

    final current = state.value ?? [];
    final previousUnreadIds = current.where((it) => !it.isRead).map((it) => it.id).toSet();
    if (previousUnreadIds.isEmpty) return;

    final previousCount = ref.read(unreadCountNotifierProvider);

    // 1. Optimistic update
    state = AsyncData(
      current.map((it) => it.copyWith(isRead: true)).toList(),
    );
    ref.read(unreadCountNotifierProvider.notifier).reset();

    // 2. Remote update
    try {
      await ref.read(notificationServiceProvider).markAllAsRead(profile.id);
    } catch (e) {
      // 3. Rollback only the items that were previously unread
      state.whenData((latestList) {
        state = AsyncData(
          latestList.map((it) {
            return previousUnreadIds.contains(it.id) ? it.copyWith(isRead: false) : it;
          }).toList(),
        );
      });
      ref.read(unreadCountNotifierProvider.notifier).setCount(previousCount);
      rethrow;
    }
  }

  /// Explicit refresh (e.g. pull to refresh or on channel reconnection)
  Future<void> refresh() async {
    final profile = ref.read(authStateProvider).valueOrNull;
    if (profile == null) return;

    final service = ref.read(notificationServiceProvider);
    try {
      final fresh = await service.getNotifications(userId: profile.id);
      state = AsyncData(fresh);
      ref.read(unreadCountNotifierProvider.notifier).fetchExactCount();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

/// Global provider for NotificationNotifier.
final notificationProvider =
    AsyncNotifierProvider<NotificationNotifier, List<NotificationItem>>(
  NotificationNotifier.new,
);
