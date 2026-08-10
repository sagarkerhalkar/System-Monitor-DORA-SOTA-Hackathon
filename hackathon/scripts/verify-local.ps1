param(
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (& git rev-parse --show-toplevel 2>$null).Trim()
if (-not $repoRoot) { throw 'Run this script from the System-Monitor-DORA-SOTA-Hackathon repository.' }

$composeFile = Join-Path $repoRoot 'hackathon\docker-compose.yml'
if (-not (Test-Path -LiteralPath $composeFile)) { throw "Missing compose file: $composeFile" }

function Assert-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command is missing: $Name"
    }
}

function Show-Pass {
    param([string]$Message)
    Write-Host "[PASS] $Message" -ForegroundColor Green
}

function Wait-Http {
    param(
        [string]$Url,
        [switch]$Insecure,
        [int]$Attempts = 45
    )

    $pythonProbe = @'
import ssl
import sys
import urllib.request
url = sys.argv[1]
insecure = sys.argv[2] == "1"
ctx = ssl._create_unverified_context() if insecure else None
try:
    with urllib.request.urlopen(url, context=ctx, timeout=5) as response:
        response.read()
        raise SystemExit(0 if 200 <= response.status < 400 else 1)
except Exception:
    raise SystemExit(1)
'@

    for ($i = 1; $i -le $Attempts; $i++) {
        $insecureFlag = if ($Insecure) { '1' } else { '0' }
        & python -c $pythonProbe $Url $insecureFlag *> $null
        if ($LASTEXITCODE -eq 0) { return }
        Start-Sleep -Seconds 2
    }

    throw "Health check failed after $Attempts attempts: $Url"
}

Assert-Command git
Assert-Command docker
Assert-Command python

Write-Host '=== System Monitor DORA + SOTA Local Verification ===' -ForegroundColor Cyan
Write-Host "Repository: $repoRoot"
Write-Host ''

& git -C $repoRoot status --short
if ($LASTEXITCODE -ne 0) { throw 'git status failed.' }
Show-Pass 'Git repository is readable'

& docker version --format '{{.Server.Version}}' | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Docker Engine is not running. Start Docker Desktop first.' }
Show-Pass 'Docker Engine is running'

& docker compose version | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Docker Compose is not available.' }
Show-Pass 'Docker Compose is available'

& python --version | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Python is not available.' }
Show-Pass 'Python is available'

