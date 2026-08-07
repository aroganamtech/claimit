"""
Twilio WhatsApp OTP diagnostic.

Run this ON THE SERVER, inside the backend's virtualenv, to see exactly what
Twilio does with an OTP WhatsApp message — no app, no guessing.

    python twilio_test.py +91XXXXXXXXXX

It will:
  1. Show which Twilio settings are loaded (secrets masked).
  2. Verify the account SID + auth token actually authenticate.
  3. Send a real WhatsApp message to the number you pass.
  4. Wait a few seconds and re-fetch the message to show its delivery
     status and any Twilio error code/message (the real reason it didn't
     arrive).

Reads the same .env as the app (TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN,
TWILIO_WHATSAPP_NUMBER, TWILIO_OTP_TEMPLATE_SID).
"""
import os
import sys
import time
import json

try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass


def mask(v: str) -> str:
    if not v:
        return "(empty)"
    v = v.strip()
    return v[:6] + "…" + v[-4:] if len(v) > 12 else "***"


def e164(phone: str) -> str:
    p = phone.strip().replace(" ", "").replace("-", "").replace(".", "")
    if p.startswith("+"):
        return p
    if len(p) == 10:
        return "+91" + p
    return "+" + p.lstrip("+")


def main():
    if len(sys.argv) < 2:
        print("Usage: python twilio_test.py +91XXXXXXXXXX")
        sys.exit(1)

    to_raw = sys.argv[1]
    to = e164(to_raw)

    sid = (os.getenv("TWILIO_ACCOUNT_SID") or "").strip()
    token = (os.getenv("TWILIO_AUTH_TOKEN") or "").strip()
    wa_from = (os.getenv("TWILIO_WHATSAPP_NUMBER") or "").strip()
    template = (os.getenv("TWILIO_OTP_TEMPLATE_SID") or "").strip()

    print("─" * 60)
    print("Twilio settings loaded from .env:")
    print(f"  TWILIO_ACCOUNT_SID       : {mask(sid)}  (starts with 'AC': {sid.startswith('AC')})")
    print(f"  TWILIO_AUTH_TOKEN        : {mask(token)}")
    print(f"  TWILIO_WHATSAPP_NUMBER   : {wa_from or '(empty)'}")
    print(f"  TWILIO_OTP_TEMPLATE_SID  : {template or '(empty)  → sandbox free-form mode'}")
    print(f"  Sending TO               : {to}  (from raw '{to_raw}')")
    print("─" * 60)

    # Hidden-character check — CRLF / stray whitespace has broken this before.
    for name, val in [("SID", sid), ("TOKEN", token), ("WA_FROM", wa_from)]:
        raw = os.getenv({"SID": "TWILIO_ACCOUNT_SID", "TOKEN": "TWILIO_AUTH_TOKEN",
                         "WA_FROM": "TWILIO_WHATSAPP_NUMBER"}[name]) or ""
        if raw != raw.strip() or "\r" in raw:
            print(f"⚠️  {name} has stray whitespace or a carriage return (\\r). "
                  f"Run:  sed -i 's/\\r$//' .env")

    if not sid or not token:
        print("❌ SID or token missing — cannot continue.")
        sys.exit(1)

    from twilio.rest import Client
    from twilio.base.exceptions import TwilioRestException

    client = Client(sid, token)

    # 1) Do the credentials authenticate at all?
    try:
        acct = client.api.accounts(sid).fetch()
        print(f"✅ Auth OK — account '{acct.friendly_name}', status: {acct.status}")
    except TwilioRestException as e:
        print(f"❌ Auth FAILED (code {e.code}): {e.msg}")
        print("   → The SID/token in .env are wrong or mismatched. Copy them fresh "
              "from the Twilio Console dashboard.")
        sys.exit(1)

    if not wa_from:
        print("❌ TWILIO_WHATSAPP_NUMBER is empty — set it (sandbox: +14155238886).")
        sys.exit(1)

    # 2) Send the message.
    otp = "123456"
    print(f"\nSending WhatsApp test (OTP {otp}) …")
    try:
        if template:
            msg = client.messages.create(
                from_=f"whatsapp:{wa_from}",
                to=f"whatsapp:{to}",
                content_sid=template,
                content_variables=json.dumps({"1": otp}),
            )
            print("   (used approved template)")
        else:
            msg = client.messages.create(
                from_=f"whatsapp:{wa_from}",
                to=f"whatsapp:{to}",
                body=f"🔐 Your Claimit test OTP is: {otp}",
            )
            print("   (used sandbox free-form body)")
    except TwilioRestException as e:
        print(f"❌ Send REJECTED immediately (code {e.code}): {e.msg}")
        _explain(e.code)
        sys.exit(1)

    print(f"✅ Accepted by Twilio. Message SID: {msg.sid}, initial status: {msg.status}")

    # 3) Poll for the final delivery status.
    print("\nWaiting for delivery status …")
    for _ in range(6):
        time.sleep(3)
        m = client.messages(msg.sid).fetch()
        print(f"   status = {m.status}"
              + (f" | error {m.error_code}: {m.error_message}" if m.error_code else ""))
        if m.status in ("delivered", "read", "failed", "undelivered"):
            if m.error_code:
                _explain(m.error_code)
            break

    print("\nDone. If status is 'delivered'/'read', Twilio is working. "
          "If 'failed'/'undelivered' with an error code, see the note above.")


def _explain(code):
    notes = {
        63007: "The 'from' WhatsApp number isn't a valid sender on this account. "
               "For sandbox use +14155238886; for production use your approved "
               "WhatsApp Business number. Also confirm the SID matches the account "
               "that owns that number.",
        63016: "Production send without an approved template to a user outside the "
               "24-hour window. Set TWILIO_OTP_TEMPLATE_SID to your approved "
               "authentication template.",
        63015: "The recipient hasn't opted in. In the SANDBOX, this phone must first "
               "send  join <your-sandbox-keyword>  to +14155238886 on WhatsApp.",
        21211: "The 'to' number isn't valid E.164. Check the number you passed.",
        63003: "Recipient can't be reached — no WhatsApp account on that number, or "
               "not joined to the sandbox.",
    }
    if code in notes:
        print(f"   ℹ️  {notes[code]}")
    else:
        print(f"   ℹ️  Look up error {code} at twilio.com/docs/api/errors/{code}")


if __name__ == "__main__":
    main()
