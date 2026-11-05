[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
& python -B -m unittest discover -s (Join-Path $root 'tools/office-oracle') -p test_layout_measurements.py
if ($LASTEXITCODE -ne 0) { throw 'Layout comparator unit tests failed.' }
& python -B -m unittest discover -s (Join-Path $root 'tools/office-oracle') -p test_forms_parity.py
if ($LASTEXITCODE -ne 0) { throw 'Forms parity unit tests failed.' }
& python -B (Join-Path $root 'tools/office-oracle/validate_layout_reference.py')
if ($LASTEXITCODE -ne 0) { throw 'Intrinsic layout references failed.' }
& python -B (Join-Path $root 'tools/office-oracle/layout_pixels.py') --reference (Join-Path $root 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.79/comparison.json') --check (Join-Path $root 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.86/control-ranking.json')
if ($LASTEXITCODE -ne 0) { throw 'Control pixel ranking replay failed.' }
& python -B (Join-Path $root 'tools/office-oracle/forms_parity.py') --reference (Join-Path $root 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.79/comparison.json') --check (Join-Path $root 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.96/forms-parity.json')
if ($LASTEXITCODE -ne 0) { throw 'Forms parity replay failed.' }
& python -B (Join-Path $root 'tools/office-oracle/combo_spacing.py')
if ($LASTEXITCODE -ne 0) { throw 'ComboBox spacing replay failed.' }
& python -B (Join-Path $root 'tools/office-oracle/literal_text_reference.py')
if ($LASTEXITCODE -ne 0) { throw 'Literal text replay failed.' }
