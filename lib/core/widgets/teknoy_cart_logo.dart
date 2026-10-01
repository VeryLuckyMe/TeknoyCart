import 'package:flutter/material.dart';
import 'package:teknoycart/core/theme.dart';

/// Pixel-perfect vector logo widget for TeknoyCart (Option A: Speed-Ribbon TC).
/// Self-contained CustomPainter ensures crisp rendering at any density without asset dependencies.
class TeknoyCartLogo extends StatelessWidget {
  final double size;
  final Color color;

  const TeknoyCartLogo({
    super.key,
    this.size = 48.0,
    this.color = TeknoyTheme.citMaroon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TeknoyCartPainter(color: color),
      ),
    );
  }
}

class _TeknoyCartPainter extends CustomPainter {
  final Color color;

  _TeknoyCartPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Original SVG coordinate space is 256x256
    final scale = size.width / 256.0;
    canvas.save();
    canvas.scale(scale, scale);

    // 1. Cart Basket Outer & Cutout (PathFillType.evenOdd)
    final basketPath = Path()..fillType = PathFillType.evenOdd;
    // Outer outline
    basketPath.moveTo(32, 56);
    basketPath.lineTo(220, 56);
    basketPath.cubicTo(228, 56, 232, 62, 230, 71);
    basketPath.lineTo(211, 143);
    basketPath.cubicTo(207, 156, 195, 166, 180, 166);
    basketPath.lineTo(85, 166);
    basketPath.cubicTo(71, 166, 60, 156, 56, 142);
    basketPath.lineTo(46, 74);
    basketPath.lineTo(32, 74);
    basketPath.cubicTo(26, 74, 22, 69, 22, 63);
    basketPath.cubicTo(22, 58, 26, 56, 32, 56);
    basketPath.close();

    // Inner cutout
    basketPath.moveTo(68, 76);
    basketPath.lineTo(76, 140);
    basketPath.cubicTo(78, 147, 84, 151, 91, 151);
    basketPath.lineTo(174, 151);
    basketPath.cubicTo(182, 151, 188, 146, 190, 139);
    basketPath.lineTo(207, 76);
    basketPath.close();

    canvas.drawPath(basketPath, paint);

    // 2. Central 'T' Stem
    final stemPath = Path();
    stemPath.addRect(const Rect.fromLTWH(120, 76, 16, 72));
    canvas.drawPath(stemPath, paint);

    // 3. Wheels (left: 92, 189; right: 168, 189)
    _drawWheel(canvas, paint, const Offset(92, 189));
    _drawWheel(canvas, paint, const Offset(168, 189));

    canvas.restore();
  }

  void _drawWheel(Canvas canvas, Paint paint, Offset center) {
    // Outer ring: radius 18, inner cutout: radius 9 (evenOdd)
    final wheelPath = Path()..fillType = PathFillType.evenOdd;
    wheelPath.addOval(Rect.fromCircle(center: center, radius: 18));
    wheelPath.addOval(Rect.fromCircle(center: center, radius: 9));
    canvas.drawPath(wheelPath, paint);

    // Center hub
    canvas.drawCircle(center, 5.0, paint);
  }

  @override
  bool shouldRepaint(covariant _TeknoyCartPainter oldDelegate) =>
      oldDelegate.color != color;
}
