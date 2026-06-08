import os
import uuid
import asyncio
import mimetypes
from functools import partial
from typing import Optional
from urllib.parse import urlparse

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError, BotoCoreError

_URL_EXPIRY = 3600


def _s3_client():
    """Virtual-hosted style + SigV4 — generates correct regional presigned URLs.
    e.g. https://claimit-image-bucket.s3.eu-north-1.amazonaws.com/shops/abc.jpg?...
    """
    region = os.getenv("AWS_REGION", "eu-north-1")
    return boto3.client(
        "s3",
        region_name=region,
        aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID", ""),
        aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY", ""),
        config=Config(
            signature_version="s3v4",
            s3={"addressing_style": "virtual"},
        ),
    )


def _bucket():
    return os.getenv("AWS_STORAGE_BUCKET_NAME", "claimit-image-bucket")


def _normalize_key(s3_key: str) -> str:
    if s3_key.startswith("https://") or s3_key.startswith("http://"):
        path = urlparse(s3_key).path.lstrip("/")
        # path-style URLs: /bucket/key — strip bucket prefix
        bucket = _bucket()
        if path.startswith(bucket + "/"):
            path = path[len(bucket) + 1:]
        return path
    return s3_key


def _sync_upload(data: bytes, key: str, content_type: str) -> str:
    _s3_client().put_object(Bucket=_bucket(), Key=key, Body=data, ContentType=content_type)
    return key


async def upload_bytes(data: bytes, folder: str, filename: Optional[str] = None,
                       content_type: str = "image/jpeg") -> str:
    ext = ""
    if filename:
        _, ext = os.path.splitext(filename)
    if not ext:
        ext = mimetypes.guess_extension(content_type) or ".bin"
    key = folder + "/" + uuid.uuid4().hex + ext
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, partial(_sync_upload, data, key, content_type))
    return key


async def upload_base64(b64_string: str, folder: str,
                        content_type: str = "image/jpeg") -> str:
    import base64
    if "," in b64_string:
        header, b64_string = b64_string.split(",", 1)
        if "data:" in header and ";" in header:
            content_type = header.split("data:")[1].split(";")[0]
    data = base64.b64decode(b64_string)
    return await upload_bytes(data, folder, content_type=content_type)


def _sync_presign(key: str) -> str:
    return _s3_client().generate_presigned_url(
        "get_object",
        Params={"Bucket": _bucket(), "Key": key},
        ExpiresIn=_URL_EXPIRY,
    )


async def generate_presigned_url(s3_key: str) -> Optional[str]:
    if not s3_key:
        return None
    try:
        key = _normalize_key(s3_key)
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, partial(_sync_presign, key))
    except Exception:
        return None


def generate_presigned_url_sync(s3_key: str) -> Optional[str]:
    if not s3_key:
        return None
    try:
        key = _normalize_key(s3_key)
        return _sync_presign(key)
    except Exception:
        return None
