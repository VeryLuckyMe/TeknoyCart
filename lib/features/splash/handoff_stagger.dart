import 'package:flutter/material.dart';
import 'package:teknoycart/features/splash/logo_handoff_route.dart';

/// Reusable entry-stagger wrapper for the AuthGateView login sequence.
/// Synchronizes the arrival of login elements with the flying Hero logo.
/// When AuthGateView is opened normally (after logout, normal nav), it falls back to
/// `kAlwaysCompleteAnimation` so content appears instantly without rebuilding/remounting subtrees.
class HandoffStagger extends StatelessWidget {
  final double begin;
  final double end;
  final double dy;
  final double scaleFrom;
  final Widget child;

  const HandoffStagger({
    super.key,
    required this.begin,
    required this.end,
    this.dy = 0.0,
    this.scaleFrom = 1.0,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final Animation<double> base =
        (route is LogoHandoffRoute && route.animation != null && !route.plainCrossfade)
            ? route.animation!
            : kAlwaysCompleteAnimation;

    final t = base.drive(
      CurveTween(
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      ),
    );

    return FadeTransition(
      opacity: t,
      child: AnimatedBuilder(
        animation: t,
        child: child,
        builder: (_, c) => Transform.translate(
          offset: Offset(0, (1.0 - t.value) * dy),
          child: Transform.scale(
            scale: scaleFrom + (1.0 - scaleFrom) * t.value,
            child: c,
          ),
        ),
      ),
    );
  }
}
