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
    category_images_collection,
)
from models.schemas import (
    AdminLoginRequest, AdminAdPatch, AdminShopPatch, AdminTicketPatch,
    AdminFeedbackReply,
)
from utils.auth import create_access_token
from utils.dependencies import get_current_admin
from utils.notify import notify_user

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
                "phone":         str(cell(row, "phone") or "").strip(),
                "lat":           _num(cell(row, "lat")),
                "lng":           _num(cell(row, "lng")),
            }
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
    await category_images_collection.update_one(
        {"category_id": category_id},
        {"$set": {"category_id": category_id, "keys": keys}},
        upsert=True,
    )
    return {"ok": True, "category_id": category_id, "count": len(keys),
            "urls": [_presign(k) or "" for k in keys]}


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


def _admin_ad_price(ad_type: str, tier: str) -> int:
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


class AdminCreateAdRequest(BaseModel):
    ad_type: str
    tier: str = "standard"          # premium | standard (ignored for home_banner)
    pincode: str = "000000"
    publish_today: bool = True
    scheduled_date: Optional[str] = None
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
    amount = _admin_ad_price(ad_type, tier)

    if body.publish_today:
        pub_date = datetime.utcnow()
    else:
        try:
            pub_date = datetime.strptime(body.scheduled_date, "%Y-%m-%d") if body.scheduled_date else datetime.utcnow()
        except ValueError:
            pub_date = datetime.utcnow()
    end_date  = pub_date + timedelta(days=7)
    ad_status = "active" if body.publish_today else "scheduled"

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
        "end_date":     end_date.strftime("%d/%m/%Y"),
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
            "end_date":     end_date.strftime("%d/%m/%Y"),
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
            "status":     ad_status,
            "end_date":   end_date.strftime("%d/%m/%Y"),
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
            "status":           ad_status,
            "end_date":         end_date.strftime("%d/%m/%Y"),
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
    }
