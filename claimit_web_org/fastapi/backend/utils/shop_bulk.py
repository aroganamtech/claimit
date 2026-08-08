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

# ── Category id → name ────────────────────────────────────────────────────────
# These ids MUST stay identical to admin.py `_CATEGORY_NAMES` (the Category
# Images pools) and shop.py `_CATEGORY_MAP` (shop register). If they drift, a
# bulk shop's category_id points at the WRONG image pool, so its category image
# never shows and its category label is wrong in the app.
CATEGORY_LEGEND: Dict[int, str] = {
    1: "Supermarkets", 2: "Fruits & Vegetables", 3: "Pharmacies",
    4: "Restaurants", 5: "Cafes", 6: "Bakery & Sweets", 7: "Juices & Shakes",
    8: "Garments & Fashion", 9: "Footwear", 10: "Mobile", 11: "Electronics",
    12: "Salons", 13: "Beauty Parlours", 14: "Dry Fruits & Nuts",
    15: "Fashion Accessories", 16: "Optical", 17: "Home Appliances",
    18: "Furniture", 19: "Home Furnishing", 20: "Baby Stores",
    21: "Books & Stationery", 22: "Gifts & Fancy Stores", 23: "Toys & Games",
    24: "Sports & Fitness", 25: "Photography & Studios", 26: "Diagnostic Centres",
    27: "Hospitals", 28: "Pet Stores",
}

CATEGORY_NAMES = list(CATEGORY_LEGEND.values())

# name (lowercased) → id, plus common singular/alternate spellings so the team
# can type natural category names. Kept in sync with shop.py `_CATEGORY_MAP`.
_NAME_TO_ID = {name.lower(): cid for cid, name in CATEGORY_LEGEND.items()}
_ALIASES = {
    "supermarket": 1,
    "fruits and vegetables": 2, "fruits": 2, "vegetables": 2, "veggies": 2, "fruits & veg": 2,
    "pharmacy": 3, "medical": 3, "medical store": 3, "medical stores": 3, "chemist": 3,
    "restaurant": 4, "food": 4, "hotel": 4,
    "cafe": 5, "café": 5, "coffee": 5, "coffee shop": 5, "coffee shops": 5,
    "bakery and sweets": 6, "bakery": 6, "sweets": 6, "cakes": 6, "sweet shop": 6,
    "juices and shakes": 7, "juices": 7, "juice": 7, "shakes": 7, "juice shop": 7, "milkshakes": 7,
    "garments and fashion": 8, "fashion": 8, "garment": 8, "garments": 8, "clothing": 8, "clothes": 8, "apparel": 8,
    "footwears": 9, "shoes": 9, "shoe": 9,
    "mobiles": 10, "mobile store": 10, "mobile stores": 10, "mobile & accessories": 10,
    "electronic": 11, "electronics store": 11,
    "salon": 12,
    "beauty parlour": 13, "beauty": 13, "parlour": 13, "parlor": 13, "spa": 13,
    "dry fruits and nuts": 14, "dry fruits": 14, "nuts": 14, "dryfruits": 14,
    "accessories": 15, "fashion accessory": 15,
    "optical store": 16, "optical stores": 16, "optics": 16, "eyewear": 16,
    "appliances": 17, "home appliance": 17, "kitchen appliances": 17,
    "furniture store": 18, "furniture stores": 18,
    "home furnishings": 19, "furnishing": 19, "home decor": 19, "home linen": 19, "curtains": 19,
    "baby": 20, "baby store": 20, "baby products": 20,
    "books and stationery": 21, "books": 21, "book": 21, "stationery": 21, "book store": 21, "bookstore": 21,
    "gifts and fancy stores": 22, "gifts": 22, "gift": 22, "fancy store": 22, "fancy stores": 22, "gift shop": 22,
    "toys and games": 23, "toys": 23, "toy": 23, "games": 23, "toy store": 23,
    "sports and fitness": 24, "sports": 24, "sport": 24, "fitness": 24, "gym": 24,
    "photography and studios": 25, "photography": 25, "studio": 25, "studios": 25, "photo studio": 25,
    "diagnostic centre": 26, "diagnostic center": 26, "diagnostics": 26, "diagnostic": 26, "labs": 26, "lab": 26,
    "hospital": 27, "clinic": 27, "clinics": 27,
    "pets": 28, "pet": 28, "pet store": 28, "pet shop": 28,
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
# Data-only import. No Redeem/Reward flags (chosen later in shop register) and
# no image (images are set per-category on the admin Category Images page).
# kind ∈ {str, int, float, ids}.
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
    ("about",          "about",          "str"),
    ("timing",         "timing",         "str"),
    ("phone",          "phone",          "str"),
    ("lat",            "lat",            "float"),
    ("lng",            "lng",            "float"),
]

HEADERS = [c[0] for c in COLUMNS]

# Example row mirrors seed.py's first shop (Indian Mart), with the structured
# address the team collects at registration.
_EXAMPLE_ROW = [
    "Indian Mart", "Supermarkets, Fruits & Vegetables",
    "India", "Tamil Nadu", "Chennai", "Chennai", "Padi", "600050",
    "89, Industrial Estate, Padi, Chennai - 600050",
    30, 4.2, 2,
    "Indian Mart is your one-stop neighbourhood store in Padi, offering fresh "
    "groceries, daily essentials, and household items.",
    "Daily: 8am – 9pm", "+91 44 2651 1234", 13.1197, 80.2183,
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
    widths = [20, 28, 12, 16, 14, 14, 14, 10, 34, 10, 8, 15, 42, 20, 16, 11, 11]
    for i, w in enumerate(widths, start=1):
        ws.column_dimensions[get_column_letter(i)].width = w

    # example row
    for i, val in enumerate(_EXAMPLE_ROW, start=1):
        c = ws.cell(row=2, column=i, value=val)
        c.alignment = wrap

    ws.row_dimensions[1].height = 34
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
        ("5. lat / lng: optional map coordinates (leave blank if unknown).", False),
        ("6. No image column: each shop shows a random image from its category — upload those", False),
        ("   on Admin → Category Images. Redeem/Reward is chosen later in shop registration.", False),
        ("7. Save the file and upload it in Admin → Bulk Upload Shops.", False),
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
