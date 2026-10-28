# TeknoyCart — Session Handover & Work Changelog
**Date:** October 28, 2026  
**Project:** TeknoyCart (CIT-U Peer-to-Peer Marketplace)  
**Target Purpose:** Complete audit and setup log to replicate or sync with your main desktop.

---

## 1. Executive Summary of What Was Accomplished
During this session, we accomplished the following core tasks:
1. **Local Android SDK Installation & Toolchain Repair:** Set up a clean, space-free Android SDK (`C:\Android\Sdk`) with Java 17 and accepted all SDK licenses.
2. **Gradle OutOfMemory Fix:** Resolved Gradle `OutOfMemoryError: Metaspace` by increasing heap and metaspace thresholds in `android/gradle.properties`.
3. **Theme Default & Persistence Bug Fix:** Resolved the issue where the app defaulted to Dark Mode on mobile phones and failed to remember when switched to Light Mode.
4. **Release APK Compilation & Distribution:** Successfully built the production release APK (`77.9 MB`) with compile-time Supabase defines and placed copies in the root for instant phone installation.
5. **Clean Git Commit & Push:** Updated `.gitignore`, protected credentials from being committed, staged only necessary source files, and pushed commit `737464c` to GitHub `origin/main`.
6. **IT411 Capstone Announcement Analysis:** Created an actionable breakdown and pre-consultation checklist for the upcoming adviser verification presentation.

---

## 2. Technical Details & Code Changes

