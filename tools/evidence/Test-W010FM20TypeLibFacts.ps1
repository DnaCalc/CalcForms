[CmdletBinding()]
param(
    [string]$FactsPath,
    [string]$ComparisonPath,
    [switch]$RequireSource
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$validator = Join-Path $repoRoot 'tools\fm20\validate_typelib_facts.py'
$exporter = Join-Path $repoRoot 'tools\fm20\export_typelib_facts.py'

$python = Get-Command python -ErrorAction Stop
& $python.Source -m unittest discover -s (Join-Path $repoRoot 'tools\fm20\tests') -p 'test_*.py'
if ($LASTEXITCODE -ne 0) {
    throw "FM20 fact-tool unit tests failed with exit code $LASTEXITCODE."
}

$arguments = @($validator)
if ($FactsPath) { $arguments += @('--facts', $FactsPath) }
if ($ComparisonPath) { $arguments += @('--comparison', $ComparisonPath) }
if ($RequireSource) { $arguments += '--require-sources' }

& $python.Source @arguments
if ($LASTEXITCODE -ne 0) {
    throw "FM20 committed-artifact validation failed with exit code $LASTEXITCODE."
}

if ($RequireSource) {
    $exportArguments = @($exporter, '--check')
    if ($FactsPath) { $exportArguments += @('--output', $FactsPath) }
    if ($ComparisonPath) { $exportArguments += @('--comparison', $ComparisonPath) }
    & $python.Source @exportArguments
    if ($LASTEXITCODE -ne 0) {
        throw "FM20 live deterministic regeneration failed with exit code $LASTEXITCODE."
    }
}

Write-Host 'W010 FM20 typelib facts: ok'
