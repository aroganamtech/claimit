"""
Admin panel API. All endpoints require an admin JWT issued by /admin/login.

Admin credentials come from the .env file:
    ADMIN_USER=admin
    ADMIN_PASS=admin123

(Defaults are admin / admin123 if those vars aren't set.)

Every endpoint reads/writes MongoDB directly — there's no per-user auth check
because admin can manage any record.
"""
from fastapi import APIRouter, HTTPException, Depends
from datetime import datetime, timedelta
from bson import ObjectId
import os

from utils.s3 import generate_presigned_url_sync as _presign
from database import (
    users_collection, ads_collection, shops_collection,
    reviews_collection, tickets_collection, transactions_collection,
    app_bill_reviews_collection, app_db, app_notifications_collection,
    app_users_collection, app_feedback_collection, app_shops_collection,
    deleted_users_collection,
)
from models.schemas import (
    AdminLoginRequest, AdminAdPatch, AdminShopPatch, AdminTicketPatch,
    AdminFeedbackReply,
)
from utils.auth import create_access_token
from utils.dependencies import get_current_admin
from utils.notify import notify_user

router = APIRouter()

ADMIN_USER = os.getenv("ADMIN_USER", "admin")
ADMIN_PASS = os.getenv("ADMIN_PASS", "admin123")


def _id(s):
    """Safely cast to ObjectId or 400."""
    try:
        return ObjectId(s)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid id")


def _serialize(doc):
    if not doc:
        return None
    out = dict(doc)
    out["id"] = str(out.pop("_id"))
    for k, v in list(out.items()):
        if isinstance(v, datetime):
            out[k] = v.isoformat()
    return out


# ─── Admin Login ──────────────────────────────────────────────
@router.post("/login")
async def admin_login(req: AdminLoginRequest):
    if req.username != ADMIN_USER or req.password != ADMIN_PASS:
        raise HTTPException(status_code=401, detail="Invalid admin credentials")
    token = create_access_token({"sub": req.username, "scope": "admin"})
    return {"access_token": token, "token_type": "bearer", "username": req.username}


# ─── Stats ────────────────────────────────────────────────────
@router.get("/stats")
async def stats(_admin=Depends(get_current_admin)):
    return {
        "users": {
            "total": await users_collection.count_documents({}),
            "advertiser": await users_collection.count_documents({"role": "advertiser"}),
            "sales": await users_collection.count_documents({"role": "sales"}),
            "shop": await users_collection.count_documents({"role": "shop"}),
        },
        "ads_total": await ads_collection.count_documents({}),
        "ads_active": await ads_collection.count_documents({"status": "active"}),
        "shops_total": await shops_collection.count_documents({}),
        "reviews_total": await reviews_collection.count_documents({}),
        "tickets_open": await tickets_collection.count_documents({"status": "open"}),
        "tickets_total": await tickets_collection.count_documents({}),
    }


# ─── Users ────────────────────────────────────────────────────
@router.get("/users")
async def list_users(role: str = "all", _admin=Depends(get_current_admin)):
    q = {} if role == "all" else {"role": role}
    docs = await users_collection.find(q).sort("created_at", -1).to_list(500)
    return [_serialize(d) for d in docs]


@router.delete("/users/{user_id}")
async def delete_user(user_id: str, _admin=Depends(get_current_admin)):
    res = await users_collection.delete_one({"_id": _id(user_id)})
    if not res.deleted_count:
        raise HTTPException(status_code=404, detail="User not found")
    # Cascade clean-up
    await ads_collection.delete_many({"user_id": user_id})
    await shops_collection.delete_many({"user_id": user_id})
    await tickets_collection.delete_many({"user_id": user_id})
    await transactions_collection.delete_many({"user_id": user_id})
    return {"ok": True}


# ─── App Users (real Flutter-app end-customers, claimit_db.users) ─────────────
# Separate from the 3 web-portal roles above — these are the actual people
# using the mobile app (OTP/phone or social login), not advertisers/sales/shops.

