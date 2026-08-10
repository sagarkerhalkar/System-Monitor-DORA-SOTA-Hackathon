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

function Get-ComposeContainerId {
    param([string]$Service)
    return ((& docker compose -f $composeFile ps -q $Service 2>$null | Out-String).Trim())
}

function Wait-ContainerHealthy {
    param(
        [string]$Service,
        [int]$Attempts = 45
    )

    for ($i = 1; $i -le $Attempts; $i++) {
        $containerId = Get-ComposeContainerId -Service $Service
        if ($containerId) {
            $status = ((& docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' $containerId 2>$null | Out-String).Trim())
            if ($status -eq 'healthy') { return }
            if ($status -in @('exited', 'dead')) {
                throw "Container $Service stopped before becoming healthy (status=$status)."
            }
        }
        Start-Sleep -Seconds 2
    }

    throw "Container $Service did not become healthy after $Attempts attempts."
}

function Wait-UiInContainer {
    param([int]$Attempts = 45)

    for ($i = 1; $i -le $Attempts; $i++) {
        $previousErrorActionPreference = $ErrorActionPreference
        $exitCode = 1
        try {
            $ErrorActionPreference = 'Continue'
            & docker compose -f $composeFile exec -T ui sh -c 'wget -qO- http://127.0.0.1:8080/ >/dev/null' *> $null
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
        if ($exitCode -eq 0) { return }
        Start-Sleep -Seconds 2
    }

    throw 'UI did not respond inside its Nginx container.'
}

function Assert-TcpPort {
    param([int]$Port)

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $client.BeginConnect('127.0.0.1', $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne(3000)) {
            throw "Timed out connecting to 127.0.0.1:$Port"
        }
        $client.EndConnect($async)
    }
    finally {
        $client.Close()
    }
    Show-Pass "Published host port $Port is reachable"
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
    Write-Host '4/6 Starting complete stack and proving service health...' -ForegroundColor Cyan
    & docker compose -f $composeFile up -d
    if ($LASTEXITCODE -ne 0) { throw 'Docker Compose startup failed.' }

    try {
        Wait-ContainerHealthy -Service 'monitor'
        Wait-ContainerHealthy -Service 'ai-ops'
        Wait-ContainerHealthy -Service 'dora'
        Wait-UiInContainer

        Assert-TcpPort -Port 8443
        Assert-TcpPort -Port 8080
        Assert-TcpPort -Port 8081
        Assert-TcpPort -Port 8082
    }
    catch {
        Write-Host ''
        Write-Host 'Health verification failed. Container status:' -ForegroundColor Yellow
        & docker compose -f $composeFile ps -a | Out-Host
        foreach ($service in @('monitor', 'ui', 'ai-ops', 'dora')) {
            Write-Host ''
            Write-Host ("{0} logs:" -f $service) -ForegroundColor Yellow
            & docker compose -f $composeFile logs --no-color --tail=200 $service | Out-Host
        }
        throw
    }
    Show-Pass 'Monitor + UI + AI Ops + DORA are healthy'

    Write-Host ''
    Write-Host '5/6 Proving AI anomaly inference inside AI Ops container...' -ForegroundColor Cyan
    $aiProof = @'
import json
import urllib.request
payload = {
    "machine_id": "windows-local-verification",
    "metrics": {
        "cpu_pct": 98,
        "memory_pct": 97,
        "disk_pct": 96,
        "latency_ms": 320,
        "packet_loss_pct": 9,
    },
    "history": [
        {"cpu_pct": 40, "memory_pct": 60, "disk_pct": 70, "latency_ms": 30, "packet_loss_pct": 0.1},
        {"cpu_pct": 41, "memory_pct": 61, "disk_pct": 70, "latency_ms": 31, "packet_loss_pct": 0.1},
        {"cpu_pct": 39, "memory_pct": 60, "disk_pct": 70, "latency_ms": 32, "packet_loss_pct": 0.1},
        {"cpu_pct": 40, "memory_pct": 59, "disk_pct": 70, "latency_ms": 30, "packet_loss_pct": 0.1},
        {"cpu_pct": 42, "memory_pct": 60, "disk_pct": 70, "latency_ms": 31, "packet_loss_pct": 0.1},
    ],
}
request = urllib.request.Request(
    "http://127.0.0.1:8081/v1/analyze",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(request, timeout=5) as response:
    result = json.load(response)
assert result.get("ok") and float(result.get("anomaly_score", 0)) >= 60, result
print(json.dumps({"anomaly_score": result["anomaly_score"], "status": result["status"]}))
'@
    $aiResult = ((& docker compose -f $composeFile exec -T ai-ops python -c $aiProof | Out-String).Trim())
    if ($LASTEXITCODE -ne 0) { throw 'AI inference proof failed.' }
    Write-Host "AI result: $aiResult"
    Show-Pass 'AI Ops anomaly inference is working'

    Write-Host ''
    Write-Host '6/6 Proving DORA event ingestion + calculation inside DORA container...' -ForegroundColor Cyan
    $commitSha = (& git rev-parse HEAD).Trim()
    $doraProof = @'
import json
import sys
import uuid
import urllib.request
from datetime import datetime, timedelta, timezone

commit_sha = sys.argv[1]
now = datetime.now(timezone.utc)
deployment_id = "local-" + uuid.uuid4().hex
payload = {
    "id": deployment_id,
    "service": "monitor",
    "commit_sha": commit_sha,
    "environment": "production",
    "change_started_at": (now - timedelta(minutes=10)).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "deployed_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
    "status": "success",
    "rollout_strategy": "canary",
    "source": "local-verification",
}
request = urllib.request.Request(
    "http://127.0.0.1:8082/v1/deployments",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(request, timeout=5) as response:
    json.load(response)
with urllib.request.urlopen("http://127.0.0.1:8082/v1/metrics?environment=production&days=30", timeout=5) as response:
    metrics = json.load(response)
assert int(metrics.get("successful_deployments", 0)) >= 1, metrics
print(json.dumps({
    "successful_deployments": metrics.get("successful_deployments"),
    "median_lead_time_seconds": metrics.get("median_lead_time_seconds"),
    "change_failure_rate_pct": metrics.get("change_failure_rate_pct"),
    "mean_time_to_restore_seconds": metrics.get("mean_time_to_restore_seconds"),
}))
'@
    $doraResult = ((& docker compose -f $composeFile exec -T dora python -c $doraProof $commitSha | Out-String).Trim())
    if ($LASTEXITCODE -ne 0) { throw 'DORA metric proof failed.' }
    Write-Host "DORA result: $doraResult"
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
