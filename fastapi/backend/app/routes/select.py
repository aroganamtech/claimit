"""
Claimit Select — a directory of trusted local professionals (doctors, lawyers,
CA & tax, architects, interior designers, tutors, beauty experts, fitness
trainers, photographers, event planners, financial advisors, home services).

How it works
────────────
• A professional REGISTERS THEMSELVES from the app (POST /select/professionals)
  and picks a listing plan — Premium / Standard / Custom. Premium listings rank
  above Standard everywhere. The listing fee is paid with Razorpay through the
  existing /payments/create-link flow (utils/cashfree.py is Razorpay under the
  hood); the "custom" plan may be any amount including 0, which is free and
  needs no payment.
• Plan prices are admin-configurable — they live in the SAME
  claimit_db.app_config {"key": "pricing"} document the web admin panel's
  Pricing page edits (select_premium / select_standard), so a price change
  there applies here immediately with no deploy.
• A customer browses by category, opens a professional, and books a
  consultation (POST /select/bookings). Per product decision the booking is a
  FREE request/enquiry for now — the consultation fee shown on the card is the
  professional's own advertised price and is NOT charged in-app yet.

Photos: the app sends base64; this module uploads them to S3 and stores only
the key. Playable/viewable URLs are resolved per-request, the same convention
routes/learn.py and routes/reels.py use.

Endpoints
─────────
GET  /select/categories            → the 12 fixed categories
GET  /select/plans                 → live listing-plan prices
GET  /select/professionals         → list (category / sort / search / geo)
GET  /select/professionals/{id}    → one professional
POST /select/professionals         → self-register (upsert own profile)
GET  /select/my-profile            → the caller's own professional profile
POST /select/bookings              → book a consultation (free request)
GET  /select/bookings              → the caller's bookings
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from typing import Optional, List
from bson import ObjectId
from datetime import datetime, timezone

from ..database import get_db
from ..utils.auth import get_current_user
from ..utils.s3 import (
    upload_base64,
    generate_presigned_url_sync,
    public_url,
)

router = APIRouter(prefix="/select", tags=["select"])


# ── Categories ────────────────────────────────────────────────────────────────
# Fixed catalogue shown on the Claimit Select home grid, in display order.
# `id` is the stable key stored on each professional document.
SELECT_CATEGORIES = [
    {"id": "doctors",       "label": "Doctors"},
    {"id": "lawyers",       "label": "Lawyers"},
    {"id": "ca_tax",        "label": "CA & Tax"},
    {"id": "architects",    "label": "Architects"},
    {"id": "interior",      "label": "Interior Designers"},
    {"id": "tutors",        "label": "Tutors"},
    {"id": "beauty",        "label": "Beauty Experts"},
    {"id": "fitness",       "label": "Fitness Trainers"},
    {"id": "photographers", "label": "Photographers"},
    {"id": "events",        "label": "Event Planners"},
    {"id": "financial",     "label": "Financial Advisors"},
    {"id": "home_services", "label": "Home Services"},
]

_CATEGORY_LABELS = {c["id"]: c["label"] for c in SELECT_CATEGORIES}

# Fallback listing-plan prices, used until an admin saves a value. Kept in sync
# with claimit_web_org/fastapi/backend/utils/pricing.py DEFAULT_PRICING.
DEFAULT_SELECT_PLANS = {"premium": 1200, "standard": 700}

# Plan rank used for ordering — Premium listings always come first, which is
# what the Premium plan actually buys.
_PLAN_RANK = {"premium": 0, "standard": 1, "custom": 2}


def _oid(id_str: str) -> ObjectId:
    try:
        return ObjectId(id_str)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid id")


async def _plan_prices(db) -> dict:
    """Live Premium/Standard listing prices from the shared app_config
    {"key": "pricing"} document the web admin Pricing page edits."""
    prices = dict(DEFAULT_SELECT_PLANS)
    try:
        cfg = await db.app_config.find_one({"key": "pricing"})
    except Exception:
        cfg = None
    if cfg:
        if cfg.get("select_premium") is not None:
            prices["premium"] = cfg["select_premium"]
        if cfg.get("select_standard") is not None:
            prices["standard"] = cfg["select_standard"]
    return prices


def _photo_url(key: str) -> str:
    if not key:
        return ""
    return generate_presigned_url_sync(key) or public_url(key) or ""


def _serialize(doc: dict, distance_km: Optional[float] = None) -> dict:
    """Shape a professional document for the app. Distance is only present
    when the caller supplied GPS coordinates."""
    cat_id = doc.get("category") or ""
    portfolio_keys = doc.get("portfolio_s3_keys") or []
    out = {
        "id": str(doc["_id"]),
        "name": doc.get("name") or "",
        "category": cat_id,
        "category_label": doc.get("category_label") or _CATEGORY_LABELS.get(cat_id, ""),
        "role": doc.get("role") or doc.get("category_label") or _CATEGORY_LABELS.get(cat_id, ""),
        "about": doc.get("about") or "",
        "experience_years": int(doc.get("experience_years") or 0),
        "consultation_fee": float(doc.get("consultation_fee") or 0),
        "photo_url": _photo_url(doc.get("photo_s3_key") or ""),
        "portfolio_urls": [_photo_url(k) for k in portfolio_keys if k],
        "services": doc.get("services") or [],
        "tags": doc.get("tags") or [],
        "phone": doc.get("phone") or "",
        "email": doc.get("email") or "",
        "area": doc.get("area") or "",
        "city": doc.get("city") or "",
        "state": doc.get("state") or "",
        "district": doc.get("district") or "",
        "pincode": doc.get("pincode") or "",
        "address": doc.get("address") or "",
        "plan": doc.get("plan") or "custom",
        "is_premium": (doc.get("plan") or "") == "premium",
        "is_verified": bool(doc.get("is_verified", True)),
        "rating": float(doc.get("rating") or 0),
        "review_count": int(doc.get("review_count") or 0),
        "offer_text": doc.get("offer_text") or "",
        "offer_percent": int(doc.get("offer_percent") or 0),
        "offer_valid_till": doc.get("offer_valid_till") or "",
        "distance": "",
    }
    if distance_km is not None:
        out["distance"] = f"{distance_km:.1f} km"
    return out


# ── Categories + plans ────────────────────────────────────────────────────────

@router.get("/categories")
async def list_categories(current_user: dict = Depends(get_current_user)):
    """The 12 Claimit Select categories, in display order."""
    return {"categories": SELECT_CATEGORIES}


@router.get("/plans")
async def get_select_plans(current_user: dict = Depends(get_current_user)):
    """Live listing-plan prices for the registration plan picker. `custom`
    carries no price — the professional types any amount (0 = free)."""
    db = get_db()
    prices = await _plan_prices(db)
    return {
        "plans": {
            "premium":  {"price": prices["premium"]},
            "standard": {"price": prices["standard"]},
            "custom":   {"price": 0},
        }
    }


# ── List professionals ────────────────────────────────────────────────────────

@router.get("/professionals")
async def list_professionals(
    category: Optional[str] = None,
    sort: str = "nearby",           # nearby | top_rated | offers
    search: Optional[str] = None,
    lat: Optional[float] = None,
    lng: Optional[float] = None,
    radius_km: float = 25,
    skip: int = 0,
    limit: int = Query(default=30, le=100),
    current_user: dict = Depends(get_current_user),
):
    """Professionals for a category. Premium listings always rank above
    Standard; within the same plan the chosen sort applies.

    sort=nearby     → nearest first when lat/lng are supplied, else newest
    sort=top_rated  → highest rated first
    sort=offers     → only professionals currently running an offer
    """
    db = get_db()

    query: dict = {"status": {"$ne": "disabled"}}
    if category:
        query["category"] = category

    # Any condition that needs its own $or goes into this list and is combined
    # with $and at the end — building them as separate query["$or"] keys would
    # silently overwrite each other when both search and offers are active.
    and_clauses: List[dict] = []

    if search:
        # Case-insensitive match on name or role. The term is regex-escaped, so
        # a user typing "(" or ".*" can't break or widen the query.
        import re
        term = re.escape(search.strip())
        if term:
            and_clauses.append({
                "$or": [
                    {"name": {"$regex": term, "$options": "i"}},
                    {"role": {"$regex": term, "$options": "i"}},
                ]
            })

    if sort == "offers":
        # "Running an offer" means either a text offer or a percentage — the
        # app's hasOffer check treats both the same way.
        and_clauses.append({
            "$or": [
                {"offer_text": {"$nin": ["", None]}},
                {"offer_percent": {"$gt": 0}},
            ]
        })

    if and_clauses:
        query["$and"] = and_clauses

    results: List[dict] = []

    # Nearby uses the geo index when the app supplied coordinates.
    if sort == "nearby" and lat is not None and lng is not None:
        pipeline = [
            {
                "$geoNear": {
                    "near": {"type": "Point", "coordinates": [lng, lat]},
                    "distanceField": "_dist_m",
                    "maxDistance": radius_km * 1000,
                    "spherical": True,
                    "query": query,
                }
            },
            {"$skip": skip},
            {"$limit": limit},
        ]
        async for doc in db.select_professionals.aggregate(pipeline):
            dist_km = doc.pop("_dist_m", 0) / 1000
            results.append(_serialize(doc, distance_km=dist_km))
        # Premium first, then by distance (geoNear already ordered by distance).
        results.sort(key=lambda p: _PLAN_RANK.get(p["plan"], 2))
        return {"professionals": results}

    # Everything else is a plain find with an explicit sort.
    if sort == "top_rated":
        sort_spec = [("rating", -1), ("review_count", -1)]
    else:
        sort_spec = [("created_at", -1)]

    cursor = db.select_professionals.find(query).sort(sort_spec).skip(skip).limit(limit)
    async for doc in cursor:
        results.append(_serialize(doc))
    results.sort(key=lambda p: _PLAN_RANK.get(p["plan"], 2))
    return {"professionals": results}


# ── The caller's own professional profile ─────────────────────────────────────
# Declared before /professionals/{id} is irrelevant here because this uses a
# distinct path, which avoids the classic "me is parsed as an id" pitfall.

@router.get("/my-profile")
async def my_professional_profile(current_user: dict = Depends(get_current_user)):
    """The caller's own Select listing, or null if they haven't registered."""
    db = get_db()
    doc = await db.select_professionals.find_one({"user_id": current_user["_id"]})
    return {"professional": _serialize(doc) if doc else None}


# ── One professional ──────────────────────────────────────────────────────────

@router.get("/professionals/{professional_id}")
async def get_professional(
    professional_id: str,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    doc = await db.select_professionals.find_one({"_id": _oid(professional_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Professional not found")
    return {"professional": _serialize(doc)}


# ── Self-registration ─────────────────────────────────────────────────────────

class RegisterProfessionalRequest(BaseModel):
    name: str
    category: str
    role: str = ""
    about: str = ""
    experience_years: int = 0
    consultation_fee: float = 0
    services: List[str] = []
    tags: List[str] = []
    phone: str = ""
    email: str = ""
    address: str = ""
    area: str = ""
    city: str = ""
    district: str = ""
    state: str = ""
    pincode: str = ""
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    # Listing plan: premium | standard | custom. For premium/standard the
    # server uses the admin-configured price and ignores `amount`; `amount` is
    # only honoured for the custom plan (where entering any value, including 0
    # for free, is the whole point).
    plan: str = "custom"
    amount: float = 0
    payment_link_id: str = ""
    # Offer shown on the card / profile (optional)
    offer_text: str = ""
    offer_percent: int = 0
    offer_valid_till: str = ""
    # base64 image payloads — uploaded to S3 here, only the key is stored
    photo_base64: str = ""
    portfolio_base64: List[str] = []


@router.post("/professionals", status_code=201)
async def register_professional(
    body: RegisterProfessionalRequest,
    current_user: dict = Depends(get_current_user),
):
    """Register (or update) the caller's own Claimit Select listing.

    One listing per user — calling this again updates the existing one rather
    than creating a duplicate.
    """
    db = get_db()

    if body.category not in _CATEGORY_LABELS:
        raise HTTPException(status_code=400, detail="Unknown category")
    if not body.name.strip():
        raise HTTPException(status_code=400, detail="Name is required")

    plan = (body.plan or "custom").strip().lower()
    if plan not in ("premium", "standard", "custom"):
        plan = "custom"

    # Authoritative listing price — never trust the client's amount for the
    # fixed plans; only the custom plan is client-priced by design.
    if plan in ("premium", "standard"):
        prices = await _plan_prices(db)
        amount = float(prices[plan])
    else:
        amount = float(body.amount or 0)
        if amount < 0:
            raise HTTPException(status_code=400, detail="Amount must be 0 or more")

    existing = await db.select_professionals.find_one({"user_id": current_user["_id"]})

    # Upload any newly supplied images; keep the existing ones when the client
    # sends nothing (so an edit that doesn't touch photos doesn't wipe them).
    photo_key = (existing or {}).get("photo_s3_key", "")
    if body.photo_base64:
        try:
            photo_key = await upload_base64(body.photo_base64, "select/profile")
        except Exception:
            raise HTTPException(status_code=502, detail="Could not upload the profile photo")

    portfolio_keys = list((existing or {}).get("portfolio_s3_keys") or [])
    if body.portfolio_base64:
        new_keys = []
        for b64 in body.portfolio_base64[:12]:   # cap at 12 portfolio images
            if not b64:
                continue
            try:
                new_keys.append(await upload_base64(b64, "select/portfolio"))
            except Exception:
                continue   # skip a bad image rather than failing the whole save
        if new_keys:
            portfolio_keys = new_keys

    doc = {
        "user_id": current_user["_id"],
        "name": body.name.strip(),
        "category": body.category,
        "category_label": _CATEGORY_LABELS[body.category],
        "role": (body.role or _CATEGORY_LABELS[body.category]).strip(),
        "about": body.about.strip(),
        "experience_years": max(0, int(body.experience_years or 0)),
        "consultation_fee": max(0.0, float(body.consultation_fee or 0)),
        "services": [s for s in body.services if s][:12],
        "tags": [t for t in body.tags if t][:6],
        "phone": body.phone or current_user.get("phone", ""),
        "email": body.email or current_user.get("email", ""),
        "address": body.address,
        "area": body.area,
        "city": body.city,
        "district": body.district,
        "state": body.state,
        "pincode": body.pincode,
        "photo_s3_key": photo_key,
        "portfolio_s3_keys": portfolio_keys,
        "plan": plan,
        "amount_paid": amount,
        "payment_link_id": body.payment_link_id,
        "offer_text": body.offer_text.strip(),
        "offer_percent": max(0, int(body.offer_percent or 0)),
        "offer_valid_till": body.offer_valid_till,
        "status": "active",
        "is_verified": True,
        "updated_at": datetime.now(timezone.utc),
    }

    # GeoJSON point so /select/professionals?sort=nearby can use the 2dsphere
    # index (same convention as shops).
    if body.latitude is not None and body.longitude is not None:
        doc["geo"] = {"type": "Point", "coordinates": [body.longitude, body.latitude]}
        doc["lat"] = body.latitude
        doc["lng"] = body.longitude

    if existing:
        # Preserve rating/reviews/created_at across profile edits.
        await db.select_professionals.update_one({"_id": existing["_id"]}, {"$set": doc})
        saved = await db.select_professionals.find_one({"_id": existing["_id"]})
    else:
        doc["rating"] = 0.0
        doc["review_count"] = 0
        doc["created_at"] = datetime.now(timezone.utc)
        result = await db.select_professionals.insert_one(doc)
        saved = await db.select_professionals.find_one({"_id": result.inserted_id})

    return {"professional": _serialize(saved)}


# ── Bookings ──────────────────────────────────────────────────────────────────

class CreateBookingRequest(BaseModel):
    professional_id: str
    service: str = ""
    date: str = ""          # YYYY-MM-DD
    time_slot: str = ""     # e.g. "10:00 AM"
    mode: str = "in_person"  # in_person | video | phone
    message: str = ""


@router.post("/bookings", status_code=201)
async def create_booking(
    body: CreateBookingRequest,
    current_user: dict = Depends(get_current_user),
):
    """Book a consultation. This is a FREE request for now — no payment is
    collected in-app; the fee stored here is the professional's advertised
    price, kept for the record and shown in My Bookings."""
    db = get_db()

    pro = await db.select_professionals.find_one({"_id": _oid(body.professional_id)})
    if not pro:
        raise HTTPException(status_code=404, detail="Professional not found")
    if not body.date or not body.time_slot:
        raise HTTPException(status_code=400, detail="Pick a date and a time slot")

    mode = (body.mode or "in_person").strip().lower()
    if mode not in ("in_person", "video", "phone"):
        mode = "in_person"

    fee = float(pro.get("consultation_fee") or 0)
    doc = {
        "user_id": current_user["_id"],
        "user_name": current_user.get("name", "User"),
        "user_phone": current_user.get("phone", ""),
        "professional_id": str(pro["_id"]),
        "professional_name": pro.get("name", ""),
        "professional_role": pro.get("role", ""),
        "professional_photo_s3_key": pro.get("photo_s3_key", ""),
        "service": body.service.strip(),
        "date": body.date,
        "time_slot": body.time_slot,
        "mode": mode,
        "message": body.message.strip()[:200],
        "consultation_fee": fee,
        "service_fee": 0.0,
        "total_amount": fee,
        # Free request for now — no in-app payment is taken at booking time.
        "payment_status": "not_required",
        "status": "requested",
        "created_at": datetime.now(timezone.utc),
    }
    result = await db.select_bookings.insert_one(doc)
    doc["_id"] = result.inserted_id
    return {"booking": _serialize_booking(doc)}


def _serialize_booking(doc: dict, incoming: bool = False) -> dict:
    """[incoming] = the professional is viewing a booking made with them, so
    the customer's name/phone are included (they need to know who booked and
    how to reach them). A customer viewing their own booking never sees
    another customer's details."""
    out = {
        "id": str(doc["_id"]),
        "professional_id": doc.get("professional_id", ""),
        "professional_name": doc.get("professional_name", ""),
        "professional_role": doc.get("professional_role", ""),
        "professional_photo_url": _photo_url(doc.get("professional_photo_s3_key") or ""),
        "service": doc.get("service", ""),
        "date": doc.get("date", ""),
        "time_slot": doc.get("time_slot", ""),
        "mode": doc.get("mode", "in_person"),
        "message": doc.get("message", ""),
        "consultation_fee": float(doc.get("consultation_fee") or 0),
        "service_fee": float(doc.get("service_fee") or 0),
        "total_amount": float(doc.get("total_amount") or 0),
        "status": doc.get("status", "requested"),
        "payment_status": doc.get("payment_status", "not_required"),
        "is_incoming": incoming,
        "customer_name": "",
        "customer_phone": "",
    }
    if incoming:
        out["customer_name"] = doc.get("user_name", "")
        out["customer_phone"] = doc.get("user_phone", "")
    return out


