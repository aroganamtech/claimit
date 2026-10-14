"""
Dispatcher for paid notification ads.

WHY THIS LIVES HERE (and not in the web backend)
------------------------------------------------
An advertiser buys a notification ad on the web portal, but the web backend
cannot send it well: the audience is "every app user within N km of this
pincode", and the `users` collection — with the GeoJSON point and the
`fcm_tokens` that go with it — belongs to this backend. More importantly a
notification ad is SCHEDULED: ads run on the weekly Friday→Thursday cycle, so
a Tuesday purchase must not fire a push on Tuesday announcing an ad that is
not live yet. The web backend is a request/response API with no scheduler, so
it would have to send immediately or not at all.

So the two sides split the job along the line that already exists:

    web backend   →  writes a JOB into claimit_db.ad_notifications
                     (what to say, where, when to send it)
    this backend  →  one background loop claims due jobs and sends them

The queue is a plain collection in the database both backends already share,
so there is no new network path, no new endpoint, and no new credential
between them — nothing for an attacker to reach that was not already
reachable. The web side can only ever ENQUEUE; everything that decides who
gets a push, and every token, stays on this side.

SAFETY PROPERTIES (all of these are deliberate)
-----------------------------------------------
  • A job is claimed with a single atomic find_one_and_update from "pending"
    to "sending". Two workers, or a restart mid-send, cannot double-send the
    same job: whoever loses the race gets None back.
  • A job stuck in "sending" (process killed mid-flight) is retried only
    after `_STUCK_AFTER_MIN`, and only `_MAX_ATTEMPTS` times, so a job that
    reliably crashes stops instead of looping forever.
  • The radius query is capped (`_MAX_RADIUS_KM`) and the audience is capped
    (`_MAX_AUDIENCE`). A malformed job cannot turn into a push to the entire
    user base.
  • Title/body are truncated and stripped of newlines before sending. They
    come from advertiser input, so they are treated as untrusted text and are
    never interpolated into anything executable.
  • Every step is wrapped: this loop must never take the API down with it.
"""

import asyncio
from datetime import datetime, timedelta

from ..database import get_db
from .fcm import send_push_to_tokens

# How often to look for due jobs. A notification ad is not time-critical to
# the minute, and a short interval would mean a pointless query every few
# seconds for the long stretches when nothing is queued.
_POLL_SECONDS = 120

# Caps. The advertiser form offers 5 km and 10 km; anything beyond this is a
# malformed or tampered job and is clamped rather than honoured.
_MAX_RADIUS_KM = 25.0
_DEFAULT_RADIUS_KM = 5.0

# Upper bound on one job's audience. Well above any realistic 25 km radius in
# the cities Claimit operates in, but it means a job with a broken geo filter
# still cannot become an app-wide blast.
_MAX_AUDIENCE = 20000

_FCM_CHUNK = 500        # FCM's own multicast limit
_MAX_ATTEMPTS = 3
_STUCK_AFTER_MIN = 15


def _clean(text: str, limit: int) -> str:
    """Advertiser-supplied text, made safe to put in a notification.

    Newlines are collapsed because a notification title with a line break
    renders as a blank line on Android, and the length cap is what keeps a
    pasted essay from being rejected by FCM (which would silently drop the
    whole multicast, not just the long field).
    """
    s = " ".join(str(text or "").split())
    return s[:limit]


async def _audience_tokens(db, job: dict) -> tuple[list[str], list[str]]:
    """(device tokens, user ids) for every user inside the job's radius.

    Uses $geoNear over `users`, which needs the 2dsphere index registered in
    database.py. Users who have never updated their location since the app
    started sending coordinates simply have no `geo` and are not reachable by
    a radius ad — that is correct behaviour, not a bug to work around: we do
    not know where they are, so we must not claim they are within 5 km.
    """
    geo = job.get("geo") or {}
    coords = geo.get("coordinates") or []
    if len(coords) != 2:
        return [], []

    try:
        radius_km = float(job.get("radius_km") or _DEFAULT_RADIUS_KM)
    except (TypeError, ValueError):
        radius_km = _DEFAULT_RADIUS_KM
    radius_km = max(0.5, min(radius_km, _MAX_RADIUS_KM))

    pipeline = [
        {
            "$geoNear": {
                "near": {"type": "Point", "coordinates": [coords[0], coords[1]]},
                "distanceField": "_dist_m",
                "maxDistance": radius_km * 1000.0,
                "spherical": True,
                "key": "geo",
            }
        },
        {"$limit": _MAX_AUDIENCE},
        {"$project": {"_id": 1}},
    ]
    user_docs = await db.users.aggregate(pipeline).to_list(_MAX_AUDIENCE)
    user_ids = [str(d["_id"]) for d in user_docs]
    if not user_ids:
        return [], []

    token_docs = await db.fcm_tokens.find(
        {"user_id": {"$in": user_ids}}, {"token": 1}
    ).to_list(_MAX_AUDIENCE * 3)
    # De-duplicated: one user with the app on two devices is two tokens, but
    # the same token must never appear twice in one multicast.
    tokens = list({d["token"] for d in token_docs if d.get("token")})
    return tokens, user_ids


