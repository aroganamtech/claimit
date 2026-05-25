from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from database import (
    shops_collection, transactions_collection, reviews_collection,
)
from models.schemas import OfferUpdateRequest, StoreUpdateRequest, ReviewCreate, ReviewReplyRequest, GalleryPhotoRequest
from utils.dependencies import get_current_user
from bson import ObjectId
from datetime import datetime, timedelta
from typing import Optional, List
import base64
import json

router = APIRouter()


def serialize(doc):
    doc["id"] = str(doc["_id"])
    del doc["_id"]
    if "created_at" in doc and doc["created_at"]:
        doc["created_at"] = str(doc["created_at"])
    return doc


# ─── Register shop (called from onboarding wizard) ────────────
@router.post("/register")
async def register_shop(
    shop_name: str = Form(...),
    shop_address: str = Form(...),
    pincode: str = Form(...),
    lat: Optional[float] = Form(None),
    lng: Optional[float] = Form(None),
    about: str = Form(""),
    category: str = Form(...),
    shop_type: str = Form(...),
    discount_percentage: int = Form(15),
    current_user=Depends(get_current_user),
):
    user_id = str(current_user["_id"])
    user_email = current_user.get("email", "")

    shop_doc = {
        "user_id": user_id,
        "user_email": user_email,
        "shop_name": shop_name,
        "shop_address": shop_address,
        "pincode": pincode,
        "lat": lat,
        "lng": lng,
        "about": about,
        "category": category,
        "shop_type": shop_type,
        "discount_percentage": discount_percentage,
        "cover_photo_b64": None,
        "gallery_photos": [],
        "status": "pending",
        "total_reward_given": 0,
        "total_redeem_used": 0,
        "created_at": datetime.utcnow(),
    }

    existing = await shops_collection.find_one({"user_id": user_id})
    if existing:
        # Preserve existing images — only update non-image fields on re-register
        update_fields = {k: v for k, v in shop_doc.items()
                         if k not in ("cover_photo_b64", "gallery_photos", "created_at")}
        await shops_collection.update_one(
            {"user_id": user_id}, {"$set": update_fields}
        )
        shop_doc["id"] = str(existing["_id"])
    else:
        result = await shops_collection.insert_one(shop_doc)
        shop_doc["id"] = str(result.inserted_id)
    if "_id" in shop_doc:
        del shop_doc["_id"]
    return {"ok": True, "shop": shop_doc}


