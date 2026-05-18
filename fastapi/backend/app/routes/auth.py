from datetime import datetime
from typing import Optional

from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from ..database import get_db
from ..utils.auth import (
    create_access_token,
    create_refresh_token,
    decode_token,
    get_current_user,
)
from ..utils.helpers import serialize_doc
from ..utils.otp import generate_otp, send_otp_sms, store_otp, verify_otp

router = APIRouter(prefix="/auth", tags=["Authentication"])


# ── Request / Response models ────────────────────────────────────────────────

class SendOtpRequest(BaseModel):
    # Field kept as "phone" for backward-compat with Flutter client.
    # Accepts mobile number OR email address.
    phone: str


class VerifyOtpRequest(BaseModel):
    phone: str   # mobile number OR email – same as above
    otp: str


class RefreshTokenRequest(BaseModel):
    refresh_token: str


# ── Helpers ──────────────────────────────────────────────────────────────────

def _is_email(identifier: str) -> bool:
    return "@" in identifier


async def _find_user(db, identifier: str):
    """Look up a user by phone number or email."""
    if _is_email(identifier):
        return await db.users.find_one({"email": identifier})
    return await db.users.find_one({"phone": identifier})


async def _auto_create_user(db, identifier: str) -> dict:
    """
    Create a new user with a generated display name.
    The user can update their name later from the Profile screen.
    """
    count = await db.users.count_documents({})
    default_name = f"User{count + 1}"

    user_doc = {
        "full_name": default_name,
        "phone": identifier if not _is_email(identifier) else "",
        "email": identifier if _is_email(identifier) else None,
        "is_verified": True,
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow(),
    }
    result = await db.users.insert_one(user_doc)
    user_doc["_id"] = result.inserted_id
    return user_doc


# ── Routes ───────────────────────────────────────────────────────────────────

@router.post("/send-otp")
async def send_otp(request: SendOtpRequest):
    """
    Send OTP to a mobile number or email address.
    Works for both new (signup) and existing (login) users –
    no separate registration step required.
    """
    identifier = request.phone.strip()
    if not identifier:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mobile number or email is required",
        )

    otp = generate_otp()
    await store_otp(identifier, otp)
    await send_otp_sms(identifier, otp)   # logs to console; plug in SMS/email provider here

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
        # New user — create account automatically
        user = await _auto_create_user(db, identifier)
    else:
        # Existing user — update last-login timestamp
        await db.users.update_one(
            {"_id": user["_id"]},
            {"$set": {"last_login": datetime.utcnow(), "is_verified": True}},
        )

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


@router.post("/logout")
async def logout(current_user: dict = Depends(get_current_user)):
    """Logout user (client should delete tokens)."""
    return {"success": True, "message": "Logged out successfully"}
