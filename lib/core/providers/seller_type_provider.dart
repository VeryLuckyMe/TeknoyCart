import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';

/// Organisation sellers (official CIT-U store, student councils, org shops)
/// sell at fixed prices: buyers cannot haggle (tawad) on their listings.
bool sellerAcceptsPriceOffers(String? sellerType) =>
    (sellerType ?? 'STUDENT').toUpperCase() != 'ORG';

/// Seller type ('STUDENT' or 'ORG') for a seller id, or null if unknown.
///
/// Requires `GRANT SELECT (seller_type) ON public.users TO authenticated`
/// (migration_v17_checkout_idempotency.sql). If the lookup fails, null is returned
/// and offers stay enabled, matching the behaviour before this provider.
final sellerTypeProvider =
    FutureProvider.family<String?, String>((ref, sellerId) async {
  try {
    final row = await SupabaseConfig.client
        .from('users')
        .select('seller_type')
        .eq('user_id', sellerId)
        .maybeSingle();
    return row?['seller_type'] as String?;
  } catch (e) {
    debugPrint('SELLER_TYPE_LOOKUP_ERROR: $e');
    return null;
  }
});

/// Whether buyers may send price offers on this seller's listings.
/// Defaults to false while loading so the button never flashes on for org stores.
final sellerAcceptsOffersProvider = Provider.family<bool, String>((ref, sellerId) {
  final type = ref.watch(sellerTypeProvider(sellerId));
  return type.maybeWhen(
    data: sellerAcceptsPriceOffers,
    error: (_, __) => true,
    orElse: () => false,
  );
});
