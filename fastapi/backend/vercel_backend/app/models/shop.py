from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


# ─────────────────────────────────────────────────────────────────────────────
# Shop models
# ─────────────────────────────────────────────────────────────────────────────

class ShopCreate(BaseModel):
    name: str
    location: str
    category_ids: List[int]
    discount: int
    rating: float
    has_rewards: bool = True
    has_redeem: bool = True
    address: str = ''
    timing: str = ''
    phone: str = ''
    image_name: str = ''   # filename in uploads/shop_images/ e.g. "img1.jpg"
    added_days_ago: int = 0


class ShopResponse(BaseModel):
    id: Optional[str] = None
    name: str
    location: str
    category_ids: List[int]
    discount: int
    rating: float
    has_rewards: bool
    has_redeem: bool
    address: str = ''
    timing: str = ''
    phone: str = ''
    image_name: str = ''
    image_data: Optional[str] = None   # base64-encoded bytes of the image
    added_days_ago: int = 0
    created_at: Optional[datetime] = None

    model_config = {"populate_by_name": True}


# ─────────────────────────────────────────────────────────────────────────────
# Reward models
# ─────────────────────────────────────────────────────────────────────────────

class RewardCreate(BaseModel):
    shop_id: str
    title: str
    description: str
    points_required: int
    discount_percent: int
    valid_days: int = 30    # days from now until expiry


class RewardResponse(BaseModel):
    id: Optional[str] = None
    shop_id: str
    shop_name: Optional[str] = None
    title: str
    description: str
    points_required: int
    discount_percent: int
    expires_at: Optional[datetime] = None
    is_active: bool = True

    model_config = {"populate_by_name": True}


# ─────────────────────────────────────────────────────────────────────────────
# Redeem models
# ─────────────────────────────────────────────────────────────────────────────

class RedeemCreate(BaseModel):
    shop_id: str
    reward_id: str


class RedeemResponse(BaseModel):
    id: Optional[str] = None
    user_id: str
    shop_id: str
    shop_name: Optional[str] = None
    reward_id: str
    reward_title: Optional[str] = None
    status: str = 'pending'   # pending | approved | used | expired
    coupon_code: str = ''
    redeemed_at: Optional[datetime] = None
    used_at: Optional[datetime] = None

    model_config = {"populate_by_name": True}
