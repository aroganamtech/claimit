"""
Reels routes — short promo video clips posted by shops.

Like tracking
─────────────
Each reel stores a `liked_by` list of user-ID strings.
  • $addToSet   → prevents double-liking at DB level
  • $pull       → unlike
  • like_count  → derived as len(liked_by) — always accurate
  • liked_by_me → returned per-request based on the authenticated user

Endpoints
─────────
GET  /reels              → list reels (liked_by_me per user)
GET  /reels/{id}         → single reel
POST /reels/{id}/like    → toggle like   {"liked": true|false}
POST /reels/{id}/view    → record a view (increments view_count)
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from bson import ObjectId

from ..database import get_db
from ..utils.auth import get_current_user

router = APIRouter(prefix="/reels", tags=["reels"])


# ── Helpers ────────────────────────────────