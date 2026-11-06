[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
& python -B (Join-Path $root 'tools/office-oracle/validate_tab_reference.py')
if ($LASTEXITCODE -ne 0) { throw 'Qualified native tab header replay failed.' }
Push-Location (Join-Path $root 'tools/office-oracle')
try {
    & python -B -m unittest test_tab_paint
    if ($LASTEXITCODE -ne 0) { throw 'Tab drawing qualification negative tests failed.' }
} finally {
    Pop-Location
}
