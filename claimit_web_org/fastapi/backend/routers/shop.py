from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from database import (
    shops_collection, transactions_collection, reviews_collection,
    app_shops_collection,
)
from models.schemas import OfferUpdateRequest, StoreUpdateRequest, ReviewCreate, ReviewReplyRequest, GalleryPhotoRequest, GalleryPhotoKeyRequest
from utils.dependencies import get_current_user
from bson import ObjectId
from datetime import datetime, timedelta
from typing import Optional, List
import base64
from utils.s3 import upload_bytes as _s3_upload, generate_presigned_url_sync as _presign, generate_presigned_upload_url, public_url as _public_url
import json
import re

# ─── Redeem Zone discount tiers (Merchant categorization) ──────────────────────
_ALLOWED_DISCOUNTS = {5, 10, 15, 20, 25, 30}

# ─── Category string → category_ids mapping ───────────────────────────────────
_CATEGORY_MAP: dict[str, int] = {
    # ID 1 — New Deals / General
    "new deals": 1,  "hardware": 1,
    # ID 2 — Groceries
    "groceries": 2,  "grocery": 2,
    # ID 3 — Supermarket
    "supermarket": 3,
    # ID 4 — Pharmacy
    "pharmacy": 4,   "medical": 4,
    # ID 5 — Salon
    "salon": 5,      "salons": 5,      "beauty": 5,
    # ID 6 — Gym
    "gym": 6,        "fitness": 6,
    # ID 7 — Restaurant
    "restaurant": 7, "restaurants": 7, "food": 7,   "bakery": 7,
    # ID 8 — Cafes
    "cafes": 8,      "cafe": 8,        "coffee": 8,
    # ID 9 — Clothing
    "clothing": 9,   "fashion": 9,     "apparel": 9,
    # ID 10 — Department Store
    "department": 10, "department store": 10,
    # ID 11 — Electronics
    "electronics": 11,
    # ID 12 — Books
    "books": 12,     "book": 12,       "stationery": 12,
    # ID 13 — Toys
    "toys": 13,      "toy": 13,
    # ID 14 — Baby
    "baby": 14,      "baby products": 14,
    # ID 15 — Home Decor
    "home decor": 15, "home": 15,
    # ID 16 — Furniture
    "furniture": 16,
    # ID 17 — Spa
    "spa": 17,
    # ID 21 — Clinics
    "clinics": 21,   "clinic": 21,     "hospital": 21, "dental": 21, "dentist": 21,
    # ID 23 — Pets
    "pets": 23,      "pet": 23,
    # ID 24 — Sports
    "sports": 24,    "sport": 24,
    # ID 26 — Mobile & Accessories
    "mobile": 26,    "mobile & accessories": 26,  "accessories": 26,
    # ID 27 — Computer & Laptop
    "computer": 27,  "computer & laptop": 27,     "laptop": 27,
    # ID 28 — Gifts
    "gifts": 28,     "gift": 28,
    # ID 29 — Jewellery
    "jewellery": 29, "jewelry": 29,
    # ID 30 — Shoes / Footwear
    "shoes": 30,     "footwear": 30,   "shoe": 30,
}


def _category_to_ids(category: str) -> list[int]:
    """Map a category string to a list of int category_ids for the app."""
    key = category.strip().lower()
    cid = _CATEGORY_MAP.get(key)
    return [cid] if cid else [1]          # default to "New deals" (1)


def _strip_b64_prefix(data_url: str | None) -> str:
    """Remove 'data:image/...;base64,' prefix — app expects raw base64."""
    if not data_url:
        return ""
    match = re.match(r"data:[^;]+;base64,(.+)", data_url, re.DOTALL)
    return match.group(1) if match else data_url


