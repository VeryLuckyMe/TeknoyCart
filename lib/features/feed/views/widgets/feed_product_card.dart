import 'package:flutter/material.dart';
import '../../../../core/models/product.dart';
import '../../../../core/theme.dart';

class FeedProductCard extends StatelessWidget {
  final Product product;

  const FeedProductCard({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
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

                  // Condition Badge (top-left) - modern rounded tag
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                      decoration: BoxDecoration(
                        color: badgeBg.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
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
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),

                  // Wishlist / Favorite Button (top-right) - premium glassmorphism
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.favorite_rounded,
                          size: 16,
                          color: TeknoyTheme.citMaroon,
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
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 13, color: TeknoyTheme.citGold),
                            const SizedBox(width: 3),
                            Text(
                              '4.8',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isDark ? Colors.white70 : const Color(0xFF5A413D),
                              ),
                            ),
                          ],
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
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Column(
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
                                  ],
                                ),
                              ),
                            Text(
                              product.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                height: 1.2,
                                color: isDark ? Colors.white : const Color(0xFF191C1D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Price - prominent burgundy highlight
                    Text(
                      '₱${product.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: TeknoyTheme.citMaroon,
                        letterSpacing: -0.5,
                      ),
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
