from fastapi import APIRouter, Depends, UploadFile, File, Form
from database import (
    ads_collection, transactions_collection,
    app_deals_collection, app_reels_collection,
)
from utils.dependencies import get_current_user
from bson import ObjectId
from datetime import datetime, timedelta
from typing import Optional
import os, json

router = APIRouter()

AD_PRICES = {
    "home_banner": 840,
    "promo_reelz": 1400,
    "brand_deals": 1400,
    "nearby_deals": 1400,
}


def serialize_ad(ad):
    ad["id"] = str(ad["_id"])
    del ad["_id"]
    return ad


# ─── Dashboard ────────────────────────────────────────────────────────────────
@router.get("/dashboard")
async def get_dashboard(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    ads = await ads_collection.find({"user_id": user_id}).to_list(100)
    total_views = sum(a.get("views", 0) for a in ads)
    total_clicks = sum(a.get("clicks", 0) for a in ads)
    return {
        "total_ads": len(ads),
        "total_views": total_views,
        "total_clicks": total_clicks,
        "ads": [serialize_ad(a) for a in ads]
    }


# ─── List ads ─────────────────────────────────────────────────────────────────
@router.get("/ads")
async def get_ads(status: Optional[str] = None, current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    query = {"user_id": user_id}
    if status and status != "all":
        query["status"] = status
    ads = await ads_collection.find(query).to_list(100)
    return [serialize_ad(a) for a in ads]


# ─── Create ad ────────────────────────────────────────────────────────────────
@router.post("/ads/create")
async def create_ad(
    # Core
    ad_type:        str            = Form(...),
    pincode:        str            = Form(...),
    publish_today:  bool           = Form(True),
    scheduled_date: Optional[str]  = Form(None),
    creative:       Optional[UploadFile] = File(None),
    thumbnail:      Optional[UploadFile] = File(None),

    # Home banner
    headline:       Optional[str]  = Form(None),
    sub:            Optional[str]  = Form(None),
    cta_link:       Optional[str]  = Form(None),

    # Promo reelz
    shop_name:      Optional[str]  = Form(None),
    shop_location:  Optional[str]  = Form(None),
    shop_category:  Optional[str]  = Form(None),
    caption:        Optional[str]  = Form(None),
    tag:            Optional[str]  = Form(None),

    # Deal (nearby / brand)
    name:           Optional[str]  = Form(None),
    location:       Optional[str]  = Form(None),
    description:    Optional[str]  = Form(None),
    address:        Optional[str]  = Form(None),
    phone:          Optional[str]  = Form(None),
    timing:         Optional[str]  = Form(None),
    type:           Optional[str]  = Form(None),
    cashback:       Optional[str]  = Form(None),
    distance:       Optional[str]  = Form(None),
    tags:           Optional[str]  = Form(None),

    # Shared
    offer:          Optional[str]  = Form(None),
    title:          Optional[str]  = Form(None),   # legacy compat

    current_user=Depends(get_current_user)
):
    user_id = str(current_user["_id"])
    amount  = AD_PRICES.get(ad_type, 1400)

    # ── Publish date ──────────────────────────────────────────────────────────
    if publish_today:
        pub_date = datetime.utcnow()
    else:
        try:
            pub_date = datetime.strptime(scheduled_date, "%Y-%m-%d") if scheduled_date else datetime.utcnow()
        except ValueError:
            pub_date = datetime.utcnow()
    end_date = pub_date + timedelta(days=7)
    ad_status = "active" if publish_today else "scheduled"

    # ── Save uploaded files ───────────────────────────────────────────────────
    upload_dir = "uploads"
    os.makedirs(upload_dir, exist_ok=True)

    web_base = os.getenv("WEB_BASE_URL", "http://localhost:8000")

    creative_url = None
    if creative and creative.filename:
        safe = f"{user_id}_{int(pub_date.timestamp())}_{creative.filename}"
        with open(os.path.join(upload_dir, safe), "wb") as f:
            f.write(await creative.read())
        creative_url = f"{web_base}/uploads/{safe}"

    thumbnail_url = None
    if thumbnail and thumbnail.filename:
        safe = f"{user_id}_{int(pub_date.timestamp())}_thumb_{thumbnail.filename}"
        with open(os.path.join(upload_dir, safe), "wb") as f:
            f.write(await thumbnail.read())
        thumbnail_url = f"{web_base}/uploads/{safe}"

    # ── Parse tags ────────────────────────────────────────────────────────────
    parsed_tags: list = []
    if tags:
        try:
            parsed_tags = json.loads(tags)
        except Exception:
            parsed_tags = [t.strip() for t in tags.split(",") if t.strip()]

    # ─────────────────────────────────────────────────────────────────────────
    # Build the web-portal ads document (stored in claimit_web.ads)
    # ─────────────────────────────────────────────────────────────────────────
    ad_doc = {
        "user_id":      user_id,
        "ad_type":      ad_type,
        "pincode":      pincode,
        "publish_date": pub_date.strftime("%d/%m/%Y"),
        "end_date":     end_date.strftime("%d/%m/%Y"),
        "amount":       amount,
        "status":       ad_status,
        "views":        0,
        "clicks":       0,
        "created_at":   datetime.utcnow(),
    }

    if ad_type == "home_banner":
        ad_doc.update({
            "headline":  headline or title or "",
            "sub":       sub or description or "",
            "cta_link":  cta_link or "",
            "image_url": creative_url or "",
            "title":     headline or title or "",
        })

    elif ad_type == "promo_reelz":
        ad_doc.update({
            "shop_name":     shop_name or "",
            "shop_location": shop_location or "",
            "shop_category": shop_category or "",
            "caption":       caption or "",
            "offer":         offer or "",
            "tag":           tag or "",
            "video_url":     creative_url or "",
            "thumbnail_url": thumbnail_url or "",
            "title":         shop_name or "",
        })

    elif ad_type in ("brand_deals", "nearby_deals"):
        ad_doc.update({
            "name":        name or "",
            "location":    location or "",
            "offer":       offer or "",
            "description": description or "",
            "address":     address or "",
            "phone":       phone or "",
            "timing":      timing or "",
            "type":        type or "",
            "cashback":    cashback or "1% Cashback",
            "distance":    distance or "",
            "tags":        parsed_tags,
            "image_url":   creative_url or "",
            "rating":      4.0,
            "reviews":     0,
            "deal_group":  "brand" if ad_type == "brand_deals" else "nearby",
            "title":       name or "",
        })

    # Insert into web portal collection
    result = await ads_collection.insert_one(ad_doc)
    ad_id  = str(result.inserted_id)

    # ─────────────────────────────────────────────────────────────────────────
    # Mirror into the app-facing claimit_db collections so the Flutter app
    # shows the ad without any manual seeding.
    # ─────────────────────────────────────────────────────────────────────────
    if ad_type in ("brand_deals", "nearby_deals"):
        deal_doc = {
            "web_ad_id":    ad_id,          # reference back to web ad
            "deal_group":   "brand" if ad_type == "brand_deals" else "nearby",
            "name":         name or "",
            "location":     location or "",
            "offer":        offer or "",
            "cashback":     cashback or "1% Cashback",
            "distance":     distance or "",
            "type":         type or "",
            "category":     type or "",     # app filters by "category" field
            "image_url":    creative_url or "",
            "description":  description or "",
            "address":      address or "",
            "phone":        phone or "",
            "timing":       timing or "",
            "rating":       4.0,
            "reviews":      0,
            "tags":         parsed_tags,
            "pincode":      pincode,
            "status":       ad_status,
            "end_date":     end_date.strftime("%d/%m/%Y"),
            "created_at":   datetime.utcnow(),
        }
        await app_deals_collection.insert_one(deal_doc)

    elif ad_type == "promo_reelz":
        reel_doc = {
            "web_ad_id":     ad_id,
            "shop_name":     shop_name or "",
            "shop_location": shop_location or "",
            "shop_category": shop_category or "",
            "caption":       caption or "",
            "offer":         offer or "",
            "video_url":     creative_url or "",
            "thumbnail_url": thumbnail_url or "",
            "like_count":    0,
            "view_count":    0,
            "tag":           tag or "",
            "liked_by":      [],
            "pincode":       pincode,
            "status":        ad_status,
            "end_date":      end_date.strftime("%d/%m/%Y"),
            "created_at":    datetime.utcnow(),
        }
        await app_reels_collection.insert_one(reel_doc)

    # ── Record transaction ────────────────────────────────────────────────────
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

    ad_doc["id"] = ad_id
    ad_doc.pop("_id", None)
    return ad_doc


# ─── Transactions ─────────────────────────────────────────────────────────────
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


# ─── Profile ──────────────────────────────────────────────────────────────────
@router.get("/profile")
async def get_profile(current_user=Depends(get_current_user)):
    return {
        "id":    str(current_user["_id"]),
        "name":  current_user.get("name", ""),
        "email": current_user.get("email", ""),
        "phone": current_user.get("phone", ""),
        "role":  current_user.get("role", ""),
    }
