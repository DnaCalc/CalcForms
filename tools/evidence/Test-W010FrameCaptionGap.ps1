[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
& python -B (Join-Path $root 'tools/office-oracle/validate_frame_gap_reference.py')
if ($LASTEXITCODE -ne 0) { throw 'Native Frame caption-gap replay failed.' }
Push-Location (Join-Path $root 'tools/office-oracle')
try {
    & python -B -m unittest test_frame_caption_gap
    if ($LASTEXITCODE -ne 0) { throw 'Frame caption-gap negative tests failed.' }
} finally {
    Pop-Location
}
