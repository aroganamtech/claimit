from motor.motor_asyncio import AsyncIOMotorClient
from .config import get_settings

settings = get_settings()

client: AsyncIOMotorClient = None
db = None


async def _ensure_phone_index_sparse(database) -> None:
    """
    Guarantee that the phone_1 index is sparse=True.

    MongoDB's create_index() is idempotent by NAME — if phone_1 already
    exists without sparse=True it silently returns the old index instead
    of updating it, so the OperationFailure trick is unreliable.

    We inspect the index options directly and force-recreate when needed.
    """
    indexes = await database.users.index_information()
    phone_idx = indexes.get("phone_1")

    if phone_idx is not None and not phone_idx.get("sparse", False):
        # Old non-sparse index exists — drop it so we can recreate correctly.
        print("⚠️  Dropping non-sparse phone_1 index and recreating as sparse…")
        await database.users.drop_index("phone_1")
        phone_idx = None  # fall through to create

    if phone_idx is None:
        await database.users.create_index("phone", unique=True, sparse=True)
        print("✅ phone_1 index created (unique, sparse)")


async def _clean_legacy_empty_credentials(database) -> None:
    """
    Remove phone: "" / email: "" fields left by old code.

    Storing "" instead of omitting the field means the sparse unique index
    still enforces uniqueness on the empty string, causing E11000 when a
    second email-only (or phone-only) user tries to register.
    """
    r1 = await database.users.update_many(
        {"phone": {"$in": ["", None]}},
        {"$unset": {"phone": ""}},
    )
    r2 = await database.users.update_many(
        {"email": {"$in": ["", None]}},
        # Only unset email if the user also has a phone (i.e. not their only credential)
        {"$unset": {"email": ""}},
    )
    # For r2 we must be careful not to strip the only credential from a user.
    # Re-apply: only unset email="" when phone is present.
    await database.users.update_many(
        {"email": {"$in": ["", None]}, "phone": {"$exists": True, "$ne": ""}},
        {"$unset": {"email": ""}},
    )
    # Unset phone="" only when email is present (phone-less email users already handled above).
    await database.users.update_many(
        {"phone": {"$in": ["", None]}, "email": {"$exists": True, "$ne": ""}},
        {"$unset": {"phone": ""}},
    )
    if r1.modified_count or r2.modified_count:
        print(f"🧹 Cleaned legacy empty credentials: "
              f"{r1.modified_count} phone, {r2.modified_count} email fields removed")


async def connect_db():
    global client, db
    client = AsyncIOMotorClient(settings.mongodb_url)
    db = client[settings.database_name]

    # ── Users: ensure phone index is sparse (fix legacy non-sparse index) ─────
    await _ensure_phone_index_sparse(db)
    # ── Users: also ensure email index is sparse ──────────────────────────────
    await db.users.create_index("email", unique=True, sparse=True)
    # ── Clean up any legacy phone/email: "" fields that break uniqueness ──────
    await _clean_legacy_empty_credentials(db)

    await db.claims.create_index("user_id")
    await db.claims.create_index("claim_number", unique=True)
    await db.notifications.create_index("user_id")
    await db.otp_store.create_index("phone")
    await db.otp_store.create_index("expires_at", expireAfterSeconds=0)
    # Shops
    await db.shops.create_index("category_ids")
    await db.shops.create_index("name")
    # Deals
    await db.deals.create_index("deal_group")
    await db.deals.create_index("category")
    # Banners
    await db.banners.create_index("status")
    await db.banners.create_index("created_at")
    # Rewards
    await db.rewards.create_index("shop_id")
    await db.rewards.create_index("is_active")
    await db.rewards.create_index("expires_at")
    # Redeem
    await db.redeem.create_index("user_id")
    await db.redeem.create_index("reward_id")
    await db.redeem.create_index([("user_id", 1), ("reward_id", 1)])
    print("✅ Connected to MongoDB")


async def disconnect_db():
    global client
    if client:
        client.close()
        print("❌ Disconnected from MongoDB")


def get_db():
    return db
