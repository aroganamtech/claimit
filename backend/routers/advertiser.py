from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, Form
from database import ads_collection, users_collection
from models.schemas import AdCreate, AdType
from utils.dependencies import get_current_user
from bson import ObjectId
from datetime import datetime, timedelta
from typing import Optional
import os

router = APIRouter()

AD_PRICES = {
    "home_banner": 840,
    "promo_reelz": 1400,
    "brand_deals": 1400,
    "nearby_deals": 1400,
}


def serialize_ad(ad):
    ad["id"] = str(ad["_id"])
    del ad["_id"]
    return ad


@router.get("/dashboard")
async def get_dashboard(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    ads = await ads_collection.find({"user_id": user_id}).to_list(100)
    total_views = sum(a.get("views", 0) for a in ads)
    total_clicks = sum(a.get("clicks", 0) for a in ads)
    return {
        "total_ads": len(ads),
        "total_views": total_views,
        "total_clicks": total_clicks,
        "ads": [serialize_ad(a) for a in ads]
    }


@router.get("/ads")
async def get_ads(status: Optional[str] = None, current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    query = {"user_id": user_id}
    if status and status != "all":
        query["status"] = status
    ads = await ads_collection.find(query).to_list(100)
    return [serialize_ad(a) for a in ads]


@router.post("/ads/create")
async def create_ad(
    ad_type: str = Form(...),
    title: str = Form(...),
    description: str = Form(...),
    pincode: str = Form(...),
    publish_today: bool = Form(True),
    scheduled_date: Optional[str] = Form(None),
    creative: Optional[UploadFile] = File(None),
    current_user=Depends(get_current_user)
):
    user_id = str(current_user["_id"])
    amount = AD_PRICES.get(ad_type, 1400)

    if publish_today:
        pub_date = datetime.utcnow()
    else:
        pub_date = datetime.strptime(scheduled_date, "%d/%m/%Y") if scheduled_date else datetime.utcnow()

    end_date = pub_date + timedelta(days=7)

    creative_url = None
    if creative:
        # Save file logic - in production use S3/Cloudinary
        upload_dir = "uploads"
        os.makedirs(upload_dir, exist_ok=True)
        file_path = f"{upload_dir}/{creative.filename}"
        content = await creative.read()
        with open(file_path, "wb") as f:
            f.write(content)
        creative_url = f"/uploads/{creative.filename}"

    ad_doc = {
        "user_id": user_id,
        "ad_type": ad_type,
        "title": title,
        "description": description,
        "pincode": pincode,
        "publish_date": pub_date.strftime("%d/%m/%Y"),
        "end_date": end_date.strftime("%d/%m/%Y"),
        "amount": amount,
        "status": "scheduled" if not publish_today else "active",
        "views": 0,
        "clicks": 0,
        "creative_url": creative_url,
        "created_at": datetime.utcnow()
    }

    result = await ads_collection.insert_one(ad_doc)
    ad_doc["id"] = str(result.inserted_id)
    del ad_doc["_id"]
    return ad_doc


@router.get("/profile")
async def get_profile(current_user=Depends(get_current_user)):
    return {
        "id": str(current_user["_id"]),
        "name": current_user.get("name", ""),
        "email": current_user.get("email", ""),
        "phone": current_user.get("phone", ""),
        "role": current_user.get("role", "")
    }
