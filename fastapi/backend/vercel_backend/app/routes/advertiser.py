"""
Advertiser portal routes.

Endpoints
─────────
POST /advertiser/presign-upload          — get a presigned S3 PUT URL (direct browser → S3 upload)
POST /advertiser/ads/create              — save ad metadata (with S3 keys) to MongoDB
GET  /advertiser/ads                     — list this advertiser's ads
GET  /advertiser/dashboard               — summary stats
GET  /advertiser/transactions            — payment history
GET  /advertiser/profile                 — advertiser profile

Video upload flow (bypasses Vercel 4.5 MB limit):
  1. Browser calls POST /advertiser/presign-upload  → receives { upload_url, key }
  2. Browser PUTs video/image directly to S3 using upload_url
  3. Browser calls POST /advertiser/ads/create with key in body (no file)
"""

import os
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Header
from pydantic import BaseModel

from ..database import get_db
from ..utils.auth import get_current_user
from ..utils.helpers import serialize_doc
from ..utils.s3 import (
    generate_presigned_upload_url,
    generate_presigned_url,
    generate_video_url,
    ALLOWED_VIDEO_TYPES,
    ALLOWED_IMAGE_TYPES,
)

router = APIRouter(prefix="/advertiser", tags=["Advertiser"])

AD_PRICES = {
    "home_banner":  840,
    "promo_reelz":  1400,
    "brand_deals":  1400,
    "nearby_deals": 1400,
}

AD_DURATION_DAYS = 7


# ── Presign upload ─────────────────────────────────────────────────────────────

class PresignRequest(BaseModel):
    filename: str
    content_type: str
    folder: str = "ads"  # "ads" for images, "videos" for reels


