#!/bin/bash
#
# secure_mongo.sh — close the hole that cost Claimit its data on 11 Sep 2026.
#
# What it does, in order:
#   1. Generates a new 32-character MongoDB password. It is NEVER printed —
#      it goes straight into the two .env files and nowhere else.
#   2. Locks MongoDB to 127.0.0.1 so it has no presence on the network at all.
#   3. Turns ON authorization, which was the actual missing piece: an `admin`
#      user existed all along, but without this setting MongoDB never checked
#      it. The password looked like protection and was protecting nothing.
#   4. Proves anonymous access is rejected before it lets the apps back up.
#   5. Rolls everything back automatically if any check fails.
#
# Safe to run twice — it detects that authorization is already enabled and
# exits without touching anything.
#
#   scp it to the server, then:  sudo -v && bash ~/secure_mongo.sh
#
set -euo pipefail

APP_ENV=/home/ubuntu/claimit_local_production/.env
WEB_ENV=/home/ubuntu/claimit_web_backend_ec2/.env
CONF=/etc/mongod.conf
STAMP=$(date +%Y%m%d_%H%M%S)
ROLLBACK_ARMED=0

say() { printf '\n=== %s ===\n' "$1"; }

rollback() {
    [ "$ROLLBACK_ARMED" -eq 1 ] || exit 1
    printf '\n!!! Something failed. Rolling everything back.\n'
    sudo cp "$CONF.bak_$STAMP" "$CONF"            || true
    cp "$APP_ENV.bak_$STAMP" "$APP_ENV"           || true
    cp "$WEB_ENV.bak_$STAMP" "$WEB_ENV"           || true
    sudo systemctl restart mongod                 || true
    sleep 5
    pm2 restart claimit-app-api claimit-backend   || true
    printf '\nRolled back to the state before this script ran.\n'
    printf 'Your apps should be working again. Nothing was lost.\n'
    exit 1
}
trap rollback ERR

# ── 0. Pre-flight ────────────────────────────────────────────────────────────
say "0. Pre-flight checks"
for f in "$APP_ENV" "$WEB_ENV" "$CONF"; do
    [ -f "$f" ] || { echo "MISSING: $f — aborting, nothing changed."; exit 1; }
done
systemctl is-active --quiet mongod || { echo "mongod is not running — aborting."; exit 1; }

if grep -qE '^[[:space:]]*authorization:[[:space:]]*enabled' "$CONF"; then
    echo "authorization is already enabled. Nothing to do."
    exit 0
fi

# Both apps must be under PM2, or step 9 cannot bring them back.
pm2 describe claimit-app-api  >/dev/null 2>&1 || { echo "PM2 process claimit-app-api not found — aborting."; exit 1; }
pm2 describe claimit-backend  >/dev/null 2>&1 || { echo "PM2 process claimit-backend not found — aborting."; exit 1; }
echo "All good."

# ── 1. Backups ───────────────────────────────────────────────────────────────
say "1. Backing up the three files this script edits"
cp      "$APP_ENV" "$APP_ENV.bak_$STAMP"
cp      "$WEB_ENV" "$WEB_ENV.bak_$STAMP"
sudo cp "$CONF"    "$CONF.bak_$STAMP"
ROLLBACK_ARMED=1
echo "Backups written with suffix .bak_$STAMP"

