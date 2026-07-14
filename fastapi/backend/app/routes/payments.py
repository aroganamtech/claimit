"""
Payment endpoints — Cashfree Payment Links, used for the Local Finds
(Rs.730/year business listing) and Local Classifieds (Rs.250/post) fees.

Endpoints
─────────
POST /payments/create-link       → create a Cashfree hosted payment link
GET  /payments/status/{link_id}  → poll whether it's been paid
"""

import uuid
from fastapi import APIRouter, Depends
from pydantic import BaseModel

from ..utils.auth import get_current_user
from ..utils.cashfree import create_payment_link, get_payment_link_status

router = APIRouter(prefix="/payments", tags=["payments"])


class CreateLinkRequest(BaseModel):
    amount: float
    purpose: str = "Claimit Listing Fee"
    return_url: str = ""


@router.post("/create-link")
async def create_link(
    body: CreateLinkRequest,
    current_user: dict = Depends(get_current_user),
):
    link_id = f"claimit_{current_user['_id']}_{uuid.uuid4().hex[:10]}"
    result = await create_payment_link(
        link_id=link_id,
        amount=body.amount,
        purpose=body.purpose,
        customer_phone=current_user.get("phone", ""),
        customer_name=current_user.get("name", "Claimit User"),
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
