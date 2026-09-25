"""
s3_check.py — find out why S3 is returning 403.

Both presigned GETs and presigned PUTs are failing with 403, signed with the
IAM user's access key. A 403 from S3 always carries a reason code, but the
browser hides it behind a CORS-opaque response. This asks S3 directly, from the
server, using the exact credentials the backend uses — so the error comes back
in full.

Read-only apart from one tiny test object it writes and immediately deletes,
under a key that cannot collide with anything real.

    cd /home/ubuntu/claimit_web_local_backend
    venv/bin/python /home/ubuntu/s3_check.py
"""
import os
import sys
import uuid

ENV_PATH = "/home/ubuntu/claimit_web_local_backend/.env"


def load_env(path: str) -> dict:
    """Minimal .env reader. Deliberately not using python-dotenv so this runs
    even if the venv is missing it."""
    data = {}
    try:
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, _, val = line.partition("=")
                data[key.strip()] = val.strip().strip('"').strip("'")
    except FileNotFoundError:
        print(f"MISSING {path}")
        sys.exit(1)
    return data


def main() -> int:
    env = load_env(ENV_PATH)

    key_id = env.get("AWS_ACCESS_KEY_ID", "")
    secret = env.get("AWS_SECRET_ACCESS_KEY", "")
    region = env.get("AWS_REGION", "eu-north-1")
    bucket = env.get("AWS_STORAGE_BUCKET_NAME", "claimit-image-bucket")

    # The access key ID is an identifier, not a secret — it is already visible
    # in every presigned URL the browser sees. The secret is never printed.
    print(f"access key id : {key_id or '(EMPTY)'}")
    print(f"secret present: {'yes, ' + str(len(secret)) + ' chars' if secret else 'NO — this alone would cause 403'}")
    print(f"region        : {region}")
    print(f"bucket        : {bucket}")
    print()

    if not key_id or not secret:
        print(">>> The backend has no AWS credentials. That is the whole problem.")
        return 1

    try:
        import boto3
        from botocore.exceptions import ClientError
    except ImportError:
        print("boto3 not installed in this venv — run with the backend's venv python")
        return 1

    s3 = boto3.client(
        "s3",
        region_name=region,
        aws_access_key_id=key_id,
        aws_secret_access_key=secret,
    )

    def report(label, fn):
        """Run one S3 call and print the real AWS error code, not a generic 403."""
        try:
            result = fn()
            print(f"  {label:<22} OK")
            return result
        except ClientError as exc:
            err = exc.response.get("Error", {})
            code = err.get("Code", "?")
            msg = err.get("Message", "")
            status = exc.response.get("ResponseMetadata", {}).get("HTTPStatusCode", "?")
            print(f"  {label:<22} FAILED  [{status}] {code}: {msg}")
            return None
        except Exception as exc:                      # noqa: BLE001
            print(f"  {label:<22} FAILED  {type(exc).__name__}: {exc}")
            return None

    print("=== identity ===")
    try:
        sts = boto3.client(
            "sts", region_name=region,
            aws_access_key_id=key_id, aws_secret_access_key=secret,
        )
        who = sts.get_caller_identity()
        print(f"  arn     : {who.get('Arn')}")
        print(f"  account : {who.get('Account')}")
    except Exception as exc:                          # noqa: BLE001
        print(f"  FAILED: {type(exc).__name__}: {exc}")
        print("  >>> If this fails, the key itself is invalid or deactivated.")
    print()

    print("=== bucket operations ===")
    listing = report("list objects", lambda: s3.list_objects_v2(
        Bucket=bucket, Prefix="category-images/", MaxKeys=3))

    if listing and listing.get("Contents"):
        sample = listing["Contents"][0]["Key"]
        print(f"  (sample object: {sample})")
        report("head existing object", lambda: s3.head_object(Bucket=bucket, Key=sample))
        report("get existing object", lambda: s3.get_object(Bucket=bucket, Key=sample))
    else:
        print("  (no objects listed — cannot test reads against a real key)")

    probe_key = f"_s3check/{uuid.uuid4().hex}.txt"
    wrote = report("put test object", lambda: s3.put_object(
        Bucket=bucket, Key=probe_key, Body=b"s3check", ContentType="text/plain"))
    if wrote:
        report("delete test object", lambda: s3.delete_object(Bucket=bucket, Key=probe_key))

    print()
    print("=== bucket settings ===")
    report("get bucket policy", lambda: s3.get_bucket_policy(Bucket=bucket))
    report("get public access block", lambda: s3.get_public_access_block(Bucket=bucket))

    print()
    print("""
────────────────────────────────────────────────────────────────
How to read this:

  InvalidAccessKeyId    the key was deleted or deactivated in IAM
  SignatureDoesNotMatch AWS_SECRET_ACCESS_KEY in .env is wrong or truncated
  AccessDenied          the key is valid but something denies it — a bucket
                        policy Deny, an SCP, or a permissions boundary
  ExpiredToken          temporary credentials that have run out

If every line says OK, the credentials are fine and the problem is in how the
presigned URL is built rather than in AWS itself.
────────────────────────────────────────────────────────────────""")
    return 0


if __name__ == "__main__":
    sys.exit(main())
