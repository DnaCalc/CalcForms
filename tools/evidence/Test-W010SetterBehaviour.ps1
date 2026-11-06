[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
& python -B (Join-Path $root 'tools/office-oracle/validate_setter_reference.py')
if ($LASTEXITCODE -ne 0) { throw 'Corrected setter/Enter native replay failed.' }
