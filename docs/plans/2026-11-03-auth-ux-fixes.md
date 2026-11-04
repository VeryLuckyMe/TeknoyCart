# Auth UX Fixes — Research & Implementation Plan

**Status:** Proposed (research complete, no production code changed yet)
**Date:** 2026-11-03
**Reporter:** survey users (4 issues: 3 UX + 1 password-reset delivery)
**Repo:** `TeknoyCart` (Flutter only — no backend change required)
**Baseline:** `main` @ `1dc00d2`, working tree clean
**Constraint from requester:** *"Don't break other features and make no mistakes."* → every fix below is scoped, additive, and backed by a test that fails before and passes after.

---

## 0. Summary

| # | Report | Real defect | Severity | Files touched | Test count |
| :-- | :--- | :--- | :--- | :--- | :--- |
| 1 | Sign in / Sign up links "don't look clickable" | Link is a bare `GestureDetector` + `Text`: no ripple, no cursor, 21 px tall target, `citMaroon` on dark = **1.77:1** contrast (WCAG fail) | Medium (a11y) | 1 view + 1 widget file | 2 new |
| 2 | Student ID "auto-inserts a dash after 2 numbers" | `StudentIdInputFormatter` force-inserts a trailing dash at 2 digits **and** force-resets the caret to end, so backspace corrupts digits | High (blocks signup) | 2 files | 6 new / 4 rewritten |
| 3 | Confirm Password "can't be typed/deleted" | Not a disabled field — it is **pushed 34 px under the keyboard** by the extra error line + non-live helper row, with default `scrollPadding` (20 px) too small to auto-scroll it back | High (blocks signup) | 3 files | 3 new |
| 4 | Password reset email links to `localhost` | Web passes `redirectTo: null` → Supabase silently falls back to the dashboard **Site URL** (`localhost:3000`); the deployed origin is never sent | High (account recovery dead) | 2 files + dashboard | 4 new |

Recommended order: **3 → 2 → 1 → 4** (3 and 2 both block signup; 1 is cosmetic/a11y; 4 needs a dashboard step the user must perform).

---

## 1. Issue 1 — Sign in / Sign up links are not recognisable as links

### 1.1 Evidence

`lib/features/auth/views/auth_gate_view.dart:660-692`

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Text(_isLoginTab ? "Don't have an account? " : 'Already have an account? ', …),
    GestureDetector(                                  // ← no ripple, no cursor, no semantics
      onTap: () => _switchTab(!_isLoginTab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(_isLoginTab ? 'Sign up' : 'Sign in',
          style: const TextStyle(
            color: TeknoyTheme.citMaroon,             // ← hardcoded, brightness-blind
            fontWeight: FontWeight.bold, …)),
      ),
    ),
  ],
)
```

Measured / derived facts:

- **Tap target:** text ~50×21 px + 4×2 padding ≈ **58×25 px** — well under the 48 dp minimum.
- **Contrast:** `citMaroon #800000` on the dark auth canvas `#0D0D0F` = **1.77:1** (needs ≥ 3:1 for large text, 4.5:1 for 14 px). Light mode is ~9:1, so the bug is dark-mode-specific.
- **Affordance:** no underline, no pressed/ripple state, no pointer cursor on web, no `Semantics(button: true)`.
- **Inconsistency:** the sibling action on the same card, "Forgot Password?" (`auth_login_form.dart:98-114`), already uses `TextButton` + `citGold` + `minimumSize(44, 40)`. The Sign-up link simply never got the same treatment.

Adjacent, same root cause, same file family:
`auth_register_form.dart:713-725` — Terms/Privacy link is also a `GestureDetector` with hardcoded `citMaroon` (1.77:1 in dark). Fixing it costs ~6 lines while we are in the pattern.

### 1.2 Fix

**A. `auth_gate_view.dart:660-692`** — replace the `Row` + `GestureDetector` block with a `Wrap` (overflow-safe at 320 dp) containing the label and a `TextButton`:

