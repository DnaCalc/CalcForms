[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
& python -B -m unittest discover -s (Join-Path $root 'tools/office-oracle') -p test_layout_measurements.py
if ($LASTEXITCODE -ne 0) { throw 'Layout comparator unit tests failed.' }
& python -B (Join-Path $root 'tools/office-oracle/validate_layout_reference.py')
if ($LASTEXITCODE -ne 0) { throw 'Intrinsic layout references failed.' }
