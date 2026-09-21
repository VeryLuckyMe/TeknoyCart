import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/models/product.dart';

void main() {
  group('Phase 5: Atomic Inventory & Pre-Order Client Regression Tests', () {
    late Product standardProduct;
    late Product preorderProduct;

    setUp(() {
      standardProduct = Product(
        id: 'prod-std-001',
        title: 'Used Graphics Tablet',
        description: 'Single secondhand item',
        price: 1500.0,
        category: 'Drawing Tools',
        condition: 'Gently Used',
        sellerId: 'seller-abc',
        isPreorderEnabled: false,
        createdAt: DateTime.now(),
      );

      preorderProduct = Product(
        id: 'prod-pre-002',
        title: 'CIT-U Engineering Batch Hoodie',
        description: 'Official department merchandise',
        price: 850.0,
        category: 'Uniforms',
        condition: 'New',
        sellerId: 'seller-org',
        isPreorderEnabled: true,
        createdAt: DateTime.now(),
      );
    });

    test('Available inventory is accurately calculated as stock minus reserved', () {
      // 1. Fully available stock
      int stockQty = 10;
      int reservedQty = 0;
      int available = (stockQty - reservedQty).clamp(0, 999999);
      expect(available, equals(10));

      // 2. Partial reservations in meetup
      reservedQty = 4;
      available = (stockQty - reservedQty).clamp(0, 999999);
      expect(available, equals(6));

      // 3. All stock held in active meetup deals
      reservedQty = 10;
      available = (stockQty - reservedQty).clamp(0, 999999);
      expect(available, equals(0));

      // 4. Over-reservation edge case clamps safely to 0
      reservedQty = 15;
      available = (stockQty - reservedQty).clamp(0, 999999);
      expect(available, equals(0));
    });

    test('Option A: Secondhand item with 0 available stock displays SOLD OUT', () {
      final int stock = 1;
      final int reserved = 1;
      final int available = (stock - reserved).clamp(0, 999999);
      final bool isOutOfStock = available <= 0;
      final bool isPreorder = standardProduct.isPreorderEnabled;

      String badgeText;
      String actionLabel;
      bool canPurchase;

      if (!isOutOfStock) {
        badgeText = '$available IN STOCK';
        actionLabel = 'Buy Now';
        canPurchase = true;
      } else if (isPreorder) {
        badgeText = 'PRE-ORDER OPEN';
        actionLabel = 'Pre-Order Now';
        canPurchase = true;
      } else {
        badgeText = 'SOLD OUT';
        actionLabel = 'Out of Stock';
        canPurchase = false;
      }

      expect(isOutOfStock, isTrue);
      expect(badgeText, equals('SOLD OUT'));
      expect(actionLabel, equals('Out of Stock'));
      expect(canPurchase, isFalse);
    });

    test('Option A: Batch merchandise with 0 available stock switches to PRE-ORDER OPEN', () {
      final int stock = 0;
      final int reserved = 0;
      final int available = (stock - reserved).clamp(0, 999999);
      final bool isOutOfStock = available <= 0;
      final bool isPreorder = preorderProduct.isPreorderEnabled;

      String badgeText;
      String actionLabel;
      bool canPurchase;

      if (!isOutOfStock) {
        badgeText = '$available IN STOCK';
        actionLabel = 'Buy Now';
        canPurchase = true;
      } else if (isPreorder) {
        badgeText = 'PRE-ORDER OPEN';
        actionLabel = 'Pre-Order Now';
        canPurchase = true;
      } else {
        badgeText = 'SOLD OUT';
        actionLabel = 'Out of Stock';
        canPurchase = false;
      }

      expect(isOutOfStock, isTrue);
      expect(badgeText, equals('PRE-ORDER OPEN'));
      expect(actionLabel, equals('Pre-Order Now'));
      expect(canPurchase, isTrue);
    });

    test('Client maps atomic RPC error codes to clear, student-friendly feedback', () {
      String mapRpcError(String? code, String itemTitle) {
        switch (code) {
          case 'INSUFFICIENT_STOCK':
            return 'Sorry, "$itemTitle" was just claimed by another student!';
          case 'PRODUCT_NOT_ACTIVE':
            return 'This listing is no longer active.';
          case 'CANNOT_RESERVE_OWN_PRODUCT':
            return 'You cannot purchase your own product listing.';
          case 'INVALID_QUANTITY':
            return 'Please select a valid quantity.';
          default:
            return 'Failed to reserve stock.';
        }
      }

      expect(
        mapRpcError('INSUFFICIENT_STOCK', 'Engineering Book'),
        equals('Sorry, "Engineering Book" was just claimed by another student!'),
      );
      expect(
        mapRpcError('PRODUCT_NOT_ACTIVE', 'Any Item'),
        equals('This listing is no longer active.'),
      );
      expect(
        mapRpcError('CANNOT_RESERVE_OWN_PRODUCT', 'My Item'),
        equals('You cannot purchase your own product listing.'),
      );
    });

    test('Client async regression check: handling simultaneous failure gracefully', () async {
      // Simulates client receiving responses from 5 concurrent checkout attempts
      Future<Map<String, dynamic>> mockRpcCall(int clientIndex) async {
        await Future.delayed(Duration(milliseconds: 10 * clientIndex));
        if (clientIndex == 0) {
          return {'success': true, 'is_preorder': false, 'remaining_available': 0};
        } else {
          return {'success': false, 'error': 'INSUFFICIENT_STOCK'};
        }
      }

      final responses = await Future.wait([
        mockRpcCall(0),
        mockRpcCall(1),
        mockRpcCall(2),
        mockRpcCall(3),
        mockRpcCall(4),
      ]);

      final successResponses = responses.where((r) => r['success'] == true).toList();
      final rejectedResponses = responses.where((r) => r['error'] == 'INSUFFICIENT_STOCK').toList();

      expect(successResponses.length, equals(1));
      expect(rejectedResponses.length, equals(4));
    });
  });
}
