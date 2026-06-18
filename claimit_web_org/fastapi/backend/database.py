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
app_banners_collection      = app_db["banners"]
app_bill_reviews_collection = app_db["bill_manual_reviews"]
app_notifications_collection = app_db["notifications"]

# Real Flutter-app end-customers (claimit_db.users) — for admin visibility/delete.
app_users_collection        = app_db["users"]
# Feedback / complaints ticket system (claimit_db.feedback) — written by the
# main backend's new POST /feedback endpoint, read/replied-to here.
app_feedback_collection     = app_db["feedback"]
