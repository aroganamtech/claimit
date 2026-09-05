"""
ad_window.py — is this ad inside its paid week right now?

Ads are sold as a weekly Friday 00:00 → Thursday 23:59 slot (see the web
backend's utils/ad_cycle.py). An ad booked on a Tuesday is written with next
Friday's dates and the status "scheduled". Nothing on the server wakes up on
Friday morning to flip it — instead every read asks this module, so an ad goes
live and expires exactly on time with no cron job to fail silently.

Two things this gets right that the old per-endpoint checks did not:

1. It checks the END date. The banners endpoint only ever checked the start,
   so a finished campaign kept showing forever.

2. It never compares a date to a "dd/mm/yyyy" STRING inside MongoDB. BSON
   orders Date before String, so `{"end_date": {"$gt": now}}` matches every
   string row rather than filtering them — silently, with no error. New ads
   carry real `publish_at` / `ends_at` datetimes; older ones are parsed here in
   Python where a string comparison actually behaves.

Ads created before the weekly cycle existed have neither field. Those are
treated as live, so nothing already running disappears.
"""
from datetime import datetime, timedelta, timezone
from typing import Optional

IST = timezone(timedelta(hours=5, minutes=30))


def _as_datetime(value) -> Optional[datetime]:
    """Read a datetime, a 'dd/mm/yyyy' string, or an ISO string. None when the
    value is missing or unreadable — the caller then treats it as 'no limit'
    rather than guessing."""
    if value is None or value == "":
        return None
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=IST)
    text = str(value).strip()
    for fmt in ("%d/%m/%Y", "%Y-%m-%d", "%d-%m-%Y"):
        try:
            return datetime.strptime(text, fmt).replace(tzinfo=IST)
        except ValueError:
            pass
    try:
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
        return parsed if parsed.tzinfo else parsed.replace(tzinfo=IST)
    except ValueError:
        return None


def is_live(doc: dict, now: Optional[datetime] = None) -> bool:
    """True when the ad should be visible to customers right now.

    Rules, in order:
      • status "paused"/"cancelled"/"expired"/"deleted" → never shown
      • start date in the future                       → not yet (scheduled)
      • end date in the past                           → finished
      • no dates at all                                → shown (pre-cycle ad)
    """
    moment = now or datetime.now(IST)
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=IST)

    status = str(doc.get("status") or "active").strip().lower()
    if status in ("paused", "cancelled", "canceled", "expired",
                  "deleted", "rejected", "draft"):
        return False

    start = _as_datetime(doc.get("publish_at") or doc.get("publish_date"))
    if start is not None and moment < start:
        return False

    end = _as_datetime(doc.get("ends_at") or doc.get("end_date"))
    if end is not None:
        # A plain "dd/mm/yyyy" end date means the whole of that day is still
        # valid — an ad ending "10/09/2026" must run until 10 Sep 23:59, not
        # vanish at midnight as it starts.
        if not isinstance(doc.get("ends_at"), datetime):
            end = end + timedelta(days=1) - timedelta(seconds=1)
        if moment > end:
            return False

    return True


def filter_live(docs, now: Optional[datetime] = None) -> list:
    """Keep only the ads inside their paid window."""
    moment = now or datetime.now(IST)
    return [d for d in docs if is_live(d, moment)]
