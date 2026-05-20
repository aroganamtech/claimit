"""
Shops endpoints — data served from MongoDB (seeded via seed.py).
Images are stored as base64 strings in the DB and returned in the JSON response.
"""
import base64
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, status, Query
from bson import ObjectId
from ..database import get_db
from ..utils.auth import get_current_user
from ..utils.helpers import serialize_doc

router = APIRouter(prefix="/shops", tags=["Shops"])


def _doc_to_response(doc: dict) -> dict:
    """Serialize a shop MongoDB document, keeping image_data as-is (base64 str)."""
    result = serialize_doc(doc)
    return result


@router.get("")
async def get_shops(
    category_id: Optional[int] = Query(None, description="Filter by category ID"),
    q: Optional[str] = Query(None, description="Search by name or location"),
    has_rewards: Optional[bool] = Query(None),
    has_redeem: Optional[bool] = Query(None),
    current_user: dict = Depends(get_current_user),
):
    """
    GET /shops
    Returns all shops. Optionally filtered by category, search term,
    has_rewards, or has_redeem.
    """
    db = get_db()
    query: dict = {}

    if category_id is not None:
        query["category_ids"] = category_id

    if has_rewards is not None:
        query["has_rewards"] = has_rewards

    if has_redeem is not None:
        query["has_redeem"] = has_redeem

    cursor = db.shops.find(query).sort("added_days_ago", 1)
    shops: List[dict] = await cursor.to_list(length=200)

    # Apply name/location search in-memory (small dataset)
    if q:
        q_lower = q.lower()
        shops = [
            s for s in shops
            if q_lower in s.get("name", "").lower()
            or q_lower in s.get("location", "").lower()
        ]

    return {
        "success": True,
        "shops": [_doc_to_response(s) for s in shops],
        "total": len(shops),
    }


@router.get("/search")
async def search_shops(
    q: str = Query(..., min_length=1),
    current_user: dict = Depends(get_current_user),
):
    """GET /shops/search?q=term — quick name/location search."""
    db = get_db()
    q_lower = q.lower()
    cursor = db.shops.find({})
    all_shops = await cursor.to_list(length=200)
    results = [
        s for s in all_shops
        if q_lower in s.get("name", "").lower()
        or q_lower in s.get("location", "").lower()
    ]
    return {
        "success": True,
        "shops": [_doc_to_response(s) for s in results],
        "total": len(results),
    }


@router.get("/{shop_id}")
async def get_shop(
    shop_id: str,
    current_user: dict = Depends(get_current_user),
):
    """GET /shops/{id} — single shop with full details including image_data."""
    db = get_db()
    try:
        oid = ObjectId(shop_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid shop ID")

    shop = await db.shops.find_one({"_id": oid})
    if not shop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shop not found")

    return {"success": True, "shop": _doc_to_response(shop)}


@router.get("/{shop_id}/image")
async def get_shop_image(
    shop_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    GET /shops/{id}/image
    Returns just the base64-encoded image string for the shop.
    Flutter can use: Image.memory(base64Decode(response['image_data']))
    """
    db = get_db()
    try:
        oid = ObjectId(shop_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid shop ID")

    shop = await db.shops.find_one({"_id": oid}, {"image_data": 1, "image_name": 1})
    if not shop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shop not found")

    return {
        "success": True,
        "shop_id": shop_id,
        "image_name": shop.get("image_name", ""),
        "image_data": shop.get("image_data", ""),
    }
