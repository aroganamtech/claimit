"""
dbcheck.py — read-only. Answers one question: where did the data go?

Run this when the app suddenly shows "account not found" and empty lists while
/health still returns healthy. That combination means the API is talking to a
database, just not the one with the data in it — so the useful thing to print
is every database on the box next to the one the API is actually configured to
use.

Deliberately read-only. Nothing here writes, drops, or creates anything.
Safe to run on production while users are on it.

    cd ~/claimit && venv/bin/python -u deploy/dbcheck.py
"""
import sys

try:
    from app.config import get_settings
    from pymongo import MongoClient
except Exception as exc:                        # noqa: BLE001
    print(f"FAILED to import app config: {exc}")
    print("Are you running this from the backend folder with its own venv?")
    sys.exit(1)

# The collections whose emptiness the user would actually notice.
WATCH = ["users", "shops", "ads", "bill_history", "reviews", "notifications"]


def main() -> int:
    settings = get_settings()

    # Never print the URI itself — it carries the Mongo password. Print only
    # the shape of it, which is what matters when diagnosing a wrong target.
    uri = str(settings.mongodb_url or "")
    host = uri.split("@")[-1].split("/")[0] if uri else "(empty)"
    print(f"Mongo host the API dials : {host}")
    print(f"Database the API uses    : {settings.database_name}")
    print()

    try:
        client = MongoClient(settings.mongodb_url, serverSelectionTimeoutMS=5000)
        client.admin.command("ping")
    except Exception as exc:                    # noqa: BLE001
        print(f"CANNOT REACH MONGO: {exc}")
        return 1

    # Every database with its size. If the API's database is 0 MB but another
    # one is fat, the data never went anywhere — the API is just pointed wrong,
    # which is a .env fix rather than a restore.
    print("=== ALL DATABASES ON THIS SERVER ===")
    try:
        dbs = client.admin.command({"listDatabases": 1}).get("databases", [])
    except Exception as exc:                    # noqa: BLE001
        print(f"  could not list databases: {exc}")
        dbs = []

    for entry in sorted(dbs, key=lambda d: -d.get("sizeOnDisk", 0)):
        name = entry.get("name", "?")
        size_mb = entry.get("sizeOnDisk", 0) / 1048576
        marker = "   <-- the API uses this one" if name == settings.database_name else ""
        print(f"  {name:<28} {size_mb:>9.1f} MB{marker}")

    if settings.database_name not in [d.get("name") for d in dbs]:
        print()
        print(f"  !! '{settings.database_name}' does not exist on this server.")
        print("     The API is pointed at a database that was never created,")
        print("     which is why every lookup returns nothing.")
    print()

    # Counts in the database the API actually uses.
    print(f"=== COLLECTIONS IN '{settings.database_name}' ===")
    db = client[settings.database_name]
    try:
        names = sorted(db.list_collection_names())
    except Exception as exc:                    # noqa: BLE001
        print(f"  could not list collections: {exc}")
        return 1

    if not names:
        print("  (none — this database is completely empty)")
    for name in names:
        try:
            count = db[name].count_documents({})
        except Exception as exc:                # noqa: BLE001
            count = f"error: {exc}"
        flag = "  <-- EMPTY" if count == 0 and name in WATCH else ""
        print(f"  {name:<28} {count}{flag}")
    print()

    # If the API's database is empty, look for the data in the others so the
    # next step is obvious rather than a guess.
    if all(db[n].count_documents({}) == 0 for n in names if n in WATCH) or not names:
        print("=== LOOKING FOR 'users' AND 'shops' IN OTHER DATABASES ===")
        found_any = False
        for entry in dbs:
            other = entry.get("name", "")
            if other in ("admin", "config", "local", settings.database_name):
                continue
            try:
                odb = client[other]
                ocols = set(odb.list_collection_names())
                hits = []
                for wanted in ("users", "shops"):
                    if wanted in ocols:
                        n = odb[wanted].count_documents({})
                        if n:
                            hits.append(f"{wanted}={n}")
                if hits:
                    found_any = True
                    print(f"  {other}: {', '.join(hits)}")
            except Exception:                   # noqa: BLE001, S110
                continue
        if not found_any:
            print("  Nothing found. The data is not in another database on this box.")
            print("  Next step is a restore from backup, not a config change.")
        else:
            print()
            print("  The data IS here, under a different database name.")
            print("  Fix DATABASE_NAME in ~/claimit/.env to match, then restart.")
            print("  Do NOT seed or reset anything.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
