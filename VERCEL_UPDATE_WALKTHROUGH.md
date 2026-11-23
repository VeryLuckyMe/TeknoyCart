# TeknoyCart — Vercel Testing Deployment Walkthrough

This guide explains how to pull the latest app updates from GitHub, rebuild the Flutter Web application, and deploy the updated version to Vercel for survey and user testing.

---

## Prerequisites

1. **PowerShell** or **Command Prompt** open in the project root:
   ```
   C:\Users\valme\OneDrive\Desktop\Projects\TeknoyCart\TeknoyCart
   ```
2. Your `.env.json` file in the project root containing your Supabase credentials.

---

## Standard Update Workflow (3 Steps)

### Step 1: Pull the Latest Code from GitHub

In your PowerShell terminal, pull the latest commits:
```powershell
git pull origin main
```

*(If Git complains about local modified files or OneDrive file locks, run `git stash` first, then `git pull origin main`, then `git stash pop`)*.

---

### Step 2: Rebuild Flutter for Web

Run the Flutter web build command with the environment configuration:
```powershell
flutter build web --release --dart-define-from-file=.env.json
```

**What this does:**
* Compiles your latest Dart code into optimized JavaScript in `build/web/`.
* Automatically includes `web/vercel.json` (which preserves SPA routes so page refreshes don't return 404).

---

### Step 3: Deploy to Vercel Production

Navigate into the output directory and deploy directly to production:
```powershell
cd build/web
npx vercel --prod
```

Once the upload completes (typically 10–20 seconds), Vercel will output your live URL:
```
✅  Production: https://teknoycart-testing-...vercel.app
```

---

## Quick One-Liner Script

To do everything in a single command, you can run:

```powershell
flutter build web --release --dart-define-from-file=.env.json; if ($?) { cd build\web; npx vercel --prod; cd ..\.. }
```

---

## Alternative: 30-Second Netlify Drop (Zero-CLI Fallback)

If Vercel CLI ever asks for authentication or throws a network timeout:

1. Run `flutter build web --release --dart-define-from-file=.env.json`.
2. Open **[app.netlify.com/drop](https://app.netlify.com/drop)** in your web browser.
3. Open Windows File Explorer and navigate to:
   ```
   C:\Users\valme\OneDrive\Desktop\Projects\TeknoyCart\TeknoyCart\build
   ```
4. Drag and drop the **`web`** folder into the browser window.
5. Netlify will immediately publish a live HTTPS testing URL.

---

## Tester Device Refresh Tips

When survey participants are testing on iOS Safari or Android Chrome:

* **Hard Refresh:** If a participant already has the app open on their phone, they should do a hard refresh (pull down on Safari, or tap Settings $\rightarrow$ Clear Cache) so the phone fetches the new `main.dart.js` rather than using cached assets.
* **Home Screen PWA:** If testers added the app to their iPhone home screen ("Add to Home Screen"), they should close the app from the iOS app switcher and reopen it to allow the service worker to update.
* **Backend Status:** Ensure your Render backend is awake by loading `https://teknoycart-backend.onrender.com/api` once before participants begin testing.
