import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/checkout/models/cart_item.dart';
import 'package:teknoycart/features/checkout/providers/cart_provider.dart';
import 'package:teknoycart/features/checkout/views/checkout_view.dart';

class CartView extends ConsumerStatefulWidget {
  const CartView({super.key});

  @override
  ConsumerState<CartView> createState() => _CartViewState();
}

class _CartViewState extends ConsumerState<CartView> {
  final Set<String> _selectedProductIds = {};

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Color definitions matching theme
    const cardBgDark = Color(0xFF1A1A1E);
    const cardBorderDark = Color(0xFF2A2A30);
    final cardBg = isDark ? cardBgDark : Colors.white;
    final cardBorder = isDark ? cardBorderDark : const Color(0xFFE0E0E4);
    final emptyTextColor = isDark ? Colors.white60 : Colors.black54;

    // Calculate total price of selected items
    double selectedTotal = 0.0;
    for (final item in cartItems) {
      if (_selectedProductIds.contains(item.product.id)) {
        selectedTotal += item.product.price * item.quantity;
      }
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101010) : const Color(0xFFF5F5F8),
      appBar: AppBar(
        title: const Text(
          'My Shopping Cart',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF0F0F12) : Colors.white,
        elevation: 0,
        actions: [
          if (cartItems.isNotEmpty)
            TextButton(
              onPressed: () {
                ref.read(cartProvider.notifier).clearCart();
                setState(() => _selectedProductIds.clear());
              },
              child: const Text(
                'Clear All',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: TeknoyTheme.citMaroon,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 72,
                    color: emptyTextColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: emptyTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Browse the marketplace and add items!',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: emptyTextColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      final isSelected = _selectedProductIds.contains(item.product.id);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder, width: 1),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              activeColor: TeknoyTheme.citMaroon,
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedProductIds.add(item.product.id);
                                  } else {
                                    _selectedProductIds.remove(item.product.id);
                                  }
                                });
                              },
                            ),
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: NetworkImage(item.product.imageUrl ?? ''),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.title,
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₱${item.product.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      color: TeknoyTheme.citMaroon,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (item.variantName != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Variant: ${item.variantName}',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                  onPressed: () {
                                    ref.read(cartProvider.notifier).removeFromCart(item.product.id, item.variantId);
                                    setState(() => _selectedProductIds.remove(item.product.id));
                                  },
                                ),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        ref.read(cartProvider.notifier).updateQuantity(
                                              item.product.id,
                                              item.variantId,
                                              item.quantity - 1,
                                            );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: cardBorder),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.remove, size: 14),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Text(
                                        '${item.quantity}',
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        ref.read(cartProvider.notifier).updateQuantity(
                                              item.product.id,
                                              item.variantId,
                                              item.quantity + 1,
                                            );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: cardBorder),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.add, size: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141418) : Colors.white,
                    border: Border(top: BorderSide(color: cardBorder, width: 1)),
                  ),
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Selected Total',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₱${selectedTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: TeknoyTheme.citMaroon,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: _selectedProductIds.isEmpty
                              ? null
                              : () {
                                  final checkoutItems = cartItems
                                      .where((item) => _selectedProductIds.contains(item.product.id))
                                      .map((item) => CheckoutItem(
                                            product: item.product,
                                            price: item.product.price,
                                            quantity: item.quantity,
                                            variantId: item.variantId,
                                            variantName: item.variantName,
                                          ))
                                      .toList();

                                  final firstSellerId = checkoutItems.first.product.sellerId;
                                  final allSameSeller = checkoutItems.every((item) => item.product.sellerId == firstSellerId);

                                  if (!allSameSeller) {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        title: const Row(
                                          children: [
                                            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                                            SizedBox(width: 8),
                                            Text(
                                              'Different Stores Selected',
                                              style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: const Text(
                                          'You can only checkout items from the same store/seller at a time. Please adjust your selection.',
                                          style: TextStyle(fontFamily: 'Inter', fontSize: 14),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text(
                                              'OK',
                                              style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontWeight: FontWeight.bold,
                                                color: TeknoyTheme.citMaroon,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    return;
                                  }

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CheckoutView(
                                        items: checkoutItems,
                                        isDirectBuy: false,
                                      ),
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TeknoyTheme.citMaroon,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Checkout Selected',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
