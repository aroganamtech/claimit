"""
notify_user — single entry point for "tell an app user something" from the
WEB backend (admin actions, feedback replies, etc.).

Does TWO things together so the in-app notification list and the system push
popup never drift apart:
  1. Inserts a row into claimit_db.notifications (powers GET /notifications,
     the bell icon / unread badge in the app).
  2. Sends a real FCM push to every device the user is logged in on (powers
     the system popup — works even when the app is backgrounded/killed).

Before this existed, admin.py wrote step 1 only — so bill-review approvals/
rejections and feedback replies never reached a user unless they happened to
already have the app open. Use notify_user() anywhere this backend needs to
tell an app user something, instead of writing to app_notifications_collection
directly.
"""

from datetime import datetime
from typing import Optional

from database import app_db
from .fcm import send_push_to_user


async def notify_user(
    user_id: str,
    title: str,
    message: str,
    type: str = "info",
    review_id: Optional[str] = None,
    feedback_id: Optional[str] = None,
    data: Optional[dict] = None,
) -> dict:
    """Persist an in-app notification AND fire a push to the user's devices."""
    doc = {
        "user_id": user_id,
        "title": title,
        "message": message,
        "type": type,
        "is_read": False,
        "created_at": datetime.utcnow(),
    }
    if review_id:
        doc["review_id"] = review_id
    if feedback_id:
        doc["feedback_id"] = feedback_id

    result = await app_db["notifications"].insert_one(doc)
    doc["_id"] = result.inserted_id

    push_data = {"type": type, "notification_id": str(result.inserted_id)}
    if review_id:
        push_data["review_id"] = review_id
    if feedback_id:
        push_data["feedback_id"] = feedback_id
    if data:
        push_data.update(data)

    # Awaited, but send_push_to_user swallows all errors internally so a push
    # outage can never fail the admin action that triggered it.
    await send_push_to_user(user_id, title, message, push_data)

    return doc
