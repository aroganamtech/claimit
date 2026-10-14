from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class UserBase(BaseModel):
    full_name: Optional[str] = None   # set by user later in Profile
    phone: Optional[str] = None
    email: Optional[str] = None


class UserCreate(UserBase):
    pass


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None        # Allow linking a phone number to an email-registered account
    date_of_birth: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    pincode: Optional[str] = None
    aadhar_number: Optional[str] = None
    pan_number: Optional[str] = None
    avatar_url: Optional[str] = None
    location: Optional[str] = None  # Selected area / locality


class LocationUpdate(BaseModel):
    """What the app sends when the user picks a location.

    `location` (the display name) is all this used to carry, which meant the
    server knew a user was in "Anna Nagar" but not WHERE that is. Nothing
    could be targeted by distance as a result — no "everyone within 5 km",
    which is what a paid notification ad is sold on.

    lat/lng/pincode are all optional so an older build of the app keeps
    working unchanged: it simply sends the name, exactly as before, and the
    user gets no coordinates until they update.
    """
    location: str
    lat: Optional[float] = None
    lng: Optional[float] = None
    pincode: Optional[str] = None


class UserResponse(BaseModel):
    """Shape returned to the Flutter client.
    `id` is the Mongo `_id` rendered as a string by helpers.serialize_doc."""

    id: Optional[str] = None
    full_name: Optional[str] = None   # user fills this in via Profile
    phone: Optional[str] = None
    email: Optional[str] = None
    date_of_birth: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    pincode: Optional[str] = None
    aadhar_number: Optional[str] = None
    pan_number: Optional[str] = None
    avatar_url: Optional[str] = None
    location: Optional[str] = None
    is_verified: bool = False
    created_at: Optional[datetime] = None

    model_config = {"populate_by_name": True}
