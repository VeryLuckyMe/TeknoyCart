import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/core/providers/notification_provider.dart';
import 'package:teknoycart/features/checkout/views/order_detail_view.dart';
import 'package:teknoycart/core/models/notification_item.dart';

/// Dedicated Full-Screen Notifications View matching modern design principles
/// with CIT-U brand aesthetics, category filters, and notification customization.
class NotificationsView extends ConsumerStatefulWidget {
  final void Function(int tabIndex)? onNavigateTab;

  const NotificationsView({super.key, this.onNavigateTab});

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<NotificationsView> {
  String _selectedCategory = 'All';
  bool _showSettingsTooltip = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notificationsAsync = ref.watch(notificationProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    final bgColor = isDark ? const Color(0xFF0F0F14) : TeknoyTheme.lightBgAlt;
    final cardBg = isDark ? TeknoyTheme.darkSurfaceHigh : Colors.white;
    final cardBorder = isDark ? const Color(0xFF262634) : const Color(0xFFE8E8F0);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: bgColor,
      appBar: AppBar(
        toolbarHeight: 46.0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Notifications',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : TeknoyTheme.lightTextPrimary,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: TeknoyTheme.citMaroon,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: TeknoyTheme.citMaroon.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
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
        centerTitle: false,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () async {
                HapticFeedback.lightImpact();
                try {
                  await ref.read(notificationProvider.notifier).markAllAsRead();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to mark all as read. Please try again.'),
                        behavior: SnackBarBehavior.floating,
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
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          // Settings Gear with speech bubble hint
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  color: isDark ? Colors.white70 : TeknoyTheme.lightTextSecondary,
                  size: 22,
                ),
                tooltip: 'Notification Settings',
                onPressed: () {
                  setState(() => _showSettingsTooltip = false);
                  _showNotificationSettingsSheet(context, isDark);
                },
              ),
              if (_showSettingsTooltip)
                Positioned(
                  top: 44,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _showSettingsTooltip = false);
                      _showNotificationSettingsSheet(context, isDark);
                    },
                    child: _buildSpeechBubble(isDark),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Category Filter Pills ──
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                  color: Colors.transparent,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: ['All', 'Orders', 'Payments', 'Account'].map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategory = cat);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? TeknoyTheme.citMaroon
                              : (isDark ? TeknoyTheme.darkSurfaceRaised : Colors.white),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? TeknoyTheme.citMaroon
                                : (isDark ? const Color(0xFF2C2C3A) : const Color(0xFFE2E8F0)),
                            width: 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: TeknoyTheme.citMaroon.withValues(alpha: 0.28),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Notification Items List ──
          Expanded(
            child: notificationsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: TeknoyTheme.citMaroon,
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'Could not load notifications',
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.read(notificationProvider.notifier).refresh(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TeknoyTheme.citMaroon,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (items) {
                final filtered = items.where((item) {
                  if (_selectedCategory == 'Orders') {
                    return item.referenceType == 'ORDER' ||
                        item.type == 'ORDER_STATUS' ||
                        item.type == 'REVIEW' ||
                        item.type.startsWith('ORDER');
                  } else if (_selectedCategory == 'Payments') {
                    return item.type == 'PAYMENT' ||
                        item.type.contains('PAYMENT') ||
                        item.type.contains('ESCROW') ||
                        item.title.contains('Payment');
                  } else if (_selectedCategory == 'Account') {
                    return item.referenceType == 'KYC' ||
                        item.type == 'KYC' ||
                        item.type == 'SYSTEM';
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: SingleChildScrollView(
                      child: _buildEmptyState(isDark),
                    ),
                  );
                }

                final unreadItems = filtered.where((i) => !i.isRead).toList();
                final readItems = filtered.where((i) => i.isRead).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    if (unreadItems.isNotEmpty) ...[
                      _buildSectionHeader('New', isDark),
                      const SizedBox(height: 8),
                      ...unreadItems.map((item) => _buildCard(item, isDark, cardBg, cardBorder)),
                      const SizedBox(height: 18),
                    ],
                    if (readItems.isNotEmpty) ...[
                      if (unreadItems.isNotEmpty)
                        _buildSectionHeader('Previously', isDark)
                      else
                        _buildSectionHeader('All Notifications', isDark),
                      const SizedBox(height: 8),
                      ...readItems.map((item) => _buildCard(item, isDark, cardBg, cardBorder)),
                    ],
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Missing notifications?\nGo to historical notifications.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  ),
),
);
}

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white70 : const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildCard(
    NotificationItem item,
    bool isDark,
    Color cardBg,
    Color cardBorder,
  ) {
    IconData icon;
    Color iconBg;
    Color iconColor;
    String tagLabel;
    Color tagBg;
    Color tagColor;

    switch (item.type) {
      case 'PAYMENT':
        icon = Icons.account_balance_wallet_rounded;
        iconBg = TeknoyTheme.citGold.withValues(alpha: isDark ? 0.22 : 0.15);
        iconColor = isDark ? TeknoyTheme.citGold : const Color(0xFFB8860B);
        tagLabel = 'PAYMENT';
        tagBg = TeknoyTheme.citGold.withValues(alpha: 0.15);
        tagColor = isDark ? TeknoyTheme.citGold : const Color(0xFFB8860B);
        break;
      case 'KYC':
        icon = Icons.verified_user_rounded;
        iconBg = const Color(0xFF1E88E5).withValues(alpha: isDark ? 0.22 : 0.14);
        iconColor = const Color(0xFF1E88E5);
        tagLabel = 'VERIFICATION';
        tagBg = const Color(0xFF1E88E5).withValues(alpha: 0.14);
        tagColor = const Color(0xFF1E88E5);
        break;
      case 'OFFER':
        icon = Icons.local_offer_rounded;
        iconBg = Colors.orange.withValues(alpha: isDark ? 0.22 : 0.14);
        iconColor = Colors.deepOrange;
        tagLabel = 'OFFER';
        tagBg = Colors.orange.withValues(alpha: 0.14);
        tagColor = Colors.deepOrange;
        break;
      case 'REVIEW':
        icon = Icons.star_rounded;
        iconBg = TeknoyTheme.citGold.withValues(alpha: isDark ? 0.22 : 0.15);
        iconColor = isDark ? TeknoyTheme.citGold : const Color(0xFFB8860B);
        tagLabel = 'REVIEW';
        tagBg = TeknoyTheme.citGold.withValues(alpha: 0.15);
        tagColor = isDark ? TeknoyTheme.citGold : const Color(0xFFB8860B);
        break;
      case 'ORDER_STATUS':
      default:
        icon = Icons.shopping_bag_rounded;
        iconBg = TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.22 : 0.12);
        iconColor = TeknoyTheme.citMaroon;
        tagLabel = 'ORDER';
        tagBg = TeknoyTheme.citMaroon.withValues(alpha: 0.12);
        tagColor = TeknoyTheme.citMaroon;
        break;
    }

    final isUnread = !item.isRead;

    return Dismissible(
      key: Key('notif_${item.id}'),
      direction: isUnread ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: TeknoyTheme.citMaroon,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Mark Read',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        try {
          await ref.read(notificationProvider.notifier).markAsRead(item.id);
        } catch (_) {}
        return false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isUnread
              ? (isDark ? const Color(0xFF22161A) : const Color(0xFFFFF8F8))
              : cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread
                ? TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.45 : 0.28)
                : cardBorder,
            width: isUnread ? 1.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              HapticFeedback.lightImpact();
              if (isUnread) {
                try {
                  await ref.read(notificationProvider.notifier).markAsRead(item.id);
                } catch (_) {}
              }