def _serialize_app_user(doc):
    if not doc:
        return None
    out = dict(doc)
    out["id"] = str(out.pop("_id"))
    # Never surface sensitive ID-document numbers in the admin list view.
    out.pop("aadhar_number", None)
    out.pop("pan_number", None)
    out.pop("password", None)
    out.pop("hashed_password", None)
    for k, v in list(out.items()):
        if isinstance(v, datetime):
            out[k] = v.isoformat()
    return out


@router.get("/app-users")
async def list_app_users(_admin=Depends(get_current_admin)):
    docs = await app_users_collection.find().sort("created_at", -1).to_list(1000)
    return [_serialize_app_user(d) for d in docs]


@router.delete("/app-users/{user_id}")
async def delete_app_user(user_id: str, _admin=Depends(get_current_admin)):
    oid = _id(user_id)
    res = await app_users_collection.delete_one({"_id": oid})
    if not res.deleted_count:
        raise HTTPException(status_code=404, detail="App user not found")
    # Cascade clean-up across claimit_db collections keyed by user_id (string).
    uid = user_id
    await app_db["claims"].delete_many({"user_id": uid})
    await app_db["notifications"].delete_many({"user_id": uid})
    await app_db["redeem"].delete_many({"user_id": uid})
    await app_db["user_wallets"].delete_many({"user_id": uid})
    await app_db["fcm_tokens"].delete_many({"user_id": uid})
    await app_bill_reviews_collection.delete_many({"user_id": uid})
    await app_feedback_collection.delete_many({"user_id": uid})
    return {"ok": True}


# ─── Feedback / Complaints (full ticket system, claimit_db.feedback) ──────────
# Users submit via the app's POST /feedback (main backend). Admin replies here;
# the reply is written back onto the same document AND pushed to the user as
# an in-app notification (claimit_db.notifications, is_read:false — matching
# the schema the app's own GET /notifications / unread-count endpoints expect).

def _serialize_feedback(doc):
    if not doc:
        return None
    out = dict(doc)
    out["id"] = str(out.pop("_id"))
    for k, v in list(out.items()):
        if isinstance(v, datetime):
            out[k] = v.isoformat()
    return out


@router.get("/feedback")
async def list_feedback(status: str = "all", _admin=Depends(get_current_admin)):
    query = {} if status == "all" else {"status": status}
    docs = await app_feedback_collection.find(query).sort("created_at", -1).to_list(500)
    return [_serialize_feedback(d) for d in docs]


@router.post("/feedback/{feedback_id}/reply")
async def reply_feedback(feedback_id: str, body: AdminFeedbackReply, _admin=Depends(get_current_admin)):
    oid = _id(feedback_id)
    fb = await app_feedback_collection.find_one({"_id": oid})
    if not fb:
        raise HTTPException(status_code=404, detail="Feedback not found")

    now = datetime.utcnow()
    await app_feedback_collection.update_one(
        {"_id": oid},
        {"$set": {
            "admin_reply": body.reply,
            "status": body.status or "replied",
            "replied_at": now,
        }},
    )

    uid = fb.get("user_id", "")
    if uid:
        await notify_user(
            uid,
            "Reply to your feedback",
            body.reply,
            type="feedback_reply",
            feedback_id=feedback_id,
        )
    return {"ok": True}


@router.delete("/feedback/{feedback_id}")
async def delete_feedback(feedback_id: str, _admin=Depends(get_current_admin)):
    res = await app_feedback_collection.delete_one({"_id": _id(feedback_id)})
    if not res.deleted_count:
        raise HTTPException(status_code=404, detail="Feedback not found")
    return {"ok": True}


# ─── Ads ──────────────────────────────────────────────────────
@router.get("/ads")
async def list_ads(_admin=Depends(get_current_admin)):
    docs = await ads_collection.find().sort("created_at", -1).to_list(500)
    return [_serialize(d) for d in docs]


@router.put("/ads/{ad_id}")
async def update_ad(ad_id: str, patch: AdminAdPatch, _admin=Depends(get_current_admin)):
    update = {k: v for k, v in patch.dict().items() if v is not None}
    if not update:
        return {"ok": True}
    res = await ads_collection.update_one({"_id": _id(ad_id)}, {"$set": update})
    if not res.matched_count:
        raise HTTPException(status_code=404, detail="Ad not found")
    return {"ok": True, "patch": update}


