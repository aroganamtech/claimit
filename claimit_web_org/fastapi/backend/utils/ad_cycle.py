"""
ad_cycle.py — every ad runs on the same weekly Friday-to-Thursday cycle.

The rule
--------
Ads do not start whenever they happen to be paid for. They run in fixed
week-long slots:

    Friday 00:00  →  Thursday 23:59:59   (IST)

An advertiser can submit and pay on ANY day. What they buy is the next slot:

  • Submit on Friday, before the week is over   → live that same Friday
  • Submit Saturday through Thursday            → live the coming Friday

So a Tuesday booking sits as "scheduled", the advertiser is shown the exact
dates before paying, and it goes live by itself when Friday arrives.

Why a fixed cycle at all
------------------------
The Premium slot caps only mean something if every ad in a slot competes over
the same window. With ads starting on arbitrary days, "3 Premium slots for
this pincode" was really "3 at any given instant", which is much harder to
sell and impossible for an advertiser to reason about.

Admin control
-------------
The start day lives in app_config so admin can move the cycle off Friday
without a redeploy. Everything below derives from that one number.

Applies to all four ad types: nearby_deals, brand_deals, home_banner and
promo_reelz.
"""
from datetime import datetime, time, timedelta, timezone
from typing import Optional

from database import app_db

# Every Claimit merchant and advertiser is in India, and the server runs UTC.
# Being explicit stops the cycle silently shifting by 5.5 hours.
IST = timezone(timedelta(hours=5, minutes=30))

# Monday = 0 … Sunday = 6, matching datetime.weekday(). 4 = Friday.
DEFAULT_START_WEEKDAY = 4
CYCLE_DAYS = 7

WEEKDAY_NAMES = ["Monday", "Tuesday", "Wednesday", "Thursday",
                 "Friday", "Saturday", "Sunday"]


async def get_start_weekday() -> int:
    """The weekday the cycle starts on, as set by admin. Falls back to Friday.

    Never raises and never returns something out of range — a bad value in the
    database must not stop ads being created.
    """
    try:
        cfg = await app_db["app_config"].find_one({"key": "ad_cycle"})
        if cfg and cfg.get("start_weekday") is not None:
            day = int(cfg["start_weekday"])
            if 0 <= day <= 6:
                return day
    except Exception:
        pass
    return DEFAULT_START_WEEKDAY


def cycle_for(now: datetime, start_weekday: int = DEFAULT_START_WEEKDAY):
    """The slot an ad submitted at `now` will run in.

    Returns (start, end) as timezone-aware IST datetimes, where start is
    00:00:00 on the start day and end is 23:59:59 on the day before the next
    cycle begins.

    Submitting ON the start day gives you that day's cycle, not next week's —
    an advertiser who pays on Friday morning expects to be live on Friday.
    """
    if not (0 <= start_weekday <= 6):
        start_weekday = DEFAULT_START_WEEKDAY

    moment = now.astimezone(IST) if now.tzinfo else now.replace(tzinfo=IST)

    # How many days forward to the next start day. 0 means today IS the start
    # day, which is what makes a Friday submission go live on Friday.
    days_ahead = (start_weekday - moment.weekday()) % 7

    start_date = (moment + timedelta(days=days_ahead)).date()
    start = datetime.combine(start_date, time(0, 0, 0), tzinfo=IST)
    end = start + timedelta(days=CYCLE_DAYS) - timedelta(seconds=1)
    return start, end


async def next_cycle(now: Optional[datetime] = None):
    """The cycle an ad created right now would run in, using the admin's day."""
    start_weekday = await get_start_weekday()
    return cycle_for(now or datetime.now(IST), start_weekday)


async def cycle_info(now: Optional[datetime] = None) -> dict:
    """Everything the advertiser form needs to explain the cycle BEFORE
    payment, so nobody pays expecting to be live today and isn't."""
    moment = (now or datetime.now(IST))
    moment = moment.astimezone(IST) if moment.tzinfo else moment.replace(tzinfo=IST)

    start_weekday = await get_start_weekday()
    start, end = cycle_for(moment, start_weekday)
    starts_today = start.date() == moment.date()
    days_to_wait = (start.date() - moment.date()).days

    return {
        "start_weekday": start_weekday,
        "start_day_name": WEEKDAY_NAMES[start_weekday],
        "end_day_name": WEEKDAY_NAMES[(start_weekday - 1) % 7],
        "cycle_days": CYCLE_DAYS,
        "publish_date": start.strftime("%d/%m/%Y"),
        "end_date": end.strftime("%d/%m/%Y"),
        "publish_at": start.isoformat(),
        "ends_at": end.isoformat(),
        "starts_today": starts_today,
        "days_to_wait": days_to_wait,
        # One sentence the form can show as-is.
        "message": (
            f"Your ad goes live today and runs until "
            f"{end.strftime('%d %b %Y')}."
            if starts_today else
            f"Ads run {WEEKDAY_NAMES[start_weekday]} to "
            f"{WEEKDAY_NAMES[(start_weekday - 1) % 7]}. Your ad will go live on "
            f"{start.strftime('%A, %d %b %Y')} and run until "
            f"{end.strftime('%A, %d %b %Y')}."
        ),
    }


def is_live(start: datetime, now: Optional[datetime] = None) -> bool:
    """Has this cycle begun? Used to decide 'active' versus 'scheduled'."""
    moment = (now or datetime.now(IST))
    moment = moment.astimezone(IST) if moment.tzinfo else moment.replace(tzinfo=IST)
    return moment >= start
