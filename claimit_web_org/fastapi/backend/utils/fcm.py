"""
Firebase Cloud Messaging (push notifications) helper — web-backend copy.

Mirrors fastapi/backend/app/utils/fcm.py (the main app backend) so both
backends can push real system notifications, not just write an in-app DB row.
Without this, anything the admin website does (approve/reject a bill review,
reply to feedback, etc.) only shows up if the user happens to open the app —
it never reaches them while the app is closed/backgrounded.

Config (set in this backend's own .env — same values as the app backend uses):
    FIREBASE_SERVICE_ACCOUNT_PATH=secret/firebase-service-account.json
    # or, on platforms with no persistent disk:
    FIREBASE_SERVICE_ACCOUNT_JSON={"type": "service_account", ...}
    FIREBASE_PROJECT_ID=your-project-id   # optional, only if not in the key file

Tokens live in claimit_db.fcm_tokens — the SAME shared collection the main
app backend writes to when a device registers — so nothing on the
Flutter/client side needs to change for this to work.
"""

import asyncio
import json
import os
from typing import Iterable, Optional

from database import app_db

_firebase_app = None
_init_attempted = False
_init_lock = asyncio.Lock()


def _build_credentials():
    from firebase_admin import credentials

    raw_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "")
    if raw_json:
        return credentials.Certificate(json.loads(raw_json))

    path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH", "")
    if path:
        if not os.path.isabs(path):
            # Resolve relative to this backend's root (utils/fcm.py -> backend/).
            backend_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
            path = os.path.join(backend_root, path)
        if os.path.isfile(path):
            return credentials.Certificate(path)
        print(f"⚠️  FCM (web backend): service account file not found at {path}")
        return None

    return None


async def _ensure_initialized():
    global _firebase_app, _init_attempted

    if _firebase_app is not None or _init_attempted:
        return _firebase_app

    async with _init_lock:
        if _firebase_app is not None or _init_attempted:
            return _firebase_app

        _init_attempted = True
        try:
            import firebase_admin

            cred = _build_credentials()
            if cred is None:
                print("⚠️  FCM (web backend): no service account configured — push "
                      "notifications disabled (set FIREBASE_SERVICE_ACCOUNT_PATH or "
                      "FIREBASE_SERVICE_ACCOUNT_JSON in .env)")
                return None

            project_id = os.getenv("FIREBASE_PROJECT_ID", "")
            options = {"projectId": project_id} if project_id else None
            _firebase_app = (firebase_admin.initialize_app(cred, options)
                              if options else firebase_admin.initialize_app(cred))
            print("✅ Firebase Admin SDK initialized (web backend) — push notifications enabled")
        except ImportError:
            print("⚠️  firebase-admin package not installed. Run: pip install firebase-admin")
        except Exception as exc:  # noqa: BLE001 — never let push setup crash the API
            print(f"⚠️  FCM (web backend) initialization failed: {exc}")

    return _firebase_app


async def send_push_to_tokens(
    tokens: Iterable[str],
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> list[str]:
    """
    Send a push to a raw list of FCM device tokens.
    Returns the subset of tokens that were rejected as invalid/unregistered.
    Safe to call even if Firebase isn't configured (no-ops, returns []).
    """
    tokens = [t for t in tokens if t]
    if not tokens:
        return []

    app = await _ensure_initialized()
    if app is None:
        return []

    try:
        from firebase_admin import messaging
    except ImportError:
        return []

    str_data = {str(k): str(v) for k, v in (data or {}).items()}

    message = messaging.MulticastMessage(
        notification=messaging.Notification(title=title, body=body),
        data=str_data,
        tokens=tokens,
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(channel_id="claimit_default_channel"),
        ),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(aps=messaging.Aps(sound="default"))
        ),
    )

    def _send():
        return messaging.send_each_for_multicast(message)

    try:
        response = await asyncio.to_thread(_send)
    except Exception as exc:  # noqa: BLE001
        print(f"⚠️  FCM (web backend) send failed: {exc}")
        return []

    invalid_tokens: list[str] = []
    for idx, result in enumerate(response.responses):
        if result.success:
            continue
        code = getattr(getattr(result, "exception", None), "code", "")
        if code in ("UNREGISTERED", "INVALID_ARGUMENT", "NOT_FOUND"):
            invalid_tokens.append(tokens[idx])

    if invalid_tokens:
        print(f"🧹 FCM (web backend): pruning {len(invalid_tokens)} invalid token(s)")

    return invalid_tokens


async def send_push_to_user(
    user_id: str,
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> None:
    """
    Look up every device token registered for `user_id` in claimit_db.fcm_tokens,
    push to all of them, and prune any the SDK reports as dead.
    Fully best-effort / non-throwing — a push failure must never break an admin action.
    """
    try:
        cursor = app_db["fcm_tokens"].find({"user_id": user_id})
        docs = await cursor.to_list(length=50)
        tokens = [d["token"] for d in docs if d.get("token")]
        if not tokens:
            return

        invalid = await send_push_to_tokens(tokens, title, body, data)
        if invalid:
            await app_db["fcm_tokens"].delete_many({"user_id": user_id, "token": {"$in": invalid}})
    except Exception as exc:  # noqa: BLE001 — pushing must never break the caller
        print(f"⚠️  send_push_to_user (web backend) failed for user {user_id}: {exc}")
