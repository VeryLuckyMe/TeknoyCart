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
}
