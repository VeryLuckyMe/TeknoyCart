import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/features/checkout/models/cart_item.dart';

abstract class CartStorageService {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureCartStorageService implements CartStorageService {
  final FlutterSecureStorage _storage;

  const SecureCartStorageService([
    this._storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  ]);

  bool get _hasBinding {
    try {
      return WidgetsBinding.instance != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> read(String key) async {
    try {
      if (!_hasBinding) return null;
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('SECURE_CART_READ: $e');
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      if (!_hasBinding) return;
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('SECURE_CART_WRITE: $e');
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      if (!_hasBinding) return;
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('SECURE_CART_DELETE: $e');
    }
  }
}

class AddToCartResult {
  final bool success;
  final int addedCount;
  final int totalInCart;
  final int? maxStock;
  final String message;

  const AddToCartResult({
    required this.success,
    required this.addedCount,
    required this.totalInCart,
    this.maxStock,
    required this.message,
  });
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  final CartStorageService? _storage;
  static const String cartStorageKey = 'teknoycart_saved_cart_items';

  CartNotifier({CartStorageService? storage, bool autoLoad = true})
      : _storage = storage ?? const SecureCartStorageService(),
        super([]) {
    if (autoLoad) {
      loadFromDisk();
    }
  }

  Future<void> loadFromDisk() async {
    if (_storage == null) return;
    try {
      final jsonStr = await _storage!.read(cartStorageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        state = decoded
            .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('CART_LOAD_FROM_DISK_ERROR: $e');
    }
  }

  Future<void> _persistToDisk() async {
    if (_storage == null) return;
    try {
      if (state.isEmpty) {
        await _storage!.delete(cartStorageKey);
      } else {
        final jsonStr = jsonEncode(state.map((item) => item.toJson()).toList());
        await _storage!.write(cartStorageKey, jsonStr);
      }
    } catch (e) {
      debugPrint('CART_PERSIST_TO_DISK_ERROR: $e');
    }
  }

  bool _matchesItem(CartItem item, String productId, String? variantId, String? variantName) {
    if (item.product.id != productId) return false;
    if (variantId != null && item.variantId != null) {
      return item.variantId == variantId;
    }
    return (item.variantName?.trim().toLowerCase() ?? '') == (variantName?.trim().toLowerCase() ?? '');
  }

  AddToCartResult addToCart(
    Product product, {
    int quantity = 1,
    String? variantId,
    String? variantName,
    int? maxStock,
  }) {
    if (quantity <= 0) {
      return const AddToCartResult(
        success: false,
        addedCount: 0,
        totalInCart: 0,
        message: 'Invalid quantity.',
      );
    }

    if (maxStock != null && maxStock <= 0) {
      return AddToCartResult(
        success: false,
        addedCount: 0,
        totalInCart: 0,
        maxStock: maxStock,
        message: 'This item is currently out of stock.',
      );
    }

    final index = state.indexWhere((item) => _matchesItem(item, product.id, variantId, variantName));

    if (index != -1) {
      final existingItem = state[index];
      final currentStockLimit = maxStock ?? existingItem.maxStock;

      if (currentStockLimit != null && existingItem.quantity >= currentStockLimit) {
        return AddToCartResult(
          success: false,
          addedCount: 0,
          totalInCart: existingItem.quantity,
          maxStock: currentStockLimit,
          message: 'You already have the maximum available stock ($currentStockLimit) in your cart.',
        );
      }

      int allowedToAdd = quantity;
      bool wasCapped = false;
      if (currentStockLimit != null && existingItem.quantity + quantity > currentStockLimit) {
        allowedToAdd = currentStockLimit - existingItem.quantity;
        wasCapped = true;
      }

      final newTotal = existingItem.quantity + allowedToAdd;
      state = [
        ...state.sublist(0, index),
        CartItem(
          product: product,
          quantity: newTotal,
          variantId: variantId ?? existingItem.variantId,
          variantName: variantName ?? existingItem.variantName,
          maxStock: currentStockLimit,
        ),
        ...state.sublist(index + 1),
      ];
      _persistToDisk();

      return AddToCartResult(
        success: true,
        addedCount: allowedToAdd,
        totalInCart: newTotal,
        maxStock: currentStockLimit,
        message: wasCapped
            ? 'Added $allowedToAdd item(s) to cart (reached stock limit of $currentStockLimit).'
            : 'Added ${product.title} to your cart!',
      );
    } else {
      int allowedToAdd = quantity;
      bool wasCapped = false;
      if (maxStock != null && quantity > maxStock) {
        allowedToAdd = maxStock;
        wasCapped = true;
      }

      state = [
        ...state,
        CartItem(
          product: product,
          quantity: allowedToAdd,
          variantId: variantId,
          variantName: variantName,
          maxStock: maxStock,
        ),
      ];
      _persistToDisk();

      return AddToCartResult(
        success: true,
        addedCount: allowedToAdd,
        totalInCart: allowedToAdd,
        maxStock: maxStock,
        message: wasCapped
            ? 'Added $allowedToAdd item(s) to cart (reached stock limit of $maxStock).'
            : 'Added ${product.title} to your cart!',
      );
    }
  }

  void removeFromCart(String productId, [String? variantId, String? variantName]) {
    state = state.where((item) => !_matchesItem(item, productId, variantId, variantName)).toList();
    _persistToDisk();
  }

  void updateQuantity(String productId, String? variantId, int newQuantity, [String? variantName]) {
    if (newQuantity <= 0) {
      removeFromCart(productId, variantId, variantName);
      return;
    }
    state = state.map((item) {
      if (_matchesItem(item, productId, variantId, variantName)) {
        int finalQty = newQuantity;
        if (item.maxStock != null && finalQty > item.maxStock!) {
          finalQty = item.maxStock!;
        }
        return CartItem(
          product: item.product,
          quantity: finalQty,
          variantId: item.variantId,
          variantName: item.variantName,
          maxStock: item.maxStock,
        );
      }
      return item;
    }).toList();
    _persistToDisk();
  }

  void updateVariant(String productId, String? oldVariantName, String newVariantName) {
    final oldIndex = state.indexWhere((item) =>
        item.product.id == productId &&
        (item.variantName?.trim().toLowerCase() ?? '') == (oldVariantName?.trim().toLowerCase() ?? ''));
    if (oldIndex == -1) return;

    final existingNewIndex = state.indexWhere((item) =>
        item.product.id == productId &&
        (item.variantName?.trim().toLowerCase() ?? '') == newVariantName.trim().toLowerCase());

    if (existingNewIndex != -1 && existingNewIndex != oldIndex) {
      // Merge with existing variant in cart
      final existing = state[existingNewIndex];
      final old = state[oldIndex];
      final mergedQty = existing.quantity + old.quantity;
      final stockLimit = existing.maxStock ?? old.maxStock;
      final finalQty = (stockLimit != null && mergedQty > stockLimit) ? stockLimit : mergedQty;

      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingNewIndex)
            CartItem(
              product: existing.product,
              quantity: finalQty,
              variantId: existing.variantId,
              variantName: newVariantName,
              maxStock: stockLimit,
            )
          else if (i != oldIndex)
            state[i],
      ];
    } else {
      final old = state[oldIndex];
      state = [
        ...state.sublist(0, oldIndex),
        CartItem(
          product: old.product,
          quantity: old.quantity,
          variantId: old.variantId,
          variantName: newVariantName,
          maxStock: old.maxStock,
        ),
        ...state.sublist(oldIndex + 1),
      ];
    }
    _persistToDisk();
  }

  void clearCart() {
    state = [];
    _persistToDisk();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier());
