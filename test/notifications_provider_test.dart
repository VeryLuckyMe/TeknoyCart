import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/models/notification_item.dart';
import 'package:teknoycart/core/services/notification_service.dart';
import 'package:teknoycart/core/providers/notification_provider.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';

/// Fake NotificationService for deterministic unit and race testing
class FakeNotificationService implements NotificationService {
  List<NotificationItem> storedNotifications = [];
  int unreadCountToReturn = 0;
  bool shouldFailMarkAsRead = false;
  bool isSubscribed = false;
  void Function(NotificationItem)? realtimeCallback;
  void Function()? reconnectCallback;
  Completer<void>? getNotificationsGate;

  @override
  Future<List<NotificationItem>> getNotifications({
    required String userId,
    int limit = 50,
  }) async {
    if (getNotificationsGate != null) {
      await getNotificationsGate!.future;
    }
    return List.from(storedNotifications.take(limit));
  }

  @override
  Future<int> getUnreadCount(String userId) async {
    return unreadCountToReturn;
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    if (shouldFailMarkAsRead) {
      throw Exception('Network connection timed out');
    }
    storedNotifications = storedNotifications.map((it) {
      return it.id == notificationId ? it.copyWith(isRead: true) : it;
    }).toList();
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    storedNotifications = storedNotifications.map((it) {
      return it.copyWith(isRead: true);
    }).toList();
  }

  @override
  void subscribeToRealtimeNotifications({
    required String userId,
    required void Function(NotificationItem) onNewNotification,
    void Function()? onReconnect,
  }) {
    isSubscribed = true;
    realtimeCallback = onNewNotification;
    reconnectCallback = onReconnect;
  }

  @override
  void unsubscribe() {
    isSubscribed = false;
    realtimeCallback = null;
    reconnectCallback = null;
  }
}

