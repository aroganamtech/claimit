"""
Admin panel API. All endpoints require an admin JWT issued by /admin/login.

Admin credentials come from the .env file:
    ADMIN_USER=admin
    ADMIN_PASS=admin123

(Defaults are admin / admin123 if those vars aren't set.)

Every endpoint reads/writes MongoDB directly — there's no per-user auth check
because admin can manage any record.
"""
from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, Query
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timezone, timedelta
from bson import ObjectId
import io
import os
import json
import random

from utils.s3 import generate_presigned_url_sync as _presign
from utils.s3 import generate_video_url_sync as _video_presign
from utils.s3 import generate_presigned_upload_url
from utils.s3 import ALLOWED_VIDEO_TYPES, ALLOWED_IMAGE_TYPES
from utils.s3 import delete_object as _s3_delete
from utils.s3 import public_url as _public_url
from database import (
    users_collection, ads_collection, shops_collection,
    reviews_collection, tickets_collection, transactions_collection,
    app_bill_reviews_collection, app_db, app_notifications_collection,
    app_users_collection, app_feedback_collection, app_shops_collection,
    deleted_users_collection,
    app_banners_collection, app_deals_collection, app_reels_collection,
    category_images_collection, app_learn_collection,
)
from models.schemas import (
    AdminLoginRequest, AdminAdPatch, AdminShopPatch, AdminTicketPatch,
    AdminFeedbackReply,
)
from utils.auth import create_access_token
from utils.dependencies import get_current_admin
from utils.notify import notify_user
from utils.pincode_geo import resolve_point_for_ad
from utils.ad_cycle import (
    next_cycle, cycle_for, cycle_info, is_live, get_start_weekday,
    IST, WEEKDAY_NAMES,
)

router = APIRouter()


def _dup_key(shop: str, bill_date: str, amount: float, bill_time=None) -> str:
    """
    Same fingerprint the main app backend computes in fastapi/backend/app/
    routes/bill.py (_dup_key) and the Flutter client (BillRewardProvider).
    Kept in sync so a bill approved here via manual review registers in the
    SAME dedup namespace as normal /bill/scan submissions — otherwise the
    app's local duplicate check (and /bill/manual-review's server-side
    check) can never recognize an already-approved bill and users can keep
    resubmitting/rescanning it.
    """
    import re as _re
    s = _re.sub(r"[^a-z0-9]", "", (shop or "").lower())
    amt = f"{amount:.0f}"
    t = (bill_time or "").strip()
    if t:
        return f"{s}|{bill_date}|{t}|{amt}"
    return f"{s}|{bill_date}|{amt}"


