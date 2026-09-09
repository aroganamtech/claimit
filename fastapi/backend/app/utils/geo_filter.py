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


async def docs_by_distance(
    db,
    collection: str,
    lat: Optional[float],
    lng: Optional[float],
    query: dict,
    limit: int = 200,
    skip: int = 0,
) -> Optional[List[dict]]:
    """Everything matching `query`, NEAREST FIRST — with no distance cut-off.

    Different from `nearby_docs` on purpose. A radius is right for a shop list:
    a shop 40 km away is useless. It is wrong for Reels, where the user swipes
    through a feed and expects it to keep going — cutting the feed at 5 km ends
    it after two videos in a quiet area.

    So this ranks instead of filtering: the closest reel plays first, then the
    next closest, and the feed only runs out when the content does.

    Records with no coordinates are appended at the end rather than dropped.
    $geoNear silently ignores them, which would have made a reel with a missing
    pincode invisible forever instead of merely last.

    Paging: `skip` walks through the same distance-ordered sequence. Because
    $geoNear's ordering is deterministic for a fixed point, page 2 continues
    exactly where page 1 stopped — no repeated and no missing reels, which is
    what naive skip/limit over an unsorted query gets wrong.

    The unlocated tail is paged too: it only begins once the located ones are
    exhausted, so it sits at the end of the whole feed rather than at the end
    of every page.

    Returns None when no coordinates were supplied or the query failed, so the
    caller falls back to its previous behaviour.
    """
    if lat is None or lng is None:
        return None
    try:
        lat_f, lng_f = float(lat), float(lng)
    except (TypeError, ValueError):
        return None
    if not (-90 <= lat_f <= 90 and -180 <= lng_f <= 180):
        return None

    try:
        # No maxDistance -> $geoNear returns every match, sorted by distance.
        pipeline = [
            {"$geoNear": {
                "near": {"type": "Point", "coordinates": [lng_f, lat_f]},
                "distanceField": "_dist_m",
                "spherical": True,
                "query": query,
            }},
            {"$skip": skip},
            {"$limit": limit},
        ]
        located = [d async for d in db[collection].aggregate(pipeline)]
    except Exception as e:
        print(f"[geo_filter] {collection} distance sort fell back: {e}")
        return None

    if len(located) >= limit:
        return located

    # Top up with the records $geoNear can't see (no coordinates), so nothing
    # is lost. How far into that tail we are depends on how much of `skip`
    # was left over after the located ones ran out.
    try:
        no_geo = {"$or": [
            {"geo": {"$exists": False}}, {"geo": None}, {"geo": {}},
        ]}
        rest_query = {"$and": [query, no_geo]} if query else no_geo

        # Everything located, so we know where the tail begins.
        total_located = await db[collection].count_documents(
            {"$and": [query, {"geo": {"$nin": [None, {}]}}]} if query
            else {"geo": {"$nin": [None, {}]}}
        )
        tail_skip = max(0, skip - total_located)

        rest = await (db[collection].find(rest_query)
                      .skip(tail_skip)
                      .limit(limit - len(located))
                      .to_list(length=limit))
        return located + rest
    except Exception:
        return located     # the located ones are still a valid answer


async def nearby_or_nearest(
    db,
    collection: str,
    lat: Optional[float],
    lng: Optional[float],
    radius_km: Optional[float],
    query: dict,
    limit: int = 200,
    skip: int = 0,
    expanded_km: float = 10.0,
    post_filter=None,
):
    """Inside the radius when there is anything there — otherwise the nearest.

    A hard radius is honest but it produces empty screens, and an empty screen
    reads as "this app is broken", not as "your area is quiet". A user who
    picked a location wants to see *something* relevant to it.

    So this walks outwards and stops at the first step that has content:

        1. within `radius_km`            (normally 5 km)
        2. within `expanded_km`          (normally 10 km)
        3. nearest first, no cut-off     (the whole country, closest first)

    Step 3 is what guarantees a non-empty screen whenever the collection has
    any matching content at all, anywhere.

    Returns `(docs, info)`. `info` says which step produced the result:

        {"radius_km": 5.0, "expanded": False, "showing_nearest": False}

    so the screen can say "Nothing within 5 km — showing the nearest instead"
    rather than silently pretending a shop 60 km away is local. Returning that
    honestly is the point; quietly widening the radius would mislead.

    `docs` is None when no coordinates were supplied, meaning geo was never
    applied and the caller should do exactly what it did before.

    Paging note: `skip` is only meaningful once a step has been chosen, so it
    is applied to step 3 (the unbounded feed) and to the bounded steps alike.
    Page 2 of a fallback result stays in fallback: a non-zero `skip` goes
    straight to the unbounded query, because the earlier steps were already
    known to be empty when page 1 was fetched.

    `post_filter` matters more than it looks. Deals and banners are dropped
    again afterwards for being outside their paid week, so a step can return
    three documents and the screen still ends up blank. Passing that filter in
    here makes each step's emptiness test count only the rows the user will
    actually see — otherwise the fallback never triggers in exactly the case
    it was written for.
    """
    def _keep(docs):
        return post_filter(docs) if post_filter else docs

    if lat is None or lng is None:
        return None, {"radius_km": radius_km, "expanded": False,
                      "showing_nearest": False}

    base = 5.0 if radius_km is None else float(radius_km)

    # Page 2+ of a feed that already fell back must not re-test the radius:
    # it would return the same first page again. Only page 1 decides the mode.
    if skip == 0:
        found = await nearby_docs(db, collection, lat, lng, base, query, limit)
        if found is None:
            return None, {"radius_km": base, "expanded": False,
                          "showing_nearest": False}
        kept = _keep(found)
        if kept:
            return kept, {"radius_km": base, "expanded": False,
                          "showing_nearest": False}

        if expanded_km and expanded_km > base:
            wider = _keep(await nearby_docs(db, collection, lat, lng,
                                            expanded_km, query, limit) or [])
            if wider:
                return wider, {"radius_km": expanded_km, "expanded": True,
                               "showing_nearest": False}

    # Nothing nearby at all — show the closest there is, rather than nothing.
    rest = await docs_by_distance(db, collection, lat, lng, query, limit, skip)
    if rest is None:
        return None, {"radius_km": base, "expanded": False,
                      "showing_nearest": False}
    return _keep(rest), {"radius_km": base, "expanded": True,
                         "showing_nearest": True}


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
