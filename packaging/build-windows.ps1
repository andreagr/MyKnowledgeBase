# Builds a distributable Windows folder for non-technical users.
param(
    [switch]$SkipBackendSetup,
    [switch]$CreateInstaller
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$AppDir = Join-Path $Root "app"
$RuntimeDir = Join-Path $PSScriptRoot "backend-runtime"
$ReleaseDir = Join-Path $PSScriptRoot "release\MyKB"
$FlutterReleaseDir = Join-Path $AppDir "build\windows\x64\runner\Release"

if (-not $SkipBackendSetup) {
    & (Join-Path $PSScriptRoot "setup-backend-runtime.ps1")
}

if (-not (Test-Path $RuntimeDir)) {
    throw "Backend runtime missing. Run setup-backend-runtime.ps1 first."
}

& (Join-Path $PSScriptRoot "sync-backend-sources.ps1") -RuntimeDir $RuntimeDir

Write-Host "Building Flutter Windows release..."
Push-Location $AppDir
try {
    flutter pub get
    dart run flutter_launcher_icons
    flutter build windows --release
} finally {
    Pop-Location
}

if (-not (Test-Path $FlutterReleaseDir)) {
    throw "Flutter release build not found at $FlutterReleaseDir"
}

Write-Host "Assembling release folder at $ReleaseDir"
if (Test-Path $ReleaseDir) {
    Remove-Item -Recurse -Force $ReleaseDir
}
New-Item -ItemType Directory -Path $ReleaseDir | Out-Null

Copy-Item -Path (Join-Path $FlutterReleaseDir "*") -Destination $ReleaseDir -Recurse
Copy-Item -Path $RuntimeDir -Destination (Join-Path $ReleaseDir "backend") -Recurse

$BundledPython = Join-Path $ReleaseDir "backend\python\python.exe"
if (-not (Test-Path $BundledPython)) {
    throw "Bundled Python missing at $BundledPython. Re-run setup-backend-runtime.ps1."
}

$PyvenvCfg = Join-Path $ReleaseDir "backend\python\pyvenv.cfg"
if (Test-Path $PyvenvCfg) {
    throw "Release contains a linked venv (pyvenv.cfg). Re-run setup-backend-runtime.ps1 to build a portable runtime."
}

Write-Host "Verifying bundled Python starts on this machine..."
$VerifyScriptPath = Join-Path $ReleaseDir "backend\_verify_release.py"
@'
import fastapi
import uvicorn
import fastembed
import local_llm
print("ok")
'@ | Set-Content -Path $VerifyScriptPath -Encoding utf8
$Verify = & $BundledPython $VerifyScriptPath 2>&1
$verifyExitCode = $LASTEXITCODE
Remove-Item -Force $VerifyScriptPath -ErrorAction SilentlyContinue
if ($verifyExitCode -ne 0) {
    throw "Bundled Python verification failed: $Verify"
}

Write-Host ""
Write-Host "Release build complete:"
Write-Host "  $ReleaseDir"
Write-Host ""
Write-Host "Give users the MyKB folder, or install Inno Setup and run:"
Write-Host "  .\build-release.ps1 -CreateInstaller"

if ($CreateInstaller) {
    $Iscc = & (Join-Path $PSScriptRoot "resolve-iscc.ps1")
    if (-not $Iscc) {
        Write-Warning @"
Inno Setup is not installed (ISCC.exe not found).
Install from https://jrsoftware.org/isinfo.php
Or run: .\build-installer.ps1
Until then, distribute: packaging\release\MyKB
"@
    } else {
        Write-Host "Building installer with: $Iscc"
        & $Iscc (Join-Path $PSScriptRoot "MyKB.iss")
        Write-Host "Installer: $(Join-Path $PSScriptRoot 'installer\MyKB-Setup.exe')"
    }
}
