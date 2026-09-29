import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';
import 'package:teknoycart/features/feed/views/product_discovery_feed_view.dart';
import 'package:teknoycart/features/feed/views/product_detail_view.dart';
import 'package:teknoycart/core/widgets/navigation_drawer.dart';
import 'package:teknoycart/features/checkout/views/checkout_view.dart';
import 'package:flutter/services.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'mock_http_client.dart';

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

  group('Relational Navigation & Modal Bottom Sheet Widget Tests', () {
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

    testWidgets('should render main Discovery Feed with slide-out drawer anchor', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
            productsListProvider.overrideWith((ref) => Future.value([testProduct])),
          ],
          child: const MaterialApp(
            home: ProductDiscoveryFeedView(),
          ),
        ),
      );

      // Verify the App Bar and title
      expect(find.text('TeknoyCart'), findsOneWidget);

      // Verify Drawer anchor button is visible (hamburger menu icon)
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);

      // Open side drawer
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      // Verify Drawer user details are correctly displayed
      expect(find.byType(TeknoyNavigationDrawer), findsOneWidget);
      expect(find.text('teknoy_wildcat'), findsOneWidget);
      expect(find.text('teknoy@cit.edu'), findsOneWidget);
    });

    testWidgets('tapping product card should programmatically instantiate ProductDetailsSheet', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
            productsListProvider.overrideWith((ref) => Future.value([testProduct])),
          ],
          child: const MaterialApp(
            home: ProductDiscoveryFeedView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify product card title is visible
      expect(find.text('Drawing Board Kit'), findsOneWidget);

      // Tap card
      await tester.tap(find.text('Drawing Board Kit'));
      await tester.pumpAndSettle();

      // Verify details view is visible
      expect(find.byType(ProductDetailView), findsOneWidget);
      expect(find.text('₱300.00'), findsWidgets);
      expect(find.text('Verified Student Account'), findsOneWidget);
    });

    testWidgets('tapping Make Offer opens Tawad bottom sheet and updates offer CTA dynamically', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
          ],
          child: MaterialApp(
            home: ProductDetailView(product: testProduct),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Make Offer button exists in bottom bar
      expect(find.text('Make Offer'), findsOneWidget);

      // Tap Make Offer
      await tester.tap(find.text('Make Offer'));
      await tester.pumpAndSettle();

      // Verify Tawad modal sheet opened
      expect(find.text('Make an Offer (Tawad)'), findsOneWidget);
      expect(find.text('-5%'), findsOneWidget);
      expect(find.text('-10%'), findsWidgets);
      expect(find.text('-15%'), findsOneWidget);
      expect(find.text('-20%'), findsOneWidget);

      // Tap -15% chip (300 * 0.85 = 255)
      await tester.tap(find.text('-15%'));
      await tester.pumpAndSettle();

      // Verify CTA button dynamically updated
      expect(find.text('Send ₱255 Offer & Open Chat'), findsOneWidget);
    });

    testWidgets('CheckoutView correctly populates negotiated product, displays Tawad banner, strike-through, and agreed price', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
          ],
          child: MaterialApp(
            home: CheckoutView(
              product: testProduct,
              agreedPrice: 255.0,
              isDirectBuy: true,
              roomId: 'room-123',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Confirm P2P Deal'), findsOneWidget);

      // Verify Tawad Deal Hero Banner is present
      expect(find.text('Campus Meetup Handshake Deal'), findsOneWidget);
      expect(find.text('AGREED PRICE • SAVE ₱45.00'), findsOneWidget);

      // Verify Product Spotlight Card shows the negotiated item (NOT Cart Items (0)!)
      expect(find.text('Cart Items (0)'), findsNothing);
      expect(find.text('Drawing Board Kit'), findsOneWidget);
      expect(find.text('TAWAD DEAL'), findsOneWidget);

      // Verify Strikethrough asking price and agreed price
      expect(find.text('₱300.00'), findsOneWidget);
      expect(find.text('₱255.00'), findsWidgets);

      // Verify Order summary total payable shows agreed price and savings
      expect(find.textContaining('Save ₱45.00'), findsOneWidget);
    });
  });
}
