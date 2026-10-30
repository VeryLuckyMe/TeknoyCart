// Order cancellation UI regression tests.
//
// Sellers no longer get a Cancel Order action for in-flight orders; buyers keep
// their own cancellation path. These tests render the real [OrderDetailView]
// with the same Supabase test bootstrap used by the GCash quality suite.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/checkout/views/order_detail_view.dart';
import 'mock_http_client.dart';

const String _buyerId = 'buyer-cancel-001';
const String _sellerId = 'seller-cancel-001';

/// Shared mock so tests can assert which endpoints a code path actually hit.
final MockHttpOverrides _http = MockHttpOverrides();

Profile _profile({required String id, required String role}) => Profile(
      id: id,
      username: role == 'SELLER' ? 'Verified Seller' : 'Test Buyer',
      email: role == 'SELLER' ? 'seller@cit.edu' : 'buyer@cit.edu',
      role: role,
      isSellerVerified: role == 'SELLER',
      createdAt: DateTime(2025, 1, 1),
    );

Map<String, dynamic> _order({
  required String status,
  required String paymentMethod,
  String totalAmount = '250.00',
}) =>
    {
      'order_id': 'ord-cancel-test-$status-$paymentMethod',
      'status': status,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'buyer_id': _buyerId,
      'seller_id': _sellerId,
      'buyer_name': 'Test Buyer',
      'seller_name': 'Verified Seller',
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
      'pickup_location': 'Library Lobby',
      'pickup_day': 'Today',
      'pickup_time': '12:00 PM - 01:30 PM',
    };

Widget _view(Map<String, dynamic> order, {required bool isSeller}) => ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => AsyncValue.data(
            _profile(id: isSeller ? _sellerId : _buyerId, role: isSeller ? 'SELLER' : 'BUYER'),
          ),
        ),
      ],
      child: MaterialApp(home: OrderDetailView(order: order, isSeller: isSeller)),
    );

