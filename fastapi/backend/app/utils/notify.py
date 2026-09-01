"""
notify_user — single entry point for "tell a user something".

Does THREE things together so the channels never drift apart:
  1. Inserts a row into `db.notifications` (powers GET /notifications, the
     bell icon / unread badge in the app).
  2. Sends a real FCM push to every device the user is logged in on (powers
     the system popup — works even when the app is backgrounded/killed).
  3. Sends the same thing over WhatsApp, so a user who has the app closed or
     push notifications switched off still hears about it.

Step 3 is dormant until TWILIO_NOTIFY_TEMPLATE_SID is set in .env, because
WhatsApp only allows pre-approved templates. Pass whatsapp=False for
notifications that are too frequent or too minor to be worth a WhatsApp
message (they still get steps 1 and 2).

Use this anywhere the backend needs to notify a user: login success, claim
status changes, offers, reminders, etc. — instead of writing to
`db.notifications` directly.
"""

from datetime import datetime
from typing import Optional

from .fcm import send_push_to_user
from .whatsapp import send_notification_to_user


async def notify_user(
    db,
    user_id: str,
    title: str,
    message: str,
    type: str = "info",  # info | success | warning | error | alert | offer | reminder
    claim_id: Optional[str] = None,
    data: Optional[dict] = None,
    whatsapp: bool = True,   # set False for noisy internal notifications
) -> dict:
    """Persist an in-app notification AND fire a push to the user's devices."""
    doc = {
        "user_id": user_id,
        "title": title,
        "message": message,
        "type": type,
        "is_read": False,
        "claim_id": claim_id,
        "created_at": datetime.utcnow(),
    }
    result = await db.notifications.insert_one(doc)
    doc["_id"] = result.inserted_id

    push_data = {"type": type, "notification_id": str(result.inserted_id)}
    if claim_id:
        push_data["claim_id"] = claim_id
    if data:
        push_data.update(data)

    # Fire-and-forget-ish: awaited, but internally swallows all errors so a
    # push outage can never fail the calling request (login, claim update, …).
    await send_push_to_user(db, user_id, title, message, push_data)

    # 3. Same message over WhatsApp, so a user with the app closed or push
    #    switched off still hears about it.
    #
    #    Does nothing until TWILIO_NOTIFY_TEMPLATE_SID is set in .env, and
    #    swallows its own errors, so this cannot affect the two steps above.
    if whatsapp is not False:
        await send_notification_to_user(db, user_id, title, message)

    return doc
