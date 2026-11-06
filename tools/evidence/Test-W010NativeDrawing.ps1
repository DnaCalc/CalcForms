[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
& python -B (Join-Path $root 'tools/office-oracle/validate_drawing_reference.py')
if ($LASTEXITCODE -ne 0) { throw 'Native drawing reference validation failed.' }
Push-Location (Join-Path $root 'tools/office-oracle')
try {
    & python -B -m unittest test_native_drawing
    if ($LASTEXITCODE -ne 0) { throw 'Native drawing negative tests failed.' }
} finally {
    Pop-Location
}
