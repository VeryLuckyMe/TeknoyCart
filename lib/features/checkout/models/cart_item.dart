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
}
