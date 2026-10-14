"""
Bill data extraction with AWS Textract AnalyzeExpense.

WHY THIS EXISTS
---------------
The app used to read the bill itself (Gemini → Groq → ML Kit regex) and send
the amount it found. Two things went wrong with that:

  1. A misread digit became money. The client's standing example is a ₹257
     bill credited as a different amount.
  2. The amount arrived from the phone, so the server was trusting a number a
     client supplied for a payout.

AnalyzeExpense fixes the first problem in a way a general-purpose vision model
cannot: it returns *labelled* fields. "TOTAL" comes back tagged as TOTAL,
"SUBTOTAL" as SUBTOTAL, "CASH" as AMOUNT_PAID. So the classic failure — picking
the subtotal, the tax line, or the cash tendered instead of the final payable —
stops being a guessing game and becomes a lookup. The client's own document
splits the ₹257 bug into exactly three causes; this module addresses all three:

  * digits misread            → Textract, plus a per-field confidence floor
  * WRONG AMOUNT SELECTED     → field labels + an explicit priority order
  * decimal/currency misparse → _parse_amount, with tests for Indian formats

COST
----
One AnalyzeExpense call per bill, about ₹1. Nothing else here costs money.
Results are cached on the image's SHA-256 for a few minutes so a user who
retries the same photo (a rejected scan, a flaky network) does not get billed
twice for the same image.

The image is passed as raw Bytes, NOT via S3. The server already receives the
photo as base64, so there is no upload, no S3 read, no storage cost, and no
"bucket must be in the same region" constraint to satisfy.

SCOPE — deliberately narrow
---------------------------
This module only EXTRACTS. It does not decide rewards, check duplicates, match
merchants or touch wallets. All of that stays exactly where it already is in
routes/bill.py.
"""

from __future__ import annotations

import asyncio
import hashlib
import os
import re
import time
from dataclasses import dataclass, field
from typing import Optional

# ── Configuration ────────────────────────────────────────────────────────────
# Textract does NOT run in eu-north-1 (Stockholm), where this server lives and
# where AWS_REGION points. The region is therefore its own setting and must
# never fall back to AWS_REGION.
TEXTRACT_REGION = os.getenv("TEXTRACT_REGION", "ap-south-1")

# A field read less confidently than this is treated as unreadable, which sends
# the bill to manual review instead of crediting a number we half-believe.
# Textract reports 0-100. 80 is deliberately strict: a wrong payout costs more
# than asking a customer to retake a photo.
MIN_CONFIDENCE = float(os.getenv("TEXTRACT_MIN_CONFIDENCE", "80"))

# Sanity bounds. Outside these the read is wrong regardless of confidence —
# this is the backstop against a decimal-point error turning ₹257 into
# ₹25,700 and against a stray line being read as the total.
MIN_PLAUSIBLE_AMOUNT = 1.0
MAX_PLAUSIBLE_AMOUNT = float(os.getenv("BILL_MAX_AMOUNT", "500000"))

# Largest image we will send. AnalyzeExpense's synchronous API caps at 10 MB;
# staying under it avoids paying for a call that was always going to fail.
MAX_IMAGE_BYTES = 9 * 1024 * 1024

_CACHE_TTL_SECONDS = 300
_CACHE_MAX_ENTRIES = 256


# ── Which summary field is the final payable amount ──────────────────────────
# Order matters and is the whole point of this module.
#
# TOTAL is what we want. AMOUNT_PAID is the fallback for receipts that only
# print what was handed over. AMOUNT_DUE last, for invoices.
#
# Everything in _NEVER_TOTAL is a number that LOOKS like a total on a bill and
# must never be chosen as one. This list is the fix for the client's
# "Scanner selects subtotal, tax or cash tendered" failure mode.
_TOTAL_PRIORITY = ("TOTAL", "AMOUNT_PAID", "AMOUNT_DUE")

_NEVER_TOTAL = {
    "SUBTOTAL", "TAX", "TAX_PAYER_ID", "DISCOUNT", "SERVICE_CHARGE",
    "TIP", "GRATUITY", "SHIPPING_HANDLING_CHARGE", "PRIOR_BALANCE",
    "DELIVERY_DATE", "DUE_DATE", "INVOICE_RECEIPT_DATE", "PAYMENT_TERMS",
}


_MONTHS = {
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
    "jul": 7, "aug": 8, "sep": 9, "sept": 9, "oct": 10, "nov": 11, "dec": 12,
}

