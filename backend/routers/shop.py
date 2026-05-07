from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from database import shops_collection, transactions_collection
from models.schemas import OfferUpdateRequest, StoreUpdateRequest
from utils.dependencies import get_current_user
from bson import ObjectId
from datetime import datetime
from typing import Optional
import os

router = APIRouter()


def serialize(doc):
    doc["id"] = str(doc["_id"])
    del doc["_id"]
    if "created_at" in doc:
        doc["created_at"] = str(doc["created_at"])
    return doc


@router.post("/register")
async def register_shop(
    shop_name: str = Form(...),
    shop_address: str = Form(...),
    pincode: str = Form(...),
    lat: Optional[float] = Form(None),
    lng: Optional[float] = Form(None),
    about: str = Form(...),
    category: str = Form(...),
    shop_type: str = Form(...),
    discount_percentage: int = Form(15),
    cover_photo: Optional[UploadFile] = File(None),
    shop_photos: Optional[UploadFile] = File(None),
    current_user=Depends(get_current_user)
):
    user_id = str(current_user["_id"])

    # Handle photo uploads
    cover_url = None
    if cover_photo:
        upload_dir = "uploads/shops"
        os.makedirs(upload_dir, exist_ok=True)
        file_path = f"{upload_dir}/{cover_photo.filename}"
        content = await cover_photo.read()
        with open(file_path, "wb") as f:
            f.write(content)
        cover_url = f"/uploads/shops/{cover_photo.filename}"

    shop_doc = {
        "user_id": user_id,
        "shop_name": shop_name,
        "shop_address": shop_address,
        "pincode": pincode,
        "lat": lat,
        "lng": lng,
        "about": about,
        "category": category,
        "shop_type": shop_type,
        "discount_percentage": discount_percentage,
        "cover_photo": cover_url,
        "status": "pending",
        "total_reward_given": 0,
        "total_redeem_used": 0,
        "created_at": datetime.utcnow()
    }

    existing = await shops_collection.find_one({"user_id": user_id})
    if existing:
        await shops_collection.update_one({"user_id": user_id}, {"$set": shop_doc})
        shop_doc["id"] = str(existing["_id"])
    else:
        result = await shops_collection.insert_one(shop_doc)
        shop_doc["id"] = str(result.inserted_id)
        if "_id" in shop_doc:
            del shop_doc["_id"]

    return shop_doc


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
            "redeems": []
        }

    # Get transactions
    txns = await transactions_collection.find({"shop_id": str(shop["_id"])}).to_list(50)

    rewards = [t for t in txns if t.get("type") == "reward"]
    redeems = [t for t in txns if t.get("type") == "redeem"]

    # Demo data if empty
    if not txns:
        demo_customers = ["Arun", "Aruna", "Sabari", "Sam", "dhanush", "Arvind"]
        rewards = [{"customer": c, "reward_points": 500, "bill_amount": 580, "date": "18/12/2025"} for c in demo_customers]
        redeems = [{"customer": c, "redeemed": 500, "bill_amount": 580, "date": "18/12/2025"} for c in demo_customers]

    return {
        "shop": serialize(shop),
        "total_reward_given": shop.get("total_reward_given", 42),
        "total_redeem_used": shop.get("total_redeem_used", 35),
        "rewards": rewards,
        "redeems": redeems
    }


@router.put("/offer")
async def update_offer(request: OfferUpdateRequest, current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    result = await shops_collection.update_one(
        {"user_id": user_id},
        {"$set": {"discount_percentage": request.discount_percentage}}
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Shop not found")
    return {"message": "Offer updated successfully", "discount_percentage": request.discount_percentage}


@router.get("/offer")
async def get_offer(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    shop = await shops_collection.find_one({"user_id": user_id})
    if not shop:
        return {"discount_percentage": 15}
    return {"discount_percentage": shop.get("discount_percentage", 15)}


@router.put("/store-details")
async def update_store_details(request: StoreUpdateRequest, current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    update_data = {k: v for k, v in request.dict().items() if v is not None}
    await shops_collection.update_one({"user_id": user_id}, {"$set": update_data})
    return {"message": "Store details updated"}


@router.get("/store-details")
async def get_store_details(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    shop = await shops_collection.find_one({"user_id": user_id})
    if not shop:
        raise HTTPException(status_code=404, detail="Shop not found")
    return serialize(shop)


@router.get("/ratings")
async def get_ratings(current_user=Depends(get_current_user)):
    # Demo ratings data
    return {
        "average_rating": 4.5,
        "total_reviews": 42,
        "positive_percentage": 94,
        "reviews": [
            {"name": "Varunn", "date": "08/08/2025", "rating": 3, "comment": "Good store with decent variety. Staff was helpful and the offers were attractive."},
            {"name": "Arun", "date": "08/08/2025", "rating": 4, "comment": "Great shopping experience. The cashback rewards are a nice touch. Will visit again."},
            {"name": "Tharun", "date": "08/08/2025", "rating": 5, "comment": "Excellent store! Best deals in the area. The loyalty program is fantastic."},
        ]
    }


@router.post("/ratings/reply")
async def reply_to_review(review_id: str, reply: str, current_user=Depends(get_current_user)):
    return {"message": "Reply posted successfully"}


@router.get("/settings")
async def get_settings(current_user=Depends(get_current_user)):
    return {
        "email": current_user.get("email", ""),
        "phone": current_user.get("phone", ""),
        "annual_price": 999,
        "next_renewal": "08/12/2026"
    }
