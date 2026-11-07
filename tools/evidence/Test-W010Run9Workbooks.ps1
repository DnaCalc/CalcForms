[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
foreach ($script in @('run9_workbook_reference.py','validate_helper_recovery.py','validate_order_entry_validation.py','greeter_lifecycle_reference.py','frame_mouse_reference.py','validate_run9_cleanup.py')) {
    & python -B (Join-Path $repo "tools/office-oracle/$script")
    if ($LASTEXITCODE -ne 0) { throw "Run 9 workbook/recovery evidence failed: $script" }
}
