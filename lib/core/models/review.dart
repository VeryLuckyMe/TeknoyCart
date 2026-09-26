import 'package:flutter/foundation.dart';

/// Represents a customer rating and review for a purchased product in TeknoyCart
@immutable
class Review {
  final String id;
  final String? orderId;
  final String productId;
  final String buyerId;
  final String buyerName;
  final String sellerId;
  final int rating; // 1 to 5
  final String comment;
  final List<String> tags; // e.g. ["Item as described", "Accurate sizing"]
  final List<String> imageUrls;
  final String? variantName; // e.g. "Size 33, Black"
  final String? sellerReply;
  final DateTime? sellerRepliedAt;
  final bool isAnonymous;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Review({
    required this.id,
    this.orderId,
    required this.productId,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.rating,
    required this.comment,
    this.tags = const [],
    this.imageUrls = const [],
    this.variantName,
    this.sellerReply,
    this.sellerRepliedAt,
    this.isAnonymous = false,
    required this.createdAt,
    this.updatedAt,
  });

  /// Name displayed in UI: masked if user chose anonymity
  String get displayName {
    if (isAnonymous) {
      return 'Wildcat Student (Verified Buyer)';
    }
    return buyerName.isNotEmpty ? buyerName : 'Wildcat Student';
  }

  /// Initial for avatar display
  String get displayInitial {
    if (isAnonymous) return 'W';
    if (buyerName.isEmpty) return 'U';
    return buyerName[0].toUpperCase();
  }

  bool get hasReply => sellerReply != null && sellerReply!.trim().isNotEmpty;
  bool get hasSellerReply => hasReply;
  String get effectiveBuyerName => displayName;

  Review copyWith({
    String? id,
    String? orderId,
    String? productId,
    String? buyerId,
    String? buyerName,
    String? sellerId,
    int? rating,
    String? comment,
    List<String>? tags,
    List<String>? imageUrls,
    String? variantName,
    String? sellerReply,
    DateTime? sellerRepliedAt,
    bool? isAnonymous,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Review(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      buyerId: buyerId ?? this.buyerId,
      buyerName: buyerName ?? this.buyerName,
      sellerId: sellerId ?? this.sellerId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      tags: tags ?? this.tags,
      imageUrls: imageUrls ?? this.imageUrls,
      variantName: variantName ?? this.variantName,
      sellerReply: sellerReply ?? this.sellerReply,
      sellerRepliedAt: sellerRepliedAt ?? this.sellerRepliedAt,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Review.fromJson(Map<String, dynamic> json) {
    // Parse tags list safely
    List<String> parsedTags = [];
    final rawTags = json['tags'];
    if (rawTags is List) {
      parsedTags = rawTags.map((e) => e.toString()).toList();
    }

    // Parse images list safely
    List<String> parsedImages = [];
    final rawImages = json['image_urls'] ?? json['imageUrls'];
    if (rawImages is List) {
      parsedImages = rawImages.map((e) => e.toString()).toList();
    }

    DateTime parsedCreated;
    final rawCreated = json['created_at'] ?? json['createdAt'];
    if (rawCreated is String) {
      parsedCreated = DateTime.tryParse(rawCreated) ?? DateTime.now();
    } else {
      parsedCreated = DateTime.now();
    }

    DateTime? parsedRepliedAt;
    final rawReplied = json['seller_replied_at'] ?? json['sellerRepliedAt'];
    if (rawReplied is String) {
      parsedRepliedAt = DateTime.tryParse(rawReplied);
    }

    DateTime? parsedUpdated;
    final rawUpdated = json['updated_at'] ?? json['updatedAt'];
    if (rawUpdated is String) {
      parsedUpdated = DateTime.tryParse(rawUpdated);
    }

    return Review(
      id: json['review_id'] as String? ?? json['id'] as String? ?? '',
      orderId: json['order_id'] as String? ?? json['orderId'] as String?,
      productId: json['product_id'] as String? ?? json['productId'] as String? ?? '',
      buyerId: json['buyer_id'] as String? ?? json['buyerId'] as String? ?? '',
      buyerName: json['buyer_name'] as String? ?? json['buyerName'] as String? ?? 'CIT Student',
      sellerId: json['seller_id'] as String? ?? json['sellerId'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      comment: json['comment'] as String? ?? '',
      tags: parsedTags,
      imageUrls: parsedImages,
      variantName: json['variant_name'] as String? ?? json['variantName'] as String?,
      sellerReply: json['seller_reply'] as String? ?? json['sellerReply'] as String?,
      sellerRepliedAt: parsedRepliedAt,
      isAnonymous: json['is_anonymous'] as bool? ?? json['isAnonymous'] as bool? ?? false,
      createdAt: parsedCreated,
      updatedAt: parsedUpdated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'review_id': id,
      if (orderId != null) 'order_id': orderId,
      'product_id': productId,
      'buyer_id': buyerId,
      'buyer_name': buyerName,
      'seller_id': sellerId,
      'rating': rating,
      'comment': comment,
      'tags': tags,
      'image_urls': imageUrls,
      if (variantName != null) 'variant_name': variantName,
      if (sellerReply != null) 'seller_reply': sellerReply,
      if (sellerRepliedAt != null) 'seller_replied_at': sellerRepliedAt!.toIso8601String(),
      'is_anonymous': isAnonymous,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Review &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          orderId == other.orderId &&
          productId == other.productId &&
          buyerId == other.buyerId &&
          sellerId == other.sellerId &&
          rating == other.rating &&
          comment == other.comment &&
          sellerReply == other.sellerReply &&
          isAnonymous == other.isAnonymous &&
          listEquals(tags, other.tags) &&
          listEquals(imageUrls, other.imageUrls);

  @override
  int get hashCode =>
      id.hashCode ^
      orderId.hashCode ^
      productId.hashCode ^
      buyerId.hashCode ^
      sellerId.hashCode ^
      rating.hashCode ^
      comment.hashCode ^
      sellerReply.hashCode ^
      isAnonymous.hashCode ^
      tags.hashCode ^
      imageUrls.hashCode;
}

/// Helper extension for rating statistics calculation
extension ReviewListExtension on List<Review> {
  double get averageRating {
    if (isEmpty) return 0.0;
    final total = fold<int>(0, (sum, r) => sum + r.rating);
    return (total / length * 10).roundToDouble() / 10;
  }

  Map<int, int> get ratingDistribution {
    final dist = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in this) {
      if (dist.containsKey(r.rating)) {
        dist[r.rating] = (dist[r.rating] ?? 0) + 1;
      }
    }
    return dist;
  }
}
