$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
& python -B (Join-Path $repoRoot 'tools/office-oracle/validate_data_entry.py')
if ($LASTEXITCODE -ne 0) { throw 'Data-entry fixture validation failed' }
& python -B (Join-Path $repoRoot 'tools/office-oracle/validate_order_entry_scenarios.py')
if ($LASTEXITCODE -ne 0) { throw 'Original data-entry native scenario validation failed' }
