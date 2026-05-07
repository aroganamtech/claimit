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


class SendOtpRequest(BaseModel):
    phone: str


class VerifyOtpRequest(BaseModel):
    phone: str
    otp: str


class RegisterRequest(BaseModel):
    full_name: str
    phone: str
    email: Optional[str] = None


class RefreshTokenRequest(BaseModel):
    refresh_token: str


@router.post("/send-otp")
async def send_otp(request: SendOtpRequest):
    """Send OTP to phone number."""
    phone = request.phone.strip()
    if not phone:
        raise HTTPException(status_code=400, detail="Phone number is required")

    otp = generate_otp()
    await store_otp(phone, otp)
    await send_otp_sms(phone, otp)

    return {
        "success": True,
        "message": f"OTP sent to {phone}",
        "phone": phone,
    }


@router.post("/verify-otp")
async def verify_otp_endpoint(request: VerifyOtpRequest):
    """Verify OTP and return tokens."""
    phone = request.phone.strip()
    otp = request.otp.strip()

    is_valid = await verify_otp(phone, otp)
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired OTP",
        )

    db = get_db()
    user = await db.users.find_one({"phone": phone})

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found. Please register first.",
        )

    user_id = str(user["_id"])
    access_token = create_access_token({"sub": user_id})
    refresh_token = create_refresh_token({"sub": user_id})

    # Update last login
    await db.users.update_one(
        {"_id": user["_id"]},
        {"$set": {"last_login": datetime.utcnow(), "is_verified": True}},
    )

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user": serialize_doc(user),
    }


@router.post("/register", status_code=status.HTTP_201_CREATED)
async def register(request: RegisterRequest):
    """Register a new user."""
    db = get_db()

    # Check if phone already exists
    existing = await db.users.find_one({"phone": request.phone})
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Phone number already registered",
        )

    # Check email uniqueness
    if request.email:
        existing_email = await db.users.find_one({"email": request.email})
        if existing_email:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Email already registered",
            )

    user_doc = {
        "full_name": request.full_name,
        "phone": request.phone,
        "email": request.email,
        "is_verified": False,
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow(),
    }

    result = await db.users.insert_one(user_doc)
    user_doc["_id"] = str(result.inserted_id)

    return {
        "success": True,
        "message": "Registration successful. Please verify your phone.",
        "user": serialize_doc(user_doc),
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
