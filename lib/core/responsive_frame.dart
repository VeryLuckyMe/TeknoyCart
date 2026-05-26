import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:teknoycart/core/theme.dart';

/// A premium mockup frame widget for desktop web deployment.
/// Constrains the layout to a realistic, centered smartphone viewport
/// while rendering standard full-screen on mobile devices and native builds.
class ResponsiveMobileFrame extends StatelessWidget {
  final Widget child;

  const ResponsiveMobileFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Enforce frame only on Web platform when the width is larger than a standard smartphone
        if (!kIsWeb || constraints.maxWidth <= 500) {
          return child;
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0C0C0F) : const Color(0xFFF1F1F5),
          body: Stack(
            children: [
              // 1. Beautiful artistic ambient background behind the phone container
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              const Color(0xFF0F0F12),
                              const Color(0xFF330000), // Rich institutional Maroon deep glow
                              const Color(0xFF0F0F12),
                              const Color(0xFF1E1400), // Rich Gold ambient hint
                            ]
                          : [
                              const Color(0xFFF3F3F7),
                              const Color(0xFFFFF0F0), // Soft warm crimson light
                              const Color(0xFFF4F4F8),
                              const Color(0xFFFFFBEA), // Soft warm gold light
                            ],
                    ),
                  ),
                ),
              ),

              // Decorative abstract vector shapes for premium aesthetics
              Positioned(
                top: -100,
                left: -100,
                width: 400,
                height: 400,
                child: Container(
                  decoration: BoxDecoration(
                    color: TeknoyTheme.citMaroon.withOpacity(isDark ? 0.08 : 0.04),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -150,
                right: -100,
                width: 500,
                height: 500,
                child: Container(
                  decoration: BoxDecoration(
                    color: TeknoyTheme.citGold.withOpacity(isDark ? 0.05 : 0.03),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // 2. Mockup Smartphone Device Frame
              Center(
                child: Hero(
                  tag: 'app_phone_frame',
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    width: 420,
                    height: 900,
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight - 48,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? TeknoyTheme.darkBg : TeknoyTheme.lightBg,
                      borderRadius: BorderRadius.circular(44),
                      border: Border.all(
                        color: isDark ? const Color(0xFF25252A) : const Color(0xFFDFDFE5),
                        width: 12, // Realistic bezel
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark 
                              ? Colors.black.withOpacity(0.7) 
                              : Colors.grey.shade400.withOpacity(0.4),
                          blurRadius: 40,
                          spreadRadius: 8,
                          offset: const Offset(0, 20),
                        ),
                        BoxShadow(
                          color: TeknoyTheme.citMaroon.withOpacity(isDark ? 0.12 : 0.04),
                          blurRadius: 50,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32), // Inner rounded corners
                      child: Stack(
                        children: [
                          // The main App Viewport
                          Positioned.fill(child: child),

                          // Dynamic Notch mockup for beautiful presentation realism
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                width: 140,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF25252A) : const Color(0xFFDFDFE5),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(20),
                                    bottomRight: Radius.circular(20),
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF101015),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
