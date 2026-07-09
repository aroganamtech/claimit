import random
import string
from datetime import datetime
from bson import ObjectId


def generate_claim_number() -> str:
    """Generate a unique claim number."""
    year = datetime.utcnow().year
    random_part = ''.join(random.choices(string.ascii_uppercase + string.digits, k=8))
    return f"CLM-{year}-{random_part}"


def serialize_doc(doc: dict) -> dict:
    """Convert MongoDB document to JSON-serializable format."""
    if doc is None:
        return None
    result = {}
    for key, value in doc.items():
        if isinstance(value, ObjectId):
            result[key] = str(value)
        elif isinstance(value, datetime):
            result[key] = value.isoformat()
        elif isinstance(value, list):
            result[key] = [
                serialize_doc(item) if isinstance(item, dict) else
                str(item) if isinstance(item, ObjectId) else
                item.isoformat() if isinstance(item, datetime) else item
                for item in value
            ]
        elif isinstance(value, dict):
            result[key] = serialize_doc(value)
        else:
            result[key] = value
    # Rename _id to id
    if "_id" in result:
        result["id"] = result.pop("_id")
    return result


def paginate(page: int = 1, page_size: int = 10) -> dict:
    """Calculate skip and limit for pagination."""
    skip = (page - 1) * page_size
    return {"skip": skip, "limit": page_size}


def prioritize_by_location(items: list, area: str = "", pincode: str = "") -> list:
    """
    Location-aware ordering for ads/deals/banners/reels:
    items whose pincode matches the user's pincode, or whose location/address
    text contains the user's area name (e.g. "Kovilpatti"), move to the TOP —
    everything else follows in its original order. When the user's location
    is unknown, or nothing matches (e.g. user is in Mudukulathur but no ads
    exist there), the list is returned completely unchanged.
    """
    area = (area or "").strip().lower()
    pin = (pincode or "").strip()
    if (not area and not pin) or not items:
        return items

    _text_fields = ("location", "address", "shop_location", "shop_address",
                    "sub", "headline", "name", "shop_name")

    def _is_local(d: dict) -> bool:
        try:
            if pin and str(d.get("pincode", "")).strip() == pin:
                return True
            if area:
                blob = " ".join(str(d.get(f) or "") for f in _text_fields).lower()
                if area in blob:
                    return True
        except Exception:
            pass
        return False

    local, others = [], []
    for d in items:
        (local if _is_local(d) else others).append(d)
    return local + others
