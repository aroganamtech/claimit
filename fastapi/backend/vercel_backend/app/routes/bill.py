"""
Bill scan / wallet / history endpoints — Vercel backend.

Routes (all read by the Flutter app):
  POST /bill/scan     — record a scanned bill, award cashback + points
  GET  /bill/wallet   — current wallet totals for the logged-in user
  GET  /bill/history  — last 100 scans, newest first

Business rules (must stay in sync with BillRewardProvider in Flutter):
  • 1 % cashback  (earned_cashback  = total * 0.01)
  • 10 % points   (earned_points    = total * 0.10, rounded)
  • New users get NEW_USER_BONUS = 1 000 free welcome points on wallet creation
  • Duplicate detection: fingerprint = "shop|date|HH:MM|amount" (with time)
                        or           "shop|date|amount"         (without time)
    → matches the duplicateKey built in BillRewardEntry.duplicateKey (Flutter)
  • bill_scans documents auto-expire after 24 h (TTL index on scanned_at)
"""

from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from bson import ObjectId

from ..database import get_db
from ..utils.auth import get_current_user, decode_token

router = APIRouter(prefix="/bill", tags=["Bill"])

NEW_USER_BONUS = 1000   # free points awarded on first wallet creation


# ── Optional auth ─────────────────────────────────────────────────────────────
# The Flutter app always sends a Bearer token, but we also accept a body
# user_id as a fallback (clock-skew / staging secret differences).

async def _resolve_user(request: Request, body_uid: Optional[str]) -> Optional[str]:
    """Return user_id string or None.  Never raises — callers decide if 401 needed."""
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
    # Fallback: body-supplied user_id
    return body_uid


# ── Request model ──────────────────────────────────────────────────────────────
class BillScanRequest(BaseModel):
    total_amount:  float          = Field(..., gt=0)
    reward_points: Optional[int]  = None   # ignored — server recalculates
    shop_name:     Optional[str]  = None
    bill_number:   Optional[str]  = None
    bill_date:     Optional[str]  = None   # YYYY-MM-DD from OCR
    bill_time:     Optional[str]  = None   # HH:MM from OCR (24-h) — used in dup key
    image_base64:  Optional[str]  = None   # stored for audit, not processed
    user_id:       Optional[str]  = None   # fallback when Bearer unavailable


# ── Helpers ────────────────────────────────────────────────────────────────────
def _dup_key(shop: str, bill_date: str, amount: float,
             bill_time: Optional[str] = None) -> str:
    """
    Duplicate fingerprint — must match BillRewardEntry.duplicateKey in Flutter.

    With time:    "shop|YYYY-M-D|HH:MM|amount"
    Without time: "shop|YYYY-M-D|amount"

    Two purchases at the same shop on the same day for the same price but at
    different times produce different keys and are both allowed.
    """
    s   = shop.lower().strip()
    amt = f"{amount:.0f}"
    t   = (bill_time or "").strip()
    if t:
        return f"{s}|{bill_date}|{t}|{amt}"
    return f"{s}|{bill_date}|{amt}"


async def _get_or_create_wallet(db, uid: str) -> dict:
    """Return existing wallet or create a brand-new one with 1 000 welcome pts."""
    wallet = await db.user_wallets.find_one({"user_id": uid})
    if wallet is None:
        wallet = {
            "user_id":           uid,
            "reward_points":     NEW_USER_BONUS,   # ← 1 000 welcome bonus
            "cashback_wallet":   0.0,
            "lifetime_cashback": 0.0,
            "total_scans":       0,
            "created_at":        datetime.now(timezone.utc),
        }
        await db.user_wallets.insert_one(wallet)
    return wallet


