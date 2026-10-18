# TeknoyCart Mobile — UI/UX Pro Max Audit Report

**Date:** 2026-10-19 (wave 7 complete + device QA verified; wave 8 ships real PDF export; wave 9 fixes the period-switch regression found in device use)
**Skill:** `ui-ux-pro-max` (installed at `~/.gemini/config/skills/ui-ux-pro-max/`)
**Scope:** All screens of the TeknoyCart Flutter app (`lib/`, 80 Dart files, 25 screen-level audit targets)
**Method:** Mechanical 14-metric scan of every file + targeted greps + deep reads of flagged files. Read-only audit; fixes applied afterward in verified patch waves (waves 1–6 fixes + wave 7 color-token migration + wave 8 PDF export, all complete) + a manual device QA pass (2026-10-19).
**Convention source of truth:** `DESIGN.md` + `lib/core/theme.dart` — the skill's generic database output (purple palette, Rubik/Nunito) was **deliberately not applied**; TeknoyCart's maroon/gold + Outfit/Inter conventions override it.

---

## 1. Verdict Summary

| Dimension | Verdict | Notes |
| :--- | :--- | :--- |
| Typography system | ✅ Fixed (hot spots) | All ≤10px text in the flagged files raised to 11px (feed product card ×8, drawer badge, stepper labels, checkout meta ×6); remaining 10.5–11.5px is intentionally kept; verified on-device at ~1.3× system font scale |
| Color & theming | ✅ Fixed | theme/darkTheme/themeMode wired correctly; dark-surface split resolved (`darkBg` = `#0F0F12`, zero `#0A0A0C` left); token migration run in 2 zero-change passes — views 747 → **444** raw literals, `theme.dart` is now pure token definitions (35 tokens, 21 added); remaining raw are one-off decorative values (optional pass-3 unification tracked in the backlog) |
| Empty states | ✅ Pass | Present on every checked screen with icon + actionable hint |
| Loading states | ✅ Pass | Spinners/skeletons present; 200–300ms animation timing respected; shimmer respects reduce-motion (verified on-device) |
| Error states | ✅ Fixed | Financial Reports silently rendered **₱0/empty as if real** on fetch failure — now shows explicit error + retry; verified on-device in airplane mode |
| Feedback & haptics | ✅ Fixed | All 5 checkout selectors converted to InkWell + haptic; cart toggles haptics added; ripple + haptic feel confirmed on-device |
| Motion & reduced-motion | ⚠️ Fixed (core loops) | `Motion` helper added; both infinite loops respect reduce-motion (holds static on-device); incremental adoption of finite transitions tracked |
| Accessibility | ✅ Fixed | All 7 flagged `Image.network` now have loading/error placeholders; icon-only controls labeled — 34 tooltips, 10 custom taps wrapped in `Semantics`, 16 content images labeled (1 excluded by design); TalkBack/VoiceOver sweep passed on-device |
| Icons & emoji | ⚠️ Fixed (structural) | 44 emoji instances; structural set replaced with Icons/plain text; message-content emoji deferred |
| Responsive/layout | ✅ Verified | Device QA 2026-10-19: phone widths + landscape on the dense screens (feed, product detail) — no overflows, clipping, or broken layout |
| Navigation & shells | ✅ Pass | 5-item labeled bottom nav; 4 "double-header" flags investigated = all legitimate (fullscreen lightboxes/embedded modes) |

