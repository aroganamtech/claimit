from datetime import datetime
from typing import Optional

from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from typing import Optional

from ..database import get_db
from ..utils.auth import (
    create_access_token,
    create_refresh_token,
    decode_token,
    get_current_user,
)
from ..utils.helpers import serialize_doc
from ..utils.otp import generate_otp, send_otp_sms, store_otp, verify_otp
from ..utils.notify import notify_user
from ..utils.welcome_email import send_welcome_email
from ..utils.whatsapp import send_welcome as send_whatsapp_welcome
import asyncio

router = APIRouter(prefix="/auth", tags=["Authentication"])


# ── Request / Response models ────────────────────────────────────────────────

class SendOtpRequest(BaseModel):
    # Field kept as "phone" for backward-compat with Flutter client.
    # Accepts mobile number OR email address.
    phone: str
    # "login"    → account MUST already exist; 404 if not found
    # "register" → account MUST NOT exist; 409 if already registered
    mode: str = "login"


class VerifyOtpRequest(BaseModel):
    phone: str   # mobile number OR email – same as above
    otp: str
    mode: str = "login"  # same semantics as SendOtpRequest.mode
    # Real name typed on the register screen — stored on the new account
    # instead of an auto-generated "User1/2/3" placeholder.
    name: Optional[str] = None
    # Optional: pass the device's FCM token here to register it for push
    # notifications in the same round-trip as login (no extra API call needed).
    fcm_token: Optional[str] = None
    fcm_platform: Optional[str] = None  # "android" | "ios" | "web"


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class LogoutRequest(BaseModel):
    # Optional: pass this device's FCM token so we can stop pushing to it
    # once the user signs out (prevents pushes meant for the next account
    # on a shared/reset device from leaking to the previous user).
    fcm_token: Optional[str] = None


class SocialLoginRequest(BaseModel):
    provider: str          # "google" | "facebook"
    name: str = ""
    email: Optional[str] = None
    provider_id: str = ""


# ── Helpers ──────────────────────────────────────────────────────────────────

def _is_email(identifier: str) -> bool:
    return "@" in identifier


async def _find_user(db, identifier: str):
    """Look up a user by phone number or email."""
    if _is_email(identifier):
        return await db.users.find_one({"email": identifier})
    return await db.users.find_one({"phone": identifier})


async def _auto_create_user(db, identifier: str, name: str = "") -> dict:
    """
    Create a new user. Uses the REAL name typed at registration when
    provided; falls back to a generated display name only for old app
    versions that don't send one.

    IMPORTANT: We deliberately omit the phone/email field when the user
    didn't provide it, rather than storing None/null.  MongoDB sparse
    indexes only skip documents where the field is *absent* from the
    document — documents with the field set to null or "" are still
    indexed and would cause E11000 duplicate-key errors when a second
    email-only (or phone-only) user registers.
    """
    clean_name = (name or "").strip()
    if not clean_name:
        count = await db.users.count_documents({})
        clean_name = f"User{count + 1}"

    user_doc: dict = {
        "full_name": clean_name,
        "is_verified": True,
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow(),
    }
    # Only set the credential that was actually provided.
    if _is_email(identifier):
        user_doc["email"] = identifier
    else:
        user_doc["phone"] = identifier

    result = await db.users.insert_one(user_doc)
    user_doc["_id"] = result.inserted_id
    return user_doc


# ── Routes ───────────────────────────────────────────────────────────────────

@router.post("/send-otp")
async def send_otp(request: SendOtpRequest):
    """
    Send OTP to a mobile number or email address.

    mode="login"    → the account must already exist; returns 404 if not found.
    mode="register" → the account must NOT exist; returns 409 if already registered.
    """
    identifier = request.phone.strip()
    if not identifier:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mobile number or email is required",
        )

    db = get_db()
    existing_user = await _find_user(db, identifier)

    if request.mode == "login" and not existing_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No account found with this mobile number or email. Please register first.",
        )

    if request.mode == "register" and existing_user:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account already exists with this mobile number or email. Please login instead.",
        )

    otp = generate_otp()
    await store_otp(identifier, otp)
    try:
        await send_otp_sms(identifier, otp)
    except Exception as exc:
        # Delivery failure must never return 500 — OTP is stored; user can retry.
        print(f"⚠️  OTP delivery error for {identifier}: {exc}")

    return {
        "success": True,
        "message": f"OTP sent to {identifier}",
        "phone": identifier,
    }


