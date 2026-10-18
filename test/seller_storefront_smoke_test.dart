import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';
import 'package:teknoycart/features/feed/providers/review_provider.dart';
import 'package:teknoycart/features/feed/views/seller_storefront_view.dart';
import 'mock_http_client.dart';

/// Smoke coverage for the sliver-based storefront body (Finder #9 wave):
/// the catalog grid now renders via SliverGrid inside a CustomScrollView.
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

  group('SellerStorefrontView Sliver Conversion Smoke Tests', () {
    late Profile mockUser;

    setUp(() {
      mockUser = Profile(
        id: 'buyer-1',
        username: 'wildcat_buyer',
        email: 'buyer@cit.edu',
        createdAt: DateTime.now(),
      );
    });

    List<Override> buildOverrides(List<Product> catalog) => [
          authStateProvider.overrideWith((ref) => AsyncValue.data(mockUser)),
          productsListProvider.overrideWith((ref) => Future.value(catalog)),
          sellerRatingSummaryProvider('seller-store-1')
              .overrideWith((ref) => (average: 4.5, total: 12)),
        ];

    testWidgets('renders header and lazily-built product grid without layout errors',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final storeProduct = Product(
        id: 'prod-store-1',
        title: 'Storefront Test Product',
        description: 'Product used to verify the seller storefront grid.',
        price: 125.50,
        category: 'Books',
        condition: 'Good',
        sellerId: 'seller-store-1',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides([storeProduct]),
          child: const MaterialApp(
            home: SellerStorefrontView(
              sellerId: 'seller-store-1',
              sellerName: 'Wildcat Store',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Wildcat Store'), findsWidgets);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Storefront Test Product'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders storefront empty-state copy when the store has no listings',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(const []),
          child: const MaterialApp(
            home: SellerStorefrontView(
              sellerId: 'seller-store-1',
              sellerName: 'Wildcat Store',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('No products found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
