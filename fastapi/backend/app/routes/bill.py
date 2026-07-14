"""
Bill scan / wallet / history / manual-review endpoints.

Routes:
  POST /bill/scan                        — record a scanned bill, award cashback + points
  GET  /bill/wallet                      — current wallet totals for the logged-in user
  GET  /bill/history                     — last 100 scans, newest first
  POST /bill/manual-review               — submit bill for manual staff review
  GET  /bill/my-reviews                  — user's own manual review submissions
  GET  /bill/manual-reviews              — admin: list all reviews (filter by status)
  POST /bill/manual-reviews/{id}/action  — admin: approve/reject → credit wallet + notify

Business rules (must stay in sync with BillRewardProvider in Flutter):
  • 1 % cashback  (earned_cashback  = total * 0.01)
  • 10 % points   (earned_points    = total * 0.10, rounded)
  • New users get a welcome bonus on wallet creation — configurable by admin:
      new_user_reward_points (default 1000 pts) + new_user_cashback (default ₹10)
  • Config is stored in app_config collection; falls back to env vars / hard defaults.
  • Duplicate detection: fingerprint = "shop|date|HH:MM|amount" (with time)
                        or           "shop|date|amount"         (without time)
"""

import os
from datetime import datetime, timezone
from typing import Optional, Literal

from fastapi import APIRouter, Depends, HTTPException, Header, Query, Request
from pydantic import BaseModel, Field
from bson import ObjectId

from ..database import get_db
from ..utils.auth import get_current_user, decode_token
from ..utils.helpers import serialize_doc
from ..utils.s3 import upload_base64, generate_presigned_url
from ..utils.notify import notify_user


def _require_admin(x_admin_key: Optional[str] = Header(None)):
    secret = os.getenv("ADMIN_SECRET_KEY", "claimit-admin-secret")
    if x_admin_key != secret:
        raise HTTPException(status_code=403, detail="Admin access required")

router = APIRouter(prefix="/bill", tags=["Bill"])


# ── New-user bonus config ──────────────────────────────────────────────────────
async def _get_new_user_config(db) -> dict:
    """
    Read new-user bonus settings from the app_config collection.
    Falls back to env vars, then to hard-coded defaults (1000 pts / ₹10 cashback).
    """
    default_pts = int(os.getenv("NEW_USER_REWARD_POINTS", "1000"))
    default_cb  = float(os.getenv("NEW_USER_CASHBACK", "10.0"))
    try:
        cfg = await db.app_config.find_one({"key": "new_user_bonus"})
        if cfg:
            return {
                "reward_points": int(cfg.get("reward_points", default_pts)),
                "cashback":      float(cfg.get("cashback", default_cb)),
            }
    except Exception:
        pass
    return {"reward_points": default_pts, "cashback": default_cb}


# ── Optional auth ─────────────────────────────────────────────────────────────
async def _resolve_user(request: Request, body_uid: Optional[str]) -> Optional[str]:
    """Return user_id string or None. Never raises — callers decide if 401 needed."""
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        token = auth_header[len("Bearer "):]
        try:
            payload = decode_token(token)
            uid = payload.get("sub")
            if uid:
                return uid
        except Exception:
            pass
    return body_uid


# ── Request models ─────────────────────────────────────────────────────────────
class BillScanRequest(BaseModel):
    total_amount:  float          = Field(..., gt=0)
    reward_points: Optional[int]  = None
    shop_name:     Optional[str]  = None
    shop_id:       Optional[str]  = None   # Redeem/Reward shop — enables server-side calc
    scan_type:     Optional[str]  = None   # "redeem" | "reward" — see _resolve_scan_type
    bill_number:   Optional[str]  = None
    bill_date:     Optional[str]  = None
    bill_time:     Optional[str]  = None
    image_base64:  Optional[str]  = None
    user_id:       Optional[str]  = None


