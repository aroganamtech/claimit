"""
select_bulk.py — helpers for the admin "Bulk Upload — Claimit Select" feature.

Same shape as shop_bulk.py: the admin downloads a styled .xlsx, fills one
PROFESSIONAL per row (photo pasted into the sheet), and uploads it. Rows are
inserted into claimit_db.select_professionals — the SAME collection the app's
self-registration writes to, with an identical document shape, so a bulk row
and a self-registered professional are indistinguishable to the app.

Kept deliberately separate from Local Finds / Classifieds: Claimit Select has
its own collection, so nothing here can ever touch classifieds data.

This module holds the pure helpers (column spec, template builder). The DB
insert + S3 upload live in routers/admin.py. Image extraction is reused from
shop_bulk.extract_row_images (identical .xlsx drawing format).
"""
from __future__ import annotations

import io
from typing import Dict, List, Tuple

import openpyxl
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

# ── Category id → label ───────────────────────────────────────────────────────
# MUST stay identical to SELECT_CATEGORIES in the app backend
# (fastapi/backend/app/routes/select.py). If these drift, a bulk professional
# gets a category id the app's grid doesn't know, so they'd be invisible.
CATEGORY_LEGEND: Dict[str, str] = {
    "doctors":     "Doctors",
    "lawyers":     "Lawyers",
    "ca_tax":      "CA & Tax",
    "architects":  "Architects",
    "interior":    "Interiors",
    "financial":   "Financial Advisors",
    "business":    "Business Consultants",
    "real_estate": "Real Estate",
    "marketing":   "Marketing Experts",
    "it_ai":       "IT & AI Experts",
    "career":      "Career Consultants",
    "events":      "Event Planners",
}

CATEGORY_NAMES = list(CATEGORY_LEGEND.values())
_LABEL_TO_ID = {v.lower(): k for k, v in CATEGORY_LEGEND.items()}
# Tolerate the team typing a close variant instead of picking the dropdown.
_ALIASES = {
    "doctor": "doctors", "medical": "doctors", "physician": "doctors",
    "lawyer": "lawyers", "advocate": "lawyers", "legal": "lawyers",
    "ca": "ca_tax", "ca and tax": "ca_tax", "tax": "ca_tax",
    "chartered accountant": "ca_tax", "accountant": "ca_tax",
    "architect": "architects",
    "interior": "interior", "interiors": "interior",
    "interior designer": "interior", "interior designers": "interior",
    "financial advisor": "financial", "finance": "financial",
    "financial": "financial", "investment": "financial",
    "business consultant": "business", "business": "business",
    "consultant": "business",
    "realestate": "real_estate", "real estate": "real_estate",
    "property": "real_estate", "realtor": "real_estate",
    "marketing": "marketing", "marketing expert": "marketing",
    "digital marketing": "marketing", "advertising": "marketing",
    "it": "it_ai", "ai": "it_ai", "it and ai": "it_ai",
    "it & ai": "it_ai", "software": "it_ai", "tech": "it_ai",
    "career": "career", "career consultant": "career",
    "career counselling": "career", "hr": "career",
    "event": "events", "event planner": "events",
    "events": "events", "event management": "events",
}

PLANS = ["premium", "standard", "custom"]


def resolve_category(value) -> str:
    """Excel cell → category id, or "" when it can't be resolved."""
    s = str(value or "").strip().lower()
    if not s:
        return ""
    if s in CATEGORY_LEGEND:          # already an id
        return s
    if s in _LABEL_TO_ID:             # exact label
        return _LABEL_TO_ID[s]
    if s in _ALIASES:                 # known variant
        return _ALIASES[s]
    return ""


def split_list(value, limit: int = 12) -> List[str]:
    """'A, B, C' → ['A','B','C'] — used for services and tags."""
    if value is None:
        return []
    parts = [p.strip() for p in str(value).replace(";", ",").split(",")]
    return [p for p in parts if p][:limit]


# ── Column spec ───────────────────────────────────────────────────────────────
# (header, doc field, type)
COLUMNS: List[Tuple[str, str, str]] = [
    ("name",             "name",             "str"),
    ("category",         "category",         "category"),
    # Photo is referenced BY FILENAME, not pasted into the sheet. The admin
    # uploads the image files on the bulk page first; the backend then matches
    # this cell against those uploads. Pasting pictures into Excel is
    # unreliable (they don't survive Google Sheets, and re-anchor on edit),
    # which is why the shops importer abandoned that approach too.
    ("image",            "image",            "str"),
    ("role",             "role",             "str"),
    ("phone",            "phone",            "str"),
    ("email",            "email",            "str"),
    ("experience_years", "experience_years", "int"),
    ("consultation_fee", "consultation_fee", "float"),
    ("plan",             "plan",             "plan"),
    ("services",         "services",         "list"),
    ("tags",             "tags",             "list"),
    ("about",            "about",            "str"),
    ("state",            "state",            "str"),
    ("district",         "district",         "str"),
    ("city",             "city",             "str"),
    ("area",             "area",             "str"),
    ("pincode",          "pincode",          "str"),
    ("address",          "address",          "str"),
    ("lat",              "lat",              "float"),
    ("lng",              "lng",              "float"),
    ("rating",           "rating",           "float"),
    ("review_count",     "review_count",     "int"),
    ("offer_text",       "offer_text",       "str"),
    ("offer_percent",    "offer_percent",    "int"),
    ("offer_valid_till", "offer_valid_till", "str"),
]

HEADERS = [c[0] for c in COLUMNS]

