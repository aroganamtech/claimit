"""
S3 access.

The app uploads the photo straight to S3 with a presigned PUT, so the image
never travels through this API. This module only hands out those URLs and
fetches objects back for hashing.

Credentials come from the EC2 instance role. There are no AWS keys in the
environment, in this repository, or in the APK.
"""
import asyncio
import logging
import uuid
from datetime import datetime, timezone

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

from .config import settings

log = logging.getLogger(__name__)

_s3 = None


def client():
    global _s3
    if _s3 is None:
        _s3 = boto3.client(
            "s3", region_name=settings().AWS_REGION,
            config=Config(signature_version="s3v4",
                          retries={"max_attempts": 3, "mode": "standard"}),
        )
    return _s3


def _put_url_sync(key: str, content_type: str, expires: int) -> str:
    return client().generate_presigned_url(
        "put_object",
        Params={"Bucket": settings().S3_BUCKET, "Key": key,
                "ContentType": content_type},
        ExpiresIn=expires,
    )


async def presign_put(user_id: str, content_type: str = "image/jpeg",
                      expires: int = 300) -> tuple[str, str]:
    """
    (upload_url, key).

    The key is server-generated and carries the user id, so one customer
    cannot overwrite another's image by choosing a path. A client-supplied
    key would be a trivial way to tamper with someone else's scan.
    """
    if content_type not in ("image/jpeg", "image/png", "image/webp"):
        raise ValueError("unsupported content type")
    stamp = datetime.now(timezone.utc).strftime("%Y/%m/%d")
    key = f"bill-scans/{stamp}/{user_id}/{uuid.uuid4().hex}.jpg"
    url = await asyncio.to_thread(_put_url_sync, key, content_type, expires)
    return url, key


def _get_url_sync(key: str, expires: int) -> str:
    return client().generate_presigned_url(
        "get_object",
        Params={"Bucket": settings().S3_BUCKET, "Key": key},
        ExpiresIn=expires,
    )


async def presign_get(key: str, expires: int = 300) -> str:
    """Short-lived read URL, handed to Azure so it fetches the image itself."""
    return await asyncio.to_thread(_get_url_sync, key, expires)


def _head_sync(key: str) -> int | None:
    try:
        return client().head_object(Bucket=settings().S3_BUCKET, Key=key)["ContentLength"]
    except ClientError:
        return None


async def object_size(key: str) -> int | None:
    return await asyncio.to_thread(_head_sync, key)


def _get_sync(key: str, limit: int) -> bytes | None:
    try:
        obj = client().get_object(Bucket=settings().S3_BUCKET, Key=key)
        # Read at most `limit`. An oversized object must not be able to
        # exhaust the memory of a 2 GB box.
        return obj["Body"].read(limit + 1)
    except ClientError as exc:
        log.warning("s3 get failed %s: %s", key, exc)
        return None


async def fetch(key: str) -> bytes | None:
    return await asyncio.to_thread(_get_sync, key, settings().MAX_IMAGE_BYTES)


def owns_key(key: str, user_id: str) -> bool:
    """
    The key must sit under this user's prefix.

    Without this, a customer could pass someone else's S3 key and claim
    cashback on a bill they never photographed.
    """
    return key.startswith("bill-scans/") and f"/{user_id}/" in key
