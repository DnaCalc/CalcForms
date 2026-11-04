[CmdletBinding()]
param(
    [string]$LedgerPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$validator = Join-Path $repoRoot 'tools\msforms-parity\validate_parity_ledger.py'
$exporter = Join-Path $repoRoot 'tools\msforms-parity\export_parity_ledger.py'
$tests = Join-Path $repoRoot 'tools\msforms-parity\tests'
$checksumValidator = Join-Path $repoRoot 'tools\evidence\Test-ChecksumManifest.ps1'
$evidenceDirectory = Join-Path $repoRoot 'docs\evidence\W010_complete_msforms_object_model_parity\beads\oxforms-jbjp.73'
$python = Get-Command python -ErrorAction Stop
$oldBytecode = $env:PYTHONDONTWRITEBYTECODE
$env:PYTHONDONTWRITEBYTECODE = '1'
try {
    & $python.Source -B -m unittest discover -s $tests -p 'test_*.py'
    if ($LASTEXITCODE -ne 0) {
        throw "MSForms parity-ledger unit tests failed with exit code $LASTEXITCODE."
    }

    # The validator always checks the reviewed committed artifact first.
    # LedgerPath is deliberately only an additional copy to validate.
    $arguments = @('-B', $validator)
    if ($LedgerPath) { $arguments += @('--additional-ledger', $LedgerPath) }
    & $python.Source @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "MSForms committed parity-ledger validation failed with exit code $LASTEXITCODE."
    }

    & $python.Source -B $exporter --check
    if ($LASTEXITCODE -ne 0) {
        throw "MSForms deterministic parity-ledger export check failed with exit code $LASTEXITCODE."
    }

    & $checksumValidator -Directory $evidenceDirectory
} finally {
    $env:PYTHONDONTWRITEBYTECODE = $oldBytecode
}

Write-Host 'W010 MSForms parity ledger: ok'
