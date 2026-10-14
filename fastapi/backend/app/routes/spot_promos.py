"""
Spot Promos — the paid cards in the "Spot Promos" strip.

The one thing worth knowing about this endpoint: there is exactly ONE of it,
and all three app pages (Local Finder, Claimit Select, Claimit Privilege)
call it. That is the product. An advertiser buys a single Spot Promo booking
and it appears in the strip on all three pages — not three bookings, not
three collections, and not three endpoints that could drift apart.

Everything else here is deliberately the same machinery Nearby Deals uses:
`nearby_or_nearest` for the 5 km → 10 km → nearest widening, `filter_live`
so an expired campaign stops showing, and `sort_by_tier` so Premium ranks
above Standard. Reusing it means a Spot Promo behaves exactly like a deal in
a quiet pincode, which is what makes the three strips look right without any
screen having to special-case them.
"""
from typing import Optional

from fastapi import APIRouter, Depends, Query

from ..database import get_db
from ..utils.auth import get_current_user
from ..utils.helpers import serialize_doc, sort_by_tier
from ..utils.s3 import public_url
from ..utils.geo_filter import attach_distance, nearby_or_nearest
from ..utils.ad_window import filter_live

router = APIRouter(prefix="/spot-promos", tags=["Spot Promos"])


def _fix_image_url(doc: dict) -> dict:
    """Stored S3 keys → URLs the app can load.

    Same two-field convention as deals and shops (`image_s3_key`/`image_url`
    for the card, `image_s3_keys`/`image_urls` for the landing carousel), so
    the card widget the app already has renders these with no change.
    """
    key = doc.get("image_s3_key") or doc.get("image_key") or ""
    if key:
        doc["image_url"] = public_url(key)

    keys = doc.get("image_s3_keys") or []
    if isinstance(keys, list) and keys:
        urls = [public_url(k) for k in keys if k]
        if urls:
            doc["image_urls"] = urls
            if not doc.get("image_url"):
                doc["image_url"] = urls[0]
    return doc


@router.get("/nearby")
async def get_spot_promos(
    category: Optional[str] = Query(None),
    lat: Optional[float] = Query(None, description="Latitude of the SELECTED location"),
    lng: Optional[float] = Query(None, description="Longitude of the selected location"),
    radius_km: float = Query(5.0, ge=0.5, le=50),
    limit: int = Query(20, ge=1, le=50),
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    query: dict = {}
    if category and category.lower() not in ("all", ""):
        query["category"] = {"$regex": category, "$options": "i"}

    promos, geo_info = await nearby_or_nearest(
        db, "spot_promos", lat, lng, radius_km, query, limit,
        post_filter=filter_live,
    )
    if promos is None:
        # No coordinates supplied at all (an older app build, or the user
        # never granted location). Fall back to newest-first rather than
        # returning nothing — the strip is paid inventory and must render.
        promos = filter_live(
            await db.spot_promos.find(query)
            .sort("created_at", -1).to_list(length=limit)
        )

    result = [attach_distance(_fix_image_url(serialize_doc(p))) for p in promos]
    result = sort_by_tier(result)
    return {"success": True, "promos": result, "total": len(result), **geo_info}
