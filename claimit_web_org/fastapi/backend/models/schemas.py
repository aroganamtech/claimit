from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime
from enum import Enum


# ─── Enums ────────────────────────────────────────────────────
class UserRole(str, Enum):
    ADVERTISER = "advertiser"   # L1 - Create Ad portal
    SALES = "sales"             # L2 - Sales/Affiliate portal
    SHOP = "shop"               # L3 - Shop owner portal


class SalesSubRole(str, Enum):
    SALES_HEAD          = "sales_head"
    SALES_EXECUTIVE     = "sales_executive"
    ADVERTISING_EXECUTIVE = "advertising_executive"
    FREELANCER          = "freelancer"


class ShopType(str, Enum):
    REWARD = "reward"
    REDEEM = "redeem"


class AdType(str, Enum):
    HOME_BANNER = "home_banner"
    PROMO_REELZ = "promo_reelz"
    BRAND_DEALS = "brand_deals"
    NEARBY_DEALS = "nearby_deals"


# ─── Auth ─────────────────────────────────────────────────────
class RegisterRequest(BaseModel):
    phone: str
    email: EmailStr
    role: UserRole
    sub_role: Optional[str] = None      # sales sub-role
    referred_by: Optional[str] = None   # Sales Head unique_id


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
    sub_role: Optional[str] = None
    referred_by: Optional[str] = None


class LoginRequest(BaseModel):
    phone: str
    role: UserRole


class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    role: UserRole
    user_id: str
    name: str
    email: Optional[str] = None


# ─── Ads ──────────────────────────────────────────────────────
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


# ─── Shops ────────────────────────────────────────────────────
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


class OfferUpdateRequest(BaseModel):
    discount_percentage: int


class StoreUpdateRequest(BaseModel):
    shop_name: Optional[str] = None
    about: Optional[str] = None
    description: Optional[str] = None
    shop_address: Optional[str] = None
    geo_location: Optional[str] = None
    category: Optional[str] = None
    shop_type: Optional[str] = None


# ─── Reviews ──────────────────────────────────────────────────
class ReviewCreate(BaseModel):
    shop_id: str
    name: str
    rating: int
    comment: str


class ReviewReplyRequest(BaseModel):
    review_id: str
    reply: str


# ─── Sales / Affiliate ────────────────────────────────────────
class SalesShopAdd(BaseModel):
    shop_name: str
    shop_address: str
    category: str
    pincode: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None


# ─── Help & Support ───────────────────────────────────────────
class TicketCreate(BaseModel):
    subject: str
    message: str
    category: Optional[str] = "general"   # general | billing | technical | account


# ─── Gallery ──────────────────────────────────────────────────
class GalleryPhotoRequest(BaseModel):
    photo_b64: str

class GalleryPhotoKeyRequest(BaseModel):
    s3_key: str


# ─── Geo ──────────────────────────────────────────────────────
class GeoLookupRequest(BaseModel):
    lat: float
    lng: float


# ─── Admin ────────────────────────────────────────────────────
class AdminLoginRequest(BaseModel):
    username: str
    password: str


class AdminAdPatch(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = None       # active | scheduled | paused
    pincode: Optional[str] = None


class AdminShopPatch(BaseModel):
    shop_name: Optional[str] = None
    status: Optional[str] = None       # pending | active | suspended
    discount_percentage: Optional[int] = None


class AdminTicketPatch(BaseModel):
    status: Optional[str] = None       # open | resolved | closed
    reply: Optional[str] = None


class AdminFeedbackReply(BaseModel):
    reply: str
    status: Optional[str] = "replied"  # open | replied | closed
