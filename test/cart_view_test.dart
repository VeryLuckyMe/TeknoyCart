import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/checkout/models/cart_item.dart';
import 'package:teknoycart/features/checkout/providers/cart_provider.dart';
import 'package:teknoycart/features/checkout/views/cart_view.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';
import 'package:teknoycart/features/feed/views/product_discovery_feed_view.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'mock_http_client.dart';

class _FakeCartStorage implements CartStorageService {
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
    const MethodChannel('plugins.flutter.io/shared_preferences')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{};
      }
      return null;
    });
    await SupabaseConfig.initialize();
  });

  group('CartView Empty Cart State & Navigation Tests', () {
    late Profile mockUser;
    late Product testProduct;

    setUp(() {
      mockUser = Profile(
        id: 'usr-1',
        username: 'teknoy_wildcat',
        email: 'teknoy@cit.edu',
        createdAt: DateTime.now(),
      );

      testProduct = Product(
        id: 'prod-test-1',
        title: 'Drawing Board Kit',
        description: 'CIT-U Drawing board with straightedge ruler and carrying case.',
        price: 300.00,
        category: 'Drawing Tools',
        condition: 'Like New',
        sellerId: 'usr-123',
        createdAt: DateTime.now(),
      );
    });

    testWidgets('empty cart renders CTA and tapping Explore Campus Deals navigates to ProductDiscoveryFeedView',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final emptyCartNotifier = CartNotifier(storage: _FakeCartStorage(), autoLoad: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
            productsListProvider.overrideWith((ref) => Future.value([testProduct])),
            cartProvider.overrideWith((ref) => emptyCartNotifier),
          ],
          child: const MaterialApp(
            home: CartView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify empty state text and CTA button
      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('Explore pre-loved uniforms, books, and drawing kits on campus!'), findsOneWidget);
      expect(find.text('Explore Campus Deals'), findsOneWidget);
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);

      // Verify "Clear All" button is not present
      expect(find.text('Clear All'), findsNothing);

      // Tap 'Explore Campus Deals'
      await tester.tap(find.text('Explore Campus Deals'));
      await tester.pumpAndSettle();

      // Verify user has been transferred into ProductDiscoveryFeedView (home / products catalog)
      expect(find.byType(ProductDiscoveryFeedView), findsOneWidget);
      expect(find.text('TeknoyCart'), findsOneWidget);
    });

    testWidgets('populated cart does not show empty state, and clearing cart reveals Explore Campus Deals CTA',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final populatedCartNotifier = CartNotifier(storage: _FakeCartStorage(), autoLoad: false);
      populatedCartNotifier.addToCart(testProduct, quantity: 1);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
            productsListProvider.overrideWith((ref) => Future.value([testProduct])),
            cartProvider.overrideWith((ref) => populatedCartNotifier),
          ],
          child: const MaterialApp(
            home: CartView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify cart items are visible, empty state CTA is not visible
      expect(find.text('Drawing Board Kit'), findsWidgets);
      expect(find.text('Your cart is empty'), findsNothing);
      expect(find.text('Explore Campus Deals'), findsNothing);
      expect(find.text('Clear All'), findsOneWidget);

      // Tap 'Clear All'
      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();

      // Verify empty state is now displayed
      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('Explore Campus Deals'), findsOneWidget);

      // Tap 'Explore Campus Deals' and verify navigation to ProductDiscoveryFeedView
      await tester.tap(find.text('Explore Campus Deals'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductDiscoveryFeedView), findsOneWidget);
      expect(find.text('TeknoyCart'), findsOneWidget);
    });
  });
}