@router.delete("/ads/{ad_id}")
async def delete_ad(ad_id: str, _admin=Depends(get_current_admin)):
    res = await ads_collection.delete_one({"_id": _id(ad_id)})
    if not res.deleted_count:
        raise HTTPException(status_code=404, detail="Ad not found")
    return {"ok": True}


# ─── Shops ────────────────────────────────────────────────────
@router.get("/shops")
async def list_shops(_admin=Depends(get_current_admin)):
    docs = await shops_collection.find().sort("created_at", -1).to_list(500)
    return [_serialize(d) for d in docs]


@router.put("/shops/{shop_id}")
async def update_shop(shop_id: str, patch: AdminShopPatch, _admin=Depends(get_current_admin)):
    update = {k: v for k, v in patch.dict().items() if v is not None}
    if not update:
        return {"ok": True}
    res = await shops_collection.update_one({"_id": _id(shop_id)}, {"$set": update})
    if not res.matched_count:
        raise HTTPException(status_code=404, detail="Shop not found")
    return {"ok": True, "patch": update}


@router.delete("/shops/{shop_id}")
async def delete_shop(shop_id: str, _admin=Depends(get_current_admin)):
    res = await shops_collection.delete_one({"_id": _id(shop_id)})
    if not res.deleted_count:
        raise HTTPException(status_code=404, detail="Shop not found")
    return {"ok": True}


@router.get("/shops/grouped")
async def list_shops_grouped_by_discount(_admin=Depends(get_current_admin)):
    """
    Redeem Zone merchant categorization — groups every shop by its registered
    discount tier (5% / 10% / 15% / 20% / 25% / 30%) for admin visibility.
    """
    docs = await shops_collection.find().sort("created_at", -1).to_list(1000)
    groups: dict = {}
    for d in docs:
        pct = d.get("discount_percentage", 0) or 0
        groups.setdefault(pct, []).append(_serialize(d))
    return {
        "groups": [
            {"discount_percentage": pct, "count": len(shops), "shops": shops}
            for pct, shops in sorted(groups.items())
        ]
    }


# ─── Reviews ──────────────────────────────────────────────────
@router.get("/reviews")
async def list_reviews(_admin=Depends(get_current_admin)):
    docs = await reviews_collection.find().sort("created_at", -1).to_list(500)
    return [_serialize(d) for d in docs]


@router.delete("/reviews/{review_id}")
async def delete_review(review_id: str, _admin=Depends(get_current_admin)):
    res = await reviews_collection.delete_one({"_id": _id(review_id)})
    if not res.deleted_count:
        raise HTTPException(status_code=404, detail="Review not found")
    return {"ok": True}


# ─── Tickets ──────────────────────────────────────────────────
@router.get("/tickets")
async def list_tickets(_admin=Depends(get_current_admin)):
    docs = await tickets_collection.find().sort("created_at", -1).to_list(500)
    return [_serialize(d) for d in docs]


@router.put("/tickets/{ticket_id}")
async def update_ticket(ticket_id: str, patch: AdminTicketPatch, _admin=Depends(get_current_admin)):
    update = {k: v for k, v in patch.dict().items() if v is not None}
    if not update:
        return {"ok": True}
    update["updated_at"] = datetime.utcnow()
    res = await tickets_collection.update_one({"_id": _id(ticket_id)}, {"$set": update})
    if not res.matched_count:
        raise HTTPException(status_code=404, detail="Ticket not found")
    return {"ok": True, "patch": {k: v for k, v in update.items() if k != "updated_at"}}


# ─── Project PDFs ─────────────────────────────────────────────
@router.get("/pdfs")
async def list_pdfs(_admin=Depends(get_current_admin)):
    return {
        "message": "PDF serving not available on Vercel. Host PDFs on a cloud bucket and return URLs here.",
        "pdfs": []
    }




