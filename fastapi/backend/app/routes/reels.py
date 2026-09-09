"""
Reels routes — short promo video clips posted by shops / advertisers.

Video storage: AWS S3 (videos/ prefix in the video bucket).
MongoDB stores only the S3 key; presigned URLs are generated per-request.

Like tracking
─────────────
Each reel stores a `liked_by` list of user-ID strings.
  • $addToSet   → prevents double-liking at DB level
  • $pull       → unlike
  • like_count  → derived as len(liked_by) — always accurate
  • liked_by_me → returned per-request based on the authenticated user

Endpoints
─────────
GET  /reels              → list reels with presigned video URLs
GET  /reels/{id}         → single reel with presigned URL
POST /reels/{id}/like    → toggle like   {"liked": true|false}
POST /reels/{id}/view    → record a view (increments view_count)
"""

from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from bson import ObjectId

from ..database import get_db
from ..utils.auth import get_current_user
from ..utils.s3 import generate_video_url_sync, generate_presigned_url_sync

router = APIRouter(prefix="/reels", tags=["reels"])


# ── Helpers ───────────────────────────────────────────────────────────────────

def _oid(reel_id: str) -> ObjectId:
    try:
        return ObjectId(reel_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid reel id")


def _serialize(doc: dict, user_id: str = "") -> dict:
    doc["id"] = str(doc.pop("_id"))
    liked_by: list = doc.pop("liked_by", [])
    doc["like_count"] = len(liked_by)
    doc["liked_by_me"] = user_id in liked_by

    # Resolve S3 keys → permanent public URLs (bucket is public)
    video_key = doc.pop("video_s3_key", None) or doc.pop("video_key", None)
    thumbnail_key = doc.pop("thumbnail_s3_key", None) or doc.pop("thumbnail_key", None)
    from ..utils.s3 import public_url as _pub
    if video_key:
        doc["video_url"] = _pub(video_key)
    if thumbnail_key:
        doc["thumbnail_url"] = _pub(thumbnail_key)
    return doc


# ── List ──────────────────────────────────────────────────────────────────────

@router.get("")
async def list_reels(
    limit: int = Query(default=10, le=100, description="Page size"),
    skip: int = Query(default=0, ge=0, description="How many already loaded"),
    area: str = Query(default="", description="User's area — local promo reels float to top"),
    pincode: str = Query(default="", description="User's pincode — local promo reels float to top"),
    lat: Optional[float] = Query(None, description="Latitude of the SELECTED location"),
    lng: Optional[float] = Query(None, description="Longitude of the selected location"),
    radius_km: float = Query(5.0, ge=0.5, le=50),
    current_user: dict = Depends(get_current_user),
):
    from ..utils.helpers import prioritize_by_location
    from ..utils.geo_filter import docs_by_distance
    db = get_db()
    # Reels are RANKED by distance, not cut off by it.
    #
    # Every other feature uses a 5 km radius, which is right for a shop or a
    # deal — one 40 km away is no use to anybody. A reel feed is different: the
    # user swipes expecting it to keep going, and a hard radius ends the feed
    # after two videos in a quiet area. So the nearest reel plays first, then
    # the next nearest, and the feed only runs out when the content does.
    #
    # radius_km is still accepted so older app builds don't break; it is simply
    # not used as a cut-off here.
    # One page at a time. The app asks for the next page while the user is
    # still a few videos from the end, so the feed never stalls and the server
    # never builds a list of every reel it has just to serve the first three.
    #
    # Ask for one extra: if it comes back we know there IS a next page, without
    # a second count query. It is trimmed off before returning.
    probe = limit + 1
    docs = await docs_by_distance(db, "reels", lat, lng, {}, probe, skip)
    ranked_by_distance = docs is not None
    if docs is None:
        docs = await (db["reels"].find({})
                      .skip(skip).limit(probe).to_list(length=probe))

    has_more = len(docs) > limit
    docs = docs[:limit]
    # Only reels inside their paid Friday→Thursday week.
    from ..utils.ad_window import filter_live
    docs = filter_live(docs)
    user_id: str = current_user["_id"]
    reels = [_serialize(d, user_id) for d in docs]

    # The old area/pincode ordering is a FALLBACK now, not an extra pass.
    #
    # Running it on top of a distance-sorted list would undo the sort: it
    # partitions by area NAME, so a reel 30 km away in the same area would be
    # pushed above one 2 km away in the next area. Real distance is strictly
    # better information, so it wins when we have it.
    if not ranked_by_distance:
        reels = prioritize_by_location(reels, area, pincode)
    return {
        "reels": reels,
        # The app appends the next page when it is a few videos from the end,
        # and stops asking once this goes false.
        "has_more": has_more,
        "skip": skip,
        "limit": limit,
    }


# ── Single ────────────────────────────────────────────────────────────────────

@router.get("/{reel_id}")
async def get_reel(
    reel_id: str,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    doc = await db["reels"].find_one({"_id": _oid(reel_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Reel not found")
    return {"reel": _serialize(doc, current_user["_id"])}


# ── Like toggle ───────────────────────────────────────────────────────────────

class LikeBody(BaseModel):
    liked: bool   # true = user is liking; false = user is unliking


@router.post("/{reel_id}/like")
async def toggle_like(
    reel_id: str,
    body: LikeBody,
    current_user: dict = Depends(get_current_user),
):
    """
    One like per user — enforced by $addToSet (no duplicates).
    Returns updated like_count and liked_by_me flag.
    """
    db = get_db()
    oid = _oid(reel_id)
    user_id: str = current_user["_id"]

    if body.liked:
        # $addToSet silently ignores if user_id already present
        await db["reels"].update_one(
            {"_id": oid},
            {"$addToSet": {"liked_by": user_id}},
        )
    else:
        # $pull removes the user_id if it exists
        await db["reels"].update_one(
            {"_id": oid},
            {"$pull": {"liked_by": user_id}},
        )

    doc = await db["reels"].find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="Reel not found")

    liked_by: list = doc.get("liked_by", [])
    return {
        "like_count": len(liked_by),
        "liked_by_me": user_id in liked_by,
    }


# ── View increment ────────────────────────────────────────────────────────────

@router.post("/{reel_id}/view")
async def record_view(
    reel_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Increment view_count by 1. Called when a reel becomes the active page."""
    db = get_db()
    result = await db["reels"].find_one_and_update(
        {"_id": _oid(reel_id)},
        {"$inc": {"view_count": 1}},
        return_document=True,
    )
    if not result:
        raise HTTPException(status_code=404, detail="Reel not found")
    return {"view_count": result.get("view_count", 0)}
