"""
Public home banner endpoint — no auth required.
Serves home_banner ads from ads_collection in _BannerData format
used by the Flutter dashboard screen.

  GET /banners   → { banners: [{ id, image_url, headline, sub, cta_link }] }
"""

from fastapi import APIRouter
from database import ads_collection
from datetime import datetime

router = APIRouter()


def _serialize_banner(ad: dict) -> dict:
    return {
        "id": str(ad["_id"]),
        "image_url": ad.get("image_url") or ad.get("creative_url") or "",
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
