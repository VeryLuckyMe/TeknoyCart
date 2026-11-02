import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/features/checkout/models/order.dart';

void main() {
  group('Order & AtomicOrderResult Unit Tests', () {
    final orderDate = DateTime.parse('2026-11-01T15:30:00Z');

    test('Order serialization roundtrip preserves integrity', () {
      final original = Order(
        id: 'ord-1234',
        productId: 'prod-5678',
        buyerId: 'buyer-cit-1',
        sellerId: 'seller-cit-2',
        agreedPrice: 320.50,
        pickupLocation: 'Library Lobby',
        status: 'PLACED',
        createdAt: orderDate,
      );

      final json = original.toJson();
      final restored = Order.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.productId, equals(original.productId));
      expect(restored.buyerId, equals(original.buyerId));
      expect(restored.sellerId, equals(original.sellerId));
      expect(restored.agreedPrice, equals(320.50));
      expect(restored.pickupLocation, equals('Library Lobby'));
      expect(restored.status, equals('PLACED'));
      expect(restored, equals(original));
      expect(restored.hashCode, equals(original.hashCode));
    });

    test('Order copyWith modifies selected fields correctly', () {
      final order = Order(
        id: 'ord-1234',
        productId: 'prod-5678',
        buyerId: 'buyer-1',
        sellerId: 'seller-2',
        agreedPrice: 100.0,
        pickupLocation: 'Canteen',
        status: 'PLACED',
        createdAt: orderDate,
      );

      final updated = order.copyWith(status: 'CONFIRMED', pickupLocation: 'Science Building');
      expect(updated.status, equals('CONFIRMED'));
      expect(updated.pickupLocation, equals('Science Building'));
      expect(updated.agreedPrice, equals(100.0));
      expect(updated.id, equals('ord-1234'));
    });

    test('AtomicOrderResult.fromDynamic parses valid RPC response maps', () {
      final rpcData = {
        'success': true,
        'orders': [
          {'order_id': 'ord-1', 'status': 'PLACED'},
          {'order_id': 'ord-2', 'status': 'PLACED'}
        ]
      };

      final result = AtomicOrderResult.fromDynamic(rpcData);
      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.orders.length, equals(2));
      expect(result.orders.first['order_id'], equals('ord-1'));
    });

    test('AtomicOrderResult.fromDynamic gracefully handles malformed data', () {
      final result1 = AtomicOrderResult.fromDynamic(null);
      expect(result1.success, isFalse);
      expect(result1.error, equals('MALFORMED_RESPONSE'));
      expect(result1.orders, isEmpty);

      final result2 = AtomicOrderResult.fromDynamic('not-a-map');
      expect(result2.success, isFalse);
      expect(result2.error, equals('MALFORMED_RESPONSE'));
      expect(result2.orders, isEmpty);

      final resultError = AtomicOrderResult.fromDynamic(const {
        'success': false,
        'error': 'OUT_OF_STOCK',
      });
      expect(resultError.success, isFalse);
      expect(resultError.error, equals('OUT_OF_STOCK'));
      expect(resultError.orders, isEmpty);
    });

    test('AtomicOrderResult ignores non-map order entries', () {
      final result = AtomicOrderResult.fromDynamic(const {
        'success': true,
        'orders': [
          {'order_id': 'ord-1'},
          'invalid-order',
          42,
        ],
      });

      expect(result.success, isTrue);
      expect(result.orders, hasLength(1));
      expect(result.orders.single['order_id'], equals('ord-1'));
    });
  });
}

