[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
& python -B (Join-Path $repoRoot 'tools/office-oracle/build_input_correction.py') --check
if ($LASTEXITCODE -ne 0) { throw 'ListBox viewport and native initial focus evidence failed.' }
