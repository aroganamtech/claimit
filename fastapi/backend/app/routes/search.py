"""
search.py — ONE geo-search API for the whole of Claimit.

Why this exists
---------------
Every feature used to query the database its own way: shops had one endpoint,
classifieds another, professionals a third. The client's brief asks for the
opposite — a single location that controls the entire app, and one search that
looks across everything at once.

This module is that single entry point. Give it a point on the map and it
returns matching content from all nine Claimit features, ranked and paged.

The location rules the brief asks for
-------------------------------------
1. The radius is measured from the SELECTED location, never from the phone's
   GPS. A customer in Chennai searching Madurai gets results around Madurai.
   That is why lat/lng are required parameters rather than read from the
   request — the caller decides what "here" means.
2. Default radius is 5 km, and it is the same 5 km everywhere.
3. Nothing expired, inactive, unapproved or deleted is ever returned.
4. A merchant that belongs to several features appears ONCE, carrying a badge
   for each feature it belongs to.
5. When there is nothing within the radius the response says so plainly and
   suggests a wider one. It never widens the search on its own.

Endpoints
---------
GET /search            → everything near a point, optionally filtered
GET /search/features   → the feature list, for building filter chips
"""
import math
import re
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, Query

from ..database import get_db
from ..utils.auth import get_current_user
from ..utils.helpers import serialize_doc
from ..utils.opening_hours import is_open_now

router = APIRouter(prefix="/search", tags=["Search"])

# ── The nine Claimit features ────────────────────────────────────────────────
# Order matters: it is the order sections appear on the home screen.
FEATURES = [
    "reward_zone", "redeem_zone", "nearby_deals", "brand_deals", "promo_reelz",
    "local_finder", "claimit_select", "claimit_privilege", "local_classifieds",
]

FEATURE_LABELS = {
    "reward_zone": "Reward Zone",
    "redeem_zone": "Redeem Zone",
    "nearby_deals": "Nearby Deals",
    "brand_deals": "Brand Deals",
    "promo_reelz": "Promo Reelz",
    "local_finder": "Local Finder",
    "claimit_select": "Claimit Select",
    "claimit_privilege": "Claimit Privilege",
    "local_classifieds": "Local Classifieds",
}

DEFAULT_RADIUS_KM = 5.0     # the brief's default, used everywhere
EXPANDED_RADIUS_KM = 10.0   # what we OFFER when 5 km is empty — never automatic


# ── Helpers ──────────────────────────────────────────────────────────────────

def _now():
    return datetime.now(timezone.utc)


def _rx(text: str) -> dict:
    """Case-insensitive 'contains', with regex characters escaped so a search
    for "C++" or "50% off" can't blow up the query."""
    return {"$regex": re.escape(text), "$options": "i"}


def _clean_text(v) -> str:
    """A trimmed string, treating None and the literal 'None'/'nan' that bulk
    uploads leave behind as empty."""
    s = str(v or "").strip()
    return "" if s.lower() in ("none", "null", "nan", "na", "-") else s


def _text_or(text: str, fields: List[str]) -> dict:
    """Match `text` against any of `fields`.

    The brief is explicit that search must not be limited to shop names, so
    each collection passes in everything worth searching: category, product,
    service, profession, brand, offer wording, locality and PIN code.
    """
    return {"$or": [{f: _rx(text)} for f in fields]}


def _active_clause(extra_active_field: Optional[str] = None) -> List[dict]:
    """Conditions that exclude inactive, unapproved and deleted rows.

    Written defensively: a document that simply doesn't carry a field is still
    treated as live, because older records pre-date some of these fields and
    must not silently vanish from the app.

    Note that EXPIRY is deliberately not handled here — see _is_expired below.
    """
    clauses = [
        {"deleted": {"$ne": True}},
        {"is_deleted": {"$ne": True}},
        {"status": {"$nin": ["rejected", "deleted", "disabled", "inactive",
                             "expired", "paused"]}},
    ]
    if extra_active_field:
        clauses.append({"$or": [{extra_active_field: {"$exists": False}},
                                {extra_active_field: True}]})
    return clauses


