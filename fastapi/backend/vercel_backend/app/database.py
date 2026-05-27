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


async def _ensure_phone_index_sparse(database) -> None:
    """
    Guarantee that the phone_1 index is sparse=True.

    MongoDB's create_index() is idempotent by NAME — if phone_1 already
    exists without sparse=True it silently returns the old index instead
    of updating it, so the OperationFailure trick is unreliable across
    all Motor/PyMongo versions.

    We inspect the index options directly and force-recreate when needed.
    """
    indexes = await database.users.index_information()
    phone_idx = indexes.get("phone_1")

    if phone_idx is not None and not phone_idx.get("sparse", False):
        print("⚠️  Dropping non-sparse phone_1 index and recreating as sparse…")
        await database.users.drop_index("phone_1")
        phone_idx = None

    if phone_idx is None:
        await database.users.create_index("phone", unique=True, sparse=True)
        print("✅ phone_1 index created (unique, sparse)")


async def _clean_legacy_empty_credentials(database) -> None:
    """
    Remove phone/email fields that are "" or null from documents that
    also have the other credential set.

    Old code stored phone: None (→ BSON null) or phone: "" for email-only
    users.  Sparse unique indexes still enforce uniqueness on null and "",
    causing E11000 when a second email-only user tries to register.
    We $unset those fields so the sparse index ignores those documents.
    """
    # Unset phone that is empty/null when email is the real credential
    r1 = await database.users.update_many(
        {"phone": {"$in": ["", None]}, "email": {"$exists": True, "$nin": ["", None]}},
        {"$unset": {"phone": ""}},
    )
    # Unset email that is empty/null when phone is the real credential
    r2 = await database.users.update_many(
        {"email": {"$in": ["", None]}, "phone": {"$exists": True, "$nin": ["", None]}},
        {"$unset": {"email": ""}},
    )
    if r1.modified_count or r2.modified_count:
        print(f"🧹 Cleaned legacy empty credentials: "
              f"{r1.modified_count} phone fields, {r2.modified_count} email fields removed")


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

    # ── Users: ensure phone index is sparse (fix legacy non-sparse index) ─────
    await _ensure_phone_index_sparse(_db)
    # ── Users: also ensure email index is sparse + unique ─────────────────────
    await _db.users.create_index("email", unique=True, sparse=True)
    # ── Clean up any legacy phone/email: "" / null fields ─────────────────────
    await _clean_legacy_empty_credentials(_db)
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
    await _db.banners.create_index("status")
    await _db.banners.create_index("created_at")
    await _db.classifieds.create_index("category")
    await _db.classifieds.create_index("subcategory")
    await _db.classifieds.create_index("pincode")
    # Bill scan / wallet
    await _db.user_wallets.create_index("user_id", unique=True)
    await _db.bill_scans.create_index("user_id")
    await _db.bill_scans.create_index([("user_id", 1), ("dup_key", 1)], unique=True)

    print("✅ Connected to MongoDB Atlas")


async def disconnect_db():
    """Called on shutdown — Vercel may not always fire this, which is fine."""
    global _client, _db
    if _client:
        _client.close()
        _client = None
        _db = None
        print("❌ Disconnected from MongoDB")


async def get_db_async():
    """
    Async version — ensures connection exists before returning.
    Use this as a FastAPI dependency: db = await get_db_async()
    Handles the case where Vercel didn't fire the lifespan startup hook.
    """
    if _db is None:
        await connect_db()
    return _db


def get_db():
    """
    Sync wrapper used by route handlers that already have a connected DB.
    Falls back to None if called before any connection — routes will 500
    rather than crash hard. For Vercel, prefer using the middleware below
    which calls connect_db() on every cold start.
    """
    return _db