# --- Bill Reviews ---
# Reads/writes claimit_db.bill_manual_reviews - same collection Flutter app writes to.

from pydantic import BaseModel as _BM
from typing import Literal as _Lit, Optional as _Opt

class _ReviewAction(_BM):
    action:        _Lit["approve", "reject"]
    reward_points: _Opt[int]   = None
    cashback:      _Opt[float] = None
    admin_note:    _Opt[str]   = None


def _serialize_review(r):
    return {
        "id":            str(r["_id"]),
        "user_id":       r.get("user_id", ""),
        "shop_name":     r.get("shop_name") or "-",
        "total_amount":  r.get("total_amount", 0),
        "bill_number":   r.get("bill_number") or "",
        "bill_date":     str(r["bill_date"])[:10] if r.get("bill_date") else "",
        "bill_time":     r.get("bill_time") or "",
        "manual_reason": r.get("manual_reason") or "missing_fields",
        "status":        r.get("status", "pending"),
        "reward_points": r.get("reward_points"),
        "cashback":      r.get("cashback"),
        "admin_note":    r.get("admin_note") or "",
        "image_url":     _presign(r.get("image_s3_key")) if r.get("image_s3_key") else None,
        "submitted_at": (
            r["submitted_at"].isoformat() if r.get("submitted_at") else
            r["created_at"].isoformat()   if r.get("created_at")   else ""
        ),
        "reviewed_at": r["reviewed_at"].isoformat() if r.get("reviewed_at") else "",
    }


@router.get("/bill-reviews")
async def admin_list_bill_reviews(status: str = "pending", _admin=Depends(get_current_admin)):
    query = {} if status == "all" else {"status": status}
    cursor = app_bill_reviews_collection.find(query).sort(
        [("submitted_at", -1), ("created_at", -1)]
    )
    docs = await cursor.to_list(length=500)
    return [_serialize_review(d) for d in docs]


