[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
& python -B (Join-Path $repoRoot 'tools/msforms-parity/facade_contract.py')
if ($LASTEXITCODE -ne 0) { throw 'Facade obligation regeneration check failed.' }
& python -B -m unittest discover -s (Join-Path $repoRoot 'tools/msforms-parity/facade_tests') -p 'test_*.py'
if ($LASTEXITCODE -ne 0) { throw 'Facade coverage/anti-promotion tests failed.' }
$parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $repoRoot 'tools/office-oracle/Capture-MSFormsFacadeProbe.ps1'),
    [ref]$null, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw "Facade capture syntax failed: $parseErrors" }
Write-Host 'Facade contract infrastructure verified; live callability and OxVba discrepancies remain open.'
