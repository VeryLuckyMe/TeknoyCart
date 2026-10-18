import 'package:flutter/material.dart';

/// Calm thumbnail placeholder for network images, shown while bytes load and
/// when loading fails so cards keep a stable, styled footprint instead of a
/// blank hole. Prefer this over spinners to match the app's skeleton style.
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({
    super.key,
    this.width,
    this.height,
    this.icon = Icons.broken_image_rounded,
    this.iconSize = 20,
  });

  final double? width;
  final double? height;
  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      color: isDark ? const Color(0xFF1C1C24) : const Color(0xFFEDEDF2),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: iconSize,
        color: isDark ? Colors.white30 : Colors.black26,
      ),
    );
  }
}
