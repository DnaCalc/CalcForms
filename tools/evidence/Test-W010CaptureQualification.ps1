[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
foreach ($pattern in @('test_desktop_lease.py', 'test_probe_source.py', 'test_capture_qualification.py')) {
    & python -B -m unittest discover -s (Join-Path $root 'tools/office-oracle') -p $pattern
    if ($LASTEXITCODE -ne 0) { throw "Capture helper tests failed: $pattern" }
}
& python -B (Join-Path $root 'tools/office-oracle/validate_capture_qualification_reference.py')
if ($LASTEXITCODE -ne 0) { throw 'Native capture qualification references failed.' }
& python -B (Join-Path $root 'tools/office-oracle/validate_frame_capture_reference.py')
if ($LASTEXITCODE -ne 0) { throw 'Native Frame capture qualification references failed.' }