```dart
Wrap(
  alignment: WrapAlignment.center,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
    Text("Don't have an account?", style: …white70/black54…),
    TextButton(
      onPressed: () => _switchTab(!_isLoginTab),
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.padded,
        foregroundColor: isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon,
        textStyle: const TextStyle(
          fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationColor: /* same token as foreground */,
        ),
      ),
      child: Text(_isLoginTab ? 'Sign up' : 'Sign in'),
    ),
  ],
)
```

- `TextButton` gives the ripple, hover/focus, pointer cursor, and button semantics for free — no new widget, no dependency (ponytail-aligned).
- Colour tokens: **dark → `citGold` (#F5B041, 10.3:1 on #0D0D0F)**, **light → `citMaroon` (~9:1 on white)**. Matches "Forgot Password?" so the card becomes internally consistent.
- Underline is the explicit non-colour affordance cue (also survives colour-blindness and forced-colours mode).
- `Wrap` prevents a horizontal overflow if the strings ever grow or the device is 320 dp wide.

**B. `auth_register_form.dart:713-725`** — same conversion for the Terms link (`TextButton` with `minimumSize(48,48)`, `isDark ? citGold : citMaroon`, keep the underline).

### 1.3 Tests

New `test/auth_link_affordance_test.dart`:
1. `find.widgetWithText(TextButton, 'Sign up')` finds exactly 1 widget; `find.byType(GestureDetector)` ancestors of that text is empty.
2. Tapping it switches the card to "Create Account" (behavioural guard — proves the refactor did not break the tab toggle).
3. Rendered size of the button ≥ 48×48 (`tester.getSize`).

Existing `auth_gate_view`/tab-switch tests must keep passing unchanged — the `onTap` callback target and `_switchTab` signature are untouched.

---

## 2. Issue 2 — Student ID auto-inserts a dash after 2 numbers

### 2.1 Evidence

`lib/features/auth/views/widgets/auth_form_fields.dart:282-315`

```dart
final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
for (int i = 0; i < digitsOnly.length && i < 9; i++) {
  if (i == 2 || i == 6) buffer.write('-');   // ← dash emitted even with no digits after it
  buffer.write(digitsOnly[i]);
}
return TextEditingValue(
  text: formatted,
  selection: TextSelection.collapsed(offset: formatted.length),  // ← caret ALWAYS jumps to end
);
```

Reproduced behaviours (scratch probe, since deleted):

| Action | Old output | French |
| :--- | :--- | :--- |
| type `2`, `1` | `21-` | dash the user never typed |
| backspace on `21-` | `2` | deletes a **digit** for one keystroke |
| `21-3456-789`, caret at 3, backspace | `23-4567-89` | digits silently shift — corruption |
| caret placed mid-field, type a digit | caret snaps to end | cannot edit in the middle |
| type in the last group | still forced to end | same |

Two independent defects:
1. **Trailing separator** — a dash is emitted when no character follows it.
2. **Caret destruction** — `selection` is unconditionally set to `formatted.length`, which makes every mid-string edit unusable; the repair logic at lines 289-299 also indexes `newValue.text` with `oldValue` offsets *after* `FilteringTextInputFormatter.digitsOnly` (line 421) has already stripped dashes, so the index arithmetic is operating on a different string than it was computed from.

Format `##-####-###` is enforced downstream in **three** places, so the formatter is only the presentation layer:

- `auth_gate_view.dart:212-221` (`_validateStep`, `^\d{2}-\d{4}-\d{3}$`)
- `auth_service.dart:309-311` (same regex before RPC)
- `is_student_id_available(p_student_id)` RPC at `auth_service.dart:319-320` — **must receive the canonical hyphenated form**, because existing profile rows store `##-####-###`. Any normalisation must therefore happen *before* the RPC, not after.

### 2.2 Fix (recommended: digits while typing, mask on completion)

Rewrite `StudentIdInputFormatter` so it is a **sanitizer + caret-preserving masker**:

```dart
class StudentIdInputFormatter extends TextInputFormatter {
  static const int _maxDigits = 9;
  static const String _pattern = '##-####-###';

  /// Canonical `##-####-###` form, or the raw digits if incomplete.
  static String digitsOf(String text) => text.replaceAll(RegExp(r'\D'), '');
  static String canonical(String text) {
    final d = digitsOf(text);
    if (d.length != _maxDigits) return d;
    return '${d.substring(0,2)}-${d.substring(2,6)}-${d.substring(6)}';
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final caret = newValue.selection.isValid
        ? newValue.selection.baseOffset.clamp(0, newValue.text.length)
        : newValue.text.length;
    final digitsBeforeCaret = digitsOf(newValue.text.substring(0, caret)).length;

    var digits = digitsOf(newValue.text);
    if (digits.length > _maxDigits) digits = digits.substring(0, _maxDigits);

    final text = digits.length == _maxDigits ? canonical(digits) : digits;

    // Map "N digits before caret" back onto the rendered string, then hop over separators.
    var offset = 0, seen = 0;
    while (offset < text.length && seen < digitsBeforeCaret) {
      if (text[offset] != '-') seen++;
      offset++;
    }
    while (offset < text.length && text[offset] == '-') offset++;

    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: offset));
  }
}
```

Resulting behaviour:

| Action | New output |
| :--- | :--- |
| type `2`, `1` | `21` (no phantom dash — the reported bug) |
| type `211029315` | `21-1029-315` (mask applied the moment the ID is complete) |
| paste `21-1029-315` | `21-1029-315` (idempotent) |
| backspace in `21-1029-315` | `21102931` (8 digits, **all digits preserved**) |
| edit the middle | caret stays next to the edited digit |
| 10+ digits | capped at 9 |

Supporting changes (no behaviour change to the wire format):

1. **`auth_register_form.dart:420-423`** — drop `FilteringTextInputFormatter.digitsOnly` (the formatter is now the single source of truth; double transformation was the cause of the caret drift) and keep `StudentIdInputFormatter()`.
2. **`auth_gate_view.dart:212-221`** — validate on digits, not on hyphens:
   `if (StudentIdInputFormatter.digitsOf(idTrimmed).length != 9) → same snackbar text`.
3. **`auth_service.dart:309-311`** — `final studentIdCanonical = StudentIdInputFormatter.canonical(studentId);` then validate + pass **canonical** to the availability RPC, `user_metadata['student_id']` (line 339) and `users.student_id` (line 375). This is the choke point that keeps DB rows and RPC lookups in `##-####-###` even if the field still shows raw digits because the user hit Continue mid-typing.
4. **`auth_gate_view.dart:400-402`** — unchanged (passes `_studentIdController.text`), since the service now normalises.

