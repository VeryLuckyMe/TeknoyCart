import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/core/config/api_config.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/models/product.dart';

// ── Static filter providers ──
final categoriesProvider = Provider<List<String>>((ref) => [
      'All',
      'Books',
      'Drawing Tools',
      'Uniforms',
      'Clothes',
      'Electronics',
      'Food & Beverages',
      'School Supplies',
      'Services',
      'Others',
    ]);

/// Seller category list (excludes 'All' filter option)
final sellCategoriesProvider = Provider<List<String>>((ref) => [
      'Books',
      'Drawing Tools',
      'Uniforms',
      'Clothes',
      'Electronics',
      'Food & Beverages',
      'School Supplies',
      'Services',
      'Others',
    ]);

final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<String>((ref) => 'All');
final selectedConditionProvider = StateProvider<String>((ref) => 'All');
final minPriceProvider = StateProvider<double?>((ref) => null);
final maxPriceProvider = StateProvider<double?>((ref) => null);

/// Sort options shared by the Browse tab and the search results screen.
enum ProductSortOption {
  recommended('Recommended'),
  newest('Newest First'),
  priceLowHigh('Price: Low to High'),
  priceHighLow('Price: High to Low');

  const ProductSortOption(this.label);

  final String label;
}

final sortOptionProvider =
    StateProvider<ProductSortOption>((ref) => ProductSortOption.recommended);

