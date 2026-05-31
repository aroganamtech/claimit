from fastapi import APIRouter, Depends, HTTPException
from app.database import tickets_collection
from app.models.schemas import TicketCreate
from app.utils.dependencies import get_current_user
from datetime import datetime
from bson import ObjectId

router = APIRouter()


# ─── FAQs (static knowledge base — easy for the user to extend) ───
FAQS = [
    {
        "q": "How do I change the discount I offer?",
        "a": "Open the Shop portal → Offer Management → pick a discount → Publish Offer.",
    },
    {
        "q": "When do my ads go live?",
        "a": "Ads marked Publish Today go live within minutes; scheduled ads activate on the chosen date.",
    },
    {
        "q": "How is my Sales commission calculated?",
        "a": "You earn 1% of all transactions at shops you referred. View it under Sales → Earning.",
    },
    {
        "q": "I forgot my account, what do I do?",
        "a": "Use the same phone number you registered with — we'll send you a fresh OTP to log in.",
    },
    {
        "q": "Can I edit my shop name later?",
        "a": "Yes — Shop portal → Store Details Management → Edit Shop Name.",
    },
    {
        "q": "How do I cancel my subscription?",
        "a": "Email support@claimit.app or open a ticket from this page; the team replies within 24 hours.",
    },
]


@router.get("/faqs")
async def list_faqs():
    return FAQS


@router.post("/tickets")
async def create_ticket(payload: TicketCreate, current_user=Depends(get_current_user)):
    doc = {
        "user_id": str(current_user["_id"]),
        "user_name": current_user.get("name", ""),
        "user_email": current_user.get("email", ""),
        "user_phone": current_user.get("phone", ""),
        "role": current_user.get("role", ""),
        "subject": payload.subject,
        "message": payload.message,
        "category": payload.category or "general",
        "status": "open",
        "created_at": datetime.utcnow(),
    }
    res = await tickets_collection.insert_one(doc)
    doc["id"] = str(res.inserted_id)
    del doc["_id"]
    if "created_at" in doc:
        doc["created_at"] = str(doc["created_at"])
    return doc


@router.get("/tickets")
async def list_tickets(current_user=Depends(get_current_user)):
    user_id = str(current_user["_id"])
    tickets = await tickets_collection.find({"user_id": user_id}).sort("created_at", -1).to_list(100)
    return [
        {
            "id": str(t["_id"]),
            "subject": t.get("subject", ""),
            "message": t.get("message", ""),
            "category": t.get("category", ""),
            "status": t.get("status", "open"),
            "created_at": str(t.get("created_at", "")),
        } for t in tickets
    ]
