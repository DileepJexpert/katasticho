param(
    [Parameter(Mandatory = $true)]
    [string]$BackupFile,
    [string]$DbHost = $env:DB_HOST,
    [string]$DbPort = $env:DB_PORT,
    [string]$DbName = $env:DB_NAME,
    [string]$DbUser = $env:DB_USER,
    [string]$DbPassword = $env:DB_PASSWORD,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

if (!(Test-Path -LiteralPath $BackupFile)) {
    throw "Backup file not found: $BackupFile"
}

if ([string]::IsNullOrWhiteSpace($DbHost)) { $DbHost = "localhost" }
if ([string]::IsNullOrWhiteSpace($DbPort)) { $DbPort = "5432" }
if ([string]::IsNullOrWhiteSpace($DbName)) { $DbName = "katasticho" }
if ([string]::IsNullOrWhiteSpace($DbUser)) { $DbUser = "katasticho" }

$pgRestore = Get-Command pg_restore -ErrorAction SilentlyContinue
if ($null -eq $pgRestore) {
    throw "pg_restore was not found. Install PostgreSQL client tools and ensure pg_restore is on PATH."
}

$shaFile = "$BackupFile.sha256"
if (Test-Path -LiteralPath $shaFile) {
    $expected = (Get-Content -LiteralPath $shaFile -Raw).Trim()
    $actual = (Get-FileHash -Algorithm SHA256 -Path $BackupFile).Hash
    if ($expected -ne $actual) {
        throw "Backup checksum mismatch. Expected $expected but got $actual."
    }
}

$env:PGPASSWORD = $DbPassword
try {
    $args = @(
        "--host=$DbHost",
        "--port=$DbPort",
        "--username=$DbUser",
        "--dbname=$DbName",
        "--verbose",
        "--no-owner",
        "--no-privileges"
    )

    if ($Clean) {
        $args += "--clean"
        $args += "--if-exists"
    }

    $args += $BackupFile
    & $pgRestore.Source @args

    if ($LASTEXITCODE -ne 0) {
        throw "pg_restore failed with exit code $LASTEXITCODE"
    }

    Write-Host "Restore completed into database: $DbName"
} finally {
    Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
}