# Date shapes Indian bills actually print, most specific first.
_DATE_PATTERNS = (
    # 13/10/2026  13-10-26  13.10.2026
    re.compile(r"\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})\b"),
    # 2026-10-13  (ISO, some POS systems)
    re.compile(r"\b(\d{4})-(\d{1,2})-(\d{1,2})\b"),
    # 13 Oct 2026  /  13-Oct-2026
    re.compile(r"\b(\d{1,2})[\s\-]([A-Za-z]{3,4})[\s\-](\d{2,4})\b"),
)
_TIME_RE = re.compile(
    r"\b([01]?\d|2[0-3])[:.]([0-5]\d)(?:[:.]([0-5]\d))?\s*([AaPp]\.?[Mm]\.?)?\b"
)
# Lines that are labels, not the shop's name.
_NOT_A_SHOP_NAME = re.compile(
    r"^(?:gstin|gst|tin|phone|ph|tel|mobile|bill|invoice|receipt|date|time|"
    r"item|qty|rate|amount|subtotal|total|cgst|sgst|igst|tax|cash|card|"
    r"change|thank|visit|sample|address|no\b|#)",
    re.IGNORECASE,
)


def _normalise_date(y: int, m: int, d: int) -> Optional[str]:
    """To DD/MM/YYYY, or None when the numbers cannot be a real date."""
    if y < 100:
        y += 2000
    if not (1 <= m <= 12 and 1 <= d <= 31 and 2000 <= y <= 2100):
        return None
    return f"{d:02d}/{m:02d}/{y:04d}"


def find_date(lines: list[str]) -> Optional[str]:
    """First plausible date in the bill's text, as DD/MM/YYYY.

    A labelled INVOICE_RECEIPT_DATE is always preferred; this is the fallback
    for bills where Textract doesn't label one — which is most small Indian
    retail bills, where the date is just a line of text near the top.

    Lines mentioning "date" are searched first, so a bill that prints both an
    invoice date and, say, a GST period doesn't pick the wrong one.
    """
    ordered = ([l for l in lines if re.search(r"date", l, re.I)] +
               [l for l in lines if not re.search(r"date", l, re.I)])
    for line in ordered:
        for i, pat in enumerate(_DATE_PATTERNS):
            m = pat.search(line)
            if not m:
                continue
            a, b, c = m.group(1), m.group(2), m.group(3)
            if i == 0:          # DD/MM/YYYY — Indian order, not US
                got = _normalise_date(int(c), int(b), int(a))
            elif i == 1:        # YYYY-MM-DD
                got = _normalise_date(int(a), int(b), int(c))
            else:               # DD Mon YYYY
                mon = _MONTHS.get(b.lower()[:4]) or _MONTHS.get(b.lower()[:3])
                got = _normalise_date(int(c), mon, int(a)) if mon else None
            if got:
                return got
    return None


def find_time(lines: list[str]) -> Optional[str]:
    """First clock time in the bill's text, as HH:MM (24h)."""
    ordered = ([l for l in lines if re.search(r"time", l, re.I)] +
               [l for l in lines if not re.search(r"time", l, re.I)])
    for line in ordered:
        m = _TIME_RE.search(line)
        if not m:
            continue
        hh, mm, _ss, ampm = m.group(1), m.group(2), m.group(3), m.group(4)
        h = int(hh)
        if ampm:
            ap = ampm.lower().replace(".", "")
            if ap == "pm" and h < 12:
                h += 12
            elif ap == "am" and h == 12:
                h = 0
        return f"{h:02d}:{mm}"
    return None


def find_shop_name(blocks: list[dict]) -> Optional[str]:
    """The shop's name, using the one thing true of every bill: it's the
    biggest text at the top.

    Ramesh's observation, and it holds — a bill header is always the largest
    type on the page. So instead of guessing semantically, this measures the
    bounding-box HEIGHT of each text line in the top third of the image and
    takes the tallest one that isn't an obvious label (GSTIN, Phone, Date…).

    Falls back to None when the response carries no geometry, in which case
    the caller uses Textract's own VENDOR_NAME.
    """
    best, best_h = None, 0.0
    for b in blocks:
        if b.get("BlockType") != "LINE":
            continue
        text = (b.get("Text") or "").strip()
        if len(text) < 3 or _NOT_A_SHOP_NAME.match(text):
            continue
        geo = (b.get("Geometry") or {}).get("BoundingBox") or {}
        top, h = geo.get("Top"), geo.get("Height")
        if top is None or h is None:
            continue
        if top > 0.33:              # header region only
            continue
        # Mostly-digits lines are phone numbers or GST ids, not names.
        letters = sum(c.isalpha() for c in text)
        if letters < len(text) * 0.5:
            continue
        if h > best_h:
            best, best_h = text, float(h)
    return best


