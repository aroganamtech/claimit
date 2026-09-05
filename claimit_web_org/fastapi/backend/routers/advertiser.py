from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from database import (
    ads_collection, transactions_collection,
    app_deals_collection, app_reels_collection, app_banners_collection,
    app_db,
)
from utils.dependencies import get_current_user
from utils.cashfree import get_payment_link_status
from utils.pincode_geo import resolve_point_for_ad
from utils.ad_cycle import next_cycle, cycle_info, is_live
from utils.s3 import (
    generate_presigned_upload_url,
    generate_presigned_url_sync as _presign,
    generate_video_url_sync as _video_presign,
    ALLOWED_VIDEO_TYPES, ALLOWED_IMAGE_TYPES,
)
from bson import ObjectId
from datetime import datetime, timedelta
from typing import Optional
import json

router = APIRouter()

# Pricing per "Claimit Advertising Packages (Weekly)" — all prices are for a
# fixed 7-day campaign and are inclusive of GST. Ad types below marked with
# both a "premium" and "standard" key support the Premium/Standard picker;
# home_banner is a single package (no tier split).
AD_PRICES = {
    "home_banner":  {"standard": 700},
    "nearby_deals": {"premium": 1050, "standard": 700},
    "brand_deals":  {"premium": 700,  "standard": 700},
    "promo_reelz":  {"premium": 700,  "standard": 700},
}

# Premium slots (Nearby Deals + Brand Deals) are scarce inventory. The cap is
# admin-configurable (see /admin/ad-settings) so it can be raised later
# without a code change; these are just the fallback defaults.
DEFAULT_MAX_PREMIUM_NEARBY = 3
DEFAULT_MAX_PREMIUM_BRAND  = 3


async def _ad_price(ad_type: str, tier: str) -> int:
    """Authoritative price for an ad booking — always the current admin-configured
    value (utils.pricing.get_pricing), never the hardcoded AD_PRICES table above,
    so a price change in the admin panel takes effect on the very next booking."""
    from utils.pricing import get_pricing
    pricing = await get_pricing()
    if ad_type == "home_banner":
        return pricing["ad_home_banner"]
    key = f"ad_{ad_type}_{tier}"
    if key in pricing:
        return pricing[key]
    # Fallback for any ad_type/tier combo without a pricing.py entry (shouldn't
    # happen with the 4 known ad types, but keeps this from ever raising).
    tiers = AD_PRICES.get(ad_type, {})
    return tiers.get(tier) or tiers.get("standard") or next(iter(tiers.values()), 700)


async def _get_premium_caps() -> dict:
    """Admin-configurable premium slot caps, stored the same way as the
    existing new-user-bonus app_config (routers/admin.py), key='premium_slots'."""
    cfg = await app_db["app_config"].find_one({"key": "premium_slots"})
    return {
        "nearby_deals": int(cfg.get("max_nearby", DEFAULT_MAX_PREMIUM_NEARBY)) if cfg else DEFAULT_MAX_PREMIUM_NEARBY,
        "brand_deals":  int(cfg.get("max_brand", DEFAULT_MAX_PREMIUM_BRAND)) if cfg else DEFAULT_MAX_PREMIUM_BRAND,
    }


async def _premium_slot_usage(ad_type: str, pincode: str, cap: int) -> dict:
    """Count Premium ads for this ad_type that are still within their 7-day
    campaign window. Nearby Deals are scoped per-pincode (each location gets
    its own pool); Brand Deals are global (shown top-of-list everywhere, not
    location filtered).

    Note: nothing else in this backend flips an ad's `status` from
    active/scheduled to expired once its 7 days are up, so we can't just
    trust `status` here — we also check `end_date` live. This is what makes
    a booked Premium slot free up automatically 7 days after publish, as
    opposed to staying "booked" forever.
    """
    query = {
        "ad_type": ad_type,
        "tier": "premium",
        "status": {"$in": ["active", "scheduled"]},
    }
    if ad_type == "nearby_deals":
        query["pincode"] = pincode
    candidates = await ads_collection.find(query, {"end_date": 1}).to_list(1000)
    today = datetime.utcnow().date()
    used = 0
    for c in candidates:
        try:
            end = datetime.strptime(c.get("end_date", ""), "%d/%m/%Y").date()
        except (ValueError, TypeError):
            # Missing/malformed end_date — be conservative and count it as used.
            used += 1
            continue
        if end >= today:
            used += 1
    return {"max": cap, "used": used, "remaining": max(0, cap - used)}

VIDEO_EXTENSIONS = (".mp4", ".mov", ".m4v", ".webm")


