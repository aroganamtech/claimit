"""
Public shop endpoints — no auth required.
Serves the Flutter app's /shops requests.

  GET  /shops                       → { shops: [...] }  (list, no gallery)
  GET  /shops/nearby                → { shops: [...] }  (GPS-based)
  GET  /shops/search                → { shops: [...] }  (text search)
  GET  /shops/{id}                  → { shop: {...} }   (detail, with gallery)
  GET  /shops/{id}/reviews          → { reviews: [...], avg_rating, total }
  POST /shops/{id}/reviews          → { review: {...} }
"""

from fastapi import APIRouter, Query, HTTPException
from database import app_shops_collection, reviews_collection, category_images_collection
from utils.s3 import generate_presigned_url_sync as _presign
from bson import ObjectId
from typing import Optional
from datetime import datetime
import math
import random

router = APIRouter()


# ── helpers ──────────────────────────────────────────────────────────────────

async def _load_category_images() -> dict:
    """category_id → [s3 keys] for shops that have no own photo."""
    m: dict = {}
    async for d in category_images_collection.find():
        keys = d.get("keys") or []
        if keys:
            m[d.get("category_id")] = keys
    return m


def _category_cover(doc: dict, cat_images: dict) -> str:
    """A stable random image (seeded by shop id) from the shop's first category
    that has an image pool. Empty string if none available."""
    if not cat_images:
        return ""
    cids = []
    for c in (doc.get("category_ids") or []):
        try:
            cids.append(int(c))
        except (ValueError, TypeError):
            pass
    for cid in cids:
        keys = cat_images.get(cid)
        if keys:
            rnd = random.Random(f"{doc.get('_id')}:{cid}")
            return _presign(rnd.choice(keys)) or ""
    return ""


def _serialize_shop(doc: dict, include_gallery: bool = False,
                    cat_images: dict = None) -> dict:
    """Convert a MongoDB shops document → Flutter ShopItem JSON shape."""
    sid = str(doc["_id"])

    # Generate presigned URL from S3 key (private bucket)
    cover_url = _presign(doc.get("image_s3_key") or "") or ""
    if not cover_url:
        stored_url = doc.get("image_url") or ""
        if stored_url.startswith("https://"):
            from urllib.parse import urlparse
            key = urlparse(stored_url).path.lstrip("/")
            cover_url = _presign(key) or ""
    # Final fallback: a random image from the shop's category pool.
    if not cover_url:
        cover_url = _category_cover(doc, cat_images)

    gallery_urls = []
    if include_gallery:
        for key in (doc.get("image_s3_keys") or []):
            url = _presign(key)
            if url:
                gallery_urls.append(url)

    result = {
        "id":            sid,
        "name":          doc.get("name") or doc.get("shop_name") or "",
        "location":      doc.get("location") or "",
        "category_ids":  doc.get("category_ids") or [1],
        "discount":      doc.get("discount") or doc.get("discount_percentage") or 0,
        "rating":        float(doc.get("rating") or 4.0),
        "review_count":  int(doc.get("review_count") or 0),
        "added_days_ago": int(doc.get("added_days_ago") or 0),
        "image_url":     cover_url,
        "image_data":    doc.get("image_data") or "",
        "image_name":    doc.get("image_name") or "",
        # Use has_rewards/has_redeem if explicitly stored (even False),
        # fall back to shop_type only when the field is absent entirely.
        "has_rewards":   bool(doc["has_rewards"] if "has_rewards" in doc else doc.get("shop_type") == "reward"),
        "has_redeem":    bool(doc["has_redeem"]  if "has_redeem"  in doc else doc.get("shop_type") == "redeem"),
        "about":         doc.get("about") or "",
        "address":       doc.get("address") or doc.get("shop_address") or "",
        "timing":        doc.get("timing") or "",
        "phone":         doc.get("phone") or "",
        "email":         doc.get("email") or doc.get("user_email") or "",
        "lat":           doc.get("lat"),
        "lng":           doc.get("lng"),
        "distance":      doc.get("distance") or "",
        "shop_type":     doc.get("shop_type") or "",
        "image_urls":    gallery_urls,
        "image_data_list": [],
    }
    return result


# Plan tier ordering — Premium shops surface first, then Standard, then every
# other shop (custom "other" plan, free, or bulk-uploaded shops with no plan).
_PLAN_ORDER = {"premium": 0, "standard": 1}


def _plan_rank(doc: dict) -> int:
    return _PLAN_ORDER.get((doc.get("plan") or "").strip().lower(), 2)


def _haversine_km(lat1, lng1, lat2, lng2) -> float:
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlng/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


