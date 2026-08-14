"""
Read-only report: shops with no phone number.

Bulk upload requires a phone per row, but some rows may have slipped through
with a blank/missing phone (e.g. an empty cell, or a value that failed the
number parse). This script does NOT change anything — it just lists them so
you can see which shops need a phone added (via Admin -> Shops, or a re-upload).

Run on the server, from the backend folder:

    cd /home/ubuntu/claimit_web_local_backend
    source venv/bin/activate
    python find_shops_no_phone.py

Reads the same MONGO_URL / APP_DB_NAME as the app.
"""
import asyncio
import os

from motor.motor_asyncio import AsyncIOMotorClient

try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass

MONGO_URL = os.getenv("MONGO_URL", "mongodb://localhost:27017")
APP_DB = os.getenv("APP_DB_NAME", "claimit_db")

# Missing, null, empty string, or whitespace-only.
FILTER = {
    "$or": [
        {"phone": {"$exists": False}},
        {"phone": None},
        {"phone": ""},
        {"phone": {"$regex": r"^\s*$"}},
    ]
}


async def main():
    client = AsyncIOMotorClient(MONGO_URL)
    shops = client[APP_DB]["shops"]

    total = await shops.count_documents({})
    missing = await shops.count_documents(FILTER)
    print(f"DB: {APP_DB}.shops")
    print(f"  total shops          : {total}")
    print(f"  missing phone        : {missing}\n")

    cursor = shops.find(
        FILTER,
        {
            "shop_name": 1, "name": 1, "category": 1,
            "state": 1, "district": 1, "city": 1, "area": 1,
            "pincode": 1, "user_id": 1, "created_at": 1,
        },
    ).sort("created_at", 1)

    n = 0
    async for s in cursor:
        n += 1
        name = s.get("shop_name") or s.get("name") or "(no name)"
        loc = " / ".join(
            x for x in (s.get("state"), s.get("district"), s.get("city"), s.get("area"))
            if x
        ) or "—"
        owned = "claimed/registered" if s.get("user_id") else "bulk (unclaimed)"
        print(f"{n:>4}. {name!r:40s} | {s.get('category', '—'):15s} | "
              f"{loc:35s} | pin {s.get('pincode') or '—':7s} | {owned} | id={s['_id']}")

    if n == 0:
        print("None found — every shop has a phone number.")


if __name__ == "__main__":
    asyncio.run(main())
