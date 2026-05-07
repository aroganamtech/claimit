import random
import string
from datetime import datetime, timedelta
from ..database import get_db
from ..config import get_settings

settings = get_settings()


def generate_otp(length: int = 6) -> str:
    """Generate a random numeric OTP."""
    return ''.join(random.choices(string.digits, k=length))


async def store_otp(phone: str, otp: str, expires_in_minutes: int = 10) -> bool:
    """Store OTP in database with expiry."""
    db = get_db()
    expires_at = datetime.utcnow() + timedelta(minutes=expires_in_minutes)

    await db.otp_store.update_one(
        {"phone": phone},
        {
            "$set": {
                "phone": phone,
                "otp": otp,
                "expires_at": expires_at,
                "attempts": 0,
                "created_at": datetime.utcnow(),
            }
        },
        upsert=True,
    )
    return True


async def verify_otp(phone: str, otp: str) -> bool:
    """Verify OTP from database. Uses static OTP for demo."""
    # Static OTP for demo/development
    if otp == settings.static_otp:
        return True

    db = get_db()
    record = await db.otp_store.find_one({"phone": phone})

    if not record:
        return False

    # Check expiry
    if record["expires_at"] < datetime.utcnow():
        await db.otp_store.delete_one({"phone": phone})
        return False

    # Check attempts (max 3)
    if record.get("attempts", 0) >= 3:
        return False

    # Increment attempts
    await db.otp_store.update_one(
        {"phone": phone},
        {"$inc": {"attempts": 1}},
    )

    if record["otp"] == otp:
        await db.otp_store.delete_one({"phone": phone})
        return True

    return False


async def send_otp_sms(phone: str, otp: str) -> bool:
    """
    Send OTP via SMS.
    In production, integrate with SMS provider (Twilio, MSG91, etc.)
    For now, just log it.
    """
    print(f"📱 OTP for {phone}: {otp}")
    # TODO: Integrate with SMS provider
    return True
