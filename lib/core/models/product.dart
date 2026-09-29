import 'package:flutter/foundation.dart';

/// Represents a single category-specific attribute (e.g. "Size": "Medium" or "Size": "S, M, L")
@immutable
class ProductAttribute {
  final String name;
  final String value;

  const ProductAttribute({required this.name, required this.value});

  /// Canonical size rank for apparel sorting (XS/S first, XL/XXL last)
  static int sizeRank(String size) {
    final s = size.trim().toUpperCase();
    const standardRanks = {
      'XXS': 1,
      'XS': 2,
      'S': 3,
      'SMALL': 3,
      'M': 4,
      'MED': 4,
      'MEDIUM': 4,
      'L': 5,
      'LARGE': 5,
      'XL': 6,
      'EXTRA LARGE': 6,
      'XXL': 7,
      '2XL': 7,
      'XXXL': 8,
      '3XL': 8,
      '4XL': 9,
      '5XL': 10,
    };
    if (standardRanks.containsKey(s)) {
      return standardRanks[s]!;
    }
    final numVal = int.tryParse(s);
    if (numVal != null) {
      return 100 + numVal; // e.g. 28 -> 128, 30 -> 130
    }
    if (s == 'FREE SIZE' || s == 'FREESIZE' || s == 'ONE SIZE') {
      return 999;
    }
    return 500;
  }

  /// Returns individual option values when multiple variants are listed (e.g. "S, M, L" -> ["S", "M", "L"])
  List<String> get options {
    if (value.isEmpty) return const [];
    final delimiter = value.contains(',')
        ? ','
        : (value.contains('·') ? '·' : null);
    if (delimiter == null) {
      return [value.trim()];
    }
    final list = value
        .split(delimiter)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (name.trim().toLowerCase() == 'size') {
      list.sort((a, b) => sizeRank(a).compareTo(sizeRank(b)));
    }
    return list;
  }

