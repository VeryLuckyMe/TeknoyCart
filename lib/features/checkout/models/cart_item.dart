import 'package:teknoycart/features/feed/models/product.dart';

class CartItem {
  final Product product;
  final int quantity;
  final String? variantId;
  final String? variantName;

  CartItem({
    required this.product,
    required this.quantity,
    this.variantId,
    this.variantName,
  });
}
