"""
Payment endpoints — Cashfree Payment Links, used to charge Advertisers for
ad bookings (Home Banner / Nearby Deals / Brand Deals / Promo Reelz) before
the ad is created. Mirrors the same Payment Links flow already used on the
mobile app for Local Finds / Local Classifieds listing fees.

Endpoints
─────────
POST /payments/create-link       → create a Cashfree hosted payment link
GET  /payments/status/{link_id}  → poll whether it's been paid

The advertiser flow is: create a link for the ad's price → redirect the
browser to the hosted checkout page → user pays → they're redirected back
→ frontend polls this status endpoint → once PAID, POST /advertiser/ads/create
is called WITH the link_id, and that endpoint re-verifies PAID status
server-side before creating/charging anything.
"""

import uuid
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from utils.dependencies import get_current_user
from utils.cashfree import create_payment_link, get_payment_link_status

router = APIRouter()


class CreateLinkRequest(BaseModel):
    amount: float
    purpose: str = "Claimit Ad Booking"
    return_url: str = ""
    # When both are supplied (the real advertiser ad-booking flow —
    # PublishAd.jsx / PaymentPage.jsx), the server recomputes the
    # authoritative price itself from the same admin-configured pricing
    # store routers/advertiser.py's /ads/create uses, and `amount` above is
    # ignored entirely. This is what actually determines how much Cashfree
    # charges, so it must never be trusted from the client — previously it
    # was, which meant nothing stopped a tampered request from opening a
    # checkout for less than the real ad price. Left unset (e.g. the
    # internal TestPayment.jsx page), `amount` is used as-is.
    ad_type: Optional[str] = None
    tier: Optional[str] = None


async def _authoritative_ad_amount(ad_type: str, tier: str) -> int:
    """Same pricing source/mapping as routers/advertiser.py's _ad_price —
    duplicated rather than imported to avoid a router-to-router import; both
    read the same utils.pricing.get_pricing() store so they can never
    disagree with what /advertiser/ads/create actually records."""
    from utils.pricing import get_pricing
    pricing = await get_pricing()
    if ad_type == "home_banner":
        return pricing["ad_home_banner"]
    key = f"ad_{ad_type}_{(tier or 'standard').strip().lower()}"
    if key in pricing:
        return pricing[key]
    raise HTTPException(status_code=400, detail=f"Unknown ad_type/tier: {ad_type}/{tier}")


@router.post("/create-link")
async def create_link(
    body: CreateLinkRequest,
    current_user: dict = Depends(get_current_user),
):
    if body.ad_type:
        amount = await _authoritative_ad_amount(body.ad_type, body.tier or "standard")
    else:
        amount = body.amount

    link_id = f"claimitweb_{current_user['_id']}_{uuid.uuid4().hex[:10]}"
    result = await create_payment_link(
        link_id=link_id,
        amount=amount,
        purpose=body.purpose,
        customer_phone=current_user.get("phone", ""),
        customer_name=current_user.get("name", "Claimit Advertiser"),
        return_url=body.return_url,
    )
    return {
        "link_id": result.get("link_id", link_id),
        "payment_link_url": result.get("link_url", ""),
        "status": result.get("link_status", "ACTIVE"),
        "amount": amount,
    }


@router.get("/status/{link_id}")
async def link_status(
    link_id: str,
    current_user: dict = Depends(get_current_user),
):
    result = await get_payment_link_status(link_id)
    return {
        "link_id": link_id,
        "status": result.get("link_status", "UNKNOWN"),
    }
