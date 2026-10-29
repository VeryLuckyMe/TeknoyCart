import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/core/services/deep_link_service.dart';
import 'package:teknoycart/core/services/wishlist_service.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/checkout/views/order_detail_view.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';
import 'package:teknoycart/features/feed/views/product_discovery_feed_view.dart';
import 'package:teknoycart/features/feed/views/wishlist_view.dart';
import 'package:teknoycart/features/splash/splash_view.dart';
import 'package:teknoycart/main.dart';
import 'mock_http_client.dart';

class _NoOpWishlistStorage implements WishlistStorageAdapter {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
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

  group('DeepLinkParser Unit Tests', () {
    test('parses teknoycart://order?id=<uuid> into DeepLinkOrder', () {
      final uri = Uri.parse('teknoycart://order?id=123e4567-e89b-12d3-a456-426614174000');
      final dest = DeepLinkParser.parse(uri);

      expect(dest, isA<DeepLinkOrder>());
      expect((dest as DeepLinkOrder).orderId, '123e4567-e89b-12d3-a456-426614174000');
    });

    test('parses path-style teknoycart://order/<uuid> into DeepLinkOrder', () {
      final uri = Uri.parse('teknoycart://order/123e4567-e89b-12d3-a456-426614174000');
      final dest = DeepLinkParser.parse(uri);

      expect(dest, isA<DeepLinkOrder>());
      expect((dest as DeepLinkOrder).orderId, '123e4567-e89b-12d3-a456-426614174000');
    });

    test('returns DeepLinkUnknown when order id is missing or blank', () {
      expect(DeepLinkParser.parse(Uri.parse('teknoycart://order')), isA<DeepLinkUnknown>());
      expect(DeepLinkParser.parse(Uri.parse('teknoycart://order?id=   ')), isA<DeepLinkUnknown>());
      expect(DeepLinkParser.parse(Uri.parse('teknoycart://order/')), isA<DeepLinkUnknown>());
    });

    test('parses teknoycart://wishlist and teknoycart://home', () {
      expect(DeepLinkParser.parse(Uri.parse('teknoycart://wishlist')), isA<DeepLinkWishlist>());
      expect(DeepLinkParser.parse(Uri.parse('teknoycart://home')), isA<DeepLinkHome>());
    });

    test('ignores Supabase auth callback teknoycart://login-callback', () {
      final uri = Uri.parse('teknoycart://login-callback#access_token=abc&type=recovery');
      expect(DeepLinkParser.parse(uri), isA<DeepLinkIgnored>());
    });

    test('returns DeepLinkUnknown for null or foreign scheme URIs without throwing', () {
      expect(DeepLinkParser.parse(null), isA<DeepLinkUnknown>());
      expect(DeepLinkParser.parse(Uri.parse('https://example.com/order?id=123')), isA<DeepLinkUnknown>());
      expect(DeepLinkParser.parse(Uri.parse('teknoycart://unknown-host')), isA<DeepLinkUnknown>());
    });
  });