class ManualReviewRequest(BaseModel):
    total_amount:  float  = Field(..., gt=0)
    image_base64:  str    = Field(..., description="Base64-encoded bill image")
    shop_name:     Optional[str] = None
    shop_id:       Optional[str] = None   # Redeem/Reward shop — enables admin-side calc
    scan_type:     Optional[str] = None   # "redeem" | "reward" — see _resolve_scan_type
    bill_number:   Optional[str] = None
    bill_date:     Optional[str] = None
    bill_time:     Optional[str] = None
    manual_reason: Optional[str] = "missing_fields"
    user_id:       Optional[str] = None


class ReviewActionRequest(BaseModel):
    action:        Literal["approve", "reject"]
    reward_points: Optional[int]   = None
    cashback:      Optional[float] = None
    admin_note:    Optional[str]   = None


# ── Helpers ────────────────────────────────────────────────────────────────────
def _dup_key(shop: str, bill_date: str, amount: float,
             bill_time: Optional[str] = None) -> str:
    import re as _re
    # Lowercase + alphanumerics only — "Fresh Basket" and "FreshBasket"
    # must produce the SAME fingerprint (mirrors the Flutter client).
    s   = _re.sub(r"[^a-z0-9]", "", shop.lower())
    amt = f"{amount:.0f}"
    t   = (bill_time or "").strip()
    if t:
        return f"{s}|{bill_date}|{t}|{amt}"
    return f"{s}|{bill_date}|{amt}"


def _resolve_scan_type(raw: Optional[str], shop_id: Optional[str]) -> str:
    """
    Normalize scan_type to "redeem" or "reward".

      • Redeem Bill — spends existing reward points against a shop's
        registered discount % AND earns 1 % cashback + 10 % points on the
        bill total (redeem shops act as redeem + reward).
      • Reward Bill — earns 1 % cashback + 10 % points on the bill total.
        No discount is applied / no points are deducted.

    Back-compat: older clients that don't send scan_type are treated as
    "redeem" when a shop_id is present (matches the original Redeem Zone
    behaviour) and "reward" otherwise (a plain scan with no shop context).
    """
    t = (raw or "").strip().lower()
    if t in ("redeem", "reward"):
        return t
    return "redeem" if shop_id else "reward"


def _names_match(expected: Optional[str], scanned: Optional[str]) -> bool:
    """
    Lenient shop-name match — mirrors BillRewardProvider.matchesExpectedShop
    on the Flutter client. Normalizes both names to lowercase alphanumerics
    and checks bidirectional substring containment, so OCR noise (extra
    branch/address words, punctuation, case) doesn't trip a false mismatch.
    Returns True when there's no expected name to check against.
    """
    if not expected or not expected.strip():
        return True
    if not scanned or not scanned.strip():
        return False
    import re
    norm = lambda s: re.sub(r"[^a-z0-9]", "", s.lower())
    e, s = norm(expected), norm(scanned)
    if not e or not s:
        return False
    return e in s or s in e


async def _get_or_create_wallet(db, uid: str) -> tuple:
    """
    Return (wallet_doc, is_new) where is_new=True if the wallet was just created.
    New wallets receive the configurable welcome bonus (points + cashback).
    """
    wallet = await db.user_wallets.find_one({"user_id": uid})
    if wallet is None:
        bonus = await _get_new_user_config(db)
        wallet = {
            "user_id":           uid,
            "reward_points":     bonus["reward_points"],
            "cashback_wallet":   bonus["cashback"],
            "lifetime_cashback": bonus["cashback"],
            "total_scans":       0,
            "created_at":        datetime.now(timezone.utc),
        }
        await db.user_wallets.insert_one(wallet)
        return wallet, True
    return wallet, False


