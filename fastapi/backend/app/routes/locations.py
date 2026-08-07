from fastapi import APIRouter, Query

from ..database import get_db

router = APIRouter(prefix="/locations", tags=["Locations"])

# Popular Chennai localities with store counts
_POPULAR_LOCATIONS = [
    {"name": "Anna Nagar", "count": 24},
    {"name": "Thoraipakkam", "count": 23},
    {"name": "Solinganallur", "count": 41},
    {"name": "OMR", "count": 12},
    {"name": "Guindy", "count": 2},
    {"name": "Padi", "count": 30},
    {"name": "Nungambakkam", "count": 27},
    {"name": "Kotturpuram", "count": 25},
    {"name": "Velachery", "count": 22},
    {"name": "Besant Nagar", "count": 30},
    {"name": "Kodambakkam", "count": 29},
    {"name": "Thiruvanmiyur", "count": 28},
    {"name": "Mylapore", "count": 35},
    {"name": "Choolaimedu", "count": 21},
    {"name": "Sholinganallur", "count": 24},
]


@router.get("/popular")
async def get_popular_locations():
    """Return popular locations with affiliated store counts."""
    return {"locations": _POPULAR_LOCATIONS}


def _norm(s) -> str:
    return (s or "").strip().lower()


def _shop_city(s: dict) -> str:
    """Best-effort city for a shop: the `city` field, else the part after the
    comma in `location` (e.g. "Padi, Chennai" -> "Chennai")."""
    c = (s.get("city") or "").strip()
    if c:
        return c
    loc = (s.get("location") or "").strip()
    if "," in loc:
        return loc.split(",")[-1].strip()
    return loc


@router.get("/nearby-cities")
async def nearby_cities(
    place: str = Query("", description="City / area / district the user picked"),
    district: str = Query("", description="District (optional, skips resolution)"),
):
    """
    Given a place (a city like 'Mudukulathur' or a district like 'Ramanathapuram'),
    return the cities in the SAME district that have shops, each with its shop
    count. If a city is passed, its district is resolved from shop data first.
    Falls back to the busiest cities overall when a district can't be resolved.
    """
    db = get_db()
    shops = await db["shops"].find(
        {},
        {"name": 1, "location": 1, "district": 1, "city": 1, "area": 1, "pincode": 1},
    ).to_list(5000)

    place_l = _norm(place)
    resolved = district.strip()

    # ── Resolve the district from the entered place ───────────────────────────
    if not resolved and place_l:
        # (a) place matches a shop's city/area → take that shop's district
        for s in shops:
            fields = [s.get("city"), s.get("area")]
            if any(place_l == _norm(f) for f in fields) or \
               any(place_l and place_l in _norm(f) for f in fields):
                if (s.get("district") or "").strip():
                    resolved = (s.get("district") or "").strip()
                    break
        # (b) place itself is a district name
        if not resolved:
            for s in shops:
                if place_l == _norm(s.get("district")):
                    resolved = (s.get("district") or "").strip()
                    break

    # ── Count shops per city within the resolved district ─────────────────────
    counts: dict = {}
    if resolved:
        rl = _norm(resolved)
        for s in shops:
            if _norm(s.get("district")) == rl:
                city = _shop_city(s)
                if city:
                    counts[city] = counts.get(city, 0) + 1

    # ── Fallback: busiest cities overall (keeps the UI populated) ─────────────
    if not counts:
        resolved = ""
        for s in shops:
            city = _shop_city(s)
            if city:
                counts[city] = counts.get(city, 0) + 1

    cities = sorted(
        [{"name": c, "count": n} for c, n in counts.items()],
        key=lambda x: (-x["count"], x["name"]),
    )
    return {"district": resolved, "cities": cities}
