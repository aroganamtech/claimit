"""
Banners endpoint — serves home_banner ads from claimit_db.banners.
Written there by the web portal whenever an advertiser creates a
home_banner ad via POST /advertiser/ads/create.

GET /banners   → { banners: [...] }   (no auth required)
"""
from fastapi import APIRouter
from datetime import datetime

from ..database import get_db
from ..utils.helpers import serialize_doc
from ..utils.s3 import public_url

router = APIRouter(prefix="/banners", tags=["Banners"])


def _is_active(banner: dict) -> bool:
    status = banner.get("status", "active")
    if status == "active":
        return True
    if status == "scheduled":
        pub = banner.get("publish_date", "")
        try:
            return datetime.utcnow() >= datetime.strptime(pub, "%d/%m/%Y")
        except Exception:
            return True
    return False


@router.get("")
async def get_banners():
    """Return all active home-banner ads for the Flutter home screen."""
    db = get_db()
    banners = await db.banners.find({}).sort("created_at", -1).to_list(50)
    active = []
    for b in banners:
        if not _is_active(b):
            continue
        doc = serialize_doc(b)
        # Always build a permanent public URL from the S3 key
        key = doc.get("image_s3_key") or doc.get("image_key") or ""
        if key:
            doc["image_url"] = public_url(key)
        active.append(doc)
    return {"success": True, "banners": active}
