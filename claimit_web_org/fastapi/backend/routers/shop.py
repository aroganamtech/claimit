from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from database import (
    shops_collection, transactions_collection, reviews_collection,
    app_shops_collection, app_db,
)
from models.schemas import OfferUpdateRequest, StoreUpdateRequest, ReviewCreate, ReviewReplyRequest, GalleryPhotoRequest, GalleryPhotoKeyRequest
from utils.dependencies import get_current_user
from bson import ObjectId
from datetime import datetime, timedelta
from typing import Optional, List
import base64
from utils.s3 import upload_bytes as _s3_upload, generate_presigned_url_sync as _presign, generate_presigned_upload_url, public_url as _public_url
from utils.fcm import send_push_to_tokens
from database import app_db as _app_db
import asyncio
import json
import re


async def _broadcast_new_shop(shop_name: str, location: str) -> None:
    """
    Push a "new shop joined" alert to EVERY app user (fire-and-forget).
    Chunked at FCM's 500-token multicast limit; dead tokens are pruned.
    Best-effort by design — must never affect the registration request.
    """
    try:
        docs = await _app_db["fcm_tokens"].find({}, {"token": 1}).to_list(20000)
        tokens = list({d["token"] for d in docs if d.get("token")})
        if not tokens:
            return
        title = "🏪 New shop just joined Claimit!"
        where = f" ({location})" if location else ""
        body = (f"{shop_name}{where} is now on Claimit — "
                "check new shops & deals near you!")
        for i in range(0, len(tokens), 500):
            chunk = tokens[i:i + 500]
            invalid = await send_push_to_tokens(
                chunk, title, body, {"type": "new_shop"})
            if invalid:
                await _app_db["fcm_tokens"].delete_many(
                    {"token": {"$in": invalid}})
        print(f"📣 New-shop broadcast sent to {len(tokens)} device(s)")
    except Exception as exc:  # noqa: BLE001 — never break registration
        print(f"⚠️  new-shop broadcast failed: {exc}")

# ─── Redeem Zone discount tiers (Merchant categorization) ──────────────────────
_ALLOWED_DISCOUNTS = {5, 10, 15, 20, 25, 30}

# ─── Category string → category_ids mapping ───────────────────────────────────
# Ids 1-20 match the app's category list (shop_filter_sheet / dashboard /
# categories screen) and the icon assets icon1.png … icon20.png. Extra aliases
# map old/alternate wording onto the new ids so existing data still resolves.
_CATEGORY_MAP: dict[str, int] = {
    # ID 1 — Supermarkets
    "supermarkets": 1, "supermarket": 1,
    # ID 2 — Grocery / Provision
    "grocery": 2,      "groceries": 2,    "provision": 2,  "grocery / provision": 2,
    # ID 3 — Medical Stores
    "medical": 3,      "medical stores": 3, "pharmacy": 3,
    # ID 4 — Restaurants
    "restaurants": 4,  "restaurant": 4,   "food": 4,       "bakery": 4,
    # ID 5 — Mobile Stores
    "mobile": 5,       "mobile stores": 5, "mobiles": 5,   "mobile & accessories": 5,
    # ID 6 — Electronics
    "electronics": 6,  "computer": 6,     "laptop": 6,
    # ID 7 — Departmental
    "departmental": 7, "department": 7,   "department store": 7,
    # ID 8 — Garment / Fashion
    "garment": 8,      "garments": 8,     "fashion": 8,    "clothing": 8,  "apparel": 8, "garment / fashion": 8,
    # ID 9 — Jewellery
    "jewellery": 9,    "jewelry": 9,
    # ID 10 — Footwears
    "footwear": 10,    "footwears": 10,   "shoes": 10,     "shoe": 10,
    # ID 11 — Coffee Shops
    "coffee": 11,      "coffee shops": 11, "cafe": 11,     "cafes": 11,
    # ID 12 — Hospitals
    "hospitals": 12,   "hospital": 12,    "clinics": 12,   "clinic": 12,
    # ID 13 — Optical Stores
    "optical": 13,     "optical stores": 13, "optics": 13,
    # ID 14 — Diagnostics
    "diagnostics": 14, "diagnostic": 14,  "labs": 14,      "lab": 14,
    # ID 15 — Furniture Stores
    "furniture": 15,   "furniture stores": 15,
    # ID 16 — Home Decor
    "home decor": 16,  "home": 16,        "decor": 16,
    # ID 17 — Beauty Parlours
    "beauty": 17,      "beauty parlours": 17, "parlour": 17, "spa": 17,
    # ID 18 — Salons
    "salons": 18,      "salon": 18,
    # ID 19 — Baby Stores
    "baby": 19,        "baby stores": 19, "baby products": 19,
    # ID 20 — Online Stores
    "online": 20,      "online stores": 20,
}