# ── POST /bill/scan ────────────────────────────────────────────────────────────
@router.post("/scan")
async def scan_bill(data: BillScanRequest, request: Request):
    uid = await _resolve_user(request, data.user_id)
    if not uid:
        raise HTTPException(status_code=401,
                            detail="Authentication required — send Bearer token or user_id")

    db    = get_db()
    total = data.total_amount

    wallet, is_new = await _get_or_create_wallet(db, uid)
    is_first = is_new or wallet.get("total_scans", 0) == 0

    bill_date = data.bill_date or datetime.now(timezone.utc).strftime("%Y-%m-%d")
    key = _dup_key(
        shop      = data.shop_name or "",
        bill_date = bill_date,
        amount    = total,
        bill_time = data.bill_time,
    )
    if await db.bill_scans.find_one({"user_id": uid, "dup_key": key}):
        raise HTTPException(status_code=409, detail="Bill already scanned")

    scan_type = _resolve_scan_type(data.scan_type, data.shop_id)

    # ── Look up merchant + verify the scanned shop matches the one selected ──
    discount_pct = 0
    if data.shop_id:
        try:
            shop_doc = await db.shops.find_one({"_id": ObjectId(data.shop_id)})
        except Exception:
            shop_doc = None

        # Safety net — the client already checks this before submitting, but
        # the server re-checks in case the client check was bypassed/stale.
        # A clear mismatch is rejected; the app then routes the user to
        # manual review instead of silently auto-crediting the wrong shop.
        # Applies to BOTH Redeem and Reward shops.
        expected_name = (shop_doc or {}).get("name")
        if expected_name and not _names_match(expected_name, data.shop_name):
            raise HTTPException(
                status_code=422,
                detail={
                    "code":          "shop_mismatch",
                    "message":       f"Scanned shop name does not match the "
                                     f"selected shop ({expected_name}).",
                    "expected_shop": expected_name,
                    "scanned_shop":  data.shop_name,
                },
            )

        # Discount % only ever applies on the Redeem path.
        if scan_type == "redeem":
            discount_pct = (shop_doc or {}).get("discount") or 0

    # ── BOTH scan types earn cashback + points on the bill total. ────────────
    # A Redeem Bill ADDITIONALLY spends existing points against the shop's
    # discount (below) — i.e. a redeem shop acts as redeem AND reward:
    # the user gets the discount from their points, then still earns
    # 1% cashback + 10% points on the bill amount, exactly like a reward shop.
    # 1:10 rule — e.g. ₹1,564 bill → 156.4 pts (decimal preserved, NOT rounded to int)
    earned_cb  = round(total * 0.01, 2)
    earned_pts = round(total / 10, 1)

    # ── Redeem Bill: deduct existing points based on the shop's discount %. ──
    # Reward Bill: never deducts — discount_pct is 0 above so this is skipped.
    # e.g. 1000 pts wallet, 10% discount shop, ₹2000 bill →
    # discount value = ₹200 → 200 pts deducted → 800 pts left.
    discount_value  = 0.0
    deducted_points = 0
    if scan_type == "redeem" and discount_pct:
        discount_value  = round(total * discount_pct / 100, 2)
        deducted_points = min(discount_value, wallet["reward_points"])

    new_pts       = wallet["reward_points"]     - deducted_points + earned_pts
    new_cb_wallet = wallet["cashback_wallet"]   + earned_cb
    new_lifetime  = wallet["lifetime_cashback"] + earned_cb
    new_scans     = wallet.get("total_scans", 0) + 1

    await db.user_wallets.update_one(
        {"user_id": uid},
        {"$set": {
            "reward_points":     new_pts,
            "cashback_wallet":   new_cb_wallet,
            "lifetime_cashback": new_lifetime,
            "total_scans":       new_scans,
            "updated_at":        datetime.now(timezone.utc),
        }},
    )

    shop_name = (data.shop_name or "Shop").strip()
    scan_doc = {
        "user_id":         uid,
        "dup_key":         key,
        "scan_type":       scan_type,
        "shop_name":       shop_name,
        "shop_id":         data.shop_id,
        "total_amount":    total,
        "earned_cashback": earned_cb,
        "earned_points":   earned_pts,
        "discount_percent": discount_pct,
        "discount_value":  discount_value,
        "deducted_points": deducted_points,
        "bill_number":     data.bill_number,
        "bill_date":       bill_date,
        "bill_time":       data.bill_time,
        "scanned_at":      datetime.now(timezone.utc),
    }
    res = await db.bill_scans.insert_one(scan_doc)

    # Permanent history record — no TTL, shown to user in the app.
    # bill_scans is deleted after 24 h (dup-detection only); bill_history is kept forever.
    await db.bill_history.insert_one({
        "user_id":         uid,
        "scan_type":       scan_type,
        "shop_name":       shop_name,
        "shop_id":         data.shop_id,
        "total_amount":    total,
        "earned_cashback": earned_cb,
        "earned_points":   earned_pts,
        "discount_percent": discount_pct,
        "discount_value":  discount_value,
        "deducted_points": deducted_points,
        "bill_number":     data.bill_number,
        "bill_date":       bill_date,
        "bill_time":       data.bill_time,
        "scanned_at":      scan_doc["scanned_at"],
    })

    # Get bonus values for response (already applied to wallet)
    bonus = await _get_new_user_config(db) if is_first else {"reward_points": 0, "cashback": 0.0}

    return {
        "ok":               True,
        "scan_id":          str(res.inserted_id),
        "scan_type":        scan_type,
        "shop_name":        shop_name,
        # Earned this scan (always 0 / 0.0 for a Redeem Bill)
        "earned_cashback":  earned_cb,
        "earned_points":    earned_pts,
        # Discount audit (always 0 / 0.0 for a Reward Bill)
        "discount_percent": discount_pct,
        "discount_value":   discount_value,
        "deducted_points":  deducted_points,
        "is_new_user_bonus": is_first,
        "bonus_points":     bonus["reward_points"] if is_first else 0,
        "bonus_cashback":   bonus["cashback"]      if is_first else 0.0,
        "reward_points":    new_pts,
        "cashback_wallet":  new_cb_wallet,
        "lifetime_cashback": new_lifetime,
    }


