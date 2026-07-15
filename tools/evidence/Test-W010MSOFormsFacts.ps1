[CmdletBinding()]
param(
    [string]$FactsPath,
    [switch]$RequireSource
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$validator = Join-Path $repoRoot 'tools\ms-oforms\validate_ms_oforms_facts.py'
$exporter = Join-Path $repoRoot 'tools\ms-oforms\export_ms_oforms_facts.py'
$tests = Join-Path $repoRoot 'tools\ms-oforms\tests'

$python = Get-Command python -ErrorAction Stop
$oldBytecode = $env:PYTHONDONTWRITEBYTECODE
$env:PYTHONDONTWRITEBYTECODE = '1'
try {
    & $python.Source -B -m unittest discover -s $tests -p 'test_*.py'
    if ($LASTEXITCODE -ne 0) {
        throw "MS-OFORMS fact-tool unit tests failed with exit code $LASTEXITCODE."
    }

    $arguments = @('-B', $validator)
    if ($FactsPath) { $arguments += @('--facts', $FactsPath) }
    if ($RequireSource) { $arguments += '--require-sources' }
    & $python.Source @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "MS-OFORMS committed-artifact validation failed with exit code $LASTEXITCODE."
    }

    if ($RequireSource) {
        $exportArguments = @('-B', $exporter, '--check')
        if ($FactsPath) { $exportArguments += @('--output', $FactsPath) }
        & $python.Source @exportArguments
        if ($LASTEXITCODE -ne 0) {
            throw "MS-OFORMS deterministic source regeneration failed with exit code $LASTEXITCODE."
        }
    }
} finally {
    $env:PYTHONDONTWRITEBYTECODE = $oldBytecode
}

Write-Host 'W010 MS-OFORMS persistence facts: ok'
