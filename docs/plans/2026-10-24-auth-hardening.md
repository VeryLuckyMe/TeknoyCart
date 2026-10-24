# Auth Hardening — Implementation Plan

**Status:** In progress — W0 baseline green; live diagnostic awaiting user run (approved 2026-10-24)
**Date:** 2026-10-24
**Demo target:** within 7 days (by 2026-10-31); correct this if the actual date is earlier
**Source audit:** `AUTH_AUDIT_REPORT.md` (45 findings: 3 critical, 13 high, 12 medium, 17 low)
**Repos:** `TeknoyCart` (Flutter) · `TeknoyCart_Backend` (Spring Boot) · `TeknoyCart_Web` (React)
**Baseline:** The `phase1-delivery` patch series is already merged into `main` (`security/phase1` is an ancestor of `main` in all three repos; 0 commits on the branch are missing from `main`). This plan layers on top and does **not** re-apply that series.
**Skills applied:** `intent-driven-development` (Full Acceptance Brief) · `tdd-workflow` (RED → GREEN per workstream) · `ponytail` (delete dead paths; no new framework or dependency unless proven necessary)

---

## 0. One-line goal

Close the audit's critical and high findings with a forward-only, test-first change set that keeps the demo working: a student can no longer self-promote, unverified accounts can no longer slip through, and sessions survive deploys.

---

## 1. Definition of done

- Every finding in `AUTH_AUDIT_REPORT.md` has a disposition: fixed, accepted with owner/date, or deferred with owner/date. C1–C3 and H1–H13 cannot be deferred without a written risk acceptance.
- A signed-in buyer attempting `PATCH users {role:'ADMIN'}` gets `403`/`42501` and the row is unchanged.
- Anon cannot read sensitive `users` columns; any public seller-card data comes from a narrow view, not the table.
- A buyer cannot insert a product; an approved seller can.
- Signup and password reset enforce 12+ characters (no composition rules); the Supabase dashboard minimum matches.
- Registration requires an explicit consent checkbox that opens the existing Terms/Privacy sheet; consent is UI-only for the demo (documented limitation).
- Realtime chat/presence still works after RLS is re-enabled; if it breaks, policies are fixed before proceeding (no RLS-off fallback).
- `/auth/login` does not reveal the account name before password verification.
- No 24-hour token cliff: a session still works after a backend deploy and after 24 hours.
- Verification email failure is visible; success is only claimed after the provider accepted the message.
- Password reset opens the set-password screen on Android, iOS and web.
- `flutter test` (existing + new), backend tests on JDK 17, and `npm test` pass; `flutter analyze` has 0 errors/warnings (the 80 pre-existing info lints are recorded and must not increase); web lint has 0 errors.
- A live proof of the escalation attempt (user-applied SQL + REST) is attached to the TDD evidence report; there is no staging project.

---

## 2. Facts established (verified, not assumed)

| Fact | Evidence |
| :--- | :--- |
| Three separate git repos, all on `main` | `TeknoyCart`, `TeknoyCart_Backend`, `TeknoyCart_Web` |
| Flutter working tree is dirty | 2 modified generated Windows plugin files + untracked `AUTH_AUDIT_REPORT.md`; one stash exists |
| One Supabase project is shared by all three clients | `chmtvasbhkbrvydbajnd` in mobile `.env.json`, web `.env`, backend `application.yml` |
| No staging project, no Supabase CLI, Docker or `psql` on this machine | `Get-Command` check |
| No CI workflows in any repo | no `.github/workflows` |
| Backend requires Java 17; machine has Java 8 | `pom.xml` `<java.version>17</java.version>`; `java -version` |
| `winget` is available; no JDK 17 or `gh` | `winget --version` works; `gh` missing |
| Deep link scheme exists on both mobile platforms | Android `teknoycart`, iOS `CFBundleURLSchemes: teknoycart` |
| Supabase auth currently uses the implicit flow | `lib/core/supabase_client.dart:45` |
| `/auth/register` is dead code | only `AuthController.java:38`; no mobile or web caller |
| Bearer token prefers the 24 h backend JWT | `secure_token_service.dart:47-61` |
| Backend already validates Supabase ES256 + issuer + JWKS | `JwtTokenProvider.java:194-283` |
| Legacy BCrypt seed users exist | `AuthController.java:349-351` (fallback only for `$2a$` hashes) |
| Web tests cover only CSV utils | `package.json`: `node --test "src/utils/*.test.js"`; only `csvExport.test.js` |
| App version is `1.0.0+1` | `pubspec.yaml` |
| `phase1-delivery` is already merged | `security/phase1` is an ancestor of `main` in all three repos; `git log main..security/phase1` is empty |
| Hardcoded Supabase defaults still ship in mobile | `supabase_client.dart:12-18` has URL/anon-key `defaultValue` despite the comment claiming none (L12) |
| Credential rotation is half-done | `ROTATION-RUNBOOK.md`: A1–A4 signed off; B1 (anon key + JWT secret) still pending |
| No demo date is documented | searched `docs/`, `README.md`, `phase1-delivery/`; none found |
| Web non-admin login still leaves a live session | `Login.jsx` finding H13; the phase1 patch only revalidates on boot |
| P6 trigger guard still has the escalation flaw | `migration_p6_admin_backdoor_hardening.sql:234-235` uses `current_user LIKE 'postgres%'` inside a `SECURITY DEFINER` function |
| Password minimum is 6 in three places | `auth_service.dart:265-267`, `auth_register_form.dart:608-616`, `auth_password_sheets.dart:209` |
| Existing Terms/Privacy copy exists | `profile_tab.dart:716` Terms sheet; `seller_kyc_verification_view.dart:1410` KYC consent checkbox |
| Realtime chat/presence touches the RLS tables | `presence_service.dart`, `chat_service.dart`; `enable_realtime.sql` disabled RLS |
| JDK 17 is installed | Temurin `17.0.20.1` at `C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot`; `mvn test` uses it |
| Baseline tests are green | Flutter 260/260; backend 63/63; web 4/4; web lint 0 errors / 10 warnings; Flutter analyze 0 errors / 0 warnings / 80 pre-existing info lints |
| `getEnrichedProfile` reads own PII columns | `auth_service.dart:58-62` selects `student_id, contact, gcash_number`; these must move to `my_profile` |
| Registration pre-checks Student ID as anon | `auth_service.dart:280-284` queries `users.student_id` before auth; revoking anon SELECT breaks it unless replaced by a narrow RPC |
| `public.users` has no `avatar_url` | no avatar column in the schema; `auth_service.dart:45` reads `user.userMetadata['avatar_url']`; `public_profiles` must join `auth.users` metadata or omit the column |
| Backend migration ledger exists | `DatabaseMigrationRunner` uses `schema_migrations` (V2/V8 constants); `enable_realtime.sql` is a one-off, not in the ledger |

