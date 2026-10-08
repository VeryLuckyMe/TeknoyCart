import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/checkout/views/order_detail_view.dart';
import 'package:teknoycart/features/checkout/views/widgets/order_status_stepper.dart';
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

  group('PayMongo GCash Payment Hold Widget & Flow Tests', () {
    testWidgets('OrderStatusStepper renders correctly for ESCROWED and REFUND_PENDING', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrderStatusStepper(
              status: 'ESCROWED',
              isPreorder: false,
              isSeller: false,
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Order Status'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);

      // Now test REFUND_PENDING banner
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrderStatusStepper(
              status: 'REFUND_PENDING',
              isPreorder: false,
              isSeller: false,
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Refund Pending'), findsOneWidget);
    });

    testWidgets('Buyer on ACCEPTED GCash order sees Pay via GCash CTA and Escrow protection', (WidgetTester tester) async {
      final buyerUser = Profile(
        id: 'buyer-123',
        username: 'Test Buyer',
        email: 'buyer@cit.edu',
        role: 'BUYER',
        isSellerVerified: false,
        createdAt: DateTime.now(),
      );

      final orderData = {
        'order_id': 'ord-test-111',
        'status': 'ACCEPTED',
        'total_amount': '250.00',
        'payment_method': 'GCASH',
        'buyer_id': 'buyer-123',
        'seller_id': 'seller-456',
        'buyer_name': 'Test Buyer',
        'seller_name': 'Test Seller',
        'created_at': DateTime.now().toIso8601String(),
        'pickup_location': 'Library Lobby',
        'pickup_day': 'Today',
        'pickup_time': '12:00 PM - 01:30 PM',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(buyerUser)),
          ],
          child: MaterialApp(
            home: OrderDetailView(order: orderData, isSeller: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Buyer sees Pay ₱ 250.00 via GCash button
      expect(find.text('Pay ₱ 250.00 via GCash'), findsOneWidget);
      // Buyer sees escrow protection badge
      expect(find.textContaining('Protection'), findsOneWidget);
      expect(find.text('PayMongo Escrow Hold'), findsOneWidget);
      // No manual GCash reference submission button
      expect(find.text('Submit GCash Reference'), findsNothing);
    });

    testWidgets('Buyer on AWAITING_PAYMENT GCash order sees Resume GCash Payment', (WidgetTester tester) async {
      final buyerUser = Profile(
        id: 'buyer-123',
        username: 'Test Buyer',
        email: 'buyer@cit.edu',
        role: 'BUYER',
        isSellerVerified: false,
        createdAt: DateTime.now(),
      );

      final orderData = {
        'order_id': 'ord-test-222',
        'status': 'AWAITING_PAYMENT',
        'total_amount': '300.00',
        'payment_method': 'GCASH',
        'buyer_id': 'buyer-123',
        'seller_id': 'seller-456',
        'buyer_name': 'Test Buyer',
        'seller_name': 'Test Seller',
        'created_at': DateTime.now().toIso8601String(),
        'pickup_location': 'Library Lobby',
        'pickup_day': 'Today',
        'pickup_time': '12:00 PM - 01:30 PM',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(buyerUser)),
          ],
          child: MaterialApp(
            home: OrderDetailView(order: orderData, isSeller: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resume GCash Payment (PayMongo)'), findsOneWidget);
    });

    testWidgets('Buyer on ESCROWED GCash order sees Payment Secured banner and no submit button', (WidgetTester tester) async {
      final buyerUser = Profile(
        id: 'buyer-123',
        username: 'Test Buyer',
        email: 'buyer@cit.edu',
        role: 'BUYER',
        isSellerVerified: false,
        createdAt: DateTime.now(),
      );

      final orderData = {
        'order_id': 'ord-test-333',
        'status': 'ESCROWED',
        'total_amount': '450.00',
        'payment_method': 'GCASH',
        'buyer_id': 'buyer-123',
        'seller_id': 'seller-456',
        'buyer_name': 'Test Buyer',
        'seller_name': 'Test Seller',
        'created_at': DateTime.now().toIso8601String(),
        'pickup_location': 'Library Lobby',
        'pickup_day': 'Today',
        'pickup_time': '12:00 PM - 01:30 PM',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(buyerUser)),
          ],
          child: MaterialApp(
            home: OrderDetailView(order: orderData, isSeller: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Payment Secured! Your funds are held safely in TeknoyCart Escrow'), findsOneWidget);
      expect(find.text('Submit GCash Reference'), findsNothing);
    });

    testWidgets('Seller on ACCEPTED GCash order is gated until buyer completes escrow payment', (WidgetTester tester) async {
      final sellerUser = Profile(
        id: 'seller-456',
        username: 'Verified Seller',
        email: 'seller@cit.edu',
        role: 'SELLER',
        isSellerVerified: true,
        createdAt: DateTime.now(),
      );

      final orderData = {
        'order_id': 'ord-test-444',
        'status': 'ACCEPTED',
        'total_amount': '500.00',
        'payment_method': 'GCASH',
        'buyer_id': 'buyer-123',
        'seller_id': 'seller-456',
        'buyer_name': 'Test Buyer',
        'seller_name': 'Test Seller',
        'created_at': DateTime.now().toIso8601String(),
        'pickup_location': 'Library Lobby',
        'pickup_day': 'Today',
        'pickup_time': '12:00 PM - 01:30 PM',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(sellerUser)),
          ],
          child: MaterialApp(
            home: OrderDetailView(order: orderData, isSeller: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Seller sees notice awaiting buyer payment, NOT schedule meetup button yet
      expect(find.textContaining('Awaiting buyer GCash payment via PayMongo'), findsOneWidget);
      expect(find.text('Schedule Meetup & Notify Buyer'), findsNothing);
      expect(find.text('Verify GCash Payment'), findsNothing);
    });

    testWidgets('Seller on ESCROWED GCash order has Schedule Meetup unlocked', (WidgetTester tester) async {
      final sellerUser = Profile(
        id: 'seller-456',
        username: 'Verified Seller',
        email: 'seller@cit.edu',
        role: 'SELLER',
        isSellerVerified: true,
        createdAt: DateTime.now(),
      );

      final orderData = {
        'order_id': 'ord-test-555',
        'status': 'ESCROWED',
        'total_amount': '500.00',
        'payment_method': 'GCASH',
        'buyer_id': 'buyer-123',
        'seller_id': 'seller-456',
        'buyer_name': 'Test Buyer',
        'seller_name': 'Test Seller',
        'created_at': DateTime.now().toIso8601String(),
        'pickup_location': 'Library Lobby',
        'pickup_day': 'Today',
        'pickup_time': '12:00 PM - 01:30 PM',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(sellerUser)),
          ],
          child: MaterialApp(
            home: OrderDetailView(order: orderData, isSeller: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Because payment is locked in escrow, seller can now schedule meetup
      expect(find.text('Schedule Meetup & Notify Buyer'), findsOneWidget);
      // No manual verification button
      expect(find.text('Verify GCash Payment'), findsNothing);
    });

    testWidgets('Cash on Pickup order allows scheduling immediately upon ACCEPTED', (WidgetTester tester) async {
      final sellerUser = Profile(
        id: 'seller-456',
        username: 'Verified Seller',
        email: 'seller@cit.edu',
        role: 'SELLER',
        isSellerVerified: true,
        createdAt: DateTime.now(),
      );

      final orderData = {
        'order_id': 'ord-test-666',
        'status': 'ACCEPTED',
        'total_amount': '150.00',
        'payment_method': 'CASH_ON_PICKUP',
        'buyer_id': 'buyer-123',
        'seller_id': 'seller-456',
        'buyer_name': 'Test Buyer',
        'seller_name': 'Test Seller',
        'created_at': DateTime.now().toIso8601String(),
        'pickup_location': 'Canteen Area',
        'pickup_day': 'Today',
        'pickup_time': '12:00 PM - 01:30 PM',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(sellerUser)),
          ],
          child: MaterialApp(
            home: OrderDetailView(order: orderData, isSeller: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cash on pickup needs no online escrow; seller can schedule meetup right away
      expect(find.text('Schedule Meetup & Notify Buyer'), findsOneWidget);
    });
  });
}
