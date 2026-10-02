import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/models/review.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/feed/providers/review_provider.dart';
import 'package:teknoycart/features/feed/views/widgets/seller_reply_dialog.dart';

/// Modal bottom sheet showcasing all verified buyer reviews and ratings for a seller.
class BuyerReviewsSheet extends ConsumerStatefulWidget {
  final String sellerId;
  final String sellerName;

  const BuyerReviewsSheet({
    super.key,
    required this.sellerId,
    required this.sellerName,
  });

  @override
  ConsumerState<BuyerReviewsSheet> createState() => _BuyerReviewsSheetState();
}

class _BuyerReviewsSheetState extends ConsumerState<BuyerReviewsSheet> {
  String _selectedFilter = 'All'; // 'All', '5', '4', '3', 'Photos'
  bool _showSampleDemoReviews = false;

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

  void _openSellerReplyDialog(BuildContext context, Review review) {
    showDialog(
      context: context,
      builder: (ctx) => SellerReplyDialog(review: review),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = ref.watch(authStateProvider).valueOrNull?.id;
    final isStoreOwner = currentUserId != null && currentUserId == widget.sellerId;

    // Fetch live reviews for this seller
    final liveReviews = ref.watch(reviewsForSellerProvider(widget.sellerId));
    
    // If current seller has no reviews yet but demo mode is on or mock seller is queried
    final reviewsToDisplay = liveReviews.isNotEmpty
        ? liveReviews
        : (_showSampleDemoReviews || widget.sellerId == 'usr-seller'
            ? ref.watch(reviewsNotifierProvider).where((r) => r.sellerId == 'usr-seller').toList()
            : <Review>[]);

    final avgRating = reviewsToDisplay.averageRating;
    final dist = reviewsToDisplay.ratingDistribution;
    final total = reviewsToDisplay.length;

    // Filter reviews
    final filteredReviews = reviewsToDisplay.where((r) {
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Photos') return r.imageUrls.isNotEmpty;
      final star = int.tryParse(_selectedFilter);
      if (star != null) return r.rating == star;
      return true;
    }).toList();

    final bgColor = isDark ? const Color(0xFF141418) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E1E24) : const Color(0xFFF9F9FB);
    final borderColor = isDark ? const Color(0xFF2E2E36) : const Color(0xFFEAEAEE);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Handle Pill ──
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header Bar ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF22C55E),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Buyer Reviews',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.sellerName.isNotEmpty
                                ? 'Ratings & feedback for ${widget.sellerName}'
                                : 'Ratings & feedback from campus buyers',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // ── Scrollable Content ──
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    // ── 1. Ratings Overview Card ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          // Left side: Big Rating Score
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                total > 0 ? avgRating.toStringAsFixed(1) : '5.0',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  color: TeknoyTheme.citMaroon,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(5, (index) {
                                  final starIndex = index + 1;
                                  final isFull = starIndex <= avgRating.round();
                                  return Icon(
                                    isFull ? Icons.star_rounded : Icons.star_outline_rounded,
                                    color: const Color(0xFFF59E0B),
                                    size: 16,
                                  );
                                }),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                total > 0 ? '$total buyer ${total == 1 ? 'review' : 'reviews'}' : 'No ratings yet',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(width: 16),
                          Container(width: 1, height: 75, color: borderColor),
                          const SizedBox(width: 16),

