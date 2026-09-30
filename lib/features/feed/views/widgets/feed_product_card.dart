import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/product.dart';
import '../../../../core/theme.dart';
import '../../providers/review_provider.dart';
import '../search_results_view.dart';

class FeedProductCard extends StatefulWidget {
  final Product product;

  const FeedProductCard({
    super.key,
    required this.product,
  });

  @override
  State<FeedProductCard> createState() => _FeedProductCardState();
}

class _FeedProductCardState extends State<FeedProductCard> {
  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Choose badge color based on product condition
    Color badgeBg;
    Color badgeText;
    if (product.condition.toLowerCase() == 'new') {
      badgeBg = const Color(0xFF10B981); // Emerald Green
      badgeText = Colors.white;
    } else if (product.condition.toLowerCase() == 'like new') {
      badgeBg = TeknoyTheme.citGold;
      badgeText = const Color(0xFF533F00);
    } else {
      badgeBg = isDark ? const Color(0xFF2C2C35) : const Color(0xFFECECEF);
      badgeText = isDark ? Colors.white70 : Colors.black87;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141418) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF22222A) : const Color(0xFFECECEF),
          width: 1,
        ),
        boxShadow: TeknoyTheme.kElevationLow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Square Image Container (with Hero transition and condition tags)
            AspectRatio(
              aspectRatio: 1.0,
              child: Stack(
                children: [
                  // Image
                  Positioned.fill(
                    child: Hero(
                      tag: 'product_image_${product.id}',
                      child: Container(
                        color: isDark ? const Color(0xFF1C1C22) : const Color(0xFFF3F3F5),
                        child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                            ? Image.network(
                                product.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 28),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.image_rounded, color: Colors.grey, size: 28),
                              ),
                      ),
                    ),
                  ),

                  // Condition Badge & Tawad Badge (top-left) - modern Shopee-inspired tags
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: badgeBg.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Text(
                            product.condition.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w800,
                              fontSize: 9,
                              color: badgeText,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: TeknoyTheme.citMaroon.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.handshake_rounded, size: 10, color: TeknoyTheme.citGold),
                              SizedBox(width: 2.5),
                              Text(
                                'TAWAD',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 8.5,
                                  color: Colors.white,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Wishlist / Favorite Button (top-right) - interactive glassmorphic button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _isFavorite = !_isFavorite);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _isFavorite
                                  ? 'Added "${product.title}" to saved items'
                                  : 'Removed from saved items',
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                            ),
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            _isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 16,
                            color: TeknoyTheme.citMaroon,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Pre-Order Badge (bottom-left)
                  if (product.isPreorderEnabled)
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded, size: 12, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              'PRE-ORDER',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
                                color: Colors.white,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 2. Dense Layout Info Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Rating & Category Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Consumer(
                          builder: (context, ref, _) {
                            final summary = ref.watch(productRatingSummaryProvider(product.id));
                            final ratingText = summary.total > 0 ? summary.average.toStringAsFixed(1) : 'New';
                            return Row(
                              children: [
                                Icon(
                                  summary.total > 0 ? Icons.star_rounded : Icons.star_outline_rounded,
                                  size: 13,
                                  color: TeknoyTheme.citGold,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  ratingText,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: isDark ? Colors.white70 : const Color(0xFF5A413D),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF1F1F5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            product.category,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                              color: isDark ? Colors.white70 : const Color(0xFF5A413D),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Store Name & Title
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final showChips = product.categoryAttributes.isNotEmpty && constraints.maxHeight >= 40;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (product.sellerStoreName != null && product.sellerStoreName!.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2.0),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.storefront_rounded, size: 12, color: TeknoyTheme.citMaroon),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  product.sellerStoreName!,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: TeknoyTheme.citMaroon,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: TeknoyTheme.citGold.withValues(alpha: 0.25),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: TeknoyTheme.citGold, width: 0.6),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.verified_rounded, size: 9, color: TeknoyTheme.citMaroon),
                                                    SizedBox(width: 2),
                                                    Text(
                                                      'CIT-U',
                                                      style: TextStyle(
                                                        fontFamily: 'Inter',
                                                        fontSize: 7.5,
                                                        fontWeight: FontWeight.w800,
                                                        color: TeknoyTheme.citMaroon,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Text(
                                  product.title,
                                  maxLines: showChips ? 1 : 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    height: 1.2,
                                    color: isDark ? Colors.white : const Color(0xFF191C1D),
                                  ),
                                ),
                                // Quick attribute chips (show top 2 key attributes)
                                if (showChips)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Wrap(
                                      spacing: 4,
                                      runSpacing: 2,
                                      children: product.categoryAttributes
                                          .take(2)
                                          .map((attr) => Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(5),
                                                  onTap: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => SearchResultsView(
                                                          initialQuery: attr.value,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: isDark
                                                          ? Colors.white.withValues(alpha: 0.06)
                                                          : const Color(0xFFF0EDF5),
                                                      borderRadius: BorderRadius.circular(5),
                                                      border: Border.all(
                                                        color: isDark
                                                            ? Colors.white.withValues(alpha: 0.08)
                                                            : const Color(0xFFDDD8E6),
                                                        width: 0.5,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      '${attr.name}: ${attr.value}',
                                                      style: TextStyle(
                                                        fontFamily: 'Inter',
                                                        fontSize: 8,
                                                        fontWeight: FontWeight.w600,
                                                        color: isDark ? Colors.white54 : const Color(0xFF5A4978),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                    // Price & Deal Tag - prominent burgundy highlight
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₱${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: TeknoyTheme.citMaroon,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Campus Meetup',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                              fontSize: 8.5,
                              color: isDark ? Colors.white38 : const Color(0xFF8E8895),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
