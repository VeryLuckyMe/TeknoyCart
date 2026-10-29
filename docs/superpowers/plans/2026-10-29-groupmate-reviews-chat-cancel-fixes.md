# Groupmate Feedback Fixes: Reviews Visibility, Unread Chat Badge, & Seller Cancel Suppression

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve the three critical marketplace bugs reported by team member testing: (1) multiple reviews from repeated purchases not appearing on the Product Detail page, (2) missing unread message badge indicator on the bottom navigation Messages tab, and (3) suppressing the seller "Cancel Order" action once an order is accepted.

**Architecture:** 
1. Fix review de-duplication in `ReviewsNotifier.submitReview` to key uniquely by `orderId` rather than collapsing multiple orders of the same `productId` by the same buyer, and add a reactive `refreshReviews()` trigger for `ProductReviewsSection`.
2. Introduce `unreadChatCountNotifierProvider` in `lib/features/chat/providers/chat_provider.dart` with Postgres exact unread count query and Supabase Realtime subscription on `messages`, binding it to `_buildBottomNavItem` in `ProductDiscoveryFeedView`.
3. Update `OrderDetailView._buildActionButtons` to suppress the seller cancellation button when `_status == 'ACCEPTED'` (or in-flight post-acceptance), preserving the structured "Decline Order" on `PLACED` and "Report No-Show" for meetup failures.

**Tech Stack:** Flutter 3.x, Riverpod (StateNotifier / AsyncNotifier), Supabase Realtime (`messages`, `product_reviews`, `orders`), PostgreSQL RLS, Spring Boot 3.x / Java 17 backend.

**Spec:** Direct user issue report from peer testing (4 mobile screenshots & Bisaya dialogue regarding review count discrepancy, missing message badge, and seller post-acceptance cancel button).

## Global Constraints
- Do not run `flutter build apk` during execution; run `flutter test` and `flutter analyze` for verification.
- Preserve existing GAP-01 (Wishlist), GAP-02 (PayMongo Deep Link), and GAP-03 (Unified Scroll Header) test suites without regressions.
- All code changes must pass `flutter analyze` with 0 issues.
- Git commits must be granular, atomic, and pushed to `origin main` after verifying tests.

## Review Focus
1. **Multi-order product review duplication check:** A buyer purchasing the same product across Order 1 and Order 2 must see both reviews rendered in `ProductReviewsSection` without one overwriting the other in local memory.
2. **Review edit vs new review distinction:** Editing an existing review on Order 1 must update only Order 1's review, not mutate Order 2.
3. **Chat unread badge real-time reactivity:** Receiving a chat message while browsing the feed must immediately trigger the red unread badge on the Messages tab; entering the chat room must clear the badge.
4. **Chat unread count filter boundary:** Unread messages sent by the current user themselves must NEVER trigger the unread badge (only incoming messages where `sender_id != currentUserId`).
5. **Seller post-acceptance order stability:** An accepted order (`_status == 'ACCEPTED'`) for either Cash or GCash must never expose a destructive `Cancel Order` button for the seller, ensuring commitment integrity.

---

## File Structure

```
TeknoyCart/
├── lib/
│   ├── features/
│   │   ├── chat/
│   │   │   ├── providers/
│   │   │   │   └── chat_provider.dart           [MODIFIED: add unreadChatCountNotifierProvider & realtime listener]
│   │   │   └── views/
│   │   │       └── inbox_view.dart              [MODIFIED: hook unread clear/sync on chat open]
│   │   ├── checkout/
│   │   │   └── views/
│   │   │       └── order_detail_view.dart       [MODIFIED: remove seller cancel button on ACCEPTED status]
│   │   └── feed/
│   │       ├── providers/
│   │       │   └── review_provider.dart         [MODIFIED: fix indexWhere collision by orderId, add refresh]
│   │       └── views/
│   │           ├── product_discovery_feed_view.dart [MODIFIED: connect unreadChatCount to Messages bottom nav item]
│   │           └── widgets/
│   │               └── product_reviews_section.dart [MODIFIED: trigger refresh on init/pull-to-refresh]
└── test/
    ├── reviews_feature_test.dart                [MODIFIED: add test for multiple reviews for same product by same buyer]
    ├── unread_chat_badge_test.dart              [NEW: test unread count notifier and bottom nav badge rendering]
    └── seller_cancel_order_test.dart            [MODIFIED: update assertions to verify ACCEPTED hides cancel for seller]
```

---

## Tasks

### Task 1: Fix Review De-duplication and Refresh in `review_provider.dart`

**Files:**
- Modify: `TeknoyCart/lib/features/feed/providers/review_provider.dart:139-160`
- Modify: `TeknoyCart/lib/features/feed/views/widgets/product_reviews_section.dart:20-40`
- Test: `TeknoyCart/test/reviews_feature_test.dart`

