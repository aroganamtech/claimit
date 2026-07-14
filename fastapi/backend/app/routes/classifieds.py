"""
Classifieds routes — local service & buy-sell postings, and Local Finds
business listings (same collection, distinguished by `listing_type`).

Endpoints
─────────
GET    /classifieds              → list (filter: category, subcategory, pincode)
GET    /classifieds/mine         → the current user's own posts (auth required)
GET    /classifieds/{id}         → single post
POST   /classifieds              → create post (auth required)
PATCH  /classifieds/{id}         → edit post fields (owner only)
PATCH  /classifieds/{id}/toggle  → toggle availability (owner only)
DELETE /classifieds/{id}         → delete post (owner only)
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from typing import Optional, List
from bson import ObjectId
from datetime import datetime, timezone

from ..database import get_db
from ..utils.auth import get_current_user

router = APIRouter(prefix="/classifieds", tags=["classifieds"])


def _oid(id_str: str) -> ObjectId:
    try:
        return ObjectId(id_str)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid id")


def _serialize(doc: dict) -> dict:
    doc["id"] = str(doc.pop("_id"))
    return doc


# ── List ──────────────────────────────────────────────────────────────────────

@router.get("")
async def list_classifieds(
    category: Optional[str] = Query(None),
    subcategory: Optional[str] = Query(None),
    pincode: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    limit: int = Query(default=20, le=50),
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    query: dict = {}
    if category:
        query["category"] = category
    if subcategory:
        query["subcategory"] = {"$regex": f"^{subcategory}$", "$options": "i"}
    if pincode:
        query["pincode"] = pincode
    if search:
        query["$or"] = [
            {"title": {"$regex": search, "$options": "i"}},
            {"user_name": {"$regex": search, "$options": "i"}},
        ]

    cursor = db["classifieds"].find(query).sort("created_at", -1).limit(limit)
    docs = await cursor.to_list(length=limit)
    return {"classifieds": [_serialize(d) for d in docs], "total": len(docs)}


# ── Mine ──────────────────────────────────────────────────────────────────────
# Must be defined BEFORE GET /{classified_id} so FastAPI doesn't try to parse
# the literal "mine" path segment as an ObjectId.

@router.get("/mine")
async def list_my_classifieds(
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    cursor = (
        db["classifieds"]
        .find({"user_id": current_user["_id"]})
        .sort("created_at", -1)
    )
    docs = await cursor.to_list(length=200)
    return {"classifieds": [_serialize(d) for d in docs], "total": len(docs)}


# ── Single ────────────────────────────────────────────────────────────────────

@router.get("/{classified_id}")
async def get_classified(
    classified_id: str,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    doc = await db["classifieds"].find_one({"_id": _oid(classified_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Not found")
    return {"classified": _serialize(doc)}


# ── Create ────────────────────────────────────────────────────────────────────

class CreateClassifiedRequest(BaseModel):
    category: str
    subcategory: str = ""
    title: str
    description: str
    price: float = 0
    years_of_exp: int = 0
    pincode: str = ""
    area: str = ""
    address: str = ""
    payment_method: str = "Credit/Debit Card"
    photos: List[str] = []   # S3 keys (uploaded via /classifieds/upload-photo)

    # "classified" = Local Classifieds item/service post (fee Rs.250)
    # "local_find" = Local Finds business directory listing (fee Rs.730/year)
    listing_type: str = "classified"
    business_name: str = ""       # Local Finds only
    whatsapp: str = ""            # Local Finds only (optional)
    latitude: Optional[float] = None
    longitude: Optional[float] = None

    # Cashfree payment reference captured once the listing fee is paid —
    # set by the app after /payments/status/{link_id} returns "PAID".
    payment_link_id: str = ""
    amount_paid: float = 0


@router.post("", status_code=201)
async def create_classified(
    body: CreateClassifiedRequest,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    doc = {
        "user_id": current_user["_id"],
        "user_name": current_user.get("name", "User"),
        "user_phone": current_user.get("phone", ""),
        "category": body.category,
        "subcategory": body.subcategory,
        "title": body.title,
        "description": body.description,
        "price": body.price,
        "years_of_exp": body.years_of_exp,
        "pincode": body.pincode,
        "area": body.area,
        "address": body.address,
        "payment_method": body.payment_method,
        "photos": body.photos,   # list of S3 keys
        "listing_type": body.listing_type,
        "business_name": body.business_name,
        "whatsapp": body.whatsapp,
        "latitude": body.latitude,
        "longitude": body.longitude,
        "payment_link_id": body.payment_link_id,
        "amount_paid": body.amount_paid,
        "is_available": True,
        "created_at": datetime.now(timezone.utc),
    }
    result = await db["classifieds"].insert_one(doc)
    doc["id"] = str(result.inserted_id)
    doc.pop("_id", None)
    return {"classified": doc, "message": "Post published successfully"}


# ── Toggle availability ───────────────────────────────────────────────────────

@router.patch("/{classified_id}/toggle")
async def toggle_availability(
    classified_id: str,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    oid = _oid(classified_id)
    doc = await db["classifieds"].find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="Not found")
    if str(doc.get("user_id", "")) != current_user["_id"]:
        raise HTTPException(status_code=403, detail="Not your post")

    new_status = not doc.get("is_available", True)
    await db["classifieds"].update_one(
        {"_id": oid}, {"$set": {"is_available": new_status}}
    )
    return {"is_available": new_status}


# ── Edit (owner only) ────────────────────────────────────────────────────────
# Every field is optional here — only the ones the app actually sends get
# updated, everything else on the existing document is left untouched.

class UpdateClassifiedRequest(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = None
    years_of_exp: Optional[int] = None
    subcategory: Optional[str] = None
    pincode: Optional[str] = None
    area: Optional[str] = None
    address: Optional[str] = None
    business_name: Optional[str] = None
    whatsapp: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    photos: Optional[List[str]] = None


@router.patch("/{classified_id}")
async def update_classified(
    classified_id: str,
    body: UpdateClassifiedRequest,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    oid = _oid(classified_id)
    doc = await db["classifieds"].find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="Not found")
    if str(doc.get("user_id", "")) != current_user["_id"]:
        raise HTTPException(status_code=403, detail="Not your post")

    updates = {k: v for k, v in body.model_dump(exclude_unset=True).items()}
    if updates:
        await db["classifieds"].update_one({"_id": oid}, {"$set": updates})
    fresh = await db["classifieds"].find_one({"_id": oid})
    return {"classified": _serialize(fresh)}


# ── Delete (owner only) ──────────────────────────────────────────────────────

@router.delete("/{classified_id}")
async def delete_classified(
    classified_id: str,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    oid = _oid(classified_id)
    doc = await db["classifieds"].find_one({"_id": oid})
    if not doc:
        raise HTTPException(status_code=404, detail="Not found")
    if str(doc.get("user_id", "")) != current_user["_id"]:
        raise HTTPException(status_code=403, detail="Not your post")

    await db["classifieds"].delete_one({"_id": oid})
    return {"deleted": True}
