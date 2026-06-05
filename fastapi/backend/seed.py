"""
seed.py — Populate MongoDB with dynamic data for Claimit.

HOW TO RUN (from fastapi/backend/ folder):
    python seed.py

Images are uploaded to AWS S3 (bucket: claimit-image-bucket).
AWS credentials are read from .env:
  AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, AWS_STORAGE_BUCKET_NAME

WHAT IT DOES:
  1. Reads shop images from  uploads/shop_images/img1.jpg … img20.jpg
     and uploads them to S3. Stores s3_key + public URL in MongoDB.
  2. Inserts 20 shops with categories, discounts, rewards, redeem flags.
  3. Inserts deals (nearby + brand groups).
  4. Inserts rewards (loyalty points offers) for each shop.
  5. Clears old data before inserting fresh seed.

IMAGES:
  • Drop your real images as  uploads/shop_images/img1.jpg … img20.jpg
    before running this script. They will be uploaded to S3 automatically.
  • If an image file is missing, a coloured placeholder is auto-generated
    and uploaded to S3.
"""

import asyncio
import base64
import io
import os
import sys
import uuid
from datetime import datetime, timezone, timedelta

import boto3
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

load_dotenv()

MONGO_URL  = os.getenv("MONGODB_URL",           "mongodb://localhost:27017")
DB_NAME    = os.getenv("DATABASE_NAME",          "claimit_db")
IMAGE_DIR  = os.path.join(os.path.dirname(__file__), "uploads", "shop_images")

# ── S3 config ─────────────────────────────────────────────────────────────────
_AWS_KEY    = os.getenv("AWS_ACCESS_KEY_ID",       "")
_AWS_SECRET = os.getenv("AWS_SECRET_ACCESS_KEY",   "")
_AWS_REGION = os.getenv("AWS_REGION",              "eu-north-1")
_BUCKET     = os.getenv("AWS_STORAGE_BUCKET_NAME", "claimit-image-bucket")

def _s3():
    return boto3.client("s3", region_name=_AWS_REGION,
                        aws_access_key_id=_AWS_KEY,
                        aws_secret_access_key=_AWS_SECRET)

def _s3_url(key: str) -> str:
    return f"https://{_BUCKET}.s3.{_AWS_REGION}.amazonaws.com/{key}"


# ─────────────────────────────────────────────────────────────────────────────
# Helper: read/generate image bytes (JPEG), upload to S3, return (s3_key, url)
# ─────────────────────────────────────────────────────────────────────────────

def _upload_image_to_s3(image_name: str,
                        max_size: tuple = (480, 360),
                        quality: int = 65) -> tuple:
    """
    Read uploads/shop_images/<image_name>, resize, compress, upload to S3.
    Returns (s3_key, public_url).  Falls back to placeholder if file missing.
    """
    from PIL import Image, ImageDraw

    path = os.path.join(IMAGE_DIR, image_name)
    try:
        if os.path.exists(path):
            img = Image.open(path).convert("RGB")
        else:
            idx = int("".join(filter(str.isdigit, image_name)) or "1")
            palette = [
                (76, 175, 80), (33, 150, 243), (255, 152, 0), (244, 67, 54),
                (156, 39, 176), (0, 188, 212), (255, 193, 7), (96, 125, 139),
                (121, 85, 72), (63, 81, 181), (0, 150, 136), (233, 30, 99),
                (205, 220, 57), (255, 87, 34), (103, 58, 183), (3, 169, 244),
                (139, 195, 74), (255, 235, 59), (121, 134, 203), (129, 199, 132),
            ]
            color = palette[(idx - 1) % len(palette)]
            img = Image.new("RGB", (400, 300), color=color)
            draw = ImageDraw.Draw(img)
            draw.rectangle([20, 110, 380, 190], fill=(255, 255, 255))

        img.thumbnail(max_size, Image.LANCZOS)
        buf = io.BytesIO()
        img.save(buf, "JPEG", quality=quality, optimize=True)
        data = buf.getvalue()

        key = f"shops/{uuid.uuid4().hex}.jpg"
        _s3().put_object(Bucket=_BUCKET, Key=key, Body=data, ContentType="image/jpeg")
        return key, _s3_url(key)

    except Exception as e:
        print(f"     ⚠️  Image upload error ({image_name}): {e}")
        return "", ""


# ─────────────────────────────────────────────────────────────────────────────
# Seed data definitions
# ─────────────────────────────────────────────────────────────────────────────

# DISCOUNT FIELD NOTES:
#   "discount"  → Redeem discount % shown as "X% Discount + 1% Cashback"
#                 on all Redeem shop cards and detail pages.
#                 The 1% Cashback is static (hardcoded in the Flutter app).
#                 Example: discount=30 → displays "30% Discount + 1% Cashback"
#   "has_redeem": True  → shop appears in the Redeem zone with discount offer
#   "has_rewards": True → shop appears in the Rewards/loyalty zone

# Category ID map (mirrors Flutter ShopCategory IDs):
#  1=New deals  2=Groceries  3=Supermarket  4=Pharmacy  5=Salon
#  6=Gym  7=Restaurant  8=Cafes  9=Clothing  10=Department
# 11=Electronics  12=Books  13=Toys  14=Baby  15=Home Decor
# 16=Furniture  17=Spa  18=Schools  19=Colleges  20=Tutoring
# 21=Clinics  22=Hospitals  23=Pets  24=Sports  25=Travel
# 26=Mobile & Accessories  27=Computer & Laptop  28=Gifts  29=Jewellery  30=Shoes

