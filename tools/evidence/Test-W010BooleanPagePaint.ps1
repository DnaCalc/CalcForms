[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
& python -B (Join-Path $root 'tools/office-oracle/validate_boolean_page_paint.py')
if ($LASTEXITCODE -ne 0) { throw 'Boolean/Page paint reference validation failed.' }
