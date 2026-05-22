"""
Bill scan endpoint.
POST /bill/scan  — records a scanned bill, awards reward points to the user,
                   and returns the updated points total.
"""
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from bson import ObjectId
from ..database import get_db
from ..utils.auth import get_current_user
from ..utils.helpers import serialize_doc

router = APIRouter(prefix="/bill", tags=["Bill"])


class BillScanRequest(BaseModel):
    total_amount: float = Field(..., gt=0, description="Total bill amount in INR")
    reward_points: Optional[int] = Field(None, ge=0)
    shop_name: Optional[str] = None
    image_base64: Optional[str] = None   # stored but not processed server-side


@router.post("/scan", status_code=201)
async def scan_bill(
    data: BillScanRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    POST /bill/scan
    Records the scanned bill, adds reward_points to the user's balance,
    and inserts a document into the `bill_rewards` collection.
    Returns: { success, reward_points, total_points, entry }
    """
    db = get_db()
    user_id = str(current_user.get("_id") or current_user.get("id", ""))

    # Compute points (10% of bill, minimum 1)
    points = data.reward_points if data.reward_points is not None \
        else max(1, int(data.total_amount * 0.1))

    # Resolve shop name
    shop_name = (data.shop_name or "").strip() or "Shop"

    # Build the bill_rewards document
    bill_doc = {
        "user_id": user_id,
        "shop_name": shop_name,
        "total_amount": round(data.total_amount, 2),
        "reward_points": points,
        "discount": round(data.total_amount * 0.1, 2),
        "has_image": data.image_base64 is not None,
        "created_at": datetime.now(timezone.utc),
    }

    result = await db.bill_rewards.insert_one(bill_doc)
    bill_doc["_id"] = result.inserted_id

    # ── Update user's reward_points ─────────────────────────────────────────
    user_oid = None
    try:
        user_oid = ObjectId(user_id)
    except Exception:
        pass

    new_total = points  # fallback
    if user_oid:
        update_result = await db.users.find_one_and_update(
            {"_id": user_oid},
            {"$inc": {"reward_points": points}},
            return_document=True,           # return the UPDATED document
        )
        if update_result:
            new_total = update_result.get("reward_points", points)

    return {
        "success": True,
        "reward_points": points,
        "total_points": new_total,
        "shop_name": shop_name,
        "entry": serialize_doc(bill_doc),
    }


@router.get("/history")
async def bill_history(
    current_user: dict = Depends(get_current_user),
):
    """GET /bill/history — return this user's scan history."""
    db = get_db()
    user_id = str(current_user.get("_id") or current_user.get("id", ""))
    cursor = db.bill_rewards.find({"user_id": user_id}).sort("created_at", -1)
    docs = await cursor.to_list(length=100)
    return {
        "success": True,
        "history": [serialize_doc(d) for d in docs],
        "total": len(docs),
    }
