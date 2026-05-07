# Claimit — Build & Run Guide

This document explains exactly how to bring the project up on Android, iOS,
and the web after the recent fixes.

---

## 1. Backend (FastAPI + MongoDB)

```powershell
cd backend
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
python run.py
```

The API will be served at **http://localhost:8001** with Swagger docs at
http://localhost:8001/docs.

The MongoDB Atlas connection string is read from `backend/.env`.

---

## 2. Flutter app

### 2.1 Required tools

- Flutter 3.19 or newer (run `flutter --version`)
- Android Studio with **Android SDK 34** and **Build Tools 34.0.0**
- For iOS: macOS + Xcode 15+ + CocoaPods (`sudo gem install cocoapods`)

### 2.2 First-time setup on Windows

The most recent build failure was caused by:
- A corrupt Gradle 8.14 transforms cache in `%USERPROFILE%\.gradle\caches\8.14`
- AGP 9 / Kotlin 2.2 incompatibility with `image_picker_android` and
  `file_picker`
- Missing `INTERNET` permission in `AndroidManifest.xml`

We have already fixed every config file in the repo. To recover the
machine-level state, **run the recovery script once**:

```powershell
cd E:\aroganamproject\claimit-app\claimit
.\fix_build.bat
```

This will:
1. `flutter clean`
2. Delete the project's build outputs and `.dart_tool`
3. Delete the corrupted Gradle 8.14 transforms cache
4. Re-download `image_picker_android` / `file_picker` /
   `flutter_secure_storage`
5. Run `flutter pub get`
6. Pre-download Gradle 8.10.2 wrapper distribution

### 2.3 Running

| Target | Command |
|---|---|
| Web (already worked for you) | `flutter run -d chrome` |
| Android emulator | `flutter run -d emulator-5554` |
| Physical Android | `flutter run -d <device-id>` |
| iOS simulator | `cd ios && pod install && cd .. && flutter run -d <ios-sim>` |

### 2.4 If you run the backend on a **physical** phone

Edit `lib/core/constants/app_constants.dart`:

```dart
// static const String baseUrl = 'http://10.0.2.2:8001'; // Android emulator
   static const String baseUrl = 'http://192.168.X.Y:8001'; // your PC's LAN IP
```

Find your IP with `ipconfig` (Windows) or `ifconfig` (Mac/Linux).
Make sure the PC firewall allows incoming connections on port 8001.

---

## 3. What was actually wrong (and how it's fixed)

| Symptom | Root cause | Fix |
|---|---|---|
| Works on Chrome, fails on mobile | `AndroidManifest.xml` had no `<uses-permission android:name="android.permission.INTERNET"/>` | Added INTERNET, ACCESS_NETWORK_STATE, CAMERA, READ_MEDIA_* permissions |
| "Cleartext HTTP not permitted" on Android 9+ | Android blocks `http://` traffic by default | Added `android:usesCleartextTraffic="true"` and `network_security_config.xml` whitelisting `10.0.2.2`/localhost |
| `Could not read workspace metadata from .gradle/caches/8.14/transforms/...` | Corrupted Gradle cache from a half-completed previous build | `fix_build.bat` deletes the cache; pinned wrapper to **8.10.2** to avoid the affected version |
| `Configuration with name 'implementation' not found` (in `image_picker_android`) | `image_picker: ^1.1.3` + Kotlin 2.2.20 + AGP 8.11 / Gradle 8.14 mismatch | Pinned `image_picker: 1.0.7`, `file_picker: 8.0.0+1`, `flutter_secure_storage: 9.2.2`; pinned **AGP 8.7.0** + **Kotlin 1.9.24** |
| `Starting AGP 9+, only the new DSL...` warning | AGP 9 deprecates the old plugin DSL | Added `android.newDsl=false` in `gradle.properties` |
| iOS "App Transport Security blocked the resource" | `Info.plist` had no ATS exceptions | Added `NSAllowsArbitraryLoads`, `NSAllowsLocalNetworking`, plus camera/photo permission strings |
| Flutter web 401 redirect loop | `validateStatus` in Dio threw on every 4xx | `ApiClient.validateStatus = status < 500`; providers now read body for error detail |
| Login flicker before token check | `isInitializing` flag missing | Added `isInitializing` in `AuthProvider` and gated splash on it |

---

## 4. Quick smoke test

Once the app is running:

1. Open it — you should see the Splash → Onboarding screens.
2. Tap **Get Started**, fill the register form (any 10-digit phone, any email).
3. On the OTP screen enter **`123456`** — that's the static demo OTP defined
   in `backend/.env` (`STATIC_OTP=123456`).
4. You should land on the dashboard with empty stats. File a new claim, attach
   any file, and watch the timeline + notifications populate.

If anything fails the bottom of the screen will show the backend's `detail`
message (e.g. *"Phone number already registered"*).

---

## 5. Next steps when going to production

- Add a real SMS provider in `backend/app/utils/otp.py:send_otp_sms` (Twilio,
  MSG91, etc.).
- Replace the wide-open CORS `allow_origins=["*"]` in `backend/app/main.py`.
- Re-enable `android:usesCleartextTraffic="false"` and serve the API over HTTPS.
- Add real KYC validators (Aadhar/PAN format) and Razorpay/Stripe payments.
