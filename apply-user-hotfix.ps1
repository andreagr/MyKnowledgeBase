# Copy fixed backend Python files into %LOCALAPPDATA%\MyKB\backend-overrides (no admin).
$ErrorActionPreference = "Stop"

$Root = $PSScriptRoot
$Overrides = Join-Path $env:LOCALAPPDATA "MyKB\backend-overrides"
$Runtime = Join-Path $env:LOCALAPPDATA "MyKB\backend-run"

New-Item -ItemType Directory -Path $Overrides -Force | Out-Null
New-Item -ItemType Directory -Path $Runtime -Force | Out-Null

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

foreach ($file in $BackendFiles) {
    $src = Join-Path $Root $file
    if (-not (Test-Path $src)) {
        throw "Missing source file: $src"
    }
    Copy-Item $src (Join-Path $Overrides $file) -Force
    Copy-Item $src (Join-Path $Runtime $file) -Force
    Write-Host "Patched $file"
}

$LocalLlmDir = Join-Path $Root "local_llm"
if (Test-Path $LocalLlmDir) {
    Copy-Item -Path $LocalLlmDir -Destination (Join-Path $Runtime "local_llm") -Recurse -Force
}

Write-Host ""
Write-Host "Hotfix applied to user profile. Close MyKB completely, then reopen it."
Write-Host "If you still see upload errors, run a fresh build (.\build-release.ps1 -Fast) and use the new mykb.exe."
