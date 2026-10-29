# GAP-04: Surface Sales Analytics & PDF Export in Seller Hub Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface the dormant 800-line sales analytics engine and PDF statement exporter (`FinancialReportsView`) into the primary seller workflows (`ProfileTab` and `ManageListingsView`), eliminating buried feature dead-ends.

**Architecture:** 
1. Expose `FinancialReportsView` in `ProfileTab` within both the high-visibility **Vendor Control Hub** card (quick action button) and the **Marketplace & Orders** grouped settings list (dedicated navigation tile with subtitle).
2. Wire an `AppBar` action (`Icons.insights_rounded`) and summary link in `ManageListingsView` so campus sellers can transition directly from stock management to sales summaries and PDF statement downloads.
3. Guard all entry points behind `isSeller` and `isSellerVerified` role checks, ensuring regular student buyers continue to see a clutter-free, buyer-focused profile.

**Tech Stack:** Flutter 3.x, Riverpod (StateNotifier / ConsumerStatefulWidget), Supabase (`orders`, `inquiries`, `products`, `product_variants`, `inventory`), PDF (`pdf` package / `sales_report_pdf.dart`), HapticFeedback.

**Spec:** `FEATURES_TO_ADD_OR_IMPROVE.md` Section 1.4 (`GAP-04: Surface Sales Analytics & PDF Export in Seller Hub`).

## Global Constraints
- Do not run `flutter build apk` during execution; use `flutter test` and `flutter analyze` for verification.
- Preserve existing GAP-00 (Reviews), GAP-01 (Wishlist), GAP-02 (PayMongo Deep Link), and GAP-03 (Unified Scroll Header) test suites without regressions.
- Code changes must adhere to `ponytail` (YAGNI, minimal lines, no duplicate code) and pass `flutter analyze` cleanly.
- Granular, atomic commits pushed to `origin main`.

## Review Focus
1. **Role-based visibility boundary:** Regular student buyers (`isSeller == false`) must NEVER see the "Sales & Financial Reports" tile or analytics buttons.
2. **Navigation stack integrity:** Tapping the analytics tile or button must push `FinancialReportsView` with a working back button returning the seller to their exact scroll position.
3. **Verified vs Unverified Seller state:** An unverified seller whose KYC is pending review should not see active store analytics until approved.
4. **Embedded mode in `ManageListingsView`:** When `ManageListingsView` is rendered in embedded mode (`widget.embedded == true`), the external AppBar must not be duplicated.
5. **Theme adaptability:** All newly added buttons, tiles, and badges must support both CIT-U Dark Mode and Light Mode with proper contrast and border tokens.

---

## File Structure

```
TeknoyCart/
├── lib/
│   └── features/
│       └── feed/
│           └── views/
│               ├── manage_listings_view.dart [MODIFIED: add AppBar analytics action & overview CTA]
│               └── tabs/
│                   └── profile_tab.dart      [MODIFIED: add analytics button in Vendor Hub and tile in Marketplace settings]
└── test/
    └── seller_analytics_navigation_test.dart [NEW: widget tests for role-based analytics navigation]
```

---

## Tasks

### Task 1: Write Navigation & Role Visibility Tests for GAP-04

**Files:**
- Create: `TeknoyCart/test/seller_analytics_navigation_test.dart`

**Steps:**
- [ ] **Step 1.1:** Create `TeknoyCart/test/seller_analytics_navigation_test.dart`:
  - Mock setup with `MockHttpOverrides` and `SupabaseConfig.initialize()`.
  - Test 1: Verified seller profile renders "Sales Analytics" action button in Vendor Control Hub card.
  - Test 2: Verified seller profile renders "Sales & Financial Reports" tile in Marketplace & Orders settings group.
  - Test 3: Tapping "Sales & Financial Reports" navigates to `FinancialReportsView`.
  - Test 4: Regular buyer profile suppresses all sales analytics buttons and tiles.
  - Test 5: `ManageListingsView` exposes `Icons.insights_rounded` in AppBar that opens `FinancialReportsView`.
- [ ] **Step 1.2:** Run `flutter test test/seller_analytics_navigation_test.dart` to observe failure on current code.

---

### Task 2: Surface Sales Analytics in `ProfileTab`

