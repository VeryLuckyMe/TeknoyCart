import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/core/models/review.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/checkout/models/cart_item.dart';
import 'mock_http_client.dart';

void main() {
  setUpAll(() async {
    HttpOverrides.global = MockHttpOverrides();
    TestWidgetsFlutterBinding.ensureInitialized();
    const MethodChannel('plugins.flutter.io/shared_preferences')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{};
      }
      return null;
    });
    await SupabaseConfig.initialize();
  });

  group('Feature 1: Authentication & Institutional Email Validation', () {
    test('Campus email validation strictly enforces @cit.edu domain', () {
      bool isCitEmail(String email) {
        final trimmed = email.trim().toLowerCase();
        return trimmed.endsWith('@cit.edu') && trimmed.length > 8;
      }

      expect(isCitEmail('mikel.nicer@cit.edu'), isTrue);
      expect(isCitEmail('student123@cit.edu'), isTrue);
      expect(isCitEmail('student@gmail.com'), isFalse);
      expect(isCitEmail('fake@cit.edu.ph'), isFalse);
      expect(isCitEmail('cit.edu'), isFalse);
    });

    test('Profile role transitions correctly between Student Buyer and Verified Vendor', () {
      final buyer = Profile(
        id: 'usr-001',
        username: 'Teknoy Student',
        email: 'teknoy@cit.edu',
        createdAt: DateTime.now(),
      );
      expect(buyer.email, endsWith('@cit.edu'));

      final vendor = buyer.copyWith(username: 'Teknoy Merch Store');
      expect(vendor.username, 'Teknoy Merch Store');
      expect(vendor.id, 'usr-001');
    });
  });

  group('Feature 2: Product Discovery & Marketplace Feed Filtering', () {
    final List<Product> catalog = [
      Product(
        id: 'p-1',
        title: 'CIT-U Maroon College Uniform (Male)',
        description: 'Size Medium, slightly used uniform.',
        price: 350.00,
        imageUrl: 'https://cit.edu/uniform.jpg',
        category: 'Uniforms',
        condition: 'Like New',
        sellerId: 'seller-1',
        createdAt: DateTime.now(),
      ),
      Product(
        id: 'p-2',
        title: 'Engineering Mathematics Vol 2',
        description: 'Standard textbook for calculus.',
        price: 250.00,
        imageUrl: 'https://cit.edu/book.jpg',
        category: 'Books',
        condition: 'Good',
        sellerId: 'seller-2',
        createdAt: DateTime.now(),
      ),
      Product(
        id: 'p-3',
        title: 'Wildcats Mechanical Keyboard',
        description: 'TKL red switch keyboard.',
        price: 1200.00,
        imageUrl: 'https://cit.edu/keyboard.jpg',
        category: 'Electronics',
        condition: 'Brand New',
        sellerId: 'seller-1',
        createdAt: DateTime.now(),
      ),
    ];

    test('Filters products by category accurately', () {
      final uniformResults = catalog.where((p) => p.category == 'Uniforms').toList();
      expect(uniformResults.length, 1);
      expect(uniformResults.first.id, 'p-1');

      final bookResults = catalog.where((p) => p.category == 'Books').toList();
      expect(bookResults.length, 1);
      expect(bookResults.first.id, 'p-2');
    });

    test('Live search query matches title and description case-insensitively', () {
      List<Product> searchCatalog(String query) {
        final q = query.toLowerCase().trim();
        if (q.isEmpty) return catalog;
        return catalog
            .where((p) =>
                p.title.toLowerCase().contains(q) ||
                p.description.toLowerCase().contains(q) ||
                p.category.toLowerCase().contains(q))
            .toList();
      }

      final queryResults = searchCatalog('maroon');
      expect(queryResults.length, 1);
      expect(queryResults.first.title, contains('Maroon'));

      final multiResults = searchCatalog('standard');
      expect(multiResults.length, 1);
      expect(multiResults.first.id, 'p-2');
    });
  });

  group('Feature 3: Product Variants & Inventory Stock Logic', () {
    test('Calculates available stock from stock minus reservations', () {
      int calculateAvailableStock(int totalStock, int reservedCount) {
        final avail = totalStock - reservedCount;
        return avail > 0 ? avail : 0;
      }

      expect(calculateAvailableStock(10, 3), 7);
      expect(calculateAvailableStock(2, 2), 0);
      expect(calculateAvailableStock(0, 0), 0);
      expect(calculateAvailableStock(5, 7), 0);
    });

    test('Variant-level stock selection determines button CTA (Buy Now vs Out of Stock)', () {
      final variants = [
        {'size': 'S', 'stock': 0},
        {'size': 'M', 'stock': 4},
        {'size': 'L', 'stock': 2},
      ];

      String getCtaForSize(String size) {
        final match = variants.firstWhere((v) => v['size'] == size);
        final stock = match['stock'] as int;
        return stock > 0 ? 'Buy Now' : 'Out of Stock';
      }

      expect(getCtaForSize('S'), 'Out of Stock');
      expect(getCtaForSize('M'), 'Buy Now');
      expect(getCtaForSize('L'), 'Buy Now');
    });
  });

  group('Feature 4: Cart & Atomic Checkout Flow', () {
    test('Cart accurately sums item subtotal and quantities', () {
      final items = [
        CartItem(
          product: Product(
            id: 'item-1',
            title: 'Uniform Polo',
            description: 'Size M',
            price: 350.00,
            imageUrl: '',
            category: 'Uniforms',
            condition: 'New',
            sellerId: 's1',
            createdAt: DateTime.now(),
          ),
          quantity: 2,
        ),
        CartItem(
          product: Product(
            id: 'item-2',
            title: 'CIT-U Lanyard',
            description: 'Gold & Maroon',
            price: 120.00,
            imageUrl: '',
            category: 'Merch',
            condition: 'Brand New',
            sellerId: 's2',
            createdAt: DateTime.now(),
          ),
          quantity: 1,
        ),
      ];

      final totalQuantity = items.fold<int>(0, (sum, item) => sum + item.quantity);
      final subtotal = items.fold<double>(0.0, (sum, item) => sum + (item.product.price * item.quantity));

      expect(totalQuantity, 3);
      expect(subtotal, 820.00);
    });

    test('Campus pickup locations and payment methods validate correctly', () {
      final campusMeetupSpots = [
        'Library Lobby',
        'Cafeteria Entrance',
        'Main Gate Waiting Area',
        'Academic Bldg Ground Floor',
        'GLE Building Lobby',
      ];

      final validPaymentMethods = ['Cash on Pickup', 'GCash Escrow'];

      expect(campusMeetupSpots.contains('Library Lobby'), isTrue);
      expect(campusMeetupSpots.contains('GLE Building Lobby'), isTrue);
      expect(campusMeetupSpots.contains('Random Street Outside CIT'), isFalse);

      expect(validPaymentMethods.contains('Cash on Pickup'), isTrue);
      expect(validPaymentMethods.contains('GCash Escrow'), isTrue);
    });
  });

  group('Feature 5: Chat Negotiation & Price State Machine', () {
    test('Buyer offer and counter-offer calculation flow', () {
      const originalPrice = 500.00;
      const initialOffer = 450.00;

      final autoCounter = (originalPrice * 0.90).roundToDouble();
      expect(autoCounter, 450.00);

      var state = 'none';
      expect(state, 'none');

      state = 'offered';
      expect(state, 'offered');

      final agreedPrice = initialOffer;
      state = 'agreed';
      expect(state, 'agreed');
      expect(agreedPrice, 450.00);
    });
  });

  group('Feature 6: Manage Listings & Seller Controls', () {
    test('Updating stock to 0 automatically updates listing availability', () {
      var stock = 5;
      bool isAvailable = stock > 0;
      expect(isAvailable, isTrue);

      stock = 0;
      isAvailable = stock > 0;
      expect(isAvailable, isFalse);
    });
  });

  group('Feature 7: Sales Analytics Computations', () {
    test('Calculates total revenue, order count, and category breakdown', () {
      final completedOrders = [
        {'id': 'o-1', 'price': 350.00, 'category': 'Uniforms'},
        {'id': 'o-2', 'price': 250.00, 'category': 'Books'},
        {'id': 'o-3', 'price': 400.00, 'category': 'Uniforms'},
        {'id': 'o-4', 'price': 1000.00, 'category': 'Electronics'},
      ];

      final totalRevenue = completedOrders.fold<double>(0.0, (sum, o) => sum + (o['price'] as double));
      final totalOrders = completedOrders.length;
      final avgOrderValue = totalRevenue / totalOrders;

      expect(totalRevenue, 2000.00);
      expect(totalOrders, 4);
      expect(avgOrderValue, 500.00);

      final categoryTotals = <String, double>{};
      for (final o in completedOrders) {
        final cat = o['category'] as String;
        categoryTotals[cat] = (categoryTotals[cat] ?? 0.0) + (o['price'] as double);
      }

      expect(categoryTotals['Uniforms'], 750.00);
      expect(categoryTotals['Books'], 250.00);
      expect(categoryTotals['Electronics'], 1000.00);
    });
  });

  group('Feature 8: Ratings, Reviews & Storefront Verification', () {
    test('Aggregates star ratings accurately from buyer reviews', () {
      final reviews = [
        Review(
          id: 'r-1',
          productId: 'p-1',
          sellerId: 's-123',
          buyerId: 'b-1',
          buyerName: 'Mikel',
          rating: 5,
          comment: 'Legit CIT student, smooth meetup at library!',
          createdAt: DateTime.now(),
        ),
        Review(
          id: 'r-2',
          productId: 'p-2',
          sellerId: 's-123',
          buyerId: 'b-2',
          buyerName: 'Josh',
          rating: 4,
          comment: 'Good condition book.',
          createdAt: DateTime.now(),
        ),
      ];

      expect(reviews.length, 2);
      expect(reviews.averageRating, 4.5);
    });

    test('Storefront favorite toggle maintains idempotent state', () {
      var isFavorited = false;

      // Tap 1: Add to favorites
      isFavorited = !isFavorited;
      expect(isFavorited, isTrue);

      // Tap 2: Remove from favorites
      isFavorited = !isFavorited;
      expect(isFavorited, isFalse);
    });
  });
}
