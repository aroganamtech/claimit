"""
Shops endpoints — data served from MongoDB.
Images stored as base64 strings returned in JSON responses.

Route ORDER matters in FastAPI:
  /search  and  /nearby  MUST come before  /{shop_id}
  otherwise "nearby" / "search" are matched as shop_id values.
"""
import math
import re
from typing import Optional, List
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status, Query
from bson import ObjectId
from ..database import get_db
from ..utils.auth import get_current_user
from ..utils.s3 import generate_presigned_url
from ..utils.helpers import serialize_doc
from ..models.shop import ReviewCreate

router = APIRouter(prefix="/shops", tags=["Shops"])


# ── Haversine distance (km) ────────────────────────────────────────────────────
def _haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Return distance in km between two GPS coordinates."""
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = (math.sin(dlat / 2) ** 2
         + math.cos(math.radians(lat1))
         * math.cos(math.radians(lat2))
         * math.sin(dlng / 2) ** 2)
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


# async def _doc_to_response(doc: dict, distance_km: Optional[float] = None) -> dict:
#     result = serialize_doc(doc)
#     if distance_km is not None:
#         result["distance"] = f"{distance_km:.1f} km"

#     # ── Generate presigned URLs from S3 keys (private bucket) ────────────────
#     s3_key  = result.get("image_s3_key")
#     s3_keys = result.get("image_s3_keys") or []

#     if s3_key:
#         result["image_url"] = await generate_presigned_url(s3_key) or ""

#     if s3_keys:
#         presigned = []
#         for k in s3_keys:
#             url = await generate_presigned_url(k)
#             if url:
#                 presigned.append(url)
#         if presigned:
#             result["image_urls"] = presigned

#     # ── Derive has_rewards / has_redeem from shop_type ────────────────────────
#     shop_type = result.get("shop_type", "")
#     if shop_type == "reward":
#         result.setdefault("has_rewards", True)
#         result.setdefault("has_redeem",  False)
#     elif shop_type == "redeem":
#         result.setdefault("has_rewards", False)
#         result.setdefault("has_redeem",  True)
#     elif shop_type == "both":
#         result.setdefault("has_rewards", True)
#         result.setdefault("has_redeem",  True)
#     else:
#         result.setdefault("has_rewards", True)
#         result.setdefault("has_redeem",  True)

#     return result

async def _doc_to_response(doc: dict, distance_km: Optional[float] = None) -> dict:
    result = serialize_doc(doc)
    if distance_km is not None:
        result["distance"] = f"{distance_km:.1f} km"

    # Since the bucket is public, we can use the clean URLs directly 
    # that your seed.py file generated and saved in MongoDB!
    # No need to override them with generate_presigned_url keys.

    # If your DB ever misses a full URL, fallback to building it manually:
    bucket = "claimit-image-bucket"
    region = "eu-north-1"
    
    if not result.get("image_url") and result.get("image_s3_key"):
        result["image_url"] = f"https://{bucket}.s3.{region}.amazonaws.com/{result['image_s3_key']}"

    if not result.get("image_urls") and result.get("image_s3_keys"):
        result["image_urls"] = [
            f"https://{bucket}.s3.{region}.amazonaws.com/{k}" for k in result["image_s3_keys"]
        ]

    # Derive has_rewards / has_redeem from shop_type.
    # When shop_type is a known value it is AUTHORITATIVE (override, not
    # setdefault) — stale stored booleans from older "Edit Shop Type" saves
    # used to contradict it, making a shop appear in BOTH zones.
    # Tolerant matching: DB values may be "reward", "Reward", "Reward Shop"…
    shop_type = str(result.get("shop_type") or "").strip().lower()
    if shop_type.startswith("reward"):
        result["has_rewards"] = True
        result["has_redeem"]  = False
    elif shop_type.startswith("redeem"):
        result["has_rewards"] = False
        result["has_redeem"]  = True
    else:
        result.setdefault("has_rewards", True)
        result.setdefault("has_redeem",  True)

    # Ownership: shops the admin bulk-uploaded have no user_id until an
    # owner finds their shop in the app and claims it (pays via the
    # website's /shop/auth → claim flow). The app uses this flag to show
    # the "Claim Your Business" button only on shops nobody owns yet.
    result["is_claimed"] = bool(str(result.get("user_id") or "").strip())

    return result
# ─────────────────────────────────────────────────────────────────────────────
# GET /shops  — list / filter / search
# ─────────────────────────────────────────────────────────────────────────────
@router.get("")
async def get_shops(
    category_id: Optional[int] = Query(None),
    q: Optional[str] = Query(None),
    area: Optional[str] = Query(None, description="Filter by area name in location field"),
    exclude_id: Optional[str] = Query(None, description="Exclude this shop ID"),
    has_rewards: Optional[bool] = Query(None),
    has_redeem: Optional[bool] = Query(None),
    limit: Optional[int] = Query(None),  # no cap — return all matching shops
    current_user: dict = Depends(get_current_user),
):
    """
    GET /shops
    Supports: category_id, q (search), area, exclude_id, has_rewards, has_redeem, limit
    """
    db = get_db()
    query: dict = {}

    if category_id is not None:
        query["category_ids"] = category_id
    if has_rewards is not None:
        query["has_rewards"] = has_rewards
    if has_redeem is not None:
        query["has_redeem"] = has_redeem

    # Search filter (name / location) — same substring, case-insensitive
    # match as before, just run inside the DB query instead of in Python
    # after fetching every shop.
    if q:
        pattern = re.escape(q)
        query["$or"] = [
            {"name": {"$regex": pattern, "$options": "i"}},
            {"location": {"$regex": pattern, "$options": "i"}},
        ]

    # Area filter — match location string, e.g. "Padi" matches "Padi, Chennai"
    if area:
        query["location"] = {"$regex": re.escape(area), "$options": "i"}

    # Exclude a specific shop (used for "stores nearby" on the detail page)
    if exclude_id:
        try:
            query["_id"] = {"$ne": ObjectId(exclude_id)}
        except Exception:
            pass  # invalid id — behave like before and exclude nothing

    cursor = db.shops.find(
        query,
        # List view doesn't need these — legacy base64 blobs the app never
        # reads (images are served via image_url/image_urls).
        {"cover_photo_b64": 0, "gallery_photos": 0},
    ).sort("added_days_ago", 1)
    if limit is not None:
        cursor = cursor.limit(limit)
    # No cap otherwise (Ramesh: "remove any limit") — still returns every
    # matching shop, just filtered by MongoDB instead of in Python.
    shops: List[dict] = await cursor.to_list(length=None)

    shops_out = []
    for s in shops:
        shops_out.append(await _doc_to_response(s))
    return {
        "success": True,
        "shops": shops_out,
        "total": len(shops_out),
    }


# ─────────────────────────────────────────────────────────────────────────────
# GET /shops/search  — must be before /{shop_id}
# ─────────────────────────────────────────────────────────────────────────────
@router.get("/search")
async def search_shops(
    q: str = Query(..., min_length=1),
    current_user: dict = Depends(get_current_user),
):
    """GET /shops/search?q=term"""
    db = get_db()
    pattern = re.escape(q)
    query = {
        "$or": [
            {"name": {"$regex": pattern, "$options": "i"}},
            {"location": {"$regex": pattern, "$options": "i"}},
        ]
    }
    cursor = db.shops.find(query, {"cover_photo_b64": 0, "gallery_photos": 0})
    results = await cursor.to_list(length=None)
    results_out = []
    for s in results:
        results_out.append(await _doc_to_response(s))
    return {
        "success": True,
        "shops": results_out,
        "total": len(results_out),
    }


# ─────────────────────────────────────────────────────────────────────────────
# Address-based matching for shops that have no GPS coordinates
# ─────────────────────────────────────────────────────────────────────────────
# Not every shop has lat/lng. A shop registered from the website without
# clicking "use my current location", or bulk-uploaded from a sheet with no
# lat/lng columns, is stored with geo = None. $geoNear can only see documents
# that carry a geo point, so those shops used to be invisible in the app even
# though they are paid, active and correct in the database.
#
# These shops are matched on ADDRESS instead: the strongest signal we have
# about the user's whereabouts, in this order —
#
#     1. pincode   exact match          (most precise)
#     2. area      "location" field     (e.g. "Anna Nagar")
#     3. city
#     4. district
#
# A shop is included as soon as one tier matches, and tiers are searched in
# order, so a same-pincode shop always outranks a same-district one.

def _clean(v) -> str:
    return str(v or "").strip()


def _ci(value: str) -> dict:
    """Case-insensitive exact match on a whole field, safely escaped so an
    address containing regex characters can't break the query."""
    return {"$regex": f"^{re.escape(value)}$", "$options": "i"}


