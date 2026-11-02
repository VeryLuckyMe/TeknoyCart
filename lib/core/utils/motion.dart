import 'package:flutter/material.dart';

/// Central motion helpers honoring the platform's "reduce motion"
/// accessibility setting ([MediaQueryData.disableAnimations]).
///
/// Use [Motion.accessibleDuration] (or [Motion.duration]) for finite transitions
/// and [Motion.prefersReducedMotion] (or [Motion.reduce]) to skip looping/infinite
/// animations so users who request minimal motion get calm, static UI instead
/// of crawling or pulsing elements.
class Motion {
  Motion._();

  /// True when the OS/user has requested reduced or disabled animations.
  static bool reduce(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Semantic identifier alias for [reduce].
  static bool prefersReducedMotion(BuildContext context) => reduce(context);

  /// Returns [base], or [Duration.zero] when reduced motion is requested.
  static Duration duration(BuildContext context, Duration base) =>
      reduce(context) ? Duration.zero : base;

  /// Semantic identifier alias for [duration].
  static Duration accessibleDuration(BuildContext context, Duration base) =>
      duration(context, base);
}
