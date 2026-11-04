[CmdletBinding()]
param(
    [string]$Comparison = 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.74/windows-session-20261104b/comparison-1/comparison.json'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$path = Join-Path $repoRoot $Comparison
$data = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
if ($data.schema -ne 'calcforms.workbook_windows_comparison.v1' -or $data.runtime -ne 'CalcVBA VM3') {
    throw 'Unexpected workbook comparison/runtime identity.'
}
if ($data.switched_input_desktop -ne $false -or $data.security_changes -ne 0 -or $data.desktop -notlike 'CalcFormsOracle_*') {
    throw 'Capture must use the private desktop without security changes or an input desktop switch.'
}
$fixture = Join-Path $repoRoot 'fixtures/workbooks/greeter/workbook-greeter.xlsm'
$stream = [System.IO.FileStream]::new($fixture, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
$sha = [System.Security.Cryptography.SHA256]::Create()
try { $fixtureHash = [Convert]::ToHexString($sha.ComputeHash($stream)).ToLowerInvariant() }
finally { $stream.Dispose(); $sha.Dispose() }
if ($fixtureHash -ne $data.workbook_sha256) {
    throw 'Workbook fixture differs from the observed input.'
}
$expected = @('initial', 'greet', 'text', 'greet-lin', 'check', 'greet-uppercase')
if (@($data.observations).Count -ne $expected.Count) { throw 'Expected all six states.' }
for ($index = 0; $index -lt $expected.Count; $index++) {
    $row = $data.observations[$index]
    if ($row.action -ne $expected[$index] -or $row.equal -ne $true -or $row.excel -cne $row.calcforms) {
        throw "Handler/state mismatch at row $index."
    }
    foreach ($side in @('excel_window', 'calcforms_window')) {
        $artifact = $row.$side
        if ($artifact.file -notmatch '^[a-z-]+\.png$' -or $artifact.distinct_colors -lt 10 -or $artifact.size[0] -lt 100 -or $artifact.size[1] -lt 100) {
            throw "Invalid or blank image at row $index, $side."
        }
        $image = Join-Path (Split-Path -Parent $path) $artifact.file
        if ((Get-FileHash -LiteralPath $image -Algorithm SHA256).Hash.ToLowerInvariant() -ne $artifact.sha256) {
            throw "Image hash differs at row $index, $side."
        }
    }
}
if ($data.observations[-1].calcforms -notlike '*caption=HELLO, LIN;loud=True') { throw 'Final handler result is missing.' }
Write-Host 'Workbook Windows comparison: six equal states, twelve captured images, unchanged input; pixel parity is not claimed.'
