import 'package:teknoycart/core/utils/safe_cast.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/models/product.dart';

/// Abstract contract for Product data operations isolating Postgrest calls from UI notifiers.
abstract class IProductRepository {
  Future<List<Product>> fetchActiveProducts();
  Future<Map<String, List<CategoryAttributeTemplate>>> fetchCategoryAttributeTemplates();
}

/// Concrete Supabase implementation of [IProductRepository].
class ProductRepository implements IProductRepository {
  final SupabaseClient _client;

  ProductRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  static const _categoryIdToName = {
    1: 'Books',
    2: 'Drawing Tools',
    3: 'Uniforms',
    4: 'Electronics',
    5: 'Others',
    6: 'Food & Beverages',
    7: 'School Supplies',
    8: 'Services',
    9: 'Clothes',
  };

  @override
  Future<Map<String, List<CategoryAttributeTemplate>>> fetchCategoryAttributeTemplates() async {
    final response = await _client
        .from('categories')
        .select('category_id, category_name, attribute_templates');
    final rows = SafeCast.toListOfMaps(response);

    final Map<String, List<CategoryAttributeTemplate>> result = {};
    for (final row in rows) {
      final categoryName =
          row['category_name'] as String? ?? row['name'] as String? ?? '';
      final rawTemplates = row['attribute_templates'];
      if (categoryName.isNotEmpty && rawTemplates != null) {
        List<dynamic> list;
        if (rawTemplates is String) {
          try {
            list = jsonDecode(rawTemplates) as List<dynamic>;
          } catch (_) {
            list = [];
          }
        } else if (rawTemplates is List) {
          list = rawTemplates;
        } else {
          list = [];
        }
        result[categoryName] = list
            .whereType<Map<String, dynamic>>()
            .map((t) => CategoryAttributeTemplate.fromJson(t))
            .toList();
      }
    }
    return result;
  }

  @override
  Future<List<Product>> fetchActiveProducts() async {
    final response = await _client
        .from('products')
        .select('''
          id,
          title,
          description,
          price,
          condition,
          status,
          is_preorder_enabled,
          category_id,
          category_attributes,
          seller_id,
          created_at,
          product_images (
            image_url,
            is_primary
          ),
          product_variants (
            variant_id,
            variant_value,
            inventory (
              stock_qty
            )
          )
        ''')
        .eq('status', 'ACTIVE')
        .order('created_at', ascending: false);

    final rows = SafeCast.toListOfMaps(response);
    if (rows.isEmpty) return [];

    return rows.map((row) {
      final images = (row['product_images'] as List<dynamic>?) ?? [];
      String imageUrl = '';
      List<String> imageUrls = [];
      if (images.isNotEmpty) {
        final sortedImages = List<Map<String, dynamic>>.from(
          images.whereType<Map<String, dynamic>>(),
        );
        sortedImages.sort((a, b) {
          final aPrim = a['is_primary'] == true ? 1 : 0;
          final bPrim = b['is_primary'] == true ? 1 : 0;
          return bPrim.compareTo(aPrim);
        });
        imageUrls = sortedImages
            .map((img) => img['image_url'] as String? ?? '')
            .where((url) => url.isNotEmpty)
            .toList();
        imageUrl = imageUrls.isNotEmpty ? imageUrls.first : '';
      }

      final catId = row['category_id'] as int? ?? 5;
      final category = _categoryIdToName[catId] ?? 'Others';

      final usersMap = row['users'] as Map<String, dynamic>?;
      String storeName = '';
      if (usersMap != null) {
        final storeProfiles = usersMap['store_profiles'];
        if (storeProfiles is Map<String, dynamic>) {
          storeName = storeProfiles['store_name'] as String? ?? '';
        } else if (storeProfiles is List && storeProfiles.isNotEmpty) {
          final firstProfile = storeProfiles[0];
          if (firstProfile is Map<String, dynamic>) {
            storeName = firstProfile['store_name'] as String? ?? '';
          }
        }
        if (storeName.isEmpty) {
          storeName = usersMap['full_name'] as String? ?? '';
        }
      }

      List<ProductAttribute> categoryAttributes = [];
      final rawAttrs = row['category_attributes'];
      if (rawAttrs != null) {
        List<dynamic> attrList;
        if (rawAttrs is String) {
          try {
            attrList = jsonDecode(rawAttrs) as List<dynamic>;
          } catch (_) {
            attrList = [];
          }
        } else if (rawAttrs is List) {
          attrList = rawAttrs;
        } else {
          attrList = [];
        }
        categoryAttributes = attrList
            .whereType<Map<String, dynamic>>()
            .map((a) => ProductAttribute.fromJson(a))
            .where((a) => a.name.isNotEmpty && a.value.isNotEmpty)
            .toList();
      }

      return Product(
        id: row['id'] as String,
        title: row['title'] as String,
        description: row['description'] as String? ?? '',
        price: (row['price'] as num?)?.toDouble() ?? 0.0,
        imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
        imageUrls: imageUrls,
        category: category,
        condition: row['condition'] as String? ?? 'Good',
        sellerId: row['seller_id'] as String? ?? '',
        sellerStoreName: storeName.isNotEmpty ? storeName : null,
        isPreorderEnabled: row['is_preorder_enabled'] as bool? ?? false,
        createdAt: row['created_at'] != null
            ? DateTime.parse(row['created_at'] as String)
            : DateTime.now(),
        categoryAttributes: categoryAttributes,
      );
    }).toList();
  }
}

/// Provider exposing the repository interface to Riverpod consumers.
final productRepositoryProvider = Provider<IProductRepository>((ref) {
  return ProductRepository();
});

