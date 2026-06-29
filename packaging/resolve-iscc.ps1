# Returns the full path to Inno Setup's ISCC.exe, or $null if not installed.
$Candidates = @(
    (Get-Command iscc -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source),
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
    "${env:LocalAppData}\Programs\Inno Setup 6\ISCC.exe"
)

foreach ($path in $Candidates) {
    if ($path -and (Test-Path $path)) {
        return $path
    }
}

return $null
