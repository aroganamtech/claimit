from motor.motor_asyncio import AsyncIOMotorClient
import os
from dotenv import load_dotenv

load_dotenv()

MONGO_URL = os.getenv("MONGO_URL", "mongodb://localhost:27017")
DB_NAME = os.getenv("DB_NAME", "claimit")

client = AsyncIOMotorClient(MONGO_URL)
db = client[DB_NAME]

# ─── Collections ──────────────────────────────────────────────
users_collection = db["users"]
shops_collection = db["shops"]
ads_collection = db["ads"]
transactions_collection = db["transactions"]   # advertiser/shop billing & reward txns
reviews_collection = db["reviews"]              # shop ratings
tickets_collection = db["support_tickets"]     # help & support
otps_collection = db["otps"]                    # persisted OTPs (so they survive restarts)
team_collection = db["team_members"]            # sales referrals
