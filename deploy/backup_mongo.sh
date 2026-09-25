#!/bin/bash
#
# backup_mongo.sh — every-3-days database backup for Claimit.
#
# Why mongodump and not the tar-of-the-data-directory that saved us this time:
# the raw directory was 251 MB. A mongodump of the same database is a couple of
# megabytes, because it stores documents rather than storage-engine internals.
# That is the difference between a backup you can keep 30 copies of for pennies
# and one you keep a single copy of and hope.
#
# Cost: ~2 MB per run, 10 kept locally on a disk you already pay for, and
# optionally the same 2 MB in S3. At S3's price that is a fraction of a rupee
# per month. Nothing here creates a new AWS resource or changes your bill in a
# way you would notice.
#
# Reads the connection string from the app's .env, so it keeps working after
# the password is rotated. Prints no secrets.
#
#   bash ~/backup_mongo.sh            normal run
#   bash ~/backup_mongo.sh --verify   also test-restore into a scratch DB
#
set -euo pipefail

APP_ENV=/home/ubuntu/claimit_local_production/.env
BACKUP_DIR=/home/ubuntu/backups
KEEP=10
STAMP=$(date +%Y%m%d_%H%M)

[ -f "$APP_ENV" ] || { echo "MISSING $APP_ENV"; exit 1; }

RAW_URI=$(grep -E '^MONGODB_URL=' "$APP_ENV" | cut -d= -f2- | tr -d "\"'")
[ -n "$RAW_URI" ] || { echo "No MONGODB_URL in $APP_ENV"; exit 1; }

# Strip any /database path so mongodump takes EVERY database, not just one.
# claimit_db and claimit_web both matter; a backup of only one of them is the
# kind of thing you discover at the worst possible moment.
#
# The trailing / is kept deliberately. mongodb://host:27017?opts is invalid —
# the driver demands mongodb://host:27017/?opts — and dropping that one
# character is exactly what made the first run fail.
BASE_URI=$(printf '%s' "$RAW_URI" | sed -E 's#(mongodb://[^/]+)/[^?]*#\1/#')

mkdir -p "$BACKUP_DIR"
WORK="$BACKUP_DIR/mongo_$STAMP"
ARCHIVE="$WORK.tar.gz"

echo "[$(date '+%F %T')] starting backup"

mongodump --uri="$BASE_URI" --out="$WORK" --quiet
tar -czf "$ARCHIVE" -C "$BACKUP_DIR" "mongo_$STAMP"
rm -rf "$WORK"

SIZE=$(du -h "$ARCHIVE" | cut -f1)
echo "[$(date '+%F %T')] wrote $ARCHIVE ($SIZE)"

# Refuse to call a suspiciously tiny dump a success. An empty or near-empty
# archive usually means the credentials stopped working, and a cron job that
# quietly writes nothing every three days is worse than no cron job at all.
BYTES=$(stat -c%s "$ARCHIVE")
if [ "$BYTES" -lt 20000 ]; then
    echo "WARNING: archive is only $BYTES bytes. That is too small to be a real backup."
    echo "Check that MONGODB_URL in $APP_ENV still authenticates."
    exit 1
fi

# ── Rotate: keep the newest $KEEP, delete the rest ───────────────────────────
DELETED=$(ls -1t "$BACKUP_DIR"/mongo_*.tar.gz 2>/dev/null | tail -n +$((KEEP + 1)) || true)
if [ -n "$DELETED" ]; then
    echo "$DELETED" | xargs -r rm -f
    echo "rotated out $(echo "$DELETED" | wc -l) old archive(s); keeping newest $KEEP"
fi

# ── Optional off-box copy to S3 ──────────────────────────────────────────────
# A backup that lives only on the machine it is backing up is not a backup.
# If the bucket name is in .env and the AWS CLI is present, ship it. If not,
# the local copy still succeeded — this must never fail the whole run.
BUCKET=$(grep -E '^S3_BUCKET_NAME=' "$APP_ENV" 2>/dev/null | cut -d= -f2- | tr -d "\"'" || true)
if [ -n "${BUCKET:-}" ] && command -v aws >/dev/null 2>&1; then
    if aws s3 cp "$ARCHIVE" "s3://$BUCKET/db-backups/" --only-show-errors; then
        echo "uploaded to s3://$BUCKET/db-backups/"
    else
        echo "WARNING: S3 upload failed. Local copy is fine."
    fi
else
    echo "S3 skipped (no S3_BUCKET_NAME in .env, or aws CLI not installed)"
fi

# ── Optional: prove the archive actually restores ────────────────────────────
# A backup nobody has ever restored is a guess. This drops the dump into a
# throwaway database, counts the documents, and removes it again.
if [ "${1:-}" = "--verify" ]; then
    echo
    echo "[verify] test-restoring into scratch database claimit_db_verify"
    TMP=$(mktemp -d)
    tar -xzf "$ARCHIVE" -C "$TMP"
    SRC=$(find "$TMP" -type d -name claimit_db | head -1)
    if [ -z "$SRC" ]; then
        echo "[verify] FAILED: no claimit_db folder inside the archive"
        rm -rf "$TMP"; exit 1
    fi
    mongorestore --uri="$BASE_URI" --db claimit_db_verify --drop "$SRC" --quiet
    mongosh "$BASE_URI" --quiet --eval 'const d=db.getSiblingDB("claimit_db_verify"); print("[verify] users = " + d.users.countDocuments({})); print("[verify] shops = " + d.shops.countDocuments({}))'
    mongosh "$BASE_URI" --quiet --eval 'db.getSiblingDB("claimit_db_verify").dropDatabase()' >/dev/null
    rm -rf "$TMP"
    echo "[verify] scratch database removed. The archive restores correctly."
fi

echo "[$(date '+%F %T')] backup complete"
ls -lh "$BACKUP_DIR"/mongo_*.tar.gz | tail -5