# A shop counts as "unlocated" when it has no usable geo point. Covers the
# three shapes seen in the collection: missing, explicit null, and an empty
# object left behind by an older write.
_NO_GEO = {"$or": [{"geo": {"$exists": False}}, {"geo": None}, {"geo": {}}]}


async def _match_unlocated_shops(
    db,
    *,
    pincode: str = "",
    area: str = "",
    city: str = "",
    district: str = "",
    exclude_oid=None,
    seen_ids=None,
) -> List[dict]:
    """Shops with no coordinates whose address matches the user's location.

    Returns them ordered strongest-match-first. Never raises: if anything at
    all goes wrong the caller just gets an empty list and the nearby endpoint
    behaves exactly as it did before this function existed.
    """
    out: List[dict] = []
    seen = set(seen_ids or ())
    try:
        # (field, value) tiers, best first. Empty values are skipped, so a
        # user with only a city set still gets a city match.
        tiers = [
            ("pincode",  pincode),
            ("location", area),
            ("city",     city),
            ("area",     area),
            ("district", district),
        ]
        for field, value in tiers:
            value = _clean(value)
            if not value:
                continue
            query: dict = {"$and": [_NO_GEO, {field: _ci(value)}]}
            if exclude_oid is not None:
                query["_id"] = {"$ne": exclude_oid}
            cursor = db.shops.find(
                query, {"cover_photo_b64": 0, "gallery_photos": 0}
            )
            async for doc in cursor:
                _id = str(doc.get("_id"))
                if _id in seen:
                    continue
                seen.add(_id)
                doc["_match_by"] = field
                out.append(doc)
    except Exception as e:
        # Deliberately swallowed — an address-matching problem must never
        # take down the main nearby list.
        print(f"[shops/nearby] address fallback skipped: {e}")
        return []
    return out


