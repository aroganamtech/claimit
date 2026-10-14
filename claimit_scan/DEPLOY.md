# Claimit Scan Service — deployment

A third FastAPI service on 127.0.0.1:8003, behind nginx at `/scan/`.

**It does not touch `claimit.service` (8001) or `claimit_web.service` (8002).**
Separate process, separate database, separate credential. Nothing is edited in
either of them, and nothing is restarted except nginx (reload, not restart).

Run these on your PC. `$key` and `$server` as usual.

---

## 1. Azure — in the portal

1. Create resource → **Document Intelligence**
2. Region **Central India** · Pricing tier **F0** (free, 500/month)
3. Open the resource → **Keys and Endpoint** → copy **Endpoint** and **KEY 1**

Keep the key out of chat, out of git, out of the APK. It goes in one place:
the server `.env` in step 4.

---

## 2. Copy the service up

```powershell
Get-ChildItem -Recurse -Filter "__pycache__" "F:\my_project_git\claimit\claimit_scan" | Remove-Item -Recurse -Force

ssh -i $key $server "mkdir -p ~/claimit_scan"
scp -i $key -r "F:\my_project_git\claimit\claimit_scan\app" "${server}:/home/ubuntu/claimit_scan/"
scp -i $key -r "F:\my_project_git\claimit\claimit_scan\deploy" "${server}:/home/ubuntu/claimit_scan/"
scp -i $key "F:\my_project_git\claimit\claimit_scan\requirements.txt" "${server}:/home/ubuntu/claimit_scan/requirements.txt"
```

---

## 3. Virtualenv

```powershell
ssh -i $key $server "cd ~/claimit_scan && python3 -m venv venv && venv/bin/pip install -q -r requirements.txt && echo installed"
```

---

## 4. Database user — the important one

This is the control that matters given September. The scan service gets
`readWrite` on `claimit_scan` **and nothing else**. If it is ever compromised,
the attacker cannot read your users, cannot read the wallet ledger, and cannot
drop the app database, because this credential has no rights there.

```powershell
ssh -i $key $server "cd ~/claimit_scan && bash deploy/setup_mongo_scan_user.sh"
```

It prints a `MONGODB_URL`. Copy it.

Now build the `.env` on the server — never on your PC, never in git:

```powershell
ssh -i $key $server "nano ~/claimit_scan/.env"
```

```
AZURE_DI_ENDPOINT=https://<your-resource>.cognitiveservices.azure.com
AZURE_DI_KEY=<KEY 1 from step 1>
MONGODB_URL=<the line the script printed>
SCAN_DB_NAME=claimit_scan
JWT_SECRET=<must match claimit_local_production/.env exactly>
S3_BUCKET_NAME=claimit-image-bucket
AWS_REGION=eu-north-1
ALLOWED_ORIGINS=https://claimit-web-aro.web.app
```

Get `JWT_SECRET` with:

```powershell
ssh -i $key $server "grep ^JWT_SECRET /home/ubuntu/claimit_local_production/.env"
```

Then lock it:

```powershell
ssh -i $key $server "chmod 600 ~/claimit_scan/.env && ls -l ~/claimit_scan/.env"
```

---

## 5. systemd

```powershell
ssh -i $key $server "sudo cp ~/claimit_scan/deploy/claimit_scan.service /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable --now claimit_scan && sleep 3 && systemctl is-active claimit_scan"
```

Expect `active`. If not:

```powershell
ssh -i $key $server "journalctl -u claimit_scan -n 40 --no-pager"
```

The service **refuses to start** with a missing secret rather than running
half-configured, so a failure here names the variable.

---

## 6. nginx

Add the block from `deploy/nginx-scan.conf` **inside your existing server
block**. Do not create a new server block and do not touch the 8001 or 8002
entries.

```powershell
ssh -i $key $server "sudo nano /etc/nginx/sites-available/<your site>"
ssh -i $key $server "sudo nginx -t && sudo systemctl reload nginx"
```

`reload`, not `restart` — reload does not drop live connections to the other
two services.

**Do not open 8003 in the security group.** nginx proxies it; the port stays
on localhost.

---

## 7. Verify

```powershell
curl http://16.170.110.232/scan/health
```

Expect `{"status":"healthy","service":"scan"}`.

Then with a real app token:

```powershell
curl -X POST http://16.170.110.232/scan/upload-url -H "Authorization: Bearer <token>" -H "Content-Type: application/json" -d "{\"content_type\":\"image/jpeg\"}"
```

Expect `upload_url` and `key`. Without a token: `401`.

---

## 8. Test before switching the app

Nothing is live yet — the app is still on the old Gemini path.

1. PUT a real bill photo to the `upload_url`
2. `POST /scan/read` with the returned `key`
3. Compare Azure's amount against what Gemini reads for the same bill
4. Repeat for **20 real bills**, including a faded thermal one and a crumpled one
5. Re-submit the same photo → expect `409 duplicate_image`
6. Photograph the same bill again at a different angle → expect
   `409 duplicate_receipt` (this is the check pHash cannot do)

Only when those pass, point the app at `/scan/*` and ship the APK.

---

## 9. After the app is switched and stable

- Remove the Gemini and Groq paths from the app
- Delete `geminiApiKey` and `groqApiKey` from `app_constants.dart`
- **Revoke both keys in their consoles** — they are in shipped APKs and must
  be assumed public

---

## Security notes

| Control | Where |
|---|---|
| Scoped DB user, `readWrite` on one database | `setup_mongo_scan_user.sh` |
| Azure key server-side only, never in the APK | `.env`, chmod 600 |
| Bound to 127.0.0.1; 8003 never opened publicly | systemd + security group |
| Customer cannot submit another user's image | `storage.owns_key()` |
| Admin tokens rejected on customer endpoints | `security.current_user()` |
| Per-user rate limit, minute and day | `security.rate_limit()` |
| Amount never accepted from the client | `routes.py` — no amount field exists |
| Duplicate rules enforced by unique indexes | `db.ensure_indexes()` |
| Memory capped at 400 MB | `MemoryMax` in the unit file |
| Stack traces never returned to clients | middleware in `main.py` |
| No OpenAPI schema served | `docs_url=None` in `main.py` |

The wallet credit deliberately stays in the app API, which owns the ledger.
This service records an approved claim; it holds no write credential on the
main database at all.
