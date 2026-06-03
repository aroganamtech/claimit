"""
Bill endpoints.
POST /bill/scan                          — records a scanned bill and awards reward points.
POST /bill/manual-review                 — queues a bill for manual staff review.
GET  /bill/history                       — returns this user's scan history.
GET  /bill/my-reviews                    — returns this user's manual review submissions.
GET  /bill/manual-reviews                — admin: list all manual reviews (filter by status).
POST /bill/manual-reviews/{id}/action    — admin: approve or reject a review, credit wallet,
                                           create bill_rewards entry, push notification.
"""
from datetime import datetime, timezone
from typing import Optional, Literal
from fastapi import APIRouter, Depends, HTTPException, Header, Query
from pydantic import BaseModel, Field
from bson import ObjectId
from ..database import get_db
from ..utils.auth import get_current_user
from ..utils.helpers import serialize_doc

# ── Admin key guard (same pattern as admin.py) ──────────────────────────────
import os

def _require_admin(x_admin_key: Optional[str] = Header(None)):
    secret = os.getenv("ADMIN_SECRET_KEY", "claimit-admin-secret")
    if x_admin_key != secret:
        raise HTTPException(status_code=403, detail="Admin access required")

router = APIRouter(prefix="/bill", tags=["Bill"])


class BillScanRequest(BaseModel):
    total_amount: float = Field(..., gt=0, description="Total bill amount in INR")
    reward_points: Optional[int] = Field(None, ge=0)
    shop_name: Optional[str] = None
    bill_number: Optional[str] = None
    bill_date: Optional[str] = None      # "YYYY-MM-DD"
    bill_time: Optional[str] = None      # "HH:MM"
    image_base64: Optional[str] = None   # stored but not processed server-side
    user_id: Optional[str] = None        # fallback if JWT decode fails


class ManualReviewRequest(BaseModel):
    total_amount: float = Field(..., gt=0)
    image_base64: str   = Field(..., description="Base64-encoded bill image")
    shop_name: Optional[str] = None
    bill_number: Optional[str] = None
    bill_date: Optional[str] = None      # "YYYY-MM-DD"
    bill_time: Optional[str] = None      # "HH:MM"
    manual_reason: Optional[str] = "missing_fields"  # 'missing_fields' | 'wrong_data'
    user_id: Optional[str] = None        # fallback if JWT decode fails


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


