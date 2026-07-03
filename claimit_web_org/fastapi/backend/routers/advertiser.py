from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from database import (
    ads_collection, transactions_collection,
    app_deals_collection, app_reels_collection, app_banners_collection,
)
from utils.dependencies import get_current_user
from utils.s3 import (
    generate_presigned_upload_url,
    generate_presigned_url_sync as _presign,
    generate_video_url_sync as _video_presign,
    ALLOWED_VIDEO_TYPES, ALLOWED_IMAGE_TYPES,
)
from bson import ObjectId
from datetime import datetime, timedelta
from typing import Optional
import json

router = APIRouter()

AD_PRICES = {
    "home_banner": 840,
    "promo_reelz": 1400,
    "brand_deals": 1400,
    "nearby_deals": 1400,
}

VIDEO_EXTENSIONS = (".mp4", ".mov", ".m4v", ".webm")


def _is_video_key(key: str) -> bool:
    """Best-effort video detection from an S3 key's file extension."""
    return bool(key) and key.lower().endswith(VIDEO_EXTENSIONS)


def serialize_ad(ad):
    ad["id"] = str(ad["_id"])
    del ad["_id"]
    # Reels track views in view_count and likes in like_count.
    # Normalize to a single "views" and "like_count" field so the
    # advertiser dashboard can display them in a uniform way.
    if ad.get("ad_type") == "promo_reelz":
        ad["views"] = int(ad.get("view_count") or 0)
        ad["like_count"] = int(ad.get("like_count") or 0)
    else:
        ad.setdefault("views", 0)
        ad["like_count"] = 0
    return ad


# ── Presign upload (direct browser -> S3, bypasses Vercel 4.5 MB limit) ───────

class PresignRequest(BaseModel):
    filename: str
    content_type: str
    folder: str = "ads"


@router.post("/presign-upload")
async def presign_upload(body: PresignRequest, current_user=Depends(get_current_user)):
    is_video = body.content_type in ALLOWED_VIDEO_TYPES
    is_image = body.content_type in ALLOWED_IMAGE_TYPES
    if not is_video and not is_image:
        raise HTTPException(status_code=400,
            detail=f"Unsupported type: {body.content_type}")
    return generate_presigned_upload_url(
        folder=body.folder,
        filename=body.filename,
        content_type=body.content_type,
        is_video=is_video,
    )


# ── Create ad (JSON body — creative_key / thumbnail_key from direct S3 upload) -

class CreateAdRequest(BaseModel):
    ad_type: str
    pincode: str = "000000"
    publish_today: bool = True
    scheduled_date: Optional[str] = None
    creative_key: Optional[str] = None
    thumbnail_key: Optional[str] = None
    # Home banner
    headline: Optional[str] = None
    sub: Optional[str] = None
    cta_link: Optional[str] = None
    # Promo reelz
    shop_name: Optional[str] = None
    shop_location: Optional[str] = None
    shop_category: Optional[str] = None
    caption: Optional[str] = None
    tag: Optional[str] = None
    # Deal
    name: Optional[str] = None
    location: Optional[str] = None
    description: Optional[str] = None
    address: Optional[str] = None
    phone: Optional[str] = None
    timing: Optional[str] = None
    type: Optional[str] = None
    cashback: Optional[str] = None
    distance: Optional[str] = None
    tags: Optional[str] = None
    offer: Optional[str] = None
    title: Optional[str] = None


