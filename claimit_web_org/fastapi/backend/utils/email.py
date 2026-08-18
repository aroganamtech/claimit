"""
Shared SMTP email sender — used anywhere the website needs to send a
transactional email (OTP codes, verification, etc). Reads SMTP_HOST /
SMTP_PORT / SMTP_USERNAME / SMTP_PASSWORD from .env (same keys the app
backend already uses for its welcome email, so the same credentials work
here unchanged).
"""
import os
import re
import smtplib
import ssl
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText


def send_email(to_email: str, subject: str, html: str) -> bool:
    """Send a transactional email over SMTP. Sends both a plain-text and an
    HTML part (multipart/alternative) instead of HTML-only — HTML-only mail
    is one of the more common spam-filter triggers, so this alone meaningfully
    improves inbox placement. Returns False (never raises) if SMTP creds
    aren't set in .env, so the caller can fall back to a dev OTP for testing."""
    user = os.getenv("SMTP_USERNAME", "")
    pw = os.getenv("SMTP_PASSWORD", "")
    if not user or not pw:
        return False

    # Plain-text fallback so every mail client (and every spam filter) sees
    # a readable version even without HTML rendering.
    text = re.sub(r"<[^>]+>", " ", html)
    text = re.sub(r"\s+", " ", text).strip()

    from_name = os.getenv("SMTP_FROM_NAME", "Claimit")
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"{from_name} <{user}>"
    msg["To"] = to_email
    msg["Reply-To"] = user
    msg.attach(MIMEText(text, "plain"))
    msg.attach(MIMEText(html, "html"))

    ctx = ssl.create_default_context()
    with smtplib.SMTP(os.getenv("SMTP_HOST", "smtp.gmail.com"),
                      int(os.getenv("SMTP_PORT", "587")), timeout=8) as srv:
        srv.ehlo()
        srv.starttls(context=ctx)
        srv.login(user, pw)
        srv.sendmail(user, to_email, msg.as_string())
    return True
