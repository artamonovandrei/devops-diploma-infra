# E2E checklist — suchy przebieg przed obroną
# Uruchom lokalnie po wdrożeniu AWS

$ErrorActionPreference = "Continue"
$failed = 0

function Check($name, $scriptBlock) {
    Write-Host -NoNewline "  [$name] "
    try {
        & $scriptBlock
        if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { throw "exit $LASTEXITCODE" }
        Write-Host "OK" -ForegroundColor Green
    } catch {
        Write-Host "FAIL - $_" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host "=== E2E Validation Checklist ===" -ForegroundColor Cyan

Write-Host "`n1. Local tools"
Check "git" { git --version | Out-Null }
Check "docker" { docker version | Out-Null }
Check "terraform" { terraform version | Out-Null }
Check "aws" { aws --version | Out-Null }

Write-Host "`n2. Local Docker Compose"
Set-Location "c:\Users\artam\Documents\DevOps\python-microservices-app"
Check "compose-up" { docker compose up -d --build 2>&1 | Out-Null; Start-Sleep 20 }
Check "user-health" { (Invoke-RestMethod http://localhost:8001/health).status -eq "healthy" | Out-Null; if (-not $?) { throw "unhealthy" } }
Check "order-health" { Invoke-RestMethod http://localhost:8002/health | Out-Null }
Check "compose-down" { docker compose down 2>&1 | Out-Null }

Write-Host "`n3. Terraform (idempotency)"
Set-Location "c:\Users\artam\Documents\DevOps\devops-diploma-infra\terraform\environments\dev"
if (Test-Path "terraform.tfvars") {
    Check "terraform-plan" { terraform plan -detailed-exitcode; if ($LASTEXITCODE -eq 1) { throw "plan error" } }
} else {
    Write-Host "  [terraform-plan] SKIP - brak terraform.tfvars" -ForegroundColor Yellow
}

Write-Host "`n4. Documentation present"
$docs = @(
    "c:\Users\artam\Documents\DevOps\devops-diploma-infra\README.md",
    "c:\Users\artam\Documents\DevOps\devops-diploma-infra\docs\ARCHITECTURE.md",
    "c:\Users\artam\Documents\DevOps\devops-diploma-infra\docs\DEPLOYMENT.md",
    "c:\Users\artam\Documents\DevOps\devops-diploma-infra\docs\DEMO.md",
    "c:\Users\artam\Documents\DevOps\python-microservices-app\README.md",
    "c:\Users\artam\Documents\DevOps\python-microservices-app\Jenkinsfile"
)
foreach ($d in $docs) {
    Check (Split-Path $d -Leaf) { if (-not (Test-Path $d)) { throw "missing" } }
}

Write-Host "`n=== Result: $failed failures ===" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
exit $failed
