# Generuje terraform.tfvars na podstawie klucza SSH i publicznego IP
# Uruchom: .\scripts\generate-tfvars.ps1

$ErrorActionPreference = "Stop"
$DevDir = Join-Path $PSScriptRoot "..\terraform\environments\dev" | Resolve-Path
$PubKeyPath = Join-Path $env:USERPROFILE ".ssh\devops-diploma.pub"

if (-not (Test-Path $PubKeyPath)) {
    New-Item -ItemType Directory -Force -Path (Join-Path $env:USERPROFILE ".ssh") | Out-Null
    ssh-keygen -t rsa -b 4096 -f (Join-Path $env:USERPROFILE ".ssh\devops-diploma") -N '""' -C "devops-diploma"
}

$pubKey = (Get-Content $PubKeyPath -Raw).Trim()
$ipv4 = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 15).Trim()

$tfvars = @"
project_name = "devops-diploma"
aws_region   = "eu-central-1"

admin_cidr = "$ipv4/32"

ssh_public_key = "$pubKey"

jenkins_instance_type = "t3.small"
k3s_instance_type     = "t3.small"
"@

$out = Join-Path $DevDir "terraform.tfvars"
Set-Content -Path $out -Value $tfvars -Encoding UTF8
Write-Host "Wrote $out" -ForegroundColor Green
Write-Host "admin_cidr = $ipv4/32"
Write-Host "NIE commituj terraform.tfvars do gita."
