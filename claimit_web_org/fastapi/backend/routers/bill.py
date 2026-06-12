import os
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from utils.s3 import upload_base64 as _s3_b64_async, generate_presigned_url_sync as _presign
from database import app_db, app_bill_reviews_collection, app_notifications_collection
from utils.dependencies import get_current_user_optional
from bson import ObjectId
from datetime import datetime

router = APIRouter()

# ── Collections (in claimit_db — same DB the Flutter app reads) ───────────────
_wallets = app_db["user_wallets"]
_scans   = app_db["bill_scans"]
_config  = app_db["app_config"]


# ── New-user bonus config ─────────────────────────────────────────────────────
async def _get_new_user_config() -> dict:
    """
    Read new-user bonus settings from app_config collection.
    Falls back to env vars, then to hard-coded defaults (1000 pts / ₹10 cashback).
    """
    default_pts = int(os.getenv("NEW_USER_REWARD_POINTS", "1000"))
    default_cb  = float(os.getenv("NEW_USER_CASHBACK", "10.0"))
    try:
        cfg = await _config.find_one({"key": "new_user_bonus"})
        if cfg:
            return {
                "reward_points": int(cfg.get("reward_points", default_pts)),
                "cashback":      float(cfg.get("cashback", default_cb)),
            }
    except Exception:
        pass
    return {"reward_points": default_pts, "cashback": default_cb}


# ── Request model ─────────────────────────────────────────────────────────────
class BillScanRequest(BaseModel):
    total_amount:  float
    reward_points: Optional[int]  = None   # ignored — we recalc server-side
    shop_name:     Optional[str]  = None
    bill_number:   Optional[str]  = None
    bill_date:     Optional[str]  = None   # YYYY-MM-DD from OCR
    image_base64:  Optional[str]  = None   # stored for audit if needed
    user_id:       Optional[str]  = None   # fallback when Bearer token unavailable


# ── Helpers ───────────────────────────────────────────────────────────────────
def _resolve_uid(current_user, body_uid: Optional[str]) -> Optional[str]:
    if current_user:
        return str(current_user["_id"])
    return body_uid


async def _get_or_create_wallet(uid: str) -> tuple:
    """
    Return (wallet_doc, is_new).
    New wallets receive the configurable welcome bonus (points + cashback).
    """
    wallet = await _wallets.find_one({"user_id": uid})
    if wallet is None:
        bonus = await _get_new_user_config()
        wallet = {
            "user_id":           uid,
            "reward_points":     bonus["reward_points"],
            "cashback_wallet":   bonus["cashback"],
            "lifetime_cashback": bonus["cashback"],
            "total_scans":       0,
            "created_at":        datetime.utcnow(),
        }
        await _wallets.insert_one(wallet)
        return wallet, True
    return wallet, False


def _dup_key(shop: str, bill_no: str, bill_date: str, amount: float) -> str:
    """Build the duplicate-detection fingerprint identical to the Flutter side."""
    s   = shop.lower().strip()
    amt = f"{amount:.0f}"
    if bill_no:
        bn = bill_no.lower().replace(" ", "")
        return f"{bn}|{s}|{bill_date}|{amt}"
    return f"{s}|{bill_date}|{amt}"


