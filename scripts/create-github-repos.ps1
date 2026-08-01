#Requires -Version 5.1
# Tworzy repozytoria na GitHub i wypycha kod.
# Wymaga: gh auth login

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path "$Root\python-microservices-app")) {
    $Root = "c:\Users\artam\Documents\DevOps"
}

Write-Host "Root: $Root" -ForegroundColor Cyan

# Sprawdź gh
gh auth status
$user = (gh api user --jq .login)
Write-Host "GitHub user: $user" -ForegroundColor Green

# Repo 1: app
$appDir = Join-Path $Root "python-microservices-app"
Set-Location $appDir
$appRemote = gh repo view "$user/python-microservices-app" 2>$null
if (-not $?) {
    gh repo create "python-microservices-app" --public --source=. --remote=origin --push
} else {
    git remote remove origin 2>$null
    git remote add origin "https://github.com/$user/python-microservices-app.git"
    git push -u origin main
}

# Repo 2: infra
$infraDir = Join-Path $Root "devops-diploma-infra"
Set-Location $infraDir
if (-not (Test-Path ".git")) {
    git init -b main
    git add .
    git commit -m "Initial DevOps diploma infrastructure: Terraform, Ansible, k3s, Jenkins, monitoring"
}
$infraRemote = gh repo view "$user/devops-diploma-infra" 2>$null
if (-not $?) {
    gh repo create "devops-diploma-infra" --public --source=. --remote=origin --push
} else {
    git remote remove origin 2>$null
    git remote add origin "https://github.com/$user/devops-diploma-infra.git"
    git push -u origin main
}

Write-Host "Done. Repos:" -ForegroundColor Green
Write-Host "  https://github.com/$user/python-microservices-app"
Write-Host "  https://github.com/$user/devops-diploma-infra"
