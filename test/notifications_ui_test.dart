import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/models/notification_item.dart';
import 'package:teknoycart/core/providers/notification_provider.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/feed/views/product_discovery_feed_view.dart';
import 'mock_http_client.dart';

class FakeNotificationNotifier extends NotificationNotifier {
  final List<NotificationItem> items;
  FakeNotificationNotifier(this.items);

  @override
  Future<List<NotificationItem>> build() async {
    return items;
  }
}

void main() {
  setUpAll(() async {
    HttpOverrides.global = MockHttpOverrides();
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{};
        }
        return null;
      },
    );
    await SupabaseConfig.initialize();
  });

  final testUser = Profile(
    id: 'user-ui-test-01',
    username: 'teknoy_tester',
    email: 'tester@cit.edu',
    role: 'BUYER',
    isSellerVerified: false,
    createdAt: DateTime.now(),
  );

  final sampleNotifications = [
    NotificationItem(
      id: 'notif-1',
      userId: testUser.id,
      title: '💰 Payment Secured in Escrow',
      body: 'Payment for CIT-U Uniform has been confirmed.',
      type: 'PAYMENT',
      referenceId: 'order-101',
      referenceType: 'ORDER',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    NotificationItem(
      id: 'notif-2',
      userId: testUser.id,
      title: 'Order Accepted',
      body: 'Seller accepted your order for Drawing Tools.',
      type: 'ORDER_STATUS',
      referenceId: 'order-102',
      referenceType: 'ORDER',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    NotificationItem(
      id: 'notif-3',
      userId: testUser.id,
      title: '🎉 Seller Verification Approved!',
      body: 'You are now an authorized CIT-U vendor.',
      type: 'KYC',
      referenceId: 'kyc-201',
      referenceType: 'KYC',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  group('Notifications UI & Bottom Sheet Widget Tests', () {
    testWidgets('1. Bell icon: red badge dot is hidden when unreadCount == 0', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(testUser)),
            unreadNotificationCountProvider.overrideWithValue(0),
            notificationProvider.overrideWith(() => FakeNotificationNotifier(const [])),
          ],
          child: const MaterialApp(
            home: ProductDiscoveryFeedView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bellFinder = find.byTooltip('Notifications');
      expect(bellFinder, findsOneWidget);

      final redBadgeFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          return box.color == const Color(0xFFD90429);
        }
        return false;
      });
      expect(redBadgeFinder, findsNothing);
    });

    testWidgets('2. Bell icon: red badge dot is visible when unreadCount > 0', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(testUser)),
            unreadNotificationCountProvider.overrideWithValue(2),
            notificationProvider.overrideWith(() => FakeNotificationNotifier(sampleNotifications)),
          ],
          child: const MaterialApp(
            home: ProductDiscoveryFeedView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final redBadgeFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          return box.color == const Color(0xFFD90429);
        }
        return false;
      });
      expect(redBadgeFinder, findsOneWidget);
    });

    testWidgets('3. Tapping bell icon opens Notification bottom sheet with items & unread counter', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(testUser)),
            unreadNotificationCountProvider.overrideWithValue(2),
            notificationProvider.overrideWith(() => FakeNotificationNotifier(sampleNotifications)),
          ],
          child: const MaterialApp(
            home: ProductDiscoveryFeedView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Mark all as read'), findsOneWidget);
      expect(find.text('💰 Payment Secured in Escrow'), findsOneWidget);
      expect(find.text('Order Accepted'), findsOneWidget);
      expect(find.text('🎉 Seller Verification Approved!'), findsOneWidget);
    });

    testWidgets('4. Empty state: renders clean empty illustration when list has no items', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(testUser)),
            unreadNotificationCountProvider.overrideWithValue(0),
            notificationProvider.overrideWith(() => FakeNotificationNotifier(const [])),
          ],
          child: const MaterialApp(
            home: ProductDiscoveryFeedView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('No new notifications'), findsOneWidget);
      expect(find.text('Updates on orders, payments, and account status will show up here.'), findsOneWidget);
      expect(find.text('Mark all as read'), findsNothing);
    });

    testWidgets('5. Category filter pills: tapping Payments filters list to only payment items', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(testUser)),
            unreadNotificationCountProvider.overrideWithValue(2),
            notificationProvider.overrideWith(() => FakeNotificationNotifier(sampleNotifications)),
          ],
          child: const MaterialApp(
            home: ProductDiscoveryFeedView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();

      expect(find.text('Payments'), findsOneWidget);
      await tester.tap(find.text('Payments'));
      await tester.pumpAndSettle();

      expect(find.text('💰 Payment Secured in Escrow'), findsOneWidget);
      expect(find.text('Order Accepted'), findsNothing);
      expect(find.text('🎉 Seller Verification Approved!'), findsNothing);
    });

    testWidgets('6. Category micro-chips render correctly (PAYMENT, ORDER, VERIFICATION)', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(testUser)),
            unreadNotificationCountProvider.overrideWithValue(2),
            notificationProvider.overrideWith(() => FakeNotificationNotifier(sampleNotifications)),
          ],
          child: const MaterialApp(
            home: ProductDiscoveryFeedView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();

      expect(find.text('PAYMENT'), findsOneWidget);
      expect(find.text('ORDER'), findsOneWidget);
      expect(find.text('VERIFICATION'), findsOneWidget);
    });

    testWidgets('7. Admin notification: New Seller Application renders properly and filters into Account category', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final adminUser = Profile(
        id: 'admin-ui-test-99',
        username: 'teknoy_admin',
        email: 'admin@cit.edu',
        role: 'ADMIN',
        isSellerVerified: true,
        createdAt: DateTime.now(),
      );

      final adminNotifications = [
        NotificationItem(
          id: 'notif-admin-01',
          userId: adminUser.id,
          title: '📋 New Seller Application',
          body: 'Maria Santos submitted KYC verification (STUDENT) for administrative review.',
          type: 'KYC',
          referenceId: 'kyc-application-101',
          referenceType: 'KYC',
          isRead: false,
          createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(adminUser)),
            unreadNotificationCountProvider.overrideWithValue(1),
            notificationProvider.overrideWith(() => FakeNotificationNotifier(adminNotifications)),
          ],
          child: const MaterialApp(
            home: ProductDiscoveryFeedView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();

      // Check title, body, and micro-chip
      expect(find.text('📋 New Seller Application'), findsOneWidget);
      expect(find.text('Maria Santos submitted KYC verification (STUDENT) for administrative review.'), findsOneWidget);
      expect(find.text('VERIFICATION'), findsOneWidget);

      // Tap 'Account' filter pill and confirm item remains visible
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      expect(find.text('📋 New Seller Application'), findsOneWidget);

      // Tap 'Orders' filter pill and confirm item is filtered out
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();
      expect(find.text('📋 New Seller Application'), findsNothing);
    });
  });
}

