import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/features/checkout/models/cart_item.dart';
import 'package:teknoycart/features/checkout/models/cart_summary.dart';
import 'package:teknoycart/features/checkout/models/checkout_item.dart';

void main() {
  group('CartSummary Unit Tests', () {
    final p1 = Product(
      id: 'prod-1',
      sellerId: 'seller-a',
      title: 'Notebook',
      description: 'CIT-U Notebook',
      price: 50.0,
      category: 'School Supplies',
      condition: 'Brand New',
      sellerStoreName: 'Wildcat Bookstore',
      createdAt: DateTime.now(),
    );

    final p2 = Product(
      id: 'prod-2',
      sellerId: 'seller-a',
      title: 'Ballpen',
      description: 'Black pen',
      price: 15.0,
      category: 'School Supplies',
      condition: 'Brand New',
      sellerStoreName: 'Wildcat Bookstore',
      createdAt: DateTime.now(),
    );

    final p3 = Product(
      id: 'prod-3',
      sellerId: 'seller-b',
      title: 'CIT-U Cap',
      description: 'Gold cap',
      price: 250.0,
      category: 'Clothes',
      condition: 'Like New',
      sellerStoreName: 'Wildcat Apparel',
      createdAt: DateTime.now(),
    );

    final item1 = CartItem(product: p1, quantity: 2); // 100.0
    final item2 = CartItem(product: p2, quantity: 3); // 45.0
    final item3 = CartItem(product: p3, quantity: 1); // 250.0

    test('lineTotal calculates price times quantity', () {
      expect(CartSummary.lineTotal(item1), 100.0);
      expect(CartSummary.lineTotal(item2), 45.0);
      expect(CartSummary.lineTotal(item3), 250.0);
    });

    test('storeSubtotal sums all items within a store group', () {
      expect(CartSummary.storeSubtotal([item1, item2]), 145.0);
      expect(CartSummary.storeSubtotal([item3]), 250.0);
    });

    test('fromCart calculates selected totals and per-store subtotals', () {
      final items = [item1, item2, item3];
      final selectedKeys = {item1.cartKey, item3.cartKey};

      final summary = CartSummary.fromCart(items, selectedKeys);

      expect(summary.selectedCount, 2);
      expect(summary.selectedTotal, 350.0);
      expect(summary.storeTotals['seller-a'], 100.0);
      expect(summary.storeTotals['seller-b'], 250.0);
    });
  });

  group('CheckoutPricing Unit Tests', () {
    final p1 = Product(
      id: 'prod-1',
      sellerId: 'seller-a',
      title: 'Uniform',
      description: 'Uniform',
      price: 300.0,
      category: 'Uniforms',
      condition: 'Brand New',
      createdAt: DateTime.now(),
    );

    final checkoutItem = CheckoutItem(product: p1, quantity: 2, price: 300.0);

    test('unitPrice incorporates variant surcharge when no agreed tawad price', () {
      const pricing = CheckoutPricing(
        variantAdditionalPrices: {'prod-1': 50.0},
      );
      expect(pricing.unitPrice(checkoutItem), 350.0);
      expect(pricing.totalPrice([checkoutItem]), 700.0);
    });

    test('unitPrice ignores variant surcharge when agreed tawad price is set', () {
      final agreedItem = CheckoutItem(product: p1, quantity: 1, price: 260.0);
      const pricing = CheckoutPricing(
        agreedPrice: 260.0,
        variantAdditionalPrices: {'prod-1': 50.0},
      );
      expect(pricing.unitPrice(agreedItem), 260.0);
      expect(pricing.totalPrice([agreedItem]), 260.0);
    });

    test('discount computes savings against asking price', () {
      const pricing = CheckoutPricing(agreedPrice: 240.0);
      expect(pricing.discount([checkoutItem]), 60.0);
    });
  });
}
