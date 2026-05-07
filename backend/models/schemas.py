from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime
from enum import Enum


class UserRole(str, Enum):
    ADVERTISER = "advertiser"   # L1 - Create Ad portal
    SALES = "sales"             # L2 - Sales/Affiliate portal
    SHOP = "shop"               # L3 - Shop owner portal


class ShopType(str, Enum):
    REWARD = "reward"
    REDEEM = "redeem"


# Auth Schemas
class RegisterRequest(BaseModel):
    phone: str
    email: EmailStr
    role: UserRole


class OTPVerifyRequest(BaseModel):
    phone: str
    email: EmailStr
    otp: str
    role: UserRole


class UserDetailsRequest(BaseModel):
    name: str
    address: str
    pincode: str
    lat: Optional[float] = None
    lng: Optional[float] = None
    role: UserRole
    phone: str
    email: EmailStr


class LoginRequest(BaseModel):
    phone: str
    role: UserRole


class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    role: UserRole
    user_id: str
    name: str


# Ad Schemas
class AdType(str, Enum):
    HOME_BANNER = "home_banner"
    PROMO_REELZ = "promo_reelz"
    BRAND_DEALS = "brand_deals"
    NEARBY_DEALS = "nearby_deals"


class AdCreate(BaseModel):
    ad_type: AdType
    title: str
    description: str
    pincode: str
    publish_today: bool = True
    scheduled_date: Optional[str] = None


class AdResponse(BaseModel):
    id: str
    ad_type: str
    title: str
    description: str
    pincode: str
    publish_date: str
    end_date: str
    amount: int
    status: str
    views: int = 0
    clicks: int = 0


# Shop Schemas
class ShopRegisterRequest(BaseModel):
    shop_name: str
    shop_address: str
    pincode: str
    lat: Optional[float] = None
    lng: Optional[float] = None
    about: str
    category: str
    shop_type: ShopType
    discount_percentage: int = 15


class ShopResponse(BaseModel):
    id: str
    shop_name: str
    shop_address: str
    category: str
    shop_type: str
    discount_percentage: int
    status: str
    total_reward_given: int = 0
    total_redeem_used: int = 0


class OfferUpdateRequest(BaseModel):
    discount_percentage: int


class StoreUpdateRequest(BaseModel):
    shop_name: Optional[str] = None
    description: Optional[str] = None
    shop_address: Optional[str] = None
    geo_location: Optional[str] = None
    category: Optional[str] = None
    shop_type: Optional[str] = None


# Sales/Affiliate Schemas
class SalesDashboardResponse(BaseModel):
    total_shops: int
    total_revenue: float
    total_members: int


class ReviewReplyRequest(BaseModel):
    review_id: str
    reply: str
