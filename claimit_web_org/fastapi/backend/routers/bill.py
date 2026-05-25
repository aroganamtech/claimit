from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from database import app_db
from utils.dependencies import get_current_user_optional
from datetime import datetime

router = APIRouter()

# ── Collections (in claimit_db — same DB the Flutter app reads) ───────────────
_wallets = app_db["user_wallets"]
_scans   = app_db["bill_scans"]

NEW_USER_BONUS = 1000   # free points given on first-ever scan


# ── Request model ─────────────────────────────────────────────────────────────
class BillScanRequest(BaseModel):
    total_amount:  float
    reward_points: Optional[int]  = None   # ignored — we recalc server-side
    shop_name:     Optional[str]  = None
    bill_number:   Optional[str]  = None
    bill_date:     Optional[str]  = None   # YYYY-MM-DD from OCR
    image_base64:  Optional[str]  = None   # stored for audit if needed
    user_id:       Optional[str]  = None   # fallback when Bearer token unavailable


# ── Helpers ───────────────────────────────────────────────────────────────────
def _resolve_uid(current_user, body_uid: Optional[str]) -> Optional[str]:
    if current_user:
        return str(current_user["_id"])
    return body_uid


async def _get_or_create_wallet(uid: str) -> dict:
    """Return existing wallet or create a brand-new one with 1000 welcome pts."""
    wallet = await _wallets.find_one({"user_id": uid})
    if wallet is None:
        wallet = {
            "user_id":          uid,
            "reward_points":    NEW_USER_BONUS,   # ← 1000 welcome bonus
            "cashback_wallet":  0.0,
            "lifetime_cashback": 0.0,
            "total_scans":      0,
            "created_at":       datetime.utcnow(),
        }
        await _wallets.insert_one(wallet)
    return wallet


def _dup_key(shop: str, bill_no: str, bill_date: str, amount: float) -> str:
    """Build the duplicate-detection fingerprint identical to the Flutter side."""
    s   = shop.lower().strip()
    amt = f"{amount:.0f}"
    if bill_no:
        bn = bill_no.lower().replace(" ", "")
        return f"{bn}|{s}|{bill_date}|{amt}"
    return f"{s}|{bill_date}|{amt}"


# ── POST /bill/scan ───────────────────────────────────────────────────────────
@router.post("/scan")
async def bill_scan(
    body: BillScanRequest,
    current_user=Depends(get_current_user_optional),
):
    uid = _resolve_uid(current_user, body.user_id)
    if not uid:
        raise HTTPException(status_code=401,
                            detail="User identification required — send Bearer token or user_id")

    total = body.total_amount
    if total <= 0:
        raise HTTPException(status_code=400, detail="Bill amount must be positive")

    # ── Load / create wallet ─────────────────────────────────────────────────
    wallet    = await _get_or_create_wallet(uid)
    is_first  = wallet.get("total_scans", 0) == 0   # first real scan?

    # ── Duplicate check ──────────────────────────────────────────────────────
    bill_date = body.bill_date or datetime.utcnow().strftime("%Y-%m-%d")
    key = _dup_key(
        shop     = body.shop_name or "",
        bill_no  = body.bill_number or "",
        bill_date= bill_date,
        amount   = total,
    )
    if await _scans.find_one({"user_id": uid, "dup_key": key}):
        raise HTTPException(status_code=409, detail="Bill already scanned")

    # ── Calculate rewards (server is authoritative) ──────────────────────────
    earned_cb  = round(total * 0.01, 2)   # 1 %  cashback
    earned_pts = round(total * 0.10)      # 10 % reward points

    # ── Cumulative update ─────────────────────────────────────────────────────
    new_pts      = wallet["reward_points"]     + earned_pts
    new_cb_wallet= wallet["cashback_wallet"]   + earned_cb
    new_lifetime = wallet["lifetime_cashback"] + earned_cb
    new_scans    = wallet.get("total_scans", 0) + 1

    await _wallets.update_one(
        {"user_id": uid},
        {"$set": {
            "reward_points":    new_pts,
            "cashback_wallet":  new_cb_wallet,
            "lifetime_cashback": new_lifetime,
            "total_scans":      new_scans,
            "updated_at":       datetime.utcnow(),
        }},
    )

    # ── Store scan record ────────────────────────────────────────────────────
    scan_doc = {
        "user_id":         uid,
        "dup_key":         key,
        "shop_name":       (body.shop_name or "Shop").strip(),
        "total_amount":    total,
        "earned_cashback": earned_cb,
        "earned_points":   earned_pts,
        "bill_number":     body.bill_number,
        "bill_date":       bill_date,
        "scanned_at":      datetime.utcnow(),
    }
    res = await _scans.insert_one(scan_doc)

    return {
        "ok":               True,
        "scan_id":          str(res.inserted_id),
        "shop_name":        scan_doc["shop_name"],
        # Earned this scan
        "earned_cashback":  earned_cb,
        "earned_points":    earned_pts,
        # New user welcome bonus info
        "is_new_user_bonus": is_first,
        "bonus_points":     NEW_USER_BONUS if is_first else 0,
        # Running wallet totals (app updates its local state from these)
        "reward_points":    new_pts,
        "cashback_wallet":  new_cb_wallet,
        "lifetime_cashback": new_lifetime,
    }


# ── GET /bill/wallet ──────────────────────────────────────────────────────────
@router.get("/wallet")
async def get_wallet(current_user=Depends(get_current_user_optional)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Authentication required")
    uid    = str(current_user["_id"])
    wallet = await _get_or_create_wallet(uid)
    return {
        "reward_points":    wallet["reward_points"],
        "cashback_wallet":  wallet["cashback_wallet"],
        "lifetime_cashback": wallet["lifetime_cashback"],
        "total_scans":      wallet.get("total_scans", 0),
    }


# ── GET /bill/history ─────────────────────────────────────────────────────────
@router.get("/history")
async def get_history(current_user=Depends(get_current_user_optional)):
    if not current_user:
        raise HTTPException(status_code=401, detail="Authentication required")
    uid   = str(current_user["_id"])
    scans = await _scans.find({"user_id": uid}).sort("scanned_at", -1).to_list(100)
    return [
        {
            "id":              str(s["_id"]),
            "shop_name":       s.get("shop_name", ""),
            "total_amount":    s.get("total_amount", 0),
            "earned_cashback": s.get("earned_cashback", 0),
            "earned_points":   s.get("earned_points", 0),
            "bill_number":     s.get("bill_number"),
            "bill_date":       s.get("bill_date"),
            "scanned_at":      s["scanned_at"].isoformat() if s.get("scanned_at") else "",
        }
        for s in scans
    ]
