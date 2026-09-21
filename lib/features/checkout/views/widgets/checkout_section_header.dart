import 'package:flutter/material.dart';
import '../../../../core/theme.dart';

class CheckoutSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool? isDark;

  const CheckoutSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? (Theme.of(context).brightness == Brightness.dark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [TeknoyTheme.citMaroon, TeknoyTheme.citMaroonLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: TeknoyTheme.citMaroon.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: TeknoyTheme.citGold, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: dark ? Colors.white : TeknoyTheme.citMaroonDark,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 33.0),
            child: Text(
              subtitle!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: dark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
