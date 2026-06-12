"""
Public home banner endpoint — no auth required.
Serves home_banner ads from ads_collection in _BannerData format
used by the Flutter dashboard screen.

  GET /banners   → { banners: [{ id, image_url, headline, sub, cta_link }] }
"""

from fastapi import APIRouter
from database import ads_collection
from datetime import datetime
from utils.s3 import generate_presigned_url_sync as _presign

router = APIRouter()


def _image_url(ad: dict) -> str:
    """Prefer a freshly-presigned URL from the stored S3 key; fall back to
    whatever raw URL/key is on the document (handles legacy ads)."""
    key = ad.get("image_s3_key") or ""
    url = _presign(key) if key else ""
    if url:
        return url
    stored = ad.get("image_url") or ad.get("creative_url") or ""
    if stored.startswith("https://") and ".amazonaws.com/" in stored:
        from urllib.parse import urlparse
        derived_key = urlparse(stored).path.lstrip("/")
        presigned = _presign(derived_key) or ""
        if presigned:
            return presigned
    return stored


def _serialize_banner(ad: dict) -> dict:
    return {
        "id": str(ad["_id"]),
        "image_url": _image_url(ad),
        "headline": ad.get("headline") or ad.get("title") or "EXCLUSIVE OFFERS!",
        "sub": ad.get("sub") or ad.get("description") or "Shop and save big",
        "cta_link": ad.get("cta_link") or "",
        "pincode": ad.get("pincode") or "",
    }


def _is_active(ad: dict) -> bool:
    status = ad.get("status", "active")
    if status == "active":
        return True
    if status == "scheduled":
        pub = ad.get("publish_date", "")
        try:
            return datetime.utcnow() >= datetime.strptime(pub, "%d/%m/%Y")
        except Exception:
            return True
    return False


@router.get("")
async def get_banners():
    ads = await ads_collection.find(
        {"ad_type": "home_banner"}
    ).sort("created_at", -1).to_list(50)
    banners = [_serialize_banner(a) for a in ads if _is_active(a)]
    return {"banners": banners}
