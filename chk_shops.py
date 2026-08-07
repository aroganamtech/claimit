"""Quick check: what image + category the app API returns for each shop,
and whether the first image URL actually loads (HTTP status).
Run on the server:  python3 chk_shops.py
"""
import json
import urllib.request

URL = "http://localhost:8002/shops?limit=50"

data = json.load(urllib.request.urlopen(URL, timeout=10))
shops = data.get("shops", [])
print(f"{len(shops)} shops returned\n")

first_img = ""
for s in shops[:20]:
    img = s.get("image_url") or ""
    if img and not first_img:
        first_img = img
    print(f"- {s.get('name','?'):32} cats={s.get('category_ids')}  "
          f"img={'EMPTY' if not img else img[:60]}")

# Does the first image URL actually load?
if first_img:
    print("\nTesting first image URL...")
    print("FULL URL:", first_img)
    try:
        req = urllib.request.Request(first_img, method="GET")
        with urllib.request.urlopen(req, timeout=15) as r:
            body = r.read()
            ct = r.headers.get("Content-Type", "?")
            print(f"HTTP {r.status}  Content-Type={ct}  bytes={len(body)}")
            if r.status == 200 and body[:3] in (b"\xff\xd8\xff", b"\x89PN", b"GIF", b"RIF"):
                print("=> Looks like a real image. Backend is fully working.")
            else:
                print("=> Loaded but may not be a valid image — check Content-Type/bytes.")
    except Exception as e:
        print(f"=> FAILED to load image: {e}")
        print("   The presigned URL is not fetchable (wrong key / bucket / expiry).")
else:
    print("\nNo image_url on any shop — category pool empty for these categories.")
