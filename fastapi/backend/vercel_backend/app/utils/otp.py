# import random
# import string
# from datetime import datetime, timedelta
# from ..database import get_db
# from ..config import get_settings

# settings = get_settings()


# def generate_otp(length: int = 6) -> str:
#     """Generate a random numeric OTP."""
#     return ''.join(random.choices(string.digits, k=length))


# async def store_otp(phone: str, otp: str, expires_in_minutes: int = 10) -> bool:
#     """Store OTP in database with expiry."""
#     db = get_db()
#     expires_at = datetime.utcnow() + timedelta(minutes=expires_in_minutes)

#     await db.otp_store.update_one(
#         {"phone": phone},
#         {
#             "$set": {
#                 "phone": phone,
#                 "otp": otp,
#                 "expires_at": expires_at,
#                 "attempts": 0,
#                 "created_at": datetime.utcnow(),
#             }
#         },
#         upsert=True,
#     )
#     return True


# async def verify_otp(phone: str, otp: str) -> bool:
#     """Verify OTP from database. Uses static OTP for demo."""
#     # Static OTP for demo/development
#     if otp == settings.static_otp:
#         return True

#     db = get_db()
#     record = await db.otp_store.find_one({"phone": phone})

#     if not record:
#         return False

#     # Check expiry
#     if record["expires_at"] < datetime.utcnow():
#         await db.otp_store.delete_one({"phone": phone})
#         return False

#     # Check attempts (max 3)
#     if record.get("attempts", 0) >= 3:
#         return False

#     # Increment attempts
#     await db.otp_store.update_one(
#         {"phone": phone},
#         {"$inc": {"attempts": 1}},
#     )

#     if record["otp"] == otp:
#         await db.otp_store.delete_one({"phone": phone})
#         return True

#     return False


# async def send_otp_sms(phone: str, otp: str) -> bool:
#     """
#     Send OTP via SMS.
#     In production, integrate with SMS provider (Twilio, MSG91, etc.)
#     For now, just log it.
#     """
#     print(f"📱 OTP for {phone}: {otp}")
#     # TODO: Integrate with SMS provider
#     return True
import random
import string
import smtplib
import os
from datetime import datetime, timedelta
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
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
    Detects if the destination is an email or phone number.
    Sends a real email using Gmail SMTP if it's an email address.
    """
    # 1. Check if it's an email address
    if "@" in phone:
        try:
            # Pull credentials securely from environment variables
            sender_email = os.environ.get("SMTP_USERNAME")
            sender_password = os.environ.get("SMTP_PASSWORD")

            if not sender_email or not sender_password:
                print("❌ Configuration Error: Email environment variables are missing!")
                return False

            # Set up the email payloads
            message = MIMEMultipart()
            message["From"] = sender_email
            message["To"] = phone
            message["Subject"] = f"{otp} is your verification code"

            body = f"""
            Hello, from claimit app 

            Your one-time verification code (OTP) is: {otp}

            This code is valid for 10 minutes. Please do not share it with anyone.
            """
            message.attach(MIMEText(body, "plain"))

            # Connect to Gmail's SMTP Server over TLS secure connection
            server = smtplib.SMTP("smtp.gmail.com", 587)
            server.starttls() 
            
            # Authenticate and transmit
            server.login(sender_email, sender_password)
            server.sendmail(sender_email, phone, message.as_string())
            server.quit()

            print(f"📧 Real Email successfully dispatched to {phone}")
            return True

        except Exception as e:
            print(f"❌ Failed to send email via SMTP: {str(e)}")
            return False

    # 2. Fallback for phone numbers (integrate Twilio/MSG91 here later)
    else:
        print(f"📱 Phone number detected. OTP Logged: {phone} -> {otp}")
        return True