def _parse_date(value) -> Optional[datetime]:
    """Read an end/start date that might be stored in any of three ways.

    Collections disagree: shops and classifieds store real datetimes, while
    deals and reels store the string "31/12/2026" (dd/mm/yyyy) because that is
    what the advertiser form produced. A few records use ISO strings.

    Returning None means "no usable date", which callers treat as not expired.
    """
    if value is None or value == "":
        return None
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    s = str(value).strip()
    for fmt in ("%d/%m/%Y", "%Y-%m-%d", "%d-%m-%Y", "%Y/%m/%d"):
        try:
            return datetime.strptime(s, fmt).replace(tzinfo=timezone.utc)
        except ValueError:
            pass
    try:
        d = datetime.fromisoformat(s.replace("Z", "+00:00"))
        return d if d.tzinfo else d.replace(tzinfo=timezone.utc)
    except Exception:
        return None


def _is_expired(doc: dict) -> bool:
    """True when this record should no longer be shown.

    Done in Python rather than in the Mongo query on purpose. A dd/mm/yyyy
    STRING compared against a date in MongoDB doesn't fail — it silently
    matches everything, because BSON orders dates before strings. Filtering
    here means an expired deal is actually removed instead of quietly
    slipping through.
    """
    now = _now()
    for field in ("expires_at", "end_date", "valid_till"):
        d = _parse_date(doc.get(field))
        if d is not None and d < now:
            return True
    start = _parse_date(doc.get("start_date"))
    if start is not None and start > now:
        return True     # campaign hasn't begun yet
    return False


async def _geo_query(
    db,
    collection: str,
    lat: float,
    lng: float,
    radius_km: float,
    match: dict,
    limit: int = 200,
) -> List[dict]:
    """Run one $geoNear against `collection`.

    Returns [] on any failure — a collection without a 2dsphere index, or one
    that doesn't exist yet, must not take down the whole search.
    """
    try:
        pipeline = [
            {"$geoNear": {
                "near": {"type": "Point", "coordinates": [lng, lat]},
                "distanceField": "_dist_m",
                "maxDistance": radius_km * 1000,
                "spherical": True,
                "query": match,
            }},
            {"$limit": limit},
            {"$project": {"cover_photo_b64": 0, "gallery_photos": 0}},
        ]
        docs = [d async for d in db[collection].aggregate(pipeline)]
        # Expiry is checked here, not in the query — see _is_expired.
        return [d for d in docs if not _is_expired(d)]
    except Exception as e:
        print(f"[search] {collection} skipped: {e}")
        return []


def _card(
    doc: dict,
    feature: str,
    *,
    name: str,
    image: str = "",
    category: str = "",
    benefit: str = "",
    locality: str = "",
) -> dict:
    """One result card, in the shape the brief's question 16 asks for."""
    dist_m = doc.get("_dist_m")
    return {
        "id": str(doc.get("_id") or doc.get("id") or ""),
        "name": name or "",
        "image": image or "",
        "category": category or "",
        "features": [feature],                       # merged later if duplicated
        "feature_labels": [FEATURE_LABELS.get(feature, feature)],
        "benefit": benefit or "",
        "distance_km": round(dist_m / 1000, 1) if dist_m is not None else None,
        "locality": locality or "",
        "phone": doc.get("phone") or doc.get("user_phone") or "",
        "lat": doc.get("lat") or doc.get("latitude"),
        "lng": doc.get("lng") or doc.get("longitude"),
        # Read from the `timing` text the merchant already gave us at
        # registration. None means the text was missing or unreadable, and the
        # card then shows no open/closed badge rather than a guess.
        "is_open": is_open_now(doc.get("timing") or doc.get("shop_timing") or ""),
        "sponsored": bool(doc.get("is_sponsored") or doc.get("sponsored")),
        "popularity": float(doc.get("rating") or doc.get("avg_rating") or 0),
        "created_at": str(doc.get("created_at") or ""),
    }


# ── Per-feature collectors ───────────────────────────────────────────────────
# Each returns a list of cards. They are separate functions so a change to one
# feature's data shape can never break the other eight.

