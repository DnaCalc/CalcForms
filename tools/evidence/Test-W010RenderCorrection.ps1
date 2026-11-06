[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
& python -B (Join-Path $repoRoot 'tools/office-oracle/build_render_reference.py') --check (Join-Path $repoRoot 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.116/before/comparison.json')
if ($LASTEXITCODE -ne 0) { throw 'Independent caption qualification did not replay against the old runtime.' }
& python -B (Join-Path $repoRoot 'tools/office-oracle/build_render_reference.py') --check (Join-Path $repoRoot 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.114/final/comparison.json')
if ($LASTEXITCODE -ne 0) { throw 'Measured rendering corrections did not replay.' }
& python -B -m unittest discover -s (Join-Path $repoRoot 'tools/office-oracle') -p 'test_tab_text_cells.py'
if ($LASTEXITCODE -ne 0) { throw 'Native tab caption qualification tests failed.' }
Write-Host 'Frame gap, tab geometry and independent caption cells verified; no full font or pixel parity claim.'
