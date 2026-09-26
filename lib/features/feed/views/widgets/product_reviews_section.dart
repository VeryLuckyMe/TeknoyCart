import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/core/models/review.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/feed/providers/review_provider.dart';
import 'package:teknoycart/features/feed/views/widgets/review_submission_sheet.dart';
import 'package:teknoycart/features/feed/views/widgets/seller_reply_dialog.dart';

/// Full-featured, interactive ratings & reviews widget for ProductDetailsSheet
class ProductReviewsSection extends ConsumerStatefulWidget {
  final Product product;

  const ProductReviewsSection({super.key, required this.product});

  @override
  ConsumerState<ProductReviewsSection> createState() => _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends ConsumerState<ProductReviewsSection> {
  String _selectedFilter = 'All'; // 'All', '5', '4', '3', 'Photos'

  void _openImageLightbox(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditReviewSheet(BuildContext context, Review review) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReviewSubmissionSheet(
        productId: widget.product.id,
        productTitle: widget.product.title,
        productImageUrl: widget.product.imageUrl,
        orderId: review.orderId,
        sellerId: widget.product.sellerId,
        variantName: review.variantName,
        existingReview: review,
      ),
    );
  }

  void _openSellerReplyDialog(BuildContext context, Review review) {
    showDialog(
      context: context,
      builder: (ctx) => SellerReplyDialog(review: review),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allReviews = ref.watch(reviewsForProductProvider(widget.product.id));
    final currentUserId = ref.watch(authStateProvider).valueOrNull?.id;
    final isSeller = currentUserId == widget.product.sellerId;

    // Filter reviews
    final filteredReviews = allReviews.where((r) {
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Photos') return r.imageUrls.isNotEmpty;
      final star = int.tryParse(_selectedFilter);
      if (star != null) return r.rating == star;
      return true;
    }).toList();

    final avgRating = allReviews.averageRating;
    final dist = allReviews.ratingDistribution;
    final total = allReviews.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141418) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF22222A) : const Color(0xFFECECEF),
        ),
        boxShadow: TeknoyTheme.kElevationLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: TeknoyTheme.citGold.withOpacity(isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.star_rounded, size: 16, color: TeknoyTheme.citGold),
              ),
              const SizedBox(width: 10),
              const Text(
                'Ratings & Reviews',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: TeknoyTheme.citMaroon.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$total',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: TeknoyTheme.citMaroon,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (total == 0) ...[
            // Empty State
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 38,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No reviews yet',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Verified Wildcat buyers who complete a meetup will leave feedback here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Rating Overview Score & Star Distribution Bars
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF191922) : const Color(0xFFF9F9FB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                ),
              ),
              child: Row(
                children: [
                  // Left side: Big number & stars
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        avgRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (idx) {
                          return Icon(
                            idx < avgRating.round()
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 15,
                            color: TeknoyTheme.citGold,
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$total ${total == 1 ? 'review' : 'reviews'}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 18),
                  Container(
                    width: 1,
                    height: 60,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  const SizedBox(width: 18),

                  // Right side: 5-bar distribution chart
                  Expanded(
                    child: Column(
                      children: List.generate(5, (index) {
                        final star = 5 - index;
                        final count = dist[star] ?? 0;
                        final ratio = total > 0 ? count / total : 0.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: Row(
                            children: [
                              Text(
                                '$star',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.star_rounded, size: 10, color: TeknoyTheme.citGold),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: ratio,
                                    minHeight: 5,
                                    backgroundColor: isDark ? Colors.white12 : Colors.black12,
                                    valueColor: const AlwaysStoppedAnimation<Color>(TeknoyTheme.citGold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 18,
                                child: Text(
                                  '$count',
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'All ($total)', isDark),
                  _buildFilterChip('5', '5 ★ (${dist[5] ?? 0})', isDark),
                  _buildFilterChip('4', '4 ★ (${dist[4] ?? 0})', isDark),
                  _buildFilterChip('3', '3 ★ (${dist[3] ?? 0})', isDark),
                  _buildFilterChip(
                    'Photos',
                    'With Photos (${allReviews.where((r) => r.imageUrls.isNotEmpty).length})',
                    isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // List of Review Cards
            ...filteredReviews.map((review) {
              final isBuyer = currentUserId != null && currentUserId == review.buyerId;
              final canSellerReply = isSeller && !review.hasReply;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF181820) : const Color(0xFFFBFBFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reviewer Header Row
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: TeknoyTheme.citMaroon,
                          child: Text(
                            review.displayInitial,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      review.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: TeknoyTheme.success.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_rounded, size: 10, color: TeknoyTheme.success),
                                        SizedBox(width: 2),
                                        Text(
                                          'Verified',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: TeknoyTheme.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  // Star icons
                                  ...List.generate(
                                    5,
                                    (i) => Icon(
                                      i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                      size: 13,
                                      color: TeknoyTheme.citGold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatTimeAgo(review.createdAt),
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Edit button if current user is the buyer
                        if (isBuyer)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            color: TeknoyTheme.citMaroon,
                            tooltip: 'Edit Review',
                            onPressed: () => _openEditReviewSheet(context, review),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),

                    // Variant Tag if any
                    if (review.variantName != null && review.variantName!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Variation: ${review.variantName}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                    ],

                    // Quick Tags Wrap
                    if (review.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: review.tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: TeknoyTheme.citMaroon.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '# $tag',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: TeknoyTheme.citMaroon,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    // Review Comment Text
                    const SizedBox(height: 8),
                    Text(
                      review.comment,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.4,
                      ),
                    ),

                    // Photos Thumbnails with Lightbox
                    if (review.imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: review.imageUrls.map((url) {
                          return GestureDetector(
                            onTap: () => _openImageLightbox(context, url),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? Colors.white12 : Colors.black12,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, size: 24),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    // Seller Reply Box
                    if (review.hasReply) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF14141A) : const Color(0xFFF1F1F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(color: TeknoyTheme.citMaroon, width: 3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.storefront_rounded, size: 12, color: TeknoyTheme.citMaroon),
                                const SizedBox(width: 4),
                                const Text(
                                  'Seller Response',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: TeknoyTheme.citMaroon,
                                  ),
                                ),
                                if (review.sellerRepliedAt != null) ...[
                                  const Spacer(),
                                  Text(
                                    _formatTimeAgo(review.sellerRepliedAt!),
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              review.sellerReply!,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: isDark ? Colors.white70 : Colors.black87,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Seller Reply Button
                    if (canSellerReply) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _openSellerReplyDialog(context, review),
                          icon: const Icon(Icons.reply_rounded, size: 14, color: TeknoyTheme.citMaroon),
                          label: const Text(
                            'Reply as Seller',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: TeknoyTheme.citMaroon,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, bool isDark) {
    final isSelected = _selectedFilter == filterKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _selectedFilter = filterKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? TeknoyTheme.citMaroon
                : (isDark ? const Color(0xFF1E1E28) : const Color(0xFFF1F1F5)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? TeknoyTheme.citMaroon : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