                          // Right side: Rating Distribution Bars
                          Expanded(
                            child: Column(
                              children: [5, 4, 3, 2, 1].map((stars) {
                                final count = dist[stars] ?? 0;
                                final fraction = total > 0 ? count / total : 0.0;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 14,
                                        child: Text(
                                          '$stars',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: fraction,
                                            minHeight: 5,
                                            backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                                            valueColor: const AlwaysStoppedAnimation<Color>(TeknoyTheme.citGold),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 18,
                                        child: Text(
                                          '$count',
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 10,
                                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── 2. Filter Chips ──
                    if (total > 0) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All', 'All ($total)', isDark),
                            const SizedBox(width: 8),
                            _buildFilterChip('5', '5 Stars (${dist[5] ?? 0})', isDark),
                            const SizedBox(width: 8),
                            _buildFilterChip('4', '4 Stars (${dist[4] ?? 0})', isDark),
                            const SizedBox(width: 8),
                            _buildFilterChip('3', '3 Stars (${dist[3] ?? 0})', isDark),
                            const SizedBox(width: 8),
                            _buildFilterChip('Photos', 'With Photos', isDark),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── 3. Reviews List or Empty State ──
                    if (filteredReviews.isEmpty)
                      _buildEmptyState(isDark, total, isStoreOwner)
                    else
                      ...filteredReviews.map((review) => _buildReviewCard(
                            review: review,
                            isDark: isDark,
                            cardBg: cardBg,
                            borderColor: borderColor,
                            isStoreOwner: isStoreOwner,
                          )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String filterKey, String label, bool isDark) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = filterKey),
      selectedColor: TeknoyTheme.citMaroon,
      backgroundColor: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF2F2F6),
      labelStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected
              ? TeknoyTheme.citMaroon
              : (isDark ? const Color(0xFF2E2E36) : const Color(0xFFE0E0E4)),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, int totalCount, bool isStoreOwner) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: TeknoyTheme.citMaroon.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rate_review_outlined,
              size: 44,
              color: TeknoyTheme.citMaroon,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            totalCount == 0 ? 'No Buyer Reviews Yet' : 'No Reviews Match Filter',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            totalCount == 0
                ? 'When campus buyers complete transactions and leave feedback for your listings, their ratings, tags, and reviews will appear here.'
                : 'Try selecting a different star filter above.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          if (totalCount == 0 && !_showSampleDemoReviews) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => setState(() => _showSampleDemoReviews = true),
              style: OutlinedButton.styleFrom(
                foregroundColor: TeknoyTheme.citMaroon,
                side: const BorderSide(color: TeknoyTheme.citMaroon),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text(
                'Preview Sample Buyer Reviews',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewCard({
    required Review review,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required bool isStoreOwner,
  }) {
    final buyerInitial = review.displayInitial;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Buyer Avatar, Name, Verified Tag, Date ──
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: TeknoyTheme.citMaroon.withValues(alpha: 0.12),
                child: Text(
                  buyerInitial,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    color: TeknoyTheme.citMaroon,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            review.effectiveBuyerName,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, size: 10, color: Color(0xFF22C55E)),
                              SizedBox(width: 3),
                              Text(
                                'Verified Buyer',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF22C55E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatRelativeTime(review.createdAt),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              // Stars
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return Icon(
                    index < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 16,
                  );
                }),
              ),
            ],
          ),

          // ── Variant Purchased info pill ──
          if (review.variantName != null && review.variantName!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 12, color: isDark ? Colors.white54 : Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Purchased: ${review.variantName}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Feedback Tags ──
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: review.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.2 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: TeknoyTheme.citMaroon.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: TeknoyTheme.citMaroon,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // ── Comment Body ──
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.45,
                color: isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF2C2C30),
              ),
            ),
          ],

          // ── Review Photos ──
          if (review.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.imageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, imgIdx) {
                  final url = review.imageUrls[imgIdx];
                  return GestureDetector(
                    onTap: () => _openImageLightbox(context, url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        url,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          color: isDark ? Colors.white12 : Colors.grey.shade200,
                          child: const Icon(Icons.broken_image_rounded, size: 24),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // ── Seller Official Reply Box ──
          if (review.hasSellerReply) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF25252E) : const Color(0xFFF1F1F5),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(
                    color: TeknoyTheme.citMaroon,
                    width: 3.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded, size: 14, color: TeknoyTheme.citMaroon),
                      const SizedBox(width: 6),
                      Text(
                        'Seller Response',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDark ? Colors.white : TeknoyTheme.citMaroon,
                        ),
                      ),
                      const Spacer(),
                      if (review.sellerRepliedAt != null)
                        Text(
                          _formatRelativeTime(review.sellerRepliedAt!),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    review.sellerReply!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      height: 1.4,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isStoreOwner) ...[
            // Seller can reply directly if it's their listing
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openSellerReplyDialog(context, review),
                style: TextButton.styleFrom(
                  foregroundColor: TeknoyTheme.citMaroon,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.reply_rounded, size: 15),
                label: const Text(
                  'Reply to Buyer',
                  style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 30) {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
