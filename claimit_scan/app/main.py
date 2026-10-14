"""
Claimit Scan Service — bill reading, on its own process and its own database.

Runs on 127.0.0.1:8003, behind nginx at /scan/. It does not import from, call
into, or share a database credential with claimit.service (8001) or
claimit_web.service (8002). If this process dies, nothing else notices.
"""
import logging
import os
import sys
import time
import uuid

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .config import settings
from .db import close, connect
from .routes import router

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s [%(message)s]",
)
log = logging.getLogger("scan")

app = FastAPI(
    title="Claimit Scan Service",
    version="1.0.0",
    # No public schema. The endpoints and their shapes are not an invitation.
    docs_url=None, redoc_url=None, openapi_url=None,
)

# The mobile app sends an Authorization header, not a cookie, so there is no
# CSRF surface and no reason to allow credentials. Origins are explicit.
_origins = [o for o in os.getenv("ALLOWED_ORIGINS", "").split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins or ["https://claimit-web-aro.web.app"],
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type"],
)


@app.on_event("startup")
async def _startup():
    missing = settings().validate()
    if missing:
        # Refuse to serve half-configured. A scan service with no Azure key
        # would silently send every bill to manual review.
        log.error("missing configuration: %s", ", ".join(missing))
        sys.exit(1)
    await connect()
    log.info("scan service ready")


@app.on_event("shutdown")
async def _shutdown():
    await close()


@app.middleware("http")
async def request_context(request: Request, call_next):
    """Request id + duration on every line, and no stack traces to clients."""
    rid = uuid.uuid4().hex[:12]
    started = time.perf_counter()
    try:
        response = await call_next(request)
    except Exception:
        log.exception("unhandled rid=%s %s %s", rid, request.method, request.url.path)
        return JSONResponse(
            status_code=500,
            content={"detail": "Something went wrong. Please try again."},
            headers={"X-Request-Id": rid},
        )
    took = (time.perf_counter() - started) * 1000
    log.info("rid=%s %s %s %s %.0fms",
             rid, request.method, request.url.path, response.status_code, took)
    response.headers["X-Request-Id"] = rid
    # Cheap hardening; nginx can also set these.
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Referrer-Policy"] = "no-referrer"
    return response


@app.get("/health")
async def health():
    """Liveness only. Deliberately says nothing about versions or config."""
    return {"status": "healthy", "service": "scan"}


app.include_router(router)