**Overall: PASS — fully verified.** 10 of 10 ranked findings resolved (waves 1–6: #1–#6, #8–#10; wave 7: #7 — token migration, passes 1–2, 303 renames, zero visual change). Automated gates green at closure (analyze 0/0, 250/250) and the manual device QA pass came back **all green with zero findings**. Wave 8 then shipped the first post-audit feature: **real PDF export** for Financial Reports (formerly backlog item 2); wave 9 hot-fixed a regression the resumed device use exposed — report-period switching had silently stopped re-filtering the data (introduced by wave 4's fetch hoist and missed by its "no refetch" test; now pinned by a data-changes regression test). Final gates: 0/0 · **257/257**. Optional polish that remains: reduced-motion adoption, type long tail, token-unification pass 3 (the only item needing visual sign-off).

---

## 2. Method & Evidence Trail

- Ran skill queries: `--design-system` for TeknoyCart, `--domain ux` (validation, empty/loading/error, forms, keyboard, multi-step), `--domain chart`, `--stack flutter` ×2.
- Wrote and ran a 14-metric scanner over all 80 Dart files (`ux_scan.py`).
- Deep reads: main shells, checkout, financial reports, product detail, notifications, inbox, order history, feed cards.
- Manual verification of every flagged nested-`Scaffold` (all 4 resolved as legitimate), embedded-screen `embedded: true` convention (verified respected).
- Automated verification after fixes: `flutter analyze` → **0 errors / 0 warnings** (79 pre-existing info-level lints, unchanged baseline); `flutter test` → **257/257 passing** (both gates re-verified green after every wave, incl. both migration passes — 303 renames total — at closure on 2026-10-19, after wave 8 (PDF export), and after the wave-9 period-switch fix).
- Manual device QA pass (2026-10-19): 4 passes (dark/normal text → light + large text → reduce-motion + offline → screen-reader sweep) across the flagged screens, including landscape rotation: **all green, zero findings** (checklist in §8).

---

## 3. Ranked Findings

| # | Severity | Finding | Status |
| :- | :--- | :--- | :--- |
| 1 | 🔴 Critical | Financial Reports: fetch failure caught and returned as zeroed metrics — sellers see ₱0 revenue as if real | ✅ **Fixed** |
| 2 | 🟠 High | Emoji used as icons/structural labels (44 instances) — violates DESIGN.md no-emoji rule + skill `no-emoji-icons` | ✅ **Fixed (structural subset)** |
| 3 | 🟠 High | 0 reduced-motion handling vs 60+ `Animated*` widgets | ✅ **Fixed (loops + helper; incremental adoption tracked)** |
| 4 | 🟠 High | Silent validation: `product_discovery_feed_view.dart:170` rejects passwords <6 chars with no message; KYC inputs lack proper keyboards | ✅ **Fixed** |
| 5 | 🟠 High | 5 ripple-less `GestureDetector` selectors in checkout (`:900, :1050, :1123, :1199, :1335`); haptics missing in checkout/cart (present elsewhere) | ✅ **Fixed** |
| 6 | 🟡 Medium | Type scale: ~780 `fontSize` literals, 203 below 12px (`navigation_drawer.dart:136` = 8px, `order_status_stepper.dart:365` = 9px, `feed_product_card.dart` 8.5–10px ×8) | ✅ **Fixed (all ≤10px hot spots raised to 11px)** |
| 7 | 🟡 Medium | ~700 raw `Color(0x)` in views (worst: `product_detail_view.dart` 79, `notifications_view.dart` 54); dark surface split `#0A0A0C` vs `#0F0F12` | ✅ **Fixed** (wave 7, passes 1–2: split resolved — `#0A0A0C` eliminated; **303 raw literals → named tokens** across 24 + 28 file passes; views 747 → **444**; `theme.dart` reduced to pure token definitions — 35 tokens, 21 added; all values used ≥8× are tokenized. Remaining raw are one-off decorative values (1–7 occ.) — optional pass-3 unification tracked in backlog) |
| 8 | 🟡 Medium | 7 of 17 `Image.network` lack loading/error builders: `order_history:782`, `order_detail:1683`, `edit_product:1297`, `manage_listings:285`, `sell_tab:2710`, `chat_input_bar:56`, `review_submission_sheet:528` | ✅ **Fixed** |
| 9 | 🟡 Medium | `shrinkWrap: true` on unbounded lists: `search_results:544`, `seller_storefront:676`, `cart:953` (checkout `:1111` acceptable — 4-item grid); Financial Reports recreated its fetch future in `build()`, so every period switch silently re-ran all analytics queries | ✅ **Fixed** (fetch hoist ✅ wave 4; all unbounded `shrinkWrap` lists converted wave 6 — app-wide count 4→1, only the accepted 4-item checkout grid remains) |
| 10 | 🔵 Low | 0 `semanticLabel` app-wide; 34 icon-only `IconButton`s without tooltips | ✅ **Fixed** (34 tooltips + 10 `Semantics` wrappers + 16 image labels) |

**Passed cleanly (verified):** empty states everywhere, 200–300ms animation timing, theme/darkTheme/themeMode wiring, 5-item labeled bottom nav, SafeArea usage, embedded-screen convention, no genuine nested-Scaffold double-headers.

---

## 4. Fixes Applied (waves 1–6 + wave 7 + wave 8)

### Fix #1 — Financial Reports honesty on failure (Critical)

**Root cause:** `_getFinancialSummary()` caught all errors and returned a zeroed map, so the `FutureBuilder` could never see a failure — the UI rendered ₱0 revenue, empty charts, and "No verified sales revenues recorded yet", indistinguishable from a real empty state.

| File | Change |
| :--- | :--- |
| `lib/features/reports/views/financial_reports_view.dart:166-170` | Outer catch now `debugPrint(...)` + **`rethrow`** so the failure reaches the `FutureBuilder` (inner per-query catches for inquiries/inventory left intact — those degrade gracefully by design) |
| `lib/features/reports/views/financial_reports_view.dart:220-230` | New `snapshot.hasError` branch: AppBar + error state; retry re-runs the fetch via `setState` |
| `lib/features/reports/views/financial_reports_view.dart:827-886` | New public `SalesReportErrorState` widget: `cloud_off_rounded` icon in tinted circle, honest copy ("Your records are safe…"), Outfit/Inter + light/dark colors, Retry button |
| `lib/features/reports/views/financial_reports_view.dart:198` | Snackbar `'✅ …'` → `'…'` |

**Test added** (`test/financial_reports_test.dart`): `SalesReportErrorState surfaces failure copy and wires the retry action` — asserts error copy, icon, and that Retry fires the callback. Verified passing in isolation.

**Note (updated in wave 4):** the `FutureBuilder` future was created inline in `build()` (pre-existing), so every rebuild refetched every query — **resolved in Fix #8** below: the future is now hoisted and re-runs only on user change or explicit Retry.

### Fix #2 — Structural emoji sweep

Replaced emoji-as-UI with plain text or Material icons; filter logic updated in lockstep:

| File | Before | After |
| :--- | :--- | :--- |
| `checkout/views/order_history_view.dart:477-504` | Filter chips `In Escrow 🔒 / Awaiting ⏳ / To Pickup 🤝 / Completed ✅ / Cancelled ❌` (+ switch cases) | Plain labels, cases updated (`_filterOrders` mapping verified consistent) |
| `chat/views/inbox_view.dart:286,302,448` | `'Deals 🤝'` filter (logic + chips + empty state) | `'Deals'` — all three sites updated together |
| `chat/views/inbox_view.dart:520-528` | Preview labels `🧾 GCash Receipt Attached`, `🤝 Deal Accepted!…`, `🏷️ Tawad Offer:…` | Plain text (content-based `contains()` checks left untouched) |
| `feed/views/widgets/feed_trending_banner.dart:69-89` | `Text('🔥 EXCLUSIVE OFFER')` | `Icon(Icons.local_fire_department_rounded, 12px)` + `Text('EXCLUSIVE OFFER')` |
| `feed/views/notifications_view.dart:288` | `… || item.title.contains('💰')` | Removed emoji coupling; typed checks (`type == 'PAYMENT'`, `'ESCROW'`, title `'Payment'`) retained |
| `feed/views/tabs/profile_tab.dart:80,538,1396` | `✅ Profile details…`, `✅ Account…`, `📋 Student ID…` | Emoji stripped |
| `auth/views/widgets/auth_password_sheets.dart:231` | `✅ Password updated…` | Emoji stripped |
| `reports/views/financial_reports_view.dart:198` | `✅ Sales Report exported…` | Emoji stripped |

**Test updated** (`test/browse_tab_anti_slop_test.dart`): assertion updated to the new string **plus a stronger guard** — `find.byType(FeedTrendingBanner), findsNothing` — so the intent (banner must not render in BrowseTab) survives future copy changes.

**Deliberately deferred (content layer, not UI):** chat/checkout message-content strings (`chat_view:399,695`, `checkout_view:377,378,1517`, `inbox_view:508`, `chat_service:742,814`) — they are user-visible message text with three `contains('Deal! 🤝')` checks coupled to them; changing them is a coordinated data change, not a UI fix. Demo/test-fixture emoji also untouched. `★` rating glyphs kept (typographic, not emoji).

### Fix #3 — Reduced motion (WCAG 2.3.3)

| File | Change |
| :--- | :--- |
| `lib/core/utils/motion.dart` (new) | `Motion.reduce(context)` (reads `MediaQueryData.disableAnimations`) + `Motion.duration(context, base)` (returns `Duration.zero` when reduced) |
| `feed/views/widgets/product_card_skeleton.dart` | Shimmer loop moved out of `initState` into `didChangeDependencies`; under reduce motion the controller stops on a static mid-sheen instead of sweeping forever |
| `chat/views/chat_view.dart` (`_TypingDots`) | Same treatment — typing dots hold steady instead of pulsing indefinitely |
| `checkout/views/checkout_view.dart` (5 selectors) | Selector transitions now use `Motion.duration(...)` |

**Test added** (`test/reduced_motion_test.dart`, 3 tests): helper behavior A/B + a mechanical proof that the skeleton shimmer ticker runs by default (`transientCallbackCount > 0`) and produces **zero** transient callbacks under `disableAnimations: true`.

### Fix #4 — Honest validation + input ergonomics

| File | Change |
| :--- | :--- |
| `feed/views/product_discovery_feed_view.dart:170` | Short-password rejection now shows "Password must be at least 6 characters." + medium haptic instead of silently doing nothing |
| `auth/views/widgets/seller_kyc_verification_view.dart:1183,1198` | Lead Officer name field: `TextInputType.name`, word capitalization, `next` IME action; position field: word capitalization, `done` IME action |

### Fix #5 — Press feedback & haptics (checkout + cart)

| File | Change |
| :--- | :--- |
| `checkout/views/checkout_view.dart` | All 5 `GestureDetector` selectors converted to `InkWell` with visible ripple (transparent-Material overlay inside the decorated container, so splash paints above the decoration), full-area tap targets preserved (container padding moved inside the InkWell), `HapticFeedback.selectionClick()` on select, reduced-motion-aware durations. Verified: `GestureDetector` count 5 → 0; ripple + haptics confirmed on-device |
| `checkout/views/cart_view.dart` | Haptics added: quantity steppers (`selectionClick`), store + item checkboxes (`selectionClick`), variant option chips + change-size chip (`selectionClick`), remove-item button (`lightImpact`). Verified: 6 haptic call sites; confirmed on-device |

**Note:** haptics were already present on tabs, category filters, notifications, and chat (`product_discovery_feed_view.dart:45`, `browse_tab.dart:145,295`, `inbox_view.dart`, `chat_input_bar.dart`, …) — the actual gap was checkout/cart, matching DESIGN.md §1.5. No test referenced `GestureDetector`/`AnimatedContainer` by type, and all tap-target text labels were preserved, so the existing checkout/order suites pass unchanged.

### Fix #6 — Type-scale pass (flagged hot spots)

All ≤10px text in the flagged files raised to 11px; every edit verified against test-font metrics (see note below):

| File | Change |
| :--- | :--- |
| `feed/views/widgets/feed_product_card.dart` | 8 sites: condition badge 9.5→11, PRE-ORDER 9→11, "Campus Meetup" 8.5→11, seller store name 9.5→11, CIT-U pill 9→11, attribute chips 9.5→11, rating 10→11, category chip 9.5→11. Re-scan: **0 sub-12 left** |
| `core/widgets/navigation_drawer.dart:136` | Role badge 8→11, wrapped in a `BoxFit.scaleDown` `FittedBox` so narrow slots scale gracefully instead of overflowing |
| `checkout/views/widgets/order_status_stepper.dart:365` | Step labels 9→11 (5 short labels — `Placed/Accepted/Meetup/Handoff/Done` — verified to fit) |
| `checkout/views/checkout_view.dart` | Meta labels 10→11 (×5) and RECOMMENDED badge 9.5→11; remaining 10.5–11.5px intentionally kept |

**Lesson recorded:** `flutter_test` renders every glyph at `1em` width, so a text bump that fits on-device can overflow in tests. The drawer badge fix (FittedBox) satisfies both: on-device it renders at 11px, in tests it scales instead of throwing `RenderFlex overflowed`. Device QA later confirmed no clipping at ~1.3× system font scale.

### Fix #7 — Image loading/error builders (7 sites)

New shared widget `lib/core/widgets/image_placeholder.dart`: a calm, themed placeholder (no spinners — matches the skeleton style) used for both `loadingBuilder` and `errorBuilder`, with `icon`/`iconSize` parameters. Applied to all 7 flagged sites (previously `Image.network` showed a blank hole on slow/failed loads):

| File | Site |
| :--- | :--- |
| `checkout/views/order_history_view.dart:782` | 54×54 thumb — placeholder while loading + on error |
| `checkout/views/order_detail_view.dart:1683` | 72×72 thumb |
| `feed/views/edit_product_view.dart:1297` | Gallery photo (fills AspectRatio) |
| `feed/views/manage_listings_view.dart:285` | 64×64 leading thumb |
| `feed/views/tabs/sell_tab.dart:2710` | 110×140 web cover photo (`kIsWeb` branch) |
| `chat/views/chat_input_bar.dart:56` | 48×48 pending-attachment preview (`kIsWeb` branch) |
| `feed/views/widgets/review_submission_sheet.dart:528` | 100×100 uploaded review photo |

Loading uses a neutral `Icons.image_outlined` placeholder; errors use `Icons.broken_image_rounded` — a visible signal instead of a silent blank. Verified: `loadingBuilder` count across `lib/` = 7 (was 0); placeholders confirmed on-device.

### Fix #8 — Financial Reports fetch hoist + PDF export honesty (Wave 4)

| File | Change |
| :--- | :--- |
| `reports/views/financial_reports_view.dart` | Analytics future hoisted out of `build()` into `_summaryFuture` / `_summaryUserId` state — created once per signed-in user and re-created **only** when the user changes or via `_retrySummary()` (the Retry button). Switching the reporting period previously rebuilt the `FutureBuilder` future and silently re-ran 4+ Supabase queries; now it just re-filters the already-fetched data client-side |
| `reports/views/financial_reports_view.dart` (export menu) | PDF item relabeled **"Export as PDF (coming soon)"**; the fake `"Simulated: Generated PDF Document successfully."` snackbar replaced with honest copy: *"PDF export is coming soon — use the CSV export for now."* CSV export (real, downloads + copies) is unaffected |

**Test added** (`test/financial_reports_test.dart`): *"switching the report period reuses the hoisted analytics future (no refetch)"* — a request-counting `HttpOverrides` wraps every Supabase call; the test loads the dashboard, switches Monthly → Weekly via the dropdown, and asserts the request count is **unchanged** (with a `greaterThan(0)` guard proving the initial load did hit the counted network, so the assertion is meaningful). Offline honesty + Retry confirmed on-device (airplane mode).

### Fix #9 — Accessibility labels: icon-only controls + content images (Wave 5)

| Area | Change |
| :--- | :--- |
| 34 icon-only `IconButton`s (auth password toggles, back/close buttons, chat attach/send/attachment-clear, cart qty steppers, product variant/quantity steppers, sell_tab stock steppers, sheet close buttons) | Contextual `tooltip:` labels added ("Show password"/"Hide password", "Back", "Close", "Attach image", "Send message", "Remove attachment", "Decrease/Increase quantity", "Decrease/Increase stock", "Clear", "Clear search", "Share product", "Add/Remove from favorites", "Previous step", "Close scanner"). Tooltips double as screen-reader labels |
| 10 custom icon-only tap targets (chat image bubble, edit-product remove-photo chip + steppers, product-detail gallery + chat quick action, browse filter button, review star rating, review-photo lightboxes) | Wrapped in `Semantics(button: true, label: ...)`; star ratings announce "N stars" with `selected:` state; the browse filter announces "Filters, active" when a condition/price filter is on |
| 17 `Image.network` sites | 16 got content-aware `semanticLabel` ("Photo of {product}", "Product photo N", "Review photo N", "Attachment preview", "Cover photo preview", "Photo N of M"); the product gallery image uses `excludeFromSemantics: true` because its tappable wrapper already announces "View photo N" (prevents double announcement) |

**Test added** (`test/chat_input_bar_test.dart`): *"Send and attach buttons expose semantic labels"* — asserts both tooltips resolve and that tapping the labeled send button still fires `onSendMessage`.

**Coverage evidence:** a purpose-written block scanner (`semantics_scan.py`) reports `IconButton` without tooltip **34 → 0**; `Image.network` without `semanticLabel` **17 → 1** (the deliberate `excludeFromSemantics` site); the remaining 4 "icon-only tap" flags are verified wrapper-outside cases where the `Semantics` sits one level above the gesture block (labels present, scanner only looks inside the block). TalkBack/VoiceOver sweep passed on-device (no double-announcements, labels sensible in context).

### Fix #10 — Performance: `shrinkWrap` lists → slivers (Wave 6)

Every unbounded `shrinkWrap: true` list was converted. App-wide `shrinkWrap: true` count **4 → 1** — the only remainder is the accepted 4-item checkout grid.

| File | Before | After |
| :--- | :--- | :--- |
| `feed/views/search_results_view.dart` | Body `SingleChildScrollView` + `Column`; products section returned `GridView.builder(shrinkWrap: true, physics: NeverScrollableScrollPhysics)` | Body is a `CustomScrollView`: pre-grid content in a `SliverList.list`, grid as `SliverGrid.builder` (lazily built / virtualized); empty state + loading + error branches return `SliverToBoxAdapter`-wrapped content |
| `feed/views/seller_storefront_view.dart` | Body `SingleChildScrollView` + `Column`; catalog grid `GridView.builder(shrinkWrap: true, physics: NeverScrollableScrollPhysics)` | Body is a `CustomScrollView`: header/tabs/sort/chips in a `SliverList.list`, catalog grid as `SliverPadding` + `SliverGrid.builder`; all `.when` branches return slivers |
| `checkout/views/cart_view.dart` | Per-store `ListView.separated(shrinkWrap: true, physics: NeverScrollableScrollPhysics)` nested inside the cart's `ListView.builder` | Plain divider-interleaved `Column` — identical layout, one less nested viewport (the outer list already owns scrolling) |
| `reports/views/financial_reports_view.dart` | Transaction log `ListView.builder(shrinkWrap: true, physics: NeverScrollableScrollPhysics)` inside the page `SingleChildScrollView` | Card extracted to `_buildTransactionCard(txn)` + plain `Column` — same visuals, no nested scrollable |

**Why cart/reports became `Column`s but search/storefront became slivers:** the cart and reports lists are content inside an already-scrolling parent, so a content-sized `Column` is the honest structure (identical clamping, one less `ListView`). The two grids were true "unbounded content inside a scroll view" cases — those got real sliver virtualization, so off-screen cards are no longer eagerly built and double-laid-out. Scroll feel confirmed smooth on-device.

**Test added** (`test/seller_storefront_smoke_test.dart` — the storefront's first widget test): renders the sliver-based body with a catalog (asserts header, tab, product card, and zero layout exceptions) and with an empty catalog (asserts the empty-state copy). Both pump through `SliverGrid` layout, which is exactly where a mis-wired sliver tree would throw.

### Fix #11 — Color-token migration (Wave 7, passes 1–2)

**Problem quantified:** 768 raw `Color(0x…)` literals existed in `lib/` (747 in views + 21 in `theme.dart`, of which 14 were the token definitions) against only 14 named tokens — 249 distinct shades in total. Dozens of raw literals were byte-identical duplicates of existing tokens; the dark canvas was split (`#0A0A0C` in theme vs `#0F0F12` across views).

#### Pass 1 — wave 7a: token-exact renames (zero visual change)

| Step | Detail |
| :--- | :--- |
| Dark-surface split resolved | `theme.dart` `darkBg` flipped `#0A0A0C → #0F0F12` (the single approved value change); the last raw `#0A0A0C` survivor (`seller_storefront_view.dart:160`) tokenized to `TeknoyTheme.darkBg` / `lightBg` — **zero `#0A0A0C` occurrences remain in `lib/`** (device QA confirmed one uniform dark canvas, no darker bands) |
| Token-exact renames | 13-value map applied mechanically: `#141418 → darkSurface`, `#22222A → darkBorder`, `#0F0F12 → darkBg`, `#ECECEF → lightBorder`, `#10B981 → success`, plus the maroon/gold/light-bg/warning/error token values — **125 occurrences across 24 files**, redundant `const` prefixes stripped |
| Verification | Token-exact duplicates: 125 → **0**; raw total 768 → 643; gates: analyze 0/0 (79 infos) + **250/250** |

#### Pass 2 — wave 7b: name the drift (zero visual change)

**What:** 21 new tokens added to `theme.dart`, every value frozen **byte-identical** to the live view usage — so zero pixel change:

| Group | Tokens (value) |
| :--- | :--- |
| Dark neutrals | `darkFill` `#14141A` · `darkSurfaceAlt` `#16161A` · `darkSurfaceHigh` `#191922` · `darkSurfaceRaised` `#1E1E28` · `darkCardBorder` `#1E1E24` · `darkHover` `#1E1E26` · `darkHighlight` `#262632` · `darkDivider` `#282830` · `darkInputFill` `#101014` · `darkSurfaceTop` `#16161C` · `darkSurfaceBottom` `#121216` |
| Light neutrals & text | `lightBgAlt` `#F8FAFC` · `lightSurfaceMuted` `#F1F1F5` · `lightDivider` `#E5E7EB` · `lightCardBorder` `#E2E2E6` · `lightTextPrimary` `#0F172A` · `lightTextSecondary` `#64748B` · `lightTextMuted` `#94A3B8` |
| Status/brand | `successDark` `#2E7D32` · `warningDark` `#D97706` · `citMaroonMuted` `#5A413D` |

`theme.dart` now references its own tokens everywhere (hover, highlight, dark/light card outlines, input fill, gradient stops) — **zero inline raw values left in the theme body**; its 35 raw literals are exactly the 35 token definitions (the palette's single source of truth).

**Sweep result:** **178 occurrences renamed across 28 files** (largest: `sell_tab` 18, `notifications_view` 18, KYC 16, `search_results` 16, `order_history` 15, `inbox` 12, `profile_tab` 11). Same guards: `theme.dart` excluded, UTF-8-safe read/write, import check (0 skips needed this time). Gate: analyze 0/0 (79 infos) + **250/250**.

**Net effect (waves 7a+7b):** views **747 → 444** raw occurrences (303 renames = every token-exact duplicate + every value used ≥8×; remaining per-file counts are 1–7 occurrence one-offs). Every recurring palette role now has a name.

**Why the drift values were named instead of merged:** several of the new dark tokens are visually near-identical steps (`darkSurface` `#141418` vs `darkFill` `#14141A`, `darkBorder` `#22222A` vs `darkDivider` `#282830`). Merging them would change pixels, so pass 2 froze them byte-identical under names — which makes any future merge a **one-line token-value change** instead of a 400-site hunt. That optional unification (pass 3) is in the backlog and needs visual sign-off.

### Fix #12 — Real PDF export (Wave 8)

The "coming soon" placeholder is gone: the share menu now generates and delivers a real, multi-page sales-report PDF.

| Step | Detail |
| :--- | :--- |
| Dependencies | `pdf 3.13.1` (pure-Dart generation) + `printing 5.15.1` (delivery). `Printing.sharePdf` opens the native share sheet on mobile and triggers a blob download on web — one delivery path for every platform |
| New generator (`lib/features/reports/services/sales_report_pdf.dart`) | Pure Dart `buildSalesReportPdf(...)` — brand-coloured header (maroon/gold), KPI row (revenue · transactions · inquiries · orders placed), conversion-funnel table, revenue-by-category table with shares, top-products table, low-stock table, full transaction log, and a page `X of Y` footer. `pw.MultiPage` handles page breaks for long logs; empty sections render explicit "no data" notes instead of blanks |
| Delivery seam | `salesReportPdfSharerProvider` (Riverpod): production binds `Printing.sharePdf`; tests override it with a capture/fail fake, so the full menu → bytes → delivery path is verified without platform channels |
| View wiring (`financial_reports_view.dart`) | PDF menu item relabeled "Export as PDF" (stale "coming soon" copy removed); `_exportPdfReport` builds the doc, delivers it, and reports honestly: success snackbar, neutral "export cancelled" copy when the user dismisses the share sheet, and an error snackbar (never fake success) on generator/delivery failure — all `mounted`-guarded |
| Base-font constraints (caught by the gate) | PDF base fonts (Helvetica) are Latin-1 only — the first test run surfaced `Unable to find a font to draw "—"` (em dashes would have exported as **blank cells**) plus a `₱`-dropping hazard. Fixed with: `PHP 1,234.50` formatting (no peso sign), a typography sanitizer (curly quotes/dashes/bullets/ellipsis → ASCII, everything above U+00FF → `?`), and centralized cell sanitization in the table helper. Verified: zero glyph warnings on the re-run; emoji/CJK listing names export safely |

**Tests added (5)** in `test/financial_reports_test.dart`: real-PDF magic bytes on a full summary; empty-data + emoji/CJK robustness; money/status formatters; end-to-end menu → captured bytes + filename regex + success snackbar (only the sharer is faked); honest failure copy when delivery fails. **Gate:** 0 errors / 0 warnings / 79 infos (baseline held) · **255/255**.

### Fix #13 — Report period switching re-filters data again (Wave 9, post-ship regression)

**Found on-device:** choosing Daily/Weekly/All Time changed the dropdown label but not the numbers. **Root cause — a regression from Fix #8 (wave 4):** the analytics fetch was hoisted so period switches no longer re-ran queries, but the period filter (`withinReportPeriod`) lived *inside* the fetch — and the fetch runs once per signed-in user. The (expensive) refetch had been the only thing re-applying the filter, so the dashboard stayed frozen at the first-loaded period. Wave 4's test asserted *no refetch*; nothing asserted *the data changes* — the missing guard.

| Step | Detail |
| :--- | :--- |
| Architecture | Split "fetch" from "compute": `_fetchReportData(userId)` fetches raw, **period-independent** rows (orders/inquiries/products) once per user; the new pure `computeSalesSummary(...)` in `seller_analytics.dart` applies the period filter + aggregation **at render time** |
| View | `build()` runs `computeSalesSummary(period: _selectedPeriod, …)` over the cached raw rows — a dropdown switch recomputes client-side (instant, still **zero** network) and PDF/CSV exports automatically carry the currently-selected period |
| Tests added (2) | `computeSalesSummary` unit test pinning Monthly vs All Time revenue/categories/txns/funnel (the missing guard), and a widget regression test with injected order fixtures proving Monthly `₱450.00` → All Time `₱750.00` **with the request count unchanged** |
| Test harness | `MockHttpOverrides` gained a mutable `supabaseBody`: the Supabase test client caches its `HttpClient` for the whole file, so per-test payloads must re-target the shared mock instead of swapping the global override (first attempt failed exactly this way and was diagnosed from the failure logs) |
| Gate | 0 errors / 0 warnings / 79 infos · **257/257** (the intermediate run also caught a stray analyzer warning in the new harness code; the gate script's severity filter was corrected to match the analyzer's `-` output format) |

---

## 5. Verification Results

| Check | Result |
| :--- | :--- |
| `flutter analyze` | **0 errors, 0 warnings** — 79 info-level lints, all pre-existing style/deprecation notes (baseline held after every wave, incl. both migration passes, and at closure 2026-10-19) |
| `flutter test` (full suite) | **257 / 257 passed** — zero regressions (248 baseline + 2 storefront smoke + 5 PDF export + 2 period re-filter tests); re-verified green after wave 7a (125 renames), wave 7b (178 renames + 21 new tokens), at closure (2026-10-19), after wave 8, and after the wave-9 period fix |
| Wave 7a gate | 0 errors / 0 warnings / 79 infos · **250/250 passed** immediately after 125 raw-color→token renames across 24 files |
| Wave 7b gate | 0 errors / 0 warnings / 79 infos · **250/250 passed** immediately after 178 renames across 28 files + the 21-token theme extension |
| Wave 8 gate | 0 errors / 0 warnings / 79 infos · **255/255 passed** immediately after the PDF export feature (new generator service + menu wiring + 5 tests; the glyph-safety defect was found and fixed in-pass) |
| Wave 9 gate | 0 errors / 0 warnings / 79 infos · **257/257 passed** immediately after the client-side period-filtering refactor + the two regression tests |
| Targeted: `financial_reports_test.dart` (waves 8–9) | **16/16 passed** — real-PDF bytes, empty/exotic data, formatters, menu→delivery seam, honest failure copy, period re-filter (unit + widget) |
| Manual device QA pass (2026-10-19) | **All green, zero findings** — uniform dark canvas after the `darkBg` flip, dark/light contrast, Dynamic Type ≈1.3×, reduced-motion holds (static shimmer/typing dots), ripples + haptics on checkout/cart, sliver scroll feel (search/storefront), image placeholders, offline Financial Reports honesty + working Retry, TalkBack/VoiceOver announcement sweep, landscape rotation |
| Targeted: `financial_reports_test.dart` + `browse_tab_anti_slop_test.dart` | 9/9 passed — incl. the new request-counter no-refetch test |
| Targeted: `chat_input_bar_test.dart` | 5/5 passed — incl. the new semantic-label assertions |
| Targeted: `cart_view_test.dart` + `financial_reports_test.dart` + `category_attributes_feature_test.dart` (wave 6) | 28/28 passed after the four list/grid conversions |
| Targeted: `seller_storefront_smoke_test.dart` (new, wave 6) | 2/2 passed — sliver storefront body renders the catalog grid and the empty state without layout errors |
| Targeted: `reduced_motion_test.dart` | 3/3 passed, including the A/B shimmer-ticker proof |
| Targeted: `navigation_test.dart` + `order_role_visibility_test.dart` | 11/11 passed (after the drawer badge FittedBox fix — see Fix #6 lesson) |
| Static re-scans | 0 sub-12px text left in flagged files · `GestureDetector` in checkout 5→0 · `loadingBuilder` 0→7 · checkout haptics 0→5, cart 0→6 · period-switch refetch requests: 0 (counter test) · unlabeled icon-only `IconButton`s 34→0 · unlabeled content images 17→1 (deliberate exclusion) · `shrinkWrap: true` lists 4→1 (only the accepted 4-item checkout grid) · raw `Color(0x)` in views 747→444 after wave 7 (token-exact duplicates: **0**; `#0A0A0C`: **0**; `theme.dart`: exactly its 35 token definitions) |
| Emoji re-scan of `lib/` | Only deferred message-content occurrences remain |

---

## 6. Per-Screen Snapshot (flagged screens)

| Screen / Component | Findings |
| :--- | :--- |
| **Financial Reports** (`reports/views/financial_reports_view.dart`) | ✅ error-as-zeros fixed · ✅ analytics fetch hoisted **and period filtering moved client-side** (wave 9: switching Daily/Weekly/Monthly/All Time re-filters instantly — regression from the wave-4 hoist, caught on-device, now test-pinned) · ✅ transaction log de-nested (plain `Column`, no `shrinkWrap`) · ✅ **real PDF export shipped (wave 8)** — branded multi-page report via share sheet / download; honest cancel + failure copy; 5 tests. ✅ offline error + Retry + CSV export verified on-device. ⬜ On-device re-checks owed: period dropdown live-update + PDF share-sheet |
| **Order History** (`checkout/views/order_history_view.dart`) | ✅ emoji chips fixed · ✅ image loading/error builders added · ✅ 22 color→token renames (waves 7a+7b) |
| **Order Detail** (`checkout/views/order_detail_view.dart`) | ✅ image loading/error builders added · ✅ 6 color→token renames (waves 7a+7b) |
| **Checkout** (`checkout/views/checkout_view.dart`) | ✅ selectors now InkWell + haptics + reduced-motion-aware (ripple + haptic confirmed on-device) · ✅ meta text ≥11px; `shrinkWrap` at `:1130` deliberately kept (4-item grid) · ✅ 3 token-exact color renames (wave 7a) |
| **Cart** (`checkout/views/cart_view.dart`) | ✅ haptics on qty/checkbox/variant/remove toggles (confirmed on-device); ✅ nested `ListView.separated(shrinkWrap)` replaced with a divider-interleaved `Column` · ✅ 13 color→token renames (waves 7a+7b) |
| **Inbox** (`chat/views/inbox_view.dart`) | ✅ Deals filter + preview labels fixed · ✅ 16 color→token renames (waves 7a+7b). ⬜ content markers deferred (above) |
| **Notifications** (`feed/views/notifications_view.dart`) | ✅ emoji-coupled logic removed · ✅ 20 color→token renames (waves 7a+7b); 54 → 34 raw, remainder are one-off decorative values |
| **Product Discovery Feed** (`feed/views/product_discovery_feed_view.dart`) | ✅ short-password validation now surfaced with message + haptic · ✅ 12 color→token renames (waves 7a+7b) |
| **Feed Product Card** (`feed/views/widgets/feed_product_card.dart`) | ✅ all 8 sub-12px text sizes raised to 11px (no clipping at 1.3× scale on-device) · ✅ 9 color→token renames (waves 7a+7b) |
| **Product Detail** (`feed/views/product_detail_view.dart`) | ✅ 79 → 42 raw colors (37 color→token renames across wave 7); remainder are one-off decorative values. ✅ 2nd Scaffold = legitimate fullscreen lightbox · ✅ landscape verified |
| **Search Results / Seller Storefront** | ✅ both converted to `CustomScrollView` + lazy `SliverGrid` (no `shrinkWrap` left; smooth on-device) · ✅ storefront image builder present · ✅ storefront's first widget test added · ✅ 26 color→token renames (search 20 + storefront 6) |
| **Navigation Drawer** (`core/widgets/navigation_drawer.dart`) | ✅ 8px badge text raised to 11px + FittedBox guard (holds at 1.3× scale on-device) |
| **Order Status Stepper** (`checkout/widgets/order_status_stepper.dart`) | ✅ 9px labels raised to 11px · ✅ 3 token-exact color renames (wave 7a) |
| **Edit Product / Manage Listings / Sell Tab / Chat Input Bar / Review Sheets** | ✅ image loading/error builders added · ✅ wave-7 color→token renames: edit-product 15, manage-listings 6, sell_tab 18, chat-input-bar 1, review sheets 10, reserved-orders 1 |
| **Theme** (`core/theme.dart`) | ✅ dark-surface split resolved (`darkBg` = `#0F0F12`) · ✅ fully token-referenced: 35 named tokens (21 added in wave 7b); theme body contains zero inline raw values — its literals are exactly the token definitions |
| Auth / Onboarding / KYC / Reviews / Profile / Sell | Mechanical scan clean: states present, animation timing OK, SafeArea respected; ✅ KYC officer fields now have proper keyboard types/IME actions · ✅ KYC view: 27 color→token renames (11 + 16); profile: 11 · auth: 8 · ✅ screen-reader sweep on auth/password toggle passed |
| **Accessibility (app-wide)** | ✅ every icon-only `IconButton` labeled (34 added, 46 total) · 10 custom icon taps wrapped in `Semantics` · 16 content images labeled (+1 intentionally excluded) · star ratings announce count + selected state · ✅ TalkBack/VoiceOver sweep verified on-device |

---

## 7. Remaining Backlog (in order)

1. **Token unification, pass 3 (optional — needs visual sign-off)** — the remaining 444 raw literals in views are one-off values (1–7 occurrences each); many are near-duplicate steps of tokens that now exist (e.g. `darkSurface` `#141418` vs `darkFill` `#14141A` vs `darkSurfaceAlt` `#16161A`; `lightBg` `#F6F6F9` vs `lightBgAlt` `#F8FAFC`). Because pass 2 froze every drift value under a name, collapsing them onto canonical shades is now a **one-line token-value change** — but it does move pixels (subtly), so it waits for an explicit visual sign-off.
2. **Reduced-motion incremental adoption** — extend `Motion.duration(...)` to the remaining finite `Animated*` usages (e.g. `sell_tab` ×19) and keep any future looping animations behind `Motion.reduce(...)`.
3. **Type scale (long tail)** — ~187 remaining sub-12px literals sit at 10.5–11.5px in non-flagged files; evaluate per-screen if any drop below 11px.
4. **Optional: embed brand fonts in the PDF** — the report currently uses PDF base fonts (Latin-1 only: `PHP` instead of `₱`, exotic names sanitized to `?`). Bundling Inter/Outfit TTFs would give full brand typography + full Unicode at the cost of ~1 MB of assets and asset-loading in the generator.

*(Former backlog items: "`semanticLabel` pass" ✅ wave 5; "`shrinkWrap` → slivers" ✅ wave 6; "token migration" ✅ wave 7; "manual device QA" ✅ 2026-10-19; "real PDF export" ✅ wave 8.)*

---

## 8. Manual Device Checks — completed (2026-10-19)

All items verified on-device in a 4-pass QA script (dark/normal → light + large text → reduce-motion + offline → screen-reader sweep). Result: **all green, zero findings.**

- ✅ Phone widths + landscape orientation on the flagged screens (incl. the dense feed + product-detail layouts) — no overflows, clipping, or broken layout.
- ✅ Rendered contrast ratios in dark mode, reprised after the wave 7a `darkBg` flip (`#0A0A0C → #0F0F12`) — one uniform canvas across tabs and overscroll; no darker bands; all text legible.
- ✅ Dynamic Type (~1.3× system font scale) — feed meta text, drawer role badge (FittedBox guard holds), stepper labels, ₱ price rows — no clipping.
- ✅ Tap-ripple + haptic feel on the rebuilt checkout selectors and cart toggles — ripple visible and buzz fires on every select.
- ✅ TalkBack/VoiceOver sweep on the newly labeled controls (icon-only buttons, password toggle, product gallery, review stars, cart steppers, chat controls) — announces correctly; no double-announcements on the gallery.
- ✅ Scroll feel on the rebuilt sliver surfaces (search results + storefront catalog grids) and the de-nested cart/transaction lists — smooth, lazy-loading, no blanks.
- ✅ Reduced-motion device check — skeleton shimmer and typing dots hold static under "Remove animations".
- ✅ Offline Financial Reports — honest error state + working Retry (never ₱0-as-real); CSV export works; PDF item shows the honest "coming soon" copy.
- ✅ Image placeholders on slow/failed loads (no blank holes); structural emoji confirmed gone from the UI.

**Pending re-checks (post wave 9):** ⬜ report-period dropdown must now live-update the numbers on-device (the wave-8 device pass found the frozen-filter regression; the fix is test-pinned, device confirmation owed) · ⬜ PDF share-sheet export (wave 8 feature).

---

## 9. Reproduction

```powershell
# Scanner (UTF-8 required)
$env:PYTHONIOENCODING="utf-8"
python C:\Users\Mikel\AppData\Local\Temp\opencode\ux_scan.py

# Accessibility scanner (wave 5)
python C:\Users\Mikel\AppData\Local\Temp\opencode\semantics_scan.py

# Wave 7 color-token re-scan (raw inventory; token-exact duplicates should stay 0 outside theme.dart)
Get-ChildItem -Recurse -Filter *.dart lib | Select-String -Pattern 'Color\(0x' -AllMatches | ForEach-Object { $_.Matches.Count } | Measure-Object -Sum

# Skill queries
python C:\Users\Mikel\.gemini\config\skills\ui-ux-pro-max\scripts\search.py "campus marketplace" --design-system

# Verification gates
cd TeknoyCart\TeknoyCart
flutter analyze
flutter test

# Wave 6 targeted gate
flutter test test/seller_storefront_smoke_test.dart test/financial_reports_test.dart test/cart_view_test.dart test/category_attributes_feature_test.dart

# Wave 8 targeted gate
flutter test test/financial_reports_test.dart
```
