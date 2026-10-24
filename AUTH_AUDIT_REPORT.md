# TeknoyCart — Login & Register Security / Reliability Audit

**Date:** 2026-10-24
**Scope:** Mobile auth (`lib/features/auth/**`), session bootstrap (`lib/main.dart`, `lib/core/**`), Spring Boot auth (`AuthController`, `JwtTokenProvider`, `JwtAuthenticationFilter`, `SecurityConfig`), Supabase registration/RLS SQL, and the React admin login.
**Method:** Full read of every file in scope + cross-layer trace of each auth flow + SQL policy/trigger review + `flutter test` + `flutter analyze`. Read-only: no application code was modified.
**Result:** **DO NOT SHIP as-is.** 3 critical, 13 high, 12 medium, 17 low findings. The critical items are database-side and defeat the RBAC model the app is built around.

---

## 1. Verdict

| Dimension | Verdict | Why |
| :--- | :--- | :--- |
| Authentication correctness | ⚠️ Partial | Mobile login works; registration and verification depend on undocumented Supabase project settings; password reset is likely broken on mobile. |
| Authorization / RBAC | ❌ Fail | The user-protection triggers are ineffective. Any authenticated student can make themselves `ADMIN`. |
| Session & token handling | ❌ Fail | No backend-token refresh, ephemeral signing key by default, stale Supabase token copies, no revocation. |
| Email verification | ⚠️ Partial | Enforced only in `/auth/login`; silently unsent without a Brevo key; the in-app status poller cannot see the result. |
| Data protection (PII) | ❌ Fail | Full name/email disclosed before password check; `users` table readable by every authenticated user; PII in query strings. |
| UX / UI quality | ✅ Good | Clear 3-step register, lockout UX, dark mode, empty/error states. |
| Accessibility | ⚠️ Partial | Gold text on white ≈ 1.9:1, maroon ≈ 3.95:1, sub-24px link targets, no autofill hints. |
| Test coverage | ⚠️ Partial | 24/24 auth tests pass, but they cover validators/UI and **codify** the enumeration leak. No success-path login test, no DB trigger test. |

---

## 2. How auth actually flows (the root problem)

There are **two identity systems** and **three login/registration surfaces**, each enforcing different rules.

```
MOBILE REGISTER
  Flutter ──signUp()──────────────────────────────▶ Supabase GoTrue (auth.users)
  Flutter ──from('users').upsert() [client, RLS]──▶ public.users        ← needs a live session
  Flutter ──POST /auth/send-verification──────────▶ Spring Boot ──▶ Brevo
  Flutter ──signOut()─────────────────────────────▶ Supabase GoTrue

MOBILE LOGIN
  Flutter ──POST /auth/login──────────────────────▶ Spring Boot
                                                      ├─ JPA: public.users (lockout, is_verified)
                                                      ├─ password grant ▶ Supabase GoTrue
                                                      └─ issues HS256 JWT (24 h) + Supabase session
  Flutter ──auth.setSession(refresh_token)────────▶ Supabase GoTrue

WEB LOGIN (admin console)
  React ──signInWithPassword()────────────────────▶ Supabase GoTrue
  React ──select role from public.users───────────▶ PostgREST
        (no backend call, no is_verified check, no lockout, no backend JWT)
```

Consequences:
- Email verification is enforced in exactly one place: `AuthController:331-338`.
- The client model **cannot represent** `is_verified` at all (`Profile` has no such field), so no client can enforce it.
- The second (unused) `/auth/register` endpoint creates `public.users` rows with **no matching `auth.users` identity**, so those accounts can never get a Supabase session.
- Two independent verification emails (Supabase's own confirmation + the backend's token) can disagree.

---

## 3. Critical findings

### C1 — Privilege escalation to `ADMIN` from any logged-in student
**Severity:** Critical · **Confidence:** High (verifiable with the query in §8)