# ── POST /bill/scan ───────────────────────────────────────────────────────────
@router.post("/scan")
async def bill_scan(
    body: BillScanRequest,
    current_user=Depends(get_current_user_optional),
):
    uid = _resolve_uid(current_user, body.user_id)
    if not uid:
        raise HTTPException(status_code=401,
                            detail="User identification required — send Bearer token or user_id")

    total = body.total_amount
    if total <= 0:
        raise HTTPException(status_code=400, detail="Bill amount must be positive")

    # ── Load / create wallet ─────────────────────────────────────────────────
    wallet, is_new = await _get_or_create_wallet(uid)
    is_first = is_new or wallet.get("total_scans", 0) == 0

    # ── Duplicate check ──────────────────────────────────────────────────────
    bill_date = body.bill_date or datetime.utcnow().strftime("%Y-%m-%d")
    key = _dup_key(
        shop     = body.shop_name or "",
        bill_no  = body.bill_number or "",
        bill_date= bill_date,
        amount   = total,
    )
    if await _scans.find_one({"user_id": uid, "dup_key": key}):
        raise HTTPException(status_code=409, detail="Bill already scanned")

    # ── Calculate rewards (server is authoritative) ──────────────────────────
    earned_cb  = round(total * 0.01, 2)   # 1 %  cashback
    earned_pts = round(total * 0.10)      # 10 % reward points

    # ── Cumulative update ─────────────────────────────────────────────────────
    new_pts      = wallet["reward_points"]     + earned_pts
    new_cb_wallet= wallet["cashback_wallet"]   + earned_cb
    new_lifetime = wallet["lifetime_cashback"] + earned_cb
    new_scans    = wallet.get("total_scans", 0) + 1

    await _wallets.update_one(
        {"user_id": uid},
        {"$set": {
            "reward_points":    new_pts,
            "cashback_wallet":  new_cb_wallet,
            "lifetime_cashback": new_lifetime,
            "total_scans":      new_scans,
            "updated_at":       datetime.utcnow(),
        }},
    )

    # ── Store scan record ────────────────────────────────────────────────────
    scan_doc = {
        "user_id":         uid,
        "dup_key":         key,
        "shop_name":       (body.shop_name or "Shop").strip(),
        "total_amount":    total,
        "earned_cashback": earned_cb,
        "earned_points":   earned_pts,
        "bill_number":     body.bill_number,
        "bill_date":       bill_date,
        "scanned_at":      datetime.utcnow(),
    }
    res = await _scans.insert_one(scan_doc)

    return {
        "ok":               True,
        "scan_id":          str(res.inserted_id),
        "shop_name":        scan_doc["shop_name"],
        # Earned this scan
        "earned_cashback":  earned_cb,
        "earned_points":    earned_pts,
        # New user welcome bonus info
        "is_new_user_bonus": is_first,
        "bonus_points":     (await _get_new_user_config())["reward_points"] if is_first else 0,
        "bonus_cashback":   (await _get_new_user_config())["cashback"] if is_first else 0.0,
        # Running wallet totals (app updates its local state from these)
        "reward_points":    new_pts,
        "cashback_wallet":  new_cb_wallet,
        "lifetime_cashback": new_lifetime,
    }