Push-Location $repoRoot
try {
    Write-Host ''
    Write-Host '1/6 Running AI Ops + DORA unit tests...' -ForegroundColor Cyan
    & python -m unittest discover -s hackathon/tests -v
    if ($LASTEXITCODE -ne 0) { throw 'Hackathon unit tests failed.' }
    Show-Pass 'All hackathon unit tests passed'

    $env:MONITOR_ADMIN_PASSWORD = 'Verify-' + [guid]::NewGuid().ToString('N') + '-Aa1!'

    Write-Host ''
    Write-Host '2/6 Validating Docker Compose...' -ForegroundColor Cyan
    & docker compose -f $composeFile config --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Docker Compose validation failed.' }
    Show-Pass 'Docker Compose configuration is valid'

    if (-not $SkipBuild) {
        Write-Host ''
        Write-Host '3/6 Building Monitor, UI, AI Ops and DORA images...' -ForegroundColor Cyan
        & docker compose -f $composeFile build
        if ($LASTEXITCODE -ne 0) { throw 'Docker image build failed.' }
        Show-Pass 'All four application images built successfully'
    }
    else {
        Write-Host '3/6 Image build skipped by request.' -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host '4/6 Starting complete stack...' -ForegroundColor Cyan
    & docker compose -f $composeFile up -d
    if ($LASTEXITCODE -ne 0) { throw 'Docker Compose startup failed.' }

    try {
        Wait-Http -Url 'https://127.0.0.1:8443/api/v1/health/live' -Insecure
        Wait-Http -Url 'http://127.0.0.1:8080/'
        Wait-Http -Url 'http://127.0.0.1:8081/healthz'
        Wait-Http -Url 'http://127.0.0.1:8082/healthz'
    }
    catch {
        Write-Host ''
        Write-Host 'Health check failed. Container status:' -ForegroundColor Yellow
        & docker compose -f $composeFile ps -a | Out-Host
        Write-Host ''
        Write-Host 'Monitor logs:' -ForegroundColor Yellow
        & docker compose -f $composeFile logs --no-color --tail=200 monitor | Out-Host
        Write-Host ''
        Write-Host 'UI logs:' -ForegroundColor Yellow
        & docker compose -f $composeFile logs --no-color --tail=200 ui | Out-Host
        throw
    }
    Show-Pass 'Monitor + UI + AI Ops + DORA are healthy'

    Write-Host ''
    Write-Host '5/6 Proving AI anomaly inference...' -ForegroundColor Cyan
    $aiPayload = @{
        machine_id = 'windows-local-verification'
        metrics = @{
            cpu_pct = 98
            memory_pct = 97
            disk_pct = 96
            latency_ms = 320
            packet_loss_pct = 9
        }
        history = @(
            @{ cpu_pct=40; memory_pct=60; disk_pct=70; latency_ms=30; packet_loss_pct=0.1 },
            @{ cpu_pct=41; memory_pct=61; disk_pct=70; latency_ms=31; packet_loss_pct=0.1 },
            @{ cpu_pct=39; memory_pct=60; disk_pct=70; latency_ms=32; packet_loss_pct=0.1 },
            @{ cpu_pct=40; memory_pct=59; disk_pct=70; latency_ms=30; packet_loss_pct=0.1 },
            @{ cpu_pct=42; memory_pct=60; disk_pct=70; latency_ms=31; packet_loss_pct=0.1 }
        )
    } | ConvertTo-Json -Depth 6
    $ai = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:8081/v1/analyze' -ContentType 'application/json' -Body $aiPayload
    if (-not $ai.ok -or [double]$ai.anomaly_score -lt 60) {
        throw "AI inference proof failed. Response: $($ai | ConvertTo-Json -Depth 6 -Compress)"
    }
    Write-Host ("AI anomaly score: {0}; status: {1}" -f $ai.anomaly_score, $ai.status)
    Show-Pass 'AI Ops anomaly inference is working'

    Write-Host ''
    Write-Host '6/6 Proving DORA event ingestion + calculation...' -ForegroundColor Cyan
    $now = (Get-Date).ToUniversalTime()
    $deploymentId = 'local-' + [guid]::NewGuid().ToString('N')
    $deployment = @{
        id = $deploymentId
        service = 'monitor'
        commit_sha = (& git rev-parse HEAD).Trim()
        environment = 'production'
        change_started_at = $now.AddMinutes(-10).ToString('yyyy-MM-ddTHH:mm:ssZ')
        deployed_at = $now.ToString('yyyy-MM-ddTHH:mm:ssZ')
        status = 'success'
        rollout_strategy = 'canary'
        source = 'local-verification'
    } | ConvertTo-Json
    $null = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:8082/v1/deployments' -ContentType 'application/json' -Body $deployment
    $dora = Invoke-RestMethod -Method Get -Uri 'http://127.0.0.1:8082/v1/metrics?environment=production&days=30'
    if ([int]$dora.successful_deployments -lt 1) {
        throw "DORA metric proof failed. Response: $($dora | ConvertTo-Json -Depth 6 -Compress)"
    }
    Write-Host ("Successful deployments: {0}; lead time median: {1}s; CFR: {2}%; MTTR: {3}s" -f $dora.successful_deployments, $dora.median_lead_time_seconds, $dora.change_failure_rate_pct, $dora.mean_time_to_restore_seconds)
    Show-Pass 'DORA event collection and metric calculation are working'

    Write-Host ''
    & docker compose -f $composeFile ps | Out-Host
    Write-Host ''
    Write-Host '=== ALL PHASE-1 CHECKS PASSED ===' -ForegroundColor Green
    Write-Host 'UI:      http://127.0.0.1:8080/'
    Write-Host 'Monitor: https://127.0.0.1:8443/api/v1/health/live'
    Write-Host 'AI Ops:  http://127.0.0.1:8081/healthz'
    Write-Host 'DORA:    http://127.0.0.1:8082/healthz'
}
finally {
    Write-Host ''
    Write-Host 'Stopping local verification stack...' -ForegroundColor Cyan
    try { & docker compose -f $composeFile down -v --remove-orphans | Out-Host } catch { }
    Remove-Item Env:MONITOR_ADMIN_PASSWORD -ErrorAction SilentlyContinue
    Pop-Location
}
