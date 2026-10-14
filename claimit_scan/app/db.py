"""
MongoDB for the scan service.

Its own database, reached with its own scoped credential. The duplicate rules
are UNIQUE INDEXES, not application checks — two requests racing the same
receipt have to lose at the database, because a find-then-insert lets both
through.
"""
import logging

from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from pymongo import ASCENDING, DESCENDING, IndexModel

from .config import settings

log = logging.getLogger(__name__)

_client: AsyncIOMotorClient | None = None
_db: AsyncIOMotorDatabase | None = None


def get_db() -> AsyncIOMotorDatabase:
    if _db is None:                                     # pragma: no cover
        raise RuntimeError("database not initialised")
    return _db


async def connect() -> None:
    global _client, _db
    s = settings()
    _client = AsyncIOMotorClient(
        s.MONGODB_URL,
        serverSelectionTimeoutMS=5000,
        maxPoolSize=20,            # small box; do not let the pool grow wild
        tz_aware=True,
    )
    await _client.admin.command("ping")
    _db = _client[s.DB_NAME]
    await ensure_indexes()
    log.info("scan db connected: %s", s.DB_NAME)


async def close() -> None:
    if _client:
        _client.close()


async def ensure_indexes() -> None:
    """
    Created at startup, idempotent.

    The two UNIQUE ones are the anti-fraud enforcement. Everything else is
    there so the queries that run on every scan stay off a collection scan.
    """
    db = get_db()

    await db.scans.create_indexes([
        # Hard stop: a byte-identical image, ever, by anyone. Global and not
        # per-user on purpose — the same JPEG passed between two accounts is
        # exactly what this is for.
        IndexModel([("sha256", ASCENDING)], unique=True, name="uq_sha256"),
        IndexModel([("user_id", ASCENDING), ("created_at", DESCENDING)],
                   name="ix_user_created"),
        IndexModel([("device_id", ASCENDING), ("created_at", DESCENDING)],
                   name="ix_device_created"),
        IndexModel([("status", ASCENDING), ("created_at", DESCENDING)],
                   name="ix_status_created"),
        # pHash near-duplicate search is bounded to a 90-day window; without
        # the TTL on the lookup this becomes a growing scan.
        IndexModel([("created_at", DESCENDING)], name="ix_created"),
    ])

    await db.signatures.create_indexes([
        # Hard stop: the same TRANSACTION, however it was photographed.
        IndexModel([("signature", ASCENDING)], unique=True, name="uq_signature"),
        IndexModel([("signature_loose", ASCENDING)], name="ix_signature_loose"),
    ])

    await db.claims.create_indexes([
        IndexModel([("idempotency_key", ASCENDING)], unique=True, name="uq_idem"),
        # One live claim per scan. A reversal carries reverses_id and is
        # allowed past by the partial filter.
        IndexModel([("scan_id", ASCENDING)], unique=True, name="uq_live_claim",
                   partialFilterExpression={"reverses_id": {"$exists": False}}),
        IndexModel([("user_id", ASCENDING), ("created_at", DESCENDING)],
                   name="ix_user_claims"),
    ])

    await db.flags.create_indexes([
        IndexModel([("scan_id", ASCENDING)], name="ix_scan"),
        IndexModel([("rule", ASCENDING), ("created_at", DESCENDING)], name="ix_rule"),
    ])

    # Rate-limit counters expire themselves rather than needing a sweeper.
    await db.rate.create_indexes([
        IndexModel([("key", ASCENDING)], unique=True, name="uq_key"),
        IndexModel([("expires_at", ASCENDING)], expireAfterSeconds=0, name="ttl"),
    ])
    log.info("scan indexes ensured")
