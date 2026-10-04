import 'package:cached_network_image/cached_network_image.dart';
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
                            ? CachedNetworkImage(
                                imageUrl: product.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: isDark ? const Color(0xFF1C1C22) : const Color(0xFFF3F3F5),
                                ),
                                errorWidget: (context, url, error) => const Center(
                                  child: Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 28),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.image_rounded, color: Colors.grey, size: 28),
                              ),
                      ),
                    ),
                  ),

                  // Condition Badge (top-left) - Refined institutional micro-tag
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: badgeBg.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
                          )
                        ],
                      ),
                      child: Text(
                        product.condition.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w800,
                          fontSize: 9.5,
                          color: badgeText,
                          letterSpacing: 0.5,
                        ),
                      ),
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

            // 2. Dense Layout Info Area with Clear Visual Hierarchy
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Product Title (Clear, scan-friendly, max 2 lines)
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.2,
                        color: isDark ? Colors.white : const Color(0xFF191C1D),
                      ),
                    ),
                    const SizedBox(height: 3),

                    // 2. Price (Prominent institutional maroon)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₱${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                            color: TeknoyTheme.citMaroon,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 5),
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
                    const SizedBox(height: 3),

                    // 3. Seller Store & CIT-U verified badge
                    if (product.sellerStoreName != null && product.sellerStoreName!.trim().isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.storefront_rounded, size: 10.5, color: TeknoyTheme.citMaroon),
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
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: TeknoyTheme.citMaroon,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: TeknoyTheme.citGold.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: TeknoyTheme.citGold, width: 0.6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified_rounded, size: 8, color: TeknoyTheme.citMaroon),
                                      SizedBox(width: 1.5),
                                      Text(
                                        'CIT-U',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 7,
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
                      const SizedBox(height: 2),
                    ],

                    // 4. Quick attribute chips (Single horizontal scroll row to prevent vertical wrap overflow)
                    if (product.categoryAttributes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: product.categoryAttributes
                                .take(2)
                                .map((attr) => Padding(
                                      padding: const EdgeInsets.only(right: 4.0),
                                      child: Material(
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
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white54 : const Color(0xFF5A4978),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),

                    const Spacer(),

                    // 5. Rating & Category Footer
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
                                  size: 12.5,
                                  color: TeknoyTheme.citGold,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  ratingText,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    color: isDark ? Colors.white70 : const Color(0xFF5A413D),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF1F1F5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            product.category,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                              fontSize: 8,
                              color: isDark ? Colors.white70 : const Color(0xFF5A413D),
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
