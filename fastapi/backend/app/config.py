from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    mongodb_url: str
    database_name: str = "claimit_db"
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 1440
    refresh_token_expire_days: int = 30
    # Kept only so an existing STATIC_OTP line in .env doesn't fail validation.
    # NOTHING reads this any more — the login bypass it powered was removed
    # from utils/otp.py. Safe to delete from .env entirely.
    static_otp: str = ""
    upload_dir: str = "uploads"
    max_file_size_mb: int = 10

    # Twilio credentials
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_phone_number: str = ""          # legacy SMS number (kept for fallback)
    twilio_whatsapp_number: str = ""       # WhatsApp sender e.g. +14155238886 (Twilio sandbox or approved number)
    # Approved WhatsApp OTP template Content SID (HXxxxxxxxx). REQUIRED for
    # production WhatsApp (business-initiated messages must use an approved
    # template). Leave blank only for the Twilio sandbox / testing.
    twilio_otp_template_sid: str = ""
    # Approved templates for the OTHER WhatsApp messages (see utils/whatsapp.py).
    # WhatsApp forbids free-form business-initiated text, so each message type
    # needs its own approved template. Leave blank to keep that message type
    # off WhatsApp — the in-app notification and FCM push are unaffected.
    # claimit_welcome_bonus — {{1}} = name, {{2}} = cashback, {{3}} = points
    twilio_welcome_template_sid: str = ""
    twilio_notify_template_sid: str = ""    # notifications — {{1}} = title, {{2}} = message
    # Default country code prepended to 10-digit numbers (E.164 prefix, e.g. +91 for India)
    twilio_default_country_code: str = "+91"

    # SMTP email credentials (used to send OTP to email identifiers)
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_username: str = ""
    smtp_password: str = ""
    smtp_from_name: str = "Claimit"

    # AWS S3 storage credentials
    aws_access_key_id: str = ""
    aws_secret_access_key: str = ""
    aws_region: str = "eu-north-1"
    aws_storage_bucket_name: str = "claimit-image-bucket"
    # Separate S3 bucket for videos (reels / promo ads).
    # Leave empty to use the same bucket as images (videos stored under videos/ prefix).
    aws_video_bucket_name: str = ""
    max_video_size_mb: int = 100

    # Firebase Cloud Messaging (push notifications)
    # Provide EITHER a path to the service-account JSON file (local/server deploys
    # where the file is on disk) OR the raw JSON contents as one string (Vercel /
    # other serverless platforms with no persistent filesystem to read from).
    firebase_project_id: str = ""
    firebase_service_account_path: str = ""
    firebase_service_account_json: str = ""

    # Razorpay Payment Gateway (Local Finds / Local Classifieds listing fees).
    # Razorpay uses one API for both modes — the key decides which:
    #   rzp_test_...  -> test mode (safe, no real money moves)
    #   rzp_live_...  -> live mode (real charges)
    # Leave the id/secret blank until you have real credentials — payment
    # endpoints return a clear error instead of crashing when they're unset.
    razorpay_key_id: str = ""
    razorpay_key_secret: str = ""

    class Config:
        env_file = ".env"
        extra = "ignore"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
