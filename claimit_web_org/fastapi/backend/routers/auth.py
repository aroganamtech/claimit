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

# ── Unique ID prefix map ───────────────────────────────────────
_SUB_ROLE_PREFIX = {
    "sales_head":             "SH",
    "sales_executive":        "SE",
    "advertising_executive":  "AE",
    "freelancer":             "FL",
}

async def _generate_unique_id(sub_role: str) -> str:
    """Generate CLM-SE-0001 style unique ID for a sales sub-role."""
    prefix = _SUB_ROLE_PREFIX.get(sub_role, "SL")
    count = await users_collection.count_documents(
        {"role": "sales", "sub_role": sub_role}
    )
    return f"CLM-{prefix}-{str(count + 1).zfill(4)}"


# ─── Step 1: register → send OTP ──────────────────────────────
@router.post("/send-otp")
async def send_otp(request: RegisterRequest):
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

    # Generate unique employee ID for sales roles
    unique_id = None
    if request.role == "sales" and request.sub_role:
        unique_id = await _generate_unique_id(request.sub_role)

    # Validate referred_by (Sales Head must exist)
    referred_by_id = None
    if request.referred_by:
        head = await users_collection.find_one({
            "unique_id": request.referred_by,
            "sub_role": "sales_head",
        })
        if not head:
            raise HTTPException(
                status_code=400,
                detail=f"Sales Head ID '{request.referred_by}' not found.",
            )
        referred_by_id = request.referred_by

    user_doc = {
        "phone":       request.phone,
        "email":       request.email,
        "name":        request.name,
        "address":     request.address,
        "pincode":     request.pincode,
        "lat":         request.lat,
        "lng":         request.lng,
        "role":        request.role,
        "sub_role":    request.sub_role,
        "unique_id":   unique_id,
        "referred_by": referred_by_id,
        "created_at":  datetime.utcnow(),
    }
    result = await users_collection.insert_one(user_doc)
    user_id = str(result.inserted_id)
    token = create_access_token({"sub": user_id, "role": request.role, "name": request.name})
    return {
        **TokenResponse(
            access_token=token,
            token_type="bearer",
            role=request.role,
            user_id=user_id,
            name=request.name,
            email=request.email,
        ).dict(),
        "unique_id": unique_id,
        "sub_role":  request.sub_role,
    }


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
    return {
        **TokenResponse(
            access_token=token,
            token_type="bearer",
            role=request.role,
            user_id=user_id,
            name=user.get("name", ""),
            email=user.get("email", ""),
        ).dict(),
        "unique_id": user.get("unique_id"),
        "sub_role":  user.get("sub_role"),
    }


# ─── Current-user (used by frontend on reload) ────────────────
@router.get("/me")
async def get_me(current_user=Depends(get_current_user)):
    return {
        "id":          str(current_user["_id"]),
        "name":        current_user.get("name", ""),
        "email":       current_user.get("email", ""),
        "phone":       current_user.get("phone", ""),
        "address":     current_user.get("address", ""),
        "pincode":     current_user.get("pincode", ""),
        "role":        current_user.get("role", ""),
        "sub_role":    current_user.get("sub_role"),
        "unique_id":   current_user.get("unique_id"),
        "referred_by": current_user.get("referred_by"),
    }
