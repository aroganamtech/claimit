"""
campaign.py — send one approved WhatsApp template to a list of numbers.

Why this lives in the APP backend
---------------------------------
The admin panel that drives this is part of the WEB backend, but the Twilio
credentials are only here. Rather than copy TWILIO_ACCOUNT_SID, the auth token
and the sender number into a second .env — doubling the number of places a
secret can leak from — the web backend calls this endpoint over localhost with
the shared X-Admin-Key the app backend already uses for its other admin routes.

What it guarantees
------------------
* Every recipient is recorded in `whatsapp_campaign_log` BEFORE the next one is
  attempted, so a crash or a timeout mid-run can never turn into a second run
  that messages the first half twice. WhatsApp bills per message; a duplicate
  send is real money and an annoyed shop owner.
* A number already messaged for the same template is skipped, so re-uploading
  the same sheet is safe.
* Sends are paced. Firing 600 requests at once gets an account rate-limited,
  and a rate-limited account fails the REST of the run.
* One bad row never stops the batch — it is recorded as failed and the run
  continues.
"""
import asyncio
import os
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel

from ..database import get_db
from ..utils.whatsapp import send_template, _looks_like_phone, _to_e164

router = APIRouter(prefix="/campaign", tags=["Campaign"])

_ADMIN_KEY = os.getenv("ADMIN_SECRET", "claimit-admin-2024")

# Gap between sends. Twilio's WhatsApp throughput is generous, but a burst of
# several hundred still risks 429s — and a 429 midway means the rest of the
# campaign silently fails. Slow and complete beats fast and half-sent.
_SEND_GAP_SECONDS = 0.35

LOG = "whatsapp_campaign_log"

# What {{1}} becomes when the sheet has a number but no shop name.
#
# The template sentence is "Your shop {{1}} is already listed on CLAIMIT", so
# the filler has to keep that grammatical. "your business" would read "Your
# shop your business is already listed"; this reads "Your shop in your area is
# already listed on CLAIMIT", which is correct and claims no name we don't
# have. Twilio also rejects an empty variable outright, so it cannot be blank.
FALLBACK_NAME = "in your area"


def _require_admin(x_admin_key: Optional[str] = Header(None)):
    if x_admin_key != _ADMIN_KEY:
        raise HTTPException(status_code=401, detail="Invalid admin key")
    return True


class Recipient(BaseModel):
    phone: str
    shop_name: str = ""


class CampaignRequest(BaseModel):
    template_sid: str
    recipients: List[Recipient]
    # A name for this run, so the log can be read back per campaign.
    campaign: str = "claim_business"
    # True = report what WOULD happen and send nothing. The admin page always
    # calls this first, so nobody spends money on a sheet they haven't seen
    # validated.
    dry_run: bool = True


@router.post("/whatsapp")
async def send_whatsapp_campaign(
    body: CampaignRequest,
    _ok: bool = Depends(_require_admin),
):
    """Send `template_sid` to every recipient, one variable: {{1}} = shop_name."""
    if not body.template_sid.startswith("HX"):
        raise HTTPException(status_code=400,
                            detail="template_sid must be a Twilio Content SID (HX…)")
    if not body.recipients:
        raise HTTPException(status_code=400, detail="No recipients")

    db = get_db()

    # Who has already been messaged for this campaign, so a re-upload of the
    # same sheet doesn't message anyone twice.
    already: set = set()
    try:
        cursor = db[LOG].find(
            {"campaign": body.campaign, "status": "sent"}, {"phone": 1})
        async for d in cursor:
            already.add(str(d.get("phone", "")))
    except Exception:
        pass    # an unreadable log must not block the campaign

    sent = failed = skipped_dupe = skipped_invalid = 0
    results = []
    seen_this_run: set = set()

    for r in body.recipients:
        phone = (r.phone or "").strip()
        name = (r.shop_name or "").strip()

        if not _looks_like_phone(phone):
            skipped_invalid += 1
            results.append({"phone": phone, "status": "invalid_number"})
            continue

        e164 = _to_e164(phone)
        if e164 in already or e164 in seen_this_run:
            skipped_dupe += 1
            results.append({"phone": e164, "status": "already_sent"})
            continue
        seen_this_run.add(e164)

        if body.dry_run:
            sent += 1
            results.append({"phone": e164, "status": "would_send",
                            "shop_name": name})
            continue

        ok = await send_template(phone, body.template_sid,
                                 {"1": name or FALLBACK_NAME})
        # Written immediately, before the next send. If the process dies here,
        # the next run knows exactly how far this one got.
        try:
            await db[LOG].update_one(
                {"campaign": body.campaign, "phone": e164},
                {"$set": {
                    "campaign": body.campaign,
                    "phone": e164,
                    "shop_name": name,
                    "template_sid": body.template_sid,
                    "status": "sent" if ok else "failed",
                    "sent_at": datetime.utcnow(),
                }},
                upsert=True,
            )
        except Exception:
            pass

        if ok:
            sent += 1
            results.append({"phone": e164, "status": "sent"})
        else:
            failed += 1
            results.append({"phone": e164, "status": "failed"})

        await asyncio.sleep(_SEND_GAP_SECONDS)

    return {
        "dry_run": body.dry_run,
        "campaign": body.campaign,
        "total_rows": len(body.recipients),
        "sent": sent,
        "failed": failed,
        "skipped_already_sent": skipped_dupe,
        "skipped_invalid_number": skipped_invalid,
        "results": results,
    }


@router.get("/whatsapp/log")
async def campaign_log(
    campaign: str = "claim_business",
    _ok: bool = Depends(_require_admin),
):
    """Who has been messaged so far, so admin can see progress and re-run
    a partially finished campaign without double-sending."""
    db = get_db()
    try:
        sent = await db[LOG].count_documents(
            {"campaign": campaign, "status": "sent"})
        failed = await db[LOG].count_documents(
            {"campaign": campaign, "status": "failed"})
        recent = await (db[LOG].find({"campaign": campaign})
                        .sort("sent_at", -1).limit(50).to_list(50))
        for d in recent:
            d["_id"] = str(d["_id"])
            if isinstance(d.get("sent_at"), datetime):
                d["sent_at"] = d["sent_at"].isoformat()
        return {"campaign": campaign, "sent": sent, "failed": failed,
                "recent": recent}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
