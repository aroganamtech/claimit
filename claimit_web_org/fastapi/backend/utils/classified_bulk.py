"""
classified_bulk.py — helpers for the admin "Bulk Upload — Local Finds" and
"Bulk Upload — Classifieds" features.

Local Finds and Local Classifieds are two separate products in the app that
happen to SHARE one MongoDB collection (claimit_db.classifieds), told apart
only by the `listing_type` field:

    listing_type = "local_find"  → Local Finds business directory listing
    listing_type = "classified"  → Local Classifieds item / service post

Because they share storage, every write here stamps listing_type explicitly and
every template is built for exactly one of the two. That is what keeps the two
products' data from mixing — get it wrong and a business would show up inside
Classifieds.

Pure helpers only (column spec + template builder). The DB insert + S3 upload
live in routers/admin.py. Image extraction is reused from
shop_bulk.extract_row_images (identical .xlsx drawing format).
"""
from __future__ import annotations

import io
from typing import List, Tuple

import openpyxl
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

# ── Category lists ────────────────────────────────────────────────────────────
# MUST stay in sync with the app's
# claimitapporg/lib/features/classifieds/data/classified_categories.dart:
#   localFindZones            → LOCAL_FIND_CATEGORIES
#   localClassifiedCategories → CLASSIFIED_CATEGORIES
# A category the app doesn't know means the listing never appears under any
# zone/tab in the app.
# These are the values STORED on a listing. They must match LocalFindZone.label
# in the app exactly — a mismatch does not show a wrong name, it makes the
# listing vanish from its zone.
#
# "Entertain" became "Leisure" on 26 Sep 2026, with the listing data re-uploaded
# against the new value. Renaming one of these WITHOUT a re-upload orphans every
# listing already stored under the old name. "Stay" still displays as
# "Stay & Travel" in the app via LocalFindZone.displayLabel — that one is a
# display override, so the stored value below stays "Stay".
LOCAL_FIND_CATEGORIES = [
    "Shop", "Eat", "Beauty", "Health", "Fitness", "Education",
    "Services", "Auto", "Stay", "Leisure", "Finance", "Living",
    # 13th, added at the client's request. New, so its stored value is the
    # full name.
    "Professional Services",
]

# Local Classifieds is the opposite of Local Finder above: a classified ad
# stores the category ID, not the label, because that is what the app's
# category tiles send as ?category= when filtering.
#
# This is a CHANGE of 28 Sep 2026. The importer used to store the label
# ("Buy & Sell") while the app filtered on the id ("buy_sell"), so every
# bulk-uploaded ad was invisible under its own category tile. Ads are being
# re-uploaded against the ids below.
#
# The list was also cut from twelve to five at the client's request; the other
# seven are gone from the app entirely (see classifiedLegacyCategories in
# classified_categories.dart) and a row still using one is now rejected.
CLASSIFIED_CATEGORIES = [
    "buy_sell", "jobs", "services", "property", "community",
]

# What an admin types in the sheet → the id stored on the ad. Covers the
# display label, the id itself, and the obvious near-misses, so a sheet filled
# in by hand does not fail on "Buy and Sell" or "Job".
CLASSIFIED_LABELS = {
    "buy_sell":  "Buy & Sell",
    "jobs":      "Jobs",
    "services":  "Services",
    "property":  "Property",
    "community": "Community",
}

_CLASSIFIED_ALIASES = {
    "buy sell": "buy_sell", "buysell": "buy_sell", "buy": "buy_sell",
    "sell": "buy_sell", "for sale": "buy_sell", "second hand": "buy_sell",
    "job": "jobs", "vacancy": "jobs", "vacancies": "jobs",
    "hiring": "jobs", "employment": "jobs", "recruitment": "jobs",
    "service": "services", "home services": "services",
    "properties": "property", "real estate": "property",
    "realestate": "property", "rent": "property", "flat": "property",
    "communities": "community", "notice": "community",
    "noticeboard": "community", "events": "community",
    "announcement": "community", "announcements": "community",
}

LOCAL_FIND_PLANS = ["free", "standard", "premium"]

VALID_TYPES = ("local_find", "classified")


def categories_for(listing_type: str) -> List[str]:
    return (LOCAL_FIND_CATEGORIES if listing_type == "local_find"
            else CLASSIFIED_CATEGORIES)


def _norm(x: str) -> str:
    return (str(x).strip().lower()
            .replace(" & ", " and ").replace("&", "and")
            .replace("_", " ").replace("-", " "))


def resolve_category(value, listing_type: str) -> str:
    """Excel cell → the value to STORE on the listing, or "" if unknown.

    The two products store different things, which is the whole reason this
    function exists rather than a plain membership test:

      • local_find  → the LABEL  ("Shop"), matching LocalFindZone.label
      • classified  → the ID     ("buy_sell"), matching the app's category tiles

    Matching is case-insensitive and tolerates '&' vs 'and', underscores and
    hyphens, so "Buy & Sell", "buy_sell" and "buy and sell" all land on the
    same id.
    """
    s = str(value or "").strip()
    if not s:
        return ""
    target = _norm(s)

    if listing_type == "local_find":
        for label in LOCAL_FIND_CATEGORIES:
            if _norm(label) == target:
                return label
        return ""

    # Classifieds — accept the id, the display label, or a known variant.
    for cid in CLASSIFIED_CATEGORIES:
        if _norm(cid) == target:
            return cid
    for cid, label in CLASSIFIED_LABELS.items():
        if _norm(label) == target:
            return cid
    return _CLASSIFIED_ALIASES.get(target, "")


