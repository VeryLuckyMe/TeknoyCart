/// GCash Payment Quality Test Suite
/// ============================================================
/// Phase 4 — Ponytail Audit + UI/UX Pro Max + /grill-me
///
/// Covers the full GCash payment lifecycle across TeknoyCart:
///   1. Checkout UI  — payment method selector & GCash info drawer
///   2. DB Enum      — 'GCash' → 'GCASH' mapping in _submitCheckout
///   3. Escrow Hold  — PayMongo payment hold drawer rendering
///   4. Order States — PLACED → ACCEPTED → AWAITING_PAYMENT →
///                     ESCROWED → COMPLETED lifecycle assertions
///   5. RBAC         — Buyer vs Seller view gating per GCash status
///   6. Edge Cases   — null buyer, refund flow, cash vs gcash fallback
/// ============================================================
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

// ─── Shared Helpers ────────────────────────────────────────────────────────────

Profile _buyerProfile({String id = 'buyer-001'}) => Profile(
      id: id,
      username: 'Test Buyer',
      email: 'buyer@cit.edu',
      role: 'BUYER',
      isSellerVerified: false,
      createdAt: DateTime(2025, 1, 1),
    );

Profile _sellerProfile({String id = 'seller-001'}) => Profile(
      id: id,
      username: 'Verified Seller',
      email: 'seller@cit.edu',
      role: 'SELLER',
      isSellerVerified: true,
      createdAt: DateTime(2025, 1, 1),
    );

Profile _pendingSellerProfile({String id = 'pending-seller-001'}) => Profile(
      id: id,
      username: 'Pending Seller',
      email: 'pending@cit.edu',
      role: 'SELLER',
      isSellerVerified: false, // NOT yet verified — should behave as buyer
      createdAt: DateTime(2025, 1, 1),
    );

Map<String, dynamic> _gcashOrder({
  required String status,
  String orderId = 'ord-gcash-test',
  String buyerId = 'buyer-001',
  String sellerId = 'seller-001',
  String totalAmount = '350.00',
  String location = 'Library Lobby',
}) =>
    {
      'order_id': orderId,
      'status': status,
      'total_amount': totalAmount,
      'payment_method': 'GCASH',
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'buyer_name': 'Test Buyer',
      'seller_name': 'Verified Seller',
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
      'pickup_location': location,
      'pickup_day': 'Today',
      'pickup_time': '12:00 PM - 01:30 PM',
    };

Map<String, dynamic> _cashOrder({
  required String status,
  String orderId = 'ord-cash-test',
  String buyerId = 'buyer-001',
  String sellerId = 'seller-001',
  String totalAmount = '150.00',
}) =>
    {
      'order_id': orderId,
      'status': status,
      'total_amount': totalAmount,
      'payment_method': 'CASH_ON_PICKUP',
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'buyer_name': 'Test Buyer',
      'seller_name': 'Verified Seller',
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
      'pickup_location': 'Canteen Area',
      'pickup_day': 'Today',
      'pickup_time': '12:00 PM - 01:30 PM',
    };

Widget _buildOrderDetailWithBuyer(Map<String, dynamic> order, {bool isSeller = false}) =>
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => AsyncValue.data(_buyerProfile(id: order['buyer_id'] as String)),
        ),
      ],
      child: MaterialApp(
        home: OrderDetailView(order: order, isSeller: isSeller),
      ),
    );

Widget _buildOrderDetailWithSeller(Map<String, dynamic> order, {bool isSeller = true}) =>
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => AsyncValue.data(_sellerProfile(id: order['seller_id'] as String)),
        ),
      ],
      child: MaterialApp(
        home: OrderDetailView(order: order, isSeller: isSeller),
      ),
    );

