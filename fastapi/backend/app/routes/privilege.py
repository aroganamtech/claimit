"""
Claimit Privilege — show-and-save discounts at partner businesses.

How it differs from the rest of the app
───────────────────────────────────────
Reward/Redeem Zone works off a scanned bill: the user pays, scans, and earns.
Privilege works BEFORE payment. The user opens a pass on their phone, shows it
to the billing executive at the counter, the executive taps Approve, and the
discount is applied to the bill by the shop. Nothing is scanned and no money
moves through Claimit.

That has one consequence worth stating plainly: the Approve button is tapped on
the customer's own phone, so nothing technically stops a customer approving
their own pass. This mirrors how a paper discount card works, and the controls
are the same three the design calls for:

  • the pass expires 10 minutes after it is issued
  • every pass carries a reference (CLM-GR-102345) the shop can quote
  • every issue AND every approval is recorded, and admin can read the log

So an abused pass is visible after the fact rather than prevented up front. If
that ever needs tightening, the honest fix is a per-shop PIN entered on this
screen — the data model already has somewhere to put it (`approval_pin` on the
partner) and `approve_pass` is the single place that would check it.

Flow
────
  GET  /privilege/categories          → the 9 fixed categories
  GET  /privilege/partners            → list, by category + location + filters
  GET  /privilege/partners/{id}       → detail (About / Privilege / T&C)
  POST /privilege/pass                → issue a 10-minute eligibility pass
  POST /privilege/pass/{ref}/approve  → billing executive approves it
  GET  /privilege/history             → this user's approved discounts
  POST /privilege/partners/self       → a user lists their own business

Partner documents live in `privilege_partners`, passes in `privilege_passes`.
Both are geo-indexed the same way as every other feature, so the 5 km radius
and the never-empty fallback behave identically here.
"""
import random
import string
from datetime import datetime, timedelta, timezone
from typing import Optional, List

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from bson import ObjectId

from ..database import get_db
from ..utils.auth import get_current_user
from ..utils.s3 import public_url, generate_presigned_url_sync, upload_base64
from ..utils.geo_filter import nearby_or_nearest, attach_distance

router = APIRouter(prefix="/privilege", tags=["Privilege"])

IST = timezone(timedelta(hours=5, minutes=30))

# How long a pass stays valid once opened. The design says 10 minutes: long
# enough to reach the counter and be served, short enough that a screenshot
# taken this morning is useless this afternoon.
PASS_VALID_MINUTES = 10

# ── Categories ────────────────────────────────────────────────────────────────
# Fixed catalogue, in the order the home grid draws them (3 x 3).
PRIVILEGE_CATEGORIES = [
    {"id": "hotels",     "label": "Hotels & Resorts"},
    {"id": "travel",     "label": "Tours, Travel & Packages"},
    {"id": "events",     "label": "Wedding & Events"},
    {"id": "interiors",  "label": "Interiors & Furniture"},
    {"id": "health",     "label": "Healthcare, Dental & Wellness"},
    {"id": "auto",       "label": "Cars, Bikes & Auto Services"},
    {"id": "education",  "label": "Education & Overseas Studies"},
    {"id": "property",   "label": "Real Estate & Property"},
    {"id": "jewellery",  "label": "Jewellery & Premium Retail"},
]

_CATEGORY_LABELS = {c["id"]: c["label"] for c in PRIVILEGE_CATEGORIES}


def _photo_url(key: str) -> str:
    if not key:
        return ""
    return generate_presigned_url_sync(key) or public_url(key) or ""


def _serialize_partner(doc: dict) -> dict:
    """Shape a partner for the list and detail screens."""
    cat = doc.get("category") or ""
    photo_keys = doc.get("photo_s3_keys") or []
    out = {
        "id": str(doc["_id"]),
        "name": doc.get("name") or "",
        "category": cat,
        "category_label": doc.get("category_label") or _CATEGORY_LABELS.get(cat, ""),
        "area": doc.get("area") or "",
        "city": doc.get("city") or "",
        "state": doc.get("state") or "",
        "pincode": doc.get("pincode") or "",
        "address": doc.get("address") or "",
        "phone": doc.get("phone") or "",
        # "Up to 15% off" on the card, "15% OFF" on the detail badge.
        "discount_percent": float(doc.get("discount_percent") or 0),
        "discount_label": doc.get("discount_label") or "",
        # The three blocks on the detail screen.
        "about": doc.get("about") or "",
        "privilege_details": doc.get("privilege_details") or "",
        "terms": doc.get("terms") or "",
        "photo_url": _photo_url((photo_keys or [""])[0]),
        "photo_urls": [_photo_url(k) for k in photo_keys if k],
        "status": doc.get("status") or "active",
        "distance": "",
    }
    if doc.get("distance_km") is not None:
        out["distance"] = f"{doc['distance_km']:.1f} km"
        out["distance_km"] = doc["distance_km"]
    return out


