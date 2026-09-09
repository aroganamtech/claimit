from contextlib import asynccontextmanager
import asyncio
import os

from dotenv import load_dotenv
load_dotenv()  # loads fastapi/backend/.env into os.environ

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles

from .database import connect_db, disconnect_db
from .routes import (
    auth, users, claims, notifications, dashboard,
    policies, locations, deals, shops, rewards,
    redeem, reels, classifieds, admin, bill, banners, advertiser,
    feedback, payments, learn, select, search, campaign,
)


from .utils.daily_push import daily_push_loop


@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_db()
    # Data normalization (idempotent): stored has_rewards/has_redeem must
    # match shop_type — older "Edit Shop Type" saves left them contradictory,
    # which made shops appear in BOTH the Reward and Redeem lists.
    try:
        from .database import get_db
        _db = get_db()
        # Case/format tolerant ("Reward", "Reward Shop", …) + canonicalizes
        # shop_type itself to plain lowercase "reward"/"redeem".
        await _db.shops.update_many(
            {"shop_type": {"$regex": "^\\s*reward", "$options": "i"}},
            {"$set": {"shop_type": "reward", "has_rewards": True,
                      "has_redeem": False, "discount": 0}})
        await _db.shops.update_many(
            {"shop_type": {"$regex": "^\\s*redeem", "$options": "i"}},
            {"$set": {"shop_type": "redeem", "has_rewards": False,
                      "has_redeem": True}})
    except Exception as _e:  # noqa: BLE001 — normalization must never block boot
        print(f"⚠️  shop-flag normalization skipped: {_e}")
    # Daily engagement push (random time 10:00–20:00 IST) — background task
    push_task = asyncio.create_task(daily_push_loop())
    yield
    push_task.cancel()
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
app.include_router(feedback.router)
app.include_router(payments.router)
app.include_router(learn.router)
# Bulk WhatsApp campaign. Called by the web admin panel over localhost with the
# shared X-Admin-Key — keeps the Twilio credentials in this backend only.
app.include_router(campaign.router)
app.include_router(select.router)
# One geo-search API across all nine features (the client's location brief).
app.include_router(search.router)


@app.get("/")
async def root():
    return {"app": "Claimit API", "version": "1.0.0", "status": "running", "docs": "/docs"}


@app.get("/health")
async def health():
    return {"status": "healthy"}


# ── Facebook Data Deletion ─────────────────────────────────────────────────────
# Facebook requires this URL in App Settings → Data Deletion.
# Set the URL to: http://16.170.110.232:8001/facebook/data-deletion

@app.get("/facebook/data-deletion", response_class=HTMLResponse)
async def fb_data_deletion_instructions():
    """Human-readable data deletion instructions page (GET)."""
    return HTMLResponse(content="""
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><title>Data Deletion – Claimit</title>
<style>body{font-family:sans-serif;max-width:600px;margin:60px auto;padding:0 20px;color:#333}
h1{color:#2563EB}a{color:#2563EB}</style></head>
<body>
<h1>Claimit – Data Deletion Instructions</h1>
<p>If you have used Facebook Login to sign in to the Claimit app and would like to
delete all data associated with your account, follow these steps:</p>
<ol>
  <li>Open the <strong>Claimit</strong> app on your device.</li>
  <li>Go to <strong>Profile → Settings → Delete Account</strong>.</li>
  <li>Confirm deletion. All your personal data (profile, bill history, rewards) will be
      permanently removed from our servers within 30 days.</li>
</ol>
<p>Alternatively, email us at <a href="mailto:support@claimit.in">support@claimit.in</a>
with the subject <em>"Delete My Data"</em> and we will process your request within 30 days.</p>
<p style="color:#888;font-size:13px">Claimit &copy; 2024</p>
</body>
</html>
""")


@app.post("/facebook/data-deletion")
async def fb_data_deletion_callback(request: Request):
    """
    Facebook signed_request callback (POST).
    Facebook sends a signed_request parameter when a user removes the app
    from their Facebook account. We acknowledge it and return a status URL.
    """
    return JSONResponse({
        "url": "http://16.170.110.232:8001/facebook/data-deletion",
        "confirmation_code": "claimit_deletion_acknowledged",
    })


@app.exception_handler(Exception)
async def unhandled_exception_handler(request, exc):
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"},
    )