void main() {
  late FakeNotificationService fakeService;

  final testProfile = Profile(
    id: 'user-wildcat-001',
    username: 'teknoy',
    email: 'teknoy@cit.edu',
    role: 'BUYER',
    isSellerVerified: false,
    createdAt: DateTime.now(),
  );

  setUp(() {
    fakeService = FakeNotificationService();
  });

  group('NotificationProvider & Notifier Hardened Unit Tests', () {
    test('1. Buffered-insert race: Realtime insert during in-flight fetch is buffered and merged', () async {
      fakeService.getNotificationsGate = Completer<void>();
      fakeService.storedNotifications = [
        NotificationItem(
          id: 'notif-1',
          userId: testProfile.id,
          title: 'Order Placed',
          body: 'Order #1 placed',
          type: 'ORDER_STATUS',
          isRead: true,
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          notificationServiceProvider.overrideWithValue(fakeService),
          authStateProvider.overrideWith((ref) => AsyncValue.data(testProfile)),
        ],
      );
      addTearDown(container.dispose);

      // Trigger build() -> starts in-flight fetch
      final subscription = container.listen(notificationProvider, (_, __) {});
      expect(container.read(notificationProvider).isLoading, true);

      // While fetch is blocked at the gate, simulate a Realtime WebSocket insert!
      final concurrentItem = NotificationItem(
        id: 'notif-race-2',
        userId: testProfile.id,
        title: 'Payment Escrowed',
        body: '₱500 escrowed',
        type: 'PAYMENT',
        isRead: false,
        createdAt: DateTime.now(),
      );
      fakeService.realtimeCallback!(concurrentItem);

      // Release fetch gate
      fakeService.getNotificationsGate!.complete();
      await container.pump();

      // Verify state now has BOTH the fetched item and the buffered realtime item!
      final result = container.read(notificationProvider).value!;
      expect(result.length, 2);
      expect(result.any((it) => it.id == 'notif-race-2'), true);
      expect(result.any((it) => it.id == 'notif-1'), true);

      subscription.close();
    });

    test('2. Granular per-item rollback: Failed markAsRead reverts only target item and preserves concurrent items', () async {
      final item1 = NotificationItem(
        id: 'item-1',
        userId: testProfile.id,
        title: 'Item 1',
        body: 'Body 1',
        type: 'ORDER_STATUS',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      fakeService.storedNotifications = [item1];

      final container = ProviderContainer(
        overrides: [
          notificationServiceProvider.overrideWithValue(fakeService),
          authStateProvider.overrideWith((ref) => AsyncValue.data(testProfile)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(notificationProvider.future);

      // Simulate a new realtime notification arriving concurrently
      final concurrentItem = NotificationItem(
        id: 'item-concurrent',
        userId: testProfile.id,
        title: 'Concurrent',
        body: 'Concurrent body',
        type: 'ORDER_STATUS',
        isRead: false,
        createdAt: DateTime.now(),
      );
      fakeService.realtimeCallback!(concurrentItem);

      expect(container.read(notificationProvider).value!.length, 2);

      // Configure service to simulate a network drop on markAsRead
      fakeService.shouldFailMarkAsRead = true;

      // Attempt markAsRead on item-1
      try {
        await container.read(notificationProvider.notifier).markAsRead('item-1');
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e.toString(), contains('Network connection timed out'));
      }

      // Verify that item-1 was rolled back to isRead: false, but concurrent item is STILL IN STATE!
      final listAfterRollback = container.read(notificationProvider).value!;
      expect(listAfterRollback.length, 2);
      final rolledBackItem = listAfterRollback.firstWhere((it) => it.id == 'item-1');
      expect(rolledBackItem.isRead, false);
      expect(listAfterRollback.any((it) => it.id == 'item-concurrent'), true);
    });

    test('3. Logout teardown: User logging out calls service.unsubscribe and drops subscription', () async {
      final authStateController = StreamController<AsyncValue<Profile?>>.broadcast();

      final container = ProviderContainer(
        overrides: [
          notificationServiceProvider.overrideWithValue(fakeService),
          authStateProvider.overrideWith((ref) => AsyncValue.data(testProfile)),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(authStateController.close);

      await container.read(notificationProvider.future);
      expect(fakeService.isSubscribed, true);

      // Dispose or trigger user logout
      container.dispose();
      expect(fakeService.isSubscribed, false);
    });

    test('4. Exact unread badge count past 50 records', () async {
      fakeService.unreadCountToReturn = 72; // More than 50 unread

      final container = ProviderContainer(
        overrides: [
          notificationServiceProvider.overrideWithValue(fakeService),
          authStateProvider.overrideWith((ref) => AsyncValue.data(testProfile)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(unreadCountNotifierProvider.notifier).fetchExactCount();
      await container.read(notificationProvider.future);

      // Badge must reflect exact DB count of 72, not 50!
      expect(container.read(unreadNotificationCountProvider), 72);

      // New unread item arrives via Realtime -> increments to 73
      final newItem = NotificationItem(
        id: 'new-99',
        userId: testProfile.id,
        title: 'New',
        body: 'New alert',
        type: 'ORDER_STATUS',
        isRead: false,
        createdAt: DateTime.now(),
      );
      fakeService.realtimeCallback!(newItem);

      expect(container.read(unreadNotificationCountProvider), 73);

      // Marking an item as read decrements count back to 72
      await container.read(notificationProvider.notifier).markAsRead('new-99');
      expect(container.read(unreadNotificationCountProvider), 72);
    });

    test('5. Channel reconnection triggers refresh to catch missed offline notifications', () async {
      fakeService.storedNotifications = [
        NotificationItem(
          id: 'offline-item-1',
          userId: testProfile.id,
          title: 'Initial',
          body: 'Initial body',
          type: 'ORDER_STATUS',
          isRead: true,
          createdAt: DateTime.now(),
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          notificationServiceProvider.overrideWithValue(fakeService),
          authStateProvider.overrideWith((ref) => AsyncValue.data(testProfile)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(notificationProvider.future);
      expect(container.read(notificationProvider).value!.length, 1);

      // Simulate a notification added to DB while client was disconnected
      fakeService.storedNotifications.insert(
        0,
        NotificationItem(
          id: 'missed-offline-item-2',
          userId: testProfile.id,
          title: 'Missed While Offline',
          body: 'Missed body',
          type: 'ORDER_STATUS',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      );

      // Simulate Realtime channel reconnecting
      fakeService.reconnectCallback!();
      await container.pump();

      // State is refreshed and picks up the missed item!
      expect(container.read(notificationProvider).value!.length, 2);
      expect(container.read(notificationProvider).value!.first.id, 'missed-offline-item-2');
    });
  });
}
