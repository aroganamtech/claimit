#!/usr/bin/env python3
"""
backfill_geo.py — give every listing a location, so the 5 km search can see it.

The problem this solves
-----------------------
The app's search is a radius query, and a radius query can only return
documents that carry a geo point. Deals and Promo Reelz never had one: the
advertiser form has always captured a PIN code, but nobody converted it into
coordinates. So those features were invisible to the search no matter how good
the search code was.

How it finds coordinates, cheapest first
----------------------------------------
1. lat/lng already on the document      — just build the geo point
2. The parent shop, matched by name     — a deal for "CK Bakers" sits where
                                          CK Bakers sits
3. The PIN code centre, from:
     a. the `pincode_centres` cache     — learned once, reused forever
     b. our own shops in that PIN code  — free, no network, most accurate
     c. OpenStreetMap postal lookup     — one call per UNIQUE PIN code

Point 3c is the important change. Geocoding each record's full address text was
slow and unreliable — many records have no address at all. Geocoding the PIN
code instead means a handful of network calls for hundreds of records, and the
answer is cached in `pincode_centres` so both backends can reuse it and no PIN
code is ever looked up twice.

Safety
------
  • Dry run by default. Nothing is written unless you pass --apply.
  • Only ever ADDS geo/lat/lng. Never edits any other field, never deletes.
  • Skips any document that already has a geo point, so re-running is safe.

Usage
-----
    python3 backfill_geo.py                  # report only, changes nothing
    python3 backfill_geo.py --apply          # write, using local sources only
    python3 backfill_geo.py --apply --geocode    # also look up unknown PIN codes
"""
import argparse
import asyncio
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from motor.motor_asyncio import AsyncIOMotorClient  # noqa: E402

MONGO_URL = os.getenv("MONGODB_URL", "mongodb://localhost:27017")
DB_NAME = os.getenv("DATABASE_NAME", "claimit_db")

# Collections that need a geo point for the radius search to see them.
TARGETS = ["deals", "reels", "shops", "classifieds", "select_professionals"]

# Shared PIN-code → coordinates cache, also written by the web backend when a
# new ad is published (utils/pincode_geo.py). One table, two writers.
CACHE = "pincode_centres"

NO_GEO = {"$or": [{"geo": {"$exists": False}}, {"geo": None}, {"geo": {}}]}


def _clean_pin(value) -> str:
    """A valid 6-digit Indian PIN code, or "". Guards against floats like
    '600040.0' that Excel imports leave behind."""
    pin = "".join(ch for ch in str(value or "") if ch.isdigit())
    return pin if len(pin) == 6 else ""


def _num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def _valid(lat, lng) -> bool:
    return (lat is not None and lng is not None
            and -90 <= lat <= 90 and -180 <= lng <= 180
            and not (lat == 0 and lng == 0))


def _point(lat, lng):
    """GeoJSON is [longitude, latitude] — reversing it silently relocates
    every Indian shop into the Indian Ocean."""
    return {"type": "Point", "coordinates": [float(lng), float(lat)]}


async def load_cache(db) -> dict:
    """The PIN codes we already know, from previous runs and from live ads."""
    table = {}
    try:
        async for d in db[CACHE].find({}):
            lat, lng = _num(d.get("lat")), _num(d.get("lng"))
            if _valid(lat, lng):
                table[str(d.get("_id"))] = (lat, lng)
    except Exception as e:
        print(f"  ! could not read {CACHE}: {e}")
    return table


async def learn_from_shops(db) -> dict:
    """PIN code → centre, averaged from records that carry both a PIN code
    and coordinates. Our own data, so no network and no guessing."""
    sums = defaultdict(lambda: [0.0, 0.0, 0])
    for coll in ("shops", "classifieds", "select_professionals"):
        try:
            cursor = db[coll].find(
                {"geo": {"$ne": None}, "pincode": {"$nin": [None, ""]}},
                {"geo": 1, "pincode": 1},
            )
            async for d in cursor:
                coords = (d.get("geo") or {}).get("coordinates") or []
                if len(coords) != 2:
                    continue
                pin = _clean_pin(d.get("pincode"))
                if not pin:
                    continue
                s = sums[pin]
                s[0] += float(coords[1])   # lat
                s[1] += float(coords[0])   # lng
                s[2] += 1
        except Exception as e:
            print(f"  ! could not read {coll}: {e}")
    return {p: (v[0] / v[2], v[1] / v[2]) for p, v in sums.items() if v[2]}


