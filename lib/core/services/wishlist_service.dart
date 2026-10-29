import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';

abstract class WishlistStorageAdapter {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureWishlistStorageAdapter implements WishlistStorageAdapter {
  final FlutterSecureStorage _storage;

  const SecureWishlistStorageAdapter([
    this._storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  ]);

  bool get _hasBinding {
    try {
      WidgetsBinding.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> read(String key) async {
    try {
      if (!_hasBinding) return null;
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      if (!_hasBinding) return;
      await _storage.write(key: key, value: value);
    } catch (_) {}
  }

  @override
  Future<void> delete(String key) async {
    try {
      if (!_hasBinding) return;
      await _storage.delete(key: key);
    } catch (_) {}
  }
}

/// Local persistence service for student favorites / wishlist (Ponytail Audit H7 & GAP-01).
class WishlistService {
  static const String storageKey = 'teknoy_favorite_product_ids';
  static const SecureWishlistStorageAdapter _defaultAdapter =
      SecureWishlistStorageAdapter();

  static Future<Set<String>> getFavorites() async {
    try {
      final data = await _defaultAdapter.read(storageKey);
      if (data == null || data.isEmpty) return {};
      final list = jsonDecode(data) as List<dynamic>;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<bool> isFavorite(String productId) async {
    final favs = await getFavorites();
    return favs.contains(productId);
  }

  static Future<bool> toggleFavorite(String productId) async {
    try {
      final favs = await getFavorites();
      final bool added = !favs.contains(productId);
      if (added) {
        favs.add(productId);
      } else {
        favs.remove(productId);
      }
      await _defaultAdapter.write(storageKey, jsonEncode(favs.toList()));
      return added;
    } catch (_) {
      return false;
    }
  }
}

/// Reactive Riverpod StateNotifier managing student wishlist IDs across all screens.
class WishlistNotifier extends StateNotifier<Set<String>> {
  final WishlistStorageAdapter _storage;

  WishlistNotifier({
    WishlistStorageAdapter? storage,
    bool autoLoad = true,
  })  : _storage = storage ?? const SecureWishlistStorageAdapter(),
        super(const <String>{}) {
    if (autoLoad) {
      loadFromDisk();
    }
  }

  Future<void> loadFromDisk() async {
    try {
      final raw = await _storage.read(WishlistService.storageKey);
      if (raw == null || raw.isEmpty) {
        state = const <String>{};
        return;
      }
      final decoded = jsonDecode(raw) as List<dynamic>;
      state = Set<String>.unmodifiable(
        decoded.map((e) => e.toString()).where((id) => id.isNotEmpty),
      );
    } catch (_) {
      state = const <String>{};
    }
  }

  Future<void> _persist() async {
    await _storage.write(
      WishlistService.storageKey,
      jsonEncode(state.toList()),
    );
  }

  bool isFavorite(String productId) => state.contains(productId);

  Future<bool> toggle(String productId) async {
    if (productId.isEmpty) return false;
    final next = Set<String>.from(state);
    final bool added;
    if (next.contains(productId)) {
      next.remove(productId);
      added = false;
    } else {
      next.add(productId);
      added = true;
    }
    state = Set<String>.unmodifiable(next);
    await _persist();
    return added;
  }

  Future<void> add(String productId) async {
    if (productId.isEmpty || state.contains(productId)) return;
    final next = Set<String>.from(state)..add(productId);
    state = Set<String>.unmodifiable(next);
    await _persist();
  }

  Future<void> remove(String productId) async {
    if (!state.contains(productId)) return;
    final next = Set<String>.from(state)..remove(productId);
    state = Set<String>.unmodifiable(next);
    await _persist();
  }

  Future<void> restoreAll(Set<String> productIds) async {
    state = Set<String>.unmodifiable(
      productIds.where((id) => id.isNotEmpty),
    );
    await _persist();
  }

  Future<void> clearAll() async {
    state = const <String>{};
    await _storage.delete(WishlistService.storageKey);
  }
}

final wishlistProvider =
    StateNotifierProvider<WishlistNotifier, Set<String>>((ref) {
  return WishlistNotifier();
});

final wishlistCountProvider = Provider<int>((ref) {
  return ref.watch(wishlistProvider.select((ids) => ids.length));
});

final isProductFavoritedProvider = Provider.family<bool, String>((ref, productId) {
  return ref.watch(wishlistProvider.select((ids) => ids.contains(productId)));
});

final wishlistedProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final favIds = ref.watch(wishlistProvider);
  final productsAsync = ref.watch(productsListProvider);

  return productsAsync.whenData((allProducts) {
    if (favIds.isEmpty) return const <Product>[];
    final byId = <String, Product>{
      for (final p in allProducts) p.id: p,
    };
    return favIds
        .map((id) => byId[id])
        .whereType<Product>()
        .toList();
  });
});
