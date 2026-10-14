"""
Generate test bill images for the Textract extraction.

Deliberately built around the client's ₹257 failure: each bill prints several
numbers that LOOK like a total — subtotal, CGST, SGST, round-off, cash
tendered, change due — so if the extractor picks the wrong one you see it
immediately instead of after a customer complains.

Shop names are invented and each image is marked as a sample, so these can
never be mistaken for a genuine merchant's bill.
"""
from PIL import Image, ImageDraw, ImageFont

MONO  = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
MONOB = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"

def f(path, size):
    return ImageFont.truetype(path, size)

def bill(fname, shop, addr, gst, items, pay_label="CASH", pay=None,
         width=700, scale=1.0, note="SAMPLE BILL - FOR SYSTEM TESTING"):
    sub = round(sum(q * r for _, q, r in items), 2)
    cgst = round(sub * 0.025, 2)
    sgst = round(sub * 0.025, 2)
    raw = sub + cgst + sgst
    total = round(raw)                      # round-off, as Indian bills do
    roundoff = round(total - raw, 2)
    pay = pay if pay is not None else (int(total // 100) + 1) * 100
    change = round(pay - total, 2)

    H = 900 + len(items) * 40     # over-tall; cropped to content below
    img = Image.new("RGB", (width, H), "white")
    d = ImageDraw.Draw(img)
    y = 22

    def line(txt, font, dy=26, center=False, x=30):
        nonlocal y
        if center:
            w = d.textlength(txt, font=font)
            d.text(((width - w) / 2, y), txt, font=font, fill="black")
        else:
            d.text((x, y), txt, font=font, fill="black")
        y += dy

    def row(left, right, font, dy=30):
        nonlocal y
        d.text((30, y), left, font=font, fill="black")
        w = d.textlength(right, font=font)
        d.text((width - 30 - w, y), right, font=font, fill="black")
        y += dy

    def rule(ch="-"):
        nonlocal y
        d.text((30, y), ch * 56, font=f(MONO, 17), fill="black")
        y += 24

    line(shop, f(MONOB, 30), 38, center=True)
    line(addr, f(MONO, 16), 24, center=True)
    line(f"GSTIN: {gst}", f(MONO, 16), 22, center=True)
    line("Phone: 044-2222 0000", f(MONO, 15), 26, center=True)
    rule("=")
    row("Bill No: INV-2026-00847", "", f(MONO, 17), 26)
    row("Date: 13/10/2026", "Time: 15:42", f(MONO, 17), 26)
    rule()
    row("ITEM", "QTY  RATE    AMOUNT", f(MONOB, 16), 28)
    rule()
    for name, qty, rate in items:
        amt = round(qty * rate, 2)
        row(name[:22], f"{qty:>3}  {rate:>6.2f}  {amt:>8.2f}", f(MONO, 17), 32)
    rule()
    # ── The decoys. Every one of these is a number that must NOT be chosen. ──
    row("SUBTOTAL", f"{sub:>10.2f}", f(MONO, 18), 30)
    row("CGST  2.5%", f"{cgst:>10.2f}", f(MONO, 18), 30)
    row("SGST  2.5%", f"{sgst:>10.2f}", f(MONO, 18), 30)
    row("ROUND OFF", f"{roundoff:>+10.2f}", f(MONO, 18), 32)
    rule("=")
    # ── The only correct answer ──────────────────────────────────────────────
    row("GRAND TOTAL", f"{total:>10.2f}", f(MONOB, 24), 38)
    rule("=")
    row(pay_label, f"{pay:>10.2f}", f(MONO, 18), 30)
    row("CHANGE DUE", f"{change:>10.2f}", f(MONO, 18), 32)
    rule()
    line("Thank you! Visit again", f(MONO, 16), 24, center=True)
    line(note, f(MONO, 13), 20, center=True)

    # Crop to what was actually drawn, plus a margin. Sizing from a formula
    # is how GRAND TOTAL got cut off; measuring the real cursor cannot.
    img = img.crop((0, 0, width, min(H, int(y) + 18)))
    if scale != 1.0:
        w2, h2 = img.size
        img = img.resize((int(w2 * scale), int(h2 * scale)), Image.LANCZOS)
    img.save(fname, "JPEG", quality=88)
    print(f"{fname:34} GRAND TOTAL = {total:.2f}   "
          f"(decoys: sub={sub:.2f} cash={pay:.2f} change={change:.2f})")
    return total

# ── Bill 1 — the ₹257 case, exactly the client's example ────────────────────
bill("bill_1_total_257.jpg",
     "QUICKMART TEST STORE", "12 Anna Nagar Main Road, Chennai 600040",
     "33AABCT1234D1ZV",
     [("Toor Dal 1kg", 1, 157.00), ("Sunflower Oil 1L", 1, 88.00)],
     pay=300.00)

# ── Bill 2 — larger amount, Indian lakh grouping territory ──────────────────
bill("bill_2_large_amount.jpg",
     "DEMO ELECTRONICS MART", "45 Ritherdon Road, Vepery, Chennai 600007",
     "33AAGCD5678E1Z9",
     [("LED TV 43 inch", 1, 24990.00), ("HDMI Cable 2m", 2, 349.00),
      ("Wall Mount Bracket", 1, 1299.00)],
     pay_label="CARD", pay=28500.00)

# ── Bill 3 — small restaurant bill, tip line as an extra decoy ──────────────
bill("bill_3_total_257_restaurant.jpg",
     "TEST TIFFIN CENTRE", "8 Gandhi Street, Madurai 625001",
     "33AACTT9012F1Z3",
     [("Masala Dosa", 2, 70.00), ("Filter Coffee", 2, 30.00),
      ("Idli Plate", 1, 45.00)],
     pay=300.00)