async def build_shop_table(db) -> dict:
    """lowercase shop name → (lat, lng), so a deal inherits its shop's spot."""
    table = {}
    try:
        cursor = db.shops.find({"geo": {"$ne": None}},
                               {"geo": 1, "name": 1, "shop_name": 1})
        async for d in cursor:
            coords = (d.get("geo") or {}).get("coordinates") or []
            if len(coords) != 2:
                continue
            for key in (d.get("name"), d.get("shop_name")):
                if key and str(key).strip():
                    table[str(key).strip().lower()] = (coords[1], coords[0])
    except Exception as e:
        print(f"  ! could not read shops: {e}")
    return table


async def geocode_pincode(state: dict, pin: str):
    """One OpenStreetMap postal-code lookup, rate-limited to 1/second as their
    usage policy requires. Returns None on any failure."""
    import httpx
    loop = asyncio.get_event_loop()
    wait = 1.0 - (loop.time() - state.get("last", 0.0))
    if wait > 0:
        await asyncio.sleep(wait)
    state["last"] = loop.time()
    try:
        async with httpx.AsyncClient(timeout=10) as c:
            r = await c.get(
                "https://nominatim.openstreetmap.org/search",
                params={"postalcode": pin, "country": "India",
                        "format": "json", "limit": 1},
                headers={"User-Agent": "ClaimitBackfill/1.0"},
            )
            r.raise_for_status()
            js = r.json()
        if isinstance(js, list) and js:
            lat, lng = float(js[0]["lat"]), float(js[0]["lon"])
            if _valid(lat, lng):
                return lat, lng
    except Exception:
        return None
    return None