@router.post("/bill-reviews/{review_id}/action")
async def admin_action_bill_review(review_id: str, body: _ReviewAction, _admin=Depends(get_current_admin)):
    try:
        oid = ObjectId(review_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid review ID")

    review = await app_bill_reviews_collection.find_one({"_id": oid})
    if not review:
        raise HTTPException(status_code=404, detail="Review not found")
    if review.get("status") != "pending":
        raise HTTPException(status_code=409, detail=f"Review already {review.get('status')}")

    now       = datetime.utcnow()
    uid       = review.get("user_id", "")
    amount    = float(review.get("total_amount", 0))
    shop_name = review.get("shop_name") or "Shop"
    # 1:10 rule — e.g. ₹1,564 bill → 156.4 pts (decimal preserved, NOT rounded to int)
    pts = body.reward_points or round(amount / 10, 1)
    cb  = body.cashback      or round(amount * 0.01, 2)

    # ── Redeem Zone: look up merchant's registered discount % (if any) ───────
    shop_id      = review.get("shop_id")
    discount_pct = 0
    if shop_id:
        try:
            shop_doc = await app_shops_collection.find_one({"_id": ObjectId(shop_id)})
        except Exception:
            shop_doc = None
        discount_pct = (shop_doc or {}).get("discount") or 0

    # Discount value = the shop's registered discount % applied directly to
    # the bill total (kept in sync with /bill/scan in the Flutter backend).
    discount_value = 0.0
    if discount_pct:
        discount_value = round(amount * discount_pct / 100, 2)

    _wallets = app_db["user_wallets"]
    _scans   = app_db["bill_scans"]

    if body.action == "approve":
        wallet = await _wallets.find_one({"user_id": uid})
        existing_pts    = wallet.get("reward_points", 0) if wallet else 0
        deducted_points = min(discount_value, existing_pts) if discount_value else 0
        net_pts         = pts - deducted_points

        await app_bill_reviews_collection.update_one(
            {"_id": oid},
            {"$set": {"status": "approved", "reward_points": pts,
                      "cashback": cb, "admin_note": body.admin_note or "", "reviewed_at": now}},
        )
        if wallet:
            await _wallets.update_one(
                {"user_id": uid},
                {"$inc": {"reward_points": net_pts, "cashback_wallet": cb, "lifetime_cashback": cb}},
            )
        else:
            await _wallets.insert_one({
                "user_id": uid, "reward_points": 1000 + net_pts,
                "cashback_wallet": cb, "lifetime_cashback": cb,
                "total_scans": 0, "created_at": now,
            })
        await _scans.insert_one({
            "user_id": uid, "dup_key": f"review|{review_id}",
            "shop_name": shop_name, "total_amount": round(amount, 2),
            "earned_cashback": cb, "earned_points": pts,
            "discount_percent": discount_pct, "discount_value": discount_value,
            "deducted_points": deducted_points,
            "source": "manual_review", "review_id": review_id, "scanned_at": now,
        })
        note_suffix = (f" ₹{discount_value:.0f} redeem-discount deducted from points."
                       if discount_value else "")
        await notify_user(
            uid,
            "Bill Approved - Rewards Added!",
            (f"Your bill from {shop_name} (Rs.{int(amount)}) verified. "
             f"Rs.{cb:.0f} cashback and {pts} reward points added.{note_suffix}"),
            type="bill_review_approved",
            review_id=review_id,
        )
        return {"ok": True, "action": "approved", "reward_points": pts, "cashback": cb,
                "deducted_points": deducted_points, "discount_value": discount_value}

    await app_bill_reviews_collection.update_one(
        {"_id": oid},
        {"$set": {"status": "rejected", "admin_note": body.admin_note or "", "reviewed_at": now}},
    )
    await notify_user(
        uid,
        "Bill Review Update",
        (f"Your bill from {shop_name} (Rs.{int(amount)}) could not be verified"
         + (f": {body.admin_note}" if body.admin_note else ".")),
        type="bill_review_rejected",
        review_id=review_id,
    )
    return {"ok": True, "action": "rejected"}


# ── App config: new-user bonus settings ───────────────────────────────────────
from pydantic import BaseModel as _BM2
import os as _os

class _AppConfigBody(_BM2):
    reward_points: int
    cashback:      float


@router.get("/app-config")
async def get_app_config(_admin=Depends(get_current_admin)):
    """Return current new-user bonus config."""
    cfg = await app_db["app_config"].find_one({"key": "new_user_bonus"})
    default_pts = int(_os.getenv("NEW_USER_REWARD_POINTS", "1000"))
    default_cb  = float(_os.getenv("NEW_USER_CASHBACK", "10.0"))
    return {
        "reward_points": int(cfg.get("reward_points", default_pts)) if cfg else default_pts,
        "cashback":      float(cfg.get("cashback", default_cb))     if cfg else default_cb,
    }


@router.put("/app-config")
async def update_app_config(body: _AppConfigBody, _admin=Depends(get_current_admin)):
    """Upsert new-user bonus. Takes effect for every new wallet created after this."""
    if body.reward_points < 0 or body.cashback < 0:
        raise HTTPException(status_code=400, detail="Values must be >= 0")
    await app_db["app_config"].update_one(
        {"key": "new_user_bonus"},
        {"$set": {
            "key":           "new_user_bonus",
            "reward_points": body.reward_points,
            "cashback":      body.cashback,
            "updated_at":    datetime.utcnow(),
        }},
        upsert=True,
    )
    return {"ok": True, "reward_points": body.reward_points, "cashback": body.cashback}


# ─── Deleted Users ─────────────────────────────────────────────
@router.get("/deleted-users")
async def list_deleted_users(_admin=Depends(get_current_admin)):
    """Admin-only: full archive of every self-deleted account."""
    docs = await deleted_users_collection.find().sort("deleted_at", -1).to_list(1000)
    result = []
    for d in docs:
        out = {
            "id":         str(d["_id"]),
            "role":       d.get("role", ""),
            "deleted_at": d["deleted_at"].isoformat() if d.get("deleted_at") else "",
            "user":       d.get("user", {}),
            "ads_count":  len(d.get("ads", [])),
            "had_shop":   d.get("shop") is not None,
        }
        result.append(out)
    return result
