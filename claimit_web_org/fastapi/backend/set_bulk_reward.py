"""
One-off migration: make existing type-less shops REWARD shops.

Bulk-uploaded shops were inserted without a shop_type, so the app treated them
as both reward AND redeem and they didn't sit cleanly on the Reward page. New
uploads now default to reward (see routers/admin.py). This script fixes the
shops that were ALREADY in the DB before that change.

It ONLY touches shops that have no type yet (missing / empty shop_type). Shops
that a user already claimed/registered as redeem or reward are left untouched.

Run once, on the server, from the backend folder:

    cd /home/ubuntu/claimit_web_local_backend
    source venv/bin/activate
    python set_bulk_reward.py            # dry run — just counts
    python set_bulk_reward.py --apply    # actually update

Reads the same MONGO_URL / APP_DB_NAME as the app.
"""
import asyncio
import os
import sys

from motor.motor_asyncio import AsyncIOMotorClient

try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass

MONGO_URL = os.getenv("MONGO_URL", "mongodb://localhost:27017")
APP_DB = os.getenv("APP_DB_NAME", "claimit_db")

# Only shops with no usable type — never overwrite a claimed redeem/reward shop.
FILTER = {
    "$or": [
        {"shop_type": {"$exists": False}},
        {"shop_type": ""},
        {"shop_type": None},
    ]
}

UPDATE = {"$set": {"shop_type": "reward", "has_rewards": True, "has_redeem": False}}


async def main(apply: bool):
    client = AsyncIOMotorClient(MONGO_URL)
    shops = client[APP_DB]["shops"]

    total = await shops.count_documents({})
    to_change = await shops.count_documents(FILTER)
    print(f"DB: {APP_DB}.shops")
    print(f"  total shops          : {total}")
    print(f"  type-less (to reward): {to_change}")

    if not apply:
        print("\nDry run — nothing changed. Re-run with --apply to update.")
        return

    res = await shops.update_many(FILTER, UPDATE)
    print(f"\n✅ Updated {res.modified_count} shop(s) to reward.")


if __name__ == "__main__":
    apply = "--apply" in sys.argv
    asyncio.run(main(apply))
