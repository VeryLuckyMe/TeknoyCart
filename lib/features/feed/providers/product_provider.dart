import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/feed/models/product.dart';

// ── Static filter providers ──
final categoriesProvider = Provider<List<String>>((ref) => [
      'All',
      'Books',
      'Drawing Tools',
      'Uniforms',
      'Electronics',
      'Others',
    ]);

final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<String>((ref) => 'All');
final selectedConditionProvider = StateProvider<String>((ref) => 'All');
final minPriceProvider = StateProvider<double?>((ref) => null);
final maxPriceProvider = StateProvider<double?>((ref) => null);

// ── Category ID mapping from Supabase schema ──
const _categoryIdToName = {
  1: 'Books',
  2: 'Drawing Tools',
  3: 'Uniforms',
  4: 'Electronics',
  5: 'Others',
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

/// Fallback demo products shown when Supabase is unreachable.
final List<Product> _fallbackProducts = [
  Product(
    id: 'prod-1',
    title: 'Engineering Drawing Table',
    description:
        'Official CIT-U drawing board with adjustable stands. Very clean, lightly used for one semester.',
    price: 450.00,
    imageUrl:
        'https://images.unsplash.com/photo-1513542789411-b6a5d4f31634?auto=format&fit=crop&q=80&w=400',
    category: 'Drawing Tools',
    condition: 'Like New',
    sellerId: 'demo-1',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  Product(
    id: 'prod-2',
    title: 'CIT-U PE Uniform (Medium)',
    description:
        'Complete set of official CIT-U physical education uniform. Unisex design, medium size.',
    price: 250.00,
    imageUrl:
        'https://images.unsplash.com/photo-1578587018452-892bacefd3f2?auto=format&fit=crop&q=80&w=400',
    category: 'Uniforms',
    condition: 'Gently Used',
    sellerId: 'demo-2',
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
  ),
  Product(
    id: 'prod-3',
    title: 'BSCS Data Structures Book',
    description:
        'Data Structures and Algorithms in Java, 6th Edition. Super helpful for second-year CS subjects.',
    price: 180.00,
    imageUrl:
        'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?auto=format&fit=crop&q=80&w=400',
    category: 'Books',
    condition: 'New',
    sellerId: 'demo-3',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
  Product(
    id: 'prod-4',
    title: 'Scientific Calculator (991ES Plus)',
    description:
        'Casio Scientific Calculator, perfect for Engineering and Math courses. All buttons working.',
    price: 350.00,
    imageUrl:
        'https://images.unsplash.com/photo-1629909613654-28e377c37b09?auto=format&fit=crop&q=80&w=400',
    category: 'Electronics',
    condition: 'Gently Used',
    sellerId: 'demo-1',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
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

      // Fetch live products from Supabase
      final response = await _supabase
          .from('products')
          .select('''
            product_id,
            name,
            description,
            base_price,
            status,
            category_id,
            seller_id,
            created_at,
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

      final rows = response as List<dynamic>;

      if (rows.isEmpty) {
        // Supabase returned no rows — use fallback demo data
        _cacheService.saveToLocalCache(_fallbackProducts);
        state = AsyncValue.data(List.from(_fallbackProducts));
        return;
      }

      final products = rows.map((row) {
        final variants = (row['product_variants'] as List<dynamic>?) ?? [];

        // Pick the best available image from Unsplash based on category
        final catId = row['category_id'] as int? ?? 5;
        final category = _categoryIdToName[catId] ?? 'Others';
        final imageUrl = _categoryImage(category);

        return Product(
          id: row['product_id'] as String,
          title: row['name'] as String? ?? 'Untitled Product',
          description: row['description'] as String? ?? '',
          price: double.tryParse(row['base_price'].toString()) ?? 0,
          imageUrl: imageUrl,
          category: category,
          condition: variants.isNotEmpty
              ? (variants[0]['variant_value'] as String? ?? 'Standard')
              : 'Standard',
          sellerId: row['seller_id'] as String? ?? '',
          createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
              DateTime.now(),
        );
      }).toList();

      _cacheService.saveToLocalCache(products);
      state = AsyncValue.data(products);
    } catch (e) {
      // Network/DB error — fall back to cache or demo data
      final local = _cacheService.getLocalCache();
      if (local != null && local.isNotEmpty) {
        state = AsyncValue.data(local);
      } else {
        _cacheService.saveToLocalCache(_fallbackProducts);
        state = AsyncValue.data(List.from(_fallbackProducts));
      }
    }
  }

  /// Adds a new product optimistically to the local state and inserts into Supabase.
  Future<void> addProduct(Product product) async {
    // Update local state immediately for instant feedback
    state.whenData((list) {
      state = AsyncValue.data([product, ...list]);
    });

    try {
      const categoryNameToId = {
        'Books': 1,
        'Drawing Tools': 2,
        'Uniforms': 3,
        'Electronics': 4,
        'Others': 5,
      };
      final categoryId = categoryNameToId[product.category] ?? 5;

      // 1. Insert product
      final inserted = await _supabase.from('products').insert({
        'name': product.title,
        'description': product.description,
        'base_price': product.price,
        'category_id': categoryId,
        'seller_id': product.sellerId,
        'status': 'ACTIVE',
      }).select().single();

      final String dbProductId = inserted['product_id'] as String;

      // 2. Create product variant
      final insertedVariant = await _supabase.from('product_variants').insert({
        'product_id': dbProductId,
        'variant_name': 'Condition',
        'variant_value': product.condition,
        'additional_price': 0,
        'sku': 'SKU-${product.category.substring(0, 3).toUpperCase()}-${dbProductId.substring(0, 6).toUpperCase()}',
      }).select().single();

      final String dbVariantId = insertedVariant['variant_id'] as String;

      // 3. Create inventory record so it shows up in Web Admin!
      await _supabase.from('inventory').insert({
        'variant_id': dbVariantId,
        'stock_qty': 1,
        'reserved_qty': 0,
        'low_stock_threshold': 1,
      });

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
        return 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?auto=format&fit=crop&q=80&w=400';
      case 'Drawing Tools':
        return 'https://images.unsplash.com/photo-1513542789411-b6a5d4f31634?auto=format&fit=crop&q=80&w=400';
      case 'Uniforms':
        return 'https://images.unsplash.com/photo-1578587018452-892bacefd3f2?auto=format&fit=crop&q=80&w=400';
      case 'Electronics':
        return 'https://images.unsplash.com/photo-1629909613654-28e377c37b09?auto=format&fit=crop&q=80&w=400';
      default:
        return 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&q=80&w=400';
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

final filteredProductsProvider = Provider<List<Product>>((ref) {
  final search = ref.watch(searchQueryProvider).toLowerCase();
  final category = ref.watch(selectedCategoryProvider);
  final condition = ref.watch(selectedConditionProvider);
  final minPrice = ref.watch(minPriceProvider);
  final maxPrice = ref.watch(maxPriceProvider);
  final productsAsync = ref.watch(productsListProvider);

  return productsAsync.maybeWhen(
    data: (products) {
      return products.where((product) {
        final matchesSearch = product.title.toLowerCase().contains(search) ||
            product.description.toLowerCase().contains(search);
        final matchesCategory =
            category == 'All' || product.category == category;
        final matchesCondition =
            condition == 'All' || product.condition.toLowerCase() == condition.toLowerCase();
        final matchesMinPrice = minPrice == null || product.price >= minPrice;
        final matchesMaxPrice = maxPrice == null || product.price <= maxPrice;
        return matchesSearch && matchesCategory && matchesCondition && matchesMinPrice && matchesMaxPrice;
      }).toList();
    },
    orElse: () => [],
  );
});
