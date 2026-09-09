import os
import random
from datetime import datetime, timedelta
from jose import JWTError, jwt
from dotenv import load_dotenv
from database import otps_collection

load_dotenv()

SECRET_KEY = os.getenv("SECRET_KEY", "claimit_secret_key_2024")
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 1440))
OTP_TTL_MINUTES = 5

# The universal OTP that used to live here has been REMOVED.
#
# It accepted one fixed code for every account, with no environment check and
# no rate limit, which meant anyone who knew it could sign in as any customer,
# merchant or admin. Real OTP delivery works, so nothing needs it any more.
#
# Kept as an empty string only so any leftover import doesn't break; it can
# never match a submitted OTP because verify_otp rejects blank input.
UNIVERSAL_OTP = ""


def generate_otp() -> str:
    return str(random.randint(100000, 999999))


async def store_otp(role: str, phone: str, otp: str):
    """Persist OTP per (role, phone) so it survives reloads."""
    await otps_collection.update_one(
        {"role": role, "phone": phone},
        {"$set": {
            "otp": otp,
            "expires": datetime.utcnow() + timedelta(minutes=OTP_TTL_MINUTES),
        }},
        upsert=True,
    )


async def verify_otp(role: str, phone: str, otp: str) -> bool:
    # Only the code we actually generated and sent is accepted. A blank or
    # missing submission is rejected outright rather than falling through to
    # a comparison that an empty stored value could satisfy.
    otp = (otp or "").strip()
    if not otp:
        return False
    rec = await otps_collection.find_one({"role": role, "phone": phone})
    if not rec:
        return False
    if datetime.utcnow() > rec["expires"]:
        await otps_collection.delete_one({"_id": rec["_id"]})
        return False
    if rec["otp"] != otp:
        return False
    await otps_collection.delete_one({"_id": rec["_id"]})
    return True


def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def decode_token(token: str):
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        return None
