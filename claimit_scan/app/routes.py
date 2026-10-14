"""
Scan endpoints.

THE RULE THIS FILE EXISTS TO ENFORCE
────────────────────────────────────
The client never sends an amount, a date or a merchant. It asks for an upload
URL, uploads the photo to S3, sends the key, and later sends a scan id.
Everything that decides money is read by this server from the image and
stored before the customer ever sees it.

    POST /scan/upload-url   → { upload_url, key }
    POST /scan/read         → { scan_id, fields, status }
    POST /scan/confirm      → { claim_id, cashback }
"""
from __future__ import annotations

import logging
import uuid
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field
from pymongo.errors import DuplicateKeyError

from .config import settings
from .db import get_db
from .extract import (
    AzureReceiptClient, Extraction, build_signatures, hamming,
    normalise_merchant, phash, read_exif, sha256_bytes,
)
from .security import User, current_user, rate_limit
from . import storage

log = logging.getLogger(__name__)
router = APIRouter(prefix="/scan", tags=["scan"])

_azure: AzureReceiptClient | None = None


def azure() -> AzureReceiptClient:
    global _azure
    if _azure is None:
        s = settings()
        _azure = AzureReceiptClient(s.AZURE_ENDPOINT, s.AZURE_KEY,
                                    api_version=s.AZURE_API_VERSION,
                                    timeout=s.AZURE_TIMEOUT)
    return _azure


# ── Schemas. Note what is absent from every request: money. ─────────────────
class UploadUrlRequest(BaseModel):
    content_type: str = Field("image/jpeg", max_length=64)


class UploadUrlResponse(BaseModel):
    upload_url: str
    key: str
    expires_in: int


class ReadRequest(BaseModel):
    key: str = Field(..., max_length=512)
    device_id: str | None = Field(None, max_length=128)
    lat: float | None = None
    lng: float | None = None


class FieldOut(BaseModel):
    value: str | None
    confidence: float | None
    needs_check: bool


class ReadResponse(BaseModel):
    scan_id: str
    status: str
    merchant: FieldOut
    txn_date: FieldOut
    total: FieldOut
    message: str


class ConfirmRequest(BaseModel):
    scan_id: str = Field(..., max_length=32)
    idempotency_key: str = Field(..., min_length=8, max_length=64)
    corrected_total: Decimal | None = None
    corrected_date: date | None = None


class ConfirmResponse(BaseModel):
    claim_id: str
    status: str
    cashback_amount: Decimal
    message: str


def _field(value, conf, auto: float) -> FieldOut:
    return FieldOut(value=None if value is None else str(value),
                    confidence=conf,
                    needs_check=(conf is None or conf < auto))


async def _flag(db, scan_id, rule: str, severity: str, detail: str = "") -> None:
    await db.flags.insert_one({"scan_id": scan_id, "rule": rule,
                               "severity": severity, "detail": detail[:500],
                               "created_at": datetime.now(timezone.utc)})


# ═══════════════════════════════════════════════════════════════════════════
# 1. Where to upload
# ═══════════════════════════════════════════════════════════════════════════
@router.post("/upload-url", response_model=UploadUrlResponse)
async def upload_url(body: UploadUrlRequest, request: Request,
                     user: User = Depends(current_user)):
    await rate_limit(user, request)
    try:
        url, key = await storage.presign_put(user.id, body.content_type)
    except ValueError:
        raise HTTPException(400, "Only JPEG, PNG or WebP images are accepted.")
    return UploadUrlResponse(upload_url=url, key=key, expires_in=300)


