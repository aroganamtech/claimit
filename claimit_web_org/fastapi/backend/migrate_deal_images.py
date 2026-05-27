"""
migrate_deal_images.py — Backfill image_data (base64) on deal docs that were
created before the image_data field was added.

Finds any deal/reel/banner doc in the app DB whose image_data is missing or
empty, tries to locate the uploaded file from the image_url path, encodes it
to base64, and writes it back.

Run from claimit_web_org/fastapi/backend/:
    python migrate_deal_images.py
"""

import asyncio
import base64
import os
import re
import sys
from datetime import datetime

from dotenv import load_dotenv
from motor.motor_asyncio import AsyncIOMotorClient

load_dotenv()

MONGO_URL   = os.getenv("MONGO_URL",    "mongodb://localhost:27017")
APP_DB_NAME = os.getenv("APP_DB_NAME",  "claimit_db")
UPLOAD_DIR  = os.path.join(os.path.dirname(__file__), "uploads")


def _extract_filename(image_url: str) -> str | None:
    """Pull the filename from a URL like http://localhost:8000/uploads/abc.jpg"""
    if not image_url:
        return None
    match = re.search(r"/uploads/(.+)$", image_url)
    return match.group(1) if match else None


def _file_to_b64(filename: str) -> str:
    """Read a file from uploads/ and return raw base64 string."""
    path = os.path.join(UPLOAD_DIR, filename)
    if not os.path.exists(path):
        return ""
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


async def _backfill(collection, label: str, image_field: str = "image_url"):
    docs = await collection.find(
        {"image_data": {"$in": [None, ""]}}
    ).to_list(1000)

    fixed = 0
    skipped = 0
    for doc in docs:
        url = doc.get(image_field, "") or ""
        filename = _extract_filename(url)
        if not filename:
            skipped += 1
            continue
        b64 = _file_to_b64(filename)
        if not b64:
            print(f"  ⚠️  File not found for {doc['_id']}: {filename}")
            skipped += 1
            continue
        await collection.update_one(
            {"_id": doc["_id"]},
            {"$set": {"image_data": b64}},
        )
        fixed += 1
        print(f"  ✅ {label} {doc['_id']} — image_data backfilled ({len(b64)//1024} KB)")

    print(f"  Fixed: {fixed}  |  Skipped (no file): {skipped}\n")


async def run():
    print(f"\n{'='*60}")
    print(f"  Deal Image Migration")
    print(f"  DB  : {APP_DB_NAME}")
    print(f"  Time: {datetime.utcnow().isoformat()}Z")
    print(f"{'='*60}\n")

    client = AsyncIOMotorClient(MONGO_URL)
    db     = client[APP_DB_NAME]

    print("Deals (brand & nearby)…")
    await _backfill(db["deals"], "deal")

    print("Reels (promo_reelz)…")
    await _backfill(db["reels"], "reel", image_field="thumbnail_url")

    print("Banners (home_banner)…")
    await _backfill(db["banners"], "banner")

    client.close()
    print("Migration complete.\n")


if __name__ == "__main__":
    try:
        asyncio.run(run())
    except KeyboardInterrupt:
        print("\nAborted.")
        sys.exit(1)
