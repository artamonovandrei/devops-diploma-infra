# Przepisuje ansible/inventory/hosts z hosts.example + IP z terraform output.
param()

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$TfDir = Join-Path $RepoRoot "terraform\environments\dev"
$Example = Join-Path $RepoRoot "ansible\inventory\hosts.example"
$Inventory = Join-Path $RepoRoot "ansible\inventory\hosts"

if (-not (Test-Path $Example)) { throw "Brak $Example" }

Push-Location $TfDir
try {
    $jenkinsIp = terraform output -raw jenkins_public_ip
    $k3sIp = terraform output -raw k3s_public_ip
} finally {
    Pop-Location
}

$text = Get-Content $Example -Raw
$text = $text.Replace("JENKINS_PUBLIC_IP", $jenkinsIp).Replace("K3S_PUBLIC_IP", $k3sIp)
# Unix line endings for WSL/Ansible
$text = $text -replace "`r`n", "`n"
[System.IO.File]::WriteAllText($Inventory, $text)

Write-Host "inventory/hosts ← jenkins=$jenkinsIp  k3s=$k3sIp" -ForegroundColor Green
