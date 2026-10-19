import 'package:flutter/material.dart';

abstract final class TeknoyBrand {
  static const logoHeroTag = 'teknoy-logo';
  static const logoAssetPath = 'assets/images/teknoy_cart_logo.png';
  static const logoProvider = AssetImage(logoAssetPath);
}

/// Shared branded logo widget ensuring identical ImageProvider and image cache keys across screens.
/// Uses FilterQuality.medium (mipmapped) for crisp anti-aliased downscaling during flights and thumbnails.
class TeknoyLogoImage extends StatelessWidget {
  final double? size;

  const TeknoyLogoImage({super.key, this.size});

  @override
  Widget build(BuildContext context) {
    return Image(
      image: TeknoyBrand.logoProvider,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      isAntiAlias: true,
      gaplessPlayback: true,
    );
  }
}