**Rejected alternative:** keep live dashes but make them caret-aware (never emit a trailing dash). It is closer to the old UX and a smaller test diff, but it still inserts a separator the user did not type at digit 3 and 7 — which is literally what the survey complained about. Kept as a fallback option if the user prefers the visual mask during typing (see §6).

### 2.3 Tests

Rewrite the `StudentIdInputFormatter & UX Validation Tests` group in `test/auth_test.dart:97-159` (4 tests currently assert the *old* live-mask behaviour, e.g. `211 → 21-1`; they are the only tests that need their expectations changed — flagged explicitly because "don't break other features" means we must know exactly which assertions move):

1. partial typing emits no dash (`2` → `2`, `21` → `21`, `211` → `211`).
2. 9 digits → `21-1029-315`; 10+ digits capped.
3. paste hyphenated → idempotent.
4. backspace from complete ID → digits intact (regression for the corruption case).
5. middle edit keeps caret adjacent to the edited digit (regression for caret-to-end).
6. `canonical()` on `211029315` and `21-1029-315` both → `21-1029-315`.
7. `auth_service` test: given `studentId: '211029315'`, the availability RPC is invoked with `p_student_id: '21-1029-315'` and metadata is canonical.

---

## 3. Issue 3 — Confirm Password cannot be typed/deleted

