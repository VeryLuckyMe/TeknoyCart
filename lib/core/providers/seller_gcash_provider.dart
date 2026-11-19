import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';

/// Whether a seller has a GCash payout number, via `seller_accepts_gcash`
/// (migration V21). The number itself is never sent to the buyer.
///
/// Returns null when the lookup fails; the server trigger still blocks a GCash
/// order for such a seller, so null is treated as "allowed" in the UI.
final sellerAcceptsGcashProvider =
    FutureProvider.family<bool?, String>((ref, sellerId) async {
  try {
    final res = await SupabaseConfig.client
        .rpc('seller_accepts_gcash', params: {'p_seller_id': sellerId});
    return res is bool ? res : null;
  } catch (e) {
    debugPrint('SELLER_GCASH_LOOKUP_ERROR: $e');
    return null;
  }
});

/// GCash availability for a whole checkout.
enum GcashAvailability { checking, available, sellerNotSetUp }

/// Combines per-seller answers: one seller without GCash blocks it for all.
GcashAvailability combineGcashAvailability(Iterable<AsyncValue<bool?>> sellers) {
  var checking = false;
  for (final s in sellers) {
    if (s.isLoading && !s.hasValue) {
      checking = true;
      continue;
    }
    if (s.valueOrNull == false) return GcashAvailability.sellerNotSetUp;
  }
  return checking ? GcashAvailability.checking : GcashAvailability.available;
}