**Evidence**
- `migration_p4_security_hardening.sql:12-37` — `enforce_default_role_on_insert()` is `SECURITY DEFINER`.
- `migration_p4_security_hardening.sql:41-73` and `migration_p6_admin_backdoor_hardening.sql:226-270` — `protect_user_security_columns()` is `SECURITY DEFINER` and starts with:
  ```sql
  IF jwt_role IS NULL
     OR jwt_role = 'service_role'
     OR current_user LIKE 'postgres%'
     OR session_user LIKE 'postgres%' THEN
      RETURN NEW;
  END IF;
  ```
- `comprehensive_rls_policies.sql:54-64` — the INSERT policy only checks `auth.uid() = user_id`; the UPDATE policy only checks ownership.
- `comprehensive_rls_policies.sql:48-51` — any authenticated user can read every row.

**Why it is broken**
1. Inside a `SECURITY DEFINER` function, `current_user` is the **function owner**, not the caller. These functions are created in the Supabase SQL editor, so they are owned by `postgres`. `current_user LIKE 'postgres%'` is therefore **true for every invocation**, including PostgREST requests from `anon`/`authenticated`. The guard returns `NEW` before any check runs.
2. Even if the owner were not `postgres`, the first branch (`jwt_role IS NULL`) fires on any PostgREST version that exposes only `request.jwt.claims` and not the legacy `request.jwt.claim.role`. Either way the trigger is a no-op.
3. The UPDATE policy does not restrict columns, and the trigger that was supposed to restrict them does nothing.

**Impact**
Any student with a session can send one PATCH and become an administrator:
- `public.users.role = 'ADMIN'`, `is_verified = true`, `is_seller_verified = true` are all writable.
- `migration_p4_auth_sync.sql:36-59` then copies `role` into `auth.users.raw_user_meta_data`.
- The web console grants access on `userProfile.role === 'ADMIN'` (`Login.jsx:44-54`).
- `admin_verify_seller()` authorizes on the same DB role (`migration_p6_admin_backdoor_hardening.sql:48-56`), so the attacker can approve/reject any KYC application.

This single issue defeats the "seller is only active when `role == 'SELLER' && is_seller_verified`" rule in `AGENTS.md`.

**Fix**
```sql
-- 1) Make the guard enforceable: INVOKER, no owner short-circuit.
CREATE OR REPLACE FUNCTION public.protect_user_security_columns()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY INVOKER SET search_path = public AS $$
BEGIN
  IF auth.role() IN ('authenticated','anon') THEN
    IF NEW.role            IS DISTINCT FROM OLD.role            THEN RAISE EXCEPTION 'role is immutable from clients'; END IF;
    IF NEW.is_verified     IS DISTINCT FROM OLD.is_verified     THEN RAISE EXCEPTION 'is_verified is immutable from clients'; END IF;
    IF NEW.is_seller_verified IS DISTINCT FROM OLD.is_seller_verified THEN RAISE EXCEPTION 'is_seller_verified is immutable from clients'; END IF;
    IF NEW.email           IS DISTINCT FROM OLD.email           THEN RAISE EXCEPTION 'email is immutable from clients'; END IF;
    IF NEW.password_hash   IS DISTINCT FROM OLD.password_hash   THEN RAISE EXCEPTION 'password_hash is immutable from clients'; END IF;
    IF NEW.verification_token IS DISTINCT FROM OLD.verification_token THEN RAISE EXCEPTION 'verification_token is immutable from clients'; END IF;
    IF NEW.is_locked       IS DISTINCT FROM OLD.is_locked OR NEW.lock_until IS DISTINCT FROM OLD.lock_until
       OR NEW.failed_attempts IS DISTINCT FROM OLD.failed_attempts THEN RAISE EXCEPTION 'lockout state is immutable from clients'; END IF;
  END IF;
  RETURN NEW;
END $$;

-- 2) Same for INSERT: force every client-created row to a safe default.
CREATE OR REPLACE FUNCTION public.enforce_default_role_on_insert()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY INVOKER SET search_path = public AS $$
BEGIN
  IF auth.role() IN ('authenticated','anon') THEN
    NEW.role := 'BUYER';
    NEW.is_seller_verified := false;
    NEW.is_verified := false;
    NEW.is_locked := false;
    NEW.failed_attempts := 0;
    NEW.lock_until := NULL;
    NEW.verification_token := NULL;
    NEW.password_hash := 'SUPABASE_AUTH_MANAGED';
  END IF;
  RETURN NEW;
END $$;
```
Also add `CHECK (role IN ('BUYER','SELLER','ADMIN'))` only if the column is plain text, and revoke client UPDATE on `password_hash` via column grants.

