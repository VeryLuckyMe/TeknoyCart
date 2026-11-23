import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';

/// Which order list a badge belongs to. Values match migration V21.
enum OrderList {
  incoming('INCOMING'),
  purchases('PURCHASES');

  const OrderList(this.dbValue);
  final String dbValue;
}

@immutable
class OrderBadgeCounts {
  final int incoming;
  final int purchases;
  const OrderBadgeCounts({this.incoming = 0, this.purchases = 0});

  int get total => incoming + purchases;

  OrderBadgeCounts cleared(OrderList list) => list == OrderList.incoming
      ? OrderBadgeCounts(incoming: 0, purchases: purchases)
      : OrderBadgeCounts(incoming: incoming, purchases: 0);

  @override
  bool operator ==(Object other) =>
      other is OrderBadgeCounts &&
      other.incoming == incoming &&
      other.purchases == purchases;

  @override
  int get hashCode => Object.hash(incoming, purchases);
}

/// Server calls behind the badges, swappable in tests.
abstract class OrderBadgeApi {
  Future<OrderBadgeCounts> fetchCounts();
  Future<void> markSeen(OrderList list);
}

class SupabaseOrderBadgeApi implements OrderBadgeApi {
  const SupabaseOrderBadgeApi();

  @override
  Future<OrderBadgeCounts> fetchCounts() async {
    final res = await SupabaseConfig.client.rpc('order_badge_counts');
    if (res is Map) {
      return OrderBadgeCounts(
        incoming: (res['incoming'] as num?)?.toInt() ?? 0,
        purchases: (res['purchases'] as num?)?.toInt() ?? 0,
      );
    }
    return const OrderBadgeCounts();
  }

  @override
  Future<void> markSeen(OrderList list) async {
    await SupabaseConfig.client
        .rpc('mark_order_list_seen', params: {'p_list': list.dbValue});
  }
}

final orderBadgeApiProvider =
    Provider<OrderBadgeApi>((ref) => const SupabaseOrderBadgeApi());

/// "+1" badges for Incoming Orders, My Purchases and the Orders tab.
///
/// A badge clears only when that list is actually on screen ([markSeen]);
/// opening the notification bell never clears it. Marking a list seen also
/// marks its order alerts read on the server, so the bell drops too.
class OrderBadgeNotifier extends StateNotifier<OrderBadgeCounts> {
  OrderBadgeNotifier(this._api, this._userId) : super(const OrderBadgeCounts()) {
    if (_userId != null) refresh();
  }

  final OrderBadgeApi _api;
  final String? _userId;

  Future<void> refresh() async {
    if (_userId == null) return;
    try {
      final counts = await _api.fetchCounts();
      if (mounted) state = counts;
    } catch (e) {
      debugPrint('ORDER_BADGE_REFRESH_ERROR: $e');
    }
  }

  /// Returns true when the server confirmed, so callers can refresh the bell.
  Future<bool> markSeen(OrderList list) async {
    if (_userId == null) return false;
    state = state.cleared(list);
    try {
      await _api.markSeen(list);
      return true;
    } catch (e) {
      debugPrint('ORDER_BADGE_MARK_SEEN_ERROR: $e');
      return false;
    }
  }
}

final orderBadgeProvider =
    StateNotifierProvider<OrderBadgeNotifier, OrderBadgeCounts>((ref) {
  final userId = ref.watch(authStateProvider).valueOrNull?.id;
  return OrderBadgeNotifier(ref.watch(orderBadgeApiProvider), userId);
});

/// True while the Orders tab of the main shell is the visible tab. Lists only
/// count as "seen" while this is true (the shell keeps tabs alive offstage).
final ordersTabVisibleProvider = StateProvider<bool>((ref) => false);
