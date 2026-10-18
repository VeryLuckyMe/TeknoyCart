import 'package:flutter/foundation.dart';

/// Statuses that count as confirmed revenue (mirrors the existing report logic).
const Set<String> paidOrderStatuses = {
  'COMPLETED',
  'PAYMENT_VERIFIED',
  'READY_FOR_PICKUP',
};

/// Statuses that never count as a placed order in the conversion funnel.
const Set<String> abandonedOrderStatuses = {'CANCELLED', 'REJECTED'};

/// True when [rawIso] falls inside the selected report period.
/// Rows without a parseable timestamp are kept (never silently dropped).
bool withinReportPeriod(String? rawIso, String period, DateTime now) {
  if (period == 'All Time' || rawIso == null) return true;
  final dt = DateTime.tryParse(rawIso);
  if (dt == null) return true;
  switch (period) {
    case 'Daily':
      return !dt.isBefore(DateTime(now.year, now.month, now.day));
    case 'Weekly':
      return !dt.isBefore(now.subtract(const Duration(days: 7)));
    case 'Monthly':
      return !dt.isBefore(now.subtract(const Duration(days: 30)));
    default:
      return true;
  }
}

/// Three-stage seller funnel: inquiries -> orders placed -> confirmed sales.
@immutable
class SalesFunnel {
  final int inquiries;
  final int ordersPlaced;
  final int confirmed;

  const SalesFunnel({
    required this.inquiries,
    required this.ordersPlaced,
    required this.confirmed,
  });

  /// Fraction of inquiries that became placed orders (0 when no inquiries).
  double get inquiryToOrderRate =>
      inquiries == 0 ? 0.0 : (ordersPlaced / inquiries).clamp(0.0, 1.0);

  /// Fraction of placed orders that reached a confirmed state.
  double get orderToConfirmRate =>
      ordersPlaced == 0 ? 0.0 : (confirmed / ordersPlaced).clamp(0.0, 1.0);
}

/// One aggregated row of the Top Products card.
@immutable
class TopProductStat {
  final String name;
  final int orders;
  final int units;
  final double revenue;

  const TopProductStat({
    required this.name,
    required this.orders,
    required this.units,
    required this.revenue,
  });
}

/// Aggregates confirmed order rows into the best-selling products by revenue.
/// Accepts the flattened rows built by the reports screen
/// (`productName`, `total_amount`, `quantity`).
List<TopProductStat> computeTopProducts(
  Iterable<Map<String, dynamic>> confirmedOrders, {
  int limit = 5,
}) {
  final aggregated = <String, TopProductStat>{};

  for (final order in confirmedOrders) {
    final name = order['productName']?.toString() ?? 'Merchandise';
    final revenue =
        double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0.0;
    final units = int.tryParse(order['quantity']?.toString() ?? '1') ?? 1;

    final prev = aggregated[name];
    aggregated[name] = TopProductStat(
      name: name,
      orders: (prev?.orders ?? 0) + 1,
      units: (prev?.units ?? 0) + units,
      revenue: (prev?.revenue ?? 0.0) + revenue,
    );
  }

  final ranked = aggregated.values.toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));
  return ranked.take(limit).toList();
}

/// One low-stock row for the inventory radar card.
@immutable
class LowStockAlert {
  final String productName;
  final String variantLabel;
  final String sku;
  final int stockQty;
  final int threshold;

  const LowStockAlert({
    required this.productName,
    required this.variantLabel,
    required this.sku,
    required this.stockQty,
    required this.threshold,
  });
}

/// Builds low-stock alerts from `products` rows fetched with embedded
/// `product_variants` and their `inventory`. Tolerates both single-object and
/// list shapes for embedded resources and ignores rows without inventory.
List<LowStockAlert> computeLowStockAlerts(
  Iterable<Map<String, dynamic>> products, {
  int limit = 8,
}) {
  final alerts = <LowStockAlert>[];

  for (final product in products) {
    final productName = product['name']?.toString() ?? 'Listing';
    final variants = product['product_variants'];
    final variantList = variants is List
        ? variants
        : (variants is Map ? <dynamic>[variants] : const <dynamic>[]);

    for (final variant in variantList) {
      if (variant is! Map) continue;

      final inventoryRaw = variant['inventory'];
      final inventory = inventoryRaw is List
          ? (inventoryRaw.isEmpty ? null : inventoryRaw.first)
          : inventoryRaw;
      if (inventory is! Map) continue;

      final stock = int.tryParse(inventory['stock_qty']?.toString() ?? '') ?? 0;
      final threshold =
          int.tryParse(inventory['low_stock_threshold']?.toString() ?? '') ?? 5;
      if (stock > threshold) continue;

      final variantName = variant['variant_name']?.toString() ?? '';
      final variantValue = variant['variant_value']?.toString() ?? '';
      alerts.add(LowStockAlert(
        productName: productName,
        variantLabel: variantValue.isEmpty
            ? variantName
            : (variantName.isEmpty
                ? variantValue
                : '$variantName: $variantValue'),
        sku: variant['sku']?.toString() ?? '',
        stockQty: stock,
        threshold: threshold,
      ));
    }
  }

  alerts.sort((a, b) => a.stockQty.compareTo(b.stockQty));
  return alerts.take(limit).toList();
}
