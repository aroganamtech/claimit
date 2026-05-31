from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from app.utils.auth import decode_token
from app.database import users_collection
from bson import ObjectId

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")


async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    payload = decode_token(token)
    if payload is None:
        raise credentials_exception

    user_id = payload.get("sub")
    if user_id is None:
        raise credentials_exception

    user = await users_collection.find_one({"_id": ObjectId(user_id)})
    if user is None:
        raise credentials_exception

    return user


# ─── Admin auth ─────────────────────────────────────────────────
async def get_current_admin(token: str = Depends(oauth2_scheme)):
    """Validates an admin JWT (issued by /admin/login)."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Admin authentication required",
        headers={"WWW-Authenticate": "Bearer"},
    )
    payload = decode_token(token)
    if not payload or payload.get("scope") != "admin":
        raise credentials_exception
    return {"username": payload.get("sub", "admin")}


# ─── Optional auth (public endpoints that enrich response when user is logged in) ───
from fastapi.security import OAuth2PasswordBearer as _OAuth2
from fastapi import Request

async def get_current_user_optional(request: Request):
    """Like get_current_user but returns None instead of raising 401."""
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return None
    token = auth_header[len("Bearer "):]
    try:
        from app.utils.auth import decode_token
        from app.database import users_collection
        from bson import ObjectId
        payload = decode_token(token)
        if payload is None:
            return None
        user_id = payload.get("sub")
        if not user_id:
            return None
        return await users_collection.find_one({"_id": ObjectId(user_id)})
    except Exception:
        return None
