import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Pure vector CustomPainter that renders and independently animates each part
/// of the TeknoyCart logo (shopping cart, wheels, isometric box with 'T',
/// tilted book, and two meshing gears).
class TeknoyCartLogoPainter extends CustomPainter {
  final double cartSlideX;
  final double cartTilt;
  final double cartBounceY;
  final double boxDropY;
  final double boxOpacity;
  final double bookDropY;
  final double bookOpacity;
  final double gear1DropY;
  final double gear1Opacity;
  final double gear1Angle;
  final double gear2DropY;
  final double gear2Opacity;
  final double gear2Angle;
  final Color? primaryColor;
  final bool isDark;

  const TeknoyCartLogoPainter({
    this.cartSlideX = 0.0,
    this.cartTilt = 0.0,
    this.cartBounceY = 0.0,
    this.boxDropY = 0.0,
    this.boxOpacity = 1.0,
    this.bookDropY = 0.0,
    this.bookOpacity = 1.0,
    this.gear1DropY = 0.0,
    this.gear1Opacity = 1.0,
    this.gear1Angle = 0.0,
    this.gear2DropY = 0.0,
    this.gear2Opacity = 1.0,
    this.gear2Angle = 0.0,
    this.primaryColor,
    this.isDark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 200.0;
    canvas.save();
    canvas.scale(scale, scale);

    final Color brandMaroon = primaryColor ?? TeknoyTheme.citMaroon;

    final Paint maroonFill = Paint()
      ..color = brandMaroon
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final Paint maroonStroke = Paint()
      ..color = brandMaroon
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // 1. GEAR 1 (Lower-Left Gear)
    if (gear1Opacity > 0.01) {
      canvas.save();
      canvas.translate(126, 48 + (gear1DropY * 140));
      canvas.rotate(gear1Angle);
      _drawGear(
        canvas,
        radius: 17,
        teeth: 8,
        color: brandMaroon.withValues(alpha: gear1Opacity.clamp(0.0, 1.0)),
      );
      canvas.restore();
    }

    // 2. GEAR 2 (Upper-Right Gear)
    if (gear2Opacity > 0.01) {
      canvas.save();
      canvas.translate(158, 30 + (gear2DropY * 140));
      canvas.rotate(gear2Angle);
      _drawGear(
        canvas,
        radius: 15.5,
        teeth: 8,
        color: brandMaroon.withValues(alpha: gear2Opacity.clamp(0.0, 1.0)),
      );
      canvas.restore();
    }

    // Apply Cart global slide & suspension bounce
    canvas.save();
    canvas.translate(cartSlideX * 260, cartBounceY * 8);
    // Pivot around front wheel for subtle brake tilt
    canvas.translate(150, 175);
    canvas.rotate(cartTilt);
    canvas.translate(-150, -175);

    // 3. TILTED BOOK (Inside Left of Basket)
    if (bookOpacity > 0.01) {
      canvas.save();
      canvas.translate(88, 62 + (bookDropY * 150));
      canvas.rotate(-0.46); // Tilted left like the original logo
      final Paint bookPaint = Paint()
        ..color = brandMaroon.withValues(alpha: bookOpacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      // Book cover body
      final RRect bookBody = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-26, -34, 52, 66),
        const Radius.circular(6),
      );
      canvas.drawRRect(bookBody, bookPaint);

      // White page lines at the bottom of the book
      final Paint pagePaint = Paint()
        ..color = Colors.white.withValues(alpha: bookOpacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(const Offset(-20, 20), const Offset(20, 20), pagePaint);
      canvas.drawLine(const Offset(-18, 25), const Offset(20, 25), pagePaint);
      canvas.restore();
    }

    // 4. ISOMETRIC BOX (Inside Right of Basket)
    if (boxOpacity > 0.01) {
      canvas.save();
      canvas.translate(154, 76 + (boxDropY * 150));
      final Paint boxPaint = Paint()
        ..color = brandMaroon.withValues(alpha: boxOpacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      final Path cubePath = Path()
        ..moveTo(0, -24) // Top peak
        ..lineTo(28, -11) // Top right
        ..lineTo(28, 21) // Bottom right
        ..lineTo(0, 34) // Bottom center
        ..lineTo(-28, 21) // Bottom left
        ..lineTo(-28, -11) // Top left
        ..close();
      canvas.drawPath(cubePath, boxPaint);

      // White isometric seams & top cross-straps
      final Paint seamPaint = Paint()
        ..color = Colors.white.withValues(alpha: boxOpacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(const Offset(-28, -11), const Offset(0, 2), seamPaint);
      canvas.drawLine(const Offset(28, -11), const Offset(0, 2), seamPaint);
      canvas.drawLine(const Offset(0, 2), const Offset(0, 34), seamPaint);
      // Cross tape on top
      canvas.drawLine(const Offset(-14, -17), const Offset(14, -4), seamPaint);
      canvas.drawLine(const Offset(14, -17), const Offset(-14, -4), seamPaint);
      // Small 'T' detail on right face
      canvas.drawLine(const Offset(10, 8), const Offset(20, 3), seamPaint);
      canvas.drawLine(const Offset(15, 6), const Offset(15, 20), seamPaint);
      canvas.restore();
    }

    // 5. SHOPPING CART WIREFRAME & WHEELS
    final Path cartPath = Path()
      // Handle
      ..moveTo(12, 42)
      ..lineTo(36, 52)
      // Spine down to lower frame
      ..lineTo(66, 146)
      // Basket outline
      ..moveTo(43, 72)
      ..lineTo(188, 86)
      ..lineTo(172, 144)
      ..lineTo(66, 144);
    canvas.drawPath(cartPath, maroonStroke);

    // Basket internal horizontal & vertical grid bars
    final Paint gridStroke = Paint()
      ..color = brandMaroon
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    // 2 inner horizontal bars
    canvas.drawLine(const Offset(50, 96), const Offset(182, 106), gridStroke);
    canvas.drawLine(const Offset(58, 120), const Offset(177, 125), gridStroke);

    // 5 inner vertical ribs
    for (int i = 1; i <= 5; i++) {
      final double t = i / 6.0;
      final double topX = 43 + (188 - 43) * t;
      final double topY = 72 + (86 - 72) * t;
      final double botX = 66 + (172 - 66) * t;
      canvas.drawLine(Offset(topX, topY), Offset(botX, 144), gridStroke);
    }

    // Lower curved undercarriage
    final Path underFrame = Path()
      ..moveTo(66, 144)
      ..quadraticBezierTo(48, 152, 64, 166)
      ..lineTo(172, 166);
    canvas.drawPath(underFrame, maroonStroke);

    // Left & Right Wheels
    _drawWheel(canvas, const Offset(78, 182), maroonFill);
    _drawWheel(canvas, const Offset(154, 182), maroonFill);

    canvas.restore(); // Restore cart slide/tilt
    canvas.restore(); // Restore canvas scale
  }

  void _drawWheel(Canvas canvas, Offset center, Paint fillPaint) {
    canvas.drawCircle(center, 14, fillPaint);
    canvas.drawCircle(center, 5.5, Paint()..color = Colors.white);
  }

  void _drawGear(
    Canvas canvas, {
    required double radius,
    required int teeth,
    required Color color,
  }) {
    final Paint gearPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final Path path = Path();
    final double innerR = radius * 0.74;
    final double outerR = radius;
    final double step = (2 * math.pi) / (teeth * 2);

    for (int i = 0; i < teeth * 2; i++) {
      final double r = i.isEven ? outerR : innerR;
      final double a1 = i * step - (step * 0.35);
      final double a2 = i * step + (step * 0.35);
      if (i == 0) {
        path.moveTo(math.cos(a1) * r, math.sin(a1) * r);
      } else {
        path.lineTo(math.cos(a1) * r, math.sin(a1) * r);
      }
      path.lineTo(math.cos(a2) * r, math.sin(a2) * r);
    }
    path.close();

    final Path hole = Path()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: radius * 0.34));
    final Path finalGear = Path.combine(PathOperation.difference, path, hole);

    canvas.drawPath(finalGear, gearPaint);
  }

  @override
  bool shouldRepaint(covariant TeknoyCartLogoPainter oldDelegate) =>
      oldDelegate.cartSlideX != cartSlideX ||
      oldDelegate.cartTilt != cartTilt ||
      oldDelegate.cartBounceY != cartBounceY ||
      oldDelegate.boxDropY != boxDropY ||
      oldDelegate.boxOpacity != boxOpacity ||
      oldDelegate.bookDropY != bookDropY ||
      oldDelegate.bookOpacity != bookOpacity ||
      oldDelegate.gear1DropY != gear1DropY ||
      oldDelegate.gear1Opacity != gear1Opacity ||
      oldDelegate.gear1Angle != gear1Angle ||
      oldDelegate.gear2DropY != gear2DropY ||
      oldDelegate.gear2Opacity != gear2Opacity ||
      oldDelegate.gear2Angle != gear2Angle ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.isDark != isDark;
}
