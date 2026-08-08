[CmdletBinding()]
param(
    [ValidateSet('chrome', 'edge', 'web-server')]
    [string]$Device = 'chrome'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath '.\pubspec.yaml')) {
    throw 'Run this script from the flutter_app directory.'
}

# Stale Dart processes can prevent DWDS from attaching to a fresh browser tab.
Get-Process -Name dart,dartaotruntime,flutter_tester,gen_snapshot -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue

$arguments = @(
    'run',
    '-d', $Device,
    '--dart-define=ENV=dev',
    '--no-web-experimental-hot-reload'
)

Write-Host "Starting Katasticho Flutter web app on $Device using Flutter's default web port..." -ForegroundColor Cyan
Write-Host 'Chrome is not closed. Use capital R for hot restart and q to quit.' -ForegroundColor DarkGray

& flutter @arguments
exit $LASTEXITCODE
