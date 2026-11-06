[CmdletBinding()]
<#
.SYNOPSIS
    Run the headless OxForms evidence validators in one pass.

.DESCRIPTION
    Aggregates the environment-independent evidence checks (no live Excel/Office
    required) so drift in committed evidence cannot sit unnoticed:

      - office-oracle scaffold and the W003 oracle comparison manifest;
      - the trace/replay schema validator over every committed trace sample;
      - the W005 interaction comparison manifest;
      - the W010 committed FM20/referenced-typelib fact pack and W005
        structural reconciliation (without requiring live Office inputs);
      - the W010 committed MS-OFORMS persistence/default fact pack (without
        requiring the sibling Foundation source checkout);
      - the W010 committed real Office FRM/FRX export fact pack, strict text
        and CFB parsers, and local fixture/hash checks (without requiring the
        sibling Foundation source checkout);
      - the W010 complete MSForms row-level parity ledger, pinned-input
        regeneration, adversarial mutation tests, and committed canonical bytes;
      - the W010 manifest-driven live MSForms member-oracle capture, including
        environment-independent generator/result/event/artifact replay;
      - every committed checksums.sha256 manifest (git-tracked coverage).

    Per-capture Office evidence validators (Test-W006*CaptureEvidence.ps1, etc.)
    take a specific -CaptureDir and are run by their owning capture beads; they
    are intentionally out of scope here.

    Exits non-zero if any check fails.
#>
param(
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

$results = [System.Collections.Generic.List[object]]::new()

function Invoke-Check {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Script,
        [hashtable]$Params = @{}
    )

    $scriptPath = Join-Path $repoRoot $Script
    $ok = $true
    $detail = ''
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        $ok = $false
        $detail = "missing script: $Script"
    } else {
        # These validators signal failure by throwing under $ErrorActionPreference
        # = 'Stop'; some also `exit N`. Treat no-throw + zero exit as success and
        # capture every stream so the child's own output stays out of the summary.
        $global:LASTEXITCODE = 0
        try {
            $output = & $scriptPath @Params *>&1
            if ($LASTEXITCODE -ne 0) {
                $ok = $false
                $detail = (@($output) | Select-Object -Last 1 | ForEach-Object { "$_" }) -join ' '
                if ([string]::IsNullOrWhiteSpace($detail)) { $detail = "exit code $LASTEXITCODE" }
            }
        } catch {
            $ok = $false
            $detail = $_.Exception.Message
        }
    }

    $results.Add([pscustomobject]@{ Name = $Name; Ok = $ok; Detail = $detail })
    if (-not $Quiet) {
        $status = if ($ok) { 'ok  ' } else { 'FAIL' }
        Write-Host "  [$status] $Name"
        if (-not $ok -and $detail) {
            Write-Host "         $detail"
        }
    }
}

