import 'package:teknoycart/core/providers/order_badge_provider.dart';

/// Badge service for widget tests: no network, zero badges. markSeen fails so
/// the view does not go on to refresh the (real) notification provider.
class OfflineOrderBadgeApi implements OrderBadgeApi {
  const OfflineOrderBadgeApi();

  @override
  Future<OrderBadgeCounts> fetchCounts() async => const OrderBadgeCounts();

  @override
  Future<void> markSeen(OrderList list) async => throw StateError('offline in tests');
}