def _is_video_key(key: str) -> bool:
    """Best-effort video detection from an S3 key's file extension."""
    return bool(key) and key.lower().endswith(VIDEO_EXTENSIONS)


def serialize_ad(ad):
    ad["id"] = str(ad["_id"])
    del ad["_id"]
    # Reels track views in view_count and likes in like_count.
    # Normalize to a single "views" and "like_count" field so the
    # advertiser dashboard can display them in a uniform way.
    if ad.get("ad_type") == "promo_reelz":
        ad["views"] = int(ad.get("view_count") or 0)
        ad["like_count"] = int(ad.get("like_count") or 0)
    else:
        ad.setdefault("views", 0)
        ad["like_count"] = 0
    return ad


# ── Presign upload (direct browser -> S3, bypasses Vercel 4.5 MB limit) ───────

class PresignRequest(BaseModel):
    filename: str
    content_type: str
    folder: str = "ads"


@router.post("/presign-upload")
async def presign_upload(body: PresignRequest, current_user=Depends(get_current_user)):
    is_video = body.content_type in ALLOWED_VIDEO_TYPES
    is_image = body.content_type in ALLOWED_IMAGE_TYPES
    if not is_video and not is_image:
        raise HTTPException(status_code=400,
            detail=f"Unsupported type: {body.content_type}")
    return generate_presigned_upload_url(
        folder=body.folder,
        filename=body.filename,
        content_type=body.content_type,
        is_video=is_video,
    )


# ── Create ad (JSON body — creative_key / thumbnail_key from direct S3 upload) -

class CreateAdRequest(BaseModel):
    ad_type: str
    tier: str = "standard"  # "premium" | "standard" — ignored for home_banner
    pincode: str = "000000"
    publish_today: bool = True
    scheduled_date: Optional[str] = None
    creative_key: Optional[str] = None
    thumbnail_key: Optional[str] = None
    # Cashfree payment reference — set by the frontend once
    # GET /payments/status/{link_id} returns "PAID". Re-verified
    # server-side below before the ad is created/charged.
    payment_link_id: Optional[str] = None
    # Home banner
    headline: Optional[str] = None
    sub: Optional[str] = None
    cta_link: Optional[str] = None
    # Promo reelz
    shop_name: Optional[str] = None
    shop_location: Optional[str] = None
    shop_category: Optional[str] = None
    caption: Optional[str] = None
    tag: Optional[str] = None
    # Deal
    name: Optional[str] = None
    location: Optional[str] = None
    description: Optional[str] = None
    address: Optional[str] = None
    phone: Optional[str] = None
    timing: Optional[str] = None
    type: Optional[str] = None
    cashback: Optional[str] = None
    distance: Optional[str] = None
    tags: Optional[str] = None
    offer: Optional[str] = None
    title: Optional[str] = None


@router.get("/ad-cycle")
async def get_ad_cycle(current_user=Depends(get_current_user)):
    """The dates the ad being booked right now will run.

    The form calls this BEFORE taking payment and shows `message` verbatim, so
    an advertiser booking on a Tuesday knows their ad goes live on Friday
    rather than discovering it after they have paid.
    """
    return await cycle_info()


