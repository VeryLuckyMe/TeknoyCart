import 'package:flutter/material.dart';
import 'package:teknoycart/core/models/product.dart';
import 'product_detail_view.dart';

/// Lightweight backwards-compatible adapter delegating directly to the canonical [ProductDetailView].
/// Consolidates all variant, attribute, rating, and reservation logic into one single source of truth.
class ProductDetailsSheet extends StatelessWidget {
  final Product product;

  const ProductDetailsSheet({
    super.key,
    required this.product,
  });

  static Future<void> show(BuildContext context, Product product) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailView(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProductDetailView(product: product);
  }
}
