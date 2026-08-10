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
import re
import unicodedata
import zipfile
import xml.etree.ElementTree as ET
from typing import Dict, List, Tuple

import openpyxl
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

# ── Category id → name ────────────────────────────────────────────────────────
# These ids MUST stay identical to admin.py `_CATEGORY_NAMES` (the Category
# Images pools) and shop.py `_CATEGORY_MAP` (shop register). If they drift, a
# bulk shop's category_id points at the WRONG image pool, so its category image
# never shows and its category label is wrong in the app.
CATEGORY_LEGEND: Dict[int, str] = {
    1: "Supermarkets", 2: "Fruits & Vegetables", 3: "Pharmacies", 4: "Restaurants",
    5: "Cafes", 6: "Bakery & Sweets", 7: "Juices & Shakes", 8: "Garments",
    9: "Fashion", 10: "Footwear", 11: "Mobile", 12: "Electronics", 13: "Salons",
    14: "Beauty Parlours", 15: "Dry Fruits & Nuts", 16: "Fashion Accessories",
    17: "Optical", 18: "Home Appliances", 19: "Furniture", 20: "Home Furnishing",
    21: "Baby Stores", 22: "Books & Stationery", 23: "Gifts & Fancy Stores",
    24: "Toys & Games", 25: "Sports & Fitness", 26: "Diagnostic Centres",
    27: "Hospitals", 28: "Photography & Studios", 29: "Pet Stores",
    30: "Training Institutes", 31: "Online Stores",
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
    "cafe": 5, "café": 5, "cafés": 5, "coffee": 5, "coffee shop": 5, "coffee shops": 5,
    "bakery and sweets": 6, "bakery": 6, "sweets": 6, "cakes": 6, "sweet shop": 6,
    "juices and shakes": 7, "juices": 7, "juice": 7, "shakes": 7, "juice shop": 7, "milkshakes": 7,
    "garment": 8, "clothing": 8, "clothes": 8, "apparel": 8, "garments & fashion": 8, "garments and fashion": 8,
    "boutique": 9, "dress": 9, "dresses": 9, "fashion wear": 9,
    "footwears": 10, "shoes": 10, "shoe": 10,
    "mobiles": 11, "mobile store": 11, "mobile stores": 11, "mobile & accessories": 11,
    "electronic": 12, "electronics store": 12,
    "salon": 13,
    "beauty parlour": 14, "beauty": 14, "parlour": 14, "parlor": 14, "spa": 14,
    "dry fruits and nuts": 15, "dry fruits": 15, "nuts": 15, "dryfruits": 15,
    "accessories": 16, "fashion accessory": 16,
    "optical store": 17, "optical stores": 17, "optics": 17, "eyewear": 17,
    "appliances": 18, "home appliance": 18, "kitchen appliances": 18,
    "furniture store": 19, "furniture stores": 19,
    "home furnishings": 20, "furnishing": 20, "home decor": 20, "home linen": 20, "curtains": 20,
    "baby": 21, "baby store": 21, "baby products": 21,
    "books and stationery": 22, "books": 22, "book": 22, "stationery": 22, "book store": 22, "bookstore": 22,
    "gifts and fancy stores": 23, "gifts": 23, "gift": 23, "fancy store": 23, "fancy stores": 23, "gift shop": 23,
    "toys and games": 24, "toys": 24, "toy": 24, "games": 24, "toy store": 24,
    "sports and fitness": 25, "sports": 25, "sport": 25, "fitness": 25, "gym": 25,
    "diagnostic centre": 26, "diagnostic center": 26, "diagnostics": 26, "diagnostic": 26, "labs": 26, "lab": 26,
    "hospital": 27, "clinic": 27, "clinics": 27,
    "photography and studios": 28, "photography": 28, "studio": 28, "studios": 28, "photo studio": 28,
    "pets": 29, "pet": 29, "pet store": 29, "pet shop": 29,
    "training institute": 30, "training": 30, "institute": 30, "institutes": 30, "academy": 30, "coaching": 30, "tuition": 30, "training centre": 30, "training center": 30,
    "online store": 31, "online": 31, "ecommerce": 31, "e-commerce": 31,
}


def _norm(s: str) -> str:
    """Fold accents, lowercase, turn '&' into 'and', drop punctuation and
    collapse spaces — so 'Cafés', 'Café' and 'Cafe' all match 'Cafes'."""
    s = unicodedata.normalize("NFKD", str(s or "")).encode("ascii", "ignore").decode("ascii")
    s = s.lower().replace("&", " and ")
    s = re.sub(r"[^a-z0-9]+", " ", s)
    return re.sub(r"\s+", " ", s).strip()


