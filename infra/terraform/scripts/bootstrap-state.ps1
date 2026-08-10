param(
    [string]$Region = "ap-south-1",
    [string]$Project = "sagar-system-monitor"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    throw 'AWS CLI is required.'
}

$accountId = ((& aws sts get-caller-identity --query Account --output text) | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $accountId) {
    throw 'AWS authentication failed. Sign in with AWS CLI/SSO or use AWS CloudShell, then retry.'
}

$bucket = ("{0}-tfstate-{1}-{2}" -f $Project, $accountId, $Region).ToLowerInvariant()
$bucket = $bucket -replace '[^a-z0-9.-]', '-'

$previousPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Continue'
    & aws s3api head-bucket --bucket $bucket *> $null
    $bucketExists = ($LASTEXITCODE -eq 0)
}
finally {
    $ErrorActionPreference = $previousPreference
}

if (-not $bucketExists) {
    Write-Host "Creating Terraform state bucket: $bucket" -ForegroundColor Cyan
    if ($Region -eq 'us-east-1') {
        & aws s3api create-bucket --bucket $bucket --region $Region | Out-Null
    }
    else {
        & aws s3api create-bucket `
            --bucket $bucket `
            --region $Region `
            --create-bucket-configuration "LocationConstraint=$Region" | Out-Null
    }
    if ($LASTEXITCODE -ne 0) { throw 'Failed to create Terraform state bucket.' }
}
else {
    Write-Host "Terraform state bucket already exists: $bucket" -ForegroundColor Yellow
}

& aws s3api put-public-access-block `
    --bucket $bucket `
    --public-access-block-configuration 'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to enforce S3 public-access block.' }

& aws s3api put-bucket-versioning `
    --bucket $bucket `
    --versioning-configuration Status=Enabled | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to enable S3 bucket versioning.' }

$encryption = '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'
& aws s3api put-bucket-encryption `
    --bucket $bucket `
    --server-side-encryption-configuration $encryption | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to enable S3 state encryption.' }

$backendFile = Join-Path (Split-Path $PSScriptRoot -Parent) 'backend.hcl'
@"
bucket = "$bucket"
key    = "system-monitor/hackathon/terraform.tfstate"
region = "$Region"
"@ | Set-Content -LiteralPath $backendFile -Encoding ascii

Write-Host ''
Write-Host '[PASS] Terraform state bootstrap complete.' -ForegroundColor Green
Write-Host "Bucket: $bucket"
Write-Host "Backend config: $backendFile"
Write-Host ''
Write-Host 'Next:' -ForegroundColor Cyan
Write-Host '  Copy-Item .\backend.tf.example .\backend.tf'
Write-Host '  terraform init -backend-config=backend.hcl'
