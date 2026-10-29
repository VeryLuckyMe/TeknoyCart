import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/core/services/wishlist_service.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/core/utils/order_ui_helper.dart';
import 'package:teknoycart/core/widgets/image_placeholder.dart';
import 'package:teknoycart/features/checkout/providers/cart_provider.dart';
import 'package:teknoycart/features/checkout/views/cart_view.dart';
import 'package:teknoycart/features/feed/views/product_detail_view.dart';
import 'package:teknoycart/features/feed/views/product_discovery_feed_view.dart';

/// Dedicated screen displaying the student's favorited / saved campus items (GAP-01).
class WishlistView extends ConsumerWidget {
  const WishlistView({super.key});

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? TeknoyTheme.darkSurfaceRaised : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Clear Saved Wishlist?',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'This will remove all saved campus items from your wishlist.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: TeknoyTheme.citMaroon,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final notifier = ref.read(wishlistProvider.notifier);
      final backup = Set<String>.from(ref.read(wishlistProvider));
      await notifier.clearAll();
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Cleared saved wishlist'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            textColor: TeknoyTheme.citGold,
            onPressed: () {
              notifier.restoreAll(backup);
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wishlistedAsync = ref.watch(wishlistedProductsProvider);
    final items = wishlistedAsync.valueOrNull ?? const <Product>[];

    return Scaffold(
      backgroundColor: isDark ? TeknoyTheme.darkBg : TeknoyTheme.lightBgAlt,
      appBar: AppBar(
        backgroundColor: isDark ? TeknoyTheme.darkSurface : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Saved Wishlist',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: isDark ? Colors.white : TeknoyTheme.citMaroon,
          ),
        ),
        actions: [
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: () => _confirmClearAll(context, ref),
                icon: const Icon(
                  Icons.delete_sweep_outlined,
                  size: 18,
                  color: TeknoyTheme.citMaroon,
                ),
                label: const Text(
                  'Clear All',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: TeknoyTheme.citMaroon,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: wishlistedAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: TeknoyTheme.citMaroon),
        ),
        error: (_, __) => _buildEmptyState(context, isDark),
        data: (products) {
          if (products.isEmpty) {
            return _buildEmptyState(context, isDark);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? TeknoyTheme.darkSurface : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? TeknoyTheme.darkDivider : TeknoyTheme.lightBorder,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      size: 16,
                      color: TeknoyTheme.citMaroon,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${products.length} Saved ${products.length == 1 ? 'Item' : 'Items'}',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _buildWishlistCard(context, ref, product, isDark);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: TeknoyTheme.citMaroon.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                size: 40,
                color: TeknoyTheme.citMaroon,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your Wishlist is Empty',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the heart icon on any textbook, uniform, or campus gear to save it here for later.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                height: 1.45,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProductDiscoveryFeedView(),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: const Text(
                'Explore Campus Deals',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: TeknoyTheme.citMaroon,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWishlistCard(
    BuildContext context,
    WidgetRef ref,
    Product product,
    bool isDark,
  ) {
    final notifier = ref.read(wishlistProvider.notifier);

    return Material(
      color: isDark ? TeknoyTheme.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailView(product: product),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? TeknoyTheme.darkBorder : TeknoyTheme.lightBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ImagePlaceholder(),
                        )
                      : const ImagePlaceholder(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          key: Key('wishlist_remove_${product.id}'),
                          tooltip: 'Remove from wishlist',
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.favorite_rounded,
                            color: TeknoyTheme.citMaroon,
                            size: 20,
                          ),
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            await notifier.remove(product.id);
                            if (!context.mounted) return;
                            final messenger = ScaffoldMessenger.of(context);
                            messenger.clearSnackBars();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Removed "${product.title}" from wishlist'),
                                behavior: SnackBarBehavior.floating,
                                action: SnackBarAction(
                                  label: 'Undo',
                                  textColor: TeknoyTheme.citGold,
                                  onPressed: () {
                                    notifier.add(product.id);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    Text(
                      '${product.category} • ${OrderUiHelper.formatCondition(product.condition)}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₱${product.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon,
                          ),
                        ),
                        ElevatedButton.icon(
                          key: Key('wishlist_action_${product.id}'),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            if (product.isPreorderEnabled) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailView(product: product),
                                ),
                              );
                              return;
                            }
                            final res = ref.read(cartProvider.notifier).addToCart(product);
                            final messenger = ScaffoldMessenger.of(context);
                            messenger.clearSnackBars();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(res.message),
                                behavior: SnackBarBehavior.floating,
                                action: SnackBarAction(
                                  label: 'View Cart',
                                  textColor: TeknoyTheme.citGold,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const CartView(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                          icon: Icon(
                            product.isPreorderEnabled
                                ? Icons.bolt_rounded
                                : Icons.add_shopping_cart_rounded,
                            size: 15,
                          ),
                          label: Text(
                            product.isPreorderEnabled ? 'View Pre-Order' : 'Add to Cart',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TeknoyTheme.citMaroon,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            minimumSize: const Size(44, 38),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
