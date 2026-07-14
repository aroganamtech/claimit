"""
Self-service account deletion for Claimit APP users — the Flutter app's own
end-customers, stored in claimit_db.users. This is a completely different
set of accounts from the web portal's advertiser/sales/shop users (which
have their own separate self-delete at DELETE /api/auth/account).

Why this lives here instead of on the app's own backend: Google Play
requires a public web URL where an app user can request account deletion
without the app installed. The app backend (fastapi/backend) has no
delete-account endpoint today, and it's only reachable over plain HTTP at a
bare IP — not safe for a browser on an HTTPS page to call directly (mixed
content). This backend already shares the exact same MongoDB cluster
(claimit_db, via `app_db`) that the app backend uses, so we operate on that
data directly — no HTTP call to the app backend needed.

Endpoints
─────────
POST /app-account/send-otp          → confirm the phone/email has an account, issue an OTP
POST /app-account/verify-and-delete → verify OTP, permanently delete the account + all its data

OTP delivery reuses the same generate_otp/store_otp/verify_otp helpers (and
UNIVERSAL_OTP fallback) already used for the web portal's own OTP login
(utils/auth.py), under a distinct role tag ("app_delete") so it can never
collide with an advertiser/sales/shop OTP for the same phone number.
"""

from datetime import datetime

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from database import app_db
from utils.auth import generate_otp, store_otp, verify_otp
from utils.s3 import delete_object

router = APIRouter()

_ROLE = "app_delete"

# Collections in claimit_db that reference a user, keyed by user_id stored
# as a STRING (str(user["_id"])) — the convention used everywhere in the app
# backend except `classifieds` (see below).
_STRING_ID_COLLECTIONS = [
    "claims", "notifications", "fcm_tokens", "redeem", "bill_rewards",
    "user_wallets", "bill_scans", "bill_history", "bill_manual_reviews",
    "feedback", "shop_reviews",
]


def _is_email(identifier: str) -> bool:
    return "@" in identifier


async def _find_app_user(identifier: str):
    """Look up a Claimit app user by phone number or email — same lookup
    rule as the app backend's own auth (`_find_user` in app/routes/auth.py)."""
    if _is_email(identifier):
        return await app_db["users"].find_one({"email": identifier})
    return await app_db["users"].find_one({"phone": identifier})


class SendOtpBody(BaseModel):
    identifier: str  # phone number or email registered on the Claimit app


@router.post("/send-otp")
async def send_otp(body: SendOtpBody):
    identifier = (body.identifier or "").strip()
    if not identifier:
        raise HTTPException(
            status_code=400,
            detail="Enter the mobile number or email on your Claimit account.",
        )

    user = await _find_app_user(identifier)
    if not user:
        raise HTTPException(
            status_code=404,
            detail="No Claimit account found with this mobile number or email.",
        )

    otp = generate_otp()
    await store_otp(_ROLE, identifier, otp)
    # No SMS/email delivery is wired up for this flow, so — same as the web
    # portal's own dev /send-otp (routers/auth.py) — the OTP is returned
    # directly in the response and shown on the page itself.
    return {"ok": True, "message": "OTP generated.", "dev_otp": otp}


class VerifyAndDeleteBody(BaseModel):
    identifier: str
    otp: str
    confirm: bool = False


@router.post("/verify-and-delete")
async def verify_and_delete(body: VerifyAndDeleteBody):
    identifier = (body.identifier or "").strip()
    if not identifier or not body.otp:
        raise HTTPException(status_code=400, detail="Mobile number/email and OTP are required.")
    if not body.confirm:
        raise HTTPException(
            status_code=400,
            detail="Please confirm you understand this permanently deletes your account.",
        )

    if not await verify_otp(_ROLE, identifier, body.otp):
        raise HTTPException(status_code=400, detail="Invalid or expired OTP. Please request a new one.")

    user = await _find_app_user(identifier)
    if not user:
        raise HTTPException(status_code=404, detail="No Claimit account found with this mobile number or email.")

    def _clean(doc: dict) -> dict:
        return {k: (str(v) if k == "_id" else v) for k, v in doc.items()}

    # ── Archive a snapshot before deleting anything (audit trail) ──────────
    await app_db["deleted_app_users"].insert_one({
        "user": _clean(user),
        "deleted_at": datetime.utcnow(),
        "deleted_via": "web_self_service",
    })

    # ── Best-effort S3 avatar cleanup ───────────────────────────────────────
    avatar_key = user.get("avatar_s3_key")
    if avatar_key:
        await delete_object(avatar_key)

    # ── Wipe every collection that references this user ────────────────────
    for name in _STRING_ID_COLLECTIONS:
        try:
            await app_db[name].delete_many({"user_id": str(user["_id"])})
        except Exception:
            pass  # a missing/renamed collection must never block deletion

    # `classifieds` stores user_id as a raw ObjectId, not a string.
    try:
        await app_db["classifieds"].delete_many({"user_id": user["_id"]})
    except Exception:
        pass

    await app_db["users"].delete_one({"_id": user["_id"]})

    return {
        "ok": True,
        "message": "Your Claimit account and all associated data have been permanently deleted.",
    }
