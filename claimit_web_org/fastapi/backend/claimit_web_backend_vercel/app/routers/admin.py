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

from app.database import (
    users_collection, ads_collection, shops_collection,
    reviews_collection, tickets_collection, transactions_collection,
    app_bill_reviews_collection, app_db, app_notifications_collection,
)
from app.models.schemas import (
    AdminLoginRequest, AdminAdPatch, AdminShopPatch, AdminTicketPatch,
)
from app.utils.auth import create_access_token
from app.utils.dependencies import get_current_admin

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
        "image_base64":  r.get("image_base64") or "",
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
    pts = body.reward_points or max(1, int(amount * 0.1))
    cb  = body.cashback      or round(amount * 0.01, 2)

    _wallets = app_db["user_wallets"]
    _scans   = app_db["bill_scans"]

    if body.action == "approve":
        await app_bill_reviews_collection.update_one(
            {"_id": oid},
            {"$set": {"status": "approved", "reward_points": pts,
                      "cashback": cb, "admin_note": body.admin_note or "", "reviewed_at": now}},
        )
        wallet = await _wallets.find_one({"user_id": uid})
        if wallet:
            await _wallets.update_one(
                {"user_id": uid},
                {"$inc": {"reward_points": pts, "cashback_wallet": cb, "lifetime_cashback": cb}},
            )
        else:
            await _wallets.insert_one({
                "user_id": uid, "reward_points": 1000 + pts,
                "cashback_wallet": cb, "lifetime_cashback": cb,
                "total_scans": 0, "created_at": now,
            })
        await _scans.insert_one({
            "user_id": uid, "dup_key": f"review|{review_id}",
            "shop_name": shop_name, "total_amount": round(amount, 2),
            "earned_cashback": cb, "earned_points": pts,
            "source": "manual_review", "review_id": review_id, "scanned_at": now,
        })
        await app_notifications_collection.insert_one({
            "user_id": uid,
            "title": "Bill Approved - Rewards Added!",
            "message": (f"Your bill from {shop_name} (Rs.{int(amount)}) verified. "
                        f"Rs.{cb:.0f} cashback and {pts} reward points added."),
            "type": "bill_review_approved",
            "is_read": False, "review_id": review_id, "created_at": now,
        })
        return {"ok": True, "action": "approved", "reward_points": pts, "cashback": cb}

    await app_bill_reviews_collection.update_one(
        {"_id": oid},
        {"$set": {"status": "rejected", "admin_note": body.admin_note or "", "reviewed_at": now}},
    )
    await app_notifications_collection.insert_one({
        "user_id": uid,
        "title": "Bill Review Update",
        "message": (f"Your bill from {shop_name} (Rs.{int(amount)}) could not be verified"
                    + (f": {body.admin_note}" if body.admin_note else ".")),
        "type": "bill_review_rejected",
        "is_read": False, "review_id": review_id, "created_at": now,
    })
    return {"ok": True, "action": "rejected"}