**Regression test to add:** an integration test that signs in as a buyer and asserts PATCH `users {role:'ADMIN'}` returns 403/42501.

---

### C2 — RLS is switched off by a checked-in "run this in the SQL editor" script
**Severity:** Critical (conditional — verify live) · **Confidence:** High that the file exists; unknown whether it was executed

**Evidence**
`enable_realtime.sql:24-27`:
```sql
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.inquiries DISABLE ROW LEVEL SECURITY;
```

**Impact if executed**
- The public anon key can `SELECT * FROM users` → `password_hash`, `verification_token` (→ account takeover by verifying someone else's email), `lock_until`, student IDs, contact numbers.
- The anon key can `UPDATE users SET role='ADMIN'` → C1 without even needing an account.
- All chat messages and inquiries become world-readable/writable.

**Corroborating signal:** the email-verification dialog polls `public.users` while the client is signed out (`email_verification_dialog.dart:36-61`). Under the documented RLS policy (`TO authenticated`) that query can never succeed — so this feature only works if RLS is actually disabled. That is itself evidence the script was run.

**Fix:** `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` on all four tables, delete `enable_realtime.sql` from the repo, and replace it with the policy-based realtime setup already present in `comprehensive_rls_policies.sql:253-330`.

---

### C3 — Email verification is not a session-level gate
**Severity:** Critical (business rule) · **Confidence:** High

**Evidence**
- `Profile` has no `isVerified` field (`lib/features/auth/models/profile.dart:4-15`); `_userToProfile` never maps it (`auth_service.dart:37-52`); `getEnrichedProfile` never selects it (`auth_service.dart:56-101`).
- The only enforcement is `AuthController.java:331-338` (`EMAIL_UNVERIFIED` before password check).
- `AuthNotifier.register()` sets state to `data(null)` and never checks verification (`auth_provider.dart:110-140`).
- `AuthService.signUp` calls `signOut()` at the end (`auth_service.dart:335`); if that call fails or is skipped, the Supabase session survives and `main.dart:54-59` navigates into the app.
- The web console never checks `is_verified` (`Login.jsx:19-59`).
- Registration's `public.users` upsert runs as the client (`auth_service.dart:311-320`) and needs `TO authenticated` (`comprehensive_rls_policies.sql:54-57`) — so it only works when Supabase "Confirm email" is **off**. That setting is not documented or asserted anywhere.

**Impact:** an unverified account can hold a fully valid Supabase session (web login, direct API, or a failed sign-out) and use every RLS-permitted feature. The verification email becomes advisory.

**Fix:** add `is_verified` to `Profile`; gate navigation on `profile.isVerified`; enforce `is_verified` in a DB helper used by RLS (`auth.jwt() -> 'user_metadata' ->> 'is_verified'` is not trustworthy — use a `public.current_user_is_verified()` SECURITY DEFINER function reading `public.users`); add the check to the web login; make `signOut()` failure fatal to the registration flow.

---

## 4. High findings

| # | Finding | Evidence | Impact | Fix |
| :- | :--- | :--- | :--- | :--- |
| H1 | Unused public `/auth/register` creates a second identity system | `AuthController.java:38-105`, `SecurityConfig.java:47` | Anyone can pre-register `victim@cit.edu` with their own password. The victim receives a real verification email; clicking it verifies an account the attacker controls. The row has a generated UUID that does not exist in `auth.users`, so the account can never obtain a Supabase session — but it can use the backend JWT on `/orders/**`. Also enables email squatting that permanently blocks the real owner from registering. | Delete the endpoint, or move it behind `ROLE_ADMIN` / service-to-service auth. If retained, create the `auth.users` identity via the Admin API in the same transaction. |
| H2 | Account existence + full name disclosed before password verification | `AuthController.java:307-338`; test asserts it at `AuthControllerLoginTest.java:73-94` | `POST /auth/login` with any password returns `EMAIL_UNVERIFIED` + `email` + `fullName` for registered accounts, and `INVALID_CREDENTIALS` otherwise. That is a clean account-enumeration oracle and a PII leak (full name). The lockout path (`:358-380`) provides a second oracle. | Verify the password first; return a generic 401 for both "bad password" and "unverified", then reveal verification only after a successful password check. Never return the name before authentication. |
| H3 | Lockout is an unauthenticated DoS and fires during outages | `AuthController.java:342-380` | 5 wrong passwords lock any known email for 10 min, repeatable forever. Worse: `authenticateWithSupabase()` returns `null` on timeout/5xx (`:273-277`), which is treated as a bad password and increments `failedAttempts` — a Supabase outage mass-locks every user who retries. | Count lockout per IP + account, not per account alone; do not increment on transport/infra failures (distinguish 401 from 5xx/timeout); add exponential backoff and a CAPTCHA after N failures. |
| H4 | No token revocation — locked/demoted users keep access | `JwtAuthenticationFilter.java:30-55`, `JwtTokenProvider.java:72-91` | The filter validates only the signature. It never re-checks `is_locked`, `is_verified`, deletion, or role changes. A backend JWT stays valid for 24 h after an account is banned; a Supabase access token stays valid ~1 h. `banned_until` blocks new tokens but not existing ones. | Add a `token_version`/`session_epoch` column, include it as a claim, and compare it on each request (cached). Or shorten the backend JWT to 15 min and add a refresh endpoint that re-checks the user row. At minimum, check `is_locked` in the filter. |
| H5 | Sessions break on every deploy and after 24 h | `application.yml:53-55` (`JWT_SECRET:''`), `JwtTokenProvider.java:48-61`, `secure_token_service.dart:47-61` | With no `JWT_SECRET`, a random 256-bit key is generated per process. Every stored backend token becomes invalid on restart/redeploy, and multi-instance deployments reject each other's tokens. There is no refresh endpoint, so after 24 h every order/KYC call that uses `getBearerToken()` (`order_detail_view.dart:97,287,354`, `order_history_view.dart:334,410`, `reserved_orders_sheet.dart:206`, `seller_verification_service.dart:115`) returns 401 with no recovery path. | Require `JWT_SECRET` at startup (fail fast, ≥32 bytes), or drop the custom JWT entirely and accept only Supabase ES256 tokens. Add a refresh flow and refresh the stored token on `onAuthStateChange`. |
| H6 | Verification email is silently not sent, but the UI says it was | `EmailService.java:44-50`; `AuthController.java:136-139`; `auth_service.dart:356-381` | Without `BREVO_API_KEY`, sending is skipped with only a server log. The endpoint still returns 200. The app shows "verification email sent", the user waits for a link that will never arrive, and because `/auth/login` blocks unverified accounts, registration is a dead end. | Return a real failure (503) when the provider is unconfigured or returns an error; surface it in the register UI; add a startup health check for the mail provider. |
| H7 | The verification status poller cannot succeed under RLS | `email_verification_dialog.dart:36-61` | The dialog queries `public.users` by email every 2 s while the client is signed out. The policy is `TO authenticated` (`comprehensive_rls_policies.sql:48-51`), so the query silently returns no rows and the success state never triggers. It only works when RLS is off (see C2). Secondary bugs: the email is not lower-cased before matching, and the query runs forever while the dialog is open. | Poll a public RPC `check_my_verification(token)` (SECURITY DEFINER, rate-limited) or have the backend verification page deep-link back to the app; stop polling after N attempts; lower-case the email. |
| H8 | Resend flow misreports success and invalidates earlier links | `email_verification_dialog.dart:77-116`; `auth_service.dart:356-381`; `AuthController.java:122-139` | `_sendVerificationEmailWithRetry` retries 3× with 2 s sleeps (up to ~51 s of blocking UI) and treats 429 as "retry", then the dialog always shows "New verification email sent!". Each backend call regenerates the token, so an earlier email the user already received becomes invalid. | Honor 429 with a client cooldown and a countdown; surface the specific error; remove the blind retry; do not regenerate the token if one is still valid (or keep a short grace window). |
| H9 | Password reset is likely broken on mobile | `auth_password_sheets.dart:75`; `auth_gate_view.dart:120-141`; `main.dart:48-66` | `resetPasswordForEmail` is called without `redirectTo`, so the link goes to the Supabase Site URL (the web app). The recovery handler lives in `AuthGateView`, which is replaced by the feed as soon as a recovery session exists (`main.dart:54-59`); `Uri.base` fragment detection is web-only. Net effect: no "set new password" screen on Android. | Pass an explicit `redirectTo` deep link; handle the recovery callback in `main.dart` before navigating; add a top-level `/reset-password` route. |
| H10 | Lockout timestamp is parsed in the wrong timezone | `AuthController.java:311-319, 359-368`; `auth_gate_view.dart:52-58, 83-96` | The backend sends `lockUntil` as a UTC `LocalDateTime.toString()` with no `Z`. `DateTime.tryParse` treats it as local and `saveLockoutUntil` persists it. In UTC+8 the stored lock is ~8 h in the future, so after one app restart a 10-minute lock becomes an 8-hour lock. | Send ISO-8601 with `Z` (`Instant`/`OffsetDateTime`), parse with `DateTime.parse(...).toUtc()`, and store UTC. Change the JPA field to `OffsetDateTime`/`Instant`, since the column is `TIMESTAMPTZ`. |
| H11 | Login can "succeed" with no Supabase session | `auth_service.dart:148-191` | Tokens are saved before `setSession`; if `refreshToken` is missing or `setSession` throws, the method still returns a fabricated `Profile` (id from `userData` or `''`). `AuthNotifier.login` then sets a logged-in state, so the app navigates to the feed while every Supabase query runs as `anon` and fails. | Treat a missing/failed session as a login failure; clear tokens and sign out; assert `currentSession != null` before returning. |
| H12 | Any authenticated user can create product listings | `comprehensive_rls_policies.sql:150-164` | `products_insert_seller` only checks `auth.uid() = seller_id`. It does not check `role = 'SELLER'` or `is_seller_verified`. An unverified buyer can POST to `/rest/v1/products` and list items, bypassing KYC entirely. | `WITH CHECK (auth.uid() = seller_id AND EXISTS (SELECT 1 FROM public.users u WHERE u.user_id = auth.uid() AND u.role = 'SELLER' AND u.is_seller_verified))`. Mirror it for `store_profiles`. |
| H13 | Web admin console accepts non-admins into a live session | `Login.jsx:19-59`; `supabase.js:16-24`; `App.jsx:299-335` | A non-admin who signs in successfully gets a real, persisted Supabase session before the role check rejects them; the session is never signed out. The console also bypasses `is_verified` and the backend lockout, and has no MFA. | On non-admin, call `supabase.auth.signOut()` immediately; require `is_verified`; add MFA (Supabase TOTP) for `ADMIN`; move the role check server-side (an `is_admin()` RPC) instead of a client-readable column. |

---

## 5. Medium findings

| # | Finding | Evidence | Impact / Fix |
| :- | :--- | :--- | :--- |
| M1 | Two migrations fight over `users` grants | `migration_p5_user_column_security.sql:17-35` vs `fix_users_select_grant.sql:7-12` | Depending on which ran last: (a) `getEnrichedProfile` selects `student_id, contact, gcash_number` which are **not** in the column grant → PostgREST 42501 → the error is swallowed (`auth_service.dart:99`) and enrichment silently never happens; or (b) full-table SELECT is restored and, with `USING (true)`, every authenticated user can read all users' emails, student IDs, and contacts. Pick one and delete the other. |
| M2 | The RLS script drops **every** policy in `public` | `comprehensive_rls_policies.sql:31-42` | The `DO` block drops all policies schema-wide, then recreates only the ones in that file. Re-running it after P6 removes `"Users can submit own verification"` / `"Users can update own rejected verification"`, re-opening KYC self-approval, and drops the notification policies. Scope the drop to the tables in the file or make it a forward-only migration. |
| M3 | Registration's profile upsert depends on Supabase "Confirm email" being off | `auth_service.dart:294-320`; `comprehensive_rls_policies.sql:54-57` | With confirmations ON, `signUp` returns no session; the `upsert` runs as `anon` and fails with an RLS error after the auth user was already created (orphaned account). Use an `auth.users` `AFTER INSERT` trigger (SECURITY DEFINER) to create the profile instead of a client write. |
| M4 | Unauthenticated Student ID existence check | `auth_service.dart:279-289` | Enumerates registered student IDs; TOCTOU race with the unique constraint; and it may fail outright under M1's column grants, breaking registration. Do it in the signup RPC/trigger with a generic error. |
| M5 | Client lockout is device-global, not account-scoped | `auth_gate_view.dart:47-107, 332-341`; `secure_token_service.dart:114-144` | A lockout from account A blocks account B on the same device for 10 min; failed attempts increment on network errors and even on client-side `FormatException` (bad email syntax), producing false lockouts. Key state by normalized email and only persist server-reported counters. |
| M6 | Public verification-state oracle | `AuthController.java:188-196` | `GET /auth/check-verification?email=` returns `verified: true/false` for any email, confirming registration. Dead code — remove it. |
| M7 | PII in query strings | `auth_service.dart:357-361` | `email` and `fullName` are sent as URL parameters to `/auth/send-verification`, so they land in proxy/access logs. Send a JSON body, and derive the name server-side. |
| M8 | Password policy is 6 characters | `auth_service.dart:265-267`; `auth_register_form.dart:608-616` | No strength, breached-password, or repetition check, despite the "Strict Security Policy" copy. Use a zxcvbn-style check and a 10–12 char minimum; Supabase supports a minimum length setting. |
| M9 | No privacy consent / KYC retention | `auth_register_form.dart:409-418`; `seller_verification_service.dart:21-22, 90-109` | The app collects student ID, college, and ID/selfie images with no consent step and no retention/deletion path, while the comment claims "RA 10173 Zero-Retention". Add an explicit consent checkbox + privacy policy link, and a documented retention window with deletion on rejection/account deletion. |
| M10 | Verification link design | `AuthController.java:80-83, 122-186` | 5-minute lifetime is user-hostile; token is stored plaintext; a GET with the token in the URL leaks via history/referrer; tokens are never invalidated on password change; `/auth/send-verification` can spam any registered address every ~60 s. Store a hash, use POST/one-time codes, extend to 15–30 min, and invalidate on credential change. |
| M11 | Two verification systems can disagree | `auth_service.dart:294-303`; `AuthController.java:331-352` | After clicking the backend link, `users.is_verified` is true but Supabase may still consider the email unconfirmed, so the password grant fails and the BCrypt fallback does not apply (`password_hash = 'SUPABASE_AUTH_MANAGED'`) → "Invalid email or password" forever. Pick one verifier or disable Supabase confirmation explicitly. |
| M12 | Client-visible role comes from a writable row | `auth_service.dart:37-52`; `migration_p4_auth_sync.sql:36-59` | The P4 trigger copies `public.users.role` into `auth.users.raw_user_meta_data`, and the app reads metadata before enrichment. Combined with C1, a self-promoted role is echoed back to the client and shown in the UI. |

---

## 6. Low / UX / accessibility / quality

| # | Finding | Evidence |
| :- | :--- | :--- |
| L1 | Contrast failures: `citGold #F5B041` on white ≈ **1.9:1** (needs 4.5:1) for "Forgot Password?" and "Step 1 of 3"; `citMaroon #800000` on white ≈ **3.95:1** for the "Sign up"/"Sign in" link. | `auth_login_form.dart:100-107`, `auth_register_form.dart:71-79`, `auth_gate_view.dart:658-670`, `theme.dart:9-13` |
| L2 | Sub-minimum tap target: the "Sign up"/"Sign in" link is a `GestureDetector` with 4×2 padding (~22 px tall, below WCAG 2.5.8's 24 px) and has no button semantics. | `auth_gate_view.dart:658-673` |
| L3 | No `autofillHints`, no `textInputAction`, no `onFieldSubmitted`: password managers cannot fill the form and Enter does not submit. | `auth_form_fields.dart:185-192`, `auth_login_form.dart:48-89` |
| L4 | The "Must be at least 6 characters" check icon never updates while typing (no controller listener; only rebuilds on the visibility toggle). | `auth_register_form.dart:619-645` |
| L5 | `setState` after `await _fadeController.reverse()` without a `mounted` check — can throw if the gate is disposed mid-transition. | `auth_gate_view.dart:161-172` |
| L6 | Switching Login ↔ Register keeps the shared password controller populated; after registration the login tab is pre-filled with the new password. | `auth_gate_view.dart:161-172` |
| L7 | Error handling is string matching (`msg.contains('400')`, `'lockout'`, regex on "attempts remaining") — brittle and can mislabel unrelated errors. | `auth_gate_view.dart:316-368` |
| L8 | Each resend calls `_startTimer()` without cancelling the previous periodic timer, so countdowns stack and run fast. | `email_verification_dialog.dart:63-75, 95-103` |
| L9 | Many raw `Color(0xFF...)` literals in auth views (amber/red/blue) instead of `TeknoyTheme` tokens; dark-mode drift risk. | `auth_login_form.dart:118-124, 234-238`, `auth_register_form.dart:208-211` |
| L10 | `AuthGateView` opens a second `onAuthStateChange` listener directly on `Supabase.instance` while `AuthNotifier` already listens. | `auth_gate_view.dart:120-141`, `auth_provider.dart:42-57` |
| L11 | `lastSupabaseError` is shared mutable state on a singleton controller (cross-request log races); the Supabase HTTP client has a connect timeout but no response timeout; a new `HttpClient` is created per login and never closed. | `AuthController.java:211, 253-264` |
| L12 | `ApiConfig.baseUrl` defaults to the production Render URL, so dev builds silently hit prod; `.env.json` and the web `.env` commit project credentials (anon key is public, but there is no environment separation). | `api_config.dart:6-9`, `.env.json:1-5`, `TeknoyCartWeb/TeknoyCart_Web/.env:1-2` |
| L13 | No `Cache-Control: no-store` on the login response that carries access/refresh tokens. | `AuthController.java:411-420` |
| L14 | Analyzer: 0 errors/warnings, 7 infos in the auth scope; `DropdownButtonFormField.value` is deprecated (Flutter 3.33+). | `auth_form_fields.dart:320` |
| L15 | The verification dialog constructs `AuthService()` directly instead of using the provider, bypassing lifecycle disposal. | `email_verification_dialog.dart:81` |
| L16 | No "I've verified — retry login" action in the verification dialog; the user must close it and retype everything. | `email_verification_dialog.dart:373-396` |
| L17 | `Profile.isPendingSeller` is defined but never used; there is no pending-seller banner (an explicit `AGENTS.md` requirement) — pending applicants just see the KYC form again. | `profile.dart:32`, `sell_tab.dart:2199-2209` |

---

## 7. What is genuinely good (keep it)

- Passwords are never stored client-side; the backend uses `BCryptPasswordEncoder(12)` for legacy rows (`SecurityConfig.java:33-36`).
- Tokens use `flutter_secure_storage` with Keystore/Keychain (`secure_token_service.dart:8-15`).
- No `service_role` key exists anywhere in the mobile or web clients (verified repo-wide).
- The KYC bucket is private (`migration_secure_kyc_storage.sql:12`), and the developer-email admin bypass was removed (`migration_p6_admin_backdoor_hardening.sql:1-56`).
- Unknown-email login returns a generic message (`AuthController.java:298-303`) — the enumeration problem is only on the *unverified* and *locked* branches.
- Lockout is mirrored to Supabase `banned_until` (`migration_p4_auth_sync.sql:7-33`).
- 30-minute inactivity auto-logout (`main.dart:97-130`).
- Clear multi-step registration with inline validation, dark mode, and error/empty states.
- CORS is explicitly configured (`SecurityConfig.java:66-77`).
- `flutter test test/auth_test.dart test/auth_login_error_recovery_test.dart` → **24/24 pass**; `flutter analyze lib/features/auth ...` → **0 errors, 0 warnings, 7 infos**.

---

## 8. Verify the database claims (run these)

```sql
-- 1) Is RLS actually on?  Any `false` here = C2.
SELECT relname, relrowsecurity
FROM pg_class
WHERE relnamespace = 'public'::regnamespace
  AND relname IN ('users','chats','messages','inquiries');

-- 2) Who owns the protection triggers, and are they SECURITY DEFINER?
SELECT p.proname, pg_get_userbyid(p.proowner) AS owner, p.prosecdef
FROM pg_proc p
WHERE p.proname IN ('protect_user_security_columns','enforce_default_role_on_insert');

-- 3) The decisive test. Run while signed in as a normal buyer (not as postgres).
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',
  json_build_object('sub', auth.uid(), 'role', 'authenticated')::text, true);
UPDATE public.users SET role = 'ADMIN' WHERE user_id = auth.uid();
-- If this UPDATE succeeds, C1 is confirmed in production.
```

Also confirm which grant migration won:
```sql
SELECT grantee, privilege_type, column_name
FROM information_schema.column_privileges
WHERE table_name = 'users' AND grantee IN ('anon','authenticated')
ORDER BY grantee, column_name;
```
If `student_id`, `contact`, `gcash_number` are absent → `getEnrichedProfile` is silently failing (M1). If the table-level `SELECT` grant is present → PII is exposed (M1/C1).

---

## 9. Prioritized remediation plan

**Phase 0 — before any demo (hours)**
1. Run §8. Re-enable RLS if it is off.
2. Replace both `users` triggers with the SECURITY INVOKER versions (C1).
3. Lock down `products_insert_seller` to verified sellers (H12).
4. Set `JWT_SECRET` (≥32 bytes) and fail startup if missing (H5).
5. Delete `enable_realtime.sql`; mark the DB migrations forward-only (C2, M2).

**Phase 1 — before release (1–2 days)**
6. Remove `/auth/register` or put it behind admin auth (H1).
7. Verify the password before revealing `EMAIL_UNVERIFIED`; remove `fullName` from the pre-auth response (H2).
8. Add `is_verified` to `Profile` and gate navigation; add the check to the web login (C3).
9. Make verification dispatch return errors; surface them in the UI (H6).
10. Replace the polling query with a public RPC or a deep link (H7); fix resend semantics (H8).
11. Add `redirectTo` + a top-level recovery route (H9).
12. Send `lockUntil` as UTC ISO-8601 and parse it as UTC (H10).
13. Fail login when `setSession` does not produce a session (H11).

**Phase 2 — hardening (release + 1 week)**
14. Token revocation (`session_epoch`) and a refresh endpoint (H4).
15. Per-IP + per-account throttling; don't count infra failures (H3).
16. Web logout for rejected users + MFA for admins (H13).
17. Consolidate to one identity/verification system (M3, M11).
18. Privacy consent, KYC retention, and a deletion path (M9).
19. Accessibility pass: contrast, tap targets, autofill (L1–L3).

---

## 10. Test coverage gaps

- No test for a **successful** `/auth/login` (Supabase session + JWT shape + `sanitizedUser` contents).
- No test asserting `setSession` failure, missing tokens, or a null Supabase session.
- No DB-level test for the `users` triggers / RLS (the C1 class of bug is invisible to the current suites).
- No test for the lockout timezone round-trip (`lockUntil` → parse → persist → restore).
- The auth widget tests cover error recovery and lockout UI, not registration step transitions, duplicate email, or the verification dialog.
- `flutter test` runs only against placeholder Supabase credentials, so no test exercises RLS or real PostgREST error codes.

---

## 11. Bottom line

The UI layer is in good shape; the security model is not. The app *looks* like it enforces "verified sellers only" and "verified emails only", but both rules live in code paths that can be bypassed — and the database trigger meant to protect the role column is inert. Fix **C1 + C2 + H12** first: until then, any student with an account can become an admin and list products without KYC.
