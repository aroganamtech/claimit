# ssh_allow_my_ip.ps1 — point the Claimit security group's SSH rule at wherever
# you are right now.
#
# Why this exists: port 22 is locked to a single address, and Ramesh's
# connection is on an Indian mobile range (157.51.x.x) that rotates every few
# hours. Each rotation locks him out of his own server, and the AWS console
# does not refresh "My IP" when it is already set to "My IP" — you have to
# clear the CIDR chip first, which is easy to miss.
#
# Run:   powershell -ExecutionPolicy Bypass -File .\deploy\ssh_allow_my_ip.ps1
#
# ONE-TIME SETUP
#   1. Install the AWS CLI:  winget install Amazon.AWSCLI
#   2. aws configure
#      Use an IAM user whose ONLY permissions are
#      ec2:DescribeSecurityGroups, ec2:AuthorizeSecurityGroupIngress and
#      ec2:RevokeSecurityGroupIngress. Do NOT use an admin key here — this
#      script runs on a laptop, and a laptop key is a key that can walk out
#      of the building.

$ErrorActionPreference = 'Stop'

$SecurityGroupId = 'sg-0b0b4ee04efc561a0'   # Claimit EC2 — from the console
$Region          = 'eu-north-1'             # Europe (Stockholm)

# ── 1. Where am I? ───────────────────────────────────────────────────────────
$ip = (Invoke-RestMethod 'https://checkip.amazonaws.com').Trim()
if ($ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
    Write-Host "Could not read your public IP (got '$ip'). Check your connection." -ForegroundColor Red
    exit 1
}
$cidr = "$ip/32"
Write-Host "Your current public IP: $ip"

# ── 2. What is allowed today? ────────────────────────────────────────────────
$existing = aws ec2 describe-security-groups `
    --group-ids $SecurityGroupId --region $Region `
    --query "SecurityGroups[0].IpPermissions[?FromPort==``22``].IpRanges[].CidrIp" `
    --output text

if ($LASTEXITCODE -ne 0) {
    Write-Host "AWS CLI call failed. Is it installed and configured? See the header of this file." -ForegroundColor Red
    exit 1
}

$current = @($existing -split '\s+' | Where-Object { $_ })
Write-Host "Port 22 currently allows: $($current -join ', ')"

if ($current -contains $cidr -and $current.Count -eq 1) {
    Write-Host "Already correct — nothing to do." -ForegroundColor Green
    exit 0
}

# ── 3. Swap the rule ─────────────────────────────────────────────────────────
# Add the new address BEFORE removing the old ones. The reverse order would
# leave a window with no SSH rule at all, and if the add then failed you would
# be locked out with no way back in except the console.
if ($current -notcontains $cidr) {
    aws ec2 authorize-security-group-ingress `
        --group-id $SecurityGroupId --region $Region `
        --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$cidr,Description=''my laptop''}]" | Out-Null
    Write-Host "Allowed $cidr" -ForegroundColor Green
}

foreach ($old in $current) {
    if ($old -eq $cidr) { continue }
    aws ec2 revoke-security-group-ingress `
        --group-id $SecurityGroupId --region $Region `
        --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$old}]" | Out-Null
    if ($old -eq '0.0.0.0/0') {
        Write-Host "Removed $old — SSH is no longer open to the whole internet." -ForegroundColor Yellow
    } else {
        Write-Host "Removed $old (stale address)"
    }
}

Write-Host ""
Write-Host "Done. SSH now allows $cidr only." -ForegroundColor Green
Write-Host "Test:  ssh -i `$key `$server `"echo ok`""