@router.get("/bookings")
async def list_my_bookings(current_user: dict = Depends(get_current_user)):
    """The caller's consultations, newest first."""
    db = get_db()
    docs = (
        await db.select_bookings.find({"user_id": current_user["_id"]})
        .sort("created_at", -1)
        .to_list(length=200)
    )
    return {"bookings": [_serialize_booking(d) for d in docs]}


# ── Professional side of bookings ─────────────────────────────────────────────
# Without these a booking would dead-end: the customer books, and nobody ever
# sees it. These let the listed professional see and action their requests.

@router.get("/bookings/received")
async def list_received_bookings(current_user: dict = Depends(get_current_user)):
    """Bookings made against the caller's own listing. Empty when the caller
    isn't listed as a professional."""
    db = get_db()
    pro = await db.select_professionals.find_one({"user_id": current_user["_id"]})
    if not pro:
        return {"bookings": []}
    docs = (
        await db.select_bookings.find({"professional_id": str(pro["_id"])})
        .sort("created_at", -1)
        .to_list(length=200)
    )
    return {"bookings": [_serialize_booking(d, incoming=True) for d in docs]}


class BookingStatusBody(BaseModel):
    status: str   # confirmed | cancelled


@router.patch("/bookings/{booking_id}/status")
async def update_booking_status(
    booking_id: str,
    body: BookingStatusBody,
    current_user: dict = Depends(get_current_user),
):
    """Confirm or decline a booking. Only the professional the booking was
    made with may change it."""
    db = get_db()
    new_status = (body.status or "").strip().lower()
    if new_status not in ("confirmed", "cancelled"):
        raise HTTPException(status_code=400, detail="status must be confirmed or cancelled")

    booking = await db.select_bookings.find_one({"_id": _oid(booking_id)})
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")

    pro = await db.select_professionals.find_one({"user_id": current_user["_id"]})
    if not pro or str(pro["_id"]) != booking.get("professional_id"):
        raise HTTPException(status_code=403, detail="Not your booking")

    await db.select_bookings.update_one(
        {"_id": booking["_id"]},
        {"$set": {"status": new_status, "updated_at": datetime.now(timezone.utc)}},
    )
    booking["status"] = new_status
    return {"booking": _serialize_booking(booking, incoming=True)}


