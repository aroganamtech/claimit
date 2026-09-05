"""
pincode_geo.py — turn a 6-digit PIN code into coordinates, reliably and cheaply.

The problem
-----------
The app's search is a 5 km radius query, which can only return records that
carry a geo point. Deals and Promo Reelz never had one: the advertiser form
asks for a PIN code (it is already used for the Premium slot caps) but nobody
ever converted that PIN code into latitude and longitude. So every deal and
every reel was invisible to the radius search.

The approach
------------
A PIN code covers a small area, so its centre is a perfectly good point to
draw a 5 km radius around. Resolution happens in this order, cheapest first:

  1. `pincode_centres` cache — a collection we fill in as we learn
  2. Shops we already have in that PIN code — average their coordinates.
     This is free, needs no network, and is the most accurate source we have
     because it is our own data.
  3. OpenStreetMap — one lookup, then cached forever.

Because step 3 result is written back to the cache, a PIN code is geocoded at
most once for the whole system. A busy PIN code with many advertisers costs
one network call, ever.

Everything here is best-effort and never raises. An ad must still publish if
the geocoder is down; it simply publishes without coordinates, and the
backfill script can fill it in later.
"""
from datetime import datetime
from typing import Optional, Tuple

import httpx

# Cache lives in the app database, beside the data that uses it, so the app
# backend's backfill script can read and write the same table.
_CACHE_NAME = "pincode_centres"


def _clean_pin(pincode) -> str:
    """A valid Indian PIN code, or "" — never a half-parsed number."""
    pin = "".join(ch for ch in str(pincode or "") if ch.isdigit())
    return pin if len(pin) == 6 else ""


def geo_point(lat, lng) -> Optional[dict]:
    """GeoJSON for MongoDB's 2dsphere index. Note the [lng, lat] order —
    reversing it is the single most common geo bug, and it puts Indian shops
    in the Indian Ocean rather than erroring."""
    try:
        lat_f, lng_f = float(lat), float(lng)
    except (TypeError, ValueError):
        return None
    if not (-90 <= lat_f <= 90 and -180 <= lng_f <= 180):
        return None
    return {"type": "Point", "coordinates": [lng_f, lat_f]}


async def _from_cache(app_db, pin: str) -> Optional[Tuple[float, float]]:
    try:
        doc = await app_db[_CACHE_NAME].find_one({"_id": pin})
        if doc and doc.get("lat") is not None and doc.get("lng") is not None:
            return float(doc["lat"]), float(doc["lng"])
    except Exception:
        pass
    return None


async def _from_our_shops(app_db, pin: str) -> Optional[Tuple[float, float]]:
    """The centre of every shop we already have in this PIN code.

    Our own data beats any external service here: these are real verified
    addresses inside the exact PIN code being asked about.
    """
    try:
        cursor = app_db["shops"].find(
            {"pincode": pin, "geo": {"$ne": None}},
            {"geo": 1},
        ).limit(200)
        lats, lngs = [], []
        async for d in cursor:
            coords = (d.get("geo") or {}).get("coordinates") or []
            if len(coords) == 2:
                lngs.append(float(coords[0]))
                lats.append(float(coords[1]))
        if lats:
            return sum(lats) / len(lats), sum(lngs) / len(lngs)
    except Exception:
        pass
    return None


async def _from_openstreetmap(pin: str) -> Optional[Tuple[float, float]]:
    """One postal-code lookup. Short timeout: publishing an ad must not hang
    behind a slow third party."""
    try:
        async with httpx.AsyncClient(timeout=6) as client:
            r = await client.get(
                "https://nominatim.openstreetmap.org/search",
                params={"postalcode": pin, "country": "India",
                        "format": "json", "limit": 1},
                headers={"User-Agent": "ClaimitBackend/1.0"},
            )
            r.raise_for_status()
            js = r.json()
        if isinstance(js, list) and js:
            return float(js[0]["lat"]), float(js[0]["lon"])
    except Exception:
        pass
    return None


async def resolve_pincode(app_db, pincode) -> Optional[Tuple[float, float]]:
    """PIN code -> (lat, lng), or None if it genuinely can't be resolved.

    Successful lookups are written back to the cache, so the expensive path
    runs at most once per PIN code for the lifetime of the system.
    """
    pin = _clean_pin(pincode)
    if not pin:
        return None

    hit = await _from_cache(app_db, pin)
    if hit:
        return hit

    for source, finder in (("shops", _from_our_shops), ("nominatim", None)):
        if finder is not None:
            found = await finder(app_db, pin)
        else:
            found = await _from_openstreetmap(pin)
        if found:
            lat, lng = found
            try:
                await app_db[_CACHE_NAME].update_one(
                    {"_id": pin},
                    {"$set": {"lat": lat, "lng": lng, "source": source,
                              "updated_at": datetime.utcnow()}},
                    upsert=True,
                )
            except Exception:
                pass    # caching is an optimisation, never a requirement
            return lat, lng

    return None


async def resolve_point_for_ad(app_db, *, lat=None, lng=None, pincode=None):
    """What an ad needs: (lat, lng, geo) with everything falling back sensibly.

    Returns (None, None, None) when there is nothing to work with, and the
    caller simply stores the ad without coordinates rather than failing.
    """
    point = geo_point(lat, lng)
    if point:
        return float(lat), float(lng), point

    found = await resolve_pincode(app_db, pincode)
    if found:
        f_lat, f_lng = found
        return f_lat, f_lng, geo_point(f_lat, f_lng)

    return None, None, None
