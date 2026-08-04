# Start od zera z ZACHOWANIEM ustawien Jenkins (EBS).
#
# Domyslnie: reuse vol z .secrets / tfvars (credentials, joby, pluginy zostaja).
# Pierwszy bootstrap w zyciu (nowy pusty dysk):
#   .\scripts\start-from-zero.ps1 -AllowNewJenkinsVolume
#
# Potem w WSL (jesli nie podasz -SkipAnsible):
#   ansible-playbook -i inventory/hosts playbooks/site.yml
#   ansible-playbook -i inventory/hosts playbooks/monitoring.yml

param(
    [switch]$AllowNewJenkinsVolume,
    [switch]$SkipBootstrap,
    [switch]$SkipAnsible,
    [switch]$SkipAppDeploy
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$TfBootstrap = Join-Path $RepoRoot "terraform\bootstrap"
$TfDir = Join-Path $RepoRoot "terraform\environments\dev"
$SshKey = Join-Path $env:USERPROFILE ".ssh\devops-diploma"

Set-Location $RepoRoot
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force | Out-Null

Write-Host "=== Start od zera (Jenkins EBS reuse) ===" -ForegroundColor Cyan

# 1) Volume guard — NIGDY pusty dysk bez -AllowNewJenkinsVolume
. "$PSScriptRoot\ensure-jenkins-volume.ps1" -AsLibrary
Ensure-JenkinsVolumeId -AllowNewVolume:$AllowNewJenkinsVolume | Out-Null

# 2) Bootstrap S3 (opcjonalnie)
if (-not $SkipBootstrap) {
    Write-Host "[1/5] Bootstrap Terraform state (S3)..." -ForegroundColor Cyan
    Push-Location $TfBootstrap
    try {
        terraform init -input=false
        terraform apply -auto-approve
    } finally {
        Pop-Location
    }
}

# 3) Infra
Write-Host "[2/5] terraform apply (EC2 + attach Jenkins EBS)..." -ForegroundColor Cyan
Push-Location $TfDir
try {
    terraform init -input=false
    terraform apply -auto-approve
    if ($LASTEXITCODE -ne 0) { throw "terraform apply failed" }
    $jenkinsIp = terraform output -raw jenkins_public_ip
    $k3sIp = terraform output -raw k3s_public_ip
} finally {
    Pop-Location
}

Persist-JenkinsVolumeFromTerraform | Out-Null

# 4) Inventory + kubeconfig (po Ansible kubeconfig jeszcze raz — tu wczesny wire po site)
Write-Host "[3/5] sync inventory..." -ForegroundColor Cyan
& "$PSScriptRoot\sync-inventory.ps1"

$drive = $RepoRoot.Substring(0, 1).ToLowerInvariant()
$wslRepo = "/mnt/$drive/" + ($RepoRoot.Substring(3) -replace '\\', '/')
$wslAnsibleDir = "$wslRepo/ansible"

Write-Host @"

[4/5] Ansible — uruchom w WSL (Jenkins zamontuje TEN SAM EBS):

  cd $wslAnsibleDir
  ansible-playbook -i inventory/hosts playbooks/site.yml
  ansible-playbook -i inventory/hosts playbooks/monitoring.yml

"@ -ForegroundColor Yellow

if (-not $SkipAnsible) {
    $wslAnsible = @"
set -euo pipefail
cd '$wslAnsibleDir'
ansible-playbook -i inventory/hosts playbooks/site.yml
ansible-playbook -i inventory/hosts playbooks/monitoring.yml
"@
    $wslAnsible = $wslAnsible -replace "`r`n", "`n"
    Write-Host "==> WSL Ansible..." -ForegroundColor Cyan
    wsl bash -lc $wslAnsible
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WSL Ansible nie powiodlo sie — odpal playbooki recznie (powyzej)." -ForegroundColor Yellow
    }
}

# 5) Kubeconfig na Jenkins (po site.yml k3s juz dziala)
Write-Host "[5/5] wire Jenkins kubeconfig..." -ForegroundColor Cyan
try {
    & "$PSScriptRoot\wire-jenkins-kubeconfig.ps1" -SshKey $SshKey
} catch {
    Write-Host "kubeconfig: $_ — sprobuj ponownie po Ansible site.yml" -ForegroundColor Yellow
}

if (-not $SkipAppDeploy) {
    Write-Host "==> Deploy app manifests na k3s..." -ForegroundColor Cyan
    $appRemote = @'
set -euo pipefail
sudo mkdir -p /opt/devops-diploma-infra
if [ ! -d /opt/devops-diploma-infra/.git ]; then
  sudo git clone --depth 1 https://github.com/artamonovandrei/devops-diploma-infra.git /opt/devops-diploma-infra
else
  sudo git -C /opt/devops-diploma-infra fetch --depth 1 origin main
  sudo git -C /opt/devops-diploma-infra reset --hard origin/main
fi
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
sudo kubectl apply -f /opt/devops-diploma-infra/kubernetes/apps/
sudo kubectl rollout status deployment/backend -n webstrike --timeout=180s || true
sudo kubectl rollout status deployment/web -n webstrike --timeout=180s || true
'@
    $appRemote = $appRemote -replace "`r`n", "`n"
    ssh -o StrictHostKeyChecking=no -i $SshKey "ubuntu@$k3sIp" $appRemote
}

Write-Host @"

=== GOTOWE ===
Jenkins (te same credentials/joby z EBS): http://${jenkinsIp}:8080
Gra:        http://${k3sIp}:30080
Prometheus: http://${k3sIp}:30090
Grafana:    http://${k3sIp}:30300

Volume ID zapisany w .secrets\jenkins-home-volume-id.txt
Pauza (zachowaj dysk): .\scripts\aws-pause.ps1
Wzorcowanie:            .\scripts\aws-resume.ps1
"@ -ForegroundColor Green
