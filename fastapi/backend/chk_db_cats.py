"""Show the category_ids actually stored on the shops the app reads.
Run in fastapi/backend (same venv as run.py):  python chk_db_cats.py
"""
import asyncio
import collections
from motor.motor_asyncio import AsyncIOMotorClient
from app.config import get_settings

NEW = {1:"Supermarkets",2:"Fruits & Vegetables",3:"Pharmacies",4:"Restaurants",
       5:"Cafes",6:"Bakery & Sweets",7:"Juices & Shakes",8:"Garments & Fashion",
       9:"Footwear",10:"Mobile",11:"Electronics",12:"Salons",13:"Beauty Parlours",
       14:"Dry Fruits & Nuts",15:"Fashion Accessories",16:"Optical",17:"Home Appliances",
       18:"Furniture",19:"Home Furnishing",20:"Baby Stores",21:"Books & Stationery",
       22:"Gifts & Fancy",23:"Toys & Games",24:"Sports & Fitness",25:"Photography & Studios",
       26:"Diagnostic Centres",27:"Hospitals",28:"Pet Stores"}


async def main():
    s = get_settings()
    c = AsyncIOMotorClient(s.mongodb_url)
    db = c[s.database_name]
    total = await db.shops.count_documents({})
    print(f"DB: {s.database_name}.shops  total={total}\n")

    cnt = collections.Counter()
    supers, salons, missing = [], [], 0
    docs = await db.shops.find({}, {"name": 1, "category_ids": 1}).to_list(length=2000)
    for d in docs:
        cids = d.get("category_ids") or []
        if not cids:
            missing += 1
        for x in cids:
            cnt[x] += 1
        nm = (d.get("name") or "")
        low = nm.lower()
        if "super" in low:
            supers.append((nm, cids))
        if "salon" in low:
            salons.append((nm, cids))

    print("category_id -> count (name in NEW legend):")
    for cid in sorted(cnt):
        print(f"  {cid:>2} {NEW.get(cid,'?'):24} {cnt[cid]}")
    print(f"\nshops with NO category_ids: {missing}")

    print("\nSupermarket-named shops -> stored category_ids (should be [1]):")
    for nm, cids in supers[:15]:
        print(f"   {cids}  {nm}")
    print("\nSalon-named shops -> stored category_ids (should be [12]):")
    for nm, cids in salons[:15]:
        print(f"   {cids}  {nm}")


if __name__ == "__main__":
    asyncio.run(main())