def collect_lines(resp: dict) -> list[str]:
    """Every text line Textract saw, from whichever place this API version
    puts them. AnalyzeExpense has carried `Blocks` at both the top level and
    inside each ExpenseDocument across versions, so both are checked rather
    than assumed — and if neither is present the field values themselves are
    used, which still covers the date on most bills."""
    out: list[str] = []
    for blk in _collect_blocks(resp):
        if blk.get("BlockType") == "LINE" and blk.get("Text"):
            out.append(blk["Text"])
    if out:
        return out
    for doc in resp.get("ExpenseDocuments") or []:
        for f in doc.get("SummaryFields") or []:
            t = (f.get("Type") or {}).get("Text")
            v = (f.get("ValueDetection") or {}).get("Text")
            if t or v:
                out.append(f"{t or ''} {v or ''}".strip())
    return out


def _collect_blocks(resp: dict) -> list[dict]:
    blocks = list(resp.get("Blocks") or [])
    for doc in resp.get("ExpenseDocuments") or []:
        blocks.extend(doc.get("Blocks") or [])
    return blocks


@dataclass
class BillExtract:
    """What Textract read off one bill. All fields optional — a bill that
    could not be read confidently comes back with total=None, which the
    caller must treat as "send to manual review", never as zero."""

    # The four fields the app actually needs.
    total: Optional[float] = None
    vendor: Optional[str] = None
    bill_date: Optional[str] = None        # DD/MM/YYYY
    bill_time: Optional[str] = None        # HH:MM, 24-hour
    bill_number: Optional[str] = None

    # Where each came from, so a wrong read is diagnosable from the log alone.
    vendor_source: Optional[str] = None
    date_source: Optional[str] = None

    # Which labelled field the total came from ("TOTAL", "AMOUNT_PAID", …).
    # Logged so a wrong extraction can be diagnosed later without the image.
    total_source: Optional[str] = None
    total_confidence: Optional[float] = None

    # Why the read was rejected, when it was.
    rejected_reason: Optional[str] = None

    # Every labelled money field seen, for the comparison log the client's
    # document asks for ("log the extraction output").
    all_fields: dict = field(default_factory=dict)

    @property
    def ok(self) -> bool:
        return self.total is not None


# ── Currency parsing ─────────────────────────────────────────────────────────

_AMOUNT_CLEAN_RE = re.compile(r"[^\d.,\-]")

# Tokens that legitimately sit next to an amount on an Indian bill and carry
# no digits. Removed before the garbled-text check below.
_CURRENCY_TOKENS_RE = re.compile(
    r"(?:₹|₨|\$)|(?<![A-Za-z])(?:RS|INR|CR|DR)(?![A-Za-z])|/-",
    re.IGNORECASE,
)
_HAS_LETTER_RE = re.compile(r"[A-Za-z]")


def _parse_amount(raw: Optional[str]) -> Optional[float]:
    """Turn a bill's printed amount into a number, or None.

    This is where the client's third failure mode lives ("₹257.00 becomes
    ₹25,700"), so it is deliberately explicit rather than a bare float() on a
    stripped string.

    Handles what Indian bills actually print:
        "₹257.00"      "Rs. 257/-"     "257"        "1,234.56"
        "₹ 2,008.80"   "INR 450.00"    "450.00 Cr"  "1.234,56" (rare, EU style)

    The comma/period ambiguity is resolved by position, not by locale guessing:
    whichever separator appears LAST and has 1-2 digits after it is the decimal
    point. "1,234.56" → 1234.56 and "1.234,56" → 1234.56 both come out right.
    """
    if raw is None:
        return None

    # ── Garbled-read guard — do this BEFORE stripping ────────────────────────
    # OCR confuses O/0, l/1, S/5. Blindly removing non-digits turns a garbled
    # "O57.OO" into "57." which parses to a perfectly plausible ₹57 and gets
    # paid out. Silently shrinking an amount is worse than refusing to read it,
    # so if any letter survives the removal of known currency tokens, the value
    # is treated as unreadable and the bill goes to manual review.
    probe = _CURRENCY_TOKENS_RE.sub("", str(raw))
    if _HAS_LETTER_RE.search(probe):
        return None

    s = _AMOUNT_CLEAN_RE.sub("", str(raw)).strip()
    if not s:
        return None

    negative = s.startswith("-")
    s = s.lstrip("-")
    # A trailing "-" is the Indian "/-" suffix with the slash already stripped,
    # not a minus sign.
    s = s.rstrip("-")
    if not s:
        return None

    last_dot, last_comma = s.rfind("."), s.rfind(",")

    if last_dot == -1 and last_comma == -1:
        digits = s
    else:
        # The separator nearer the end is the candidate decimal point, but only
        # if exactly 1-2 digits follow it. "1,234" has 3 digits after the comma,
        # so that comma is a thousands separator and the number is 1234.
        sep_pos = max(last_dot, last_comma)
        tail = s[sep_pos + 1:]
        if len(tail) in (1, 2) and tail.isdigit():
            head = s[:sep_pos].replace(",", "").replace(".", "")
            digits = f"{head}.{tail}"
        else:
            digits = s.replace(",", "").replace(".", "")

    try:
        val = float(digits)
    except ValueError:
        return None
    if negative:
        val = -val
    return val


