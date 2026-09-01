"""
Daily engagement push — once per day, at a RANDOM time between 10:00 and
20:00 IST, every app user gets a small "check new shops & deals" notification
to bring them back into the app.

Runs as a single in-process asyncio task started from main.py's lifespan.
Designed to be impossible to break anything:
  • the last-sent date is stored in app_config {"key": "daily_push"}, so a
    server restart can never double-send on the same day;
  • if the server restarts after 20:00 IST with nothing sent, that day is
    simply skipped (no late-night notifications);
  • every step is wrapped in try/except — a failure waits 10 min and retries;
  • production runs a single uvicorn worker, so there is exactly one scheduler.
"""

import asyncio
import random
from datetime import datetime, timedelta, timezone

from ..database import get_db
from .fcm import send_push_to_tokens

IST = timezone(timedelta(hours=5, minutes=30))

# Rotating message pool — a different one is picked at random each day.
_MESSAGES = [
    ("🛍️ New shops & deals are waiting!",
     "Open Claimit and check what's new near you today."),
    ("💰 Don't miss today's cashback!",
     "Scan your shopping bills and earn rewards on Claimit."),
    ("🏪 Fresh deals just dropped",
     "Check new shops and offers around you on Claimit."),
    ("🎁 Your rewards are waiting",
     "New shops, new deals — see what's new on Claimit today."),
    ("🔥 Deals near you are heating up",
     "Tap to explore new shops and today's best offers on Claimit."),
]

_WINDOW_START_H = 10   # 10:00 IST
_WINDOW_END_H   = 20   # 20:00 IST


async def _broadcast(title: str, body: str) -> None:
    """Send to every registered device token, chunked at FCM's 500 limit."""
    db = get_db()
    docs = await db.fcm_tokens.find({}, {"token": 1}).to_list(20000)
    tokens = list({d["token"] for d in docs if d.get("token")})
    if not tokens:
        print("📣 Daily push: no device tokens registered yet — skipping")
        return
    print(f"📣 Daily push: sending to {len(tokens)} device(s)")
    for i in range(0, len(tokens), 500):
        chunk = tokens[i:i + 500]
        invalid = await send_push_to_tokens(
            chunk, title, body, {"type": "daily_engagement"})
        if invalid:
            await db.fcm_tokens.delete_many({"token": {"$in": invalid}})


async def _already_sent(db, today: str) -> bool:
    cfg = await db.app_config.find_one({"key": "daily_push"})
    return bool(cfg) and cfg.get("last_sent_date") == today


async def daily_push_loop() -> None:
    await asyncio.sleep(30)   # let the API finish booting first
    while True:
        try:
            db = get_db()
            now = datetime.now(IST)
            today = now.strftime("%Y-%m-%d")

            window_end = now.replace(hour=_WINDOW_END_H, minute=0,
                                     second=0, microsecond=0)

            if await _already_sent(db, today) or now >= window_end:
                # Done for today (or window over) — sleep to just after
                # midnight IST and plan the next day.
                tomorrow = (now + timedelta(days=1)).replace(
                    hour=0, minute=5, second=0, microsecond=0)
                await asyncio.sleep(
                    max(60.0, (tomorrow - now).total_seconds()))
                continue

            # Pick a random moment in what's left of today's window
            window_start = now.replace(hour=_WINDOW_START_H, minute=0,
                                       second=0, microsecond=0)
            start = max(now, window_start)
            available = int((window_end - start).total_seconds())
            send_at = start + timedelta(
                seconds=random.randint(0, max(1, available)))

            wait = (send_at - datetime.now(IST)).total_seconds()
            if wait > 0:
                await asyncio.sleep(wait)

            # Re-check right before sending (protects against restarts
            # that happened during the long sleep)
            if not await _already_sent(db, today):
                title, body = random.choice(_MESSAGES)
                await _broadcast(title, body)
                await db.app_config.update_one(
                    {"key": "daily_push"},
                    {"$set": {
                        "last_sent_date": today,
                        "last_sent_at":   datetime.utcnow(),
                        "last_title":     title,
                    }},
                    upsert=True,
                )
        except Exception as exc:  # noqa: BLE001 — scheduler must never die
            print(f"⚠️  daily push loop error: {exc}")
            await asyncio.sleep(600)
