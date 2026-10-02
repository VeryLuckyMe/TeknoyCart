import 'package:flutter/material.dart';
import 'package:teknoycart/core/theme.dart';

class ChatNegotiationBanner extends StatelessWidget {
  final String activeState;
  final double activeOfferPrice;
  final double askingPrice;
  final bool isBuyer;
  final VoidCallback onOfferPrice;
  final VoidCallback onCheckout;

  const ChatNegotiationBanner({
    super.key,
    required this.activeState,
    required this.activeOfferPrice,
    required this.askingPrice,
    required this.isBuyer,
    required this.onOfferPrice,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: activeState == 'agreed' || activeState == 'completed'
            ? TeknoyTheme.success.withValues(alpha: 0.08)
            : activeState == 'offered'
                ? TeknoyTheme.citGold.withValues(alpha: 0.08)
                : TeknoyTheme.citMaroon.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(
            color: activeState == 'agreed' || activeState == 'completed'
                ? TeknoyTheme.success.withValues(alpha: 0.2)
                : activeState == 'offered'
                    ? TeknoyTheme.citGold.withValues(alpha: 0.2)
                    : TeknoyTheme.citMaroon.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  activeState == 'agreed' || activeState == 'completed'
                      ? Icons.check_circle_rounded
                      : activeState == 'offered'
                          ? Icons.hourglass_empty_rounded
                          : Icons.info_outline_rounded,
                  size: 20,
                  color: activeState == 'agreed' || activeState == 'completed'
                      ? TeknoyTheme.success
                      : activeState == 'offered'
                          ? TeknoyTheme.citGold
                          : TeknoyTheme.citMaroon,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activeState == 'agreed'
                        ? 'Deal Agreed: ₱${activeOfferPrice.toStringAsFixed(2)}!'
                        : activeState == 'completed'
                            ? 'Deal Finalized! Meetup Scheduled.'
                            : activeState == 'offered'
                                ? 'Offered Price: ₱${activeOfferPrice.toStringAsFixed(2)}...'
                                : 'Asking Price: ₱${askingPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: activeState == 'agreed' || activeState == 'completed'
                          ? TeknoyTheme.success
                          : const Color(0xFF191C1D),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (activeState == 'completed') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: TeknoyTheme.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'COMPLETED',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: TeknoyTheme.success,
                ),
              ),
            ),
          ] else if (activeState != 'agreed') ...[
            if (isBuyer)
              TextButton.icon(
                onPressed: onOfferPrice,
                icon: const Icon(Icons.handshake_outlined, size: 16, color: TeknoyTheme.citMaroon),
                label: const Text(
                  'Offer Price',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    color: TeknoyTheme.citMaroon,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ] else ...[
            if (isBuyer)
              ElevatedButton.icon(
                onPressed: onCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TeknoyTheme.success,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 16),
                label: const Text(
                  'Checkout Deal',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
