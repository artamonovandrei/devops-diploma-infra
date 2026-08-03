# Przywroc infrastrukture i podlacz ten sam dysk Jenkins (ustawienia wracaja).
# Uzycie:
#   .\scripts\aws-resume.ps1

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$TfDir = Join-Path $RepoRoot "terraform\environments\dev"
$SecretsDir = Join-Path $RepoRoot ".secrets"
$VolumeFile = Join-Path $SecretsDir "jenkins-home-volume-id.txt"
$Tfvars = Join-Path $TfDir "terraform.tfvars"
$Inventory = Join-Path $RepoRoot "ansible\inventory\hosts"

if (-not (Test-Path $VolumeFile)) {
    throw "Brak $VolumeFile — uruchom najpierw aws-pause.ps1 albo wstaw vol-xxx recznie."
}
$volId = (Get-Content $VolumeFile -Raw).Trim()
if ($volId -notmatch '^vol-') {
    throw "Niepoprawne volume ID w $VolumeFile : $volId"
}

if (-not (Test-Path $Tfvars)) {
    throw "Brak $Tfvars"
}

# Upsert jenkins_home_volume_id w tfvars
$tfvarsText = Get-Content $Tfvars -Raw
if ($tfvarsText -match 'jenkins_home_volume_id\s*=') {
    $tfvarsText = [regex]::Replace(
        $tfvarsText,
        'jenkins_home_volume_id\s*=\s*"[^"]*"',
        "jenkins_home_volume_id = `"$volId`""
    )
} else {
    $tfvarsText = $tfvarsText.TrimEnd() + "`r`n`r`njenkins_home_volume_id = `"$volId`"`r`n"
}
Set-Content -Path $Tfvars -Value $tfvarsText -NoNewline
Write-Host "tfvars: jenkins_home_volume_id = $volId" -ForegroundColor Green

Push-Location $TfDir
try {
    Write-Host "==> terraform apply..." -ForegroundColor Cyan
    terraform apply -auto-approve

    $jenkinsIp = terraform output -raw jenkins_public_ip
    $k3sIp = terraform output -raw k3s_public_ip
    $jenkinsPriv = terraform output -raw jenkins_private_ip
    $k3sPriv = terraform output -raw k3s_private_ip

    Write-Host "Jenkins: http://${jenkinsIp}:8080" -ForegroundColor Green
    Write-Host "k3s:     $k3sIp" -ForegroundColor Green
}
finally {
    Pop-Location
}

# Odswiez inventory (prosty szablon)
if (Test-Path $Inventory) {
    Write-Host "==> Aktualizacja ansible inventory (sprawdz IP recznie jesli trzeba)..." -ForegroundColor Cyan
}

Write-Host @"

Dalej (WSL / Ansible):
  cd ansible
  # uzupelnij inventory/hosts nowymi IP
  ansible-playbook -i inventory/hosts playbooks/site.yml

Jenkins powinien wstac z poprzednimi jobami/credentials (ten sam EBS).
Jesli setup wizard — volume byl pusty (pierwszy raz bez migracji).
"@ -ForegroundColor Yellow
