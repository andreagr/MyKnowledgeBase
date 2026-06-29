# Rebuild the distributable Windows app (backend + Flutter + release folder).
# Run from the repo root after making changes.
#
# Usage:
#   .\build-release.ps1                  # full rebuild (default)
#   .\build-release.ps1 -Fast            # skip pip reinstall if only Flutter/UI changed
#   .\build-release.ps1 -CreateInstaller # also build MyKB-Setup.exe (needs Inno Setup)

param(
    [switch]$Fast,
    [switch]$CreateInstaller
)

$ErrorActionPreference = "Stop"

$buildArgs = @()
if ($Fast) {
    $buildArgs += "-SkipBackendSetup"
}
if ($CreateInstaller) {
    $buildArgs += "-CreateInstaller"
}

& (Join-Path $PSScriptRoot "packaging\build-windows.ps1") @buildArgs
