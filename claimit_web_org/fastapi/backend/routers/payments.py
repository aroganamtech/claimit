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
    # The "+ announce by push" add-on. It has to be known HERE as well as at
    # /advertiser/ads/create, because this is the call that decides how much
    # Cashfree actually collects — if the add-on were only priced at ad
    # creation, every advertiser who ticked the box would be charged the base
    # price and get the add-on for free.
    with_notification: bool = False


async def _authoritative_ad_amount(ad_type: str, tier: str,
                                   with_notification: bool = False) -> int:
    """The price Cashfree will charge for this booking.

    Imported straight from routers.advertiser rather than reimplemented: this
    number and the one recorded on the ad MUST be identical, and the previous
    hand-copied version of this mapping is exactly the kind of duplication
    that drifts the first time a new ad type or an add-on is introduced.

    The import is local to the function so neither router imports the other
    at module load.
    """
    from routers.advertiser import _ad_price, KNOWN_AD_TYPES

    ad_type = (ad_type or "").strip().lower()
    if ad_type not in KNOWN_AD_TYPES:
        raise HTTPException(status_code=400, detail=f"Unknown ad_type: {ad_type}")
    return await _ad_price(ad_type, (tier or "standard").strip().lower(),
                           with_notification)


@router.post("/create-link")
async def create_link(
    body: CreateLinkRequest,
    current_user: dict = Depends(get_current_user),
):
    if body.ad_type:
        amount = await _authoritative_ad_amount(
            body.ad_type, body.tier or "standard", body.with_notification)
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
