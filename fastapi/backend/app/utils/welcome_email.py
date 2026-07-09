"""
Welcome / promo email — sent ONCE to every newly registered user, whether
they signed up with email OTP or with the Google/Facebook button.

Purely additive and safe by design:
  • fire-and-forget (callers use asyncio.create_task — registration never
    waits for, or fails because of, this email);
  • silently no-ops when the user has no email address (phone-only signups)
    or when SMTP isn't configured;
  • never raises.
"""

import asyncio
import smtplib
import ssl
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from ..config import get_settings

settings = get_settings()


def _build_welcome_email(to_email: str, name: str) -> MIMEMultipart:
    display = name.strip() if name and name.strip() else "there"

    msg = MIMEMultipart("alternative")
    msg["Subject"] = "Welcome to Claimit — earn rewards on every bill! 🎉"
    msg["From"] = f"{settings.smtp_from_name} <{settings.smtp_username}>"
    msg["To"] = to_email

    plain = (
        f"Hi {display},\n\n"
        "Welcome to Claimit — thanks for joining!\n\n"
        "Here's what you can do with the app:\n"
        "  • Scan your shopping bills and earn 1% cashback + 10% reward points\n"
        "  • Redeem your points for real discounts at Redeem Zone shops near you\n"
        "  • Discover local deals, offers and new shops in your area\n\n"
        "Open the app, scan your first bill and watch your wallet grow!\n\n"
        "— The Claimit Team\n"
    )

    html = f"""
    <html>
      <body style="margin:0;padding:0;background:#f4f6fa;font-family:Arial,Helvetica,sans-serif;">
        <div style="max-width:520px;margin:24px auto;background:#ffffff;border-radius:12px;
                    overflow:hidden;border:1px solid #e5e7eb;">
          <div style="background:#1565C0;padding:28px 24px;text-align:center;">
            <h1 style="color:#ffffff;margin:0;font-size:24px;">Welcome to Claimit! 🎉</h1>
          </div>
          <div style="padding:28px 24px;">
            <p style="color:#111827;font-size:15px;">Hi <strong>{display}</strong>,</p>
            <p style="color:#374151;font-size:14px;line-height:1.7;">
              Thanks for joining Claimit — the app that turns your everyday
              shopping bills into real rewards.
            </p>
            <div style="background:#EFF6FF;border:1px solid #BFDBFE;border-radius:10px;
                        padding:16px 18px;margin:18px 0;">
              <p style="color:#1565C0;font-size:14px;margin:0 0 10px;font-weight:bold;">
                Here's what you can do:
              </p>
              <p style="color:#374151;font-size:13px;line-height:1.9;margin:0;">
                🧾 <strong>Scan your bills</strong> — earn 1% cashback + 10% reward points<br>
                🏪 <strong>Redeem points</strong> — get real discounts at Redeem Zone shops<br>
                🛍️ <strong>Discover deals</strong> — offers and new shops near you
              </p>
            </div>
            <p style="color:#374151;font-size:14px;line-height:1.7;">
              Open the app, scan your first bill and watch your wallet grow!
            </p>
            <p style="color:#374151;font-size:14px;margin-top:22px;">
              — The Claimit Team
            </p>
          </div>
          <hr style="border:none;border-top:1px solid #e5e7eb;margin:0;">
          <p style="color:#9ca3af;font-size:12px;text-align:center;padding:14px;">
            &copy; Claimit &mdash; Do not reply to this email.
          </p>
        </div>
      </body>
    </html>
    """
    msg.attach(MIMEText(plain, "plain"))
    msg.attach(MIMEText(html, "html"))
    return msg


def _send_sync(to_email: str, name: str) -> None:
    msg = _build_welcome_email(to_email, name)
    context = ssl.create_default_context()
    with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=8) as server:
        server.ehlo()
        server.starttls(context=context)
        server.login(settings.smtp_username, settings.smtp_password)
        server.sendmail(settings.smtp_username, to_email, msg.as_string())


async def send_welcome_email(email: str, name: str = "") -> None:
    """Send the promo/welcome email. Never raises, never blocks registration."""
    if not email or "@" not in email:
        return
    if not settings.smtp_username or not settings.smtp_password:
        print(f"⚠️  SMTP not configured — welcome email skipped for {email}")
        return
    try:
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, _send_sync, email, name)
        print(f"✅ Welcome email sent to {email}")
    except Exception as e:  # noqa: BLE001 — promo mail must never break signup
        print(f"❌ Welcome email failed for {email}: {e}")
