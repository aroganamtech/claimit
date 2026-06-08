from fastapi import APIRouter, Depends
from bson import ObjectId
from datetime import datetime
from pydantic import BaseModel
from typing import Optional
from ..database import get_db
from ..utils.auth import get_current_user
from ..utils.helpers import serialize_doc

router = APIRouter(prefix="/notifications", tags=["Notifications"])


# ── Push notifications (FCM device-token registration) ──────────────────────

class FcmTokenRequest(BaseModel):
    token: str
    platform: Optional[str] = None  # "android" | "ios" | "web" (optional, for diagnostics)


@router.post("/fcm-token")
async def register_fcm_token(
    request: FcmTokenRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Register/refresh this device's FCM token against the logged-in user.

    Call this:
      - right after FcmService.init() obtains a token (app start / login)
      - whenever FirebaseMessaging.onTokenRefresh fires

    A token always belongs to exactly ONE device, but a USER can have many
    devices — so we upsert by token (re-pointing it to the current user if it
    was previously registered to someone else, e.g. shared/reset device) and
    leave the user's other device tokens untouched.
    """
    db = get_db()
    user_id = str(current_user.get("_id") or current_user.get("id"))
    token = request.token.strip()

    if not token:
        return {"success": False, "detail": "Empty token"}

    await db.fcm_tokens.update_one(
        {"token": token},
        {
            "$set": {
                "user_id": user_id,
                "platform": request.platform,
                "updated_at": datetime.utcnow(),
            },
            "$setOnInsert": {"created_at": datetime.utcnow()},
        },
        upsert=True,
    )
    return {"success": True}


@router.delete("/fcm-token")
async def unregister_fcm_token(
    request: FcmTokenRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Remove this device's token — call on logout (or before switching accounts
    on the same device) so the old user stops receiving pushes meant for it.
    """
    db = get_db()
    user_id = str(current_user.get("_id") or current_user.get("id"))
    token = request.token.strip()

    await db.fcm_tokens.delete_one({"token": token, "user_id": user_id})
    return {"success": True}


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


# NOTE: Fixed route ordering — static routes (/read-all, /unread-count) MUST come
# before the dynamic route (/{notification_id}/read) otherwise FastAPI matches
# "read-all" as a notification_id parameter.

@router.get("/unread-count")
async def get_unread_count(current_user: dict = Depends(get_current_user)):
    """Get unread notification count."""
    db = get_db()
    user_id = current_user.get("_id") or current_user.get("id")

    count = await db.notifications.count_documents(
        {"user_id": user_id, "is_read": False}
    )
    return {"count": count}


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


@router.patch("/{notification_id}/read")
async def mark_as_read(
    notification_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Mark a single notification as read."""
    db = get_db()
    user_id = current_user.get("_id") or current_user.get("id")

    await db.notifications.update_one(
        {"_id": ObjectId(notification_id), "user_id": user_id},
        {"$set": {"is_read": True}},
    )
    return {"success": True}
