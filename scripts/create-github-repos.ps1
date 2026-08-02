$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$user = (gh api user --jq .login)

# App repo already exists as Counter-Strike — only ensure infra remote/push helpers
$infraDir = Join-Path $Root "devops-diploma-infra"
Set-Location $infraDir

$infraRemote = gh repo view "$user/devops-diploma-infra" 2>$null
if (-not $infraRemote) {
    gh repo create "devops-diploma-infra" --public --source=. --remote=origin --push
} else {
    git remote remove origin 2>$null
    git remote add origin "https://github.com/$user/devops-diploma-infra.git"
    git push -u origin HEAD
}

Write-Host "App:   https://github.com/$user/Counter-Strike"
Write-Host "Infra: https://github.com/$user/devops-diploma-infra"
