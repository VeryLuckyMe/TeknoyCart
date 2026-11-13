import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/widgets/inactivity_wrapper.dart';

void main() {
  late DateTime now;
  late int timeouts;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: InactivityWrapper(
        timeout: const Duration(minutes: 30),
        clock: () => now,
        onTimeout: () => timeouts++,
        child: const Scaffold(body: SizedBox.expand(key: Key('body'))),
      ),
    ));
  }

  void resume(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  setUp(() {
    now = DateTime(2026, 11, 11, 10);
    timeouts = 0;
  });

  testWidgets('fires after 30 minutes with no interaction', (tester) async {
    await pump(tester);
    await tester.pump(const Duration(minutes: 29));
    expect(timeouts, 0);
    await tester.pump(const Duration(minutes: 1, seconds: 1));
    expect(timeouts, 1);
  });

  testWidgets('a tap restarts the countdown', (tester) async {
    await pump(tester);
    await tester.pump(const Duration(minutes: 20));
    now = now.add(const Duration(minutes: 20));
    await tester.tapAt(const Offset(100, 100));
    await tester.pump(const Duration(minutes: 20));
    expect(timeouts, 0, reason: 'only 20 min since the tap');
    await tester.pump(const Duration(minutes: 11));
    expect(timeouts, 1);
  });

  testWidgets('returning from background after 30+ min logs out immediately', (tester) async {
    await pump(tester);
    // Phone suspended: no timers run, but wall-clock time passes.
    now = now.add(const Duration(hours: 2));
    resume(tester);
    expect(timeouts, 1);
    await tester.pump(const Duration(minutes: 31));
    expect(timeouts, 1, reason: 'fires only once');
  });

  testWidgets('returning early keeps the remaining time', (tester) async {
    await pump(tester);
    now = now.add(const Duration(minutes: 10));
    resume(tester);
    expect(timeouts, 0);
    await tester.pump(const Duration(minutes: 19));
    expect(timeouts, 0);
    await tester.pump(const Duration(minutes: 1, seconds: 1));
    expect(timeouts, 1);
  });

  testWidgets('activity after a timeout starts a fresh countdown', (tester) async {
    await pump(tester);
    await tester.pump(const Duration(minutes: 31));
    expect(timeouts, 1);
    now = now.add(const Duration(minutes: 31));
    await tester.tapAt(const Offset(100, 100));
    await tester.pump(const Duration(minutes: 31));
    expect(timeouts, 2);
  });
}
