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
from fastapi import APIRouter, Depends
from pydantic import BaseModel

from utils.dependencies import get_current_user
from utils.cashfree import create_payment_link, get_payment_link_status

router = APIRouter()


class CreateLinkRequest(BaseModel):
    amount: float
    purpose: str = "Claimit Ad Booking"
    return_url: str = ""


@router.post("/create-link")
async def create_link(
    body: CreateLinkRequest,
    current_user: dict = Depends(get_current_user),
):
    link_id = f"claimitweb_{current_user['_id']}_{uuid.uuid4().hex[:10]}"
    result = await create_payment_link(
        link_id=link_id,
        amount=body.amount,
        purpose=body.purpose,
        customer_phone=current_user.get("phone", ""),
        customer_name=current_user.get("name", "Claimit Advertiser"),
        return_url=body.return_url,
    )
    return {
        "link_id": result.get("link_id", link_id),
        "payment_link_url": result.get("link_url", ""),
        "status": result.get("link_status", "ACTIVE"),
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