def _category_to_ids(category: str) -> list[int]:
    """Map a category string to a list of int category_ids for the app."""
    key = category.strip().lower()
    cid = _CATEGORY_MAP.get(key)
    return [cid] if cid else [1]          # default to "Supermarkets" (1)


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


async def _sync_shop_to_app(shop_id) -> None:
    """
    Sync ONE web shop → app fields (scoped by shop _id so it works when a
    user owns multiple shops). Accepts a shop ObjectId or its string form.
    """
    try:
        oid = shop_id if isinstance(shop_id, ObjectId) else ObjectId(str(shop_id))
    except Exception:
        return
    shop = await shops_collection.find_one({"_id": oid})
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
        "shop_type":       shop.get("shop_type", ""),
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


async def _resolve_shop(current_user, shop_id: Optional[str] = None):
    """Return the shop the request should act on when a user may own MANY
    shops. If shop_id is given it must belong to this user; otherwise fall
    back to the user's most recently created shop (keeps every existing
    single-shop caller working unchanged). Returns None if the user has no
    shop yet."""
    user_id = str(current_user["_id"])
    if shop_id:
        try:
            oid = ObjectId(shop_id)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid shop id")
        shop = await shops_collection.find_one({"_id": oid, "user_id": user_id})
        if not shop:
            raise HTTPException(status_code=404, detail="Shop not found")
        return shop
    return await shops_collection.find_one(
        {"user_id": user_id}, sort=[("created_at", -1)]
    )


@router.get("/list")
async def list_my_shops(current_user=Depends(get_current_user)):
    """All shops owned by the current user — powers the shop switcher."""
    user_id = str(current_user["_id"])
    shops = await shops_collection.find({"user_id": user_id}).sort("created_at", 1).to_list(100)
    return [
        {
            "id":        str(s["_id"]),
            "shop_name": s.get("shop_name", ""),
            "location":  s.get("location", ""),
            "shop_type": s.get("shop_type", ""),
            "status":    s.get("status", ""),
        }
        for s in shops
    ]


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
    # Structured address (dropdown-driven; pincode/location above are derived)
    country: str = Form(""),
    state: str = Form(""),
    district: str = Form(""),
    city: str = Form(""),
    current_user=Depends(get_current_user),
):
    shop_type = (shop_type or "").strip().lower()
    if shop_type not in ("reward", "redeem"):
        raise HTTPException(
            status_code=400,
            detail="shop_type must be 'reward' or 'redeem'",
        )

    # Reward shops give free reward points — they have NO redeem discount.
    # (Previously the 15% form default leaked into reward shops, which made
    # the app show "15% Disc" badges on Reward Zone cards.)
    if shop_type == "reward":
        discount_percentage = 0
    elif discount_percentage not in _ALLOWED_DISCOUNTS:
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
        # Structured address
        "country": country,
        "state": state,
        "district": district,
        "city": city,
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

    # A single user can now own MANY shops — every registration creates a new
    # shop record (no more one-shop-per-user overwrite).
    result = await shops_collection.insert_one(shop_doc)
    new_id = result.inserted_id
    shop_doc["id"] = str(new_id)
    # Brand-new shop — announce to every app user (fire-and-forget,
    # runs in the background so registration responds instantly)
    asyncio.create_task(_broadcast_new_shop(shop_name, location))

    # Mirror this specific shop into app database
    await _sync_shop_to_app(new_id)

    if "_id" in shop_doc:
        del shop_doc["_id"]
    return {"ok": True, "shop": shop_doc}


# ─── Dashboard ────────────────────────────────────────────────
@router.get("/dashboard")
async def get_dashboard(shop_id: Optional[str] = None, current_user=Depends(get_current_user)):
    shop = await _resolve_shop(current_user, shop_id)
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


# ─── Bill scans (read-only visibility for the shop owner) ─────────────────────
@router.get("/bill-scans")
async def get_bill_scans(shop_id: Optional[str] = None, current_user=Depends(get_current_user)):
    """
    Every bill scanned at this owner's shop through the Claimit app —
    read-only, so owners can cross-check customer scans against their sales.
    Matches by shop_id first, plus case-insensitive shop-name match for
    scans where the app only captured the OCR'd name (no shop context).
    """
    shop = await _resolve_shop(current_user, shop_id)
    if not shop:
        return {"total_scans": 0, "scans": []}

    shop_id = str(shop["_id"])
    name = (shop.get("shop_name") or shop.get("name") or "").strip()

    query = {"$or": [{"shop_id": shop_id}]}
    if name:
        query["$or"].append(
            {"shop_name": {"$regex": f"^{re.escape(name)}$", "$options": "i"}}
        )

    docs = (
        await app_db["bill_history"]
        .find(query)
        .sort("scanned_at", -1)
        .to_list(300)
    )

    def _fmt(d):
        ts = d.get("scanned_at")
        return {
            "scan_type":       d.get("scan_type", ""),
            "shop_name":       d.get("shop_name", ""),
            "total_amount":    d.get("total_amount", 0),
            "earned_cashback": d.get("earned_cashback", 0),
            "earned_points":   d.get("earned_points", 0),
            "discount_value":  d.get("discount_value", 0),
            "bill_number":     d.get("bill_number") or "",
            "bill_date":       d.get("bill_date") or "",
            "bill_time":       d.get("bill_time") or "",
            "source":          d.get("source", "scan"),
            "scanned_at":      ts.isoformat() if hasattr(ts, "isoformat")
                               else str(ts or ""),
        }

    return {"total_scans": len(docs), "scans": [_fmt(d) for d in docs]}


