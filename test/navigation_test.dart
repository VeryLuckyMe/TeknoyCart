import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/features/feed/models/product.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';
import 'package:teknoycart/features/feed/views/product_discovery_feed_view.dart';
import 'package:teknoycart/features/feed/views/product_details_sheet.dart';
import 'package:teknoycart/core/navigation_drawer.dart';
import 'mock_http_client.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = MockHttpOverrides();
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

      // Verify details bottom sheet overlay is visible
      expect(find.byType(ProductDetailsSheet), findsOneWidget);
      expect(find.text('₱300.00'), findsWidgets);
      expect(find.text('Verified Student Account'), findsOneWidget);
    });
  });
}
