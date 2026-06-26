# deploy_app_backend.ps1
# Pushes app backend changes (fastapi/backend/app/*, run.py) to the
# live server (port 8001) and restarts the service.
#
# NOTE: .env is NOT copied — your server's .env likely has different
# production values (DB URI, secrets). Edit it manually on the server if needed.
#
# Run from PowerShell:  .\deploy_app_backend.ps1

$Key    = "C:\Users\sk764\OneDrive\Documents\GitHub\claimit\claimit.pem"
$Server = "ubuntu@16.170.110.232"
$Local  = "C:\Users\sk764\OneDrive\Documents\GitHub\claimit\fastapi\backend"

Write-Host "Locating the app backend folder on the server..." -ForegroundColor Cyan
$RemoteDir = (ssh -i $Key $Server "find /home /opt /srv /var/www -maxdepth 6 -type d -name backend 2>/dev/null | grep -v claimit_web_org | head -1").Trim()

if (-not $RemoteDir) {
    Write-Host "Could not find the app backend folder automatically on the server." -ForegroundColor Red
    Write-Host "Tell me the exact remote path (e.g. /home/ubuntu/claimit/fastapi/backend) and I'll hardcode it." -ForegroundColor Red
    exit 1
}
Write-Host "Found: $RemoteDir" -ForegroundColor Green

Write-Host "`nCopying app/ folder and run.py (excluding .env)..." -ForegroundColor Cyan
scp -i $Key -r "$Local\app" "${Server}:${RemoteDir}/"
scp -i $Key "$Local\run.py" "${Server}:${RemoteDir}/"

Write-Host "`nRestarting the backend..." -ForegroundColor Cyan
$RemoteScript = @'
set -e
if systemctl list-units --type=service --all 2>/dev/null | grep -qi claimit; then
  SERVICE=$(systemctl list-units --type=service --all | grep -i claimit | awk '{print $1}' | head -1)
  echo "Restarting systemd service: $SERVICE"
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
