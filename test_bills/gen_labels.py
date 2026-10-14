"""
Label-variant bills.

Ramesh's point: the final amount is printed under a different name on every
bill — GRAND TOTAL, NET PAYABLE, FINAL AMOUNT, AMOUNT PAYABLE, BILL AMOUNT.
The extractor must not care which.

Every bill here has the SAME correct answer (257.00) and the same decoys, so
the only variable is the wording of the label. If Textract labels all five as
TOTAL, the algorithm is wording-independent and proven so.

Bill 5 deliberately has NO subtotal and NO tax line — just items and a total —
because plenty of small shops print exactly that.
"""
from PIL import Image, ImageDraw, ImageFont

MONO  = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
MONOB = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"
F = lambda p, s: ImageFont.truetype(p, s)

def make(fname, shop, total_label, with_tax=True, width=700):
    items = [("Toor Dal 1kg", 1, 157.00), ("Sunflower Oil 1L", 1, 88.00)]
    sub = round(sum(q * r for _, q, r in items), 2)
    if with_tax:
        cg = sg = round(sub * 0.025, 2)
        total = round(sub + cg + sg)
        roundoff = round(total - (sub + cg + sg), 2)
    else:
        cg = sg = roundoff = None
        total = 257.00                      # printed directly, no tax breakdown
    cash, img_h = 300.00, 1000
    img = Image.new("RGB", (width, img_h), "white")
    d = ImageDraw.Draw(img); y = 22

    def line(t, f, dy=26, center=False):
        nonlocal y
        if center:
            d.text(((width - d.textlength(t, font=f)) / 2, y), t, font=f, fill="black")
        else:
            d.text((30, y), t, font=f, fill="black")
        y += dy

    def row(l, r, f, dy=30):
        nonlocal y
        d.text((30, y), l, font=f, fill="black")
        d.text((width - 30 - d.textlength(r, font=f), y), r, font=f, fill="black")
        y += dy

    def rule(ch="-"):
        nonlocal y
        d.text((30, y), ch * 56, font=F(MONO, 17), fill="black"); y += 24

    line(shop, F(MONOB, 30), 38, center=True)
    line("22 Bazaar Street, Madurai 625001", F(MONO, 16), 24, center=True)
    line("GSTIN: 33AABCL7788K1Z4", F(MONO, 16), 24, center=True)
    rule("=")
    row("Bill No: 4471", "Date: 13/10/2026", F(MONO, 17), 26)
    row("", "Time: 18:05", F(MONO, 17), 26)
    rule()
    for n, q, r in items:
        row(n, f"{q}  {r:>7.2f}  {q*r:>8.2f}", F(MONO, 17), 32)
    rule()
    if with_tax:
        row("SUBTOTAL", f"{sub:>10.2f}", F(MONO, 18), 30)
        row("CGST 2.5%", f"{cg:>10.2f}", F(MONO, 18), 30)
        row("SGST 2.5%", f"{sg:>10.2f}", F(MONO, 18), 30)
        row("ROUND OFF", f"{roundoff:>+10.2f}", F(MONO, 18), 32)
    rule("=")
    row(total_label, f"{total:>10.2f}", F(MONOB, 24), 38)   # ← the variable
    rule("=")
    row("CASH", f"{cash:>10.2f}", F(MONO, 18), 30)
    row("BALANCE", f"{cash-total:>10.2f}", F(MONO, 18), 32)
    rule()
    line("SAMPLE BILL - FOR SYSTEM TESTING", F(MONO, 13), 20, center=True)

    img.crop((0, 0, width, int(y) + 18)).save(fname, "JPEG", quality=88)
    print(f"{fname:34} label={total_label:<16} answer={total:.2f}"
          f"{'' if with_tax else '   (no subtotal/tax lines)'}")

make("lbl_1_net_payable.jpg",    "LAKSHMI TEST STORES",  "NET PAYABLE")
make("lbl_2_total_amount.jpg",   "AMMAN TEST TRADERS",   "TOTAL AMOUNT")
make("lbl_3_final_amount.jpg",   "VELAN TEST MART",      "FINAL AMOUNT")
make("lbl_4_amount_payable.jpg", "KUMARAN TEST SHOP",    "AMOUNT PAYABLE")
make("lbl_5_bill_amount_notax.jpg","SELVI TEST STORE",   "BILL AMOUNT", with_tax=False)
