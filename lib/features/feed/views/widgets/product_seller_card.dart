import 'package:flutter/material.dart';
import 'package:teknoycart/core/theme.dart';

class ProductSellerCard extends StatelessWidget {
  final bool isDark;
  final String storeName;
  final VoidCallback onVisitShop;

  const ProductSellerCard({
    super.key,
    required this.isDark,
    required this.storeName,
    required this.onVisitShop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? TeknoyTheme.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? TeknoyTheme.darkBorder : TeknoyTheme.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: TeknoyTheme.citMaroon,
            child: Text(
              storeName.isNotEmpty ? storeName[0].toUpperCase() : 'W',
              style: const TextStyle(
                fontFamily: 'Outfit',
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        storeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: TeknoyTheme.citGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 10, color: Color(0xFF8B6B00)),
                          SizedBox(width: 2),
                          Text(
                            'CIT-U',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF8B6B00),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Campus Student Seller',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onVisitShop,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: TeknoyTheme.citMaroon, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              'Visit Shop',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: TeknoyTheme.citMaroon,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

