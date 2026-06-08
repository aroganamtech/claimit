"""
Public deals endpoints — no auth required.
Serves nearby_deals and brand_deals ads from ads_collection
in the DealDto format the Flutter app expects.

  GET /deals/nearby          → { deals: [...] }
  GET /deals/brand           → { deals: [...] }
  GET /deals/{id}            → { deal: {...} }
"""

from fastapi import APIRouter, HTTPException, Query
from app.database import ads_collection
from bson import ObjectId
from datetime import datetime
from typing import Optional
from app.utils.s3 import generate_presigned_url_sync as _presign

router = APIRouter()


def _image_url(ad: dict) -> str:
    """Prefer a freshly-presigned URL from the stored S3 key; fall back to
    whatever raw URL/key is on the document (handles legacy ads)."""
    key = ad.get("image_s3_key") or ""
    url = _presign(key) if key else ""
    if url:
        return url
    stored = ad.get("image_url") or ""
    if stored.startswith("https://") and ".amazonaws.com/" in stored:
        from urllib.parse import urlparse
        derived_key = urlparse(stored).path.lstrip("/")
        url = _presign(derived_key) or ""
        if url:
            return url
    return stored


def _serialize_deal(ad: dict) -> dict:
    """Map a MongoDB ads_collection document → DealDto shape."""
    return {
        "id": str(ad["_id"]),
        "name": ad.get("name") or ad.get("title") or "",
        "location": ad.get("location") or "",
        "offer": ad.get("offer") or "",
        "cashback": ad.get("cashback") or "1% Cashback",
        "distance": ad.get("distance") or "",
        "type": ad.get("type") or "",
        "image_url": _image_url(ad),
        "description": ad.get("description") or "",
        "address": ad.get("address") or "",
        "phone": ad.get("phone") or "",
        "timing": ad.get("timing") or "",
        "rating": float(ad.get("rating") or 4.0),
        "reviews": int(ad.get("reviews") or 0),
        "deal_group": ad.get("deal_group") or ("brand" if ad.get("ad_type") == "brand_deals" else "nearby"),
        "tags": ad.get("tags") or [],
        "pincode": ad.get("pincode") or "",
    }


def _is_active(ad: dict) -> bool:
    """Return True if ad is active or scheduled-but-past."""
    status = ad.get("status", "active")
    if status == "active":
        return True
    if status == "scheduled":
        pub = ad.get("publish_date", "")
        try:
            pub_dt = datetime.strptime(pub, "%d/%m/%Y")
            return datetime.utcnow() >= pub_dt
        except Exception:
            return True
    return False


@router.get("/nearby")
async def get_nearby_deals(category: Optional[str] = Query(None)):
    query: dict = {"ad_type": "nearby_deals"}
    if category:
        query["type"] = {"$regex": category, "$options": "i"}
    ads = await ads_collection.find(query).sort("created_at", -1).to_list(200)
    deals = [_serialize_deal(a) for a in ads if _is_active(a)]
    return {"deals": deals}


@router.get("/brand")
async def get_brand_deals(category: Optional[str] = Query(None)):
    query: dict = {"ad_type": "brand_deals"}
    if category:
        query["type"] = {"$regex": category, "$options": "i"}
    ads = await ads_collection.find(query).sort("created_at", -1).to_list(200)
    deals = [_serialize_deal(a) for a in ads if _is_active(a)]
    return {"deals": deals}


@router.get("/{deal_id}")
async def get_deal_by_id(deal_id: str):
    try:
        oid = ObjectId(deal_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid deal ID")
    ad = await ads_collection.find_one({"_id": oid, "ad_type": {"$in": ["nearby_deals", "brand_deals"]}})
    if not ad:
        raise HTTPException(status_code=404, detail="Deal not found")
    return {"deal": _serialize_deal(ad)}