**Detailed Root Cause:**
In `review_provider.dart:142-145`:
```dart
final existingIndex = state.indexWhere((r) =>
    (orderId != null && r.orderId == orderId) ||
    (r.productId == productId && r.buyerId == buyerId));
```
When a buyer buys the same product in a subsequent order (`orderId != r.orderId`), the condition `(r.productId == productId && r.buyerId == buyerId)` evaluates to `true`, replacing the earlier review in local memory (`updatedList[existingIndex] = newReview`) instead of prepending it (`state = [newReview, ...state]`). In contrast, Supabase and PostgreSQL have `CONSTRAINT unique_order_buyer_review UNIQUE (order_id, buyer_id)`, allowing both rows to persist. When the seller opened the profile on another device, both rows were loaded from Supabase; but on the buyer's device, the first review was squashed out of memory.

**Steps:**
- [ ] **Step 1.1:** In `TeknoyCart/test/reviews_feature_test.dart`, write a failing unit test:
  - Submit Review 1 for `productId: 'prod-A'`, `orderId: 'ord-1'`, `buyerId: 'usr-1'`.
  - Submit Review 2 for `productId: 'prod-A'`, `orderId: 'ord-2'`, `buyerId: 'usr-1'`.
  - Assert that `reviewsForProductProvider('prod-A')` contains both 2 reviews, not 1.
- [ ] **Step 1.2:** Run `flutter test test/reviews_feature_test.dart` to verify failure.
- [ ] **Step 1.3:** In `TeknoyCart/lib/features/feed/providers/review_provider.dart`:
  - Change line 142-145 in `submitReview`:
    ```dart
    final existingIndex = orderId != null
        ? state.indexWhere((r) => r.orderId == orderId)
        : state.indexWhere((r) => r.productId == productId && r.buyerId == buyerId && r.orderId == null);
    ```
  - Add public `Future<void> refreshReviews()` to `ReviewsNotifier` that re-runs `_loadFromSupabase()` and updates `state`.
- [ ] **Step 1.4:** In `TeknoyCart/lib/features/feed/views/widgets/product_reviews_section.dart`:
  - Call `ref.read(reviewsNotifierProvider.notifier).refreshReviews()` in `initState` so that fresh reviews from other orders/devices are immediately synchronized when the product view opens.
- [ ] **Step 1.5:** Run `flutter test test/reviews_feature_test.dart` to verify all tests pass.
- [ ] **Step 1.6:** Run `flutter analyze` and commit:
  `git commit -m "fix(reviews): allow multiple reviews across distinct orders for same product"`

---

### Task 2: Realtime Unread Chat Count Provider & Bottom Nav Badge

**Files:**
- Modify: `TeknoyCart/lib/features/chat/providers/chat_provider.dart:1-55`
- Modify: `TeknoyCart/lib/features/chat/views/inbox_view.dart:580-600`
- Modify: `TeknoyCart/lib/features/feed/views/product_discovery_feed_view.dart:240-330, 660-670`
- Test: `TeknoyCart/test/unread_chat_badge_test.dart`

**Detailed Root Cause:**
In `product_discovery_feed_view.dart:663`, `hasBadge: false` is hardcoded on the `Messages` tab. Furthermore, `chat_provider.dart` has no notifier or stream tracking unread messages across chats, unlike `notification_provider.dart` which features `UnreadCountNotifier` and `unreadNotificationCountProvider`.

**Steps:**
- [ ] **Step 2.1:** Create unit test `TeknoyCart/test/unread_chat_badge_test.dart`:
  - Test `UnreadChatCountNotifier` initialization with exact count from mock.
  - Test increment on incoming message (`sender_id != currentUserId`).
  - Test no-op or exclusion on self message (`sender_id == currentUserId`).
  - Test decrement/reset when messages in a room are marked as read.
  - Test widget rendering of `_buildBottomNavItem` showing badge pill when `unreadChatCount > 0`.
- [ ] **Step 2.2:** In `TeknoyCart/lib/features/chat/providers/chat_provider.dart`:
  - Implement `UnreadChatCountNotifier extends StateNotifier<int>`:
    - `fetchExactCount()`: Queries Supabase `messages` table for `is_read = false` and `sender_id != currentUserId`. Note: RLS policy `messages_select_participants` guarantees user can only query messages from their own chats.
    - `subscribeToRealtimeUnread(String currentUserId)`: Listens to Postgres changes on `messages` table. On INSERT with `sender_id != currentUserId`, increments count. On UPDATE with `is_read == true`, refreshes exact count.
    - `decrementBy(int count)` / `decrement()` / `reset()` / `refresh()`.
  - Expose `unreadChatCountNotifierProvider` and `unreadChatCountProvider`.