# ── GET /bill/wallet ──────────────────────────────────────────────────────────
@router.get("/wallet")
async def get_wallet(current_user=Depends(get_current_user_optional)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Authentication required")
    uid    = str(current_user["_id"])
    wallet, _ = await _get_or_create_wallet(uid)
    return {
        "reward_points":    wallet["reward_points"],
        "cashback_wallet":  wallet["cashback_wallet"],
        "lifetime_cashback": wallet["lifetime_cashback"],
        "total_scans":      wallet.get("total_scans", 0),
    }


# ── GET /bill/history ─────────────────────────────────────────────────────────
@router.get("/history")
async def get_history(current_user=Depends(get_current_user_optional)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Authentication required")
    uid   = str(current_user["_id"])
    scans = await _scans.find({"user_id": uid}).sort("scanned_at", -1).to_list(100)
    return [
        {
            "id":              str(s["_id"]),
            "shop_name":       s.get("shop_name", ""),
            "total_amount":    s.get("total_amount", 0),
            "earned_cashback": s.get("earned_cashback", 0),
            "earned_points":   s.get("earned_points", 0),
            "bill_number":     s.get("bill_number"),
            "bill_date":       s.get("bill_date"),
            "scanned_at":      s["scanned_at"].isoformat() if s.get("scanned_at") else "",
            "type":            "auto",
            "status":          "approved",
        }
        for s in scans
    ]


# ═══════════════════════════════════════════════════════════════════════════════
# MANUAL REVIEW FLOW
# ═══════════════════════════════════════════════════════════════════════════════

class ManualBillRequest(BaseModel):
    total_amount:   float
    shop_name:      Optional[str] = None
    bill_number:    Optional[str] = None
    bill_date:      Optional[str] = None
    bill_time:      Optional[str] = None
    image_base64:   str            # REQUIRED — bill image for admin to verify
    manual_reason:  str = "missing_fields"  # missing_fields | wrong_data
    user_id:        Optional[str] = None    # fallback when no JWT


class AdminReviewAction(BaseModel):
    action:         str    # approve | reject
    reward_points:  Optional[int]   = None
    cashback:       Optional[float] = None
    admin_note:     Optional[str]   = None


# ── POST /bill/manual-review ──────────────────────────────────────────────────
@router.post("/manual-review")
async def submit_manual_review(
    body: ManualBillRequest,
    current_user=Depends(get_current_user_optional),
):
    uid = _resolve_uid(current_user, body.user_id)
    if not uid:
        raise HTTPException(status_code=401, detail="Authentication required")

    if not body.image_base64 or len(body.image_base64) < 100:
        raise HTTPException(status_code=400, detail="Bill image is required for manual review")

    if body.total_amount <= 0:
        raise HTTPException(status_code=400, detail="Bill amount must be positive")

    doc = {
        "user_id":       uid,
        "shop_name":     (body.shop_name or "").strip(),
        "total_amount":  body.total_amount,
        "bill_number":   body.bill_number or "",
        "bill_date":     body.bill_date or datetime.utcnow().strftime("%Y-%m-%d"),
        "bill_time":     body.bill_time or "",
        "image_s3_key":  None,  # populated below
        "manual_reason": body.manual_reason,   # missing_fields | wrong_data
        "status":        "pending",             # pending | approved | rejected
        "reward_points": None,
        "cashback":      None,
        "admin_note":    None,
        "submitted_at":  datetime.utcnow(),
        "reviewed_at":   None,
    }
    if body.image_base64:
        try:
            doc["image_s3_key"] = await _s3_b64_async(body.image_base64, "bill-reviews")
        except Exception as _e:
            print(f"S3 upload error: {_e}")
    res = await app_bill_reviews_collection.insert_one(doc)
    return {
        "ok":        True,
        "review_id": str(res.inserted_id),
        "status":    "pending",
        "message":   "Submitted for review. Points and cashback will be added after our team verifies your bill.",
    }


# ── GET /bill/manual-reviews (admin) ─────────────────────────────────────────
@router.get("/manual-reviews")
async def list_manual_reviews(status: str = "pending"):
    """Admin endpoint — lists manual bill review submissions."""
    query = {}
    if status != "all":
        query["status"] = status
    reviews = await app_bill_reviews_collection.find(query).sort("submitted_at", -1).to_list(200)
    return [
        {
            "id":            str(r["_id"]),
            "user_id":       r.get("user_id", ""),
            "shop_name":     r.get("shop_name", ""),
            "total_amount":  r.get("total_amount", 0),
            "bill_number":   r.get("bill_number", ""),
            "bill_date":     r.get("bill_date", ""),
            "bill_time":     r.get("bill_time", ""),
            "image_url":     _presign(r.get("image_s3_key")) if r.get("image_s3_key") else None,
            "manual_reason": r.get("manual_reason", ""),
            "status":        r.get("status", "pending"),
            "reward_points": r.get("reward_points"),
            "cashback":      r.get("cashback"),
            "admin_note":    r.get("admin_note"),
            "submitted_at":  r["submitted_at"].isoformat() if r.get("submitted_at") else "",
            "reviewed_at":   r["reviewed_at"].isoformat() if r.get("reviewed_at") else "",
        }
        for r in reviews
    ]


# ── POST /bill/manual-reviews/{id}/action (admin approve/reject) ──────────────
@router.post("/manual-reviews/{review_id}/action")
async def review_action(review_id: str, body: AdminReviewAction):
    """Admin approves or rejects a manual bill review."""
    try:
        oid = ObjectId(review_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid review ID")

    review = await app_bill_reviews_collection.find_one({"_id": oid})
    if not review:
        raise HTTPException(status_code=404, detail="Review not found")
    if review["status"] != "pending":
        raise HTTPException(status_code=400, detail="Review already processed")

    if body.action not in ("approve", "reject"):
        raise HTTPException(status_code=400, detail="action must be approve or reject")

    now = datetime.utcnow()

    if body.action == "approve":
        pts = body.reward_points or round(review["total_amount"] * 0.10)
        cb  = body.cashback      or round(review["total_amount"] * 0.01, 2)
        uid = review["user_id"]

        # Add to user wallet
        wallet, _ = await _get_or_create_wallet(uid)
        await _wallets.update_one(
            {"user_id": uid},
            {"$set": {
                "reward_points":    wallet["reward_points"]    + pts,
                "cashback_wallet":  wallet["cashback_wallet"]  + cb,
                "lifetime_cashback": wallet["lifetime_cashback"] + cb,
                "updated_at":       now,
            }},
        )

        # Update review record
        await app_bill_reviews_collection.update_one(
            {"_id": oid},
            {"$set": {
                "status":        "approved",
                "reward_points": pts,
                "cashback":      cb,
                "admin_note":    body.admin_note or "",
                "reviewed_at":   now,
            }},
        )

        # Push notification to user
        await app_notifications_collection.insert_one({
            "user_id":   uid,
            "type":      "bill_review_approved",
            "title":     "Bill Review Approved! 🎉",
            "body":      f"Your bill from '{review['shop_name']}' has been verified. "
                         f"You earned {pts} points and ₹{cb:.2f} cashback!",
            "data": {
                "review_id":     review_id,
                "reward_points": pts,
                "cashback":      cb,
                "shop_name":     review.get("shop_name", ""),
            },
            "read":       False,
            "created_at": now,
        })

        return {"ok": True, "action": "approved", "reward_points": pts, "cashback": cb}

    else:
        # Reject
        await app_bill_reviews_collection.update_one(
            {"_id": oid},
            {"$set": {
                "status":      "rejected",
                "admin_note":  body.admin_note or "",
                "reviewed_at": now,
            }},
        )

        # Notify user of rejection
        await app_notifications_collection.insert_one({
            "user_id":   review["user_id"],
            "type":      "bill_review_rejected",
            "title":     "Bill Review Update",
            "body":      f"Your bill from '{review['shop_name']}' could not be verified. "
                         + (f"Note: {body.admin_note}" if body.admin_note else "Please ensure the bill is clear and legible."),
            "data":      {"review_id": review_id},
            "read":      False,
            "created_at": now,
        })

        return {"ok": True, "action": "rejected"}


# ── GET /bill/my-reviews (user — check status of submitted reviews) ───────────
@router.get("/my-reviews")
async def my_reviews(current_user=Depends(get_current_user_optional)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Authentication required")
    uid     = str(current_user["_id"])
    reviews = await app_bill_reviews_collection.find({"user_id": uid}).sort("submitted_at", -1).to_list(50)
    return [
        {
            "id":            str(r["_id"]),
            "shop_name":     r.get("shop_name", ""),
            "total_amount":  r.get("total_amount", 0),
            "status":        r.get("status", "pending"),
            "reward_points": r.get("reward_points"),
            "cashback":      r.get("cashback"),
            "admin_note":    r.get("admin_note"),
            "submitted_at":  r["submitted_at"].isoformat() if r.get("submitted_at") else "",
            "reviewed_at":   r["reviewed_at"].isoformat() if r.get("reviewed_at") else "",
            "type":          "manual",
        }
        for r in reviews
    ]


# ── GET /bill/notifications (user — bill-related notifications) ──────────────
@router.get("/notifications")
async def get_bill_notifications(current_user=Depends(get_current_user_optional)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Authentication required")
    uid   = str(current_user["_id"])
    notifs = await app_notifications_collection.find(
        {"user_id": uid}
    ).sort("created_at", -1).to_list(50)
    return [
        {
            "id":         str(n["_id"]),
            "type":       n.get("type", ""),
            "title":      n.get("title", ""),
            "body":       n.get("body", ""),
            "data":       n.get("data", {}),
            "read":       n.get("read", False),
            "created_at": n["created_at"].isoformat() if n.get("created_at") else "",
        }
        for n in notifs
    ]


# ── POST /bill/notifications/{id}/read ───────────────────────────────────────
@router.post("/notifications/{notif_id}/read")
async def mark_notification_read(
    notif_id: str,
    current_user=Depends(get_current_user_optional),
):
    if not current_user:
        raise HTTPException(status_code=401, detail="Authentication required")
    try:
        oid = ObjectId(notif_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid notification ID")
    await app_notifications_collection.update_one(
        {"_id": oid, "user_id": str(current_user["_id"])},
        {"$set": {"read": True}},
    )
    return {"ok": True}
