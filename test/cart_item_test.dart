import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/features/checkout/models/cart_item.dart';

void main() {
  group('CartItem Unit Tests', () {
    final testProduct = Product(
      id: 'prod-123',
      sellerId: 'seller-abc',
      title: 'Teknoy Lanyard',
      description: 'Official university lanyard',
      price: 150.0,
      condition: 'New',
      category: 'Merch',
      createdAt: DateTime.parse('2026-11-01T12:00:00Z'),
    );

    test('cartKey generates composite identifier correctly', () {
      final item1 = CartItem(
        product: testProduct,
        quantity: 2,
        variantId: 'v-maroon',
        variantName: 'Maroon',
      );
      expect(item1.cartKey, equals('prod-123__v-maroon__Maroon'));

      final itemWithoutVariant = CartItem(
        product: testProduct,
        quantity: 1,
      );
      expect(itemWithoutVariant.cartKey, equals('prod-123____'));
    });

    test('toJson and fromJson preserve all properties accurately', () {
      final original = CartItem(
        product: testProduct,
        quantity: 3,
        variantId: 'v-gold',
        variantName: 'Gold Edition',
        maxStock: 10,
      );

      final json = original.toJson();
      final restored = CartItem.fromJson(json);

      expect(restored.product.id, equals(original.product.id));
      expect(restored.product.title, equals(original.product.title));
      expect(restored.quantity, equals(3));
      expect(restored.variantId, equals('v-gold'));
      expect(restored.variantName, equals('Gold Edition'));
      expect(restored.maxStock, equals(10));
    });
  });
}