def _plausible(v: Optional[float]) -> bool:
    return v is not None and MIN_PLAUSIBLE_AMOUNT <= v <= MAX_PLAUSIBLE_AMOUNT


# ── Reading the Textract response ────────────────────────────────────────────

def _field_type(f: dict) -> str:
    return str((f.get("Type") or {}).get("Text") or "").upper()


def _field_value(f: dict) -> str:
    return str((f.get("ValueDetection") or {}).get("Text") or "").strip()


def _field_confidence(f: dict) -> float:
    """Confidence in the VALUE, not in the label.

    Textract scores the type and the value separately. The value is the number
    we are about to pay out on, so that is the one that has to clear the bar.
    """
    try:
        return float((f.get("ValueDetection") or {}).get("Confidence") or 0.0)
    except (TypeError, ValueError):
        return 0.0


def parse_expense_response(resp: dict) -> BillExtract:
    """Pull the final payable amount (and vendor/date/number) out of an
    AnalyzeExpense response.

    Separated from the API call so it can be unit-tested against recorded
    responses with no AWS account and no spend.
    """
    out = BillExtract()
    docs = resp.get("ExpenseDocuments") or []
    if not docs:
        out.rejected_reason = "no expense document found in image"
        return out

    summary = docs[0].get("SummaryFields") or []

    # Collect every labelled field. Keep the HIGHEST-confidence instance of
    # each type: bills often print "Total" twice (once per column, or once per
    # page) and the clearer read is the one to trust.
    best: dict[str, tuple[str, float]] = {}
    for f in summary:
        ftype, val, conf = _field_type(f), _field_value(f), _field_confidence(f)
        if not ftype or not val:
            continue
        if ftype not in best or conf > best[ftype][1]:
            best[ftype] = (val, conf)

    out.all_fields = {k: {"value": v, "confidence": round(c, 1)}
                      for k, (v, c) in best.items()}

    # ── The total ────────────────────────────────────────────────────────────
    for ftype in _TOTAL_PRIORITY:
        if ftype in _NEVER_TOTAL:          # guard against a bad edit above
            continue
        hit = best.get(ftype)
        if not hit:
            continue
        val, conf = hit
        amount = _parse_amount(val)
        if not _plausible(amount):
            # Try the next candidate rather than giving up: a garbled TOTAL
            # with a clean AMOUNT_PAID beside it is still a usable bill.
            out.rejected_reason = (
                f"{ftype} value {val!r} did not parse to a plausible amount")
            continue
        if conf < MIN_CONFIDENCE:
            out.rejected_reason = (
                f"{ftype} read at {conf:.0f}% confidence, below "
                f"{MIN_CONFIDENCE:.0f}% minimum")
            continue
        out.total = round(amount, 2)
        out.total_source = ftype
        out.total_confidence = round(conf, 1)
        out.rejected_reason = None
        break

    if out.total is None and out.rejected_reason is None:
        out.rejected_reason = "no TOTAL / AMOUNT_PAID / AMOUNT_DUE field on bill"

    # ── Supporting fields ────────────────────────────────────────────────────
    # Extracted and returned for logging and for the caller to use later.
    # Deliberately NOT wired into the merchant-match or duplicate checks in
    # this change: those rules are tuned to the app's current values, and
    # changing the amount source and the matching rules at the same time would
    # make a rejection impossible to attribute.
    if (v := best.get("INVOICE_RECEIPT_ID")):
        out.bill_number = v[0]

    # ── Shop name: labelled field first, then "biggest text at the top" ──────
    if (v := best.get("VENDOR_NAME")):
        out.vendor = v[0].strip()
    if not out.vendor:
        out.vendor = find_shop_name(_collect_blocks(resp))
        if out.vendor:
            out.vendor_source = "header_geometry"
    else:
        out.vendor_source = "VENDOR_NAME"

    # ── Date: labelled field first, then regex over every line ──────────────
    # Small Indian retail bills usually print the date as plain text, which
    # Textract often does not label — the reason a gallery upload came back
    # with a correct shop name but no date.
    if (v := best.get("INVOICE_RECEIPT_DATE")):
        raw = v[0]
        out.bill_date = find_date([raw]) or raw.strip()
        out.date_source = "INVOICE_RECEIPT_DATE"
    lines = collect_lines(resp)
    if not out.bill_date:
        out.bill_date = find_date(lines)
        if out.bill_date:
            out.date_source = "text_scan"

    # ── Time: never a labelled field, always a text scan ────────────────────
    out.bill_time = find_time(lines)

    return out


