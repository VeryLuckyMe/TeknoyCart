import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/checkout/providers/cart_provider.dart';
import 'package:teknoycart/features/checkout/views/checkout_view.dart';
import 'package:teknoycart/features/checkout/models/checkout_item.dart';
import 'package:teknoycart/features/checkout/models/cart_item.dart';
import 'package:teknoycart/features/feed/views/product_discovery_feed_view.dart';

class CartView extends ConsumerStatefulWidget {
  const CartView({super.key});

  @override
  ConsumerState<CartView> createState() => _CartViewState();
}

class _CartViewState extends ConsumerState<CartView> {
  final Set<String> _selectedItemKeys = {};
  final Set<String> _editingSellerIds = {};
  final Map<String, int> _draftQuantities = {};

  void _enterStoreEditMode(String sellerId, List<CartItem> storeItems) {
    setState(() {
      _editingSellerIds.add(sellerId);
      for (final item in storeItems) {
        _draftQuantities[item.cartKey] = item.quantity;
      }
    });
  }

  void _exitStoreEditMode(String sellerId, String storeName, List<CartItem> storeItems) {
    final storeDrafts = <String, int>{};
    for (final item in storeItems) {
      if (_draftQuantities.containsKey(item.cartKey)) {
        storeDrafts[item.cartKey] = _draftQuantities[item.cartKey]!;
      }
    }
    if (storeDrafts.isNotEmpty) {
      ref.read(cartProvider.notifier).batchUpdateQuantities(storeDrafts);
      _showSnack('Updated $storeName quantities!');
    }
    setState(() {
      _editingSellerIds.remove(sellerId);
      for (final item in storeItems) {
        _draftQuantities.remove(item.cartKey);
      }
    });
  }