SHOPS_SEED = [
    {
        "name": "Indian Mart",
        "location": "Padi, Chennai",
        "category_ids": [1, 2, 3],
        "discount": 30,
        "rating": 4.2,
        "added_days_ago": 2,
        "image_name": "img1.jpg",
        "image_names": ["img1.jpg", "img2.jpeg", "img3.jpeg"],
        "has_rewards": False,
        "has_redeem": True,
        "about": "Indian Mart is your one-stop neighbourhood store in Padi, offering a wide range of fresh groceries, daily essentials, and household items. Known for competitive prices and friendly service, the store has been serving the local community for over a decade. Claimit members enjoy exclusive redeem discounts on every visit.",
        "address": "89, Industrial Estate, Padi, Chennai - 600050",
        "timing": "Daily: 8am – 9pm",
        "phone": "+91 44 2651 1234",
        "lat": 13.1197,
        "lng": 80.2183,
    },
    {
        "name": "Annachi Supermarket",
        "location": "Padi, Chennai",
        "category_ids": [2, 3],
        "discount": 20,
        "rating": 3.8,
        "added_days_ago": 5,
        "image_name": "img2.jpeg",
        "image_names": ["img2.jpeg", "img4.jpeg", "img6.jpeg"],
        "has_rewards": True,
        "has_redeem": False,
        "about": "Annachi Supermarket has been a trusted grocery destination in Padi for years. With a sprawling store packed with fresh produce, packaged foods, and daily needs, it caters to families looking for quality at affordable prices. Earn reward points and enjoy Claimit redeem benefits on every purchase.",
        "address": "12, 3rd Street, Padi, Chennai - 600050",
        "timing": "Daily: 7am – 10pm",
        "phone": "+91 98400 22222",
        "lat": 13.1197,
        "lng": 80.2183,
    },
    {
        "name": "Fresh Basket",
        "location": "Anna Nagar, Chennai",
        "category_ids": [2, 3],
        "discount": 15,
        "rating": 4.0,
        "added_days_ago": 3,
        "image_name": "img3.jpeg",
        "image_names": ["img3.jpeg", "img5.jpeg", "img7.jpeg"],
        "has_rewards": True,
        "has_redeem": False,
        "about": "Fresh Basket in Anna Nagar brings farm-fresh produce and organic groceries directly to your neighbourhood. Committed to quality and freshness, the store sources vegetables and fruits daily from local farms. Claimit loyalty members earn reward points redeemable for future savings.",
        "address": "45, 6th Avenue, Anna Nagar, Chennai - 600040",
        "timing": "Daily: 6am – 10pm",
        "phone": "+91 98765 33333",
        "lat": 13.0839,
        "lng": 80.2101,
    },
    {
        "name": "Nilgiris",
        "location": "T. Nagar, Chennai",
        "category_ids": [2, 3, 4],
        "discount": 10,
        "rating": 4.3,
        "added_days_ago": 7,
        "image_name": "img4.jpeg",
        "image_names": ["img4.jpeg", "img6.jpeg", "img1.jpg"],
        "has_rewards": False,
        "has_redeem": True,
        "about": "Nilgiris is one of South India's oldest and most-trusted retail chains, renowned for its quality dairy products, bakery items, and supermarket range. The T. Nagar outlet offers a premium shopping experience with a wide selection of groceries, health foods, and personal care essentials. Claimit members unlock exclusive redeem savings here.",
        "address": "140, Usman Road, T. Nagar, Chennai - 600017",
        "timing": "Daily: 9am – 9pm",
        "phone": "+91 44 2434 9999",
        "lat": 13.035,
        "lng": 80.2337,
    },
    {
        "name": "MedPlus Pharmacy",
        "location": "Porur, Chennai",
        "category_ids": [4],
        "discount": 10,
        "rating": 4.3,
        "added_days_ago": 1,
        "image_name": "img5.jpeg",
        "image_names": ["img5.jpeg", "img7.jpeg", "img2.jpeg"],
        "has_rewards": False,
        "has_redeem": True,
        "about": "MedPlus is India's second-largest pharmacy chain, offering genuine medicines, health supplements, and personal care products at the best prices. The Porur branch is staffed by qualified pharmacists available for consultation. Claimit members enjoy additional discounts and loyalty rewards on every medical purchase.",
        "address": "7, Arcot Road, Porur, Chennai - 600116",
        "timing": "Daily: 8am – 10pm",
        "phone": "+91 1800 102 6454",
        "lat": 13.0359,
        "lng": 80.1577,
    },
    {
        "name": "Apollo Pharmacy",
        "location": "Velachery, Chennai",
        "category_ids": [4],
        "discount": 12,
        "rating": 4.5,
        "added_days_ago": 4,
        "image_name": "img6.jpeg",
        "image_names": ["img6.jpeg", "img1.jpg", "img3.jpeg"],
        "has_rewards": True,
        "has_redeem": False,
        "about": "Apollo Pharmacy, part of the renowned Apollo Hospitals group, is committed to making quality healthcare accessible and affordable. The Velachery outlet stocks a comprehensive range of branded and generic medicines, wellness products, and baby care items. Claimit members benefit from reward points and redeem discounts on every visit.",
        "address": "100 Feet Road, Velachery, Chennai - 600042",
        "timing": "Daily: 8am – 11pm",
        "phone": "+91 1800 180 0104",
        "lat": 12.979,
        "lng": 80.2181,
    },
    {
        "name": "Naturals Salon",
        "location": "Nungambakkam, Chennai",
        "category_ids": [5, 17],
        "discount": 30,
        "rating": 4.4,
        "added_days_ago": 3,
        "image_name": "img7.jpeg",
        "image_names": ["img7.jpeg", "img2.jpeg", "img5.jpeg"],
        "has_rewards": False,
        "has_redeem": True,
        "about": "Naturals Salon is one of India's leading unisex salon chains known for professional hair care, skin treatments, and spa services. The Nungambakkam studio employs certified stylists using international-grade products. Whether it's a haircut, facial, or a complete makeover, Claimit members enjoy premium services at exclusive discounted rates.",
        "address": "22, Khader Nawaz Khan Rd, Nungambakkam, Chennai - 600006",
        "timing": "Daily: 9am – 8pm",
        "phone": "+91 44 4390 1234",
        "lat": 13.0569,
        "lng": 80.2425,
    },
    {
        "name": "Green Trends Salon",
        "location": "Adyar, Chennai",
        "category_ids": [5, 17],
        "discount": 25,
        "rating": 4.1,
        "added_days_ago": 6,
        "image_name": "img8.jpeg",
        "image_names": ["img8.jpeg", "img3.jpeg", "img6.jpeg"],
        "has_rewards": True,
        "has_redeem": False,
        "about": "Green Trends is a premium unisex salon chain celebrated for its eco-friendly products and expert styling. The Adyar branch offers hair cutting, colouring, skin care, and bridal packages in a relaxed and hygienic environment. Claimit loyalty members earn points on every service for future rewards.",
        "address": "16, 4th Main Road, Adyar, Chennai - 600020",
        "timing": "Daily: 10am – 8pm",
        "phone": "+91 98400 88888",
        "lat": 13.0012,
        "lng": 80.2565,
    },
    {
        "name": "Fitness First",
        "location": "Velachery, Chennai",
        "category_ids": [6, 24],
        "discount": 50,
        "rating": 4.6,
        "added_days_ago": 1,
        "image_name": "img8.jpeg",
        "image_names": ["img8.jpeg", "img4.jpeg", "img1.jpg"],
        "has_rewards": False,
        "has_redeem": True,
        "about": "Fitness First is a world-class gym and wellness centre equipped with state-of-the-art cardio machines, free weights, and dedicated zones for yoga and functional training. The Velachery facility features certified personal trainers, group fitness classes, and modern locker rooms. Claimit members get the biggest savings with 50% discount on memberships.",
        "address": "100 Feet Road, Velachery, Chennai - 600042",
        "timing": "Mon–Sat: 5am – 11pm | Sun: 6am – 9pm",
        "phone": "+91 98400 55555",
        "lat": 12.979,
        "lng": 80.2181,
    },
    {
        "name": "Cult.fit",
        "location": "Koramangala, Chennai",
        "category_ids": [6, 24],
        "discount": 40,
        "rating": 4.7,
        "added_days_ago": 2,
        "image_name": "img4.jpeg",
        "image_names": ["img4.jpeg", "img8.jpeg", "img2.jpeg"],
        "has_rewards": True,
        "has_redeem": False,
        "about": "Cult.fit is India's leading fitness and wellness platform offering a wide variety of workout formats — from HIIT and boxing to yoga and dance — all under one roof. The Koramangala centre features expert coaches, live-streamed classes, and an in-centre cafe. Claimit members enjoy 40% redeem discount and loyalty rewards on memberships.",
        "address": "12, 3rd Cross, Koramangala, Chennai",
        "timing": "Mon–Sun: 5am – 11pm",
        "phone": "+91 98400 77777",
        "lat": 12.9352,
        "lng": 77.6245,
    },
    {
        "name": "KFC",
        "location": "Anna Nagar, Chennai",
        "category_ids": [7, 1],
        "discount": 20,
        "rating": 4.2,
        "added_days_ago": 3,
        "image_name": "img2.jpeg",
        "image_names": ["img2.jpeg", "img5.jpeg", "img8.jpeg"],
        "has_rewards": False,
        "has_redeem": True,
        "about": "KFC (Kentucky Fried Chicken) is the world's most popular chicken restaurant chain, famous for its Original Recipe® fried chicken made with a unique blend of 11 herbs and spices. The Anna Nagar outlet serves a full menu including burgers, wraps, rice bowls, and desserts. Claimit members enjoy 20% off on every dine-in or takeaway order.",
        "address": "3rd Avenue, Anna Nagar, Chennai - 600040",
        "timing": "Daily: 11am – 11pm",
        "phone": "+91 98765 11111",
        "lat": 13.0839,
        "lng": 80.2101,
    },
    {
        "name": "Domino's Pizza",
        "location": "Padi, Chennai",
        "category_ids": [7],
        "discount": 15,
        "rating": 4.0,
        "added_days_ago": 5,
        "image_name": "img3.jpeg",
        "image_names": ["img3.jpeg", "img6.jpeg", "img1.jpg"],
        "has_rewards": True,
        "has_redeem": False,
        "about": "Domino's Pizza is renowned for delivering hot, fresh pizzas to your doorstep in 30 minutes or less. The Padi outlet offers a wide selection of pizzas, pasta, garlic bread, and beverages in both classic and innovative flavours. Claimit members can redeem 15% off on dine-in orders and earn reward points for home delivery.",
        "address": "45, Industrial Estate, Padi, Chennai - 600050",
        "timing": "Daily: 11am – 11:30pm",
        "phone": "+91 1800 208 1234",
        "lat": 13.1197,
        "lng": 80.2183,
    },
    {
        "name": "Indian Coffee House",
        "location": "Egmore, Chennai",
        "category_ids": [8],
        "discount": 10,
        "rating": 4.3,
        "added_days_ago": 4,
        "image_name": "img1.jpeg",
        "image_names": ["img1.jpeg", "img4.jpeg", "img7.jpeg"],
        "has_rewards": False,
        "has_redeem": True,
        "about": "Indian Coffee House is a legendary café chain with a history spanning over 70 years, beloved for its authentic filter coffee, dosas, and wholesome South Indian meals. The Egmore branch retains the classic charm of the original cooperative-run outlets, offering a no-frills yet flavourful dining experience. Claimit members enjoy a straight 10% redeem discount.",
        "address": "Cathedral Road, Egmore, Chennai - 600008",
        "timing": "Daily: 7am – 9pm",
        "phone": "+91 44 2811 5678",
        "lat": 13.0782,
        "lng": 80.2603,
    },
    {
        "name": "Brew & Bite Café",
        "location": "Besant Nagar, Chennai",
        "category_ids": [8, 7],
        "discount": 20,
        "rating": 4.5,
        "added_days_ago": 1,
        "image_name": "img4.jpeg",
        "image_names": ["img4.jpeg", "img7.jpeg", "img3.jpeg"],
        "has_rewards": True,
        "has_redeem": False,
        "about": "Brew & Bite Café is a cosy artisan café in the heart of Besant Nagar, known for its hand-crafted single-origin coffee, freshly baked pastries, and all-day brunch menu. The relaxed beach-facing ambience makes it a favourite spot for students, professionals, and families alike. Claimit members enjoy 20% off and earn loyalty points on every visit.",
        "address": "2nd Avenue, Besant Nagar, Chennai - 600090",
        "timing": "Daily: 8am – 10pm",
        "phone": "+91 98400 14141",
        "lat": 12.9997,
        "lng": 80.2705,
    },
    {
        "name": "Shoppers Stop",
        "location": "Nungambakkam, Chennai",
        "category_ids": [9, 10, 28, 29, 30],
        "discount": 25,
        "rating": 4.3,
        "added_days_ago": 6,
        "image_name": "img5.jpeg",
        "image_names": ["img5.jpeg", "img1.jpg", "img8.jpeg"],
        "has_rewards": False,
        "has_redeem": True,
        "about": "Shoppers Stop is one of India's premier fashion and lifestyle department stores, offering a carefully curated mix of international and Indian brands across clothing, accessories, beauty, and home décor. The Nungambakkam store provides a world-class shopping experience with in-store stylists and exclusive brand events. Claimit members enjoy 25% redeem savings and loyalty rewards.",
        "address": "Khader Nawaz Khan Rd, Nungambakkam, Chennai - 600006",
        "timing": "Daily: 10am – 10pm",
        "phone": "+91 44 4215 6789",
        "lat": 13.0569,
        "lng": 80.2425,
    },
    {
        "name": "Lifestyle",
        "location": "Anna Nagar, Chennai",
        "category_ids": [9, 10, 30],
        "discount": 20,
        "rating": 4.4,
        "added_days_ago": 4,
        "image_name": "img6.jpeg",
        "image_names": ["img6.jpeg", "img2.jpeg", "img4.jpeg"],
        "has_rewards": True,
        "has_redeem": False,
        "about": "Lifestyle is a leading fashion retail destination bringing the latest trends in clothing, footwear, accessories, and home furnishings to Chennai. The Anna Nagar outlet stocks brands across every budget and style — from casual wear to formal collections. Claimit loyalty members accumulate reward points that can be redeemed for exciting discounts.",
        "address": "5th Avenue, Anna Nagar, Chennai - 600040",
        "timing": "Daily: 10am – 9pm",
        "phone": "+91 44 4215 4567",
        "lat": 13.0839,
        "lng": 80.2101,
    },
    {
        "name": "Poorvika Mobiles",
        "location": "T. Nagar, Chennai",
        "category_ids": [11, 26],
        "discount": 8,
        "rating": 4.1,
        "added_days_ago": 2,
        "image_name": "img7.jpeg",
        "image_names": ["img7.jpeg", "img3.jpeg", "img5.jpeg"],
        "has_rewards": True,
        "has_redeem": False,
        "about": "Poorvika Mobiles is South India's largest mobile retail chain, offering the widest range of smartphones, tablets, accessories, and wearables at competitive prices. The T. Nagar flagship store provides expert guidance, hands-on demos, and EMI options. Claimit members benefit from an additional 8% redeem discount plus loyalty reward points.",
        "address": "110, Usman Road, T. Nagar, Chennai - 600017",
        "timing": "Daily: 10am – 9pm",
        "phone": "+91 44 4218 1111",
        "lat": 13.035,
        "lng": 80.2337,
    },
    {
        "name": "Croma",
        "location": "Anna Nagar, Chennai",
        "category_ids": [11, 26, 27],
        "discount": 15,
        "rating": 4.2,
        "added_days_ago": 3,
        "image_name": "img1.jpeg",
        "image_names": ["img1.jpeg", "img5.jpeg", "img6.jpeg"],
        "has_rewards": False,
        "has_redeem": True,
        "about": "Croma, a Tata enterprise, is India's first large-format specialist retail store for consumer electronics and durables. The Anna Nagar outlet stocks everything from televisions and laptops to smart home devices and kitchen appliances, all backed by Tata's assurance of quality and after-sales support. Claimit members get 15% off and earn reward points.",
        "address": "Plot 5, 5th Avenue, Anna Nagar, Chennai - 600040",
        "timing": "Mon–Sat: 9am – 9pm",
        "phone": "+91 98400 18181",
        "lat": 13.0839,
        "lng": 80.2101,
    },
    {
        "name": "Landmark Books",
        "location": "Nungambakkam, Chennai",
        "category_ids": [12, 13],
        "discount": 12,
        "rating": 4.6,
        "added_days_ago": 5,
        "image_name": "img1.jpeg",
        "image_names": ["img1.jpeg", "img7.jpeg", "img4.jpeg"],
        "has_rewards": True,
        "has_redeem": False,
        "about": "Landmark is India's most beloved books-and-music retail chain, housing an impressive collection of books across every genre, stationery, educational toys, and musical instruments. The Spencer Plaza outlet is a cultural hub for readers and learners of all ages. Claimit members enjoy 12% redeem savings and accumulate reward points with every purchase.",
        "address": "Spencer Plaza, Anna Salai, Chennai - 600002",
        "timing": "Daily: 10am – 9pm",
        "phone": "+91 44 4205 9595",
        "lat": 13.0569,
        "lng": 80.2425,
    },
    {
        "name": "Smile Dentist",
        "location": "Padi, Chennai",
        "category_ids": [21, 22],
        "discount": 25,
        "rating": 4.5,
        "added_days_ago": 7,
        "image_name": "img3.jpeg",
        "image_names": ["img3.jpeg", "img8.jpeg", "img6.jpeg"],
        "has_rewards": False,
        "has_redeem": True,
        "about": "Smile Dentist is a modern multi-specialty dental clinic offering comprehensive oral care including general dentistry, orthodontics, cosmetic procedures, implants, and dental surgery. The Padi clinic is equipped with the latest digital X-ray and pain-free treatment technology. Claimit members receive a 25% discount on all consultations and treatments.",
        "address": "12, 3rd Street, Padi, Chennai - 600050",
        "timing": "Mon–Sat: 9am – 8pm",
        "phone": "+91 98765 43210",
        "lat": 13.1197,
        "lng": 80.2183,
    },
]


