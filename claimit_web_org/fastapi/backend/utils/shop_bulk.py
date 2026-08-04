"""
shop_bulk.py — helpers for the admin "Bulk Upload Shops" feature.

Admins fill a predefined Excel workbook (one shop per row, with the shop's
photo pasted into the Image column) and upload it. The backend:

  1. Reads the cell values with openpyxl.
  2. Extracts the pasted images by unzipping the .xlsx and mapping each
     embedded picture to its anchor row (openpyxl drops images on load, so we
     parse the drawing XML ourselves).
  3. Uploads each image to S3 and inserts the shops into claimit_db.shops with
     the SAME document shape seed.py produces.

This module holds the pure helpers (column spec, template builder, image
extractor). The DB insert + S3 upload live in routers/admin.py.
"""
from __future__ import annotations

import io
import zipfile
import xml.etree.ElementTree as ET
from typing import Dict, List, Tuple

import openpyxl
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

# ── Category id → name (mirrors the Flutter ShopCategory ids + seed.py) ────────
CATEGORY_LEGEND: Dict[int, str] = {
    1: "New deals", 2: "Groceries", 3: "Supermarket", 4: "Pharmacy", 5: "Salon",
    6: "Gym", 7: "Restaurant", 8: "Cafes", 9: "Clothing", 10: "Department",
    11: "Electronics", 12: "Books", 13: "Toys", 14: "Baby", 15: "Home Decor",
    16: "Furniture", 17: "Spa", 18: "Schools", 19: "Colleges", 20: "Tutoring",
    21: "Clinics", 22: "Hospitals", 23: "Pets", 24: "Sports", 25: "Travel",
    26: "Mobile & Accessories", 27: "Computer & Laptop", 28: "Gifts",
    29: "Jewellery", 30: "Shoes",
}

CATEGORY_NAMES = list(CATEGORY_LEGEND.values())

# name (lowercased) → id, plus common singular/alternate spellings so the team
# can type natural category names.
_NAME_TO_ID = {name.lower(): cid for cid, name in CATEGORY_LEGEND.items()}
_ALIASES = {
    "grocery": 2, "supermarkets": 3, "super market": 3, "restaurants": 7,
    "cafe": 8, "café": 8, "cafés": 8, "clothes": 9, "apparel": 9,
    "electronic": 11, "electronics store": 11, "book": 12, "toy": 13,
    "mobile": 26, "mobiles": 26, "mobile & accessories": 26, "laptop": 27,
    "computer": 27, "computer & laptop": 27, "jewelry": 29, "jewellery": 29,
    "shoe": 30, "shoes": 30, "salons": 5, "gyms": 6, "hospital": 22,
    "clinic": 21, "school": 18, "college": 19, "pet": 23, "sport": 24,
    "gift": 28, "home decor": 15, "homedecor": 15,
}


def parse_categories(value) -> Tuple[List[int], List[str]]:
    """
    Turn a comma-separated list of category NAMES (e.g. "Groceries, Supermarket")
    into a de-duplicated list of ids. Also accepts raw numbers as a fallback.
    Returns (ids, unknown_names).
    """
    ids: List[int] = []
    unknown: List[str] = []
    for part in str(value or "").replace(";", ",").split(","):
        p = part.strip()
        if not p:
            continue
        low = p.lower()
        if low in _NAME_TO_ID:
            ids.append(_NAME_TO_ID[low])
        elif low in _ALIASES:
            ids.append(_ALIASES[low])
        else:
            try:
                n = int(float(p))
                if n in CATEGORY_LEGEND:
                    ids.append(n)
                    continue
            except (ValueError, TypeError):
                pass
            unknown.append(p)
    seen = set()
    out = []
    for i in ids:
        if i not in seen:
            seen.add(i)
            out.append(i)
    return out, unknown

