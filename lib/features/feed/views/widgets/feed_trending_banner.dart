import 'package:flutter/material.dart';
import '../../../../core/theme.dart';

class FeedTrendingBanner extends StatelessWidget {
  const FeedTrendingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      height: 166,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF3A0000), const Color(0xFF180E02)]
              : [const Color(0xFFFFF0F0), const Color(0xFFFFF9E6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF5A1D1D) : const Color(0xFFFFD5D5),
          width: 1.5,
        ),
        boxShadow: TeknoyTheme.kElevationLow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Decorative glow circle
            Positioned(
              right: -50,
              top: -50,
              width: 150,
              height: 150,
              child: Container(
                decoration: BoxDecoration(
                  color: TeknoyTheme.citGold.withValues(alpha: isDark ? 0.08 : 0.15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Row(
              children: [
                // Left Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Dynamic Gold badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                          decoration: BoxDecoration(
                            color: TeknoyTheme.citGold,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: const Text(
                            '🔥 EXCLUSIVE OFFER',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              color: Color(0xFF6F5400),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Title
                        Text(
                          'Pre-Loved\nEngineering Books',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            height: 1.15,
                            color: isDark ? Colors.white : TeknoyTheme.citMaroon,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Subtitle
                        Text(
                          'Up to 40% off from senior students. Limited time only.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                            color: isDark ? Colors.white60 : const Color(0xFF5A413D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Right Content: Stack of books image with drop shadow
                Padding(
                  padding: const EdgeInsets.only(right: 20.0, top: 16.0, bottom: 16.0),
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF25252A) : const Color(0xFFEDEEEF),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                      image: const DecorationImage(
                        image: NetworkImage(
                          'https://picsum.photos/seed/books-cs/200/200',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
