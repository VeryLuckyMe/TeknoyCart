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

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? const Color(0xFF2A2A34) : const Color(0xFFE8E8EE),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with Success Icon & Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.25 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: TeknoyTheme.citGold,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    isPreorder ? 'Pre-Order Secured!' : 'Meetup Deal Logged!',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                      fontSize: 19,
                      color: isDark ? Colors.white : TeknoyTheme.citMaroonDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Order summary description
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

            // Info Notice Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF261E14) : TeknoyTheme.citGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: TeknoyTheme.citGold.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.info_outline_rounded, color: TeknoyTheme.citGold, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Coordinate with the seller via chat for meetup and payment verification updates.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white.withValues(alpha: 0.9) : TeknoyTheme.citMaroonDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Primary Action: View Order Details (Full Width, 48dp)
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
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
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text(
                  'View Order Details',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Secondary Action: Back to Feed (Full Width, 44dp)
            SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : const Color(0xFF5A413D),
                  side: BorderSide(
                    color: isDark ? Colors.white24 : const Color(0xFFD6CBC8),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text(
                  'Back to Feed',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
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
