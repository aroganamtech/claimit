"""
migrate_shops.py — One-time migration to fix web-registered shops in claimit_db.shops.

WHAT IT DOES
============
1. Deletes orphan "sync" documents (those created by the old _sync_shop_to_app code
   that had a `web_shop_id` field).  These are ghost duplicates — one per shop —
   that the Flutter app was picking up alongside the real web doc.

2. Backfills app-friendly field aliases on every existing web shop doc
   (docs that have `shop_name` but no `name` field).  After this the Flutter
   app can read name / discount / category_ids / image_data etc. correctly.

3. Also strips the data-URL prefix from cover_photo_b64 / gallery_photos so
   image_data / image_data_list stored in the doc are raw base64 (as the app
   expects), not "data:image/jpeg;base64,..." strings.

HOW TO RUN
==========
From the claimit_web_org/fastapi/backend/ folder:

    python migrate_shops.py

Set MONGO_URL and APP_DB_NAME environment variables (or add a .env file)
if they differ from the defaults below.
"""

import asyncio
import os
import re
import sys
from datetime import datetime

from dotenv import load_dotenv
from motor.motor_asyncio import AsyncIOMotorClient

load_dotenv()

MONGO_URL   = os.getenv("MONGO_URL",    "mongodb://localhost:27017")
APP_DB_NAME = os.getenv("APP_DB_NAME",  "claimit_db")

# ─── Category map (must mirror routers/shop.py) ───────────────────────────────
_CATEGORY_MAP: dict[str, int] = {
    "new deals": 1,  "hardware": 1,
    "groceries": 2,  "grocery": 2,
    "supermarket": 3,
    "pharmacy": 4,   "medical": 4,
    "salon": 5,      "salons": 5,      "beauty": 5,
    "gym": 6,        "fitness": 6,
    "restaurant": 7, "restaurants": 7, "food": 7,   "bakery": 7,
    "cafes": 8,      "cafe": 8,        "coffee": 8,
    "clothing": 9,   "fashion": 9,     "apparel": 9,
    "department": 10, "department store": 10,
    "electronics": 11,
    "books": 12,     "book": 12,       "stationery": 12,
    "toys": 13,      "toy": 13,
    "baby": 14,      "baby products": 14,
    "home decor": 15, "home": 15,
    "furniture": 16,
    "spa": 17,
    "clinics": 21,   "clinic": 21,     "hospital": 21, "dental": 21, "dentist": 21,
    "pets": 23,      "pet": 23,
    "sports": 24,    "sport": 24,
    "mobile": 26,    "mobile & accessories": 26,  "accessories": 26,
    "computer": 27,  "computer & laptop": 27,     "laptop": 27,
    "gifts": 28,     "gift": 28,
    "jewellery": 29, "jewelry": 29,
    "shoes": 30,     "footwear": 30,   "shoe": 30,
}

def _category_to_ids(category: str) -> list[int]:
    key = (category or "").strip().lower()
    cid = _CATEGORY_MAP.get(key)
    return [cid] if cid else [1]

def _strip_b64_prefix(data_url: str | None) -> str:
    if not data_url:
        return ""
    match = re.match(r"data:[^;]+;base64,(.+)", data_url, re.DOTALL)
    return match.group(1) if match else data_url

def _build_app_fields(shop: dict) -> dict:
    """Compute the app-friendly field aliases from a web shop document."""
    cover_raw   = _strip_b64_prefix(shop.get("cover_photo_b64") or "")
    gallery     = shop.get("gallery_photos", []) or []
    gallery_raw = [_strip_b64_prefix(p) for p in gallery if p]

    return {
        "name":            shop.get("shop_name", ""),
        "location":        shop.get("location", ""),
        "category_ids":    _category_to_ids(shop.get("category", "")),
        "discount":        shop.get("discount_percentage", 0),
        "rating":          shop.get("rating", 4.0),
        "added_days_ago":  0,
        "image_name":      "",
        "image_names":     [],
        "has_rewards":     shop.get("shop_type", "") == "reward",
        "has_redeem":      shop.get("shop_type", "") == "redeem",
        "about":           shop.get("about", ""),
        "address":         shop.get("shop_address", ""),
        "timing":          shop.get("timing", ""),
        "phone":           shop.get("phone", ""),
        "lat":             shop.get("lat"),
        "lng":             shop.get("lng"),
        "image_data":      cover_raw,
        "image_data_list": gallery_raw,
    }


