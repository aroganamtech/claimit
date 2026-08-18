"""
seed_select.py — Add professionals to Claimit Select.

HOW TO RUN (from the fastapi/backend/ folder):
    python seed_select.py              # add / update the people listed below
    python seed_select.py --dry-run    # show what would happen, change nothing
    python seed_select.py --list       # show what's currently seeded
    python seed_select.py --wipe       # remove ONLY seeded people

⚠️  WHY THIS SCRIPT IS NOT LIKE seed.py
    seed.py clears whole collections (delete_many({})) before inserting.
    That must NEVER happen here: real professionals REGISTER THEMSELVES and
    PAY a listing fee, so wiping select_professionals would delete paying
    customers' listings.

    Instead this script is non-destructive and re-runnable:
      • Every seeded person gets user_id = "seed:<key>" and seeded = True.
      • Running again UPDATES those same people instead of duplicating them
        (upsert on user_id, which is uniquely indexed).
      • --wipe only ever deletes documents with seeded = True. A real
        self-registered professional is never touched by this script.

PHOTOS
    Put image files in:  uploads/select_images/
    then reference them by filename in the PEOPLE list below, e.g.
        "photo": "ananya.jpg",
        "portfolio": ["ananya_1.jpg", "ananya_2.jpg"],
    They're uploaded to S3 and only the key is stored (same as the app does).
    If a file is missing the person is still created — the app falls back to
    a placeholder avatar — and a warning is printed.

AWS credentials are read from .env, same as seed.py:
    AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION,
    AWS_STORAGE_BUCKET_NAME
"""

import asyncio
import io
import os
import sys
import uuid
from datetime import datetime, timezone

import boto3
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

load_dotenv()

MONGO_URL = os.getenv("MONGODB_URL", "mongodb://localhost:27017")
DB_NAME   = os.getenv("DATABASE_NAME", "claimit_db")
IMAGE_DIR = os.path.join(os.path.dirname(__file__), "uploads", "select_images")

# ── S3 config (identical to seed.py) ──────────────────────────────────────────
_AWS_KEY    = os.getenv("AWS_ACCESS_KEY_ID", "")
_AWS_SECRET = os.getenv("AWS_SECRET_ACCESS_KEY", "")
_AWS_REGION = os.getenv("AWS_REGION", "eu-north-1")
_BUCKET     = os.getenv("AWS_STORAGE_BUCKET_NAME", "claimit-image-bucket")


def _s3():
    return boto3.client(
        "s3",
        region_name=_AWS_REGION,
        aws_access_key_id=_AWS_KEY,
        aws_secret_access_key=_AWS_SECRET,
    )


# Must match SELECT_CATEGORIES in app/routes/select.py — a typo in a person's
# "category" is caught before anything is written.
CATEGORY_LABELS = {
    "doctors":       "Doctors",
    "lawyers":       "Lawyers",
    "ca_tax":        "CA & Tax",
    "architects":    "Architects",
    "interior":      "Interior Designers",
    "tutors":        "Tutors",
    "beauty":        "Beauty Experts",
    "fitness":       "Fitness Trainers",
    "photographers": "Photographers",
    "events":        "Event Planners",
    "financial":     "Financial Advisors",
    "home_services": "Home Services",
}


# ═════════════════════════════════════════════════════════════════════════════
#  EDIT THIS LIST — one entry per professional you want listed.
#
#  Required : key, name, category, phone
#  Optional : everything else (sensible defaults are applied)
#
#  "key" is a permanent id for the person. Keep it stable — changing it
#  creates a NEW person instead of updating the existing one.
#
#  "plan": "premium" ranks above "standard" everywhere in the app.
# ═════════════════════════════════════════════════════════════════════════════

PEOPLE = [
    {
        "key": "ananya-menon",
        "name": "Ananya Menon",
        "category": "interior",
        "role": "Interior Designer",
        "about": "Ananya creates elegant, functional spaces that reflect your "
                 "personality. Specializing in modern minimal and luxury interiors.",
        "experience_years": 8,
        "consultation_fee": 499,
        "services": ["Home Interiors", "Modular Kitchens",
                     "Space Planning", "Renovation Consultation"],
        "tags": ["Modern", "Minimal", "Luxury"],
        "phone": "9000000001",
        "email": "",
        "area": "Anna Nagar",
        "city": "Chennai",
        "district": "Chennai",
        "state": "Tamil Nadu",
        "pincode": "600040",
        "address": "",
        "lat": 13.0850,
        "lng": 80.2101,
        "plan": "premium",
        "rating": 4.9,
        "review_count": 126,
        "offer_text": "20% OFF on this week's bookings",
        "offer_percent": 20,
        "offer_valid_till": "25 May 2026",
        "photo": "ananya.jpg",
        "portfolio": ["ananya_1.jpg", "ananya_2.jpg", "ananya_3.jpg"],
    },
    {
        "key": "rohit-iyer",
        "name": "Rohit Iyer",
        "category": "interior",
        "role": "Interior Designer",
        "about": "Contemporary and modular interiors with a focus on smart "
                 "storage and clean lines.",
        "experience_years": 6,
        "consultation_fee": 599,
        "services": ["Modular Kitchens", "Wardrobes", "Full Home Interiors"],
        "tags": ["Contemporary", "Modular"],
        "phone": "9000000002",
        "area": "Anna Nagar",
        "city": "Chennai",
        "district": "Chennai",
        "state": "Tamil Nadu",
        "pincode": "600040",
        "lat": 13.0878,
        "lng": 80.2145,
        "plan": "standard",
        "rating": 4.7,
        "review_count": 98,
        "photo": "rohit.jpg",
        "portfolio": [],
    },
    {
        "key": "meera-krishnan",
        "name": "Meera Krishnan",
        "category": "interior",
        "role": "Interior Designer",
        "about": "Classic and elegant interiors, with Vastu-compliant layouts "
                 "on request.",
        "experience_years": 5,
        "consultation_fee": 499,
        "services": ["Home Interiors", "Vastu Consultation", "Space Planning"],
        "tags": ["Classic", "Elegant", "Vastu"],
        "phone": "9000000003",
        "area": "Anna Nagar",
        "city": "Chennai",
        "district": "Chennai",
        "state": "Tamil Nadu",
        "pincode": "600040",
        "lat": 13.0921,
        "lng": 80.2058,
        "plan": "standard",
        "rating": 4.6,
        "review_count": 74,
        "photo": "meera.jpg",
        "portfolio": [],
    },
]