# ═══════════════════════════════════════════════════════════════════════════
# 2. Read it
# ═══════════════════════════════════════════════════════════════════════════
@router.post("/read", response_model=ReadResponse)
async def read_receipt(body: ReadRequest, request: Request,
                       user: User = Depends(current_user)):
    # Authorisation FIRST, before any I/O.
    #
    # This check is pure string work and needs no database. Running it ahead
    # of the rate limiter means someone probing with other people's keys is
    # refused without costing a database write — and it keeps the cheapest
    # rejection the earliest one.
    if not storage.owns_key(body.key, user.id):
        raise HTTPException(403, "That image does not belong to this account.")

    s = settings()
    await rate_limit(user, request)
    db = get_db()

    size = await storage.object_size(body.key)
    if size is None:
        raise HTTPException(400, "Upload not found. Please try again.")
    if size > s.MAX_IMAGE_BYTES:
        raise HTTPException(413, "That image is too large. Please retake it.")

    data = await storage.fetch(body.key)
    if not data:
        raise HTTPException(400, "Could not read the uploaded image.")

    digest = sha256_bytes(data)
    now = datetime.now(timezone.utc)

    # ── Exact duplicate: cheapest check, run first ──────────────────────
    prior = await db.scans.find_one({"sha256": digest}, {"created_at": 1})
    if prior:
        raise HTTPException(409, detail={
            "code": "duplicate_image",
            "message": "This exact photo has already been submitted.",
            "original_date": prior["created_at"].date().isoformat(),
        })

    ph = await phash(data)
    exif = await read_exif(data)

    scan = {
        "user_id": user.id, "key": body.key, "sha256": digest, "phash": ph,
        "device_id": body.device_id, "has_exif": exif.has_exif,
        "exif_taken_at": exif.taken_at, "exif_model": exif.model,
        "lat": body.lat, "lng": body.lng,
        "status": "extracting", "created_at": now,
    }
    try:
        res = await db.scans.insert_one(scan)
    except DuplicateKeyError:
        # Lost a race on the unique index — the other request won.
        raise HTTPException(409, detail={"code": "duplicate_image",
                                         "message": "This photo was just submitted."})
    scan_id = res.inserted_id

    # ── Near-duplicate image. WARN only: on receipts pHash collides between
    #    genuinely different bills often enough that blocking on it would
    #    refuse real customers. ────────────────────────────────────────────
    if ph is not None:
        cutoff = now - timedelta(days=90)
        async for other in db.scans.find(
                {"_id": {"$ne": scan_id}, "phash": {"$ne": None},
                 "created_at": {"$gt": cutoff}}, {"phash": 1}).limit(5000):
            if hamming(ph, other["phash"]) <= s.PHASH_DIST:
                await _flag(db, scan_id, "phash_near_duplicate", "warn",
                            f"within {s.PHASH_DIST} bits of {other['_id']}")
                break

    # A camera photo carries EXIF; a screenshot or a re-exported edit usually
    # does not. Suggestive, never proof — so it warns, it does not block.
    if not exif.has_exif:
        await _flag(db, scan_id, "no_exif", "warn",
                    "no camera metadata — screenshot or re-saved image")

    # ── Azure reads it straight from S3; this process holds no second copy ──
    try:
        url = await storage.presign_get(body.key)
        ex: Extraction = await azure().analyse_url(url)
    except Exception as exc:
        log.warning("extraction failed scan=%s: %s", scan_id, exc)
        await db.scans.update_one({"_id": scan_id}, {"$set": {"status": "needs_review"}})
        await _flag(db, scan_id, "extraction_failed", "warn", str(exc))
        return ReadResponse(
            scan_id=str(scan_id), status="needs_review",
            merchant=_field(None, None, s.CONF_AUTO),
            txn_date=_field(None, None, s.CONF_AUTO),
            total=_field(None, None, s.CONF_AUTO),
            message="We could not read this bill automatically. "
                    "It has been sent for checking.")

    # ── Policy ──────────────────────────────────────────────────────────
    today = now.date()
    blocks: list[str] = []
    if ex.txn_date:
        if ex.txn_date > today:
            blocks.append(f"the bill is dated {ex.txn_date}")
            await _flag(db, scan_id, "future_date", "block", str(ex.txn_date))
        elif (today - ex.txn_date).days > s.MAX_BILL_AGE_DAYS:
            blocks.append(f"the bill is more than {s.MAX_BILL_AGE_DAYS} days old")
            await _flag(db, scan_id, "stale_bill", "block",
                        f"{(today - ex.txn_date).days} days")
    if ex.txn_date and exif.taken_at:
        drift = (exif.taken_at.date() - ex.txn_date).days
        if drift > s.MAX_BILL_AGE_DAYS:
            await _flag(db, scan_id, "exif_date_drift", "warn",
                        f"photographed {drift} days after the bill date")
    if ex.total is not None:
        if float(ex.total) < s.MIN_BILL_AMOUNT:
            blocks.append(f"the minimum bill is ₹{s.MIN_BILL_AMOUNT:.0f}")
            await _flag(db, scan_id, "below_minimum", "block", str(ex.total))
        elif float(ex.total) > s.MAX_BILL_AMOUNT:
            await _flag(db, scan_id, "above_maximum", "warn", str(ex.total))

    # ── Transaction-level duplicate: the same receipt, re-photographed.
    #    pHash cannot see this. This is the real defence. ──────────────────
    warn_loose = False
    if ex.total is not None and ex.txn_date:
        strict, loose = build_signatures(ex)
        try:
            await db.signatures.insert_one({
                "scan_id": scan_id, "signature": strict,
                "signature_loose": loose, "created_at": now})
        except DuplicateKeyError:
            await db.scans.update_one({"_id": scan_id},
                                      {"$set": {"status": "rejected"}})
            await _flag(db, scan_id, "duplicate_receipt", "block", strict)
            raise HTTPException(409, detail={
                "code": "duplicate_receipt",
                "message": "This bill has already been claimed, even though "
                           "the photo is different."})
        if await db.signatures.count_documents(
                {"signature_loose": loose, "scan_id": {"$ne": scan_id}}, limit=1):
            warn_loose = True
            await _flag(db, scan_id, "loose_signature_match", "warn",
                        "another scan shares merchant + date + amount")

    # ── Store what the SERVER read. Written once; no client payload here. ──
    await db.scans.update_one({"_id": scan_id}, {"$set": {
        "extraction": {
            "provider": ex.provider,
            "merchant_raw": ex.merchant,
            "merchant_norm": normalise_merchant(ex.merchant),
            "txn_date": ex.txn_date.isoformat() if ex.txn_date else None,
            "txn_time": ex.txn_time,
            "total_amount": float(ex.total) if ex.total is not None else None,
            "currency": ex.currency,
            "bill_number": ex.bill_number,
            "conf_merchant": ex.conf_merchant,
            "conf_date": ex.conf_date,
            "conf_total": ex.conf_total,
            "conf_overall": ex.conf_overall,
        },
    }})

    # ── Route it ────────────────────────────────────────────────────────
    has_warn = bool(await db.flags.count_documents(
        {"scan_id": scan_id, "severity": "warn"}, limit=1)) or warn_loose

    if blocks:
        status_, msg = "rejected", "This bill cannot be accepted — " + "; ".join(blocks) + "."
    elif ex.total is None or ex.txn_date is None or ex.conf_overall < s.CONF_REVIEW:
        status_, msg = "needs_review", ("We could not read this clearly. "
                                        "It has gone for checking.")
    elif ex.conf_overall < s.CONF_AUTO or has_warn:
        status_, msg = "needs_review", ("Thanks — we are double-checking this one. "
                                        "You will hear shortly.")
    else:
        status_, msg = "extracted", "Looks good. Confirm to claim your cashback."

    await db.scans.update_one({"_id": scan_id}, {"$set": {"status": status_}})

    return ReadResponse(
        scan_id=str(scan_id), status=status_,
        merchant=_field(ex.merchant, ex.conf_merchant, s.CONF_AUTO),
        txn_date=_field(ex.txn_date, ex.conf_date, s.CONF_AUTO),
        total=_field(ex.total, ex.conf_total, s.CONF_AUTO),
        message=msg)


