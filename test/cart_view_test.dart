import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
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

    testWidgets('Cart Edit Mode: steppers are hidden in normal mode, appear in edit mode, and batch commit on Done',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final populatedCartNotifier = CartNotifier(storage: _FakeCartStorage(), autoLoad: false);
      populatedCartNotifier.addToCart(testProduct, quantity: 1, maxStock: 10);

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

      // Normal mode: steppers should NOT be visible, static Qty pill is visible
      expect(find.text('Qty: 1'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsNothing);
      expect(find.byIcon(Icons.remove_rounded), findsNothing);
      expect(find.byKey(const Key('cart_edit_mode_button')), findsOneWidget);
      expect(find.byKey(const Key('cart_done_button')), findsNothing);

      // Tap generic edit button (Icons.tune_rounded)
      await tester.tap(find.byKey(const Key('cart_edit_mode_button')));
      await tester.pumpAndSettle();

      // Edit mode: 'Editing' badge and 'Done' button appear
      expect(find.text('Editing'), findsOneWidget);
      expect(find.byKey(const Key('cart_done_button')), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      // Increment draft quantity
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      // UI displays draft quantity 2, but CartNotifier state is still 1 (zero real-time mutation!)
      expect(find.text('2'), findsOneWidget);
      expect(populatedCartNotifier.state.first.quantity, 1);

      // Tap 'Done' button to batch commit
      await tester.tap(find.byKey(const Key('cart_done_button')));
      await tester.pumpAndSettle();

      // Returns to normal mode: notifier state is now committed to 2
      expect(populatedCartNotifier.state.first.quantity, 2);
      expect(find.text('Qty: 2'), findsOneWidget);
      expect(find.text('Editing'), findsNothing);
    });

    testWidgets('Cart Edit Mode: tapping minus on quantity 1 displays confirmation sheet instead of immediate deletion',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final populatedCartNotifier = CartNotifier(storage: _FakeCartStorage(), autoLoad: false);
      populatedCartNotifier.addToCart(testProduct, quantity: 1, maxStock: 5);

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

      // Enter edit mode
      await tester.tap(find.byKey(const Key('cart_edit_mode_button')));
      await tester.pumpAndSettle();

      // Tap minus on quantity 1 (trash icon on stepper)
      await tester.tap(find.byIcon(Icons.delete_outline_rounded).last);
      await tester.pumpAndSettle();

      // Confirmation sheet appears with 'Remove from Cart?' and 'Keep in Cart'
      expect(find.text('Remove from Cart?'), findsOneWidget);
      expect(find.text('Keep in Cart'), findsOneWidget);
      expect(find.text('Remove Item'), findsOneWidget);

      // Tap 'Keep in Cart' to dismiss without deleting
      await tester.tap(find.text('Keep in Cart'));
      await tester.pumpAndSettle();

      // Item is still in cart! Not vanished!
      expect(find.text('Drawing Board Kit'), findsWidgets);
      expect(populatedCartNotifier.state, isNotEmpty);
    });

    testWidgets('Cart Per-Store Edit Mode: editing Store 1 reveals steppers only for Store 1 while Store 2 remains unaffected',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final product1 = Product(
        id: 'prod-store1',
        title: 'Boxy Cropped Polo',
        description: 'Store 1 item',
        price: 250.00,
        category: 'Uniform',
        condition: 'Good',
        sellerId: 'seller-josh',
        sellerStoreName: 'josh store',
        createdAt: DateTime.now(),
      );

      final product2 = Product(
        id: 'prod-store2',
        title: 'Kanding for Sale',
        description: 'Store 2 item',
        price: 700.00,
        category: 'Pets',
        condition: 'New',
        sellerId: 'seller-cit',
        sellerStoreName: 'CIT Marketing',
        createdAt: DateTime.now(),
      );

      final populatedCartNotifier = CartNotifier(storage: _FakeCartStorage(), autoLoad: false);
      populatedCartNotifier.addToCart(product1, quantity: 1, maxStock: 5);
      populatedCartNotifier.addToCart(product2, quantity: 1, maxStock: 5);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
            productsListProvider.overrideWith((ref) => Future.value([product1, product2])),
            cartProvider.overrideWith((ref) => populatedCartNotifier),
          ],
          child: const MaterialApp(
            home: CartView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both stores visible
      expect(find.text('josh store'), findsOneWidget);
      expect(find.text('CIT Marketing'), findsOneWidget);

      // Both stores are in normal mode initially (each has static "Qty: 1")
      expect(find.text('Qty: 1'), findsNWidgets(2));
      expect(find.text('Edit'), findsNWidgets(2));
      expect(find.text('Done'), findsNothing);

      // Tap Edit on Store 1 (josh store)
      await tester.tap(find.byKey(const Key('cart_edit_mode_button')));
      await tester.pumpAndSettle();

      // Only Store 1 is in edit mode!
      expect(find.text('Editing'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget); // Store 2 still has Edit!

      // Store 1 shows steppers (+ icon)
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      // Store 2 still has static Qty: 1
      expect(find.text('Qty: 1'), findsOneWidget);

      // Tap Done on Store 1
      await tester.tap(find.byKey(const Key('cart_done_button')));
      await tester.pumpAndSettle();

      // Both are back in normal mode
      expect(find.text('Editing'), findsNothing);
      expect(find.text('Done'), findsNothing);
      expect(find.text('Edit'), findsNWidgets(2));
      expect(find.text('Qty: 1'), findsNWidgets(2));
    });
  });
}