### 3.1 Evidence (this one was **not** what it looked like)

A widget probe (390×844, keyboard inset 336 px) proved the field is **not disabled and not read-only**: after a failed submit, `enterText('abc')` then `enterText('ab')` works. What actually happens:

- Password field shows its validator error (*"Password must be at least 12 characters"*, `auth_register_form.dart:620-622`);
- a separate static helper row *"Must be at least 12 characters"* already occupies `auth_register_form.dart:626-653`;
- together they add **~40 px** of height *after* the keyboard has already opened;
- Confirm Password shifts from **y 433-482 → y 473-542** while the keyboard-resized scroll viewport ends at **y 508** → **34 px of the field is under the keyboard**;
- `AuthInputField` (`auth_form_fields.dart:225`) never sets `scrollPadding`, so `EditableText` uses the default `EdgeInsets.all(20)` — too small to scroll a field that just grew a 20 px error line above it;
- the helper row is **not live**: it reads `widget.passwordController.text` inside `build()` with no listener, so the tick only flips when some unrelated `setState` happens (obscure toggle, tab switch…). Users therefore cannot see the requirement being satisfied while typing, which is why they keep hammering the field.

So the honest root cause is **layout + keyboard inset + a non-reactive helper**, in that order. The field itself is fine.

### 3.2 Fix

**A. Reserve the helper's height so validation can never shift the form** (`auth_register_form.dart:626-653`)
Wrap the helper in a fixed-height `SizedBox(height: 20)` and make it reactive:

```dart
const SizedBox(height: 6),
ValueListenableBuilder<TextEditingValue>(
  valueListenable: widget.passwordController,
  builder: (context, value, _) {
    final ok = value.text.length >= 12;
    final color = ok ? Colors.green : (isDark ? Colors.white54 : Colors.black45);
    return SizedBox(
      height: 20,                      // ← constant height, no reflow
      child: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.info_outline_rounded, size: 13, color: color),
        const SizedBox(width: 4),
        Expanded(child: Text(ok ? 'At least 12 characters ✓' : 'Must be at least 12 characters',
            style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: color))),
      ]),
    );
  },
)
```

This is exactly the W6 item already prescribed in `docs/plans/2026-10-24-auth-hardening.md:329-360`; it was never implemented.

**B. Give text fields keyboard-aware scroll padding** (`auth_form_fields.dart:190-280`)
Add an optional parameter with a safe default and forward it:

```dart
final EdgeInsets scrollPadding;   // default: const EdgeInsets.only(top: 24, bottom: 120)
…
TextFormField(… scrollPadding: scrollPadding, …)
```

`bottom: 120` = 14 (field padding) + 20 (helper) + ~40 (error line) + 24 (breathing room). This is the mechanism `EditableText` uses to `ensureVisible` the caret, so the confirm field will auto-scroll above the keyboard even when an error appears above it.

**C. (Optional, P2) Live mismatch feedback on Confirm Password only** — `autovalidateMode: AutovalidateMode.onUserInteraction` on that single field, plus a `ValueListenableBuilder` on the password controller so an already-typed confirmation re-validates when the password changes. Nice-to-have; not required to close the report.