# ─────────────────────────────────────────────────────────────────────────────
# Image upload
# ─────────────────────────────────────────────────────────────────────────────

def _upload_image(filename: str, folder: str,
                  max_size: tuple = (800, 800), quality: int = 70) -> str:
    """Read uploads/select_images/<filename>, resize, upload to S3, return the
    S3 key. Returns "" when the file is missing or the upload fails — the app
    shows a placeholder avatar in that case, so a missing photo is never fatal.
    """
    if not filename:
        return ""
    path = os.path.join(IMAGE_DIR, filename)
    if not os.path.exists(path):
        print(f"      ⚠️  image not found, skipping: uploads/select_images/{filename}")
        return ""
    try:
        from PIL import Image

        img = Image.open(path).convert("RGB")
        img.thumbnail(max_size, Image.LANCZOS)
        buf = io.BytesIO()
        img.save(buf, "JPEG", quality=quality, optimize=True)
        data = buf.getvalue()

        key = f"{folder}/{uuid.uuid4().hex}.jpg"
        _s3().put_object(Bucket=_BUCKET, Key=key,
                         Body=data, ContentType="image/jpeg")
        print(f"      ⬆️  uploaded {filename}  ({len(data) // 1024} KB)")
        return key
    except Exception as e:
        print(f"      ⚠️  upload failed for {filename}: {e}")
        return ""


# ─────────────────────────────────────────────────────────────────────────────
# Document builder
# ─────────────────────────────────────────────────────────────────────────────

def _validate(person: dict, index: int) -> str:
    """Returns an error string, or "" when the entry is usable."""
    key = person.get("key", "")
    if not key:
        return f"PEOPLE[{index}] is missing a 'key'"
    if not person.get("name"):
        return f"'{key}' is missing a 'name'"
    cat = person.get("category", "")
    if cat not in CATEGORY_LABELS:
        return (f"'{key}' has unknown category '{cat}'. "
                f"Valid: {', '.join(CATEGORY_LABELS)}")
    return ""


def _build_doc(person: dict, upload_images: bool) -> dict:
    cat = person["category"]
    photo_key = _upload_image(person.get("photo", ""), "select/profile") \
        if upload_images else ""
    portfolio_keys = []
    if upload_images:
        for fn in (person.get("portfolio") or []):
            k = _upload_image(fn, "select/portfolio")
            if k:
                portfolio_keys.append(k)

    now = datetime.now(timezone.utc)
    doc = {
        "name": person["name"],
        "category": cat,
        "category_label": CATEGORY_LABELS[cat],
        "role": person.get("role") or CATEGORY_LABELS[cat],
        "about": person.get("about", ""),
        "experience_years": int(person.get("experience_years", 0)),
        "consultation_fee": float(person.get("consultation_fee", 0)),
        "services": list(person.get("services") or [])[:12],
        "tags": list(person.get("tags") or [])[:6],
        "phone": str(person.get("phone", "")),
        "email": person.get("email", ""),
        "address": person.get("address", ""),
        "area": person.get("area", ""),
        "city": person.get("city", ""),
        "district": person.get("district", ""),
        "state": person.get("state", ""),
        "pincode": str(person.get("pincode", "")),
        "plan": person.get("plan", "standard"),
        "amount_paid": 0.0,
        "payment_link_id": "",
        "offer_text": person.get("offer_text", ""),
        "offer_percent": int(person.get("offer_percent", 0)),
        "offer_valid_till": person.get("offer_valid_till", ""),
        "rating": float(person.get("rating", 0)),
        "review_count": int(person.get("review_count", 0)),
        "status": "active",
        "is_verified": True,
        # Marks this document as script-managed. --wipe only ever touches
        # documents carrying this flag.
        "seeded": True,
        "updated_at": now,
    }

    lat, lng = person.get("lat"), person.get("lng")
    if lat is not None and lng is not None:
        # GeoJSON point so the "Nearby" sort ($geoNear) works for seeded people
        # exactly as it does for self-registered ones.
        doc["geo"] = {"type": "Point", "coordinates": [float(lng), float(lat)]}
        doc["lat"] = float(lat)
        doc["lng"] = float(lng)

    # Only overwrite images when we actually uploaded new ones, so re-running
    # without the image files present doesn't blank out existing photos.
    if photo_key:
        doc["photo_s3_key"] = photo_key
    if portfolio_keys:
        doc["portfolio_s3_keys"] = portfolio_keys

    return doc


