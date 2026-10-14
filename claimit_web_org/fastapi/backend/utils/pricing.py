"""
Single source of truth for every price charged across Claimit (shop
registration/claim, advertiser ad bookings, Local Finds business plans).

Stored the same way as the existing new-user-bonus / premium-slot app_config
(routers/admin.py) — one document in claimit_db.app_config, key="pricing".
Admin edits it via GET/PUT /admin/pricing; every payment flow (both this
backend and the app backend, which reads the SAME claimit_db collection)
reads the current value from here instead of a hardcoded constant, so a
price change in the admin panel takes effect everywhere immediately.

DEFAULT_PRICING below is only the fallback used until admin sets a value —
it must stay in sync with whatever the app currently shows so a fresh
deploy doesn't silently change prices.
"""
from database import app_db

DEFAULT_PRICING = {
    # Shop registration / "Claim Your Business" — same two tiers, same
    # prices, used by both ChooseShopType.jsx (register) and ShopClaim.jsx.
    "shop_premium":  720,
    "shop_standard": 365,
    # Annual renewal price shown in the shop's Settings screen.
    "shop_annual_renewal": 999,
    # Advertiser ad bookings — weekly, GST-inclusive (see advertiser.py).
    "ad_home_banner":          700,
    "ad_nearby_deals_premium": 1050,
    "ad_nearby_deals_standard": 700,
    "ad_brand_deals_premium":  700,
    "ad_brand_deals_standard": 700,
    "ad_promo_reelz_premium":  700,
    "ad_promo_reelz_standard": 700,
    # ── New ad products ──────────────────────────────────────────────────────
    # Spot Promos: ONE booking that appears in the "Spot Promos" strip on all
    # three app pages (Local Finder, Claimit Select, Claimit Privilege) — the
    # same ad in all three, not three separate placements. Priced like Nearby
    # Deals because it is the same card format with wider reach.
    "ad_spot_promos_premium":  1050,
    "ad_spot_promos_standard": 700,
    # Special Cards: sold and charged now; the app-side placement is built
    # later, so a booking is recorded against the advertiser but nothing is
    # mirrored into an app collection yet.
    "ad_special_cards_premium":  700,
    "ad_special_cards_standard": 700,
    # Notification ad — a push notification sent to every app user inside the
    # chosen radius of the advertiser's pincode. Sold standalone (no card,
    # no creative placement), which is why it is far cheaper than a weekly
    # placement: it is a single send, not seven days of inventory.
    "ad_notification": 150,
    # Add-on available on EVERY ad type: "also announce my ad by push".
    # Charged on top of the ad's own price, so an advertiser books a
    # ₹700 Brand Deal with the add-on and pays ₹800.
    "ad_notification_addon": 100,
    # Local Finds business listing plans (per year). Free is always 0 and
    # isn't editable. Payment collection for these isn't wired up yet, but
    # the price is already shown to users, so it must come from here too.
    "local_finds_standard": 999,
    "local_finds_premium":  1999,
    # Claimit Select — what a professional pays to LIST themselves in the
    # Select directory (doctors, lawyers, interior designers, ...). Premium
    # listings rank above Standard. A third "custom" plan lets the
    # professional enter any amount (0 = free), so it has no fixed price here.
    "select_premium":  1200,
    "select_standard": 700,
}


async def get_pricing() -> dict:
    """Current prices, merged over the defaults (admin only needs to have
    saved the fields they actually changed)."""
    cfg = await app_db["app_config"].find_one({"key": "pricing"})
    result = dict(DEFAULT_PRICING)
    if cfg:
        for k in DEFAULT_PRICING:
            if k in cfg and cfg[k] is not None:
                result[k] = cfg[k]
    return result