---

## 3. Scope posture (all rounds settled)

**Settled in Round 1**

- Demo-only: no real users, no external installed builds, one Supabase project, no staging. Manual, user-applied SQL is the DB change path (D2 = C).
- Full-scope intent (D3 = C): MFA, privacy/KYC, cross-user PII and password policy are in scope, not automatically deferred.
- Balanced risk (D6 = C): security-first for DB/RBAC; demo-first for the identity refactor.

**Ponytail cuts that stay regardless**

- No migration framework (Flyway/Liquibase), no new auth/state/HTTP package, no admin-console or KYC UI rewrite.
- No visual redesign beyond the auth screen fixes in W6.

**Settled scope (Round 2 + 3).** Before the demo: privacy consent checkbox + 12+ password policy, plus the critical/high fixes and the minimal public-profile view. After the demo, with written acceptance: admin MFA, KYC retention/deletion automation, full order/chat PII redesign, and consent persistence. The minimal public-profile view is not optional: C2 cannot be closed without it if seller cards read `users`.

**Demo target:** within 7 days (by 2026-10-31). Four-account story: buyer purchases, approved seller lists, pending seller sees the banner, admin reviews.

---

## 4. Target architecture (recommended baseline)

```
MOBILE / WEB
  Supabase SDK  ── signUp / signInWithPassword ──▶ Supabase GoTrue
  Supabase SDK  ── access token (auto-refreshed) ─▶ PostgREST (RLS)
  Mobile        ── POST /auth/login ─────────────▶ Spring Boot
                                                   ├─ verify password (Supabase)
                                                   ├─ enforce is_verified + lockout
                                                   └─ return sanitized user + Supabase session
  Mobile/Web    ── Bearer <Supabase access token> ▶ Spring Boot (ES256 + JWKS)
  Admin web     ── Supabase session + role/is_verified check ─▶ admin RPCs
```

**Decisions in this baseline**

1. **Supabase is the identity provider.** The custom HS256 JWT is a demo-only compatibility shim, removed after the demo (D7). `JWT_SECRET` must be non-empty for the demo; set a new random value in Render and never commit it.
2. **Mobile bearer token is the live Supabase session** (`currentSession?.accessToken`); the stored backend JWT is only a fallback during the demo. This removes the refresh cliff (H5) and the half-authenticated state (H11) without a hard cutover before the demo.
3. **The backend remains the login policy gate** so `is_verified` and lockout are enforced before a session is handed to the app.
4. **Email verification stays on the existing backend token flow**, with Supabase "Confirm email" disabled and documented. The provider is live and the four demo accounts exist (D8); pre-verify them and test one real signup. Moving to Supabase-native confirmation remains a post-demo option.
5. **Lockout is server-side only**, per account plus a small per-IP limiter, with UTC timestamps.
6. **Seller signup** writes `role='SELLER'` (never `ADMIN`); the DB forces `is_seller_verified=false`, and the app shows the pending banner (D9).
7. **Consent is UI-only for the demo**: a required checkbox opens the existing Terms/Privacy sheet; no `privacy_accepted_at` column yet (D18, documented limitation).
8. **Password policy is 12+ characters with no composition rules**; the Supabase dashboard minimum is set to 12 (D17).

**Ponytail rationale:** the biggest deletion is the custom token lifecycle. Using the SDK's live session removes `saveTokens`, the refresh-token copy, the 24 h expiry bug and the "fallback profile with no session" path in one move. Keeping the existing verification flow avoids new SMTP wiring and a new auth trigger.

---

## 5. Workstreams

### W0 — Safety net (before any mutation)

- Add a read-only diagnostic SQL script: RLS state, trigger owner + `prosecdef`, policy list, column grants, counts of users / verified / locked / pending KYC, and the current `users` grants.
- Export auth-critical tables (`users`, `products`, `orders`) from the Supabase dashboard. Store the export outside the repo and delete it after the demo. The DB is otherwise disposable (D14).
- Confirm the four demo accounts (buyer, approved seller, pending seller, admin) and that the admin account is current — A4 deleted the old `capstone.team45` credential. Pre-verify all four; store credentials outside git (D16).
- Baseline: `flutter test`, `flutter analyze`, `npm test`, backend tests on JDK 17.
- Install JDK 17: `winget install EclipseAdoptium.Temurin.17.JDK` (verified `winget` is available; no JDK 17 on the machine). Optional: `winget install GitHub.cli` for PR creation; otherwise push branches and use the compare URL.
- Set the Supabase Auth minimum password length to 12 (D17). Set a new random backend `JWT_SECRET` in Render (D7); do not commit it.
- Freeze DB writes during the migration window.

**Exit gate:** diagnostic output reviewed; export recorded; four accounts confirmed; baseline green on JDK 17.

**W0 evidence (2026-10-24)**

- JDK 17: Temurin `17.0.20.1` at `C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot`.
- Flutter: `flutter test` → **260/260 passed**; `flutter analyze` → **0 errors, 0 warnings, 80 info** (exit 1 because info-level lints are fatal by default; use `flutter analyze --no-fatal-infos` for the baseline gate and do not add new issues).
- Backend: `mvn test` on JDK 17 → **63/63 passed**, `BUILD SUCCESS`.
- Web: `npm test` → **4/4 passed**; `npm run lint` → **0 errors, 10 warnings**.
- Diagnostic: `TeknoyCart_Backend/src/main/resources/db/diagnostics/auth_diagnostic_2026_10_24.sql`; read-only; syntax-parsed with `pglast`; **not yet run against the live DB** — the user runs it and pastes the result.
- No DB export yet; no four-account confirmation yet; W0 remains in progress until those land.

