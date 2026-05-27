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

The Supabase Auth database has been pre-seeded with specialized accounts for your capstone presentation. You can log in using:

### 🎓 CIT Representative Account (Auto-Login)
- **Email**: `capstone.team45@cit.edu`
- **Password**: `teknoycart2026`

### 🛒 Wildcat Buyer Account
- **Email**: `wildcat.buyer@my.cit.edu`
- **Password**: `teknoycart2026`

> [!IMPORTANT]
> **Domain Restriction Enforced**: 
> The application and database triggers restrict signups and logins **strictly** to institutional CIT email domains:
> - `@cit.edu`
> - `@my.cit.edu`

---

## 📂 Project Structure

A quick guide to the main directories inside `lib/`:
```
lib/
├── core/
│   ├── supabase_client.dart   # Contains Supabase URL & Anon Key configurations
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
The backend is completely serverless. The endpoint URL and Anon Keys are already configured out of the box in `lib/core/supabase_client.dart`. You do **not** need to set up any `.env` file to start developing or running the project.