def _new_reference(name: str) -> str:
    """CLM-GR-102345 — Claimit, the partner's initials, then a random block.

    Random rather than sequential on purpose: a sequential reference tells
    anyone holding one roughly how many passes Claimit has ever issued, and
    makes the next one guessable.
    """
    initials = "".join(w[0] for w in (name or "").split()[:2] if w).upper() or "CL"
    digits = "".join(random.choices(string.digits, k=6))
    return f"CLM-{initials}-{digits}"


# ── Categories ────────────────────────────────────────────────────────────────

@router.get("/categories")
async def list_categories(current_user: dict = Depends(get_current_user)):
    """The 9 Privilege categories, in home-grid order."""
    return {"categories": PRIVILEGE_CATEGORIES}


# ── Partners ──────────────────────────────────────────────────────────────────

@router.get("/partners")
async def list_partners(
    category: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    sort: str = Query("distance", description="distance | discount | location"),
    lat: Optional[float] = Query(None),
    lng: Optional[float] = Query(None),
    radius_km: float = Query(5.0, ge=0.5, le=50),
    limit: int = Query(20, le=50),
    skip: int = Query(0, ge=0),
    current_user: dict = Depends(get_current_user),
):
    """Partners for a category, nearest first.

    The three filter chips on the design map to `sort`:
      distance → nearest first (the default)
      discount → biggest discount first
      location → grouped by area name, A-Z

    Radius behaves like the rest of the app: 5 km, then 10 km, then the nearest
    anywhere rather than an empty screen. A user in a quiet pincode should see
    the closest privileges, honestly labelled, not a blank page.
    """
    db = get_db()
    query: dict = {"status": {"$ne": "disabled"}}
    if category:
        query["category"] = category
    if search and search.strip():
        import re
        term = re.escape(search.strip())
        query["$or"] = [
            {"name": {"$regex": term, "$options": "i"}},
            {"area": {"$regex": term, "$options": "i"}},
            {"city": {"$regex": term, "$options": "i"}},
        ]

    probe = limit + 1
    docs, geo_info = await nearby_or_nearest(
        db, "privilege_partners", lat, lng, radius_km, query, probe, skip=skip,
    )
    if docs is None:
        docs = await (db["privilege_partners"].find(query)
                      .sort("name", 1).skip(skip).limit(probe)
                      .to_list(length=probe))

    has_more = len(docs) > limit
    docs = docs[:limit]
    items = [_serialize_partner(attach_distance(d)) for d in docs]

    # Re-order for the other two chips. Distance order is whatever $geoNear
    # already produced, so it needs no extra sort.
    if sort == "discount":
        items.sort(key=lambda p: -p["discount_percent"])
    elif sort == "location":
        items.sort(key=lambda p: (p["area"].lower(), p["name"].lower()))

    return {
        "partners": items,
        "total": len(items),
        "has_more": has_more,
        "skip": skip,
        **geo_info,
    }


@router.get("/coverage")
async def privilege_coverage(
    city: str = Query("", description="City name, prefix match"),
    current_user: dict = Depends(get_current_user),
):
    """How many privilege partners each category has in a city.

    Same question the Select coverage screen answers: is it worth looking here?
    Without it the user taps nine categories to find eight empty.
    """
    import re
    db = get_db()
    base = {"status": {"$ne": "disabled"}}
    term = re.escape((city or "").strip())
    if term:
        base["city"] = {"$regex": f"^{term}", "$options": "i"}

    counts: dict = {}
    try:
        async for row in db.privilege_partners.aggregate([
            {"$match": base},
            {"$group": {"_id": "$category", "n": {"$sum": 1}}},
        ]):
            counts[str(row.get("_id") or "")] = int(row.get("n") or 0)
    except Exception as e:
        print(f"[privilege/coverage] failed: {e}")

    categories = [
        {"id": c["id"], "label": c["label"], "count": counts.get(c["id"], 0)}
        for c in PRIVILEGE_CATEGORIES
    ]
    return {
        "city": (city or "").strip(),
        "total": sum(c["count"] for c in categories),
        "categories": categories,
    }


