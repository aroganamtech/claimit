# Claimit — Launch Readiness Audit

**Date:** 7 September 2026
**Scope:** Flutter app (`claimitapporg`), app backend (`fastapi/backend`), web backend
(`claimit_web_org/fastapi/backend`), web frontend, Android build configuration.

**Verdict: not ready to launch.** Three blockers, all security. The app's UI, features and
build configuration are in good shape — the problems are in authentication and data
protection, and two of the three can be fixed in under an hour.

---

## BLOCKER 1 — Anyone can log in as any user

**Severity: critical. Fix before launch.**

`fastapi/backend/app/utils/otp.py:56`

```python
async def verify_otp(phone: str, otp: str) -> bool:
    """Verify OTP from database. Uses static OTP for demo."""
    # Static OTP for demo/development
    if otp == settings.static_otp:
        return True
```

The same bypass exists in the web backend at
`claimit_web_org/fastapi/backend/utils/auth.py:36` (`UNIVERSAL_OTP`).

**What this means.** Entering the static OTP logs you in as *any* account — any customer, any
merchant, any admin. There is no debug flag, no environment check, no rate limit in front of
it. It is active in production right now.

Both values are set in `.env` (7 characters, not the `123456` default), but **both `.env`
files are committed to git** — see Blocker 2. So the bypass code is public and the value to
use with it is public.

**Fix.** Delete the bypass, or gate it so it cannot run in production:

```python
# app/utils/otp.py
async def verify_otp(phone: str, otp: str) -> bool:
    # Test bypass — development only. In production this branch must never run.
    if settings.environment != "production" and otp == settings.static_otp:
        return True
    ...
```

Add `environment: str = "production"` to `config.py` so the *safe* value is the default and a
missing env var fails closed, not open. Apply the same change to the web backend.

---

## BLOCKER 2 — Production credentials are committed to git

**Severity: critical. Fix before launch.**

Tracked in the repository:

| File | What it exposes |
|---|---|
| `claimit.pem` | **SSH private key to the production server** — full root-capable access |
| `fastapi/backend/.env` | `SECRET_KEY` (JWT signing), `TWILIO_AUTH_TOKEN`, `SMTP_PASSWORD`, `MONGODB_URL`, `STATIC_OTP` |
| `claimit_web_org/fastapi/backend/.env` | `SECRET_KEY`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `ADMIN_USER`, `ADMIN_PASS`, `UNIVERSAL_OTP` |
| `claimit_web_org/frontend/.env.local`, `.env.production` | frontend config |
| `claimitapporg/.env` | Google / Facebook OAuth client IDs |
| `claimitapporg/android/app/google-services.json` | Firebase config (lower risk, but tracked) |

`.gitignore` already lists all of these — but **`.gitignore` does not untrack files that were
committed before the rule was added.** They are still in the repository and in its history.

With the JWT `SECRET_KEY`, an attacker forges a valid token for any user without needing a
password or OTP at all. With `claimit.pem`, they have the server.

**Fix, in order:**

1. **Rotate everything first** — assume all of it is compromised:
   - new EC2 key pair (`claimit.pem`), remove the old public key from `~/.ssh/authorized_keys`
   - new `SECRET_KEY` on both backends (this logs everyone out — expected)
   - regenerate the Twilio auth token
   - new AWS IAM access key, delete the old one
   - new SMTP password, new `ADMIN_PASS`
   - new `STATIC_OTP` / `UNIVERSAL_OTP` (or remove them entirely, per Blocker 1)

2. **Untrack the files** (keeps them on disk, stops future commits):

```powershell
cd F:\my_project_git\claimit
git rm --cached claimit.pem fastapi/backend/.env claimit_web_org/fastapi/backend/.env claimitapporg/.env claimit_web_org/frontend/.env.local claimit_web_org/frontend/.env.production
git commit -m "Stop tracking secrets; rotated separately"
```

3. History still contains them. If the repo is private and only you have access, rotation is
   enough. If it is public or shared, the history needs rewriting (`git filter-repo`) or the
   repo recreating.

---

## BLOCKER 3 — The app talks to the API over plain HTTP

**Severity: high. Fix before launch.**

`claimitapporg/lib/core/constants/app_constants.dart:7`

```dart
static const String baseUrl = 'http://16.170.110.232:8001';
```

No TLS, and a raw IP rather than a hostname. Every OTP, JWT, phone number, email and address
travels in clear text. Anyone on the same café or airport wifi can read them, and can modify
responses.