@router.post("/verify-otp")
async def verify_otp_endpoint(request: VerifyOtpRequest):
    """
    Verify OTP and return auth tokens.

    - If OTP is valid and user already exists  → login.
    - If OTP is valid and user does NOT exist  → auto-create account,
      then login.  The user can fill in their name / details later
      from the Profile screen.
    """
    identifier = request.phone.strip()
    otp = request.otp.strip()

    # ── 1. Validate OTP ──────────────────────────────────────────────────────
    is_valid = await verify_otp(identifier, otp)
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired OTP",
        )

    # ── 2. Find or create user ───────────────────────────────────────────────
    db = get_db()
    user = await _find_user(db, identifier)

    if not user:
        if request.mode == "login":
            # Login attempted with an unregistered identifier
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No account found with this mobile number or email. Please register first.",
            )
        # Register mode — create account (with the real typed name)
        user = await _auto_create_user(db, identifier, request.name or "")
        # NEW USER: send the promo/welcome message in the background
        # (fire-and-forget — registration never waits for it).
        #
        # Whichever way they signed up decides the channel: an email address
        # gets the welcome email, a mobile number gets the WhatsApp welcome.
        # Both are no-ops when their credentials aren't configured, so a
        # delivery problem can never fail a registration.
        _welcome_name = user.get("full_name", "")
        if _is_email(identifier):
            asyncio.create_task(send_welcome_email(identifier, _welcome_name))
        else:
            asyncio.create_task(send_whatsapp_welcome(identifier, _welcome_name))
    else:
        if request.mode == "register":
            # Registration attempted with an already-registered identifier
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="An account already exists with this mobile number or email. Please login instead.",
            )
        # Existing user — update last-login timestamp
        await db.users.update_one(
            {"_id": user["_id"]},
            {"$set": {"last_login": datetime.utcnow(), "is_verified": True}},
        )

    # ── 3. Issue tokens ──────────────────────────────────────────────────────
    user_id = str(user["_id"])
    access_token = create_access_token({"sub": user_id})
    refresh_token = create_refresh_token({"sub": user_id})

    # ── 4. Register this device's FCM token (optional, single round-trip) ────
    if request.fcm_token:
        token = request.fcm_token.strip()
        if token:
            await db.fcm_tokens.update_one(
                {"token": token},
                {
                    "$set": {
                        "user_id": user_id,
                        "platform": request.fcm_platform,
                        "updated_at": datetime.utcnow(),
                    },
                    "$setOnInsert": {"created_at": datetime.utcnow()},
                },
                upsert=True,
            )

    # ── 5. Fire the "Login Successful" notification (in-app + push popup) ────
    # Best-effort: notify_user() swallows its own errors, so a push outage
    # can never fail a login.
    display_name = user.get("full_name") or user.get("name") or identifier
    await notify_user(
        db,
        user_id,
        title="✅ Login Successful",
        message=f"Welcome back, {display_name}! You're now logged in to Claimit.",
        type="success",
        data={"event": "login_success"},
    )

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user": serialize_doc(user),
    }


@router.post("/refresh")
async def refresh_token(request: RefreshTokenRequest):
    """Refresh access token."""
    payload = decode_token(request.refresh_token)

    if payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        )

    user_id = payload.get("sub")
    db = get_db()
    user = await db.users.find_one({"_id": ObjectId(user_id)})

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    access_token = create_access_token({"sub": user_id})
    return {"access_token": access_token, "token_type": "bearer"}


@router.post("/social/login")
async def social_login(request: SocialLoginRequest):
    """
    Social login / registration via Google or Facebook.
    Finds an existing user by email or provider_id, or creates a new one.
    Returns access_token, refresh_token, and user object.
    """
    db = get_db()
    provider = request.provider.strip().lower()
    email = request.email.strip() if request.email else None
    provider_id = request.provider_id.strip()
    name = request.name.strip()

    # ── 1. Find existing user by email or provider_id ────────────────────────
    user = None
    if email:
        user = await db.users.find_one({"email": email})
    if not user and provider_id:
        user = await db.users.find_one({f"{provider}_id": provider_id})

    # ── 2. Create user if not found ──────────────────────────────────────────
    if not user:
        count = await db.users.count_documents({})
        user_doc: dict = {
            "full_name": name or f"User{count + 1}",
            "is_verified": True,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow(),
            f"{provider}_id": provider_id,
        }
        if email:
            user_doc["email"] = email
        result = await db.users.insert_one(user_doc)
        user_doc["_id"] = result.inserted_id
        user = user_doc
        # NEW USER via Google/Facebook button: promo/welcome email in the
        # background (fire-and-forget, never blocks or fails the login)
        if email:
            asyncio.create_task(send_welcome_email(email, name))
    else:
        # Update provider_id and name if missing
        updates: dict = {"updated_at": datetime.utcnow()}
        if provider_id and not user.get(f"{provider}_id"):
            updates[f"{provider}_id"] = provider_id
        if name and not user.get("full_name"):
            updates["full_name"] = name
        await db.users.update_one({"_id": user["_id"]}, {"$set": updates})

    # ── 3. Issue tokens ──────────────────────────────────────────────────────
    user_id = str(user["_id"])
    access_token = create_access_token({"sub": user_id})
    refresh_token = create_refresh_token({"sub": user_id})

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user": serialize_doc(user),
    }


@router.post("/logout")
async def logout(
    request: LogoutRequest = LogoutRequest(),
    current_user: dict = Depends(get_current_user),
):
    """Logout user (client should delete tokens). Also de-registers this
    device's FCM token so the signed-out account stops receiving pushes
    meant for it (important on shared/reset devices)."""
    if request.fcm_token:
        db = get_db()
        user_id = str(current_user.get("_id") or current_user.get("id"))
        await db.fcm_tokens.delete_one({"token": request.fcm_token.strip(), "user_id": user_id})

    return {"success": True, "message": "Logged out successfully"}