_EXAMPLE_ROW = [
    "Ananya Menon", "Interiors", "ananya.jpg", "Interior Designer",
    "9000000001", "ananya@example.com",
    8, 499, "premium",
    "Home Interiors, Modular Kitchens, Space Planning",
    "Modern, Minimal, Luxury",
    "Ananya creates elegant, functional spaces that reflect your personality.",
    "Tamil Nadu", "Chennai", "Chennai", "Anna Nagar", "600040",
    "12, 2nd Avenue, Anna Nagar, Chennai - 600040",
    13.0850, 80.2101,
    4.9, 126,
    "20% OFF on this week's bookings", 20, "25 Dec 2026",
]

_WIDTHS = [22, 20, 20, 22, 14, 26, 16, 17, 11, 40, 26, 46,
           16, 14, 14, 16, 10, 40, 11, 11, 9, 13, 32, 13, 16]


def build_template_bytes() -> bytes:
    """Styled .xlsx template — Professionals + Categories + Instructions."""
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Professionals"

    head_fill = PatternFill("solid", fgColor="1A237E")
    head_font = Font(bold=True, color="FFFFFF", size=11)
    wrap = Alignment(vertical="center", wrap_text=True)

    for i, header in enumerate(HEADERS, start=1):
        c = ws.cell(row=1, column=i, value=header)
        c.fill = head_fill
        c.font = head_font
        c.alignment = Alignment(vertical="center", horizontal="center", wrap_text=True)

    for i, w in enumerate(_WIDTHS, start=1):
        ws.column_dimensions[get_column_letter(i)].width = w

    for i, val in enumerate(_EXAMPLE_ROW, start=1):
        ws.cell(row=2, column=i, value=val).alignment = wrap

    ws.row_dimensions[1].height = 34
    ws.freeze_panes = "A2"

    # ── Dropdowns via named ranges (most reliable across Excel + Sheets) ──────
    ref_ws = wb.create_sheet("Categories")
    ref_ws["A1"] = "Category options — used by the dropdown (do not edit)"
    ref_ws["A1"].font = Font(bold=True, color="1A237E")
    ref_ws.column_dimensions["A"].width = 32
    for idx, label in enumerate(CATEGORY_NAMES, start=2):
        ref_ws.cell(row=idx, column=1, value=label)

    ref_ws["C1"] = "Plan options"
    ref_ws["C1"].font = Font(bold=True, color="1A237E")
    ref_ws.column_dimensions["C"].width = 16
    for idx, p in enumerate(PLANS, start=2):
        ref_ws.cell(row=idx, column=3, value=p)

    from openpyxl.workbook.defined_name import DefinedName

    def _named(name: str, ref: str):
        dn = DefinedName(name, attr_text=ref)
        try:                                  # openpyxl >= 3.1
            wb.defined_names[name] = dn
        except TypeError:                     # openpyxl < 3.1
            wb.defined_names.add(dn)

    _named("SelectCategories", f"Categories!$A$2:$A${len(CATEGORY_NAMES) + 1}")
    _named("SelectPlans", f"Categories!$C$2:$C${len(PLANS) + 1}")

    def _dropdown(col_header: str, formula: str, title: str, prompt: str):
        letter = get_column_letter(HEADERS.index(col_header) + 1)
        dv = DataValidation(type="list", formula1=formula,
                            allow_blank=True, showErrorMessage=False)
        dv.promptTitle = title
        dv.prompt = prompt
        ws.add_data_validation(dv)
        dv.add(f"{letter}2:{letter}2000")

    _dropdown("category", "SelectCategories", "Category",
              "Pick one from the dropdown, or type it manually.")
    _dropdown("plan", "SelectPlans", "Listing plan",
              "premium ranks above standard. custom = any/free.")

    # ── Instructions ─────────────────────────────────────────────────────────
    ins = wb.create_sheet("Instructions")
    ins.column_dimensions["A"].width = 76
    lines = [
        ("How to use this template — Claimit Select", True),
        ("1. One PROFESSIONAL per row, starting at row 2. The sample row is an example — overwrite or delete it.", False),
        ("2. name, category and phone are REQUIRED. A row missing any of them is skipped and reported.", False),
        ("3. phone doubles as the row's identity: re-uploading the same phone UPDATES that professional", False),
        ("   instead of creating a duplicate, so you can safely fix a sheet and upload it again.", False),
        ("4. category: pick from the dropdown (12 Claimit Select categories).", False),
        ("5. plan: premium / standard / custom. Premium listings rank above Standard everywhere in the app.", False),
        ("6. services and tags: comma-separated, e.g. 'Home Interiors, Modular Kitchens'.", False),
        ("7. PHOTOS — do NOT paste pictures into this sheet. Instead:", True),
        ("     a) On the Bulk Upload page, use 'Upload photos' FIRST and select all the image files.", False),
        ("     b) In the 'image' column here, type that file's name, e.g. ananya.jpg", False),
        ("     c) Then upload this sheet. The photo is matched to the row by its filename.", False),
        ("   The name is matched ignoring case, and the extension is optional ('ananya' also works).", False),
        ("   Rows with a blank image still upload — the app just shows a placeholder avatar.", False),
        ("8. lat / lng: optional map coordinates. Filling them makes the professional appear in 'Nearby'", False),
        ("   with a real distance; without them they still list, just without a distance.", False),
        ("9. consultation_fee is what the professional charges customers — Claimit does not collect it.", False),
        ("", False),
        ("This upload writes ONLY to Claimit Select. It never touches Local Finds or Classifieds.", True),
        ("", False),
        ("Valid categories", True),
    ]
    r = 1
    for text, bold in lines:
        c = ins.cell(row=r, column=1, value=text)
        if bold:
            c.font = Font(bold=True, size=12, color="1A237E")
        r += 1
    for label in CATEGORY_NAMES:
        ins.cell(row=r, column=1, value=label)
        r += 1

    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()
