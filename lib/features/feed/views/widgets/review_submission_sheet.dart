import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:teknoycart/core/models/review.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/feed/providers/review_provider.dart';

/// Interactive modal sheet allowing verified buyers to rate and review a purchased item
class ReviewSubmissionSheet extends ConsumerStatefulWidget {
  final String productId;
  final String productTitle;
  final String? productImageUrl;
  final String? orderId;
  final String sellerId;
  final String? variantName;
  final Review? existingReview;

  const ReviewSubmissionSheet({
    super.key,
    required this.productId,
    required this.productTitle,
    this.productImageUrl,
    this.orderId,
    required this.sellerId,
    this.variantName,
    this.existingReview,
  });

  @override
  ConsumerState<ReviewSubmissionSheet> createState() => _ReviewSubmissionSheetState();
}

class _ReviewSubmissionSheetState extends ConsumerState<ReviewSubmissionSheet> {
  late int _rating;
  late final TextEditingController _commentController;
  late final Set<String> _selectedTags;
  late bool _isAnonymous;
  XFile? _selectedImage;
  String? _uploadedImageUrl;
  bool _isSubmitting = false;

  final List<String> _presetTags = const [
    'Item as described',
    'Accurate sizing',
    'Fast meetup',
    'Friendly seller',
    'Great quality',
    'Would buy again',
    'Good packaging',
  ];

