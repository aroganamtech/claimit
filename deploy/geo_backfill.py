"""
geo_backfill.py — give already-uploaded records the coordinates they need.

Records imported from a sheet with blank lat/lng columns were saved with no
`geo` field. $geoNear does not return such documents — not last, not far away,
not at all. They sit in the database and in the admin panel and no user ever
sees them.

This finds them, geocodes their pincode once per pincode (not once per row),
and writes lat / lng / geo back.

Dry run by default. Nothing is written until you pass --write.

    cd /home/ubuntu/claimit_web_local_backend
    venv/bin/python /home/ubuntu/geo_backfill.py              # report only
    venv/bin/python /home/ubuntu/geo_backfill.py --write      # apply
    venv/bin/python /home/ubuntu/geo_backfill.py --write shops select_professionals
"""
import asyncio
import sys

sys.path.insert(0, "/home/ubuntu/claimit_web_local_backend")

try:
    from database import app_db
    from utils.pincode_geo import resolve_point_for_ad
except Exception as exc:                                   # noqa: BLE001
    print(f"import failed: {exc}")
    print("Run this from /home/ubuntu/claimit_web_local_backend with its venv.")
    sys.exit(1)

DEFAULT_COLLECTIONS = [
    "shops",
    "select_professionals",
    "privilege_partners",
    "classifieds",
    "deals",
    "reels",
]

# What "has no usable position" means to $geoNear.
UNLOCATED = {
    "$or": [
        {"geo": None},
        {"geo": {"$exists": False}},
        {"geo.type": {"$ne": "Point"}},
        {"geo.coordinates.0": {"$not": {"$type": "number"}}},
    ]
}


async def backfill(name: str, write: bool) -> tuple:
    col = app_db[name]

    total = await col.count_documents({})
    if total == 0:
        return 0, 0, 0

    missing = await col.count_documents(UNLOCATED)
    if missing == 0:
        print(f"── {name}: {total} records, all located. Nothing to do.")
        return total, 0, 0

    print(f"── {name}: {total} records, {missing} with no position")

    # Group by pincode first. Several hundred rows usually share three or four
    # pincodes, and geocoding each pincode once turns a few hundred network
    # calls into a few.
    by_pin: dict = {}
    no_pin = 0
    async for doc in col.find(UNLOCATED, {"pincode": 1}):
        pin = "".join(ch for ch in str(doc.get("pincode") or "") if ch.isdigit())
        if len(pin) != 6:
            no_pin += 1
            continue
        by_pin.setdefault(pin, []).append(doc["_id"])

    if no_pin:
        print(f"   {no_pin} have no valid 6-digit pincode — cannot be placed automatically")

    fixed = 0
    unresolved = 0

    for pin, ids in sorted(by_pin.items(), key=lambda kv: -len(kv[1])):
        try:
            lat, lng, geo = await resolve_point_for_ad(app_db, pincode=pin)
        except Exception as exc:                           # noqa: BLE001
            print(f"   {pin}: lookup failed ({exc}) — {len(ids)} rows skipped")
            unresolved += len(ids)
            continue

        if not geo or lat is None or lng is None:
            print(f"   {pin}: could not be geocoded — {len(ids)} rows skipped")
            unresolved += len(ids)
            continue

        if write:
            res = await col.update_many(
                {"_id": {"$in": ids}},
                {"$set": {"lat": lat, "lng": lng, "geo": geo}},
            )
            n = res.modified_count
        else:
            n = len(ids)

        fixed += n
        verb = "updated" if write else "would update"
        print(f"   {pin}: {lat:.5f}, {lng:.5f}  →  {verb} {n} record(s)")

    return total, fixed, unresolved + no_pin


async def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    write = "--write" in sys.argv
    collections = args or DEFAULT_COLLECTIONS

    print("MODE: WRITING CHANGES" if write else "MODE: dry run — nothing will be written")
    print()

    grand_fixed = grand_stuck = 0
    existing = await app_db.list_collection_names()

    for name in collections:
        if name not in existing:
            print(f"── {name}: collection does not exist, skipped")
            continue
        try:
            _, fixed, stuck = await backfill(name, write)
            grand_fixed += fixed
            grand_stuck += stuck
        except Exception as exc:                           # noqa: BLE001
            print(f"── {name}: FAILED — {exc}")
        print()

    print("────────────────────────────────────────────────────────────────")
    if write:
        print(f"Located {grand_fixed} record(s).")
    else:
        print(f"{grand_fixed} record(s) can be located. Re-run with --write to apply.")
    if grand_stuck:
        print(f"{grand_stuck} could NOT be placed — missing or unrecognised pincode.")
        print("Those need a pincode corrected in the admin panel, or lat/lng")
        print("filled in the sheet, before they will appear in the app.")
    print()
    print("Afterwards, confirm with:")
    print("  cd /home/ubuntu/claimit_local_production && \\")
    print("    venv/bin/python /home/ubuntu/geo_check.py")
    print("────────────────────────────────────────────────────────────────")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