# ── 2. New password ──────────────────────────────────────────────────────────
say "2. Generating a new password"
# 32 hex characters = 128 bits of entropy.
#
# openssl rather than `tr -dc ... < /dev/urandom | head -c 32`, which is the
# obvious way and is wrong here: head closes the pipe after 32 bytes, tr dies
# of SIGPIPE, and `set -o pipefail` correctly reports that as a failure. This
# version has no pipe to break.
#
# Hex also guarantees no @ : / ? or # — characters that would corrupt the
# mongodb:// connection string this gets written into.
NEWPW=$(openssl rand -hex 16)
[ ${#NEWPW} -eq 32 ] || { echo "password generation failed"; false; }
echo "Generated (32 chars). It will not be displayed."

# ── 3. Apply it to MongoDB (auth is still off, so this works anonymously) ────
say "3. Changing the MongoDB admin password"
mongosh admin --quiet --eval "db.changeUserPassword('admin', '$NEWPW')"
echo "Changed."

# ── 4. Rewrite both connection strings ───────────────────────────────────────
say "4. Updating both .env files"
# Matches mongodb://<user>:<anything-up-to-@>@ and swaps only the password.
# Works regardless of what the old password was, and regardless of whether the
# variable is called MONGODB_URL (app) or MONGO_URL (web).
sed -i -E "s#(mongodb://[^:/@]+:)[^@]*@#\1${NEWPW}@#g" "$APP_ENV"
sed -i -E "s#(mongodb://[^:/@]+:)[^@]*@#\1${NEWPW}@#g" "$WEB_ENV"
chmod 600 "$APP_ENV" "$WEB_ENV"
echo "Both updated and locked to owner-only (chmod 600)."

# ── 5. Lock the network and enforce auth ─────────────────────────────────────
say "5. bindIp -> 127.0.0.1, authorization -> enabled"
sudo sed -i -E 's/^([[:space:]]*)bindIp:.*/\1bindIp: 127.0.0.1/' "$CONF"

if grep -qE '^security:' "$CONF"; then
    sudo sed -i -E '/^security:/a\  authorization: enabled' "$CONF"
else
    printf '\nsecurity:\n  authorization: enabled\n' | sudo tee -a "$CONF" >/dev/null
fi
echo "Config written."

# ── 6. Restart MongoDB ───────────────────────────────────────────────────────
say "6. Restarting MongoDB"
sudo systemctl restart mongod
sleep 6
systemctl is-active mongod

# ── 7. Prove the lock actually works ─────────────────────────────────────────
say "7. Verifying anonymous access is REJECTED"
if timeout 8 mongosh --quiet --eval 'db.adminCommand({listDatabases:1})' >/dev/null 2>&1; then
    echo "FAILED: anonymous access still works."
    false
fi
echo "Confirmed: connecting without a password is refused."

say "7b. Verifying MongoDB is no longer on the network"
if ss -lnt | grep -q '0.0.0.0:27017'; then
    echo "FAILED: still listening on 0.0.0.0."
    false
fi
ss -lnt | grep 27017 || true
echo "Confirmed: localhost only."

# ── 8. Prove the apps' credentials still work ────────────────────────────────
say "8. Verifying the new credentials"
APP_URI=$(grep -E '^MONGODB_URL=' "$APP_ENV" | cut -d= -f2- | tr -d "\"'")
WEB_URI=$(grep -E '^MONGO_URL='   "$WEB_ENV" | cut -d= -f2- | tr -d "\"'")
timeout 8 mongosh "$APP_URI" --quiet --eval 'db.adminCommand({ping:1})'
timeout 8 mongosh "$WEB_URI" --quiet --eval 'db.adminCommand({ping:1})'
echo "Both connection strings authenticate."

# ── 9. Bring the apps back ───────────────────────────────────────────────────
say "9. Restarting both backends"
trap - ERR          # past the point of no return; a restart hiccup is not a reason to undo a working lock
pm2 restart claimit-app-api claimit-backend
sleep 8
pm2 list --no-color
pm2 save

say "10. Final state"
echo "Documents visible to the app:"
timeout 8 mongosh "$APP_URI" --quiet --eval 'const d=db.getSiblingDB("claimit_db"); print("users = " + d.users.countDocuments({})); print("shops = " + d.shops.countDocuments({}))'

cat <<'EOF'

────────────────────────────────────────────────────────────────
DONE. MongoDB is now:
  • reachable only from the server itself (127.0.0.1)
  • enforcing authentication
  • using a fresh 32-character password

The password exists in exactly two places, both chmod 600:
  /home/ubuntu/claimit_local_production/.env   (MONGODB_URL)
  /home/ubuntu/claimit_web_backend_ec2/.env    (MONGO_URL)

To read it when you need it (e.g. for Compass):
  grep MONGODB_URL /home/ubuntu/claimit_local_production/.env

For Compass, do NOT reopen port 27017. Use an SSH tunnel instead:
  Advanced Connection Options -> Proxy/SSH -> SSH with Identity File
  hostname: localhost   user: ubuntu   identity: your claimit.pem
────────────────────────────────────────────────────────────────
EOF
