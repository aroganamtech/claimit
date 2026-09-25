#!/bin/bash
#
# set_aws_keys.sh — install a new AWS access key across every backend .env.
#
# The old key AKIA53CJHAB2KKEHKTJ6 was deleted, which broke S3 for every
# backend at once: presigned GETs and PUTs both returned 403 with
# InvalidAccessKeyId. This puts a replacement in place everywhere and proves
# it works before restarting anything.
#
# The secret is typed at a prompt, never passed as an argument. Arguments end
# up in shell history and in `ps` output; prompts do not.
#
#   bash ~/set_aws_keys.sh
#
set -euo pipefail

STAMP=$(date +%Y%m%d_%H%M%S)

# Every .env that might hold AWS credentials. Missing ones are skipped quietly.
ENVS=(
    /home/ubuntu/claimit_web_local_backend/.env
    /home/ubuntu/claimit_local_production/.env
    /home/ubuntu/claimit_web_backend_ec2/.env
)

say() { printf '\n=== %s ===\n' "$1"; }

say "1. New credentials"
read -rp  "AWS_ACCESS_KEY_ID     : " NEW_ID
read -rsp "AWS_SECRET_ACCESS_KEY : " NEW_SECRET
echo

[ -n "$NEW_ID" ]     || { echo "no key id given"; exit 1; }
[ -n "$NEW_SECRET" ] || { echo "no secret given"; exit 1; }

case "$NEW_ID" in
    AKIA*) ;;
    *) echo "that does not look like an access key id (should start with AKIA)"; exit 1 ;;
esac

if [ ${#NEW_SECRET} -ne 40 ]; then
    echo "WARNING: secret is ${#NEW_SECRET} characters; AWS secrets are 40."
    read -rp "Continue anyway? [y/N] " yn
    [ "$yn" = "y" ] || exit 1
fi

say "2. Testing the key BEFORE changing any file"
# Verify first. Writing a bad key into three files and restarting three
# services is a much worse afternoon than finding out here.
REGION=$(grep -hE '^AWS_REGION=' "${ENVS[0]}" 2>/dev/null | cut -d= -f2- | tr -d "\"'" || true)
REGION=${REGION:-eu-north-1}
BUCKET=$(grep -hE '^AWS_STORAGE_BUCKET_NAME=' "${ENVS[0]}" 2>/dev/null | cut -d= -f2- | tr -d "\"'" || true)
BUCKET=${BUCKET:-claimit-image-bucket}

AWS_ACCESS_KEY_ID="$NEW_ID" \
AWS_SECRET_ACCESS_KEY="$NEW_SECRET" \
AWS_DEFAULT_REGION="$REGION" \
/home/ubuntu/claimit_web_local_backend/venv/bin/python - "$BUCKET" <<'PY'
import os, sys, uuid
import boto3
from botocore.exceptions import ClientError

bucket = sys.argv[1]
s3 = boto3.client("s3")
try:
    boto3.client("sts").get_caller_identity()
    print("  identity        OK")
    s3.list_objects_v2(Bucket=bucket, MaxKeys=1)
    print("  list objects    OK")
    k = f"_s3check/{uuid.uuid4().hex}.txt"
    s3.put_object(Bucket=bucket, Key=k, Body=b"ok", ContentType="text/plain")
    print("  write           OK")
    s3.delete_object(Bucket=bucket, Key=k)
    print("  delete          OK")
except ClientError as e:
    err = e.response.get("Error", {})
    print(f"  FAILED  {err.get('Code')}: {err.get('Message')}")
    sys.exit(1)
except Exception as e:
    print(f"  FAILED  {type(e).__name__}: {e}")
    sys.exit(1)
PY

echo "  key works."

say "3. Writing it into every .env"
for f in "${ENVS[@]}"; do
    [ -f "$f" ] || { echo "  skip (missing): $f"; continue; }
    if ! grep -q '^AWS_ACCESS_KEY_ID=' "$f"; then
        echo "  skip (no AWS keys in it): $f"
        continue
    fi
    cp "$f" "$f.bak_$STAMP"
    # The '#' delimiter matters: AWS secrets routinely contain '/' and '+'.
    sed -i -E "s#^AWS_ACCESS_KEY_ID=.*#AWS_ACCESS_KEY_ID=${NEW_ID}#"          "$f"
    sed -i -E "s#^AWS_SECRET_ACCESS_KEY=.*#AWS_SECRET_ACCESS_KEY=${NEW_SECRET}#" "$f"
    chmod 600 "$f"
    echo "  updated: $f  (backup .bak_$STAMP)"
done

say "4. Restarting the backends"
pm2 restart claimit-web-api claimit-app-api claimit-backend 2>/dev/null || true
sleep 8
pm2 list --no-color
pm2 save

say "5. Confirming S3 works through the backend's own config"
cd /home/ubuntu/claimit_web_local_backend
venv/bin/python /home/ubuntu/s3_check.py 2>/dev/null | head -20 || true

cat <<'EOF'

────────────────────────────────────────────────────────────────
Done. Hard-reload the admin page — thumbnails and uploads should work.

Important, so this does not happen again:

  The old key was deleted while it was in active use. Your .env files are
  committed to git, and AWS automatically deletes access keys it finds in
  public repositories. A new key in the same repo will meet the same end.

  Two things worth doing this week:
    1. git rm --cached every .env, add them to .gitignore, purge history
    2. Replace this IAM USER with an IAM ROLE on the EC2 instance. A role
       issues short-lived credentials automatically — there is no key to
       leak, and nothing to rotate.
────────────────────────────────────────────────────────────────
EOF