# ── Column specs (one per product — they collect different things) ────────────
_LOCAL_FIND_COLUMNS: List[Tuple[str, str, str]] = [
    ("business_name", "business_name", "str"),
    ("category",      "category",      "category"),
    # Referenced BY FILENAME — the admin uploads image files on the bulk page
    # first and types the filename here. Pasting pictures into Excel is
    # unreliable, which is why the shops importer abandoned that approach.
    ("image",         "image",         "str"),
    ("subcategory",   "subcategory",   "str"),
    ("plan",          "plan",          "plan"),
    ("phone",         "user_phone",    "str"),
    ("whatsapp",      "whatsapp",      "str"),
    ("email",         "email",         "str"),
    ("website",       "website",       "str"),
    ("description",   "description",   "str"),
    ("state",         "state",         "str"),
    ("district",      "district",      "str"),
    ("city",          "city",          "str"),
    ("area",          "area",          "str"),
    ("pincode",       "pincode",       "str"),
    ("address",       "address",       "str"),
    ("lat",           "latitude",      "float"),
    ("lng",           "longitude",     "float"),
]

_CLASSIFIED_COLUMNS: List[Tuple[str, str, str]] = [
    ("title",        "title",        "str"),
    ("category",     "category",     "category"),
    # Referenced BY FILENAME — see the note on the Local Finds spec above.
    ("image",        "image",        "str"),
    ("subcategory",  "subcategory",  "str"),
    ("price",        "price",        "float"),
    ("phone",        "user_phone",   "str"),
    ("description",  "description",  "str"),
    ("years_of_exp", "years_of_exp", "int"),
    ("state",        "state",        "str"),
    ("district",     "district",     "str"),
    ("city",         "city",         "str"),
    ("area",         "area",         "str"),
    ("pincode",      "pincode",      "str"),
    ("address",      "address",      "str"),
    ("lat",          "latitude",     "float"),
    ("lng",          "longitude",    "float"),
]


def columns_for(listing_type: str) -> List[Tuple[str, str, str]]:
    return (_LOCAL_FIND_COLUMNS if listing_type == "local_find"
            else _CLASSIFIED_COLUMNS)


def headers_for(listing_type: str) -> List[str]:
    return [c[0] for c in columns_for(listing_type)]


_LF_EXAMPLE = [
    "Green Leaf Organics", "Shop", "greenleaf.jpg", "Grocery", "standard",
    "9000000010", "9000000010", "hello@greenleaf.example", "https://greenleaf.example",
    "Fresh organic produce, millets and cold-pressed oils sourced from local farms.",
    "Tamil Nadu", "Chennai", "Chennai", "Anna Nagar", "600040",
    "45, 3rd Street, Anna Nagar, Chennai - 600040",
    13.0878, 80.2145,
]

_CL_EXAMPLE = [
    "Honda Activa 6G - 2022", "Vehicles", "activa.jpg", "Two Wheelers", 68000,
    "9000000011",
    "Single owner, 12,000 km, insurance valid till 2027, excellent condition.",
    0,
    "Tamil Nadu", "Chennai", "Chennai", "Adyar", "600020",
    "8, Gandhi Nagar, Adyar, Chennai - 600020",
    13.0067, 80.2570,
]

_LF_WIDTHS = [26, 14, 20, 20, 11, 14, 14, 26, 28, 48, 16, 14, 14, 16, 10, 40, 11, 11]
_CL_WIDTHS = [28, 14, 20, 20, 12, 14, 48, 13, 16, 14, 14, 16, 10, 40, 11, 11]


