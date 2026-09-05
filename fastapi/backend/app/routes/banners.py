"""
Banners endpoint — serves home_banner ads from claimit_db.banners.
Written there by the web portal whenever an advertiser creates a
home_banner ad via POST /advertiser/ads/create.

GET /banners   → { banners: [...] }   (no auth required)
"""
from typing import Optional
from fastapi import APIRouter, Query
from datetime import datetime

from ..database import get_db
from ..utils.helpers import serialize_doc, prioritize_by_location
from ..utils.ad_window import is_live
from ..utils.s3 import public_url, generate_video_url_sync

router = APIRouter(prefix="/banners", tags=["Banners"])


def _is_active(banner: dict) -> bool:
    """Inside its paid Friday→Thursday week.

    Replaces a check that only ever looked at the START date, which meant a
    finished banner campaign kept showing forever. ad_window.is_live checks
    both ends and understands the real `publish_at` / `ends_at` datetimes as
    well as the older "dd/mm/yyyy" strings.
    """
    return is_live(banner)


@router.get("")
async def get_banners(
    area: Optional[str] = Query(None, description="User's area — local banners float to top"),
    pincode: Optional[str] = Query(None, description="User's pincode — local banners float to top"),
):
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
        # Video banner support — media_type discriminates image vs video.
        video_key = doc.get("video_s3_key") or doc.get("video_key") or ""
        media_type = doc.get("media_type") or ("video" if video_key else "image")
        doc["media_type"] = media_type
        if video_key:
            doc["video_url"] = generate_video_url_sync(video_key) or public_url(video_key)
        else:
            doc.setdefault("video_url", "")
        active.append(doc)
    # Location-aware ordering: banners for the user's pincode/area first
    active = prioritize_by_location(active, area or "", pincode or "")
    return {"success": True, "banners": active}
