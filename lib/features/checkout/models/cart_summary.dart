import 'package:teknoycart/features/checkout/models/cart_item.dart';
import 'package:teknoycart/features/checkout/models/checkout_item.dart';

/// Pure domain value object that consolidates all cart pricing calculations.
///
/// Eliminates scattered `fold` and inline arithmetic across UI widgets by
/// centralising subtotal, discount, and per-store totals in a single testable
/// class.
class CartSummary {
  /// Total price of all selected cart items (unit price × quantity).
  final double selectedTotal;

  /// Number of distinct cart items selected.
  final int selectedCount;

  /// Per-seller subtotals keyed by seller ID.
  final Map<String, double> storeTotals;

  const CartSummary({
    required this.selectedTotal,
    required this.selectedCount,
    required this.storeTotals,
  });

  /// Builds a [CartSummary] from a cart item list and a set of selected keys.
  factory CartSummary.fromCart(
    List<CartItem> items,
    Set<String> selectedKeys,
  ) {
    double total = 0.0;
    int count = 0;
    final Map<String, double> storeTotals = {};

    for (final item in items) {
      if (selectedKeys.contains(item.cartKey)) {
        final lineTotal = item.product.price * item.quantity;
        total += lineTotal;
        count++;

        final sellerId = item.product.sellerId;
        storeTotals[sellerId] = (storeTotals[sellerId] ?? 0.0) + lineTotal;
      }
    }

    return CartSummary(
      selectedTotal: total,
      selectedCount: count,
      storeTotals: storeTotals,
    );
  }

  /// Computes the line total for a single cart item.
  static double lineTotal(CartItem item) =>
      item.product.price * item.quantity;

  /// Computes the subtotal for a list of cart items (typically a single-store group).
  static double storeSubtotal(List<CartItem> items) =>
      items.fold<double>(0.0, (sum, i) => sum + lineTotal(i));
}

/// Pricing helper for checkout items, handling tawad agreed prices and
/// per-variant additional charges.
class CheckoutPricing {
  final double? agreedPrice;
  final Map<String, double> variantAdditionalPrices;

  const CheckoutPricing({
    this.agreedPrice,
    this.variantAdditionalPrices = const {},
  });

  /// Effective unit price for a checkout item, incorporating variant
  /// surcharges only when no agreed tawad price was negotiated.
  double unitPrice(CheckoutItem item) =>
      item.price +
      (agreedPrice == null
          ? (variantAdditionalPrices[item.product.id] ?? 0.0)
          : 0.0);

  /// Order total across all checkout items.
  double totalPrice(List<CheckoutItem> items) =>
      items.fold<double>(0.0, (sum, item) => sum + unitPrice(item) * item.quantity);

  /// The original asking price (catalog price) for tawad discount calculation.
  double askingPrice(List<CheckoutItem> items, {double? productPrice}) =>
      productPrice ?? (items.isNotEmpty ? items.first.product.price : 0.0);

  /// Discount amount between asking and agreed price.
  double discount(List<CheckoutItem> items, {double? productPrice}) {
    final asking = askingPrice(items, productPrice: productPrice);
    final agreed = agreedPrice ?? 0.0;
    return (asking > agreed && asking > 0) ? (asking - agreed) : 0.0;
  }
}

