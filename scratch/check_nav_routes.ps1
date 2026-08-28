$shell = Get-Content 'flutter_app/lib/routing/shell_screen.dart' -Raw
$router = Get-Content 'flutter_app/lib/routing/app_router.dart' -Raw

$allMatches = [regex]::Matches($shell, 'route:\s*([^\),\s]+)')
Write-Host "Total nav routes found in shell_screen: $($allMatches.Count)"

$checked = 0
$missingRouteConst = @()
$missingGoRoute = @()

foreach ($m in $allMatches) {
    $r = $m.Groups[1].Value.Trim()
    $checked++
    if ($r.StartsWith('Routes.')) {
        $name = $r.Substring(7)
        if ($router -match ("static const\s+" + [regex]::Escape($name) + "\s*=\s*'([^']+)'")) {
            $pathPattern = $Matches[1]
            if ($router -notmatch ("path:\s*(Routes\." + [regex]::Escape($name) + "|'" + [regex]::Escape($pathPattern) + "')")) {
                $missingGoRoute += "$name ($pathPattern)"
            }
        } else {
            $missingRouteConst += $name
        }
    } elseif ($r.StartsWith("'/") -or $r.StartsWith('"/')) {
        $path = $r.Trim("'`"")
        if ($router -notmatch ("path:\s*'" + [regex]::Escape($path) + "'")) {
            $missingGoRoute += "Literal path: $path"
        }
    }
}

Write-Host "Routes checked: $checked"
Write-Host "Missing in Routes class: $($missingRouteConst.Count)"
if ($missingRouteConst.Count -gt 0) {
    $missingRouteConst | ForEach-Object { Write-Host "  - $_" }
}

Write-Host "Missing GoRoute in ShellRoute: $($missingGoRoute.Count)"
if ($missingGoRoute.Count -gt 0) {
    $missingGoRoute | ForEach-Object { Write-Host "  - $_" }
}