async def run_migration():
    print(f"\n{'='*60}")
    print(f"  Claimit Shop Migration")
    print(f"  DB  : {APP_DB_NAME}  ({MONGO_URL[:40]}...)")
    print(f"  Time: {datetime.utcnow().isoformat()}Z")
    print(f"{'='*60}\n")

    client = AsyncIOMotorClient(MONGO_URL)
    db     = client[APP_DB_NAME]
    shops  = db["shops"]

    # ── Step 1: Delete orphan web_shop_id docs ────────────────────────────────
    print("Step 1 — Deleting orphan sync docs (have web_shop_id field)...")
    orphan_cursor = shops.find({"web_shop_id": {"$exists": True}})
    orphan_docs   = await orphan_cursor.to_list(length=1000)

    if orphan_docs:
        orphan_ids = [d["_id"] for d in orphan_docs]
        result = await shops.delete_many({"_id": {"$in": orphan_ids}})
        print(f"  ✅ Deleted {result.deleted_count} orphan doc(s):")
        for d in orphan_docs:
            print(f"     • {d['_id']}  (was synced from web_shop_id={d.get('web_shop_id')})")
    else:
        print("  ℹ️  No orphan docs found.")

    # ── Step 2: Backfill app fields on web shop docs ──────────────────────────
    print("\nStep 2 — Backfilling app fields on web shop docs (have shop_name, no name)...")
    web_cursor = shops.find({
        "shop_name": {"$exists": True},
        "name":      {"$exists": False},
    })
    web_docs = await web_cursor.to_list(length=1000)

    if web_docs:
        updated = 0
        for doc in web_docs:
            app_fields = _build_app_fields(doc)
            await shops.update_one(
                {"_id": doc["_id"]},
                {"$set": app_fields},
            )
            updated += 1
            shop_name = doc.get("shop_name", "?")
            category  = doc.get("category", "?")
            cat_ids   = app_fields["category_ids"]
            has_img   = bool(app_fields["image_data"])
            n_gallery = len(app_fields["image_data_list"])
            print(
                f"  ✅ {doc['_id']}  shop_name={shop_name!r}  "
                f"category={category!r}→{cat_ids}  "
                f"cover={'yes' if has_img else 'no'}  gallery={n_gallery}"
            )
        print(f"\n  Total updated: {updated} doc(s)")
    else:
        print("  ℹ️  No web shop docs needing backfill.")

    # ── Step 3: Re-sync docs that already have name but stale image fields ────
    print("\nStep 3 — Re-syncing image fields on docs that already have name but empty image_data...")
    stale_cursor = shops.find({
        "shop_name":      {"$exists": True},
        "name":           {"$exists": True},
        "cover_photo_b64": {"$exists": True},
        "image_data":     "",   # was synced but cover was null at that time
    })
    stale_docs = await stale_cursor.to_list(length=1000)

    refreshed = 0
    for doc in stale_docs:
        cover_raw   = _strip_b64_prefix(doc.get("cover_photo_b64") or "")
        gallery     = doc.get("gallery_photos", []) or []
        gallery_raw = [_strip_b64_prefix(p) for p in gallery if p]
        if cover_raw or gallery_raw:
            await shops.update_one(
                {"_id": doc["_id"]},
                {"$set": {"image_data": cover_raw, "image_data_list": gallery_raw}},
            )
            refreshed += 1
            print(f"  ✅ {doc['_id']}  refreshed image_data (cover={'yes' if cover_raw else 'no'}, gallery={len(gallery_raw)})")

    if refreshed == 0:
        print("  ℹ️  No stale image docs found.")

    # ── Summary ───────────────────────────────────────────────────────────────
    total_after = await shops.count_documents({})
    print(f"\n{'='*60}")
    print(f"  Migration complete.")
    print(f"  Total docs in claimit_db.shops now: {total_after}")
    print(f"{'='*60}\n")

    client.close()


if __name__ == "__main__":
    try:
        asyncio.run(run_migration())
    except KeyboardInterrupt:
        print("\nAborted.")
        sys.exit(1)
