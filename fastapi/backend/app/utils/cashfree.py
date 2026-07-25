"""
Razorpay Payment Links helper — used for the Local Finds (Rs.730) and Local
Classifieds (Rs.250) listing fees.

NOTE: this file keeps its old name (cashfree.py) and the same function names /
return-dict keys as the previous Cashfree integration, so the routes that
import it need no changes. Internally it now calls Razorpay's Payment Links
API instead of Cashfree.

Uses Razorpay's Payment Links API (v1). Reads credentials from Settings
(.env: RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET).

Razorpay has ONE base URL for both test and live — the mode is decided by the
key itself:
  rzp_test_...  -> test mode  (no real money moves)
  rzp_live_...  -> live mode  (real charges)

Docs: https://razorpay.com/docs/api/payments/payment-links/
"""

import httpx
from fastapi import HTTPException

from ..config import get_settings

settings = get_settings()

_BASE_URL = "https://api.razorpay.com/v1"


def _auth() -> tuple:
    """Razorpay uses HTTP Basic auth: (key_id, key_secret)."""
    if not settings.razorpay_key_id or not settings.razorpay_key_secret:
        raise HTTPException(
            status_code=503,
            detail=(
                "Payments are not configured yet — add RAZORPAY_KEY_ID and "
                "RAZORPAY_KEY_SECRET to the backend .env, then restart the "
                "server."
            ),
        )
    return (settings.razorpay_key_id, settings.razorpay_key_secret)


def _map_status(razorpay_status: str) -> str:
    """Map Razorpay payment-link statuses to the uppercase values the app and
    website already expect (the same words Cashfree used), so nothing else has
    to change.
    Razorpay: created | partially_paid | expired | cancelled | paid."""
    return {
        "paid": "PAID",
        "created": "ACTIVE",
        "partially_paid": "PARTIALLY_PAID",
        "expired": "EXPIRED",
        "cancelled": "CANCELLED",
    }.get((razorpay_status or "").lower(), (razorpay_status or "UNKNOWN").upper())


async def create_payment_link(
    link_id: str,
    amount: float,
    purpose: str,
    customer_phone: str,
    customer_name: str,
    return_url: str,
) -> dict:
    """Creates a Razorpay hosted payment link. Returns a dict with the SAME
    keys the routes already read from the old Cashfree response:
      link_id     -> Razorpay's payment-link id (plink_...), used to poll status
      link_url    -> the hosted checkout short_url
      link_status -> mapped status (ACTIVE / PAID / ...)
    """
    # Razorpay expects the amount in the smallest currency unit (paise), as an
    # integer. Rs.730.00 -> 73000 paise.
    amount_paise = int(round(amount * 100))

    payload = {
        "amount": amount_paise,
        "currency": "INR",
        "description": purpose[:2048],  # Razorpay caps description at 2048
        # Razorpay caps reference_id at 40 chars. Our link_id can be longer
        # (prefix + Mongo _id + uuid), so keep the last 40 chars — the unique
        # uuid suffix is preserved, so reference_ids stay unique.
        "reference_id": link_id if len(link_id) <= 40 else link_id[-40:],
        "customer": {
            "name": customer_name or "Claimit User",
            "contact": customer_phone or "9999999999",
        },
        "notify": {"sms": False, "email": False},
        "reminder_enable": False,
    }
    # A return/callback URL is optional. If present, Razorpay redirects the
    # browser back to it after payment (must be paired with callback_method).
    if return_url:
        payload["callback_url"] = return_url
        payload["callback_method"] = "get"

    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.post(
            f"{_BASE_URL}/payment_links", auth=_auth(), json=payload
        )
    if resp.status_code >= 400:
        raise HTTPException(
            status_code=502,
            detail=f"Razorpay error creating payment link: {resp.text}",
        )
    data = resp.json()
    return {
        "link_id": data.get("id", link_id),        # plink_... — poll with this
        "link_url": data.get("short_url", ""),
        "link_status": _map_status(data.get("status", "created")),
    }


async def get_payment_link_status(link_id: str) -> dict:
    """Fetches a payment link's current status from Razorpay.
    Returns {'link_status': ...} using the same uppercase words as before:
    ACTIVE, PAID, EXPIRED, CANCELLED, PARTIALLY_PAID."""
    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.get(
            f"{_BASE_URL}/payment_links/{link_id}", auth=_auth()
        )
    if resp.status_code >= 400:
        raise HTTPException(
            status_code=502,
            detail=f"Razorpay error fetching link status: {resp.text}",
        )
    data = resp.json()
    return {"link_status": _map_status(data.get("status", ""))}
