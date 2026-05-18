"""
Deals endpoints — returns dummy data until the admin data-flow is complete.
Replace the _DUMMY_* lists with real DB queries once shop data is seeded.
"""
from typing import Optional
from fastapi import APIRouter, Depends
from ..utils.auth import get_current_user

router = APIRouter(prefix="/deals", tags=["Deals"])

# ── Dummy data ────────────────────────────────────────────────────────────────

_DUMMY_NEARBY = [
    {
        "id": "deal_001",
        "name": "Smile Dentist",
        "location": "Padi, Chennai",
        "offer": "25% Off on All Treatments",
        "cashback": "1% Cashback",
        "distance": "6 Km",
        "type": "Clinic",
        "category": "Clinics",
        "image_url": "https://images.unsplash.com/photo-1588776814546-ec7eb8e02bb5?w=700&q=80",
        "description": "Smile Dentist offers world-class dental care with experienced professionals. Get 25% off on all treatments including cleaning, fillings, and orthodontics.",
        "address": "12, 3rd Street, Padi, Chennai - 600050",
        "phone": "+91 98765 43210",
        "timing": "Mon–Sat: 9am – 8pm",
        "rating": 4.5,
        "reviews": 128,
        "tags": ["Dental", "Clinic", "Health"],
    },
    {
        "id": "deal_002",
        "name": "CK Bakers",
        "location": "Anna Nagar, Chennai",
        "offer": "Buy 2 Get 1 Free on Cakes",
        "cashback": "1% Cashback",
        "distance": "3 Km",
        "type": "Bakery",
        "category": "Restaurant",
        "image_url": "https://images.unsplash.com/photo-1568254183919-78a4f43a2877?w=700&q=80",
        "description": "CK Bakers is Anna Nagar's favourite bakery since 1995. Freshly baked breads, cakes, and pastries daily. Buy 2 Get 1 Free on all custom cakes this month.",
        "address": "45, 2nd Avenue, Anna Nagar, Chennai - 600040",
        "phone": "+91 98765 12345",
        "timing": "Daily: 7am – 10pm",
        "rating": 4.3,
        "reviews": 312,
        "tags": ["Bakery", "Cakes", "Sweets"],
    },
    {
        "id": "deal_003",
        "name": "India Mart",
        "location": "Padi, Chennai",
        "offer": "25% Off on All Grocery",
        "cashback": "1% Cashback",
        "distance": "2 Km",
        "type": "Supermarket",
        "category": "Supermarket",
        "image_url": "https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=700&q=80",
        "description": "Your one-stop shop for all groceries. Fresh vegetables, fruits, dairy, and household essentials — all under one roof with unbeatable prices.",
        "address": "89, Industrial Estate, Padi, Chennai - 600050",
        "phone": "+91 44 2651 1234",
        "timing": "Daily: 8am – 9pm",
        "rating": 4.1,
        "reviews": 245,
        "tags": ["Grocery", "Supermarket", "Fresh"],
    },
    {
        "id": "deal_004",
        "name": "Fitness First",
        "location": "Velachery, Chennai",
        "offer": "50% Off on 3-Month Membership",
        "cashback": "1% Cashback",
        "distance": "8 Km",
        "type": "Gym",
        "category": "Gym",
        "image_url": "https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=700&q=80",
        "description": "State-of-the-art gym with premium equipment, personal trainers, and group classes. Get 50% off your first 3-month membership.",
        "address": "100 Feet Road, Velachery, Chennai - 600042",
        "phone": "+91 98400 55555",
        "timing": "Mon–Sat: 5am – 11pm | Sun: 6am – 9pm",
        "rating": 4.6,
        "reviews": 189,
        "tags": ["Gym", "Fitness", "Health"],
    },
    {
        "id": "deal_005",
        "name": "Naturals Salon",
        "location": "Nungambakkam, Chennai",
        "offer": "30% Off on All Hair Services",
        "cashback": "1% Cashback",
        "distance": "5 Km",
        "type": "Salon",
        "category": "Salon",
        "image_url": "https://images.unsplash.com/photo-1521590832167-7bcbfaa6381f?w=700&q=80",
        "description": "Naturals is India's leading salon chain. Expert stylists, premium products, and the latest trends — all at great prices this season.",
        "address": "22, Khader Nawaz Khan Road, Nungambakkam, Chennai - 600006",
        "phone": "+91 44 4390 1234",
        "timing": "Daily: 9am – 8pm",
        "rating": 4.4,
        "reviews": 421,
        "tags": ["Salon", "Hair", "Beauty"],
    },
]

