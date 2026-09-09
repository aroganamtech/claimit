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
import os
import smtplib
import ssl
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from ..config import get_settings

settings = get_settings()


async def _new_user_bonus() -> dict:
    """The joining bonus the user has actually been given.

    Reads the SAME app_config document the wallet uses (key "new_user_bonus",
    written by the admin panel's PUT /admin/app-config), so when admin changes
    the free amount the email changes with it. Falls back to the env vars and
    then the hard-coded defaults, exactly like bill.py does — the email must
    never quote a figure the wallet didn't actually credit.
    """
    default_pts = int(os.getenv("NEW_USER_REWARD_POINTS", "1000"))
    default_cb = float(os.getenv("NEW_USER_CASHBACK", "10.0"))
    try:
        from ..database import get_db
        cfg = await get_db().app_config.find_one({"key": "new_user_bonus"})
        if cfg:
            return {
                "reward_points": int(cfg.get("reward_points", default_pts)),
                "cashback": float(cfg.get("cashback", default_cb)),
            }
    except Exception:
        pass
    return {"reward_points": default_pts, "cashback": default_cb}


def _money(value: float) -> str:
    """₹10 rather than ₹10.0, but ₹10.50 keeps its paise."""
    return f"{value:.2f}".rstrip("0").rstrip(".")


def _build_welcome_email(to_email: str, name: str, bonus: dict) -> MIMEMultipart:
    display = name.strip() if name and name.strip() else "there"
    cashback = _money(float(bonus.get("cashback", 0)))
    points = f"{int(bonus.get('reward_points', 0)):,}"

    msg = MIMEMultipart("alternative")
    msg["Subject"] = "Welcome to Claimit — earn rewards on every bill! 🎉"
    msg["From"] = f"{settings.smtp_from_name} <{settings.smtp_username}>"
    msg["To"] = to_email

    plain = (
        f"Hi {display},\n\n"
        "Welcome to Claimit — thanks for joining!\n\n"
        "Your joining bonus is already in your wallet:\n"
        f"  • Rs {cashback} cashback\n"
        f"  • {points} reward points\n\n"
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
            <!-- Joining bonus. Figures come from the same admin config the
                 wallet is credited from, so they can never disagree with the
                 balance the user actually sees in the app. -->
            <div style="background:#FFF8E1;border:1px solid #F4C430;border-radius:10px;
                        padding:16px 18px;margin:18px 0;">
              <p style="color:#8A5A00;font-size:14px;margin:0 0 10px;font-weight:bold;">
                🎁 Your joining bonus is already in your wallet
              </p>
              <table role="presentation" cellpadding="0" cellspacing="0" width="100%">
                <tr>
                  <td width="50%" style="text-align:center;padding:6px 4px;">
                    <div style="font-size:22px;line-height:1;">💰</div>
                    <div style="color:#1565C0;font-size:20px;font-weight:bold;
                                margin-top:4px;">&#8377;{cashback}</div>
                    <div style="color:#6B7280;font-size:12px;">cashback</div>
                  </td>
                  <td width="50%" style="text-align:center;padding:6px 4px;">
                    <div style="font-size:22px;line-height:1;">⭐</div>
                    <div style="color:#1565C0;font-size:20px;font-weight:bold;
                                margin-top:4px;">{points}</div>
                    <div style="color:#6B7280;font-size:12px;">reward points</div>
                  </td>
                </tr>
              </table>
            </div>
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


def _send_sync(to_email: str, name: str, bonus: dict) -> None:
    msg = _build_welcome_email(to_email, name, bonus)
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
        # Read the bonus BEFORE going to the thread pool: the Motor client is
        # bound to this event loop and cannot be used from an executor thread.
        bonus = await _new_user_bonus()
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, _send_sync, email, name, bonus)
        print(f"✅ Welcome email sent to {email}")
    except Exception as e:  # noqa: BLE001 — promo mail must never break signup
        print(f"❌ Welcome email failed for {email}: {e}")
