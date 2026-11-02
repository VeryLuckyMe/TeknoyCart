import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/models/product.dart';

void main() {
  group('Product Model Unit Tests', () {
    final fixedTime = DateTime.parse('2026-11-01T08:00:00Z');

    test('toJson and fromJson handle standard product attributes and pricing', () {
      final product = Product(
        id: 'prod-999',
        title: 'CIT Engineering Uniform',
        description: 'Clean uniform size L',
        price: 450.0,
        imageUrl: 'https://example.com/uniform.png',
        imageUrls: const ['https://example.com/uniform.png', 'https://example.com/uniform_back.png'],
        category: 'Uniforms',
        condition: 'Like New',
        sellerId: 'user-seller-9',
        sellerStoreName: 'Wildcat Supplies',
        isPreorderEnabled: false,
        createdAt: fixedTime,
      );

      final json = product.toJson();
      final restored = Product.fromJson(json);

      expect(restored.id, equals('prod-999'));
      expect(restored.title, equals('CIT Engineering Uniform'));
      expect(restored.price, equals(450.0));
      expect(restored.category, equals('Uniforms'));
      expect(restored.condition, equals('Like New'));
      expect(restored.sellerId, equals('user-seller-9'));
      expect(restored.sellerStoreName, equals('Wildcat Supplies'));
      expect(restored.imageUrls.length, equals(2));
      expect(restored.isPreorderEnabled, isFalse);
    });

    test('Product.fromJson parses category_attributes safely', () {
      final json = {
        'id': 'prod-100',
        'title': 'Mechanical Pencil',
        'description': '0.5mm lead',
        'price': 45.0,
        'category': 'Stationery',
        'condition': 'New',
        'seller_id': 'seller-1',
        'created_at': fixedTime.toIso8601String(),
        'category_attributes': const [
          {'name': 'Color', 'value': 'Maroon'},
          {'name': 'Lead Size', 'value': '0.5mm'}
        ],
      };

      final product = Product.fromJson(json);
      expect(product.categoryAttributes.length, equals(2));
      expect(product.categoryAttributes[0].name, equals('Color'));
      expect(product.categoryAttributes[0].value, equals('Maroon'));
      expect(product.categoryAttributes[1].name, equals('Lead Size'));
      expect(product.categoryAttributes[1].value, equals('0.5mm'));
    });

    test('Product.fromJson supports map attributes and product image rows', () {
      final product = Product.fromJson({
        'id': 'prod-101',
        'title': 'Notebook',
        'description': 'Ruled pages',
        'price': 80,
        'category': 'Stationery',
        'condition': 'New',
        'seller_id': 'seller-1',
        'created_at': fixedTime.toIso8601String(),
        'product_images': const [
          {'image_url': 'https://example.com/front.png'},
          {'image_url': 'https://example.com/back.png'},
        ],
        'category_attributes': const {
          'Color': 'Maroon',
          '': 'ignored',
          'Material': 'Paper',
        },
      });

      expect(product.imageUrl, equals('https://example.com/front.png'));
      expect(product.imageUrls, hasLength(2));
      expect(product.categoryAttributes, hasLength(2));
      expect(product.categoryAttributes.first.name, equals('Color'));
    });

    test('ProductAttribute sorts size options and preserves scalar values', () {
      expect(
        const ProductAttribute(name: 'Size', value: 'XL, S, M').options,
        equals(['S', 'M', 'XL']),
      );
      expect(
        const ProductAttribute(name: 'Color', value: 'Maroon').options,
        equals(['Maroon']),
      );
      expect(const ProductAttribute(name: 'Size', value: '').options, isEmpty);
    });
  });
}
