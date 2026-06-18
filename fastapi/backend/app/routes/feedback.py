"""
Feedback / Complaints — lets an app user submit feedback or a complaint and
later see the admin's reply (full two-way ticket system).

New, additive file — does not touch any existing route. Reuses the existing
get_current_user dependency unchanged, so it authenticates exactly like every
other route on this backend.

Admin reads/replies to these tickets from the separate web-admin backend
(claimit_web_org), reading/writing this SAME `feedback` collection in
claimit_db directly via its own App_db client — see that backend's
routers/admin.py for the matching admin-side endpoints.
"""
from fastapi import APIRouter, HTTPException, Depends
from datetime import datetime
from typing import Optional, Literal
from bson import ObjectId
from pydantic import BaseModel, Field

from ..database import get_db
from ..utils.auth import get_current_user
from ..utils.helpers import serialize_doc

router = APIRouter(prefix="/feedback", tags=["Feedback"])


class FeedbackCreate(BaseModel):
    category: Literal["feedback", "complaint", "suggestion"] = "feedback"
    subject: str = Field(..., min_length=1, max_length=150)
    message: str = Field(..., min_length=1, max_length=2000)


@router.post("")
async def submit_feedback(body: FeedbackCreate, current_user: dict = Depends(get_current_user)):
    db = get_db()
    user_id = str(current_user["_id"])
    doc = {
        "user_id": user_id,
        "user_name": current_user.get("name") or "",
        "category": body.category,
        "subject": body.subject.strip(),
        "message": body.message.strip(),
        "status": "open",          # open | replied | closed
        "admin_reply": None,
        "replied_at": None,
        "created_at": datetime.utcnow(),
    }
    result = await db.feedback.insert_one(doc)
    doc["_id"] = result.inserted_id
    return serialize_doc(doc)


@router.get("/my")
async def get_my_feedback(current_user: dict = Depends(get_current_user)):
    db = get_db()
    user_id = str(current_user["_id"])
    cursor = db.feedback.find({"user_id": user_id}).sort("created_at", -1)
    docs = await cursor.to_list(length=200)
    return [serialize_doc(d) for d in docs]


@router.get("/{feedback_id}")
async def get_feedback_detail(feedback_id: str, current_user: dict = Depends(get_current_user)):
    db = get_db()
    try:
        oid = ObjectId(feedback_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid feedback ID")
    doc = await db.feedback.find_one({"_id": oid, "user_id": str(current_user["_id"])})
    if not doc:
        raise HTTPException(status_code=404, detail="Feedback not found")
    return serialize_doc(doc)
