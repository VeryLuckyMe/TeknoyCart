# Cart Edit Mode & Mobile UI/UX Overhaul Implementation Plan

> **Goal:** Transform TeknoyCart's cart screen into a polished, Shopee/Lazada-grade experience with a batch "Edit Mode", tactile micro-interactions, batch deletion, zero-quantity safety dialogs, and elevated visual hierarchy using `refactoring-ui` and `microinteractions`.

**Architecture:**
- **Layer 1: Local Draft State & Mode Controller**: Introduce an `isEditingMode` toggle with local `_draftQuantities` so adjustments never trigger premature API/database calls or immediate item deletion.
- **Layer 2: Tactile Edit Header & Morphing CTA**: Replace the static top bar with a generic edit icon (pencil/tune) that animates into a highlighted Done checkmark when active, while the bottom bar morphs between "Checkout Selected" and "Delete Selected (N)".
- **Layer 3: Visual Polish & Touch Ergonomics**: Modernize store bento cards, expand stepper buttons to ≥38dp with subtle spring depression, and ensure all typography adheres to CIT-U brand scales (≥12dp).
- **Layer 4: Destructive Action Safety Gate**: Intercept `quantity == 1` minuses with a gentle modal sheet offering "Remove Item" or "Move to Wishlist / Save for Later" instead of instant vanishing.

**Tech Stack:** Flutter 3.x, Riverpod (`cartProvider`), Dart, CIT-U Theme tokens.

---

### Phase 1: Local Draft State & Mode Architecture
**Files:**
- Modify: `TeknoCart/lib/features/checkout/views/cart_view.dart`
- Modify: `TeknoCart/lib/features/checkout/providers/cart_provider.dart`

#### Task 1.1: Add Batch Quantity Update to `CartNotifier`
- Add `batchUpdateQuantities(Map<String, int> updates)` to `CartNotifier` in `cart_provider.dart` to apply multiple quantity modifications in a single state mutation.
- **Verification:** Unit test verifying `batchUpdateQuantities` updates quantities without duplicate notifications.

#### Task 1.2: Add `isEditingMode` and `_draftQuantities` in `_CartViewState`
- In `_CartViewState`, add:
  - `bool _isEditingMode = false;`
  - `final Map<String, int> _draftQuantities = {};`
  - `final Set<String> _editSelectedKeys = {};`
- When entering edit mode, populate `_draftQuantities` with current item quantities.
- When exiting/saving edit mode, dispatch batch updates to Riverpod only for keys where `_draftQuantities[key] != item.quantity`.

---

### Phase 2: Top App Bar & Morphing Edit Trigger
**Files:**
- Modify: `TeknoCart/lib/features/checkout/views/cart_view.dart`

#### Task 2.1: Implement the Generic Edit Icon Trigger
- In the `AppBar` actions:
  - When `!_isEditingMode`: Render a clean, subtle generic icon button (`Icons.tune_rounded` or `Icons.edit_outlined`) with touch bounds ≥ 44×44dp and tooltip "Manage cart".
  - When `_isEditingMode`: Animate into a highlighted Pill button with a checkmark icon (`Icons.check_rounded`) and label "Done" in CIT-U Maroon (`#800000`) / Gold (`#FFC107`).
- Add a sub-100ms bouncy tap animation (`AnimatedScale` 0.95 -> 1.0) on press.

---

### Phase 3: Bento Card UI & Stepper Refactor (Visual Elevation)
**Files:**
- Modify: `TeknoCart/lib/features/checkout/views/cart_view.dart`

#### Task 3.1: Elevated Store Bento Cards (`refactoring-ui`)
- Wrap each store grouping in a Bento card container:
  - Border radius: `16dp`
  - Subtle card shadow: `BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: Offset(0, 3))`
  - Surface background: Crisp white (`#FFFFFF`) in light mode, `#1A1A20` in dark mode.
- Store header: Storefront icon in amber badge, bold store name, and subtle "Store Deal >" chip.

#### Task 3.2: Dual-State Cart Item Row (Normal vs Edit Mode)
- **In Normal Mode:**
  - Checkbox selects item for **Checkout**.
  - Steppers are hidden; quantity is shown as a neat badge chip: `Qty: 2` with variation `Size: L`.
  - Item price displayed in bold CIT-U Maroon (`₱550.00`).
- **In Edit Mode:**
  - Checkbox selects item for **Batch Deletion**.
  - Steppers `[-] [ qty ] [+]` are prominently unlocked with tactile bouncy feedback.
  - Tapping variation chip opens variation switcher directly without leaving edit mode.

#### Task 3.3: Safety Confirmation Sheet for Zero Quantity / Delete
- When user taps `[-]` while draft quantity is `1`, or clicks the red delete trash icon:
  - Do NOT delete immediately.
  - Present a smooth bottom modal sheet:
    - Title: "Remove from Cart?"
    - Product thumbnail & title
    - Two clear action buttons:
      1. **"Save for Later"** (moves to wishlist/favorites).
      2. **"Remove"** (destructive red pill).
      3. Cancel tap outside or back.

---

### Phase 4: Bottom Action Bar Transformation
**Files:**
- Modify: `TeknoCart/lib/features/checkout/views/cart_view.dart`

#### Task 4.1: Dynamic Bottom Summary Bar
- Use `AnimatedSwitcher` to transition the bottom bar between two states:
  - **State A (Normal Shopping Mode):**
    - Left: "Selected Total" + large `₱XX.XX` in CIT-U Maroon Outfit bold font.
    - Right: "Checkout Selected (N)" in full maroon pill with safe area thumb reach.
  - **State B (Edit Mode Active):**
    - Left: "Select All" checkbox + count of items marked for removal.
    - Right: Destructive red pill: **"Delete Selected (N)"** with trash icon.
    - Disabled when 0 items selected in edit mode.

---

### Phase 5: Verification, Regressions & Performance
**Files:**
- Test: `TeknoCart/test/comprehensive_features_test.dart`
- Test: `TeknoCart/test/cart_edit_mode_test.dart`

#### Task 5.1: Create Dedicated Widget & Unit Tests
- Test 1: Entering edit mode uncouples quantity changes from immediate provider mutations.
- Test 2: Clicking "Done" commits only altered quantities.
- Test 3: Batch deletion removes all selected keys in one atomic state update.
- Test 4: Reducing quantity at 1 triggers the safety confirmation sheet instead of deleting.

#### Task 5.2: Full Regression Run
- Run `flutter test` across all feature test suites to guarantee zero regression on checkout totals and order creation.
