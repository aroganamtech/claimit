import asyncio
import random
import smtplib
import ssl
import string
from datetime import datetime, timedelta
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from ..database import get_db
from ..config import get_settings

settings = get_settings()

# Lazy-load Twilio client so the app still starts if twilio isn't installed yet
_twilio_client = None

def _get_twilio_client():
    global _twilio_client
    if _twilio_client is None:
        try:
            from twilio.rest import Client
            if settings.twilio_account_sid and settings.twilio_auth_token:
                _twilio_client = Client(settings.twilio_account_sid, settings.twilio_auth_token)
        except ImportError:
            print("⚠️  twilio package not installed. Run: pip install twilio")
    return _twilio_client


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


def _format_e164(phone: str) -> str:
    """
    Convert a raw phone number to E.164 format required by Twilio.
    - Already has '+' prefix  → return as-is
    - 10-digit Indian mobile  → prepend +91
    - Any other number without '+' → prepend the configured default country code
    """
    # Strip spaces/dashes/dots
    cleaned = phone.strip().replace(" ", "").replace("-", "").replace(".", "")

    if cleaned.startswith("+"):
        return cleaned  # already E.164

    # 10-digit number → assume Indian (+91)
    if len(cleaned) == 10:
        return f"+91{cleaned}"

    # Use default country code from settings if provided, else +91
    default_code = getattr(settings, "twilio_default_country_code", "+91").strip()
    if not default_code.startswith("+"):
        default_code = f"+{default_code}"
    return f"{default_code}{cleaned}"


def _build_otp_email(to_email: str, otp: str) -> MIMEMultipart:
    """Build a formatted HTML OTP email."""
    msg = MIMEMultipart("alternative")
    msg["Subject"] = f"{otp} is your Claimit OTP"
    msg["From"] = f"{settings.smtp_from_name} <{settings.smtp_username}>"
    msg["To"] = to_email

    plain = (
        f"Your Claimit OTP is: {otp}\n\n"
        f"This code is valid for 10 minutes. Do not share it with anyone."
    )
    html = f"""
    <html>
      <body style="font-family:Arial,sans-serif;background:#f4f4f4;padding:30px;">
        <div style="max-width:480px;margin:auto;background:#fff;border-radius:10px;
                    padding:32px;box-shadow:0 2px 8px rgba(0,0,0,0.08);">
          <h2 style="color:#2563eb;margin-top:0;">Claimit Login OTP</h2>
          <p style="color:#374151;font-size:15px;">Use the code below to log in to your account:</p>
          <div style="text-align:center;margin:28px 0;">
            <span style="font-size:36px;font-weight:bold;letter-spacing:10px;
                         color:#111827;background:#f3f4f6;padding:14px 28px;
                         border-radius:8px;">{otp}</span>
          </div>
          <p style="color:#6b7280;font-size:13px;">
            This code expires in <strong>10 minutes</strong>.<br>
            If you didn't request this, please ignore this email.
          </p>
          <hr style="border:none;border-top:1px solid #e5e7eb;margin:24px 0;">
          <p style="color:#9ca3af;font-size:12px;text-align:center;">
            &copy; Claimit &mdash; Do not reply to this email.
          </p>
        </div>
      </body>
    </html>
    """
    msg.attach(MIMEText(plain, "plain"))
    msg.attach(MIMEText(html, "html"))
    return msg


def _send_email_sync(to_email: str, otp: str) -> None:
    """Blocking SMTP send — run this inside an executor to avoid blocking the event loop."""
    msg = _build_otp_email(to_email, otp)
    context = ssl.create_default_context()
    with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=8) as server:
        server.ehlo()
        server.starttls(context=context)
        server.login(settings.smtp_username, settings.smtp_password)
        server.sendmail(settings.smtp_username, to_email, msg.as_string())


async def send_otp_email(email: str, otp: str) -> bool:
    """
    Send OTP to an email address via SMTP (non-blocking).
    Falls back to console log if SMTP credentials are not configured.
    """
    if not settings.smtp_username or not settings.smtp_password:
        print(f"⚠️  SMTP not configured — OTP for {email}: {otp}")
        return True

    try:
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, _send_email_sync, email, otp)
        print(f"✅ OTP email sent to {email}")
        return True
    except Exception as e:
        print(f"❌ SMTP email failed for {email}: {e}")
        # Don't break the login flow — the OTP is still stored in DB
        return True


async def send_otp_sms(phone: str, otp: str) -> bool:
    """
    Route OTP delivery based on identifier type:
      • Email address  → SMTP email
      • Phone number   → Twilio SMS (auto-formatted to E.164)
    Falls back to console log if the respective provider is not configured.
    """
    # ── Email path ────────────────────────────────────────────────────────────
    if "@" in phone:
        return await send_otp_email(phone, otp)

    # ── SMS path ──────────────────────────────────────────────────────────────
    e164_phone = _format_e164(phone)
    message_body = f"Your Claimit OTP is: {otp}. Valid for 10 minutes. Do not share it with anyone."

    client = _get_twilio_client()
    if client and settings.twilio_phone_number:
        try:
            message = client.messages.create(
                body=message_body,
                from_=settings.twilio_phone_number,
                to=e164_phone,
            )
            print(f"✅ OTP SMS sent to {e164_phone} | Twilio SID: {message.sid}")
            return True
        except Exception as e:
            print(f"❌ Twilio SMS failed for {e164_phone}: {e}")
    else:
        print(f"⚠️  Twilio not configured — OTP for {e164_phone}: {otp}")

    return True
