import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/utils/motion.dart';
import 'package:teknoycart/features/feed/views/widgets/product_card_skeleton.dart';

void main() {
  group('Motion helper (reduce-motion accessibility)', () {
    Future<void> pumpProbe(
      WidgetTester tester, {
      required bool disableAnimations,
      required void Function(bool reduce, Duration duration) onBuild,
    }) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Builder(
            builder: (context) {
              onBuild(
                Motion.reduce(context),
                Motion.duration(context, const Duration(milliseconds: 250)),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    }

    testWidgets('keeps the base duration when animations are enabled',
        (tester) async {
      bool? reduced;
      Duration? duration;
      await pumpProbe(tester, disableAnimations: false, onBuild: (r, d) {
        reduced = r;
        duration = d;
      });

      expect(reduced, isFalse);
      expect(duration, const Duration(milliseconds: 250));
    });

    testWidgets(
        'collapses finite transitions to zero when reduce motion is requested',
        (tester) async {
      bool? reduced;
      Duration? duration;
      await pumpProbe(tester, disableAnimations: true, onBuild: (r, d) {
        reduced = r;
        duration = d;
      });

      expect(reduced, isTrue);
      expect(duration, Duration.zero);
    });

    testWidgets(
        'ProductGridSkeleton shimmer loops by default but goes static under reduce motion',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
            home: Scaffold(body: ProductGridSkeleton(itemCount: 2))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.binding.transientCallbackCount,
        greaterThan(0),
        reason: 'the shimmer should be looping while animations are allowed',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const Scaffold(body: ProductGridSkeleton(itemCount: 2)),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.binding.transientCallbackCount,
        0,
        reason: 'the shimmer must stop ticking when reduce motion is requested',
      );
    });
  });
}