# ── GET /shops ────────────────────────────────────────────────────────────────
@router.get("")
async def list_shops(
    category_id: Optional[int] = Query(None),
    area: Optional[str] = Query(None),
    exclude_id: Optional[str] = Query(None),
    limit: int = Query(50, le=100),
):
    query: dict = {"status": {"$in": ["active", "approved", "pending", None]}}

    if category_id:
        query["category_ids"] = category_id

    if area:
        query["location"] = {"$regex": area, "$options": "i"}

    if exclude_id:
        try:
            query["_id"] = {"$ne": ObjectId(exclude_id)}
        except Exception:
            pass

    # Exclude heavy image fields from list — fetch only metadata + cover
    projection = {"cover_photo_b64": 0, "gallery_photos": 0, "image_data_list": 0}

    docs = await app_shops_collection.find(query, projection).limit(limit).to_list(limit)
    # Premium first, then Standard, then everyone else (stable within a tier).
    docs.sort(key=_plan_rank)
    cat_images = await _load_category_images()
    shops = [_serialize_shop(d, include_gallery=False, cat_images=cat_images) for d in docs]
    return {"shops": shops}


# ── GET /shops/nearby ─────────────────────────────────────────────────────────
@router.get("/nearby")
async def nearby_shops(
    lat: float = Query(...),
    lng: float = Query(...),
    radius_km: float = Query(4.0),
    exclude_id: Optional[str] = Query(None),
):
    # Fetch all shops that have coordinates, exclude heavy image fields
    projection = {"cover_photo_b64": 0, "gallery_photos": 0, "image_data_list": 0}
    query: dict = {"lat": {"$ne": None}, "lng": {"$ne": None}}
    if exclude_id:
        try:
            query["_id"] = {"$ne": ObjectId(exclude_id)}
        except Exception:
            pass

    docs = await app_shops_collection.find(query, projection).to_list(500)
    cat_images = await _load_category_images()

    nearby = []
    for d in docs:
        slat = d.get("lat")
        slng = d.get("lng")
        if slat is None or slng is None:
            continue
        try:
            dist = _haversine_km(lat, lng, float(slat), float(slng))
        except Exception:
            continue
        if dist <= radius_km:
            shop = _serialize_shop(d, include_gallery=False, cat_images=cat_images)
            shop["distance"] = f"{dist:.1f} Km"
            nearby.append((_plan_rank(d), dist, shop))

    # Premium first, then Standard, then others — distance breaks ties.
    nearby.sort(key=lambda x: (x[0], x[1]))
    return {"shops": [s for _, _, s in nearby]}


# ── GET /shops/search ─────────────────────────────────────────────────────────
@router.get("/search")
async def search_shops(q: str = Query(..., min_length=1)):
    projection = {"cover_photo_b64": 0, "gallery_photos": 0, "image_data_list": 0}
    query = {
        "$or": [
            {"name":     {"$regex": q, "$options": "i"}},
            {"location": {"$regex": q, "$options": "i"}},
            {"about":    {"$regex": q, "$options": "i"}},
        ]
    }
    docs = await app_shops_collection.find(query, projection).limit(30).to_list(30)
    cat_images = await _load_category_images()
    return {"shops": [_serialize_shop(d, include_gallery=False, cat_images=cat_images) for d in docs]}


# ── GET /shops/{id} ───────────────────────────────────────────────────────────
@router.get("/{shop_id}")
async def get_shop(shop_id: str):
    try:
        oid = ObjectId(shop_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid shop ID")

    # On detail view include gallery but still exclude raw b64 blob
    projection = {"cover_photo_b64": 0, "gallery_photos": 0}
    doc = await app_shops_collection.find_one({"_id": oid}, projection)
    if not doc:
        raise HTTPException(status_code=404, detail="Shop not found")
    cat_images = await _load_category_images()
    return {"shop": _serialize_shop(doc, include_gallery=True, cat_images=cat_images)}


# ── GET /shops/{id}/reviews ───────────────────────────────────────────────────
@router.get("/{shop_id}/reviews")
async def get_shop_reviews(shop_id: str):
    revs = await reviews_collection.find({"shop_id": shop_id}).sort("created_at", -1).to_list(100)
    if not revs:
        return {"reviews": [], "avg_rating": 0.0, "total": 0}
    total = len(revs)
    avg = sum(r.get("rating", 0) for r in revs) / total
    return {
        "reviews": [
            {
                "id":         str(r["_id"]),
                "user_name":  r.get("name") or "User",
                "rating":     r.get("rating", 0),
                "comment":    r.get("comment") or "",
                "created_at": str(r.get("created_at") or r.get("date") or ""),
                "reply":      r.get("reply") or "",
            }
            for r in revs
        ],
        "avg_rating": round(avg, 1),
        "total": total,
    }


# ── POST /shops/{id}/reviews ──────────────────────────────────────────────────
@router.post("/{shop_id}/reviews")
async def submit_review(shop_id: str, body: dict):
    doc = {
        "shop_id":    shop_id,
        "name":       body.get("name") or "User",
        "rating":     float(body.get("rating") or 0),
        "comment":    body.get("comment") or "",
        "created_at": datetime.utcnow(),
        "reply":      "",
    }
    res = await reviews_collection.insert_one(doc)
    doc["id"] = str(res.inserted_id)
    del doc["_id"]
    return {"review": doc}