  @override
  void initState() {
    super.initState();
    final rev = widget.existingReview;
    _rating = rev?.rating ?? 5;
    _commentController = TextEditingController(text: rev?.comment ?? '');
    _selectedTags = Set<String>.from(rev?.tags ?? ['Item as described']);
    _isAnonymous = rev?.isAnonymous ?? false;
    if (rev != null && rev.imageUrls.isNotEmpty) {
      _uploadedImageUrl = rev.imageUrls.first;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _getRatingLabel(int stars) {
    switch (stars) {
      case 1:
        return '★ Poor';
      case 2:
        return '★★ Fair';
      case 3:
        return '★★★ Good';
      case 4:
        return '★★★★ Very Good';
      case 5:
        return '★★★★★ Excellent!';
      default:
        return '';
    }
  }

  Color _getRatingColor(int stars) {
    if (stars <= 2) return TeknoyTheme.error;
    if (stars == 3) return Colors.orange;
    return TeknoyTheme.citGold;
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = picked;
          _uploadedImageUrl = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e'), backgroundColor: TeknoyTheme.error),
        );
      }
    }
  }

  Future<void> _handleSubmit() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write a short comment about your purchase.'),
          backgroundColor: TeknoyTheme.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUser = ref.read(authStateProvider).valueOrNull;
      final buyerId = currentUser?.id ?? 'usr-buyer-current';
      final buyerName = currentUser?.username.isNotEmpty == true
          ? currentUser!.username
          : (currentUser?.email.split('@').first ?? 'CIT Student');

      // Upload photo if new image was picked
      String? finalImageUrl = _uploadedImageUrl;
      if (_selectedImage != null) {
        try {
          final fileName = 'review_${widget.productId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final bytes = await _selectedImage!.readAsBytes();
          await SupabaseConfig.client.storage
              .from('product-images')
              .uploadBinary(
                fileName,
                bytes,
                fileOptions: FileOptions(contentType: 'image/jpeg', upsert: true),
              );
          finalImageUrl = SupabaseConfig.client.storage
              .from('product-images')
              .getPublicUrl(fileName);
        } catch (_) {
          // If storage fails, continue without blocking review submission
        }
      }

      final imageUrls = finalImageUrl != null ? [finalImageUrl] : <String>[];

      if (widget.existingReview != null) {
        await ref.read(reviewsNotifierProvider.notifier).updateReview(
              widget.existingReview!.id,
              rating: _rating,
              comment: comment,
              tags: _selectedTags.toList(),
              imageUrls: imageUrls,
              isAnonymous: _isAnonymous,
            );
      } else {
        await ref.read(reviewsNotifierProvider.notifier).submitReview(
              orderId: widget.orderId,
              productId: widget.productId,
              buyerId: buyerId,
              buyerName: buyerName,
              sellerId: widget.sellerId,
              rating: _rating,
              comment: comment,
              tags: _selectedTags.toList(),
              imageUrls: imageUrls,
              variantName: widget.variantName,
              isAnonymous: _isAnonymous,
            );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.star_rounded, color: TeknoyTheme.citGold, size: 20),
                const SizedBox(width: 8),
                Text(widget.existingReview != null ? 'Review updated successfully!' : 'Review published! Thank you for supporting peer trust.'),
              ],
            ),
            backgroundColor: TeknoyTheme.citMaroon,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving review: $e'), backgroundColor: TeknoyTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.existingReview != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 12,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Header Title & Subtitle
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: TeknoyTheme.citMaroon.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.rate_review_rounded,
                    color: TeknoyTheme.citMaroon,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Edit Your Review' : 'Rate & Review Order',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.productTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            // Variant Badge if any
            if (widget.variantName != null && widget.variantName!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: TeknoyTheme.citMaroon.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.straighten_rounded, size: 13, color: TeknoyTheme.citMaroon),
                    const SizedBox(width: 4),
                    Text(
                      'Purchased: ${widget.variantName}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: TeknoyTheme.citMaroon,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 28),

            // Star Rating Section
            Center(
              child: Column(
                children: [
                  const Text(
                    'Tap stars to rate product quality & meetup',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      final isSelected = starValue <= _rating;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = starValue),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Icon(
                            isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 38,
                            color: isSelected ? _getRatingColor(_rating) : (isDark ? Colors.white30 : Colors.black26),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getRatingLabel(_rating),
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _getRatingColor(_rating),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Quick Preset Feedback Tags
            const Text(
              'Quick feedback tags',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedTags.remove(tag);
                      } else {
                        _selectedTags.add(tag);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? TeknoyTheme.citMaroon
                          : (isDark ? const Color(0xFF1E1E28) : const Color(0xFFF1F1F5)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? TeknoyTheme.citMaroon : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          tag,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Review Comment Text Field
            const Text(
              'Written Review *',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 500,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Share your honest feedback on condition, sizing, and handoff experience to guide other CIT-U students...',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: isDark ? Colors.white30 : Colors.black38,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF1C1C24) : const Color(0xFFF9F9FB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: TeknoyTheme.citMaroon, width: 2),
                ),
              ),
            ),

            // Optional Photo Upload
            Row(
              children: [
                const Text(
                  'Item Photo (Optional)',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_selectedImage != null || _uploadedImageUrl != null)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _selectedImage = null;
                      _uploadedImageUrl = null;
                    }),
                    icon: const Icon(Icons.delete_outline_rounded, size: 15, color: TeknoyTheme.error),
                    label: const Text('Remove', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: TeknoyTheme.error)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedImage != null)
              Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TeknoyTheme.citMaroon, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: FutureBuilder<List<int>>(
                    future: _selectedImage!.readAsBytes(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Image.memory(snapshot.data as dynamic, fit: BoxFit.cover);
                      }
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    },
                  ),
                ),
              )
            else if (_uploadedImageUrl != null)
              Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TeknoyTheme.citMaroon, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(_uploadedImageUrl!, fit: BoxFit.cover),
                ),
              )
            else
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickImage,
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C24) : const Color(0xFFF9F9FB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.black26,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt_outlined, size: 20, color: TeknoyTheme.citMaroon),
                      const SizedBox(width: 8),
                      Text(
                        'Upload real photo of received item',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Anonymous Toggle Tile
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A24) : const Color(0xFFF4F5F8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _isAnonymous
                          ? TeknoyTheme.citMaroon.withValues(alpha: 0.12)
                          : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isAnonymous ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      size: 18,
                      color: _isAnonymous ? TeknoyTheme.citMaroon : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Post Anonymously',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _isAnonymous
                              ? 'Your name displays as "Wildcat Student (Verified Buyer)"'
                              : 'Your real CIT name will be visible to peer buyers',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isAnonymous,
                    activeColor: TeknoyTheme.citMaroon,
                    onChanged: (val) => setState(() => _isAnonymous = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TeknoyTheme.citMaroon,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: _isSubmitting ? null : _handleSubmit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isEditing ? 'Save Changes' : 'Publish Review',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
