from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import auth, advertiser, sales, shop, support, geo, admin
from app.routers import deals, reels, banners, bill
import os
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="Claimit Web API", version="1.2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# NOTE: Static file serving (uploads/) is not available on Vercel serverless.
# Store ad creatives/images in a cloud bucket (Cloudinary, S3, Supabase Storage)
# and save the public URL in the database instead of a local path.

# Authenticated portals
app.include_router(auth.router,       prefix="/api/auth",       tags=["Auth"])
app.include_router(advertiser.router, prefix="/api/advertiser", tags=["Advertiser"])
app.include_router(sales.router,      prefix="/api/sales",      tags=["Sales"])
app.include_router(shop.router,       prefix="/api/shop",       tags=["Shop"])
app.include_router(support.router,    prefix="/api/support",    tags=["Support"])
app.include_router(geo.router,        prefix="/api/geo",        tags=["Geo"])
app.include_router(admin.router,      prefix="/api/admin",      tags=["Admin"])

# Public app-facing endpoints (read by Flutter app)
app.include_router(deals.router,      prefix="/deals",          tags=["Deals"])
app.include_router(reels.router,      prefix="/reels",          tags=["Reels"])
app.include_router(banners.router,    prefix="/banners",        tags=["Banners"])
app.include_router(bill.router,       prefix="/bill",           tags=["Bill"])


@app.get("/")
def root():
    return {"message": "Claimit Web API Running", "version": "1.2.0"}