# ─────────────────────────────────────────────────────────────────────────────
# GET /shops/nearby  — must be before /{shop_id}
# ─────────────────────────────────────────────────────────────────────────────
@router.get("/nearby")
async def get_nearby_shops(
    lat: float = Query(..., description="User latitude"),
    lng: float = Query(..., description="User longitude"),
    radius_km: float = Query(4.0, ge=0.1, le=50.0, description="Search radius in km"),
    exclude_id: Optional[str] = Query(None, description="Shop ID to exclude from results"),
    skip: int = Query(0, ge=0, description="Pagination offset — 0 = start from nearest"),
    limit: int = Query(0, ge=0, description="Max shops to return. 0 (default) = no limit, return every shop in radius — unchanged behaviour for existing callers."),
    premium_first: bool = Query(False, description="Sort Premium-plan shops to the top of the (already distance-sorted) results. Default False — off unless a caller explicitly asks for it."),
    # Optional address hints. When the app sends them (fresh GPS-derived area
    # or the area the user picked) they win; otherwise the logged-in user's
    # own saved profile address is used, so older app builds get the same
    # behaviour with no update.
    pincode: Optional[str] = Query(None, description="User pincode — used to find shops that have no GPS coordinates"),
    city: Optional[str] = Query(None, description="User city — address fallback"),
    area: Optional[str] = Query(None, description="User area/locality — address fallback"),
    district: Optional[str] = Query(None, description="User district — address fallback"),
    include_unlocated: bool = Query(True, description="Include address-matched shops that have no GPS coordinates. Set false for a strict distance-only list."),
    current_user: dict = Depends(get_current_user),
):
    """
    GET /shops/nearby?lat=X&lng=Y&radius_km=4[&skip=0&limit=10&premium_first=true]
    Returns shops within `radius_km` of the given GPS coordinates, nearest
    first. Each shop gets a `distance` field e.g. "2.3 km".
    Shops without stored GPS coordinates are excluded (same as before).

    skip/limit/premium_first are OPTIONAL and default to the original
    behaviour (return every shop in radius, distance-sorted, no reordering)
    so existing callers (dashboard "nearby" widget, shop-detail "stores
    nearby" widget) are unaffected. Pass limit>0 to page results — used by
    the shop list (Reward/Redeem Zone) screens for infinite scroll.

    Uses a $geoNear aggregation against the `geo` 2dsphere index instead of
    pulling every shop into memory and computing haversine distance in
    Python — same results, but MongoDB does the radius filtering using the
    index, so this scales with matches, not with the whole collection.
    """
    db = get_db()

    geo_query: dict = {}
    exclude_oid = None
    if exclude_id:
        try:
            exclude_oid = ObjectId(exclude_id)
            geo_query["_id"] = {"$ne": exclude_oid}
        except Exception:
            pass  # invalid id — behave like before and exclude nothing

    pipeline = [
        {
            "$geoNear": {
                "near": {"type": "Point", "coordinates": [lng, lat]},
                "distanceField": "_dist_m",
                "maxDistance": radius_km * 1000,
                "spherical": True,
                "query": geo_query,
            }
        },
        # List view doesn't need these — they're legacy base64 blobs the app
        # never reads (images are served via image_url/image_urls).
        {"$project": {"cover_photo_b64": 0, "gallery_photos": 0}},
    ]

    shops_out = []
    async for shop in db.shops.aggregate(pipeline):
        dist_km = shop.pop("_dist_m", 0) / 1000
        shops_out.append(await _doc_to_response(shop, distance_km=dist_km))

    # Premium-first: stable sort, so within each group (premium / not) the
    # existing nearest-first order is preserved — same pattern already used
    # for deals (see utils/helpers.py sort_by_tier).
    if premium_first:
        shops_out = sorted(
            shops_out,
            key=lambda s: 0 if str(s.get("plan", "")).strip().lower() == "premium" else 1,
        )

    # ── Address fallback: shops that have no GPS coordinates ─────────────────
    # These can't take part in $geoNear, so they are matched on address and
    # appended AFTER the distance-sorted results — a shop the user can measure
    # a distance to always comes first.
    #
    # Where the address comes from, in order: what the caller passed (the app
    # sends the area/pincode it resolved from GPS or from the area the user
    # picked), then the logged-in user's own saved profile. The profile
    # fallback is what lets an app build that knows nothing about these
    # parameters still get the right shops.
    if include_unlocated:
        _pin  = _clean(pincode)  or _clean(current_user.get("pincode"))
        _area = _clean(area)     or _clean(current_user.get("location"))
        _city = _clean(city)     or _clean(current_user.get("city"))
        _dist = _clean(district) or _clean(current_user.get("district"))

        extra_docs = await _match_unlocated_shops(
            db,
            pincode=_pin, area=_area, city=_city, district=_dist,
            exclude_oid=exclude_oid,
            seen_ids={s.get("id") for s in shops_out},
        )

        extra_out = []
        for doc in extra_docs:
            match_by = doc.pop("_match_by", "")
            try:
                item = await _doc_to_response(doc)
            except Exception:
                continue  # one bad document must not drop the rest
            # No coordinates means no honest distance to show. The app renders
            # an empty distance as blank rather than a wrong "0.0 km".
            item["distance"] = ""
            item["match_by"] = match_by
            extra_out.append(item)

        if premium_first:
            extra_out = sorted(
                extra_out,
                key=lambda s: 0 if str(s.get("plan", "")).strip().lower() == "premium" else 1,
            )
        shops_out.extend(extra_out)

    total_in_radius = len(shops_out)
    if limit:
        page = shops_out[skip: skip + limit]
    elif skip:
        page = shops_out[skip:]
    else:
        page = shops_out

    return {
        "success": True,
        "shops": page,
        "total": total_in_radius,
        "returned": len(page),
        "has_more": (skip + len(page)) < total_in_radius,
        "radius_km": radius_km,
        "user_lat": lat,
        "user_lng": lng,
        # How many of `total` were found by address rather than distance.
        # Handy when checking why a particular shop did or didn't appear.
        "address_matched": sum(1 for s in shops_out if s.get("match_by")),
    }