// ── Category ID mapping from Supabase schema ──
const _categoryIdToName = {
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

const _categoryNameToId = {
  'Books': 1,
  'Drawing Tools': 2,
  'Uniforms': 3,
  'Electronics': 4,
  'Others': 5,
  'Food & Beverages': 6,
  'School Supplies': 7,
  'Services': 8,
  'Clothes': 9,
};

/// Provides the category name→ID map for use in the sell form
final categoryNameToIdProvider = Provider<Map<String, int>>((ref) => _categoryNameToId);

// ── Category Attribute Templates Provider ──
// Fetches attribute templates from the categories table in Supabase.
// Fallback hardcoded templates used when Supabase is unreachable.
final categoryAttributeTemplatesProvider =
    FutureProvider<Map<String, List<CategoryAttributeTemplate>>>((ref) async {
  try {
    final response = await SupabaseConfig.client
        .from('categories')
        .select('category_id, category_name, attribute_templates');
    final rows = response as List<dynamic>;

    final Map<String, List<CategoryAttributeTemplate>> result = {};
    for (final row in rows) {
      final categoryName = row['category_name'] as String? ?? row['name'] as String? ?? '';
      final rawTemplates = row['attribute_templates'];
      if (categoryName.isNotEmpty && rawTemplates != null) {
        List<dynamic> templateList;
        if (rawTemplates is String) {
          templateList = jsonDecode(rawTemplates) as List<dynamic>;
        } else if (rawTemplates is List) {
          templateList = rawTemplates;
        } else {
          continue;
        }
        result[categoryName] = templateList
            .whereType<Map<String, dynamic>>()
            .map((t) => CategoryAttributeTemplate.fromJson(t))
            .toList();
      }
    }
    if (result.isEmpty) {
      return _fallbackTemplates;
    }
    // Merge any missing categories from fallback templates for maximum resilience
    for (final entry in _fallbackTemplates.entries) {
      result.putIfAbsent(entry.key, () => entry.value);
    }
    return result;
  } catch (e) {
    // Fallback hardcoded templates when Supabase is unavailable
    return _fallbackTemplates;
  }
});

/// Hardcoded fallback templates matching the SQL migration
const Map<String, List<CategoryAttributeTemplate>> _fallbackTemplates = {
  'Books': [
    CategoryAttributeTemplate(name: 'Subject', type: 'text', placeholder: 'e.g. Calculus, Physics'),
    CategoryAttributeTemplate(name: 'Author', type: 'text', placeholder: 'e.g. James Stewart'),
    CategoryAttributeTemplate(name: 'Edition', type: 'text', placeholder: 'e.g. 9th Edition'),
    CategoryAttributeTemplate(name: 'ISBN', type: 'text', placeholder: 'e.g. 978-1-285-74062-1'),
  ],
  'Drawing Tools': [
    CategoryAttributeTemplate(name: 'Brand', type: 'text', placeholder: 'e.g. Staedtler, Faber-Castell'),
    CategoryAttributeTemplate(name: 'Set Size', type: 'text', placeholder: 'e.g. 12-piece, 24-piece'),
    CategoryAttributeTemplate(
      name: 'Type',
      type: 'select',
      placeholder: 'Select type',
      options: ['Pencil Set', 'Drawing Board', 'T-Square', 'Compass Set', 'Triangle Set', 'Eraser Set', 'Marker Set', 'Complete Kit'],
    ),
  ],
  'Uniforms': [
    CategoryAttributeTemplate(
      name: 'Size',
      type: 'select',
      placeholder: 'Select size(s)',
      options: [
        'XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL',
        '26', '28', '30', '32', '34', '36',
      ],
      isMultiSelect: true,
    ),
    CategoryAttributeTemplate(
      name: 'Uniform Type',
      type: 'select',
      placeholder: 'Select type',
      options: ['PE Uniform', 'School Uniform', 'Department Shirt', 'Lab Gown', 'OJT Attire', 'Event Shirt'],
    ),
    CategoryAttributeTemplate(
      name: 'Gender',
      type: 'select',
      placeholder: 'Select fit',
      options: ['Unisex', 'Male', 'Female'],
    ),
  ],
  'Clothes': [
    CategoryAttributeTemplate(
      name: 'Clothing Type',
      type: 'select',
      placeholder: 'Select type (T-Shirt, Shorts, Jorts, etc.)',
      options: [
        'T-Shirt',
        'Shorts',
        'Jorts',
        'Pants / Jeans',
        'Hoodie / Jacket',
        'Polo / Collared Shirt',
        'Skirt / Dress',
        'Joggers / Sweatpants',
        'Tank Top / Sando',
        'Other',
      ],
    ),
    CategoryAttributeTemplate(
      name: 'Size',
      type: 'select',
      placeholder: 'Select size(s)',
      options: [
        'XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL',
        '28', '29', '30', '31', '32', '33', '34', '36', '38',
        'Free Size',
      ],
      isMultiSelect: true,
    ),
    CategoryAttributeTemplate(
      name: 'Color',
      type: 'select',
      placeholder: 'Select color(s)',
      options: [
        'Black',
        'White',
        'Gray',
        'Denim Blue',
        'Navy Blue',
        'Maroon',
        'Beige / Khaki',
        'Brown',
        'Green',
        'Red',
      ],
      isMultiSelect: true,
    ),
    CategoryAttributeTemplate(
      name: 'Gender / Fit',
      type: 'select',
      placeholder: 'Select fit',
      options: ['Unisex', 'Men', 'Women'],
    ),
    CategoryAttributeTemplate(
      name: 'Brand',
      type: 'text',
      placeholder: 'e.g. Uniqlo, H&M, Cotton On, Thrifted',
    ),
  ],
  'Electronics': [
    CategoryAttributeTemplate(name: 'Brand', type: 'text', placeholder: 'e.g. Casio, HP, Logitech'),
    CategoryAttributeTemplate(name: 'Model', type: 'text', placeholder: 'e.g. fx-991ES Plus'),
    CategoryAttributeTemplate(name: 'Specs', type: 'text', placeholder: 'e.g. 16GB RAM, 512GB SSD'),
    CategoryAttributeTemplate(
      name: 'Warranty',
      type: 'select',
      placeholder: 'Select warranty',
      options: ['No Warranty', '1 Month', '3 Months', '6 Months', '1 Year'],
    ),
    CategoryAttributeTemplate(name: 'Accessories Included', type: 'text', placeholder: 'e.g. Charger, Case, Cable'),
  ],
  'Food & Beverages': [
    CategoryAttributeTemplate(
      name: 'Type',
      type: 'select',
      placeholder: 'Select type',
      options: ['Snack', 'Beverage', 'Meal Prep', 'Baked Goods', 'Homemade', 'Instant Food', 'Condiments'],
    ),
    CategoryAttributeTemplate(name: 'Flavor/Variant', type: 'text', placeholder: 'e.g. Chocolate, Vanilla, Spicy'),
    CategoryAttributeTemplate(name: 'Allergens', type: 'text', placeholder: 'e.g. Contains nuts, dairy-free'),
    CategoryAttributeTemplate(name: 'Expiry Date', type: 'text', placeholder: 'e.g. 2026-12-31'),
    CategoryAttributeTemplate(name: 'Serving Size', type: 'text', placeholder: 'e.g. 250ml, 6 pieces'),
  ],
  'School Supplies': [
    CategoryAttributeTemplate(
      name: 'Type',
      type: 'select',
      placeholder: 'Select type',
      options: ['Notebook', 'Folder', 'Binder', 'Index Cards', 'Sticky Notes', 'Paper', 'Art Materials', 'Lab Equipment', 'Stationery Set'],
    ),
    CategoryAttributeTemplate(name: 'Brand', type: 'text', placeholder: 'e.g. Pilot, Muji, Cattleya'),
    CategoryAttributeTemplate(name: 'Size/Specification', type: 'text', placeholder: 'e.g. A4, Legal, 200 pages'),
    CategoryAttributeTemplate(name: 'Pack Quantity', type: 'text', placeholder: 'e.g. 3-pack, 12 pieces'),
  ],
  'Services': [
    CategoryAttributeTemplate(
      name: 'Service Type',
      type: 'select',
      placeholder: 'Select service type',
      options: ['Tutoring', 'Printing', 'Design', 'Programming Help', 'Thesis Binding', 'Photo/Video', 'Delivery', 'Other'],
    ),
    CategoryAttributeTemplate(name: 'Duration', type: 'text', placeholder: 'e.g. 1 hour, per session'),
    CategoryAttributeTemplate(name: 'Availability', type: 'text', placeholder: 'e.g. Mon-Fri 3PM-6PM'),
  ],
  'Others': [
    CategoryAttributeTemplate(name: 'Type', type: 'text', placeholder: 'e.g. Snack, Beverage, Meal Prep'),
    CategoryAttributeTemplate(name: 'Quantity/Weight', type: 'text', placeholder: 'e.g. 500g, 6 pieces, 1 liter'),
  ],
};

/// Defines which attribute names are primary (featured as 1-tap chips outside the accordion)
const Map<String, List<String>> primaryCategoryAttributeNames = {
  'Books': ['Subject'],
  'Drawing Tools': ['Type'],
  'Uniforms': ['Uniform Type', 'Size'],
  'Clothes': ['Clothing Type', 'Size'],
  'Electronics': ['Brand'],
  'Food & Beverages': ['Type', 'Flavor/Variant'],
  'School Supplies': ['Type'],
  'Services': ['Service Type'],
  'Others': ['Type'],
};

/// Popular campus quick suggestions for primary text attributes
const Map<String, Map<String, List<String>>> primaryAttributeQuickSuggestions = {
  'Books': {
    'Subject': [
      'Calculus',
      'Physics',
      'Eng. Math',
      'CS / IT',
      'Chemistry',
      'Accounting',
      'General Education',
    ],
  },
  'Electronics': {
    'Brand': [
      'Casio',
      'Canon',
      'HP',
      'Logitech',
      'Apple',
      'Asus',
      'Acer',
      'Lenovo',
      'Xiaomi',
    ],
  },
  'Food & Beverages': {
    'Flavor/Variant': [
      'Classic',
      'Chocolate',
      'Cheese',
      'Spicy',
      'Sweet',
      'Salted',
    ],
  },
};

// ── Local cache (fallback for offline resilience) ──
class ProductCacheService {
  List<Product>? _cachedProducts;

  List<Product>? getLocalCache() => _cachedProducts;

  void saveToLocalCache(List<Product> products) {
    _cachedProducts = List.from(products);
  }
}

final productCacheServiceProvider = Provider<ProductCacheService>((ref) {
  return ProductCacheService();
});

/// Bundled sample products — served only with --dart-define=DEMO_MODE=true (see [ApiConfig.demoMode]).
final List<Product> _fallbackProducts = [
  Product(
    id: 'prod-1',
    title: 'Engineering Drawing Table',
    description:
        'Official CIT-U drawing board with adjustable stands. Very clean, lightly used for one semester.',
    price: 450.00,
    imageUrl:
        'https://images.unsplash.com/photo-1513542789411-b6a5d4f31634?w=600&auto=format&fit=crop',
    category: 'Drawing Tools',
    condition: 'Like New',
    sellerId: 'demo-1',
    sellerStoreName: 'CEA Drawing Board Shop',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    categoryAttributes: const [
      ProductAttribute(name: 'Brand', value: 'Staedtler'),
      ProductAttribute(name: 'Type', value: 'Drawing Board'),
    ],
  ),
  Product(
    id: 'prod-2',
    title: 'CIT-U PE Uniform (Medium)',
    description:
        'Complete set of official CIT-U physical education uniform. Unisex design, medium size.',
    price: 250.00,
    imageUrl:
        'https://images.unsplash.com/photo-1578587018452-892bacefd3f2?w=600&auto=format&fit=crop',
    category: 'Uniforms',
    condition: 'Gently Used',
    sellerId: 'demo-2',
    sellerStoreName: 'Wildcat Threads',
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    categoryAttributes: const [
      ProductAttribute(name: 'Size', value: 'M'),
      ProductAttribute(name: 'Uniform Type', value: 'PE Uniform'),
      ProductAttribute(name: 'Gender', value: 'Unisex'),
    ],
  ),
  Product(
    id: 'prod-3',
    title: 'BSCS Data Structures Book',
    description:
        'Data Structures and Algorithms in Java, 6th Edition. Super helpful for second-year CS subjects.',
    price: 180.00,
    imageUrl:
        'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=600&auto=format&fit=crop',
    category: 'Books',
    condition: 'New',
    sellerId: 'demo-3',
    sellerStoreName: 'CS Book Depot',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    categoryAttributes: const [
      ProductAttribute(name: 'Subject', value: 'Computer Science'),
      ProductAttribute(name: 'Author', value: 'Michael T. Goodrich'),
      ProductAttribute(name: 'Edition', value: '6th Edition'),
    ],
  ),
  Product(
    id: 'prod-4',
    title: 'Scientific Calculator (991ES Plus)',
    description:
        'Casio Scientific Calculator, perfect for Engineering and Math courses. All buttons working.',
    price: 350.00,
    imageUrl:
        'https://images.unsplash.com/photo-1629909613654-28e377c37b09?w=600&auto=format&fit=crop',
    category: 'Electronics',
    condition: 'Gently Used',
    sellerId: 'demo-1',
    sellerStoreName: 'CEA Drawing Board Shop',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    categoryAttributes: const [
      ProductAttribute(name: 'Brand', value: 'Casio'),
      ProductAttribute(name: 'Model', value: 'fx-991ES Plus'),
      ProductAttribute(name: 'Warranty', value: 'No Warranty'),
    ],
  ),
  Product(
    id: 'prod-5',
    title: 'Fresh Baked Choco Chip Cookies (Box of 6)',
    description:
        'Freshly baked artisan chocolate chip cookies made by CIT-U Hospitality students. Warm and soft-baked.',
    price: 120.00,
    imageUrl:
        'https://images.unsplash.com/photo-1509722747041-616f39b57569?w=600&auto=format&fit=crop',
    category: 'Food & Beverages',
    condition: 'New',
    sellerId: 'demo-4',
    sellerStoreName: 'Teknoy Sweet Bites',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    categoryAttributes: const [
      ProductAttribute(name: 'Type', value: 'Baked Goods'),
      ProductAttribute(name: 'Flavor/Variant', value: 'Chocolate Chip'),
      ProductAttribute(name: 'Allergens', value: 'Contains dairy, wheat'),
      ProductAttribute(name: 'Serving Size', value: '6 pieces'),
    ],
  ),
  Product(
    id: 'prod-6',
    title: 'Pilot G-Tec-C3 Gel Pen Set (Black/Blue)',
    description:
        'Original Pilot G-Tec-C 0.3mm ultra-fine point gel ink pens. Perfect for technical sketching and clean notes.',
    price: 165.00,
    imageUrl:
        'https://images.unsplash.com/photo-1456735190827-d1262f71b8a3?w=600&auto=format&fit=crop',
    category: 'School Supplies',
    condition: 'New',
    sellerId: 'demo-5',
    sellerStoreName: 'Wildcat Stationery Hub',
    createdAt: DateTime.now().subtract(const Duration(hours: 8)),
    categoryAttributes: const [
      ProductAttribute(name: 'Type', value: 'Stationery Set'),
      ProductAttribute(name: 'Brand', value: 'Pilot'),
      ProductAttribute(name: 'Size/Specification', value: '0.3mm Ultra Fine'),
      ProductAttribute(name: 'Pack Quantity', value: '3-pack'),
    ],
  ),
  Product(
    id: 'prod-7',
    title: 'Baggy Denim Jorts (Vintage Wash)',
    description:
        'Trendy streetwear wide-leg denim jorts. High-quality denim with deep pockets, perfect campus casual style.',
    price: 320.00,
    imageUrl:
        'https://images.unsplash.com/photo-1489987707025-afc232f7ea0f?w=600&auto=format&fit=crop',
    category: 'Clothes',
    condition: 'Like New',
    sellerId: 'demo-2',
    sellerStoreName: 'Wildcat Threads',
    createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    categoryAttributes: const [
      ProductAttribute(name: 'Clothing Type', value: 'Jorts'),
      ProductAttribute(name: 'Size', value: 'L'),
      ProductAttribute(name: 'Color', value: 'Denim Blue'),
      ProductAttribute(name: 'Gender / Fit', value: 'Unisex'),
    ],
  ),
];

/// Notifier that fetches products from Supabase with local fallback.
class ProductListNotifier
    extends StateNotifier<AsyncValue<List<Product>>> {
  final ProductCacheService _cacheService;
  final SupabaseClient _supabase;

  ProductListNotifier(this._cacheService, this._supabase)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      // Check if cache is available first for instant UI
      final cached = _cacheService.getLocalCache();
      if (cached != null && cached.isNotEmpty) {
        state = AsyncValue.data(cached);
      }

      // Fetch live products from Supabase with graceful fallback if unauthenticated RLS restricts users join
      dynamic response;
      try {
        response = await _supabase
            .from('products')
            .select('''
              product_id,
              name,
              description,
              base_price,
              status,
              is_preorder_enabled,
              category_id,
              category_attributes,
              seller_id,
              created_at,
              users (
                full_name,
                store_profiles (
                  store_name
                )
              ),
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
      } catch (joinErr) {
        debugPrint('PRODUCTS_FETCH_JOIN_RESTRICTED: Falling back to direct products query without users join ($joinErr)');
        response = await _supabase
            .from('products')
            .select('''
              product_id,
              name,
              description,
              base_price,
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
      }

      final rows = response as List<dynamic>;

      if (rows.isEmpty) {
        // Legitimate empty database — return empty list so clean empty state displays (Ponytail Audit M2)
        _cacheService.saveToLocalCache([]);
        state = const AsyncValue.data([]);
        return;
      }

      final products = rows.map((row) {
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

        if (imageUrl.isEmpty) {
          // Pick the best available image from Unsplash based on category
          imageUrl = _categoryImage(category);
          imageUrls = [imageUrl];
        }

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

        // Parse category_attributes from JSONB
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
          id: row['product_id'] as String,
          title: row['name'] as String? ?? 'Untitled Product',
          description: row['description'] as String? ?? '',
          price: double.tryParse(row['base_price'].toString()) ?? 0,
          imageUrl: imageUrl,
          imageUrls: imageUrls,
          category: category,
          condition: row['condition'] as String? ??
              (categoryAttributes.any((a) => a.name.toLowerCase() == 'condition')
                  ? categoryAttributes.firstWhere((a) => a.name.toLowerCase() == 'condition').value
                  : 'Like New'),
          sellerId: row['seller_id'] as String? ?? '',
          sellerStoreName: storeName,
          isPreorderEnabled: row['is_preorder_enabled'] as bool? ?? false,
          createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
              DateTime.now(),
          categoryAttributes: categoryAttributes,
        );
      }).toList();

      _cacheService.saveToLocalCache(products);
      state = AsyncValue.data(products);
    } catch (e, st) {
      // Network/DB error — serve the last real result from cache when available.
      // Bundled sample products are only used with --dart-define=DEMO_MODE=true;
      // otherwise the feed shows its honest offline/error state.
      final local = _cacheService.getLocalCache();
      if (local != null && local.isNotEmpty) {
        state = AsyncValue.data(local);
      } else if (ApiConfig.demoMode) {
        _cacheService.saveToLocalCache(_fallbackProducts);
        state = AsyncValue.data(List.from(_fallbackProducts));
      } else {
        debugPrint('PRODUCTS_FETCH_FAILED: $e');
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// Adds a new product optimistically to the local state and inserts into Supabase.
  Future<void> addProduct(
    Product product, {
    Map<String, int>? variantStocks,
    int totalStock = 1,
  }) async {
    // Update local state immediately for instant feedback
    state.whenData((list) {
      state = AsyncValue.data([product, ...list]);
    });

    try {
      int categoryId = _categoryNameToId[product.category] ?? 5;
      try {
        final catRow = await _supabase
            .from('categories')
            .select('category_id')
            .eq('category_name', product.category)
            .maybeSingle();
        if (catRow != null && catRow['category_id'] != null) {
          categoryId = (catRow['category_id'] as num).toInt();
        }
      } catch (e) { debugPrint('PRODUCT_CATEGORY_LOOKUP: $e'); }

      // 1. Insert product (including category_attributes with graceful fallback)
      final insertPayload = <String, dynamic>{
        'name': product.title,
        'description': product.description,
        'base_price': product.price,
        'category_id': categoryId,
        'seller_id': product.sellerId,
        'status': 'ACTIVE',
        if (product.categoryAttributes.isNotEmpty)
          'category_attributes': product.categoryAttributes
              .map((a) => a.toJson())
              .toList(),
      };

      Map<String, dynamic> inserted;
      try {
        inserted = await _supabase.from('products').insert(insertPayload).select().single();
      } catch (err) {
        // Fallback for backward compatibility if the database column does not exist yet
        if (err.toString().contains('category_attributes')) {
          insertPayload.remove('category_attributes');
          inserted = await _supabase.from('products').insert(insertPayload).select().single();
        } else {
          rethrow;
        }
      }

      final String dbProductId = inserted['product_id'] as String;

      // 1b. Insert product images if uploaded (supporting multiple gallery photos)
      final allImagesToInsert = <String>[];
      if (product.imageUrls.isNotEmpty) {
        allImagesToInsert.addAll(product.imageUrls);
      } else if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
        allImagesToInsert.add(product.imageUrl!);
      }

      for (int i = 0; i < allImagesToInsert.length; i++) {
        final imgUrl = allImagesToInsert[i];
        if (imgUrl.isNotEmpty) {
          // Retry with exponential backoff for unreliable campus WiFi (HIGH-07)
          bool imageInserted = false;
          for (int attempt = 0; attempt < 3 && !imageInserted; attempt++) {
            try {
              await _supabase.from('product_images').insert({
                'product_id': dbProductId,
                'image_url': imgUrl,
                'is_primary': i == 0,
              });
              imageInserted = true;
            } catch (e) {
              if (attempt < 2) {
                await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
              } else {
                debugPrint('PRODUCT_IMAGE_INSERT: Failed after 3 attempts for image $i: $e');
              }
            }
          }
        }
      }

      // 2. Create product variants (supporting combination matrix and individual options)
      bool anyVariantCreated = false;

      if (variantStocks != null && variantStocks.isNotEmpty) {
        int index = 0;
        for (final entry in variantStocks.entries) {
          final combo = entry.key;
          final targetStock = entry.value;
          final cleanCombo = combo.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
          final safeProd = dbProductId.length >= 6 ? dbProductId.substring(0, 6) : dbProductId;
          final catPrefix = product.category.substring(0, product.category.length < 3 ? product.category.length : 3).toUpperCase();
          final timestampSuffix = DateTime.now().millisecondsSinceEpoch % 10000;
          final sku = 'SKU-$catPrefix-${safeProd.toUpperCase()}-$cleanCombo-$timestampSuffix-$index';
          index++;

          try {
            final insertedVariant = await _supabase.from('product_variants').insert({
              'product_id': dbProductId,
              'variant_name': combo.contains(' / ') ? 'Variation' : 'Size',
              'variant_value': combo,
              'additional_price': 0,
              'sku': sku,
            }).select().maybeSingle();

            if (insertedVariant != null && insertedVariant['variant_id'] != null) {
              final String dbVariantId = insertedVariant['variant_id'] as String;
              anyVariantCreated = true;

              await _supabase.from('inventory').insert({
                'variant_id': dbVariantId,
                'stock_qty': targetStock >= 0 ? targetStock : 0,
                'reserved_qty': 0,
                'low_stock_threshold': 1,
              }).catchError((_) {});
            }
          } catch (vErr) {
            debugPrint("Failed to insert variant $combo: $vErr");
          }
        }
      }

      // 4. Guarantee at least 1 default variant & inventory record if no variants were created
      if (!anyVariantCreated) {
        try {
          final safeProd = dbProductId.length >= 8 ? dbProductId.substring(0, 8) : dbProductId;
          final fallbackSku = 'SKU-${safeProd.toUpperCase()}-DEFAULT-${DateTime.now().millisecondsSinceEpoch % 10000}';
          final fallbackVar = await _supabase.from('product_variants').insert({
            'product_id': dbProductId,
            'variant_name': 'Standard',
            'variant_value': product.condition.isNotEmpty ? product.condition : 'Default',
            'additional_price': 0,
            'sku': fallbackSku,
          }).select().maybeSingle();

          if (fallbackVar != null && fallbackVar['variant_id'] != null) {
            final String fallbackVarId = fallbackVar['variant_id'] as String;
            await _supabase.from('inventory').insert({
              'variant_id': fallbackVarId,
              'stock_qty': totalStock > 0 ? totalStock : 1,
              'reserved_qty': 0,
              'low_stock_threshold': 1,
            }).catchError((_) {});
          }
        } catch (fErr) {
          debugPrint("Fallback variant creation error: $fErr");
        }
      }

      // Reload fresh list to sync generated database UUIDs
      await _load();
    } catch (e) {
      // Revert local state by reloading cache on failure
      await _load();
      rethrow;
    }
  }

  /// Refresh from Supabase
  Future<void> refresh() => _load();

  /// Returns a relevant Unsplash image for a given category.
  static String _categoryImage(String category) {
    switch (category) {
      case 'Books':
        return 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=600&auto=format&fit=crop';
      case 'Drawing Tools':
        return 'https://images.unsplash.com/photo-1513542789411-b6a5d4f31634?w=600&auto=format&fit=crop';
      case 'Uniforms':
        return 'https://images.unsplash.com/photo-1578587018452-892bacefd3f2?w=600&auto=format&fit=crop';
      case 'Clothes':
        return 'https://images.unsplash.com/photo-1489987707025-afc232f7ea0f?w=600&auto=format&fit=crop';
      case 'Electronics':
        return 'https://images.unsplash.com/photo-1629909613654-28e377c37b09?w=600&auto=format&fit=crop';
      case 'Food & Beverages':
        return 'https://images.unsplash.com/photo-1509722747041-616f39b57569?w=600&auto=format&fit=crop';
      case 'School Supplies':
        return 'https://images.unsplash.com/photo-1456735190827-d1262f71b8a3?w=600&auto=format&fit=crop';
      case 'Services':
        return 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=600&auto=format&fit=crop';
      default:
        return 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=600&auto=format&fit=crop';
    }
  }
}

final productsListNotifierProvider =
    StateNotifierProvider<ProductListNotifier, AsyncValue<List<Product>>>((ref) {
  final cache = ref.watch(productCacheServiceProvider);
  final supabase = SupabaseConfig.client;
  return ProductListNotifier(cache, supabase);
});

final productsListProvider = FutureProvider<List<Product>>((ref) async {
  final asyncVal = ref.watch(productsListNotifierProvider);
  return asyncVal.when(
    data: (data) => data,
    loading: () async {
      await Future.delayed(const Duration(milliseconds: 100));
      return ref.read(productsListNotifierProvider).value ?? [];
    },
    error: (err, _) => throw err,
  );
});

/// Pure filter + sort pipeline shared by the Browse tab, the search results
/// screen and the unit tests. Keeps every surface consistent (Ponytail H-high).
List<Product> applyProductFilters(
  List<Product> products, {
  required String search,
  required String category,
  required String condition,
  required double? minPrice,
  required double? maxPrice,
  required ProductSortOption sort,
}) {
  final query = search.trim().toLowerCase();

  final result = products.where((product) {
    // Search across title, description, store name, category AND attributes
    final matchesSearch = query.isEmpty ||
        product.title.toLowerCase().contains(query) ||
        product.description.toLowerCase().contains(query) ||
        product.category.toLowerCase().contains(query) ||
        (product.sellerStoreName?.toLowerCase().contains(query) ?? false) ||
        product.categoryAttributes.any((attr) =>
            attr.name.toLowerCase().contains(query) ||
            attr.value.toLowerCase().contains(query));
    final matchesCategory = category == 'All' || product.category == category;
    final matchesCondition = condition == 'All' ||
        product.condition.toLowerCase() == condition.toLowerCase();
    final matchesMinPrice = minPrice == null || product.price >= minPrice;
    final matchesMaxPrice = maxPrice == null || product.price <= maxPrice;
    return matchesSearch &&
        matchesCategory &&
        matchesCondition &&
        matchesMinPrice &&
        matchesMaxPrice;
  }).toList();

  switch (sort) {
    case ProductSortOption.recommended:
      break; // Keep the feed's natural (server) order
    case ProductSortOption.newest:
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case ProductSortOption.priceLowHigh:
      result.sort((a, b) => a.price.compareTo(b.price));
    case ProductSortOption.priceHighLow:
      result.sort((a, b) => b.price.compareTo(a.price));
  }

  return result;
}

final filteredProductsProvider = Provider<List<Product>>((ref) {
  final search = ref.watch(searchQueryProvider);
  final category = ref.watch(selectedCategoryProvider);
  final condition = ref.watch(selectedConditionProvider);
  final minPrice = ref.watch(minPriceProvider);
  final maxPrice = ref.watch(maxPriceProvider);
  final sort = ref.watch(sortOptionProvider);
  final productsAsync = ref.watch(productsListProvider);

  return productsAsync.maybeWhen(
    data: (products) => applyProductFilters(
      products,
      search: search,
      category: category,
      condition: condition,
      minPrice: minPrice,
      maxPrice: maxPrice,
      sort: sort,
    ),
    orElse: () => [],
  );
});

class StoreResult {
  final String sellerId;
  final String storeName;
  final String ownerName;
  final bool isVerified;
  final int trustScore;

  const StoreResult({
    required this.sellerId,
    required this.storeName,
    required this.ownerName,
    required this.isVerified,
    required this.trustScore,
  });
}

final matchingStoresProvider = FutureProvider.family<List<StoreResult>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final searchTerm = query.trim().toLowerCase();
  try {
    final response = await SupabaseConfig.client
        .from('store_profiles')
        .select('''
          seller_id,
          store_name,
          users (
            full_name,
            is_seller_verified
          )
        ''');
    final rows = response as List<dynamic>;
    final List<StoreResult> results = [];

    for (final r in rows) {
      final storeName = r['store_name'] as String? ?? '';
      final usersMap = r['users'] as Map<String, dynamic>?;
      final ownerName = usersMap?['full_name'] as String? ?? 'Campus Vendor';
      // Match the strict seller definition: SELLER + is_seller_verified.
      final isVerified = usersMap?['is_seller_verified'] as bool? ?? false;

      if (storeName.toLowerCase().contains(searchTerm) || ownerName.toLowerCase().contains(searchTerm)) {
        results.add(StoreResult(
          sellerId: r['seller_id'] as String? ?? '',
          storeName: storeName.isEmpty ? '$ownerName Store' : storeName,
          ownerName: ownerName,
          isVerified: isVerified,
          trustScore: 98,
        ));
      }
    }
    return results;
  } catch (e) {
    return [];
  }
});
