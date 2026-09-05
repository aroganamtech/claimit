"""
geo_filter.py — restrict any feature list to a radius around a point.

Why this exists
---------------
The unified /search endpoint has always been radius-based, but the individual
feature screens (Nearby Deals, Brand Deals, Promo Reelz, Local Classifieds)
were still asking their own endpoints, which only *floated local results to
the top* rather than filtering by distance. So "within 5 km of Madurai" was
true on the search screen and not true on the feature pages — the same app
disagreeing with itself, which is exactly what the brief's question 11 rules
out.

This helper gives those endpoints the same radius filter without rewriting
them. They keep their existing query, sorting and response shape; they simply
get their documents from here when the caller supplies coordinates.

The fallback rule
-----------------
`nearby_docs` returns None to mean "geo was NOT applied" — either the caller
sent no coordinates, or the aggregation failed (a collection with no 2dsphere
index, say). The caller then does exactly what it did before. That way adding
a radius can never turn a working screen into an empty one.

An empty LIST is different from None: it means the radius WAS applied and
genuinely nothing is within it. The caller must respect that and return
nothing, otherwise the filter would be meaningless.
"""
from typing import List, Optional


async def nearby_docs(
    db,
    collection: str,
    lat: Optional[float],
    lng: Optional[float],
    radius_km: Optional[float],
    query: dict,
    limit: int = 200,
) -> Optional[List[dict]]:
    """Documents matching `query` within `radius_km` of the point.

    Returns None when no radius was applied, so the caller falls back to its
    previous behaviour. Returns a (possibly empty) list when it was.
    """
    if lat is None or lng is None:
        return None
    try:
        # `radius_km or 5.0` would be wrong here: 0 is falsy, so a radius of
        # zero would silently become 5 km instead of being rejected.
        radius = 5.0 if radius_km is None else float(radius_km)
        lat_f, lng_f = float(lat), float(lng)
    except (TypeError, ValueError):
        return None
    if not (-90 <= lat_f <= 90 and -180 <= lng_f <= 180) or radius <= 0:
        return None

    try:
        pipeline = [
            {"$geoNear": {
                "near": {"type": "Point", "coordinates": [lng_f, lat_f]},
                "distanceField": "_dist_m",
                "maxDistance": radius * 1000,
                "spherical": True,
                "query": query,
            }},
            {"$limit": limit},
        ]
        return [d async for d in db[collection].aggregate(pipeline)]
    except Exception as e:
        # No 2dsphere index, or a malformed geo field somewhere in the
        # collection. Falling back beats showing the user an error.
        print(f"[geo_filter] {collection} fell back to unfiltered: {e}")
        return None


def attach_distance(doc: dict) -> dict:
    """Copy $geoNear's metres into a `distance_km` the app can display."""
    d = doc.get("_dist_m")
    if d is not None:
        try:
            doc["distance_km"] = round(float(d) / 1000, 1)
        except (TypeError, ValueError):
            pass
        doc.pop("_dist_m", None)
    return doc