# ── GET /bill/wallet ──────────────────────────────────────────────────────────
@router.get("/wallet")
async def get_wallet(current_user: dict = Depends(get_current_user)):
    db     = get_db()
    uid    = str(current_user["_id"])
    wallet, _ = await _get_or_create_wallet(db, uid)
    return {
        "reward_points":     wallet["reward_points"],
        "cashback_wallet":   wallet["cashback_wallet"],
        "lifetime_cashback": wallet["lifetime_cashback"],
        "total_scans":       wallet.get("total_scans", 0),
    }


# ── GET /bill/history ─────────────────────────────────────────────────────────
@router.get("/history")
async def bill_history(current_user: dict = Depends(get_current_user)):
    db    = get_db()
    uid   = str(current_user["_id"])
    # Read from bill_history (permanent) — NOT bill_scans (expires in 24 h)
    records = await db.bill_history.find({"user_id": uid}).sort("scanned_at", -1).to_list(200)
    return [
        {
            "id":              str(r["_id"]),
            # Older records (scanned before this field existed) are inferred
            # from whether a discount was applied.
            "scan_type":       r.get("scan_type")
                                or ("redeem" if r.get("discount_percent") else "reward"),
            "shop_name":       r.get("shop_name", ""),
            "total_amount":    r.get("total_amount", 0),
            "earned_cashback": r.get("earned_cashback", 0),
            "earned_points":   r.get("earned_points", 0),
            "discount_percent": r.get("discount_percent", 0),
            "discount_value":  r.get("discount_value", 0),
            "deducted_points": r.get("deducted_points", 0),
            "bill_number":     r.get("bill_number"),
            "bill_date":       r.get("bill_date"),
            "bill_time":       r.get("bill_time"),
            "scanned_at":      r["scanned_at"].isoformat() if r.get("scanned_at") else "",
        }
        for r in records
    ]