- [ ] **Step 2.3:** In `TeknoyCart/lib/features/feed/views/product_discovery_feed_view.dart`:
  - Update `_buildBottomNavItem`:
    - Add parameter `int? badgeCount`.
    - If `hasBadge` is true, render a red badge pill (with `$badgeCount` text if `badgeCount > 0`, formatted as `'99+'` if `> 99`, or dot if count is null), styled identically to the notification badge in the app bar.
  - In `build()`, watch `final unreadChatCount = ref.watch(unreadChatCountProvider);`
  - Pass `hasBadge: unreadChatCount > 0` and `badgeCount: unreadChatCount` to the `Messages` tab item.
- [ ] **Step 2.4:** In `TeknoyCart/lib/features/chat/views/inbox_view.dart`:
  - When opening a chat room or when messages are marked as read, notify `ref.read(unreadChatCountNotifierProvider.notifier).refresh()`.
- [ ] **Step 2.5:** Run `flutter test test/unread_chat_badge_test.dart` and `flutter test test/navigation_test.dart`.
- [ ] **Step 2.6:** Run `flutter analyze` and commit:
  `git commit -m "feat(chat): add reactive realtime unread message badge to bottom navigation"`

---

### Task 3: Suppress Seller "Cancel Order" on Accepted Status

**Files:**
- Modify: `TeknoyCart/lib/features/checkout/views/order_detail_view.dart:2300-2315`
- Modify: `TeknoyCart/test/seller_cancel_order_test.dart:100-125`

**Detailed Root Cause:**
In `order_detail_view.dart:2300-2305`:
```dart
final showSellerCancel = _status == 'ACCEPTED' ||
    _status == 'AWAITING_PAYMENT' ||
    _status == 'ESCROWED' ||
    _status == 'PAYMENT_SUBMITTED' ||
    (_status == 'MEETUP_SCHEDULED' && !_isGCash);
```
Once the seller accepts the order (`_status == 'ACCEPTED'`), they have made a binding commitment to sell. Showing a prominent "Cancel Order" button after acceptance violates e-commerce convention and allows sellers to arbitrarily renege on accepted orders. If the seller does not want to accept the order, they have "Decline Order" in the `PLACED` state. If meetup scheduling fails or buyer doesn't show up, they have "Report No-Show".

**Steps:**
- [ ] **Step 3.1:** In `TeknoyCart/test/seller_cancel_order_test.dart`:
  - Update test `ACCEPTED cash order exposes Cancel Order alongside schedule`:
    - Change assertion: verify `find.text('Schedule Meetup & Notify Buyer')` is found, and `find.text('Cancel Order')` is `findsNothing` for the seller.
  - Update test `ACCEPTED GCash order (buyer has not paid) exposes Cancel Order`:
    - Change assertion: verify `find.text('Cancel Order')` is `findsNothing` for the seller on `ACCEPTED` GCash order.
- [ ] **Step 3.2:** Run `flutter test test/seller_cancel_order_test.dart` to verify the tests fail on the current code.
- [ ] **Step 3.3:** In `TeknoyCart/lib/features/checkout/views/order_detail_view.dart:2300`:
  - Remove `_status == 'ACCEPTED'` and `_status == 'AWAITING_PAYMENT'` from `showSellerCancel`:
    ```dart
    final showSellerCancel = 
        _status == 'ESCROWED' ||
        _status == 'PAYMENT_SUBMITTED';
    ```
  - For `ACCEPTED` orders, the seller sees:
    - Cash on pickup: "Schedule Meetup & Notify Buyer" (+ Chat).
    - GCash: "Awaiting buyer GCash payment via PayMongo" banner (+ Chat).
    - No destructive `Cancel Order` button.
- [ ] **Step 3.4:** Run `flutter test test/seller_cancel_order_test.dart` to verify all 12 tests pass.
- [ ] **Step 3.5:** Run `flutter analyze` and commit:
  `git commit -m "fix(orders): suppress seller cancel button once order is accepted"`

---

### Task 4: Comprehensive Verification & Regression Testing

**Files:**
- Test: All relevant test suites in `TeknoyCart/test/`

**Steps:**
- [ ] **Step 4.1:** Run all affected test suites:
  - `flutter test test/reviews_feature_test.dart`
  - `flutter test test/unread_chat_badge_test.dart`
  - `flutter test test/seller_cancel_order_test.dart`
  - `flutter test test/order_role_visibility_test.dart`
  - `flutter test test/navigation_test.dart`
  - `flutter test test/browse_tab_anti_slop_test.dart`
- [ ] **Step 4.2:** Run full static analysis:
  - `flutter analyze` (Must be 0 issues, 0 warnings).
- [ ] **Step 4.3:** Push branch to remote `origin main`:
  - `git push origin main`
- [ ] **Step 4.4:** Document findings and response for the groupmate's GCash no-show inquiry.