### A. Theme Default & Android Persistence Fix
* **Target File:** [`TeknoyCart/lib/core/providers/theme_provider.dart`](file:///c:/Users/HP%20Laptop%2015s/.gemini/antigravity-ide/scratch/TeknoyCart_Project/TeknoyCart/lib/core/providers/theme_provider.dart)
* **Problem 1 (Why it was dark on phone but light in browser):**  
  The app originally read `WidgetsBinding.instance.platformDispatcher.platformBrightness`. On PC/Browser, Windows reported Light Mode. On Android phones with system dark mode enabled, it reported Dark Mode.
* **Problem 2 (Why it reverted to dark on restart):**  
  `FlutterSecureStorage` was instantiated without `AndroidOptions(encryptedSharedPreferences: true)`. On modern Android (API 29+), raw KeyStore access failed or cleared upon process death, and silent `catch (_) {}` blocks swallowed the error.
* **Solution Applied:**  
  ```dart
  class ThemeModeNotifier extends StateNotifier<ThemeMode> {
    static const _storageKey = 'teknoycart_theme_mode';
    static const FlutterSecureStorage _storage = FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
    );

    ThemeModeNotifier({ThemeMode initialMode = ThemeMode.light}) : super(initialMode) {
      _loadTheme();
    }
    // ...
  }
  ```

---

### B. Gradle Build Configuration & Memory Optimization
* **Target File:** [`TeknoyCart/android/gradle.properties`](file:///c:/Users/HP%20Laptop%2015s/.gemini/antigravity-ide/scratch/TeknoyCart_Project/TeknoyCart/android/gradle.properties)
* **Problem:** Gradle failed during native AOT / CMake compilation with `java.lang.OutOfMemoryError: Metaspace` because it was constrained to `-XX:MaxMetaspaceSize=384m` and `-Xmx1536m`.
* **Solution Applied:**
  ```properties
  org.gradle.jvmargs=-Xmx4096m -XX:MaxMetaspaceSize=1024m
  org.gradle.parallel=true
  android.useAndroidX=true
  android.newDsl=false
  android.builtInKotlin=false
  ```

---

### C. Android SDK Setup on Windows (For your Main Desktop)
If your main desktop does not yet have the Android SDK configured:
1. Ensure Java 17 JDK is installed (e.g. `Microsoft jdk-17`).
2. Install Android Command-Line Tools to a path **WITHOUT spaces** (e.g., `C:\Android\Sdk`):
   ```powershell
   # In PowerShell (Admin)
   New-Item -ItemType Directory -Force -Path "C:\Android\cmdline-tools"
   curl.exe -L "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip" -o "$env:TEMP\cmdline-tools.zip"
   Expand-Archive -Path "$env:TEMP\cmdline-tools.zip" -DestinationPath "$env:TEMP\cmdline-extract" -Force
   Move-Item -Path "$env:TEMP\cmdline-extract\cmdline-tools" -Destination "C:\Android\Sdk\cmdline-tools\latest" -Force
   ```
3. Install required platform tools & accept licenses:
   ```powershell
   & "C:\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat" "platform-tools" "build-tools;34.0.0" "platforms;android-34" "platforms;android-36"
   $inputY = ("y`n" * 20)
   $inputY | & "C:\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat" --licenses
   ```
4. Configure Flutter:
   ```powershell
   flutter config --android-sdk "C:\Android\Sdk"
   [System.Environment]::SetEnvironmentVariable('ANDROID_HOME', "C:\Android\Sdk", 'User')
   ```

---

### D. Building the Release APK
To rebuild the release APK at any time on your main desktop:
```bash
cd TeknoyCart
flutter build apk --release --dart-define-from-file=.env.json
```
Output path:
- `build/app/outputs/flutter-apk/app-release.apk`

---

### E. Git Repository Status
* **Remote:** `https://github.com/VeryLuckyMe/TeknoyCart.git`
* **Branch:** `main`
* **Pushed Commits:**
  - [`737464c`](https://github.com/VeryLuckyMe/TeknoyCart/commit/737464c): `feat(theme): default to light mode, persist with encryptedSharedPreferences, and tune build memory`
  - [`924c413`](https://github.com/VeryLuckyMe/TeknoyCart/commit/924c413): `fix(auth): harden password recovery deep-link, in-app link verification, and inline modal error UI`
  - [`6eb255c`](https://github.com/VeryLuckyMe/TeknoyCart/commit/6eb255c): `refactor(auth): simplify forgot password confirmation modal and remove debug copy`
  - [`a75c2f0`](https://github.com/VeryLuckyMe/TeknoyCart/commit/a75c2f0): `fix(db): add hotfix migration for atomic checkout inventory search_path`
* **Ignored Artifacts:** Added `*.apk` and `*.aab` to `.gitignore`. No credentials or large binary files were leaked to git.
* **To pull on your main desktop next week:**
  ```bash
  git pull origin main
  ```

---

### F. New Skills Installed for Production Readiness, Benchmarks & Gap Auditing
Added 3 dedicated expert skills to `.agents/skills/` and registered them in `AGENTS.md` and `GEMINI.md`:
1. **`flutter-production-readiness`**:
   - Master checklist for crash boundaries (`ErrorWidget.builder`, `PlatformDispatcher.instance.onError`), offline state resilience, memory leak prevention, and release build hygiene.
2. **`performance-benchmark-profiling`**:
   - Quantitative profiling framework specifically generating the **Response Time, Throughput, Frame Rate (60 FPS), and Error Rate** tables required by IT411 Section C.
3. **`system-architecture-gap-auditor`**:
   - E-commerce & marketplace domain gap analysis engine. Identifies missing business logic, unhandled order states, transaction dead-ends, fraud vulnerabilities, and capstone thesis requirements.


---

### G. Forgot Password `localhost:3000` Redirect Fix & In-App Recovery Hardening
* **Root Cause:** In [`auth_password_sheets.dart`](file:///c:/Users/HP%20Laptop%2015s/.gemini/antigravity-ide/scratch/TeknoyCart_Project/TeknoyCart/lib/features/auth/views/widgets/auth_password_sheets.dart), `resetPasswordForEmail` requests `redirectTo: 'teknoycart://login-callback'`. Because `teknoycart://login-callback` was not yet in Supabase Dashboard's **Redirect URLs** allowlist, Supabase rejected the custom scheme and fell back to the default **Site URL** (`http://localhost:3000`).
* **Supabase Dashboard Fix Applied:** Added `teknoycart://login-callback` and `teknoycart://**` under **Authentication → URL Configuration → Redirect URLs** in Supabase (`chmtvasbhkbrvydbajnd`).
* **Flutter App Hardening Applied & Rebuilt into `TeknoyCart.apk` (Commit `924c413`):**
  - [`auth_password_sheets.dart`](file:///c:/Users/HP%20Laptop%2015s/.gemini/antigravity-ide/scratch/TeknoyCart_Project/TeknoyCart/lib/features/auth/views/widgets/auth_password_sheets.dart):
    1. Replaced the hidden bottom `SnackBar` inside `showSetNewPasswordSheet` with a high-visibility **inline error banner inside the modal** above the `Update Password` button, added an explicit `New Password (12+ characters)` label, a loading spinner, and a `Cancel & Return to Sign In` button.
    2. Added Step 2 ("Verify Password Reset") so users can either tap the email deep-link OR paste a `localhost:3000` URL / email reset link / 6-digit recovery code directly in the app.
  - [`main.dart`](file:///c:/Users/HP%20Laptop%2015s/.gemini/antigravity-ide/scratch/TeknoyCart_Project/TeknoyCart/lib/main.dart) & [`splash_view.dart`](file:///c:/Users/HP%20Laptop%2015s/.gemini/antigravity-ide/scratch/TeknoyCart_Project/TeknoyCart/lib/features/splash/splash_view.dart): Captured `AuthChangeEvent.passwordRecovery` at cold start so [`SplashView`](file:///c:/Users/HP%20Laptop%2015s/.gemini/antigravity-ide/scratch/TeknoyCart_Project/TeknoyCart/lib/features/splash/splash_view.dart#L30-L35) routes to [`AuthGateView`](file:///c:/Users/HP%20Laptop%2015s/.gemini/antigravity-ide/scratch/TeknoyCart_Project/TeknoyCart/lib/features/auth/views/auth_gate_view.dart#L26-L31) to open the **Set New Password** sheet instead of bypassing it.
  - [`AndroidManifest.xml`](file:///c:/Users/HP%20Laptop%2015s/.gemini/antigravity-ide/scratch/TeknoyCart_Project/TeknoyCart/android/app/src/main/AndroidManifest.xml): Added explicit `<data android:scheme="teknoycart" android:host="login-callback"/>` intent-filter entry.
---

### H. Checkout `relation "inventory" does not exist` Error & Database Function Fix
* **Issue Encountered During Presentation:** When confirming a meetup deal on checkout, PostgreSQL failed with:
  `Checkout failed: PostgrestException(message: relation "inventory" does not exist, code: 42P01, details: Not Found, hint: null)`
* **Root Cause Identified:** The database function `public.place_orders_atomic` had `SET search_path = ''` (empty search path). When PostgreSQL tried to evaluate the Row Level Security (RLS) policies on `inventory` (specifically `WHERE pv.variant_id = inventory.variant_id`), PostgreSQL could not find table `inventory` because the schema was not in the search path.
* **Fix Created ([`fix_checkout_inventory.sql`](file:///c:/Users/HP%20Laptop%2015s/.gemini/antigravity-ide/scratch/TeknoyCart_Project/TeknoyCart/fix_checkout_inventory.sql)):**
  1. Updated `place_orders_atomic` with `SET search_path = public, pg_temp`.
  2. Changed `JOIN public.inventory` to `LEFT JOIN public.inventory` with auto self-healing `ON CONFLICT (variant_id) DO NOTHING`.
  3. Added broad RLS policies on `public.inventory` allowing authenticated checkout transactions to read and update reserved stock.

---

### I. Meetup Scheduling `Exception: Error 403` & Supabase RPC Resilience
* **Issue Encountered During Presentation:** When seller tapped **"Schedule Meetup & Notify Buyer"** on Order #EEC7684E, a red SnackBar appeared:
  `Failed to schedule: Exception: Error 403`
* **Root Cause Identified:**
  1. In [`order_detail_view.dart`](file:///c:/Users/HP%20Laptop%2015s/.gemini/antigravity-ide/scratch/TeknoyCart_Project/TeknoyCart/lib/features/checkout/views/order_detail_view.dart), `accept` and `cancel` had dedicated Supabase RPCs (`accept_order_as_seller` / `cancel_order_as_seller`), so they succeeded immediately without touching Spring Boot.
  2. However, `schedule` (and `verify-handoff` / `confirm-receipt`) called Spring Boot on Render via `_callSpringApi('schedule')`.
  3. Spring Security rejected the request with HTTP 403 Forbidden because the app sends a Supabase HS256 JWT, while Spring Boot expected a backend-issued JWT with a different `jwt.secret` (or was unauthenticated after password reset).
* **Fix Applied:**
  1. Created [`fix_meetup_schedule_and_rpcs.sql`](file:///c:/Users/HP%20Laptop%2015s/.gemini/antigravity-ide/scratch/TeknoyCart_Project/fix_meetup_schedule_and_rpcs.sql):
     - Immediately advances Order #EEC7684E to `MEETUP_SCHEDULED` with OTP `582914`.
     - Implemented `schedule_meetup_as_seller`, `verify_handoff_as_seller`, and `confirm_receipt_as_buyer` RPCs with `SECURITY DEFINER` and `search_path = public, pg_temp`.
     - Added Row Level Security (RLS) UPDATE policy allowing buyers and sellers to mutate their own orders directly in Supabase.
  2. Updated [`order_detail_view.dart`](file:///c:/Users/HP%20Laptop%2015s/.gemini/antigravity-ide/scratch/TeknoyCart_Project/TeknoyCart/lib/features/checkout/views/order_detail_view.dart) with three-tier execution hierarchy: Primary Supabase RPC → Direct Supabase DB update → Spring Boot fallback.
