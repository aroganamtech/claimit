from fastapi import APIRouter, HTTPException, Query
from models.schemas import GeoLookupRequest
from database import app_db
import httpx

router = APIRouter()

NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse"

# India Post pincode API (free, official, no key). Given a 6-digit pincode it
# returns the post offices in that pincode, each with State / District / area.
INDIA_POST_URL = "https://api.postalpincode.in/pincode/{pincode}"

# States + Union Territories of India (for the State dropdown).
INDIA_STATES = [
    "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chhattisgarh",
    "Goa", "Gujarat", "Haryana", "Himachal Pradesh", "Jharkhand", "Karnataka",
    "Kerala", "Madhya Pradesh", "Maharashtra", "Manipur", "Meghalaya", "Mizoram",
    "Nagaland", "Odisha", "Punjab", "Rajasthan", "Sikkim", "Tamil Nadu",
    "Telangana", "Tripura", "Uttar Pradesh", "Uttarakhand", "West Bengal",
    "Andaman and Nicobar Islands", "Chandigarh",
    "Dadra and Nagar Haveli and Daman and Diu", "Delhi", "Jammu and Kashmir",
    "Ladakh", "Lakshadweep", "Puducherry",
]


@router.get("/pincodes")
async def list_pincodes(q: str = Query("", description="filter by pincode, area or city")):
    """Every PIN code Claimit actually has content in, for a dropdown.

    Typing a PIN code by hand is where the location data goes wrong: a typo,
    a blank, or the "000000" placeholder all produce a listing with no
    position, which then never appears in the 5 km search. Nobody notices
    until a shop asks why they are invisible.

    A dropdown built from real data removes that failure entirely — an
    advertiser can only choose a PIN code we can already place on the map.

    Sources, merged:
      • pincode_centres — every PIN code we have resolved coordinates for
      • shops           — gives each one a human label (area, city)
    """
    out: dict = {}

    try:
        async for d in app_db["pincode_centres"].find({}, {"_id": 1}):
            pin = str(d.get("_id", "")).strip()
            if len(pin) == 6 and pin.isdigit():
                out[pin] = {"pincode": pin, "label": pin, "has_coords": True}
    except Exception:
        pass

    # Label them from the shop data, and include PIN codes that have shops but
    # no cached centre yet — those still resolve on first use.
    try:
        pipeline = [
            {"$match": {"pincode": {"$nin": [None, ""]}}},
            {"$group": {"_id": "$pincode",
                        "city": {"$first": "$city"},
                        "area": {"$first": "$area"},
                        "n": {"$sum": 1}}},
            {"$sort": {"n": -1}},
            {"$limit": 3000},
        ]
        async for d in app_db["shops"].aggregate(pipeline):
            pin = str(d.get("_id", "")).strip()
            if not (len(pin) == 6 and pin.isdigit()):
                continue
            bits = [str(d.get(k) or "").strip() for k in ("area", "city")]
            name = ", ".join(b for b in bits if b and b.lower() not in ("none", "nan"))
            entry = out.setdefault(pin, {"pincode": pin, "label": pin,
                                         "has_coords": False})
            entry["label"] = f"{pin} — {name}" if name else pin
            entry["shops"] = int(d.get("n") or 0)
    except Exception:
        pass

    items = sorted(out.values(), key=lambda x: (-x.get("shops", 0), x["pincode"]))

    needle = (q or "").strip().lower()
    if needle:
        items = [i for i in items if needle in i["label"].lower()]

    return {"pincodes": items[:500], "total": len(out)}


@router.get("/countries")
async def list_countries():
    """Country dropdown. Single-item for now (India-only app)."""
    return {"countries": ["India"]}


@router.get("/states")
async def list_states(country: str = "India"):
    """State/UT dropdown for the given country."""
    if country.strip().lower() != "india":
        return {"states": []}
    return {"states": INDIA_STATES}


@router.get("/pincode/{pincode}")
async def lookup_pincode(pincode: str):
    """
    Look up an Indian pincode via the official India Post API and return the
    country, state, district, and the list of areas/cities under it — used to
    populate the District (auto) and City (dropdown) fields on the address form.
    """
    pincode = (pincode or "").strip()
    if not (pincode.isdigit() and len(pincode) == 6):
        raise HTTPException(status_code=400, detail="Pincode must be 6 digits")
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(INDIA_POST_URL.format(pincode=pincode))
            resp.raise_for_status()
            data = resp.json()
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Pincode lookup failed: {e}")

    # India Post returns a list with one entry: {Status, PostOffice: [...]}
    entry = data[0] if isinstance(data, list) and data else {}
    if entry.get("Status") != "Success" or not entry.get("PostOffice"):
        raise HTTPException(status_code=404, detail="No records found for this pincode")

    offices = entry["PostOffice"]
    first = offices[0]
    # Unique area/city names (a pincode can cover several localities)
    seen, areas = set(), []
    for po in offices:
        name = (po.get("Name") or "").strip()
        if name and name.lower() not in seen:
            seen.add(name.lower())
            areas.append(name)
    return {
        "pincode": pincode,
        "country": first.get("Country", "India"),
        "state": first.get("State", ""),
        "district": first.get("District", ""),
        "areas": areas,   # City / locality dropdown options
    }


@router.post("/reverse")
async def reverse_geocode(req: GeoLookupRequest):
    """
    Translate (lat, lng) into a human-readable address + pincode.
    Uses OpenStreetMap Nominatim (free, no API key, please respect rate limits).
    The frontend uses this when the user clicks "Use my current location".
    """
    params = {
        "lat": req.lat,
        "lon": req.lng,
        "format": "json",
        "addressdetails": 1,
        "zoom": 18,
    }
    headers = {"User-Agent": "claimit-app/1.0"}
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(NOMINATIM_URL, params=params, headers=headers)
            resp.raise_for_status()
            data = resp.json()
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Geocoding failed: {e}")

    addr = data.get("address", {})
    parts = [
        addr.get("road"),
        addr.get("suburb") or addr.get("neighbourhood"),
        addr.get("city") or addr.get("town") or addr.get("village"),
        addr.get("state"),
    ]
    short_address = ", ".join([p for p in parts if p])
    return {
        "lat": req.lat,
        "lng": req.lng,
        "address": short_address or data.get("display_name", ""),
        "full_address": data.get("display_name", ""),
        "pincode": addr.get("postcode", ""),
        "city": addr.get("city") or addr.get("town") or addr.get("village") or "",
        "state": addr.get("state", ""),
        "country": addr.get("country", ""),
    }
