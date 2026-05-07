from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import auth, advertiser, sales, shop
import os
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="Claimit API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/auth", tags=["Auth"])
app.include_router(advertiser.router, prefix="/api/advertiser", tags=["Advertiser"])
app.include_router(sales.router, prefix="/api/sales", tags=["Sales"])
app.include_router(shop.router, prefix="/api/shop", tags=["Shop"])

@app.get("/")
def root():
    return {"message": "Claimit API Running"}
