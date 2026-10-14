"""
Run real bill images through the Textract extractor and print what it read.

This is the proof that the AWS side works: it makes genuine AnalyzeExpense
calls with the server's own credentials, through the same code path the live
scan uses, and shows the four fields the app needs — amount, date, time, shop.

    cd /home/ubuntu/claimit_local_production
    venv/bin/python -u deploy/textract_run.py ~/bill_1_total_257.jpg
    venv/bin/python -u deploy/textract_run.py ~/*.jpg

One AnalyzeExpense call per image (~₹1). Re-running the same file inside five
minutes is served from cache and costs nothing.

Pass --raw to dump the full API response to <image>.textract.json, which is
how we find out what the response actually contains on this API version
rather than assuming.
"""

import asyncio
import json
import sys
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.utils import textract_ocr as T  # noqa: E402


def show(label, value, extra=""):
    v = "—" if value in (None, "") else value
    print(f"    {label:<14} {v}{extra}")


async def one(path: Path, dump_raw: bool) -> bool:
    print(f"\n{'=' * 68}\n{path.name}\n{'=' * 68}")
    try:
        data = path.read_bytes()
    except Exception as e:  # noqa: BLE001
        print(f"  cannot read file: {e}")
        return False
    print(f"  size: {len(data) // 1024} KB")

    # Call the API directly here (rather than extract_bill) so --raw can keep
    # the untouched response; the parsing below is the exact same function the
    # live path uses.
    try:
        client = await T._get_client()
        resp = await asyncio.to_thread(
            lambda: client.analyze_expense(Document={"Bytes": data}))
    except Exception as e:  # noqa: BLE001
        print(f"  ❌ TEXTRACT CALL FAILED: {type(e).__name__}: {e}")
        print("     >> AWS side is NOT working. Check the IAM policy and region.")
        return False

    print(f"  ✅ Textract responded (region {T.TEXTRACT_REGION})")

    if dump_raw:
        out = path.with_suffix(path.suffix + ".textract.json")
        out.write_text(json.dumps(resp, indent=2, default=str))
        print(f"  raw response → {out}")

    res = T.parse_expense_response(resp)

    print("\n  ── THE FOUR FIELDS THE APP NEEDS ──")
    show("AMOUNT", res.total,
         f"   (from {res.total_source} @ {res.total_confidence}%)"
         if res.total is not None else "")
    show("DATE", res.bill_date,
         f"   (via {res.date_source})" if res.date_source else "")
    show("TIME", res.bill_time)
    show("SHOP", res.vendor,
         f"   (via {res.vendor_source})" if res.vendor_source else "")
    show("bill no", res.bill_number)

    if res.total is None:
        print(f"\n  ⚠️  NO AMOUNT → manual review. Reason: {res.rejected_reason}")

    print("\n  ── every labelled field Textract found ──")
    if not res.all_fields:
        print("    (none)")
    for k, v in sorted(res.all_fields.items()):
        mark = "  <-- chosen" if k == res.total_source else ""
        print(f"    {k:<28} {v['value']!r:<18} {v['confidence']}%{mark}")

    lines = T.collect_lines(resp)
    print(f"\n  ── text lines seen: {len(lines)} ──")
    for l in lines[:12]:
        print(f"    | {l}")
    if len(lines) > 12:
        print(f"    | … {len(lines) - 12} more")

    return res.total is not None


async def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dump_raw = "--raw" in sys.argv
    if not args:
        print(__doc__)
        return 2

    paths = [Path(a).expanduser() for a in args]
    results = [await one(p, dump_raw) for p in paths]

    print(f"\n{'=' * 68}")
    ok = sum(results)
    print(f"read an amount on {ok} of {len(results)} image(s)")
    print(f"cost: ~₹{len(results)} (one call per image)")
    print("=" * 68)
    return 0 if ok else 1


sys.exit(asyncio.run(main()))
