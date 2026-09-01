#!/usr/bin/env python3
"""
check_twilio.py — verify the Twilio WhatsApp OTP setup on this server.

Run it ON THE SERVER, from the folder that holds the .env:

    cd /home/ubuntu/claimit_local_production
    python3 check_twilio.py                      # check configuration only
    python3 check_twilio.py +919884190908        # also send one real test OTP

What it does
------------
1. Reads the .env next to it and shows each Twilio setting MASKED — you can
   confirm a value is present and ends correctly without ever printing the
   secret in full.
2. Asks Twilio to confirm the Account SID and Auth Token actually work.
3. Lists every Content template on the account, with its SID and how many
   variables it expects — this is where you find your Authentication
   template SID.
4. Checks the template named in TWILIO_OTP_TEMPLATE_SID really exists and
   takes exactly one variable.
5. If you pass a phone number, sends a real OTP through the template and
   reports what Twilio says about it.

Nothing here changes any setting. It only reads.
"""
import json
import os
import random
import sys

GREEN, RED, YELL, DIM, END = "\033[92m", "\033[91m", "\033[93m", "\033[2m", "\033[0m"
OK, BAD, WARN = f"{GREEN}OK{END}", f"{RED}PROBLEM{END}", f"{YELL}CHECK{END}"


def load_env(path=".env"):
    """Minimal .env reader — avoids needing python-dotenv installed."""
    values = {}
    if not os.path.exists(path):
        print(f"{BAD}  No .env found at {os.path.abspath(path)}")
        print("        Run this from the folder that contains your .env file.")
        sys.exit(1)
    for line in open(path, encoding="utf-8", errors="ignore"):
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        values[k.strip()] = v.strip().strip('"').strip("'")
    return values


def mask(value: str, keep: int = 4) -> str:
    """Show only the last few characters, so a value can be compared safely."""
    if not value:
        return "(empty)"
    if len(value) <= keep:
        return "*" * len(value)
    return f"{'*' * (len(value) - keep)}{value[-keep:]}  ({len(value)} chars)"


