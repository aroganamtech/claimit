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
    # Store files in MongoDB (base64) or use an external service like Cloudinary.
    max_file_size_mb: int = 10

    class Config:
        # On Vercel, all vars come from the dashboard (env vars).
        # Locally, a .env file in this folder is also read.
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
