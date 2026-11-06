[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
foreach ($script in @('inventory_reference.py', 'greeter_input_reference.py', 'validate_run8_cleanup.py')) {
    & python -B (Join-Path $repoRoot "tools/office-oracle/$script")
    if ($LASTEXITCODE -ne 0) { throw "Run 8 workbook evidence failed: $script" }
}