# ── POST /bill/manual-review ──────────────────────────────────────────────────
@router.post("/manual-review", status_code=201)
async def submit_manual_review(data: ManualReviewRequest, request: Request):
    uid = await _resolve_user(request, data.user_id)
    if not uid:
        raise HTTPException(status_code=401, detail="Authentication required")
    db = get_db()
    parsed_date = None
    if data.bill_date:
        try:
            parsed_date = datetime.strptime(data.bill_date, "%Y-%m-%d")
        except ValueError:
            pass

    # ── Duplicate check ────────────────────────────────────────────────────
    # Manual-review submissions previously had NO duplicate protection at
    # all, unlike /bill/scan. That let the same physical bill be resubmitted
    # for review over and over (each rescan created a brand-new pending
    # review). Compute the same fingerprint /bill/scan uses and block a
    # resubmit if this exact bill was already scanned normally, already
    # approved via manual review, or is still sitting in the review queue.
    dup_key = None
    if data.shop_name and data.bill_date:
        dup_key = _dup_key(
            shop      = data.shop_name,
            bill_date = data.bill_date,
            amount    = data.total_amount,
            bill_time = data.bill_time,
        )
        if await db.bill_scans.find_one({"user_id": uid, "dup_key": dup_key}):
            raise HTTPException(status_code=409, detail="This bill has already been scanned/claimed.")
        existing_review = await db.bill_manual_reviews.find_one(
            {"user_id": uid, "dup_key": dup_key, "status": {"$in": ["pending", "approved"]}}
        )
        if existing_review:
            if existing_review.get("status") == "approved":
                raise HTTPException(status_code=409, detail="This bill has already been approved.")
            raise HTTPException(status_code=409, detail="This bill is already pending review — no need to resubmit.")

    doc = {
        "user_id":       uid,
        "scan_type":     _resolve_scan_type(data.scan_type, data.shop_id),
        "total_amount":  round(data.total_amount, 2),
        "shop_name":     (data.shop_name or "").strip() or None,
        "shop_id":       data.shop_id,
        "bill_number":   (data.bill_number or "").strip() or None,
        "bill_date":     parsed_date,
        "bill_time":     (data.bill_time or "").strip() or None,
        "manual_reason": data.manual_reason or "missing_fields",
        "has_image":     bool(data.image_base64),
        "image_s3_key":  (await upload_base64(data.image_base64, "bill-reviews")
                  if data.image_base64 else None),
        "dup_key":       dup_key,
        "status":        "pending",
        "created_at":    datetime.now(timezone.utc),
        "reviewed_at":   None,
        "review_note":   None,
    }
    result = await db.bill_manual_reviews.insert_one(doc)
    return {
        "success":   True,
        "review_id": str(result.inserted_id),
        "message":   "Your bill has been submitted for review. Our team will verify it within 24 hours.",
    }


# ── GET /bill/my-reviews ──────────────────────────────────────────────────────
@router.get("/my-reviews")
async def my_reviews(current_user: dict = Depends(get_current_user)):
    db  = get_db()
    uid = str(current_user["_id"])
    cursor = db.bill_manual_reviews.find({"user_id": uid}, {"image_s3_key": 0}).sort("created_at", -1)
    docs = await cursor.to_list(length=100)
    return {"success": True, "reviews": [serialize_doc(d) for d in docs], "total": len(docs)}


# ── GET /bill/manual-reviews  (admin) ────────────────────────────────────────
@router.get("/manual-reviews")
async def admin_list_reviews(
    status: Optional[str] = Query(None),
    _: None = Depends(_require_admin),
):
    db    = get_db()
    query = {} if not status or status == "all" else {"status": status}
    cursor = db.bill_manual_reviews.find(query).sort("created_at", -1)
    docs   = await cursor.to_list(length=500)
    result = []
    for d in docs:
        s = serialize_doc(d)
        s.setdefault("submitted_at", s.get("created_at"))
        s3_key = s.pop("image_s3_key", None)
        s["image_url"] = await generate_presigned_url(s3_key) if s3_key else None
        result.append(s)
    return result


