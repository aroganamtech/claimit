from fastapi import APIRouter, HTTPException
from models.schemas import GeoLookupRequest
import httpx

router = APIRouter()

NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse"


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
