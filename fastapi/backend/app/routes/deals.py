"""
Deals endpoints — data served from MongoDB.
"""
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from bson import ObjectId
from ..database import get_db
from ..utils.auth import get_current_user
from ..utils.helpers import serialize_doc, prioritize_by_location, sort_by_tier
from ..utils.s3 import public_url
from ..utils.geo_filter import nearby_docs, attach_distance
from ..utils.ad_window import filter_live

router = APIRouter(prefix="/deals", tags=["Deals"])


def _fix_image_url(doc: dict) -> dict:
    key = doc.get("image_s3_key") or doc.get("image_key") or ""
    if key:
        doc["image_url"] = public_url(key)
    return doc


@router.get("/nearby")
async def get_nearby_deals(
    location: Optional[str] = Query(None),
    category: Optional[str] = Query(None),
    area: Optional[str] = Query(None, description="User's area name — local deals float to top"),
    pincode: Optional[str] = Query(None, description="User's pincode — local deals float to top"),
    lat: Optional[float] = Query(None, description="Latitude of the SELECTED location"),
    lng: Optional[float] = Query(None, description="Longitude of the selected location"),
    radius_km: float = Query(5.0, ge=0.5, le=50),
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    query: dict = {"deal_group": "nearby"}
    if category and category.lower() not in ("all", ""):
        query["category"] = {"$regex": category, "$options": "i"}

    # Radius filter when the app sends the selected point, so this page agrees
    # with the search screen about what "nearby" means. Without coordinates it
    # behaves exactly as it always has — an older app build keeps working.
    deals = await nearby_docs(db, "deals", lat, lng, radius_km, query, 100)
    if deals is None:
        deals = await db.deals.find(query).sort("name", 1).to_list(length=100)
    # Only ads inside their paid Friday→Thursday week. This is what makes a
    # deal booked on Tuesday stay hidden until Friday, and stop showing after
    # its Thursday — no cron job required.
    deals = filter_live(deals)
    result = [attach_distance(_fix_image_url(serialize_doc(d))) for d in deals]
    # Premium-first WITHIN each location group: tier-sort first (stable), then
    # partition by location — prioritize_by_location's partition is itself
    # stable, so the premium-first order survives inside both the "local"
    # and "everywhere else" groups. If the user moves to a new area, that
    # area's own Premium deals float to the top instead.
    result = sort_by_tier(result)
    result = prioritize_by_location(result, area or location or "", pincode or "")
    return {"success": True, "deals": result, "total": len(result)}


@router.get("/brand")
async def get_brand_deals(
    category: Optional[str] = Query(None),
    lat: Optional[float] = Query(None, description="Latitude of the SELECTED location"),
    lng: Optional[float] = Query(None, description="Longitude of the selected location"),
    radius_km: float = Query(5.0, ge=0.5, le=50),
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    query: dict = {"deal_group": "brand"}
    if category and category.lower() not in ("all", ""):
        query["category"] = {"$regex": category, "$options": "i"}

    # Brand Deals are location-scoped now, by the client's decision: each one
    # carries a pincode and is shown within the radius like every other
    # feature. A brand deal with no coordinates simply won't appear until its
    # pincode is filled in.
    deals = await nearby_docs(db, "deals", lat, lng, radius_km, query, 100)
    if deals is None:
        deals = await db.deals.find(query).sort("name", 1).to_list(length=100)
    # Only ads inside their paid Friday→Thursday week. This is what makes a
    # deal booked on Tuesday stay hidden until Friday, and stop showing after
    # its Thursday — no cron job required.
    deals = filter_live(deals)
    result = [attach_distance(_fix_image_url(serialize_doc(d))) for d in deals]
    # Premium ads still rank first within whatever is in range.
    result = sort_by_tier(result)
    return {"success": True, "deals": result, "total": len(result)}


@router.get("/{deal_id}")
async def get_deal_detail(
    deal_id: str,
    current_user: dict = Depends(get_current_user),
):
    db = get_db()
    deal = None
    if ObjectId.is_valid(deal_id):
        deal = await db.deals.find_one({"_id": ObjectId(deal_id)})
    if not deal:
        deal = await db.deals.find_one({"id": deal_id})
    if not deal:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Deal not found")
    return {"success": True, "deal": _fix_image_url(serialize_doc(deal))}
