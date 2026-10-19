import 'package:flutter/material.dart';

/// Smooth fade route specifically tailored for the splash-to-login logo handoff.
/// Keeps `opaque: false` so the splash canvas and fading furniture remain visible underneath.
/// Driven via `animation.drive` to avoid listener leaks.
class LogoHandoffRoute<T> extends PageRouteBuilder<T> {
  final bool plainCrossfade;

  LogoHandoffRoute({
    required WidgetBuilder builder,
    this.plainCrossfade = false,
  }) : super(
          transitionDuration: plainCrossfade
              ? const Duration(milliseconds: 250)
              : const Duration(milliseconds: 400),
          reverseTransitionDuration: Duration.zero,
          opaque: false,
          barrierDismissible: false,
          pageBuilder: (context, _, __) => builder(context),
          transitionsBuilder: (context, animation, _, child) => FadeTransition(
            // Login background + decorative circles fade in over the first half (or plain 250ms crossfade)
            opacity: plainCrossfade
                ? animation
                : animation.drive(
                    CurveTween(
                      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                    ),
                  ),
            child: child,
          ),
        );
}
