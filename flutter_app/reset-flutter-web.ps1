# Reset Flutter web state and start Chrome for local recovery.
# Run from flutter_app. This is a recovery script, not the normal startup path.

[CmdletBinding()]
param(
    [ValidateRange(1024, 65535)]
    [int]$WebPort = 52100,

    [switch]$DeepClean,
    [switch]$VerboseFlutter,
    [switch]$KeepChrome
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Checked {
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(ValueFromRemainingArguments)][string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "'$Command $($Arguments -join ' ')' failed with exit code $LASTEXITCODE."
    }
}

function Remove-Safely {
    param([Parameter(Mandatory)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        Write-Host "Removing $Path"
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
    }
}

function Stop-ByName {
    param([Parameter(Mandatory)][string[]]$Names)

    foreach ($name in $Names) {
        Get-Process -Name $name -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

function Release-Port {
    param([Parameter(Mandatory)][int]$Port)

    $ownerPids = @(
        Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty OwningProcess -Unique
    )

    if (-not $ownerPids) {
        $pattern = "^\s*TCP\s+\S+:$Port\s+\S+\s+LISTENING\s+(\d+)\s*$"
        $ownerPids = @(
            netstat -ano -p tcp | ForEach-Object {
                if ($_ -match $pattern) { [int]$Matches[1] }
            } | Select-Object -Unique
        )
    }

    foreach ($ownerPid in $ownerPids) {
        if ($ownerPid -and $ownerPid -ne $PID) {
            Write-Host "Stopping PID $ownerPid using port $Port..."
            Stop-Process -Id $ownerPid -Force -ErrorAction SilentlyContinue
        }
    }

    Start-Sleep -Milliseconds 700
    if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) {
        throw "Port $Port is still occupied. Run PowerShell as Administrator and retry."
    }
}

try {
    if (-not (Test-Path -LiteralPath '.\pubspec.yaml') -or
        -not (Test-Path -LiteralPath '.\lib\main.dart')) {
        throw 'Run this script from the Flutter project root: flutter_app.'
    }
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        throw "The 'flutter' command is not available in PATH."
    }

    Write-Host 'Flutter web recovery reset' -ForegroundColor Green
    Write-Host "Project: $(Get-Location)"
    Write-Host "Port:    $WebPort"
    if (-not $KeepChrome) {
        Write-Warning 'All Chrome windows will be closed. Save browser work first.'
        Stop-ByName -Names @('chrome', 'chromedriver')
    }
    Stop-ByName -Names @('dart', 'dartaotruntime', 'flutter_tester', 'gen_snapshot')
    Start-Sleep -Seconds 1

    Write-Host 'Freeing the Flutter web port...'
    Release-Port -Port $WebPort

    Write-Host 'Cleaning generated Flutter files...'
    Invoke-Checked flutter clean
    @('.\.dart_tool', '.\build', '.\.flutter-plugins',
      '.\.flutter-plugins-dependencies') | ForEach-Object { Remove-Safely $_ }

    if ($DeepClean) {
        Write-Host 'Cleaning optional Dart/DevTools caches...'
        if ($env:APPDATA) { Remove-Safely (Join-Path $env:APPDATA '.flutter-devtools') }
        if ($env:LOCALAPPDATA) { Remove-Safely (Join-Path $env:LOCALAPPDATA '.dartServer') }
        Write-Host 'Repairing the global Pub cache. This may take several minutes.'
        Invoke-Checked flutter pub cache repair
    }

    Write-Host 'Refreshing dependencies and web artifacts...'
    Invoke-Checked flutter pub get
    Invoke-Checked flutter precache --web
    Invoke-Checked flutter devices

    $flutterArguments = @(
        'run', '-d', 'chrome',
        '--web-hostname=127.0.0.1',
        "--web-port=$WebPort",
        '--no-web-experimental-hot-reload'
    )
    if ($VerboseFlutter) { $flutterArguments += '-v' }

    Write-Host "Starting Flutter at http://127.0.0.1:$WebPort" -ForegroundColor Cyan
    Write-Host 'Use capital R for hot restart and q to quit.'
    & flutter @flutterArguments
    exit $LASTEXITCODE
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Run PowerShell as Administrator only if port cleanup was denied.'
    exit 1
}