# ═══════════════════════════════════════════════════════════════════════════
# Messages — in-app chat between a customer and a listed professional.
#
# One conversation per (customer, professional) pair. Both sides are always
# authorised explicitly on every call: a conversation is only readable or
# writable by the customer who started it or the user who owns the listing.
# Unread counts are tracked per side so each participant sees their own badge.
# ═══════════════════════════════════════════════════════════════════════════

def _serialize_conversation(doc: dict, me: str) -> dict:
    """Shape a conversation from the perspective of [me] — the other party's
    name/photo is what the list should show."""
    is_customer = doc.get("customer_id") == me
    other_name = doc.get("professional_name", "") if is_customer else doc.get("customer_name", "")
    other_photo_key = doc.get("professional_photo_s3_key", "") if is_customer else ""
    unread = int((doc.get("unread") or {}).get(
        "customer" if is_customer else "professional", 0))
    last_at = doc.get("last_message_at")
    return {
        "id": str(doc["_id"]),
        "professional_id": doc.get("professional_id", ""),
        "other_name": other_name or "Claimit user",
        "other_role": doc.get("professional_role", "") if is_customer else "Customer",
        "other_photo_url": _photo_url(other_photo_key),
        "last_message": doc.get("last_message", ""),
        "last_message_at": last_at.isoformat() if last_at else "",
        "unread_count": unread,
        "i_am_professional": not is_customer,
    }


