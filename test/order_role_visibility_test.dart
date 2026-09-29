import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/checkout/views/order_history_view.dart';
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

  group('Role-Based Order Visibility Audit & Regression Tests', () {
    testWidgets('Registered BUYER only sees My Purchases and NOT Incoming Orders', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Pure student buyer
      final buyerUser = Profile(
        id: 'usr-buyer-only',
        username: 'Student Buyer',
        email: 'buyer@cit.edu',
        role: 'BUYER',
        isSellerVerified: false,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(buyerUser)),
          ],
          child: const MaterialApp(
            home: OrderHistoryView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified: 'My Purchases' is visible
      expect(find.text('My Purchases'), findsOneWidget);

      // Verified: 'Incoming Orders' is HIDDEN for pure buyers
      expect(find.text('Incoming Orders'), findsNothing);
      expect(find.text('Orders Hub'), findsNothing);
    });

    testWidgets('Pending UNVERIFIED SELLER (Clark Kent scenario) only sees My Purchases and NOT Incoming Orders', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Pending seller application: role is SELLER but isSellerVerified is false
      final pendingSellerUser = Profile(
        id: 'usr-clark-kent',
        username: 'Clark Kent',
        email: 'clark.kent@cit.edu',
        role: 'SELLER',
        isSellerVerified: false,
        createdAt: DateTime.now(),
      );

      // Standalone View
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(pendingSellerUser)),
          ],
          child: const MaterialApp(
            home: OrderHistoryView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pending seller has not been approved by admin, so they cannot sell or receive orders
      expect(find.text('My Purchases'), findsOneWidget);
      expect(find.text('Incoming Orders'), findsNothing);
      expect(find.text('Orders Hub'), findsNothing);
    });

    testWidgets('Embedded mode for buyer/pending seller suppresses duplicate AppBar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final pendingSellerUser = Profile(
        id: 'usr-clark-kent',
        username: 'Clark Kent',
        email: 'clark.kent@cit.edu',
        role: 'SELLER',
        isSellerVerified: false,
        createdAt: DateTime.now(),
      );

      // Embedded inside ProductDiscoveryFeedView
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(pendingSellerUser)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(56),
                child: Text('Parent AppBar'),
              ),
              body: OrderHistoryView(embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In embedded mode, OrderHistoryView does not render an inner Scaffold/AppBar
      expect(find.text('Incoming Orders'), findsNothing);
      expect(find.text('Orders Hub'), findsNothing);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('Fully VERIFIED SELLER sees unified Orders Hub with both My Purchases and Incoming Orders', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Verified campus vendor/seller
      final verifiedSellerUser = Profile(
        id: 'usr-seller-vendor',
        username: 'Campus Merchant',
        email: 'merchant@cit.edu',
        role: 'SELLER',
        isSellerVerified: true,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(verifiedSellerUser)),
          ],
          child: const MaterialApp(
            home: OrderHistoryView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified: 'Orders Hub' title is visible
      expect(find.text('Orders Hub'), findsOneWidget);

      // Verified: Both tabs exist for verified seller
      expect(find.text('My Purchases'), findsOneWidget);
      expect(find.text('Incoming Orders'), findsOneWidget);
    });
  });
}
