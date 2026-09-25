"""
geo_check.py — is bulk-uploaded data actually findable by the 5 km search?

Why this exists
---------------
MongoDB's $geoNear only ever returns documents that HAVE a usable geo field.
A row with no `geo` is not "far away" — it does not exist as far as the search
is concerned. No error, no warning, no log line. The admin panel shows the
record, the database contains it, and the app never displays it to anyone.

That is the single most common way a bulk upload appears to work and doesn't.
This checks for it, plus the three other ways geo data goes wrong:

  * no 2dsphere index          -> $geoNear fails outright
  * swapped coordinates        -> GeoJSON is [lng, lat]; [lat, lng] puts a
                                  Chennai shop off the coast of Somalia
  * zero / null coordinates    -> everything clusters at [0,0] in the Atlantic

Read-only. Runs no writes of any kind.

    cd /home/ubuntu/claimit_local_production
    venv/bin/python /home/ubuntu/geo_check.py
    venv/bin/python /home/ubuntu/geo_check.py 600040 600101 600102
"""
import sys

sys.path.insert(0, "/home/ubuntu/claimit_local_production")

try:
    from app.config import get_settings
    from pymongo import MongoClient
except Exception as exc:                                  # noqa: BLE001
    print(f"import failed: {exc}")
    print("Run this with the backend's own venv, from its folder.")
    sys.exit(1)

# The collections the app searches by distance.
COLLECTIONS = [
    ("shops", "Reward / Redeem zone shops"),
    ("select_professionals", "Claimit Select"),
    ("privilege_partners", "Claimit Privilege"),
    ("classifieds", "Local Finds / Classifieds"),
    ("deals", "Deals"),
    ("reels", "Reelz"),
]

# India's rough bounding box, used only to spot swapped coordinates.
LAT_MIN, LAT_MAX = 6.0, 37.5
LNG_MIN, LNG_MAX = 68.0, 97.5


def main() -> int:
    wanted_pincodes = [a.strip() for a in sys.argv[1:] if a.strip()]

    settings = get_settings()
    client = MongoClient(settings.mongodb_url, serverSelectionTimeoutMS=5000)
    db = client[settings.database_name]
    print(f"database: {settings.database_name}")
    if wanted_pincodes:
        print(f"focus pincodes: {', '.join(wanted_pincodes)}")
    print()

    existing = set(db.list_collection_names())

    for name, label in COLLECTIONS:
        if name not in existing:
            continue

        col = db[name]
        total = col.count_documents({})
        if total == 0:
            print(f"── {label}  ({name})\n   empty\n")
            continue

        # "Usable" means what $geoNear actually requires: a GeoJSON Point with
        # two numeric coordinates. Anything else is invisible to the search.
        usable = col.count_documents({
            "geo.type": "Point",
            "geo.coordinates.0": {"$type": "number"},
            "geo.coordinates.1": {"$type": "number"},
        })
        missing = total - usable

        print(f"── {label}  ({name})")
        print(f"   total records      : {total}")
        print(f"   findable by 5 km   : {usable}")
        if missing:
            pct = missing * 100.0 / total
            print(f"   INVISIBLE to search: {missing}  ({pct:.0f}%)  <-- will never appear in the app")
        else:
            print("   INVISIBLE to search: 0")

        # Which pincodes the invisible ones belong to — usually one bulk file.
        if missing:
            try:
                rows = list(col.aggregate([
                    {"$match": {"geo.type": {"$ne": "Point"}}},
                    {"$group": {"_id": "$pincode", "n": {"$sum": 1}}},
                    {"$sort": {"n": -1}},
                    {"$limit": 8},
                ]))
                if rows:
                    print("   missing geo, by pincode:")
                    for r in rows:
                        pin = r["_id"] or "(no pincode)"
                        print(f"       {pin:<12} {r['n']}")
            except Exception as exc:                      # noqa: BLE001
                print(f"   (pincode breakdown failed: {exc})")

        # Coordinates the wrong way round. GeoJSON is [lng, lat]; a lot of
        # import scripts write [lat, lng] and the record lands in the ocean.
        try:
            swapped = col.count_documents({
                "geo.coordinates.0": {"$gte": LAT_MIN, "$lte": LAT_MAX},
                "geo.coordinates.1": {"$gte": LNG_MIN, "$lte": LNG_MAX},
            })
            if swapped:
                print(f"   SWAPPED lat/lng    : {swapped}  <-- stored as [lat,lng], must be [lng,lat]")
        except Exception:                                 # noqa: BLE001, S110
            pass

        # Null island — coordinates that defaulted to zero.
        zeroed = col.count_documents({
            "geo.coordinates.0": 0, "geo.coordinates.1": 0,
        })
        if zeroed:
            print(f"   at [0,0]           : {zeroed}  <-- no real location")

        # Without a 2dsphere index $geoNear does not degrade, it errors.
        try:
            idx = col.index_information()
            has_2d = any("2dsphere" in str(v.get("key", "")) for v in idx.values())
            print(f"   2dsphere index     : {'yes' if has_2d else 'NO  <-- $geoNear will fail'}")
        except Exception as exc:                          # noqa: BLE001
            print(f"   index check failed : {exc}")

        # Counts for the pincodes passed on the command line.
        for pin in wanted_pincodes:
            t = col.count_documents({"pincode": pin})
            if t:
                u = col.count_documents({
                    "pincode": pin,
                    "geo.type": "Point",
                    "geo.coordinates.0": {"$type": "number"},
                })
                flag = "" if u == t else f"   <-- {t - u} invisible"
                print(f"   pincode {pin:<10}: {t} records, {u} findable{flag}")

        # The real test: run the query the app runs and see what comes back.
        sample = col.find_one(
            {"geo.type": "Point", "geo.coordinates.0": {"$type": "number"}},
            {"geo": 1, "pincode": 1, "name": 1},
        )
        if sample:
            lng, lat = sample["geo"]["coordinates"][:2]
            try:
                near = list(col.aggregate([
                    {"$geoNear": {
                        "near": {"type": "Point", "coordinates": [lng, lat]},
                        "distanceField": "d",
                        "maxDistance": 5000,          # 5 km, in metres
                        "spherical": True,
                    }},
                    {"$count": "n"},
                ]))
                n = near[0]["n"] if near else 0
                around = sample.get("pincode") or f"{lat:.4f},{lng:.4f}"
                print(f"   live 5 km test     : {n} found around {around}")
            except Exception as exc:                      # noqa: BLE001
                print(f"   live 5 km test FAILED: {exc}")
        print()

    print("""
────────────────────────────────────────────────────────────────
Reading this:

  findable = total            the 5 km search sees everything. Good.
  INVISIBLE > 0               those rows exist in the database and in the
                              admin panel, but no user will ever see them.
                              They need geocoding from their pincode.
  SWAPPED lat/lng > 0         coordinates written [lat,lng] instead of
                              [lng,lat]. Those records are in the sea.
  2dsphere index: NO          $geoNear errors; the whole feature is down.
  live 5 km test: 0 or 1      geo exists but the records are scattered, or
                              only the sample itself matched.
────────────────────────────────────────────────────────────────""")
    return 0


if __name__ == "__main__":
    sys.exit(main())
