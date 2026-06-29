# Copies latest Python backend sources into backend-runtime (and optional install dir).
param(
    [string]$RuntimeDir = (Join-Path $PSScriptRoot "backend-runtime"),
    [string]$InstallBackendDir = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

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

if (-not (Test-Path $RuntimeDir)) {
    throw "Backend runtime not found at $RuntimeDir. Run setup-backend-runtime.ps1 first."
}

Write-Host "Syncing backend Python sources to $RuntimeDir"
foreach ($file in $BackendFiles) {
    Copy-Item (Join-Path $Root $file) (Join-Path $RuntimeDir $file) -Force
}

$LocalLlmDir = Join-Path $Root "local_llm"
if (Test-Path $LocalLlmDir) {
    Copy-Item -Path $LocalLlmDir -Destination (Join-Path $RuntimeDir "local_llm") -Recurse -Force
}

if ($InstallBackendDir -and (Test-Path $InstallBackendDir)) {
    Write-Host "Syncing backend Python sources to $InstallBackendDir"
    foreach ($file in $BackendFiles) {
        Copy-Item (Join-Path $Root $file) (Join-Path $InstallBackendDir $file) -Force
    }
    if (Test-Path $LocalLlmDir) {
        Copy-Item -Path $LocalLlmDir -Destination (Join-Path $InstallBackendDir "local_llm") -Recurse -Force
    }
}
