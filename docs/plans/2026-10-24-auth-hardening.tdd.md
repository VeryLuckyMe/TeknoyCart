# Auth Hardening TDD Evidence

**Source plan:** [2026-10-24-auth-hardening.md](2026-10-24-auth-hardening.md)
**Date updated:** 2026-10-26
**Status:** Local automated gates pass; operational Supabase and device checks remain for the project owner.

## User journeys

1. A student registers, receives a verification email only after the provider accepts it, then returns to sign in without a signed-in profile poller.
2. A student requests a password reset, opens the app deep link, sets a new password, and returns to the sign-in screen.
3. An active verified seller lists items; a pending seller remains in buyer mode and sees a review banner.
4. A non-admin who signs in to the web console is signed out and receives a generic access error.

## Implementation record

| Workstream | Change | Evidence / remaining gap |
| --- | --- | --- |
| W2 | Removed mobile Supabase URL/key defaults; switched to PKCE. Backend now requires persistent 32-byte `JWT_SECRET` and `SUPABASE_URL`; removed ephemeral signing-key fallback and set the configured JWT lifetime to one hour. | Full backend suite passed. Deployment must set these environment values. |
| W4 | Backend waits up to 15 seconds for email-provider acceptance, returns 503 on failure, clears an unused new token, enforces a 60-second resend cooldown, uses deterministic HMAC tokens for valid-link resend, and stores SHA-256 token digests. Legacy plaintext tokens remain verifiable during transition. | Controller tests cover failed delivery and hash-at-rest/verification; full backend suite passed. Concurrency across multiple backend instances is not proven. |
| W4 | Mobile removed blind resend retries and the signed-out `my_profile` poller; resend errors surface, and the dialog returns to sign-in. | `email_verification_dialog_test.dart` passed. |
| W5 | Password reset uses `teknoycart://login-callback` on mobile and the configured Supabase Site URL on web; auth uses PKCE, consumes recovery events at the auth gate, and signs out after a successful password update. | Android, iOS, and web flows were not run. The Supabase mobile redirect allowlist remains a dashboard action. |
| W6 | Auth fields support autofill and keyboard actions; tab switching clears passwords; pending sellers see a pending-review banner. | Manual contrast, keyboard, screen-reader, and tap-target review remains. |
| W7 | Added CI workflows for Flutter, Spring Boot/JDK 17, and web tests/lint. | Workflows were not run by GitHub; they will run on push/PR. |

## Test specification and observed results

| Guarantee | Test / command | Result | Evidence |
| --- | --- | --- | --- |
| Verified admins alone pass the shared web predicate | `npm test` | PASS | 9 tests passed, 0 failed. |
| Web lint has no errors | `npm run lint` | PASS with existing warnings | 0 errors, 10 warnings in existing Inventory/Moderation/Orders files. |
| Full Spring Boot backend suite passes on JDK 17 | `mvn -o -DforkCount=0 test` | PASS | 70 tests passed, 0 failures, 0 errors. |
| Flutter feature tests and all existing Flutter tests pass | `flutter test` | PASS | 266 tests passed, 0 failed. |
| Flutter analyzer has no errors or warnings | `flutter analyze --no-fatal-infos` | PASS | 0 errors, 0 warnings, 80 info lints, same count as baseline. |
| Failed verification-email dispatch is not reported as success | `AuthControllerLoginTest#verificationEmailFailureReturnsServiceUnavailable` | PASS | Included in `mvn -o -DforkCount=0 test`. |
| Stored verification tokens are digests and the mailed token verifies | `AuthControllerLoginTest#verificationTokenIsHashedAndCanVerify` | PASS | Included in `mvn -o -DforkCount=0 test`. |
| Verification dialog offers explicit return to sign-in and a resend cooldown | `test/email_verification_dialog_test.dart` | PASS | Included in full `flutter test`. |
| Registration consent gate stays enforced | `test/auth_register_form_test.dart` | PASS | Included in full `flutter test`. |

The Maven test JVM was run in-process (`-DforkCount=0`) because the default forked process stalled under the local Windows environment. The complete suite still reported 70 tests, 0 failures, and 0 errors. Flutter and backend test runs needed access to their local SDK caches outside the workspace.

Coverage percentages were not measured. The automated suites do not prove live RLS behavior, mail-provider acceptance, cross-device recovery, or accessibility behavior.

No checkpoint commits were created: all three repositories already had user changes, including overlapping auth files, and committing whole files would capture unrelated work.

## Required external verification

- Run W0 live diagnostics, save the database export outside the repository, confirm the four demo accounts, and confirm Supabase Auth minimum password length 12 and Confirm email disabled.
- Set and preserve `JWT_SECRET` (at least 32 bytes), `SUPABASE_URL`, and the required mail provider configuration in the backend deployment environment.
- Add `teknoycart://login-callback` to the Supabase Auth redirect allowlist.
- Run the W1 live PostgREST escalation proof with a buyer and admin account; verify buyer role escalation and buyer product creation are denied.
- Run the buyer/seller two-device Realtime chat/presence smoke test with RLS enabled.
- Exercise password recovery on Android, iOS, and web; complete keyboard, screen-reader, contrast, and touch-target checks.
- Confirm the new GitHub workflows pass after the auth changes are pushed or opened as a PR. Do not mark the overall plan complete until the live and device evidence is recorded.
