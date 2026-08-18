"""
Learn Claimit — short "how to use the app" video lessons.

Admin adds a question + uploads a video from the web admin panel
(claimit_web_org/fastapi/backend/routers/admin.py, POST /admin/learn) into
claimit_db.learn_content — the SAME database this backend reads from
directly, so a new lesson appears in the app immediately with no sync step.

The app first shows the list of questions; tapping one opens the video
(with sound) plus a one-time like button, matching the Reels player pattern.

Video storage: AWS S3 — MongoDB stores only the S3 key, a playable URL is
resolved per-request (same convention as routes/reels.py, routes/banners.py).

Endpoints
─────────
GET  /learn              → list of questions with resolved video URLs
POST /learn/{id}/like    → toggle like   {"liked": true|false}
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from bson import ObjectId

from ..database import get_db
from ..utils.auth import get_current_user
from ..utils.s3 import generate_video_url_sync, public_url

router = APIRouter(prefix="/learn", tags=["learn"])


# ── Helpers ───────────────────────────────────────────────────────────────────

def _oid(item_id: str) -> ObjectId:
    try:
        return ObjectId(item_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid id")


def _serialize(doc: dict, user_id: str = "") -> dict:
    liked_by: list = doc.get("liked_by", [])
    video_key = doc.get("video_s3_key") or ""
    video_url = (generate_video_url_sync(video_key) or public_url(video_key)) if video_key else ""
    return {
        "id": str(doc["_id"]),
        "question": doc.get("question") or "",
        "video_url": video_url,
        "like_count": len(liked_by),
        "liked_by_me": user_id in liked_by,
    }


# ── List ──────────────────────────────────────────────────────────────────────

@router.get("")
async def list_learn_items(current_user: dict = Depends(get_current_user)):
    db = get_db()
    docs = await db.learn_content.find({}).sort("created_at", -1).to_list(length=200)
    user_id: str = current_user["_id"]
    return {"items": [_serialize(d, user_id) for d in docs]}


# ── Like toggle ───────────────────────────────────────────────────────────────

class LikeBody(BaseModel):
    liked: bool   # true = user is liking; false = user is unliking


@router.post("/{item_id}/like")
async def toggle_like(
    item_id: str,
    body: LikeBody,
    current_user: dict = Depends(get_current_user),
):
    """One like per user — enforced by $addToSet (no duplicates)."""
    db = get_db()
    oid = _oid(item_id)
    user_id: str = current_user["_id"]

    if body.liked:
        await db.learn_content.update_one(
            {"_id": oid},
            {"$addToSet": {"liked_by": user_id}},
        )
    else:
        await db.learn_content.update_one(
            {"_id": oid},
            {"$pull": {"liked_by": user_id}},
        )

    doc = await db.learn_content.find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="Item not found")

    liked_by: list = doc.get("liked_by", [])
    return {
        "like_count": len(liked_by),
        "liked_by_me": user_id in liked_by,
    }
