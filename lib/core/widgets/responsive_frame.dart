import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:teknoycart/core/theme.dart';

/// A professional responsive layout container for desktop and web deployments.
/// On wide viewports, centers the application within a clean, max-width container
/// without artificial phone bezels or fake camera notches.
class ResponsiveMobileFrame extends StatelessWidget {
  final Widget child;

  const ResponsiveMobileFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Full width on mobile screens or native mobile platforms
        if (!kIsWeb || constraints.maxWidth <= 640) {
          return child;
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF070709) : const Color(0xFFEBEBF0),
          body: Center(
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 580,
              ),
              decoration: BoxDecoration(
                color: isDark ? TeknoyTheme.darkBg : TeknoyTheme.lightBg,
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.08 : 0.03),
                    blurRadius: 16,
                  ),
                ],
                border: Border.symmetric(
                  vertical: BorderSide(
                    color: isDark ? const Color(0xFF22222A) : const Color(0xFFDFDFE5),
                    width: 1,
                  ),
                ),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

