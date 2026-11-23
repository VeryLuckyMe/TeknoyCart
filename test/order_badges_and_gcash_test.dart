import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/core/providers/order_badge_provider.dart';
import 'package:teknoycart/core/providers/seller_gcash_provider.dart';
import 'package:teknoycart/features/checkout/services/checkout_error_mapper.dart';

class _FakeBadgeApi implements OrderBadgeApi {
  OrderBadgeCounts counts;
  final seen = <OrderList>[];
  bool failMarkSeen = false;
  _FakeBadgeApi(this.counts);

  @override
  Future<OrderBadgeCounts> fetchCounts() async => counts;

  @override
  Future<void> markSeen(OrderList list) async {
    if (failMarkSeen) throw Exception('offline');
    seen.add(list);
    counts = counts.cleared(list);
  }
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('OrderBadgeNotifier', () {
    test('loads both counts and totals them for the Orders tab', () async {
      final api = _FakeBadgeApi(const OrderBadgeCounts(incoming: 1, purchases: 2));
      final n = OrderBadgeNotifier(api, 'user-1');
      await _settle();
      expect(n.state, const OrderBadgeCounts(incoming: 1, purchases: 2));
      expect(n.state.total, 3);
    });

    test('opening My Purchases clears only purchases; incoming +1 stays', () async {
      final api = _FakeBadgeApi(const OrderBadgeCounts(incoming: 1, purchases: 1));
      final n = OrderBadgeNotifier(api, 'user-1');
      await _settle();

      expect(await n.markSeen(OrderList.purchases), isTrue);
      expect(n.state, const OrderBadgeCounts(incoming: 1, purchases: 0));
      expect(api.seen, [OrderList.purchases]);

      await n.refresh();
      expect(n.state.incoming, 1, reason: 'Incoming clears only when that list is opened');
    });

    test('opening Incoming Orders clears it', () async {
      final api = _FakeBadgeApi(const OrderBadgeCounts(incoming: 2));
      final n = OrderBadgeNotifier(api, 'user-1');
      await _settle();
      await n.markSeen(OrderList.incoming);
      await n.refresh();
      expect(n.state.total, 0);
    });

    test('reports failure so the bell is not refreshed on a failed call', () async {
      final api = _FakeBadgeApi(const OrderBadgeCounts(incoming: 1))..failMarkSeen = true;
      final n = OrderBadgeNotifier(api, 'user-1');
      await _settle();
      expect(await n.markSeen(OrderList.incoming), isFalse);
    });

    test('signed out: no calls, zero badges', () async {
      final api = _FakeBadgeApi(const OrderBadgeCounts(incoming: 5));
      final n = OrderBadgeNotifier(api, null);
      await _settle();
      expect(n.state.total, 0);
      expect(await n.markSeen(OrderList.incoming), isFalse);
      expect(api.seen, isEmpty);
    });
  });

  group('combineGcashAvailability', () {
    test('available only when every seller has GCash set up', () {
      expect(
        combineGcashAvailability(const [AsyncData(true), AsyncData(true)]),
        GcashAvailability.available,
      );
    });

    test('one seller without GCash blocks it for the whole checkout', () {
      expect(
        combineGcashAvailability(const [AsyncData(true), AsyncData(false)]),
        GcashAvailability.sellerNotSetUp,
      );
    });

    test('still loading shows checking (GCash not selectable yet)', () {
      expect(
        combineGcashAvailability(const [AsyncData(true), AsyncLoading<bool?>()]),
        GcashAvailability.checking,
      );
    });

    test('failed lookup does not block; the server trigger still enforces it', () {
      expect(
        combineGcashAvailability(const [AsyncData<bool?>(null)]),
        GcashAvailability.available,
      );
    });
  });

  test('server GCash rejection shows a plain message', () {
    const err = PostgrestException(message: 'SELLER_GCASH_NOT_SET', code: 'P0001');
    expect(checkoutErrorMessage(err), contains("hasn't set up GCash"));
  });
}