There is also a build risk: **no `usesCleartextTraffic="true"` and no network security config
exists in any manifest.** Android blocks cleartext HTTP by default for apps targeting API 28+,
which this app does. Debug builds are permitted by Flutter's tooling, which is why testing
works — but the release build on Play Store may be unable to reach the API at all.

**Verify this before anything else:** install the release AAB (not a debug build) on a phone
and try to log in. If it hangs or fails, the app currently in review is non-functional.

**Fix.** Put the API behind a domain with a TLS certificate — you already own `claimitapp.in`.
Point e.g. `api.claimitapp.in` at the server, terminate TLS with nginx + Let's Encrypt, then:

```dart
static const String baseUrl = 'https://api.claimitapp.in';
```

Do **not** work around this by adding `usesCleartextTraffic="true"`. That makes the release
build work while leaving every user's data readable in transit, and Play Store's data-safety
declaration would be inaccurate.

---

## Fixed during this session

| Issue | Where | Impact |
|---|---|---|
| Explore Claimit row overflowed 8px | `dashboard_screen.dart` | Tile width was computed from screen width assuming an 18px arrow gutter while the arrow was 22px. Broken on **13 of 19** common device widths. Now measured with `LayoutBuilder` — cannot overflow at any width. |
| "All" category tile overflowed 8px | `dashboard_screen.dart` | Hardcoded a 48px icon while the row reserved `iconSize + 34` from the shared sizing function (38px). Broken on **12 of 19** widths. Now reads the same function as its neighbours. |
| 6 crash-on-restore routes | `app_router.dart` | `state.extra as ShopItem` etc. with no guard. When Android kills the app in the background and the user returns, GoRouter restores the route but `extra` is gone — red screen crash. Now redirect to a sensible screen. Affected `/shop-detail`, `/deal-detail`, `/classified/zone`, `/classified/detail`, `/redeem-loading`, `/redeem-eligibility`. |

---

## Should fix, not blocking

1. **Advertiser form is out of date.** It still shows "Publish today" and a date picker; the
   backend now ignores both and uses the Friday–Thursday cycle. An advertiser can pay
   expecting to go live today and won't, with nothing explaining why.
   Wire the form to `GET /advertiser/ad-cycle` and show its `message`.

2. **5 brand deals have no pincode** — India Mart, Chellian Super Stores, Preethi, Usha,
   Shoppers Stop. Invisible to the radius search until set.

3. **`responsive.dart` has 6 compile errors** (`conflicting_static_and_instance`). Harmless
   today because nothing imports it — but it will break the build the moment someone does.
   Delete the file or fix the duplicate members.

4. **`test/widget_test.dart` references `MyApp`, which no longer exists.** Not part of the app
   build, but `flutter test` fails.

5. **`lib/test_image.dart`** is a development scratch file shipped inside `lib/`. Remove it.

6. **Duplicate `signingConfig` line** in `android/app/build.gradle.kts` — the debug line is
   immediately overwritten by the release line, so signing is correct, but delete the dead line
   and its misleading TODO comment.

7. **17 Columns built entirely from hardcoded pixel heights** (Reelz, Search, Select, Bill
   Reader). None are erroring because they sit in scrollable areas rather than fixed-height
   rows. They are the same shape as the two bugs fixed above and will overflow if anyone puts
   one in a constrained box. Worth converting to measured sizing over time.

---

## Confirmed healthy

- **Release signing** uses a real keystore, with `isMinifyEnabled` and `isShrinkResources` on.
- **No hardcoded API keys or tokens** anywhere in the Flutter or React source.
- **Every `Image.network` has an `errorBuilder`** — a broken image URL cannot crash a screen.
- **Permissions are minimal and justified**: internet, notifications, camera, location, audio.
- Backend healthy: service `active`, no errors in the log, 2dsphere indexes on all five
  collections, 614/614 shops located, Open Now readable on 613/614.

---

## Recommended order

1. Verify the release build can actually reach the API over HTTP (Blocker 3's build risk). If
   it cannot, the version in review is broken and must be replaced regardless.
2. Remove the OTP bypass (Blocker 1) — under an hour, both backends.
3. Rotate every credential and untrack the secrets (Blocker 2).
4. Set up `api.claimitapp.in` with TLS and switch `baseUrl` (Blocker 3).
5. Rebuild, retest, resubmit.

Items 2 and 3 are backend-only and need no new app build. Items 1 and 4 do.
