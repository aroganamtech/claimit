"""
privilege_bulk.py — the Claimit Privilege bulk-upload template and parser.

Same shape as select_bulk / classified_bulk: build_template() writes the .xlsx
an admin downloads, parse_sheet() reads the filled copy back.

Two things this is strict about, because both produce silent failures that
nobody notices for weeks:

  • A partner with no resolvable position never appears in the 5 km search.
    So a row needs a 6-digit pincode (or explicit lat/lng). A row without one
    is rejected loudly here rather than saved and invisible.

  • The category has to be one of the nine fixed ids. A typo like "Hotel"
    would create a category nothing links to, so the row is rejected with the
    list of valid ids in the message.
"""
import io
from typing import List, Tuple

from openpyxl import Workbook, load_workbook
from openpyxl.styles import Font, PatternFill, Alignment

# Must match PRIVILEGE_CATEGORIES in the app backend's routes/privilege.py.
CATEGORY_IDS = [
    "hotels", "travel", "events", "interiors", "health",
    "auto", "education", "property", "jewellery",
]

CATEGORY_LABELS = {
    "hotels":    "Hotels & Resorts",
    "travel":    "Tours, Travel & Packages",
    "events":    "Wedding & Events",
    "interiors": "Interiors & Furniture",
    "health":    "Healthcare, Dental & Wellness",
    "auto":      "Cars, Bikes & Auto Services",
    "education": "Education & Overseas Studies",
    "property":  "Real Estate & Property",
    "jewellery": "Jewellery & Premium Retail",
}

COLUMNS = [
    ("name",              "REQUIRED. Business name, e.g. The Grand Residency"),
    ("category",          "REQUIRED. One of: " + ", ".join(CATEGORY_IDS)),
    ("discount_percent",  "REQUIRED. Number only, e.g. 15"),
    ("discount_label",    "What it applies to, e.g. Food and Soft Beverages"),
    ("about",             "Short description shown on the detail page"),
    ("privilege_details", "What the customer gets, in full"),
    ("terms",             "Terms & conditions"),
    ("area",              "e.g. Anna Nagar"),
    ("city",              "e.g. Chennai"),
    ("state",             "e.g. Tamil Nadu"),
    ("pincode",           "REQUIRED. 6 digits — this is what places you on the map"),
    ("address",           "Full address"),
    ("phone",             "10-digit contact number"),
    ("image",             "Optional. Filename of an image uploaded in step 1"),
]

REQUIRED = ("name", "category", "discount_percent", "pincode")

_NOTE_MARKERS = ("required.", "optional.", "one of:", "number only")


def _clean(value) -> str:
    s = str(value or "").strip()
    return "" if s.lower() in ("none", "null", "nan", "-") else s


def _clean_pin(value) -> str:
    """Excel turns 600040 into 600040.0 and drops leading zeros from some
    pincodes. Strip to digits and re-pad, so a legitimate 0-leading pincode
    typed as a number still parses."""
    s = _clean(value)
    if s.endswith(".0"):
        s = s[:-2]
    digits = "".join(ch for ch in s if ch.isdigit())
    if 0 < len(digits) < 6:
        digits = digits.zfill(6)
    return digits