# ─────────────────────────────────────────────────────────────────────────────
# Commands
# ─────────────────────────────────────────────────────────────────────────────

async def cmd_list(db):
    docs = await db.select_professionals.find({"seeded": True}).to_list(length=500)
    total = await db.select_professionals.count_documents({})
    print(f"\n📋 Seeded professionals ({len(docs)} of {total} total in Select):\n")
    if not docs:
        print("   (none yet — run:  python seed_select.py)")
    for d in docs:
        print(f"   • {d.get('name','?'):<22} {d.get('category_label',''):<20} "
              f"{d.get('plan',''):<9} ₹{int(d.get('consultation_fee',0))}"
              f"   [{d.get('user_id','')}]")
    print()


async def cmd_wipe(db):
    seeded = await db.select_professionals.count_documents({"seeded": True})
    real   = await db.select_professionals.count_documents({"seeded": {"$ne": True}})
    if seeded == 0:
        print("\n   Nothing to remove — no seeded professionals found.\n")
        return
    print(f"\n⚠️  About to delete {seeded} SEEDED professional(s).")
    print(f"   {real} self-registered professional(s) will NOT be touched.")
    confirm = input("   Type 'yes' to continue: ").strip().lower()
    if confirm != "yes":
        print("   Cancelled.\n")
        return
    res = await db.select_professionals.delete_many({"seeded": True})
    print(f"   ✅ Removed {res.deleted_count} seeded professional(s).\n")


async def cmd_seed(db, dry_run: bool):
    # Validate everything BEFORE writing anything, so a typo can't leave the
    # collection half-populated.
    errors = [e for i, p in enumerate(PEOPLE) if (e := _validate(p, i))]
    if errors:
        print("\n❌ Fix these entries in PEOPLE before running:\n")
        for e in errors:
            print(f"   • {e}")
        print()
        sys.exit(1)

    keys = [p["key"] for p in PEOPLE]
    dupes = {k for k in keys if keys.count(k) > 1}
    if dupes:
        print(f"\n❌ Duplicate key(s) in PEOPLE: {', '.join(dupes)}\n")
        sys.exit(1)

    print(f"\n👤 Seeding {len(PEOPLE)} professional(s) into Claimit Select "
          f"{'(DRY RUN — nothing will be written)' if dry_run else ''}…\n")

    added = updated = 0
    for person in PEOPLE:
        user_id = f"seed:{person['key']}"
        existing = await db.select_professionals.find_one({"user_id": user_id})
        action = "update" if existing else "add"
        print(f"   {'✏️ ' if existing else '➕'} {action}: {person['name']} "
              f"({CATEGORY_LABELS[person['category']]})")

        if dry_run:
            continue

        doc = _build_doc(person, upload_images=True)
        doc["user_id"] = user_id
        if not existing:
            doc.setdefault("created_at", datetime.now(timezone.utc))
            doc.setdefault("photo_s3_key", "")
            doc.setdefault("portfolio_s3_keys", [])
            added += 1
        else:
            updated += 1

        await db.select_professionals.update_one(
            {"user_id": user_id}, {"$set": doc}, upsert=True
        )

    if dry_run:
        print("\n   (dry run — no changes made)\n")
        return

    seeded = await db.select_professionals.count_documents({"seeded": True})
    real   = await db.select_professionals.count_documents({"seeded": {"$ne": True}})
    print("\n" + "═" * 58)
    print(f"  ✅  Added        : {added}")
    print(f"  ✅  Updated      : {updated}")
    print(f"  📋  Seeded total : {seeded}")
    print(f"  👥  Self-registered (untouched) : {real}")
    print("═" * 58)
    print("\n🚀 Done. Open Claimit Select in the app to see them.\n")


async def main():
    args = set(sys.argv[1:])
    client = AsyncIOMotorClient(MONGO_URL)
    db = client[DB_NAME]
    try:
        # Confirm we can actually reach Mongo before doing anything else.
        await db.command("ping")
    except Exception as e:
        print(f"\n❌ Could not connect to MongoDB at {MONGO_URL}\n   {e}\n")
        client.close()
        sys.exit(1)

    print(f"\n🔌 Connected to {DB_NAME}")

    if "--list" in args:
        await cmd_list(db)
    elif "--wipe" in args:
        await cmd_wipe(db)
    else:
        await cmd_seed(db, dry_run="--dry-run" in args)

    client.close()


if __name__ == "__main__":
    asyncio.run(main())
