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
from database import app_shops_collection, reviews_collection
from bson import ObjectId
from typing import Optional
from datetime import datetime
import math

router = APIRouter()


# ── helpers ──────────────────────────────────────────────────────────────────

def _serialize_shop(doc: dict, include_gallery: bool = False) -> dict:
    """Convert a MongoDB shops document → Flutter ShopItem JSON shape."""
    sid = str(doc["_id"])

    # Cover image — use stripped image_data (no data-URL prefix)
    image_data = doc.get("image_data") or ""
    # Truncate safety: if somehow still has prefix, strip it
    if image_data.startswith("data:"):
        import re
        m = re.match(r"data:[^;]+;base64,(.+)", image_data, re.DOTALL)
        image_data = m.group(1) if m else ""

    result = {
        "id":            sid,
        "name":          doc.get("name") or doc.get("shop_name") or "",
        "location":      doc.get("location") or "",
        "category_ids":  doc.get("category_ids") or [1],
        "discount":      doc.get("discount") or doc.get("discount_percentage") or 0,
        "rating":        float(doc.get("rating") or 4.0),
        "review_count":  int(doc.get("review_count") or 0),
        "added_days_ago": int(doc.get("added_days_ago") or 0),
        "image_data":    image_data,
        "image_name":    doc.get("image_name") or "",
        "has_rewards":   bool(doc.get("has_rewards") or doc.get("shop_type") == "reward"),
        "has_redeem":    bool(doc.get("has_redeem") or doc.get("shop_type") == "redeem"),
        "about":         doc.get("about") or "",
        "address":       doc.get("address") or doc.get("shop_address") or "",
        "timing":        doc.get("timing") or "",
        "phone":         doc.get("phone") or "",
        "email":         doc.get("email") or doc.get("user_email") or "",
        "lat":           doc.get("lat"),
        "lng":           doc.get("lng"),
        "distance":      doc.get("distance") or "",
        "shop_type":     doc.get("shop_type") or "",
        # Gallery only on detail view — omit on list to keep response small
        "image_data_list": (doc.get("image_data_list") or []) if include_gallery else [],
    }
    return result


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
    shops = [_serialize_shop(d, include_gallery=False) for d in docs]
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
            shop = _serialize_shop(d, include_gallery=False)
            shop["distance"] = f"{dist:.1f} Km"
            nearby.append((dist, shop))

    nearby.sort(key=lambda x: x[0])
    return {"shops": [s for _, s in nearby]}


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
    return {"shops": [_serialize_shop(d, include_gallery=False) for d in docs]}


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
    return {"shop": _serialize_shop(doc, include_gallery=True)}


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