def build_template_bytes(listing_type: str) -> bytes:
    """Styled .xlsx template for ONE product. `listing_type` must be
    'local_find' or 'classified' — it decides the columns, the category
    dropdown and the sheet name, so a Local Finds sheet can't be filled with
    Classifieds data by accident."""
    if listing_type not in VALID_TYPES:
        raise ValueError(f"listing_type must be one of {VALID_TYPES}")

    is_lf = listing_type == "local_find"
    headers = headers_for(listing_type)
    widths = _LF_WIDTHS if is_lf else _CL_WIDTHS
    example = _LF_EXAMPLE if is_lf else _CL_EXAMPLE
    # What the dropdown OFFERS. Local Finder stores its label, so the two are
    # the same string. Classifieds stores an id but an admin should be picking
    # "Buy & Sell", not "buy_sell" — resolve_category() accepts either, so the
    # sheet can stay readable without the importer losing anything.
    cats = ([CLASSIFIED_LABELS[c] for c in CLASSIFIED_CATEGORIES]
            if listing_type == "classified"
            else categories_for(listing_type))
    product = "Local Finds" if is_lf else "Classifieds"

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Local Finds" if is_lf else "Classifieds"

    head_fill = PatternFill("solid", fgColor="1A237E")
    head_font = Font(bold=True, color="FFFFFF", size=11)
    wrap = Alignment(vertical="center", wrap_text=True)

    for i, header in enumerate(headers, start=1):
        c = ws.cell(row=1, column=i, value=header)
        c.fill = head_fill
        c.font = head_font
        c.alignment = Alignment(vertical="center", horizontal="center", wrap_text=True)

    for i, w in enumerate(widths, start=1):
        ws.column_dimensions[get_column_letter(i)].width = w

    for i, val in enumerate(example, start=1):
        ws.cell(row=2, column=i, value=val).alignment = wrap

    ws.row_dimensions[1].height = 34
    ws.freeze_panes = "A2"

    # ── Dropdowns ────────────────────────────────────────────────────────────
    ref_ws = wb.create_sheet("Categories")
    ref_ws["A1"] = "Category options — used by the dropdown (do not edit)"
    ref_ws["A1"].font = Font(bold=True, color="1A237E")
    ref_ws.column_dimensions["A"].width = 32
    for idx, label in enumerate(cats, start=2):
        ref_ws.cell(row=idx, column=1, value=label)

    from openpyxl.workbook.defined_name import DefinedName

    def _named(name: str, ref: str):
        dn = DefinedName(name, attr_text=ref)
        try:
            wb.defined_names[name] = dn
        except TypeError:
            wb.defined_names.add(dn)

    _named("ClaimitCatList", f"Categories!$A$2:$A${len(cats) + 1}")

    def _dropdown(col_header: str, formula: str, title: str, prompt: str):
        letter = get_column_letter(headers.index(col_header) + 1)
        dv = DataValidation(type="list", formula1=formula,
                            allow_blank=True, showErrorMessage=False)
        dv.promptTitle = title
        dv.prompt = prompt
        ws.add_data_validation(dv)
        dv.add(f"{letter}2:{letter}2000")

    _dropdown("category", "ClaimitCatList", "Category",
              "Pick one from the dropdown, or type it manually.")

    if is_lf:
        ref_ws["C1"] = "Plan options"
        ref_ws["C1"].font = Font(bold=True, color="1A237E")
        ref_ws.column_dimensions["C"].width = 16
        for idx, p in enumerate(LOCAL_FIND_PLANS, start=2):
            ref_ws.cell(row=idx, column=3, value=p)
        _named("ClaimitLfPlans", f"Categories!$C$2:$C${len(LOCAL_FIND_PLANS) + 1}")
        _dropdown("plan", "ClaimitLfPlans", "Plan",
                  "free / standard / premium — controls the photo limit.")

    # ── Instructions ─────────────────────────────────────────────────────────
    ins = wb.create_sheet("Instructions")
    ins.column_dimensions["A"].width = 78
    common = [
        (f"How to use this template — {product}", True),
        (f"1. One {'business' if is_lf else 'post'} per row, starting at row 2. "
         "The sample row is an example — overwrite or delete it.", False),
        (f"2. {'business_name' if is_lf else 'title'}, category and phone are REQUIRED. "
         "A row missing any of them is skipped and reported.", False),
        ("3. phone doubles as the row's identity: re-uploading the same phone with the same", False),
        (f"   {'business_name' if is_lf else 'title'} UPDATES that listing instead of duplicating it.", False),
        ("4. category: pick from the dropdown.", False),
        ("5. PHOTOS — do NOT paste pictures into this sheet. Instead:", True),
        ("     a) On the Bulk Upload page use 'Upload photos' FIRST and select all the image files.", False),
        ("     b) In the 'image' column here, type that file's name, e.g. greenleaf.jpg", False),
        ("     c) Then upload this sheet — the photo is matched to the row by its filename.", False),
        ("   Matching ignores case and the extension is optional. A blank image still uploads.", False),
        ("6. lat / lng: REQUIRED. A row without both is rejected. The app finds listings by distance,", False),
        ("   and a listing with no coordinates is never returned by the search — it would upload fine", False),
        ("   and stay invisible to every user. Get them from Google Maps: right-click the shop, then", False),
        ("   click the numbers at the top to copy. First number = lat, second = lng.", False),
    ]
    if is_lf:
        common.append(("7. plan: free / standard / premium (photo limit 1 / 5 / 15).", False))
    common += [
        ("", False),
        (f"This upload writes ONLY to {product} (listing_type = \"{listing_type}\").", True),
        ("It never touches Claimit Select, and never the other of Local Finds / Classifieds.", True),
        ("", False),
        ("Valid categories", True),
    ]
    r = 1
    for text, bold in common:
        c = ins.cell(row=r, column=1, value=text)
        if bold:
            c.font = Font(bold=True, size=12, color="1A237E")
        r += 1
    for label in cats:
        ins.cell(row=r, column=1, value=label)
        r += 1

    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()