async def _write_inbox_rows(db, user_ids: list[str], job: dict) -> None:
    """Also drop the ad into each user's in-app notification list.

    A push that arrives while the phone is locked and is then swiped away is
    gone forever. The advertiser paid for the message, so it also has to be
    findable in the app's bell afterwards — same shape every other
    notification in this backend uses, so the existing list screen renders it
    with no change.
    """
    if not user_ids:
        return
    now = datetime.utcnow()
    rows = [
        {
            "user_id": uid,
            "title": job.get("title", ""),
            "message": job.get("body", ""),
            "type": "sponsored",
            "is_read": False,
            "image_url": job.get("image_url") or "",
            "cta_link": job.get("cta_link") or "",
            "web_ad_id": job.get("web_ad_id") or "",
            "created_at": now,
        }
        for uid in user_ids
    ]
    # Chunked so one insert_many is never megabytes long.
    for i in range(0, len(rows), 1000):
        try:
            await db.notifications.insert_many(rows[i:i + 1000], ordered=False)
        except Exception as exc:  # noqa: BLE001
            print(f"⚠️  ad inbox rows chunk failed: {exc}")


async def _claim_due_job(db):
    """Atomically take one due job, or return None.

    The `$or` is what makes this crash-safe: either the job is pending and
    due, or it has been sitting in "sending" long enough that whoever claimed
    it is clearly gone.
    """
    now = datetime.utcnow()
    stuck_before = now - timedelta(minutes=_STUCK_AFTER_MIN)
    return await db.ad_notifications.find_one_and_update(
        {
            "attempts": {"$lt": _MAX_ATTEMPTS},
            "$or": [
                {"status": "pending", "send_at": {"$lte": now}},
                {"status": "sending", "claimed_at": {"$lte": stuck_before}},
            ],
        },
        {"$set": {"status": "sending", "claimed_at": now},
         "$inc": {"attempts": 1}},
        sort=[("send_at", 1)],
    )


async def _dispatch(db, job: dict) -> None:
    title = _clean(job.get("title"), 120)
    body = _clean(job.get("body"), 300)
    if not title and not body:
        await db.ad_notifications.update_one(
            {"_id": job["_id"]},
            {"$set": {"status": "failed", "error": "empty title and body",
                      "finished_at": datetime.utcnow()}},
        )
        return

    tokens, user_ids = await _audience_tokens(db, job)

    data = {
        "type": "sponsored",
        "web_ad_id": str(job.get("web_ad_id") or ""),
    }
    if job.get("cta_link"):
        data["cta_link"] = str(job["cta_link"])

    sent = 0
    for i in range(0, len(tokens), _FCM_CHUNK):
        chunk = tokens[i:i + _FCM_CHUNK]
        invalid = await send_push_to_tokens(chunk, title or "Claimit", body, data)
        sent += len(chunk) - len(invalid)
        if invalid:
            await db.fcm_tokens.delete_many({"token": {"$in": invalid}})

    await _write_inbox_rows(db, user_ids, job)

    await db.ad_notifications.update_one(
        {"_id": job["_id"]},
        {"$set": {
            "status": "sent",
            "audience_users": len(user_ids),
            "tokens_targeted": len(tokens),
            "tokens_delivered": sent,
            "finished_at": datetime.utcnow(),
        }},
    )
    print(f"📣 Ad notification sent: {len(user_ids)} user(s), "
          f"{sent}/{len(tokens)} device(s) — ad {job.get('web_ad_id')}")


async def ad_notification_loop() -> None:
    """Background task started from main.py's lifespan.

    Deliberately a plain polling loop rather than a scheduler library: there
    is nothing to configure, nothing to keep in sync with the cron format,
    and a restart loses no state because every job's due time lives in the
    database.
    """
    await asyncio.sleep(45)   # let the API finish booting first
    while True:
        try:
            db = get_db()
            # Drain everything that is due, then go back to sleep. One job at
            # a time so a large audience can't hold the loop in one query.
            while True:
                job = await _claim_due_job(db)
                if job is None:
                    break
                try:
                    await _dispatch(db, job)
                except Exception as exc:  # noqa: BLE001
                    print(f"⚠️  ad notification dispatch failed: {exc}")
                    await db.ad_notifications.update_one(
                        {"_id": job["_id"]},
                        {"$set": {"status": "pending", "error": str(exc)[:300]}},
                    )
        except Exception as exc:  # noqa: BLE001 — the loop must never die
            print(f"⚠️  ad notification loop error: {exc}")
        await asyncio.sleep(_POLL_SECONDS)