# ── Column spec: (header, field, kind) ────────────────────────────────────────
# Headers are the EXACT seed.py SHOPS_SEED keys so the Excel format matches the
# existing seeder. kind ∈ {str, int, float, bool, ids, image}.
COLUMNS: List[Tuple[str, str, str]] = [
    ("name",           "name",           "str"),
    ("categories",     "category_ids",   "ids"),
    # Structured address — same fields the shop register form collects.
    ("country",        "country",        "str"),
    ("state",          "state",          "str"),
    ("district",       "district",       "str"),
    ("city",           "city",           "str"),
    ("area",           "area",           "str"),
    ("pincode",        "pincode",        "str"),
    ("address",        "address",        "str"),
    ("discount",       "discount",       "int"),
    ("rating",         "rating",         "float"),
    ("added_days_ago", "added_days_ago", "int"),
    ("has_rewards",    "has_rewards",    "bool"),
    ("has_redeem",     "has_redeem",     "bool"),
    ("about",          "about",          "str"),
    ("timing",         "timing",         "str"),
    ("phone",          "phone",          "str"),
    ("lat",            "lat",            "float"),
    ("lng",            "lng",            "float"),
    ("image",          "image",          "image"),
]

HEADERS = [c[0] for c in COLUMNS]
IMAGE_COL_INDEX = next(i for i, c in enumerate(COLUMNS) if c[2] == "image")  # 0-based

# Example row mirrors seed.py's first shop (Indian Mart), with the structured
# address the team collects at registration.
_EXAMPLE_ROW = [
    "Indian Mart", "New deals, Groceries, Supermarket",
    "India", "Tamil Nadu", "Chennai", "Chennai", "Padi", "600050",
    "89, Industrial Estate, Padi, Chennai - 600050",
    30, 4.2, 2, "FALSE", "TRUE",
    "Indian Mart is your one-stop neighbourhood store in Padi, offering fresh "
    "groceries, daily essentials, and household items.",
    "Daily: 8am – 9pm", "+91 44 2651 1234", 13.1197, 80.2183, "",
]


def derive_location(area: str, city: str, district: str) -> str:
    """App display 'location' (e.g. 'Padi, Chennai') from the structured parts."""
    primary = (area or city or "").strip()
    tail = ""
    for cand in (city, district):
        cand = (cand or "").strip()
        if cand and cand.lower() != primary.lower():
            tail = cand
            break
    return ", ".join([p for p in (primary, tail) if p])


# ── Template builder ──────────────────────────────────────────────────────────
def build_template_bytes() -> bytes:
    """Return a styled .xlsx template (Shops sheet + Instructions sheet)."""
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Shops"

    head_fill = PatternFill("solid", fgColor="1A237E")
    head_font = Font(bold=True, color="FFFFFF", size=11)
    wrap = Alignment(vertical="center", wrap_text=True)

    for i, header in enumerate(HEADERS, start=1):
        cell = ws.cell(row=1, column=i, value=header)
        cell.fill = head_fill
        cell.font = head_font
        cell.alignment = Alignment(vertical="center", horizontal="center", wrap_text=True)

    # widths
    widths = [20, 28, 12, 16, 14, 14, 14, 10, 34, 10, 8, 15, 12, 12, 42, 20, 16, 11, 11, 20]
    for i, w in enumerate(widths, start=1):
        ws.column_dimensions[get_column_letter(i)].width = w

    # example row
    for i, val in enumerate(_EXAMPLE_ROW, start=1):
        c = ws.cell(row=2, column=i, value=val)
        c.alignment = wrap
    ws.cell(row=2, column=IMAGE_COL_INDEX + 1,
            value="↙ paste photo into this cell").alignment = wrap

    ws.row_dimensions[1].height = 34
    # tall rows so pasted images have room
    for r in range(2, 60):
        ws.row_dimensions[r].height = 60
    ws.freeze_panes = "A2"

    # ── Instructions sheet ────────────────────────────────────────────────────
    ins = wb.create_sheet("Instructions")
    ins.column_dimensions["A"].width = 60
    ins.column_dimensions["B"].width = 40
    lines = [
        ("How to use this template", True),
        ("1. Fill one shop per row starting at row 2 (the sample row is an example — overwrite or delete it).", False),
        ("2. name is required. Give at least one category.", False),
        ("3. categories: type the category NAMES, comma-separated, e.g. Groceries, Supermarket", False),
        ("   (use the exact names from the list below — you can enter more than one).", False),
        ("4. Address: fill country, state, district, city, area, pincode and the full address —", False),
        ("   the same details collected on the shop registration form. The app 'City / Area'", False),
        ("   label shown on shop cards is built automatically from area + city.", False),
        ("5. has_rewards / has_redeem: type TRUE or FALSE.", False),
        ("6. lat / lng: optional map coordinates (leave blank if unknown).", False),
        ("7. image: click a cell in the image column → Insert → Picture, and place the shop", False),
        ("   photo over that row. Leave blank to use a placeholder (add a photo later in admin).", False),
        ("8. Save the file and upload it in Admin → Bulk Upload Shops.", False),
        ("", False),
        ("Valid category names (type these in the 'categories' column)", True),
    ]
    r = 1
    for text, bold in lines:
        c = ins.cell(row=r, column=1, value=text)
        if bold:
            c.font = Font(bold=True, size=12, color="1A237E")
        r += 1
    for cid, cname in CATEGORY_LEGEND.items():
        ins.cell(row=r, column=1, value=cname)
        r += 1

    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()


