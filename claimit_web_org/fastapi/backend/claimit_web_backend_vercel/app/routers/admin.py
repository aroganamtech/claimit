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
# NOTE: Local file serving is not available on Vercel serverless.
# Upload the design-spec PDFs to a cloud bucket (S3, Supabase, Cloudinary)
# and return public URLs here instead.
@router.get("/pdfs")
async def list_pdfs(_admin=Depends(get_current_admin)):
    return {
        "message": "PDF serving not available on Vercel. Host PDFs on a cloud bucket and return URLs here.",
        "pdfs": []
    }
