import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/checkout/views/order_detail_view.dart';
import 'mock_http_client.dart';

void main() {
  setUpAll(() async {
    HttpOverrides.global = MockHttpOverrides();
    TestWidgetsFlutterBinding.ensureInitialized();
    const MethodChannel('plugins.flutter.io/shared_preferences')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getAll') return <String, dynamic>{};
      return null;
    });
    await SupabaseConfig.initialize();
  });

  Profile makeSellerProfile({String id = 'seller-123'}) => Profile(
        id: id,
        username: 'Test Seller',
        email: 'seller@cit.edu',
        role: 'SELLER',
        isSellerVerified: true,
        createdAt: DateTime(2025, 1, 1),
      );

  Profile makeBuyerProfile({String id = 'buyer-456'}) => Profile(
        id: id,
        username: 'Clark Kent',
        email: 'buyer@cit.edu',
        role: 'BUYER',
        isSellerVerified: false,
        createdAt: DateTime(2025, 1, 1),
      );

  Map<String, dynamic> makeOrder({
    required String orderId,
    required String paymentMethod,
    required String status,
    String sellerId = 'seller-123',
    String buyerId = 'buyer-456',
  }) {
    return {
      'order_id': orderId,
      'status': status,
      'payment_method': paymentMethod,
      'seller_id': sellerId,
      'buyer_id': buyerId,
      'buyer_name': 'Clark Kent',
      'seller_name': 'Test Seller',
      'total_amount': '150.00',
      'pickup_location': 'Library Lobby',
      'pickup_day': 'Today',
      'pickup_time': '12:00 PM - 01:30 PM',
      'created_at': DateTime.now().toIso8601String(),
      'version': 0,
    };
  }

  Widget createWidget({
    required Map<String, dynamic> order,
    required Profile user,
    required bool isSeller,
    required WidgetTester tester,
  }) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    return ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => AsyncValue.data(user)),
      ],
      child: MaterialApp(
        home: OrderDetailView(
          order: order,
          isSeller: isSeller,
        ),
      ),
    );
  }

  group('Accept Order Logic Tests (Cash on Pickup & GCash)', () {
    testWidgets('Seller viewing PLACED order with Cash on Pickup sees Accept Order button', (tester) async {
      final order = makeOrder(
        orderId: '3BD65441-0000-0000-0000-000000000001',
        paymentMethod: 'CASH_ON_PICKUP',
        status: 'PLACED',
      );
      final seller = makeSellerProfile();

      await tester.pumpWidget(createWidget(
        order: order,
        user: seller,
        isSeller: true,
        tester: tester,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Accept Order'), findsOneWidget);
      expect(find.text('Decline Order'), findsOneWidget);
      expect(find.text('Cash on Pickup'), findsOneWidget);
    });

    testWidgets('Seller viewing PLACED order with GCash sees Accept Order button', (tester) async {
      final order = makeOrder(
        orderId: 'D77BAF94-0000-0000-0000-000000000002',
        paymentMethod: 'GCASH',
        status: 'PLACED',
      );
      final seller = makeSellerProfile();

      await tester.pumpWidget(createWidget(
        order: order,
        user: seller,
        isSeller: true,
        tester: tester,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Accept Order'), findsOneWidget);
      expect(find.text('Decline Order'), findsOneWidget);
      expect(find.text('GCash'), findsOneWidget);
    });

    testWidgets('Buyer viewing PLACED order does NOT see Accept Order or Decline Order buttons', (tester) async {
      final order = makeOrder(
        orderId: 'D77BAF94-0000-0000-0000-000000000003',
        paymentMethod: 'GCASH',
        status: 'PLACED',
      );
      final buyer = makeBuyerProfile();

      await tester.pumpWidget(createWidget(
        order: order,
        user: buyer,
        isSeller: false,
        tester: tester,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Accept Order'), findsNothing);
      expect(find.text('Decline Order'), findsNothing);
    });

    testWidgets('Tapping Accept Order for Cash on Pickup triggers accept flow gracefully', (tester) async {
      final order = makeOrder(
        orderId: '3BD65441-0000-0000-0000-000000000004',
        paymentMethod: 'CASH_ON_PICKUP',
        status: 'PLACED',
      );
      final seller = makeSellerProfile();

      await tester.pumpWidget(createWidget(
        order: order,
        user: seller,
        isSeller: true,
        tester: tester,
      ));
      await tester.pumpAndSettle();

      final acceptBtn = find.text('Accept Order');
      expect(acceptBtn, findsOneWidget);

      await tester.tap(acceptBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // No unhandled exceptions thrown; view remains mounted
      expect(find.byType(OrderDetailView), findsOneWidget);
    });

    testWidgets('Tapping Accept Order for GCash triggers accept flow gracefully', (tester) async {
      final order = makeOrder(
        orderId: 'D77BAF94-0000-0000-0000-000000000005',
        paymentMethod: 'GCASH',
        status: 'PLACED',
      );
      final seller = makeSellerProfile();

      await tester.pumpWidget(createWidget(
        order: order,
        user: seller,
        isSeller: true,
        tester: tester,
      ));
      await tester.pumpAndSettle();

      final acceptBtn = find.text('Accept Order');
      expect(acceptBtn, findsOneWidget);

      await tester.tap(acceptBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // No unhandled exceptions thrown; view remains mounted
      expect(find.byType(OrderDetailView), findsOneWidget);
    });
  });
}