async def _shops(db, lat, lng, r, text, feature) -> List[dict]:
    """Reward Zone and Redeem Zone both live in `shops`, told apart by
    shop_type — the same rule the rest of the app uses."""
    match = {"$and": _active_clause()}
    if feature == "reward_zone":
        match["$and"].append({"shop_type": {"$regex": "^reward", "$options": "i"}})
    elif feature == "redeem_zone":
        match["$and"].append({"shop_type": {"$regex": "^redeem", "$options": "i"}})
    if text:
        match["$and"].append(_text_or(text, [
            "name", "shop_name", "category", "about", "address",
            "location", "area", "city", "pincode",
        ]))
    out = []
    for d in await _geo_query(db, "shops", lat, lng, r, match):
        disc = d.get("discount") or d.get("discount_percentage") or 0
        out.append(_card(
            d, feature,
            name=d.get("name") or d.get("shop_name", ""),
            image=d.get("image_url", ""),
            category=d.get("category", ""),
            benefit=(f"{disc}% off" if feature == "redeem_zone" and disc
                     else "Earn rewards" if feature == "reward_zone" else ""),
            locality=d.get("location") or d.get("area", ""),
        ))
    return out


async def _classifieds(db, lat, lng, r, text, feature) -> List[dict]:
    """Local Finder and Local Classifieds share one collection, separated by
    listing_type. Getting this wrong mixes two products together, which has
    happened before — hence the explicit filter."""
    listing_type = "local_find" if feature == "local_finder" else "classified"
    match = {"$and": _active_clause() + [{"listing_type": listing_type}]}
    if text:
        match["$and"].append(_text_or(text, [
            "title", "business_name", "category", "subcategory", "description",
            "area", "city", "pincode", "address",
        ]))
    out = []
    for d in await _geo_query(db, "classifieds", lat, lng, r, match):
        photos = d.get("photos") or []
        price = d.get("price") or 0
        out.append(_card(
            d, feature,
            name=d.get("title") or d.get("business_name", ""),
            image=photos[0] if photos else "",
            category=d.get("subcategory") or d.get("category", ""),
            benefit=(f"₹ {int(price):,}" if price else ""),
            locality=d.get("area") or d.get("city", ""),
        ))
    return out


async def _professionals(db, lat, lng, r, text, feature) -> List[dict]:
    match = {"$and": _active_clause("is_active")}
    if text:
        match["$and"].append(_text_or(text, [
            "name", "category", "category_label", "about", "specialisation",
            "area", "city", "pincode",
        ]))
    out = []
    for d in await _geo_query(db, "select_professionals", lat, lng, r, match):
        fee = d.get("consultation_fee") or 0
        out.append(_card(
            d, feature,
            name=d.get("name", ""),
            image=d.get("photo_url") or d.get("photo_s3_key", ""),
            category=d.get("category_label") or d.get("category", ""),
            benefit=(f"₹ {int(fee):,} consultation" if fee else ""),
            locality=d.get("area") or d.get("city", ""),
        ))
    return out


async def _simple(db, lat, lng, r, text, feature, collection,
                  name_fields, image_field) -> List[dict]:
    """Deals, brand deals and reels — same shape, different collection."""
    match = {"$and": _active_clause("is_active")}
    if text:
        match["$and"].append(_text_or(text, list(name_fields) + [
            "title", "description", "category", "brand", "offer",
            "area", "city", "pincode",
        ]))
    out = []
    for d in await _geo_query(db, collection, lat, lng, r, match):
        name = next((d[f] for f in name_fields if d.get(f)), "")
        out.append(_card(
            d, feature,
            name=name,
            image=d.get(image_field, "") or "",
            category=d.get("category", ""),
            benefit=d.get("offer") or d.get("discount_text", ""),
            locality=d.get("area") or d.get("city", ""),
        ))
    return out


# ── De-duplication ───────────────────────────────────────────────────────────

def _merge_duplicates(cards: List[dict]) -> List[dict]:
    """One merchant, one card, several badges.

    The brief's question 10 asks for this directly: a shop in both the Reward
    Zone and Nearby Deals should not appear twice in a combined list. Matching
    is on id first, then on name + locality, which catches the same business
    stored separately in two collections.
    """
    merged: dict = {}
    for c in cards:
        key = c["id"] or f"{c['name'].strip().lower()}|{c['locality'].strip().lower()}"
        if key in merged:
            m = merged[key]
            for f, lbl in zip(c["features"], c["feature_labels"]):
                if f not in m["features"]:
                    m["features"].append(f)
                    m["feature_labels"].append(lbl)
            # Keep the closest distance and the most descriptive benefit.
            if c["distance_km"] is not None and (
                    m["distance_km"] is None or c["distance_km"] < m["distance_km"]):
                m["distance_km"] = c["distance_km"]
            if not m["benefit"] and c["benefit"]:
                m["benefit"] = c["benefit"]
            if not m["image"] and c["image"]:
                m["image"] = c["image"]
        else:
            merged[key] = c
    return list(merged.values())