# ── Cache, so a retry of the same photo costs nothing ────────────────────────

_cache: dict[str, tuple[float, BillExtract]] = {}


def _cache_get(key: str) -> Optional[BillExtract]:
    hit = _cache.get(key)
    if not hit:
        return None
    ts, val = hit
    if time.time() - ts > _CACHE_TTL_SECONDS:
        _cache.pop(key, None)
        return None
    return val


def _cache_put(key: str, val: BillExtract) -> None:
    if len(_cache) >= _CACHE_MAX_ENTRIES:
        # Cheapest sufficient eviction: drop the oldest. This cache exists to
        # stop double-billing within one user's retry loop, not to be an LRU.
        oldest = min(_cache.items(), key=lambda kv: kv[1][0])[0]
        _cache.pop(oldest, None)
    _cache[key] = (time.time(), val)


# ── The call ─────────────────────────────────────────────────────────────────

_client = None
_client_lock = asyncio.Lock()


async def _get_client():
    """One boto3 Textract client, created on first use.

    `region_name` is passed explicitly. The server's AWS_REGION is
    eu-north-1, where Textract does not exist, so relying on the default
    would fail with an endpoint error on every bill.
    """
    global _client
    if _client is not None:
        return _client
    async with _client_lock:
        if _client is None:
            import boto3
            from botocore.config import Config
            _client = boto3.client(
                "textract",
                region_name=TEXTRACT_REGION,
                config=Config(
                    retries={"max_attempts": 2, "mode": "standard"},
                    connect_timeout=5,
                    read_timeout=15,
                ),
            )
    return _client


async def extract_bill(image_bytes: bytes) -> BillExtract:
    """Read one bill. Never raises — a failure returns total=None plus a
    reason, and the caller decides what to do about it.

    The caller must treat total=None as "cannot be read → manual review",
    never as zero and never as permission to fall back to a client-supplied
    amount.
    """
    if not image_bytes:
        return BillExtract(rejected_reason="no image supplied")
    if len(image_bytes) > MAX_IMAGE_BYTES:
        return BillExtract(
            rejected_reason=f"image is {len(image_bytes) // 1024} KB, over the "
                            f"{MAX_IMAGE_BYTES // 1024} KB limit")

    key = hashlib.sha256(image_bytes).hexdigest()
    if (cached := _cache_get(key)) is not None:
        return cached

    try:
        client = await _get_client()
    except Exception as exc:  # noqa: BLE001 — missing boto3/credentials
        return BillExtract(rejected_reason=f"textract unavailable: {exc}")

    def _call():
        return client.analyze_expense(Document={"Bytes": image_bytes})

    try:
        resp = await asyncio.to_thread(_call)
    except Exception as exc:  # noqa: BLE001
        # Includes AccessDenied, throttling, bad image, endpoint errors. The
        # bill goes to review; it must never credit on a failed read.
        name = type(exc).__name__
        print(f"⚠️  Textract analyze_expense failed: {name}: {exc}")
        return BillExtract(rejected_reason=f"textract error: {name}")

    out = parse_expense_response(resp)
    _cache_put(key, out)
    return out
