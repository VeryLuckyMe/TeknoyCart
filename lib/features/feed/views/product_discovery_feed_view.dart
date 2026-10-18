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
import 'tabs/browse_tab.dart';
import 'tabs/sell_tab.dart';
import 'tabs/profile_tab.dart';
import 'notifications_view.dart';

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
        tab = InboxView(embedded: true, onNavigateTab: _onTabSelected);
        break;
      case 2:
        tab = SellTab(onNavigateTab: _onTabSelected);
        break;
      case 3:
        tab = OrderHistoryView(embedded: true, onNavigateTab: _onTabSelected);
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
            _showSetNewPasswordSheet();
          }
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = Uri.base;
      if (uri.fragment.contains('type=recovery') || uri.queryParameters['type'] == 'recovery') {
        if (mounted) {
          _showSetNewPasswordSheet();
        }
      }
    });
  }

  @override
  void dispose() {
    _recoverySub?.cancel();
    super.dispose();
  }

  void _showSetNewPasswordSheet() {
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
                    if (newPass.length < 6) {
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password must be at least 6 characters.'),
                        ),
                      );
                      return;
                    }
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
                    backgroundColor: TeknoyTheme.citMaroon,
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsView(
          onNavigateTab: (idx) => _onTabSelected(idx),
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
                            color: isDark ? TeknoyTheme.darkBg : Colors.white,
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
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? TeknoyTheme.darkBg : TeknoyTheme.lightBgAlt,
      appBar: AppBar(
        toolbarHeight: 46.0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
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
                      color: isDark ? Colors.white70 : TeknoyTheme.citMaroonMuted,
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
                            color: isDark ? TeknoyTheme.darkBg : Colors.white,
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
                      hasUnreadNotifications
                          ? Icons.notifications_rounded
                          : Icons.notifications_outlined,
                      color: isDark
                          ? (hasUnreadNotifications ? TeknoyTheme.citGold : Colors.white70)
                          : (hasUnreadNotifications ? TeknoyTheme.citMaroon : TeknoyTheme.citMaroonMuted),
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
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD90429),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? TeknoyTheme.darkBg : Colors.white,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD90429).withValues(alpha: 0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unreadCount',
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
        ],
      ),
      drawer: TeknoyNavigationDrawer(
        onSelectTab: _onTabSelected,
        currentTabIndex: _activeTab,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.22, 1.0],
            colors: isDark
                ? [
                    const Color(0xFF221115),
                    const Color(0xFF140D10),
                    TeknoyTheme.darkBg,
                  ]
                : [
                    const Color(0xFFFFEDE1),
                    const Color(0xFFFFF7F2),
                    TeknoyTheme.lightBgAlt,
                  ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 46.0),
            child: _buildActiveTabBody(context),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? TeknoyTheme.darkBg : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? TeknoyTheme.darkDivider : Colors.grey.withValues(alpha: 0.2),
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