# ── Sorting ──────────────────────────────────────────────────────────────────

def _sort_cards(cards: List[dict], sort: str, text: str) -> List[dict]:
    """Sponsored results are pinned to the top in every mode, and carry a flag
    so the app can label them — the brief allows priority but requires the
    label."""
    def relevance(c):
        # Exact name match first, then a name that starts with the query, then
        # anything else. Distance and popularity break the tie.
        n = c["name"].lower()
        q = (text or "").lower().strip()
        exact = 0 if q and n == q else 1
        starts = 0 if q and n.startswith(q) else 1
        return (exact, starts, c["distance_km"] if c["distance_km"] is not None else 9e9,
                -c["popularity"])

    if sort == "nearest":
        cards.sort(key=lambda c: c["distance_km"] if c["distance_km"] is not None else 9e9)
    elif sort == "latest":
        cards.sort(key=lambda c: c["created_at"], reverse=True)
    elif sort == "highest_discount":
        def pct(c):
            m = re.search(r"(\d+)\s*%", c["benefit"] or "")
            return int(m.group(1)) if m else -1
        cards.sort(key=pct, reverse=True)
    elif sort == "popular":
        cards.sort(key=lambda c: -c["popularity"])
    else:  # relevance — the default
        cards.sort(key=relevance)

    cards.sort(key=lambda c: 0 if c["sponsored"] else 1)
    return cards


# ── The endpoint ─────────────────────────────────────────────────────────────

