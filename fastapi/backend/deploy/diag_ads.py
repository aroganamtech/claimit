"""
Read-only diagnostic for the Spot Promos + notification-ad features.

Answers three questions in one pass:
  1. Do any Spot Promo ads exist, and do they carry a geo point?
     (No geo => they can never appear in the app's radius search.)
  2. Do users have coordinates yet?
     (A radius notification targets users by their own `geo` point. Only app
      builds from 10 Oct 2026 onward send coordinates, so an older build
      means the server does not know where anyone is and every radius push
      correctly reaches nobody.)
  3. What happened to each queued notification job?

Writes nothing. Safe to run on production at any time.

    cd /home/ubuntu/claimit_local_production
    venv/bin/python -u deploy/diag_ads.py
"""

import asyncio
import os

from dotenv import load_dotenv
from motor.motor_asyncio import AsyncIOMotorClient

load_dotenv()


def line(title):
    print("\n" + title)
    print("-" * len(title))


async def main():
    uri = os.getenv("MONGODB_URL")
    if not uri:
        print("MONGODB_URL missing from .env — run this from the backend folder")
        return
    db = AsyncIOMotorClient(uri)[os.getenv("DATABASE_NAME", "claimit_db")]

    # ── 1. Spot Promos ───────────────────────────────────────────────────────
    line("SPOT PROMOS (the paid cards on Local Finder / Select / Privilege)")
    total = await db.spot_promos.count_documents({})
    with_geo = await db.spot_promos.count_documents({"geo": {"$exists": True}})
    print(f"total           : {total}")
    print(f"with geo point  : {with_geo}")
    if total == 0:
        print(">> None booked yet. The strip showing only organic listings is")
        print("   CORRECT, not a bug. Create one: Admin > Create Ad >")
        print("   Spot Promos Ad, duration 'Start now', a pincode near you.")
    for d in await db.spot_promos.find(
        {}, {"name": 1, "pincode": 1, "status": 1, "end_date": 1, "geo": 1, "tier": 1}
    ).sort("created_at", -1).to_list(10):
        geo = "geo OK" if d.get("geo") else "NO GEO -> invisible to radius search"
        print(f"  - {d.get('name','(no name)')!r:30} pin={d.get('pincode')} "
              f"tier={d.get('tier')} status={d.get('status')} "
              f"ends={d.get('end_date')} {geo}")

    # ── 2. Can users be reached by distance at all? ──────────────────────────
    line("USER COORDINATES (what radius notifications target)")
    users = await db.users.count_documents({})
    users_geo = await db.users.count_documents({"geo": {"$exists": True}})
    tokens = await db.fcm_tokens.count_documents({})
    print(f"users total     : {users}")
    print(f"users WITH geo  : {users_geo}")
    print(f"device tokens   : {tokens}")
    if users_geo == 0:
        print(">> THIS is why a radius push reaches nobody. No user has sent")
        print("   coordinates yet, so $geoNear matches zero people and the job")
        print("   completes 'sent' with an audience of 0. Install the NEW APK,")
        print("   open the app once, then re-check this number.")

    # ── 3. The notification queue ────────────────────────────────────────────
    line("NOTIFICATION JOBS (newest first)")
    jobs = await db.ad_notifications.find({}).sort("created_at", -1).to_list(10)
    print(f"total jobs      : {await db.ad_notifications.count_documents({})}")
    if not jobs:
        print(">> No job was ever queued. The ad was not created, or it was")
        print("   created without the notification option.")
    for j in jobs:
        print(f"  - status={j.get('status')} attempts={j.get('attempts')} "
              f"radius={j.get('radius_km')}km pin={j.get('pincode')}")
        print(f"    send_at={j.get('send_at')}  geo={'yes' if j.get('geo') else 'NO'}")
        print(f"    audience_users={j.get('audience_users')} "
              f"tokens_targeted={j.get('tokens_targeted')} "
              f"delivered={j.get('tokens_delivered')}")
        print(f"    title={str(j.get('title'))[:60]!r}")
        if j.get("error"):
            print(f"    ERROR: {j['error'][:200]}")

    # ── 3b. Can the existing user base be backfilled? ───────────────────────
    # Users only gain `geo` once they run an app build that sends coordinates.
    # Everyone who installed earlier stays unreachable by radius targeting
    # until they update — which could be never. But most profiles already
    # carry a pincode or an area string, and the ad side already turns a
    # pincode into a point. If these counts are healthy, a one-off backfill
    # makes the existing base targetable immediately.
    line("BACKFILL POTENTIAL (existing users without geo)")
    no_geo = {"geo": {"$exists": False}}
    have_pin = await db.users.count_documents(
        {**no_geo, "pincode": {"$exists": True, "$nin": [None, ""]}})
    have_loc = await db.users.count_documents(
        {**no_geo, "location": {"$exists": True, "$nin": [None, ""]}})
    have_latlng = await db.users.count_documents(
        {**no_geo, "lat": {"$exists": True, "$ne": None},
         "lng": {"$exists": True, "$ne": None}})
    print(f"no geo, HAS pincode     : {have_pin}")
    print(f"no geo, HAS location str: {have_loc}")
    print(f"no geo, HAS lat/lng     : {have_latlng}  (instant fix, no lookup)")
    print("sample location strings  :")
    for u in await db.users.find(
        {**no_geo, "location": {"$nin": [None, ""]}},
        {"location": 1, "pincode": 1, "city": 1},
    ).to_list(8):
        print(f"   location={u.get('location')!r} pincode={u.get('pincode')!r} "
              f"city={u.get('city')!r}")
    print("distinct pincodes on users:")
    pins = await db.users.distinct("pincode", {"pincode": {"$nin": [None, ""]}})
    print(f"   {len(pins)} distinct -> {pins[:15]}")

    # ── 4. Indexes the features depend on ────────────────────────────────────
    line("REQUIRED INDEXES")
    for coll in ("users", "spot_promos"):
        idx = await db[coll].index_information()
        has2d = any("2dsphere" in str(v.get("key", "")) for v in idx.values())
        print(f"{coll:12} 2dsphere on geo : {'YES' if has2d else 'MISSING'}")
    idx = await db.ad_notifications.index_information()
    print(f"ad_notifications status+send_at : "
          f"{'YES' if any('status' in str(v.get('key','')) for v in idx.values()) else 'MISSING'}")
    print()


asyncio.run(main())