def _compress_b64_image(b64_raw: str, max_kb: int = 150) -> str:
    if not b64_raw:
        return ""
    try:
        import io, base64
        from PIL import Image
        img_bytes = base64.b64decode(b64_raw + "==")
        img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
        max_side = 800
        w, h = img.size
        if max(w, h) > max_side:
            scale = max_side / max(w, h)
            img = img.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
        for quality in [75, 60, 45, 30]:
            buf = io.BytesIO()
            img.save(buf, format="JPEG", quality=quality, optimize=True)
            compressed = buf.getvalue()
            if len(compressed) <= max_kb * 1024:
                return base64.b64encode(compressed).decode()
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=20, optimize=True)
        return base64.b64encode(buf.getvalue()).decode()
    except Exception:
        return b64_raw


async def _sync_shop_to_app(user_id: str) -> None:
    """
    Sync web shop → app fields. Compresses images and removes raw blobs
    so the document stays under MongoDB's 16 MB limit.
    """
    shop = await shops_collection.find_one({"user_id": user_id})
    if not shop:
        return

    import os as _os

    def _b64_to_bytes(b64: str) -> bytes:
        import base64 as _b64
        raw = _strip_b64_prefix(b64)
        return _b64.b64decode(raw + "==") if raw else b""

    _region = _os.getenv("AWS_REGION", "eu-north-1")
    _bucket = _os.getenv("AWS_STORAGE_BUCKET_NAME", "claimit-image-bucket")

    def _s3_url(key: str) -> str:
        return f"https://{_bucket}.s3.{_region}.amazonaws.com/{key}" if key else ""

    # Upload cover photo to S3
    # NOTE: decode + upload are both inside the try/except — a single corrupt
    # or undecodable image must never crash this function before it reaches
    # the final update_one() below (that previously dropped EVERY image field,
    # including ones that had already uploaded fine in this same call).
    cover_key = ""
    cover_url = ""
    try:
        cover_raw = _b64_to_bytes(shop.get("cover_photo_b64") or "")
        if cover_raw:
            cover_key = await _s3_upload(cover_raw, "shop-covers", content_type="image/jpeg")
            cover_url = _s3_url(cover_key)
    except Exception as _e:
        print(f"Cover S3 upload error: {_e}")

    # Upload gallery photos to S3 — each photo is isolated so one bad
    # image (e.g. an undecodable base64 string) doesn't block the rest.
    gallery_keys = []
    gallery_urls = []
    for gp in (shop.get("gallery_photos") or []):
        try:
            gb = _b64_to_bytes(gp)
            if gb:
                gk = await _s3_upload(gb, "shop-gallery", content_type="image/jpeg")
                gallery_keys.append(gk)
                gallery_urls.append(_s3_url(gk))
        except Exception as _e:
            print(f"Gallery S3 upload error: {_e}")

    app_fields = {
        "name":            shop.get("shop_name", ""),
        "location":        shop.get("location", ""),
        "category_ids":    _category_to_ids(shop.get("category", "")),
        "discount":        shop.get("discount_percentage", 0),
        "rating":          shop.get("rating", 4.0),
        "added_days_ago":  0,
        "image_name":      "",
        "image_names":     [],
        "has_rewards":     shop.get("shop_type", "") == "reward",
        "has_redeem":      shop.get("shop_type", "") == "redeem",
        "about":           shop.get("about", ""),
        "address":         shop.get("shop_address", ""),
        "timing":          shop.get("timing", ""),
        "phone":           shop.get("phone", ""),
        "lat":             shop.get("lat"),
        "lng":             shop.get("lng"),
        # S3 keys and URLs — if no base64 was found to upload, preserve
        # keys already stored (e.g. shops that used presigned-URL upload).
        "image_s3_key":    cover_key or shop.get("image_s3_key", ""),
        "image_url":       cover_url or shop.get("image_url", ""),
        "image_s3_keys":   gallery_keys if gallery_keys else shop.get("image_s3_keys", []),
        "image_urls":      gallery_urls if gallery_urls else shop.get("image_urls", []),
        # Legacy empty fields (no more base64 in DB)
        "image_data":      "",
        "image_data_list": [],
    }

    # Keep cover_photo_b64 and gallery_photos — removing them breaks
    # subsequent $push calls (each new gallery upload would recreate the
    # array from scratch, leaving only the last photo).
    await shops_collection.update_one(
        {"_id": shop["_id"]},
        {"$set": app_fields},
    )