# ─────────────────────────────────────────────────────────────────────────────
# GET /shops/{shop_id}  — single shop
# ─────────────────────────────────────────────────────────────────────────────
@router.get("/{shop_id}")
async def get_shop(
    shop_id: str,
    current_user: dict = Depends(get_current_user),
):
    """GET /shops/{id}"""
    db = get_db()
    try:
        oid = ObjectId(shop_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid shop ID")

    shop = await db.shops.find_one({"_id": oid})
    if not shop:
        raise HTTPException(status_code=404, detail="Shop not found")

    # Attach review count
    review_count = await db.shop_reviews.count_documents({"shop_id": shop_id})
    shop["review_count"] = review_count

    return {"success": True, "shop": await _doc_to_response(shop)}


# ─────────────────────────────────────────────────────────────────────────────
# GET /shops/{shop_id}/image
# ─────────────────────────────────────────────────────────────────────────────
@router.get("/{shop_id}/image")
async def get_shop_image(
    shop_id: str,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    try:
        oid = ObjectId(shop_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid shop ID")

    shop = await db.shops.find_one(
        {"_id": oid},
        {"image_s3_key": 1, "image_s3_keys": 1,
         "image_url": 1,    "image_urls": 1,
         "image_data": 1,   "image_name": 1},
    )
    if not shop:
        raise HTTPException(status_code=404, detail="Shop not found")

    # Generate presigned URLs from S3 keys (private bucket); fall back to
    # whatever is stored in image_url for legacy/base64 records.
    s3_key  = shop.get("image_s3_key")
    s3_keys = shop.get("image_s3_keys") or []

    image_url = (
        await generate_presigned_url(s3_key)
        if s3_key
        else shop.get("image_url", "")
    )
    image_urls = []
    for key in s3_keys:
        url = await generate_presigned_url(key)
        if url:
            image_urls.append(url)
    if not image_urls:
        image_urls = shop.get("image_urls", [])

    return {
        "success":      True,
        "shop_id":      shop_id,
        "image_url":    image_url or "",
        "image_urls":   image_urls,
        "image_s3_key": s3_key,
        # legacy fields kept for backward compat
        "image_name":   shop.get("image_name", ""),
        "image_data":   shop.get("image_data", ""),
    }


# ─────────────────────────────────────────────────────────────────────────────
# GET /shops/{shop_id}/reviews
# ─────────────────────────────────────────────────────────────────────────────
@router.get("/{shop_id}/reviews")
async def get_shop_reviews(
    shop_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    GET /shops/{id}/reviews
    Returns: { reviews: [...], avg_rating, total }
    """
    db = get_db()
    # Validate shop exists
    try:
        oid = ObjectId(shop_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid shop ID")

    shop = await db.shops.find_one({"_id": oid}, {"_id": 1})
    if not shop:
        raise HTTPException(status_code=404, detail="Shop not found")

    cursor = db.shop_reviews.find({"shop_id": shop_id}).sort("created_at", -1)
    reviews = await cursor.to_list(length=100)

    # Compute average rating
    total = len(reviews)
    avg_rating = (
        round(sum(r.get("rating", 0) for r in reviews) / total, 1)
        if total > 0 else 0.0
    )

    return {
        "success": True,
        "reviews": [serialize_doc(r) for r in reviews],
        "avg_rating": avg_rating,
        "total": total,
    }


# ─────────────────────────────────────────────────────────────────────────────
# POST /shops/{shop_id}/reviews
# ─────────────────────────────────────────────────────────────────────────────
@router.post("/{shop_id}/reviews", status_code=201)
async def submit_review(
    shop_id: str,
    data: ReviewCreate,
    current_user: dict = Depends(get_current_user),
):
    """
    POST /shops/{id}/reviews
    Body: { rating: float, comment: str }
    One review per user per shop (upsert).
    """
    db = get_db()
    try:
        oid = ObjectId(shop_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid shop ID")

    shop = await db.shops.find_one({"_id": oid}, {"_id": 1})
    if not shop:
        raise HTTPException(status_code=404, detail="Shop not found")

    user_id = str(current_user.get("_id") or current_user.get("id"))
    user_name = current_user.get("full_name") or current_user.get("name") or "User"
    user_avatar = current_user.get("avatar_url")

    review_doc = {
        "shop_id": shop_id,
        "user_id": user_id,
        "user_name": user_name,
        "user_avatar": user_avatar,
        "rating": round(float(data.rating), 1),
        "comment": data.comment.strip(),
        "created_at": datetime.now(timezone.utc),
    }

    # Upsert: one review per user per shop
    await db.shop_reviews.update_one(
        {"shop_id": shop_id, "user_id": user_id},
        {"$set": review_doc},
        upsert=True,
    )

    # Update cached avg_rating on the shop document
    cursor = db.shop_reviews.find({"shop_id": shop_id})
    all_reviews = await cursor.to_list(length=500)
    total = len(all_reviews)
    new_avg = round(sum(r.get("rating", 0) for r in all_reviews) / total, 1) if total else 0
    await db.shops.update_one(
        {"_id": oid},
        {"$set": {"rating": new_avg, "review_count": total}},
    )

    return {
        "success": True,
        "message": "Review submitted successfully",
        "review": serialize_doc(review_doc),
        "new_avg_rating": new_avg,
    }
