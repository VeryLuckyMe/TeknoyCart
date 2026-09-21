import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/features/checkout/providers/cart_provider.dart';

void main() {
  group('CartNotifier Stock Limit & Add to Cart Tests', () {
    late CartNotifier cartNotifier;
    late Product testProduct;

    setUp(() {
      cartNotifier = CartNotifier();
      testProduct = Product(
        id: 'prod-001',
        title: 'Engineering Mechanics Book',
        description: 'CIT-U textbook',
        price: 350.0,
        category: 'Books',
        condition: 'Like New',
        sellerId: 'seller-123',
        createdAt: DateTime.now(),
      );
    });

    test('adding within stock limits succeeds', () {
      final result = cartNotifier.addToCart(
        testProduct,
        quantity: 2,
        maxStock: 5,
      );

      expect(result.success, isTrue);
      expect(result.addedCount, 2);
      expect(result.totalInCart, 2);
      expect(cartNotifier.state.first.quantity, 2);
    });

    test('adding more than maxStock initially is capped at maxStock', () {
      final result = cartNotifier.addToCart(
        testProduct,
        quantity: 5,
        maxStock: 3,
      );

      expect(result.success, isTrue);
      expect(result.addedCount, 3);
      expect(result.totalInCart, 3);
      expect(cartNotifier.state.first.quantity, 3);
    });

    test('adding to cart repeatedly cannot exceed maxStock', () {
      // First add: 2 units (stock is 3)
      cartNotifier.addToCart(
        testProduct,
        quantity: 2,
        maxStock: 3,
      );
      expect(cartNotifier.state.first.quantity, 2);

      // Second add: 2 units (should cap at 3, only 1 added)
      final result2 = cartNotifier.addToCart(
        testProduct,
        quantity: 2,
        maxStock: 3,
      );
      expect(result2.success, isTrue);
      expect(result2.addedCount, 1);
      expect(result2.totalInCart, 3);
      expect(cartNotifier.state.first.quantity, 3);

      // Third add: 1 unit (already at max 3, should be rejected)
      final result3 = cartNotifier.addToCart(
        testProduct,
        quantity: 1,
        maxStock: 3,
      );
      expect(result3.success, isFalse);
      expect(result3.addedCount, 0);
      expect(result3.totalInCart, 3);
      expect(cartNotifier.state.first.quantity, 3);
    });

    test('updateQuantity cannot exceed maxStock', () {
      cartNotifier.addToCart(
        testProduct,
        quantity: 1,
        maxStock: 2,
      );

      // Try updating to 3 (exceeds maxStock 2)
      cartNotifier.updateQuantity(testProduct.id, null, 3);
      expect(cartNotifier.state.first.quantity, 2);

      // Updating to 0 removes item
      cartNotifier.updateQuantity(testProduct.id, null, 0);
      expect(cartNotifier.state, isEmpty);
    });

    test('adding out-of-stock item (maxStock = 0) fails', () {
      final result = cartNotifier.addToCart(
        testProduct,
        quantity: 1,
        maxStock: 0,
      );

      expect(result.success, isFalse);
      expect(result.addedCount, 0);
      expect(cartNotifier.state, isEmpty);
    });
  });
}
