# Mobile UI/UX Overhaul & Ergonomics Implementation Plan

> **Goal:** Modernize and elevate the entire mobile UI/UX of TeknoyCart by fixing touch targets, keyboard insets/overflows, destructive action hazards, cart seller grouping, sticky action bars, and gesture-driven image viewing while preserving all 116 tests and CIT-U maroon/gold branding.

**Architecture:**
- **Layer 1: Safety & Keyboard Viewport Stability:** Add confirmation modals on destructive order state changes, wrap all bottom sheet forms in `SingleChildScrollView`, and enable global tap-to-dismiss keyboard on forms.
- **Layer 2: Touch Ergonomics & Accessibility:** Expand all interactive touch targets to ≥ 44–48dp (favorite button, quantity steppers, photo deletion badge, login/register options) and elevate micro-font sizes to ≥ 10.5dp.
- **Layer 3: E-Commerce Layout & Thumb Zone CTAs:** Pin primary conversion CTAs in Checkout to sticky bottom bars and group Cart items by Store/Seller with store-level selection.
- **Layer 4: Interactive Media & Shell Polish:** Add an interactive pinch-to-zoom full-screen image gallery lightbox in product details and synchronize the active drawer item with the current tab index.

**Tech Stack:** Flutter 3.x, Riverpod, Supabase Flutter, Dart.

---

### Task 1: Destructive Action Safety Gate for Order Decline
- **Target File:** `lib/features/checkout/views/order_history_view.dart`
- **Goal:** Prevent accidental immediate rejection of incoming customer orders. Show a confirmation dialog with clear consequence explanation before invoking `_declineOrder`.

### Task 2: Keyboard Inset & Overflow Defenses on Modal Bottom Sheets
- **Target Files:**
  - `lib/features/feed/views/tabs/browse_tab.dart` (Filter sheet)
  - `lib/features/feed/views/product_detail_view.dart` (Tawad offer sheet)
  - `lib/features/feed/views/tabs/profile_tab.dart` (Edit profile sheet)
  - `lib/features/feed/views/tabs/sell_tab.dart` (Listing creation form keyboard dismiss)
- **Goal:** Prevent `RenderFlex overflowed by XX pixels` when soft keyboards appear by wrapping sheet contents in `SingleChildScrollView(physics: BouncingScrollPhysics())` and removing artificial height clamps.

### Task 3: Touch Target Expansion (≥ 44dp) & Micro-Font Scaling
- **Target Files:**
  - `lib/features/feed/views/widgets/feed_product_card.dart` (Heart favorite button hit area to 44dp; condition & department font minimums)
  - `lib/features/checkout/views/cart_view.dart` (Quantity stepper `+` / `-` buttons to 36–44dp)
  - `lib/features/feed/views/tabs/sell_tab.dart` (Photo deletion badge to 36–44dp)
  - `lib/features/auth/views/widgets/auth_login_form.dart` (Forgot password link padding)
  - `lib/features/auth/views/widgets/auth_register_form.dart` (Department selection chips touch padding)

### Task 4: Sticky Checkout Action Bar in Campus Checkout
- **Target File:** `lib/features/checkout/views/checkout_view.dart`
- **Goal:** Move the Order Summary total price and "Confirm Meetup Deal" button to `Scaffold.bottomNavigationBar` with elevated shadow and safe-area padding so it remains accessible in the thumb zone at all times.

### Task 5: Store-Grouped Cart Architecture
- **Target File:** `lib/features/checkout/views/cart_view.dart`
- **Goal:** Replace the flat cart list with store-grouped Bento cards. Each store has a store header, store select checkbox, and direct store checkout button. This removes the blocking multi-seller alert dialog.

### Task 6: Product Detail Action Bar Re-layout & Pinch-to-Zoom Lightbox
- **Target File:** `lib/features/feed/views/product_detail_view.dart`
- **Goal:**
  - Re-layout the 4 cramped buttons into 2 quick icon buttons (Chat & Cart) + 2 action buttons (Offer & Buy Now).
  - Add pinch-to-zoom full-screen photo viewing on tap using `InteractiveViewer`.

### Task 7: Navigation Drawer Tab Sync & Notifications Polish
- **Target Files:**
  - `lib/core/widgets/navigation_drawer.dart`
  - `lib/features/feed/views/product_discovery_feed_view.dart`
- **Goal:** Pass `currentTabIndex` to highlight the true active tab in the side drawer.

### Task 8: Verification & Automated Test Suite Run
- **Goal:** Run `flutter test` across all 116 tests to verify complete zero-regression across auth, checkout, feed, chat, reviews, and profile.
