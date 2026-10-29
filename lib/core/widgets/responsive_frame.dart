import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:teknoycart/core/theme.dart';

/// A premium mockup frame widget for desktop web deployment.
/// Constrains the layout to a realistic, centered smartphone viewport
/// with realistic bezels, rounded corners, and camera notch,
/// while rendering standard full-screen on mobile devices and native builds.
class ResponsiveMobileFrame extends StatelessWidget {
  final Widget child;

  const ResponsiveMobileFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Enforce frame only on Web platform when the width is larger than a standard smartphone
    if (!kIsWeb) return child;
    final mediaSize = MediaQuery.sizeOf(context);
    if (mediaSize.width <= 500) {
      return child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    const phoneBorderWidth = 10.0;
    const phoneFrameWidth = 460.0;
    const phoneWidth = phoneFrameWidth - (phoneBorderWidth * 2); // 440.0
    final phoneHeight = (mediaSize.height - 24.0).clamp(650.0, 940.0) - (phoneBorderWidth * 2);

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0C0C0F) : TeknoyTheme.lightSurfaceMuted,
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
                              TeknoyTheme.darkBg,
                              const Color(0xFF330000), // Rich institutional Maroon deep glow
                              TeknoyTheme.darkBg,
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
                    color: TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.08 : 0.04),
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
                    color: TeknoyTheme.citGold.withValues(alpha: isDark ? 0.05 : 0.03),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // 2. Mockup Smartphone Device Frame
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  width: phoneFrameWidth,
                  height: 940,
                  constraints: BoxConstraints(
                    maxHeight: mediaSize.height - 24,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? TeknoyTheme.darkBg : TeknoyTheme.lightBg,
                    borderRadius: BorderRadius.circular(46),
                    border: Border.all(
                      color: isDark ? const Color(0xFF25252A) : const Color(0xFFDFDFE5),
                      width: phoneBorderWidth, // Refined bezel
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark 
                            ? Colors.black.withValues(alpha: 0.7) 
                            : Colors.grey.shade400.withValues(alpha: 0.4),
                        blurRadius: 40,
                        spreadRadius: 8,
                        offset: const Offset(0, 20),
                      ),
                      BoxShadow(
                        color: TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.12 : 0.04),
                        blurRadius: 50,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36), // Inner rounded corners
                    child: Stack(
                      children: [
                        // The main App Viewport
                        Positioned.fill(
                          child: MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              size: Size(phoneWidth, phoneHeight),
                              padding: EdgeInsets.only(
                                top: 20,
                                bottom: MediaQuery.of(context).padding.bottom,
                                left: MediaQuery.of(context).padding.left,
                                right: MediaQuery.of(context).padding.right,
                              ),
                              viewPadding: EdgeInsets.only(
                                top: 20,
                                bottom: MediaQuery.of(context).viewPadding.bottom,
                                left: MediaQuery.of(context).viewPadding.left,
                                right: MediaQuery.of(context).viewPadding.right,
                              ),
                            ),
                            child: child,
                          ),
                        ),

                        // Dynamic Island mockup: sleek & modern
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                width: 110,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF25252A) : const Color(0xFFDFDFE5),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(14),
                                    bottomRight: Radius.circular(14),
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 9,
                                    height: 9,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF101015),
                                      shape: BoxShape.circle,
                                    ),
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
            ],
          ),
        );
  }
}
