import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/core/models/review.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/checkout/views/order_detail_view.dart';
import 'package:teknoycart/features/feed/providers/review_provider.dart';
import 'package:teknoycart/features/feed/views/widgets/product_reviews_section.dart';
import 'package:teknoycart/features/feed/views/widgets/review_submission_sheet.dart';
import 'package:teknoycart/features/feed/views/widgets/buyer_reviews_sheet.dart';
import 'mock_http_client.dart';

void main() {
  late MockHttpOverrides mockHttp;

  setUpAll(() async {
    mockHttp = MockHttpOverrides();
    HttpOverrides.global = mockHttp;
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
    test('ReviewsNotifier starts empty when demo seeding is off', () {
      final container = ProviderContainer();

      // Demo seeding is opt-in via --dart-define=DEMO_MODE=true; the default
      // test/runtime state is an honest, empty review list.
      expect(container.read(reviewsNotifierProvider), isEmpty);
    });

    test('ReviewsNotifier loads seed reviews in demo mode and filters by product', () {
      final container = ProviderContainer(
        overrides: [
          reviewsNotifierProvider.overrideWith((ref) => ReviewsNotifier(seedDemo: true)),
        ],
      );
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

    test('publishing a review uses INSERT and adopts the database id', () async {
      // The insert response carries the generated review_id; the local state
      // must keep it so edits and seller replies target the real row.
      mockHttp.productReviewInsertBody = '{"review_id": "rev-db-1"}';
      addTearDown(() => mockHttp.productReviewInsertBody = null);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(reviewsNotifierProvider.notifier);

      final saved = await notifier.submitReview(
        orderId: 'ord-db-id-test',
        productId: 'prod-db-id-test',
        buyerId: 'buyer-db-id-test',
        buyerName: 'Database Id Tester',
        sellerId: 'seller-db-id-test',
        rating: 5,
        comment: 'First review for this completed order.',
      );

      expect(saved.id, 'rev-db-1');
      expect(
        container.read(orderReviewProvider('ord-db-id-test'))?.id,
        'rev-db-1',
      );

      // A PostgREST upsert would send Prefer: resolution=merge-duplicates and
      // require UPDATE grants that P0 intentionally withholds.
      expect(mockHttp.lastReviewWriteMethod, 'POST');
      expect(
        mockHttp.lastReviewWriteUrl?.path,
        endsWith('/rest/v1/product_reviews'),
      );
      expect(
        mockHttp.lastReviewWritePrefer,
        contains('return=representation'),
      );
      expect(
        mockHttp.lastReviewWritePrefer,
        isNot(contains('merge-duplicates')),
      );
    });

    test('Multiple reviews for the same product across different orders are both preserved', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(reviewsNotifierProvider.notifier);

      // Order 1 review
      await notifier.submitReview(
        orderId: 'ord-repeat-1',
        productId: 'prod-repeat-test',
        buyerId: 'buyer-repeat-user',
        buyerName: 'Harvey Valmera',
        sellerId: 'seller-repeat-user',
        rating: 5,
        comment: 'First purchase review',
        tags: ['Item as described'],
      );

      // Order 2 review for the same product by the same buyer
      await notifier.submitReview(
        orderId: 'ord-repeat-2',
        productId: 'prod-repeat-test',
        buyerId: 'buyer-repeat-user',
        buyerName: 'Harvey Valmera',
        sellerId: 'seller-repeat-user',
        rating: 5,
        comment: 'Second purchase review - solid repeat purchase',
        tags: ['Fast meetup'],
      );

      final productReviews = container.read(reviewsForProductProvider('prod-repeat-test'));
      expect(productReviews.length, 2);
      expect(productReviews.any((r) => r.orderId == 'ord-repeat-1'), isTrue);
      expect(productReviews.any((r) => r.orderId == 'ord-repeat-2'), isTrue);
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
          overrides: [
            reviewsNotifierProvider.overrideWith((ref) => ReviewsNotifier(seedDemo: true)),
          ],
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
        ProviderScope(
          overrides: [
            reviewsNotifierProvider.overrideWith((ref) => ReviewsNotifier(seedDemo: true)),
          ],
          child: const MaterialApp(
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

    testWidgets('Seller order detail shows buyer review and reply action, never buyer edit controls', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final seller = Profile(
        id: 'usr-seller',
        username: 'Wildcat Store',
        email: 'seller@cit.edu',
        role: 'SELLER',
        isSellerVerified: true,
        createdAt: DateTime.now(),
      );

      final order = <String, dynamic>{
        'order_id': 'ord-mock-1',
        'status': 'COMPLETED',
        'total_amount': '450.00',
        'payment_method': 'CASH_ON_PICKUP',
        'buyer_id': 'usr-buyer-sample',
        'seller_id': 'usr-seller',
        'buyer_name': 'Marc Lopez',
        'seller_name': 'Wildcat Store',
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewsNotifierProvider.overrideWith((ref) => ReviewsNotifier(seedDemo: true)),
            authStateProvider.overrideWith((ref) => AsyncValue.data(seller)),
          ],
          child: MaterialApp(
            home: OrderDetailView(order: order, isSeller: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Buyer rated this'), findsOneWidget);
      expect(find.text('Edit Reply'), findsOneWidget);
      expect(find.textContaining('You rated this'), findsNothing);
      expect(find.text('Rate & Review Order'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Edit'), findsNothing);

      await tester.tap(find.text('Edit Reply'));
      await tester.pumpAndSettle();
      expect(find.text('Seller Response'), findsOneWidget);
      expect(find.text('Publish Reply'), findsOneWidget);
    });

    testWidgets('Buyer order detail keeps the existing review edit controls', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final buyer = Profile(
        id: 'usr-buyer-sample',
        username: 'Marc Lopez',
        email: 'buyer@cit.edu',
        role: 'BUYER',
        isSellerVerified: false,
        createdAt: DateTime.now(),
      );

      final order = <String, dynamic>{
        'order_id': 'ord-mock-1',
        'status': 'COMPLETED',
        'total_amount': '450.00',
        'payment_method': 'CASH_ON_PICKUP',
        'buyer_id': 'usr-buyer-sample',
        'seller_id': 'usr-seller',
        'buyer_name': 'Marc Lopez',
        'seller_name': 'Wildcat Store',
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewsNotifierProvider.overrideWith((ref) => ReviewsNotifier(seedDemo: true)),
            authStateProvider.overrideWith((ref) => AsyncValue.data(buyer)),
          ],
          child: MaterialApp(
            home: OrderDetailView(order: order, isSeller: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('You rated this'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Edit'), findsOneWidget);
      expect(find.textContaining('Buyer rated this'), findsNothing);
      expect(find.text('Edit Reply'), findsNothing);
    });
  });
}
