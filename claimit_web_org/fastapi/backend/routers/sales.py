from fastapi import APIRouter, Depends, HTTPException, Query
from database import shops_collection, users_collection, team_collection, transactions_collection
from models.schemas import SalesShopAdd
from utils.dependencies import get_current_user
from datetime import datetime
from typing import Optional

router = APIRouter()


def serialize(doc):
    doc["id"] = str(doc["_id"])
    del doc["_id"]
    if "created_at" in doc and doc["created_at"]:
        doc["created_at"] = str(doc["created_at"])
    return doc


# ── Helper: shops visible to a sales user ─────────────────────
async def get_all_shops_for_user(user_id: str, user_email: str, status_filter: str = "all"):
    q_sales = {"sales_agent_id": user_id}
    if status_filter != "all":
        q_sales["status"] = status_filter
    sales_shops = await shops_collection.find(q_sales).to_list(200)

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

    seen, merged = set(), []
    for s in sales_shops + email_shops:
        sid = str(s["_id"])
        if sid not in seen:
            seen.add(sid)
            merged.append(s)
    return merged


# ── Dashboard ─────────────────────────────────────────────────
@router.get("/dashboard")
async def get_dashboard(
    email: Optional[str] = Query(None),
    current_user=Depends(get_current_user)
):
    user_id   = str(current_user["_id"])
    user_email = email or current_user.get("email", "")
    shops      = await get_all_shops_for_user(user_id, user_email)

    # If Sales Head → also count executives under them
    unique_id    = current_user.get("unique_id", "")
    sub_role     = current_user.get("sub_role", "")
    team_count   = 0
    if sub_role == "sales_head" and unique_id:
        team_count = await users_collection.count_documents(
            {"referred_by": unique_id, "role": "sales"}
        )
    else:
        team_count = await team_collection.count_documents({"sales_agent_id": user_id})

    shop_ids = [str(s["_id"]) for s in shops]
    revenue  = 0.0
    if shop_ids:
        async for t in transactions_collection.find({"shop_id": {"$in": shop_ids}}):
            revenue += float(t.get("bill_amount", 0))

    return {
        "total_shops":   len(shops),
        "total_revenue": revenue,
        "total_members": team_count,
        "unique_id":     unique_id,
        "sub_role":      sub_role,
        "shops": [serialize(s) for s in shops],
    }


# ── Shops list ────────────────────────────────────────────────
@router.get("/shops")
async def list_shops(
    status: str = "all",
    email: Optional[str] = Query(None),
    current_user=Depends(get_current_user)
):
    user_id    = str(current_user["_id"])
    user_email = email or current_user.get("email", "")
    shops      = await get_all_shops_for_user(user_id, user_email, status)
    return [serialize(s) for s in shops]


@router.post("/shops/add")
async def add_shop(payload: SalesShopAdd, current_user=Depends(get_current_user)):
    user_id   = str(current_user["_id"])
    unique_id = current_user.get("unique_id", "")
    shop_doc  = {
        "sales_agent_id":  user_id,
        "sales_unique_id": unique_id,          # employee unique ID for tracking
        "sales_sub_role":  current_user.get("sub_role", ""),
        "shop_name":       payload.shop_name,
        "shop_address":    payload.shop_address,
        "category":        payload.category,
        "pincode":         payload.pincode or "",
        "lat":             payload.lat,
        "lng":             payload.lng,
        "status":          "pending",
        "discount_percentage": 0,
        "created_at":      datetime.utcnow(),
    }
    res = await shops_collection.insert_one(shop_doc)
    shop_doc["id"] = str(res.inserted_id)
    del shop_doc["_id"]
    return shop_doc


# ── Team ──────────────────────────────────────────────────────
@router.get("/team")
async def get_team(current_user=Depends(get_current_user)):
    """
    Sales Head sees executives registered under their unique_id.
    Others see their invited team members.
    """
    unique_id = current_user.get("unique_id", "")
    sub_role  = current_user.get("sub_role", "")

    if sub_role == "sales_head" and unique_id:
        # All executives who gave this head's ID during registration
        members = await users_collection.find(
            {"referred_by": unique_id, "role": "sales"}
        ).to_list(200)
        return [
            {
                "id":        str(m["_id"]),
                "name":      m.get("name", ""),
                "phone":     m.get("phone", ""),
                "email":     m.get("email", ""),
                "unique_id": m.get("unique_id", ""),
                "sub_role":  m.get("sub_role", ""),
                "created_at": str(m.get("created_at", "")),
                "total_shops": await shops_collection.count_documents(
                    {"sales_agent_id": str(m["_id"])}
                ),
            }
            for m in members
        ]

    user_id = str(current_user["_id"])
    members = await team_collection.find({"sales_agent_id": user_id}).to_list(100)
    return [serialize(m) for m in members]


@router.post("/team/invite")
async def invite_team_member(name: str, email: str, phone: str, current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    doc = {
        "sales_agent_id": user_id,
        "name":  name,
        "email": email,
        "phone": phone,
        "joined": False,
        "created_at": datetime.utcnow(),
    }
    res = await team_collection.insert_one(doc)
    doc["id"] = str(res.inserted_id)
    del doc["_id"]
    return doc


# ── Earnings ──────────────────────────────────────────────────
@router.get("/earnings")
async def get_earnings(current_user=Depends(get_current_user)):
    user_id    = str(current_user["_id"])
    user_email = current_user.get("email", "")
    shops      = await get_all_shops_for_user(user_id, user_email)
    shop_ids   = [str(s["_id"]) for s in shops]

    total_revenue = 0.0
    if shop_ids:
        async for t in transactions_collection.find({"shop_id": {"$in": shop_ids}}):
            total_revenue += float(t.get("bill_amount", 0))

    earned  = round(total_revenue * 0.01)
    paid    = round(earned * 0.5)
    pending = earned - paid

    return {
        "total_earned": earned,
        "pending":      pending,
        "paid":         paid,
        "transactions": [],
    }


# ── Profile ───────────────────────────────────────────────────
@router.get("/profile")
async def get_profile(current_user=Depends(get_current_user)):
    uid = str(current_user["_id"])
    return {
        "id":        uid,
        "unique_id": current_user.get("unique_id") or uid[-6:].upper(),
        "sub_role":  current_user.get("sub_role", ""),
        "name":      current_user.get("name", ""),
        "email":     current_user.get("email", ""),
        "phone":     current_user.get("phone", ""),
        "referred_by": current_user.get("referred_by", ""),
    }


# ── Admin: list all sales employees (called by admin panel) ───
@router.get("/all-employees")
async def list_all_employees(current_user=Depends(get_current_user)):
    """Super admin view — all sales employees with unique IDs."""
    employees = await users_collection.find({"role": "sales"}).to_list(500)
    result = []
    for e in employees:
        eid = str(e["_id"])
        shop_count = await shops_collection.count_documents({"sales_agent_id": eid})
        result.append({
            "id":          eid,
            "name":        e.get("name", ""),
            "phone":       e.get("phone", ""),
            "email":       e.get("email", ""),
            "unique_id":   e.get("unique_id", ""),
            "sub_role":    e.get("sub_role", ""),
            "referred_by": e.get("referred_by", ""),
            "created_at":  str(e.get("created_at", "")),
            "total_shops": shop_count,
        })
    return result
