from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from routers import auth, advertiser, sales, shop, support, geo, admin, payments
from routers import deals, reels, banners, bill, app_shops, app_account
import os
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="Claimit API", version="1.2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve uploaded files (cover photos, ad creatives, videos) in dev
os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# ── Authenticated portals ──────────────────────────────────────────────────────
app.include_router(auth.router,       prefix="/api/auth",       tags=["Auth"])
app.include_router(advertiser.router, prefix="/api/advertiser", tags=["Advertiser"])
app.include_router(sales.router,      prefix="/api/sales",      tags=["Sales"])
app.include_router(shop.router,       prefix="/api/shop",       tags=["Shop"])
app.include_router(support.router,    prefix="/api/support",    tags=["Support"])
app.include_router(geo.router,        prefix="/api/geo",        tags=["Geo"])
app.include_router(admin.router,      prefix="/api/admin",      tags=["Admin"])
app.include_router(payments.router,   prefix="/api/payments",   tags=["Payments"])

# ── Public app-facing endpoints (read by Flutter app) ─────────────────────────
app.include_router(deals.router,      prefix="/deals",          tags=["Deals"])
app.include_router(reels.router,      prefix="/reels",          tags=["Reels"])
app.include_router(banners.router,    prefix="/banners",        tags=["Banners"])
app.include_router(bill.router,       prefix="/bill",           tags=["Bill"])
app.include_router(app_shops.router,  prefix="/shops",          tags=["AppShops"])

# Public — no login required. Lets a Claimit APP user (claimit_db.users)
# delete their account from the website, per Google Play's account-deletion
# requirement. See routers/app_account.py for why this lives here.
app.include_router(app_account.router, prefix="/api/app-account", tags=["AppAccountDeletion"])


@app.get("/")
def root():
    return {"message": "Claimit API Running", "version": "1.2.0"}
