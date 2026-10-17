# TeknoyCart 🛒 (Mobile App)

A modern, high-fidelity mobile application for the **TeknoyCart** campus e-commerce platform. Built with **Flutter**, **Riverpod** for robust state management, and fully integrated with a **Supabase** backend.

---

## 🚀 Getting Started

Follow these steps to run the Flutter mobile app on your local machine.

### 📋 Prerequisites

Ensure you have the following installed:
- **Flutter SDK** (v3.19+ recommended): [Install Flutter](https://docs.flutter.dev/get-started/install)
- An Editor/IDE (VS Code with Flutter extension, or Android Studio)
- Google Chrome (if testing in web browser) or a booted Mobile Emulator (Android/iOS)

---

## 🛠️ Installation & Setup

1. Open your terminal and navigate to the project directory:
   ```bash
   cd TeknoyCart
   ```

2. Fetch all required packages and dependencies:
   ```bash
   flutter pub get
   ```

3. Ensure you have no configuration issues by running a doctor check:
   ```bash
   flutter doctor
   ```

---

## 🏃 Running the App

### ⚙️ Required configuration flags

There are no hardcoded credentials: every run/build must supply the environment with `--dart-define` flags. A run without them fails fast with a clear startup error.

```bash
flutter run -d chrome --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon key> --dart-define=BACKEND_URL=https://<backend-host>/api
```

> [!TIP]
> Add `--dart-define=DEMO_MODE=true` to serve bundled sample products/reviews for offline demos. Never enable it in production builds.

Append the `--dart-define` flags to every command below.

You can run TeknoyCart on various targets:

### Option A: Local Web Server (Recommended for fast UI testing)
Runs the web version on a fixed port (`8080`) which is pre-configured for responsive viewing:
```bash
flutter run -d web-server --web-port=8080
```
Then open `http://localhost:8080` in your browser.

### Option B: Chrome Browser
```bash
flutter run -d chrome
```

### Option C: Mobile Emulator / Device
Connect your physical device or start an emulator, then execute:
```bash
flutter run
```

---

## 🔑 Demo & Presentation Accounts

The Supabase Auth database has been pre-seeded with accounts for capstone presentations. Ask the project lead for the current credentials — they are intentionally not stored in this repository.

> [!IMPORTANT]
> **Domain restriction enforced**:
> The application and database triggers restrict signups and logins **strictly** to institutional CIT email addresses (`@cit.edu`).

---

## 📂 Project Structure

A quick guide to the main directories inside `lib/`:
```
lib/
├── core/
│   ├── supabase_client.dart   # Supabase client bootstrap (reads --dart-define flags)
│   ├── theme.dart             # Curated CIT Maroon theme values
│   └── responsive_frame.dart  # Mobile mock framing for desktop web previews
└── features/
    ├── auth/
    │   ├── providers/         # Riverpod Authentication states
    │   └── views/             # Login, Register, institutional Gate Views
    └── feed/
        └── views/             # Product discovery, home screens
```

---

## 🌐 Supabase Integration

The backend is completely serverless and talks directly to Supabase.

- **Credentials**: provided at build time via `--dart-define=SUPABASE_URL` / `--dart-define=SUPABASE_ANON_KEY` (see the Running section above). There are **no hardcoded fallbacks**; a missing configuration fails fast at startup. Never commit real keys.
- **Data honesty**: the app renders only what Supabase returns. When the service is unreachable it shows cached data or an explicit offline state — it never fabricates listings (bundled samples require `DEMO_MODE=true`).
