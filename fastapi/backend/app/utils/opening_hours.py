"""
opening_hours.py — decide whether a shop is open right now.

Why this exists
---------------
The client's brief asks for an "Open Now" filter and an open/closed badge on
every result card. There is no structured opening-hours field in the database
and adding one would mean every existing merchant re-registering.

But there IS a `timing` field on shops and deals, filled in since day one,
holding text a human wrote:

    "Daily: 8am - 9pm"
    "Mon-Sat: 5am - 11pm | Sun: 6am - 9pm"
    "10:00 - 22:00"
    "24 Hours"
    "Mon to Sat 9.30 AM to 8.30 PM, Sunday Closed"

This module reads that text. It means Open Now works today, on the data that
already exists, with nothing for merchants to re-enter.

Design rules
------------
* Never raise. Bad or missing text returns None, meaning "we don't know" —
  which the API reports as a null `is_open` and the card simply omits.
* "We don't know" is never reported as "open". A shop is only ever called open
  when the text was understood and the clock falls inside a window.
* All comparisons are in IST, because every Claimit merchant is in India and
  the server runs in UTC.
"""
import re
from datetime import datetime, timedelta, timezone
from typing import List, Optional, Tuple

# The server runs UTC; merchants are in India. Doing this explicitly avoids
# depending on the server's local timezone, which is a classic silent bug.
IST = timezone(timedelta(hours=5, minutes=30))

# Monday = 0 … Sunday = 6, matching datetime.weekday().
_DAY_INDEX = {
    "mon": 0, "monday": 0,
    "tue": 1, "tues": 1, "tuesday": 1,
    "wed": 2, "weds": 2, "wednesday": 2,
    "thu": 3, "thur": 3, "thurs": 3, "thursday": 3,
    "fri": 4, "friday": 4,
    "sat": 5, "saturday": 5,
    "sun": 6, "sunday": 6,
}

_ALL_DAYS = (0, 1, 2, 3, 4, 5, 6)

# Every dash variant that turns up in real data, plus the word "to".
_DASH = r"(?:-|–|—|to|until|till)"

# "8am", "8:30 pm", "9.30AM", "20:00", "12 noon", "midnight"
_CLOCK = re.compile(
    r"(?P<h>\d{1,2})\s*(?:[:.](?P<m>\d{2}))?\s*(?P<ap>a\.?m\.?|p\.?m\.?)?",
    re.I,
)

_ALWAYS_OPEN = re.compile(
    r"24\s*(?:x\s*7|/\s*7|hours?|hrs?)|open\s*24|all\s*(?:day|time)", re.I
)
_CLOSED_WORD = re.compile(r"\bclosed\b|\bholiday\b|\boff\b", re.I)


def _clock_to_minutes(text: str) -> Optional[int]:
    """"8:30pm" -> 1230 minutes past midnight. None if it isn't a time."""
    if not text:
        return None
    t = text.strip().lower()

    if t in ("noon", "12 noon", "midday"):
        return 12 * 60
    if t in ("midnight", "12 midnight"):
        return 0

    m = _CLOCK.search(t)
    if not m:
        return None
    try:
        hour = int(m.group("h"))
    except (TypeError, ValueError):
        return None
    minute = int(m.group("m") or 0)
    ap = (m.group("ap") or "").replace(".", "").lower()

    if minute > 59:
        return None

    if ap == "pm":
        if hour < 12:
            hour += 12
    elif ap == "am":
        if hour == 12:          # 12am is midnight, not noon
            hour = 0
    elif hour > 23:
        return None

    if hour > 23:
        return None
    return hour * 60 + minute