# ═══════════════════════════════════════════════════════════════════════════
# 3. Confirm — still no amount in the request
# ═══════════════════════════════════════════════════════════════════════════
@router.post("/confirm", response_model=ConfirmResponse,
             status_code=status.HTTP_201_CREATED)
async def confirm(body: ConfirmRequest, user: User = Depends(current_user)):
    s, db = settings(), get_db()

    try:
        sid = ObjectId(body.scan_id)
    except Exception:
        raise HTTPException(400, "Invalid scan id.")

    # Idempotency first — a retried confirm must be a no-op, not a second payout.
    existing = await db.claims.find_one({"idempotency_key": body.idempotency_key})
    if existing:
        return ConfirmResponse(claim_id=str(existing["_id"]), status=existing["status"],
                               cashback_amount=Decimal(str(existing["cashback_amount"])),
                               message="Already claimed.")

    scan = await db.scans.find_one({"_id": sid})
    if not scan or scan["user_id"] != user.id:
        raise HTTPException(404, "Scan not found.")
    if scan["status"] == "claimed":
        raise HTTPException(409, "This bill has already been claimed.")
    if scan["status"] == "rejected":
        raise HTTPException(422, "This bill was not accepted.")
    if scan["created_at"] < datetime.now(timezone.utc) - timedelta(minutes=s.DRAFT_TTL_MIN):
        await db.scans.update_one({"_id": sid}, {"$set": {"status": "expired"}})
        raise HTTPException(410, "This scan expired. Please photograph the bill again.")

    ext = scan.get("extraction") or {}
    if ext.get("total_amount") is None:
        raise HTTPException(422, "Nothing was read from this bill.")

    # A correction is recorded and forces review. It is NOT used to compute
    # anything — that is the point. Editing the number in the UI changes a
    # field a human will look at, not the money.
    if body.corrected_total is not None or body.corrected_date is not None:
        await db.scans.update_one({"_id": sid}, {"$set": {
            "status": "needs_review",
            "user_correction": {
                "total": float(body.corrected_total) if body.corrected_total else None,
                "date": body.corrected_date.isoformat() if body.corrected_date else None,
                "at": datetime.now(timezone.utc)}}})
        await _flag(db, sid, "user_corrected", "warn",
                    f"server read {ext.get('total_amount')} / {ext.get('txn_date')}; "
                    f"user said {body.corrected_total} / {body.corrected_date}")
        raise HTTPException(202, detail={
            "code": "sent_for_review",
            "message": "Thanks — because you changed a value we will check this "
                       "by hand. You will hear shortly."})

    if scan["status"] == "needs_review":
        raise HTTPException(202, detail={
            "code": "under_review",
            "message": "This bill is being checked. You will hear shortly."})

    rate_doc = await db.config.find_one({"_id": "cashback_rate"}) or {}
    rate = Decimal(str(rate_doc.get("percent", "1.0")))
    rate_version = int(rate_doc.get("version", 1))

    bill = Decimal(str(ext["total_amount"]))          # ← server value, always
    cashback = (bill * rate / 100).quantize(Decimal("0.01"))

    claim = {
        "scan_id": sid, "user_id": user.id,
        "bill_amount": float(bill), "rate_percent": float(rate),
        "cashback_amount": float(cashback), "rate_version": rate_version,
        "status": "approved", "idempotency_key": body.idempotency_key,
        "created_at": datetime.now(timezone.utc),
    }
    try:
        res = await db.claims.insert_one(claim)
    except DuplicateKeyError:
        raise HTTPException(409, "This bill has already been claimed.")

    await db.scans.update_one({"_id": sid}, {"$set": {"status": "claimed"}})

    # NOTE: crediting the customer's wallet lives in the app API, which owns
    # the ledger. This service records the approved claim and the app API
    # picks it up — deliberately, so the scan service never holds a write
    # credential on the main database.
    return ConfirmResponse(claim_id=str(res.inserted_id), status="approved",
                           cashback_amount=cashback,
                           message=f"₹{cashback} cashback approved.")