@router.post("/ads/create")
async def create_ad(body: CreateAdRequest, current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    ad_type = body.ad_type
    amount  = AD_PRICES.get(ad_type, 1400)

    if publish_today := body.publish_today:
        pub_date = datetime.utcnow()
    else:
        try:
            pub_date = datetime.strptime(body.scheduled_date, "%Y-%m-%d") if body.scheduled_date else datetime.utcnow()
        except ValueError:
            pub_date = datetime.utcnow()
    end_date  = pub_date + timedelta(days=7)
    ad_status = "active" if body.publish_today else "scheduled"

    # Resolve S3 keys to presigned URLs
    creative_s3_key  = body.creative_key or ""
    thumbnail_s3_key = body.thumbnail_key or ""

    # home_banner now supports either an image OR a video creative — detect by
    # the uploaded file's extension (promo_reelz is always video).
    is_video = ad_type == "promo_reelz" or (
        ad_type == "home_banner" and _is_video_key(creative_s3_key)
    )
    creative_url  = (_video_presign(creative_s3_key) if is_video else _presign(creative_s3_key)) if creative_s3_key else ""
    thumbnail_url = _presign(thumbnail_s3_key) if thumbnail_s3_key else ""

    parsed_tags: list = []
    if body.tags:
        try:
            parsed_tags = json.loads(body.tags)
        except Exception:
            parsed_tags = [t.strip() for t in body.tags.split(",") if t.strip()]

    ad_doc = {
        "user_id":    user_id,
        "ad_type":    ad_type,
        "pincode":    body.pincode,
        "publish_date": pub_date.strftime("%d/%m/%Y"),
        "end_date":   end_date.strftime("%d/%m/%Y"),
        "amount":     amount,
        "status":     ad_status,
        "views":      0,
        "clicks":     0,
        "created_at": datetime.utcnow(),
    }

    if ad_type == "home_banner":
        ad_doc.update({
            "headline":     body.headline or body.title or "",
            "sub":          body.sub or body.description or "",
            "cta_link":     body.cta_link or "",
            "media_type":   "video" if is_video else "image",
            "image_s3_key": "" if is_video else creative_s3_key,
            "image_url":    "" if is_video else creative_url,
            "video_s3_key": creative_s3_key if is_video else "",
            "video_url":    creative_url if is_video else "",
            "title":        body.headline or body.title or "",
        })

    elif ad_type == "promo_reelz":
        ad_doc.update({
            "shop_name":        body.shop_name or "",
            "shop_location":    body.shop_location or "",
            "shop_category":    body.shop_category or "",
            "caption":          body.caption or "",
            "offer":            body.offer or "",
            "tag":              body.tag or "",
            "video_s3_key":     creative_s3_key,
            "video_url":        creative_url,
            "thumbnail_s3_key": thumbnail_s3_key,
            "thumbnail_url":    thumbnail_url,
            "title":            body.shop_name or "",
        })

    elif ad_type in ("brand_deals", "nearby_deals"):
        ad_doc.update({
            "name":         body.name or "",
            "location":     body.location or "",
            "offer":        body.offer or "",
            "description":  body.description or "",
            "address":      body.address or "",
            "phone":        body.phone or "",
            "timing":       body.timing or "",
            "type":         body.type or "",
            "cashback":     body.cashback or "1% Cashback",
            "distance":     body.distance or "",
            "tags":         parsed_tags,
            "image_s3_key": creative_s3_key,
            "image_url":    creative_url,
            "rating":       4.0,
            "reviews":      0,
            "deal_group":   "brand" if ad_type == "brand_deals" else "nearby",
            "title":        body.name or "",
        })

    result = await ads_collection.insert_one(ad_doc)
    ad_id  = str(result.inserted_id)

    # Mirror into app-facing collections
    if ad_type == "home_banner":
        await app_banners_collection.insert_one({
            "web_ad_id":    ad_id,
            "headline":     ad_doc.get("headline", ""),
            "sub":          ad_doc.get("sub", ""),
            "cta_link":     ad_doc.get("cta_link", ""),
            "media_type":   ad_doc.get("media_type", "image"),
            "image_s3_key": ad_doc.get("image_s3_key", ""),
            "image_url":    ad_doc.get("image_url", ""),
            "video_s3_key": ad_doc.get("video_s3_key", ""),
            "video_url":    ad_doc.get("video_url", ""),
            "pincode":      body.pincode,
            "status":       ad_status,
            "end_date":     end_date.strftime("%d/%m/%Y"),
            "created_at":   datetime.utcnow(),
        })

    elif ad_type in ("brand_deals", "nearby_deals"):
        await app_deals_collection.insert_one({
            "web_ad_id":  ad_id,
            "deal_group": ad_doc["deal_group"],
            "name":       ad_doc.get("name", ""),
            "location":   ad_doc.get("location", ""),
            "offer":      ad_doc.get("offer", ""),
            "cashback":   ad_doc.get("cashback", "1% Cashback"),
            "distance":   ad_doc.get("distance", ""),
            "type":       ad_doc.get("type", ""),
            "category":   ad_doc.get("type", ""),
            "image_s3_key": creative_s3_key,
            "image_url":  creative_url,
            "description": ad_doc.get("description", ""),
            "address":    ad_doc.get("address", ""),
            "phone":      ad_doc.get("phone", ""),
            "timing":     ad_doc.get("timing", ""),
            "rating":     4.0,
            "reviews":    0,
            "tags":       parsed_tags,
            "pincode":    body.pincode,
            "status":     ad_status,
            "end_date":   end_date.strftime("%d/%m/%Y"),
            "created_at": datetime.utcnow(),
        })

    elif ad_type == "promo_reelz":
        await app_reels_collection.insert_one({
            "web_ad_id":        ad_id,
            "shop_name":        ad_doc.get("shop_name", ""),
            "shop_location":    ad_doc.get("shop_location", ""),
            "shop_category":    ad_doc.get("shop_category", ""),
            "caption":          ad_doc.get("caption", ""),
            "offer":            ad_doc.get("offer", ""),
            "video_s3_key":     creative_s3_key,
            "video_url":        creative_url,
            "thumbnail_s3_key": thumbnail_s3_key,
            "thumbnail_url":    thumbnail_url,
            "like_count":       0,
            "view_count":       0,
            "liked_by":         [],
            "tag":              ad_doc.get("tag", ""),
            "pincode":          body.pincode,
            "status":           ad_status,
            "end_date":         end_date.strftime("%d/%m/%Y"),
            "created_at":       datetime.utcnow(),
        })

    display_title = (
        ad_doc.get("headline") or ad_doc.get("name") or
        ad_doc.get("shop_name") or ad_doc.get("title") or ""
    )
    await transactions_collection.insert_one({
        "user_id":    user_id,
        "type":       "ad_purchase",
        "ad_id":      ad_id,
        "title":      display_title,
        "amount":     amount,
        "date":       pub_date.strftime("%d/%m/%Y"),
        "created_at": datetime.utcnow(),
    })

    return {
        "id":           ad_id,
        "ad_type":      ad_type,
        "publish_date": ad_doc["publish_date"],
        "end_date":     ad_doc["end_date"],
        "amount":       amount,
        "status":       ad_status,
    }


# ── Dashboard ─────────────────────────────────────────────────────────────────

@router.get("/dashboard")
async def get_dashboard(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    ads = await ads_collection.find({"user_id": user_id}).to_list(100)
    # Reels store views in view_count, others in views
    total_views = sum(
        int(a.get("view_count") or 0) if a.get("ad_type") == "promo_reelz"
        else int(a.get("views") or 0)
        for a in ads
    )
    total_clicks = sum(int(a.get("clicks") or 0) for a in ads)
    total_likes  = sum(int(a.get("like_count") or 0) for a in ads if a.get("ad_type") == "promo_reelz")
    return {
        "total_ads":    len(ads),
        "total_views":  total_views,
        "total_clicks": total_clicks,
        "total_likes":  total_likes,
        "ads": [serialize_ad(a) for a in ads],
    }


# ── List ads ──────────────────────────────────────────────────────────────────

@router.get("/ads")
async def get_ads(status: Optional[str] = None, current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    query = {"user_id": user_id}
    if status and status != "all":
        query["status"] = status
    ads = await ads_collection.find(query).to_list(100)
    return [serialize_ad(a) for a in ads]


# ── Transactions ──────────────────────────────────────────────────────────────

@router.get("/transactions")
async def get_transactions(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    txns = await transactions_collection.find(
        {"user_id": user_id, "type": "ad_purchase"}
    ).sort("created_at", -1).to_list(200)
    return [
        {
            "id":     str(t["_id"]),
            "title":  t.get("title", ""),
            "amount": t.get("amount", 0),
            "date":   t.get("date", ""),
            "ad_id":  t.get("ad_id", ""),
        }
        for t in txns
    ]


# ── Profile ───────────────────────────────────────────────────────────────────

@router.get("/profile")
async def get_profile(current_user=Depends(get_current_user)):
    return {
        "id":    str(current_user["_id"]),
        "name":  current_user.get("name", ""),
        "email": current_user.get("email", ""),
        "phone": current_user.get("phone", ""),
        "role":  current_user.get("role", ""),
    }
