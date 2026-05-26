import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/feed/models/product.dart';
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
