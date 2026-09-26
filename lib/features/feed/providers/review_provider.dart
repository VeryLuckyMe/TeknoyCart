import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/models/review.dart';
import 'package:teknoycart/core/supabase_client.dart';

/// Notifier managing all customer reviews in TeknoyCart
class ReviewsNotifier extends StateNotifier<List<Review>> {
  ReviewsNotifier() : super(_initialMockReviews) {
    _loadFromSupabase();
  }

  /// Initial sample reviews for seed products to provide rich UI/UX out of the box
  static final List<Review> _initialMockReviews = [
    Review(
      id: 'rev-seed-1',
      orderId: 'ord-mock-1',
      productId: 'prod-1', // Engineering Calculus
      buyerId: 'usr-buyer-sample',
      buyerName: 'Marc Lopez',
      sellerId: 'usr-seller',
      rating: 5,
      comment: 'Book is in mint condition! Calculus formulas are super clear, no missing pages or highlights. Met up at CIT-U library on time.',
      tags: const ['Item as described', 'Fast meetup', 'Friendly seller'],
      variantName: 'Condition: Like New',
      sellerReply: 'Thank you Marc! Good luck on your midterm exams! Wildcat pride 🐾',
      sellerRepliedAt: DateTime.now().subtract(const Duration(days: 2)),
      isAnonymous: false,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    Review(
      id: 'rev-seed-2',
      orderId: 'ord-mock-2',
      productId: 'prod-1',
      buyerId: 'usr-buyer-anon',
      buyerName: 'CIT Student',
      sellerId: 'usr-seller',
      rating: 5,
      comment: 'Very accommodating seller! Handed over right after my 3PM class at Main Building.',
      tags: const ['Fast meetup', 'Would buy again'],
      variantName: 'Condition: Like New',
      isAnonymous: true,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    Review(
      id: 'rev-seed-3',
      orderId: 'ord-mock-3',
      productId: 'prod-2', // CIT-U PE Uniform
      buyerId: 'usr-buyer-sample2',
      buyerName: 'Alyssa Mae Ramos',
      sellerId: 'usr-seller-2',
      rating: 5,
      comment: 'Size Medium fits perfectly! Fabric is fresh and CIT maroon color is vibrant. Salamat kaayo!',
      tags: const ['Accurate sizing', 'Item as described', 'Great quality'],
      variantName: 'Size: M',
      sellerReply: 'Glad you loved the fit Alyssa! Enjoy PE class! 😊',
      sellerRepliedAt: DateTime.now().subtract(const Duration(days: 1)),
      isAnonymous: false,
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
    Review(
      id: 'rev-seed-4',
      orderId: 'ord-mock-4',
      productId: 'prod-3', // Engineering Drawing Compass Set
      buyerId: 'usr-buyer-sample3',
      buyerName: 'John Carlo Tan',
      sellerId: 'usr-seller',
      rating: 4,
      comment: 'Good Staedtler compass. Case has minor scratches as mentioned in description, but instruments are 100% accurate.',
      tags: const ['Item as described', 'Friendly seller'],
      variantName: 'Condition: Good',
      isAnonymous: false,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
  ];

  Future<void> _loadFromSupabase() async {
    try {
      final response = await SupabaseConfig.client
          .from('product_reviews')
          .select('*')
          .order('created_at', ascending: false);

      final rows = response as List<dynamic>;
      if (rows.isNotEmpty) {
        final dbReviews = rows
            .map((r) => Review.fromJson(r as Map<String, dynamic>))
            .toList();

        // Merge with current state (preserving any newly submitted reviews or seed reviews)
        final Set<String> existingIds = dbReviews.map((r) => r.id).toSet();
        final Set<String> existingOrderBuyer = dbReviews
            .where((r) => r.orderId != null)
            .map((r) => '${r.orderId}_${r.buyerId}')
            .toSet();

        final preserved = state.where((r) =>
            !existingIds.contains(r.id) &&
            !existingOrderBuyer.contains('${r.orderId}_${r.buyerId}')).toList();

        state = [...dbReviews, ...preserved];
      }
    } catch (_) {
      // Keep resilient initial mock reviews if Supabase table is not yet created
    }
  }

  /// Submit a new review for an order and product
  Future<Review> submitReview({
    String? orderId,
    required String productId,
    required String buyerId,
    required String buyerName,
    required String sellerId,
    required int rating,
    required String comment,
    List<String> tags = const [],
    List<String> imageUrls = const [],
    String? variantName,
    bool isAnonymous = false,
  }) async {
    final reviewId = 'rev-${DateTime.now().millisecondsSinceEpoch}';
    final newReview = Review(
      id: reviewId,
      orderId: orderId,
      productId: productId,
      buyerId: buyerId,
      buyerName: buyerName,
      sellerId: sellerId,
      rating: rating,
      comment: comment,
      tags: tags,
      imageUrls: imageUrls,
      variantName: variantName,
      isAnonymous: isAnonymous,
      createdAt: DateTime.now(),
    );

    // Update state immediately (optimistic UI)
    // Replace if existing review for this order/buyer, else prepend
    final existingIndex = state.indexWhere((r) =>
        (orderId != null && r.orderId == orderId) ||
        (r.productId == productId && r.buyerId == buyerId));

    if (existingIndex >= 0) {
      final updatedList = List<Review>.from(state);
      updatedList[existingIndex] = newReview;
      state = updatedList;
    } else {
      state = [newReview, ...state];
    }

    // Persist to Supabase if available
    try {
      await SupabaseConfig.client.from('product_reviews').upsert({
        'order_id': orderId,
        'product_id': productId,
        'buyer_id': buyerId,
        'buyer_name': buyerName,
        'seller_id': sellerId,
        'rating': rating,
        'comment': comment,
        'tags': tags,
        'image_urls': imageUrls,
        'variant_name': variantName,
        'is_anonymous': isAnonymous,
        'created_at': newReview.createdAt.toIso8601String(),
      });
    } catch (_) {
      // Retain optimistic state if offline or table not yet migrated
    }

    return newReview;
  }

  /// Update an existing review
  Future<void> updateReview(
    String reviewId, {
    required int rating,
    required String comment,
    List<String> tags = const [],
    List<String> imageUrls = const [],
    bool isAnonymous = false,
  }) async {
    final index = state.indexWhere((r) => r.id == reviewId);
    if (index < 0) return;

    final old = state[index];
    final updated = old.copyWith(
      rating: rating,
      comment: comment,
      tags: tags,
      imageUrls: imageUrls,
      isAnonymous: isAnonymous,
      updatedAt: DateTime.now(),
    );

    final updatedList = List<Review>.from(state);
    updatedList[index] = updated;
    state = updatedList;

    try {
      await SupabaseConfig.client.from('product_reviews').update({
        'rating': rating,
        'comment': comment,
        'tags': tags,
        'image_urls': imageUrls,
        'is_anonymous': isAnonymous,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('review_id', reviewId);
    } catch (_) {
      // Optimistic update retained
    }
  }

  /// Seller posts an official reply to a buyer's review
  Future<void> replyToReview(String reviewId, String replyText) async {
    final trimmed = replyText.trim();
    if (trimmed.isEmpty) return;

    final index = state.indexWhere((r) => r.id == reviewId);
    if (index < 0) return;

    final now = DateTime.now();
    final updated = state[index].copyWith(
      sellerReply: trimmed,
      sellerRepliedAt: now,
    );

    final updatedList = List<Review>.from(state);
    updatedList[index] = updated;
    state = updatedList;

    try {
      await SupabaseConfig.client.from('product_reviews').update({
        'seller_reply': trimmed,
        'seller_replied_at': now.toIso8601String(),
      }).eq('review_id', reviewId);
    } catch (_) {
      // Optimistic update retained
    }
  }
}

/// Global provider for reviews
final reviewsNotifierProvider =
    StateNotifierProvider<ReviewsNotifier, List<Review>>((ref) {
  return ReviewsNotifier();
});

/// Reviews filtered by product ID
final reviewsForProductProvider =
    Provider.family<List<Review>, String>((ref, productId) {
  final allReviews = ref.watch(reviewsNotifierProvider);
  return allReviews.where((r) => r.productId == productId).toList();
});

/// Reviews filtered by seller ID (for seller storefront)
final reviewsForSellerProvider =
    Provider.family<List<Review>, String>((ref, sellerId) {
  final allReviews = ref.watch(reviewsNotifierProvider);
  return allReviews.where((r) => r.sellerId == sellerId).toList();
});

/// Checks if an order has been reviewed
final orderReviewProvider =
    Provider.family<Review?, String>((ref, orderId) {
  final allReviews = ref.watch(reviewsNotifierProvider);
  try {
    return allReviews.firstWhere((r) => r.orderId == orderId);
  } catch (_) {
    return null;
  }
});

/// Rating summary for a specific product
final productRatingSummaryProvider =
    Provider.family<({double average, int total, Map<int, int> distribution}), String>((ref, productId) {
  final productReviews = ref.watch(reviewsForProductProvider(productId));
  return (
    average: productReviews.averageRating,
    total: productReviews.length,
    distribution: productReviews.ratingDistribution,
  );
});

/// Store rating summary for a seller
final sellerRatingSummaryProvider =
    Provider.family<({double average, int total}), String>((ref, sellerId) {
  final sellerReviews = ref.watch(reviewsForSellerProvider(sellerId));
  return (
    average: sellerReviews.averageRating,
    total: sellerReviews.length,
  );
});