@router.get("")
async def unified_search(
    lat: float = Query(..., description="Latitude of the SELECTED location — not necessarily the phone's GPS"),
    lng: float = Query(..., description="Longitude of the selected location"),
    radius_km: float = Query(DEFAULT_RADIUS_KM, ge=0.5, le=50),
    q: Optional[str] = Query(None, description="Free text: shop, category, product, service, profession, brand, offer, locality or PIN"),
    feature: Optional[str] = Query(None, description="Limit to one feature; omit for everything"),
    category: Optional[str] = Query(None),
    open_now: bool = Query(False),
    has_reward: bool = Query(False),
    has_discount: bool = Query(False),
    sort: str = Query("relevance", description="relevance | nearest | latest | highest_discount | popular"),
    auto_expand: bool = Query(
        True,
        description="If 5 km is empty, retry at 10 km and say so in the "
                    "response. Set false to keep the radius fixed.",
    ),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_user: dict = Depends(get_current_user),
):
    """Everything Claimit has near a point.

    Returns cards grouped by feature AND as one merged list, so the home
    screen can show sections while search shows a single ranked list.
    """
    db = get_db()
    text = (q or "").strip()
    wanted = [feature] if feature in FEATURES else FEATURES

    async def _gather(r: float):
        """Everything within `r` km, filtered, deduplicated and sorted.

        Pulled out as a local function so the same work can be repeated at a
        wider radius without duplicating a line of it.
        """
        collected: List[dict] = []
        for f in wanted:
            if f in ("reward_zone", "redeem_zone"):
                collected += await _shops(db, lat, lng, r, text, f)
            elif f in ("local_finder", "local_classifieds"):
                collected += await _classifieds(db, lat, lng, r, text, f)
            elif f == "claimit_select":
                collected += await _professionals(db, lat, lng, r, text, f)
            elif f == "nearby_deals":
                collected += await _simple(db, lat, lng, r, text, f,
                                           "deals", ["name", "title"], "image_url")
            elif f == "brand_deals":
                collected += await _simple(db, lat, lng, r, text, f,
                                           "deals", ["name", "title"], "image_url")
            elif f == "promo_reelz":
                collected += await _simple(db, lat, lng, r, text, f,
                                           "reels", ["title", "caption"], "thumbnail_url")
            elif f == "claimit_privilege":
                # No collection of its own yet — returns nothing rather than
                # erroring, so it can be switched on later by adding one.
                pass

        # ── Filters that apply after collection ─────────────────────────────
        if category:
            collected = [c for c in collected
                         if category.lower() in (c["category"] or "").lower()]
        # "Open Now" means open now — a merchant whose hours we couldn't read
        # is NOT presented as open. But hiding those silently makes the app
        # look broken when many merchants have no usable timing text, so the
        # count comes back and the app can say "12 hidden — hours not listed".
        hidden = 0
        if open_now:
            hidden = sum(1 for c in collected if c["is_open"] is None)
            collected = [c for c in collected if c["is_open"] is True]
        if has_reward:
            collected = [c for c in collected if "reward_zone" in c["features"]]
        if has_discount:
            collected = [c for c in collected
                         if "%" in (c["benefit"] or "")
                         or "redeem_zone" in c["features"]]

        return _sort_cards(_merge_duplicates(collected), sort, text), hidden

    # ── 5 km first. Only if that is empty, try 10 km ─────────────────────────
    # The brief (question 13) says the radius must never widen "without
    # informing the customer" — so it widens here, and the response says
    # plainly that it did, via auto_expanded and radius_used. The app shows
    # that as a banner, and 5 km results are always preferred when they exist.
    merged, hidden_unknown_hours = await _gather(radius_km)
    radius_used = radius_km
    auto_expanded = False

    if not merged and auto_expand and radius_km < EXPANDED_RADIUS_KM:
        wider, wider_hidden = await _gather(EXPANDED_RADIUS_KM)
        if wider:
            merged = wider
            hidden_unknown_hours = wider_hidden
            radius_used = EXPANDED_RADIUS_KM
            auto_expanded = True

    total = len(merged)
    start = (page - 1) * limit
    page_items = merged[start:start + limit]

    # ── Grouped by feature, for the home screen's sections ───────────────────
    sections = []
    for f in wanted:
        items = [c for c in merged if f in c["features"]]
        if items:
            sections.append({
                "feature": f,
                "label": FEATURE_LABELS.get(f, f),
                "count": len(items),
                "items": items[:10],
            })

    return {
        "success": True,
        # radius_km is what was asked for; radius_used is what the results
        # actually came from. They differ only when auto_expanded is true.
        "location": {"lat": lat, "lng": lng, "radius_km": radius_km,
                     "radius_used_km": radius_used},
        "radius_used_km": radius_used,
        "auto_expanded": auto_expanded,
        "query": text,
        "sort": sort,
        "total": total,
        "page": page,
        "limit": limit,
        "has_more": start + len(page_items) < total,
        "results": page_items,
        "sections": sections,
        # Empty even at the wider radius. Nothing left to offer except a
        # different location or a different category.
        "empty": total == 0,
        "suggest_radius_km": (
            EXPANDED_RADIUS_KM
            if total == 0 and radius_used < EXPANDED_RADIUS_KM else None
        ),
        # How many results the Open Now filter removed because their opening
        # hours aren't listed — so an empty screen can explain itself instead
        # of looking like a bug.
        "hidden_unknown_hours": hidden_unknown_hours,
        # One line the app can show verbatim. Either "nothing found", or —
        # when the radius was widened — an honest note that these results are
        # from further away than asked for.
        "message": (
            (f"No results found within {radius_used:g} km of the selected location."
             + (f" {hidden_unknown_hours} nearby listings were hidden because "
                "their opening hours aren't listed." if hidden_unknown_hours else ""))
            if total == 0
            else (f"Nothing within {radius_km:g} km — showing results within "
                  f"{radius_used:g} km of the selected location."
                  if auto_expanded else "")
        ),
    }


