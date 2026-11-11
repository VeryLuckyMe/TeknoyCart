/// Placeholder id some legacy code paths store instead of null.
const String kNilVariantId = '00000000-0000-0000-0000-000000000000';

enum VariantResolutionFailure {
  /// The product has several variants and the buyer's choice is unknown.
  ambiguous,

  /// The product has no variants at all (seller never configured inventory).
  notConfigured,
}

class VariantResolution {
  final String? variantId;
  final VariantResolutionFailure? failure;

  const VariantResolution.resolved(String this.variantId) : failure = null;
  const VariantResolution.failed(VariantResolutionFailure this.failure) : variantId = null;

  bool get isResolved => variantId != null;
}

/// Looks up variant ids for a product, optionally filtered by variant value.
/// Implementations should return at most [limit] ids.
typedef VariantIdLookup = Future<List<String>> Function(
  String productId, {
  String? variantValue,
  required int limit,
});

/// Decides which variant a checkout line buys, without ever guessing.
///
/// 1. An explicit variant id wins.
/// 2. Otherwise a variant whose value matches [variantName] exactly, if unique.
/// 3. Otherwise, only if the product has exactly ONE variant, that variant.
///
/// A product with several variants and no clear choice is [ambiguous]: the
/// buyer must pick (the old code silently bought "any" variant, e.g. size M
/// instead of L).
Future<VariantResolution> resolveCheckoutVariant({
  required String productId,
  String? variantId,
  String? variantName,
  required VariantIdLookup lookup,
}) async {
  if (variantId != null && variantId.isNotEmpty && variantId != kNilVariantId) {
    return VariantResolution.resolved(variantId);
  }

  if (variantName != null && variantName.trim().isNotEmpty) {
    final byName = await lookup(productId, variantValue: variantName, limit: 2);
    if (byName.length == 1) return VariantResolution.resolved(byName.single);
  }

  final all = await lookup(productId, limit: 2);
  if (all.length == 1) return VariantResolution.resolved(all.single);
  if (all.isEmpty) {
    return const VariantResolution.failed(VariantResolutionFailure.notConfigured);
  }
  return const VariantResolution.failed(VariantResolutionFailure.ambiguous);
}
