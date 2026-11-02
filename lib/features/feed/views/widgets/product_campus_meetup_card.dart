import 'package:flutter/material.dart';
import 'package:teknoycart/core/theme.dart';

class ProductCampusMeetupCard extends StatelessWidget {
  final bool isDark;

  const ProductCampusMeetupCard({
    super.key,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? TeknoyTheme.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? TeknoyTheme.darkBorder : TeknoyTheme.lightBorder,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: TeknoyTheme.citMaroon.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.place_rounded,
                  size: 18,
                  color: TeknoyTheme.citMaroon,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Campus Fulfillment & Meetup',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B1B22) : const Color(0xFFF9F9FB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF252530) : const Color(0xFFE5E5EB),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.school_outlined, size: 16, color: TeknoyTheme.citMaroon),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Designated CIT-U Meetup Zones',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Main Campus Grounds \u2022 Library Lobby \u2022 Wildcat Canteen \u2022 Academic Complex',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              color: isDark ? Colors.white60 : Colors.black54,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.verified_outlined, size: 15, color: TeknoyTheme.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Secure in-person exchange protected by CIT-U community verification.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.black54,
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
    );
  }
}

