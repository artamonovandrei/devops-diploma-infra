# E2E checklist — suchy przebieg przed obroną
# Uruchom lokalnie po wdrożeniu AWS

$ErrorActionPreference = "Continue"
$script:failed = 0

function Check($name, [scriptblock]$scriptBlock) {
    Write-Host -NoNewline "  [$name] "
    try {
        $result = & $scriptBlock
        if ($result -eq $false) { throw "check returned false" }
        Write-Host "OK" -ForegroundColor Green
    } catch {
        Write-Host "FAIL - $_" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host "=== E2E Validation Checklist ===" -ForegroundColor Cyan

Write-Host "`n1. Local tools"
Check "git" { git --version | Out-Null; $true }
Check "docker" { docker version | Out-Null; $true }
Check "terraform" { terraform version | Out-Null; $true }
Check "aws" { aws --version | Out-Null; $true }

Write-Host "`n2. Local Docker Compose"
Set-Location "c:\Users\artam\Documents\DevOps\python-microservices-app"
Check "compose-up" {
    docker compose up -d --build 2>&1 | Out-Null
    Start-Sleep 15
    $true
}
Check "user-health" {
    $h = Invoke-RestMethod http://localhost:8001/health
    if ($h.status -ne "healthy") { throw "unhealthy" }
    $true
}
Check "order-health" {
    $h = Invoke-RestMethod http://localhost:8002/health
    if ($h.status -ne "healthy") { throw "unhealthy" }
    $true
}
Check "integration" {
    $u = Invoke-RestMethod http://localhost:8001/users/1
    $o = Invoke-RestMethod http://localhost:8002/orders/1
    if (-not $o.user.name) { throw "order missing user enrichment" }
    $true
}
Check "compose-down" {
    docker compose down 2>&1 | Out-Null
    $true
}

Write-Host "`n3. Terraform files"
$tfRoot = "c:\Users\artam\Documents\DevOps\devops-diploma-infra\terraform"
Check "modules" { Test-Path "$tfRoot\modules\network\main.tf" }
Check "jenkins-ec2" { Test-Path "$tfRoot\modules\ec2-jenkins\main.tf" }
Check "k3s-ec2" { Test-Path "$tfRoot\modules\ec2-k3s\main.tf" }
Check "tfvars" {
    if (Test-Path "$tfRoot\environments\dev\terraform.tfvars") { $true }
    else { throw "brak terraform.tfvars — uruchom scripts\generate-tfvars.ps1" }
}
Check "aws-creds" {
    aws sts get-caller-identity 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "uruchom: aws configure (wymagane do terraform apply)" }
    $true
}

Write-Host "`n4. Documentation present"
$docs = @(
    "c:\Users\artam\Documents\DevOps\devops-diploma-infra\README.md",
    "c:\Users\artam\Documents\DevOps\devops-diploma-infra\docs\ARCHITECTURE.md",
    "c:\Users\artam\Documents\DevOps\devops-diploma-infra\docs\DEPLOYMENT.md",
    "c:\Users\artam\Documents\DevOps\devops-diploma-infra\docs\DEMO.md",
    "c:\Users\artam\Documents\DevOps\devops-diploma-infra\docs\JENKINS.md",
    "c:\Users\artam\Documents\DevOps\devops-diploma-infra\docs\NEXT_STEPS.md",
    "c:\Users\artam\Documents\DevOps\python-microservices-app\README.md",
    "c:\Users\artam\Documents\DevOps\python-microservices-app\Jenkinsfile",
    "c:\Users\artam\Documents\DevOps\devops-diploma-infra\jenkins\Jenkinsfile.ci",
    "c:\Users\artam\Documents\DevOps\devops-diploma-infra\jenkins\Jenkinsfile.cd",
    "c:\Users\artam\Documents\DevOps\devops-diploma-infra\ansible\playbooks\site.yml",
    "c:\Users\artam\Documents\DevOps\devops-diploma-infra\kubernetes\monitoring\kube-prometheus-values.yaml"
)
foreach ($d in $docs) {
    Check (Split-Path $d -Leaf) { if (-not (Test-Path $d)) { throw "missing: $d" }; $true }
}

Write-Host "`n=== Result: $($script:failed) failures ===" -ForegroundColor $(if ($script:failed -eq 0) { "Green" } else { "Yellow" })
Write-Host "Uwaga: terraform apply / Ansible / Jenkins wymagaja AWS credentials — patrz docs/NEXT_STEPS.md"
exit $script:failed
