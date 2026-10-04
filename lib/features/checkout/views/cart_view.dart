import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/checkout/providers/cart_provider.dart';
import 'package:teknoycart/features/checkout/views/checkout_view.dart';
import 'package:teknoycart/features/checkout/models/checkout_item.dart';
import 'package:teknoycart/features/checkout/models/cart_item.dart';

class CartView extends ConsumerStatefulWidget {
  const CartView({super.key});

  @override
  ConsumerState<CartView> createState() => _CartViewState();
}

class _CartViewState extends ConsumerState<CartView> {
  final Set<String> _selectedItemKeys = {};

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
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Switched to ${variantAttr.name}: ${opt.trim()}'),
                            backgroundColor: TeknoyTheme.citMaroon,
                            duration: const Duration(seconds: 2),
                          ),
                        );
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
                setState(() => _selectedItemKeys.clear());
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
                      onPressed: () => Navigator.pop(context),
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
                                      final checkoutItems = cartItems
                                          .where((item) => _selectedItemKeys.contains(item.cartKey))
                                          .map((item) => CheckoutItem(
                                                product: item.product,
                                                price: item.product.price,
                                                quantity: item.quantity,
                                                variantId: item.variantId,
                                                variantName: item.variantName,
                                              ))
                                          .toList();

                                      final selectedSellers = checkoutItems.map((item) => item.product.sellerId).toSet();

                                      if (selectedSellers.length > 1) {
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
                );
              },
            ),
    );
  }

  void _checkoutSpecificStore(BuildContext context, List<CartItem> itemsToCheckout) {
    if (itemsToCheckout.isEmpty) return;
    final checkoutItems = itemsToCheckout
        .map((item) => CheckoutItem(
              product: item.product,
              price: item.product.price,
              quantity: item.quantity,
              variantId: item.variantId,
              variantName: item.variantName,
            ))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutView(
          items: checkoutItems,
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
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
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
                final firstItem = storeItems.first;
                final storeName = (firstItem.product.sellerStoreName != null && firstItem.product.sellerStoreName!.isNotEmpty)
                    ? firstItem.product.sellerStoreName!
                    : 'Wildcat Student Store';
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
    required String sellerId,
    required List<CartItem> storeItems,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
  }) {
    final firstItem = storeItems.first;
    final storeName = (firstItem.product.sellerStoreName != null && firstItem.product.sellerStoreName!.isNotEmpty)
        ? firstItem.product.sellerStoreName!
        : 'Wildcat Student Store';

    final allStoreKeys = storeItems.map((e) => e.cartKey).toSet();
    final isStoreAllSelected = allStoreKeys.every(_selectedItemKeys.contains);
    final isStorePartiallySelected = !isStoreAllSelected && allStoreKeys.any(_selectedItemKeys.contains);

    final selectedStoreItems = storeItems.where((i) => _selectedItemKeys.contains(i.cartKey)).toList();
    final storeCheckoutItems = selectedStoreItems.isNotEmpty ? selectedStoreItems : storeItems;

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
          // Store Header
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
                    onChanged: (val) {
                      setState(() {
                        if (isStoreAllSelected) {
                          _selectedItemKeys.removeAll(allStoreKeys);
                        } else {
                          _selectedItemKeys.addAll(allStoreKeys);
                        }
                      });
                    },
                  ),
                ),
                Icon(
                  Icons.storefront_rounded,
                  size: 16,
                  color: isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon,
                ),
                const SizedBox(width: 8),
                Expanded(
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
                TextButton(
                  onPressed: () => _checkoutSpecificStore(context, storeCheckoutItems),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(44, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Store Deal',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon,
                      ),
                    ],
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
  }) {
    final isSelected = _selectedItemKeys.contains(item.cartKey);

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
                    if (val == true) {
                      _selectedItemKeys.add(item.cartKey);
                    } else {
                      _selectedItemKeys.remove(item.cartKey);
                    }
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Product Thumbnail
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isDark ? const Color(0xFF25252D) : const Color(0xFFEDEDF2),
              border: Border.all(color: cardBorder, width: 0.8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: item.product.imageUrl != null && item.product.imageUrl!.isNotEmpty
                  ? Image.network(
                      item.product.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 24,
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 24,
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                    ),
            ),
          ),
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
                    item.quantity >= item.maxStock!
                        ? 'Max stock reached (${item.maxStock})'
                        : '${item.maxStock} in stock',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: item.quantity >= item.maxStock!
                          ? Colors.orange.shade700
                          : (isDark ? Colors.white54 : Colors.black45),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Quantity & Delete
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
                padding: const EdgeInsets.all(8),
                onPressed: () {
                  ref.read(cartProvider.notifier).removeFromCart(item.product.id, item.variantId, item.variantName);
                  setState(() => _selectedItemKeys.remove(item.cartKey));
                },
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      ref.read(cartProvider.notifier).updateQuantity(
                            item.product.id,
                            item.variantId,
                            item.quantity - 1,
                            item.variantName,
                          );
                    },
                    icon: const Icon(Icons.remove, size: 15),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: const EdgeInsets.all(8),
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: cardBorder),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: (item.maxStock != null && item.quantity >= item.maxStock!)
                        ? null
                        : () {
                            ref.read(cartProvider.notifier).updateQuantity(
                                  item.product.id,
                                  item.variantId,
                                  item.quantity + 1,
                                  item.variantName,
                                );
                          },
                    icon: const Icon(Icons.add, size: 15),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: const EdgeInsets.all(8),
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: (item.maxStock != null && item.quantity >= item.maxStock!)
                              ? (isDark ? Colors.white24 : Colors.grey.shade300)
                              : cardBorder,
                        ),
                      ),
                    ),
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