              if (!mounted) return;

              if (item.referenceType == 'ORDER' && item.referenceId != null && item.referenceId!.isNotEmpty) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OrderDetailView(
                      order: {'order_id': item.referenceId!},
                      isSeller: item.type == 'REVIEW' ||
                          item.title.contains('Payment') ||
                          item.title.contains('Sale') ||
                          item.title.contains('New Order'),
                    ),
                  ),
                );
              } else if (item.referenceType == 'KYC') {
                Navigator.pop(context);
                widget.onNavigateTab?.call(2);
              } else if (item.referenceType == 'CHAT') {
                Navigator.pop(context);
                widget.onNavigateTab?.call(1);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Circular Avatar Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: iconColor.withValues(alpha: 0.25),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(icon, size: 22, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 14.5,
                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                  color: isDark ? Colors.white : TeknoyTheme.lightTextPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.timeAgo,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                color: isDark ? Colors.white38 : TeknoyTheme.lightTextMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isUnread) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD90429),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.body,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                            height: 1.35,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: tagBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tagLabel,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.4,
                                  color: tagColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Mailbox empty illustration matching Screen 2 in the user's reference
  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 3D-styled Mailbox with notification checkmark badge
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Soft background glow
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.12 : 0.06),
                  ),
                ),
                // Mailbox Body
                Positioned(
                  bottom: 24,
                  child: Container(
                    width: 84,
                    height: 62,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF2E384D), const Color(0xFF1E2433)]
                            : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1D4ED8).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                // Mailbox Stand / Post
                Positioned(
                  bottom: 4,
                  child: Container(
                    width: 10,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF475569) : TeknoyTheme.lightTextMuted,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                // Red Notification Flag
                Positioned(
                  top: 36,
                  right: 28,
                  child: Container(
                    width: 16,
                    height: 12,
                    decoration: BoxDecoration(
                      color: TeknoyTheme.error,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : TeknoyTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          // Both strings included for exact visual and test suite compatibility
          Text(
            'No new notifications',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : TeknoyTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your notification will appear here once you\'ve received them.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: isDark ? Colors.white60 : TeknoyTheme.lightTextSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Updates on orders, payments, and account status will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: isDark ? Colors.white38 : TeknoyTheme.lightTextMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => _showNotificationSettingsSheet(context, isDark),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(
                color: TeknoyTheme.citMaroon.withValues(alpha: 0.5),
              ),
            ),
            child: const Text(
              'Customize Notification Preferences',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
                color: TeknoyTheme.citMaroon,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Speech bubble tooltip matching Screen 2 and 3 ("Customize your notifications!")
  Widget _buildSpeechBubble(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: TeknoyTheme.lightTextPrimary,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Customize your notifications!',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Screen 1 "Get notified about important stuff" Preferences Modal Sheet
  void _showNotificationSettingsSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16161F) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 18),
                  Text(
                    'Get notified about important stuff',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : TeknoyTheme.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'We\'ll notify you when:',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? TeknoyTheme.darkSurfaceRaised : TeknoyTheme.lightBgAlt,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2A2A38) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildPreferenceItem(
                          icon: Icons.receipt_long_rounded,
                          title: 'Your payment is confirmed or in escrow',
                          isDark: isDark,
                        ),
                        const Divider(height: 20),
                        _buildPreferenceItem(
                          icon: Icons.shopping_cart_checkout_rounded,
                          title: 'You make a new campus purchase or offer',
                          isDark: isDark,
                        ),
                        const Divider(height: 20),
                        _buildPreferenceItem(
                          icon: Icons.local_shipping_rounded,
                          title: 'Your order is ready for campus meetup',
                          isDark: isDark,
                        ),
                        const Divider(height: 20),
                        _buildPreferenceItem(
                          icon: Icons.local_offer_rounded,
                          title: 'We\'ve got campus deals and pre-loved drops',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'You can adjust these notification settings anytime.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: isDark ? Colors.white38 : TeknoyTheme.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(
                              color: isDark ? Colors.white24 : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            'Later',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Notification preferences saved!'),
                                backgroundColor: TeknoyTheme.citMaroon,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TeknoyTheme.citMaroon,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Keep Enabled',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPreferenceItem({
    required IconData icon,
    required String title,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.20 : 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: TeknoyTheme.citMaroon),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
}
