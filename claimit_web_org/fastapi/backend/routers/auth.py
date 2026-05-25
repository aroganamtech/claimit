from fastapi import APIRouter, HTTPException, Depends
from database import users_collection
from models.schemas import (
    RegisterRequest, OTPVerifyRequest, UserDetailsRequest,
    LoginRequest, TokenResponse,
)
from utils.auth import (
    generate_otp, store_otp, verify_otp,
    create_access_token, UNIVERSAL_OTP,
)
from utils.dependencies import get_current_user
from bson import ObjectId
from datetime import datetime

router = APIRouter()


# ─── Step 1: register → send OTP ──────────────────────────────
@router.post("/send-otp")
async def send_otp(request: RegisterRequest):
    # Block re-registration with the same phone+role
    existing = await users_collection.find_one({
        "phone": request.phone,
        "role": request.role,
    })
    if existing:
        raise HTTPException(
            status_code=409,
            detail="User already registered with this phone. Please login instead.",
        )

    otp = generate_otp()
    await store_otp(request.role, request.phone, otp)
    print(f"[DEV OTP] role={request.role} phone={request.phone} otp={otp}")
    # `dev_otp` is also returned so the OTP screen can display it during dev.
    return {"message": "OTP sent successfully", "dev_otp": otp}


# ─── Step 2: verify OTP ───────────────────────────────────────
@router.post("/verify-otp")
async def verify_otp_endpoint(request: OTPVerifyRequest):
    valid = await verify_otp(request.role, request.phone, request.otp)
    if not valid:
        raise HTTPException(status_code=400, detail="Invalid or expired OTP")
    return {"message": "OTP verified successfully", "verified": True}


# ─── Step 3: complete registration ────────────────────────────
@router.post("/complete-registration")
async def complete_registration(request: UserDetailsRequest):
    existing = await users_collection.find_one({
        "phone": request.phone,
        "role": request.role,
    })
    if existing:
        raise HTTPException(
            status_code=409,
            detail="User already registered with this phone. Please login instead.",
        )

    user_doc = {
        "phone": request.phone,
        "email": request.email,
        "name": request.name,
        "address": request.address,
        "pincode": request.pincode,
        "lat": request.lat,
        "lng": request.lng,
        "role": request.role,
        "created_at": datetime.utcnow(),
    }
    result = await users_collection.insert_one(user_doc)
    user_id = str(result.inserted_id)
    token = create_access_token({"sub": user_id, "role": request.role, "name": request.name})
    return TokenResponse(
        access_token=token,
        token_type="bearer",
        role=request.role,
        user_id=user_id,
        name=request.name,
        email=request.email,
    )


# ─── Login (existing user) ────────────────────────────────────
@router.post("/login")
async def login(request: LoginRequest):
    user = await users_collection.find_one({
        "phone": request.phone,
        "role": request.role,
    })
    if not user:
        raise HTTPException(
            status_code=404,
            detail="No account with this phone. Please register first.",
        )

    user_id = str(user["_id"])
    token = create_access_token({"sub": user_id, "role": request.role, "name": user.get("name", "")})
    return TokenResponse(
        access_token=token,
        token_type="bearer",
        role=request.role,
        user_id=user_id,
        name=user.get("name", ""),
        email=user.get("email", ""),
    )


# ─── Current-user (used by frontend on reload) ────────────────
@router.get("/me")
async def get_me(current_user=Depends(get_current_user)):
    return {
        "id": str(current_user["_id"]),
        "name": current_user.get("name", ""),
        "email": current_user.get("email", ""),
        "phone": current_user.get("phone", ""),
        "address": current_user.get("address", ""),
        "pincode": current_user.get("pincode", ""),
        "role": current_user.get("role", ""),
    }
