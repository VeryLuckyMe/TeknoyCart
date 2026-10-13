import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/core/widgets/navigation_drawer.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/chat/views/inbox_view.dart';
import 'package:teknoycart/features/checkout/views/order_history_view.dart';
import 'package:teknoycart/features/checkout/providers/cart_provider.dart';
import 'package:teknoycart/features/checkout/views/cart_view.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';
import 'package:teknoycart/core/providers/notification_provider.dart';
import 'package:teknoycart/core/models/notification_item.dart';
import 'package:teknoycart/features/checkout/views/order_detail_view.dart';
import 'tabs/browse_tab.dart';
import 'tabs/sell_tab.dart';
import 'tabs/profile_tab.dart';

// Export for compatibility with other modules & tests
export 'tabs/profile_tab.dart' show userCompletedDealsCountProvider, TextStyles;

/// Product Discovery Feed representing Figma Node 1:39.
/// Main marketplace landing hub for listing, browsing, and searching products.
/// Modularized into BrowseTab, SellTab, and ProfileTab (HIGH-04).
class ProductDiscoveryFeedView extends ConsumerStatefulWidget {
  final int initialTab;

  const ProductDiscoveryFeedView({
    super.key,
    this.initialTab = 0,
  });

  @override
  ConsumerState<ProductDiscoveryFeedView> createState() => _ProductDiscoveryFeedViewState();
}

class _ProductDiscoveryFeedViewState extends ConsumerState<ProductDiscoveryFeedView> {
  late int _activeTab;
  StreamSubscription<AuthState>? _recoverySub;
  late final Set<int> _loadedTabs = {_activeTab};
  final Map<int, Widget> _cachedTabs = {};

  void _onTabSelected(int index) {
    HapticFeedback.selectionClick();
    if (_activeTab == index) {
      if (index == 0) {
        ref.read(productsListNotifierProvider.notifier).refresh();
      }
      return;
    }
    setState(() {
      _activeTab = index;
      _loadedTabs.add(index);
    });
  }

  Widget _getTabWidget(int index) {
    if (_cachedTabs.containsKey(index)) return _cachedTabs[index]!;
    Widget tab;
    switch (index) {
      case 0:
        tab = const BrowseTab();
        break;
      case 1:
        tab = const InboxView(embedded: true);
        break;
      case 2:
        tab = SellTab(onNavigateTab: _onTabSelected);
        break;
      case 3:
        tab = const OrderHistoryView(embedded: true);
        break;
      case 4:
        tab = ProfileTab(onNavigateTab: _onTabSelected);
        break;
      default:
        tab = const SizedBox.shrink();
    }
    _cachedTabs[index] = tab;
    return tab;
  }

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _loadedTabs.add(_activeTab);

