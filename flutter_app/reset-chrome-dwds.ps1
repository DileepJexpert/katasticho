[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host 'Resetting Chrome and Flutter web debug state...' -ForegroundColor Cyan
Write-Host 'Chrome windows will be closed. Cookies, passwords, and saved sessions are kept.' -ForegroundColor Yellow

Get-Process -Name chrome,chromedriver,dart,dartaotruntime,flutter_tester,gen_snapshot `
    -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 2

# Flutter creates temporary Chrome profiles for web debugging.
Get-ChildItem -Path "$env:TEMP\flutter_tools.*" -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# Clear browser caches only. Do not remove cookies or account/session databases.
$cachePaths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache"
)

foreach ($cachePath in $cachePaths) {
    if (Test-Path -LiteralPath $cachePath) {
        Remove-Item -LiteralPath $cachePath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host 'Starting Flutter on Chrome using the default automatically selected port...' -ForegroundColor Green
& "$PSScriptRoot\run-dev-web.ps1" -Device chrome
exit $LASTEXITCODE
