import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/features/auth/views/auth_gate_view.dart';
import 'package:teknoycart/main.dart';
import 'support/test_harness.dart';

/// Reproduces the reported regression: after a failed submit where the
/// password is below the 12-character minimum AND the Confirm Password value
/// does not match it, the Confirm Password field can no longer be edited —
/// nothing can be typed into it nor deleted from it.
///
/// Unlike test/auth_keyboard_overflow_test.dart (which pumps the bare
/// [AuthRegisterForm] and therefore has no header chrome displacing the
/// fields downward), this drives the REAL flow — TeknoyCartApp →
/// AuthGateView → all three register steps → the real submit handler —
/// on a 390x844 viewport, with the keyboard closed while navigating and open
/// while typing, exactly as on a device.
Finder _fieldByLabel(String label) => find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == label,
      description: 'TextField labelled "$label"',
    );

/// The layout-overflow reports raised by DebugOverflowIndicatorMixin are
/// `FlutterError`s carrying the sizing information collector.
bool exceptionsIsOverflow(FlutterErrorDetails details) =>
    details.exception is FlutterError;

void main() {
  setUpAll(() async {
    await TestHarness.setUpAllEnvironment();
  });

  testWidgets(
    'after a failed submit the Confirm Password field clears the keyboard and accepts edits',
    (tester) async {
      // Phone viewport, keyboard open (like a device mid-typing) once the
      // register flow starts. 390x844 with a 336 px IME — a mid-size phone
      // layout; the companion auth_keyboard_overflow_test.dart covers the
      // other keyboard/geometry classes of this form.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 0);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      // The repo ships no font assets (pubspec has none) and Inter/Outfit are
      // unavailable to the test environment, so every glyph renders with the
      // square Ahem fallback. Text-heavy rows (e.g. the register "Step n of 3"
      // indicator and the splash sign-up link) then exceed their natural
      // on-device widths and produce RenderFlex overflow errors — an
      // environment artifact, not a product defect. Filter only those so this
      // suite still fails on any real, unexpected error.
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final message = details.exception.toString();
        final isOverflowNoise = exceptionsIsOverflow(details) &&
            message.contains('RenderFlex overflowed by');
        if (!isOverflowNoise && originalOnError != null) {
          originalOnError(details);
          return;
        }
        if (isOverflowNoise) return;
      };

      // Keep taps faithful: a real user scrolls an element into view first.
      Future<void> tapVisible(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
      }

      await tester.pumpWidget(const ProviderScope(child: TeknoyCartApp()));
      await tester.pumpAndSettle();
      expect(find.byType(AuthGateView), findsOneWidget);

      // Register tab (keyboard still closed — nothing to type on this tab).
      await tapVisible(find.text('Sign up'));
      await tester.pumpAndSettle();

      // Keyboard opens with the first typing, as on a device.
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);

      // Step 0 — identity.
      await tester.enterText(_fieldByLabel('First Name'), 'Ada');
      await tester.enterText(_fieldByLabel('Last Name'), 'Lovelace');
      await tapVisible(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 1 — student identity.
      await tester.enterText(_fieldByLabel('Student ID'), '21-1029-315');
      // Tap the dropdown FIELD itself — its hint Text's center can resolve to
      // the decoration label rather than the field's tap area.
      await tapVisible(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CCS — College of Computer Studies'));
      await tester.pumpAndSettle();
      await tapVisible(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2 — credentials, exactly the reported values.
      await tester.enterText(
        _fieldByLabel('CIT-U Email (@cit.edu)'),
        'ada.lovelace@cit.edu',
      );
      await tester.enterText(_fieldByLabel('Password'), 'abcdefghijk'); // 11 chars
      await tester.enterText(
        _fieldByLabel('Confirm Password'),
        'abcdefghijx', // mismatch
      );

      // Accept terms so the real submit handler actually runs.
      await tester.tap(find.byKey(const Key('auth-terms-checkbox')));
      await tester.pump();

      await tapVisible(find.byKey(const Key('auth-submit-btn')));
      await tester.pump();

      // A failed validate closes the keyboard on device (AuthGateView unfocuses).
      tester.view.viewInsets = const FakeViewPadding(bottom: 0);
      await tester.pumpAndSettle();

      // The reported state: BOTH field-level error lines are showing.
      expect(
        find.text('Password must be at least 12 characters'),
        findsOneWidget,
      );
      expect(find.text('Passwords do not match'), findsOneWidget);

      // …and the Confirm Password field still holds the first (mismatched) entry.
      final confirmFinder = _fieldByLabel('Confirm Password');
      final confirm = tester.widget<TextField>(confirmFinder).controller!;
      expect(confirm.text, 'abcdefghijx');

      // The user taps the Confirm Password field to fix it → IME opens again.
      await tapVisible(confirmFinder);
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      await tester.pumpAndSettle();

      // REGRESSION: the focused field must sit fully above the IME line.
      const imeTop = 844.0 - 336.0;
      final confirmRect = tester.getRect(confirmFinder);
      expect(
        confirmRect.bottom,
        lessThanOrEqualTo(imeTop),
        reason:
            'After the failed submit the Confirm Password field (bottom: '
            '${confirmRect.bottom}) must clear the keyboard (top: $imeTop) — '
            'otherwise taps reach the IME instead of the field, and the field '
            'cannot be typed into or edited.',
      );

      // Editing works: typing replaces the value…
      await tester.enterText(confirmFinder, 'abcdefghijkl');
      await tester.pumpAndSettle();
      expect(confirm.text, 'abcdefghijkl');

      // The platform side must be attached to this exact field with its live
      // value at attach time, and platform-delivered edits (what a real
      // keyboard sends) must reach the field — typing and deleting both.
      // (The framework does not echo setEditingState back for platform-driven
      // changes, so editingState reflects attach-time state, not later edits.)
      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(tester.testTextInput.editingState?['text'], 'abcdefghijx');

      // Platform-delivered backspace: value shrinks from 12 to 11 chars.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'abcdefghijk',
          selection: TextSelection.collapsed(offset: 11),
          composing: TextRange.empty,
        ),
      );
      await tester.pump();
      expect(confirm.text, 'abcdefghijk');

      // Platform-delivered typing: value grows again.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'abcdefghijkl',
          selection: TextSelection.collapsed(offset: 12),
          composing: TextRange.empty,
        ),
      );
      await tester.pump();
      expect(confirm.text, 'abcdefghijkl');

      // The hardware-keyboard backspace path keeps working too.
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(confirm.text, 'abcdefghijk');
    },
  );
}

