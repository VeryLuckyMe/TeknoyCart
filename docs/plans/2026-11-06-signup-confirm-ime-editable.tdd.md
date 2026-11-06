# Signup — Confirm Password becomes uneditable after a failed submit

**Date:** 2026-11-06
**Status:** Local automated gates pass (all 402 Flutter tests green, analyzer clean apart from 2 pre-existing infos). The freeze itself is an Android-on-device IME connection symptom that widget tests cannot enter — emulator verification by the project owner is the confirming RED/GREEN step.

## User journey

1. A student fills step 3 of sign-up with a password under the 12-character minimum **and** a Confirm Password that does not match it.
2. The student taps **Create Account**. The gate unfocuses (keyboard closes) and both field-level errors appear: *Password must be at least 12 characters* and *Passwords do not match*. This part is correct.
3. The student taps the Confirm Password field to fix it. The caret appears and the keyboard opens — but nothing they type, and nothing they delete, reaches the field. The form is now effectively dead for editing credentials.

**Lived observation (device):** "Caret appears, keyboard opens, but typing/deleting does nothing" on an **Android emulator**, and **both** password fields can freeze — not just Confirm Password.

## Investigation record

| Probe / layer | Result | Conclusion |
| --- | --- | --- |
| Code audit: `enabled`, `readOnly`, input formatters, controller cascades, lifecycle `unfocus()` | All clean across `auth_gate_view.dart`, `auth_login_form.dart`, `auth_register_form.dart`, `auth_form_fields.dart` | Not a widget-logic bug |
| IME/scroll geometry, driven through the real `TeknoyCartApp → AuthGateView` flow at 5 viewport+keyboard combos (390×844/336, 360×800/320, 360×800/400, 375×667/336, 320×690/300) | In every combo the failed submit closes the keyboard; re-tapping the field re-focuses it and EditableText's `showCaretOnScreen` auto-scrolls it fully above the IME line (e.g. 360×800: pre-tap y438→506 under IME line 480 → post-tap y326→394) | Geometry is not the cause; the framework reveal works even in the tightest scroll case |
| Platform IME channel (`tester.testTextInput`): connection attach, attach-time editing state, platform-delivered deletion + typing, hardware-keyboard backspace | Every path reaches the field after the real failed-submit flow | The framework↔tester IME contract is intact |
| Autofill surface | Both password fields carry `autofillHints: [AutofillHints.newPassword]` (register form and login form), and **no `AutofillGroup` exists anywhere in the app** | Every field opened an autofill-tagged IME connection with no group/session scope — the one non-vanilla thing on the platform side |

**Remaining layer = the real-device IME connection lifecycle.** The two fields the user saw freeze are exactly the two declared as `newPassword` autofill clients. With no enclosing `AutofillGroup`, each refocus after the submit-time `unfocus()` re-opens an autofill-annotated connection outside any group session; the closest known analog (flutter-stripe #392) is a text-input connection deadlock triggered by field churn the same way. Widget tests cannot enter this layer — `TestTextInput` is a mock of the platform side, so its behavior stays well-formed even when a real Android IME wedges.

## Fix (minimal)

Follow the documented `AutofillGroup` usage: "Wrap the TextField widgets that belong to the same logical form in an AutofillGroup."

| File | Change |
| --- | --- |
| `lib/features/auth/views/widgets/auth_register_form.dart` | The single `return Column(...)` becomes `final formColumn = Column(...)` + `return AutofillGroup(onDisposeAction: AutofillContextAction.cancel, child: formColumn)`. `cancel` (not commit) so an abandoned/failed sign-up never triggers a "Save password?" prompt with incomplete data. |
| `lib/features/auth/views/widgets/auth_login_form.dart` | Same wrap with the default action (`commit`), which is standard for credential forms. |
| `test/auth_register_confirm_editable_test.dart` (new) | Full-flow regression guard (see below). |

No behavior change to layout, validation, or submit. Fields across all three register steps share one scope; the group survives step switches because it sits above the whole step `Column`.

## Test specification and observed results

| Guarantee | Test / command | Result | Evidence |
| --- | --- | --- | --- |
| After the real failed submit, Confirm Password holds its value, the error lines show, the field clears the IME line on refocus, and typing + platform deletion + hardware deletion all still work | `test/auth_register_confirm_editable_test.dart` (drives Real app → gate → 3 steps → real submit handler, then asserts geometry, `testTextInput` attach contract, and every edit path) | PASS | Included in full `flutter test` |
| The earlier keyboard-overlap regression suite stays green | `test/auth_keyboard_overflow_test.dart` | PASS | Included in full `flutter test` |
| Whole Flutter suite | `flutter test` | PASS | 402 passed, 0 failed |
| Analyzer adds no new findings | `flutter analyze --no-fatal-infos` | PASS | Only the 2 pre-existing `dart:html` infos in `lib/features/reports/views/download_web.dart` (unrelated file, untouched) |

### Honest RED note (why the suite never went red in-model)

Two earlier "RED" runs were investigated and turned out to be a false failure of my own assertion: `testTextInput.editingState` legitimately does not echo back platform-originated edits (the framework does not re-broadcast `setEditingState` for platform-driven changes), so the attach-time snapshot `'abcdefghijx'` is the correct expectation, and after correcting it every layer passed. The genuine confirming RED/GREEN is the emulator check below — the widget model cannot reproduce a wedged real IME connection.

### Pre-existing test-environment artifacts documented (not touched by this fix)

The repo ships no font assets (`pubspec.yaml` has no `fonts:` entry), so under `flutter test` every glyph renders as the square Ahem fallback. Two text-heavy rows then exceed their on-device widths and throw `RenderFlex overflowed by …` during tests: the splash sign-up link row (`splash_view.dart` L778, up to 164 px at 320 width) and the register step-indicator row (`auth_register_form.dart` ~L69, up to 82 px). Widths scale exactly with viewport width — a font-fallback artifact, not a product defect. The new guard filters only this class of error; on a device with real Inter/Outfit metrics these rows do not occur. If desired, these two rows can be hardened separately (e.g. `FittedBox`/`Expanded`) — out of scope here.

## Required external verification (project owner)

1. On the Android emulator: repeat the exact failing sequence (step 3, 11-char password + mismatched confirm, submit, error lines). After the fix, both password and confirm fields must accept typing and deleting, repeatedly (dismiss keyboard, re-tap each field several times).
2. Confirm the login tab still autofills email/password from the keyboard suggestions (group commit is active there).
3. Confirm no stray "Save password?" bubble appears when abandoning the sign-up form mid-typing (dispose action = cancel).
4. If the freeze somehow persists on the emulator, the next candidate is the Android engine's `TextInput.clearClient → setClient` restart timing; the guard test gives us a stable baseline to bisect against.

Commits: the four signup-fix paths are staged locally in the nested `TeknoyCart/TeknoyCart` git repo (its working branch; index only, no commit). The root repo's `security/critical-fixes` branch is unrelated to this fix — the root does not track these app files. Nothing is pushed.
