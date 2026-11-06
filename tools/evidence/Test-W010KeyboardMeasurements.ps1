[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
& python -B (Join-Path $root 'tools/office-oracle/validate_keyboard_reference.py')
if ($LASTEXITCODE -ne 0) { throw 'Native/runtime keyboard and overflow replay failed.' }
Push-Location (Join-Path $root 'tools/office-oracle')
try {
    & python -B -m unittest test_keyboard_probes
    if ($LASTEXITCODE -ne 0) { throw 'Keyboard/scroll negative tests failed.' }
} finally {
    Pop-Location
}