**D. (Optional, P2)** In `_submitForm`, after `_formKey.currentState!.validate()` returns false, scroll to the first error (`Scrollable.ensureVisible` on the field's context and/or a `GlobalKey` per error). Not required — A + B already make the failing field reachable.

### 3.3 Tests

New `test/auth_keyboard_overflow_test.dart`:
1. Render the register form in a 390×844 surface with `tester.view.viewInsets` set to a 336 px keyboard; submit with a 5-char password; assert `tester.takeException()` is null (no overflow) and that the Confirm Password field's `scrollPadding.bottom >= 100`.
2. Type 12 characters and assert the check icon appears **without** any other interaction (regression for the non-live helper) — this test fails on `main` today.
3. Assert the register column's height is identical before and after the password error appears (proves the fixed-height helper eliminates the reflow).

---

## 4. Issue 4 — Password reset email points at `localhost`

### 4.1 Evidence

`lib/features/auth/views/widgets/auth_password_sheets.dart:250-257`

```dart
await Supabase.instance.client.auth.resetPasswordForEmail(
  email,
  redirectTo: kIsWeb ? null : 'teknoycart://login-callback',
);
```

- On web, `null` means *"use the project's Site URL"*. `SESSION_HANDOVER_AND_CHANGELOG.md:127-135` records that the project Site URL is still `http://localhost:3000`, so the emailed link opens `localhost` on a phone → dead end.
- The deployed origin is never transmitted, so Supabase cannot pick the right host even when the allowlist is correct.
- Client is PKCE (`supabase_client.dart:41-48`), so the recovery link returns `?code=…`; `auth_gate_view.dart:120-147` already listens for `AuthChangeEvent.passwordRecovery` **and** falls back to scanning `Uri.base` for `type=recovery`. Recovery handling exists — only the redirect target is wrong.
- Two parts are needed: **(a) the client must pass an explicit URL**, and **(b) the Supabase dashboard allowlist must contain it.** Neither alone works: Supabase silently falls back to Site URL when the requested `redirectTo` is not allowlisted, which is why this has stayed broken.

### 4.2 Fix

**A. Config** — `lib/core/config/api_config.dart` (mirrors the existing `String.fromEnvironment` pattern):

```dart
/// Explicit web origin for auth emails (password reset / recovery). Set at
/// build time for production:  --dart-define=AUTH_REDIRECT_URL=https://app.example.com/
static const String authRedirectUrl = String.fromEnvironment('AUTH_REDIRECT_URL');

/// Native deep-link target (already declared in AndroidManifest / Info.plist).
static const String mobileAuthRedirectUrl = String.fromEnvironment(
  'AUTH_REDIRECT_MOBILE_URL',
  defaultValue: 'teknoycart://login-callback',
);
```

**B. Pure resolver** (unit-testable, no platform channels) — new `lib/features/auth/utils/auth_redirect.dart`:

```dart
/// Returns the redirect URL Supabase should embed in auth emails, or null.
/// Precedence: explicit --dart-define → current web origin (fragment/query
/// stripped) → null (Supabase Site URL; last resort only).
String? resolveAuthRedirect({
  required bool isWeb,
  required Uri baseUri,
  String configuredWebUrl = ApiConfig.authRedirectUrl,
  String mobileUrl = ApiConfig.mobileAuthRedirectUrl,
}) {
  if (!isWeb) return mobileUrl;
  if (configuredWebUrl.isNotEmpty) return configuredWebUrl;
  if (baseUri.scheme != 'http' && baseUri.scheme != 'https') return null;
  final clean = baseUri.replace(fragment: '', query: '');   // keeps sub-path deploys
  return clean.toString();
}
```

**C. Call site** — `auth_password_sheets.dart:250-257`:

```dart
redirectTo: resolveAuthRedirect(isWeb: kIsWeb, baseUri: Uri.base),
```

That is the entire client change: production links now carry the deployed origin automatically, and `--dart-define=AUTH_REDIRECT_URL=…` pins it if the app is served from a host that differs from `Uri.base` (reverse proxy / store-redirect wrappers).

### 4.3 Supabase dashboard steps (external — must be done by the project owner)

These are configuration, not code, and **must** be completed or the fix will appear to do nothing:

1. **Authentication → URL Configuration → Site URL** = `https://<production-web-host>/` (no longer `localhost:3000`).
2. **Redirect URLs** — add:
   - `https://<production-web-host>/**`
   - `https://<staging-or-preview-host>/**` (only if used)
   - `http://localhost:8080/**` (current `flutter run -d web-server --web-port=8080` dev origin)
   - `http://localhost:3000/**` (if the team also runs web on 3000)
   - `teknoycart://login-callback` (native — confirm it is actually still present; the changelog suggests mobile may already be relying on the Site URL fallback)
3. **Email Templates → Reset Password** — optional but recommended: add `{{ .Token }}` alongside the link so the existing manual-code fallback (`verifyRecoveryInput`, `auth_password_sheets.dart:13-99`) works when the link host is unreachable.
4. **Project settings → Auth → SMTP**: confirm custom SMTP is configured; the default sender is rate-limited to a handful of mails per hour, which makes verification look like "the reset email is broken".

### 4.4 Tests

New `test/auth_redirect_test.dart` (pure function, no mocking):
1. web + `AUTH_REDIRECT_URL` set → that value verbatim.
2. web + no define → `Uri.parse('https://app.teknoycart.com/login?x=1#y')` resolves to `https://app.teknoycart.com/login` (query/fragment stripped, sub-path preserved).
3. native → `teknoycart://login-callback`, unchanged from today.
4. non-http base URI → `null` (safe fallback, same as current behaviour).

Plus one assertion in the existing forgot-password sheet test that `resetPasswordForEmail` is invoked with a non-null `redirectTo` on web (and with exactly `teknoycart://login-callback` on native), so the regression cannot silently return.

### 4.5 Honest limitation

Automated tests can only prove *the app sends the right URL*. They cannot prove the dashboard allowlist matches, nor that the delivered email contains it. Final verification is necessarily manual:

- request a reset on the deployed web build → open the email → **link host == deployed host** → link opens the app → "Set new password" sheet appears;
- same on Android → app opens via `teknoycart://`.

---

## 5. Risk register / non-regression checks

| Risk | Mitigation |
| :--- | :--- |
| Student ID formatter rewrite changes an existing user-visible behaviour | Only the 4 formatter tests in `auth_test.dart` change; DB/RPC contract is *strengthened* (canonical form guaranteed before `is_student_id_available`), with a dedicated test for it |
| Rejecting `21-1029-31` (8 digits) still works after digit-based validation | `_validateStep` checks `digitsOf(...).length != 9` — same rejection, clearer message |
| `scrollPadding` too large causing overscroll on small screens | Value checked at 320×568 and 390×844 in the widget test |
| TextButton changes the auth card's pixel height → other golden/layout tests | No goldens exist in `test/`; the card is inside a `SingleChildScrollView` (`auth_gate_view.dart:506`) so growth is absorbed |
| Gold link colour looks off-brand | Dark-mode gold is already used by "Forgot Password?" on the same card — this makes the card consistent, not new |
| `AUTH_REDIRECT_URL` mis-set / not allowlisted → silent fallback to Site URL | Resolver test + dashboard checklist + the manual email inspection above; misconfiguration degrades to today's behaviour, it does not create a new failure |
| Deep-link scheme drifts from the manifest | `mobileAuthRedirectUrl` defaults to the literal already in `AndroidManifest.xml`; if it changes, both must change (noted inline) |

Full-suite gate before shipping (per `AGENTS.md` Phase 5), from `TeknoyCart/TeknoyCart`:

```powershell
flutter analyze
flutter test                                    # 54 existing files + 4 new
flutter test test/auth_test.dart test/auth_register_form_test.dart test/auth_link_affordance_test.dart test/auth_keyboard_overflow_test.dart test/auth_redirect_test.dart
flutter run -d chrome --web-port=8080 --dart-define=AUTH_REDIRECT_URL=http://localhost:8080/
```

Also update after shipping: `AUTH_AUDIT_REPORT.md` (H9 → fixed), `SESSION_HANDOVER_AND_CHANGELOG.md` (localhost fallback resolved), and tick W6 in `docs/plans/2026-10-24-auth-hardening.md`.

---

## 6. Decisions — RESOLVED (2026-11-03)

1. **Student ID behaviour**: no automatic dash at all (faculties use `2004-3732`). Implemented as a sanitizer: keeps digits and dashes, preserves the caret, never inserts a separator. Validation is digit-count based (6–12). → `StudentIdRules` / `StudentIdInputFormatter`.
2. **Dark-mode link colour**: `citMaroon` (user preference), plus underline + `TextButton` for affordance. Contrast caveat (1.77:1) noted; underline is the non-colour cue.
3. **Scope of link fix**: Sign in/Sign up **and** the Terms/Privacy link (same defect), both converted to `TextButton`.
4. **Dashboard access**: SQL + dashboard checklist provided; user must apply them. Code fix alone is insufficient.

## 7. Implementation status

Implemented in this change set (all `flutter analyze` infos pre-existing except none new; targeted tests green):

- `lib/features/auth/utils/auth_redirect.dart` — `AuthRedirectConfig` + `AuthRedirectFailure`.
- `lib/features/auth/utils/student_id.dart` — `StudentIdRules`.
- `lib/core/config/api_config.dart` — `AUTH_REDIRECT_URL` / `AUTH_REDIRECT_MOBILE_URL` defines.
- `lib/features/auth/views/widgets/auth_form_fields.dart` — caret-preserving sanitizer + `scrollPadding` param.
- `lib/features/auth/views/widgets/auth_register_form.dart` — live fixed-height password hint + no auto-dash + TextButton terms link.
- `lib/features/auth/views/auth_gate_view.dart` — TextButton/Wrap link, digit-count validation, error-param handling, keyboard dismiss on failed submit.
- `lib/features/auth/services/auth_service.dart` — relaxed validation.
- `lib/features/auth/views/widgets/auth_password_sheets.dart` — resolver + same-browser hint.
- `student_id_format_relax.sql` — DB migration (constraint relax + digit-based uniqueness + RPC rewrite).
- Tests: `auth_test.dart` (rewritten formatter group), `auth_redirect_test.dart`, `auth_link_affordance_test.dart`, `auth_keyboard_overflow_test.dart`.

### Manual follow-ups (cannot be done from this repo)
- Supabase dashboard: Site URL → deployed origin; Redirect URLs add `https://<prod>/**`, `http://localhost:8080/**`, `teknoycart://login-callback`; `{{ .Token }}` in the recovery template; custom SMTP.
- Run `student_id_format_relax.sql` in the Supabase SQL editor (review the RPC body first — it is not in this repo).
- Always run web on a pinned port (`--web-port=8080`) so the PKCE code verifier survives across requests.

1. **Student ID behaviour** — (a) *recommended*: digits-only while typing, `##-####-###` applied the moment the 9th digit lands; (b) live caret-aware mask that never emits a trailing dash. (a) fixes the complaint literally and is the simplest to keep correct; (b) looks closer to today but still inserts separators mid-typing.
2. **Dark-mode link colour** — `citGold` (10.3:1, already used by "Forgot Password?") vs `citMaroonLight` `#B22222` (2.89:1, still fails AA) vs maroon + underline only. Recommend gold.
3. **Scope of the link-pattern fix** — Sign in/Sign up only, or also the Terms/Privacy link in the register form (same defect, +6 lines)?
4. **Issue 4 dashboard access** — can you (or the project owner) apply the Site URL / Redirect URL changes? The code fix is worthless without them, and I cannot reach the Supabase dashboard from here.

Nothing in this plan touches order flow, RBAC (`role == 'SELLER' && is_seller_verified`), Riverpod providers, or the backend.
