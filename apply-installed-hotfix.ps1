# Hotfix: copy latest backend .py files into the installed MyKB (requires admin).
$ErrorActionPreference = "Stop"

$InstallBackend = "${env:ProgramFiles}\MyKB\backend"
if (-not (Test-Path $InstallBackend)) {
    throw "Installed MyKB not found at $InstallBackend"
}

$SyncScript = Join-Path $PSScriptRoot "packaging\sync-backend-sources.ps1"
$elevated = @"
& '$SyncScript' -InstallBackendDir '$InstallBackend'
Write-Host 'Hotfix applied. Close and reopen MyKB.'
"@

Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command $elevated" -Wait
Write-Host ""
Write-Host "If UAC was declined, run without admin instead:"
Write-Host "  .\apply-user-hotfix.ps1"
