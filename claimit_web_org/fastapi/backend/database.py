from motor.motor_asyncio import AsyncIOMotorClient
import os
from dotenv import load_dotenv

load_dotenv()

# ── Web portal database (claimit_web) ─────────────────────────────────────────
MONGO_URL = os.getenv("MONGO_URL", "mongodb://localhost:27017")
DB_NAME   = os.getenv("DB_NAME", "claimit_web")
APP_DB    = os.getenv("APP_DB_NAME","claimit_db")

client = AsyncIOMotorClient(MONGO_URL)
App_client=AsyncIOMotorClient(MONGO_URL)
db     = client[DB_NAME]
App_db=App_client[APP_DB]

# Web-portal collections
users_collection        = db["users"]
shops_collection        = App_db["shops"]
ads_collection          = db["ads"]
transactions_collection = db["transactions"]
reviews_collection      = db["reviews"]
tickets_collection      = db["support_tickets"]
otps_collection         = db["otps"]
team_collection         = db["team_members"]
deleted_users_collection = db["deleted_users"]


# ── App database (claimit_db) ─────────────────────────────────────────────────
# The Flutter app reads deals from claimit_db.deals and reels from
# claimit_db.reels on the SAME MongoDB Atlas cluster.
# When an advertiser submits a deal / reel ad through the web portal we write
# into BOTH the web ads collection AND the app-facing collection so the ad
# appears in the app immediately without any manual seeding.

APP_DB_NAME = os.getenv("APP_DB_NAME", "claimit_db")
app_db      = client[APP_DB_NAME]

app_deals_collection        = app_db["deals"]
app_reels_collection        = app_db["reels"]
app_shops_collection        = app_db["shops"]
# Per-category image pools (admin uploads up to 15 images per category; shops
# with no own photo show a random image from their category).
category_images_collection  = app_db["category_images"]
app_banners_collection      = app_db["banners"]
# Spot Promos — ONE paid booking that appears in the "Spot Promos" strip on
# all three app feature pages (Local Finder, Claimit Select, Claimit
# Privilege). Deliberately a single shared collection rather than three, so
# the advertiser buys one placement and all three pages show the same ad.
app_spot_promos_collection  = app_db["spot_promos"]
# Queue for paid notification ads. This backend only ever WRITES jobs here;
# the app backend's background loop (app/utils/ad_push.py) is what resolves
# the audience and sends the pushes, because the user coordinates and the
# device tokens live on that side.
app_ad_notifications_collection = app_db["ad_notifications"]
app_bill_reviews_collection = app_db["bill_manual_reviews"]
app_notifications_collection = app_db["notifications"]
# "Learn Claimit" — admin-curated question + how-to video lessons shown in
# the app's Featured Zones ("Learn Claimit" tile). Same claimit_db the app
# backend reads from directly.
app_learn_collection        = app_db["learn_content"]

# Real Flutter-app end-customers (claimit_db.users) — for admin visibility/delete.
app_users_collection        = app_db["users"]
# Feedback / complaints ticket system (claimit_db.feedback) — written by the
# main backend's new POST /feedback endpoint, read/replied-to here.
app_feedback_collection     = app_db["feedback"]