# ── Embedded-image extraction ─────────────────────────────────────────────────
_NS = {
    "xdr": "http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing",
    "a":   "http://schemas.openxmlformats.org/drawingml/2006/main",
    "r":   "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
}


def extract_row_images(xlsx_bytes: bytes) -> Dict[int, Tuple[bytes, str]]:
    """
    Map 1-based worksheet row numbers → (image_bytes, ext) for pictures pasted
    into the sheet. Rows are read from each picture's drawing anchor (0-based
    <xdr:from><xdr:row>), converted to 1-based to line up with cell rows.
    """
    out: Dict[int, Tuple[bytes, str]] = {}
    try:
        zf = zipfile.ZipFile(io.BytesIO(xlsx_bytes))
    except Exception:
        return out

    names = zf.namelist()
    drawings = [n for n in names if n.startswith("xl/drawings/") and n.endswith(".xml")]
    for drawing in drawings:
        try:
            root = ET.fromstring(zf.read(drawing))
        except Exception:
            continue
        # rId → media path via the drawing's .rels
        rels_path = drawing.rsplit("/", 1)[0] + "/_rels/" + drawing.rsplit("/", 1)[1] + ".rels"
        rid_to_media: Dict[str, str] = {}
        if rels_path in names:
            try:
                rels_root = ET.fromstring(zf.read(rels_path))
                for rel in rels_root:
                    rid = rel.get("Id")
                    target = rel.get("Target", "")
                    # normalise ../media/imageN.png or /xl/media/imageN.png
                    # → xl/media/imageN.png
                    target = target.replace("../", "").lstrip("/")
                    if not target.startswith("xl/"):
                        target = "xl/" + target
                    rid_to_media[rid] = target
            except Exception:
                pass

        # every anchor (one/two-cell) that carries a picture
        for anchor in list(root):
            frm = anchor.find("xdr:from", _NS)
            blip = anchor.find(".//a:blip", _NS)
            if frm is None or blip is None:
                continue
            row_el = frm.find("xdr:row", _NS)
            if row_el is None:
                continue
            try:
                row0 = int(row_el.text)
            except (TypeError, ValueError):
                continue
            embed = blip.get("{%s}embed" % _NS["r"])
            media = rid_to_media.get(embed)
            if not media or media not in names:
                continue
            try:
                data = zf.read(media)
            except Exception:
                continue
            ext = "." + media.rsplit(".", 1)[-1].lower() if "." in media else ".png"
            out[row0 + 1] = (data, ext)  # 0-based anchor → 1-based row
    return out