  group('DeepLinkService Cold/Warm Start & Routing Widget Tests', () {
    testWidgets('cold start with teknoycart://order?id=... navigates to OrderDetailView',
        (WidgetTester tester) async {
      final navKey = GlobalKey<NavigatorState>();
      final fakeSource = FakeAppLinkSource(
        initialLink: Uri.parse('teknoycart://order?id=ord-cold-99'),
      );
      final service = DeepLinkService(
        navigatorKey: navKey,
        source: fakeSource,
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWithValue(const AsyncValue.data(null)),
          ],
          child: MaterialApp(
            navigatorKey: navKey,
            home: const Scaffold(body: Text('Home Placeholder')),
          ),
        ),
      );

      await service.initialize();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(OrderDetailView), findsOneWidget);
      expect(find.textContaining('ORD-COLD'), findsOneWidget);
    });

    testWidgets('warm start stream emission routes to OrderDetailView and WishlistView with deduplication',
        (WidgetTester tester) async {
      final navKey = GlobalKey<NavigatorState>();
      final fakeSource = FakeAppLinkSource();
      int pushedRoutes = 0;

      final service = DeepLinkService(
        navigatorKey: navKey,
        source: fakeSource,
        onDestinationNavigated: (_) => pushedRoutes++,
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWithValue(const AsyncValue.data(null)),
            wishlistProvider.overrideWith(
              (ref) => WishlistNotifier(storage: _NoOpWishlistStorage(), autoLoad: false),
            ),
            productsListProvider.overrideWith((ref) => Future.value(<Product>[])),
          ],
          child: MaterialApp(
            navigatorKey: navKey,
            home: const Scaffold(body: Text('Home Placeholder')),
          ),
        ),
      );

      await service.initialize();
      await tester.pump();

      // Emit duplicate order links back-to-back: should only push once
      fakeSource.emit(Uri.parse('teknoycart://order?id=ord-warm-42'));
      fakeSource.emit(Uri.parse('teknoycart://order?id=ord-warm-42'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(pushedRoutes, 1);
      expect(find.byType(OrderDetailView), findsOneWidget);

      // Emit wishlist link: should navigate to WishlistView
      fakeSource.emit(Uri.parse('teknoycart://wishlist'));
      await tester.pumpAndSettle();

      expect(pushedRoutes, 2);
      expect(find.byType(WishlistView), findsOneWidget);
    });

    testWidgets('queues deep link when splash/auth is not ready and flushes when ready',
        (WidgetTester tester) async {
      final navKey = GlobalKey<NavigatorState>();
      final fakeSource = FakeAppLinkSource(
        initialLink: Uri.parse('teknoycart://order?id=ord-queued-77'),
      );
      bool ready = false;
      bool authed = false;

      final service = DeepLinkService(
        navigatorKey: navKey,
        source: fakeSource,
        isNavigationReady: () => ready,
        isAuthenticated: () => authed,
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWithValue(const AsyncValue.data(null)),
          ],
          child: MaterialApp(
            navigatorKey: navKey,
            home: const Scaffold(body: Text('Splash Screen')),
          ),
        ),
      );

      await service.initialize();
      await tester.pump();

      // Still on splash screen because ready == false and authed == false
      expect(find.byType(OrderDetailView), findsNothing);
      expect(service.pendingDestination, isA<DeepLinkOrder>());

      // Splash completes and user is authenticated -> flushPending() routes to OrderDetailView
      ready = true;
      authed = true;
      await service.flushPending();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(service.pendingDestination, isNull);
      expect(find.byType(OrderDetailView), findsOneWidget);
    });

    testWidgets('TeknoyCartApp root integration wires deepLinkServiceProvider and routes on incoming PayMongo return link',
        (WidgetTester tester) async {
      final fakeSource = FakeAppLinkSource();
      addTearDown(fakeSource.dispose);

      final testUser = Profile(
        id: 'usr-buyer-1',
        username: 'Teknoy Buyer',
        email: 'buyer@cit.edu',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLinkSourceProvider.overrideWithValue(fakeSource),
            isSplashCompletedProvider.overrideWith((ref) => true),
            authStateProvider.overrideWithValue(AsyncValue.data(testUser)),
            productsListProvider.overrideWith((ref) => Future.value(<Product>[])),
            wishlistProvider.overrideWith(
              (ref) => WishlistNotifier(storage: _NoOpWishlistStorage(), autoLoad: false),
            ),
          ],
          child: const TeknoyCartApp(),
        ),
      );

      // Replace SplashView with ProductDiscoveryFeedView to simulate active post-splash state
      appNavigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(builder: (_) => const ProductDiscoveryFeedView()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Simulate PayMongo browser redirect returning to app
      fakeSource.emit(Uri.parse('teknoycart://order?id=paymongo-escrow-88'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(OrderDetailView), findsOneWidget);
      expect(find.textContaining('PAYMONGO'), findsOneWidget);
    });
  });
}