  factory ProductAttribute.fromJson(Map<String, dynamic> json) {
    return ProductAttribute(
      name: json['name'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'value': value};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductAttribute &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          value == other.value;

  @override
  int get hashCode => name.hashCode ^ value.hashCode;
}

/// Represents a category attribute template (defines what attributes a category supports)
@immutable
class CategoryAttributeTemplate {
  final String name;
  final String type; // 'text' or 'select'
  final String placeholder;
  final List<String> options; // Only for 'select' type
  final bool isMultiSelect; // Whether multiple options can be selected (e.g. multiple sizes in stock)

  const CategoryAttributeTemplate({
    required this.name,
    required this.type,
    required this.placeholder,
    this.options = const [],
    this.isMultiSelect = false,
  });

  factory CategoryAttributeTemplate.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    final rawOptions = (json['options'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final isColor = name.trim().toLowerCase() == 'color';
    final options = isColor
        ? rawOptions.where((o) => o.trim().toLowerCase() != 'other').toList()
        : rawOptions;
    return CategoryAttributeTemplate(
      name: name,
      type: json['type'] as String? ?? 'text',
      placeholder: json['placeholder'] as String? ?? '',
      options: options,
      isMultiSelect: json['is_multi_select'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'placeholder': placeholder,
        if (options.isNotEmpty) 'options': options,
        if (isMultiSelect) 'is_multi_select': true,
      };
}

@immutable
class Product {
  final String id;
  final String title;
  final String description;
  final double price;
  final String? imageUrl;
  final List<String> imageUrls;
  final String category;
  final String condition; // e.g., 'New', 'Like New', 'Gently Used', 'Fair'
  final String sellerId;
  final String? sellerStoreName;
  final bool isPreorderEnabled;
  final DateTime createdAt;
  final List<ProductAttribute> categoryAttributes;

  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.imageUrl,
    this.imageUrls = const [],
    required this.category,
    required this.condition,
    required this.sellerId,
    this.sellerStoreName,
    this.isPreorderEnabled = false,
    required this.createdAt,
    this.categoryAttributes = const [],
  });

  /// Factory constructor to create a Product from a Supabase/PostgreSQL JSON object.
  factory Product.fromJson(Map<String, dynamic> json) {
    // Parse category_attributes from JSONB
    List<ProductAttribute> attrs = [];
    if (json['category_attributes'] != null) {
      final rawAttrs = json['category_attributes'];
      if (rawAttrs is List) {
        final parsed = rawAttrs
            .whereType<Map<String, dynamic>>()
            .map((a) => ProductAttribute.fromJson(a))
            .where((a) => a.name.isNotEmpty && a.value.isNotEmpty)
            .toList();
        final seen = <String>{};
        attrs = [];
        for (final a in parsed) {
          final key = a.name.trim().toLowerCase();
          if (seen.add(key)) {
            attrs.add(a);
          }
        }
      }
    }

    // Parse multi-image URLs if present
    List<String> parsedImages = [];
    if (json['image_urls'] is List) {
      parsedImages = (json['image_urls'] as List).map((e) => e.toString()).toList();
    } else if (json['product_images'] is List) {
      final rawList = json['product_images'] as List;
      for (final item in rawList) {
        if (item is Map && item['image_url'] != null) {
          parsedImages.add(item['image_url'].toString());
        } else if (item is String && item.isNotEmpty) {
          parsedImages.add(item);
        }
      }
    }

    final singleImg = json['image_url'] as String?;
    if (parsedImages.isEmpty && singleImg != null && singleImg.isNotEmpty) {
      parsedImages = [singleImg];
    }

    return Product(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      imageUrl: singleImg ?? (parsedImages.isNotEmpty ? parsedImages.first : null),
      imageUrls: parsedImages,
      category: json['category'] as String,
      condition: json['condition'] as String,
      sellerId: json['seller_id'] as String,
      sellerStoreName: json['seller_store_name'] as String?,
      isPreorderEnabled: json['is_preorder_enabled'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      categoryAttributes: attrs,
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
      'image_urls': imageUrls,
      'category': category,
      'condition': condition,
      'seller_id': sellerId,
      'seller_store_name': sellerStoreName,
      'is_preorder_enabled': isPreorderEnabled,
      'created_at': createdAt.toIso8601String(),
      'category_attributes':
          categoryAttributes.map((a) => a.toJson()).toList(),
    };
  }

  /// Creates a copy of the Product with modified fields, preserving immutability.
  Product copyWith({
    String? id,
    String? title,
    String? description,
    double? price,
    String? imageUrl,
    List<String>? imageUrls,
    String? category,
    String? condition,
    String? sellerId,
    String? sellerStoreName,
    bool? isPreorderEnabled,
    DateTime? createdAt,
    List<ProductAttribute>? categoryAttributes,
  }) {
    return Product(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      category: category ?? this.category,
      condition: condition ?? this.condition,
      sellerId: sellerId ?? this.sellerId,
      sellerStoreName: sellerStoreName ?? this.sellerStoreName,
      isPreorderEnabled: isPreorderEnabled ?? this.isPreorderEnabled,
      createdAt: createdAt ?? this.createdAt,
      categoryAttributes: categoryAttributes ?? this.categoryAttributes,
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
          listEquals(imageUrls, other.imageUrls) &&
          category == other.category &&
          condition == other.condition &&
          sellerId == other.sellerId &&
          sellerStoreName == other.sellerStoreName &&
          isPreorderEnabled == other.isPreorderEnabled &&
          createdAt == other.createdAt &&
          listEquals(categoryAttributes, other.categoryAttributes);

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      description.hashCode ^
      price.hashCode ^
      imageUrl.hashCode ^
      imageUrls.hashCode ^
      category.hashCode ^
      condition.hashCode ^
      sellerId.hashCode ^
      sellerStoreName.hashCode ^
      isPreorderEnabled.hashCode ^
      createdAt.hashCode ^
      categoryAttributes.hashCode;
}