# ─── Dashboard ────────────────────────────────────────────────
@router.get("/dashboard")
async def get_dashboard(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    shop = await shops_collection.find_one({"user_id": user_id})
    if not shop:
        return {
            "shop": None,
            "total_reward_given": 0,
            "total_redeem_used": 0,
            "rewards": [],
            "redeems": [],
        }

    shop_id = str(shop["_id"])
    txns = await transactions_collection.find({"shop_id": shop_id}).to_list(200)

    rewards = [
        {
            "customer": t.get("customer", ""),
            "reward_points": t.get("reward_points", 0),
            "bill_amount": t.get("bill_amount", 0),
            "date": t.get("date", ""),
        }
        for t in txns if t.get("type") == "reward"
    ]
    redeems = [
        {
            "customer": t.get("customer", ""),
            "redeemed": t.get("redeemed", 0),
            "bill_amount": t.get("bill_amount", 0),
            "date": t.get("date", ""),
        }
        for t in txns if t.get("type") == "redeem"
    ]

    return {
        "shop": serialize(shop),
        "total_reward_given": len(rewards),
        "total_redeem_used": len(redeems),
        "rewards": rewards,
        "redeems": redeems,
    }


# ─── Offer ────────────────────────────────────────────────────
@router.put("/offer")
async def update_offer(request: OfferUpdateRequest, current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    result = await shops_collection.update_one(
        {"user_id": user_id},
        {"$set": {"discount_percentage": request.discount_percentage}}
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Shop not found")
    return {"discount_percentage": request.discount_percentage}


@router.get("/offer")
async def get_offer(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    shop = await shops_collection.find_one({"user_id": user_id})
    if not shop:
        return {"discount_percentage": 0}
    return {"discount_percentage": shop.get("discount_percentage", 0)}


# ─── Store Details ────────────────────────────────────────────
@router.put("/store-details")
async def update_store_details(request: StoreUpdateRequest, current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    update_data = {k: v for k, v in request.dict().items() if v is not None}
    if not update_data:
        return {"message": "Nothing to update"}
    res = await shops_collection.update_one({"user_id": user_id}, {"$set": update_data})
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="Shop not found")
    return {"message": "Store details updated", "patch": update_data}


@router.get("/store-details")
async def get_store_details(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    shop = await shops_collection.find_one({"user_id": user_id})
    if not shop:
        # Return empty fields rather than 404 so the page can render an empty state.
        return {
            "shop_name": "", "about": "", "shop_address": "",
            "geo_location": "", "category": "", "shop_type": "",
        }
    return serialize(shop)


# ─── Ratings & Reviews (NO MORE static demo) ──────────────────
@router.get("/ratings")
async def get_ratings(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    shop = await shops_collection.find_one({"user_id": user_id})
    if not shop:
        return {"average_rating": 0, "total_reviews": 0, "positive_percentage": 0, "reviews": []}
    shop_id = str(shop["_id"])

    reviews = await reviews_collection.find({"shop_id": shop_id}).sort("date", -1).to_list(200)
    if not reviews:
        return {"average_rating": 0, "total_reviews": 0, "positive_percentage": 0, "reviews": []}

    total = len(reviews)
    avg = sum(r.get("rating", 0) for r in reviews) / total
    positive = sum(1 for r in reviews if r.get("rating", 0) >= 4)

    return {
        "average_rating": round(avg, 1),
        "total_reviews": total,
        "positive_percentage": round((positive / total) * 100),
        "reviews": [
            {
                "id": str(r["_id"]),
                "name": r.get("name", ""),
                "rating": r.get("rating", 0),
                "comment": r.get("comment", ""),
                "date": r.get("date", ""),
                "reply": r.get("reply", ""),
            } for r in reviews
        ],
    }


@router.post("/ratings")
async def add_review(request: ReviewCreate):
    """Public-facing endpoint a customer app would call to leave a review."""
    doc = {
        "shop_id": request.shop_id,
        "name": request.name,
        "rating": request.rating,
        "comment": request.comment,
        "date": datetime.utcnow().strftime("%d/%m/%Y"),
        "created_at": datetime.utcnow(),
        "reply": "",
    }
    res = await reviews_collection.insert_one(doc)
    doc["id"] = str(res.inserted_id)
    del doc["_id"]
    return doc


@router.post("/ratings/reply")
async def reply_to_review(request: ReviewReplyRequest, current_user=Depends(get_current_user)):
    try:
        oid = ObjectId(request.review_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid review id")
    res = await reviews_collection.update_one(
        {"_id": oid},
        {"$set": {"reply": request.reply, "replied_at": datetime.utcnow()}},
    )
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="Review not found")
    return {"message": "Reply posted"}


# ─── Gallery Photos ───────────────────────────────────────────
@router.get("/gallery")
async def get_gallery(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    shop = await shops_collection.find_one({"user_id": user_id})
    if not shop:
        return {"cover_photo_b64": None, "gallery_photos": []}
    return {
        "cover_photo_b64": shop.get("cover_photo_b64"),
        "gallery_photos": shop.get("gallery_photos", []),
    }


@router.post("/gallery/cover")
async def upload_cover_photo(request: GalleryPhotoRequest, current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    res = await shops_collection.update_one(
        {"user_id": user_id},
        {"$set": {"cover_photo_b64": request.photo_b64}}
    )
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="Shop not found")
    return {"ok": True}


@router.post("/gallery/add")
async def add_gallery_photo(request: GalleryPhotoRequest, current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    res = await shops_collection.update_one(
        {"user_id": user_id},
        {"$push": {"gallery_photos": request.photo_b64}}
    )
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="Shop not found")
    return {"ok": True}


@router.delete("/gallery/{index}")
async def delete_gallery_photo(index: int, current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    shop = await shops_collection.find_one({"user_id": user_id})
    if not shop:
        raise HTTPException(status_code=404, detail="Shop not found")
    gallery = shop.get("gallery_photos", [])
    if index < 0 or index >= len(gallery):
        raise HTTPException(status_code=400, detail="Invalid photo index")
    gallery.pop(index)
    await shops_collection.update_one(
        {"user_id": user_id},
        {"$set": {"gallery_photos": gallery}}
    )
    return {"ok": True}


# ─── Settings ─────────────────────────────────────────────────
@router.get("/settings")
async def get_settings(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    shop = await shops_collection.find_one({"user_id": user_id})
    next_renewal = ""
    if shop and shop.get("created_at"):
        renewal = shop["created_at"] + timedelta(days=365)
        next_renewal = renewal.strftime("%d/%m/%Y")
    return {
        "email": current_user.get("email", ""),
        "phone": current_user.get("phone", ""),
        "annual_price": 999,
        "next_renewal": next_renewal,
    }
