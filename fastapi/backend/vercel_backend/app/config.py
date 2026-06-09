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
    # upload_dir removed — Vercel has no persistent filesystem.
    max_file_size_mb: int = 10
    # Video storage — files go directly browser → S3 (presigned PUT URLs).
    # Vercel's 4.5 MB request limit is never hit for video uploads.
    aws_access_key_id: str = ""
    aws_secret_access_key: str = ""
    aws_region: str = "eu-north-1"
    aws_storage_bucket_name: str = "claimit-image-bucket"
    aws_video_bucket_name: str = ""   # leave empty to use same bucket as images
    max_video_size_mb: int = 100

    # Twilio (OTP delivery)
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_phone_number: str = ""         # SMS fallback number
    twilio_whatsapp_number: str = ""      # WhatsApp sender number (e.g. +14155238886)
    twilio_default_country_code: str = "+91"

    # SMTP email (OTP fallback)
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_username: str = ""
    smtp_password: str = ""
    smtp_from_name: str = "Claimit"

    # Firebase Cloud Messaging (push notifications)
    # Vercel has no persistent filesystem, so use FIREBASE_SERVICE_ACCOUNT_JSON
    # (paste the ENTIRE service-account JSON contents as one env var value).
    firebase_project_id: str = ""
    firebase_service_account_json: str = ""
    firebase_service_account_path: str = ""

    class Config:
        # On Vercel, all vars come from the dashboard (env vars).
        # Locally, a .env file in this folder is also read.
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
