# Przywroc infrastrukture i podlacz TEN SAM dysk Jenkins (joby + credentials).
# Uzycie:
#   .\scripts\aws-resume.ps1

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$TfDir = Join-Path $RepoRoot "terraform\environments\dev"
$SshKey = Join-Path $env:USERPROFILE ".ssh\devops-diploma"

Set-Location $RepoRoot
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force | Out-Null

. "$PSScriptRoot\ensure-jenkins-volume.ps1" -AsLibrary
Ensure-JenkinsVolumeId | Out-Null

Push-Location $TfDir
try {
    Write-Host "==> terraform apply (reuse Jenkins EBS)..." -ForegroundColor Cyan
    terraform apply -auto-approve
    if ($LASTEXITCODE -ne 0) { throw "terraform apply failed (exit $LASTEXITCODE)" }

    $jenkinsIp = terraform output -raw jenkins_public_ip
    $k3sIp = terraform output -raw k3s_public_ip

    Write-Host "Jenkins: http://${jenkinsIp}:8080" -ForegroundColor Green
    Write-Host "k3s:     $k3sIp" -ForegroundColor Green
} finally {
    Pop-Location
}

Persist-JenkinsVolumeFromTerraform | Out-Null

Write-Host "==> sync inventory..." -ForegroundColor Cyan
& "$PSScriptRoot\sync-inventory.ps1"

$drive = $RepoRoot.Substring(0, 1).ToLowerInvariant()
$wslAnsibleDir = "/mnt/$drive/" + (($RepoRoot.Substring(3) -replace '\\', '/') + "/ansible")

Write-Host @"

Dalej (WSL):
  cd $wslAnsibleDir
  ansible-playbook -i inventory/hosts playbooks/site.yml
  ansible-playbook -i inventory/hosts playbooks/monitoring.yml

Potem (PowerShell) — kubeconfig na Jenkins (nowe private IP k3s):
  .\scripts\wire-jenkins-kubeconfig.ps1

Jenkins wstaje z poprzednimi jobami/credentials (ten sam EBS).
Jesli setup wizard — volume byl pusty albo nie podlaczony (sprawdz .secrets).
"@ -ForegroundColor Yellow

# Best-effort kubeconfig (dziala dopiero gdy k3s juz skonfigurowany)
if (Test-Path $SshKey) {
    Write-Host "==> Proba wire kubeconfig (moze fail jesli Ansible jeszcze nie odpalony)..." -ForegroundColor Cyan
    try {
        & "$PSScriptRoot\wire-jenkins-kubeconfig.ps1" -SshKey $SshKey
    } catch {
        Write-Host "kubeconfig pominiety na razie: $_" -ForegroundColor DarkYellow
    }
}
