import 'package:flutter/foundation.dart';

@immutable
class Order {
  final String id;
  final String productId;
  final String buyerId;
  final String sellerId;
  final double agreedPrice; // Reflects peer-to-peer price agreements & negotiations
  final String pickupLocation; // e.g., 'Canteen', 'Library Lobby', 'Science Building'
  final String status; // e.g., 'Pending', 'Agreed', 'Completed', 'Cancelled'
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.productId,
    required this.buyerId,
    required this.sellerId,
    required this.agreedPrice,
    required this.pickupLocation,
    required this.status,
    required this.createdAt,
  });

  /// Factory constructor to create an Order from a Supabase/PostgreSQL JSON object.
  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      buyerId: json['buyer_id'] as String,
      sellerId: json['seller_id'] as String,
      agreedPrice: (json['agreed_price'] as num).toDouble(),
      pickupLocation: json['pickup_location'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Converts the Order instance into a JSON map for database writes.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'agreed_price': agreedPrice,
      'pickup_location': pickupLocation,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Creates a copy of the Order with modified fields, preserving immutability.
  Order copyWith({
    String? id,
    String? productId,
    String? buyerId,
    String? sellerId,
    double? agreedPrice,
    String? pickupLocation,
    String? status,
    DateTime? createdAt,
  }) {
    return Order(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      buyerId: buyerId ?? this.buyerId,
      sellerId: sellerId ?? this.sellerId,
      agreedPrice: agreedPrice ?? this.agreedPrice,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Order &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          productId == other.productId &&
          buyerId == other.buyerId &&
          sellerId == other.sellerId &&
          agreedPrice == other.agreedPrice &&
          pickupLocation == other.pickupLocation &&
          status == other.status &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      productId.hashCode ^
      buyerId.hashCode ^
      sellerId.hashCode ^
      agreedPrice.hashCode ^
      pickupLocation.hashCode ^
      status.hashCode ^
      createdAt.hashCode;
}