DEALS_SEED = [
    # ── Nearby deals ─────────────────────────────────────────────────────────
    {
        "deal_group": "nearby",
        "name": "Smile Dentist",
        "location": "Padi, Chennai",
        "offer": "25% Off on All Treatments",
        "cashback": "1% Cashback",
        "distance": "6 Km",
        "type": "Clinic",
        "category": "Clinics",
        "image_url": "https://images.unsplash.com/photo-1588776814546-ec7eb8e02bb5?w=700&q=80",
        "description": "Smile Dentist offers world-class dental care. Get 25% off on all treatments including cleaning, fillings, and orthodontics.",
        "address": "12, 3rd Street, Padi, Chennai - 600050",
        "phone": "+91 98765 43210",
        "timing": "Mon–Sat: 9am – 8pm",
        "rating": 4.5,
        "reviews": 128,
        "tags": ["Dental", "Clinic", "Health"],
    },
    {
        "deal_group": "nearby",
        "name": "CK Bakers",
        "location": "Anna Nagar, Chennai",
        "offer": "Buy 2 Get 1 Free on Cakes",
        "cashback": "1% Cashback",
        "distance": "3 Km",
        "type": "Bakery",
        "category": "Restaurant",
        "image_url": "https://images.unsplash.com/photo-1568254183919-78a4f43a2877?w=700&q=80",
        "description": "Anna Nagar's favourite bakery since 1995. Buy 2 Get 1 Free on all custom cakes this month.",
        "address": "45, 2nd Avenue, Anna Nagar, Chennai - 600040",
        "phone": "+91 98765 12345",
        "timing": "Daily: 7am – 10pm",
        "rating": 4.3,
        "reviews": 312,
        "tags": ["Bakery", "Cakes", "Sweets"],
    },
    {
        "deal_group": "nearby",
        "name": "India Mart",
        "location": "Padi, Chennai",
        "offer": "25% Off on All Grocery",
        "cashback": "1% Cashback",
        "distance": "2 Km",
        "type": "Supermarket",
        "category": "Supermarket",
        "image_url": "https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=700&q=80",
        "description": "Your one-stop shop for all groceries — fresh vegetables, fruits, dairy, and household essentials.",
        "address": "89, Industrial Estate, Padi, Chennai - 600050",
        "phone": "+91 44 2651 1234",
        "timing": "Daily: 8am – 9pm",
        "rating": 4.1,
        "reviews": 245,
        "tags": ["Grocery", "Supermarket", "Fresh"],
    },
    {
        "deal_group": "nearby",
        "name": "Fitness First",
        "location": "Velachery, Chennai",
        "offer": "50% Off on 3-Month Membership",
        "cashback": "1% Cashback",
        "distance": "8 Km",
        "type": "Gym",
        "category": "Gym",
        "image_url": "https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=700&q=80",
        "description": "State-of-the-art gym with premium equipment, personal trainers, and group classes.",
        "address": "100 Feet Road, Velachery, Chennai - 600042",
        "phone": "+91 98400 55555",
        "timing": "Mon–Sat: 5am – 11pm | Sun: 6am – 9pm",
        "rating": 4.6,
        "reviews": 189,
        "tags": ["Gym", "Fitness", "Health"],
    },
    {
        "deal_group": "nearby",
        "name": "Naturals Salon",
        "location": "Nungambakkam, Chennai",
        "offer": "30% Off on All Hair Services",
        "cashback": "1% Cashback",
        "distance": "5 Km",
        "type": "Salon",
        "category": "Salon",
        "image_url": "https://images.unsplash.com/photo-1521590832167-7bcbfaa6381f?w=700&q=80",
        "description": "India's leading salon chain. Expert stylists and premium products.",
        "address": "22, Khader Nawaz Khan Rd, Nungambakkam, Chennai - 600006",
        "phone": "+91 44 4390 1234",
        "timing": "Daily: 9am – 8pm",
        "rating": 4.4,
        "reviews": 421,
        "tags": ["Salon", "Hair", "Beauty"],
    },
    {
        "deal_group": "nearby",
        "name": "MedPlus Pharmacy",
        "location": "Porur, Chennai",
        "offer": "10% Off on All Medicines",
        "cashback": "1% Cashback",
        "distance": "2 Km",
        "type": "Pharmacy",
        "category": "Pharmacy",
        "image_url": "https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=700&q=80",
        "description": "One of India's largest pharmacy chains with licensed pharmacists.",
        "address": "7, Arcot Road, Porur, Chennai - 600116",
        "phone": "+91 1800 102 6454",
        "timing": "Daily: 8am – 10pm",
        "rating": 4.3,
        "reviews": 389,
        "tags": ["Pharmacy", "Medicine", "Health"],
    },
    {
        "deal_group": "nearby",
        "name": "Cream Story",
        "location": "Anna Nagar, Chennai",
        "offer": "25% Off on All Beverages",
        "cashback": "1% Cashback",
        "distance": "6 Km",
        "type": "cafe",
        "category": "Cafes",
        "image_url": "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=700&q=80",
        "description": "Cream Story — artisan desserts and handcrafted beverages. Fresh cakes, cold brews and specialty coffees in a cozy ambiance.",
        "address": "3rd Avenue, Anna Nagar, Chennai - 600040",
        "phone": "+91 98400 77700",
        "timing": "Daily: 10am – 10pm",
        "rating": 4.4,
        "reviews": 312,
        "tags": ["Cafe", "Desserts", "Coffee"],
    },
    {
        "deal_group": "nearby",
        "name": "Chellian Super Stores",
        "location": "Padi, Chennai",
        "offer": "20% Off on All Groceries",
        "cashback": "1% Cashback",
        "distance": "1 Km",
        "type": "Supermarket",
        "category": "Supermarket",
        "image_url": "https://images.unsplash.com/photo-1567958451986-2de427a4a0be?w=700&q=80",
        "description": "Chellian Super Stores — your neighbourhood supermarket for fresh produce, daily essentials and household items at the best prices.",
        "address": "22, Padi Main Road, Chennai - 600050",
        "phone": "+91 44 2651 9999",
        "timing": "Daily: 7am – 9pm",
        "rating": 4.1,
        "reviews": 198,
        "tags": ["Supermarket", "Grocery", "Fresh"],
    },
    # ── Brand deals ───────────────────────────────────────────────────────────
    {
        "deal_group": "brand",
        "name": "Preethi",
        "location": "Anna Nagar, Chennai",
        "offer": "10% Offer On Products",
        "cashback": "1% Cashback",
        "distance": "5 Km",
        "type": "Electronics",
        "category": "Electronics",
        "image_url": "https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=700&q=80",
        "description": "Preethi Kitchen Appliances — India's most trusted kitchen brand. Get 10% off on mixers, grinders, juicers and all kitchen appliances.",
        "address": "78, Arcot Road, Anna Nagar, Chennai - 600040",
        "phone": "+91 1800 425 1000",
        "timing": "Mon–Sat: 9am – 7pm",
        "rating": 4.5,
        "reviews": 1240,
        "tags": ["Electronics", "Kitchen", "Appliances"],
    },
    {
        "deal_group": "brand",
        "name": "Canon",
        "location": "T. Nagar, Chennai",
        "offer": "10% Offer On Camera & Accessories",
        "cashback": "1% Cashback",
        "distance": "8 Km",
        "type": "Camera",
        "category": "Electronics",
        "image_url": "https://images.unsplash.com/photo-1510127034890-ba27508e9f1c?w=700&q=80",
        "description": "Canon India — official brand store for cameras, lenses, printers and accessories. Experience world-class imaging technology.",
        "address": "110, Usman Road, T. Nagar, Chennai - 600017",
        "phone": "+91 1800 180 3366",
        "timing": "Mon–Sat: 10am – 7pm",
        "rating": 4.6,
        "reviews": 876,
        "tags": ["Camera", "Photography", "Electronics"],
    },
    {
        "deal_group": "brand",
        "name": "Slam Fitness",
        "location": "Velachery, Chennai",
        "offer": "10% Offer On Products",
        "cashback": "1% Cashback",
        "distance": "6 Km",
        "type": "Gym",
        "category": "Gym",
        "image_url": "https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=700&q=80",
        "description": "Slam Lifestyle and Fitness Studio — premium fitness equipment, supplements and training gear. Exclusive member discounts available.",
        "address": "100 Feet Road, Velachery, Chennai - 600042",
        "phone": "+91 98400 55500",
        "timing": "Mon–Sun: 6am – 10pm",
        "rating": 4.4,
        "reviews": 567,
        "tags": ["Gym", "Fitness", "Equipment"],
    },
    {
        "deal_group": "brand",
        "name": "Usha",
        "location": "Nungambakkam, Chennai",
        "offer": "10% Offer On Products",
        "cashback": "1% Cashback",
        "distance": "7 Km",
        "type": "Electronics",
        "category": "Electronics",
        "image_url": "https://images.unsplash.com/photo-1585771724684-38269d6639fd?w=700&q=80",
        "description": "Usha International — premium fans, sewing machines, kitchen appliances and more. Quality products for every home.",
        "address": "Khader Nawaz Khan Rd, Nungambakkam, Chennai - 600006",
        "phone": "+91 1860 180 5050",
        "timing": "Mon–Sat: 9am – 7pm",
        "rating": 4.3,
        "reviews": 720,
        "tags": ["Electronics", "Appliances", "Fans"],
    },
    {
        "deal_group": "brand",
        "name": "Boss Gym",
        "location": "Anna Nagar, Chennai",
        "offer": "10% Off On Memberships",
        "cashback": "1% Cashback",
        "distance": "4 Km",
        "type": "Gym",
        "category": "Gym",
        "image_url": "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=700&q=80",
        "description": "Boss Gym & Fitness Studio — state-of-the-art equipment, certified trainers, and all fitness programs under one roof.",
        "address": "5th Avenue, Anna Nagar, Chennai - 600040",
        "phone": "+91 98765 00100",
        "timing": "Mon–Sun: 5am – 11pm",
        "rating": 4.5,
        "reviews": 389,
        "tags": ["Gym", "Fitness", "Training"],
    },
    {
        "deal_group": "brand",
        "name": "Croma",
        "location": "Anna Nagar, Chennai",
        "offer": "Up to 15% Off on Electronics",
        "cashback": "1% Cashback",
        "distance": "4 Km",
        "type": "Electronics",
        "category": "Electronics",
        "image_url": "https://images.unsplash.com/photo-1491933382434-500287f9b54b?w=700&q=80",
        "description": "Tata's multi-brand electronics chain. Best deals on TVs, laptops, mobiles and home appliances.",
        "address": "5th Avenue, Anna Nagar, Chennai - 600040",
        "phone": "+91 98400 18181",
        "timing": "Mon–Sat: 9am – 9pm",
        "rating": 4.2,
        "reviews": 932,
        "tags": ["Electronics", "Appliances", "Tata"],
    },
    {
        "deal_group": "brand",
        "name": "Shoppers Stop",
        "location": "Nungambakkam, Chennai",
        "offer": "Flat 25% Off on All Apparel",
        "cashback": "2% Cashback",
        "distance": "6 Km",
        "type": "Clothing",
        "category": "Clothing",
        "image_url": "https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=700&q=80",
        "description": "India's premier department store. Clothes, accessories, footwear and more — all under one roof.",
        "address": "Khader Nawaz Khan Rd, Nungambakkam, Chennai - 600006",
        "phone": "+91 44 4215 6789",
        "timing": "Daily: 10am – 10pm",
        "rating": 4.3,
        "reviews": 810,
        "tags": ["Clothing", "Fashion", "Department"],
    },
]

# ─────────────────────────────────────────────────────────────────────────────
# Classifieds seed — sample local service postings
# ─────────────────────────────────────────────────────────────────────────────

CLASSIFIEDS_SEED = [
    {
        "user_id": "seed_user", "user_name": "Hariharan", "user_phone": "+91 98400 11111",
        "category": "home_maintenance", "subcategory": "Electrician",
        "title": "Professional Electrician – 10 Yrs Exp",
        "description": "Experienced in all types of electrical work — wiring, switchboard repair, inverter installation and more. Available 7 days.",
        "price": 500, "years_of_exp": 10, "pincode": "600102", "area": "Anna Nagar East",
        "address": "No 5 V O C Nagar, 1st Cross, Anna Nagar East, Chennai 600 102",
        "is_available": True, "photos": [],
    },
    {
        "user_id": "seed_user", "user_name": "Sreenivasan", "user_phone": "+91 98400 22222",
        "category": "home_maintenance", "subcategory": "Electrician",
        "title": "Certified Electrician – Residential & Commercial",
        "description": "12 years in wiring, panel upgrades, outdoor lighting, and emergency repairs.",
        "price": 600, "years_of_exp": 12, "pincode": "600102", "area": "Anna Nagar East",
        "address": "No 5 V O C Nagar, 1st Cross, Anna Nagar East, Chennai 600 102",
        "is_available": True, "photos": [],
    },
    {
        "user_id": "seed_user", "user_name": "Mohan Raj", "user_phone": "+91 98400 33333",
        "category": "home_maintenance", "subcategory": "Electrician",
        "title": "Home Wiring, Fans & Light Installations",
        "description": "Expert in new wiring, fan installations, ceiling lights and all electrical repairs.",
        "price": 450, "years_of_exp": 8, "pincode": "600040", "area": "Anna Nagar",
        "address": "No 5 V O C Nagar, 1st Cross, Anna Nagar East, Chennai 600 102",
        "is_available": True, "photos": [],
    },
    {
        "user_id": "seed_user", "user_name": "Dilip", "user_phone": "+91 98400 44444",
        "category": "home_maintenance", "subcategory": "Electrician",
        "title": "24/7 Emergency Electrician",
        "description": "Available round the clock for urgent electrical issues. 15 years experience.",
        "price": 500, "years_of_exp": 15, "pincode": "600037", "area": "Mogappair",
        "address": "No 5 V O C Nagar, 1st Cross, Anna Nagar East, Chennai 600 102",
        "is_available": True, "photos": [],
    },
    {
        "user_id": "seed_user", "user_name": "Ramu", "user_phone": "+91 98765 55555",
        "category": "home_maintenance", "subcategory": "Plumbing",
        "title": "Expert Plumber – All Pipe Works",
        "description": "Pipe fitting, leakage repair, bathroom fitting, water heater installation. Same day service.",
        "price": 400, "years_of_exp": 7, "pincode": "600040", "area": "Anna Nagar",
        "address": "2nd Cross, Anna Nagar, Chennai 600 040",
        "is_available": True, "photos": [],
    },
    {
        "user_id": "seed_user", "user_name": "Vijayalakshmi", "user_phone": "+91 98765 66666",
        "category": "domestic_help", "subcategory": "Cook",
        "title": "Home Cook – South Indian Specialist",
        "description": "Experienced home cook for daily meals, tiffin and special occasions. Hygienic and punctual.",
        "price": 3000, "years_of_exp": 5, "pincode": "600049", "area": "Villivakkam",
        "address": "23, 4th Street, Villivakkam, Chennai 600 049",
        "is_available": True, "photos": [],
    },
    {
        "user_id": "seed_user", "user_name": "Meenakshi", "user_phone": "+91 98765 77777",
        "category": "domestic_help", "subcategory": "Maid Services",
        "title": "Full-time Housemaid Available",
        "description": "Experienced in cleaning, washing, mopping, utensils and general household tasks.",
        "price": 4000, "years_of_exp": 6, "pincode": "600040", "area": "Anna Nagar",
        "address": "15, 6th Avenue, Anna Nagar, Chennai 600 040",
        "is_available": True, "photos": [],
    },
    {
        "user_id": "seed_user", "user_name": "Karthi", "user_phone": "+91 98765 88888",
        "category": "home_maintenance", "subcategory": "AC Repair",
        "title": "AC Service, Gas Charging & Repair",
        "description": "All AC brands serviced — installation, gas charging, deep cleaning and repairs.",
        "price": 600, "years_of_exp": 9, "pincode": "600037", "area": "Mogappair",
        "address": "8, Main Road, Mogappair, Chennai 600 037",
        "is_available": True, "photos": [],
    },
    {
        "user_id": "seed_user", "user_name": "Priya Devi", "user_phone": "+91 98765 99999",
        "category": "on_demand_beauty", "subcategory": "Makeup Artist",
        "title": "Bridal & Party Makeup at Home",
        "description": "Professional bridal makeup, party looks, and full beauty services at your doorstep.",
        "price": 2500, "years_of_exp": 4, "pincode": "600040", "area": "Anna Nagar",
        "address": "10, 3rd Ave, Anna Nagar, Chennai 600 040",
        "is_available": True, "photos": [],
    },
    {
        "user_id": "seed_user", "user_name": "Suresh Kumar", "user_phone": "+91 98400 00001",
        "category": "fitness_sports", "subcategory": "Personal Trainer",
        "title": "Certified Personal Trainer – Home Sessions",
        "description": "Home workout sessions, diet plans and fitness coaching. Visible results in 30 days.",
        "price": 1500, "years_of_exp": 3, "pincode": "600040", "area": "Anna Nagar",
        "address": "5th Avenue, Anna Nagar, Chennai 600 040",
        "is_available": True, "photos": [],
    },
]


# ─────────────────────────────────────────────────────────────────────────────
# Reels seed — short promo video clips linked to shops
# Using publicly accessible sample MP4s from Google's sample video bucket.
# Replace video_url values with real promo clips in production.
# ─────────────────────────────────────────────────────────────────────────────

REELS_SEED = [
    {
        "shop_name": "Naturals Salon",
        "shop_location": "Nungambakkam, Chennai",
        "shop_category": "Salon",
        "caption": "🌟 30% off on all hair services this month! Visit Naturals and transform your look.",
        "offer": "30% Off on Hair Services",
        "video_url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
        "thumbnail_url": "https://images.unsplash.com/photo-1521590832167-7bcbfaa6381f?w=700&q=80",
        "like_count": 1240,
        "view_count": 8900,
        "tag": "Salon",
    },
    {
        "shop_name": "Boss Gym",
        "shop_location": "Anna Nagar, Chennai",
        "shop_category": "Gym",
        "caption": "💪 New year, new you! 10% off memberships. State-of-the-art equipment awaits.",
        "offer": "10% Off On Memberships",
        "video_url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
        "thumbnail_url": "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=700&q=80",
        "like_count": 980,
        "view_count": 6700,
        "tag": "Gym",
    },
    {
        "shop_name": "Preethi",
        "shop_location": "Anna Nagar, Chennai",
        "shop_category": "Electronics",
        "caption": "🍳 Cook smarter with Preethi appliances. Exclusive 10% off on all kitchen essentials.",
        "offer": "10% Off on All Products",
        "video_url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
        "thumbnail_url": "https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=700&q=80",
        "like_count": 2100,
        "view_count": 14200,
        "tag": "Electronics",
    },
    {
        "shop_name": "Cream Story",
        "shop_location": "Anna Nagar, Chennai",
        "shop_category": "Cafe",
        "caption": "☕ Handcrafted beverages & artisan desserts. 25% off on all drinks today!",
        "offer": "25% Off on Beverages",
        "video_url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4",
        "thumbnail_url": "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=700&q=80",
        "like_count": 1560,
        "view_count": 9300,
        "tag": "Cafe",
    },
    {
        "shop_name": "Shoppers Stop",
        "shop_location": "Nungambakkam, Chennai",
        "shop_category": "Clothing",
        "caption": "👗 Flat 25% off on all apparel. Fashion that speaks for itself — visit us today!",
        "offer": "Flat 25% Off on Apparel",
        "video_url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4",
        "thumbnail_url": "https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=700&q=80",
        "like_count": 3200,
        "view_count": 21000,
        "tag": "Clothing",
    },
]


# Rewards templates: one reward per shop (keyed by shop name for linking)
REWARDS_TEMPLATE = [
    {"title": "5% Cashback Voucher",      "description": "Get 5% cashback on your next purchase above ₹500.",  "points_required": 100, "discount_percent": 5,  "valid_days": 30},
    {"title": "10% Discount Coupon",      "description": "Flat 10% off on all items for one visit.",           "points_required": 200, "discount_percent": 10, "valid_days": 30},
    {"title": "Free Delivery Pass",       "description": "Free home delivery on your next 3 orders.",          "points_required": 150, "discount_percent": 0,  "valid_days": 14},
    {"title": "15% Weekend Offer",        "description": "15% off valid on Saturdays and Sundays only.",        "points_required": 250, "discount_percent": 15, "valid_days": 60},
    {"title": "Buy 2 Get 1 Free",         "description": "Buy any 2 items and get 1 free on selected products.","points_required": 300, "discount_percent": 33, "valid_days": 21},
    {"title": "₹100 Flat Off",            "description": "₹100 discount on purchase above ₹1000.",             "points_required": 180, "discount_percent": 10, "valid_days": 30},
    {"title": "VIP Member Discount",      "description": "Exclusive 20% off for loyalty members.",              "points_required": 400, "discount_percent": 20, "valid_days": 90},
    {"title": "Loyalty Bonus — 8% Off",   "description": "Earn 8% off on every visit as a loyalty member.",    "points_required": 220, "discount_percent": 8,  "valid_days": 45},
    {"title": "Anniversary Special",      "description": "Celebrate with 25% off on your special day.",        "points_required": 350, "discount_percent": 25, "valid_days": 7},
    {"title": "First Visit Reward",       "description": "Get 12% off on your very first visit to our store.", "points_required": 50,  "discount_percent": 12, "valid_days": 15},
    {"title": "Referral Bonus Coupon",    "description": "Refer a friend and both get 10% off.",               "points_required": 200, "discount_percent": 10, "valid_days": 30},
    {"title": "Festival Offer — 18% Off", "description": "Special 18% discount during festive season.",        "points_required": 280, "discount_percent": 18, "valid_days": 14},
    {"title": "Student Discount",         "description": "20% off for valid student ID holders.",               "points_required": 150, "discount_percent": 20, "valid_days": 60},
    {"title": "Senior Citizen Benefit",   "description": "15% off for customers above 60 years.",              "points_required": 100, "discount_percent": 15, "valid_days": 90},
    {"title": "Weekend Flash Sale",       "description": "30% off on selected items every Sunday.",             "points_required": 320, "discount_percent": 30, "valid_days": 7},
    {"title": "Bundle Saver Coupon",      "description": "Save 22% when you buy any 3 items together.",        "points_required": 260, "discount_percent": 22, "valid_days": 30},
    {"title": "Early Bird Offer",         "description": "15% off for visits before 10am.",                    "points_required": 180, "discount_percent": 15, "valid_days": 30},
    {"title": "Members-Only Mega Deal",   "description": "35% off on premium products for members only.",       "points_required": 500, "discount_percent": 35, "valid_days": 30},
    {"title": "Flat ₹200 Off",            "description": "₹200 off on purchases above ₹2000.",                 "points_required": 400, "discount_percent": 10, "valid_days": 45},
    {"title": "Gold Tier Reward",         "description": "Exclusive 40% off for Gold tier members.",           "points_required": 600, "discount_percent": 40, "valid_days": 60},
]


# ─────────────────────────────────────────────────────────────────────────────
# Main seeder
# ─────────────────────────────────────────────────────────────────────────────

async def seed():
    print(f"\n🌱 Connecting to MongoDB at {MONGO_URL} / db={DB_NAME} …")
    client = AsyncIOMotorClient(MONGO_URL)
    db = client[DB_NAME]

    # ── Clear old seed data ──────────────────────────────────────────────────
    print("🗑  Clearing old shops, deals, rewards, redeem, reels data …")
    await db.shops.delete_many({})
    await db.deals.delete_many({})
    await db.rewards.delete_many({})
    await db.redeem.delete_many({})
    await db.reels.delete_many({})
    await db.classifieds.delete_many({})

    # ── Seed shops ───────────────────────────────────────────────────────────
    print(f"\n🏪 Seeding {len(SHOPS_SEED)} shops …")
    shop_docs = []
    for shop in SHOPS_SEED:
        image_name  = shop.get("image_name", "")
        image_names = shop.get("image_names", [image_name] if image_name else [])

        print(f"   ☁️  Uploading '{shop['name']}' images to S3 …", end=" ", flush=True)
        # Primary image — upload to S3, store key + public URL
        primary_key, primary_url = _upload_image_to_s3(image_name) if image_name else ("", "")
        # Gallery images (detail carousel)
        gallery = [_upload_image_to_s3(n) for n in image_names]
        gallery_keys = [k for k, _ in gallery]
        gallery_urls = [u for _, u in gallery]
        print(f"✅ {primary_url[:60]}…" if primary_url else "⚠️  (upload failed)")

        doc = {
            **shop,
            # S3 keys — backend generates presigned URLs from these at serve time
            "image_s3_key":       primary_key,
            "image_s3_keys":      gallery_keys,
            # Leave image_url/image_urls empty — presigned URLs are generated
            # on demand by the API so they never expire in the DB.
            "image_url":          "",
            "image_urls":         [],
            # Legacy fields kept for backward compatibility
            "image_data":         "",
            "image_data_list":    [],
            "created_at": datetime.now(timezone.utc),
        }
        shop_docs.append(doc)

    result = await db.shops.insert_many(shop_docs)
    shop_ids = result.inserted_ids
    print(f"   ✅ Inserted {len(shop_ids)} shops.")

    # ── Seed deals ───────────────────────────────────────────────────────────
    print(f"\n🎯 Seeding {len(DEALS_SEED)} deals …")
    deal_docs = [
        {**deal, "created_at": datetime.now(timezone.utc)}
        for deal in DEALS_SEED
    ]
    await db.deals.insert_many(deal_docs)
    print(f"   ✅ Inserted {len(deal_docs)} deals.")

    # ── Seed rewards (1 per shop) ─────────────────────────────────────────────
    print(f"\n🎁 Seeding rewards …")
    reward_docs = []
    for i, shop_id in enumerate(shop_ids):
        template = REWARDS_TEMPLATE[i % len(REWARDS_TEMPLATE)]
        expires_at = datetime.now(timezone.utc) + timedelta(days=template["valid_days"])
        reward_docs.append({
            "shop_id": str(shop_id),
            "title": template["title"],
            "description": template["description"],
            "points_required": template["points_required"],
            "discount_percent": template["discount_percent"],
            "expires_at": expires_at,
            "is_active": True,
            "created_at": datetime.now(timezone.utc),
        })

    await db.rewards.insert_many(reward_docs)
    print(f"   ✅ Inserted {len(reward_docs)} rewards.")

    # ── Seed classifieds ─────────────────────────────────────────────────────
    print(f"\n📋 Seeding {len(CLASSIFIEDS_SEED)} classifieds …")
    classified_docs = [
        {**c, "created_at": datetime.now(timezone.utc)}
        for c in CLASSIFIEDS_SEED
    ]
    await db.classifieds.insert_many(classified_docs)
    print(f"   ✅ Inserted {len(classified_docs)} classifieds.")

    # ── Seed reels ───────────────────────────────────────────────────────────
    print(f"\n🎬 Seeding {len(REELS_SEED)} reels …")
    reel_docs = [
        {**reel, "liked_by": [], "created_at": datetime.now(timezone.utc)}
        for reel in REELS_SEED
    ]
    await db.reels.insert_many(reel_docs)
    print(f"   ✅ Inserted {len(reel_docs)} reels.")

    # ── Summary ──────────────────────────────────────────────────────────────
    print("\n" + "═" * 55)
    print(f"  ✅  Shops   : {await db.shops.count_documents({})}")
    print(f"  ✅  Deals   : {await db.deals.count_documents({})}")
    print(f"  ✅  Rewards : {await db.rewards.count_documents({})}")
    print(f"  ✅  Redeem  : {await db.redeem.count_documents({})} (users create these at runtime)")
    print(f"  ✅  Classifieds: {await db.classifieds.count_documents({})}")
    print(f"  ✅  Reels   : {await db.reels.count_documents({})}")
    print("═" * 55)
    print("\n🚀 Seed complete! Start the FastAPI server and enjoy dynamic data.\n")

    client.close()


if __name__ == "__main__":
    asyncio.run(seed())
