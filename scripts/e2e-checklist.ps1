$ErrorActionPreference = "Stop"
$Root = "c:\Users\artam\Documents\DevOps"

Write-Host "=== Local app files ==="
@(
    "$Root\Counter-Strike\README.md",
    "$Root\Counter-Strike\Jenkinsfile",
    "$Root\Counter-Strike\docker-compose.yml",
    "$Root\devops-diploma-infra\kubernetes\apps\backend.yaml",
    "$Root\devops-diploma-infra\kubernetes\apps\web.yaml"
) | ForEach-Object {
    if (Test-Path $_) { Write-Host "OK $_" } else { Write-Host "MISSING $_"; exit 1 }
}

Write-Host "=== Docker compose (optional) ==="
if (Get-Command docker -ErrorAction SilentlyContinue) {
    Set-Location "$Root\Counter-Strike"
    if (-not (Test-Path .env)) { Copy-Item .env.example .env }
    docker compose up -d --build
    Start-Sleep -Seconds 25
    try {
        $hz = Invoke-RestMethod http://localhost/healthz
        Write-Host "healthz: $hz"
        $api = Invoke-RestMethod http://localhost/api/health
        Write-Host "api: $($api | ConvertTo-Json -Compress)"
    } catch {
        Write-Host "Compose health check failed: $_"
    }
    docker compose down
}

Write-Host "Checklist local OK"
