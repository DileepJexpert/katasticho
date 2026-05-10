param(
    [string]$OutputDir = ".\backups",
    [string]$DbHost = $env:DB_HOST,
    [string]$DbPort = $env:DB_PORT,
    [string]$DbName = $env:DB_NAME,
    [string]$DbUser = $env:DB_USER,
    [string]$DbPassword = $env:DB_PASSWORD,
    [int]$RetentionDays = 30
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($DbHost)) { $DbHost = "localhost" }
if ([string]::IsNullOrWhiteSpace($DbPort)) { $DbPort = "5432" }
if ([string]::IsNullOrWhiteSpace($DbName)) { $DbName = "katasticho" }
if ([string]::IsNullOrWhiteSpace($DbUser)) { $DbUser = "katasticho" }

$pgDump = Get-Command pg_dump -ErrorAction SilentlyContinue
if ($null -eq $pgDump) {
    throw "pg_dump was not found. Install PostgreSQL client tools and ensure pg_dump is on PATH."
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$fileName = "katasticho-$DbName-$timestamp.dump"
$target = Join-Path $OutputDir $fileName

$env:PGPASSWORD = $DbPassword
try {
    & $pgDump.Source `
        --host=$DbHost `
        --port=$DbPort `
        --username=$DbUser `
        --format=custom `
        --blobs `
        --verbose `
        --file=$target `
        $DbName

    if ($LASTEXITCODE -ne 0) {
        throw "pg_dump failed with exit code $LASTEXITCODE"
    }

    $hash = Get-FileHash -Algorithm SHA256 -Path $target
    $hash.Hash | Set-Content -Path "$target.sha256" -Encoding ascii

    Get-ChildItem -Path $OutputDir -Filter "katasticho-$DbName-*.dump" |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) } |
        Remove-Item -Force

    Write-Host "Backup created: $target"
    Write-Host "SHA256: $($hash.Hash)"
} finally {
    Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
}
