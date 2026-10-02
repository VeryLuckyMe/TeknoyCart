import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/features/checkout/models/cart_item.dart';
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

    test('adding different variants of same product creates separate line items', () {
      cartNotifier.addToCart(
        testProduct,
        quantity: 1,
        variantName: 'M',
        maxStock: 5,
      );

      cartNotifier.addToCart(
        testProduct,
        quantity: 2,
        variantName: 'XL',
        maxStock: 5,
      );

      expect(cartNotifier.state.length, 2);
      expect(cartNotifier.state[0].variantName, 'M');
      expect(cartNotifier.state[0].quantity, 1);
      expect(cartNotifier.state[1].variantName, 'XL');
      expect(cartNotifier.state[1].quantity, 2);

      // Adding size XL again should only increment size XL
      cartNotifier.addToCart(
        testProduct,
        quantity: 1,
        variantName: 'XL',
        maxStock: 5,
      );

      expect(cartNotifier.state.length, 2);
      expect(cartNotifier.state[1].quantity, 3);
      expect(cartNotifier.state[0].quantity, 1);
    });

    test('updateVariant allows switching variant of a cart item', () {
      cartNotifier.addToCart(
        testProduct,
        quantity: 1,
        variantName: 'M',
        maxStock: 5,
      );

      cartNotifier.updateVariant(testProduct.id, 'M', 'L');

      expect(cartNotifier.state.length, 1);
      expect(cartNotifier.state.first.variantName, 'L');
    });
  });

  group('CartNotifier Disk Persistence & Hydration Tests (HIGH-06)', () {
    late _InMemoryCartStorage mockStorage;
    late Product testProduct;

    setUp(() {
      mockStorage = _InMemoryCartStorage();
      testProduct = Product(
        id: 'prod-persist-1',
        title: 'Drafting Compass Set',
        description: 'CIT-U drafting tools',
        price: 250.0,
        category: 'Drawing Tools',
        condition: 'Like New',
        sellerId: 'seller-456',
        createdAt: DateTime.parse('2026-10-01T10:00:00.000Z'),
      );
    });

    test('CartItem serialization to and from JSON preserves all fields', () {
      final original = CartItem(
        product: testProduct,
        quantity: 3,
        variantId: 'var-blue',
        variantName: 'Blue Set',
        maxStock: 10,
      );

      final json = original.toJson();
      final revived = CartItem.fromJson(json);

      expect(revived.product.id, original.product.id);
      expect(revived.product.title, original.product.title);
      expect(revived.quantity, 3);
      expect(revived.variantId, 'var-blue');
      expect(revived.variantName, 'Blue Set');
      expect(revived.maxStock, 10);
      expect(revived, equals(original));
    });

    test('Adding to cart persists items to storage', () async {
      final notifier = CartNotifier(storage: mockStorage, autoLoad: false);

      notifier.addToCart(testProduct, quantity: 2);
      await Future<void>.delayed(Duration.zero);

      expect(mockStorage.data.containsKey(CartNotifier.cartStorageKey), isTrue);
      expect(mockStorage.data[CartNotifier.cartStorageKey], contains('prod-persist-1'));
    });

    test('New CartNotifier auto-hydrates saved items from storage', () async {
      final notifier1 = CartNotifier(storage: mockStorage, autoLoad: false);
      notifier1.addToCart(testProduct, quantity: 4, variantName: 'Silver');
      await Future<void>.delayed(Duration.zero);

      // Create a second notifier referencing the same storage
      final notifier2 = CartNotifier(storage: mockStorage, autoLoad: true);
      await Future<void>.delayed(Duration.zero);

      expect(notifier2.state.length, 1);
      expect(notifier2.state.first.product.id, 'prod-persist-1');
      expect(notifier2.state.first.quantity, 4);
      expect(notifier2.state.first.variantName, 'Silver');
    });

    test('clearCart deletes persisted cart data from storage', () async {
      final notifier = CartNotifier(storage: mockStorage, autoLoad: false);
      notifier.addToCart(testProduct, quantity: 2);
      await Future<void>.delayed(Duration.zero);

      notifier.clearCart();
      await Future<void>.delayed(Duration.zero);

      expect(mockStorage.data.containsKey(CartNotifier.cartStorageKey), isFalse);
    });
  });
}

class _InMemoryCartStorage implements CartStorageService {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }
}

