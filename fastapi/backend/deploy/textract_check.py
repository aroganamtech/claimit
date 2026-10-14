"""
Pre-flight check for the Textract bill-scan work.

Answers, in order:
  1. Which AWS identity do the backend's credentials resolve to?
  2. Can it reach the Mumbai bill bucket?
  3. Does Textract answer in ap-south-1, and is the identity allowed to call it?

Uses boto3 (already installed for S3) rather than the AWS CLI, which is not
on this server. Writes nothing anywhere. Prints no secrets — only the key ID
prefix, never the secret.

    cd /home/ubuntu/claimit_local_production
    venv/bin/python -u textract_check.py
"""

import base64
import os

from dotenv import load_dotenv

load_dotenv()

REGION = "ap-south-1"          # Mumbai — where Textract and the bill bucket live
BUCKET = "claimit-bill-scans"

# A 1x1 PNG. Too small for a real receipt, which is the point: Textract will
# reject it on CONTENT, and that rejection proves credentials + region +
# permission all work. An AccessDenied would mean the policy is missing.
TINY_PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)


def main():
    try:
        import boto3
        from botocore.exceptions import ClientError, NoCredentialsError
    except ImportError:
        print("boto3 not installed in this venv — stop, tell Claude.")
        return

    kid = os.getenv("AWS_ACCESS_KEY_ID", "")
    print(f"AWS_ACCESS_KEY_ID in .env : {'yes, ' + kid[:8] + '…' if kid else 'NO'}")
    print(f"AWS_REGION in .env        : {os.getenv('AWS_REGION') or '(unset)'}")

    # ── 1. Who am I? ─────────────────────────────────────────────────────────
    print("\n[1] Identity")
    try:
        ident = boto3.client("sts", region_name=REGION).get_caller_identity()
        print(f"    account : {ident['Account']}")
        print(f"    arn     : {ident['Arn']}")
    except NoCredentialsError:
        print("    FAIL: no credentials found at all.")
        return
    except ClientError as e:
        print(f"    FAIL: {e.response['Error']['Code']} — {e.response['Error']['Message']}")
        return

    # ── 2. The Mumbai bucket ────────────────────────────────────────────────
    print(f"\n[2] S3 bucket {BUCKET} (region {REGION})")
    try:
        s3 = boto3.client("s3", region_name=REGION)
        s3.head_bucket(Bucket=BUCKET)
        n = s3.list_objects_v2(Bucket=BUCKET, MaxKeys=1).get("KeyCount", 0)
        print(f"    OK — reachable, {n} object(s) seen")
    except ClientError as e:
        code = e.response["Error"]["Code"]
        print(f"    FAIL: {code} — {e.response['Error']['Message']}")
        if code in ("404", "NoSuchBucket"):
            print("    >> bucket name wrong, or created in another region")
        elif code in ("403", "AccessDenied"):
            print("    >> credentials cannot see this bucket")

    # ── 3. Textract in Mumbai ───────────────────────────────────────────────
    print(f"\n[3] Textract AnalyzeExpense in {REGION}")
    try:
        tx = boto3.client("textract", region_name=REGION)
        tx.analyze_expense(Document={"Bytes": TINY_PNG})
        print("    OK — call succeeded (unexpected for a 1x1 image, but fine)")
    except ClientError as e:
        code = e.response["Error"]["Code"]
        msg = e.response["Error"]["Message"]
        if code in ("AccessDeniedException", "AccessDenied",
                    "UnrecognizedClientException"):
            print(f"    FAIL: {code}")
            print("    >> PERMISSION missing. Attach AmazonTextractFullAccess")
            print("       to the IAM user shown in [1], then re-run this.")
        elif code in ("InvalidParameterException", "UnsupportedDocumentException",
                      "BadDocumentException", "DocumentTooLargeException",
                      "ValidationException"):
            print(f"    OK — Textract answered and rejected the 1x1 test image")
            print(f"       ({code}). Credentials, region and permission all work.")
        else:
            print(f"    UNEXPECTED: {code} — {msg}")
    except Exception as e:  # noqa: BLE001
        name = type(e).__name__
        print(f"    FAIL: {name} — {e}")
        if "EndpointConnectionError" in name:
            print("    >> Textract not reachable in this region.")

    print()


main()
