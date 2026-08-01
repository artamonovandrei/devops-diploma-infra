# Skrypt przygotowania środowiska Windows 11 (uruchom w PowerShell jako Administrator)
# Wymagane: winget

$ErrorActionPreference = "Stop"

Write-Host "=== DevOps Diploma - Setup Windows ===" -ForegroundColor Cyan

# 1. SSH key
$sshKey = "$env:USERPROFILE\.ssh\devops-diploma"
if (-not (Test-Path $sshKey)) {
    New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.ssh" | Out-Null
    ssh-keygen -t rsa -b 4096 -f $sshKey -N '""' -C "devops-diploma"
    Write-Host "SSH key created: $sshKey" -ForegroundColor Green
} else {
    Write-Host "SSH key already exists: $sshKey" -ForegroundColor Yellow
}

# 2. Tools via winget
$packages = @(
    @{ Id = "Hashicorp.Terraform"; Name = "Terraform" },
    @{ Id = "Amazon.AWSCLI"; Name = "AWS CLI" },
    @{ Id = "GitHub.cli"; Name = "GitHub CLI" }
)

foreach ($pkg in $packages) {
    Write-Host "Installing $($pkg.Name)..." -ForegroundColor Cyan
    winget install --id $pkg.Id -e --accept-source-agreements --accept-package-agreements
}

# 3. Start Docker Desktop
$dockerExe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
if (Test-Path $dockerExe) {
    Start-Process $dockerExe
    Write-Host "Docker Desktop starting..." -ForegroundColor Green
} else {
    Write-Host "Docker Desktop not found. Install from https://www.docker.com/products/docker-desktop/" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Next steps ===" -ForegroundColor Cyan
Write-Host "1. Restart PowerShell (refresh PATH)"
Write-Host "2. aws configure"
Write-Host "3. gh auth login"
Write-Host "4. Copy public key into terraform.tfvars:"
Write-Host "   Get-Content `$env:USERPROFILE\.ssh\devops-diploma.pub"
Write-Host "5. Get your public IP: (Invoke-RestMethod ifconfig.me)/32"
Write-Host "6. Follow docs/DEPLOYMENT.md"
