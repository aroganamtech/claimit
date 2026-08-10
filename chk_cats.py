"""What category_ids are the uploaded shops actually stored with?
Run on the server:  python3 chk_cats.py
Hits the web backend (8002), which reads the same DB the app uses.
"""
import json
import urllib.request

URL = "http://localhost:8002/shops?limit=100"
data = json.load(urllib.request.urlopen(URL, timeout=10))
shops = data.get("shops", [])
print(f"{len(shops)} shops\n")

# Show every shop's name + category_ids; flag supermarket-named ones.
for s in shops:
    name = s.get("name", "?")
    cats = s.get("category_ids")
    flag = "  <-- SUPERMARKET name" if "super" in name.lower() else ""
    print(f"cats={str(cats):10} {name}{flag}")

# Summary: how many shops per category id
from collections import Counter
c = Counter()
for s in shops:
    for cid in (s.get("category_ids") or []):
        c[cid] += 1
print("\nshops per category_id:", dict(sorted(c.items())))
print("(In the new legend, 1 = Supermarkets, 3 = Pharmacies)")
