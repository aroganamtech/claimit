"""
Cashfree Payment Links helper — used to charge Advertisers for ad bookings
(Home Banner, Nearby Deals, Brand Deals, Promo Reelz) before the ad is
created/published.

Mirrors the pattern already used on the mobile app backend for Local Finds /
Local Classifieds listing fees (fastapi/backend/app/utils/cashfree.py), so
both backends share the exact same integration approach — just reads its
credentials with plain os.getenv() since this backend doesn't use a
pydantic Settings class.

Uses Cashfree's Payment Links API (v2023-08-01). Reads credentials from
the .env file: CASHFREE_APP_ID / CASHFREE_SECRET_KEY / CASHFREE_ENV.

CASHFREE_ENV=TEST -> https://sandbox.cashfree.com/pg  (no real money moves)
CASHFREE_ENV=PROD -> https://api.cashfree.com/pg      (real charges)

Docs: https://docs.cashfree.com/reference/pglinkscreate
"""

import os
import httpx
from fastapi import HTTPException

_API_VERSION = "2023-08-01"


def _base_url() -> str:
    return (
        "https://api.cashfree.com/pg"
        if os.getenv("CASHFREE_ENV", "TEST").upper() == "PROD"
        else "https://sandbox.cashfree.com/pg"
    )


def _headers() -> dict:
    app_id = os.getenv("CASHFREE_APP_ID", "")
    secret_key = os.getenv("CASHFREE_SECRET_KEY", "")
    if not app_id or not secret_key:
        raise HTTPException(
            status_code=503,
            detail=(
                "Payments are not configured yet — add CASHFREE_APP_ID and "
                "CASHFREE_SECRET_KEY to the backend .env, then restart the "
                "server."
            ),
        )
    return {
        "x-client-id": app_id,
        "x-client-secret": secret_key,
        "x-api-version": _API_VERSION,
        "Content-Type": "application/json",
    }


async def create_payment_link(
    link_id: str,
    amount: float,
    purpose: str,
    customer_phone: str,
    customer_name: str,
    return_url: str,
) -> dict:
    """Creates a Cashfree hosted payment link. Returns the raw Cashfree
    response (contains 'link_url', 'link_status', 'cf_link_id', ...)."""
    payload = {
        "link_id": link_id,
        "link_amount": amount,
        "link_currency": "INR",
        "link_purpose": purpose[:490],  # Cashfree caps this field's length
        "customer_details": {
            "customer_phone": customer_phone or "9999999999",
            "customer_name": customer_name or "Claimit Advertiser",
        },
        "link_notify": {"send_sms": False, "send_email": False},
        "link_meta": {"return_url": return_url} if return_url else {},
    }
    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.post(
            f"{_base_url()}/links", headers=_headers(), json=payload
        )
    if resp.status_code >= 400:
        raise HTTPException(
            status_code=502,
            detail=f"Cashfree error creating payment link: {resp.text}",
        )
    return resp.json()


async def get_payment_link_status(link_id: str) -> dict:
    """Fetches a payment link's current status from Cashfree.
    link_status is one of: ACTIVE, PAID, EXPIRED, CANCELLED, PARTIALLY_PAID."""
    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.get(
            f"{_base_url()}/links/{link_id}", headers=_headers()
        )
    if resp.status_code >= 400:
        raise HTTPException(
            status_code=502,
            detail=f"Cashfree error fetching link status: {resp.text}",
        )
    return resp.json()
