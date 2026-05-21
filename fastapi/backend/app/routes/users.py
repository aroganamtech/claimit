from fastapi import APIRouter, HTTPException, status, Depends, UploadFile, File
from datetime import datetime
from bson import ObjectId
import os
import aiofiles
from ..database import get_db
from ..utils.auth import get_current_user
from ..utils.helpers import serialize_doc
from ..models.user import UserUpdate, LocationUpdate
from ..config import get_settings

router = APIRouter(prefix="/users", tags=["Users"])
settings = get_settings()


@router.get("/profile")
async def get_profile(current_user: dict = Depends(get_current_user)):
    """Get current user profile including stored location."""
    return serialize_doc(current_user)


@router.put("/profile/update")
async def update_profile(
    update_data: UserUpdate,
    current_user: dict = Depends(get_current_user),
):
    """Update user profile fields."""
    db = get_db()
    user_id = current_user.get("_id") or current_user.get("id")

    update_dict = {k: v for k, v in update_data.model_dump().items() if v is not None}
    update_dict["updated_at"] = datetime.utcnow()

    if not update_dict:
        raise HTTPException(status_code=400, detail="No fields to update")

    await db.users.update_one(
        {"_id": ObjectId(str(user_id))},
        {"$set": update_dict},
    )

    updated_user = await db.users.find_one({"_id": ObjectId(str(user_id))})
    return serialize_doc(updated_user)


@router.post("/location")
async def update_location(
    data: LocationUpdate,
    current_user: dict = Depends(get_current_user),
):
    """Save the user's selected location (area / locality)."""
    db = get_db()
    user_id = current_user.get("_id") or current_user.get("id")

    await db.users.update_one(
        {"_id": ObjectId(str(user_id))},
        {"$set": {"location": data.location, "updated_at": datetime.utcnow()}},
    )

    updated_user = await db.users.find_one({"_id": ObjectId(str(user_id))})
    return {"success": True, "location": data.location, "user": serialize_doc(updated_user)}


@router.post("/avatar")
async def upload_avatar(
    avatar: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
):
    """Upload user avatar image."""
    user_id = current_user.get("_id") or current_user.get("id")

    allowed_types = ["image/jpeg", "image/png", "image/jpg"]
    if avatar.content_type not in allowed_types:
        raise HTTPException(status_code=400, detail="Only JPEG/PNG images allowed")

    content = await avatar.read()
    if len(content) > settings.max_file_size_mb * 1024 * 1024:
        raise HTTPException(
            status_code=400,
            detail=f"File size exceeds {settings.max_file_size_mb}MB limit",
        )

    upload_dir = os.path.join(settings.upload_dir, "avatars")
    os.makedirs(upload_dir, exist_ok=True)

    ext = avatar.filename.split(".")[-1]
    filename = f"{user_id}.{ext}"
    filepath = os.path.join(upload_dir, filename)

    async with aiofiles.open(filepath, "wb") as f:
        await f.write(content)

    avatar_url = f"/uploads/avatars/{filename}"

    db = get_db()
    await db.users.update_one(
        {"_id": ObjectId(str(user_id))},
        {"$set": {"avatar_url": avatar_url, "updated_at": datetime.utcnow()}},
    )

    return {"avatar_url": avatar_url, "success": True}


# ── Favourites ────────────────────────────────────────────────────────────────

@router.post("/favourites/{shop_id}")
async def toggle_favourite(
    shop_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    POST /users/favourites/{shop_id}
    Toggles like/unlike for a shop.
    Returns { liked: bool } — true = just liked, false = just unliked.
    """
    db = get_db()
    user_id = str(current_user.get("_id") or current_user.get("id"))
    liked_shop_ids = current_user.get("liked_shop_ids", [])

    if shop_id in liked_shop_ids:
        await db.users.update_one(
            {"_id": ObjectId(user_id)},
            {"$pull": {"liked_shop_ids": shop_id}},
        )
        return {"success": True, "liked": False, "shop_id": shop_id}
    else:
        await db.users.update_one(
            {"_id": ObjectId(user_id)},
            {"$addToSet": {"liked_shop_ids": shop_id}},
        )
        return {"success": True, "liked": True, "shop_id": shop_id}


@router.get("/favourites")
async def get_favourites(
    current_user: dict = Depends(get_current_user),
):
    """
    GET /users/favourites
    Returns full shop details for all liked shops.
    """
    db = get_db()
    liked_shop_ids: list = current_user.get("liked_shop_ids", [])

    shops = []
    for shop_id in liked_shop_ids:
        try:
            shop = await db.shops.find_one({"_id": ObjectId(shop_id)})
            if shop:
                shops.append(serialize_doc(shop))
        except Exception:
            pass  # skip invalid ids silently

    return {"success": True, "shops": shops, "total": len(shops)}


@router.get("/liked-ids")
async def get_liked_ids(
    current_user: dict = Depends(get_current_user),
):
    """
    GET /users/liked-ids
    Returns just the list of liked shop IDs — used to initialise
    the heart-button state on shop cards without fetching full shop data.
    """
    liked_shop_ids: list = current_user.get("liked_shop_ids", [])
    return {"success": True, "liked_shop_ids": liked_shop_ids}


# ── Deal Favourites ────────────────────────────────────────────────────────────

@router.post("/deal-favourites/{deal_id}")
async def toggle_deal_favourite(
    deal_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    POST /users/deal-favourites/{deal_id}
    Toggles like/unlike for a deal.
    Returns { liked: bool }.
    """
    db = get_db()
    user_id = str(current_user.get("_id") or current_user.get("id"))
    liked_deal_ids = current_user.get("liked_deal_ids", [])

    if deal_id in liked_deal_ids:
        await db.users.update_one(
            {"_id": ObjectId(user_id)},
            {"$pull": {"liked_deal_ids": deal_id}},
        )
        return {"success": True, "liked": False, "deal_id": deal_id}
    else:
        await db.users.update_one(
            {"_id": ObjectId(user_id)},
            {"$addToSet": {"liked_deal_ids": deal_id}},
        )
        return {"success": True, "liked": True, "deal_id": deal_id}


@router.get("/liked-deal-ids")
async def get_liked_deal_ids(
    current_user: dict = Depends(get_current_user),
):
    """
    GET /users/liked-deal-ids
    Returns the list of liked deal IDs — used to seed heart-button state.
    """
    liked_deal_ids: list = current_user.get("liked_deal_ids", [])
    return {"success": True, "liked_deal_ids": liked_deal_ids}


@router.get("/deal-favourites")
async def get_deal_favourites(
    current_user: dict = Depends(get_current_user),
):
    """
    GET /users/deal-favourites
    Returns full deal details for all liked deals.
    """
    db = get_db()
    liked_deal_ids: list = current_user.get("liked_deal_ids", [])

    deals = []
    for deal_id in liked_deal_ids:
        try:
            deal = await db.deals.find_one({"_id": ObjectId(deal_id)})
            if deal:
                deals.append(serialize_doc(deal))
        except Exception:
            pass

    return {"success": True, "deals": deals, "total": len(deals)}