---

### W1 — Database integrity (C1, C2, H12, M1, M2)

**Files**

- `TeknoyCart_Backend/src/main/resources/db/migration_auth_hardening_2026_10_24.sql` — forward-only.
- `TeknoyCart_Backend/src/main/resources/db/diagnostics/auth_w1_verify_2026_10_24.sql` - read-only catalog assertions (147 checks after the W0 review; the first run had 144), committed as the first RED checkpoint.
- `TeknoyCart_Backend/src/main/resources/db/rollback_auth_hardening_2026_10_24.sql` — restore previous bodies/policies.
- `TeknoyCart_Backend/src/main/resources/db/README-auth-hardening.md` — apply order + ledger entry.
- Archive the one-off `TeknoyCart/TeknoyCart/enable_realtime.sql` with a warning header. Do **not** move `comprehensive_rls_policies.sql`: `DatabaseMigrationRunner` reads it from the classpath at startup. Add a "superseded; do not re-run" header instead, and apply the new migration after V2/P6.

**Changes**

1. Recreate `protect_user_security_columns` and `enforce_default_role_on_insert` as `SECURITY INVOKER` (the current `SECURITY DEFINER` makes every caller look like `postgres`, which is the C1 escalation). **Keep the `current_user`/`session_user`/`service_role` guard**; it is only safe once the function is INVOKER (DEFINER + guard is the bug, not the guard alone). Allow security-column changes only for the real backend role (`postgres`/`service_role`); block `authenticated` and `anon`. Keep the admin RPC path working and test it (the RPC is DEFINER, so the trigger sees `postgres`). Also guard `token_expires_at` alongside `verification_token`.
1b. Drop the legacy `Admins can manage all verifications` policy on `seller_verifications`: it is `ALL`, role `public`, `USING (true)`, so it ORs past the user PENDING/REJECTED policies and still allows self-approval to `APPROVED`. Keep the second admin policy (`Admins can view and manage all verifications`) because it carries the ADMIN/service_role predicate, and keep the two user policies. The admin RPC remains the approval path. W0 C04 exposed this; W1 P20/P21 did not catch it, so P22 now asserts no `ALL`/public/`USING(true)` policy exists.
2. INSERT trigger: allow `BUYER` or `SELLER` only (never `ADMIN`); force `email` from the JWT (`auth.jwt()->>'email'` or `auth.users.email`), `is_verified=false`, `is_seller_verified=false`, lockout defaults, `password_hash='SUPABASE_AUTH_MANAGED'`, `verification_token=NULL`, `token_expires_at=NULL`; reject a missing/mismatched email.
3. UPDATE trigger: block changes to `role`, `is_verified`, `is_seller_verified`, `email`, `password_hash`, `verification_token`, `token_expires_at`, `is_locked`, `lock_until`, `failed_attempts` from `anon`/`authenticated`; verify the backend (JDBC) and the admin RPC can still make their intended changes.
4. `ENABLE ROW LEVEL SECURITY` on `users`, `chats`, `messages`, `inquiries` (idempotent; the live DB already reports RLS on and the W1 run confirms it). **Do not recreate the realtime publication**: the live publication already contains `chats`/`messages` and excludes `users` (V50-V52 GREEN). Leave it untouched unless the live catalog changes; the old `enable_realtime.sql` stays archived with a warning.
5. `products_insert_seller` and `products_update_seller` require a real seller check — `EXISTS (SELECT 1 FROM public.users WHERE user_id = auth.uid() AND role='SELLER' AND is_seller_verified)` in both `USING` and `WITH CHECK`, not just `auth.uid() = seller_id`. After the parent fix, re-check the child-table policies (`product_images`, `product_variants`, `inventory`) because they currently rely on product ownership; they should be safe once a buyer cannot create a product, but verify. Allow a pending seller to create a draft `store_profiles` row before approval so the KYC/store setup flow still works; keep products/orders gated.
6. **PII/grant design (precise).** Revoke all privileges on `public.users` from `anon`; revoke table-level `SELECT`/`INSERT`/`UPDATE`/`DELETE` from `authenticated`. Grant `authenticated` only the public columns it actually reads (`user_id`, `full_name`, `role`, `is_seller_verified`, `last_seen_at`); grant column `INSERT` only for `user_id`, `full_name`, `role`, `student_id` (if present), `seller_type` (if present); grant column `UPDATE` only for `full_name`, `contact`, `gcash_number`, `last_seen_at` (if present) on its own row. Do not grant `UPDATE` on `student_id` unless the profile edit actually needs it. The existing `users_update_own_profile` RLS policy enforces own-row, and the trigger blocks security columns. Do **not** grant `email`, `password_hash`, `verification_token`, `is_verified`, `is_locked`, `lock_until` or `failed_attempts` on the base table to `anon`/`authenticated`.
   - `my_profile` view: owner-run (`security_invoker=false`), `WHERE user_id = auth.uid()`, explicit safe columns only — include `user_id, full_name, email, role, is_verified, is_seller_verified, student_id, contact, gcash_number, seller_type, last_seen_at, created_at` **when the live table has them**; do not invent columns (`department`/`avatar_url` live in auth metadata unless the live table has them). `GRANT SELECT TO authenticated`. Never select `password_hash`, `verification_token`, `is_locked`, `lock_until` or `failed_attempts`. Use it in `getEnrichedProfile` and the web admin self-check.
   - `public_profiles` view: owner-run, `user_id, full_name, avatar_url, is_seller_verified, last_seen_at`; because `public.users` has no `avatar_url`, source it from `auth.users.raw_user_meta_data->>'avatar_url'` (or omit it and keep the mobile auth-metadata fallback). `GRANT SELECT TO anon, authenticated`. Switch `seller_storefront_view.dart`, `inbox_view.dart`, `order_history_view.dart`, and `reserved_orders_sheet.dart` to it; `presence_service.isUserOnline` reads `public_profiles.last_seen_at`.
   - `store_profiles`: revoke **table-level** grants from `anon`/`authenticated`, then grant safe column `SELECT` for the public storefront fields (`store_id`, `seller_id`, `store_name`, `description`, `banner_url`, `usual_active_hours`, `preferred_meetup_spots`, `created_at`) and own-row column `INSERT`/`UPDATE` (including `contact_number`) so the existing PostgREST embeds and the pending-seller setup keep working. Do **not** grant `SELECT` on `contact_number` to `anon`/`authenticated`; expose the owner's full row through `my_store_profile` (owner-run, `WHERE seller_id = auth.uid()`, `GRANT SELECT TO authenticated`) and a safe `public_store_profiles` view (owner-run, store/public fields only, no phone/address/contact/gcash, `GRANT SELECT TO anon, authenticated`) for new code. This is a deliberate ponytail deviation from revoking *all* direct grants: column grants preserve the existing feed/storefront joins without a risky query rewrite. The W1 verify checks table-level SELECT = false and sensitive-column SELECT = 0 (V40-V42).
   - Registration pre-check: replace `users.select('user_id').eq('student_id', ...)` (runs as anon) with a narrow `SECURITY DEFINER` RPC `is_student_id_available(text) RETURNS boolean` granted to `anon, authenticated`, or delete the pre-check and rely on the unique constraint. Never grant anon SELECT on `student_id`.
   - Signup: change the `users.upsert` to `insert` (or `upsert` with `ignoreDuplicates`) so an existing row does not trigger the update guard on `role`/`is_verified`; the insert trigger forces the email/flags/role.
   - Admin console: `Moderation.jsx` currently selects `email`/`student_id` for all users. Replace that query with an admin-only `admin_kyc_queue` view (owner-run; `WHERE EXISTS (SELECT 1 FROM users WHERE user_id = auth.uid() AND role='ADMIN' AND is_verified = true AND is_locked = false)`; returns the latest KYC row plus email/student_id) granted to `authenticated`; non-admins see no rows. Do not grant those columns on the base table. The admin self-check must use `my_profile` in the web login, not the base table.
   - Accepted demo degradation: `chat_service.dart:602-609` reads the seller's `gcash_number` for the auto-reply assistant. Do not grant `gcash_number` broadly; the assistant omits that detail if the read is denied. The full counterparty payment-hint RPC stays post-demo (D12).
   - Full order/chat counterparty contact redesign is post-demo (D12).
