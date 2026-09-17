import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/features/feed/models/product.dart';
import 'package:teknoycart/features/checkout/models/cart_item.dart';

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
  CartNotifier() : super([]);

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

    final index = state.indexWhere((item) => item.product.id == product.id && item.variantId == variantId);

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
          variantId: variantId,
          variantName: variantName ?? existingItem.variantName,
          maxStock: currentStockLimit,
        ),
        ...state.sublist(index + 1),
      ];

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

  void removeFromCart(String productId, String? variantId) {
    state = state.where((item) => !(item.product.id == productId && item.variantId == variantId)).toList();
  }

  void updateQuantity(String productId, String? variantId, int newQuantity) {
    if (newQuantity <= 0) {
      removeFromCart(productId, variantId);
      return;
    }
    state = state.map((item) {
      if (item.product.id == productId && item.variantId == variantId) {
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
  }

  void clearCart() {
    state = [];
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier());