void main() {
  setUpAll(() async {
    HttpOverrides.global = _http;
    TestWidgetsFlutterBinding.ensureInitialized();
    const MethodChannel('plugins.flutter.io/shared_preferences')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getAll') return <String, dynamic>{};
      return null;
    });
    // Bearer-token lookup must not depend on a real secure-storage plugin.
    // Without this handler the read never resolves and an acting spinner
    // animates forever, which makes pumpAndSettle time out.
    final storage = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        final key = methodCall.arguments?['key'] as String?;
        if (methodCall.method == 'read') return storage[key];
        if (methodCall.method == 'write') {
          storage[key!] = methodCall.arguments['value'] as String;
          return null;
        }
        if (methodCall.method == 'delete') {
          storage.remove(key);
          return null;
        }
        if (methodCall.method == 'deleteAll') {
          storage.clear();
          return null;
        }
        return null;
      },
    );
    await SupabaseConfig.initialize();
  });

  group('Seller cancellation actions', () {
    testWidgets('ACCEPTED cash order exposes schedule and hides Cancel Order for seller', (tester) async {
      await tester.pumpWidget(_view(_order(status: 'ACCEPTED', paymentMethod: 'CASH_ON_PICKUP'), isSeller: true));
      await tester.pumpAndSettle();

      expect(find.text('Schedule Meetup & Notify Buyer'), findsOneWidget);
      expect(find.text('Cancel Order'), findsNothing);
    });

    testWidgets('ACCEPTED GCash order (buyer has not paid) hides Cancel Order for seller', (tester) async {
      await tester.pumpWidget(_view(_order(status: 'ACCEPTED', paymentMethod: 'GCASH'), isSeller: true));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Order'), findsNothing);
    });

    testWidgets('ESCROWED order hides seller cancellation, including refund requests', (tester) async {
      await tester.pumpWidget(_view(_order(status: 'ESCROWED', paymentMethod: 'GCASH'), isSeller: true));
      await tester.pumpAndSettle();

      expect(find.text('Cancel & Request Refund'), findsNothing);
      expect(find.text('Cancel Order'), findsNothing);
    });

    testWidgets('PAYMENT_SUBMITTED order hides seller cancellation', (tester) async {
      await tester.pumpWidget(_view(_order(status: 'PAYMENT_SUBMITTED', paymentMethod: 'GCASH'), isSeller: true));
      await tester.pumpAndSettle();

      expect(find.text('Cancel & Request Refund'), findsNothing);
      expect(find.text('Cancel Order'), findsNothing);
    });

    testWidgets('MEETUP_SCHEDULED cash order hides seller cancellation', (tester) async {
      await tester.pumpWidget(_view(_order(status: 'MEETUP_SCHEDULED', paymentMethod: 'CASH_ON_PICKUP'), isSeller: true));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Order'), findsNothing);
      expect(find.text('Cancel & Request Refund'), findsNothing);
    });

    testWidgets('MEETUP_SCHEDULED GCash order hides cancellation (payment attached)', (tester) async {
      await tester.pumpWidget(_view(_order(status: 'MEETUP_SCHEDULED', paymentMethod: 'GCASH'), isSeller: true));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Order'), findsNothing);
      expect(find.text('Cancel & Request Refund'), findsNothing);
    });

    testWidgets('COMPLETED order hides seller cancellation', (tester) async {
      await tester.pumpWidget(_view(_order(status: 'COMPLETED', paymentMethod: 'CASH_ON_PICKUP'), isSeller: true));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Order'), findsNothing);
      expect(find.text('Cancel & Request Refund'), findsNothing);
    });

    testWidgets('Buyer keeps only their own cancel action, never the seller refund action',
        (tester) async {
      await tester.pumpWidget(_view(_order(status: 'ACCEPTED', paymentMethod: 'GCASH'), isSeller: false));
      await tester.pumpAndSettle();

      // Buyers may cancel before payment, but the seller-only refund action
      // (keyed) must never be rendered for them.
      expect(find.byKey(const Key('seller_cancel_action')), findsNothing);
      expect(find.text('Cancel & Request Refund'), findsNothing);
      expect(find.text('Cancel Order'), findsOneWidget);
    });

    testWidgets('Tapping Cancel Order opens the confirmation dialog', (tester) async {
      await tester.pumpWidget(_view(_order(status: 'NEEDS_REVIEW', paymentMethod: 'CASH_ON_PICKUP'), isSeller: true));
      await tester.pumpAndSettle();

      final cancelBtn = find.byKey(const Key('seller_cancel_action'));
      await tester.ensureVisible(cancelBtn);
      await tester.pumpAndSettle();
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      expect(find.text('Cancel Order?'), findsOneWidget);
      expect(find.text('Yes, Cancel Order'), findsOneWidget);
    });
  });

  group('Buyer cancellation routing', () {
    testWidgets('Buyer cancel skips the seller-only RPC and calls the backend',
        (tester) async {
      await tester.pumpWidget(
          _view(_order(status: 'ACCEPTED', paymentMethod: 'CASH_ON_PICKUP'), isSeller: false));
      await tester.pumpAndSettle();

      _http.requestedPaths.clear();

      await tester.ensureVisible(find.text('Cancel Order'));
      await tester.tap(find.text('Cancel Order'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes, Cancel Order'));
      await tester.pumpAndSettle();

      // The RPC answers "Only the seller can cancel this order" for buyers, so
      // attempting it first surfaced an error before the backend was reached.
      expect(
        _http.requestedPaths.where((p) => p.contains('cancel_order_as_seller')),
        isEmpty,
        reason: 'A buyer must never call the seller-scoped cancellation RPC.',
      );
      expect(
        _http.requestedPaths.where((p) => p.endsWith('/cancel')),
        isNotEmpty,
        reason: 'Buyer cancellation must reach POST /orders/{id}/cancel.',
      );
    });
  });
}
