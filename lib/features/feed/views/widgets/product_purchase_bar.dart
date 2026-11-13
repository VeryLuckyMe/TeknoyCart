import 'package:flutter/material.dart';
import 'package:teknoycart/core/theme.dart';

class ProductPurchaseBar extends StatelessWidget {
  final bool isDark;
  final int cartCount;
  final bool isInitializingChat;
  final int availableStock;
  final bool isPreorderEnabled;
  final bool isLoadingInventory;
  final VoidCallback? onChatPressed;
  final VoidCallback onAddToCartPressed;
  final VoidCallback? onMakeOfferPressed;
  final VoidCallback? onBuyNowPressed;

  /// False for organisation/official stores, which sell at fixed prices.
  final bool showMakeOffer;

  const ProductPurchaseBar({
    super.key,
    required this.isDark,
    required this.cartCount,
    required this.isInitializingChat,
    required this.availableStock,
    required this.isPreorderEnabled,
    required this.isLoadingInventory,
    required this.onChatPressed,
    required this.onAddToCartPressed,
    required this.onMakeOfferPressed,
    required this.onBuyNowPressed,
    this.showMakeOffer = true,
  });

  String get _actionButtonText {
    if (availableStock > 0) return 'Buy Now';
    if (isPreorderEnabled) return 'Pre-Order Now';
    return 'Out of Stock';
  }

  Color _actionButtonBg(bool isDark) {
    if (availableStock > 0) return TeknoyTheme.citMaroon;
    if (isPreorderEnabled) return TeknoyTheme.warningDark;
    return isDark ? Colors.white12 : Colors.grey.shade300;
  }

  Color _actionButtonFg(bool isDark) {
    if (availableStock > 0 || isPreorderEnabled) return Colors.white;
    return isDark ? Colors.white38 : Colors.grey.shade600;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 360;

        return Container(
          padding: EdgeInsets.fromLTRB(
            isSmallScreen ? 10 : 16,
            10,
            isSmallScreen ? 10 : 16,
            MediaQuery.of(context).padding.bottom + 8,
          ),
          decoration: BoxDecoration(
            color: isDark ? TeknoyTheme.darkSurface : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? TeknoyTheme.darkBorder : TeknoyTheme.lightBorder,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Chat Quick Action (48dp target)
              InkWell(
                onTap: isInitializingChat ? null : onChatPressed,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF202028) : const Color(0xFFF5F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E2E38) : const Color(0xFFE4E4EB),
                    ),
                  ),
                  child: Center(
                    child: isInitializingChat
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: TeknoyTheme.citMaroon,
                            ),
                          )
                        : Semantics(
                            label: 'Message seller',
                            button: true,
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: isDark ? Colors.white70 : TeknoyTheme.citMaroon,
                              size: 20,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Cart Quick Action with Badge (48dp target)
              InkWell(
                onTap: onAddToCartPressed,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF202028) : const Color(0xFFF5F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E2E38) : const Color(0xFFE4E4EB),
                    ),
                  ),
                  child: Center(
                    child: Badge(
                      isLabelVisible: cartCount > 0,
                      label: Text(
                        '$cartCount',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: TeknoyTheme.citMaroon,
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: isDark ? Colors.white70 : TeknoyTheme.citMaroon,
                        size: 21,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Make an Offer (Tawad) Action Button — hidden for fixed-price org stores
              if (showMakeOffer) ...[
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (!isLoadingInventory &&
                            (availableStock > 0 || isPreorderEnabled))
                        ? onMakeOfferPressed
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TeknoyTheme.citGold,
                      foregroundColor: const Color(0xFF4A3800),
                      disabledBackgroundColor:
                          isDark ? Colors.white12 : Colors.grey.shade300,
                      disabledForegroundColor:
                          isDark ? Colors.white38 : Colors.grey.shade600,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.handshake_outlined, size: 16),
                        SizedBox(width: 5),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Make Offer',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ],

              // Buy Now / Pre-Order Action Button
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (availableStock > 0 || isPreorderEnabled) ? onBuyNowPressed : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _actionButtonBg(isDark),
                      disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                      foregroundColor: _actionButtonFg(isDark),
                      disabledForegroundColor: isDark ? Colors.white38 : Colors.grey.shade600,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _actionButtonText,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
