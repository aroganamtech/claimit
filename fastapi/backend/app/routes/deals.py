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
from ..utils.geo_filter import attach_distance, nearby_or_nearest
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

    # Radius first, then widen rather than show nothing: 5 km, then 10 km,
    # then the nearest deals anywhere. An empty screen reads as a broken app,
    # so a quiet area gets the closest deals instead — labelled as such by
    # `showing_nearest` below, never passed off as local.
    #
    # filter_live goes IN as the post-filter: without it a step could return
    # three expired ads, count as "found", and still render blank.
    deals, geo_info = await nearby_or_nearest(
        db, "deals", lat, lng, radius_km, query, 100, post_filter=filter_live,
    )
    if deals is None:
        deals = filter_live(
            await db.deals.find(query).sort("name", 1).to_list(length=100)
        )
    result = [attach_distance(_fix_image_url(serialize_doc(d))) for d in deals]
    # Premium-first WITHIN each location group: tier-sort first (stable), then
    # partition by location — prioritize_by_location's partition is itself
    # stable, so the premium-first order survives inside both the "local"
    # and "everywhere else" groups. If the user moves to a new area, that
    # area's own Premium deals float to the top instead.
    result = sort_by_tier(result)
    result = prioritize_by_location(result, area or location or "", pincode or "")
    return {"success": True, "deals": result, "total": len(result), **geo_info}


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
    # Same widening rule as Nearby Deals — 5 km, 10 km, then nearest anywhere —
    # so a user in a quiet pincode sees brand offers rather than a blank page.
    deals, geo_info = await nearby_or_nearest(
        db, "deals", lat, lng, radius_km, query, 100, post_filter=filter_live,
    )
    if deals is None:
        deals = filter_live(
            await db.deals.find(query).sort("name", 1).to_list(length=100)
        )
    result = [attach_distance(_fix_image_url(serialize_doc(d))) for d in deals]
    # Premium ads still rank first within whatever is in range.
    result = sort_by_tier(result)
    return {"success": True, "deals": result, "total": len(result), **geo_info}


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
