$base = Join-Path $PSScriptRoot "release\MyKB"
$site = Join-Path $base "backend\python\Lib\site-packages"

Write-Host "=== Top-level ==="
Get-ChildItem $base | ForEach-Object {
    if ($_.PSIsContainer) {
        $s = (Get-ChildItem $_.FullName -Recurse -File -EA SilentlyContinue | Measure-Object Length -Sum).Sum
    } else { $s = $_.Length }
    [PSCustomObject]@{ Path = $_.Name; MB = [math]::Round($s / 1MB, 1) }
} | Sort-Object MB -Descending | Format-Table -AutoSize

Write-Host "=== Largest site-packages (>15 MB) ==="
Get-ChildItem $site -Directory | ForEach-Object {
    $s = (Get-ChildItem $_.FullName -Recurse -File -EA SilentlyContinue | Measure-Object Length -Sum).Sum
    if ($s -gt 15MB) {
        [PSCustomObject]@{ Package = $_.Name; MB = [math]::Round($s / 1MB, 0) }
    }
} | Sort-Object MB -Descending | Format-Table -AutoSize

$total = (Get-ChildItem $base -Recurse -File | Measure-Object Length -Sum).Sum
Write-Host "Total: $([math]::Round($total / 1GB, 2)) GB"
