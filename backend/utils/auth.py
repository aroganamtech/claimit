import os
import random
from datetime import datetime, timedelta
from jose import JWTError, jwt
from passlib.context import CryptContext
from dotenv import load_dotenv

load_dotenv()

SECRET_KEY = os.getenv("SECRET_KEY", "claimit_secret_key_2024")
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 1440))

# In-memory OTP store (use Redis in production)
otp_store = {}


def generate_otp() -> str:
    return str(random.randint(100000, 999999))


def store_otp(phone: str, otp: str):
    otp_store[phone] = {
        "otp": otp,
        "expires": datetime.utcnow() + timedelta(minutes=5)
    }


def verify_otp(phone: str, otp: str) -> bool:
    if phone not in otp_store:
        return False
    stored = otp_store[phone]
    if datetime.utcnow() > stored["expires"]:
        del otp_store[phone]
        return False
    if stored["otp"] == otp:
        del otp_store[phone]
        return True
    return False


def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def decode_token(token: str) -> dict:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None
