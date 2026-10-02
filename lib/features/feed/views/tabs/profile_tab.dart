import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/core/providers/theme_provider.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';
import 'package:teknoycart/features/feed/providers/review_provider.dart';
import 'package:teknoycart/features/feed/views/manage_listings_view.dart';
import 'package:teknoycart/features/feed/views/seller_storefront_view.dart';
import 'package:teknoycart/features/feed/views/widgets/buyer_reviews_sheet.dart';

/// Provider to dynamically count completed orders/deals for a given user ID
final userCompletedDealsCountProvider = FutureProvider.family<int, String>((ref, userId) async {
  if (userId.isEmpty) return 0;
  try {
    final client = SupabaseConfig.client;
    final res = await client
        .from('orders')
        .select('order_id')
        .or('buyer_id.eq.,seller_id.eq.')
        .eq('status', 'completed');
    return (res as List).length;
  } catch (_) {
    return 0;
  }
});

/// Modular Profile Tab for ProductDiscoveryFeedView (HIGH-04).
class ProfileTab extends ConsumerStatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const ProfileTab({super.key, this.onNavigateTab});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}
class _ProfileTabState extends ConsumerState<ProfileTab> {
  Map<String, dynamic>? _cachedProfileData;
  String? _cachedProfileUserId;
  Future<Map<String, dynamic>>? _profileFuture;

  Future<Map<String, dynamic>?> _getUserRoleAndStatus(String userId) async {
    try {
      final res = await SupabaseConfig.client
          .from('users')
          .select('role, is_seller_verified, student_id')
          .eq('user_id', userId)
          .single();
      return res;
    } catch (e) {
      return null;
    }
  }