router = APIRouter()


def serialize(doc):
    doc["id"] = str(doc["_id"])
    del doc["_id"]
    if "created_at" in doc and doc["created_at"]:
        doc["created_at"] = str(doc["created_at"])
    return doc


# ─── Register shop (called from onboarding wizard) ────────────
@router.post("/register")
async def register_shop(
    shop_name: str = Form(...),
    shop_address: str = Form(...),
    pincode: str = Form(...),
    lat: Optional[float] = Form(None),
    lng: Optional[float] = Form(None),
    about: str = Form(""),
    location: str = Form(""),          # "City / Area" — shown in app
    phone: str = Form(""),             # contact phone
    timing: str = Form(""),            # opening hours e.g. "Daily: 10am – 10pm"
    category: str = Form(...),
    shop_type: str = Form(...),
    discount_percentage: int = Form(15),
    current_user=Depends(get_current_user),
):
    if discount_percentage not in _ALLOWED_DISCOUNTS:
        raise HTTPException(
            status_code=400,
            detail=f"discount_percentage must be one of {sorted(_ALLOWED_DISCOUNTS)}",
        )

    user_id = str(current_user["_id"])
    user_email = current_user.get("email", "")

    shop_doc = {
        "user_id": user_id,
        "user_email": user_email,
        "shop_name": shop_name,
        "shop_address": shop_address,
        "pincode": pincode,
        "lat": lat,
        "lng": lng,
        "about": about,
        "location": location,
        "phone": phone,
        "timing": timing,
        "category": category,
        "shop_type": shop_type,
        "discount_percentage": discount_percentage,
        "cover_photo_b64": None,
        "gallery_photos": [],
        "status": "pending",
        "total_reward_given": 0,
        "total_redeem_used": 0,
        "created_at": datetime.utcnow(),
    }

    existing = await shops_collection.find_one({"user_id": user_id})
    if existing:
        # Preserve existing images — only update non-image fields on re-register
        update_fields = {k: v for k, v in shop_doc.items()
                         if k not in ("cover_photo_b64", "gallery_photos", "created_at")}
        await shops_collection.update_one(
            {"user_id": user_id}, {"$set": update_fields}
        )
        shop_doc["id"] = str(existing["_id"])
    else:
        result = await shops_collection.insert_one(shop_doc)
        shop_doc["id"] = str(result.inserted_id)

    # Mirror into app database
    await _sync_shop_to_app(user_id)

    if "_id" in shop_doc:
        del shop_doc["_id"]
    return {"ok": True, "shop": shop_doc}