# ── POST /bill/scan ────────────────────────────────────────────────────────────
@router.post("/scan")
async def scan_bill(data: BillScanRequest, request: Request):
    uid = await _resolve_user(request, data.user_id)
    if not uid:
        raise HTTPException(status_code=401,
                            detail="Authentication required — send Bearer token or user_id")

    db    = get_db()
    total = data.total_amount

    # ── Load / create wallet ──────────────────────────────────────────────────
    wallet   = await _get_or_create_wallet(db, uid)
    is_first = wallet.get("total_scans", 0) == 0   # first real scan this wallet?

    # ── Duplicate check ───────────────────────────────────────────────────────
    bill_date = data.bill_date or datetime.now(timezone.utc).strftime("%Y-%m-%d")
    key = _dup_key(
        shop      = data.shop_name or "",
        bill_date = bill_date,
        amount    = total,
        bill_time = data.bill_time,
    )
    if await db.bill_scans.find_one({"user_id": uid, "dup_key": key}):
        raise HTTPException(status_code=409, detail="Bill already scanned")

    # ── Calculate rewards (server is authoritative) ───────────────────────────
    earned_cb  = round(total * 0.01, 2)    # 1 % cashback
    earned_pts = round(total * 0.10)       # 10 % reward points

    # ── Cumulative wallet update ──────────────────────────────────────────────
    new_pts      = wallet["reward_points"]     + earned_pts
    new_cb_wallet= wallet["cashback_wallet"]   + earned_cb
    new_lifetime = wallet["lifetime_cashback"] + earned_cb
    new_scans    = wallet.get("total_scans", 0) + 1

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

    # ── Store scan record ─────────────────────────────────────────────────────
    shop_name = (data.shop_name or "Shop").strip()
    scan_doc = {
        "user_id":         uid,
        "dup_key":         key,
        "shop_name":       shop_name,
        "total_amount":    total,
        "earned_cashback": earned_cb,
        "earned_points":   earned_pts,
        "bill_number":     data.bill_number,
        "bill_date":       bill_date,
        "bill_time":       data.bill_time,
        "scanned_at":      datetime.now(timezone.utc),
    }
    res = await db.bill_scans.insert_one(scan_doc)

    return {
        "ok":               True,
        "scan_id":          str(res.inserted_id),
        "shop_name":        shop_name,
        # Earned this scan
        "earned_cashback":  earned_cb,
        "earned_points":    earned_pts,
        # New user welcome bonus info
        "is_new_user_bonus": is_first,
        "bonus_points":     NEW_USER_BONUS if is_first else 0,
        # Running wallet totals — Flutter app updates its local state from these
        "reward_points":    new_pts,
        "cashback_wallet":  new_cb_wallet,
        "lifetime_cashback": new_lifetime,
    }


# ── GET /bill/wallet ──────────────────────────────────────────────────────────
@router.get("/wallet")
async def get_wallet(
    request: Request,
    current_user: dict = Depends(get_current_user),
):
    db     = get_db()
    uid    = str(current_user["_id"])
    wallet = await _get_or_create_wallet(db, uid)
    return {
        "reward_points":     wallet["reward_points"],
        "cashback_wallet":   wallet["cashback_wallet"],
        "lifetime_cashback": wallet["lifetime_cashback"],
        "total_scans":       wallet.get("total_scans", 0),
    }


# ── GET /bill/history ─────────────────────────────────────────────────────────
@router.get("/history")
async def bill_history(
    current_user: dict = Depends(get_current_user),
):
    """Returns a plain list (Flutter app iterates it directly)."""
    db    = get_db()
    uid   = str(current_user["_id"])
    scans = await db.bill_scans.find(
        {"user_id": uid}
    ).sort("scanned_at", -1).to_list(100)

    return [
        {
            "id":              str(s["_id"]),
            "shop_name":       s.get("shop_name", ""),
            "total_amount":    s.get("total_amount", 0),
            "earned_cashback": s.get("earned_cashback", 0),
            "earned_points":   s.get("earned_points", 0),
            "bill_number":     s.get("bill_number"),
            "bill_date":       s.get("bill_date"),
            "bill_time":       s.get("bill_time"),
            "scanned_at":      s["scanned_at"].isoformat() if s.get("scanned_at") else "",
        }
        for s in scans
    ]
