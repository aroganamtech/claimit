#!/bin/bash
#
# rotate_db_password.sh — change the MongoDB password without downtime drama.
#
# Use this whenever the password may have been seen: pasted into a chat or an
# email, shown on a screen share, or handled by someone who has since left.
# Rotating is cheap. Wondering whether you need to is not.
#
# Unlike secure_mongo.sh this touches nothing structural — mongod.conf, bindIp
# and authorization are left exactly as they are. It only swaps the password in
# MongoDB and in the two .env files that hold it, then restarts the apps.
#
# It never prints the new password. Read it back with:
#   grep MONGODB_URL /home/ubuntu/claimit_local_production/.env
#
#   bash ~/rotate_db_password.sh
#
set -euo pipefail

APP_ENV=/home/ubuntu/claimit_local_production/.env
WEB_ENV=/home/ubuntu/claimit_web_backend_ec2/.env
STAMP=$(date +%Y%m%d_%H%M%S)
ROLLBACK_ARMED=0

say() { printf '\n=== %s ===\n' "$1"; }

rollback() {
    [ "$ROLLBACK_ARMED" -eq 1 ] || exit 1
    printf '\n!!! Failed. Restoring the previous password everywhere.\n'
    # Put the old connection strings back first, then set MongoDB's password
    # back to the old one so the two sides match again.
    cp "$APP_ENV.bak_$STAMP" "$APP_ENV" || true
    cp "$WEB_ENV.bak_$STAMP" "$WEB_ENV" || true
    OLD=$(grep -E '^MONGODB_URL=' "$APP_ENV" | sed -E 's#.*mongodb://[^:]+:([^@]*)@.*#\1#')
    mongosh "$(grep -E '^MONGODB_URL=' "$APP_ENV" | cut -d= -f2- | tr -d "\"'")" \
        --quiet --eval "db.getSiblingDB('admin').changeUserPassword('admin', '$OLD')" >/dev/null 2>&1 || true
    pm2 restart claimit-app-api claimit-backend || true
    printf 'Restored. Your apps should be working on the old password.\n'
    exit 1
}
trap rollback ERR

say "0. Pre-flight"
for f in "$APP_ENV" "$WEB_ENV"; do
    [ -f "$f" ] || { echo "MISSING: $f"; exit 1; }
done

CUR_URI=$(grep -E '^MONGODB_URL=' "$APP_ENV" | cut -d= -f2- | tr -d "\"'")
[ -n "$CUR_URI" ] || { echo "No MONGODB_URL found"; exit 1; }

# Prove the current credentials work before changing anything. If they already
# don't, rotating would just produce a second broken password.
timeout 8 mongosh "$CUR_URI" --quiet --eval 'db.adminCommand({ping:1})' >/dev/null
echo "Current credentials work."

say "1. Backing up both .env files"
cp "$APP_ENV" "$APP_ENV.bak_$STAMP"
cp "$WEB_ENV" "$WEB_ENV.bak_$STAMP"
ROLLBACK_ARMED=1
echo "Saved with suffix .bak_$STAMP"

say "2. Generating a new password"
NEWPW=$(openssl rand -hex 16)
[ ${#NEWPW} -eq 32 ] || { echo "generation failed"; false; }
echo "Generated (32 chars, not displayed)."

say "3. Applying it to MongoDB"
mongosh "$CUR_URI" --quiet --eval "db.getSiblingDB('admin').changeUserPassword('admin', '$NEWPW')"
echo "Applied."

say "4. Updating both .env files"
sed -i -E "s#(mongodb://[^:/@]+:)[^@]*@#\1${NEWPW}@#g" "$APP_ENV"
sed -i -E "s#(mongodb://[^:/@]+:)[^@]*@#\1${NEWPW}@#g" "$WEB_ENV"
chmod 600 "$APP_ENV" "$WEB_ENV"
echo "Updated."

say "5. Verifying the new credentials"
APP_URI=$(grep -E '^MONGODB_URL=' "$APP_ENV" | cut -d= -f2- | tr -d "\"'")
WEB_URI=$(grep -E '^MONGO_URL='   "$WEB_ENV" | cut -d= -f2- | tr -d "\"'")
timeout 8 mongosh "$APP_URI" --quiet --eval 'db.adminCommand({ping:1})'
timeout 8 mongosh "$WEB_URI" --quiet --eval 'db.adminCommand({ping:1})'
echo "Both authenticate."

say "6. Restarting both backends"
trap - ERR
pm2 restart claimit-app-api claimit-backend
sleep 8
pm2 list --no-color
pm2 save

say "7. Final check"
timeout 8 mongosh "$APP_URI" --quiet --eval 'const d=db.getSiblingDB("claimit_db"); print("users = " + d.users.countDocuments({})); print("shops = " + d.shops.countDocuments({}))'

cat <<'EOF'

────────────────────────────────────────────────────────────────
Password rotated. Nothing else changed.

Read it when you need it:
  grep MONGODB_URL /home/ubuntu/claimit_local_production/.env

Put it straight into a password manager. Do not paste it into a
chat, an email, or a screenshot.
────────────────────────────────────────────────────────────────
EOF
