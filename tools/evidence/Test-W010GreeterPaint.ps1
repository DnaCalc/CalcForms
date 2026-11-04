[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$directory = Join-Path $root 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.76'
$data = Get-Content -LiteralPath (Join-Path $directory 'comparison.json') -Raw | ConvertFrom-Json
if ($data.schema -cne 'calcforms.greeter_paint.v1' -or $data.excel_launches -ne 1) { throw 'Invalid paint session.' }
if (@($data.observations).Count -ne 4) { throw 'Expected before/after at two scales.' }
foreach ($zoom in @(100, 150)) {
    $rows = @($data.observations | Where-Object zoom -EQ $zoom)
    if ($rows.Count -ne 2) { throw "Missing scale $zoom." }
    $before = @($rows | Where-Object stage -EQ 'before')
    $after = @($rows | Where-Object stage -EQ 'paint')
    if ($before.Count -ne 1 -or $after.Count -ne 1 -or
        $after[0].pixels.different_fraction -ge $before[0].pixels.different_fraction) { throw 'Paint correction did not improve the comparison.' }
    foreach ($row in $rows) {
        $imageNames = @($row.images.file | Sort-Object)
        $expectedNames = @("$($row.stage)-$zoom-calcforms.png", "$($row.stage)-$zoom-excel.png")
        if (($imageNames -join ',') -cne ($expectedNames -join ',')) { throw 'Expected both engine images for every row.' }
        if ($row.excel_state -cne $row.calcforms_state -or $row.excel_state -cne 'Initialize;text=Ada;caption=(ready);loud=False') { throw 'Initial original-handler state differs.' }
        if (($row.geometry.excel.client_size -join ',') -cne ($row.geometry.calcforms.client_size -join ',')) { throw 'Client size mismatch.' }
        $expectedSize = if ($zoom -eq 100) { '384,174' } else { '576,261' }
        if (($row.geometry.excel.client_size -join ',') -cne $expectedSize) { throw 'Unexpected client dimensions.' }
        if ($row.excel_facts -notlike '*Prompt;12;12;96;18;Tahoma;8.25;0*') { throw 'Native geometry/font facts differ.' }
        foreach ($artifact in $row.images) {
            if ($artifact.file -notmatch '^(before|paint)-(100|150)-(excel|calcforms)\.png$') { throw 'Unsafe image path.' }
            if ((Get-FileHash -LiteralPath (Join-Path $directory $artifact.file) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $artifact.sha256) { throw 'Paint image hash differs.' }
        }
    }
}
Write-Host 'Greeter paint: equal original-handler state and client sizes at two scales; lower pixel errors; eight compact references verified.'
