$files = Get-ChildItem -Path "flutter_app/lib/features" -Recurse -Filter "*screen*.dart"
Write-Host "Found $($files.Count) screen files"

$stats = @{
    TotalScreens = $files.Count
    UsingKCard = 0
    UsingKButton = 0
    UsingKMoney = 0
    UsingKStatusChip = 0
    UsingElevatedButton = 0
    UsingTextButton = 0
    UsingOutlineButton = 0
}

$rawButtonFiles = @()

foreach ($f in $files) {
    $content = Get-Content $f.FullName -Raw
    if ($content -match "KCard") { $stats.UsingKCard++ }
    if ($content -match "KButton") { $stats.UsingKButton++ }
    if ($content -match "KMoney") { $stats.UsingKMoney++ }
    if ($content -match "KStatusChip") { $stats.UsingKStatusChip++ }
    
    $hasRawButton = $false
    if ($content -match "ElevatedButton" -or $content -match "OutlinedButton\(" -or $content -match "TextButton\(") {
        $hasRawButton = $true
        $rawButtonFiles += $f.FullName.Replace("c:\dileepkm\Learning\katasticho\flutter_app\", "")
    }
}

Write-Host "--- Presentation Screen Design Token Adoption ---"
Write-Host "Total Screens: $($stats.TotalScreens)"
Write-Host "Using KCard: $($stats.UsingKCard)"
Write-Host "Using KButton: $($stats.UsingKButton)"
Write-Host "Using KMoney: $($stats.UsingKMoney)"
Write-Host "Using KStatusChip: $($stats.UsingKStatusChip)"
Write-Host "Screens with raw Flutter buttons (ElevatedButton/OutlinedButton/TextButton): $($rawButtonFiles.Count)"
if ($rawButtonFiles.Count -gt 0) {
    Write-Host "`nTop 25 screens with raw buttons to review:"
    $rawButtonFiles | Select-Object -First 25 | ForEach-Object { Write-Host "  - $_" }
}
