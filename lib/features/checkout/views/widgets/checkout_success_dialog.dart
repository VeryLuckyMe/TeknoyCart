import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../order_history_view.dart';

class CheckoutSuccessDialog extends StatelessWidget {
  final bool isPreorder;
  final double totalPrice;
  final VoidCallback? onViewOrders;

  const CheckoutSuccessDialog({
    super.key,
    required this.isPreorder,
    required this.totalPrice,
    this.onViewOrders,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isPreorder,
    required double totalPrice,
    VoidCallback? onViewOrders,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CheckoutSuccessDialog(
        isPreorder: isPreorder,
        totalPrice: totalPrice,
        onViewOrders: onViewOrders,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? TeknoyTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? TeknoyTheme.darkBorder : TeknoyTheme.lightBorder,
          width: 1,
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.25 : 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: TeknoyTheme.citGold, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isPreorder ? 'Pre-Order Secured!' : 'Meetup Deal Logged!',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? Colors.white : TeknoyTheme.citMaroonDark,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isPreorder
                ? 'Your pre-order for ₱${totalPrice.toStringAsFixed(2)} has been secured! The seller will prepare your item and coordinate via chat once the batch is ready.'
                : 'Your order for ₱${totalPrice.toStringAsFixed(2)} has been successfully logged! 1 unit is held for your campus meetup within 24 hours.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              height: 1.5,
              color: isDark ? Colors.white70 : const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF251C12) : TeknoyTheme.citGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: TeknoyTheme.citGold.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: TeknoyTheme.citGold, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Coordinate with the seller via chat for meetup and payment verification updates.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white.withValues(alpha: 0.9) : TeknoyTheme.citMaroonDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? Colors.white70 : const Color(0xFF5A413D),
            side: BorderSide(
              color: isDark ? Colors.white24 : const Color(0xFFD0C3C0),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: const Text(
            'Back to Feed',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop(); // dismiss dialog
            if (onViewOrders != null) {
              onViewOrders!();
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const OrderHistoryView()),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: TeknoyTheme.citMaroon,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          icon: const Icon(Icons.receipt_long_rounded, size: 16),
          label: const Text(
            'View Order Details',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
