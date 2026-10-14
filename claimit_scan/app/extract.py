"""
Receipt services: hashing, Azure Document Intelligence, duplicate detection.

Every CPU-bound call here is pushed to a threadpool. A 2 MP JPEG decode takes
tens of milliseconds; doing that on the event loop stalls every other request
on the worker, and on a small box that is the difference between a responsive
API and a queue.
"""
from __future__ import annotations

import asyncio
import hashlib
import io
import logging
import re
from dataclasses import dataclass, field
from datetime import date, datetime, timezone
from decimal import Decimal, InvalidOperation

import httpx
from PIL import Image, ExifTags

log = logging.getLogger(__name__)


# ═════════════════════════════════════════════════════════════════════════════
# Hashing
# ═════════════════════════════════════════════════════════════════════════════
def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _phash_sync(data: bytes, hash_size: int = 8) -> int | None:
    """
    64-bit DCT perceptual hash, returned as a signed int for BIGINT storage.

    Implemented directly rather than pulled from imagehash so there is no
    numpy/scipy dependency on an API box, and so the exact algorithm is
    pinned — changing library versions silently changes every stored hash.
    """
    try:
        im = Image.open(io.BytesIO(data))
        im = im.convert("L").resize((hash_size * 4, hash_size * 4), Image.LANCZOS)
        px = list(im.getdata())
        n = hash_size * 4

        # 2-D DCT-II, separable. n is 32, so this is cheap enough.
        import math
        cos = [[math.cos((2 * x + 1) * u * math.pi / (2 * n)) for x in range(n)]
               for u in range(n)]
        rows = [[sum(px[y * n + x] * cos[u][x] for x in range(n)) for u in range(n)]
                for y in range(n)]
        dct = [[sum(rows[y][u] * cos[v][y] for y in range(n)) for u in range(n)]
               for v in range(n)]

        # Top-left block minus the DC term carries the structure.
        block = [dct[v][u] for v in range(hash_size) for u in range(hash_size)]
        med = sorted(block[1:])[len(block[1:]) // 2]
        bits = 0
        for i, val in enumerate(block):
            if val > med:
                bits |= 1 << i
        # Postgres BIGINT is signed; wrap the top bit rather than overflow.
        return bits - (1 << 64) if bits >= (1 << 63) else bits
    except Exception as exc:                                   # pragma: no cover
        log.warning("phash failed: %s", exc)
        return None


async def phash(data: bytes) -> int | None:
    return await asyncio.to_thread(_phash_sync, data)


def hamming(a: int, b: int) -> int:
    return bin((a ^ b) & ((1 << 64) - 1)).count("1")


# ═════════════════════════════════════════════════════════════════════════════
# EXIF — the cheapest fraud signal available
# ═════════════════════════════════════════════════════════════════════════════
@dataclass(slots=True)
class ExifInfo:
    taken_at: datetime | None = None
    model: str | None = None
    has_exif: bool = False


def _exif_sync(data: bytes) -> ExifInfo:
    out = ExifInfo()
    try:
        im = Image.open(io.BytesIO(data))
        raw = im.getexif()
        if not raw:
            return out
        out.has_exif = True
        tags = {ExifTags.TAGS.get(k, k): v for k, v in raw.items()}
        out.model = str(tags.get("Model") or "")[:128] or None
        dt = tags.get("DateTimeOriginal") or tags.get("DateTime")
        if dt:
            try:
                out.taken_at = datetime.strptime(str(dt), "%Y:%m:%d %H:%M:%S") \
                                       .replace(tzinfo=timezone.utc)
            except ValueError:
                pass
    except Exception:                                          # pragma: no cover
        pass
    return out


async def read_exif(data: bytes) -> ExifInfo:
    return await asyncio.to_thread(_exif_sync, data)


# ═════════════════════════════════════════════════════════════════════════════
# Azure Document Intelligence — prebuilt-receipt
# ═════════════════════════════════════════════════════════════════════════════
@dataclass(slots=True)
class Extraction:
    merchant: str | None = None
    txn_date: date | None = None
    txn_time: str | None = None
    total: Decimal | None = None
    currency: str = "INR"
    bill_number: str | None = None
    conf_merchant: float | None = None
    conf_date: float | None = None
    conf_total: float | None = None
    raw: dict = field(default_factory=dict)
    provider: str = "azure_di"

    @property
    def conf_overall(self) -> float:
        """
        The weakest link, not the average.

        Averaging lets a confident merchant name hide an unreadable total,
        which is precisely the field that must never be wrong.
        """
        vals = [c for c in (self.conf_merchant, self.conf_date, self.conf_total)
                if c is not None]
        return min(vals) if vals else 0.0


class AzureReceiptClient:
    """
    Thin async client for the prebuilt-receipt model.

    Accepts a URL rather than bytes wherever possible: the API process then
    never holds the image at all, which on a small instance is the single
    biggest memory saving available.
    """

    def __init__(self, endpoint: str, key: str, *, api_version: str = "2024-11-30",
                 timeout: float = 25.0, poll_interval: float = 0.8):
        self.base = endpoint.rstrip("/")
        self.key = key
        self.api_version = api_version
        self.timeout = timeout
        self.poll_interval = poll_interval

    async def analyse_url(self, url: str) -> Extraction:
        return await self._analyse({"urlSource": url}, content_type="application/json")

    async def analyse_bytes(self, data: bytes) -> Extraction:
        return await self._analyse(data, content_type="application/octet-stream")

    async def _analyse(self, body, *, content_type: str) -> Extraction:
        path = (f"{self.base}/documentintelligence/documentModels/"
                f"prebuilt-receipt:analyze?api-version={self.api_version}")
        headers = {"Ocp-Apim-Subscription-Key": self.key, "Content-Type": content_type}

        async with httpx.AsyncClient(timeout=self.timeout) as client:
            if content_type == "application/json":
                resp = await client.post(path, headers=headers, json=body)
            else:
                resp = await client.post(path, headers=headers, content=body)

            if resp.status_code not in (200, 202):
                raise RuntimeError(f"Azure DI {resp.status_code}: {resp.text[:300]}")

            op = resp.headers.get("operation-location")
            if not op:
                raise RuntimeError("Azure DI returned no operation-location")

            # Poll. The deadline is the caller's, not an open-ended loop —
            # a hung provider must not hold a worker indefinitely.
            deadline = asyncio.get_running_loop().time() + self.timeout
            while True:
                if asyncio.get_running_loop().time() > deadline:
                    raise TimeoutError("Azure DI did not finish in time")
                await asyncio.sleep(self.poll_interval)
                r = await client.get(op, headers={"Ocp-Apim-Subscription-Key": self.key})
                r.raise_for_status()
                body_json = r.json()
                status = body_json.get("status")
                if status == "succeeded":
                    return self._parse(body_json)
                if status == "failed":
                    raise RuntimeError(f"Azure DI failed: {body_json.get('error')}")

    @staticmethod
    def _parse(payload: dict) -> Extraction:
        out = Extraction(raw=payload)
        docs = (payload.get("analyzeResult") or {}).get("documents") or []
        if not docs:
            return out
        f = docs[0].get("fields") or {}

        def pick(name):
            return f.get(name) or {}

        m = pick("MerchantName")
        out.merchant = (m.get("valueString") or m.get("content") or "").strip() or None
        out.conf_merchant = m.get("confidence")

        d = pick("TransactionDate")
        raw_date = d.get("valueDate") or d.get("content")
        out.conf_date = d.get("confidence")
        if raw_date:
            try:
                out.txn_date = date.fromisoformat(str(raw_date)[:10])
            except ValueError:
                pass

        t = pick("TransactionTime")
        if t.get("valueTime"):
            out.txn_time = str(t["valueTime"])[:5]

        tot = pick("Total")
        out.conf_total = tot.get("confidence")
        amt = tot.get("valueCurrency", {}).get("amount", tot.get("valueNumber"))
        if amt is None and tot.get("content"):
            amt = re.sub(r"[^\d.]", "", str(tot["content"])) or None
        if amt is not None:
            try:
                out.total = Decimal(str(amt)).quantize(Decimal("0.01"))
            except (InvalidOperation, ValueError):
                pass
        cur = tot.get("valueCurrency", {}).get("currencyCode")
        if cur:
            out.currency = cur
        return out


# ═════════════════════════════════════════════════════════════════════════════
# Composite signature
# ═════════════════════════════════════════════════════════════════════════════
_NON_ALNUM = re.compile(r"[^a-z0-9]")


def normalise_merchant(name: str | None) -> str:
    """"Fresh Basket #2 (Anna Nagar)" and "FRESH BASKET 2" collapse together."""
    if not name:
        return ""
    s = _NON_ALNUM.sub("", name.lower())
    for noise in ("pvtltd", "private", "limited", "ltd", "llp", "inc", "store", "shop"):
        s = s.replace(noise, "")
    return s


def build_signatures(ex: Extraction) -> tuple[str, str]:
    """
    (strict, loose).

    strict — includes time and bill number when present. Unique-indexed, so a
             collision is a hard refusal.
    loose  — merchant + date + amount only. Advisory: two genuine purchases of
             the same value at the same shop on the same day do happen, so
             this routes to review rather than refusing.
    """
    m = normalise_merchant(ex.merchant)
    d = ex.txn_date.isoformat() if ex.txn_date else ""
    a = f"{ex.total:.2f}" if ex.total is not None else ""
    strict = "|".join([m, d, ex.txn_time or "", a, (ex.bill_number or "").lower()])
    loose = "|".join([m, d, a])
    return (hashlib.sha256(strict.encode()).hexdigest(),
            hashlib.sha256(loose.encode()).hexdigest())
