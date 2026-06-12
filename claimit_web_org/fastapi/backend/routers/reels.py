"""
Public reels endpoints — no auth for GET, optional auth for like/view.
Serves promo_reelz ads from ads_collection in ReelItem format.

  GET  /reels                → { reels: [...] }
  POST /reels/{id}/like      → { like_count, liked_by_me }
  POST /reels/{id}/view      → { view_count }
"""

from fastapi import APIRouter, HTTPException, Depends, Body
from database import ads_collection
from bson import ObjectId
from datetime import datetime
from utils.dependencies import get_current_user_optional
from utils.s3 import generate_presigned_url_sync as _presign
from typing import Optional

router = APIRouter()


def _media_url(ad: dict, key_field: str, url_fields: list[str]) -> str:
    """Prefer a freshly-presigned URL from the stored S3 key; fall back to
    whatever raw URL/key is on the document (handles legacy ads)."""
    key = ad.get(key_field) or ""
    url = _presign(key) if key else ""
    if url:
        return url
    for f in url_fields:
        stored = ad.get(f) or ""
        if stored:
            if stored.startswith("https://") and ".amazonaws.com/" in stored:
                from urllib.parse import urlparse
                derived_key = urlparse(stored).path.lstrip("/")
                presigned = _presign(derived_key) or ""
                if presigned:
                    return presigned
            return stored
    return ""


def _serialize_reel(ad: dict, user_id: Optional[str] = None) -> dict:
    """Map a MongoDB promo_reelz document → ReelItem shape."""
    liked_ids: list = ad.get("liked_by", [])
    liked_by_me = user_id in liked_ids if user_id else False
    return {
        "id": str(ad["_id"]),
        "shop_name": ad.get("shop_name") or ad.get("title") or "",
        "shop_location": ad.get("shop_location") or ad.get("location") or "",
        "shop_category": ad.get("shop_category") or ad.get("type") or "",
        "caption": ad.get("caption") or ad.get("description") or "",
        "offer": ad.get("offer") or "",
        "video_url": _media_url(ad, "video_s3_key", ["video_url", "creative_url"]),
        "thumbnail_url": _media_url(ad, "thumbnail_s3_key", ["thumbnail_url", "image_url"]),
        "like_count": int(ad.get("like_count") or 0),
        "view_count": int(ad.get("view_count") or 0),
        "tag": ad.get("tag") or "",
        "liked_by_me": liked_by_me,
    }


@router.get("")
async def get_reels(current_user=Depends(get_current_user_optional)):
    user_id = str(current_user["_id"]) if current_user else None
    ads = await ads_collection.find({"ad_type": "promo_reelz", "status": {"$in": ["active", "scheduled"]}}).sort("created_at", -1).to_list(200)
    return {"reels": [_serialize_reel(a, user_id) for a in ads]}


@router.post("/{reel_id}/like")
async def like_reel(
    reel_id: str,
    payload: dict = Body(default={}),
    current_user=Depends(get_current_user_optional)
):
    try:
        oid = ObjectId(reel_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid reel ID")

    ad = await ads_collection.find_one({"_id": oid})
    if not ad:
        raise HTTPException(status_code=404, detail="Reel not found")

    liked: bool = payload.get("liked", True)
    user_id = str(current_user["_id"]) if current_user else None
    liked_by: list = ad.get("liked_by", [])

    if user_id:
        if liked and user_id not in liked_by:
            liked_by.append(user_id)
        elif not liked and user_id in liked_by:
            liked_by.remove(user_id)

    new_count = len(liked_by)
    await ads_collection.update_one(
        {"_id": oid},
        {"$set": {"like_count": new_count, "liked_by": liked_by}}
    )
    return {"like_count": new_count, "liked_by_me": liked}


@router.post("/{reel_id}/view")
async def view_reel(reel_id: str):
    try:
        oid = ObjectId(reel_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid reel ID")

    result = await ads_collection.find_one_and_update(
        {"_id": oid},
        {"$inc": {"view_count": 1}},
        return_document=True
    )
    if not result:
        raise HTTPException(status_code=404, detail="Reel not found")
    return {"view_count": int(result.get("view_count") or 0)}