@router.post("/presign-upload")
async def presign_upload(
    body: PresignRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Returns a presigned S3 PUT URL so the browser uploads directly to S3.
    The browser must send the file with the exact Content-Type returned here.
    """
    is_video = body.content_type in ALLOWED_VIDEO_TYPES
    is_image = body.content_type in ALLOWED_IMAGE_TYPES

    if not is_video and not is_image:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported content type: {body.content_type}. Allowed: mp4, mov, webm, jpg, png"
        )

    result = generate_presigned_upload_url(
        folder=body.folder,
        filename=body.filename,
        content_type=body.content_type,
        is_video=is_video,
    )
    return result


# ── Create Ad ─────────────────────────────────────────────────────────────────

class CreateAdRequest(BaseModel):
    ad_type: str
    pincode: str = "000000"
    publish_today: bool = True
    scheduled_date: Optional[str] = None

    # S3 keys set after direct-to-S3 upload
    creative_key: Optional[str] = None       # video key (promo_reelz) or image key (others)
    thumbnail_key: Optional[str] = None      # thumbnail image key (promo_reelz only)

    # Ad-type specific fields
    headline: Optional[str] = None
    sub: Optional[str] = None
    cta_link: Optional[str] = None
    shop_name: Optional[str] = None
    shop_location: Optional[str] = None
    shop_category: Optional[str] = None
    caption: Optional[str] = None
    name: Optional[str] = None
    offer: Optional[str] = None
    location: Optional[str] = None
    type: Optional[str] = None


@router.post("/ads/create")
async def create_ad(
    body: CreateAdRequest,
    current_user: dict = Depends(get_current_user),
):
    if body.ad_type not in AD_PRICES:
        raise HTTPException(status_code=400, detail=f"Unknown ad_type: {body.ad_type}")

    db = get_db()
    now = datetime.utcnow()

    # Resolve publish date
    if body.publish_today or not body.scheduled_date:
        publish_date = now
    else:
        try:
            publish_date = datetime.strptime(body.scheduled_date, "%Y-%m-%d")
        except ValueError:
            publish_date = now

    end_date = publish_date + timedelta(days=AD_DURATION_DAYS)

    # Build document
    doc = {
        "ad_type": body.ad_type,
        "pincode": body.pincode,
        "status": "active" if body.publish_today else "scheduled",
        "publish_date": publish_date.strftime("%d/%m/%Y"),
        "end_date": end_date.strftime("%d/%m/%Y"),
        "amount": AD_PRICES[body.ad_type],
        "created_at": now,
        "advertiser_id": str(current_user["_id"]),
        "advertiser_email": current_user.get("email", ""),

        # S3 keys — store keys, serve presigned URLs on read
        "creative_key": body.creative_key,
        "thumbnail_key": body.thumbnail_key,

        # Metadata fields
        "headline": body.headline,
        "sub": body.sub,
        "cta_link": body.cta_link,
        "shop_name": body.shop_name,
        "shop_location": body.shop_location,
        "shop_category": body.shop_category,
        "caption": body.caption,
        "name": body.name,
        "offer": body.offer,
        "location": body.location,
        "type": body.type,
    }

    # Remove None fields
    doc = {k: v for k, v in doc.items() if v is not None}

    result = await db.ads.insert_one(doc)
    ad_id = str(result.inserted_id)

    # If it's a promo reel, also insert into reels collection so Flutter feed picks it up
    if body.ad_type == "promo_reelz" and body.creative_key:
        reel_doc = {
            "title": body.shop_name or body.name or "Promo Reel",
            "caption": body.caption or body.offer or "",
            "shop_name": body.shop_name or body.name or "",
            "location": body.shop_location or body.location or "",
            "category": body.shop_category or body.type or "",
            "video_key": body.creative_key,
            "thumbnail_key": body.thumbnail_key,
            "ad_id": ad_id,
            "source": "advertiser",
            "liked_by": [],
            "view_count": 0,
            "created_at": now,
        }
        await db.reels.insert_one(reel_doc)

    # Also insert into banners if home_banner
    if body.ad_type == "home_banner" and body.creative_key:
        banner_doc = {
            "ad_type": "home_banner",
            "headline": body.headline or "",
            "sub": body.sub or "",
            "cta_link": body.cta_link or "",
            "image_key": body.creative_key,
            "status": doc["status"],
            "publish_date": doc["publish_date"],
            "end_date": doc["end_date"],
            "created_at": now,
        }
        await db.banners.insert_one(banner_doc)

    return {
        "id": ad_id,
        "ad_type": body.ad_type,
        "publish_date": doc["publish_date"],
        "end_date": doc["end_date"],
        "amount": AD_PRICES[body.ad_type],
        "status": doc["status"],
    }


# ── List Ads ───────────────────────────────────────────────────────────────────

@router.get("/ads")
async def list_ads(
    status: str = "all",
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    query = {"advertiser_id": str(current_user["_id"])}
    if status != "all":
        query["status"] = status

    docs = await db.ads.find(query).sort("created_at", -1).to_list(100)
    ads = []
    for d in docs:
        d = serialize_doc(d)
        # Resolve presigned URLs for creative and thumbnail
        if d.get("creative_key"):
            if d.get("ad_type") == "promo_reelz":
                d["video_url"] = generate_video_url_sync(d["creative_key"])
            else:
                d["image_url"] = generate_presigned_url_sync(d["creative_key"])
        if d.get("thumbnail_key"):
            d["thumbnail_url"] = generate_presigned_url_sync(d["thumbnail_key"])
        ads.append(d)
    return {"ads": ads}


# ── Dashboard ─────────────────────────────────────────────────────────────────

@router.get("/dashboard")
async def dashboard(current_user: dict = Depends(get_current_user)):
    db = get_db()
    advertiser_id = str(current_user["_id"])

    total = await db.ads.count_documents({"advertiser_id": advertiser_id})
    active = await db.ads.count_documents({"advertiser_id": advertiser_id, "status": "active"})
    scheduled = await db.ads.count_documents({"advertiser_id": advertiser_id, "status": "scheduled"})

    # Total spend
    pipeline = [
        {"$match": {"advertiser_id": advertiser_id}},
        {"$group": {"_id": None, "total": {"$sum": "$amount"}}},
    ]
    spend_result = await db.ads.aggregate(pipeline).to_list(1)
    total_spend = spend_result[0]["total"] if spend_result else 0

    return {
        "total_ads": total,
        "active_ads": active,
        "scheduled_ads": scheduled,
        "total_spend": total_spend,
    }


# ── Transactions ──────────────────────────────────────────────────────────────

@router.get("/transactions")
async def transactions(current_user: dict = Depends(get_current_user)):
    db = get_db()
    docs = await db.ads.find(
        {"advertiser_id": str(current_user["_id"])},
        {"ad_type": 1, "amount": 1, "publish_date": 1, "status": 1, "created_at": 1}
    ).sort("created_at", -1).to_list(100)
    return {"transactions": [serialize_doc(d) for d in docs]}


# ── Profile ───────────────────────────────────────────────────────────────────

@router.get("/profile")
async def profile(current_user: dict = Depends(get_current_user)):
    return {
        "id": str(current_user["_id"]),
        "name": current_user.get("name", ""),
        "email": current_user.get("email", ""),
        "phone": current_user.get("phone", ""),
    }
