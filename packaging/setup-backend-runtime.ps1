# Builds a portable Python runtime for the packaged desktop app.
# Uses the official Windows embeddable distribution so the bundle works on
# any PC — not a developer-machine venv with absolute paths in pyvenv.cfg.
param(
    [string]$PythonVersion = "3.12.8"
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$RuntimeDir = Join-Path $PSScriptRoot "backend-runtime"
$PythonDir = Join-Path $RuntimeDir "python"
$CacheDir = Join-Path $PSScriptRoot "cache"
$Requirements = Join-Path $Root "requirements-packaging.txt"

$BackendFiles = @(
    "app.py",
    "backend_main.py",
    "paths.py",
    "embeddings.py",
    "llm_providers.py",
    "connections_store.py",
    "settings_store.py",
    "folder_scan.py",
    "email_sync.py"
)

$MajorMinor = ($PythonVersion.Split(".")[0..1] -join "")
$EmbedZipName = "python-$PythonVersion-embed-amd64.zip"
$EmbedUrl = "https://www.python.org/ftp/python/$PythonVersion/$EmbedZipName"
$EmbedZip = Join-Path $CacheDir $EmbedZipName
$GetPipUrl = "https://bootstrap.pypa.io/get-pip.py"
$GetPipScript = Join-Path $CacheDir "get-pip.py"

function Ensure-Directory([string]$Path) {
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Download-File([string]$Url, [string]$Destination) {
    if (Test-Path $Destination) {
        return
    }
    Ensure-Directory (Split-Path -Parent $Destination)
    Write-Host "Downloading $Url"
    Invoke-WebRequest -Uri $Url -OutFile $Destination
}

Write-Host "Creating portable backend runtime in $RuntimeDir"

if (Test-Path $RuntimeDir) {
    try {
        Remove-Item -Recurse -Force $RuntimeDir
    } catch {
        $staleDir = Join-Path $PSScriptRoot ("backend-runtime-stale-" + (Get-Date -Format "yyyyMMddHHmmss"))
        Write-Warning "Could not delete $RuntimeDir (files in use). Moving aside to $staleDir"
        Move-Item -Path $RuntimeDir -Destination $staleDir -Force
    }
}
Ensure-Directory $RuntimeDir
Ensure-Directory $CacheDir

Download-File $EmbedUrl $EmbedZip
Download-File $GetPipUrl $GetPipScript

Write-Host "Extracting embeddable Python $PythonVersion"
Expand-Archive -Path $EmbedZip -DestinationPath $PythonDir -Force

$SitePackages = Join-Path $PythonDir "Lib\site-packages"
Ensure-Directory $SitePackages

$PthFile = Join-Path $PythonDir "python$MajorMinor._pth"
if (-not (Test-Path $PthFile)) {
    throw "Expected path file not found: $PthFile"
}

@"
python$MajorMinor.zip
.
..
Lib\site-packages
import site
"@ | Set-Content -Path $PthFile -Encoding ascii

$PythonExe = Join-Path $PythonDir "python.exe"
if (-not (Test-Path $PythonExe)) {
    throw "Embeddable python.exe not found at $PythonExe"
}

Write-Host "Installing pip into portable runtime"
& $PythonExe $GetPipScript --no-warn-script-location

$PipExe = Join-Path $PythonDir "Scripts\pip.exe"
if (-not (Test-Path $PipExe)) {
    throw "pip installation failed; Scripts\pip.exe is missing."
}

Write-Host "Installing Python dependencies (this may take several minutes)"
& $PipExe install --no-warn-script-location -r $Requirements

& (Join-Path $PSScriptRoot "prune-backend-runtime.ps1") -PythonDir $PythonDir

foreach ($file in $BackendFiles) {
    Copy-Item (Join-Path $Root $file) (Join-Path $RuntimeDir $file)
}

$LocalLlmDir = Join-Path $Root "local_llm"
if (Test-Path $LocalLlmDir) {
    Copy-Item -Path $LocalLlmDir -Destination (Join-Path $RuntimeDir "local_llm") -Recurse -Force
}

Write-Host "Verifying portable runtime"
$VerifyScriptPath = Join-Path $RuntimeDir "_verify_runtime.py"
@'
import sys
from pathlib import Path

exe = Path(sys.executable)
root = exe.parent
assert exe.name.lower() in {"python.exe", "pythonw.exe"}
embed_zip = root / ("python" + "".join(map(str, sys.version_info[:2])) + ".zip")
assert embed_zip.exists(), f"embed zip missing: {embed_zip}"
import fastapi
import uvicorn
import fastembed
import local_llm
print("OK", sys.executable)
'@ | Set-Content -Path $VerifyScriptPath -Encoding utf8

$verifyOutput = & $PythonExe $VerifyScriptPath 2>&1
$verifyExitCode = $LASTEXITCODE
Remove-Item -Force $VerifyScriptPath -ErrorAction SilentlyContinue
if ($verifyExitCode -ne 0) {
    throw "Portable Python verification failed: $verifyOutput"
}

if (Test-Path (Join-Path $PythonDir "pyvenv.cfg")) {
    throw "Unexpected pyvenv.cfg found. Runtime must not be a linked venv."
}

Write-Host $verifyOutput
Write-Host "Backend runtime ready."
Write-Host "  Python: $PythonExe"
