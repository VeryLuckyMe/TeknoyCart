import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/core/theme.dart';

import 'package:teknoycart/features/reports/views/financial_reports_view.dart';
import 'package:teknoycart/features/chat/views/inbox_view.dart';

/// Contextual slide-out Navigation Drawer for TeknoyCart.
/// Provides links to manage listings, order history, and view active sessions.
class TeknoyNavigationDrawer extends ConsumerWidget {
  const TeknoyNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: userAsync.when(
        data: (user) {
          if (user == null) return const SizedBox();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drawer User Header Card with CIT-U Maroon Branding
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  color: TeknoyTheme.citMaroon,
                  image: DecorationImage(
                    image: NetworkImage(
                      'https://images.unsplash.com/photo-1579546929518-9e396f3cc809?auto=format&fit=crop&q=80&w=400',
                    ),
                    fit: BoxFit.cover,
                    opacity: 0.15,
                  ),
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: TeknoyTheme.citGold,
                  child: Text(
                    user.username[0].toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                accountName: Text(
                  user.username,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                accountEmail: Text(
                  user.email,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ),

              // Drawer Nav Options List
              ListTile(
                leading: const Icon(Icons.storefront_rounded, color: TeknoyTheme.citMaroon),
                title: const Text('Marketplace Feed', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                selected: true,
                selectedColor: TeknoyTheme.citMaroon,
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.forum_outlined, color: Colors.grey),
                title: const Text('Negotiation Chats', style: TextStyle(fontFamily: 'Outfit')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const InboxView()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.analytics_outlined, color: Colors.grey),
                title: const Text('Financial Reports', style: TextStyle(fontFamily: 'Outfit')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FinancialReportsView()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.loyalty_rounded, color: Colors.grey),
                title: const Text('Manage My Listings', style: TextStyle(fontFamily: 'Outfit')),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Manage Listings view coming in Phase 4!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_rounded, color: Colors.grey),
                title: const Text('Order History', style: TextStyle(fontFamily: 'Outfit')),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Order History coming in Phase 4!')),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings_outlined, color: Colors.grey),
                title: const Text('Settings', style: TextStyle(fontFamily: 'Outfit')),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.grey),
                title: const Text('Sign Out', style: TextStyle(fontFamily: 'Outfit')),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(authNotifierProvider.notifier).logout();
                },
              ),

              const Spacer(),

              // Institutional Signature Label
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'TeknoyCart v1.0.0',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      'CIT-U Lead Engineering Guild',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: TeknoyTheme.citMaroon),
        ),
        error: (err, _) => Center(
          child: Text('Error loading user session: $err'),
        ),
      ),
    );
  }
}
