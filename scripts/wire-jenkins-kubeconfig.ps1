# Kopiuje kubeconfig k3s na Jenkins (/var/lib/jenkins/.kube/config) z prywatnym IP API.
param(
    [string]$SshKey = "$env:USERPROFILE\.ssh\devops-diploma"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$TfDir = Join-Path $RepoRoot "terraform\environments\dev"

if (-not (Test-Path $SshKey)) { throw "Brak klucza SSH: $SshKey" }

Push-Location $TfDir
try {
    $jenkinsIp = terraform output -raw jenkins_public_ip
    $k3sIp = terraform output -raw k3s_public_ip
    $k3sPriv = terraform output -raw k3s_private_ip
} finally {
    Pop-Location
}

$sshOpts = @("-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=30", "-i", $SshKey)
$tmp = Join-Path $env:TEMP "k3s-jenkins.yaml"

Write-Host "==> Pobieram kubeconfig z k3s ($k3sIp)..." -ForegroundColor Cyan
$raw = & ssh @sshOpts "ubuntu@$k3sIp" "sudo cat /etc/rancher/k3s/k3s.yaml"
if ($LASTEXITCODE -ne 0) { throw "ssh k3s failed" }

$fixed = ($raw | Out-String) `
    -replace 'https://127\.0\.0\.1:6443', "https://${k3sPriv}:6443" `
    -replace 'https://localhost:6443', "https://${k3sPriv}:6443"
# ASCII for Linux
[System.IO.File]::WriteAllText($tmp, ($fixed -replace "`r`n", "`n"))

Write-Host "==> Wgrywam na Jenkins ($jenkinsIp)..." -ForegroundColor Cyan
& scp @sshOpts $tmp "ubuntu@${jenkinsIp}:/tmp/k3s.yaml"
if ($LASTEXITCODE -ne 0) { throw "scp failed" }

$remote = @'
set -euo pipefail
sudo mkdir -p /var/lib/jenkins/.kube
sudo cp /tmp/k3s.yaml /var/lib/jenkins/.kube/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube
sudo chmod 600 /var/lib/jenkins/.kube/config
sudo -u jenkins kubectl --kubeconfig=/var/lib/jenkins/.kube/config get nodes
'@
$remote = $remote -replace "`r`n", "`n"
& ssh @sshOpts "ubuntu@$jenkinsIp" $remote
if ($LASTEXITCODE -ne 0) { throw "wire kubeconfig on Jenkins failed" }

Write-Host "Jenkins kubeconfig OK → https://${k3sPriv}:6443" -ForegroundColor Green
