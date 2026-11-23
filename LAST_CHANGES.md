# TeknoyCart — Recent Changes & Updates Log

**Last Updated:** November 2026  
**Repository:** `TeknoyCart` (Flutter Mobile & Web)  
**Branch:** `main`

---

## 1. Summary of Recent Updates (21 New Commits)

Over the past week, the team merged critical improvements focusing on **survey readiness**, **authentication resilience**, **seller KYC verification**, and **UI/UX stability**:

```
2320ccc Merge pull request #18: Security fixes and UI/UX minor fixes
79f140a fix(app): seller KYC gate for external emails, orphan review cleanup, wrapped product attributes, order notification names
b907c26 Merge pull request #17: fix(auth): survey-user UX fixes for sign in/up links, Student ID, password flows
df9ff8e Fixed some UI/UX bugs
81a6237 Merge pull request #16: Added tests for auth, checkout, notification, order, product
c5dc61f Merge pull request #15: fix/account-deletion-resilience
fa3d947 fix(navigation): re-export appNavigatorKey from main.dart
67c13c9 refactor(quality): safe context mounted checks, app navigator key isolation, lifecycle safety
93e22f5 Merge pull request #14: Desloppify code refactoring and architecture elevation
70a5e77 Merge pull request #13: KYC intro guide, registration rollback, resilient account deletion
d502d07 Merge pull request #12: Registration email resilience
16eae92 Merge pull request #11: P0 security audit, seller cancellation hardening
```

---

## 2. Detailed Breakdown of Changes

### A. Authentication & Survey UX Fixes (PR #17, PR #18)
* **Student ID Input Format:** Relaxed format constraints (`student_id.dart`) so survey testers with different ID formats (hyphens vs. non-hyphenated) are not blocked during registration.
* **Sign In / Sign Up Link Affordance:** Polished the touch targets and visual styling for switching between Login and Sign Up screens to prevent tap misses.
* **Keyboard Overflow Protection:** Wrapped registration inputs in resilient scroll views to prevent "Bottom Overflowed by N pixels" errors when mobile keyboards pop up.
* **Registration Confirm Field:** Addressed IME/keyboard input bugs on the password confirmation field during signup.

### B. Email & Registration Resilience (PR #12, PR #13)
* **Email Delivery Fallback:** When the external email delivery service (e.g. Render backend or SMTP) is delayed or sleeping, registration no longer crashes with a raw `ClientException`. It now wraps the response in a graceful `SignUpResult`.
* **"Email Not Sent" Guidance:** Users are presented with a helpful dialog explaining how to resend or continue instead of being stuck.
* **Registration Rollback:** If account provisioning fails midway, incomplete records are rolled back to prevent stranded email addresses.

### C. Seller KYC & Storefront Safeguards
* **External Email KYC Gate:** Proper handling of non-CIT student emails requesting seller status.
* **What to Expect KYC Intro Guide:** Removed premature "pending verification" banners on initial sign-up and replaced them with a clear 2-minute identity verification walkthrough.
* **Seller Cancellation Rules:** Enforced strict logic preventing sellers from canceling once an order has already transitioned to accepted.

### D. Feed & Catalog Polish
* **Wrapped Product Attributes:** Fixed text clipping and layout constraints on category chips and product detail tags.
* **Orphan Review Cleanup:** Ensured deleted products or users do not leave orphaned reviews breaking review list renders.
* **Notification Names:** Order notifications now display explicit buyer/seller names rather than ambiguous IDs.

### E. Account Management & Lifecycle Safety (PR #14, PR #15)
* **Resilient Account Deletion:** Permanent account deletion protects accounts with active ongoing orders from accidental erasure.
* **Navigation & Context Safety:** Re-exported `appNavigatorKey` from `main.dart` and added `mounted` guards across asynchronous service calls to eliminate Flutter framework exceptions.

---

## 3. Verification & Test Suite
* Added comprehensive test coverage:
  * `test/auth_keyboard_overflow_test.dart`
  * `test/auth_link_affordance_test.dart`
  * `test/auth_redirect_test.dart`
  * `test/auth_registration_rollback_test.dart`
  * `test/auth_delete_account_test.dart`
  * `test/auth_verification_email_test.dart`
  * `test/notification_item_test.dart`, `order_test.dart`, `product_test.dart`
