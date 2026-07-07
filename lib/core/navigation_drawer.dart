import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/core/theme.dart';

import 'package:teknoycart/features/reports/views/financial_reports_view.dart';
import 'package:teknoycart/features/chat/views/inbox_view.dart';

/// Upgraded sliding Navigation Drawer reflecting a multi-billion-dollar brand layout.
class TeknoyNavigationDrawer extends ConsumerWidget {
  const TeknoyNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final drawerBgDecoration = isDark
        ? const BoxDecoration(
            color: Color(0xFF0F0A0A),
          )
        : const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFFCF5F5), // Soft Maroon blush
                Color(0xFFFDFBF7), // Soft Gold blush
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          );

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F0A0A) : Colors.white,
      elevation: 16,
      child: Container(
        decoration: drawerBgDecoration,
        child: userAsync.when(
          data: (user) {
            if (user == null) return const SizedBox();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Premium Glassmorphic User Header ───────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        TeknoyTheme.citMaroon.withOpacity(0.9),
                        TeknoyTheme.citMaroonDark.withOpacity(0.95),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: const Border(
                      bottom: BorderSide(
                        color: Colors.white10,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Dynamic outer ring avatar
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: TeknoyTheme.citGold,
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: TeknoyTheme.citMaroonLight,
                              backgroundImage: user.avatarUrl != null
                                  ? NetworkImage(user.avatarUrl!)
                                  : null,
                              child: user.avatarUrl == null
                                  ? Text(
                                      user.username[0].toUpperCase(),
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Role Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: TeknoyTheme.citGold.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: TeknoyTheme.citGold.withOpacity(0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.verified_user_rounded,
                                        size: 11,
                                        color: TeknoyTheme.citGold,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        user.studentId != null ? 'VERIFIED STUDENT' : 'CIT-U TECH MEMBER',
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: TeknoyTheme.citGold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  user.username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Contact/Department stats strip
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.school_outlined, size: 16, color: Colors.white.withOpacity(0.6)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                user.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Premium Custom Bento Drawer Options ───────────────────
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _buildNavTile(
                        context,
                        icon: Icons.storefront_rounded,
                        title: 'Marketplace Feed',
                        isActive: true,
                        onTap: () => Navigator.pop(context),
                      ),
                      _buildNavTile(
                        context,
                        icon: Icons.forum_outlined,
                        title: 'Negotiation Chats',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const InboxView()),
                          );
                        },
                      ),
                      _buildNavTile(
                        context,
                        icon: Icons.analytics_outlined,
                        title: 'Financial Reports',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const FinancialReportsView()),
                          );
                        },
                      ),
                      _buildNavTile(
                        context,
                        icon: Icons.loyalty_rounded,
                        title: 'Manage My Listings',
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Manage Listings view coming in Phase 4!'),
                              backgroundColor: TeknoyTheme.citMaroon,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                      ),
                      _buildNavTile(
                        context,
                        icon: Icons.receipt_long_rounded,
                        title: 'Order History',
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Order History coming in Phase 4!'),
                              backgroundColor: TeknoyTheme.citMaroon,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Divider(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
                      ),
                      _buildNavTile(
                        context,
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        onTap: () => Navigator.pop(context),
                      ),
                      _buildNavTile(
                        context,
                        icon: Icons.logout_rounded,
                        title: 'Sign Out',
                        isDanger: true,
                        onTap: () {
                          Navigator.pop(context);
                          ref.read(authNotifierProvider.notifier).logout();
                        },
                      ),
                    ],
                  ),
                ),

                // Institutional Premium Tech Label
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.security_rounded,
                              size: 14,
                              color: TeknoyTheme.citGold.withOpacity(0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'TeknoyCart Platform v1.0.0',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'CIT-U LEAD ENGINEERING GUILD',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white.withOpacity(0.25) : Colors.black.withOpacity(0.25),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: TeknoyTheme.citGold),
          ),
          error: (err, _) => Center(
            child: Text(
              'Error loading user session: $err',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isActive = false,
    bool isDanger = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isActive
            ? TeknoyTheme.citMaroon.withOpacity(isDark ? 0.15 : 0.08)
            : Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isActive
                ? TeknoyTheme.citGold.withOpacity(0.3)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: Icon(
            icon,
            color: isActive
                ? TeknoyTheme.citGold
                : isDanger
                    ? TeknoyTheme.error.withOpacity(0.8)
                    : (isDark ? Colors.white60 : Colors.black54),
            size: 22,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 15,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive
                  ? (isDark ? Colors.white : TeknoyTheme.citMaroon)
                  : isDanger
                      ? TeknoyTheme.error.withOpacity(0.9)
                      : (isDark ? Colors.white.withOpacity(0.8) : Colors.black87),
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: isActive
                ? TeknoyTheme.citGold.withOpacity(0.7)
                : (isDark ? Colors.white24 : Colors.black26),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          onTap: onTap,
        ),
      ),
    );
  }
}

