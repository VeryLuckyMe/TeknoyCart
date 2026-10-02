import 'package:teknoycart/core/models/product.dart';

class CartItem {
  final Product product;
  final int quantity;
  final String? variantId;
  final String? variantName;
  final int? maxStock;

  CartItem({
    required this.product,
    required this.quantity,
    this.variantId,
    this.variantName,
    this.maxStock,
  });

  /// Unique key distinguishing different variants of the same product in the cart
  String get cartKey => '${product.id}__${variantId ?? ''}__${variantName ?? ''}';

  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        'quantity': quantity,
        'variant_id': variantId,
        'variant_name': variantName,
        'max_stock': maxStock,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      variantId: json['variant_id'] as String?,
      variantName: json['variant_name'] as String?,
      maxStock: (json['max_stock'] as num?)?.toInt(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          runtimeType == other.runtimeType &&
          product == other.product &&
          quantity == other.quantity &&
          variantId == other.variantId &&
          variantName == other.variantName &&
          maxStock == other.maxStock;

  @override
  int get hashCode =>
      product.hashCode ^
      quantity.hashCode ^
      (variantId?.hashCode ?? 0) ^
      (variantName?.hashCode ?? 0) ^
      (maxStock?.hashCode ?? 0);
}