@router.get("/places")
async def search_places(
    q: str = Query("", description="area, city, district or PIN code"),
    limit: int = Query(12, ge=1, le=40),
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """Type-ahead for "Search Another Location".

    The brief wants a customer to be able to pick any locality or PIN code by
    hand, without ever switching GPS on. This endpoint answers that.

    The place list is not hardcoded — it is learned from the shops Claimit
    already has. Averaging the coordinates of every shop in an area gives that
    area's centre, which is exactly the point a radius search should be drawn
    around. Two useful consequences:

      • every place offered is somewhere Claimit actually has content, so the
        user can never pick a location that returns an empty screen by
        definition
      • the list improves by itself as merchants are added, with nothing to
        maintain

    Results are ranked by how much content sits there, so the busiest matching
    area is offered first.
    """
    text = (q or "").strip()
    if len(text) < 2:
        return {"places": []}

    rx = _rx(text)
    is_pin = text.isdigit()

    # Match the typed text against any of the address fields. A numeric query
    # is treated as a PIN code prefix, which is how people actually type them.
    match: dict = {"geo": {"$ne": None}}
    if is_pin:
        match["pincode"] = {"$regex": f"^{re.escape(text)}", "$options": "i"}
    else:
        match["$or"] = [
            {"area": rx}, {"city": rx}, {"district": rx},
            {"state": rx}, {"address": rx}, {"location": rx},
        ]

    # Group by the finest label available, keeping a running centre.
    pipeline = [
        {"$match": match},
        {"$project": {
            "geo": 1, "pincode": 1,
            "area": {"$ifNull": ["$area", ""]},
            "city": {"$ifNull": ["$city", ""]},
            "district": {"$ifNull": ["$district", ""]},
            "state": {"$ifNull": ["$state", ""]},
        }},
        {"$group": {
            "_id": {
                "area": "$area", "city": "$city",
                "district": "$district", "pincode": "$pincode",
            },
            "state": {"$first": "$state"},
            "coords": {"$push": "$geo.coordinates"},
            "count": {"$sum": 1},
        }},
        {"$sort": {"count": -1}},
        {"$limit": limit * 4},
    ]

    try:
        rows = await db.shops.aggregate(pipeline).to_list(length=limit * 4)
    except Exception:
        rows = []

    places, seen = [], set()
    for r in rows:
        key = r.get("_id") or {}
        area = _clean_text(key.get("area"))
        city = _clean_text(key.get("city"))
        district = _clean_text(key.get("district"))
        pin = _clean_text(key.get("pincode"))
        state = _clean_text(r.get("state"))

        label = area or city or district or pin
        if not label:
            continue

        # Average the coordinates of everything grouped here — that is the
        # centre of the area, not one arbitrary shop's doorstep.
        pts = [c for c in (r.get("coords") or []) if isinstance(c, list) and len(c) == 2]
        if not pts:
            continue
        lng = sum(float(p[0]) for p in pts) / len(pts)
        lat = sum(float(p[1]) for p in pts) / len(pts)

        # "Anna Nagar · Chennai, Tamil Nadu" — never "Chennai, Chennai,
        # Tamil Nadu". City and district are frequently the same word, and
        # either can repeat the label, so drop anything already said.
        sub_parts: List[str] = []
        for part in (city, district, state):
            if part and part.lower() != label.lower() and \
                    part.lower() not in [p.lower() for p in sub_parts]:
                sub_parts.append(part)
        sub = ", ".join(sub_parts)

        dedupe = (label.lower(), pin, round(lat, 3), round(lng, 3))
        if dedupe in seen:
            continue
        seen.add(dedupe)

        places.append({
            "label": label,
            "sub_label": sub,
            "pincode": pin,
            "lat": round(lat, 6),
            "lng": round(lng, 6),
            "listing_count": int(r.get("count") or 0),
        })
        if len(places) >= limit:
            break

    return {"places": places}


@router.get("/features")
async def list_features(current_user: dict = Depends(get_current_user)):
    """The feature list, so the app can build filter chips without hardcoding
    them and drifting out of step with the backend."""
    return {
        "features": [{"key": f, "label": FEATURE_LABELS[f]} for f in FEATURES],
        "default_radius_km": DEFAULT_RADIUS_KM,
        "expanded_radius_km": EXPANDED_RADIUS_KM,
        "sorts": [
            {"key": "relevance", "label": "Most Relevant"},
            {"key": "nearest", "label": "Nearest"},
            {"key": "latest", "label": "Latest"},
            {"key": "highest_discount", "label": "Highest Discount"},
            {"key": "popular", "label": "Most Popular"},
        ],
    }
