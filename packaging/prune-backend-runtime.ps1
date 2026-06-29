# Remove non-runtime cruft from the portable Python site-packages.
param(
    [Parameter(Mandatory = $true)]
    [string]$PythonDir
)

$ErrorActionPreference = "Stop"
$SitePackages = Join-Path $PythonDir "Lib\site-packages"

if (-not (Test-Path $SitePackages)) {
    return
}

Write-Host "Pruning site-packages to reduce install size..."

Get-ChildItem $SitePackages -Recurse -Directory -Filter "__pycache__" -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

foreach ($dirName in @("tests", "test", "testing", "docs", "doc")) {
    Get-ChildItem $SitePackages -Recurse -Directory -Filter $dirName -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "site-packages" } |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

Get-ChildItem $SitePackages -Recurse -Include "*.pyc", "*.pyo" -File -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

# Optional native debug symbols
Get-ChildItem $SitePackages -Recurse -Include "*.pdb" -File -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

Write-Host "Prune complete."
