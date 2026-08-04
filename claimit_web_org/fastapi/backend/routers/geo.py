from fastapi import APIRouter, HTTPException
from models.schemas import GeoLookupRequest
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