def _serialize_message(doc: dict, me: str) -> dict:
    created = doc.get("created_at")
    return {
        "id": str(doc["_id"]),
        "text": doc.get("text", ""),
        "sender_id": doc.get("sender_id", ""),
        "is_mine": doc.get("sender_id") == me,
        "created_at": created.isoformat() if created else "",
    }


async def _conversation_for(db, conversation_id: str, me: str) -> dict:
    """Fetch a conversation and assert the caller is one of its two members."""
    convo = await db.select_conversations.find_one({"_id": _oid(conversation_id)})
    if not convo:
        raise HTTPException(status_code=404, detail="Conversation not found")
    if me not in (convo.get("customer_id"), convo.get("professional_user_id")):
        raise HTTPException(status_code=403, detail="Not your conversation")
    return convo


class StartConversationBody(BaseModel):
    professional_id: str


@router.post("/conversations", status_code=201)
async def start_conversation(
    body: StartConversationBody,
    current_user: dict = Depends(get_current_user),
):
    """Start a chat with a professional, or return the existing thread.
    Idempotent — tapping Enquire repeatedly never creates duplicates."""
    db = get_db()
    me: str = current_user["_id"]

    pro = await db.select_professionals.find_one({"_id": _oid(body.professional_id)})
    if not pro:
        raise HTTPException(status_code=404, detail="Professional not found")
    if pro.get("user_id") == me:
        raise HTTPException(status_code=400, detail="You can't message your own listing")

    existing = await db.select_conversations.find_one({
        "customer_id": me,
        "professional_id": str(pro["_id"]),
    })
    if existing:
        return {"conversation": _serialize_conversation(existing, me)}

    doc = {
        "customer_id": me,
        "customer_name": current_user.get("name", "Claimit user"),
        "professional_id": str(pro["_id"]),
        "professional_user_id": pro.get("user_id", ""),
        "professional_name": pro.get("name", ""),
        "professional_role": pro.get("role", ""),
        "professional_photo_s3_key": pro.get("photo_s3_key", ""),
        "last_message": "",
        "last_message_at": datetime.now(timezone.utc),
        "unread": {"customer": 0, "professional": 0},
        "created_at": datetime.now(timezone.utc),
    }
    result = await db.select_conversations.insert_one(doc)
    doc["_id"] = result.inserted_id
    return {"conversation": _serialize_conversation(doc, me)}


