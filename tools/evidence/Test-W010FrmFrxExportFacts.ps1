[CmdletBinding()]
param(
    [string]$FactsPath,
    [switch]$RequireSource
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$validator = Join-Path $repoRoot 'tools\forms-persistence\validate_frm_frx_facts.py'
$exporter = Join-Path $repoRoot 'tools\forms-persistence\export_frm_frx_facts.py'
$cfbSourcePin = Join-Path $repoRoot 'tools\forms-persistence\extract_ms_cfb_selected_rows.py'
$tests = Join-Path $repoRoot 'tools\forms-persistence\tests'

$python = Get-Command python -ErrorAction Stop
$oldBytecode = $env:PYTHONDONTWRITEBYTECODE
$oldRequireSources = $env:OXFORMS_REQUIRE_PERSISTENCE_SOURCES
$env:PYTHONDONTWRITEBYTECODE = '1'
if ($RequireSource) {
    $env:OXFORMS_REQUIRE_PERSISTENCE_SOURCES = '1'
} else {
    Remove-Item Env:OXFORMS_REQUIRE_PERSISTENCE_SOURCES -ErrorAction SilentlyContinue
}
try {
    & $python.Source -B $cfbSourcePin
    if ($LASTEXITCODE -ne 0) {
        throw "MS-CFB authoritative source-pin validation failed with exit code $LASTEXITCODE."
    }

    & $python.Source -B -m unittest discover -s $tests -p 'test_*.py'
    if ($LASTEXITCODE -ne 0) {
        throw "FRM/FRX fact-tool unit tests failed with exit code $LASTEXITCODE."
    }

    $arguments = @('-B', $validator)
    if ($FactsPath) { $arguments += @('--facts', $FactsPath) }
    if ($RequireSource) { $arguments += '--require-sources' }
    & $python.Source @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "FRM/FRX committed-artifact validation failed with exit code $LASTEXITCODE."
    }

    if ($RequireSource) {
        $exportArguments = @('-B', $exporter, '--check')
        if ($FactsPath) { $exportArguments += @('--output', $FactsPath) }
        & $python.Source @exportArguments
        if ($LASTEXITCODE -ne 0) {
            throw "FRM/FRX deterministic source regeneration failed with exit code $LASTEXITCODE."
        }
    }
} finally {
    $env:PYTHONDONTWRITEBYTECODE = $oldBytecode
    if ($null -eq $oldRequireSources) {
        Remove-Item Env:OXFORMS_REQUIRE_PERSISTENCE_SOURCES -ErrorAction SilentlyContinue
    } else {
        $env:OXFORMS_REQUIRE_PERSISTENCE_SOURCES = $oldRequireSources
    }
}

Write-Host 'W010 FRM/FRX export facts: ok'
