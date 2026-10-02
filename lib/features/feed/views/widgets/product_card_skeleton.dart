import 'package:flutter/material.dart';
import '../../../../core/theme.dart';

/// Shimmer skeleton matching FeedProductCard for smooth loading states (MED-04).
class ProductGridSkeleton extends StatefulWidget {
  final int itemCount;

  const ProductGridSkeleton({super.key, this.itemCount = 6});

  @override
  State<ProductGridSkeleton> createState() => _ProductGridSkeletonState();
}

class _ProductGridSkeletonState extends State<ProductGridSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.itemCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.54,
            ),
            itemBuilder: (context, index) {
              return ProductCardSkeleton(shimmerValue: _shimmerAnimation.value);
            },
          ),
        );
      },
    );
  }
}

class ProductCardSkeleton extends StatelessWidget {
  final double shimmerValue;

  const ProductCardSkeleton({super.key, required this.shimmerValue});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark ? const Color(0xFF1E1E24) : const Color(0xFFECECF0);
    final highlightColor = isDark ? const Color(0xFF2D2D36) : const Color(0xFFF7F7FA);

    final gradient = LinearGradient(
      begin: Alignment(shimmerValue - 1, 0),
      end: Alignment(shimmerValue + 1, 0),
      colors: [baseColor, highlightColor, baseColor],
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141418) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF22222A) : const Color(0xFFECECEF),
          width: 1,
        ),
        boxShadow: TeknoyTheme.kElevationLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Square Image Skeleton
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                gradient: gradient,
              ),
            ),
          ),

          // 2. Details Skeleton
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Condition pill skeleton
                Container(
                  width: 50,
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: gradient,
                  ),
                ),
                const SizedBox(height: 8),

                // Title line 1
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: gradient,
                  ),
                ),
                const SizedBox(height: 6),

                // Title line 2
                Container(
                  width: 90,
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: gradient,
                  ),
                ),
                const SizedBox(height: 12),

                // Price skeleton
                Container(
                  width: 70,
                  height: 18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: gradient,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