# ── POST /bill/manual-reviews/{id}/action  (admin) ───────────────────────────
@router.post("/manual-reviews/{review_id}/action")
async def admin_action_review(
    review_id: str,
    data: ReviewActionRequest,
    _: None = Depends(_require_admin),
):
    db = get_db()
    try:
        oid = ObjectId(review_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid review ID")

    review = await db.bill_manual_reviews.find_one({"_id": oid})
    if not review:
        raise HTTPException(status_code=404, detail="Review not found")
    if review.get("status") != "pending":
        raise HTTPException(status_code=409, detail=f"Review already {review.get('status')}")

    now       = datetime.now(timezone.utc)
    uid       = review.get("user_id", "")
    amount    = float(review.get("total_amount", 0))
    shop_name = review.get("shop_name") or "Shop"
    shop_id   = review.get("shop_id")
    scan_type = _resolve_scan_type(review.get("scan_type"), shop_id)

    # BOTH scan types earn cashback + points (same rule as /bill/scan) —
    # a Redeem Bill additionally spends points against the shop's discount.
    # 1:10 rule — e.g. ₹1,564 bill → 156.4 pts (decimal preserved, NOT rounded to int)
    pts = data.reward_points if data.reward_points is not None else round(amount / 10, 1)
    cb  = data.cashback      if data.cashback      is not None else round(amount * 0.01, 2)

    # ── Redeem Bill: look up merchant's registered discount % (if any) ───────
    discount_pct = 0
    if shop_id and scan_type == "redeem":
        try:
            shop_doc = await db.shops.find_one({"_id": ObjectId(shop_id)})
        except Exception:
            shop_doc = None
        discount_pct = (shop_doc or {}).get("discount") or 0

    # Same direct-percentage formula as /bill/scan — discount value is the
    # shop's discount % applied straight to the bill total (see scan_bill).
    discount_value = 0.0
    if discount_pct:
        discount_value = round(amount * discount_pct / 100, 2)

    update_fields = {"status": data.action, "reviewed_at": now, "review_note": data.admin_note or ""}
    if data.action == "approve":
        update_fields["reward_points"] = pts
        update_fields["cashback"]      = cb
    await db.bill_manual_reviews.update_one({"_id": oid}, {"$set": update_fields})

    deducted_points = 0
    if data.action == "approve":
        wallet, _ = await _get_or_create_wallet(db, uid)
        deducted_points = min(discount_value, wallet["reward_points"]) if discount_value else 0
        net_pts         = pts - deducted_points
        await db.user_wallets.update_one(
            {"user_id": uid},
            {"$set": {
                "reward_points":     wallet["reward_points"]     + net_pts,
                "cashback_wallet":   wallet["cashback_wallet"]   + cb,
                "lifetime_cashback": wallet["lifetime_cashback"] + cb,
                "updated_at":        now,
            }},
        )
        scan_now = now
        await db.bill_scans.insert_one({
            "user_id": uid, "dup_key": f"review|{review_id}",
            "scan_type": scan_type,
            "shop_name": shop_name, "shop_id": shop_id, "total_amount": round(amount, 2),
            "earned_cashback": cb, "earned_points": pts,
            "discount_percent": discount_pct, "discount_value": discount_value,
            "deducted_points": deducted_points,
            "bill_number": review.get("bill_number"),
            "bill_date":   str(review.get("bill_date", "")),
            "bill_time":   review.get("bill_time"),
            "source": "manual_review", "review_id": review_id, "scanned_at": scan_now,
        })
        # Also write to permanent bill_history so it shows in the app
        await db.bill_history.insert_one({
            "user_id":         uid,
            "scan_type":       scan_type,
            "shop_name":       shop_name,
            "shop_id":         shop_id,
            "total_amount":    round(amount, 2),
            "earned_cashback": cb,
            "earned_points":   pts,
            "discount_percent": discount_pct,
            "discount_value":  discount_value,
            "deducted_points": deducted_points,
            "bill_number":     review.get("bill_number"),
            "bill_date":       str(review.get("bill_date", "")),
            "bill_time":       review.get("bill_time"),
            "source":          "manual_review",
            "scanned_at":      scan_now,
        })

    await notify_user(
        db,
        user_id=uid,
        title=(
            "🎉 Bill Approved — Rewards Added!" if data.action == "approve"
            else "Bill Review Update"
        ),
        message=(
            f"Your bill from {shop_name} (Rs.{int(amount)}) has been verified. "
            f"Rs.{cb:.0f} cashback and {pts} reward points added to your wallet."
        ) if data.action == "approve" else (
            f"Your bill from {shop_name} (Rs.{int(amount)}) could not be verified"
            + (f": {data.admin_note}" if data.admin_note else ".")
        ),
        type="bill_review_approved" if data.action == "approve" else "bill_review_rejected",
        data={"review_id": review_id},
    )

    return {
        "success": True, "action": data.action, "review_id": review_id,
        "scan_type": scan_type,
        "reward_points": pts if data.action == "approve" else 0,
        "cashback":      cb  if data.action == "approve" else 0,
        "discount_value":  discount_value  if data.action == "approve" else 0.0,
        "deducted_points": deducted_points if data.action == "approve" else 0,
    }


# ══════════════════════════════════════════════════════════════════════════════
# AI Bill OCR  —  POST /bill/ocr
#
# The Gemini Vision call used to live inside the Flutter app, which meant the
# API key shipped inside the APK (extractable) and prompt/model changes needed
# an app release. It now lives here: the app POSTs the bill image (base64) and
# gets back the extracted fields. The app keeps its on-device ML Kit fallback
# for when this endpoint is unreachable or returns nothing.
#
# Key: set GEMINI_API_KEY in fastapi/backend/.env  (new AI Studio "auth keys"
# start with "AQ." and are sent via the x-goog-api-key header).
# ══════════════════════════════════════════════════════════════════════════════

import asyncio
import json as _json
import httpx

GEMINI_MODEL_URL = (
    "https://generativelanguage.googleapis.com/v1beta/models/"
    "gemini-2.5-flash:generateContent"
)

# TODO: move this default into fastapi/backend/.env as GEMINI_API_KEY=...
_GEMINI_KEY_DEFAULT = "AQ.Ab8RN6IFWok-_JzuTJaKM0P05tF533XYuFRI_RbRhXZzsFX6uw"

_OCR_PROMPT = """
You are a bill/receipt OCR assistant. Carefully analyze the receipt image and extract:

1. shop_name: The business/store name — usually the largest, bold, or logo text at the top of the receipt (before address, phone, GSTIN, or date). Example: "The Daily Grind Cafe", "DMart".
   - NEVER return generic header words like "TAX INVOICE", "RETAIL INVOICE", "CASH MEMO", "RECEIPT", "BILL", "WELCOME", "CUSTOMER COPY", "THANK YOU" — the shop name is always an actual business name.
   - If the top line is a header word like "TAX INVOICE", the real shop name is usually just above or below it.

2. total_amount: The FINAL amount the customer actually PAID, after ALL discounts and taxes.
   - Receipts often show Subtotal, Discount/Savings, Tax/GST/CGST/SGST lines, and then a final total. Always pick the final payable figure.
   - The label may be "TOTAL", "TOTAL AMOUNT", "GRAND TOTAL", "NET TOTAL", "NET PAYABLE", "AMOUNT PAYABLE", "FINAL AMOUNT", "AMOUNT PAID", "BILL AMOUNT" — or there may be NO label at all, just a bold/large printed number. On some bills this final amount is printed at the TOP of the receipt, not the bottom.
   - NEVER return: the discount value, savings amount, subtotal (pre-discount), a tax amount, cash tendered, change/balance returned, loyalty points, or an individual item price.
   - Sanity check: when subtotal, discount and tax lines are visible, the total should equal subtotal - discount + tax.
   - Return only the numeric value (no currency sign or commas).

3. bill_date: The date on the receipt. Always return in DD/MM/YYYY format. For example, if the receipt shows "May 23, 2026" return "23/05/2026".

4. bill_number: The receipt/invoice/bill number (e.g., "98432", "INV-001"). Strip any leading # symbol.

Return ONLY a single valid JSON object with no markdown or explanation. Example:
{"shop_name":"The Daily Grind Cafe","total_amount":2008.80,"bill_date":"23/05/2026","bill_number":"98432"}

If a field cannot be confidently read, set it to null.
"""


class BillOcrRequest(BaseModel):
    image_base64: str = Field(..., description="Base64-encoded bill image (no data: prefix)")
    mime_type: Optional[str] = "image/jpeg"


@router.post("/ocr")
async def ai_bill_ocr(data: BillOcrRequest):
    """
    Extract bill fields from an image using Gemini Vision (server-side).

    Returns 200 with:
      {"success": true,  "shop_name": ..., "total_amount": ...,
       "bill_date": "DD/MM/YYYY", "bill_number": ..., "raw": "<gemini json>"}
    or {"success": false, "detail": "..."} when the AI is unavailable — the app
    then falls back to on-device ML Kit OCR.
    """
    key = os.getenv("GEMINI_API_KEY", _GEMINI_KEY_DEFAULT).strip()
    if not key:
        return {"success": False, "detail": "GEMINI_API_KEY not configured"}

    payload = {
        "contents": [{
            "parts": [
                {"inlineData": {
                    "mimeType": data.mime_type or "image/jpeg",
                    "data": data.image_base64,
                }},
                {"text": _OCR_PROMPT},
            ],
        }],
        "generationConfig": {
            "temperature": 0,
            "topP": 1,
            "topK": 1,
            "maxOutputTokens": 512,
            "responseMimeType": "application/json",
            # gemini-2.5-flash is a thinking model — disable thinking so
            # reasoning tokens don't eat the output budget (faster + cheaper).
            "thinkingConfig": {"thinkingBudget": 0},
        },
    }

    last_error = "unknown"
    async with httpx.AsyncClient(timeout=25.0) as client:
        # Up to 2 attempts — occasionally Gemini returns truncated/invalid
        # JSON or a transient 503 "model overloaded". Those usually clear in
        # a second or two, so pause briefly before the retry.
        for attempt in (1, 2):
            if attempt == 2:
                await asyncio.sleep(2.0)
            try:
                resp = await client.post(
                    GEMINI_MODEL_URL,
                    headers={
                        "Content-Type": "application/json",
                        "x-goog-api-key": key,
                    },
                    json=payload,
                )
                if resp.status_code == 429:
                    # Quota/rate limit — retrying immediately is pointless
                    last_error = f"quota exceeded ({resp.status_code})"
                    break
                if resp.status_code != 200:
                    last_error = f"gemini http {resp.status_code}"
                    continue

                body = resp.json()
                candidates = body.get("candidates") or []
                if not candidates:
                    last_error = "no candidates"
                    continue
                parts = ((candidates[0].get("content") or {}).get("parts")) or []
                if not parts:
                    last_error = "no parts"
                    continue
                text = (parts[0].get("text") or "").strip()

                # Strip markdown fences and isolate the first {...} block
                text = text.removeprefix("```json").removesuffix("```").strip()
                start, end = text.find("{"), text.rfind("}")
                if start == -1 or end <= start:
                    last_error = "no json block"
                    continue
                parsed = _json.loads(text[start:end + 1])

                def _clean_str(v):
                    if v is None:
                        return None
                    s = str(v).strip()
                    return s if s and s.lower() != "null" else None

                def _clean_num(v):
                    if v is None:
                        return None
                    if isinstance(v, (int, float)):
                        return float(v)
                    try:
                        return float(str(v).replace(",", "").replace("₹", "").strip())
                    except ValueError:
                        return None

                return {
                    "success":      True,
                    "shop_name":    _clean_str(parsed.get("shop_name")),
                    "total_amount": _clean_num(parsed.get("total_amount")),
                    "bill_date":    _clean_str(parsed.get("bill_date")),
                    "bill_number":  _clean_str(parsed.get("bill_number")),
                    "raw":          text[start:end + 1],
                }
            except Exception as e:  # network error, bad JSON, timeout…
                last_error = str(e)[:200]

    return {"success": False, "detail": last_error}
