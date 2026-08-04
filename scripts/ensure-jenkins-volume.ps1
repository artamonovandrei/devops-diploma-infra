# Ustawia jenkins_home_volume_id w terraform.tfvars z .secrets (albo odwrotnie).
# Domyslnie ODMAWIA utworzenia nowego pustego dysku (utrata credentials/jobow).
#
# Pierwszy bootstrap (swiezy dysk):
#   .\scripts\ensure-jenkins-volume.ps1 -AllowNewVolume
#
# Z innego skryptu:
#   . "$PSScriptRoot\ensure-jenkins-volume.ps1"
#   Ensure-JenkinsVolumeId

param(
    [switch]$AllowNewVolume,
    [switch]$AsLibrary
)

$ErrorActionPreference = "Stop"

function Get-RepoPaths {
    $here = $PSScriptRoot
    if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    $RepoRoot = Split-Path -Parent $here
    [pscustomobject]@{
        RepoRoot   = $RepoRoot
        TfDir      = Join-Path $RepoRoot "terraform\environments\dev"
        Tfvars     = Join-Path $RepoRoot "terraform\environments\dev\terraform.tfvars"
        SecretsDir = Join-Path $RepoRoot ".secrets"
        VolumeFile = Join-Path $RepoRoot ".secrets\jenkins-home-volume-id.txt"
    }
}

function Read-VolumeFromFile([string]$Path) {
    if (-not (Test-Path $Path)) { return "" }
    $v = (Get-Content $Path -Raw).Trim()
    if ($v -match '^vol-[0-9a-f]+$') { return $v }
    return ""
}

function Read-VolumeFromTfvars([string]$Path) {
    if (-not (Test-Path $Path)) { return "" }
    $m = [regex]::Match((Get-Content $Path -Raw), 'jenkins_home_volume_id\s*=\s*"([^"]*)"')
    if (-not $m.Success) { return "" }
    $v = $m.Groups[1].Value.Trim()
    if ($v -match '^vol-[0-9a-f]+$') { return $v }
    return ""
}

function Set-VolumeInTfvars([string]$Tfvars, [string]$VolId) {
    if (-not (Test-Path $Tfvars)) {
        throw "Brak $Tfvars — skopiuj terraform.tfvars.example"
    }
    $text = Get-Content $Tfvars -Raw
    if ($text -match 'jenkins_home_volume_id\s*=') {
        $text = [regex]::Replace(
            $text,
            'jenkins_home_volume_id\s*=\s*"[^"]*"',
            "jenkins_home_volume_id = `"$VolId`""
        )
    } else {
        $text = $text.TrimEnd() + "`r`n`r`njenkins_home_volume_id = `"$VolId`"`r`n"
    }
    Set-Content -Path $Tfvars -Value $text -NoNewline
}

function Save-VolumeId([string]$VolumeFile, [string]$SecretsDir, [string]$VolId) {
    New-Item -ItemType Directory -Force -Path $SecretsDir | Out-Null
    Set-Content -Path $VolumeFile -Value $VolId -NoNewline
}

function Ensure-JenkinsVolumeId {
    param([switch]$AllowNewVolume)
    $p = Get-RepoPaths
    $fromSecrets = Read-VolumeFromFile $p.VolumeFile
    $fromTfvars  = Read-VolumeFromTfvars $p.Tfvars

    $volId = if ($fromSecrets) { $fromSecrets } elseif ($fromTfvars) { $fromTfvars } else { "" }

    if ($volId) {
        Set-VolumeInTfvars $p.Tfvars $volId
        Save-VolumeId $p.VolumeFile $p.SecretsDir $volId
        Write-Host "Jenkins EBS (reuse): $volId — credentials/joby zostana zachowane" -ForegroundColor Green
        return $volId
    }

    if (-not $AllowNewVolume) {
        throw @"
ODMOWA: brak jenkins_home_volume_id — terraform utworzylby NOWY pusty dysk i Jenkins stracilby ustawienia.

Napraw jedno z:
  1. .secrets\jenkins-home-volume-id.txt  (zawartosc: vol-xxxxxxxx)
  2. terraform\environments\dev\terraform.tfvars → jenkins_home_volume_id = `"vol-...`"
  3. Pierwszy raz w zyciu: .\scripts\ensure-jenkins-volume.ps1 -AllowNewVolume
"@
    }

    Set-VolumeInTfvars $p.Tfvars ""
    Write-Host "UWAGA: ALLOW new Jenkins volume — pierwszy bootstrap (pusty dysk)" -ForegroundColor Yellow
    return ""
}

function Persist-JenkinsVolumeFromTerraform {
    $p = Get-RepoPaths
    Push-Location $p.TfDir
    try {
        $volId = terraform output -raw jenkins_home_volume_id 2>$null
    } finally {
        Pop-Location
    }
    if (-not $volId -or $volId -notmatch '^vol-') {
        throw "terraform output jenkins_home_volume_id nie zwrocil vol-*"
    }
    Set-VolumeInTfvars $p.Tfvars $volId
    Save-VolumeId $p.VolumeFile $p.SecretsDir $volId
    Write-Host "Zapisano Jenkins EBS: $volId → .secrets + tfvars" -ForegroundColor Green
    return $volId
}

if (-not $AsLibrary) {
    Ensure-JenkinsVolumeId -AllowNewVolume:$AllowNewVolume | Out-Null
}