@router.post("/ads/create")
async def create_ad(body: CreateAdRequest, current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    ad_type = body.ad_type
    tier    = (body.tier or "standard").strip().lower()
    if tier not in ("premium", "standard"):
        tier = "standard"
    amount  = await _ad_price(ad_type, tier)

    # Every ad booking now requires a completed Cashfree payment before the
    # ad is created — mirrors the same Payment Links flow already used on
    # the mobile app for Local Finds / Local Classifieds. We don't trust the
    # frontend's word for it: re-check the link's status directly with
    # Cashfree here.
    if not body.payment_link_id:
        raise HTTPException(status_code=402, detail="Payment is required before publishing an ad.")
    link_status = await get_payment_link_status(body.payment_link_id)
    if (link_status.get("link_status") or "").upper() != "PAID":
        raise HTTPException(
            status_code=402,
            detail="Payment not completed yet. Please complete the payment and try again.",
        )

    # Premium is scarce inventory for both Nearby Deals (per-location pool)
    # and Brand Deals (global pool). Enforce the admin-configured cap here.
    # Note: since payment already happened above, a cap collision at this
    # point is a rare race (two advertisers paying for the last slot at
    # once) — the ad is rejected and the advertiser should be refunded
    # manually; this trade-off keeps the slot cap always exact rather than
    # ever over-selling it.
    if tier == "premium" and ad_type in ("nearby_deals", "brand_deals"):
        caps = await _get_premium_caps()
        cap = caps[ad_type]
        usage = await _premium_slot_usage(ad_type, body.pincode, cap)
        if usage["remaining"] <= 0:
            label = "Nearby Deals" if ad_type == "nearby_deals" else "Brand Deals"
            scope = "for this location" if ad_type == "nearby_deals" else "right now"
            suggestion = ", or pick a different pincode" if ad_type == "nearby_deals" else ""
            raise HTTPException(
                status_code=400,
                detail=(
                    f"All {cap} Premium {label} slots {scope} are already booked. "
                    f"Please choose Standard{suggestion}."
                ),
            )

    # ── Weekly ad cycle: every ad runs Friday 00:00 → Thursday 23:59 ─────────
    # The advertiser no longer picks a start date. They buy the next slot: pay
    # on a Friday and it is live that day, pay any other day and it goes live
    # the coming Friday. The dates were shown on the form before payment
    # (GET /advertiser/ad-cycle), so nobody pays expecting to be live today.
    #
    # This is what makes the Premium slot caps meaningful — every ad in a slot
    # competes over the same window instead of starting on arbitrary days.
    cycle_start, cycle_end = await next_cycle()
    pub_date  = cycle_start
    end_date  = cycle_end
    # Live immediately only when the cycle has already begun today; otherwise
    # it waits, and the read-side activation flips it on when Friday arrives.
    ad_status = "active" if is_live(cycle_start) else "scheduled"

    # Resolve S3 keys to presigned URLs
    creative_s3_key  = body.creative_key or ""
    thumbnail_s3_key = body.thumbnail_key or ""

    # home_banner now supports either an image OR a video creative — detect by
    # the uploaded file's extension (promo_reelz is always video).
    is_video = ad_type == "promo_reelz" or (
        ad_type == "home_banner" and _is_video_key(creative_s3_key)
    )
    creative_url  = (_video_presign(creative_s3_key) if is_video else _presign(creative_s3_key)) if creative_s3_key else ""
    thumbnail_url = _presign(thumbnail_s3_key) if thumbnail_s3_key else ""

    parsed_tags: list = []
    if body.tags:
        try:
            parsed_tags = json.loads(body.tags)
        except Exception:
            parsed_tags = [t.strip() for t in body.tags.split(",") if t.strip()]

    ad_doc = {
        "user_id":    user_id,
        "ad_type":    ad_type,
        "tier":       tier,
        "pincode":    body.pincode,
        "publish_date": pub_date.strftime("%d/%m/%Y"),
        "end_date":   end_date.strftime("%d/%m/%Y"),
        # Real datetimes alongside the display strings. Comparing a
        # "dd/mm/yyyy" STRING against a date in MongoDB does not fail — BSON
        # orders Date before String, so every string looks "greater than" every
        # date and an expiry filter silently matches everything. These two
        # fields are what any date comparison must use.
        "publish_at": pub_date,
        "ends_at":    end_date,
        "amount":     amount,
        "status":     ad_status,
        "payment_link_id": body.payment_link_id,
        "views":      0,
        "clicks":     0,
        "created_at": datetime.utcnow(),
    }

    if ad_type == "home_banner":
        ad_doc.update({
            "headline":     body.headline or body.title or "",
            "sub":          body.sub or body.description or "",
            "cta_link":     body.cta_link or "",
            "media_type":   "video" if is_video else "image",
            "image_s3_key": "" if is_video else creative_s3_key,
            "image_url":    "" if is_video else creative_url,
            "video_s3_key": creative_s3_key if is_video else "",
            "video_url":    creative_url if is_video else "",
            "title":        body.headline or body.title or "",
        })

    elif ad_type == "promo_reelz":
        ad_doc.update({
            "shop_name":        body.shop_name or "",
            "shop_location":    body.shop_location or "",
            "shop_category":    body.shop_category or "",
            "caption":          body.caption or "",
            "offer":            body.offer or "",
            "tag":              body.tag or "",
            "video_s3_key":     creative_s3_key,
            "video_url":        creative_url,
            "thumbnail_s3_key": thumbnail_s3_key,
            "thumbnail_url":    thumbnail_url,
            "title":            body.shop_name or "",
        })

    elif ad_type in ("brand_deals", "nearby_deals"):
        ad_doc.update({
            "name":         body.name or "",
            "location":     body.location or "",
            "offer":        body.offer or "",
            "description":  body.description or "",
            "address":      body.address or "",
            "phone":        body.phone or "",
            "timing":       body.timing or "",
            "type":         body.type or "",
            "cashback":     body.cashback or "1% Cashback",
            "distance":     body.distance or "",
            "tags":         parsed_tags,
            "image_s3_key": creative_s3_key,
            "image_url":    creative_url,
            "rating":       4.0,
            "reviews":      0,
            "deal_group":   "brand" if ad_type == "brand_deals" else "nearby",
            "title":        body.name or "",
        })

    # ── Coordinates, so the ad is visible to the app's 5 km radius search ────
    # The advertiser already gives us a PIN code (it drives the Premium slot
    # caps above). Turning it into a point here is what makes Nearby Deals,
    # Brand Deals and Promo Reelz appear in a location search at all — without
    # it they carry no geo and $geoNear can never return them.
    #
    # Best-effort by design: if the lookup fails the ad still publishes, just
    # without coordinates, and backfill_geo.py can fill it in later. Never let
    # a geocoding hiccup block a paid ad.
    ad_lat, ad_lng, ad_geo = await resolve_point_for_ad(
        app_db, pincode=body.pincode
    )
    if ad_geo:
        ad_doc.update({"lat": ad_lat, "lng": ad_lng, "geo": ad_geo})

    result = await ads_collection.insert_one(ad_doc)
    ad_id  = str(result.inserted_id)

    # Mirror into app-facing collections
    if ad_type == "home_banner":
        await app_banners_collection.insert_one({
            "web_ad_id":    ad_id,
            "headline":     ad_doc.get("headline", ""),
            "sub":          ad_doc.get("sub", ""),
            "cta_link":     ad_doc.get("cta_link", ""),
            "media_type":   ad_doc.get("media_type", "image"),
            "image_s3_key": ad_doc.get("image_s3_key", ""),
            "image_url":    ad_doc.get("image_url", ""),
            "video_s3_key": ad_doc.get("video_s3_key", ""),
            "video_url":    ad_doc.get("video_url", ""),
            "pincode":      body.pincode,
            "lat":          ad_lat,
            "lng":          ad_lng,
            "geo":          ad_geo,
            "status":       ad_status,
            "end_date":     end_date.strftime("%d/%m/%Y"),
            "publish_date": pub_date.strftime("%d/%m/%Y"),
            "publish_at":   pub_date,
            "ends_at":      end_date,
            "created_at":   datetime.utcnow(),
        })

    elif ad_type in ("brand_deals", "nearby_deals"):
        await app_deals_collection.insert_one({
            "web_ad_id":  ad_id,
            "deal_group": ad_doc["deal_group"],
            "tier":       tier,
            "name":       ad_doc.get("name", ""),
            "location":   ad_doc.get("location", ""),
            "offer":      ad_doc.get("offer", ""),
            "cashback":   ad_doc.get("cashback", "1% Cashback"),
            "distance":   ad_doc.get("distance", ""),
            "type":       ad_doc.get("type", ""),
            "category":   ad_doc.get("type", ""),
            "image_s3_key": creative_s3_key,
            "image_url":  creative_url,
            "description": ad_doc.get("description", ""),
            "address":    ad_doc.get("address", ""),
            "phone":      ad_doc.get("phone", ""),
            "timing":     ad_doc.get("timing", ""),
            "rating":     4.0,
            "reviews":    0,
            "tags":       parsed_tags,
            "pincode":    body.pincode,
            # Geo point derived from the PIN code above — this is what lets a
            # deal show up in "within 5 km of Madurai".
            "lat":        ad_lat,
            "lng":        ad_lng,
            "geo":        ad_geo,
            "status":     ad_status,
            "end_date":   end_date.strftime("%d/%m/%Y"),
            "publish_date": pub_date.strftime("%d/%m/%Y"),
            "publish_at": pub_date,
            "ends_at":    end_date,
            "created_at": datetime.utcnow(),
        })

    elif ad_type == "promo_reelz":
        await app_reels_collection.insert_one({
            "web_ad_id":        ad_id,
            "shop_name":        ad_doc.get("shop_name", ""),
            "shop_location":    ad_doc.get("shop_location", ""),
            "shop_category":    ad_doc.get("shop_category", ""),
            "caption":          ad_doc.get("caption", ""),
            "offer":            ad_doc.get("offer", ""),
            "video_s3_key":     creative_s3_key,
            "video_url":        creative_url,
            "thumbnail_s3_key": thumbnail_s3_key,
            "thumbnail_url":    thumbnail_url,
            "like_count":       0,
            "view_count":       0,
            "liked_by":         [],
            "tag":              ad_doc.get("tag", ""),
            "pincode":          body.pincode,
            "lat":              ad_lat,
            "lng":              ad_lng,
            "geo":              ad_geo,
            "status":           ad_status,
            "end_date":         end_date.strftime("%d/%m/%Y"),
            "publish_date":     pub_date.strftime("%d/%m/%Y"),
            "publish_at":       pub_date,
            "ends_at":          end_date,
            "created_at":       datetime.utcnow(),
        })

    display_title = (
        ad_doc.get("headline") or ad_doc.get("name") or
        ad_doc.get("shop_name") or ad_doc.get("title") or ""
    )
    await transactions_collection.insert_one({
        "user_id":    user_id,
        "type":       "ad_purchase",
        "ad_id":      ad_id,
        "title":      display_title,
        "amount":     amount,
        "date":       pub_date.strftime("%d/%m/%Y"),
        "payment_link_id": body.payment_link_id,
        "created_at": datetime.utcnow(),
    })

    return {
        "id":           ad_id,
        "ad_type":      ad_type,
        "publish_date": ad_doc["publish_date"],
        "end_date":     ad_doc["end_date"],
        "amount":       amount,
        "status":       ad_status,
    }


# ── Premium slot availability (for the "? Premium vs Standard" + slot counter
#    on the ad registration page) ───────────────────────────────────────────────

@router.get("/premium-slots")
async def get_premium_slots(
    ad_type: str,
    pincode: str = "000000",
    current_user=Depends(get_current_user),
):
    if ad_type not in ("nearby_deals", "brand_deals"):
        raise HTTPException(status_code=400, detail="ad_type must be nearby_deals or brand_deals")
    caps = await _get_premium_caps()
    cap = caps[ad_type]
    usage = await _premium_slot_usage(ad_type, pincode, cap)
    return {
        "ad_type":       ad_type,
        "location_scoped": ad_type == "nearby_deals",
        **usage,
    }


# ── Public pricing (ad type picker reads live prices here) ────────────────────

@router.get("/pricing")
async def get_advertiser_pricing():
    """Current ad prices for all 4 ad types — no auth required, shown on the ad
    type/tier picker before checkout. Same admin-configured source _ad_price()
    uses, so what's displayed always matches what's actually charged."""
    from utils.pricing import get_pricing
    pricing = await get_pricing()
    return {
        "home_banner":  {"standard": pricing["ad_home_banner"]},
        "nearby_deals": {"premium": pricing["ad_nearby_deals_premium"], "standard": pricing["ad_nearby_deals_standard"]},
        "brand_deals":  {"premium": pricing["ad_brand_deals_premium"], "standard": pricing["ad_brand_deals_standard"]},
        "promo_reelz":  {"premium": pricing["ad_promo_reelz_premium"], "standard": pricing["ad_promo_reelz_standard"]},
    }


# ── Dashboard ─────────────────────────────────────────────────────────────────

@router.get("/dashboard")
async def get_dashboard(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    ads = await ads_collection.find({"user_id": user_id}).to_list(100)
    # Reels store views in view_count, others in views
    total_views = sum(
        int(a.get("view_count") or 0) if a.get("ad_type") == "promo_reelz"
        else int(a.get("views") or 0)
        for a in ads
    )
    total_clicks = sum(int(a.get("clicks") or 0) for a in ads)
    total_likes  = sum(int(a.get("like_count") or 0) for a in ads if a.get("ad_type") == "promo_reelz")
    return {
        "total_ads":    len(ads),
        "total_views":  total_views,
        "total_clicks": total_clicks,
        "total_likes":  total_likes,
        "ads": [serialize_ad(a) for a in ads],
    }


# ── List ads ──────────────────────────────────────────────────────────────────

@router.get("/ads")
async def get_ads(status: Optional[str] = None, current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    query = {"user_id": user_id}
    if status and status != "all":
        query["status"] = status
    ads = await ads_collection.find(query).to_list(100)
    return [serialize_ad(a) for a in ads]


# ── Transactions ──────────────────────────────────────────────────────────────

@router.get("/transactions")
async def get_transactions(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    txns = await transactions_collection.find(
        {"user_id": user_id, "type": "ad_purchase"}
    ).sort("created_at", -1).to_list(200)
    return [
        {
            "id":     str(t["_id"]),
            "title":  t.get("title", ""),
            "amount": t.get("amount", 0),
            "date":   t.get("date", ""),
            "ad_id":  t.get("ad_id", ""),
        }
        for t in txns
    ]


# ── Profile ───────────────────────────────────────────────────────────────────

@router.get("/profile")
async def get_profile(current_user=Depends(get_current_user)):
    return {
        "id":    str(current_user["_id"]),
        "name":  current_user.get("name", ""),
        "email": current_user.get("email", ""),
        "phone": current_user.get("phone", ""),
        "role":  current_user.get("role", ""),
    }
