from fastapi import APIRouter, HTTPException, Depends
from database import users_collection, ads_collection, shops_collection, deleted_users_collection
from models.schemas import (
    RegisterRequest, OTPVerifyRequest, UserDetailsRequest,
    LoginRequest, TokenResponse,
)
from utils.auth import (
    generate_otp, store_otp, verify_otp,
    create_access_token, UNIVERSAL_OTP,
)
from utils.dependencies import get_current_user
from utils.email import send_email
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
    return f"CLM-{prefix}-{str(count + 1000+1).zfill(4)}"


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
    # Verified by email now — phone is collected and stored as profile data
    # only, it's no longer the OTP delivery/verification channel.
    await store_otp(request.role, request.email, otp)
    sent = False
    try:
        sent = send_email(
            request.email, f"{otp} is your Claimit verification code",
            f"<p style='font-family:Arial'>Your Claimit verification code is "
            f"<b style='font-size:22px'>{otp}</b>.<br>Valid for 10 minutes.</p>",
        )
    except Exception:
        sent = False
    resp = {"message": "OTP sent successfully", "sent": sent}
    if not sent:                       # SMTP not configured → surface for testing
        resp["dev_otp"] = otp
        print(f"[DEV OTP] role={request.role} email={request.email} otp={otp}")
    return resp


# ─── Step 2: verify OTP ───────────────────────────────────────
@router.post("/verify-otp")
async def verify_otp_endpoint(request: OTPVerifyRequest):
    valid = await verify_otp(request.role, request.email, request.otp)
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


# ─── Delete account ───────────────────────────────────────────
@router.delete("/account")
async def delete_account(current_user=Depends(get_current_user)):
    """
    Self-service account deletion. Deletes the user's account, all their ads,
    and their shop. Full record is archived in deleted_users_collection for
    admin review before permanent removal.
    """
    user_id = str(current_user["_id"])
    role    = current_user.get("role", "")

    # Gather associated data before deleting
    user_ads  = await ads_collection.find({"user_id": user_id}).to_list(500)
    user_shop = await shops_collection.find_one({"user_id": user_id})

    # Archive full snapshot to deleted_users collection
    archive = {
        "user":       {**{k: str(v) if k == "_id" else v for k, v in current_user.items()}},
        "ads":        [{**{k: str(v) if k == "_id" else v for k, v in a.items()}} for a in user_ads],
        "shop":       {**{k: str(v) if k == "_id" else v for k, v in user_shop.items()}} if user_shop else None,
        "deleted_at": datetime.utcnow(),
        "role":       role,
    }
    await deleted_users_collection.insert_one(archive)

    # Delete ads and shop
    await ads_collection.delete_many({"user_id": user_id})
    if user_shop:
        await shops_collection.delete_one({"_id": user_shop["_id"]})

    # Delete user account
    await users_collection.delete_one({"_id": current_user["_id"]})

    return {"ok": True, "message": "Account deleted successfully"}


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
