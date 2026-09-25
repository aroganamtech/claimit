#!/bin/bash
#
# fix_web_8002.sh — reconnect the REAL admin backend.
#
# The admin panel (claimit-web-aro.web.app -> CloudFront) is served by the
# process on port 8002, running from /home/ubuntu/claimit_web_local_backend.
# Port 8000 is a 5-June copy that nothing uses.
#
# Two things are wrong with 8002's .env:
#   1. MONGO_URL points at the public IP, which is now firewalled.
#   2. It still holds the OLD MongoDB password — secure_mongo.sh only rewrote
#      the two .env files it knew about, and this was not one of them.
#
# Either alone breaks every data request. Login still worked because it checks
# credentials from .env rather than the database, which is why the panel let
# you in and then showed nothing.
#
# It is also an orphan: started by hand on 12 September, not under PM2, so a
# reboot would have lost it silently. This registers it properly.
#
#   bash ~/fix_web_8002.sh
#
set -euo pipefail

WEB=/home/ubuntu/claimit_web_local_backend
APP_ENV=/home/ubuntu/claimit_local_production/.env
STAMP=$(date +%Y%m%d_%H%M%S)

say() { printf '\n=== %s ===\n' "$1"; }

say "0. Pre-flight"
[ -f "$WEB/.env" ]  || { echo "MISSING $WEB/.env"; exit 1; }
[ -f "$APP_ENV" ]   || { echo "MISSING $APP_ENV"; exit 1; }
[ -x "$WEB/venv/bin/python3" ] || { echo "MISSING $WEB/venv/bin/python3"; exit 1; }
echo "OK"

say "1. Backing up .env"
cp "$WEB/.env" "$WEB/.env.bak_$STAMP"
echo "saved $WEB/.env.bak_$STAMP"

say "2. Pointing MONGO_URL at localhost"
sed -i 's/16\.170\.110\.232/127.0.0.1/g' "$WEB/.env"
echo "public IP occurrences left: $(grep -c '16.170.110.232' "$WEB/.env" || true)"

say "3. Copying the current password across"
# Lifted straight out of the app's working connection string, so the two can
# never drift apart again the way they just did.
PW=$(grep -E '^MONGODB_URL=' "$APP_ENV" | sed -E 's#.*mongodb://[^:]+:([^@]*)@.*#\1#')
[ -n "$PW" ] || { echo "could not read the current password"; exit 1; }
sed -i -E "s#(mongodb://[^:/@]+:)[^@]*@#\1${PW}@#g" "$WEB/.env"
chmod 600 "$WEB/.env"
echo "done (not displayed)"

say "4. Verifying the connection string works"
WEB_URI=$(grep -E '^MONGO_URL=' "$WEB/.env" | cut -d= -f2- | tr -d "\"'")
timeout 10 mongosh "$WEB_URI" --quiet --eval 'db.adminCommand({ping:1})'
echo "authenticates."

say "5. Replacing the orphan with a PM2 process"
pm2 delete claimit-web-api >/dev/null 2>&1 || true
sudo fuser -k 8002/tcp >/dev/null 2>&1 || true
sleep 3
if sudo ss -lnt | grep -q ':8002 '; then
    echo "port 8002 is still held — aborting rather than fighting it."
    exit 1
fi
echo "port 8002 free."

# --kill-timeout 8000: uvicorn needs longer to release the port than PM2's
# default allows. Every orphan on this box today came from PM2 starting a
# replacement while the old process still held the socket.
pm2 start "$WEB/venv/bin/python3" \
    --name claimit-web-api \
    --cwd "$WEB" \
    --kill-timeout 8000 \
    -- -m uvicorn main:app --host 0.0.0.0 --port 8002
sleep 8

say "6. Checking it came up"
pm2 list --no-color
echo
echo -n "port 8002: "; sudo ss -lntp | grep ':8002 ' || echo "NOT LISTENING"
echo
for p in /api/admin/stats /api/admin/shops /api/admin/category-images; do
    printf '%-34s ' "$p"
    curl -s -m 20 -o /dev/null -w 'status=%{http_code} time=%{time_total}s\n' "http://127.0.0.1:8002$p"
done

say "7. Saving the PM2 process list"
pm2 save

cat <<'EOF'

────────────────────────────────────────────────────────────────
Expect every endpoint above to answer 401 in well under a second.

  401 fast  = working. The admin panel supplies a token; curl does not.
  500 slow  = still cannot reach MongoDB. Send me the output.
  404       = that route is missing from this backend.

Now hard-reload the admin site (Ctrl+Shift+R) and log in.

Three backends are running on this box:
  8001  claimit-app-api   phone app      claimit_local_production
  8002  claimit-web-api   ADMIN PANEL    claimit_web_local_backend   <- the real one
  8000  claimit-backend   nothing uses it, code frozen at 5 June
────────────────────────────────────────────────────────────────
EOF
