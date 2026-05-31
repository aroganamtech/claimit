from fastapi import APIRouter, Depends, HTTPException, Query
from app.database import shops_collection, users_collection, team_collection, transactions_collection
from app.models.schemas import SalesShopAdd
from app.utils.dependencies import get_current_user
from datetime import datetime
from typing import Optional

router = APIRouter()


def serialize(doc):
    doc["id"] = str(doc["_id"])
    del doc["_id"]
    if "created_at" in doc and doc["created_at"]:
        doc["created_at"] = str(doc["created_at"])
    return doc


# --- Helper: get all shops visible to a sales user ---
async def get_all_shops_for_user(user_id: str, user_email: str, status_filter: str = "all"):
    """
    Returns shops added by this sales agent PLUS shops registered through
    the shop portal by any user sharing the same email address.
    """
    q_sales = {"sales_agent_id": user_id}
    if status_filter != "all":
        q_sales["status"] = status_filter
    sales_shops = await shops_collection.find(q_sales).to_list(200)

    # Find shop-portal users with the same email
    email_shops = []
    if user_email:
        shop_users = await users_collection.find(
            {"email": user_email, "role": "shop"}
        ).to_list(100)
        if shop_users:
            shop_user_ids = [str(u["_id"]) for u in shop_users]
            q_email = {"user_id": {"$in": shop_user_ids}}
            if status_filter != "all":
                q_email["status"] = status_filter
            email_shops = await shops_collection.find(q_email).to_list(200)

    # Deduplicate by shop _id
    seen = set()
    merged = []
    for s in sales_shops + email_shops:
        sid = str(s["_id"])
        if sid not in seen:
            seen.add(sid)
            merged.append(s)
    return merged


# --- Dashboard ---
@router.get("/dashboard")
async def get_dashboard(
    email: Optional[str] = Query(None),
    current_user=Depends(get_current_user)
):
    user_id = str(current_user["_id"])
    # Use email from query param if sent by frontend, otherwise fall back to DB value
    user_email = email or current_user.get("email", "")
    shops = await get_all_shops_for_user(user_id, user_email)
    total_members = await team_collection.count_documents({"sales_agent_id": user_id})

    # Revenue = sum of bill amounts for txns at all visible shops
    shop_ids = [str(s["_id"]) for s in shops]
    revenue = 0.0
    if shop_ids:
        async for t in transactions_collection.find({"shop_id": {"$in": shop_ids}}):
            revenue += float(t.get("bill_amount", 0))

    return {
        "total_shops": len(shops),
        "total_revenue": revenue,
        "total_members": total_members,
        "shops": [serialize(s) for s in shops],
    }


# --- Shops list ---
@router.get("/shops")
async def list_shops(
    status: str = "all",
    email: Optional[str] = Query(None),
    current_user=Depends(get_current_user)
):
    user_id = str(current_user["_id"])
    user_email = email or current_user.get("email", "")
    shops = await get_all_shops_for_user(user_id, user_email, status)
    return [serialize(s) for s in shops]


@router.post("/shops/add")
async def add_shop(payload: SalesShopAdd, current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    shop_doc = {
        "sales_agent_id": user_id,
        "shop_name": payload.shop_name,
        "shop_address": payload.shop_address,
        "category": payload.category,
        "pincode": payload.pincode or "",
        "lat": payload.lat,
        "lng": payload.lng,
        "status": "pending",
        "discount_percentage": 0,
        "created_at": datetime.utcnow(),
    }
    res = await shops_collection.insert_one(shop_doc)
    shop_doc["id"] = str(res.inserted_id)
    del shop_doc["_id"]
    return shop_doc


# --- Team ---
@router.get("/team")
async def get_team(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    members = await team_collection.find({"sales_agent_id": user_id}).to_list(100)
    return [serialize(m) for m in members]


@router.post("/team/invite")
async def invite_team_member(name: str, email: str, phone: str, current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    doc = {
        "sales_agent_id": user_id,
        "name": name,
        "email": email,
        "phone": phone,
        "joined": False,
        "created_at": datetime.utcnow(),
    }
    res = await team_collection.insert_one(doc)
    doc["id"] = str(res.inserted_id)
    del doc["_id"]
    return doc


# --- Earnings ---
@router.get("/earnings")
async def get_earnings(current_user=Depends(get_current_user)):
    """1% of revenue from referred shops as commission."""
    user_id = str(current_user["_id"])
    user_email = current_user.get("email", "")
    shops = await get_all_shops_for_user(user_id, user_email)
    shop_ids = [str(s["_id"]) for s in shops]

    total_revenue = 0.0
    if shop_ids:
        async for t in transactions_collection.find({"shop_id": {"$in": shop_ids}}):
            total_revenue += float(t.get("bill_amount", 0))

    earned = round(total_revenue * 0.01)
    paid = round(earned * 0.5)
    pending = earned - paid

    return {
        "total_earned": earned,
        "pending": pending,
        "paid": paid,
        "transactions": [],
    }


# --- Profile ---
@router.get("/profile")
async def get_profile(current_user=Depends(get_current_user)):
    uid = str(current_user["_id"])
    return {
        "id": uid,
        "user_id": uid[-6:].upper(),
        "name": current_user.get("name", ""),
        "email": current_user.get("email", ""),
        "phone": current_user.get("phone", ""),
    }