@router.get("/partners/{partner_id}")
async def get_partner(
    partner_id: str,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    try:
        doc = await db.privilege_partners.find_one({"_id": ObjectId(partner_id)})
    except Exception:
        doc = None
    if not doc:
        raise HTTPException(status_code=404, detail="Privilege partner not found")
    return {"partner": _serialize_partner(doc)}


# ── Eligibility pass ──────────────────────────────────────────────────────────

class PassRequest(BaseModel):
    partner_id: str


@router.post("/pass")
async def issue_pass(
    body: PassRequest,
    current_user: dict = Depends(get_current_user),
):
    """Issue a 10-minute eligibility pass for this user at this partner.

    Everything the counter needs is frozen INTO the pass at issue time — the
    partner name, the discount, the user's name and number. If the partner
    later changes their offer, a pass already open at a till still shows what
    the customer was promised, and the log still says what was approved.
    """
    db = get_db()
    uid = str(current_user["_id"])

    try:
        partner = await db.privilege_partners.find_one({"_id": ObjectId(body.partner_id)})
    except Exception:
        partner = None
    if not partner:
        raise HTTPException(status_code=404, detail="Privilege partner not found")
    if (partner.get("status") or "active") == "disabled":
        raise HTTPException(status_code=400, detail="This privilege is not currently available")

    now = datetime.now(timezone.utc)
    doc = {
        "user_id":        uid,
        "user_name":      current_user.get("name") or current_user.get("full_name") or "",
        "user_phone":     current_user.get("phone") or "",
        "user_photo_key": current_user.get("photo_s3_key") or "",
        "partner_id":     str(partner["_id"]),
        "partner_name":   partner.get("name") or "",
        "partner_area":   partner.get("area") or "",
        "partner_city":   partner.get("city") or "",
        "discount_percent": float(partner.get("discount_percent") or 0),
        "discount_label":   partner.get("discount_label") or "",
        "reference":      _new_reference(partner.get("name") or ""),
        "status":         "pending",
        "issued_at":      now,
        "expires_at":     now + timedelta(minutes=PASS_VALID_MINUTES),
        "approved_at":    None,
    }
    await db.privilege_passes.insert_one(doc)
    return {"pass": _serialize_pass(doc)}


def _serialize_pass(doc: dict) -> dict:
    exp = doc.get("expires_at")
    if exp is not None and exp.tzinfo is None:
        exp = exp.replace(tzinfo=timezone.utc)
    now = datetime.now(timezone.utc)
    seconds_left = int((exp - now).total_seconds()) if exp else 0
    return {
        "reference":        doc.get("reference") or "",
        "status":           doc.get("status") or "pending",
        "user_name":        doc.get("user_name") or "",
        "user_phone":       doc.get("user_phone") or "",
        "user_photo_url":   _photo_url(doc.get("user_photo_key") or ""),
        "partner_id":       doc.get("partner_id") or "",
        "partner_name":     doc.get("partner_name") or "",
        "partner_area":     doc.get("partner_area") or "",
        "partner_city":     doc.get("partner_city") or "",
        "discount_percent": float(doc.get("discount_percent") or 0),
        "discount_label":   doc.get("discount_label") or "",
        "valid_minutes":    PASS_VALID_MINUTES,
        # Negative would render as a countdown running backwards; clamp it.
        "seconds_left":     max(0, seconds_left),
        "issued_at":        _iso(doc.get("issued_at")),
        "expires_at":       _iso(doc.get("expires_at")),
        "approved_at":      _iso(doc.get("approved_at")),
    }


def _iso(value) -> str:
    if not isinstance(value, datetime):
        return ""
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(IST).isoformat()


@router.post("/pass/{reference}/approve")
async def approve_pass(
    reference: str,
    current_user: dict = Depends(get_current_user),
):
    """The billing executive approves the discount on the customer's phone.

    Refuses an expired pass and refuses a second approval. Both matter: the
    first stops a screenshot from this morning being honoured, the second
    stops one pass being used twice at the same counter.
    """
    db = get_db()
    uid = str(current_user["_id"])

    doc = await db.privilege_passes.find_one({"reference": reference})
    if not doc:
        raise HTTPException(status_code=404, detail="Pass not found")
    # A pass belongs to the user it was issued to — approving someone else's
    # from another account would let one phone launder another's discounts.
    if doc.get("user_id") != uid:
        raise HTTPException(status_code=403, detail="This pass belongs to another user")
    if doc.get("status") == "approved":
        raise HTTPException(status_code=400, detail="This discount was already approved")

    exp = doc.get("expires_at")
    if exp is not None:
        if exp.tzinfo is None:
            exp = exp.replace(tzinfo=timezone.utc)
        if datetime.now(timezone.utc) > exp:
            await db.privilege_passes.update_one(
                {"_id": doc["_id"]}, {"$set": {"status": "expired"}})
            raise HTTPException(
                status_code=400,
                detail="This pass has expired. Open it again at the counter.")

    now = datetime.now(timezone.utc)
    await db.privilege_passes.update_one(
        {"_id": doc["_id"]},
        {"$set": {"status": "approved", "approved_at": now}},
    )
    doc["status"], doc["approved_at"] = "approved", now
    return {"pass": _serialize_pass(doc)}


@router.get("/history")
async def my_history(
    limit: int = Query(50, le=100),
    skip: int = Query(0, ge=0),
    current_user: dict = Depends(get_current_user),
):
    """This user's privilege history, newest first.

    Approved passes only — an issued-but-never-approved pass is noise the user
    did not benefit from, and showing it would make the list look like a
    record of discounts they received when it isn't.
    """
    db = get_db()
    uid = str(current_user["_id"])
    probe = limit + 1
    docs = await (db.privilege_passes
                  .find({"user_id": uid, "status": "approved"})
                  .sort("approved_at", -1)
                  .skip(skip).limit(probe)
                  .to_list(length=probe))
    has_more = len(docs) > limit
    return {
        "history": [_serialize_pass(d) for d in docs[:limit]],
        "has_more": has_more,
        "skip": skip,
    }


# ── A user listing their own business (the + button on the home screen) ───────

class SelfPartnerRequest(BaseModel):
    name: str
    category: str
    about: str = ""
    privilege_details: str = ""
    terms: str = ""
    discount_percent: float = 0
    discount_label: str = ""
    area: str = ""
    city: str = ""
    state: str = ""
    pincode: str = ""
    address: str = ""
    phone: str = ""
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    # The app sends base64 and this module uploads to S3, storing only the key
    # — the same convention select.py and the bill reader already use.
    photos_base64: List[str] = []


@router.post("/partners/self")
async def create_own_partner(
    body: SelfPartnerRequest,
    current_user: dict = Depends(get_current_user),
):
    """A user lists their own business as a privilege partner.

    Created as `pending` — it does not appear to other users until admin
    approves it. Anything else would let anyone publish a discount claiming to
    be a hotel they don't own.
    """
    db = get_db()
    uid = str(current_user["_id"])

    if body.category not in _CATEGORY_LABELS:
        raise HTTPException(status_code=400, detail="Unknown category")
    if not body.name.strip():
        raise HTTPException(status_code=400, detail="Business name is required")

    # Coordinates, so the listing appears in the radius search at all. Falls
    # back to the PIN code centre when the phone gave no fix — the common case
    # indoors, and the exact gap that made earlier listings invisible.
    lat, lng = body.latitude, body.longitude
    if lat is None or lng is None:
        pin = "".join(ch for ch in str(body.pincode or "") if ch.isdigit())
        if len(pin) == 6:
            try:
                centre = await db["pincode_centres"].find_one({"_id": pin})
                if centre:
                    lat = float(centre.get("lat"))
                    lng = float(centre.get("lng"))
            except Exception:
                pass

    # One bad image is skipped rather than failing the whole submission — the
    # listing is still useful without its third photo.
    photo_keys: List[str] = []
    for b64 in (body.photos_base64 or [])[:6]:
        if not b64:
            continue
        try:
            photo_keys.append(await upload_base64(b64, "privilege"))
        except Exception:
            continue

    doc = {
        "name":              body.name.strip(),
        "category":          body.category,
        "category_label":    _CATEGORY_LABELS[body.category],
        "about":             body.about,
        "privilege_details": body.privilege_details,
        "terms":             body.terms,
        "discount_percent":  max(0.0, float(body.discount_percent or 0)),
        "discount_label":    body.discount_label,
        "area":              body.area,
        "city":              body.city,
        "state":             body.state,
        "pincode":           body.pincode,
        "address":           body.address,
        "phone":             body.phone,
        "photo_s3_keys":     photo_keys,
        "created_by":        uid,
        "status":            "pending",
        "created_at":        datetime.now(timezone.utc),
    }
    if lat is not None and lng is not None:
        try:
            doc["lat"], doc["lng"] = float(lat), float(lng)
            doc["geo"] = {"type": "Point", "coordinates": [float(lng), float(lat)]}
        except (TypeError, ValueError):
            pass

    res = await db.privilege_partners.insert_one(doc)
    doc["_id"] = res.inserted_id
    return {"partner": _serialize_partner(doc),
            "message": "Submitted for review. It goes live once approved."}
