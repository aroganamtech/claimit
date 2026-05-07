from fastapi import APIRouter, Depends
from bson import ObjectId
from datetime import datetime
from ..database import get_db
from ..utils.auth import get_current_user
from ..utils.helpers import serialize_doc

router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("")
async def get_notifications(
    page: int = 1,
    page_size: int = 20,
    current_user: dict = Depends(get_current_user),
):
    """Get all notifications for current user."""
    db = get_db()
    user_id = current_user.get("_id") or current_user.get("id")

    skip = (page - 1) * page_size
    cursor = db.notifications.find({"user_id": user_id}).sort(
        "created_at", -1
    ).skip(skip).limit(page_size)

    notifications = await cursor.to_list(length=page_size)
    return [serialize_doc(n) for n in notifications]


@router.patch("/{notification_id}/read")
async def mark_as_read(
    notification_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Mark a notification as read."""
    db = get_db()
    user_id = current_user.get("_id") or current_user.get("id")

    await db.notifications.update_one(
        {"_id": ObjectId(notification_id), "user_id": user_id},
        {"$set": {"is_read": True}},
    )
    return {"success": True}


@router.patch("/read-all")
async def mark_all_read(current_user: dict = Depends(get_current_user)):
    """Mark all notifications as read."""
    db = get_db()
    user_id = current_user.get("_id") or current_user.get("id")

    await db.notifications.update_many(
        {"user_id": user_id, "is_read": False},
        {"$set": {"is_read": True}},
    )
    return {"success": True}


@router.get("/unread-count")
async def get_unread_count(current_user: dict = Depends(get_current_user)):
    """Get unread notification count."""
    db = get_db()
    user_id = current_user.get("_id") or current_user.get("id")

    count = await db.notifications.count_documents(
        {"user_id": user_id, "is_read": False}
    )
    return {"count": count}