# ─── Offer ────────────────────────────────────────────────────
@router.put("/offer")
async def update_offer(request: OfferUpdateRequest, shop_id: Optional[str] = None, current_user=Depends(get_current_user)):
    if request.discount_percentage not in _ALLOWED_DISCOUNTS:
        raise HTTPException(
            status_code=400,
            detail=f"discount_percentage must be one of {sorted(_ALLOWED_DISCOUNTS)}",
        )
    shop = await _resolve_shop(current_user, shop_id)
    if not shop:
        raise HTTPException(status_code=404, detail="Shop not found")
    await shops_collection.update_one(
        {"_id": shop["_id"]},
        {"$set": {"discount_percentage": request.discount_percentage}}
    )
    # Mirror updated discount into app-facing fields (was missing — app's
    # cached "discount" field would otherwise go stale after an offer change).
    await _sync_shop_to_app(shop["_id"])
    return {"discount_percentage": request.discount_percentage}


@router.get("/offer")
async def get_offer(shop_id: Optional[str] = None, current_user=Depends(get_current_user)):
    shop = await _resolve_shop(current_user, shop_id)
    if not shop:
        return {"discount_percentage": 0}
    return {"discount_percentage": shop.get("discount_percentage", 0)}


# ─── Store Details ────────────────────────────────────────────
@router.put("/store-details")
async def update_store_details(request: StoreUpdateRequest, shop_id: Optional[str] = None, current_user=Depends(get_current_user)):
    shop = await _resolve_shop(current_user, shop_id)
    if not shop:
        raise HTTPException(status_code=404, detail="Shop not found")
    update_data = {k: v for k, v in request.dict().items() if v is not None}
    if not update_data:
        return {"message": "Nothing to update"}

    # BUG FIX: when shop_type changes, the stored has_rewards / has_redeem
    # booleans MUST change with it — otherwise the app's DB-level filters
    # (which use the booleans) contradict shop_type and the shop appears
    # in BOTH the Reward and Redeem lists.
    if "shop_type" in update_data:
        st = str(update_data["shop_type"]).strip().lower()
        # Tolerant: "reward", "Reward Shop", "redeem shop"… all normalize
        if st.startswith("reward") or st.startswith("redeem"):
            st = "reward" if st.startswith("reward") else "redeem"
            update_data["shop_type"]   = st
            update_data["has_rewards"] = (st == "reward")
            update_data["has_redeem"]  = (st == "redeem")
            if st == "reward":
                # Reward shops have no redeem discount
                update_data["discount_percentage"] = 0
                update_data["discount"] = 0

    await shops_collection.update_one({"_id": shop["_id"]}, {"$set": update_data})
    # Keep the app-facing mirror fields consistent with the edit
    await _sync_shop_to_app(shop["_id"])
    return {"message": "Store details updated", "patch": update_data}


@router.get("/store-details")
async def get_store_details(shop_id: Optional[str] = None, current_user=Depends(get_current_user)):
    shop = await _resolve_shop(current_user, shop_id)
    if not shop:
        # Return empty fields rather than 404 so the page can render an empty state.
        return {
            "shop_name": "", "about": "", "shop_address": "",
            "geo_location": "", "category": "", "shop_type": "",
        }
    return serialize(shop)


