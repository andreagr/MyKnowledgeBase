# Build MyKB-Setup.exe using Inno Setup (no PATH required).
$ErrorActionPreference = "Stop"

$PackagingDir = Join-Path $PSScriptRoot "packaging"
$ReleaseDir = Join-Path $PackagingDir "release\MyKB"
$Iscc = & (Join-Path $PackagingDir "resolve-iscc.ps1")

if (-not $Iscc) {
    throw @"
Inno Setup not found. Install from https://jrsoftware.org/isinfo.php
Expected: C:\Program Files (x86)\Inno Setup 6\ISCC.exe
"@
}

if (-not (Test-Path (Join-Path $ReleaseDir "mykb.exe"))) {
    throw "Release folder missing. Run .\build-release.ps1 first."
}

Write-Host "Using: $Iscc"
Push-Location $PackagingDir
try {
    & $Iscc (Join-Path $PackagingDir "MyKB.iss")
} finally {
    Pop-Location
}

$Installer = Join-Path $PackagingDir "installer\MyKB-Setup.exe"
if (Test-Path $Installer) {
    Write-Host ""
    Write-Host "Installer ready:"
    Write-Host "  $Installer"
} else {
    throw "Compiler finished but installer was not created at $Installer"
}