7. Reuse the backend's existing `schema_migrations` ledger (do not create a second one); record `V9__auth_hardening` as the manual version. The old root SQL files are archived or marked, not deleted.
8. Re-enable RLS with participant policies on `chats`, `messages` and `inquiries`; verify the existing policies and add missing ones. Do not leave RLS off. Immediately run the two-device Realtime chat/presence smoke test; if it breaks, fix the policies before proceeding (D19).

**TDD (RED → GREEN)**

1. The verification SQL is written at `TeknoyCart_Backend/src/main/resources/db/diagnostics/auth_w1_verify_2026_10_24.sql` and committed as the first RED checkpoint. The first user run (144 checks) exported `AUTH W1.csv`: **144 checks, 99 check failures (100 FAIL rows including `ZZ_SUMMARY`)**. Four of those were test-spec errors caught in review (the trigger guard is correct once the function is INVOKER): T03/T04/T22/T23 now expect the guard `true`, and V42 counts sensitive `SELECT` grants only. The W0 review added three checks: P22 (legacy `seller_verifications` ALL/public/`USING(true)` policy), T14 (protect guards `token_expires_at`), and T34 (insert clears `token_expires_at`). The script is now **147 checks**; the current pre-migration DB is expected to fail **98** of them (95 after the guard correction + 3 new). The agent has no DB credentials.
2. The user applies the migration in the SQL editor.
3. The user re-runs the verification — it must **pass** (GREEN).
4. Run the two-device Realtime smoke test: buyer ↔ seller chat + presence. Record the result; a broken subscription blocks the migration.
5. The assertion script is committed; commit the migration separately after GREEN.

**W1 RED evidence (2026-10-24, live project `chmtvasbhkrvydbajnd`)**

- Raw export: 145 rows (144 checks + summary); 99 check failures. The current 147-check script is expected to fail 98 checks on the pre-migration DB (95 after the guard correction + 3 new).
- Confirmed RED: table-level `SELECT`/`INSERT`/`UPDATE`/`DELETE` on `users` for `anon`/`authenticated` (G01-G08); `anon` can read `users` (G30-G32); sensitive `users` columns readable/insertable/updatable (G14-G23, G45-G52, G64-G73); missing `my_profile`/`public_profiles`/`admin_kyc_queue` (V01-V26); missing `is_student_id_available`/helper RPCs (V30-V34); missing store views (V70-V80); `store_profiles` table-level SELECT + 8 sensitive grants (V40-V42); `products_insert_seller`/`products_update_seller` only check `auth.uid() = seller_id` (P10-P11); both trigger functions are `SECURITY DEFINER` (T02/T21); `protect_user_security_columns` does not guard `password_hash` or `token_expires_at` (T09/T14); `enforce_default_role_on_insert` lacks `SELLER`, JWT email, `password_hash`, `is_verified`, `verification_token`, `token_expires_at`, `failed_attempts`, and `lock_until` (T25, T27-T29, T31-T34); no `V9__auth_hardening` ledger row (V60).
- **Critical W0 C04 finding (not caught by P20/P21):** `seller_verifications` still has `Admins can manage all verifications` with `cmd=ALL`, role `public`, `USING(true)`. Permissive policies OR together, so this lets any client update any verification row to `APPROVED`; the user-only PENDING/REJECTED policies do not protect it. P22 is RED. W1 must drop that policy; keep `Admins can view and manage all verifications` (ADMIN/service_role predicate).
- Confirmed GREEN already (do not re-apply): RLS is enabled on `users`, `chats`, `messages`, `inquiries` (R01-R04); the Realtime publication already contains `chats`/`messages` and excludes `users` (V50-V52); the `seller_verifications` user insert/update policies themselves require PENDING/REJECTED (P20-P21), but the broad ALL policy above defeats them; the 3-arg `admin_verify_seller` exists with no 2-arg overload or hardcoded email (P30-P32); the `users` insert/update policies exist with `auth.uid() = user_id` (P01-P03); both triggers are enabled (T40-T41).
- Contract correction: the guard itself is not the bug. `SECURITY DEFINER` + guard is C1; the end state is `SECURITY INVOKER` + guard present. The test now asserts that explicitly.
- App-side coupling to schedule with the SQL apply: signup pre-check → `is_student_id_available`; signup `upsert` → `ignoreDuplicates` safe-column insert; `getEnrichedProfile` → `my_profile`; email dialog → `my_profile.is_verified`; order-history `contact` and reserved-orders `email` → remove/fallback (post-demo counterparty RPC); `matchingStoresProvider` `is_verified` → `is_seller_verified`; web `Login.jsx` → `my_profile`; web `Moderation.jsx` → `admin_kyc_queue`.
- W0 CSV received: 21 rows. Confirmed exact `users` columns/constraints, 2 admins (both verified/unlocked), 12 sellers (2 verified), 17 buyers, 35 auth / 31 public users, 8 auth-without-profile, 4 public-without-auth, 6 verification rows. The migration no longer needs defensive `ADD COLUMN` guesses for `users`. Still needed before applying: the three-table export outside the repo, confirmation of the four demo credentials (especially which admin replaces the deleted `capstone.team45`), and the Supabase minimum password length set to 12.

