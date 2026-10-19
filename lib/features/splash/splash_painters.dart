import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:teknoycart/core/theme.dart';

/// Lightweight radial glow painter centered on the logo.
/// Uses a direct Canvas RadialGradient shader with zero blur passes for 120 FPS performance.
class SplashGlowPainter extends CustomPainter {
  final double radius;
  final double alpha;
  final bool isDark;

  const SplashGlowPainter({
    required this.radius,
    required this.alpha,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0 || alpha <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final baseAlpha = isDark ? 0.30 : 0.38;
    final effectiveAlpha = (baseAlpha * alpha).clamp(0.0, 1.0);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          TeknoyTheme.citGold.withValues(alpha: effectiveAlpha),
          TeknoyTheme.citGold.withValues(alpha: effectiveAlpha * 0.4),
          TeknoyTheme.citGold.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, glowPaint);
  }

  @override
  bool shouldRepaint(covariant SplashGlowPainter old) {
    return old.radius != radius || old.alpha != alpha || old.isDark != isDark;
  }
}

/// Thin expanding ripple ring for the "landing impact" moment (0.6x -> 1.5x logo size).
class SplashRippleRingPainter extends CustomPainter {
  final double radius;
  final double progress; // 0.0 -> 1.0
  final double maxAlpha;

  const SplashRippleRingPainter({
    required this.radius,
    required this.progress,
    this.maxAlpha = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1.0 || radius <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final alpha = (maxAlpha * (1.0 - progress)).clamp(0.0, 1.0);

    final paint = Paint()
      ..color = TeknoyTheme.citGold.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant SplashRippleRingPainter old) {
    return old.radius != radius || old.progress != progress;
  }
}

/// Traces the 2px gold ring along the expanding circular iris boundary during route transition.
class IrisRingPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final double progress; // 0.0 -> 1.0

  const IrisRingPainter({
    required this.center,
    required this.radius,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0 || progress >= 1.0) return;

    final alpha = (0.6 * (1.0 - progress)).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = TeknoyTheme.citGold.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant IrisRingPainter old) {
    return old.radius != radius || old.progress != progress || old.center != center;
  }
}

/// Subtle static radial vignette behind the splash canvas.
/// RepaintBoundary wrapped for zero re-draw cost.
class SplashVignettePainter extends CustomPainter {
  final bool isDark;

  const SplashVignettePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = math.sqrt(size.width * size.width + size.height * size.height) / 2;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? const [
                Color(0xFF1E1318), // Subtle warm center vignette
                Color(0xFF140D10), // Dark scaffold edge
              ]
            : const [
                Color(0xFFFFFFFF), // Crisp center highlight
                Color(0xFFFFF7F2), // Warm cream campus edge
              ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxR));

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant SplashVignettePainter old) => old.isDark != isDark;
}
