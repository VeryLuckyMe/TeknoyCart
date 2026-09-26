import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/features/checkout/models/order.dart';
import 'package:teknoycart/features/chat/models/message.dart';

void main() {
  group('Profile Model Tests', () {
    final testJson = {
      'id': 'user-123',
      'username': 'wildcat_teknoy',
      'email': 'teknoy@cit.edu',
      'avatar_url': 'https://cit.edu/avatar.png',
      'created_at': '2026-05-26T14:00:00.000Z',
    };

    test('should correctly instantiate from JSON', () {
      final profile = Profile.fromJson(testJson);
      expect(profile.id, 'user-123');
      expect(profile.username, 'wildcat_teknoy');
      expect(profile.email, 'teknoy@cit.edu');
      expect(profile.avatarUrl, 'https://cit.edu/avatar.png');
      expect(profile.createdAt, DateTime.parse('2026-05-26T14:00:00.000Z'));
    });

    test('should correctly serialize to JSON', () {
      final profile = Profile(
        id: 'user-123',
        username: 'wildcat_teknoy',
        email: 'teknoy@cit.edu',
        avatarUrl: 'https://cit.edu/avatar.png',
        createdAt: DateTime.parse('2026-05-26T14:00:00.000Z'),
      );
      final json = profile.toJson();
      expect(json['id'], 'user-123');
      expect(json['username'], 'wildcat_teknoy');
      expect(json['email'], 'teknoy@cit.edu');
      expect(json['avatar_url'], 'https://cit.edu/avatar.png');
    });

    test('should support copyWith values', () {
      final profile = Profile(
        id: 'user-123',
        username: 'wildcat_teknoy',
        email: 'teknoy@cit.edu',
        createdAt: DateTime.parse('2026-05-26T14:00:00.000Z'),
      );
      final updated = profile.copyWith(username: 'new_name');
      expect(updated.username, 'new_name');
      expect(updated.id, 'user-123');
    });
  });

  group('Product Model Tests', () {
    final testJson = {
      'id': 'prod-1',
      'title': 'Engineering Drawing Table',
      'description': 'CIT-U standard drawing table, slightly used.',
      'price': 450.00,
      'image_url': 'https://cit.edu/drawing_table.jpg',
      'category': 'Drawing Tools',
      'condition': 'Like New',
      'seller_id': 'user-123',
      'created_at': '2026-05-26T14:00:00.000Z',
    };

    test('should correctly instantiate from JSON', () {
      final product = Product.fromJson(testJson);
      expect(product.id, 'prod-1');
      expect(product.title, 'Engineering Drawing Table');
      expect(product.price, 450.00);
      expect(product.condition, 'Like New');
    });

    test('should correctly serialize to JSON', () {
      final product = Product(
        id: 'prod-1',
        title: 'Engineering Drawing Table',
        description: 'CIT-U standard drawing table, slightly used.',
        price: 450.00,
        imageUrl: 'https://cit.edu/drawing_table.jpg',
        category: 'Drawing Tools',
        condition: 'Like New',
        sellerId: 'user-123',
        createdAt: DateTime.parse('2026-05-26T14:00:00.000Z'),
      );
      final json = product.toJson();
      expect(json['id'], 'prod-1');
      expect(json['price'], 450.00);
      expect(json['condition'], 'Like New');
    });

    test('should correctly parse and serialize category attributes (Clothes, Electronics, Food, School Supplies)', () {
      final productJson = {
        'id': 'prod-clothes-1',
        'title': 'CIT-U PE Uniform Shirt',
        'description': 'Official Maroon PE Shirt',
        'price': 250.00,
        'image_url': 'https://cit.edu/shirt.jpg',
        'category': 'Uniforms',
        'condition': 'New',
        'seller_id': 'seller-pe-1',
        'created_at': '2026-05-26T14:00:00.000Z',
        'category_attributes': [
          {'name': 'Size', 'value': 'Medium'},
          {'name': 'Color', 'value': 'Maroon'},
          {'name': 'Gender', 'value': 'Unisex'},
          {'name': 'Uniform Type', 'value': 'PE Uniform'},
        ],
      };

      final product = Product.fromJson(productJson);
      expect(product.categoryAttributes.length, 4);
      expect(product.categoryAttributes[0].name, 'Size');
      expect(product.categoryAttributes[0].value, 'Medium');
      expect(product.categoryAttributes[1].name, 'Color');
      expect(product.categoryAttributes[1].value, 'Maroon');

      // Test serialization
      final serialized = product.toJson();
      expect(serialized['category_attributes'], isA<List>());
      final attrs = serialized['category_attributes'] as List;
      expect(attrs.length, 4);
      expect(attrs[0]['name'], 'Size');
      expect(attrs[0]['value'], 'Medium');

      // Test copyWith preserves or updates attributes
      final updated = product.copyWith(
        categoryAttributes: [
          const ProductAttribute(name: 'Size', value: 'Large'),
        ],
      );
      expect(updated.categoryAttributes.length, 1);
      expect(updated.categoryAttributes.first.value, 'Large');
    });
  });

  group('Category Attributes & Templates Model Tests', () {
    test('ProductAttribute equality and serialization', () {
      const attr1 = ProductAttribute(name: 'Size', value: 'XL');
      const attr2 = ProductAttribute(name: 'Size', value: 'XL');
      const attr3 = ProductAttribute(name: 'Color', value: 'Maroon');

      expect(attr1, equals(attr2));
      expect(attr1 == attr3, isFalse);

      final json = attr1.toJson();
      final fromJson = ProductAttribute.fromJson(json);
      expect(fromJson.name, 'Size');
      expect(fromJson.value, 'XL');
      expect(fromJson, equals(attr1));
    });

    test('CategoryAttributeTemplate serialization for select and text types', () {
      const selectTemplate = CategoryAttributeTemplate(
        name: 'Size',
        type: 'select',
        placeholder: 'Select size',
        options: ['S', 'M', 'L', 'XL'],
      );

      final json = selectTemplate.toJson();
      expect(json['name'], 'Size');
      expect(json['type'], 'select');
      expect(json['options'], ['S', 'M', 'L', 'XL']);

      final fromJson = CategoryAttributeTemplate.fromJson(json);
      expect(fromJson.name, 'Size');
      expect(fromJson.type, 'select');
      expect(fromJson.options.length, 4);
      expect(fromJson.options.contains('XL'), isTrue);

      const textTemplate = CategoryAttributeTemplate(
        name: 'Brand',
        type: 'text',
        placeholder: 'e.g. Casio, HP',
      );
      final textJson = textTemplate.toJson();
      expect(textJson.containsKey('options'), isFalse);
      final textFromJson = CategoryAttributeTemplate.fromJson(textJson);
      expect(textFromJson.name, 'Brand');
      expect(textFromJson.options.isEmpty, isTrue);
    });
  });

  group('Order Model Tests', () {
    final testJson = {
      'id': 'order-1',
      'product_id': 'prod-1',
      'buyer_id': 'buyer-1',
      'seller_id': 'seller-1',
      'agreed_price': 400.00,
      'pickup_location': 'Library Lobby',
      'status': 'Pending',
      'created_at': '2026-05-26T14:00:00.000Z',
    };

    test('should correctly instantiate from JSON', () {
      final order = Order.fromJson(testJson);
      expect(order.id, 'order-1');
      expect(order.agreedPrice, 400.00);
      expect(order.pickupLocation, 'Library Lobby');
    });

    test('should correctly serialize to JSON', () {
      final order = Order(
        id: 'order-1',
        productId: 'prod-1',
        buyerId: 'buyer-1',
        sellerId: 'seller-1',
        agreedPrice: 400.00,
        pickupLocation: 'Library Lobby',
        status: 'Pending',
        createdAt: DateTime.parse('2026-05-26T14:00:00.000Z'),
      );
      final json = order.toJson();
      expect(json['id'], 'order-1');
      expect(json['agreed_price'], 400.00);
      expect(json['pickup_location'], 'Library Lobby');
    });
  });

  group('Message Model Tests', () {
    final testJson = {
      'id': 'msg-1',
      'sender_id': 'sender-1',
      'receiver_id': 'receiver-1',
      'content': 'Is the price negotiable?',
      'created_at': '2026-05-26T14:00:00.000Z',
      'room_id': 'room-1',
    };

    test('should correctly instantiate from JSON', () {
      final message = Message.fromJson(testJson);
      expect(message.id, 'msg-1');
      expect(message.content, 'Is the price negotiable?');
      expect(message.roomId, 'room-1');
    });

    test('should correctly serialize to JSON', () {
      final message = Message(
        id: 'msg-1',
        senderId: 'sender-1',
        receiverId: 'receiver-1',
        content: 'Is the price negotiable?',
        createdAt: DateTime.parse('2026-05-26T14:00:00.000Z'),
        roomId: 'room-1',
      );
      final json = message.toJson();
      expect(json['id'], 'msg-1');
      expect(json['room_id'], 'room-1');
    });
  });
}
