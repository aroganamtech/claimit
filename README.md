# Claimit - Full Stack Application

## Project Structure
```
claimit/
├── backend/          # FastAPI + MongoDB
└── frontend/         # React + Vite
```

## Quick Start

### 1. Setup Backend

```bash
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Edit .env and replace MONGO_URL with your MongoDB Atlas connection string
# Example: MONGO_URL=mongodb+srv://username:password@cluster.mongodb.net/?retryWrites=true&w=majority

uvicorn main:app --reload --port 8000
```

### 2. Setup Frontend

```bash
cd frontend
npm install
npm run dev
```

### 3. Open Browser
- App runs at: http://localhost:5173
- API docs at: http://localhost:8000/docs

---

## 3 User Portals (all same site, click "Login" top right)

### L1 - Advertiser Portal (`/advertiser/auth`)
- Register with phone + email
- Create ads (Home Banner, Promo Reelz, Brand Deals, Nearby Deals)
- View dashboard with stats
- Manage ad campaigns

### L2 - Sales / Affiliate Portal (`/sales/auth`)
- Register with phone + email
- Add shops to the network
- View team and earnings

### L3 - Shop Owner Portal (`/shop/auth`)
- Register with phone + email
- Full shop onboarding flow
- Manage offers, store details
- View ratings & reviews

---

## Environment Variables (backend/.env)

```env
MONGO_URL=mongodb+srv://<username>:<password>@<cluster>.mongodb.net/?retryWrites=true&w=majority
DB_NAME=claimit
SECRET_KEY=your_super_secret_key_here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=1440
```

## OTP (Development)
- The API returns `dev_otp` in the register response (visible on screen)
- Universal OTP: `123456` works for any verification
- Remove `dev_otp` from response for production

## Image Placeholders
All image areas are marked with `{/* image */}` comments.
Replace the placeholder divs with actual `<img>` tags pointing to your assets.

## Tech Stack
- **Frontend**: React 18, Vite, React Router v6
- **Backend**: FastAPI, Motor (async MongoDB), python-jose (JWT)
- **Database**: MongoDB Atlas
- **Auth**: Phone + Email OTP → JWT tokens
