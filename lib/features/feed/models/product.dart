import 'package:flutter/foundation.dart';

@immutable
class Product {
  final String id;
  final String title;
  final String description;
  final double price;
  final String? imageUrl;
  final String category;
  final String condition; // e.g., 'New', 'Like New', 'Gently Used', 'Fair'
  final String sellerId;
  final DateTime createdAt;

  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.category,
    required this.condition,
    required this.sellerId,
    required this.createdAt,
  });

  /// Factory constructor to create a Product from a Supabase/PostgreSQL JSON object.
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'] as String?,
      category: json['category'] as String,
      condition: json['condition'] as String,
      sellerId: json['seller_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Converts the Product instance into a JSON map for database writes.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'image_url': imageUrl,
      'category': category,
      'condition': condition,
      'seller_id': sellerId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Creates a copy of the Product with modified fields, preserving immutability.
  Product copyWith({
    String? id,
    String? title,
    String? description,
    double? price,
    String? imageUrl,
    String? category,
    String? condition,
    String? sellerId,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      condition: condition ?? this.condition,
      sellerId: sellerId ?? this.sellerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          price == other.price &&
          imageUrl == other.imageUrl &&
          category == other.category &&
          condition == other.condition &&
          sellerId == other.sellerId &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      description.hashCode ^
      price.hashCode ^
      imageUrl.hashCode ^
      category.hashCode ^
      condition.hashCode ^
      sellerId.hashCode ^
      createdAt.hashCode;
}
