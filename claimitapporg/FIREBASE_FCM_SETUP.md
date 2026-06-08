# Firebase Cloud Messaging (FCM) Setup — Claimit Flutter App

This covers ONLY the Flutter app (`claimitapporg/`). The web app folders are not touched.

What's already done in code (so you don't have to):
- `pubspec.yaml` → added `firebase_core`, `firebase_messaging`, `flutter_local_notifications`
- `lib/core/services/fcm_service.dart` → handles permissions, token, and shows the popup
- `lib/main.dart` → initializes Firebase + FCM on app start
- `lib/features/auth/screens/otp_screen.dart` → fires a **"✅ Login Successful"** popup right after OTP verification succeeds
- `android/app/src/main/AndroidManifest.xml` → notification permission + default channel
- `android/settings.gradle.kts` / `android/app/build.gradle.kts` → Google Services Gradle plugin wired in

You only need to do the **Firebase Console steps** and **drop in 2 config files**. Nothing else to code.

---

## 1. Create the Firebase project

1. Go to https://console.firebase.google.com → **Add project** → name it (e.g. "Claimit") → finish the wizard (Google Analytics is optional).
2. Inside the project, click the **Android icon** to register an app:
   - Android package name: `com.example.claimitapporg` (from `android/app/build.gradle.kts` → `applicationId`). **If you change this before release, update it here too.**
   - App nickname: anything, e.g. "Claimit Android"
   - Debug signing certificate SHA-1: optional for FCM (only needed for Google Sign-In/Dynamic Links)
3. Download **`google-services.json`** and place it at:
   ```
   claimitapporg/android/app/google-services.json
   ```
4. (If you also build iOS) click **Add app → iOS**, use bundle ID `com.example.claimitapporg`, download **`GoogleService-Info.plist`**, and add it to the Xcode project at:
   ```
   claimitapporg/ios/Runner/GoogleService-Info.plist
   ```
   (Open `ios/Runner.xcworkspace` in Xcode, drag the file into the `Runner` folder, check "Copy items if needed".)

That's it for the **frontend** — no API keys to paste into Dart code. The `google-services.json` / `GoogleService-Info.plist` files *are* the configuration; `Firebase.initializeApp()` reads them automatically at build time.

---

## 2. Enable Cloud Messaging

In the Firebase console: **Project settings → Cloud Messaging tab**. Firebase Cloud Messaging API (V1) is enabled by default for new projects — nothing to toggle. You'll come back to this tab to grab backend credentials (next section).

---

## 3. What goes in the BACKEND (not the Flutter app)

Your backend (`fastapi/backend/`) is what actually *sends* push notifications — e.g. "send a push to user X when their claim status changes." For that it needs to authenticate to Firebase using a **service account**, not the `google-services.json` file (that one is client-side only).

1. Firebase console → ⚙️ **Project settings → Service accounts** tab → **Generate new private key**. This downloads a JSON file like `claimit-firebase-adminsdk-xxxxx.json`.
2. **Never commit this file to git.** Store it outside the repo or as a secret, e.g.:
   - Local dev: save it somewhere like `fastapi/backend/secrets/firebase-service-account.json` and add that path to `.gitignore`
   - Production (Vercel): paste its full JSON contents into an environment variable, e.g. `FIREBASE_SERVICE_ACCOUNT_JSON`, in the Vercel project settings (and in `fastapi/backend/.env` for local dev — see `.env.example`)
3. In your FastAPI backend, install the Firebase Admin SDK and send pushes like:
   ```python
   # pip install firebase-admin
   import firebase_admin
   from firebase_admin import credentials, messaging
   import json, os

   cred = credentials.Certificate(json.loads(os.environ["FIREBASE_SERVICE_ACCOUNT_JSON"]))
   firebase_admin.initialize_app(cred)

   def send_push(device_token: str, title: str, body: str, data: dict | None = None):
       message = messaging.Message(
           notification=messaging.Notification(title=title, body=body),
           data=data or {},
           token=device_token,
       )
       return messaging.send(message)
   ```
4. **Device tokens**: the Flutter app already fetches and prints its FCM token in `FcmService.init()` (`debugPrint('🔑 FCM device token: $_fcmToken')`). You need one more backend endpoint, e.g. `POST /users/fcm-token`, to receive and store that token against the logged-in user (there's a `// TODO` marker for this in `fcm_service.dart` — just wire it to your existing `ApiClient`/`AppConstants` pattern once the endpoint exists). Then `send_push(stored_token, ...)` targets that exact device.

So, summary of "where keys go":
| Item | Where it lives | Used by |
|---|---|---|
| `google-services.json` | `claimitapporg/android/app/` | Flutter/Android app (client) |
| `GoogleService-Info.plist` | `claimitapporg/ios/Runner/` | Flutter/iOS app (client) |
| Service-account JSON / `FIREBASE_SERVICE_ACCOUNT_JSON` | Backend env var / secret (FastAPI / Vercel) — never in the Flutter repo | Backend, to *send* pushes |
| Device FCM token | Stored in your DB per user (sent from app → backend) | Backend, to target a specific device |

There is **no "API key" you paste into Dart code** for FCM — that model (legacy server key) is deprecated by Google in favor of the service-account based HTTP v1 API shown above.

---

## 4. Install & test

```bash
cd claimitapporg
flutter pub get
flutter run
```

On first launch the app will ask for notification permission (Android 13+/iOS). Then:

- **Test the "Login successful" popup** (no Firebase backend call needed — it's a local notification): log in with OTP → as soon as verification succeeds, you should see a system popup/banner: **"✅ Login Successful — You are now logged in to Claimit."** This fires from `FcmService.instance.showLoginSuccessNotification()` in `otp_screen.dart`.
- **Test a real server push**: Firebase console → **Engage → Messaging → New campaign → Notifications** → compose a title/body → under "Target" pick your app → send a test message using the FCM token printed in `flutter run`'s debug console (look for `🔑 FCM device token: ...`) via "Send test message".

---

## 5. Notes / gotchas

- Until `google-services.json` is added, the app still runs — `main.dart` wraps Firebase init in a `try/catch` and just logs a warning (`⚠️ Firebase/FCM initialization skipped`), so you won't get a crash, but no push features will work.
- Once you add `google-services.json`, the Gradle build will pick up the `com.google.gms.google-services` plugin already wired into `android/build` files and generate the Firebase config automatically — no extra Gradle edits needed.
- App's current `applicationId` is the Flutter default `com.example.claimitapporg`. Before publishing, change it (and re-register in Firebase with the new package name, downloading a fresh `google-services.json`).
