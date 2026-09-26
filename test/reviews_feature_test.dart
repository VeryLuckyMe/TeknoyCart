import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/core/models/review.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/feed/providers/review_provider.dart';
import 'package:teknoycart/features/feed/views/widgets/product_reviews_section.dart';
import 'package:teknoycart/features/feed/views/widgets/review_submission_sheet.dart';
import 'package:teknoycart/features/feed/views/widgets/buyer_reviews_sheet.dart';
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

  group('Review Model & Extension Tests', () {
    test('Review serialization to and from JSON', () {
      final now = DateTime.now();
      final review = Review(
        id: 'rev-test-1',
        orderId: 'ord-123',
        productId: 'prod-1',
        buyerId: 'usr-buyer',
        buyerName: 'John Doe',
        sellerId: 'usr-seller',
        rating: 5,
        comment: 'Excellent condition!',
        tags: const ['Item as described', 'Fast meetup'],
        imageUrls: const ['https://example.com/item.jpg'],
        variantName: 'Size: 33',
        isAnonymous: false,
        createdAt: now,
      );

      final json = review.toJson();
      expect(json['review_id'], 'rev-test-1');
      expect(json['rating'], 5);
      expect(json['is_anonymous'], isFalse);

      final parsed = Review.fromJson(json);
      expect(parsed.id, review.id);
      expect(parsed.buyerName, review.buyerName);
      expect(parsed.displayName, 'John Doe');
      expect(parsed.rating, 5);
      expect(parsed.tags, containsAll(['Item as described', 'Fast meetup']));
      expect(parsed.variantName, 'Size: 33');
    });

    test('Anonymous review masks student name correctly', () {
      final review = Review(
        id: 'rev-anon',
        productId: 'prod-1',
        buyerId: 'usr-buyer',
        buyerName: 'Secret Student',
        sellerId: 'usr-seller',
        rating: 4,
        comment: 'Great transaction',
        isAnonymous: true,
        createdAt: DateTime.now(),
      );

      expect(review.displayName, 'Wildcat Student (Verified Buyer)');
      expect(review.displayInitial, 'W');
    });

    test('Review list extension computes averageRating and distribution accurately', () {
      final reviews = [
        Review(
          id: '1',
          productId: 'p',
          buyerId: 'b',
          buyerName: 'User',
          sellerId: 's',
          rating: 5,
          comment: 'c',
          createdAt: DateTime.now(),
        ),
        Review(
          id: '2',
          productId: 'p',
          buyerId: 'b',
          buyerName: 'User',
          sellerId: 's',
          rating: 4,
          comment: 'c',
          createdAt: DateTime.now(),
        ),
        Review(
          id: '3',
          productId: 'p',
          buyerId: 'b',
          buyerName: 'User',
          sellerId: 's',
          rating: 5,
          comment: 'c',
          createdAt: DateTime.now(),
        ),
      ];

      expect(reviews.averageRating, 4.7);
      final dist = reviews.ratingDistribution;
      expect(dist[5], 2);
      expect(dist[4], 1);
      expect(dist[3], 0);
    });
  });

  group('Reviews Riverpod Provider & State Management Tests', () {
    test('ReviewsNotifier loads initial seed reviews and filters by product', () {
      final container = ProviderContainer();
      final prod1Reviews = container.read(reviewsForProductProvider('prod-1'));

      expect(prod1Reviews.isNotEmpty, isTrue);
      expect(prod1Reviews.every((r) => r.productId == 'prod-1'), isTrue);
    });

    test('ReviewsNotifier can submit new review, update it, and allow seller reply', () async {
      final container = ProviderContainer();
      final notifier = container.read(reviewsNotifierProvider.notifier);

      // 1. Submit review
      final newRev = await notifier.submitReview(
        orderId: 'ord-unit-test-1',
        productId: 'prod-unit-test',
        buyerId: 'buyer-unit-1',
        buyerName: 'Hannah Montana',
        sellerId: 'seller-unit-1',
        rating: 5,
        comment: 'Met up at CIT canteen on time. Perfect shorts size 33!',
        tags: ['Fast meetup', 'Accurate sizing'],
        variantName: 'Size: 33',
        isAnonymous: false,
      );

      final productReviews = container.read(reviewsForProductProvider('prod-unit-test'));
      expect(productReviews.length, 1);
      expect(productReviews.first.comment, contains('size 33'));

      // Check order review lookup
      final orderRev = container.read(orderReviewProvider('ord-unit-test-1'));
      expect(orderRev, isNotNull);
      expect(orderRev!.rating, 5);

      // 2. Update review
      await notifier.updateReview(
        newRev.id,
        rating: 4,
        comment: 'Updated: Actually minor loose thread, but overall great.',
        tags: ['Accurate sizing'],
      );

      final updatedReviews = container.read(reviewsForProductProvider('prod-unit-test'));
      expect(updatedReviews.first.rating, 4);
      expect(updatedReviews.first.comment, contains('Updated:'));

      // 3. Seller reply
      await notifier.replyToReview(newRev.id, 'Thanks for your feedback Hannah!');
      final repliedReviews = container.read(reviewsForProductProvider('prod-unit-test'));
      expect(repliedReviews.first.hasReply, isTrue);
      expect(repliedReviews.first.sellerReply, 'Thanks for your feedback Hannah!');
    });
  });

  group('Reviews UI Component Tests', () {
    final testProduct = Product(
      id: 'prod-1',
      title: 'Engineering Calculus Textbook',
      description: 'Stewart 9th Edition',
      price: 450.0,
      category: 'Books',
      condition: 'Like New',
      sellerId: 'usr-seller',
      createdAt: DateTime.now(),
    );

    testWidgets('ProductReviewsSection renders rating summary, distribution, and reviews', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProductReviewsSection(product: testProduct),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Ratings & Reviews'), findsOneWidget);

      // Verify Verified purchase badge
      expect(find.text('Verified'), findsWidgets);

      // Verify Seller response indicator on seed review 1
      expect(find.text('Seller Response'), findsWidgets);
    });

    testWidgets('ReviewSubmissionSheet renders star rating, tags, and comment field', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReviewSubmissionSheet(
                productId: 'prod-1',
                productTitle: 'Engineering Calculus Textbook',
                sellerId: 'usr-seller',
                variantName: 'Size: 33',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header & Title
      expect(find.text('Rate & Review Order'), findsOneWidget);
      expect(find.text('Engineering Calculus Textbook'), findsOneWidget);

      // Verify Variant badge
      expect(find.text('Purchased: Size: 33'), findsOneWidget);

      // Verify Preset Tags
      expect(find.text('Item as described'), findsOneWidget);
      expect(find.text('Accurate sizing'), findsOneWidget);
      expect(find.text('Fast meetup'), findsOneWidget);

      // Verify Anonymous toggle
      expect(find.text('Post Anonymously'), findsOneWidget);

      // Verify Publish button
      expect(find.text('Publish Review'), findsOneWidget);
    });

    testWidgets('BuyerReviewsSheet renders buyer reviews, rating distribution, and verified badges', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: BuyerReviewsSheet(
                sellerId: 'usr-seller',
                sellerName: 'Wildcat Store',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Buyer Reviews'), findsOneWidget);
      expect(find.text('Ratings & feedback for Wildcat Store'), findsOneWidget);

      // Verify Verified Buyer tags
      expect(find.text('Verified Buyer'), findsWidgets);

      // Verify Seller Response exists for seed review
      expect(find.text('Seller Response'), findsWidgets);
    });
  });
}
