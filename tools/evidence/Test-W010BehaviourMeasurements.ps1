[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
& python -B (Join-Path $root 'tools/office-oracle/validate_behaviour_reference.py')
if ($LASTEXITCODE -ne 0) { throw 'Native/runtime behaviour measurement replay failed.' }
Push-Location (Join-Path $root 'tools/office-oracle')
try {
    & python -B -m unittest test_behaviour_probes test_forms_parity
    if ($LASTEXITCODE -ne 0) { throw 'Behaviour measurement negative tests failed.' }
} finally {
    Pop-Location
}
