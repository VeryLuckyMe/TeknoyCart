import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/features/feed/models/product.dart';
import 'package:teknoycart/features/checkout/models/cart_item.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addToCart(Product product, {int quantity = 1, String? variantId, String? variantName}) {
    final index = state.indexWhere((item) => item.product.id == product.id && item.variantId == variantId);
    if (index != -1) {
      final existingItem = state[index];
      state = [
        ...state.sublist(0, index),
        CartItem(
          product: product,
          quantity: existingItem.quantity + quantity,
          variantId: variantId,
          variantName: variantName,
        ),
        ...state.sublist(index + 1),
      ];
    } else {
      state = [
        ...state,
        CartItem(
          product: product,
          quantity: quantity,
          variantId: variantId,
          variantName: variantName,
        ),
      ];
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
        return CartItem(
          product: item.product,
          quantity: newQuantity,
          variantId: item.variantId,
          variantName: item.variantName,
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