@router.post("/manual-review", status_code=201)
async def submit_manual_review(
    data: ManualReviewRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    POST /bill/manual-review
    Queues a bill for manual staff review when OCR data is wrong or fields are
    missing. Does NOT award points — staff will approve/reject via admin panel.
    Returns: { success, review_id, message }
    """
    db = get_db()
    user_id = str(current_user.get("_id") or current_user.get("id", ""))

    # Parse bill_date string to datetime if provided
    parsed_date = None
    if data.bill_date:
        try:
            parsed_date = datetime.strptime(data.bill_date, "%Y-%m-%d")
        except ValueError:
            pass

    doc = {
        "user_id":       user_id,
        "total_amount":  round(data.total_amount, 2),
        "shop_name":     (data.shop_name or "").strip() or None,
        "bill_number":   (data.bill_number or "").strip() or None,
        "bill_date":     parsed_date,
        "bill_time":     (data.bill_time or "").strip() or None,
        "manual_reason": data.manual_reason or "missing_fields",
        "has_image":     bool(data.image_base64),
        "image_base64":  data.image_base64,   # store for staff review
        "status":        "pending",            # pending | approved | rejected
        "created_at":    datetime.now(timezone.utc),
        "reviewed_at":   None,
        "review_note":   None,
    }

    result = await db.bill_manual_reviews.insert_one(doc)

    return {
        "success":   True,
        "review_id": str(result.inserted_id),
        "message":   "Your bill has been submitted for review. "
                     "Our team will verify it within 24 hours.",
    }


@router.get("/my-reviews")
async def my_reviews(
    current_user: dict = Depends(get_current_user),
):
    """
    GET /bill/my-reviews
    Returns all manual review submissions by the current user, newest first.
    Excludes the raw base64 image to keep the response small.
    """
    db = get_db()
    user_id = str(current_user.get("_id") or current_user.get("id", ""))
    cursor = db.bill_manual_reviews.find(
        {"user_id": user_id},
        {"image_base64": 0},
    ).sort("created_at", -1)
    docs = await cursor.to_list(length=100)
    return {
        "success": True,
        "reviews": [serialize_doc(d) for d in docs],
        "total":   len(docs),
    }


# ── Admin endpoints ───────────────────────────────────────────────────────────

class ReviewActionRequest(BaseModel):
    action:        Literal["approve", "reject"]
    reward_points: Optional[int]   = None   # override auto-calc (10% of amount)
    cashback:      Optional[float] = None   # override auto-calc (1% of amount)
    admin_note:    Optional[str]   = None


@router.get("/manual-reviews")
async def admin_list_reviews(
    status: Optional[str] = Query(None, description="pending | approved | rejected | all"),
    _: None = Depends(_require_admin),
):
    """
    GET /bill/manual-reviews?status=pending
    Admin: list all manual review submissions, optionally filtered by status.
    Includes image_base64 so the admin UI can render the bill image inline.
    """
    db = get_db()
    query: dict = {}
    if status and status != "all":
        query["status"] = status

    cursor = db.bill_manual_reviews.find(query).sort("created_at", -1)
    docs = await cursor.to_list(length=500)
    # rename created_at → submitted_at for the web UI
    result = []
    for d in docs:
        s = serialize_doc(d)
        s.setdefault("submitted_at", s.get("created_at"))
        result.append(s)
    return result


@router.post("/manual-reviews/{review_id}/action", status_code=200)
async def admin_action_review(
    review_id: str,
    data: ReviewActionRequest,
    _: None = Depends(_require_admin),
):
    """
    POST /bill/manual-reviews/{review_id}/action
    Admin: approve or reject a manual bill review.

    On APPROVE:
      • Calculates reward_points (10% of amount) and cashback (1%) unless overridden.
      • Increments user's reward_points and cashback_wallet in the users collection.
      • Creates a bill_rewards entry so it appears in the user's scan history.
      • Sends an in-app notification to the user.

    On REJECT:
      • Updates status to rejected.
      • Sends a rejection notification to the user.
    """
    db = get_db()

    # ── Fetch the review ──────────────────────────────────────────────────────
    try:
        oid = ObjectId(review_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid review ID")

    review = await db.bill_manual_reviews.find_one({"_id": oid})
    if not review:
        raise HTTPException(status_code=404, detail="Review not found")
    if review.get("status") != "pending":
        raise HTTPException(
            status_code=409,
            detail=f"Review is already {review.get('status')}",
        )

    now       = datetime.now(timezone.utc)
    user_id   = review.get("user_id", "")
    amount    = float(review.get("total_amount", 0))
    shop_name = review.get("shop_name") or "Shop"

    # ── Compute reward amounts ────────────────────────────────────────────────
    pts = data.reward_points if data.reward_points is not None else max(1, int(amount * 0.1))
    cb  = data.cashback      if data.cashback      is not None else round(amount * 0.01, 2)

    # ── Update review document ────────────────────────────────────────────────
    update_fields: dict = {
        "status":      data.action,           # "approved" | "rejected"
        "reviewed_at": now,
        "review_note": data.admin_note or "",
    }
    if data.action == "approve":
        update_fields["reward_points"] = pts
        update_fields["cashback"]      = cb

    await db.bill_manual_reviews.update_one(
        {"_id": oid},
        {"$set": update_fields},
    )

    # ── On approve: credit wallet + add to history ────────────────────────────
    if data.action == "approve":
        # Resolve user ObjectId (user_id stored as string)
        user_oid = None
        try:
            user_oid = ObjectId(user_id)
        except Exception:
            pass

        if user_oid:
            await db.users.update_one(
                {"_id": user_oid},
                {
                    "$inc": {
                        "reward_points":   pts,
                        "cashback_wallet": cb,
                        "lifetime_cashback": cb,
                    }
                },
            )

        # Create a bill_rewards entry so it shows in scan history
        await db.bill_rewards.insert_one({
            "user_id":       user_id,
            "shop_name":     shop_name,
            "total_amount":  round(amount, 2),
            "reward_points": pts,
            "earned_points": pts,
            "earned_cashback": cb,
            "cashback":      cb,
            "discount":      cb,
            "bill_number":   review.get("bill_number"),
            "bill_date":     review.get("bill_date"),
            "bill_time":     review.get("bill_time"),
            "source":        "manual_review",
            "review_id":     str(oid),
            "created_at":    now,
        })

    # ── Push in-app notification to user ──────────────────────────────────────
    if data.action == "approve":
        notif_title   = "🎉 Bill Approved — Rewards Added!"
        notif_message = (
            f"Your bill from {shop_name} (₹{int(amount)}) has been verified. "
            f"₹{cb:.0f} cashback and {pts} reward points have been added to your wallet."
        )
        notif_type = "bill_review_approved"
    else:
        notif_title   = "Bill Review Update"
        notif_message = (
            f"Your bill submission from {shop_name} (₹{int(amount)}) could not be verified"
            + (f": {data.admin_note}" if data.admin_note else ".")
        )
        notif_type = "bill_review_rejected"

    # Store notification (keyed by user_id as ObjectId if possible, else string)
    notif_user_ref = None
    try:
        notif_user_ref = ObjectId(user_id)
    except Exception:
        notif_user_ref = user_id

    await db.notifications.insert_one({
        "user_id":    notif_user_ref,
        "title":      notif_title,
        "message":    notif_message,
        "type":       notif_type,
        "is_read":    False,
        "review_id":  str(oid),
        "created_at": now,
    })

    return {
        "success":       True,
        "action":        data.action,
        "review_id":     review_id,
        "reward_points": pts if data.action == "approve" else 0,
        "cashback":      cb  if data.action == "approve" else 0,
        "message": (
            f"Bill approved. {pts} pts and ₹{cb:.2f} cashback credited to user."
            if data.action == "approve"
            else "Bill rejected. User has been notified."
        ),
    }
