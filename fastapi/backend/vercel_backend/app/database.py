"""
Serverless-safe MongoDB connection.

Vercel spins up a new Python process for every cold start, and the process
may be reused across warm invocations.  We use a module-level lazy singleton
so we:
  • create the client once per process lifetime (cheap on warm invocations)
  • never try to reuse a dead socket across cold starts

The lifespan hook in main.py still calls connect_db() on startup so that
indexes are guaranteed to exist on the first request of a new process.
"""

from motor.motor_asyncio import AsyncIOMotorClient
from .config import get_settings

settings = get_settings()

_client: AsyncIOMotorClient | None = None
_db = None


async def connect_db():
    """Called once per process on startup (lifespan hook)."""
    global _client, _db
    if _db is not None:
        return  # already connected (warm invocation)

    _client = AsyncIOMotorClient(
        settings.mongodb_url,
        # Keep the connection pool small — Vercel functions are short-lived
        # and Atlas has a connection limit on free/shared tiers.
        maxPoolSize=5,
        minPoolSize=0,
        serverSelectionTimeoutMS=5000,
    )
    _db = _client[settings.database_name]

    # Ensure indexes exist (idempotent — safe to run every cold start)
    await _db.users.create_index("phone", unique=True)
    await _db.users.create_index("email", sparse=True)
    await _db.claims.create_index("user_id")
    await _db.claims.create_index("claim_number", unique=True)
    await _db.notifications.create_index("user_id")
    await _db.otp_store.create_index("phone")
    await _db.otp_store.create_index("expires_at", expireAfterSeconds=0)
    await _db.shops.create_index("category_ids")
    await _db.shops.create_index("name")
    await _db.deals.create_index("deal_group")
    await _db.deals.create_index("category")
    await _db.rewards.create_index("shop_id")
    await _db.rewards.create_index("is_active")
    await _db.rewards.create_index("expires_at")
    await _db.redeem.create_index("user_id")
    await _db.redeem.create_index("reward_id")
    await _db.redeem.create_index([("user_id", 1), ("reward_id", 1)])
    await _db.reels.create_index("shop_id")
    await _db.classifieds.create_index("category")
    await _db.classifieds.create_index("subcategory")
    await _db.classifieds.create_index("pincode")

    print("✅ Connected to MongoDB Atlas")


async def disconnect_db():
    """Called on shutdown — Vercel may not always fire this, which is fine."""
    global _client, _db
    if _client:
        _client.close()
        _client = None
        _db = None
        print("❌ Disconnected from MongoDB")


def get_db():
    """
    Returns the active DB handle.
    All route handlers call this; if somehow called before connect_db(),
    it returns None and routes will surface a 500 rather than crashing hard.
    """
    return _db
