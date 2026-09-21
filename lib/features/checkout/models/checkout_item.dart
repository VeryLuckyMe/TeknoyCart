import 'package:teknoycart/core/models/product.dart';

class CheckoutItem {
  final Product product;
  final double price;
  final int quantity;
  final String? variantId;
  final String? variantName;

  const CheckoutItem({
    required this.product,
    required this.price,
    required this.quantity,
    this.variantId,
    this.variantName,
  });
}
