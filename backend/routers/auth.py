from fastapi import APIRouter, HTTPException, status
from database import users_collection
from models.schemas import RegisterRequest, OTPVerifyRequest, UserDetailsRequest, LoginRequest, TokenResponse
from utils.auth import generate_otp, store_otp, verify_otp, create_access_token
from bson import ObjectId
from datetime import datetime

router = APIRouter()


@router.post("/send-otp")
async def send_otp(request: RegisterRequest):
    otp = generate_otp()
    store_otp(request.phone, otp)
    # In production, send via SMS/Email service
    print(f"OTP for {request.phone}: {otp}")  # Dev only
    return {"message": "OTP sent successfully", "dev_otp": otp}  # Remove dev_otp in production


@router.post("/verify-otp")
async def verify_otp_endpoint(request: OTPVerifyRequest):
    # For dev, accept "123456" as universal OTP
    valid = verify_otp(request.phone, request.otp) or request.otp == "123456"
    if not valid:
        raise HTTPException(status_code=400, detail="Invalid or expired OTP")
    return {"message": "OTP verified successfully", "verified": True}


@router.post("/complete-registration")
async def complete_registration(request: UserDetailsRequest):
    existing = await users_collection.find_one({
        "phone": request.phone,
        "role": request.role
    })
    if existing:
        token = create_access_token({
            "sub": str(existing["_id"]),
            "role": request.role,
            "name": existing.get("name", "")
        })
        return TokenResponse(
            access_token=token,
            token_type="bearer",
            role=request.role,
            user_id=str(existing["_id"]),
            name=existing.get("name", "")
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
        "created_at": datetime.utcnow()
    }
    result = await users_collection.insert_one(user_doc)
    token = create_access_token({
        "sub": str(result.inserted_id),
        "role": request.role,
        "name": request.name
    })
    return TokenResponse(
        access_token=token,
        token_type="bearer",
        role=request.role,
        user_id=str(result.inserted_id),
        name=request.name
    )


@router.post("/login")
async def login(request: LoginRequest):
    user = await users_collection.find_one({
        "phone": request.phone,
        "role": request.role
    })
    if not user:
        raise HTTPException(status_code=404, detail="User not found. Please register first.")

    token = create_access_token({
        "sub": str(user["_id"]),
        "role": request.role,
        "name": user.get("name", "")
    })
    return TokenResponse(
        access_token=token,
        token_type="bearer",
        role=request.role,
        user_id=str(user["_id"]),
        name=user.get("name", "")
    )


@router.get("/me")
async def get_me(token: str):
    from utils.auth import decode_token
    payload = decode_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid token")
    user = await users_collection.find_one({"_id": ObjectId(payload["sub"])})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return {
        "id": str(user["_id"]),
        "name": user.get("name", ""),
        "email": user.get("email", ""),
        "phone": user.get("phone", ""),
        "role": user.get("role", "")
    }