def build_template() -> bytes:
    """The .xlsx an admin downloads: one sheet to fill, one explaining it."""
    wb = Workbook()
    ws = wb.active
    ws.title = "Partners"

    header_font = Font(bold=True, color="FFFFFF", size=11)
    header_fill = PatternFill("solid", fgColor="1565C0")
    note_font = Font(italic=True, size=9, color="777777")

    for i, (col, note) in enumerate(COLUMNS, start=1):
        c = ws.cell(row=1, column=i, value=col)
        c.font = header_font
        c.fill = header_fill
        c.alignment = Alignment(horizontal="center", vertical="center")

        n = ws.cell(row=2, column=i, value=note)
        n.font = note_font
        n.alignment = Alignment(wrap_text=True, vertical="top")

        ws.column_dimensions[c.column_letter].width = max(16, min(38, len(note) // 2 + 12))

    ws.row_dimensions[2].height = 42
    ws.freeze_panes = "A3"

    # A filled example row, so the first-time user can see the shape rather
    # than guess it.
    example = [
        "The Grand Residency", "hotels", 15, "Food and Soft Beverages",
        "A premium business hotel offering elegant rooms and multi-cuisine dining.",
        "Get 15% off eligible food and soft-beverage charges at the all-day "
        "dining restaurant.",
        "Valid for registered Claimit users on eligible items only. Inform the "
        "billing executive before billing. Cannot be combined with other offers.",
        "Anna Nagar", "Chennai", "Tamil Nadu", "600040",
        "12 2nd Avenue, Anna Nagar", "9884190908", "grand-residency.jpg",
    ]
    for i, v in enumerate(example, start=1):
        ws.cell(row=3, column=i, value=v)

    # ── Read Me ──────────────────────────────────────────────────────────
    rm = wb.create_sheet("Read Me")
    rm.column_dimensions["A"].width = 100
    lines = [
        "Claimit Privilege — bulk upload",
        "",
        "1. Row 2 is a note row. Leave it or delete it; either works.",
        "2. Row 3 is an example. DELETE IT before uploading, or you will "
        "publish a hotel that does not exist.",
        "3. One partner per row from row 3 onwards.",
        "",
        "Required columns: name, category, discount_percent, pincode",
        "",
        "category must be exactly one of these ids (lowercase):",
    ]
    lines += [f"    {cid}  =  {CATEGORY_LABELS[cid]}" for cid in CATEGORY_IDS]
    lines += [
        "",
        "pincode is required because it is what places the partner on the map.",
        "A partner without one never appears in the app's 5 km search, no",
        "matter how correct the rest of the row is.",
        "",
        "image is optional: upload the photos first, then put the filename",
        "here exactly as uploaded (including the extension).",
    ]
    for i, line in enumerate(lines, start=1):
        cell = rm.cell(row=i, column=1, value=line)
        if i == 1:
            cell.font = Font(bold=True, size=13)

    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()


def parse_sheet(data: bytes) -> Tuple[List[dict], List[dict], dict]:
    """(partners, rejected, summary).

    `rejected` explains every dropped row and why, so an admin can fix the
    sheet instead of wondering why 40 partners never appeared.
    """
    wb = load_workbook(io.BytesIO(data), data_only=True)
    ws = wb["Partners"] if "Partners" in wb.sheetnames else wb.worksheets[0]

    header_row, headers = None, {}
    for r in range(1, min(ws.max_row, 10) + 1):
        values = [str(ws.cell(row=r, column=c).value or "").strip().lower()
                  for c in range(1, ws.max_column + 1)]
        if "name" in values and "category" in values:
            header_row = r
            headers = {v: i + 1 for i, v in enumerate(values) if v}
            break
    if header_row is None:
        raise ValueError(
            "Could not find the header row. Use the downloaded template and "
            "do not rename the columns.")

    missing = [c for c in REQUIRED if c not in headers]
    if missing:
        raise ValueError(f"Missing required column(s): {', '.join(missing)}")

    def cell(r: int, col: str):
        return ws.cell(row=r, column=headers[col]).value if col in headers else None

    partners, rejected = [], []
    seen_names = set()

    for r in range(header_row + 1, ws.max_row + 1):
        name = _clean(cell(r, "name"))
        category = _clean(cell(r, "category")).lower()

        # The note row and blank rows are skipped silently — neither is a
        # mistake by the person filling the sheet.
        joined = f"{name} {category}".lower()
        if any(m in joined for m in _NOTE_MARKERS):
            continue
        if not name and not category:
            continue

        if not name:
            rejected.append({"row": r, "reason": "Missing name"})
            continue
        if category not in CATEGORY_IDS:
            rejected.append({
                "row": r, "name": name,
                "reason": f"Unknown category '{category}'. Use one of: "
                          + ", ".join(CATEGORY_IDS)})
            continue

        raw_disc = _clean(cell(r, "discount_percent"))
        try:
            discount = float(raw_disc) if raw_disc else 0.0
        except ValueError:
            rejected.append({"row": r, "name": name,
                             "reason": f"Discount '{raw_disc}' is not a number"})
            continue
        if discount < 0 or discount > 100:
            rejected.append({"row": r, "name": name,
                             "reason": "Discount % must be between 0 and 100"})
            continue

        pin = _clean_pin(cell(r, "pincode"))
        if len(pin) != 6:
            rejected.append({
                "row": r, "name": name,
                "reason": "Pincode must be 6 digits — without it this partner "
                          "never appears in the app's location search"})
            continue

        # Same name in the same pincode twice is a duplicated row, not two
        # branches; two branches would differ by area or address.
        key = (name.lower(), pin)
        if key in seen_names:
            rejected.append({"row": r, "name": name,
                             "reason": "Duplicate of an earlier row"})
            continue
        seen_names.add(key)

        partners.append({
            "name":              name,
            "category":          category,
            "category_label":    CATEGORY_LABELS[category],
            "discount_percent":  discount,
            "discount_label":    _clean(cell(r, "discount_label")),
            "about":             _clean(cell(r, "about")),
            "privilege_details": _clean(cell(r, "privilege_details")),
            "terms":             _clean(cell(r, "terms")),
            "area":              _clean(cell(r, "area")),
            "city":              _clean(cell(r, "city")),
            "state":             _clean(cell(r, "state")),
            "pincode":           pin,
            "address":           _clean(cell(r, "address")),
            "phone":             _clean(cell(r, "phone")),
            "image":             _clean(cell(r, "image")),
            "_row":              r,
        })

    summary = {
        "total_rows": len(partners) + len(rejected),
        "valid":      len(partners),
        "rejected":   len(rejected),
    }
    return partners, rejected, summary
