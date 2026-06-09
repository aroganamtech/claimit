from contextlib import asynccontextmanager
import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from .database import connect_db, disconnect_db
from .routes import (
    auth, users, claims, notifications, dashboard,
    policies, locations, deals, shops, rewards,
    redeem, reels, classifieds, admin, bill, banners, advertiser,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_db()
    yield
    await disconnect_db()


app = FastAPI(
    title="Claimit API",
    description="Claimit -- loyalty, classifieds & claims backend",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

os.makedirs("uploads", exist_ok=True)
os.makedirs("uploads/avatars", exist_ok=True)
os.makedirs("uploads/claims", exist_ok=True)
os.makedirs("uploads/shop_images", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(claims.router)
app.include_router(notifications.router)
app.include_router(dashboard.router)
app.include_router(policies.router)
app.include_router(locations.router)
app.include_router(deals.router)
app.include_router(shops.router)
app.include_router(rewards.router)
app.include_router(redeem.router)
app.include_router(reels.router)
app.include_router(classifieds.router)
app.include_router(admin.router)
app.include_router(bill.router)
app.include_router(banners.router)
app.include_router(advertiser.router)


@app.get("/")
async def root():
    return {"app": "Claimit API", "version": "1.0.0", "status": "running", "docs": "/docs"}


@app.get("/health")
async def health():
    return {"status": "healthy"}


@app.exception_handler(Exception)
async def unhandled_exception_handler(request, exc):
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"},
    )