async def report_timing(db):
    """How many shops have opening hours we can actually read.

    This drives the "Open Now" filter. A shop with no readable timing is never
    shown as open, so this number is exactly how much of the catalogue that
    filter can see.
    """
    try:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from app.utils.opening_hours import parse_timing
    except Exception as e:
        print(f"  ! could not load the timing parser: {e}")
        return

    total = readable = blank = unreadable = 0
    samples = []
    try:
        async for d in db.shops.find({}, {"timing": 1}):
            total += 1
            t = str(d.get("timing") or "").strip()
            if not t:
                blank += 1
            elif parse_timing(t) is None:
                unreadable += 1
                if len(samples) < 8 and t not in samples:
                    samples.append(t)
            else:
                readable += 1
    except Exception as e:
        print(f"  ! could not read shop timings: {e}")
        return

    pct = (readable / total * 100) if total else 0
    print(f"\n  Open Now coverage: {readable}/{total} shops "
          f"({pct:.0f}%) have opening hours we can read")
    if blank:
        print(f"    {blank} have no timing text at all")
    if unreadable:
        print(f"    {unreadable} have timing text we could not parse, e.g.:")
        for s in samples:
            print(f"      - {s[:70]}")


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true",
                    help="actually write. Without this it only reports.")
    ap.add_argument("--geocode", action="store_true",
                    help="look up unknown PIN codes online (1 call per PIN code)")
    ap.add_argument("--limit", type=int, default=100000)
    args = ap.parse_args()

    client = AsyncIOMotorClient(MONGO_URL)
    db = client[DB_NAME]

    print("=" * 66)
    print("  Claimit — geo backfill" + ("" if args.apply else "   (DRY RUN)"))
    print("=" * 66)

    print("\nBefore:")
    before = {}
    for c in TARGETS:
        try:
            total = await db[c].count_documents({})
            missing = await db[c].count_documents(NO_GEO)
            before[c] = (total, missing)
            print(f"  {c:24} {total - missing:>6} located / {total:>6} total"
                  f"   {missing:>6} missing")
        except Exception as e:
            print(f"  {c:24} unreadable: {e}")

    print("\nLearning locations already in the database…")
    pins = await load_cache(db)
    cached_count = len(pins)
    learned = await learn_from_shops(db)
    for p, v in learned.items():
        pins.setdefault(p, v)          # cache wins; it may be hand-corrected
    shops = await build_shop_table(db)
    print(f"  {cached_count} PIN codes from cache, "
          f"{len(learned)} learned from shops, "
          f"{len(shops)} shop names mapped")

    # ── Which PIN codes are still unknown? ───────────────────────────────────
    unknown_pins = set()
    docs_by_coll = {}
    for coll in TARGETS:
        try:
            docs = [d async for d in db[coll].find(NO_GEO).limit(args.limit)]
        except Exception as e:
            print(f"\n{coll}: cannot read ({e})")
            docs = []
        docs_by_coll[coll] = docs
        for d in docs:
            pin = _clean_pin(d.get("pincode"))
            if pin and pin not in pins:
                unknown_pins.add(pin)

    if unknown_pins:
        print(f"\n  {len(unknown_pins)} PIN code(s) not yet known: "
              f"{', '.join(sorted(unknown_pins)[:12])}"
              f"{' …' if len(unknown_pins) > 12 else ''}")
        if args.geocode:
            print(f"  Looking them up online (about "
                  f"{len(unknown_pins)} second(s))…")
            state = {"last": 0.0}
            for pin in sorted(unknown_pins):
                found = await geocode_pincode(state, pin)
                if found:
                    pins[pin] = found
                    print(f"    {pin} -> {found[0]:.4f}, {found[1]:.4f}")
                    if args.apply:
                        try:
                            await db[CACHE].update_one(
                                {"_id": pin},
                                {"$set": {"lat": found[0], "lng": found[1],
                                          "source": "nominatim"}},
                                upsert=True)
                        except Exception:
                            pass
                else:
                    print(f"    {pin} -> not found")
        else:
            print("  Re-run with --geocode to look these up.")

    # Persist what we learned from our own shops, so the web backend can use
    # it instantly when the next ad is published.
    if args.apply:
        for pin, (lat, lng) in learned.items():
            try:
                await db[CACHE].update_one(
                    {"_id": pin},
                    {"$setOnInsert": {"lat": lat, "lng": lng,
                                      "source": "shops"}},
                    upsert=True)
            except Exception:
                pass

    # ── Fill in the missing coordinates ──────────────────────────────────────
    stats = defaultdict(int)
    for coll, docs in docs_by_coll.items():
        if not docs:
            continue
        print(f"\n{coll}: {len(docs)} without coordinates")
        for d in docs:
            lat = _num(d.get("lat") or d.get("latitude"))
            lng = _num(d.get("lng") or d.get("longitude"))
            source = "existing lat/lng"

            if not _valid(lat, lng):
                name = str(d.get("name") or d.get("shop_name")
                           or "").strip().lower()
                if name and name in shops:
                    lat, lng = shops[name]
                    source = "parent shop"

            if not _valid(lat, lng):
                pin = _clean_pin(d.get("pincode"))
                if pin and pin in pins:
                    lat, lng = pins[pin]
                    source = "PIN code centre"

            if not _valid(lat, lng):
                stats[f"{coll}:no source"] += 1
                continue

            stats[f"{coll}:{source}"] += 1
            if args.apply:
                await db[coll].update_one(
                    {"_id": d["_id"]},
                    {"$set": {"geo": _point(lat, lng),
                              "lat": float(lat), "lng": float(lng)}},
                )

    print("\n" + "-" * 66)
    print("  Coordinates found")
    print("-" * 66)
    for k in sorted(stats):
        print(f"  {k:44} {stats[k]:>6}")

    if args.apply:
        print("\nAfter:")
        for c in TARGETS:
            try:
                total = await db[c].count_documents({})
                missing = await db[c].count_documents(NO_GEO)
                was = before.get(c, (0, 0))[1]
                print(f"  {c:24} {total - missing:>6} located / {total:>6}"
                      f"   fixed {was - missing:>5}")
            except Exception:
                pass
    else:
        print("\nNothing was written. Re-run with --apply to save these.")
        print("Add --geocode as well to look up the unknown PIN codes.")

    await report_timing(db)
    print()
    client.close()


if __name__ == "__main__":
    asyncio.run(main())
