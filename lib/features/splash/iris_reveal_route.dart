import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:teknoycart/features/splash/splash_painters.dart';

/// Custom clipper that punches an expanding circular hole originating from the logo center.
class IrisClipper extends CustomClipper<Path> {
  final double progress; // 0.0 -> 1.0
  final Offset center;

  const IrisClipper({
    required this.progress,
    required this.center,
  });

  @override
  Path getClip(Size size) {
    final corners = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    final maxR = corners.map((c) => (c - center).distance).reduce(math.max);
    final currentR = maxR * progress;

    return Path()..addOval(Rect.fromCircle(center: center, radius: currentR));
  }

  @override
  bool shouldReclip(IrisClipper old) => old.progress != progress || old.center != center;
}

/// Custom PageRouteBuilder implementing the cinematic Iris Circular Reveal.
/// Keeps `opaque: false` so the splash screen remains visible underneath while the iris expands.
class IrisRevealRoute<T> extends PageRouteBuilder<T> {
  final Widget destination;
  final Offset originCenter;
  final Duration revealDuration;
  final bool plainCrossfade;

  IrisRevealRoute({
    required this.destination,
    required this.originCenter,
    this.revealDuration = const Duration(milliseconds: 640),
    this.plainCrossfade = false,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => destination,
          transitionDuration: revealDuration,
          reverseTransitionDuration: Duration.zero,
          opaque: false, // Ensures splash canvas is visible under expanding circle
          barrierDismissible: false,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (plainCrossfade || MediaQuery.of(context).disableAnimations) {
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                ),
                child: child,
              );
            }

            final curvedProgress = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            );

            return AnimatedBuilder(
              animation: curvedProgress,
              builder: (context, _) {
                final progress = curvedProgress.value;
                final size = MediaQuery.sizeOf(context);
                final center = originCenter == Offset.zero
                    ? Offset(size.width / 2, size.height / 2)
                    : originCenter;

                final corners = [
                  Offset.zero,
                  Offset(size.width, 0),
                  Offset(0, size.height),
                  Offset(size.width, size.height),
                ];
                final maxR = corners.map((c) => (c - center).distance).reduce(math.max);
                final currentR = maxR * progress;

                // Subtle inward scale (1.06 -> 1.0) inside the clip for visual depth
                final depthScale = 1.06 - (0.06 * progress);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Expanding clipped content with RepaintBoundary
                    ClipPath(
                      clipper: IrisClipper(
                        progress: progress,
                        center: center,
                      ),
                      child: Transform.scale(
                        scale: depthScale,
                        alignment: Alignment.center,
                        child: RepaintBoundary(child: child),
                      ),
                    ),

                    // 2px gold ring tracing the expanding iris edge
                    IgnorePointer(
                      child: CustomPaint(
                        size: size,
                        painter: IrisRingPainter(
                          center: center,
                          radius: currentR,
                          progress: progress,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
}