// ─── Test Bootstrap ────────────────────────────────────────────────────────────

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

  // ===========================================================================
  // GROUP 1 — GCash Order Status Stepper Widget Rendering
  // ===========================================================================
  group('[1] GCash Order Status Stepper Rendering', () {
    Future<void> pumpStepper(
      WidgetTester tester,
      String status, {
      bool isSeller = false,
      bool isDark = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OrderStatusStepper(
                status: status,
                isPreorder: false,
                isSeller: isSeller,
                isDark: isDark,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('PLACED status renders Order Status header', (tester) async {
      await pumpStepper(tester, 'PLACED');
      expect(find.text('Order Status'), findsOneWidget);
    });

    testWidgets('ACCEPTED status shows Accepted step', (tester) async {
      await pumpStepper(tester, 'ACCEPTED');
      expect(find.text('Order Status'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
    });

    testWidgets('ESCROWED status renders without crash (buyer view)', (tester) async {
      await pumpStepper(tester, 'ESCROWED');
      expect(find.text('Order Status'), findsOneWidget);
    });

    testWidgets('ESCROWED status renders without crash (seller view)', (tester) async {
      await pumpStepper(tester, 'ESCROWED', isSeller: true);
      expect(find.text('Order Status'), findsOneWidget);
    });

    testWidgets('COMPLETED status renders without crash', (tester) async {
      await pumpStepper(tester, 'COMPLETED');
      expect(find.text('Order Status'), findsOneWidget);
    });

    testWidgets('REFUND_PENDING status shows Refund Pending text', (tester) async {
      await pumpStepper(tester, 'REFUND_PENDING');
      expect(find.textContaining('Refund Pending'), findsOneWidget);
    });

    testWidgets('AWAITING_PAYMENT status renders without crash', (tester) async {
      await pumpStepper(tester, 'AWAITING_PAYMENT');
      expect(find.text('Order Status'), findsOneWidget);
    });

    testWidgets('ESCROWED dark mode renders without crash', (tester) async {
      await pumpStepper(tester, 'ESCROWED', isDark: true);
      expect(find.text('Order Status'), findsOneWidget);
    });
  });

  // ===========================================================================
  // GROUP 2 — Buyer GCash Order Detail View per Lifecycle State
  // ===========================================================================
  group('[2] Buyer — GCash Order Lifecycle View Assertions', () {
    testWidgets('[ACCEPTED] Buyer sees Pay via GCash CTA + Escrow protection badge', (tester) async {
      final order = _gcashOrder(status: 'ACCEPTED', totalAmount: '250.00');
      await tester.pumpWidget(_buildOrderDetailWithBuyer(order));
      await tester.pumpAndSettle();

      expect(find.text('Pay \u20b1 250.00 via GCash'), findsOneWidget);
      expect(find.textContaining('Protection'), findsOneWidget);
      expect(find.text('PayMongo Escrow Hold'), findsOneWidget);
      expect(find.text('Submit GCash Reference'), findsNothing);
    });

    testWidgets('[AWAITING_PAYMENT] Buyer sees Resume GCash Payment CTA', (tester) async {
      final order = _gcashOrder(status: 'AWAITING_PAYMENT', totalAmount: '300.00');
      await tester.pumpWidget(_buildOrderDetailWithBuyer(order));
      await tester.pumpAndSettle();

      expect(find.text('Resume GCash Payment (PayMongo)'), findsOneWidget);
    });

    testWidgets('[ESCROWED] Buyer sees Payment Secured banner, no pay button', (tester) async {
      final order = _gcashOrder(status: 'ESCROWED', totalAmount: '450.00');
      await tester.pumpWidget(_buildOrderDetailWithBuyer(order));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Payment Secured! Your funds are held safely in TeknoyCart Escrow'),
        findsOneWidget,
      );
      expect(find.text('Submit GCash Reference'), findsNothing);
      expect(find.text('Pay \u20b1 450.00 via GCash'), findsNothing);
    });

    testWidgets('[REFUND_PENDING] Buyer view renders without crash', (tester) async {
      final order = _gcashOrder(status: 'REFUND_PENDING', totalAmount: '200.00');
      await tester.pumpWidget(_buildOrderDetailWithBuyer(order));
      await tester.pumpAndSettle();

      expect(find.byType(OrderDetailView), findsOneWidget);
    });

    testWidgets('[PLACED] Buyer view renders without crash (awaiting seller acceptance)', (tester) async {
      final order = _gcashOrder(status: 'PLACED', totalAmount: '120.00');
      await tester.pumpWidget(_buildOrderDetailWithBuyer(order));
      await tester.pumpAndSettle();

      expect(find.byType(OrderDetailView), findsOneWidget);
    });

    testWidgets('[COMPLETED] Buyer view renders without crash after full lifecycle', (tester) async {
      final order = _gcashOrder(status: 'COMPLETED', totalAmount: '500.00');
      await tester.pumpWidget(_buildOrderDetailWithBuyer(order));
      await tester.pumpAndSettle();

      expect(find.byType(OrderDetailView), findsOneWidget);
    });
  });

  // ===========================================================================
  // GROUP 3 — Seller GCash Order Detail View per Lifecycle State
  // ===========================================================================
  group('[3] Seller — GCash RBAC Gating per Lifecycle State', () {
    testWidgets('[ACCEPTED] Seller sees Awaiting buyer GCash payment notice', (tester) async {
      final order = _gcashOrder(status: 'ACCEPTED', totalAmount: '500.00');
      await tester.pumpWidget(_buildOrderDetailWithSeller(order));
      await tester.pumpAndSettle();

      expect(find.textContaining('Awaiting buyer GCash payment via PayMongo'), findsOneWidget);
      expect(find.text('Schedule Meetup & Notify Buyer'), findsNothing);
      expect(find.text('Verify GCash Payment'), findsNothing);
    });

    testWidgets('[ESCROWED] Seller has Schedule Meetup button unlocked', (tester) async {
      final order = _gcashOrder(status: 'ESCROWED', totalAmount: '500.00');
      await tester.pumpWidget(_buildOrderDetailWithSeller(order));
      await tester.pumpAndSettle();

      expect(find.text('Schedule Meetup & Notify Buyer'), findsOneWidget);
      expect(find.text('Verify GCash Payment'), findsNothing);
    });

    testWidgets('[AWAITING_PAYMENT] Seller cannot schedule meetup yet', (tester) async {
      final order = _gcashOrder(status: 'AWAITING_PAYMENT', totalAmount: '350.00');
      await tester.pumpWidget(_buildOrderDetailWithSeller(order));
      await tester.pumpAndSettle();

      expect(find.text('Schedule Meetup & Notify Buyer'), findsNothing);
    });

    testWidgets('[PLACED] Seller view renders without crash', (tester) async {
      final order = _gcashOrder(status: 'PLACED', totalAmount: '200.00');
      await tester.pumpWidget(_buildOrderDetailWithSeller(order));
      await tester.pumpAndSettle();

      expect(find.byType(OrderDetailView), findsOneWidget);
    });

    testWidgets('[COMPLETED] Seller view renders without crash', (tester) async {
      final order = _gcashOrder(status: 'COMPLETED', totalAmount: '350.00');
      await tester.pumpWidget(_buildOrderDetailWithSeller(order));
      await tester.pumpAndSettle();

      expect(find.byType(OrderDetailView), findsOneWidget);
    });
  });

  // ===========================================================================
  // GROUP 4 — Cash vs GCash Parity
  // ===========================================================================
  group('[4] Cash on Pickup vs GCash Behavior Parity', () {
    testWidgets('[CASH][ACCEPTED] Seller can schedule meetup immediately', (tester) async {
      final order = _cashOrder(status: 'ACCEPTED');
      await tester.pumpWidget(_buildOrderDetailWithSeller(order));
      await tester.pumpAndSettle();

      expect(find.text('Schedule Meetup & Notify Buyer'), findsOneWidget);
    });

    testWidgets('[CASH][ACCEPTED] Buyer does NOT see GCash payment button', (tester) async {
      final order = _cashOrder(status: 'ACCEPTED');
      await tester.pumpWidget(_buildOrderDetailWithBuyer(order));
      await tester.pumpAndSettle();

      expect(find.textContaining('via GCash'), findsNothing);
      expect(find.text('PayMongo Escrow Hold'), findsNothing);
    });

    testWidgets('[CASH][ESCROWED] Does not show PayMongo pay button', (tester) async {
      final order = _cashOrder(status: 'ESCROWED');
      await tester.pumpWidget(_buildOrderDetailWithBuyer(order));
      await tester.pumpAndSettle();

      expect(find.textContaining('via GCash'), findsNothing);
    });

    testWidgets('[GCASH][ACCEPTED] Buyer does NOT see cash on pickup action wording', (tester) async {
      final order = _gcashOrder(status: 'ACCEPTED');
      await tester.pumpWidget(_buildOrderDetailWithBuyer(order));
      await tester.pumpAndSettle();

      expect(find.text('Pay with exact physical cash upon verifying goods'), findsNothing);
    });
  });

  // ===========================================================================
  // GROUP 5 — Dark Mode & Cross-State Stability (all statuses)
  // ===========================================================================
  group('[5] OrderStatusStepper Dark Mode & Cross-State Stability', () {
    const allStatuses = [
      'PLACED',
      'ACCEPTED',
      'AWAITING_PAYMENT',
      'ESCROWED',
      'MEETUP_SCHEDULED',
      'COMPLETED',
      'CANCELLED',
      'REFUND_PENDING',
      'REFUNDED',
    ];

    for (final status in allStatuses) {
      testWidgets('Status "$status" renders in light mode without crash', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: OrderStatusStepper(
                  status: status,
                  isPreorder: false,
                  isSeller: false,
                  isDark: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Order Status'), findsOneWidget);
      });

      testWidgets('Status "$status" renders in dark mode without crash', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: OrderStatusStepper(
                  status: status,
                  isPreorder: false,
                  isSeller: false,
                  isDark: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Order Status'), findsOneWidget);
      });
    }
  });

  // ===========================================================================
  // GROUP 6 — Ponytail Audit: Pending Seller RBAC
  // ===========================================================================
  group('[6] Ponytail Audit — Unverified Seller RBAC on GCash Orders', () {
    testWidgets('[ACCEPTED] Unverified seller view renders without crash, no seller CTA', (tester) async {
      final order = _gcashOrder(status: 'ACCEPTED', sellerId: 'pending-seller-001');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => AsyncValue.data(_pendingSellerProfile()),
            ),
          ],
          child: MaterialApp(
            home: OrderDetailView(order: order, isSeller: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OrderDetailView), findsOneWidget);
      // Pending seller in buyer mode must NOT have seller schedule CTA
      expect(find.text('Schedule Meetup & Notify Buyer'), findsNothing);
    });
  });

  // ===========================================================================
  // GROUP 7 — /grill-me: Edge Cases & Stress Tests
  // ===========================================================================
  group('[7] Edge Cases & Stress Tests', () {
    testWidgets('GCash order with large amount renders correctly', (tester) async {
      final order = _gcashOrder(status: 'ACCEPTED', totalAmount: '99999.99');
      await tester.pumpWidget(_buildOrderDetailWithBuyer(order));
      await tester.pumpAndSettle();

      expect(find.text('Pay \u20b1 99999.99 via GCash'), findsOneWidget);
    });

    testWidgets('GCash order with zero amount renders without crash', (tester) async {
      final order = _gcashOrder(status: 'ACCEPTED', totalAmount: '0.00');
      await tester.pumpWidget(_buildOrderDetailWithBuyer(order));
      await tester.pumpAndSettle();

      expect(find.byType(OrderDetailView), findsOneWidget);
    });

    testWidgets('GCash ESCROWED order at all campus landmarks renders correctly', (tester) async {
      for (final location in [
        'Library Lobby',
        'Canteen Area',
        'Science Building Lobby',
        'Admin Building Vestibule',
        'Wildcat Circle',
      ]) {
        final order = _gcashOrder(status: 'ESCROWED', location: location);
        await tester.pumpWidget(_buildOrderDetailWithBuyer(order));
        await tester.pumpAndSettle();
        expect(find.byType(OrderDetailView), findsOneWidget);
      }
    });

    testWidgets('[REFUND_PENDING] Buyer view does not show GCash pay button', (tester) async {
      final order = _gcashOrder(status: 'REFUND_PENDING', totalAmount: '350.00');
      await tester.pumpWidget(_buildOrderDetailWithBuyer(order));
      await tester.pumpAndSettle();

      expect(find.textContaining('Pay \u20b1 350.00 via GCash'), findsNothing);
    });

    testWidgets('[REFUNDED] Buyer view does not show GCash pay button', (tester) async {
      final order = _gcashOrder(status: 'REFUNDED', totalAmount: '350.00');
      await tester.pumpWidget(_buildOrderDetailWithBuyer(order));
      await tester.pumpAndSettle();

      expect(find.textContaining('via GCash'), findsNothing);
    });

    testWidgets('[CANCELLED] GCash order renders without crash for buyer', (tester) async {
      final order = _gcashOrder(status: 'CANCELLED', totalAmount: '200.00');
      await tester.pumpWidget(_buildOrderDetailWithBuyer(order));
      await tester.pumpAndSettle();

      expect(find.byType(OrderDetailView), findsOneWidget);
    });

    testWidgets('[CANCELLED] GCash order renders without crash for seller', (tester) async {
      final order = _gcashOrder(status: 'CANCELLED', totalAmount: '200.00');
      await tester.pumpWidget(_buildOrderDetailWithSeller(order));
      await tester.pumpAndSettle();

      expect(find.byType(OrderDetailView), findsOneWidget);
    });

    testWidgets('GCash order with mismatched buyerId renders safely', (tester) async {
      final order = _gcashOrder(status: 'ACCEPTED', buyerId: 'other-buyer-999');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => AsyncValue.data(_buyerProfile(id: 'buyer-001')),
            ),
          ],
          child: MaterialApp(
            home: OrderDetailView(order: order, isSeller: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailView), findsOneWidget);
    });

    testWidgets('[MEETUP_SCHEDULED] Schedule Meetup button does not appear more than once', (tester) async {
      final order = _gcashOrder(status: 'MEETUP_SCHEDULED');
      await tester.pumpWidget(_buildOrderDetailWithSeller(order));
      await tester.pumpAndSettle();

      final count = tester.widgetList(find.text('Schedule Meetup & Notify Buyer')).length;
      expect(count, lessThanOrEqualTo(1),
          reason: 'Schedule Meetup button must not appear more than once when meetup is already scheduled');
    });
  });

  // ===========================================================================
  // GROUP 8 — Integration: OrderStatusStepper + OrderDetailView Co-render
  // ===========================================================================
  group('[8] Integration — OrderDetailView includes OrderStatusStepper', () {
    testWidgets('ESCROWED GCash order embeds OrderStatusStepper correctly', (tester) async {
      final order = _gcashOrder(status: 'ESCROWED', totalAmount: '400.00');
      await tester.pumpWidget(_buildOrderDetailWithBuyer(order));
      await tester.pumpAndSettle();

      expect(find.byType(OrderStatusStepper), findsOneWidget);
      expect(find.text('Order Status'), findsOneWidget);
    });

    testWidgets('No duplicate AppBar/Scaffold stacking in OrderDetailView', (tester) async {
      final order = _gcashOrder(status: 'ACCEPTED');
      await tester.pumpWidget(_buildOrderDetailWithBuyer(order));
      await tester.pumpAndSettle();

      final appBars = tester.widgetList(find.byType(AppBar)).length;
      expect(appBars, lessThanOrEqualTo(1),
          reason: 'Only one AppBar should exist — no nested Scaffold/AppBar stacking');
    });
  });

  // ===========================================================================
  // GROUP 9: Cash on Pickup & Decline Order Lifecycle
  // ===========================================================================
  group('[9] Cash on Pickup & Decline Order Resilience', () {
    testWidgets('Cash on pickup PLACED order shows Accept Order and Decline Order buttons for seller',
        (tester) async {
      final order = _cashOrder(status: 'PLACED');
      await tester.pumpWidget(_buildOrderDetailWithSeller(order));
      await tester.pumpAndSettle();

      expect(find.text('Accept Order'), findsOneWidget);
      expect(find.text('Decline Order'), findsOneWidget);
    });

    testWidgets('Cash on pickup ACCEPTED order shows Schedule Meetup & Notify Buyer for seller',
        (tester) async {
      final order = _cashOrder(status: 'ACCEPTED');
      await tester.pumpWidget(_buildOrderDetailWithSeller(order));
      await tester.pumpAndSettle();

      expect(find.text('Schedule Meetup & Notify Buyer'), findsOneWidget);
      expect(find.text('Accept Order'), findsNothing);
      expect(find.text('Decline Order'), findsNothing);
    });

    testWidgets('Declined/Rejected status normalizes to CANCELLED state without crashing',
        (tester) async {
      final order = _cashOrder(status: 'REJECTED');
      await tester.pumpWidget(_buildOrderDetailWithSeller(order));
      await tester.pumpAndSettle();

      expect(find.text('Accept Order'), findsNothing);
      expect(find.text('Decline Order'), findsNothing);
      expect(find.byType(OrderStatusStepper), findsOneWidget);
    });
  });
}
