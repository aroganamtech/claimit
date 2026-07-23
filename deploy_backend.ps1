# deploy_backend.ps1
# Pushes the Redeem Zone backend changes (admin.py, bill.py, shop.py) to the
# live server (the FastAPI backend the Flutter app talks to) and restarts
# whatever is currently serving them on port 8001.
#
# Run from PowerShell:  .\deploy_backend.ps1

$Key       = "C:\Users\sk764\OneDrive\Documents\GitHub\claimit\claimit.pem"
$Server    = "ubuntu@16.170.110.232"
$Backend   = "C:\Users\sk764\OneDrive\Documents\GitHub\claimit\claimit_web_org\fastapi\backend"
$Local     = "$Backend\routers"
$LocalUtil = "$Backend\utils"

Write-Host "Locating the backend folder on the server..." -ForegroundColor Cyan
$RemoteDir = (ssh -i $Key $Server "find /home /opt /srv /var/www -maxdepth 8 -type d -path '*claimit_web_org*backend/routers' 2>/dev/null | head -1").Trim()

if (-not $RemoteDir) {
    Write-Host "Could not find the routers folder automatically on the server." -ForegroundColor Red
    Write-Host "Tell me the exact remote path (e.g. /home/ubuntu/claimit/claimit_web_org/fastapi/backend/routers) and I'll hardcode it." -ForegroundColor Red
    exit 1
}
Write-Host "Found: $RemoteDir" -ForegroundColor Green
$RemoteBackend = $RemoteDir -replace '/routers$', ''
$RemoteUtils   = "$RemoteBackend/utils"

Write-Host "`nCopying admin.py, bill.py, shop.py, advertiser.py, payments.py..." -ForegroundColor Cyan
scp -i $Key "$Local\admin.py" "$Local\bill.py" "$Local\shop.py" "$Local\advertiser.py" "$Local\payments.py" "${Server}:${RemoteDir}/"

Write-Host "`nCopying utils/cashfree.py and main.py..." -ForegroundColor Cyan
scp -i $Key "$LocalUtil\cashfree.py" "${Server}:${RemoteUtils}/"
scp -i $Key "$Backend\main.py" "${Server}:${RemoteBackend}/"

Write-Host "`nNOTE: .env is never auto-copied. If the server's .env doesn't already have Razorpay keys, add these two lines to it once (SSH in and edit), then re-run this script:" -ForegroundColor Yellow
Write-Host "  RAZORPAY_KEY_ID=rzp_live_xxxxxxxxxxxxxx      (use rzp_test_... for testing)" -ForegroundColor Yellow
Write-Host "  RAZORPAY_KEY_SECRET=your_razorpay_key_secret" -ForegroundColor Yellow

Write-Host "`nRestarting the backend..." -ForegroundColor Cyan
$RemoteScript = @'
set -e
if systemctl list-units --type=service --all 2>/dev/null | grep -qi claimit_web; then
  # Prefer the web backend service by exact name — this server also runs
  # claimit.service (the app backend on a different port); a plain
  # grep -i claimit would match either one unpredictably.
  SERVICE=$(systemctl list-units --type=service --all | grep -i claimit_web | awk '{print $1}' | head -1)
  echo "Restarting systemd service: $SERVICE"
  sudo systemctl restart "$SERVICE"
  sleep 2
  sudo systemctl is-active "$SERVICE"
elif systemctl list-units --type=service --all 2>/dev/null | grep -qi claimit; then
  SERVICE=$(systemctl list-units --type=service --all | grep -i claimit | awk '{print $1}' | head -1)
  echo "claimit_web.service not found — falling back to: $SERVICE (verify this is the web backend, not the app backend!)"
  sudo systemctl restart "$SERVICE"
  sleep 2
  sudo systemctl is-active "$SERVICE"
elif command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' | grep -qi claimit; then
  CONTAINER=$(docker ps --format '{{.Names}}' | grep -i claimit | head -1)
  echo "Restarting docker container: $CONTAINER"
  docker restart "$CONTAINER"
elif command -v pm2 >/dev/null 2>&1 && pm2 list 2>/dev/null | grep -qi claimit; then
  echo "Restarting via pm2"
  pm2 restart all
else
  echo "Could not auto-detect a service manager. Here's what's listening on port 8001:"
  sudo lsof -i :8001 2>/dev/null || sudo ss -tlnp | grep 8001
  echo "Restart it manually using whatever command started that process above."
fi
'@
ssh -i $Key $Server $RemoteScript

Write-Host "`nVerifying the backend is back up..." -ForegroundColor Cyan
Start-Sleep -Seconds 3
ssh -i $Key $Server "curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://localhost:8001/docs"