@router.get("/conversations")
async def list_conversations(current_user: dict = Depends(get_current_user)):
    """Every thread the caller is part of — as customer or as professional —
    most recently active first."""
    db = get_db()
    me: str = current_user["_id"]
    docs = (
        await db.select_conversations.find({
            "$or": [{"customer_id": me}, {"professional_user_id": me}],
        })
        .sort("last_message_at", -1)
        .to_list(length=200)
    )
    return {"conversations": [_serialize_conversation(d, me) for d in docs]}


@router.get("/conversations/{conversation_id}/messages")
async def list_messages(
    conversation_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Messages oldest-first, and marks the caller's side as read."""
    db = get_db()
    me: str = current_user["_id"]
    convo = await _conversation_for(db, conversation_id, me)

    docs = (
        await db.select_messages.find({"conversation_id": conversation_id})
        .sort("created_at", 1)
        .to_list(length=500)
    )

    # Opening the thread clears this side's unread badge.
    side = "customer" if convo.get("customer_id") == me else "professional"
    await db.select_conversations.update_one(
        {"_id": convo["_id"]}, {"$set": {f"unread.{side}": 0}}
    )

    return {"messages": [_serialize_message(d, me) for d in docs]}


class SendMessageBody(BaseModel):
    text: str


@router.post("/conversations/{conversation_id}/messages", status_code=201)
async def send_message(
    conversation_id: str,
    body: SendMessageBody,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    me: str = current_user["_id"]
    convo = await _conversation_for(db, conversation_id, me)

    text = (body.text or "").strip()[:2000]
    if not text:
        raise HTTPException(status_code=400, detail="Message is empty")

    now = datetime.now(timezone.utc)
    doc = {
        "conversation_id": conversation_id,
        "sender_id": me,
        "text": text,
        "created_at": now,
    }
    result = await db.select_messages.insert_one(doc)
    doc["_id"] = result.inserted_id

    # Bump the thread and raise the *other* side's unread badge.
    other_side = "professional" if convo.get("customer_id") == me else "customer"
    await db.select_conversations.update_one(
        {"_id": convo["_id"]},
        {
            "$set": {"last_message": text, "last_message_at": now},
            "$inc": {f"unread.{other_side}": 1},
        },
    )

    return {"message": _serialize_message(doc, me)}
