from motor.motor_asyncio import AsyncIOMotorClient
from .config import get_settings

settings = get_settings()

client: AsyncIOMotorClient = None
db = None


async def connect_db():
    global client, db
    client = AsyncIOMotorClient(settings.mongodb_url)
    db = client[settings.database_name]
    # Create indexes
    await db.users.create_index("phone", unique=True)
    await db.users.create_index("email", sparse=True)
    await db.claims.create_index("user_id")
    await db.claims.create_index("claim_number", unique=True)
    await db.notifications.create_index("user_id")
    await db.otp_store.create_index("phone")
    await db.otp_store.create_index("expires_at", expireAfterSeconds=0)
    print("✅ Connected to MongoDB")


async def disconnect_db():
    global client
    if client:
        client.close()
        print("❌ Disconnected from MongoDB")


def get_db():
    return db