# ─── Dashboard ────────────────────────────────────────────────
@router.get("/dashboard")
async def get_dashboard(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    shop = await shops_collection.find_one({"user_id": user_id})
    if not shop:
        return {
            "shop": None,
            "total_reward_given": 0,
            "total_redeem_used": 0,
            "rewards": [],
            "redeems": [],
        }

    shop_id = str(shop["_id"])
    txns = await transactions_collection.find({"shop_id": shop_id}).to_list(200)

    rewards = [
        {
            "customer": t.get("customer", ""),
            "reward_points": t.get("reward_points", 0),
            "bill_amount": t.get("bill_amount", 0),
            "date": t.get("date", ""),
        }
        for t in txns if t.get("type") == "reward"
    ]
    redeems = [
        {
            "customer": t.get("customer", ""),
            "redeemed": t.get("redeemed", 0),
            "bill_amount": t.get("bill_amount", 0),
            "date": t.get("date", ""),
        }
        for t in txns if t.get("type") == "redeem"
    ]

    return {
        "shop": serialize(shop),
        "total_reward_given": len(rewards),
        "total_redeem_used": len(redeems),
        "total_favorites": int(shop.get("favorites_count") or 0),
        "rewards": rewards,
        "redeems": redeems,
    }


# ─── Offer ────────────────────────────────────────────────────
@router.put("/offer")
async def update_offer(request: OfferUpdateRequest, current_user=Depends(get_current_user)):
    if request.discount_percentage not in _ALLOWED_DISCOUNTS:
        raise HTTPException(
            status_code=400,
            detail=f"discount_percentage must be one of {sorted(_ALLOWED_DISCOUNTS)}",
        )
    user_id = str(current_user["_id"])
    result = await shops_collection.update_one(
        {"user_id": user_id},
        {"$set": {"discount_percentage": request.discount_percentage}}
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Shop not found")
    # Mirror updated discount into app-facing fields (was missing — app's
    # cached "discount" field would otherwise go stale after an offer change).
    await _sync_shop_to_app(user_id)
    return {"discount_percentage": request.discount_percentage}


@router.get("/offer")
async def get_offer(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    shop = await shops_collection.find_one({"user_id": user_id})
    if not shop:
        return {"discount_percentage": 0}
    return {"discount_percentage": shop.get("discount_percentage", 0)}


# ─── Store Details ────────────────────────────────────────────
@router.put("/store-details")
async def update_store_details(request: StoreUpdateRequest, current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    update_data = {k: v for k, v in request.dict().items() if v is not None}
    if not update_data:
        return {"message": "Nothing to update"}
    res = await shops_collection.update_one({"user_id": user_id}, {"$set": update_data})
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="Shop not found")
    return {"message": "Store details updated", "patch": update_data}


@router.get("/store-details")
async def get_store_details(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    shop = await shops_collection.find_one({"user_id": user_id})
    if not shop:
        # Return empty fields rather than 404 so the page can render an empty state.
        return {
            "shop_name": "", "about": "", "shop_address": "",
            "geo_location": "", "category": "", "shop_type": "",
        }
    return serialize(shop)


# ─── Ratings & Reviews (NO MORE static demo) ──────────────────
@router.get("/ratings")
async def get_ratings(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    shop = await shops_collection.find_one({"user_id": user_id})
    if not shop:
        return {"average_rating": 0, "total_reviews": 0, "positive_percentage": 0, "reviews": []}
    shop_id = str(shop["_id"])

    reviews = await reviews_collection.find({"shop_id": shop_id}).sort("date", -1).to_list(200)
    if not reviews:
        return {"average_rating": 0, "total_reviews": 0, "positive_percentage": 0, "reviews": []}

    total = len(reviews)
    avg = sum(r.get("rating", 0) for r in reviews) / total
    positive = sum(1 for r in reviews if r.get("rating", 0) >= 4)

    return {
        "average_rating": round(avg, 1),
        "total_reviews": total,
        "positive_percentage": round((positive / total) * 100),
        "reviews": [
            {
                "id": str(r["_id"]),
                "name": r.get("name", ""),
                "rating": r.get("rating", 0),
                "comment": r.get("comment", ""),
                "date": r.get("date", ""),
                "reply": r.get("reply", ""),
            } for r in reviews
        ],
    }


@router.post("/ratings")
async def add_review(request: ReviewCreate):
    """Public-facing endpoint a customer app would call to leave a review."""
    doc = {
        "shop_id": request.shop_id,
        "name": request.name,
        "rating": request.rating,
        "comment": request.comment,
        "date": datetime.utcnow().strftime("%d/%m/%Y"),
        "created_at": datetime.utcnow(),
        "reply": "",
    }
    res = await reviews_collection.insert_one(doc)
    doc["id"] = str(res.inserted_id)
    del doc["_id"]
    return doc


@router.post("/ratings/reply")
async def reply_to_review(request: ReviewReplyRequest, current_user=Depends(get_current_user)):
    try:
        oid = ObjectId(request.review_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid review id")
    res = await reviews_collection.update_one(
        {"_id": oid},
        {"$set": {"reply": request.reply, "replied_at": datetime.utcnow()}},
    )
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="Review not found")
    return {"message": "Reply posted"}


# ─── Gallery Photos ───────────────────────────────────────────
@router.get("/gallery")
async def get_gallery(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    shop = await shops_collection.find_one({"user_id": user_id})
    if not shop:
        return {"cover_photo_b64": None, "gallery_photos": []}
    return {
        "cover_photo_b64": shop.get("cover_photo_b64"),
        "gallery_photos": shop.get("gallery_photos", []),
    }


@router.post("/gallery/cover")
async def upload_cover_photo(request: GalleryPhotoRequest, current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    res = await shops_collection.update_one(
        {"user_id": user_id},
        {"$set": {"cover_photo_b64": request.photo_b64}}
    )
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="Shop not found")
    # Mirror updated cover photo into app database
    await _sync_shop_to_app(user_id)
    return {"ok": True}


@router.post("/gallery/add")
async def add_gallery_photo(request: GalleryPhotoRequest, current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    res = await shops_collection.update_one(
        {"user_id": user_id},
        {"$push": {"gallery_photos": request.photo_b64}}
    )
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="Shop not found")
    # Mirror updated gallery into app database
    await _sync_shop_to_app(user_id)
    return {"ok": True}


@router.delete("/gallery/{index}")
async def delete_gallery_photo(index: int, current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    shop = await shops_collection.find_one({"user_id": user_id})
    if not shop:
        raise HTTPException(status_code=404, detail="Shop not found")
    gallery = shop.get("gallery_photos", [])
    if index < 0 or index >= len(gallery):
        raise HTTPException(status_code=400, detail="Invalid photo index")
    gallery.pop(index)
    await shops_collection.update_one(
        {"user_id": user_id},
        {"$set": {"gallery_photos": gallery}}
    )
    # Mirror updated gallery into app database
    await _sync_shop_to_app(user_id)
    return {"ok": True}


# ─── Presigned-URL upload (same pattern as brand_deals / nearby_deals) ────────
# Browser requests a presigned S3 PUT URL, uploads the file directly to S3,
# then sends just the S3 key to one of the two endpoints below.
# This avoids routing image bytes through the backend / nginx entirely.

@router.post("/gallery/presign")
async def presign_shop_image(current_user=Depends(get_current_user)):
    """Return a presigned S3 PUT URL for a single shop image upload."""
    result = generate_presigned_upload_url(
        folder="shops",
        filename="image.jpg",
        content_type="image/jpeg",
        is_video=False,
    )
    result["public_url"] = _public_url(result["key"])
    return result


@router.post("/gallery/cover-key")
async def set_cover_photo_key(request: GalleryPhotoKeyRequest, current_user=Depends(get_current_user)):
    """Store an already-uploaded S3 key as the shop cover photo."""
    user_id = str(current_user["_id"])
    key = request.s3_key
    url = _public_url(key)
    res = await shops_collection.update_one(
        {"user_id": user_id},
        {"$set": {"image_s3_key": key, "image_url": url}},
    )
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="Shop not found")
    return {"ok": True}


@router.post("/gallery/add-key")
async def add_gallery_photo_key(request: GalleryPhotoKeyRequest, current_user=Depends(get_current_user)):
    """Append an already-uploaded S3 key to the shop gallery."""
    user_id = str(current_user["_id"])
    key = request.s3_key
    url = _public_url(key)
    res = await shops_collection.update_one(
        {"user_id": user_id},
        {"$push": {"image_s3_keys": key, "image_urls": url}},
    )
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="Shop not found")
    return {"ok": True}


# ─── Settings ─────────────────────────────────────────────────
@router.get("/settings")
async def get_settings(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    shop = await shops_collection.find_one({"user_id": user_id})
    next_renewal = ""
    if shop and shop.get("created_at"):
        renewal = shop["created_at"] + timedelta(days=365)
        next_renewal = renewal.strftime("%d/%m/%Y")
    return {
        "email": current_user.get("email", ""),
        "phone": current_user.get("phone", ""),
        "annual_price": 999,
        "next_renewal": next_renewal,
    }
