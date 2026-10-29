# GAP-08: Persistent Search History & Recent Search Chips Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide persistent local storage of student search keywords using Flutter secure storage with fine-grained Riverpod state, and surface recent search chips across `BrowseTab`, `SearchResultsView`, and zero-result empty states.

**Architecture:** 
1. Create `SearchHistoryStorageAdapter` (with `SecureSearchHistoryStorageAdapter` and in-memory `InMemorySearchHistoryStorageAdapter` for instant test isolation) and `SearchHistoryNotifier extends StateNotifier<List<String>>` in `lib/core/services/search_history_service.dart`.
2. Build `SearchHistoryChips` widget in `lib/features/feed/views/widgets/search_history_chips.dart` with horizontal scrollable chips, tap-to-re-search, single-chip deletion, and "Clear All" action.
3. Wire into `BrowseTab` (below search input deck with auto-collapse on active search, plus in zero-match empty state) and `SearchResultsView` (app bar search submission and empty query fallback).

**Tech Stack:** Flutter 3.x, Flutter Riverpod 2.6.x, `FlutterSecureStorage`, TDD widget & unit tests.

**Spec:** [`FEATURES_TO_ADD_OR_IMPROVE.md`](file:///c:/Users/HP%20Laptop%2015s/.gemini/antigravity-ide/scratch/TeknoyCart_Project/FEATURES_TO_ADD_OR_IMPROVE.md#L86-L89) (GAP-08).

---

## Global Constraints

- **Dependency Limits:** Rely strictly on existing dependencies (`flutter_riverpod`, `flutter_secure_storage`). Do not introduce third-party storage bloat.
- **De-duplication Policy:** Case-insensitive deduplication (e.g. searching "calculus" when "Calculus" exists brings it to the top without duplicating).
- **History Cap:** Maximum 8 recent search items preserved to prevent memory bloat and horizontal sprawl.
- **Minimum Query Length:** Queries must have at least 2 non-whitespace characters to be recorded into history.
- **Performance:** Asynchronous non-blocking persistence; Riverpod updates UI state immediately.
- **No APK Builds:** Test strictly via `flutter test`. Never execute `flutter build apk`.

---

## Review Focus

1. **Empty/Whitespace Queries:** Typing spaces or empty string must not pollute search history or create blank chips.
2. **Duplicate Query Ranking:** Searching an existing query must float it to index 0 rather than appending a second chip.
3. **Delete Single vs. Clear All:** Deleting one chip must only remove that specific keyword; "Clear All" must reset state to empty and clear storage.
4. **Theme Contrast (Dark/Light):** Chip backgrounds, icons, and text must maintain >= 4.5:1 contrast against both CIT-U Maroon/dark mode backgrounds and light mode.
5. **Short-Viewport & Overflow Resilience:** Chip rows must scroll horizontally without throwing horizontal RenderFlex overflow errors on narrow device viewports.

---

## File Structure

- **Create:**
  - `TeknoyCart/lib/core/services/search_history_service.dart` (Storage adapter, Riverpod notifier, and providers)
  - `TeknoyCart/lib/features/feed/views/widgets/search_history_chips.dart` (Reusable UI chip row)
  - `TeknoyCart/test/search_history_service_test.dart` (Unit tests for notifier & storage adapter)
  - `TeknoyCart/test/search_history_ui_test.dart` (Widget tests for chips in BrowseTab and SearchResultsView)
- **Modify:**
  - `TeknoyCart/lib/features/feed/views/tabs/browse_tab.dart` (Search history integration & empty state recommendation)
  - `TeknoyCart/lib/features/feed/views/search_results_view.dart` (Submission recording & empty query view)
  - `FEATURES_TO_ADD_OR_IMPROVE.md` (Live status tracker)

---

## Task Decomposition

### Task 1: Search History Service & Riverpod State Notifier (TDD)

**Files:**
- Create: `TeknoyCart/lib/core/services/search_history_service.dart`
- Test: `TeknoyCart/test/search_history_service_test.dart`

**Steps:**
- [ ] Write failing unit tests in `test/search_history_service_test.dart` covering:
  - Initial state loads from storage adapter.
  - `addQuery()` adds new search to front of list.
  - `addQuery()` ignores empty or single-char strings.
  - `addQuery()` de-duplicates case-insensitively and promotes to head.
  - `addQuery()` caps history at `maxHistoryLength = 8`.
  - `removeQuery()` removes target query.
  - `clearAll()` empties history.
  - Persistence across re-initialization with `InMemorySearchHistoryStorageAdapter`.
- [ ] Run `flutter test test/search_history_service_test.dart` (Verify tests fail).
- [ ] Implement `SearchHistoryStorageAdapter`, `SecureSearchHistoryStorageAdapter`, `InMemorySearchHistoryStorageAdapter`, and `SearchHistoryNotifier` in `lib/core/services/search_history_service.dart`.
- [ ] Expose `searchHistoryStorageProvider`, `searchHistoryProvider`, and `hasSearchHistoryProvider`.
- [ ] Re-run `flutter test test/search_history_service_test.dart` (Verify all pass).

---

### Task 2: Reusable `SearchHistoryChips` Widget (TDD)

**Files:**
- Create: `TeknoyCart/lib/features/feed/views/widgets/search_history_chips.dart`
- Test: `TeknoyCart/test/search_history_ui_test.dart`

**Steps:**
- [ ] Write failing widget tests in `test/search_history_ui_test.dart` verifying:
  - Hidden when history is empty.
  - Renders recent search chips when history contains items.
  - Tapping chip invokes `onSelectQuery(query)`.
  - Tapping individual delete icon invokes `removeQuery(query)`.
  - Tapping "Clear All" clears the list.
- [ ] Run `flutter test test/search_history_ui_test.dart` (Verify tests fail).
- [ ] Implement `SearchHistoryChips` with:
  - Header: `"Recent Searches"` with `Icons.history_rounded` and `"Clear All"` button.
  - Horizontal `ListView` with chips styled in CIT-U Maroon accents.
  - Individual `✕` remove button with accessible hit test area.
- [ ] Re-run `flutter test test/search_history_ui_test.dart` (Verify all pass).

---

### Task 3: Wire into `BrowseTab` and `SearchResultsView`

**Files:**
- Modify: `TeknoyCart/lib/features/feed/views/tabs/browse_tab.dart`
- Modify: `TeknoyCart/lib/features/feed/views/search_results_view.dart`
- Test: `TeknoyCart/test/search_history_ui_test.dart`

**Steps:**
- [ ] In `BrowseTab`:
  - When `onSubmitted` is triggered in the search input deck, call `ref.read(searchHistoryProvider.notifier).addQuery(val)`.
  - Embed `SearchHistoryChips` right below the search deck when `searchQuery.isEmpty` and `recentSearches.isNotEmpty`.
  - In the empty search state (`'No items match your search.'`), render recent search chips so users can pivot immediately.
- [ ] In `SearchResultsView`:
  - In `_submitSearch()`, call `ref.read(searchHistoryProvider.notifier).addQuery(query)`.
  - When search bar is cleared (`_activeQuery.isEmpty`), render recent search chips so the screen remains useful.
- [ ] Add integration tests in `test/search_history_ui_test.dart` validating navigation on chip tap and submission recording.
- [ ] Run `flutter test test/search_history_ui_test.dart` and `test/browse_tab_anti_slop_test.dart`.

---

### Task 4: Regression Testing, Documentation, & Commit

**Files:**
- Modify: `FEATURES_TO_ADD_OR_IMPROVE.md`

**Steps:**
- [ ] Run full test suite: `flutter test test/search_history_service_test.dart test/search_history_ui_test.dart test/search_filters_sort_test.dart`.
- [ ] Run `flutter analyze` to ensure 0 lint errors or warnings.
- [ ] Update `FEATURES_TO_ADD_OR_IMPROVE.md` marking GAP-08 as resolved with commit hash.
- [ ] Commit and push to `origin main`.

