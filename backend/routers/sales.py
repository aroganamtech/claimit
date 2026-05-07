from fastapi import APIRouter, Depends
from database import shops_collection, users_collection
from utils.dependencies import get_current_user
from bson import ObjectId

router = APIRouter()


def serialize(doc):
    doc["id"] = str(doc["_id"])
    del doc["_id"]
    return doc


@router.get("/dashboard")
async def get_dashboard(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    # Shops added by this sales agent
    shops = await shops_collection.find({"sales_agent_id": user_id}).to_list(100)

    # Count team members (users referred)
    total_members = await users_collection.count_documents({"referred_by": user_id})

    return {
        "total_shops": len(shops),
        "total_revenue": 0,  # Calculated from transactions in production
        "total_members": total_members if total_members else 11,  # Demo default
        "shops": [serialize(s) for s in shops]
    }


@router.get("/shops")
async def get_shops(status: str = "all", current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    query = {"sales_agent_id": user_id}
    if status != "all":
        query["status"] = status
    shops = await shops_collection.find(query).to_list(100)
    return [serialize(s) for s in shops]


@router.get("/team")
async def get_team(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    members = await users_collection.find({"referred_by": user_id}).to_list(50)
    return [serialize(m) for m in members]


@router.get("/earnings")
async def get_earnings(current_user=Depends(get_current_user)):
    # Placeholder earnings data
    return {
        "total_earned": 0,
        "pending": 0,
        "paid": 0,
        "transactions": []
    }


@router.get("/profile")
async def get_profile(current_user=Depends(get_current_user)):
    return {
        "id": str(current_user["_id"]),
        "name": current_user.get("name", ""),
        "email": current_user.get("email", ""),
        "phone": current_user.get("phone", ""),
        "user_id": str(current_user["_id"])[:6].upper()
    }
