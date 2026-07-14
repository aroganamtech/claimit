from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    mongodb_url: str
    database_name: str = "claimit_db"
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 1440
    refresh_token_expire_days: int = 30
    static_otp: str = "123456"
    upload_dir: str = "uploads"
    max_file_size_mb: int = 10

    # Twilio credentials
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_phone_number: str = ""          # legacy SMS number (kept for fallback)
    twilio_whatsapp_number: str = ""       # WhatsApp sender e.g. +14155238886 (Twilio sandbox or approved number)
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

    # Cashfree Payment Gateway (Local Finds / Local Classifieds listing fees).
    # cashfree_env: "TEST" uses the sandbox API (safe, no real money moves),
    # "PROD" switches to the live API. Leave the id/key blank until you have
    # real credentials — payment endpoints return a clear error instead of
    # crashing when they're unset.
    cashfree_app_id: str = ""
    cashfree_secret_key: str = ""
    cashfree_env: str = "TEST"

    class Config:
        env_file = ".env"
        extra = "ignore"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
