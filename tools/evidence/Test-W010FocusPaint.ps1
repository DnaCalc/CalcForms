[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$directory = Join-Path $root 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.81'
$data = Get-Content -LiteralPath (Join-Path $directory 'comparison.json') -Raw | ConvertFrom-Json
if ($data.schema -cne 'calcforms.focus_paint.v1' -or $data.pixel_parity_claimed) { throw 'Invalid focus evidence.' }
if (@($data.observations).Count -ne 2) { throw 'Expected before/after focus observations.' }
foreach ($stage in @('before', 'after')) {
    $rows = @($data.observations | Where-Object stage -CEQ $stage)
    if ($rows.Count -ne 1) { throw 'Missing focus stage.' }
    $row = $rows[0]
    if ($row.zoom -ne 100 -or ($row.excel_geometry.client_size -join ',') -cne '384,174' -or
        ($row.runtime_geometry.client_size -join ',') -cne '384,174') { throw 'Client geometry differs.' }
    if ($row.ownership.excel_launches -ne 1 -or $row.ownership.excel_launches_by_this_session -ne 0 -or
        $row.ownership.closed -cne 'retained_by_original_session' -or @($row.ownership.cleanup_notes).Count -ne 0) { throw 'Owned session cleanup differs.' }
    $expected = if ($stage -ceq 'after') {
        'Initialize|Check:True|Click:HELLO, ADA;text=Ada;caption=HELLO, ADA;loud=True'
    } else {
        'Initialize|Change:Adaj|Click:Hello, Adaj|Check:True|Click:HELLO, ADAJ;text=Adaj;caption=HELLO, ADAJ;loud=True'
    }
    if ($row.state -cne $expected) { throw 'Original-handler state differs.' }
    if (@($row.images).Count -ne 2) { throw 'Expected two engine images.' }
    foreach ($engine in @('excel', 'calcforms')) {
        $images = @($row.images | Where-Object file -CEQ "$stage-$engine.png")
        if ($images.Count -ne 1 -or (Get-FileHash -LiteralPath (Join-Path $directory $images[0].file) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $images[0].sha256) { throw 'Focus reference image differs.' }
    }
}
Write-Host 'Focus references: before/after images and equal native/runtime original-handler states verified; no whole-image score across different text.'