  void _commitAllPendingDrafts() {
    if (_draftQuantities.isNotEmpty) {
      ref.read(cartProvider.notifier).batchUpdateQuantities(Map.from(_draftQuantities));
      _draftQuantities.clear();
      _editingSellerIds.clear();
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: TeknoyTheme.citMaroon,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _dragHandle(bool isDark) => Center(
        child: Container(
          width: 38,
          height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white24 : Colors.black12,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  void _showConfirmActionSheet({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    required VoidCallback onConfirm,
    String cancelText = 'Cancel',
    IconData icon = Icons.delete_outline_rounded,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dragHandle(isDark),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.red, size: 32),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: isDark ? Colors.white70 : Colors.black54, height: 1.4)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                    ),
                    child: Text(cancelText, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(confirmText, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveItemConfirmationSheet(BuildContext context, CartItem item) {
    _showConfirmActionSheet(
      context: context,
      title: 'Remove from Cart?',
      message: 'Do you want to remove "${item.product.title}" from your shopping cart?',
      confirmText: 'Remove Item',
      cancelText: 'Keep in Cart',
      onConfirm: () {
        ref.read(cartProvider.notifier).removeFromCart(item.product.id, item.variantId, item.variantName);
        setState(() {
          _draftQuantities.remove(item.cartKey);
          _selectedItemKeys.remove(item.cartKey);
        });
        _showSnack('Removed "${item.product.title}"');
      },
    );
  }

  String _storeName(CartItem item) =>
      item.product.sellerStoreName?.isNotEmpty == true ? item.product.sellerStoreName! : 'Wildcat Student Store';

  List<CheckoutItem> _toCheckoutItems(Iterable<CartItem> items) => items
      .map((i) => CheckoutItem(
            product: i.product,
            price: i.product.price,
            quantity: i.quantity,
            variantId: i.variantId,
            variantName: i.variantName,
          ))
      .toList();

  Widget _qtyBtn({
    required VoidCallback? onPressed,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) =>
      IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 15, color: color),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: const EdgeInsets.all(6),
        style: IconButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF22222A) : const Color(0xFFF5F5F8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isDark ? Colors.white12 : const Color(0xFFE2E2EA),
              width: 1,
            ),
          ),
        ),
      );

  Widget _productThumb(String? url, Color cardBorder, bool isDark) {
    final icon = Center(
      child: Icon(Icons.inventory_2_outlined, size: 24, color: isDark ? Colors.white30 : Colors.black26),
    );
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isDark ? const Color(0xFF25252D) : const Color(0xFFEDEDF2),
        border: Border.all(color: cardBorder, width: 0.8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: (url != null && url.isNotEmpty)
            ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => icon)
            : icon,
      ),
    );
  }

  void _showChangeVariantSheet(BuildContext context, CartItem item) {
    final variantAttr = item.product.categoryAttributes
        .where((a) => a.options.isNotEmpty && (a.options.length > 1 || a.name.toLowerCase() == 'size' || a.name.toLowerCase() == 'color'))
        .firstOrNull;
    if (variantAttr == null || variantAttr.options.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C22) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dragHandle(isDark),
              const Text(
                'Change Variation',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.product.title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Text(
                'Select ${variantAttr.name}:',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: variantAttr.options.map((opt) {
                  final isCurrent = (item.variantName?.trim().toLowerCase() ?? '') == opt.trim().toLowerCase();
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (!isCurrent) {
                        ref.read(cartProvider.notifier).updateVariant(
                              item.product.id,
                              item.variantName,
                              opt.trim(),
                            );
                        _showSnack('Switched to ${variantAttr.name}: ${opt.trim()}');
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? TeknoyTheme.citMaroon
                            : (isDark ? const Color(0xFF262630) : const Color(0xFFF1F1F6)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCurrent ? TeknoyTheme.citMaroon : (isDark ? Colors.white12 : Colors.black12),
                          width: isCurrent ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCurrent) ...[
                            const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            opt,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                              color: isCurrent ? Colors.white : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    if (cartItems.isEmpty) {
      _editingSellerIds.clear();
      _draftQuantities.clear();
      _selectedItemKeys.clear();
    }
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
      if (_selectedItemKeys.contains(item.cartKey)) {
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
                setState(() {
                  _selectedItemKeys.clear();
                  _editingSellerIds.clear();
                  _draftQuantities.clear();
                });
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
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A22) : const Color(0xFFEDEDF4),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shopping_cart_outlined,
                        size: 64,
                        color: isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Your cart is empty',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Explore pre-loved uniforms, books, and drawing kits on campus!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: emptyTextColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProductDiscoveryFeedView(initialTab: 0),
                          ),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.storefront_rounded, size: 18),
                      label: const Text(
                        'Explore Campus Deals',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TeknoyTheme.citMaroon,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Builder(
              builder: (context) {
                final Map<String, List<CartItem>> itemsBySeller = {};
                for (final item in cartItems) {
                  final sellerKey = item.product.sellerId.isNotEmpty ? item.product.sellerId : 'store-default';
                  itemsBySeller.putIfAbsent(sellerKey, () => []).add(item);
                }
                final sellerKeys = itemsBySeller.keys.toList();

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: sellerKeys.length,
                        itemBuilder: (context, index) {
                          final sellerId = sellerKeys[index];
                          final storeItems = itemsBySeller[sellerId]!;
                          return _buildStoreCard(
                            context: context,
                            index: index,
                            sellerId: sellerId,
                            storeItems: storeItems,
                            isDark: isDark,
                            cardBg: cardBg,
                            cardBorder: cardBorder,
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141418) : Colors.white,
                        border: Border(top: BorderSide(color: cardBorder, width: 1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, -3),
                          ),
                        ],
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
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: TeknoyTheme.citMaroon,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton(
                              onPressed: _selectedItemKeys.isEmpty
                                  ? null
                                  : () {
                                      _commitAllPendingDrafts();
                                      final checkoutItems = _toCheckoutItems(
                                          cartItems.where((i) => _selectedItemKeys.contains(i.cartKey)));
                                      if (checkoutItems.map((i) => i.product.sellerId).toSet().length > 1) {
                                        _showMultiStoreCheckoutChooser(context, itemsBySeller);
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
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: Text(
                                _selectedItemKeys.isEmpty
                                    ? 'Checkout Selected'
                                    : 'Checkout Selected (${_selectedItemKeys.length})',
                                style: const TextStyle(
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
                );
              },
            ),
    );
  }

  void _checkoutSpecificStore(BuildContext context, List<CartItem> itemsToCheckout) {
    if (itemsToCheckout.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutView(
          items: _toCheckoutItems(itemsToCheckout),
          isDirectBuy: false,
        ),
      ),
    );
  }

  void _showMultiStoreCheckoutChooser(
    BuildContext context,
    Map<String, List<CartItem>> itemsBySeller,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter to sellers that actually have selected items
    final selectedBySeller = <String, List<CartItem>>{};
    for (final entry in itemsBySeller.entries) {
      final selectedInStore = entry.value.where((item) => _selectedItemKeys.contains(item.cartKey)).toList();
      if (selectedInStore.isNotEmpty) {
        selectedBySeller[entry.key] = selectedInStore;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A20) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dragHandle(isDark),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: TeknoyTheme.citMaroon.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: TeknoyTheme.citMaroon, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Checkout by Store',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Campus meetup orders are arranged per seller.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ...selectedBySeller.entries.map((entry) {
                final storeItems = entry.value;
                final storeName = _storeName(storeItems.first);
                final storeTotal = storeItems.fold<double>(0.0, (sum, i) => sum + (i.product.price * i.quantity));

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF22222A) : const Color(0xFFF7F7FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E2E38) : const Color(0xFFE4E4EC),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              storeName,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${storeItems.length} item${storeItems.length > 1 ? 's' : ''} • ₱${storeTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: TeknoyTheme.citMaroon,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _checkoutSpecificStore(context, storeItems);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TeknoyTheme.citMaroon,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Checkout',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStoreCard({
    required BuildContext context,
    required int index,
    required String sellerId,
    required List<CartItem> storeItems,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
  }) {
    final firstItem = storeItems.first;
    final storeName = _storeName(firstItem);
    final isStoreEditing = _editingSellerIds.contains(sellerId);

    final allStoreKeys = storeItems.map((e) => e.cartKey).toSet();
    final isStoreAllSelected = allStoreKeys.every(_selectedItemKeys.contains);
    final isStorePartiallySelected = !isStoreAllSelected && allStoreKeys.any(_selectedItemKeys.contains);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store Header: Checkbox + Store Name + [Editing badge] on left, Edit/Done on right
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E26) : const Color(0xFFF9F9FC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: cardBorder, width: 0.8)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  height: 38,
                  child: Checkbox(
                    value: isStoreAllSelected ? true : (isStorePartiallySelected ? null : false),
                    tristate: true,
                    activeColor: TeknoyTheme.citMaroon,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (_) => setState(() {
                      isStoreAllSelected
                          ? _selectedItemKeys.removeAll(allStoreKeys)
                          : _selectedItemKeys.addAll(allStoreKeys);
                    }),
                  ),
                ),
                Icon(
                  Icons.storefront_rounded,
                  size: 16,
                  color: isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          storeName,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isStoreEditing) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade700, width: 0.8),
                          ),
                          child: Text(
                            'Editing',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isStoreEditing)
                  TextButton.icon(
                    key: const Key('cart_done_button'),
                    onPressed: () => _exitStoreEditMode(sellerId, storeName, storeItems),
                    icon: const Icon(Icons.check_rounded, size: 15, color: TeknoyTheme.citMaroon),
                    label: const Text(
                      'Done',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: TeknoyTheme.citMaroon,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(44, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                else
                  TextButton(
                    key: index == 0
                        ? const Key('cart_edit_mode_button')
                        : Key('cart_edit_mode_button_$sellerId'),
                    onPressed: () => _enterStoreEditMode(sellerId, storeItems),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(44, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Edit',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Items in Store
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: storeItems.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: cardBorder.withValues(alpha: 0.5)),
            itemBuilder: (context, itemIdx) {
              final item = storeItems[itemIdx];
              return _buildCartItemTile(
                context: context,
                item: item,
                isDark: isDark,
                cardBorder: cardBorder,
                isEditing: isStoreEditing,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemTile({
    required BuildContext context,
    required CartItem item,
    required bool isDark,
    required Color cardBorder,
    required bool isEditing,
  }) {
    final isSelected = _selectedItemKeys.contains(item.cartKey);
    final currentQty = isEditing
        ? (_draftQuantities[item.cartKey] ?? item.quantity)
        : item.quantity;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Select Checkbox with 44dp hit area
          SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Checkbox(
                value: isSelected,
                activeColor: TeknoyTheme.citMaroon,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (val) {
                  setState(() {
                    val == true ? _selectedItemKeys.add(item.cartKey) : _selectedItemKeys.remove(item.cartKey);
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          _productThumb(item.product.imageUrl, cardBorder, isDark),
          const SizedBox(width: 12),
          // Product Info
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
                if (item.variantName != null && item.variantName!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _showChangeVariantSheet(context, item),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF23232B) : const Color(0xFFF4F4F7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: TeknoyTheme.citMaroon.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: TeknoyTheme.citMaroon.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.straighten_rounded, size: 10, color: TeknoyTheme.citMaroon),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Size: ${item.variantName}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 13,
                            color: isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (item.maxStock != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    currentQty >= item.maxStock!
                        ? 'Max stock reached (${item.maxStock})'
                        : '${item.maxStock} in stock',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: currentQty >= item.maxStock!
                          ? Colors.orange.shade700
                          : (isDark ? Colors.white54 : Colors.black45),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Normal vs Edit Mode Quantity Section
          if (!isEditing)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF22222A) : const Color(0xFFF1F1F6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E2EA),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    'Qty: ${item.quantity}',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '₱${(item.product.price * item.quantity).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
                  padding: const EdgeInsets.all(6),
                  tooltip: 'Remove item',
                  onPressed: () => _showRemoveItemConfirmationSheet(context, item),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _qtyBtn(
                      onPressed: () {
                        if (currentQty > 1) {
                          setState(() => _draftQuantities[item.cartKey] = currentQty - 1);
                        } else {
                          _showRemoveItemConfirmationSheet(context, item);
                        }
                      },
                      icon: currentQty > 1 ? Icons.remove_rounded : Icons.delete_outline_rounded,
                      color: currentQty > 1
                          ? (isDark ? Colors.white70 : Colors.black87)
                          : Colors.red.shade400,
                      isDark: isDark,
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 34),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '$currentQty',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    _qtyBtn(
                      onPressed: (item.maxStock != null && currentQty >= item.maxStock!)
                          ? null
                          : () => setState(() => _draftQuantities[item.cartKey] = currentQty + 1),
                      icon: Icons.add_rounded,
                      color: (item.maxStock != null && currentQty >= item.maxStock!)
                          ? (isDark ? Colors.white24 : Colors.grey.shade400)
                          : (isDark ? Colors.white70 : Colors.black87),
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