# Structural / manifest checks.
Invoke-Check -Name 'office-oracle scaffold' -Script 'tools/office-oracle/Test-OfficeOracleScaffold.ps1'
Invoke-Check -Name 'W003 oracle comparison manifest' -Script 'tools/office-oracle/Test-OracleComparisonManifest.ps1'
Invoke-Check -Name 'W005 interaction comparison manifest' -Script 'tools/evidence/Test-W005InteractionComparison.ps1'
Invoke-Check -Name 'W010 FM20 typelib fact pack' -Script 'tools/evidence/Test-W010FM20TypeLibFacts.ps1'
Invoke-Check -Name 'W010 MS-OFORMS persistence fact pack' -Script 'tools/evidence/Test-W010MSOFormsFacts.ps1'
Invoke-Check -Name 'W010 FRM/FRX export fact pack' -Script 'tools/evidence/Test-W010FrmFrxExportFacts.ps1'
Invoke-Check -Name 'W010 MSForms parity ledger' -Script 'tools/evidence/Test-W010MSFormsParityLedger.ps1'
Invoke-Check -Name 'W010 MSForms member oracle' -Script 'tools/evidence/Test-W010MSFormsMemberOracle.ps1'
Invoke-Check -Name 'W010 MSForms facade contract' -Script 'tools/evidence/Test-W010MSFormsFacadeContract.ps1'
Invoke-Check -Name 'W010 workbook Windows comparison' -Script 'tools/evidence/Test-W010WorkbookComparison.ps1'
Invoke-Check -Name 'W010 real data-entry workbook' -Script 'tools/evidence/Test-W010DataEntry.ps1'
Invoke-Check -Name 'W010 greeter paint comparison' -Script 'tools/evidence/Test-W010GreeterPaint.ps1'
Invoke-Check -Name 'W010 intrinsic layout comparison' -Script 'tools/evidence/Test-W010IntrinsicLayout.ps1'
Invoke-Check -Name 'W010 focus paint comparison' -Script 'tools/evidence/Test-W010FocusPaint.ps1'
Invoke-Check -Name 'W010 TextBox layout comparison' -Script 'tools/evidence/Test-W010TextBoxLayout.ps1'
Invoke-Check -Name 'W010 native capture qualification' -Script 'tools/evidence/Test-W010CaptureQualification.ps1'
Invoke-Check -Name 'W010 Frame layout comparison' -Script 'tools/evidence/Test-W010FrameLayout.ps1'
Invoke-Check -Name 'W010 ListBox row comparison' -Script 'tools/evidence/Test-W010ListRows.ps1'
Invoke-Check -Name 'W010 TabStrip caption comparison' -Script 'tools/evidence/Test-W010TabCaptions.ps1'
Invoke-Check -Name 'W010 Boolean/Page paint comparison' -Script 'tools/evidence/Test-W010BooleanPagePaint.ps1'
Invoke-Check -Name 'W010 native public drawing measurements' -Script 'tools/evidence/Test-W010NativeDrawing.ps1'
Invoke-Check -Name 'W010 behaviour and native accessibility measurements' -Script 'tools/evidence/Test-W010BehaviourMeasurements.ps1'
Invoke-Check -Name 'W010 keyboard and overflow measurements' -Script 'tools/evidence/Test-W010KeyboardMeasurements.ps1'
Invoke-Check -Name 'W010 measured setter and Enter behaviour' -Script 'tools/evidence/Test-W010SetterBehaviour.ps1'
Invoke-Check -Name 'W010 qualified tab header paint sizes' -Script 'tools/evidence/Test-W010TabPaintSizes.ps1'
Invoke-Check -Name 'W010 Frame caption border gap' -Script 'tools/evidence/Test-W010FrameCaptionGap.ps1'
Invoke-Check -Name 'W010 measured input corrections' -Script 'tools/evidence/Test-W010InputCorrection.ps1'
Invoke-Check -Name 'W010 real workbook input and owned cleanup' -Script 'tools/evidence/Test-W010Run8Workbooks.ps1'
Invoke-Check -Name 'W010 measured rendering corrections' -Script 'tools/evidence/Test-W010RenderCorrection.ps1'

# Trace/replay schema over every committed trace sample.
$traceSamples = @(
    'docs/evidence/W005_input_interaction_model_exploration/trace-replay/synthetic-click-trace.v1.json',
    'docs/evidence/W005_input_interaction_model_exploration/trace-replay/reducer-skeleton-transition-log.v1.json',
    'docs/evidence/W005_input_interaction_model_exploration/trace-replay/w005-headless-probe-replay.golden.v1.json',
    'docs/evidence/W006_control_implementation_rollout/trace-replay/modal-frame-subset.synthetic.v1.json'
)
foreach ($trace in $traceSamples) {
    Invoke-Check -Name "trace schema: $(Split-Path -Leaf $trace)" -Script 'tools/trace-replay/Test-TraceReplaySchema.ps1' -Params @{ TracePath = $trace }
}

# Every committed checksum manifest. Discover through the index so retained
# untracked failed-capture staging directories remain diagnostics rather than
# impersonating committed evidence roots.
$trackedChecksumPaths = @(git -C $repoRoot ls-files -- 'docs/evidence/**/checksums.sha256')
if ($LASTEXITCODE -ne 0) {
    throw 'git ls-files failed while discovering committed checksum manifests.'
}
$checksumDirs = @(
    $trackedChecksumPaths |
        ForEach-Object {
            Split-Path -Parent ([System.IO.Path]::GetFullPath((Join-Path $repoRoot $_)))
        } |
        Sort-Object
)
foreach ($dir in $checksumDirs) {
    $label = $dir.Substring($repoRoot.Length).TrimStart('\', '/').Replace('\', '/')
    Invoke-Check -Name "checksums: $label" -Script 'tools/evidence/Test-ChecksumManifest.ps1' -Params @{ Directory = $dir; GitTrackedOnly = $true }
}

$failed = @($results | Where-Object { -not $_.Ok })
$total = $results.Count
Write-Host ''
Write-Host "Evidence checks: $($total - $failed.Count)/$total passed."
if ($failed.Count -gt 0) {
    Write-Host "Failed: $(($failed | ForEach-Object { $_.Name }) -join '; ')"
    exit 1
}
exit 0
