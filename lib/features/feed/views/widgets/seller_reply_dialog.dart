import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/models/review.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/feed/providers/review_provider.dart';

/// Modal dialog allowing the seller to write a polite official response to a buyer review
class SellerReplyDialog extends ConsumerStatefulWidget {
  final Review review;

  const SellerReplyDialog({super.key, required this.review});

  @override
  ConsumerState<SellerReplyDialog> createState() => _SellerReplyDialogState();
}

class _SellerReplyDialogState extends ConsumerState<SellerReplyDialog> {
  late final TextEditingController _replyController;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _replyController = TextEditingController(text: widget.review.sellerReply ?? '');
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your response message.'),
          backgroundColor: TeknoyTheme.error,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await ref
          .read(reviewsNotifierProvider.notifier)
          .replyToReview(widget.review.id, text);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your seller response has been published!'),
            backgroundColor: TeknoyTheme.citMaroon,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish reply: $e'), backgroundColor: TeknoyTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TeknoyTheme.citMaroon.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.reply_rounded, color: TeknoyTheme.citMaroon, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Seller Response',
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quoted Buyer Review Preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14141A) : const Color(0xFFF7F7FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.review.displayName,
                        style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const Spacer(),
                      Row(
                        children: List.generate(
                          widget.review.rating,
                          (_) => const Icon(Icons.star_rounded, size: 14, color: TeknoyTheme.citGold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.review.comment,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Your Public Reply',
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _replyController,
              autofocus: true,
              maxLines: 4,
              maxLength: 300,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Thank the buyer or address their feedback respectfully...',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: isDark ? Colors.white30 : Colors.black38,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: TeknoyTheme.citMaroon, width: 2),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: TeknoyTheme.citMaroon,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          onPressed: _isSending ? null : _handleSend,
          child: _isSending
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Publish Reply', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
