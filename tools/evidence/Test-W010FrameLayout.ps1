[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
& python -B (Join-Path $root 'tools/office-oracle/validate_frame_reference.py')
if ($LASTEXITCODE -ne 0) { throw 'Frame layout reference validation failed.' }
