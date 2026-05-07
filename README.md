# Claimit - Insurance Claims Management App

A full-stack insurance claims management application built with **Flutter** (frontend) and **FastAPI** (backend) with **MongoDB** database.

## Project Structure

```
claimit-app/
├── claimit_app/          # Flutter Mobile App
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/
│   │   │   ├── constants/
│   │   │   ├── network/
│   │   │   ├── router/
│   │   │   ├── theme/
│   │   │   └── utils/
│   │   ├── features/
│   │   │   ├── auth/          # Login, Register, OTP
│   │   │   ├── dashboard/     # Home Dashboard
│   │   │   ├── claims/        # Claims CRUD
│   │   │   ├── notifications/ # Push Notifications
│   │   │   ├── policies/      # Insurance Policies
│   │   │   ├── profile/       # User Profile
│   │   │   └── home/          # Bottom Navigation
│   │   └── shared/
│   │       └── widgets/       # Reusable Widgets
│   └── assets/
│       ├── images/
│       ├── icons/
│       └── animations/
│
└── backend/              # FastAPI Backend
    ├── app/
    │   ├── main.py
    │   ├── config.py
    │   ├── database.py
    │   ├── models/
    │   │   ├── user.py
    │   │   ├── claim.py
    │   │   └── notification.py
    │   ├── routes/
    │   │   ├── auth.py
    │   │   ├── users.py
    │   │   ├── claims.py
    │   │   ├── notifications.py
    │   │   ├── dashboard.py
    │   │   └── policies.py
    │   └── utils/
    │       ├── auth.py
    │       ├── otp.py
    │       └── helpers.py
    ├── requirements.txt
    ├── .env
    └── run.py
```

## Features

### Flutter App
- **Splash Screen** with animated logo
- **Onboarding** with 3 slides
- **Authentication** via OTP (phone-based, multi-user)
- **Dashboard** with stats overview and quick actions
- **Claims Management** - Create, view, track claims
- **Multi-step Claim Form** with validation
- **Document Upload** for claim evidence
- **Claim Timeline** tracking
- **Policies** management
- **Notifications** with read/unread state
- **Profile** with KYC details
- **Bottom Navigation** with 5 tabs

### FastAPI Backend
- JWT Authentication (access + refresh tokens)
- OTP-based login (static OTP: `123456` for demo)
- Multi-user support (each user has isolated data)
- Claims CRUD with status tracking
- Document upload with file validation
- Dashboard statistics aggregation
- Notification system
- MongoDB with Motor (async)

## Setup

### Backend

```bash
cd backend
pip install -r requirements.txt
python run.py
```

API will be available at: http://localhost:8000
Swagger docs: http://localhost:8000/docs

### Flutter App

```bash
cd claimit_app
flutter pub get
flutter run
```

**For physical device**, update `lib/core/constants/app_constants.dart`:
```dart
static const String baseUrl = 'http://YOUR_PC_IP:8000';
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /auth/send-otp | Send OTP to phone |
| POST | /auth/verify-otp | Verify OTP & get tokens |
| POST | /auth/register | Register new user |
| POST | /auth/refresh | Refresh access token |
| GET | /users/profile | Get user profile |
| PUT | /users/profile/update | Update profile |
| POST | /users/avatar | Upload avatar |
| GET | /claims | Get all claims |
| POST | /claims/create | Create new claim |
| GET | /claims/{id} | Get claim details |
| POST | /claims/{id}/documents | Upload document |
| PATCH | /claims/{id}/status | Update claim status |
| GET | /dashboard | Get dashboard stats |
| GET | /notifications | Get notifications |
| PATCH | /notifications/{id}/read | Mark as read |
| GET | /policies | Get policies |
| POST | /policies | Add policy |

## OTP

- **Static OTP**: `123456` (works for all numbers in demo mode)
- Real OTP is also generated and stored in DB
- OTP expires in 10 minutes
- Max 3 verification attempts

## Database

MongoDB Atlas: `claimit_db`

Collections:
- `users` - User accounts
- `claims` - Insurance claims
- `notifications` - User notifications
- `policies` - Insurance policies
- `otp_store` - Temporary OTP storage (TTL indexed)

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.x |
| State Management | Provider |
| Navigation | GoRouter |
| HTTP Client | Dio |
| Secure Storage | flutter_secure_storage |
| Backend | FastAPI |
| Database | MongoDB Atlas |
| ODM | Motor (async) |
| Auth | JWT (python-jose) |
| File Upload | python-multipart |