_DUMMY_BRAND = [
    {
        "id": "brand_001",
        "name": "T. Nagar Silks",
        "location": "T. Nagar, Chennai",
        "offer": "Flat 20% Off on Sarees",
        "cashback": "1% Cashback",
        "distance": "10 Km",
        "type": "Clothing",
        "category": "Clothing",
        "image_url": "https://images.unsplash.com/photo-1583391733956-6c78276477e2?w=700&q=80",
        "description": "T. Nagar's most trusted silk saree brand since 1978. Premium Kancheepuram silks, designer lehengas, and ethnic wear at factory prices.",
        "address": "140, Usman Road, T. Nagar, Chennai - 600017",
        "phone": "+91 44 2434 5678",
        "timing": "Daily: 10am – 9pm",
        "rating": 4.7,
        "reviews": 876,
        "tags": ["Clothing", "Sarees", "Ethnic"],
    },
    {
        "id": "brand_002",
        "name": "Adyar Ananda Bhavan",
        "location": "Adyar, Chennai",
        "offer": "10% Off on All Sweet Boxes",
        "cashback": "1% Cashback",
        "distance": "7 Km",
        "type": "Restaurant",
        "category": "Restaurant",
        "image_url": "https://images.unsplash.com/photo-1517244683847-7456b63c5969?w=700&q=80",
        "description": "A&B — the iconic South Indian sweet and snack chain. Authentic recipes, hygienic preparation, and the same great taste since 1988.",
        "address": "16, 4th Main Road, Adyar, Chennai - 600020",
        "phone": "+91 44 2441 5252",
        "timing": "Daily: 7am – 10pm",
        "rating": 4.5,
        "reviews": 1240,
        "tags": ["Sweets", "Snacks", "South Indian"],
    },
    {
        "id": "brand_003",
        "name": "Anna Nagar Electronics",
        "location": "Anna Nagar, Chennai",
        "offer": "Up to 15% Off on Appliances",
        "cashback": "1% Cashback",
        "distance": "4 Km",
        "type": "Electronics",
        "category": "Electronics",
        "image_url": "https://images.unsplash.com/photo-1550009158-9ebf69173e03?w=700&q=80",
        "description": "Chennai's largest multi-brand electronics store. TVs, refrigerators, washing machines, mobiles — all brands, best prices, free installation.",
        "address": "Plot 5, 5th Avenue, Anna Nagar, Chennai - 600040",
        "phone": "+91 98400 11111",
        "timing": "Mon–Sat: 9am – 9pm",
        "rating": 4.2,
        "reviews": 567,
        "tags": ["Electronics", "Appliances", "Mobiles"],
    },
]


# ── Routes ────────────────────────────────────────────────────────────────────

@router.get("/nearby")
async def get_nearby_deals(
    location: Optional[str] = None,
    category: Optional[str] = None,
    current_user: dict = Depends(get_current_user),
):
    """
    Return nearby deals.
    `location` and `category` are optional filter params.
    Currently returns dummy data — replace with DB query once admin flow is done.
    """
    deals = _DUMMY_NEARBY
    if category and category.lower() not in ("all", ""):
        deals = [d for d in deals if d["category"].lower() == category.lower()]
    return {"success": True, "deals": deals, "total": len(deals)}


@router.get("/brand")
async def get_brand_deals(
    category: Optional[str] = None,
    current_user: dict = Depends(get_current_user),
):
    """
    Return brand deals.
    Currently returns dummy data — replace with DB query once admin flow is done.
    """
    deals = _DUMMY_BRAND
    if category and category.lower() not in ("all", ""):
        deals = [d for d in deals if d["category"].lower() == category.lower()]
    return {"success": True, "deals": deals, "total": len(deals)}


@router.get("/{deal_id}")
async def get_deal_detail(
    deal_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Return full details for a single deal."""
    all_deals = _DUMMY_NEARBY + _DUMMY_BRAND
    deal = next((d for d in all_deals if d["id"] == deal_id), None)
    if not deal:
        from fastapi import HTTPException, status
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Deal not found")
    return {"success": True, "deal": deal}