def main():
    print()
    print("=" * 68)
    print("  Claimit — Twilio WhatsApp OTP configuration check")
    print("=" * 68)

    env = load_env()

    # ── 1. What is configured ────────────────────────────────────────────────
    print("\n1. Settings found in .env")
    sid       = env.get("TWILIO_ACCOUNT_SID", "")
    token     = env.get("TWILIO_AUTH_TOKEN", "")
    wa_number = env.get("TWILIO_WHATSAPP_NUMBER", "")
    tmpl_sid  = env.get("TWILIO_OTP_TEMPLATE_SID", "")

    welcome_sid = env.get("TWILIO_WELCOME_TEMPLATE_SID", "")
    notify_sid  = env.get("TWILIO_NOTIFY_TEMPLATE_SID", "")

    print(f"   TWILIO_ACCOUNT_SID           {mask(sid, 6)}")
    print(f"   TWILIO_AUTH_TOKEN            {mask(token)}")
    print(f"   TWILIO_WHATSAPP_NUMBER       {wa_number or '(empty)'}")
    print(f"   TWILIO_OTP_TEMPLATE_SID      {tmpl_sid or '(empty)'}")
    print(f"   TWILIO_WELCOME_TEMPLATE_SID  {welcome_sid or '(empty — welcome not sent on WhatsApp)'}")
    print(f"   TWILIO_NOTIFY_TEMPLATE_SID   {notify_sid or '(empty — notifications not sent on WhatsApp)'}")

    problems = []

    if not sid.startswith("AC"):
        problems.append("TWILIO_ACCOUNT_SID should start with 'AC'.")
    if not token:
        problems.append("TWILIO_AUTH_TOKEN is empty.")
    if not wa_number:
        problems.append("TWILIO_WHATSAPP_NUMBER is empty.")
    elif not wa_number.startswith("+"):
        problems.append(f"TWILIO_WHATSAPP_NUMBER should start with '+' (got {wa_number}).")
    elif "14155238886" in wa_number:
        problems.append(
            "TWILIO_WHATSAPP_NUMBER is still the Twilio SANDBOX number. Real "
            "customers will NOT receive anything — only phones that joined the "
            "sandbox do. Replace it with your approved sender."
        )
    if not tmpl_sid:
        problems.append("TWILIO_OTP_TEMPLATE_SID is empty — OTP will fall back to "
                        "a plain message, which only works in the sandbox.")
    elif not tmpl_sid.startswith("HX"):
        problems.append("TWILIO_OTP_TEMPLATE_SID should start with 'HX'.")

    # ── 2. Do the credentials actually work? ─────────────────────────────────
    print("\n2. Asking Twilio whether these credentials work")
    try:
        from twilio.rest import Client
    except ImportError:
        print(f"   {BAD}  The 'twilio' package is not installed here.")
        print("           Fix: pip install twilio")
        sys.exit(1)

    if not (sid and token):
        print(f"   {BAD}  Cannot test — Account SID or Auth Token missing.")
        _summary(problems)
        return

    client = Client(sid, token)
    try:
        account = client.api.accounts(sid).fetch()
        print(f"   {OK}  Credentials accepted.")
        print(f"        Account name   : {account.friendly_name}")
        print(f"        Account status : {account.status}")
        if account.status != "active":
            problems.append(f"Twilio account status is '{account.status}', not 'active'.")
    except Exception as e:
        print(f"   {BAD}  Twilio rejected these credentials.")
        print(f"        {e}")
        problems.append("Account SID / Auth Token are wrong or the account is suspended.")
        _summary(problems)
        return

    # ── 3. Templates on this account ─────────────────────────────────────────
    print("\n3. Content templates on this account")
    templates = {}
    try:
        for c in client.content.v1.contents.list(limit=100):
            variables = c.variables or {}
            types = list((c.types or {}).keys())
            templates[c.sid] = {
                "name": c.friendly_name,
                "vars": len(variables),
                "types": types,
                "language": c.language,
            }
        if not templates:
            print(f"   {WARN}  No templates found on this account.")
        for s, t in templates.items():
            marker = " <-- configured for OTP" if s == tmpl_sid else ""
            kind = ", ".join(t["types"]) or "unknown type"
            print(f"   {s}  {t['name']}")
            print(f"        {DIM}{kind} · {t['language']} · {t['vars']} variable(s){END}{marker}")
    except Exception as e:
        print(f"   {WARN}  Could not list templates: {e}")

    # ── 4. Are the configured templates usable? ──────────────────────────────
    # Each message type needs a template with the exact number of variables
    # the code fills in. A mismatch fails at send time with error 63016, which
    # is much harder to diagnose than catching it here.
    print("\n4. Templates configured for each message type")
    checks = [
        ("OTP",           tmpl_sid,    1, "TWILIO_OTP_TEMPLATE_SID",     "{{1}} = the code"),
        ("Welcome",       welcome_sid, 1, "TWILIO_WELCOME_TEMPLATE_SID", "{{1}} = name"),
        ("Notifications", notify_sid,  2, "TWILIO_NOTIFY_TEMPLATE_SID",  "{{1}} = title, {{2}} = message"),
    ]
    for label, s, want_vars, env_key, shape in checks:
        print(f"\n   {label}  ({shape})")
        if not s:
            print(f"   {WARN}  {env_key} is empty — this message type does NOT go to")
            print("           WhatsApp. In-app notifications and push are unaffected.")
            continue
        if s not in templates:
            print(f"   {BAD}  {s} was not found on this account.")
            problems.append(f"{env_key} does not match any template on this account.")
            continue
        t = templates[s]
        print(f"   {OK}  {t['name']}  ·  {t['vars']} variable(s)")
        if t["vars"] != want_vars:
            print(f"   {BAD}  Expects {t['vars']} variable(s) but the code sends {want_vars}.")
            problems.append(
                f"Template '{t['name']}' has {t['vars']} variable(s); the code sends "
                f"{want_vars}. Fix the template body or it will fail with error 63016."
            )
        if label == "OTP" and not any("authentication" in x.lower() for x in t["types"]):
            print(f"   {WARN}  Not an Authentication template. WhatsApp expects")
            print("           verification codes to use the Authentication category.")

    # ── 5. Optional live test ────────────────────────────────────────────────
    if len(sys.argv) > 1:
        to = sys.argv[1].strip()
        if not to.startswith("+"):
            print(f"\n{BAD}  Test number must be in E.164 form, e.g. +919884190908")
            _summary(problems)
            return
        code = "".join(random.choices("0123456789", k=6))
        print(f"\n5. Sending a real test OTP to {to}")
        print(f"   Code being sent: {code}")
        try:
            kwargs = dict(from_=f"whatsapp:{wa_number}", to=f"whatsapp:{to}")
            if tmpl_sid:
                kwargs["content_sid"] = tmpl_sid
                kwargs["content_variables"] = json.dumps({"1": code})
            else:
                kwargs["body"] = f"Your Claimit test code is {code}"
            msg = client.messages.create(**kwargs)
            print(f"   {OK}  Accepted by Twilio.")
            print(f"        Message SID : {msg.sid}")
            print(f"        Status      : {msg.status}")
            print(f"\n   {DIM}'queued' or 'accepted' means Twilio took it. Check delivery with:")
            print(f"   python3 check_twilio.py --status {msg.sid}{END}")
        except Exception as e:
            print(f"   {BAD}  Twilio refused the message.")
            print(f"        {e}")
            print(f"\n   {DIM}Common causes:")
            print("     63016 — template not approved, or wrong variable count")
            print("     63007 — the 'from' number is not a registered WhatsApp sender")
            print("     21211 — the 'to' number is not valid WhatsApp{END}")
            problems.append("The live test send failed — see the error above.")

    _summary(problems)


def _summary(problems):
    print("\n" + "=" * 68)
    if not problems:
        print(f"  {GREEN}Everything checks out.{END}")
    else:
        print(f"  {RED}{len(problems)} thing(s) to fix:{END}")
        for i, p in enumerate(problems, 1):
            print(f"    {i}. {p}")
    print("=" * 68 + "\n")


if __name__ == "__main__":
    # --status <SID> : look up what happened to a message you already sent
    if len(sys.argv) > 2 and sys.argv[1] == "--status":
        env = load_env()
        from twilio.rest import Client
        c = Client(env.get("TWILIO_ACCOUNT_SID", ""), env.get("TWILIO_AUTH_TOKEN", ""))
        m = c.messages(sys.argv[2]).fetch()
        print(f"\n  Status     : {m.status}")
        print(f"  To         : {m.to}")
        print(f"  Error code : {m.error_code or '-'}")
        print(f"  Error      : {m.error_message or '-'}\n")
    else:
        main()
