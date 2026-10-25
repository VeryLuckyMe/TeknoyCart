import 'package:flutter/material.dart';
import '../../../../core/theme.dart';

/// Shared Terms of Student Commerce / privacy notice.
///
/// Registration and the profile settings both open this sheet so the consent
/// copy has one source of truth. Persistence of `privacy_accepted_at` is
/// intentionally deferred until after the demo.
Future<void> showPrivacyConsentSheet(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: isDark ? TeknoyTheme.darkSurfaceAlt : Colors.white,
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