**Files:**
- Modify: `TeknoyCart/lib/features/feed/views/tabs/profile_tab.dart:940-975, 1513-1575`
- Test: `TeknoyCart/test/seller_analytics_navigation_test.dart`

**Steps:**
- [ ] **Step 2.1:** Import `financial_reports_view.dart` in `profile_tab.dart`:
  ```dart
  import 'package:teknoycart/features/reports/views/financial_reports_view.dart';
  ```
- [ ] **Step 2.2:** In `_buildVendorControlHub()` ([`profile_tab.dart:1513-1572`](file:///c:/Users/HP%20Laptop%2015s/.gemini/antigravity-ide/scratch/TeknoyCart_Project/TeknoyCart/lib/features/feed/views/tabs/profile_tab.dart#L1513-L1572)):
  - Upgrade the button layout to include a 3rd button or sleek 2-row layout:
    - Row 1: "Storefront" (`OutlinedButton`) & "Manage Stock" (`ElevatedButton`).
    - Row 2: "Sales Analytics & PDF Reports" (`OutlinedButton.icon` with `Icons.insights_rounded`, full-width or side-by-side).
- [ ] **Step 2.3:** In `Marketplace & Orders` settings list ([`profile_tab.dart:915-980`](file:///c:/Users/HP%20Laptop%2015s/.gemini/antigravity-ide/scratch/TeknoyCart_Project/TeknoyCart/lib/features/feed/views/tabs/profile_tab.dart#L915-L980)):
  - Add setting row when `isSeller && isVerified`:
    ```dart
    if (isSeller && isVerified)
      _buildGroupedSettingRow(
        icon: Icons.insights_rounded,
        title: 'Sales & Financial Reports',
        subtitle: 'View revenue breakdown, metrics, and export PDF statements',
        showDivider: true,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FinancialReportsView()),
          );
        },
        isDark: isDark,
      ),
    ```
- [ ] **Step 2.4:** Run `flutter test test/seller_analytics_navigation_test.dart` to verify profile tests pass.

---

### Task 3: Surface Sales Analytics in `ManageListingsView`

**Files:**
- Modify: `TeknoyCart/lib/features/feed/views/manage_listings_view.dart:1-20, 570-580`
- Test: `TeknoyCart/test/seller_analytics_navigation_test.dart`

**Steps:**
- [ ] **Step 3.1:** Import `financial_reports_view.dart` in `manage_listings_view.dart`:
  ```dart
  import 'package:teknoycart/features/reports/views/financial_reports_view.dart';
  ```
- [ ] **Step 3.2:** In `ManageListingsView.build` Scaffold AppBar ([`manage_listings_view.dart:571-576`](file:///c:/Users/HP%20Laptop%2015s/.gemini/antigravity-ide/scratch/TeknoyCart_Project/TeknoyCart/lib/features/feed/views/manage_listings_view.dart#L571-L576)):
  - Add `actions` list to `AppBar`:
    ```dart
    actions: [
      IconButton(
        icon: const Icon(Icons.insights_rounded, color: TeknoyTheme.citMaroon),
        tooltip: 'Sales Analytics & Reports',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FinancialReportsView()),
          );
        },
      ),
      const SizedBox(width: 4),
    ],
    ```
- [ ] **Step 3.3:** Run `flutter test test/seller_analytics_navigation_test.dart` to verify all 5 tests pass.

---

### Task 4: Regression Testing & Documentation Sync

**Files:**
- Test: `TeknoyCart/test/financial_reports_test.dart`, `TeknoyCart/test/order_role_visibility_test.dart`, `TeknoyCart/test/seller_analytics_navigation_test.dart`
- Modify: `FEATURES_TO_ADD_OR_IMPROVE.md`

**Steps:**
- [ ] **Step 4.1:** Run all affected test suites:
  - `flutter test test/seller_analytics_navigation_test.dart`
  - `flutter test test/financial_reports_test.dart`
  - `flutter test test/order_role_visibility_test.dart`
- [ ] **Step 4.2:** Run `flutter analyze` to ensure 0 errors.
- [ ] **Step 4.3:** Update `FEATURES_TO_ADD_OR_IMPROVE.md` marking `GAP-04` as `✅ Resolved`.
- [ ] **Step 4.4:** Commit and push changes to remote `main`.
