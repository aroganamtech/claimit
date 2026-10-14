#!/usr/bin/env bash
# Creates a SCOPED database user for the scan service.
#
# This is the control that matters most given what happened in September. The
# scan service gets readWrite on claimit_scan AND NOTHING ELSE. If it is ever
# compromised, the attacker cannot read users, cannot read the wallet ledger,
# and cannot drop the app database — because this credential has no rights
# there at all.
#
# Run ON THE SERVER:  bash setup_mongo_scan_user.sh
set -euo pipefail

read -rsp "Mongo admin username: " ADMIN_U; echo
read -rsp "Mongo admin password: " ADMIN_P; echo

SCAN_PASS="$(openssl rand -hex 24)"

mongosh --quiet -u "$ADMIN_U" -p "$ADMIN_P" --authenticationDatabase admin <<MONGO
use claimit_scan
db.createUser({
  user: "claimit_scan",
  pwd:  "${SCAN_PASS}",
  roles: [ { role: "readWrite", db: "claimit_scan" } ]
})
MONGO

echo
echo "Created user 'claimit_scan' with readWrite on claimit_scan only."
echo
echo "Put this line in /home/ubuntu/claimit_scan/.env :"
echo
echo "MONGODB_URL=mongodb://claimit_scan:${SCAN_PASS}@127.0.0.1:27017/claimit_scan?authSource=claimit_scan"
echo
echo "Then:  chmod 600 /home/ubuntu/claimit_scan/.env"
echo "This password is shown once. It is not stored anywhere else."
