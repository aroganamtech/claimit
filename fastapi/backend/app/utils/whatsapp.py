"""
whatsapp.py — send WhatsApp messages to users through Twilio.

Why this file exists
--------------------
The app already tells users things two ways: an in-app notification row and an
FCM push popup. This adds WhatsApp as a third channel, so a user who has the
app closed (or has push notifications switched off) still hears from Claimit.

The one rule that shapes everything here
----------------------------------------
WhatsApp does NOT allow a business to send free-form text. Outside a 24-hour
window that only opens when the USER messages you first, every message must
use a template that Meta has approved in advance. You fill in its variables;
you cannot change its wording at send time.

So each kind of message needs its own approved template, and its Content SID
goes in .env:

    TWILIO_WELCOME_TEMPLATE_SID   the first-login welcome    — 1 variable  {{1}} = name
    TWILIO_NOTIFY_TEMPLATE_SID    general notifications      — 2 variables {{1}} = title, {{2}} = message

Until a SID is set, that message type simply doesn't go to WhatsApp. Nothing
breaks and nothing is logged as an error — the in-app notification and the FCM
push carry on exactly as before. That is deliberate: this can be deployed
today and switched on later, one .env line at a time.

Everything here is best-effort. No function raises. A WhatsApp outage, a
rejected template or a user with no phone number must never fail a login, a
registration or a payment.
"""
import json
from typing import Optional

from ..config import get_settings

settings = get_settings()

_client = None


def _twilio():
    """Twilio client, created once. Returns None if unavailable — callers
    treat that as 'WhatsApp is off' rather than as an error."""
    global _client
    if _client is None:
        try:
            from twilio.rest import Client
            if settings.twilio_account_sid and settings.twilio_auth_token:
                _client = Client(settings.twilio_account_sid,
                                 settings.twilio_auth_token)
        except ImportError:
            print("⚠️  twilio package not installed — WhatsApp disabled")
    return _client


def _to_e164(phone: str) -> str:
    """Phone number → the +country format Twilio requires.

    Mirrors the same logic in otp.py: a bare 10-digit number is assumed to be
    Indian, anything else without a '+' gets the configured default code.
    """
    cleaned = str(phone or "").strip().replace(" ", "").replace("-", "").replace(".", "")
    if not cleaned:
        return ""
    if cleaned.startswith("+"):
        return cleaned
    if len(cleaned) == 10:
        return f"+91{cleaned}"
    code = getattr(settings, "twilio_default_country_code", "+91").strip()
    if not code.startswith("+"):
        code = f"+{code}"
    return f"{code}{cleaned}"


def _looks_like_phone(value: str) -> bool:
    """True for a phone number, False for an email address.

    Users sign up with either, and both end up in the same field, so every
    caller needs this check before trying to send a WhatsApp message.
    """
    v = str(value or "").strip()
    if not v or "@" in v:
        return False
    digits = "".join(c for c in v if c.isdigit())
    return len(digits) >= 8


async def send_template(
    phone: str,
    template_sid: str,
    variables: Optional[dict] = None,
) -> bool:
    """Send one approved template. Returns True only if Twilio accepted it.

    `variables` maps the template's placeholders to values, e.g.
    {"1": "Ramesh"} fills {{1}}. Values are forced to str because Twilio
    rejects numbers.
    """
    if not template_sid:
        return False                      # this message type isn't switched on
    if not _looks_like_phone(phone):
        return False                      # email-only user, or no number

    client = _twilio()
    sender = getattr(settings, "twilio_whatsapp_number", "").strip()
    if not (client and sender):
        return False                      # WhatsApp not configured on this server

    to = _to_e164(phone)
    if not to:
        return False

    # A sender can't message itself — Twilio error 63031. Silently skip rather
    # than log a scary error for what is really just a test number.
    if to.lstrip("+") == sender.lstrip("+"):
        return False

    try:
        msg = client.messages.create(
            from_=f"whatsapp:{sender}",
            to=f"whatsapp:{to}",
            content_sid=template_sid,
            content_variables=json.dumps(
                {k: str(v) for k, v in (variables or {}).items()}
            ),
        )
        print(f"✅ WhatsApp sent to {to} | SID: {msg.sid}")
        return True
    except Exception as e:
        # Swallowed on purpose. Common causes: template not approved (63016),
        # sender not registered (63007), number not on WhatsApp (21211).
        print(f"⚠️  WhatsApp to {to} failed: {e}")
        return False


async def send_welcome(phone: str, name: str = "") -> bool:
    """The first-login welcome. Template takes one variable: {{1}} = name."""
    sid = getattr(settings, "twilio_welcome_template_sid", "").strip()
    return await send_template(phone, sid, {"1": name or "there"})


async def send_notification(phone: str, title: str, message: str) -> bool:
    """A general notification. Template takes two variables:
    {{1}} = title, {{2}} = message.

    WhatsApp rejects a variable containing a newline, a tab or four spaces in
    a row, so the text is flattened first — otherwise a multi-line push body
    that works fine on FCM would silently fail here.
    """
    sid = getattr(settings, "twilio_notify_template_sid", "").strip()
    return await send_template(phone, sid, {
        "1": _flatten(title),
        "2": _flatten(message),
    })


def _flatten(text: str) -> str:
    """Collapse whitespace so the value is safe to put in a template variable."""
    return " ".join(str(text or "").split())


async def send_notification_to_user(db, user_id: str, title: str, message: str) -> bool:
    """Look the user's number up, then send. Used by notify_user().

    Prefers the `phone` field; falls back to `mobile` in case an older record
    used that name.
    """
    try:
        from bson import ObjectId
        try:
            oid = ObjectId(str(user_id))
        except Exception:
            return False
        user = await db.users.find_one({"_id": oid}, {"phone": 1, "mobile": 1})
        if not user:
            return False
        phone = user.get("phone") or user.get("mobile") or ""
        return await send_notification(phone, title, message)
    except Exception as e:
        print(f"⚠️  WhatsApp lookup failed for user {user_id}: {e}")
        return False


async def broadcast_notification(db, title: str, message: str, limit: int = 20000) -> int:
    """Send one notification to every user who has a phone number.

    Returns how many were accepted by Twilio. Sends one at a time and skips
    failures — a bad number in the middle must not stop the rest.

    Note this costs money per message and, for anything promotional, Meta
    expects the user to have opted in. Keep an eye on the WhatsApp quality
    rating in the Twilio console after a large send.
    """
    sid = getattr(settings, "twilio_notify_template_sid", "").strip()
    if not sid:
        return 0

    sent = 0
    try:
        cursor = db.users.find(
            {"phone": {"$nin": [None, ""]}},
            {"phone": 1},
        ).limit(limit)
        async for u in cursor:
            if await send_notification(u.get("phone", ""), title, message):
                sent += 1
    except Exception as e:
        print(f"⚠️  WhatsApp broadcast stopped early: {e}")
    print(f"📣 WhatsApp broadcast: {sent} message(s) accepted")
    return sent