    _recoverySub = SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showSetNewPasswordSheet(context);
          }
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = Uri.base;
      if (uri.fragment.contains('type=recovery') || uri.queryParameters['type'] == 'recovery') {
        if (mounted) {
          _showSetNewPasswordSheet(context);
        }
      }
    });
  }

  @override
  void dispose() {
    _recoverySub?.cancel();
    super.dispose();
  }

  void _showSetNewPasswordSheet(BuildContext context) {
    final passCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Set New Password',
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please enter your new password below.',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    final newPass = passCtrl.text.trim();
                    if (newPass.length < 6) return;
                    Navigator.pop(ctx);
                    try {
                      await SupabaseConfig.client.auth.updateUser(UserAttributes(password: newPass));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password updated successfully!')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF800000),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Update Password', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final notificationsAsync = ref.watch(notificationProvider);
          final unreadCount = ref.watch(unreadNotificationCountProvider);

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141418) : const Color(0xFFFFFFFF),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: TeknoyTheme.kElevationHigh,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Notifications',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: TeknoyTheme.citMaroon,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (unreadCount > 0)
                      TextButton(
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          try {
                            await ref.read(notificationProvider.notifier).markAllAsRead();
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to mark all as read. Please try again.'),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text(
                          'Mark all as read',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: TeknoyTheme.citMaroon,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: isDark ? const Color(0xFF26262B) : const Color(0xFFEAEAEE)),
                Flexible(
                  child: notificationsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: TeknoyTheme.citMaroon,
                        ),
                      ),
                    ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          const Text('Could not load notifications', style: TextStyle(fontFamily: 'Inter', fontSize: 14)),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => ref.read(notificationProvider.notifier).refresh(),
                            child: const Text('Retry', style: TextStyle(color: TeknoyTheme.citMaroon)),
                          ),
                        ],
                      ),
                    ),
                    data: (items) {
                      if (items.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_none_rounded,
                                size: 48,
                                color: isDark ? Colors.white30 : Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No new notifications',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Updates on orders, payments, and account status will show up here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: isDark ? const Color(0xFF26262B) : const Color(0xFFF0F0F4),
                        ),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _buildNotificationTile(context, ref, item, isDark);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    WidgetRef ref,
    NotificationItem item,
    bool isDark,
  ) {
    IconData icon;
    Color iconColor;
    Color iconBg;

    switch (item.type) {
      case 'PAYMENT':
        icon = Icons.account_balance_wallet_rounded;
        iconColor = TeknoyTheme.citGold;
        iconBg = TeknoyTheme.citGold.withValues(alpha: 0.15);
        break;
      case 'KYC':
        icon = Icons.verified_user_rounded;
        iconColor = const Color(0xFF1E88E5);
        iconBg = const Color(0xFF1E88E5).withValues(alpha: 0.15);
        break;
      case 'OFFER':
        icon = Icons.local_offer_rounded;
        iconColor = Colors.orangeAccent;
        iconBg = Colors.orangeAccent.withValues(alpha: 0.15);
        break;
      case 'ORDER_STATUS':
      default:
        icon = Icons.shopping_bag_rounded;
        iconColor = TeknoyTheme.citMaroon;
        iconBg = TeknoyTheme.citMaroon.withValues(alpha: 0.15);
        break;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        HapticFeedback.lightImpact();
        final nav = Navigator.of(context);
        final scaffoldMessenger = ScaffoldMessenger.of(context);

        if (!item.isRead) {
          try {
            await ref.read(notificationProvider.notifier).markAsRead(item.id);
          } catch (e) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Could not update notification state')),
            );
          }
        }

        nav.pop();

        if (item.referenceType == 'ORDER' && item.referenceId != null && item.referenceId!.isNotEmpty) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => OrderDetailView(
                order: {'order_id': item.referenceId!},
                isSeller: item.title.contains('Payment') || item.title.contains('Sale') || item.title.contains('New Order'),
              ),
            ),
          );
        } else if (item.referenceType == 'KYC') {
          _onTabSelected(2);
        } else if (item.referenceType == 'CHAT') {
          _onTabSelected(1);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 14,
                            fontWeight: item.isRead ? FontWeight.w500 : FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        item.timeAgo,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.body,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!item.isRead) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: TeknoyTheme.citMaroon,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabBody(BuildContext context) {
    return IndexedStack(
      index: _activeTab,
      children: List.generate(5, (index) {
        if (!_loadedTabs.contains(index)) {
          return const SizedBox.shrink();
        }
        return _getTabWidget(index);
      }),
    );
  }

  Widget _buildBottomNavItem(
    BuildContext context, {
    required IconData icon,
    IconData? activeIcon,
    required String label,
    required bool isActive,
    bool isActionFocus = false,
    bool hasBadge = false,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? const Color(0xFFFF8585) : TeknoyTheme.citMaroon;
    final inactiveColor = isDark ? Colors.white54 : const Color(0xFF757575);
    final currentIcon = (isActive && activeIcon != null) ? activeIcon : icon;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      splashColor: TeknoyTheme.citMaroon.withValues(alpha: 0.12),
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 13 : 9,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark
                  ? const Color(0xFF350E14)
                  : TeknoyTheme.citMaroon.withValues(alpha: 0.10))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: isActive
              ? Border.all(
                  color: isDark
                      ? TeknoyTheme.citMaroon.withValues(alpha: 0.70)
                      : TeknoyTheme.citMaroon.withValues(alpha: 0.22),
                  width: 1.2,
                )
              : null,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.45 : 0.18),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isActive ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    currentIcon,
                    size: 21,
                    color: isActive ? activeColor : inactiveColor,
                  ),
                  if (hasBadge)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD90429),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF0F0F12) : Colors.white,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: Alignment.centerLeft,
              child: isActive
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 6),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: activeColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            // TikTok-inspired animated accent bar
                            Container(
                              height: 2,
                              width: 14,
                              decoration: BoxDecoration(
                                color: activeColor,
                                borderRadius: BorderRadius.circular(1),
                                boxShadow: [
                                  BoxShadow(
                                    color: TeknoyTheme.citMaroon.withValues(alpha: 0.6),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F0F12) : Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu_rounded, color: TeknoyTheme.citMaroon),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'Navigation Drawer',
            );
          },
        ),
        title: Text(
          _activeTab == 0
              ? 'TeknoyCart'
              : _activeTab == 1
                  ? 'Messages'
                  : _activeTab == 2
                      ? 'Sell Items'
                      : _activeTab == 3
                          ? 'My Orders'
                          : 'Wildcat Profile',
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w800,
            fontSize: 21,
            letterSpacing: -0.5,
            color: TeknoyTheme.citMaroon,
          ),
        ),
        centerTitle: true,
        actions: [
          // ── 1. Shopping Cart Action ──
          Consumer(
            builder: (context, ref, child) {
              final cart = ref.watch(cartProvider);
              final itemCount = cart.fold<int>(0, (sum, item) => sum + item.quantity);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shopping_cart_outlined,
                      color: isDark ? Colors.white70 : const Color(0xFF5A413D),
                      size: 22,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CartView(),
                        ),
                      );
                    },
                    tooltip: 'Shopping Cart',
                  ),
                  if (itemCount > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD90429),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF0F0F12) : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$itemCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          // ── 2. Notification Action ──
          Consumer(
            builder: (context, ref, child) {
              final unreadCount = ref.watch(unreadNotificationCountProvider);
              final hasUnreadNotifications = unreadCount > 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.notifications_outlined,
                      color: isDark ? Colors.white70 : const Color(0xFF5A413D),
                      size: 22,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _showNotificationsSheet(context);
                    },
                    tooltip: 'Notifications',
                  ),
                  if (hasUnreadNotifications)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD90429),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF0F0F12) : Colors.white,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      drawer: TeknoyNavigationDrawer(
        onSelectTab: _onTabSelected,
        currentTabIndex: _activeTab,
      ),
      body: _buildActiveTabBody(context),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F0F12) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF282830) : Colors.grey.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
            _buildBottomNavItem(
              context,
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
              isActive: _activeTab == 0,
              onTap: () => _onTabSelected(0),
            ),
            _buildBottomNavItem(
              context,
              icon: Icons.forum_outlined,
              activeIcon: Icons.forum_rounded,
              label: 'Messages',
              isActive: _activeTab == 1,
              hasBadge: false,
              onTap: () => _onTabSelected(1),
            ),
            _buildBottomNavItem(
              context,
              icon: Icons.add_circle_outline_rounded,
              activeIcon: Icons.add_circle_rounded,
              label: 'Sell',
              isActive: _activeTab == 2,
              isActionFocus: true,
              onTap: () => _onTabSelected(2),
            ),
            _buildBottomNavItem(
              context,
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              label: 'Orders',
              isActive: _activeTab == 3,
              hasBadge: false,
              onTap: () => _onTabSelected(3),
            ),
            _buildBottomNavItem(
              context,
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
              isActive: _activeTab == 4,
              onTap: () => _onTabSelected(4),
            ),
          ],
        ),
      ),
    ),
  );
}
}