  Future<void> _updateProfileMetadata(String dept, String contact, String gcashNumber, {String? storeName}) async {
    try {
      final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
      final updateData = <String, dynamic>{
        'department': dept,
        'contact': contact,
        'gcash_number': gcashNumber,
      };
      if (storeName != null) {
        updateData['store_name'] = storeName;
      }

      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(data: updateData),
      );

      if (currentUserId != null) {
        await SupabaseConfig.client
            .from('users')
            .update({
              'gcash_number': gcashNumber,
              'contact': contact,
            })
            .eq('user_id', currentUserId);

        if (storeName != null && storeName.trim().isNotEmpty) {
          await SupabaseConfig.client.from('store_profiles').upsert({
            'seller_id': currentUserId,
            'store_name': storeName.trim(),
          });
        }
      }
      ref.invalidate(authStateProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profile details updated live in Supabase!'),
          backgroundColor: TeknoyTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: TeknoyTheme.error,
        ),
      );
    }
  }


  void _showEditProfileModal(
    BuildContext context, {
    required String currentDept,
    required String currentContact,
    required String currentGcash,
    required bool isSeller,
    required String currentStoreName,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final departments = [
      'College of Computer Studies',
      'College of Engineering and Architecture',
      'College of Management, Business and Accountancy',
      'College of Arts, Sciences and Education',
      'College of Nursing and Allied Health Sciences',
      'College of Criminal Justice',
      'Senior High School',
      'Other / General Studies',
    ];

    String selectedDept = departments.contains(currentDept)
        ? currentDept
        : departments.first;
    final contactController = TextEditingController(text: currentContact == '0912 345 6789' ? '' : currentContact);
    final gcashController = TextEditingController(text: currentGcash == 'Not Configured' ? '' : currentGcash);
    final storeNameController = TextEditingController(text: currentStoreName == 'Not Configured' ? '' : currentStoreName);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: EdgeInsets.only(bottom: bottomInset),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16161A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: TeknoyTheme.kElevationHigh,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF2A2A32) : const Color(0xFFE4E4E8),
                    width: 1,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Pull handle
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.edit_note_rounded,
                              color: TeknoyTheme.citMaroon,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Profile Details',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Updates sync to your verified campus identity',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(modalContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Department Dropdown
                      const Text(
                        'CIT-U Department / College',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: selectedDept,
                        dropdownColor: isDark ? const Color(0xFF222228) : Colors.white,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.school_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: departments
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(
                                    d,
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedDept = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      // Primary Contact Field
                      const Text(
                        'Mobile Contact Number',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: contactController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: '09XXXXXXXXX',
                          prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (val) {
                          final text = val?.trim() ?? '';
                          if (text.isEmpty) return 'Contact number is required';
                          if (!RegExp(r'^09[0-9]{9}$').hasMatch(text) && text.length != 11) {
                            return 'Enter an 11-digit Philippine number (e.g. 09171234567)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // GCash Payout Field
                      const Text(
                        'GCash Payout Number',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: gcashController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: '09XXXXXXXXX',
                          prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (val) {
                          final text = val?.trim() ?? '';
                          if (text.isEmpty) return 'GCash number is required for deal payouts';
                          if (!RegExp(r'^09[0-9]{9}$').hasMatch(text) && text.length != 11) {
                            return 'Enter an 11-digit GCash number (e.g. 09171234567)';
                          }
                          return null;
                        },
                      ),
                      if (isSeller) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Store Display Name',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: storeNameController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Teknoy Corner, Books & Tech',
                            prefixIcon: const Icon(Icons.storefront_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Store name cannot be empty for vendors';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSaving ? null : () => Navigator.pop(modalContext),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) return;
                                      setModalState(() => isSaving = true);
                                      try {
                                        await _updateProfileMetadata(
                                          selectedDept,
                                          contactController.text.trim(),
                                          gcashController.text.trim(),
                                          storeName: isSeller ? storeNameController.text.trim() : null,
                                        );
                                        if (modalContext.mounted) {
                                          Navigator.pop(modalContext);
                                        }
                                      } finally {
                                        if (modalContext.mounted) {
                                          setModalState(() => isSaving = false);
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: TeknoyTheme.citMaroon,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text(
                                      'Save Changes',
                                      style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSignOutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: TeknoyTheme.citMaroon, size: 24),
            SizedBox(width: 10),
            Text(
              'Sign Out',
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out of TeknoyCart? You will need to sign in again to browse deals, manage listings, and chat with buyers.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogCtx);
              try {
                await ref.read(authNotifierProvider.notifier).logout();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Logout failed: $e'),
                    backgroundColor: TeknoyTheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TeknoyTheme.citMaroon,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rand = math.Random();
    final randomCode = List.generate(5, (index) => chars[rand.nextInt(chars.length)]).join();

    final controller = TextEditingController();
    bool isValid = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: TeknoyTheme.error, size: 26),
                  SizedBox(width: 8),
                  Text(
                    'Delete Account',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                      color: TeknoyTheme.error,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This action is permanent and cannot be undone. All your listings, deals, and messages will be permanently deleted.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Type this code to delete the account: $randomCode',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: TeknoyTheme.citMaroon,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Verification Code',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setState(() {
                        isValid = val.trim() == randomCode;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isValid
                      ? () async {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(context);
                          try {
                            await SupabaseConfig.client.rpc('delete_user_account');
                            await ref.read(authNotifierProvider.notifier).logout();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('✅ Account successfully deleted.'),
                                backgroundColor: TeknoyTheme.success,
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Failed to delete account: $e'),
                                backgroundColor: TeknoyTheme.error,
                              ),
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TeknoyTheme.error,
                    disabledBackgroundColor: TeknoyTheme.error.withValues(alpha: 0.4),
                  ),
                  child: const Text('Delete Permanently'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSafeTradeGuidelinesSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16161A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF2A2A32) : const Color(0xFFE4E4E8),
              width: 1,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: TeknoyTheme.citGold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.security_rounded, color: Color(0xFFB45309), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Campus Trade Safe Zones',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildSafetyZoneTile(
              icon: Icons.meeting_room_rounded,
              title: 'CIT-U Student Lounge',
              subtitle: 'Ground Floor, Main Building — High foot traffic, safe seating.',
              isDark: isDark,
            ),
            _buildSafetyZoneTile(
              icon: Icons.local_library_rounded,
              title: 'University Library Lobby',
              subtitle: 'Well-lit, CCTV-monitored campus transition point.',
              isDark: isDark,
            ),
            _buildSafetyZoneTile(
              icon: Icons.restaurant_rounded,
              title: 'Main Campus Food Court',
              subtitle: 'Active during school hours (7:30 AM – 6:00 PM).',
              isDark: isDark,
            ),
            _buildSafetyZoneTile(
              icon: Icons.shield_rounded,
              title: 'University Main Gate Security Post',
              subtitle: 'Ideal for exchanges with alumni or weekend drop-offs.',
              isDark: isDark,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: TeknoyTheme.citMaroon.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TeknoyTheme.citMaroon.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: TeknoyTheme.citMaroon, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Golden Rule: Always inspect physical merchandise before releasing GCash or cash payments.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyZoneTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF222228) : const Color(0xFFF3F3F7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: TeknoyTheme.citMaroon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTermsOfCommerceSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16161A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF2A2A32) : const Color(0xFFE4E4E8),
              width: 1,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: TeknoyTheme.citMaroon.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.gavel_rounded, color: TeknoyTheme.citMaroon, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Terms of Student Commerce',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildCommerceTermItem(
              number: '1',
              title: 'Academic Honor Code Compliance',
              desc: 'Strict prohibition on selling exams, quizzes, thesis papers, or faculty-restricted solution manuals.',
              isDark: isDark,
            ),
            _buildCommerceTermItem(
              number: '2',
              title: 'No Scalping or Ticket Price-Gouging',
              desc: 'Campus event tickets, intramural passes, and departmental merchandise must not be resold above face value.',
              isDark: isDark,
            ),
            _buildCommerceTermItem(
              number: '3',
              title: 'Accurate Item Disclosures',
              desc: 'Disclose all physical wear, battery health, and condition honesties upfront. Counterfeits result in immediate suspension.',
              isDark: isDark,
            ),
            _buildCommerceTermItem(
              number: '4',
              title: 'Zero-Retention Identity Privacy',
              desc: 'Verification documents submitted for KYC are secured and subject to Philippine RA 10173 data privacy safeguards.',
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommerceTermItem({
    required String number,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: TeknoyTheme.citMaroon,
            child: Text(
              number,
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Index 4: Profile Page Body — Digital Wildcat Student ID Pass & Inset Grouped Settings
  @override
  Widget build(BuildContext context) {
    final authStateAsync = ref.watch(authStateProvider);
    final user = authStateAsync.valueOrNull;
    final name = user?.username ?? 'Wildcat Student';
    final email = user?.email ?? 'Pending verification';
    final rawId = user?.id ?? '';
    final dept = user?.department ?? 'College of Computer Studies';
    final contact = user?.contact ?? '0912 345 6789';
    final gcashNumber = user?.gcashNumber ?? 'Not Configured';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final productsAsync = ref.watch(productsListProvider);
    final userListingsCount = productsAsync.valueOrNull
            ?.where((p) => p.sellerId == rawId)
            .length ??
        0;
    final dealsAsync = ref.watch(userCompletedDealsCountProvider(rawId));
    final dealsCount = dealsAsync.valueOrNull ?? 0;

    // Cache the future so it doesn't re-run on every tab switch
    if (rawId.isNotEmpty && _cachedProfileUserId != rawId) {
      _cachedProfileUserId = rawId;
      _profileFuture = _getUserRoleAndStatus(rawId)
          .then((v) => v ?? {'role': 'BUYER', 'is_seller_verified': false});
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture ?? Future.value({'role': 'BUYER', 'is_seller_verified': false}),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _cachedProfileData = snapshot.data;
        }
        final roleInfo = _cachedProfileData ?? {'role': 'BUYER', 'is_seller_verified': false};
        final String role = roleInfo['role'] as String;
        final bool isVerified = roleInfo['is_seller_verified'] as bool;
        final isSeller = role == 'SELLER';
        final String studentId = user?.studentId 
            ?? (roleInfo['student_id'] as String?)
            ?? 'Pending';

        final String rawStoreName = (SupabaseConfig.client.auth.currentUser?.userMetadata?['store_name'] as String?)
            ?? (roleInfo['store_name'] as String? ?? '');
        final String storeName = rawStoreName.trim().isNotEmpty ? rawStoreName.trim() : 'Not Configured';

        return Container(
          color: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF7F7FA),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Digital Wildcat Student ID Pass
                _buildWildcatIdPassCard(
                  context: context,
                  name: name,
                  email: email,
                  studentId: studentId,
                  dept: dept,
                  isSeller: isSeller,
                  isVerified: isVerified,
                  isDark: isDark,
                ),

                const SizedBox(height: 16),

                // 2. Role-Adaptive Credential Strip (Ponytail Audit)
                _buildRoleAdaptiveStrip(
                  context: context,
                  rawId: rawId,
                  name: name,
                  storeName: storeName,
                  isSeller: isSeller,
                  isVerified: isVerified,
                  isDark: isDark,
                ),

                const SizedBox(height: 16),

                // 3. 3-Pillar Reputation & Metrics Strip
                _buildProfileMetricsStrip(
                  context: context,
                  rawId: rawId,
                  name: name,
                  listingsCount: userListingsCount,
                  dealsCount: dealsCount,
                  isDark: isDark,
                ),

                const SizedBox(height: 24),

                // 4. Inset Group 1: Campus Credentials & Contact Details
                _buildSettingsGroup(
                  title: 'Campus Credentials',
                  actionLabel: 'Edit Details',
                  onActionTap: () => _showEditProfileModal(
                    context,
                    currentDept: dept,
                    currentContact: contact,
                    currentGcash: gcashNumber,
                    isSeller: isSeller,
                    currentStoreName: storeName,
                  ),
                  isDark: isDark,
                  children: [
                    _buildGroupedSettingRow(
                      icon: Icons.badge_outlined,
                      title: studentId,
                      subtitle: 'Verified Campus ID Number',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: TeknoyTheme.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 11, color: TeknoyTheme.success),
                            SizedBox(width: 4),
                            Text(
                              'LOCKED',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: TeknoyTheme.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                      isDark: isDark,
                    ),
                    _buildGroupedSettingRow(
                      icon: Icons.alternate_email_rounded,
                      title: email,
                      subtitle: 'CIT-U Institutional Email',
                      trailing: const Icon(Icons.verified_rounded, size: 16, color: TeknoyTheme.success),
                      isDark: isDark,
                    ),
                    _buildGroupedSettingRow(
                      icon: Icons.school_outlined,
                      title: dept,
                      subtitle: 'College / Department',
                      onTap: () => _showEditProfileModal(
                        context,
                        currentDept: dept,
                        currentContact: contact,
                        currentGcash: gcashNumber,
                        isSeller: isSeller,
                        currentStoreName: storeName,
                      ),
                      isDark: isDark,
                    ),
                    _buildGroupedSettingRow(
                      icon: Icons.phone_iphone_rounded,
                      title: contact,
                      subtitle: 'Primary Mobile Contact',
                      onTap: () => _showEditProfileModal(
                        context,
                        currentDept: dept,
                        currentContact: contact,
                        currentGcash: gcashNumber,
                        isSeller: isSeller,
                        currentStoreName: storeName,
                      ),
                      isDark: isDark,
                    ),
                    _buildGroupedSettingRow(
                      icon: Icons.account_balance_wallet_outlined,
                      title: gcashNumber,
                      subtitle: 'GCash Payout Mobile',
                      showDivider: isSeller,
                      onTap: () => _showEditProfileModal(
                        context,
                        currentDept: dept,
                        currentContact: contact,
                        currentGcash: gcashNumber,
                        isSeller: isSeller,
                        currentStoreName: storeName,
                      ),
                      isDark: isDark,
                    ),
                    if (isSeller)
                      _buildGroupedSettingRow(
                        icon: Icons.storefront_outlined,
                        title: storeName,
                        subtitle: 'Store Display Name',
                        showDivider: false,
                        onTap: () => _showEditProfileModal(
                          context,
                          currentDept: dept,
                          currentContact: contact,
                          currentGcash: gcashNumber,
                          isSeller: isSeller,
                          currentStoreName: storeName,
                        ),
                        isDark: isDark,
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // 5. Inset Group 2: Marketplace & Activities
                _buildSettingsGroup(
                  title: 'Marketplace & Orders',
                  isDark: isDark,
                  children: [
                    _buildGroupedSettingRow(
                      icon: Icons.receipt_long_rounded,
                      title: 'My Orders & Reservations',
                      subtitle: 'Track active meetup deals and purchase history',
                      onTap: () => widget.onNavigateTab?.call(3),
                      isDark: isDark,
                    ),
                    _buildGroupedSettingRow(
                      icon: Icons.inventory_2_outlined,
                      title: 'Inventory & Listings Hub',
                      subtitle: 'Manage active stock, discounts, and item listings',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ManageListingsView()),
                        );
                      },
                      isDark: isDark,
                    ),
                    _buildGroupedSettingRow(
                      icon: Icons.rate_review_outlined,
                      title: 'Buyer Reviews & Feedback',
                      subtitle: 'Read feedback from verified student meetup deals',
                      showDivider: isSeller && isVerified,
                      onTap: () {
                        final targetSellerId = rawId.isNotEmpty ? rawId : 'usr-seller';
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => BuyerReviewsSheet(
                            sellerId: targetSellerId,
                            sellerName: name,
                          ),
                        );
                      },
                      isDark: isDark,
                    ),
                    if (isSeller && isVerified)
                      _buildGroupedSettingRow(
                        icon: Icons.store_mall_directory_outlined,
                        title: 'Public Storefront Page',
                        subtitle: 'Preview your vendor profile as seen by buyers',
                        showDivider: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SellerStorefrontView(
                                sellerId: rawId,
                                sellerName: name,
                              ),
                            ),
                          );
                        },
                        isDark: isDark,
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // 6. Inset Group 3: Campus Trust & Safety
                _buildSettingsGroup(
                  title: 'Campus Trust & Safety',
                  isDark: isDark,
                  children: [
                    _buildGroupedSettingRow(
                      icon: Icons.security_rounded,
                      title: 'Campus Meetup Safe Zones',
                      subtitle: 'Designated safe areas: Student Lounge, Library, Canteen',
                      onTap: () => _showSafeTradeGuidelinesSheet(context),
                      isDark: isDark,
                    ),
                    _buildGroupedSettingRow(
                      icon: Icons.gavel_rounded,
                      title: 'Terms of Student Commerce',
                      subtitle: 'Wildcat honor code, anti-scalping & trade rules',
                      showDivider: false,
                      onTap: () => _showTermsOfCommerceSheet(context),
                      isDark: isDark,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Appearance & Theme Mode (MED-01)
                _buildSettingsGroup(
                  title: 'Appearance',
                  isDark: isDark,
                  children: [
                    _buildGroupedSettingRow(
                      icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      iconColor: TeknoyTheme.citGold,
                      iconBgColor: TeknoyTheme.citGold.withValues(alpha: 0.15),
                      title: 'Dark Theme Mode',
                      subtitle: isDark ? 'Currently in Sleek Dark mode' : 'Currently in Clean Campus Light mode',
                      showDivider: false,
                      trailing: Switch.adaptive(
                        value: isDark,
                        activeTrackColor: TeknoyTheme.citMaroon,
                        onChanged: (val) {
                          ref.read(themeModeProvider.notifier).setThemeMode(
                            val ? ThemeMode.dark : ThemeMode.light,
                          );
                        },
                      ),
                      isDark: isDark,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 7. Inset Group 4: Account Actions
                _buildSettingsGroup(
                  title: 'Account Settings',
                  isDark: isDark,
                  children: [
                    _buildGroupedSettingRow(
                      icon: Icons.logout_rounded,
                      iconColor: TeknoyTheme.citMaroon,
                      iconBgColor: TeknoyTheme.citMaroon.withValues(alpha: 0.12),
                      title: 'Sign Out Account',
                      subtitle: 'Safely disconnect from this device',
                      onTap: () => _showSignOutConfirmDialog(context),
                      isDark: isDark,
                    ),
                    _buildGroupedSettingRow(
                      icon: Icons.delete_forever_rounded,
                      iconColor: TeknoyTheme.error,
                      iconBgColor: TeknoyTheme.error.withValues(alpha: 0.12),
                      title: 'Delete Account Permanently',
                      subtitle: 'Irreversible erasure of account and active listings',
                      showDivider: false,
                      onTap: () => _showDeleteAccountDialog(context),
                      isDark: isDark,
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                // Institutional Footer
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: TeknoyTheme.citGold,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'TEKNOYCART CIT-U v1.4.0',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white38 : Colors.grey.shade500,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cebu Institute of Technology - University',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          color: isDark ? Colors.white24 : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWildcatIdPassCard({
    required BuildContext context,
    required String name,
    required String email,
    required String studentId,
    required String dept,
    required bool isSeller,
    required bool isVerified,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF16161A) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF26262E) : const Color(0xFFE2E2E8);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Top Institutional Header Ribbon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: const BoxDecoration(
                color: TeknoyTheme.citMaroon,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: TeknoyTheme.citGold,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: TeknoyTheme.citMaroon,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CEBU INSTITUTE OF TECHNOLOGY - UNIVERSITY',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: TeknoyTheme.citGold,
                            letterSpacing: 1.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'TEKNOYCART OFFICIAL STUDENT PASS',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_rounded, size: 10, color: TeknoyTheme.citGold),
                        SizedBox(width: 4),
                        Text(
                          'OFFICIAL',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Pass Body with User Profile and Verification Seal
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dual-ring Avatar
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: TeknoyTheme.citGold, width: 1.5),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: TeknoyTheme.citMaroon,
                          ),
                          child: CircleAvatar(
                            radius: 34,
                            backgroundColor: isDark ? const Color(0xFF222228) : const Color(0xFFF0F0F4),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'W',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: TeknoyTheme.citMaroon,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Identity details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                                letterSpacing: -0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            // Student ID Monospace Tag with tap-to-copy
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: studentId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('📋 Student ID copied to clipboard'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF202026) : const Color(0xFFEFEFF4),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF32323D) : const Color(0xFFD6D6DE),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.badge_outlined, size: 12, color: TeknoyTheme.citMaroon),
                                    const SizedBox(width: 5),
                                    Text(
                                      'ID: $studentId',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.copy_rounded,
                                      size: 10,
                                      color: isDark ? Colors.white38 : Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Email
                            Row(
                              children: [
                                const Icon(Icons.verified_rounded, size: 13, color: TeknoyTheme.success),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    email,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Role Credential Strip (Ponytail Audit)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSeller
                          ? (isVerified
                              ? TeknoyTheme.citGold.withValues(alpha: isDark ? 0.15 : 0.12)
                              : Colors.amber.withValues(alpha: isDark ? 0.15 : 0.12))
                          : TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.12 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSeller
                            ? (isVerified
                                ? TeknoyTheme.citGold.withValues(alpha: 0.5)
                                : Colors.amber.withValues(alpha: 0.5))
                            : TeknoyTheme.citMaroon.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSeller
                              ? (isVerified ? Icons.verified_user_rounded : Icons.pending_actions_rounded)
                              : Icons.school_outlined,
                          size: 16,
                          color: isSeller
                              ? (isVerified ? const Color(0xFFD97706) : Colors.amber.shade700)
                              : TeknoyTheme.citMaroon,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isSeller
                                ? (isVerified ? 'VERIFIED CAMPUS VENDOR' : 'KYC APPLICATION UNDER REVIEW')
                                : 'ENROLLED WILDCAT BUYER',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: isSeller
                                  ? (isVerified ? const Color(0xFFB45309) : Colors.amber.shade800)
                                  : TeknoyTheme.citMaroon,
                            ),
                          ),
                        ),
                        if (isSeller && isVerified)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: TeknoyTheme.citGold,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Bar: Department + Gold accent line
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A20) : const Color(0xFFF9F9FC),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF26262E) : const Color(0xFFE8E8EE),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_rounded,
                    size: 14,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dept,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white60 : Colors.grey.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Gold bottom accent stripe
            Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [TeknoyTheme.citMaroon, TeknoyTheme.citGold, TeknoyTheme.citMaroon],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleAdaptiveStrip({
    required BuildContext context,
    required String rawId,
    required String name,
    required String storeName,
    required bool isSeller,
    required bool isVerified,
    required bool isDark,
  }) {
    if (isSeller && isVerified) {
      // Verified Vendor Actions
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16161A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF26262E) : const Color(0xFFE2E2E8),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.store_rounded, color: TeknoyTheme.citMaroon, size: 20),
                const SizedBox(width: 8),
                Text(
                  storeName == 'Not Configured' ? 'Vendor Control Hub' : storeName,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SellerStorefrontView(
                            sellerId: rawId,
                            sellerName: name,
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: TeknoyTheme.citMaroon),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.storefront_outlined, size: 16, color: TeknoyTheme.citMaroon),
                    label: const Text(
                      'Storefront',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: TeknoyTheme.citMaroon,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ManageListingsView()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TeknoyTheme.citMaroon,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.inventory_2_outlined, size: 16),
                    label: const Text(
                      'Manage Stock',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else if (isSeller && !isVerified) {
      // Pending Vendor: Informative amber banner (Ponytail compliant)
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: isDark ? 0.08 : 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Vendor KYC Under Review',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB45309),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Your seller documents are currently being checked by campus administrators. In the meantime, your account functions as a student buyer.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  widget.onNavigateTab?.call(2); // Jump to Sell tab where KYC status is rendered
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB45309),
                  side: const BorderSide(color: Color(0xFFD97706)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text(
                  'Check Verification Status',
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Buyer Mode: Invitation to become a vendor
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TeknoyTheme.citMaroon.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: TeknoyTheme.citMaroon.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront_rounded, color: TeknoyTheme.citMaroon, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sell to Fellow Wildcats',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Turn unused books, kits, and uniforms into cash on campus.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                widget.onNavigateTab?.call(2); // Switch to Sell tab
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TeknoyTheme.citMaroon,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text(
                'Apply',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildProfileMetricsStrip({
    required BuildContext context,
    required String rawId,
    required String name,
    required int listingsCount,
    required int dealsCount,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF16161A) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF26262E) : const Color(0xFFE2E2E8);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Pillar 1: Listings
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageListingsView()),
                );
              },
              child: Column(
                children: [
                  Text(
                    '$listingsCount',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Listings',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 26, color: cardBorder),
          // Pillar 2: Deals
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                widget.onNavigateTab?.call(3); // Go to Orders tab
              },
              child: Column(
                children: [
                  Text(
                    '$dealsCount',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: TeknoyTheme.citMaroon,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Deals Done',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 26, color: cardBorder),
          // Pillar 3: Reviews / Rating
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final targetSellerId = rawId.isNotEmpty ? rawId : 'usr-seller';
                final summary = ref.watch(sellerRatingSummaryProvider(targetSellerId));
                final hasReviews = summary.total > 0;
                final ratingScore = hasReviews ? summary.average.toStringAsFixed(1) : '5.0';

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => BuyerReviewsSheet(
                        sellerId: targetSellerId,
                        sellerName: name,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ratingScore,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD97706),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasReviews ? '${summary.total} Reviews' : 'Reputation',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup({
    required String title,
    String? actionLabel,
    VoidCallback? onActionTap,
    required List<Widget> children,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF16161A) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF26262E) : const Color(0xFFE2E2E8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white38 : Colors.grey.shade600,
                  letterSpacing: 0.8,
                ),
              ),
              if (actionLabel != null && onActionTap != null)
                GestureDetector(
                  onTap: onActionTap,
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: TeknoyTheme.citMaroon,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupedSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconColor,
    Color? iconBgColor,
    Widget? trailing,
    VoidCallback? onTap,
    bool showDivider = true,
    required bool isDark,
  }) {
    final defaultIconColor = iconColor ?? TeknoyTheme.citMaroon;
    final defaultBgColor = iconBgColor ?? defaultIconColor.withValues(alpha: isDark ? 0.14 : 0.09);
    final cardBorder = isDark ? const Color(0xFF26262E) : const Color(0xFFE2E2E8);

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: defaultBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: defaultIconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
                if (trailing == null && onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: isDark ? Colors.white24 : Colors.grey.shade400,
                  ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 64),
            child: Divider(height: 1, color: cardBorder),
          ),
      ],
    );
  }


}

class TextStyles {
  static TextStyle badgeStyle(Color textColor) => TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.bold,
        fontSize: 10,
        color: textColor,
        letterSpacing: 0.5,
      );
}