def _days_from_text(text: str) -> Optional[Tuple[int, ...]]:
    """"Mon-Sat" -> (0,1,2,3,4,5). "Daily" -> all. None if no day named.

    None is meaningful: it lets the caller tell "this segment names no days,
    so the times apply every day" apart from "this segment names days".
    """
    t = text.lower()
    if re.search(r"daily|everyday|every\s*day|all\s*days|mon\s*(?:-|–|—|to)\s*sun", t):
        return _ALL_DAYS

    # A range: "mon-sat", "tue to fri"
    rng = re.search(
        r"\b(" + "|".join(_DAY_INDEX) + r")\b\s*(?:-|–|—|to)\s*\b("
        + "|".join(_DAY_INDEX) + r")\b", t)
    if rng:
        a, b = _DAY_INDEX[rng.group(1)], _DAY_INDEX[rng.group(2)]
        # Wraps across the weekend, e.g. "Sat-Mon".
        return tuple(sorted({(a + i) % 7 for i in range((b - a) % 7 + 1)}))

    # A list: "mon, wed, fri" or a single day.
    found = {_DAY_INDEX[d] for d in re.findall(
        r"\b(" + "|".join(_DAY_INDEX) + r")\b", t)}
    return tuple(sorted(found)) if found else None


def parse_timing(timing: str) -> Optional[List[Tuple[Tuple[int, ...], int, int]]]:
    """Free text -> [(days, start_minute, end_minute), …].

    Returns None when nothing could be understood, so the caller can say
    "unknown" rather than guessing. An empty list means the text was
    understood and says the place is never open (e.g. "Closed").
    """
    if not timing or not str(timing).strip():
        return None
    text = str(timing).strip()

    # "24 hours" wins outright, whatever else the text says.
    if _ALWAYS_OPEN.search(text):
        return [(_ALL_DAYS, 0, 24 * 60)]

    windows: List[Tuple[Tuple[int, ...], int, int]] = []
    understood_anything = False

    # Segments are separated by | ; or / — e.g.
    # "Mon-Sat: 5am - 11pm | Sun: 6am - 9pm"
    for segment in re.split(r"[|;]|(?<=[apm.])\s*/\s*", text):
        segment = segment.strip()
        if not segment:
            continue

        days = _days_from_text(segment)

        # "Sunday Closed" — understood, and contributes no open window.
        if _CLOSED_WORD.search(segment) and not re.search(_DASH, segment, re.I):
            understood_anything = True
            continue

        # Split the segment on the first dash that sits between two times.
        pair = re.search(
            r"(\d{1,2}(?:[:.]\d{2})?\s*(?:a\.?m\.?|p\.?m\.?)?)"
            r"\s*" + _DASH + r"\s*"
            r"(\d{1,2}(?:[:.]\d{2})?\s*(?:a\.?m\.?|p\.?m\.?)?)",
            segment, re.I,
        )
        if not pair:
            continue

        start = _clock_to_minutes(pair.group(1))
        end = _clock_to_minutes(pair.group(2))
        if start is None or end is None:
            continue

        # "10am - 10am" is meaningless; treat as unparsed rather than
        # a zero-length window that would make the shop never open.
        if start == end:
            continue

        understood_anything = True
        windows.append((days if days is not None else _ALL_DAYS, start, end))

    if not understood_anything:
        return None
    return windows


def is_open_now(timing: str, now: Optional[datetime] = None) -> Optional[bool]:
    """True / False / None ("we don't know").

    `now` is injectable so the behaviour can be tested at any hour without
    waiting for the clock.
    """
    windows = parse_timing(timing)
    if windows is None:
        return None
    if not windows:
        return False

    moment = (now or datetime.now(IST))
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=IST)
    else:
        moment = moment.astimezone(IST)

    today = moment.weekday()
    minutes = moment.hour * 60 + moment.minute
    yesterday = (today - 1) % 7

    for days, start, end in windows:
        if end > start:
            # A normal same-day window.
            if today in days and start <= minutes < end:
                return True
        else:
            # Crosses midnight, e.g. 6pm - 2am. Two chances to be open: late
            # on the listed day, or early on the day after it. Missing this
            # is why late-night restaurants look closed at 1am.
            if today in days and minutes >= start:
                return True
            if yesterday in days and minutes < end:
                return True
    return False