# Normalised lookup built once from the legend names + aliases.
_LOOKUP: Dict[str, int] = {}
for _k, _v in {**_NAME_TO_ID, **_ALIASES}.items():
    _LOOKUP.setdefault(_norm(_k), _v)


def _resolve_one(p: str):
    """Best-effort map ONE category token to an id — tolerant of an extra 's',
    extra words, '&'/'and', reordering and minor punctuation. Returns None only
    when nothing sensible matches."""
    n = _norm(p)
    if not n:
        return None
    if n in _LOOKUP:                       # exact (after normalising)
        return _LOOKUP[n]
    if n.endswith("s") and n[:-1] in _LOOKUP:   # dropped a stray plural 's'
        return _LOOKUP[n[:-1]]
    if (n + "s") in _LOOKUP:                # missing plural 's'
        return _LOOKUP[n + "s"]
    try:                                    # a raw category number
        i = int(float(p))
        if i in CATEGORY_LEGEND:
            return i
    except (ValueError, TypeError):
        pass
    # Extra words / reordering: pick the longest known name whose words all
    # appear in the input (e.g. "fresh fruits and vegetables mart" → id 2).
    tokens = set(n.split())
    best, best_len = None, 0
    for key, cid in _LOOKUP.items():
        if len(key) >= 4 and set(key.split()).issubset(tokens) and len(key) > best_len:
            best, best_len = cid, len(key)
    return best


def parse_categories(value) -> Tuple[List[int], List[str]]:
    """
    Turn a comma/semicolon-separated list of category NAMES into a de-duplicated
    list of ids. Tolerant of common mistakes (extra 's', extra words, '&'/'and').
    Also accepts raw category numbers. Returns (ids, unknown_names).
    """
    ids: List[int] = []
    unknown: List[str] = []
    for part in str(value or "").replace(";", ",").split(","):
        p = part.strip()
        if not p:
            continue
        cid = _resolve_one(p)
        if cid:
            ids.append(cid)
        else:
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
    "Indian Mart", "Supermarkets",
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

    # ── Category dropdown ──────────────────────────────────────────────────────
    # The 28 valid categories live on a small visible "Categories" sheet and are
    # exposed as a NAMED RANGE. A named range is the most reliable way to make an
    # in-cell dropdown appear across Excel versions and Google Sheets (a hidden
    # helper column sometimes won't render the arrow). Manual typing/paste is
    # still allowed (showErrorMessage=False) and the backend tolerates variants.
    cats_ws = wb.create_sheet("Categories")
    cats_ws["A1"] = "Category options — used by the dropdown (do not edit)"
    cats_ws["A1"].font = Font(bold=True, color="1A237E")
    cats_ws.column_dimensions["A"].width = 32
    for idx, cname in enumerate(CATEGORY_LEGEND.values(), start=2):
        cats_ws.cell(row=idx, column=1, value=cname)
    last_row = len(CATEGORY_LEGEND) + 1                 # A2 .. A29 for 28 items
    ref = f"Categories!$A$2:$A${last_row}"

    from openpyxl.workbook.defined_name import DefinedName
    dn = DefinedName("ClaimitCategories", attr_text=ref)
    try:                                                # openpyxl >= 3.1
        wb.defined_names["ClaimitCategories"] = dn
    except TypeError:                                   # openpyxl < 3.1
        wb.defined_names.add(dn)

    cat_col = HEADERS.index("categories") + 1
    cat_letter = get_column_letter(cat_col)
    dv = DataValidation(
        type="list",
        formula1="ClaimitCategories",                  # the named range
        allow_blank=True,
        showErrorMessage=False,                         # dropdown + manual entry
    )
    dv.promptTitle = "Category"
    dv.prompt = "Pick one from the dropdown, or type it manually."
    ws.add_data_validation(dv)
    dv.add(f"{cat_letter}2:{cat_letter}2000")           # whole column, fill-down safe

    # ── Instructions sheet ────────────────────────────────────────────────────
    ins = wb.create_sheet("Instructions")
    ins.column_dimensions["A"].width = 60
    ins.column_dimensions["B"].width = 40
    lines = [
        ("How to use this template", True),
        ("1. Fill one shop per row starting at row 2 (the sample row is an example — overwrite or delete it).", False),
        ("2. name is required. Give at least one category.", False),
        ("3. categories: click the cell and PICK a category from the dropdown arrow", False),
        ("   (no typing — this avoids spelling mistakes; one category per shop).", False),
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