ADMIN_USER = os.getenv("ADMIN_USER", "admin")
ADMIN_PASS = os.getenv("ADMIN_PASS", "Krishna2001$%")


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
    """Overview counts for the admin dashboard.

    IMPORTANT — there are two separate populations, in two databases:

      claimit_web.users  — people who registered on the WEBSITE: advertisers,
                           sales agents, shop owners. Grows only when somebody
                           signs up on the web portal.

      claimit_db.users   — the real end-customers who downloaded the FLUTTER
                           APP. This is the number that grows with the
                           business, and it is the one people mean by "users".

    This endpoint used to count only the first one, under the label
    "Total Users". So every app signup was invisible here: the figure looked
    small and never moved, no matter how many downloads there were. Both are
    now reported, named for what they actually are.
    """
    app_users = 0
    app_users_today = 0
    try:
        app_users = await app_users_collection.count_documents({})
        # "Joined today" gives the client a live signal — a total alone can't
        # show whether growth has stopped.
        _since = datetime.utcnow() - timedelta(days=1)
        app_users_today = await app_users_collection.count_documents(
            {"created_at": {"$gte": _since}})
    except Exception as e:
        print(f"[stats] app user count failed: {e}")

    return {
        # End-customers in the app — the headline number.
        "app_users": app_users,
        "app_users_today": app_users_today,
        # Web-portal accounts, by role.
        "users": {
            "total": await users_collection.count_documents({}),
            "advertiser": await users_collection.count_documents({"role": "advertiser"}),
            "sales": await users_collection.count_documents({"role": "sales"}),
            "shop": await users_collection.count_documents({"role": "shop"}),
        },
        "ads_total": await ads_collection.count_documents({}),
        "ads_active": await ads_collection.count_documents({"status": "active"}),
        # Already the APP database (claimit_db.shops) — every shop, whether it
        # was bulk-uploaded, registered on the web, or claimed in the app.
        "shops_total": await shops_collection.count_documents({}),
        "shops_claimed": await shops_collection.count_documents({"is_claimed": True}),
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
    # Cascade clean-up — also remove app-side ad mirrors + S3 creatives,
    # otherwise the deleted user's ads keep showing inside the Flutter app.
    user_ads = await ads_collection.find({"user_id": user_id}).to_list(500)
    for ad in user_ads:
        aid = str(ad["_id"])
        for coll in (app_banners_collection, app_deals_collection,
                     app_reels_collection):
            await coll.delete_many({"web_ad_id": aid})
        for key_field in ("image_s3_key", "video_s3_key", "thumbnail_s3_key"):
            if ad.get(key_field):
                await _s3_delete(ad[key_field])
    await ads_collection.delete_many({"user_id": user_id})
    # Same S3 clean-up as the direct /admin/shops/{id} delete — otherwise a
    # user's shop photos are orphaned in S3 when their account is removed.
    user_shops = await shops_collection.find({"user_id": user_id}).to_list(500)
    for shop in user_shops:
        await _delete_shop_media(shop)
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
    # Claims store uploaded evidence documents in S3 (documents: [s3_key, ...]).
    user_claims = await app_db["claims"].find({"user_id": uid}).to_list(500)
    for claim in user_claims:
        for key in (claim.get("documents") or []):
            if key:
                await _s3_delete(key)
    await app_db["claims"].delete_many({"user_id": uid})
    await app_db["notifications"].delete_many({"user_id": uid})
    await app_db["redeem"].delete_many({"user_id": uid})
    await app_db["user_wallets"].delete_many({"user_id": uid})
    await app_db["fcm_tokens"].delete_many({"user_id": uid})
    # Bill reviews store the scanned bill photo in S3 (image_s3_key).
    user_bill_reviews = await app_bill_reviews_collection.find({"user_id": uid}).to_list(500)
    for review in user_bill_reviews:
        if review.get("image_s3_key"):
            await _s3_delete(review["image_s3_key"])
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

    # ── Mirror the edit into the app-facing copies ───────────────────────────
    # The Flutter app reads claimit_db.deals / reels / banners, NOT this web
    # ads collection. Without this, an admin editing an ad saw the change on
    # the website and nothing at all in the app — the same class of bug the
    # delete endpoint below was already fixed for.
    #
    # Editing the pincode also re-resolves the coordinates, so correcting a
    # missing or wrong pincode is all an admin has to do to make a deal
    # appear in the 5 km radius search. No script, no redeploy.
    mirrored = dict(update)
    if "pincode" in update:
        ad_lat, ad_lng, ad_geo = await resolve_point_for_ad(
            app_db, pincode=update["pincode"]
        )
        if ad_geo:
            located = {"lat": ad_lat, "lng": ad_lng, "geo": ad_geo}
            mirrored.update(located)
            await ads_collection.update_one({"_id": _id(ad_id)},
                                            {"$set": located})

    for coll in (app_banners_collection, app_deals_collection,
                 app_reels_collection):
        try:
            await coll.update_many({"web_ad_id": ad_id}, {"$set": mirrored})
        except Exception as e:
            # A mirror failure must not lose the edit that already succeeded.
            print(f"[admin] ad {ad_id} mirror failed: {e}")

    return {"ok": True, "patch": mirrored}


@router.delete("/ads/{ad_id}")
async def delete_ad(ad_id: str, _admin=Depends(get_current_admin)):
    """
    Deleting an ad must remove it EVERYWHERE:
      1. the mirrored app-side copy (claimit_db banners / deals / reels —
         this is what the Flutter app actually displays; the old code left
         these behind, so "deleted" ads kept showing in the app),
      2. the creative files in S3 (image / video / thumbnail),
      3. the web ads record itself.
    """
    ad = await ads_collection.find_one({"_id": _id(ad_id)})
    if not ad:
        raise HTTPException(status_code=404, detail="Ad not found")

    # 1) Remove mirrored app-side copies (all types — delete_many is a no-op
    #    on collections that don't contain this web_ad_id)
    for coll in (app_banners_collection, app_deals_collection,
                 app_reels_collection):
        await coll.delete_many({"web_ad_id": ad_id})

    # 2) Delete creative files from S3 (best-effort — never blocks)
    for key_field in ("image_s3_key", "video_s3_key", "thumbnail_s3_key"):
        key = ad.get(key_field)
        if key:
            await _s3_delete(key)

    # 3) Delete the web ad record
    await ads_collection.delete_one({"_id": _id(ad_id)})
    return {"ok": True}


# ─── Shops ────────────────────────────────────────────────────
@router.get("/shops")
async def list_shops(
    state: str = Query("", description="Filter by state (exact, case-insensitive)"),
    district: str = Query("", description="Filter by district (exact, case-insensitive)"),
    city: str = Query("", description="Filter by city (exact, case-insensitive)"),
    pincode: str = Query("", description="Filter by pincode (exact)"),
    category: str = Query("", description="Filter by category (exact, case-insensitive)"),
    shop_name: str = Query("", description="Filter by shop name (substring, case-insensitive)"),
    shop_type: str = Query("", description="Filter by 'redeem' or 'reward'"),
    status: str = Query("", description="Filter by 'pending' / 'active' / 'suspended'"),
    claimed: str = Query("", description="'yes' = has an owner, 'no' = bulk/unclaimed"),
    _admin=Depends(get_current_admin),
):
    """List shops. All filters are optional and combine with AND — supports
    the client's State → District → PIN code → Category → Shop hierarchy,
    plus type/status/claimed so admin can quickly zero in on one shop."""
    query: dict = {}
    if state:
        query["state"] = {"$regex": f"^{state.strip()}$", "$options": "i"}
    if district:
        query["district"] = {"$regex": f"^{district.strip()}$", "$options": "i"}
    if city:
        query["city"] = {"$regex": f"^{city.strip()}$", "$options": "i"}
    if pincode:
        query["pincode"] = pincode.strip()
    if category:
        query["category"] = {"$regex": f"^{category.strip()}$", "$options": "i"}
    if shop_name:
        query["shop_name"] = {"$regex": shop_name.strip(), "$options": "i"}
    if shop_type:
        query["shop_type"] = shop_type.strip().lower()
    if status:
        query["status"] = status.strip().lower()
    if claimed == "yes":
        query["user_id"] = {"$exists": True, "$ne": "", "$nin": [None]}
    elif claimed == "no":
        query["$or"] = [
            {"user_id": {"$exists": False}}, {"user_id": None}, {"user_id": ""},
        ]
    docs = await shops_collection.find(query).sort("created_at", -1).to_list(2000)
    return [_serialize(d) for d in docs]


@router.get("/shops/filters")
async def shop_filter_options(_admin=Depends(get_current_admin)):
    """Distinct state/district/city/category values, for populating the
    filter dropdowns."""
    states = await shops_collection.distinct("state")
    districts = await shops_collection.distinct("district")
    cities = await shops_collection.distinct("city")
    categories = await shops_collection.distinct("category")
    return {
        "states": sorted([s for s in states if s]),
        "districts": sorted([d for d in districts if d]),
        "cities": sorted([c for c in cities if c]),
        "categories": sorted([c for c in categories if c]),
    }


@router.put("/shops/{shop_id}")
async def update_shop(shop_id: str, patch: AdminShopPatch, _admin=Depends(get_current_admin)):
    update = {k: v for k, v in patch.dict().items() if v is not None}
    if not update:
        return {"ok": True}
    res = await shops_collection.update_one({"_id": _id(shop_id)}, {"$set": update})
    if not res.matched_count:
        raise HTTPException(status_code=404, detail="Shop not found")
    return {"ok": True, "patch": update}


async def _delete_shop_media(shop: dict) -> None:
    """Best-effort delete of a shop's cover + gallery images from S3.
    Never raises — a failed S3 delete must not block deleting the DB record."""
    keys = []
    if shop.get("image_s3_key"):
        keys.append(shop["image_s3_key"])
    keys.extend(k for k in (shop.get("image_s3_keys") or []) if k)
    for key in keys:
        await _s3_delete(key)


@router.delete("/shops/{shop_id}")
async def delete_shop(shop_id: str, _admin=Depends(get_current_admin)):
    shop = await shops_collection.find_one({"_id": _id(shop_id)})
    if not shop:
        raise HTTPException(status_code=404, detail="Shop not found")
    await _delete_shop_media(shop)
    await shops_collection.delete_one({"_id": shop["_id"]})
    return {"ok": True}


# ─── Transactions ─────────────────────────────────────────────
@router.get("/transactions")
async def list_transactions(_admin=Depends(get_current_admin)):
    """Every shop-registration payment with full shop + user + payment detail."""
    docs = await transactions_collection.find().sort("created_at", -1).to_list(5000)
    return [_serialize(d) for d in docs]


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


# ─── Shops: bulk Excel upload ─────────────────────────────────
# Admin downloads a predefined template, fills one shop per row (photo pasted
# into the Image column), and uploads it. Rows are inserted into the SAME
# claimit_db.shops collection seed.py uses. Images are extracted from the
# workbook and pushed to S3 (image_s3_key), exactly like the seeder.

@router.get("/shops/bulk-template")
async def shops_bulk_template(_admin=Depends(get_current_admin)):
    """Download the predefined .xlsx template for bulk shop upload."""
    from utils.shop_bulk import build_template_bytes
    data = build_template_bytes()
    return StreamingResponse(
        io.BytesIO(data),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={
            "Content-Disposition": 'attachment; filename="claimit_shops_template_v1.xlsx"',
            # avoid the browser serving a stale cached copy of the template
            "Cache-Control": "no-store, must-revalidate",
        },
    )


# NOTE: this path-param route is deliberately declared last among the
# /shops/* GET routes — FastAPI matches routes in declaration order, and a
# {shop_id} path param would otherwise swallow literal paths like
# /shops/grouped or /shops/bulk-template.
@router.get("/shops/{shop_id}")
async def get_shop_detail(shop_id: str, _admin=Depends(get_current_admin)):
    """Full detail for one shop, including its registration/payment transaction
    if one exists — used by the admin shop landing page."""
    doc = await shops_collection.find_one({"_id": _id(shop_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Shop not found")
    shop = _serialize(doc)
    txn = await transactions_collection.find_one(
        {"shop_id": shop_id}, sort=[("created_at", -1)]
    )
    shop["transaction"] = _serialize(txn) if txn else None
    return shop


def _to_bool(v) -> bool:
    return str(v).strip().lower() in ("true", "1", "yes", "y", "✓")


def _num(v):
    """Parse an optional float; blank/invalid → None (so lat/lng stay unset)."""
    if v is None or str(v).strip() == "":
        return None
    try:
        return float(v)
    except (ValueError, TypeError):
        return None


class BulkUploadBody(BaseModel):
    key: str = ""          # S3 key of the uploaded .xlsx (browser PUTs it first)
    # {original filename: s3 key} for photos the admin uploaded BEFORE the
    # sheet. Rows reference a photo by filename in their `image` column. Empty
    # for the shops importer, which takes its images from category pools.
    images: dict = {}


@router.post("/shops/bulk-upload")
async def shops_bulk_upload(
    body: BulkUploadBody,
    replace: bool = Query(False, description="Wipe all shops before inserting"),
    _admin=Depends(get_current_admin),
):
    """
    Parse a shops workbook the browser already uploaded to S3 (same pattern as
    image/video uploads — the file goes straight to S3, only its key comes to
    the API) and insert the rows into claimit_db.shops. Returns a per-row
    summary. `replace=true` clears the collection first.
    """
    import openpyxl
    from utils.shop_bulk import (
        COLUMNS, parse_categories, derive_location,
    )
    from utils.s3 import download_bytes

    if not body.key:
        raise HTTPException(status_code=400, detail="Missing uploaded file key.")

    try:
        raw = download_bytes(body.key)
    except Exception as e:
        raise HTTPException(status_code=400,
                            detail=f"Could not read the uploaded file from storage: {e}")

    try:
        wb = openpyxl.load_workbook(io.BytesIO(raw), data_only=True)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Could not read Excel file: {e}")

    ws = wb["Shops"] if "Shops" in wb.sheetnames else wb.worksheets[0]

    # Map header text → column index (0-based) using the first row.
    header_cells = [str(c.value).strip() if c.value is not None else "" for c in ws[1]]
    header_lookup = {h: i for i, h in enumerate(header_cells)}
    # Fall back to positional mapping if headers were altered.
    col_index = {}
    for pos, (header, field, kind) in enumerate(COLUMNS):
        col_index[field] = header_lookup.get(header, pos)

    def cell(row, field):
        idx = col_index.get(field)
        if idx is None or idx >= len(row):
            return None
        return row[idx]

    # Load the per-category image pools once (Admin → Category Images). Each
    # bulk shop is given a real cover + gallery picked from its category's pool
    # so it shows a picture in the app without a per-row image upload.
    cat_pool: dict = {}
    async for _cd in category_images_collection.find():
        _keys = [k for k in (_cd.get("keys") or []) if k]
        if _keys:
            cat_pool[_cd.get("category_id")] = _keys

    errors = []
    docs = []
    seen_any = False
    for r in range(2, ws.max_row + 1):
        row = [c.value for c in ws[r]]
        name = cell(row, "name")
        if name is None or str(name).strip() == "":
            continue  # skip blank rows silently
        seen_any = True
        name = str(name).strip()

        cat_ids, unknown_cats = parse_categories(cell(row, "category_ids"))
        if not cat_ids:
            errors.append({"row": r, "name": name,
                           "error": "No valid category — check the category names."})
            continue
        if unknown_cats:
            errors.append({"row": r, "name": name,
                           "error": f"Unknown categories skipped: {', '.join(unknown_cats)}"})

        # Phone is mandatory — a shop with no number can never be claimed by
        # its owner (claim-by-mobile is the only claim flow), so a blank
        # phone here silently produced an unclaimable shop before this check.
        phone = str(cell(row, "phone") or "").strip()
        if not phone:
            errors.append({"row": r, "name": name,
                           "error": "Missing phone number — mobile number is mandatory."})
            continue

        country  = str(cell(row, "country")  or "").strip()
        state    = str(cell(row, "state")    or "").strip()
        district = str(cell(row, "district") or "").strip()
        city     = str(cell(row, "city")     or "").strip()
        area     = str(cell(row, "area")     or "").strip()
        pincode  = str(cell(row, "pincode")  or "").strip()
        address  = str(cell(row, "address")  or "").strip()
        location = derive_location(area, city, district)

        try:
            doc = {
                "name":          name,
                "category_ids":  cat_ids,
                # Structured address (same fields as the shop register form).
                "country":       country,
                "state":         state,
                "district":      district,
                "city":          city,
                "area":          area,
                "pincode":       pincode,
                "address":       address,
                "shop_address":  address,   # register uses this key
                "location":      location,  # "Area, City" shown on shop cards
                # Tolerant numeric parse — a blank or bad value falls back to a
                # sensible default instead of skipping the whole shop row.
                "discount":      int(_num(cell(row, "discount")) or 0),
                "rating":        (_num(cell(row, "rating")) or 4.0),
                "added_days_ago": int(_num(cell(row, "added_days_ago")) or 0),
                "about":         str(cell(row, "about") or "").strip(),
                "timing":        str(cell(row, "timing") or "").strip(),
                "phone":         phone,
                "lat":           _num(cell(row, "lat")),
                "lng":           _num(cell(row, "lng")),
            }
            # GeoJSON mirror of lat/lng for the app's real $geoNear "nearby
            # shops" query (2dsphere index). None when lat/lng weren't given
            # (they're optional in the sheet) — same as the register flow.
            _lat, _lng = doc["lat"], doc["lng"]
            doc["geo"] = {"type": "Point", "coordinates": [_lng, _lat]} if (_lat is not None and _lng is not None) else None
        except (ValueError, TypeError) as e:
            errors.append({"row": r, "name": name, "error": f"Invalid number: {e}"})
            continue

        # discount_percentage kept in sync for the admin grouped view.
        doc["discount_percentage"] = doc["discount"]

        # Assign a real cover + up to 3 gallery images from the shop's category
        # image pool (Admin → Category Images). The app builds public S3 URLs
        # from these keys, so the shop shows a picture with no per-row upload.
        # Uses the FIRST of the shop's categories that has an image pool:
        #   • only 1 image in the pool → that image is the cover for every shop
        #     in the category (gallery stays empty),
        #   • many images → a random cover + up to 3 random others as gallery.
        cover_key = ""
        gallery_keys: list = []
        for _cid in cat_ids:
            _pool = cat_pool.get(_cid)
            if _pool:
                cover_key = random.choice(_pool)
                _others = [k for k in _pool if k != cover_key]
                random.shuffle(_others)
                gallery_keys = _others[:3]
                break

        # Bulk-uploaded shops default to a REWARD shop so they appear on the
        # app's Reward page straight away. The owner can change the type later
        # when they claim/register the shop. (Without a type the app treats a
        # shop as both reward AND redeem, which kept them off the Reward page.)
        doc.update({
            "shop_type":       "reward",
            "has_rewards":     True,
            "has_redeem":      False,
            "image_s3_key":    cover_key,
            "image_s3_keys":   gallery_keys,
            "image_url":       _public_url(cover_key) if cover_key else "",
            "image_urls":      [_public_url(k) for k in gallery_keys],
            "image_data":      "",
            "image_data_list": [],
            "created_at":      datetime.now(timezone.utc),
        })
        docs.append(doc)

    if replace:
        await shops_collection.delete_many({})

    inserted = 0
    if docs:
        res = await shops_collection.insert_many(docs)
        inserted = len(res.inserted_ids)

    return {
        "ok": True,
        "replaced": replace,
        "inserted": inserted,
        "skipped_empty": not seen_any,
        "errors": errors,
    }


# ═══════════════════════════════════════════════════════════════════════════
# Bulk upload — Claimit Select  /  Local Finds  /  Classifieds
#
# Three SEPARATE products, so three separate uploads. Each one writes to
# exactly one place and can never touch another's rows:
#
#   Claimit Select → claimit_db.select_professionals   (its own collection)
#   Local Finds    → claimit_db.classifieds, listing_type="local_find"
#   Classifieds    → claimit_db.classifieds, listing_type="classified"
#
# Local Finds and Classifieds share a collection, so every write below stamps
# listing_type explicitly and every query filters on it.
#
# IMPORTANT — `replace` here is NOT the same as the shops one. Shops wipes the
# whole collection; that would be destructive here because professionals and
# businesses REGISTER THEMSELVES and pay. So `replace` only ever deletes rows
# this bulk tool created (source="bulk"); self-registered rows are untouched.
# ═══════════════════════════════════════════════════════════════════════════

_select_professionals = app_db["select_professionals"]
_classifieds_collection = app_db["classifieds"]

# ── Scoped category image pools ───────────────────────────────────────────────
# Shops already have per-category image pools (category_images_collection, keyed
# by an int id). Claimit Select / Local Finds / Classifieds need the same idea
# but their category ids are STRINGS and their category sets differ, so they get
# their own collection keyed by (scope, category_id). Kept separate from the
# shops pools deliberately — nothing here can disturb existing shop data.
_feature_category_images = app_db["feature_category_images"]

# scope → the category ids/labels that scope allows.
def _scope_categories(scope: str) -> dict:
    """{category_id: label} for a scope, or {} when the scope is unknown."""
    if scope == "select":
        from utils.select_bulk import CATEGORY_LEGEND
        return dict(CATEGORY_LEGEND)
    if scope in ("local_find", "classified"):
        from utils.classified_bulk import categories_for
        # These use the label itself as the id (that's what the app stores).
        return {label: label for label in categories_for(scope)}
    return {}


FEATURE_SCOPES = ("select", "local_find", "classified")


async def _category_pool(scope: str) -> dict:
    """{category_id: [s3 keys]} for one scope — used by the bulk importers to
    give a row an image when it didn't name one."""
    pool: dict = {}
    async for d in _feature_category_images.find({"scope": scope}):
        keys = [k for k in (d.get("keys") or []) if k]
        if keys:
            pool[d.get("category_id")] = keys
    return pool


def _bulk_cell_reader(ws, columns):
    """header→column mapping with positional fallback (same approach as the
    shops importer, so a reordered or renamed header still imports)."""
    header_cells = [str(c.value).strip() if c.value is not None else "" for c in ws[1]]
    lookup = {h: i for i, h in enumerate(header_cells)}
    col_index = {}
    for pos, (header, field, _kind) in enumerate(columns):
        col_index[field] = lookup.get(header, pos)

    def cell(row, field):
        idx = col_index.get(field)
        if idx is None or idx >= len(row):
            return None
        return row[idx]

    return cell


async def _upload_row_image(img, folder: str) -> str:
    """(bytes, ext) tuple from extract_row_images → S3 key, or "" on failure.

    Only a FALLBACK. Pictures pasted into a workbook are unreliable (they don't
    survive Google Sheets and re-anchor when rows are edited), which is why the
    shops importer dropped that approach. The primary path is _match_image()
    below: the admin uploads image files first and names them in the sheet.
    """
    if not img:
        return ""
    try:
        from utils.s3 import upload_bytes
        data, ext = img
        return await upload_bytes(data, folder, filename=f"row{ext}")
    except Exception:
        return ""


def _build_image_index(images: dict) -> dict:
    """Normalise the {filename: s3_key} map the browser sends after uploading
    the pictures, so a sheet can reference a photo loosely.

    Indexed twice per file — with and without its extension — and lowercased,
    so "Ananya.JPG", "ananya.jpg" and "ananya" all resolve to the same key.
    """
    idx = {}
    for fname, key in (images or {}).items():
        if not fname or not key:
            continue
        base = str(fname).strip().lower()
        idx[base] = key
        stem = base.rsplit(".", 1)[0] if "." in base else base
        idx.setdefault(stem, key)
    return idx


def _match_image(cell_value, index: dict) -> str:
    """Sheet's `image` cell → S3 key, or "" when blank/unmatched."""
    name = str(cell_value or "").strip().lower()
    if not name or not index:
        return ""
    if name in index:
        return index[name]
    stem = name.rsplit(".", 1)[0] if "." in name else name
    return index.get(stem, "")


# ── Claimit Select ────────────────────────────────────────────────────────────

@router.get("/select/bulk-template")
async def select_bulk_template(_admin=Depends(get_current_admin)):
    """Download the .xlsx template for bulk Claimit Select professionals."""
    from utils.select_bulk import build_template_bytes
    data = build_template_bytes()
    return StreamingResponse(
        io.BytesIO(data),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={
            "Content-Disposition": 'attachment; filename="claimit_select_template_v1.xlsx"',
            "Cache-Control": "no-store, must-revalidate",
        },
    )


@router.post("/select/bulk-upload")
async def select_bulk_upload(
    body: BulkUploadBody,
    replace: bool = Query(False, description="Delete previously bulk-uploaded professionals first (never self-registered ones)"),
    _admin=Depends(get_current_admin),
):
    """Insert professionals into claimit_db.select_professionals from a
    workbook the browser already PUT to S3. Re-uploading the same phone
    UPDATES that professional instead of duplicating."""
    import openpyxl
    from utils.select_bulk import COLUMNS, resolve_category, split_list, CATEGORY_LEGEND, PLANS
    from utils.shop_bulk import extract_row_images
    from utils.s3 import download_bytes

    if not body.key:
        raise HTTPException(status_code=400, detail="Missing uploaded file key.")
    try:
        raw = download_bytes(body.key)
    except Exception as e:
        raise HTTPException(status_code=400,
                            detail=f"Could not read the uploaded file from storage: {e}")
    try:
        wb = openpyxl.load_workbook(io.BytesIO(raw), data_only=True)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Could not read Excel file: {e}")

    ws = wb["Professionals"] if "Professionals" in wb.sheetnames else wb.worksheets[0]
    cell = _bulk_cell_reader(ws, COLUMNS)
    img_index = _build_image_index(body.images)   # 1st: uploaded-first photos
    pasted = extract_row_images(raw)              # 2nd: pasted into the sheet
    cat_pool = await _category_pool("select")     # 3rd: the category's pool

    if replace:
        await _select_professionals.delete_many({"source": "bulk"})

    errors, inserted, updated = [], 0, 0
    seen_any = False

    for r in range(2, ws.max_row + 1):
        row = [c.value for c in ws[r]]
        name = str(cell(row, "name") or "").strip()
        if not name:
            continue                      # blank row
        seen_any = True

        cat = resolve_category(cell(row, "category"))
        if not cat:
            errors.append({"row": r, "name": name,
                           "error": "Unknown category — pick one from the dropdown."})
            continue

        phone = str(cell(row, "phone") or "").strip()
        if not phone:
            errors.append({"row": r, "name": name,
                           "error": "Missing phone — it identifies the row on re-upload."})
            continue

        plan = str(cell(row, "plan") or "custom").strip().lower()
        if plan not in PLANS:
            plan = "custom"

        lat, lng = _num(cell(row, "lat")), _num(cell(row, "lng"))

        doc = {
            "name": name,
            "category": cat,
            "category_label": CATEGORY_LEGEND[cat],
            "role": str(cell(row, "role") or CATEGORY_LEGEND[cat]).strip(),
            "about": str(cell(row, "about") or "").strip(),
            "experience_years": int(_num(cell(row, "experience_years")) or 0),
            "consultation_fee": float(_num(cell(row, "consultation_fee")) or 0),
            "services": split_list(cell(row, "services")),
            "tags": split_list(cell(row, "tags"), limit=6),
            "phone": phone,
            "email": str(cell(row, "email") or "").strip(),
            "address": str(cell(row, "address") or "").strip(),
            "area": str(cell(row, "area") or "").strip(),
            "city": str(cell(row, "city") or "").strip(),
            "district": str(cell(row, "district") or "").strip(),
            "state": str(cell(row, "state") or "").strip(),
            "pincode": str(cell(row, "pincode") or "").strip(),
            "plan": plan,
            "amount_paid": 0.0,
            "payment_link_id": "",
            "offer_text": str(cell(row, "offer_text") or "").strip(),
            "offer_percent": int(_num(cell(row, "offer_percent")) or 0),
            "offer_valid_till": str(cell(row, "offer_valid_till") or "").strip(),
            "rating": float(_num(cell(row, "rating")) or 0),
            "review_count": int(_num(cell(row, "review_count")) or 0),
            "status": "active",
            "is_verified": True,
            "source": "bulk",
            "updated_at": datetime.now(timezone.utc),
        }
        if lat is not None and lng is not None:
            doc["geo"] = {"type": "Point", "coordinates": [lng, lat]}
            doc["lat"] = lat
            doc["lng"] = lng

        # Photo, in order of preference:
        #   1. the filename named in the sheet (uploaded beforehand)
        #   2. a picture pasted into the sheet (legacy fallback)
        #   3. a random image from this category's pool (Admin → Category
        #      Images), so a row with no photo of its own still looks right
        # Only set when we actually found one, so re-uploading a sheet without
        # images keeps whatever photo the professional already had.
        named = str(cell(row, "image") or "").strip()
        key = _match_image(named, img_index)
        if not key:
            key = await _upload_row_image(pasted.get(r), "select/images")
        if not key:
            _pool = cat_pool.get(cat)
            if _pool:
                key = random.choice(_pool)
        if key:
            doc["photo_s3_key"] = key
        if named and not _match_image(named, img_index):
            # They named a file that wasn't uploaded — say so, rather than
            # silently substituting a category image without explanation.
            errors.append({"row": r, "name": name,
                           "error": f"Photo '{named}' wasn't among the uploaded images"
                                    + (" — used a category image instead." if key
                                       else " — row saved without a photo.")})

        # Phone is the stable identity for bulk rows, so a corrected sheet can
        # be re-uploaded without creating duplicates.
        user_id = f"bulk:select:{phone}"
        existing = await _select_professionals.find_one({"user_id": user_id})
        if existing:
            await _select_professionals.update_one({"_id": existing["_id"]}, {"$set": doc})
            updated += 1
        else:
            doc["user_id"] = user_id
            doc.setdefault("photo_s3_key", "")
            doc.setdefault("portfolio_s3_keys", [])
            doc["created_at"] = datetime.now(timezone.utc)
            await _select_professionals.insert_one(doc)
            inserted += 1

    return {
        "ok": True,
        "replaced": replace,
        "inserted": inserted,
        "updated": updated,
        "skipped_empty": not seen_any,
        "errors": errors,
    }


# ── Local Finds / Classifieds ─────────────────────────────────────────────────

@router.get("/classifieds/bulk-template")
async def classifieds_bulk_template(
    listing_type: str = Query("local_find", description="local_find | classified"),
    _admin=Depends(get_current_admin),
):
    """Download the .xlsx template for ONE of the two products."""
    from utils.classified_bulk import build_template_bytes, VALID_TYPES
    if listing_type not in VALID_TYPES:
        raise HTTPException(status_code=400,
                            detail=f"listing_type must be one of {VALID_TYPES}")
    data = build_template_bytes(listing_type)
    fname = ("claimit_local_finds_template_v1.xlsx" if listing_type == "local_find"
             else "claimit_classifieds_template_v1.xlsx")
    return StreamingResponse(
        io.BytesIO(data),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={
            "Content-Disposition": f'attachment; filename="{fname}"',
            "Cache-Control": "no-store, must-revalidate",
        },
    )


@router.post("/classifieds/bulk-upload")
async def classifieds_bulk_upload(
    body: BulkUploadBody,
    listing_type: str = Query("local_find", description="local_find | classified"),
    replace: bool = Query(False, description="Delete previously bulk-uploaded rows OF THIS TYPE first"),
    _admin=Depends(get_current_admin),
):
    """Insert Local Finds businesses or Classifieds posts. `listing_type`
    decides which product the rows belong to and is stamped on every document,
    so the two can never mix."""
    import openpyxl
    from utils.classified_bulk import (
        columns_for, resolve_category, VALID_TYPES, LOCAL_FIND_PLANS,
    )
    from utils.shop_bulk import extract_row_images
    from utils.s3 import download_bytes

    if listing_type not in VALID_TYPES:
        raise HTTPException(status_code=400,
                            detail=f"listing_type must be one of {VALID_TYPES}")
    if not body.key:
        raise HTTPException(status_code=400, detail="Missing uploaded file key.")
    try:
        raw = download_bytes(body.key)
    except Exception as e:
        raise HTTPException(status_code=400,
                            detail=f"Could not read the uploaded file from storage: {e}")
    try:
        wb = openpyxl.load_workbook(io.BytesIO(raw), data_only=True)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Could not read Excel file: {e}")

    is_lf = listing_type == "local_find"
    sheet = "Local Finds" if is_lf else "Classifieds"
    ws = wb[sheet] if sheet in wb.sheetnames else wb.worksheets[0]
    columns = columns_for(listing_type)
    cell = _bulk_cell_reader(ws, columns)
    img_index = _build_image_index(body.images)   # 1st: uploaded-first photos
    pasted = extract_row_images(raw)              # 2nd: pasted into the sheet
    cat_pool = await _category_pool(listing_type) # 3rd: this product's pools

    if replace:
        # Scoped to this product AND to bulk rows only — never deletes a
        # user's own listing, and never the other product's rows.
        await _classifieds_collection.delete_many(
            {"source": "bulk", "listing_type": listing_type})

    errors, inserted, updated = [], 0, 0
    seen_any = False

    for r in range(2, ws.max_row + 1):
        row = [c.value for c in ws[r]]
        title_field = "business_name" if is_lf else "title"
        title = str(cell(row, title_field) or "").strip()
        if not title:
            continue
        seen_any = True

        cat = resolve_category(cell(row, "category"), listing_type)
        if not cat:
            errors.append({"row": r, "name": title,
                           "error": "Unknown category for this product — pick one from the dropdown."})
            continue

        phone = str(cell(row, "user_phone") or "").strip()
        if not phone:
            errors.append({"row": r, "name": title,
                           "error": "Missing phone — it identifies the row on re-upload."})
            continue

        lat, lng = _num(cell(row, "latitude")), _num(cell(row, "longitude"))

        doc = {
            "user_id": f"bulk:{listing_type}:{phone}",
            "user_name": title,
            "user_phone": phone,
            "category": cat,
            "subcategory": str(cell(row, "subcategory") or "").strip(),
            "description": str(cell(row, "description") or "").strip(),
            "state": str(cell(row, "state") or "").strip(),
            "district": str(cell(row, "district") or "").strip(),
            "city": str(cell(row, "city") or "").strip(),
            "area": str(cell(row, "area") or "").strip(),
            "pincode": str(cell(row, "pincode") or "").strip(),
            "address": str(cell(row, "address") or "").strip(),
            "country": "India",
            "latitude": lat,
            "longitude": lng,
            # The field that keeps the two products apart. Never omit it.
            "listing_type": listing_type,
            "is_available": True,
            "source": "bulk",
            "updated_at": datetime.now(timezone.utc),
        }

        if is_lf:
            plan = str(cell(row, "plan") or "free").strip().lower()
            if plan not in LOCAL_FIND_PLANS:
                plan = "free"
            doc.update({
                "business_name": title,
                "title": title,
                "plan": plan,
                "whatsapp": str(cell(row, "whatsapp") or "").strip(),
                "email": str(cell(row, "email") or "").strip(),
                "website": str(cell(row, "website") or "").strip(),
                "price": 0.0,
                "years_of_exp": 0,
            })
        else:
            doc.update({
                "title": title,
                "business_name": "",
                "price": float(_num(cell(row, "price")) or 0),
                "years_of_exp": int(_num(cell(row, "years_of_exp")) or 0),
            })

        # Photo: named file → pasted picture → this category's pool.
        named = str(cell(row, "image") or "").strip()
        key = _match_image(named, img_index)
        if not key:
            # Folder named after the product, so Local Finds and Classifieds
            # photos never share an S3 prefix.
            key = await _upload_row_image(pasted.get(r), f"{listing_type}/images")
        if not key:
            _pool = cat_pool.get(cat)
            if _pool:
                key = random.choice(_pool)
        if key:
            doc["photos"] = [key]
        if named and not _match_image(named, img_index):
            errors.append({"row": r, "name": title,
                           "error": f"Photo '{named}' wasn't among the uploaded images"
                                    + (" — used a category image instead." if key
                                       else " — row saved without a photo.")})

        # Identity = product + phone + title, so re-uploading a corrected sheet
        # updates rather than duplicating.
        match = {
            "source": "bulk",
            "listing_type": listing_type,
            "user_phone": phone,
            "title": title,
        }
        existing = await _classifieds_collection.find_one(match)
        # ── Coordinates for the app's 5 km search ────────────────────────────
        # latitude/longitude in the sheet are not enough on their own:
        # $geoNear only sees a GeoJSON `geo` field. Without this, every Local
        # Find and Classified uploaded here was stored with a position it could
        # never be found by — present in the database, invisible in the app.
        #
        # Falls back to the PIN code centre, which most sheets have even when
        # the latitude column is empty.
        _glat, _glng = lat, lng
        if _glat is None or _glng is None:
            _pin = "".join(ch for ch in str(doc.get("pincode") or "") if ch.isdigit())
            if len(_pin) == 6:
                try:
                    centre = await app_db["pincode_centres"].find_one({"_id": _pin})
                    if centre:
                        _glat = float(centre.get("lat"))
                        _glng = float(centre.get("lng"))
                except Exception:
                    pass
        try:
            if _glat is not None and _glng is not None:
                _la, _lo = float(_glat), float(_glng)
                if -90 <= _la <= 90 and -180 <= _lo <= 180 and not (_la == 0 and _lo == 0):
                    doc["lat"] = _la
                    doc["lng"] = _lo
                    # [lng, lat] — reversed puts Indian listings in the ocean.
                    doc["geo"] = {"type": "Point", "coordinates": [_lo, _la]}
        except (TypeError, ValueError):
            pass    # unlocated is survivable; failing the whole upload is not

        if existing:
            await _classifieds_collection.update_one({"_id": existing["_id"]}, {"$set": doc})
            updated += 1
        else:
            doc.setdefault("photos", [])
            doc["created_at"] = datetime.now(timezone.utc)
            await _classifieds_collection.insert_one(doc)
            inserted += 1

    return {
        "ok": True,
        "listing_type": listing_type,
        "replaced": replace,
        "inserted": inserted,
        "updated": updated,
        "skipped_empty": not seen_any,
        "errors": errors,
    }


# ─── Category images ──────────────────────────────────────────
# Admin uploads up to 15 images per shop category (ids 1-20). Shops with no own
# photo show a random image from their first category's pool (see app_shops.py).
_CATEGORY_NAMES = {
    1: "Supermarkets", 2: "Fruits & Vegetables", 3: "Pharmacies", 4: "Restaurants",
    5: "Cafes", 6: "Bakery & Sweets", 7: "Juices & Shakes", 8: "Garments",
    9: "Fashion", 10: "Footwear", 11: "Mobile", 12: "Electronics", 13: "Salons",
    14: "Beauty Parlours", 15: "Dry Fruits & Nuts", 16: "Fashion Accessories",
    17: "Optical", 18: "Home Appliances", 19: "Furniture", 20: "Home Furnishing",
    21: "Baby Stores", 22: "Books & Stationery", 23: "Gifts & Fancy Stores",
    24: "Toys & Games", 25: "Sports & Fitness", 26: "Diagnostic Centres",
    27: "Hospitals", 28: "Photography & Studios", 29: "Pet Stores",
    30: "Training Institutes", 31: "Online Stores",
}
_MAX_CATEGORY_IMAGES = 15


@router.get("/category-images")
async def list_category_images(_admin=Depends(get_current_admin)):
    """The 20 categories, each with its stored image keys + presigned URLs."""
    docs = {d["category_id"]: d async for d in category_images_collection.find()}
    out = []
    for cid, name in _CATEGORY_NAMES.items():
        keys = (docs.get(cid) or {}).get("keys", [])
        out.append({
            "category_id": cid,
            "name": name,
            "keys": keys,
            "urls": [_presign(k) or "" for k in keys],
        })
    return {"categories": out}


class CategoryImagesPut(BaseModel):
    keys: list = []


@router.put("/category-images/{category_id}")
async def set_category_images(
    category_id: int, body: CategoryImagesPut, _admin=Depends(get_current_admin)
):
    """Replace a category's image pool (already-uploaded S3 keys, max 15)."""
    if category_id not in _CATEGORY_NAMES:
        raise HTTPException(status_code=400, detail="Unknown category id")
    keys = [k for k in body.keys if isinstance(k, str) and k][:_MAX_CATEGORY_IMAGES]
    # Delete from S3 any image that was in the old pool but isn't in the new
    # one (this is how the admin UI removes a single image — it PUTs the
    # pool back minus that key).
    existing = await category_images_collection.find_one({"category_id": category_id})
    old_keys = set((existing or {}).get("keys") or [])
    for removed_key in old_keys - set(keys):
        await _s3_delete(removed_key)
    await category_images_collection.update_one(
        {"category_id": category_id},
        {"$set": {"category_id": category_id, "keys": keys}},
        upsert=True,
    )
    return {"ok": True, "category_id": category_id, "count": len(keys),
            "urls": [_presign(k) or "" for k in keys]}


# ─── Category images for Select / Local Finds / Classifieds ───────────────────
# Same idea as the shops pools above, but scoped per feature because their
# category ids are strings and their category sets differ. A listing with no
# photo of its own falls back to a random image from its category's pool.

@router.get("/feature-category-images")
async def list_feature_category_images(
    scope: str = Query("select", description="select | local_find | classified"),
    _admin=Depends(get_current_admin),
):
    """Every category in `scope`, each with its stored keys + presigned URLs."""
    cats = _scope_categories(scope)
    if not cats:
        raise HTTPException(status_code=400,
                            detail=f"scope must be one of {FEATURE_SCOPES}")
    docs = {d["category_id"]: d async for d in _feature_category_images.find({"scope": scope})}
    out = []
    for cid, label in cats.items():
        keys = (docs.get(cid) or {}).get("keys", [])
        out.append({
            "category_id": cid,
            "name": label,
            "keys": keys,
            "urls": [_presign(k) or "" for k in keys],
        })
    return {"scope": scope, "categories": out}


@router.put("/feature-category-images/{scope}/{category_id}")
async def set_feature_category_images(
    scope: str,
    category_id: str,
    body: CategoryImagesPut,
    _admin=Depends(get_current_admin),
):
    """Replace one category's image pool for one feature."""
    cats = _scope_categories(scope)
    if not cats:
        raise HTTPException(status_code=400,
                            detail=f"scope must be one of {FEATURE_SCOPES}")
    if category_id not in cats:
        raise HTTPException(status_code=400,
                            detail=f"Unknown category '{category_id}' for scope '{scope}'")

    keys = [k for k in body.keys if isinstance(k, str) and k][:_MAX_CATEGORY_IMAGES]
    # Same removal semantics as the shops pools: anything dropped from the pool
    # is deleted from S3, so removing an image in the UI doesn't orphan a file.
    existing = await _feature_category_images.find_one(
        {"scope": scope, "category_id": category_id})
    old_keys = set((existing or {}).get("keys") or [])
    for removed_key in old_keys - set(keys):
        await _s3_delete(removed_key)

    await _feature_category_images.update_one(
        {"scope": scope, "category_id": category_id},
        {"$set": {"scope": scope, "category_id": category_id, "keys": keys}},
        upsert=True,
    )
    return {"ok": True, "scope": scope, "category_id": category_id,
            "count": len(keys), "urls": [_presign(k) or "" for k in keys]}


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


# ─── Learn Claimit (question + how-to video lessons) ──────────
# Admin adds a question + uploads a video (S3, via /admin/presign-upload,
# folder="learn-claimit"); the Flutter app's "Learn Claimit" zone shows the
# question list, then plays the matching video with sound + a like button.
# Stored in claimit_db.learn_content — the SAME database the app backend
# (fastapi/backend) reads from directly, so no extra sync step is needed.

class LearnCreateRequest(BaseModel):
    question: str
    video_key: str


def _serialize_learn(doc: dict) -> dict:
    out = _serialize(doc)
    video_key = out.pop("video_s3_key", None) or ""
    out["video_url"] = (_video_presign(video_key) or "") if video_key else ""
    out.pop("liked_by", None)
    out["like_count"] = len(doc.get("liked_by", []))
    return out


@router.get("/learn")
async def list_learn_items(_admin=Depends(get_current_admin)):
    docs = await app_learn_collection.find().sort("created_at", -1).to_list(500)
    return [_serialize_learn(d) for d in docs]


@router.post("/learn")
async def create_learn_item(body: LearnCreateRequest, _admin=Depends(get_current_admin)):
    question = body.question.strip()
    if not question:
        raise HTTPException(status_code=400, detail="Question is required")
    if not body.video_key.strip():
        raise HTTPException(status_code=400, detail="Video is required")
    doc = {
        "question": question,
        "video_s3_key": body.video_key.strip(),
        "liked_by": [],
        "created_at": datetime.utcnow(),
    }
    res = await app_learn_collection.insert_one(doc)
    doc["_id"] = res.inserted_id
    return _serialize_learn(doc)


@router.delete("/learn/{item_id}")
async def delete_learn_item(item_id: str, _admin=Depends(get_current_admin)):
    doc = await app_learn_collection.find_one({"_id": _id(item_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Learn item not found")
    video_key = doc.get("video_s3_key") or ""
    if video_key:
        await _s3_delete(video_key)  # best-effort — never blocks the DB delete
    await app_learn_collection.delete_one({"_id": doc["_id"]})
    return {"ok": True}


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
        "image_url":     _public_url(r.get("image_s3_key")) if r.get("image_s3_key") else None,
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

    # Prefer the dup_key stored at submission time (POST /bill/manual-review
    # computes it from the raw request). Fall back to reconstructing it here
    # for reviews submitted before that field existed, so old pending
    # reviews don't crash — just skip dedup registration if we truly can't
    # build a key (no shop/date on record).
    review_dup_key = review.get("dup_key")
    if not review_dup_key:
        _bd = review.get("bill_date")
        _bd_str = _bd.strftime("%Y-%m-%d") if hasattr(_bd, "strftime") else (str(_bd) if _bd else None)
        review_dup_key = (
            _dup_key(shop_name, _bd_str, amount, review.get("bill_time"))
            if _bd_str else f"review|{review_id}"
        )

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
            "user_id": uid, "dup_key": review_dup_key,
            "shop_name": shop_name, "total_amount": round(amount, 2),
            "earned_cashback": cb, "earned_points": pts,
            "discount_percent": discount_pct, "discount_value": discount_value,
            "deducted_points": deducted_points,
            "source": "manual_review", "review_id": review_id, "scanned_at": now,
        })
        # Permanent history record — this is the ONLY collection the app's
        # profile history (GET /bill/history) and the shop owner's web
        # dashboard (GET /shop/bill-scans) read from. bill_scans above is
        # kept only for dup-detection/audit; without this insert, an
        # approved manual review never showed up in either place even
        # though the wallet credit + push notification both worked.
        await app_db["bill_history"].insert_one({
            "user_id": uid,
            "dup_key": review_dup_key,
            "scan_type": "redeem" if discount_pct else "reward",
            "shop_name": shop_name,
            "shop_id": str(shop_id) if shop_id else None,
            "total_amount": round(amount, 2),
            "earned_cashback": cb, "earned_points": pts,
            "discount_percent": discount_pct, "discount_value": discount_value,
            "deducted_points": deducted_points,
            "bill_number": review.get("bill_number"),
            "bill_date": review.get("bill_date"),
            "bill_time": review.get("bill_time"),
            "source": "manual_review", "review_id": review_id,
            "scanned_at": now,
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


# ── Claimit Privilege ─────────────────────────────────────────────────────────
# Partners live in claimit_db.privilege_partners, which the APP backend reads
# directly — so anything written here is live in the app immediately, with no
# mirroring step. Passes (privilege_passes) are written by the app and only
# read here, which is what makes the approval log trustworthy as an audit
# trail: admin never writes to it.

from utils.privilege_bulk import (
    build_template as _priv_template,
    parse_sheet as _priv_parse,
    CATEGORY_IDS as _PRIV_CATEGORY_IDS,
    CATEGORY_LABELS as _PRIV_CATEGORY_LABELS,
)


class _PrivilegePartnerBody(_BM2):
    name: str
    category: str
    discount_percent: float = 0
    discount_label: str = ""
    about: str = ""
    privilege_details: str = ""
    terms: str = ""
    area: str = ""
    city: str = ""
    state: str = ""
    pincode: str = ""
    address: str = ""
    phone: str = ""
    status: str = "active"
    photo_s3_keys: list = []


def _priv_serialize(doc: dict) -> dict:
    return {
        "id": str(doc.get("_id", "")),
        "name": doc.get("name", ""),
        "category": doc.get("category", ""),
        "category_label": doc.get("category_label")
                          or _PRIV_CATEGORY_LABELS.get(doc.get("category", ""), ""),
        "discount_percent": float(doc.get("discount_percent") or 0),
        "discount_label": doc.get("discount_label", ""),
        "about": doc.get("about", ""),
        "privilege_details": doc.get("privilege_details", ""),
        "terms": doc.get("terms", ""),
        "area": doc.get("area", ""),
        "city": doc.get("city", ""),
        "state": doc.get("state", ""),
        "pincode": doc.get("pincode", ""),
        "address": doc.get("address", ""),
        "phone": doc.get("phone", ""),
        "status": doc.get("status", "active"),
        "created_by": doc.get("created_by", ""),
        "located": bool(doc.get("geo")),
        "photo_s3_keys": doc.get("photo_s3_keys") or [],
    }


@router.get("/privilege/categories")
async def privilege_categories(_admin=Depends(get_current_admin)):
    """The nine fixed ids, for the create/edit dropdown."""
    return {"categories": [{"id": cid, "label": _PRIV_CATEGORY_LABELS[cid]}
                           for cid in _PRIV_CATEGORY_IDS]}


@router.get("/privilege/partners")
async def privilege_list(
    status: Optional[str] = Query(None, description="active | pending | disabled"),
    category: Optional[str] = Query(None),
    city: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    _admin=Depends(get_current_admin),
):
    q: dict = {}
    if status:
        q["status"] = status
    if category:
        q["category"] = category
    # Local import: this module has no module-level `re`.
    import re as _re
    if city:
        q["city"] = {"$regex": f"^{_re.escape(city)}", "$options": "i"}
    if search:
        q["name"] = {"$regex": _re.escape(search), "$options": "i"}

    docs = await (app_db["privilege_partners"].find(q)
                  .sort("created_at", -1).to_list(1000))
    items = [_priv_serialize(d) for d in docs]
    return {
        "partners": items,
        "total": len(items),
        # How many can't be found in the app because they have no position.
        # Surfaced rather than buried: an unlocated partner is invisible.
        "unlocated": sum(1 for i in items if not i["located"]),
    }


@router.post("/privilege/partners")
async def privilege_create(
    body: _PrivilegePartnerBody,
    _admin=Depends(get_current_admin),
):
    if body.category not in _PRIV_CATEGORY_IDS:
        raise HTTPException(status_code=400, detail="Unknown category")
    if not body.name.strip():
        raise HTTPException(status_code=400, detail="Name is required")

    doc = body.dict()
    doc["name"] = body.name.strip()
    doc["category_label"] = _PRIV_CATEGORY_LABELS[body.category]
    doc["created_at"] = datetime.utcnow()
    doc["created_by"] = "admin"

    # Coordinates from the pincode, or this partner never appears in the app.
    lat, lng, geo = await resolve_point_for_ad(app_db, pincode=body.pincode)
    if geo:
        doc.update({"lat": lat, "lng": lng, "geo": geo})

    res = await app_db["privilege_partners"].insert_one(doc)
    doc["_id"] = res.inserted_id
    return {"partner": _priv_serialize(doc), "located": bool(geo)}


@router.put("/privilege/partners/{partner_id}")
async def privilege_update(
    partner_id: str,
    body: _PrivilegePartnerBody,
    _admin=Depends(get_current_admin),
):
    if body.category not in _PRIV_CATEGORY_IDS:
        raise HTTPException(status_code=400, detail="Unknown category")

    update = body.dict()
    update["category_label"] = _PRIV_CATEGORY_LABELS[body.category]
    update["updated_at"] = datetime.utcnow()

    # Re-resolve on every save: correcting a wrong pincode is all an admin
    # should have to do to make a partner visible again.
    lat, lng, geo = await resolve_point_for_ad(app_db, pincode=body.pincode)
    if geo:
        update.update({"lat": lat, "lng": lng, "geo": geo})

    res = await app_db["privilege_partners"].update_one(
        {"_id": _id(partner_id)}, {"$set": update})
    if not res.matched_count:
        raise HTTPException(status_code=404, detail="Partner not found")
    return {"ok": True, "located": bool(geo)}


@router.delete("/privilege/partners/{partner_id}")
async def privilege_delete(partner_id: str, _admin=Depends(get_current_admin)):
    res = await app_db["privilege_partners"].delete_one({"_id": _id(partner_id)})
    if not res.deleted_count:
        raise HTTPException(status_code=404, detail="Partner not found")
    return {"ok": True}


@router.get("/privilege/bulk-template")
async def privilege_bulk_template(_admin=Depends(get_current_admin)):
    # StreamingResponse, not Response — `Response` is not imported in this
    # module, and every other template download here uses this same shape.
    return StreamingResponse(
        io.BytesIO(_priv_template()),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={
            "Content-Disposition":
                'attachment; filename="Claimit_Privilege_Template.xlsx"',
            "Cache-Control": "no-store, must-revalidate",
        },
    )


@router.post("/privilege/bulk-upload")
async def privilege_bulk_upload(
    body: BulkUploadBody,
    replace: bool = Query(False, description="Wipe all partners before inserting"),
    _admin=Depends(get_current_admin),
):
    """Parse a workbook the browser already PUT to S3 and insert the rows.

    Sent as an S3 key rather than a multipart POST because CloudFront blocks
    multipart file uploads with a 403 — the same pattern every other importer
    here uses.
    """
    from utils.s3 import download_bytes
    data = download_bytes(body.key)
    if not data:
        raise HTTPException(status_code=400, detail="Could not read the uploaded file")

    try:
        partners, rejected, summary = _priv_parse(data)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    if replace:
        await app_db["privilege_partners"].delete_many({})

    inserted, failed = 0, list(rejected)
    for p in partners:
        row = p.pop("_row", None)
        image_name = p.pop("image", "")
        doc = dict(p)
        doc["status"] = "active"
        doc["created_at"] = datetime.utcnow()
        doc["created_by"] = "admin-bulk"

        if image_name and body.images.get(image_name):
            doc["photo_s3_keys"] = [body.images[image_name]]

        # Resolve the pincode to a point. The parser already guaranteed six
        # digits; this can still fail if the pincode isn't a real one, and a
        # partner with no position is invisible, so it is reported not hidden.
        try:
            lat, lng, geo = await resolve_point_for_ad(app_db, pincode=doc.get("pincode", ""))
            if geo:
                doc.update({"lat": lat, "lng": lng, "geo": geo})
        except Exception:
            geo = None

        try:
            await app_db["privilege_partners"].insert_one(doc)
            inserted += 1
            if not geo:
                failed.append({
                    "row": row, "name": doc.get("name", ""),
                    "reason": "Saved, but the pincode could not be placed on the "
                              "map — this partner will not appear in the app "
                              "until it is corrected."})
        except Exception as e:
            failed.append({"row": row, "name": doc.get("name", ""),
                           "reason": f"Could not save: {e}"})

    return {**summary, "inserted": inserted, "issues": failed}


@router.get("/privilege/history")
async def privilege_history(
    limit: int = Query(200, le=500),
    skip: int = Query(0, ge=0),
    _admin=Depends(get_current_admin),
):
    """Every approved discount, newest first — the audit trail.

    Read-only on purpose. The value of this log is that admin cannot edit it,
    so a shop disputing a discount can be checked against what the app
    actually recorded at the time.
    """
    q = {"status": "approved"}
    docs = await (app_db["privilege_passes"].find(q)
                  .sort("approved_at", -1)
                  .skip(skip).limit(limit).to_list(limit))
    total = await app_db["privilege_passes"].count_documents(q)
    return {
        "history": [{
            "reference":        d.get("reference", ""),
            "user_name":        d.get("user_name", ""),
            "user_phone":       d.get("user_phone", ""),
            "partner_name":     d.get("partner_name", ""),
            "partner_area":     d.get("partner_area", ""),
            "partner_city":     d.get("partner_city", ""),
            "discount_percent": float(d.get("discount_percent") or 0),
            "discount_label":   d.get("discount_label", ""),
            "issued_at":        d.get("issued_at").isoformat() if d.get("issued_at") else "",
            "approved_at":      d.get("approved_at").isoformat() if d.get("approved_at") else "",
        } for d in docs],
        "total": total,
        "skip": skip,
    }


# ── App config: bill scan reward rates ────────────────────────────────────────
# What a user earns for scanning a bill. These were hard-coded in the app
# backend (1 % cashback, 10 % points), so changing the offer meant editing code
# and redeploying. They now live in app_config {"key": "bill_rates"}, which
# routes/bill.py reads on every scan — a change here applies to the next scan
# with no restart.

# Hard ceiling on cashback, mirrored in routes/bill.py. Enforced in both
# places so a value written straight into Mongo still can't over-pay.
MAX_CASHBACK_PERCENT = 5.0


class _BillTier(_BM2):
    min_scans:        int
    cashback_percent: float


class _BillRatesBody(_BM2):
    cashback_percent: float
    points_percent:   float
    # The monthly scan-count ladder. Omitted by an older admin build, in which
    # case the stored tiers are left exactly as they are rather than wiped.
    # Built-in generic rather than typing.List, which this module doesn't
    # import. Keeps per-row validation: pydantic coerces each entry to
    # _BillTier, so a malformed row is rejected before it reaches Mongo.
    tiers: Optional[list[_BillTier]] = None


def _default_tiers(base: float) -> list:
    """Starting ladder, derived from the base rate so switching this on can
    never reduce anyone's cashback (a hard-coded 1% first tier would drop an
    admin who had already moved the base to 2%)."""
    return [
        {"min_scans": 0,  "cashback_percent": base},
        {"min_scans": 15, "cashback_percent": min(base + 1, MAX_CASHBACK_PERCENT)},
        {"min_scans": 50, "cashback_percent": min(base + 2, MAX_CASHBACK_PERCENT)},
    ]


@router.get("/bill-rates")
async def get_bill_rates(_admin=Depends(get_current_admin)):
    """Current bill-scan reward rates, with the launch defaults as fallback."""
    cfg = await app_db["app_config"].find_one({"key": "bill_rates"}) or {}
    base = float(cfg.get("cashback_percent", 1.0))
    tiers = cfg.get("tiers") or _default_tiers(base)
    return {
        "cashback_percent": base,
        "points_percent":   float(cfg.get("points_percent", 10.0)),
        "tiers":            tiers,
        "max_cashback_percent": MAX_CASHBACK_PERCENT,
    }


@router.put("/bill-rates")
async def update_bill_rates(body: _BillRatesBody, _admin=Depends(get_current_admin)):
    """Set the reward rates and the monthly tier ladder.

    Applies to every scan from the moment it saves. Zero is allowed — that is
    how an offer gets switched off. Negative is not: it would debit the user
    for shopping. Cashback is capped at 5%; a typo like 20 for 2 would
    otherwise pay ten times the intended amount on every bill until somebody
    noticed the wallet totals.
    """
    if body.cashback_percent < 0:
        raise HTTPException(status_code=400, detail="Cashback % cannot be negative")
    if body.cashback_percent > MAX_CASHBACK_PERCENT:
        raise HTTPException(
            status_code=400,
            detail=f"Cashback % cannot exceed {MAX_CASHBACK_PERCENT:g}%")
    if body.points_percent < 0:
        raise HTTPException(status_code=400, detail="Points % cannot be negative")
    if body.points_percent > 100:
        raise HTTPException(status_code=400, detail="Points % cannot exceed 100")

    update = {
        "key":              "bill_rates",
        "cashback_percent": float(body.cashback_percent),
        "points_percent":   float(body.points_percent),
        "updated_at":       datetime.utcnow(),
    }

    if body.tiers is not None:
        seen = set()
        clean = []
        for t in body.tiers:
            if t.min_scans < 0:
                raise HTTPException(status_code=400,
                                    detail="Tier scan count cannot be negative")
            if t.cashback_percent < 0:
                raise HTTPException(status_code=400,
                                    detail="Tier cashback % cannot be negative")
            if t.cashback_percent > MAX_CASHBACK_PERCENT:
                raise HTTPException(
                    status_code=400,
                    detail=f"Tier cashback % cannot exceed {MAX_CASHBACK_PERCENT:g}%")
            # Two tiers starting at the same scan count is ambiguous — one of
            # them would silently never apply.
            if t.min_scans in seen:
                raise HTTPException(
                    status_code=400,
                    detail=f"Two tiers both start at {t.min_scans} scans")
            seen.add(t.min_scans)
            clean.append({"min_scans": int(t.min_scans),
                          "cashback_percent": float(t.cashback_percent)})

        clean.sort(key=lambda t: t["min_scans"])
        if not clean or clean[0]["min_scans"] != 0:
            raise HTTPException(
                status_code=400,
                detail="The first tier must start at 0 scans, otherwise a new "
                       "user matches no tier and earns nothing.")
        # A ladder that goes DOWN would cut a loyal user's rate for using the
        # app more, which is the opposite of the point.
        for a, b in zip(clean, clean[1:]):
            if b["cashback_percent"] < a["cashback_percent"]:
                raise HTTPException(
                    status_code=400,
                    detail=f"Tier at {b['min_scans']} scans pays less than the "
                           f"tier below it — higher tiers must not pay less.")
        update["tiers"] = clean

    await app_db["app_config"].update_one(
        {"key": "bill_rates"}, {"$set": update}, upsert=True,
    )
    return {"ok": True, **{k: v for k, v in update.items() if k != "key"}}


# ── App config: Premium ad slot caps (Nearby Deals + Brand Deals) ─────────────

class _AdSettingsBody(_BM2):
    max_nearby: int
    max_brand:  int


@router.get("/ad-settings")
async def get_ad_settings(_admin=Depends(get_current_admin)):
    """Return current Premium slot caps. Nearby Deals caps are per-location
    (each pincode gets its own pool of max_nearby slots); Brand Deals caps
    are global (one shared pool of max_brand slots, not location filtered)."""
    cfg = await app_db["app_config"].find_one({"key": "premium_slots"})
    return {
        "max_nearby": int(cfg.get("max_nearby", 3)) if cfg else 3,
        "max_brand":  int(cfg.get("max_brand", 3)) if cfg else 3,
    }


@router.put("/ad-settings")
async def update_ad_settings(body: _AdSettingsBody, _admin=Depends(get_current_admin)):
    """Upsert Premium slot caps. Takes effect immediately for every new ad
    booking (existing booked ads are unaffected)."""
    if body.max_nearby < 0 or body.max_brand < 0:
        raise HTTPException(status_code=400, detail="Values must be >= 0")
    await app_db["app_config"].update_one(
        {"key": "premium_slots"},
        {"$set": {
            "key":        "premium_slots",
            "max_nearby": body.max_nearby,
            "max_brand":  body.max_brand,
            "updated_at": datetime.utcnow(),
        }},
        upsert=True,
    )
    return {"ok": True, "max_nearby": body.max_nearby, "max_brand": body.max_brand}


# ── App config: every price charged across the app (shop, ads, Local Finds) ──
# Single source of truth — see utils/pricing.py. Editing a value here takes
# effect immediately on the next order/registration; already-paid records
# are unaffected (their amount is stored on the record itself).

from utils.pricing import DEFAULT_PRICING as _DEFAULT_PRICING, get_pricing as _get_pricing


class _PricingBody(_BM2):
    shop_premium: Optional[int] = None
    shop_standard: Optional[int] = None
    shop_annual_renewal: Optional[int] = None
    ad_home_banner: Optional[int] = None
    ad_nearby_deals_premium: Optional[int] = None
    ad_nearby_deals_standard: Optional[int] = None
    ad_brand_deals_premium: Optional[int] = None
    ad_brand_deals_standard: Optional[int] = None
    ad_promo_reelz_premium: Optional[int] = None
    ad_promo_reelz_standard: Optional[int] = None
    local_finds_standard: Optional[int] = None
    local_finds_premium: Optional[int] = None
    select_premium: Optional[int] = None
    select_standard: Optional[int] = None


@router.get("/pricing")
async def get_pricing_settings(_admin=Depends(get_current_admin)):
    """Current value of every price in the app."""
    return await _get_pricing()


@router.put("/pricing")
async def update_pricing_settings(body: _PricingBody, _admin=Depends(get_current_admin)):
    """Upsert only the fields that were provided. Every value must be >= 0."""
    update = {k: v for k, v in body.dict().items() if v is not None}
    if not update:
        return await _get_pricing()
    for k, v in update.items():
        if v < 0:
            raise HTTPException(status_code=400, detail=f"{k} must be >= 0")
    update["key"] = "pricing"
    update["updated_at"] = datetime.utcnow()
    await app_db["app_config"].update_one(
        {"key": "pricing"},
        {"$set": update},
        upsert=True,
    )
    return await _get_pricing()


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


# ═══════════════════════════════════════════════════════════════════════════
# Admin ad creation — lets an admin publish the same 4 ad types as advertisers
# but WITHOUT any payment. Completely separate from the advertiser flow
# (routers/advertiser.py is untouched); it just reuses the same S3 upload +
# app-facing collections so admin-created ads appear in the app exactly like
# paid ones.
# ═══════════════════════════════════════════════════════════════════════════

# List prices (weekly, GST-incl.) — stored on the ad only for record-keeping;
# no money is charged for admin-created ads.
_ADMIN_AD_PRICES = {
    "home_banner":  {"standard": 700},
    "nearby_deals": {"premium": 1050, "standard": 700},
    "brand_deals":  {"premium": 700,  "standard": 700},
    "promo_reelz":  {"premium": 700,  "standard": 700},
}
_ADMIN_VIDEO_EXTS = (".mp4", ".mov", ".m4v", ".webm")


async def _admin_ad_price(ad_type: str, tier: str) -> int:
    """Same admin-configured pricing source as routers/advertiser.py's
    _ad_price — even though no money is charged for admin-created ads, the
    stored `amount` is used for revenue record-keeping, so it must always
    match the real (current) price rather than a stale hardcoded one."""
    from utils.pricing import get_pricing
    pricing = await get_pricing()
    if ad_type == "home_banner":
        return pricing["ad_home_banner"]
    key = f"ad_{ad_type}_{tier}"
    if key in pricing:
        return pricing[key]
    tiers = _ADMIN_AD_PRICES.get(ad_type, {})
    return tiers.get(tier) or tiers.get("standard") or next(iter(tiers.values()), 700)


def _admin_is_video_key(key: str) -> bool:
    return bool(key) and key.lower().endswith(_ADMIN_VIDEO_EXTS)


class AdminPresignRequest(BaseModel):
    filename: str
    content_type: str
    folder: str = "ads"


@router.post("/presign-upload")
async def admin_presign_upload(body: AdminPresignRequest, _admin=Depends(get_current_admin)):
    """Admin-only presigned S3 upload URL (same as advertiser presign, but
    behind the admin token). Browser PUTs the file directly to S3."""
    _DOC_TYPES = {
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",  # .xlsx
        "application/vnd.ms-excel",                                           # .xls
        "application/octet-stream",                                           # fallback
    }
    is_video = body.content_type in ALLOWED_VIDEO_TYPES
    is_image = body.content_type in ALLOWED_IMAGE_TYPES
    is_doc = body.content_type in _DOC_TYPES
    if not is_video and not is_image and not is_doc:
        raise HTTPException(status_code=400, detail=f"Unsupported type: {body.content_type}")
    return generate_presigned_upload_url(
        folder=body.folder,
        filename=body.filename,
        content_type=body.content_type,
        is_video=is_video,   # docs/images go to the main image bucket
    )


# ─── WhatsApp claim campaign ──────────────────────────────────────────────
# Admin uploads a sheet of shop numbers and sends them the approved
# "claim your business" template.
#
# The sending itself happens in the APP backend, because that is where the
# Twilio credentials live. Copying them here would double the number of places
# a secret can leak from, so this proxies over localhost with the shared admin
# key instead.

_APP_BACKEND = _os.getenv("APP_BACKEND_URL", "http://127.0.0.1:8001")
_APP_ADMIN_KEY = _os.getenv("ADMIN_SECRET", "claimit-admin-2024")
_CLAIM_TEMPLATE_SID = _os.getenv("TWILIO_CLAIM_TEMPLATE_SID", "")
# Second campaign: inviting ordinary users to download the app. Different
# template, different audience, different variables — so it gets its own SID
# and its own log name rather than sharing the shop-owner one.
_USER_TEMPLATE_SID = _os.getenv("TWILIO_USER_TEMPLATE_SID", "")

# One place defining each campaign, so the preview and the send can never
# disagree about which template or which log they are working with.
#
#   variables — the shape the app backend fills in:
#     "shop_name"      {{1}} = shop name
#     "new_user_bonus" {{1}} = cashback, {{2}} = reward points, both read from
#                      the SAME admin config the wallet is credited from, so
#                      the invite can't promise a figure the user won't get.
CAMPAIGNS = {
    "claim_business": {
        "label": "Shop owners — claim your business",
        "sid_env": "TWILIO_CLAIM_TEMPLATE_SID",
        "variables": "shop_name",
    },
    "user_attraction": {
        "label": "Users — download Claimit",
        "sid_env": "TWILIO_USER_TEMPLATE_SID",
        "variables": "new_user_bonus",
    },
}


def _campaign_sid(name: str) -> str:
    """The configured template SID for a campaign, read live from the env."""
    cfg = CAMPAIGNS.get(name)
    if not cfg:
        raise HTTPException(status_code=400, detail=f"Unknown campaign '{name}'")
    return _os.getenv(cfg["sid_env"], "")


@router.get("/whatsapp-campaign/types")
async def whatsapp_campaign_types(_admin=Depends(get_current_admin)):
    """The campaigns this server can run, and whether each is configured.

    `configured` false means the template SID env var is missing — the admin
    page disables Send rather than letting someone upload 600 numbers and hit
    a wall.
    """
    return {"campaigns": [
        {"id": k, "label": v["label"],
         "configured": bool(_os.getenv(v["sid_env"], "")),
         "env_var": v["sid_env"]}
        for k, v in CAMPAIGNS.items()
    ]}


@router.post("/whatsapp-campaign/preview")
async def whatsapp_campaign_preview(
    body: BulkUploadBody,
    campaign: str = Query("claim_business", description="claim_business | user_attraction"),
    _admin=Depends(get_current_admin),
):
    """Read the uploaded sheet and report what WOULD be sent.

    Takes an S3 key, not a file. CloudFront sits in front of this API and
    blocks multipart file POSTs with a 403 — so the browser PUTs the .xlsx
    straight to S3 with a presigned URL and sends only the key, the same way
    every other bulk upload here works.

    Nothing is sent from this endpoint. The admin sees the valid count, every
    rejected row with its reason, and the real message before any money is
    spent.
    """
    from utils.campaign_bulk import parse_campaign_sheet
    from utils.s3 import download_bytes

    if not body.key:
        raise HTTPException(status_code=400, detail="No file uploaded")
    try:
        data = download_bytes(body.key)
    except Exception as e:
        raise HTTPException(status_code=400,
                            detail=f"Could not read the uploaded file: {e}")
    try:
        recipients, rejected, summary = parse_campaign_sheet(data)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=400,
                            detail=f"Could not read that file: {e}")

    # Who has already been messaged, so the admin knows the real cost of
    # pressing send rather than the row count of the sheet.
    # Scoped to THIS campaign: someone messaged about claiming their shop has
    # not been invited to download the app, so the two runs must not suppress
    # each other.
    already = 0
    try:
        phones = {"+91" + r["phone"] for r in recipients}
        already = await app_db["whatsapp_campaign_log"].count_documents(
            {"campaign": campaign, "status": "sent",
             "phone": {"$in": list(phones)}})
    except Exception:
        pass

    sid = _campaign_sid(campaign)
    return {
        **summary,
        "campaign": campaign,
        "already_sent": already,
        "will_send": max(0, summary["valid"] - already),
        "template_sid": sid,
        "template_configured": bool(sid),
        "recipients": recipients[:200],   # enough to eyeball, not a huge payload
        # NOT capped. These are the rows that will not be messaged, each with
        # the reason — the admin has to see every one to fix the sheet, so
        # truncating them would hide exactly the information that matters.
        "rejected": rejected,
    }


class _CampaignSendBody(BaseModel):
    recipients: list          # [{phone, shop_name}, …] as returned by preview
    confirm: bool = False
    campaign: str = "claim_business"


@router.post("/whatsapp-campaign/send")
async def whatsapp_campaign_send(
    body: _CampaignSendBody,
    _admin=Depends(get_current_admin),
):
    """Actually send. Requires confirm=true so a stray click can't spend money."""
    if not body.confirm:
        raise HTTPException(status_code=400,
                            detail="confirm must be true to send")
    cfg = CAMPAIGNS.get(body.campaign)
    if not cfg:
        raise HTTPException(status_code=400,
                            detail=f"Unknown campaign '{body.campaign}'")
    sid = _campaign_sid(body.campaign)
    if not sid:
        raise HTTPException(
            status_code=400,
            detail=f"{cfg['sid_env']} is not set on the server.")
    if not body.recipients:
        raise HTTPException(status_code=400, detail="No recipients")

    import httpx
    payload = {
        "template_sid": sid,
        "campaign": body.campaign,
        # Tells the app backend what to put in the template's variables. For
        # the user invite it fills in the joining bonus from admin config;
        # nothing here comes from the uploaded sheet.
        "variables": cfg["variables"],
        "dry_run": False,
        "recipients": [
            {"phone": str(r.get("phone", "")),
             "shop_name": str(r.get("shop_name", ""))}
            for r in body.recipients
        ],
    }
    # Long timeout on purpose: sends are paced to avoid rate limits, so a few
    # hundred recipients legitimately takes minutes.
    try:
        async with httpx.AsyncClient(timeout=900) as c:
            r = await c.post(f"{_APP_BACKEND}/campaign/whatsapp",
                             json=payload,
                             headers={"X-Admin-Key": _APP_ADMIN_KEY})
            r.raise_for_status()
            return r.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=502,
                            detail=f"App backend refused: {e.response.text[:300]}")
    except Exception as e:
        raise HTTPException(status_code=502,
                            detail=f"Could not reach the app backend: {e}")


@router.get("/whatsapp-campaign/log")
async def whatsapp_campaign_log(
    campaign: str = Query("claim_business", description="claim_business | user_attraction"),
    _admin=Depends(get_current_admin),
):
    """How many have been messaged so far, and the most recent ones.

    Scoped to one campaign. The two runs have separate audiences, so a shared
    count would tell an admin nothing useful about either.
    """
    try:
        sent = await app_db["whatsapp_campaign_log"].count_documents(
            {"campaign": campaign, "status": "sent"})
        failed = await app_db["whatsapp_campaign_log"].count_documents(
            {"campaign": campaign, "status": "failed"})
        recent = await (app_db["whatsapp_campaign_log"]
                        .find({"campaign": campaign})
                        .sort("sent_at", -1).limit(50).to_list(50))
        for d in recent:
            d["_id"] = str(d["_id"])
            if isinstance(d.get("sent_at"), datetime):
                d["sent_at"] = d["sent_at"].isoformat()
        return {"sent": sent, "failed": failed, "recent": recent}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ─── Ad cycle (weekly Friday → Thursday window) ───────────────────────────
# All four ad types — Nearby Deals, Brand Deals, Home Banner and Promo Reelz —
# run in the same weekly slot. Admin owns which weekday that slot starts on.

class AdCyclePatch(BaseModel):
    start_weekday: int      # 0 = Monday … 4 = Friday … 6 = Sunday


@router.get("/ad-cycle")
async def admin_get_ad_cycle(_admin=Depends(get_current_admin)):
    """The configured cycle plus the exact window an ad booked now would run
    in, so admin can see the effect of the setting rather than infer it."""
    info = await cycle_info()
    return {
        **info,
        "weekday_options": [
            {"value": i, "label": name} for i, name in enumerate(WEEKDAY_NAMES)
        ],
    }


@router.put("/ad-cycle")
async def admin_set_ad_cycle(body: AdCyclePatch, _admin=Depends(get_current_admin)):
    """Move the cycle to a different weekday.

    Ads already booked keep the window they were sold, because their dates are
    stored on the document. Only ads created after this change use the new day.
    """
    if not (0 <= body.start_weekday <= 6):
        raise HTTPException(
            status_code=400,
            detail="start_weekday must be 0 (Monday) to 6 (Sunday).",
        )
    await app_db["app_config"].update_one(
        {"key": "ad_cycle"},
        {"$set": {"start_weekday": body.start_weekday,
                  "updated_at": datetime.utcnow()}},
        upsert=True,
    )
    return {"ok": True, **(await cycle_info())}


class AdminCreateAdRequest(BaseModel):
    ad_type: str
    tier: str = "standard"          # premium | standard (ignored for home_banner)
    pincode: str = "000000"
    publish_today: bool = True
    scheduled_date: Optional[str] = None
    # How long an admin-created ad runs. Advertisers always get "cycle" (the
    # paid Friday → Thursday week); only admin gets the other two.
    #   "cycle"  — next weekly cycle, exactly like a paid ad (default)
    #   "now"    — live this second, ends when the current cycle ends
    #   "always" — live this second, no end date, runs until admin stops it
    duration: str = "cycle"
    creative_key: Optional[str] = None
    thumbnail_key: Optional[str] = None
    # Home banner
    headline: Optional[str] = None
    sub: Optional[str] = None
    cta_link: Optional[str] = None
    # Promo reelz
    shop_name: Optional[str] = None
    shop_location: Optional[str] = None
    shop_category: Optional[str] = None
    caption: Optional[str] = None
    tag: Optional[str] = None
    # Deal
    name: Optional[str] = None
    location: Optional[str] = None
    description: Optional[str] = None
    address: Optional[str] = None
    phone: Optional[str] = None
    timing: Optional[str] = None
    type: Optional[str] = None
    cashback: Optional[str] = None
    distance: Optional[str] = None
    tags: Optional[str] = None
    offer: Optional[str] = None
    title: Optional[str] = None


@router.post("/ads/create")
async def admin_create_ad(body: AdminCreateAdRequest, _admin=Depends(get_current_admin)):
    """Create an ad as admin with NO payment. Mirrors the advertiser ad
    document + app-facing collections so it shows up in the app identically."""
    ad_type = body.ad_type
    tier    = (body.tier or "standard").strip().lower()
    if tier not in ("premium", "standard"):
        tier = "standard"
    amount = await _admin_ad_price(ad_type, tier)

    # An advertiser always buys the weekly Friday → Thursday cycle. Admin is
    # not selling anything, so admin gets three choices; `duration` says which.
    #
    #   "now"    — live this second. Waiting until Friday to show house content
    #              or a correction makes no sense, so this skips the cycle and
    #              still stops at the end of the current week.
    #   "always" — live this second with NO end date. `ad_window.is_live` in the
    #              app treats a missing end as "no limit", so this runs until an
    #              admin pauses it. Used for evergreen content.
    #   "cycle"  — unchanged default: the next paid week, so an admin ad
    #              competes for the same slot as a paid one.
    #
    # scheduled_date still wins when given, snapped onto the cycle it falls in
    # so the windows never overlap.
    mode = (body.duration or "cycle").strip().lower()
    if mode not in ("cycle", "now", "always"):
        mode = "cycle"

    now_ist = datetime.now(IST)
    if body.scheduled_date:
        try:
            requested = datetime.strptime(body.scheduled_date, "%Y-%m-%d").replace(tzinfo=IST)
        except ValueError:
            requested = now_ist
        pub_date, end_date = cycle_for(requested, await get_start_weekday())
    elif mode == "always":
        pub_date, end_date = now_ist, None
    elif mode == "now":
        # End of the week this moment falls in — not next Friday's week.
        _, end_date = cycle_for(now_ist, await get_start_weekday())
        pub_date = now_ist
    else:
        pub_date, end_date = await next_cycle()

    # "now" and "always" start in the past-tense sense of *right now*, so they
    # are active immediately; only a future cycle start is "scheduled".
    ad_status = "active" if is_live(pub_date) else "scheduled"

    # end_date is None only for "always". Every document below stores the
    # display string AND the real datetime; an empty string and a None both
    # read as "no end" to the app's is_live(), so nothing expires by accident.
    end_date_str = end_date.strftime("%d/%m/%Y") if end_date else ""

    creative_s3_key  = body.creative_key or ""
    thumbnail_s3_key = body.thumbnail_key or ""

    is_video = ad_type == "promo_reelz" or (
        ad_type == "home_banner" and _admin_is_video_key(creative_s3_key)
    )
    creative_url  = (_video_presign(creative_s3_key) if is_video else _presign(creative_s3_key)) if creative_s3_key else ""
    thumbnail_url = _presign(thumbnail_s3_key) if thumbnail_s3_key else ""

    parsed_tags: list = []
    if body.tags:
        try:
            parsed_tags = json.loads(body.tags)
        except Exception:
            parsed_tags = [t.strip() for t in body.tags.split(",") if t.strip()]

    ad_doc = {
        "user_id":      "admin",
        "created_by":   "admin",
        "ad_type":      ad_type,
        "tier":         tier,
        "pincode":      body.pincode,
        "publish_date": pub_date.strftime("%d/%m/%Y"),
        "end_date":     end_date_str,
        # Real datetimes beside the display strings — a "dd/mm/yyyy" string
        # compared against a date in MongoDB silently matches everything.
        "publish_at":   pub_date,
        "ends_at":      end_date,
        "duration":     mode,
        "never_expires": end_date is None,
        "amount":       amount,
        "status":       ad_status,
        "payment_link_id": "ADMIN_FREE",
        "views":        0,
        "clicks":       0,
        "created_at":   datetime.utcnow(),
    }

    if ad_type == "home_banner":
        ad_doc.update({
            "headline":     body.headline or body.title or "",
            "sub":          body.sub or body.description or "",
            "cta_link":     body.cta_link or "",
            "media_type":   "video" if is_video else "image",
            "image_s3_key": "" if is_video else creative_s3_key,
            "image_url":    "" if is_video else creative_url,
            "video_s3_key": creative_s3_key if is_video else "",
            "video_url":    creative_url if is_video else "",
            "title":        body.headline or body.title or "",
        })
    elif ad_type == "promo_reelz":
        ad_doc.update({
            "shop_name":        body.shop_name or "",
            "shop_location":    body.shop_location or "",
            "shop_category":    body.shop_category or "",
            "caption":          body.caption or "",
            "offer":            body.offer or "",
            "tag":              body.tag or "",
            "video_s3_key":     creative_s3_key,
            "video_url":        creative_url,
            "thumbnail_s3_key": thumbnail_s3_key,
            "thumbnail_url":    thumbnail_url,
            "title":            body.shop_name or "",
        })
    elif ad_type in ("brand_deals", "nearby_deals"):
        ad_doc.update({
            "name":         body.name or "",
            "location":     body.location or "",
            "offer":        body.offer or "",
            "description":  body.description or "",
            "address":      body.address or "",
            "phone":        body.phone or "",
            "timing":       body.timing or "",
            "type":         body.type or "",
            "cashback":     body.cashback or "1% Cashback",
            "distance":     body.distance or "",
            "tags":         parsed_tags,
            "image_s3_key": creative_s3_key,
            "image_url":    creative_url,
            "rating":       4.0,
            "reviews":      0,
            "deal_group":   "brand" if ad_type == "brand_deals" else "nearby",
            "title":        body.name or "",
        })
    else:
        raise HTTPException(status_code=400, detail=f"Unknown ad_type: {ad_type}")

    # Coordinates from the PIN code, so an admin-created ad is just as
    # visible to the app's 5 km radius search as an advertiser-created one.
    # Best-effort: a failed lookup stores the ad without coordinates rather
    # than rejecting it.
    ad_lat, ad_lng, ad_geo = await resolve_point_for_ad(
        app_db, pincode=body.pincode
    )
    if ad_geo:
        ad_doc.update({"lat": ad_lat, "lng": ad_lng, "geo": ad_geo})

    result = await ads_collection.insert_one(ad_doc)
    ad_id  = str(result.inserted_id)

    # Mirror into the app-facing collections (identical to advertiser flow).
    if ad_type == "home_banner":
        await app_banners_collection.insert_one({
            "web_ad_id":    ad_id,
            "headline":     ad_doc.get("headline", ""),
            "sub":          ad_doc.get("sub", ""),
            "cta_link":     ad_doc.get("cta_link", ""),
            "media_type":   ad_doc.get("media_type", "image"),
            "image_s3_key": ad_doc.get("image_s3_key", ""),
            "image_url":    ad_doc.get("image_url", ""),
            "video_s3_key": ad_doc.get("video_s3_key", ""),
            "video_url":    ad_doc.get("video_url", ""),
            "pincode":      body.pincode,
            "status":       ad_status,
            "end_date":     end_date_str,
            "publish_date": pub_date.strftime("%d/%m/%Y"),
            "publish_at":   pub_date,
            "ends_at":      end_date,
            "never_expires": end_date is None,
            "created_at":   datetime.utcnow(),
        })
    elif ad_type in ("brand_deals", "nearby_deals"):
        await app_deals_collection.insert_one({
            "web_ad_id":  ad_id,
            "deal_group": ad_doc["deal_group"],
            "tier":       tier,
            "name":       ad_doc.get("name", ""),
            "location":   ad_doc.get("location", ""),
            "offer":      ad_doc.get("offer", ""),
            "cashback":   ad_doc.get("cashback", "1% Cashback"),
            "distance":   ad_doc.get("distance", ""),
            "type":       ad_doc.get("type", ""),
            "category":   ad_doc.get("type", ""),
            "image_s3_key": creative_s3_key,
            "image_url":  creative_url,
            "description": ad_doc.get("description", ""),
            "address":    ad_doc.get("address", ""),
            "phone":      ad_doc.get("phone", ""),
            "timing":     ad_doc.get("timing", ""),
            "rating":     4.0,
            "reviews":    0,
            "tags":       parsed_tags,
            "pincode":    body.pincode,
            "lat":        ad_lat,
            "lng":        ad_lng,
            "geo":        ad_geo,
            "status":     ad_status,
            "end_date":   end_date_str,
            "publish_date": pub_date.strftime("%d/%m/%Y"),
            "publish_at": pub_date,
            "ends_at":    end_date,
            "never_expires": end_date is None,
            "created_at": datetime.utcnow(),
        })
    elif ad_type == "promo_reelz":
        await app_reels_collection.insert_one({
            "web_ad_id":        ad_id,
            "shop_name":        ad_doc.get("shop_name", ""),
            "shop_location":    ad_doc.get("shop_location", ""),
            "shop_category":    ad_doc.get("shop_category", ""),
            "caption":          ad_doc.get("caption", ""),
            "offer":            ad_doc.get("offer", ""),
            "video_s3_key":     creative_s3_key,
            "video_url":        creative_url,
            "thumbnail_s3_key": thumbnail_s3_key,
            "thumbnail_url":    thumbnail_url,
            "like_count":       0,
            "view_count":       0,
            "liked_by":         [],
            "tag":              ad_doc.get("tag", ""),
            "pincode":          body.pincode,
            "lat":              ad_lat,
            "lng":              ad_lng,
            "geo":              ad_geo,
            "status":           ad_status,
            "end_date":         end_date_str,
            "publish_date":     pub_date.strftime("%d/%m/%Y"),
            "publish_at":       pub_date,
            "ends_at":          end_date,
            "never_expires":    end_date is None,
            "created_at":       datetime.utcnow(),
        })

    return {
        "id":           ad_id,
        "ad_type":      ad_type,
        "publish_date": ad_doc["publish_date"],
        "end_date":     ad_doc["end_date"],
        "amount":       amount,
        "status":       ad_status,
        "created_by":   "admin",
        "duration":     mode,
        "never_expires": end_date is None,
    }
