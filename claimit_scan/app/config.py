"""
Configuration — every value from the environment, nothing hard-coded.

The scan service holds two things worth stealing: an Azure key that costs
₹1 per call, and a database credential. Neither appears in this repository,
in the APK, or in any log line.
"""
import os
from functools import lru_cache


class Settings:
    # ── Azure Document Intelligence ──────────────────────────────────────
    AZURE_ENDPOINT: str = os.getenv("AZURE_DI_ENDPOINT", "").rstrip("/")
    AZURE_KEY: str      = os.getenv("AZURE_DI_KEY", "")
    AZURE_API_VERSION: str = os.getenv("AZURE_DI_API_VERSION", "2024-11-30")
    AZURE_TIMEOUT: float   = float(os.getenv("AZURE_DI_TIMEOUT", "25"))

    # ── Database ─────────────────────────────────────────────────────────
    # A SCOPED user with readWrite on claimit_scan ONLY. Never the admin
    # superuser, and never the credential the app API uses: if this service
    # is ever compromised, the blast radius stops at its own database.
    MONGODB_URL: str = os.getenv("MONGODB_URL", "")
    DB_NAME: str     = os.getenv("SCAN_DB_NAME", "claimit_scan")

    # ── Auth ─────────────────────────────────────────────────────────────
    # Same secret the app API signs with, so an existing token just works.
    # Verified locally — no call back to 8001, so a restart there cannot
    # take scanning down.
    JWT_SECRET: str    = os.getenv("JWT_SECRET", "")
    JWT_ALGORITHM: str = os.getenv("JWT_ALGORITHM", "HS256")

    # ── S3 ───────────────────────────────────────────────────────────────
    S3_BUCKET: str   = os.getenv("S3_BUCKET_NAME", "")
    AWS_REGION: str  = os.getenv("AWS_REGION", "eu-north-1")
    # Credentials come from the EC2 instance role. Leave the key vars unset.

    # ── Policy. Tune without a code change. ──────────────────────────────
    CONF_AUTO: float      = float(os.getenv("SCAN_CONF_AUTO", "0.85"))
    CONF_REVIEW: float    = float(os.getenv("SCAN_CONF_REVIEW", "0.60"))
    PHASH_DIST: int       = int(os.getenv("SCAN_PHASH_DIST", "3"))
    MAX_BILL_AGE_DAYS: int = int(os.getenv("SCAN_MAX_BILL_AGE_DAYS", "30"))
    MIN_BILL_AMOUNT: float = float(os.getenv("SCAN_MIN_BILL_AMOUNT", "50"))
    MAX_BILL_AMOUNT: float = float(os.getenv("SCAN_MAX_BILL_AMOUNT", "100000"))
    DRAFT_TTL_MIN: int     = int(os.getenv("SCAN_DRAFT_TTL_MIN", "30"))
    MAX_IMAGE_BYTES: int   = int(os.getenv("SCAN_MAX_IMAGE_BYTES", str(8 * 1024 * 1024)))

    # ── Rate limits, per user ────────────────────────────────────────────
    RATE_PER_MIN: int  = int(os.getenv("SCAN_RATE_PER_MIN", "6"))
    RATE_PER_DAY: int  = int(os.getenv("SCAN_RATE_PER_DAY", "40"))

    def validate(self) -> list[str]:
        """Refuse to start half-configured — a missing secret must be loud."""
        missing = [n for n in ("AZURE_ENDPOINT", "AZURE_KEY", "MONGODB_URL",
                               "JWT_SECRET", "S3_BUCKET")
                   if not getattr(self, n)]
        return missing


@lru_cache
def settings() -> Settings:
    return Settings()