# ─── Ratings & Reviews (NO MORE static demo) ──────────────────
@router.get("/ratings")
async def get_ratings(shop_id: Optional[str] = None, current_user=Depends(get_current_user)):
    shop = await _resolve_shop(current_user, shop_id)
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
# Two upload paths exist on this shop doc:
#   - legacy: cover_photo_b64 / gallery_photos (raw base64, written by the
#     old JSON-body upload — dropped for new uploads, kept here only so
#     shops that still have base64 images from before this fix keep showing)
#   - current: image_url / image_urls (S3 key + public URL, written by the
#     presigned-upload endpoints below — same pattern already used during
#     shop registration in ShopPhotos.jsx)
# GET /gallery merges both so the edit page always shows whatever the shop
# actually has, regardless of which path it was uploaded through.
@router.get("/gallery")
async def get_gallery(shop_id: Optional[str] = None, current_user=Depends(get_current_user)):
    shop = await _resolve_shop(current_user, shop_id)
    if not shop:
        return {"cover_photo_b64": None, "gallery_photos": [], "cover_url": None, "gallery_urls": []}
    return {
        # kept for backward compatibility with any older cached frontend
        "cover_photo_b64": shop.get("cover_photo_b64"),
        "gallery_photos": shop.get("gallery_photos", []),
        # preferred — used by the current edit page
        "cover_url": shop.get("image_url") or shop.get("cover_photo_b64"),
        "gallery_urls": shop.get("image_urls") or shop.get("gallery_photos", []),
    }


@router.post("/gallery/cover")
async def upload_cover_photo(request: GalleryPhotoRequest, shop_id: Optional[str] = None, current_user=Depends(get_current_user)):
    shop = await _resolve_shop(current_user, shop_id)
    if not shop:
        raise HTTPException(status_code=404, detail="Shop not found")
    await shops_collection.update_one(
        {"_id": shop["_id"]},
        {"$set": {"cover_photo_b64": request.photo_b64}}
    )
    # Mirror updated cover photo into app database
    await _sync_shop_to_app(shop["_id"])
    return {"ok": True}


@router.post("/gallery/add")
async def add_gallery_photo(request: GalleryPhotoRequest, shop_id: Optional[str] = None, current_user=Depends(get_current_user)):
    shop = await _resolve_shop(current_user, shop_id)
    if not shop:
        raise HTTPException(status_code=404, detail="Shop not found")
    await shops_collection.update_one(
        {"_id": shop["_id"]},
        {"$push": {"gallery_photos": request.photo_b64}}
    )
    # Mirror updated gallery into app database
    await _sync_shop_to_app(shop["_id"])
    return {"ok": True}


@router.delete("/gallery/{index}")
async def delete_gallery_photo(index: int, shop_id: Optional[str] = None, current_user=Depends(get_current_user)):
    shop = await _resolve_shop(current_user, shop_id)
    if not shop:
        raise HTTPException(status_code=404, detail="Shop not found")

    # Delete from whichever list this shop actually has photos in — new
    # uploads live in image_s3_keys/image_urls, older shops may still have
    # gallery_photos (base64).
    keys = shop.get("image_s3_keys") or []
    urls = shop.get("image_urls") or []
    if urls:
        if index < 0 or index >= len(urls):
            raise HTTPException(status_code=400, detail="Invalid photo index")
        urls.pop(index)
        if index < len(keys):
            keys.pop(index)
        await shops_collection.update_one(
            {"_id": shop["_id"]},
            {"$set": {"image_s3_keys": keys, "image_urls": urls}}
        )
    else:
        gallery = shop.get("gallery_photos", [])
        if index < 0 or index >= len(gallery):
            raise HTTPException(status_code=400, detail="Invalid photo index")
        gallery.pop(index)
        await shops_collection.update_one(
            {"_id": shop["_id"]},
            {"$set": {"gallery_photos": gallery}}
        )
        # Mirror updated gallery into app database (only relevant for the
        # legacy base64 path — the S3-key path already writes app-facing
        # fields directly, see gallery/add-key above).
        await _sync_shop_to_app(shop["_id"])
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
async def set_cover_photo_key(request: GalleryPhotoKeyRequest, shop_id: Optional[str] = None, current_user=Depends(get_current_user)):
    """Store an already-uploaded S3 key as the shop cover photo."""
    shop = await _resolve_shop(current_user, shop_id)
    if not shop:
        raise HTTPException(status_code=404, detail="Shop not found")
    key = request.s3_key
    url = _public_url(key)
    await shops_collection.update_one(
        {"_id": shop["_id"]},
        {"$set": {"image_s3_key": key, "image_url": url}},
    )
    return {"ok": True}


@router.post("/gallery/add-key")
async def add_gallery_photo_key(request: GalleryPhotoKeyRequest, shop_id: Optional[str] = None, current_user=Depends(get_current_user)):
    """Append an already-uploaded S3 key to the shop gallery."""
    shop = await _resolve_shop(current_user, shop_id)
    if not shop:
        raise HTTPException(status_code=404, detail="Shop not found")
    key = request.s3_key
    url = _public_url(key)
    await shops_collection.update_one(
        {"_id": shop["_id"]},
        {"$push": {"image_s3_keys": key, "image_urls": url}},
    )
    return {"ok": True}


# ─── Settings ─────────────────────────────────────────────────
@router.get("/settings")
async def get_settings(shop_id: Optional[str] = None, current_user=Depends(get_current_user)):
    shop = await _resolve_shop(current_user, shop_id)
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