**Rollback:** the user runs the down script inside a transaction; restore the W0 export if any assertion fails after apply. The down script restores the previous realtime policies; only restore "RLS off" as an emergency, with a written risk acceptance.

**Caveat:** the Supabase SQL editor runs as `postgres` and bypasses RLS. The catalog verification script is necessary but not sufficient; the **live escalation proof** must use `SET LOCAL ROLE authenticated` + JWT claims, or a real test user through PostgREST, and a real mobile session. The Realtime smoke test also uses real mobile sessions, not the SQL editor.

---

### W2 — Identity and session (H1, H4, H5, H11, H13)

**Direction (D7 settled):** Supabase token is primary now; HS256 stays only as a demo fallback. Demo-only means there are no external builds, so the fallback is removed immediately after the demo.

**Changes**

- `secure_token_service.dart`: `getBearerToken()` returns the live `currentSession?.accessToken` first; storage is only a last-resort fallback. Stop writing the backend/access/refresh copies.
- `supabase_client.dart`: remove the hardcoded URL/anon-key `defaultValue` (L12) and require `--dart-define` at build time; update the run commands/README. Coordinate with the pending B1 rotation.
- `auth_service.dart`:
  - `signIn`: after `setSession`, assert `currentSession != null`; if not, clear tokens and throw.
  - `signUp`: if `response.session == null`, fail with a clear "Supabase email confirmation must be disabled" error and a doc link.
  - `getEnrichedProfile`: select only granted columns; do not silently swallow permission errors.
- `AuthController`: delete `/auth/register` and its store/JPA creation path. Stop minting new custom JWTs; return the Supabase session only. Keep HS256 validation for existing demo tokens, then remove it after the demo.
- `JwtAuthenticationFilter`: after signature validation, load `is_locked` / `is_verified` (60 s cache) and reject locked, unverified or deleted users.
- `JwtTokenProvider`: keep HS256 for the demo window only; require `JWT_SECRET` (fail startup if empty), shorten to 1 h, and source the JWKS/issuer from `SUPABASE_URL` instead of hardcoded project defaults. Remove the HS256 path and `/auth/register` after the demo.
- Web `Login.jsx`: after sign-in, read `role` and `is_verified` from `my_profile` (not the base `users` table) for the caller; if not `ADMIN` or not verified, `await supabase.auth.signOut()` and show a generic error. Use the Supabase auth user email for display; the base table no longer grants `email`.

**TDD**

- Flutter: bearer token comes from the live session; no session → login fails; no backend token write; no hardcoded URL/key.
- Backend: `/auth/register` → 404; filter rejects locked/unverified; ES256 accepted; HS256 accepted only during the demo window.
- Web: extract `canEnterAdminConsole(user)` and test it with `node --test`.

---

### W3 — Login policy (H2, H3, H10)

**Changes**

- `AuthController.login`: verify the password **first**, then check `is_verified`; return `EMAIL_UNVERIFIED` only after a correct password; remove `fullName` from the response.
- Lockout: increment only on genuine credential failures (Supabase 400/401 or BCrypt mismatch), never on timeout/5xx/unconfigured. Add a small per-IP limiter. Return the same counter shape for unknown emails (synthetic, per IP/email) so the counter is not an oracle.
- Timestamps: `Instant`/`OffsetDateTime`, ISO-8601 with `Z`; JPA field becomes `Instant`. Client parses `.toUtc()` and stores UTC.
- `send-verification` takes a JSON body (no email/name in the query string); `check-verification` is removed.

**TDD**

- Backend MockMvc: wrong password + unverified → generic 401, no name; correct password + unverified → 403 with email only; Supabase 5xx does not increment; 5 failures → locked; unknown email also reaches the locked shape; `lockUntil` ends with `Z`.
- Flutter unit: UTC parse/restore; local lockout no longer global.

---

### W3b — Signup policy and consent (M8, M9)

**Settled (D17/D18)**

- Password: 12+ characters, no composition rules. Apply in `auth_service.dart`, `auth_register_form.dart`, `auth_password_sheets.dart`; set the Supabase dashboard minimum to 12. Existing demo logins keep working.
- Consent: explicit checkbox on the registration final step; opens the existing Terms/Privacy sheet. No DB persistence for the demo (`privacy_accepted_at` is post-demo); document this limitation. Reuse/extract the existing copy instead of duplicating it.

**Changes**

- `auth_service.dart`: replace the 6-char check with 12; same error copy.
- `auth_service.dart` signup: replace the anon `users.student_id` pre-check with the `is_student_id_available` RPC (or remove it); change `users.upsert` to `insert`/`ignoreDuplicates`; keep the Supabase session non-null assertion (W2).
- `auth_service.dart` profile: `getEnrichedProfile` reads own PII from `my_profile`, not the base `users` table.
- `auth_register_form.dart`: validation + indicator + copy to 12; add `_acceptedTerms`; disable submit until checked; link opens the shared terms sheet.
- `auth_password_sheets.dart`: reset password 12.
- Extract the Terms sheet from `profile_tab.dart` into a shared widget (or a small `PrivacyConsentSheet`) so registration and profile use one source of truth.
- Supabase dashboard: Auth → Providers → Email → minimum password length 12. Enable leaked-password protection if the plan supports it.

**TDD**

- Unit: 6/11 chars rejected; 12 accepted; no composition requirement.
- Widget: consent unchecked → submit disabled; checked → proceeds; sheet opens; reset sheet rejects 11 chars.
- Update existing auth tests that use short passwords.

---

### W4 — Verification (H6, H7, H8, M11)

**Precondition (D8 settled):** the backend email provider is live and the four demo accounts exist. Pre-verify the accounts so the demo never depends on a live email; test one real signup end-to-end. Keep the verification gate; do not add a general bypass.

**Changes**

- `EmailService` / `AuthController`: return 503 when Brevo is unconfigured or rejects the send; log the provider response.
- `auth_service.dart`: no blind 3× retry; return a result and surface 429/503.
- `email_verification_dialog.dart`: remove the 2 s `users` poll. Add an "I've verified — continue" action that retries login. One timer only; cancel before restart; 60 s resend cooldown; show expiry.
- Token: 15 min lifetime, reuse the same token on resend until expiry, SHA-256 hash at rest, invalidate on password change.
- Document the required Supabase setting ("Confirm email" off). Post-demo option: `auth.users` trigger + Supabase-native confirmation, then delete this flow.

**TDD**

- Backend: email failure → 503; resend inside cooldown → 429; token reuse; expired token → 410; verify sets `is_verified`.
- Flutter widget: no poller; "I've verified" calls login; timers do not stack.

---

### W5 — Password reset (H9)

**Changes**

- `SupabaseConfig.initialize`: `AuthFlowType.pkce`.
- `auth_password_sheets.dart`: `resetPasswordForEmail(email, redirectTo: 'teknoycart://login-callback')`.
- `main.dart`: detect the recovery session/callback **before** the auth-state router and show a top-level `ResetPasswordView`; after update, sign out and return to login.
- Supabase dashboard: add `teknoycart://login-callback` to the redirect allowlist.

**TDD**

- Flutter widget: recovery state shows the reset view; update calls `updateUser`; expired link shows an error.
- Manual: Android, iOS and web deep link.

---

### W6 — UI and accessibility (L1–L3, L6, L8, L17)

- Links on light surfaces use `citMaroon` (≥ 4.5:1); gold stays on maroon/dark surfaces. Step labels use body/muted ink.
- "Sign up"/"Sign in" becomes a `TextButton`/`InkWell` with a ≥ 48 px target and button semantics.
- Inputs get `autofillHints`, `textInputAction` and `onFieldSubmitted`.
- Password-length indicator uses `ValueListenableBuilder` on the controller.
- Tab switch clears password + confirm.
- Timers: cancel before restart; `mounted` checks after awaits.
- Pending seller: show the `isPendingSeller` banner on the Sell tab; keep the KYC view.
- Replace raw auth-view hex colors with theme tokens where a token exists.

**TDD:** widget tests for the indicator, tab clear, timer cancel and pending banner; manual contrast check.

---

### W7 — Evidence and CI

- `docs/plans/2026-10-24-auth-hardening.tdd.md` with the RED/GREEN evidence table, the per-finding disposition, and the Realtime smoke-test result.
- One minimal GitHub Actions workflow per repo (D4 = A): Flutter test + analyze; backend `mvn test` on JDK 17; web `npm test` + lint. Trigger on PR and `main`.
- Live proof script for the five security proofs (below), run with real demo accounts; no staging project.
- Demo-day runbook (Section 14) checked one day before the demo.

---

## 6. Acceptance criteria (Full Brief)

| ID | Scenario → action | Expected | Must not | Verification | Priority |
| :--- | :--- | :--- | :--- | :--- | :--- |
| AC-001 | Signed-in buyer → `PATCH users {role:'ADMIN'}` | `403`/`42501`, row unchanged | Any security column changes | User-run SQL assertion + REST test on the live project | Required |
| AC-002 | Anon → `SELECT` sensitive `users` columns; anon → public profile view | Sensitive columns denied; only safe public fields exposed | Email/phone/token leak | SQL assertion + anon REST call | Required |
| AC-003 | Unverified user → app login / web login | No session, generic message | Entry to feed or admin console | Backend test + Flutter widget test + manual | Required |
| AC-004 | Login with wrong password on a known email | Generic 401, no name/role/verification state | `fullName` or verification state before password | MockMvc | Required |
| AC-005 | Buyer → insert product; approved seller → insert product | Buyer denied; seller allowed | Buyer listing without KYC | SQL assertion + REST test | Required |
| AC-006 | Backend redeploy, then use an existing session; wait > 24 h | API calls still succeed | 401 cliff | Manual + unit test on token source | Required |
| AC-007 | 5 failures; Supabase 5xx; unknown email 5× | Lock after 5 real failures; no lock on 5xx; same shape for unknown | Enumeration or outage lockout | MockMvc with mocked Supabase | Required |
| AC-008 | Brevo missing/rejects → register/send | 503 surfaced in UI | "Email sent" on failure | Backend + widget test | Required |
| AC-009 | Verify email → return to app | Login succeeds; dialog does not poll | Background `users` polling | Widget test + manual | Required |
| AC-010 | Forgot password → email link on Android/iOS/web | Set-password screen opens | Link landing on web only | Manual device test | Required |
| AC-011 | Non-admin web login | Signed out, generic error | Live session left behind | Manual + pure-function test | Required |
| AC-012 | `POST /auth/register` | `404` | Second identity path | MockMvc | Required |
| AC-013 | Secret scan of the diff | No new secret/anon key committed | New credential in git | `git diff` review | Required |
| AC-014 | Full suite | Existing + new tests pass, analyzer clean | Regressions | `flutter test`, `mvn test`, `npm test` | Required |
| AC-015 | Run rollback script inside a transaction on the live project (user-run) | Previous behavior restored | Unrecoverable DB state | User-run SQL + export restore | Important |
| AC-016 | Keyboard/screen-reader pass on auth screens | Labels, focus order, 48 px targets, ≥ 4.5:1 link contrast | Unlabeled controls | Manual a11y review | Important |
| AC-017 | Every audit finding | Has a disposition (fixed/accepted/deferred + owner/date) | Unlisted finding | `AUTH_AUDIT_REPORT.md` cross-check | Required |
| AC-018 | Signup/reset with 11 chars; then 12 chars | 11 rejected, 12 accepted; no composition rule | Old 6-char policy | Unit + widget tests | Required |
| AC-019 | Register without consent; with consent | Submit disabled until checked; sheet opens; with consent proceeds | Silent consent | Widget test | Required |
| AC-020 | Re-enable RLS, then send chat + presence between buyer/seller | Realtime still delivers; policies deny non-participants | RLS off or broken chat | Two-device manual test + SQL participant check | Required |
| AC-021 | Four demo accounts | Buyer, approved seller, pending seller, admin all pre-verified/seeded; admin is current | Missing/old admin credential | Manual pre-demo check | Required |
| AC-022 | Buyer opens seller storefront and inbox after RLS/grants | Seller `full_name` renders; no email/phone exposed | Silent "Wildcat Student" fallback or PII leak | Manual + REST test with buyer token | Required |

---

## 7. TDD evidence plan

| Workstream | RED artifact (before code) | GREEN evidence | Checkpoint |
| :--- | :--- | :--- | :--- |
| W1 | `diagnostics/auth_w1_verify_2026_10_24.sql` fails on current DB (user-pasted output) | Same script passes after migration | `test(auth): add read-only W1 security verification` → `fix(db): enforce auth invariants` |
| W1 realtime | Baseline: RLS off, chat works; after RLS on, chat must still work | Two-device chat + presence pass with participant policies | `test(db): pin realtime RLS policies` → `fix(db): ...` |
| W2 | Flutter test: bearer token must be the live session (fails today); backend test: `/auth/register` must 404 | Both pass | `test(auth): pin token source and remove legacy registration` → `fix(auth): ...` |
| W3 | MockMvc: password-first ordering + UTC `Z` (fails today) | Pass | `test(auth): pin login ordering and UTC lockout` → `fix(auth): ...` |
| W3b | Unit/widget: 11-char reject, 12-char accept, consent required | Pass | `test(auth): pin password length and consent` → `fix(auth): ...` |
| W4 | MockMvc/widget: email failure → 503, no poller | Pass | `test(auth): pin verification failure semantics` → `fix(auth): ...` |
| W5 | Widget: recovery route | Pass | `test(auth): pin recovery deep link` → `fix(auth): ...` |
| W6 | Widget: indicator, tab clear, timer cancel, pending banner | Pass | `test(ui): pin auth a11y regressions` → `fix(ui): ...` |

Per `tdd-workflow`: one commit for the failing test (RED validated), one for the minimal fix (GREEN validated), optional refactor commit. The final evidence report goes in `docs/plans/2026-10-24-auth-hardening.tdd.md`.

---

## 8. Sequencing and gates

**Phase 0 — stop the bleeding (target: 2026-10-25 → 2026-10-27, gated by the user's SQL runs)**

1. W0 diagnostic + export.
2. W1 migration + verification (C1, C2, H12).
3. W3 password-first + no-name response (H2), deploy backend.
4. Web: sign out non-admins + `is_verified` check (H13).

**Gate 0:** AC-001, AC-002, AC-004, AC-005, AC-011 pass on the live project.

**Phase 1 — release-ready (target: 2026-10-27 → 2026-10-30)**

5. W2 identity/session (Supabase-primary tokens, delete `/auth/register`, filter lock check).
6. W3 lockout + UTC.
7. W3b password policy + consent.
8. W4 verification.
9. W5 reset.
10. W6 L1–L3, L6, L8, L17.
11. W7 evidence + CI.

**Gate 1:** AC-003, AC-006–AC-022 pass. Demo buffer: 2026-10-31.

**Phase 2 — hardening (post-demo, accepted in D15)**

- M1 full order/chat counterparty RPC (the minimal public-profile view is already in W1), M9 consent persistence + KYC retention/deletion automation, admin MFA, optional Supabase-native confirmation, B1 full rotation (anon key + JWT secret), remove HS256 and the legacy `password_hash` path.

---

## 9. Rollout order (why)

1. **DB first** — backward compatible; narrows the attack surface without changing the client contract. Immediately test Realtime chat/presence after RLS is re-enabled; fix policies before moving on.
2. **Backend** — accepts Supabase tokens (already does) and keeps HS256 only during the demo window.
3. **Web** — sign-out and `is_verified` enforcement.
4. **Mobile** — live-session bearer, unverified gate, reset flow.
5. **Cleanup** — remove HS256, `/auth/register`, legacy storage writes.

Demo-only means there are no external installed builds. Keep HS256 only as the demo fallback, then remove it in the post-demo cleanup.

---

## 10. Rollback

- **DB:** run the down script in a transaction; if an assertion fails after apply, restore the W0 export. The down script restores the previous realtime policies; only restore "RLS off" as an emergency, with a written risk acceptance.
- **Backend/web:** redeploy the previous Render/Vercel build.
- **Mobile:** demo devices only; reinstall the previous build if needed. The compatibility window exists for demo safety, not for external users.

---

## 11. Verification commands

```powershell
cd TeknoyCart/TeknoyCart
flutter test
flutter analyze

cd TeknoyCart_Backend
# after: winget install EclipseAdoptium.Temurin.17.JDK
# open a new shell and verify: java -version  (must be 17)
mvn test

cd TeknoyCartWeb/TeknoyCart_Web
npm test
npm run lint
```

SQL checks run in the Supabase SQL editor with `diagnostics/auth_w1_verify_2026_10_24.sql`; REST checks use a test buyer + anon key and expect `42501`/`403`. Manual: two-device chat/presence after RLS; Supabase dashboard minimum password length = 12.

---

## 12. Decisions

### Settled in Round 1

| ID | Decision | Answer |
| :--- | :--- | :--- |
| D1 | Milestone / audience | Demo-only; target by 2026-10-31 (D13). |
| D2 | DB change path | C: read-only diagnostic + forward-only SQL; user applies manually and verifies. No staging. |
| D3 | Scope boundary | C: everything is in scope. Before-demo subset settled in D15. |
| D4 | Toolchain / proof | A: install JDK 17; add minimal GitHub Actions per repo; require a live escalation proof. |
| D5 | Git workflow | Yes: one branch per repo, PRs into `main`; leave generated Windows files and the existing stash alone; commit docs/baseline separately. |
| D6 | Risk posture | C: balanced — security-first for DB/RBAC; demo-first for the identity refactor. |

### Settled in Round 2

| ID | Decision | Answer |
| :--- | :--- | :--- |
| D7 | Identity | Supabase primary + HS256 fallback through the demo; remove after. |
| D8 | Verification/email | Provider live + four accounts exist; keep the gate; pre-verify; test one real signup. |
| D9 | Seller signup | `SELLER` pending + banner. |
| D10 | Admin MFA | Post-demo. |
| D11 | Privacy/KYC retention | Consent checkbox + policy link before demo; persistence/retention post-demo. |
| D12 | Cross-user PII | Minimal public-profile view before demo; full order/chat RPC post-demo. |
| D13 | Demo date/story | Within 7 days (by 2026-10-31); four-account flow. |
| D14 | DB safety | Export first, then disposable. |
| D15 | Before-demo scope | Privacy consent + password policy only; MFA/KYC retention/full PII post-demo. |
| D16 | Demo accounts | Four accounts exist; pre-verify; admin current. |

### Settled in Round 3

| ID | Decision | Answer |
| :--- | :--- | :--- |
| D17 | Password policy | 12+ chars, no composition; Supabase min 12. |
| D18 | Consent persistence | UI checkbox + existing Terms/Privacy sheet; no DB persistence for the demo. |
| D19 | Realtime fallback | Fix policies + test chat/presence; do not leave RLS off. |

**No open decisions.** Awaiting the explicit go-ahead in Section 15.

---

## 13. Revision log

| Rev | Date | Change |
| :--- | :--- | :--- |
| 0.1 | 2026-10-24 | Initial draft from `AUTH_AUDIT_REPORT.md`; Round 1 pending |
| 0.2 | 2026-10-24 | Round 1 settled (D1–D6); phase1 baseline correction; manual SQL path; JDK 17/CI; scope reconciliation queued for Round 2 |
| 0.3 | 2026-10-24 | Round 2 + 3 settled (D7–D19); demo target 2026-10-31; password/consent/realtime scope; plan ready for go-ahead |

---

## 14. Demo-day runbook (target 2026-10-31)

**T-1 day**

- Confirm four accounts: buyer, approved seller, pending seller, admin; all pre-verified; the admin is current (not the deleted `capstone.team45` credential).
- Run the verification SQL; all rows PASS.
- Export `users`, `products`, `orders` outside the repo.
- Two-device Realtime test: buyer ↔ seller chat + presence.
- Build mobile with `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` (no hardcoded fallback).
- Web admin login: non-admin → signed out; admin → dashboard.

**Demo flow (10 minutes)**

1. Buyer logs in, browses, purchases.
2. Approved seller logs in, lists a product, sees incoming orders.
3. Pending seller logs in, sees the pending banner, cannot list.
4. Admin logs in, verifies the pending seller.
5. Optional proof: buyer attempts `PATCH users {role:'ADMIN'}` → denied; row unchanged.
6. Optional proof: anon REST `users` sensitive column → denied; public profile view only.

**After the demo**

- Remove HS256, `/auth/register`, legacy token storage.
- Rotate B1 (anon key + JWT secret) if not already done.
- Persist consent; add KYC retention/deletion, MFA, and the full PII RPC.

---

## 15. Shared understanding (confirm before edit)

**I will**

- Work in one branch per repo (`fix/auth-hardening`), PR into `main`, no direct pushes.
- Apply DB changes only through user-run SQL in the Supabase SQL editor; no direct DB access.
- Install JDK 17 and add minimal CI; run the existing tests + new tests.
- Fix C1–C3/H1–H13, add the minimal public-profile view, 12+ password policy, consent checkbox, and Realtime RLS policies.
- Defer MFA, KYC retention/deletion automation, full order/chat PII RPC, and consent persistence to post-demo with written acceptance.

**I will not**

- Re-apply the `phase1-delivery` patch series (already merged).
- Disable the verification gate or leave RLS off on chats/messages.
- Commit credentials, exports, or generated Windows files.
- Change the visual design beyond the auth a11y fixes.

Approved on 2026-10-24. W0 is in progress; the next stop is after the live diagnostic output is reviewed and the first RED verification test is written (before any migration is applied).

---

## Appendix A — Finding disposition (completed in W7)

| Severity | Count | Primary workstream | Remaining / accepted |
| :--- | :--- | :--- | :--- |
| Critical | 3 | W1 (C1, C2), W2/W3/W4 (C3) | none without written risk acceptance |
| High | 13 | W1–W5 | any deferred item needs owner/date |
| Medium | 12 | W1, W3b, W4, W6 + Phase 2 | per D15 |
| Low | 17 | W6 + Phase 2 | per D15 |

The per-finding mapping (ID → workstream → test → status) goes in `2026-10-24-auth-hardening.tdd.md`. No finding may be silently dropped.
