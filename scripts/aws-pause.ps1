# Zatrzymaj koszty EC2, ALE zachowaj dysk Jenkins (joby, credentials, pluginy).
# Uzycie (z katalogu devops-diploma-infra):
#   .\scripts\aws-pause.ps1

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$TfDir = Join-Path $RepoRoot "terraform\environments\dev"
$SecretsDir = Join-Path $RepoRoot ".secrets"
$VolumeFile = Join-Path $SecretsDir "jenkins-home-volume-id.txt"
$Tfvars = Join-Path $TfDir "terraform.tfvars"

New-Item -ItemType Directory -Force -Path $SecretsDir | Out-Null

Push-Location $TfDir
try {
    Write-Host "==> Odczyt ID dysku Jenkins..." -ForegroundColor Cyan
    $volId = terraform output -raw jenkins_home_volume_id 2>$null
    if (-not $volId) {
        throw "Brak output jenkins_home_volume_id. Najpierw: terraform apply (z nowym modulem EBS) + ansible jenkins.yml"
    }

    Set-Content -Path $VolumeFile -Value $volId -NoNewline
    Write-Host "Zapisano volume ID: $volId -> $VolumeFile" -ForegroundColor Green

    # Trzymaj tfvars w sync — kolejny apply nie stworzy pustego dysku
    if (Test-Path $Tfvars) {
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
    }

    Write-Host "==> Usuwam volume z Terraform state (AWS dysk zostaje)..." -ForegroundColor Cyan
    # Ignoruj blad gdy zasobu juz nie ma w state (PowerShell + terraform stderr)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    terraform state rm "module.jenkins.aws_volume_attachment.jenkins_home" 2>$null | Out-Null
    terraform state rm "module.jenkins.aws_ebs_volume.jenkins_home[0]" 2>$null | Out-Null
    $ErrorActionPreference = $prevEap

    Write-Host "==> terraform destroy (EC2/VPC; dysk Jenkins zostaje w AWS)..." -ForegroundColor Yellow
    terraform destroy -auto-approve
    if ($LASTEXITCODE -ne 0) {
        throw "terraform destroy failed (exit $LASTEXITCODE)"
    }

    Write-Host @"

PAUSE OK.
Dysk Jenkins w AWS: $volId (status: available)
Przy nastepnym starcie:
  1. W terraform.tfvars ustaw:
       jenkins_home_volume_id = `"$volId`"
  2. .\scripts\aws-resume.ps1

Albo od razu: .\scripts\aws-resume.ps1 (wstawi ID z .secrets)
"@ -ForegroundColor Green
}
finally {
    Pop-Location
}
