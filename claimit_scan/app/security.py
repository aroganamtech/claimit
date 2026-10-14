"""
Auth and rate limiting.

Tokens are the ones the app already holds — same secret, same algorithm,
verified locally. No call back to the app API, so a restart over there
cannot take scanning down.
"""
import logging
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .config import settings
from .db import get_db

log = logging.getLogger(__name__)
_bearer = HTTPBearer(auto_error=False)


class User:
    __slots__ = ("id", "raw")

    def __init__(self, uid: str, raw: dict):
        self.id = uid
        self.raw = raw


async def current_user(
    cred: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> User:
    if not cred or not cred.credentials:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Authentication required.")
    s = settings()
    try:
        payload = jwt.decode(cred.credentials, s.JWT_SECRET, algorithms=[s.JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Session expired.")
    except jwt.InvalidTokenError:
        # Never echo the reason — it tells an attacker which part was wrong.
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid session.")

    uid = str(payload.get("sub") or payload.get("user_id") or "")
    if not uid:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid session.")

    # A token minted for the admin console must not spend a customer's
    # cashback. If the app API sets a `typ` claim, honour it.
    typ = payload.get("typ")
    if typ and typ not in ("customer", "user", "app"):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Wrong token type.")

    return User(uid, payload)


async def rate_limit(user: User, request: Request) -> None:
    """
    Per-user minute and day counters, in Mongo with a TTL so they clean
    themselves up. Scanning costs real money per call — an uncapped endpoint
    is an uncapped bill, quite apart from the fraud angle.
    """
    s, db = settings(), get_db()
    now = datetime.now(timezone.utc)

    for window, limit, ttl in (
        (now.strftime("%Y%m%d%H%M"), s.RATE_PER_MIN, 120),
        (now.strftime("%Y%m%d"),     s.RATE_PER_DAY, 86400 + 600),
    ):
        key = f"{user.id}:{window}"
        doc = await db.rate.find_one_and_update(
            {"key": key},
            {"$inc": {"n": 1},
             "$setOnInsert": {"expires_at": now + timedelta(seconds=ttl)}},
            upsert=True, return_document=True,
        )
        if doc and doc.get("n", 0) > limit:
            raise HTTPException(
                status.HTTP_429_TOO_MANY_REQUESTS,
                detail={"code": "rate_limited",
                        "message": "Too many scans just now. Please try again shortly."},
            )
