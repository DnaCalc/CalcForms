[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$GenerateOnly,
    [switch]$SkipKeyboardProbe,
    [int]$ActionDelayMilliseconds = 220
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Thin sequential wrapper that runs the keyboard pre-flight probe and then each
# office-oracle capture in a FRESH separate pwsh process (separate processes
# avoid COM / Add-Type namespace leakage between captures).
#
# - FIRST (unless -DryRun / -GenerateOnly / -SkipKeyboardProbe) it runs
#   Test-KeyboardSendInputReachable.ps1. If that probe fails, the whole batch is
#   ABORTED before any keyboard-dependent capture runs, with the clear message.
# - It CONTINUES past a capture that exits non-zero or self-blocks; each capture
#   writes its own blocker.json, and an honest blocker is a batch SUCCESS.
# - It exits non-zero only if a capture threw OUTSIDE its own blocker path (a
#   real harness bug: no manifest AND no blocker AND non-zero exit), or if the
#   keyboard probe aborts the batch.
#
# Clean-room: orchestration + status aggregation only; it makes no MSForms claim
# and treats a missing row / missing artifact as unobserved, never as a negative
# fact.
# ---------------------------------------------------------------------------

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$oracleToolDir = Join-Path $repoRoot 'tools\office-oracle'
$w006Root = Join-Path $repoRoot 'docs\evidence\W006_control_implementation_rollout\captures'
$w008Root = Join-Path $repoRoot 'docs\evidence\W008_native_event_breadth\captures'
$captureRoot = $w006Root  # batch-summary location

# Ordered list of capture scripts to run (fresh process each). 'root' is the
# captures dir the script writes under (W006 vs the new W008 subtree); 'dir_prefix'
# is the actual capture-id leaf prefix the script's Resolve-CaptureDir produces, so
# the runner can locate the newest dir each script created and read its status.
#
# Capture-W006HeldRefResiduals.ps1 is DEFERRED from the default batch: its two-form
# fixture generation hangs headless Excel during VBIDE generation (reproduced under
# -GenerateOnly, both alone and in-batch), so it would stall the live run. It needs
# dedicated live debugging; its event orderings are already captured by
# oxforms-0a0.24 (nested-modal-lifecycle) and only the held-reference state
# dimension is outstanding. Re-add the entry once the generation hang is fixed.
$captureScripts = @(
    [ordered]@{ name = 'Capture-W008FocusValidation.ps1';        root = $w008Root; dir_prefix = 'w008-focus-validation' }
    [ordered]@{ name = 'Capture-W008KeyMutation.ps1';            root = $w008Root; dir_prefix = 'w008-key-mutation' }
    [ordered]@{ name = 'Capture-W006CtrlVKeyboardOrdering.ps1';  root = $w006Root; dir_prefix = 'ctrlv-keyboard-ordering' }
    [ordered]@{ name = 'Capture-W006CheckBoxKeyboardToggle.ps1'; root = $w006Root; dir_prefix = 'checkbox-keyboard-toggle' }
)

$pwshPath = (Get-Process -Id $PID).Path
if ([string]::IsNullOrWhiteSpace($pwshPath)) { $pwshPath = 'pwsh' }

$scratchRoot = $env:TEMP
if ([string]::IsNullOrWhiteSpace($scratchRoot)) { $scratchRoot = [System.IO.Path]::GetTempPath() }

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][string]$Path)
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try { return ([System.BitConverter]::ToString($sha256.ComputeHash($stream)) -replace '-', '').ToLowerInvariant() } finally { $sha256.Dispose() }
    } finally { $stream.Dispose() }
}

function Get-NewestCaptureDir {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Prefix,
        [datetime]$NewerThanUtc
    )
    # Find the newest directory under the capture's own root whose leaf name starts
    # with the capture's dir_prefix and that was created at/after this capture's
    # start. Returns $null when the capture created no directory (e.g. it threw
    # before Resolve-CaptureDir).
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return $null }
    $candidates = @(Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name.StartsWith($Prefix, [System.StringComparison]::OrdinalIgnoreCase) -and $_.LastWriteTimeUtc -ge $NewerThanUtc.AddSeconds(-2) } |
        Sort-Object LastWriteTimeUtc -Descending)
    if ($candidates.Count -eq 0) { return $null }
    return $candidates[0].FullName
}

function Get-CaptureStatus {
    param([string]$CaptureDir)
    # Reads manifest/blocker to classify a capture. Never infers behavior from a
    # missing row: a missing dir is 'no_output', a present blocker is 'blocked'
    # (an honest, expected outcome), a present manifest carries its own status.
    $result = [ordered]@{ status = 'no_output'; row_count = $null; manifest_schema = $null; blocker_reason = $null }
    if ([string]::IsNullOrWhiteSpace($CaptureDir) -or -not (Test-Path -LiteralPath $CaptureDir -PathType Container)) {
        return $result
    }

    $manifestPath = Join-Path $CaptureDir 'oracle-capture-manifest.json'
    $blockerPath = Join-Path $CaptureDir 'blocker.json'

    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        try {
            $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
            $result.manifest_schema = [string]$manifest.schema
            $result.status = if ($null -ne $manifest.status) { [string]$manifest.status } else { 'unknown' }
            # row_count appears under observed_coverage or observed_facts depending on the capture.
            if ($null -ne $manifest.PSObject.Properties['observed_coverage'] -and $null -ne $manifest.observed_coverage -and $null -ne $manifest.observed_coverage.PSObject.Properties['row_count']) {
                $result.row_count = [int]$manifest.observed_coverage.row_count
            } elseif ($null -ne $manifest.PSObject.Properties['observed_facts'] -and $null -ne $manifest.observed_facts -and $null -ne $manifest.observed_facts.PSObject.Properties['row_count']) {
                $result.row_count = [int]$manifest.observed_facts.row_count
            }
        } catch {
            $result.status = 'manifest_unreadable'
            $result.blocker_reason = $_.Exception.Message
        }
    }

    if (Test-Path -LiteralPath $blockerPath -PathType Leaf) {
        try {
            $blocker = Get-Content -Raw -LiteralPath $blockerPath | ConvertFrom-Json
            if ($result.status -in @('no_output', 'unknown')) { $result.status = 'blocked' }
            $result.blocker_reason = [string]$blocker.reason
        } catch {
            if ($result.status -eq 'no_output') { $result.status = 'blocked' }
        }
    }

    return $result
}

function Get-StrayExcelCount {
    return @(Get-Process EXCEL -ErrorAction SilentlyContinue).Count
}

# ---- keyboard pre-flight ----
$probePath = Join-Path $oracleToolDir 'Test-KeyboardSendInputReachable.ps1'
$probeOutcome = 'skipped'
if (-not ($DryRun -or $GenerateOnly -or $SkipKeyboardProbe)) {
    if (-not (Test-Path -LiteralPath $probePath -PathType Leaf)) {
        throw "Keyboard pre-flight probe not found: $probePath"
    }
    Write-Host '== Keyboard SendInput pre-flight probe =='
    $probeArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $probePath, '-ActionDelayMilliseconds', $ActionDelayMilliseconds)
    & $pwshPath @probeArgs
    $probeExit = $LASTEXITCODE
    if ($probeExit -ne 0) {
        Write-Host ''
        Write-Host 'ABORTING BATCH: keyboard pre-flight probe failed.'
        Write-Host 'interactive desktop is locked or input-incapable; SendInput injected 0 events / SetForegroundWindow=False - reconnect/unlock the console session and rerun'
        Write-Host 'No keyboard-dependent captures were run (they would falsely report "no rows" on a dead keyboard).'
        exit 1
    }
    $probeOutcome = 'passed'
    Write-Host 'Keyboard pre-flight probe passed; continuing with captures.'
    Write-Host ''
} else {
    Write-Host "Keyboard pre-flight probe skipped (DryRun=$DryRun GenerateOnly=$GenerateOnly SkipKeyboardProbe=$SkipKeyboardProbe)."
    Write-Host ''
}

# ---- run captures, fresh process each ----
$batchStartUtc = (Get-Date).ToUniversalTime()
$results = [System.Collections.Generic.List[object]]::new()
$harnessBug = $false

foreach ($capture in $captureScripts) {
    $scriptPath = Join-Path $oracleToolDir $capture.name
    Write-Host "== $($capture.name) =="

    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        Write-Host "  SKIPPED: capture script not found on disk: $scriptPath"
        $results.Add([ordered]@{
            name = $capture.name
            exit_code = $null
            capture_dir = $null
            status = 'script_missing'
            row_count = $null
            blocker_reason = 'Capture script not present on disk.'
        }) | Out-Null
        continue
    }

    $captureStartUtc = (Get-Date).ToUniversalTime()
    $childArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath)
    if ($DryRun) { $childArgs += '-DryRun' }
    if ($GenerateOnly) { $childArgs += '-GenerateOnly' }
    $childArgs += @('-ActionDelayMilliseconds', $ActionDelayMilliseconds)

    & $pwshPath @childArgs
    $exitCode = $LASTEXITCODE

    $captureDir = if ($DryRun -or $GenerateOnly) { $null } else { Get-NewestCaptureDir -Root $capture.root -Prefix $capture.dir_prefix -NewerThanUtc $captureStartUtc }
    $statusInfo = if ($DryRun -or $GenerateOnly) {
        [ordered]@{ status = $(if ($exitCode -eq 0) { 'dryrun_ok' } else { 'dryrun_failed' }); row_count = $null; manifest_schema = $null; blocker_reason = $null }
    } else {
        Get-CaptureStatus -CaptureDir $captureDir
    }

    # Harness-bug detector: non-zero exit AND no manifest AND no blocker means the
    # capture died outside its own honest blocker path.
    if (-not ($DryRun -or $GenerateOnly) -and $exitCode -ne 0 -and $statusInfo.status -in @('no_output', 'manifest_unreadable')) {
        $harnessBug = $true
        Write-Host "  HARNESS BUG: exit $exitCode with no manifest and no blocker.json (capture died outside its blocker path)."
    }

    $results.Add([ordered]@{
        name = $capture.name
        exit_code = $exitCode
        capture_dir = $(if ($null -ne $captureDir) { $captureDir.Replace([System.IO.Path]::DirectorySeparatorChar, '/') } else { $null })
        status = $statusInfo.status
        row_count = $statusInfo.row_count
        manifest_schema = $statusInfo.manifest_schema
        blocker_reason = $statusInfo.blocker_reason
    }) | Out-Null

    Write-Host "  exit=$exitCode status=$($statusInfo.status) rows=$($statusInfo.row_count) dir=$captureDir"

    # Warn (do NOT force-kill) if a stray EXCEL lingers between captures.
    $strayExcel = Get-StrayExcelCount
    if ($strayExcel -gt 0) {
        Write-Warning "A stray EXCEL process is still running after $($capture.name) (count=$strayExcel). Not force-killing; the next capture starts its own Excel instance."
    }
    Write-Host ''
}

# ---- summary table ----
Write-Host '== Oracle batch summary =='
$table = @($results | ForEach-Object {
    [pscustomobject]@{
        Capture = $_.name
        Exit = $_.exit_code
        Status = $_.status
        Rows = $_.row_count
    }
})
$table | Format-Table -AutoSize | Out-String | Write-Host

# ---- write summary json ----
$utc = $batchStartUtc.ToString('yyyyMMddTHHmmssZ')
$summary = [ordered]@{
    schema = 'oxforms.office_oracle.oracle_batch_summary.v1'
    generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    batch_started_utc = $batchStartUtc.ToString('o')
    mode = [ordered]@{ dry_run = [bool]$DryRun; generate_only = [bool]$GenerateOnly; skip_keyboard_probe = [bool]$SkipKeyboardProbe; action_delay_ms = $ActionDelayMilliseconds }
    keyboard_probe = $probeOutcome
    pwsh_path = $pwshPath
    capture_order = @($captureScripts | ForEach-Object { $_.name })
    results = @($results)
    harness_bug_detected = [bool]$harnessBug
    clean_room = [ordered]@{
        source = 'Orchestration only: a keyboard pre-flight probe plus fresh-process invocation of repo-owned capture scripts that each use public Excel/VBIDE/Windows automation.'
        prohibited = 'No Office internals, decompilation, disassembly, non-public source, or OxForms output comparison were used by the runner.'
    }
    non_claims = @(
        'A blocked or skipped capture is an honest, expected outcome and is not a negative MSForms fact.',
        'Absence of a row or artifact is unobserved, not a negative parity claim.',
        'No OxForms runtime behavior is implemented or claimed by this batch runner.'
    )
}

# Place the summary under docs/evidence when a real (non-dry) batch produced
# capture dirs, so it can be checksummed alongside them; otherwise drop it in
# the scratchpad.
$underEvidence = (-not ($DryRun -or $GenerateOnly)) -and (Test-Path -LiteralPath $captureRoot -PathType Container)
if ($underEvidence) {
    $batchDir = Join-Path $captureRoot ('oracle-batch-' + $utc)
    New-Item -ItemType Directory -Force -Path $batchDir | Out-Null
    $summaryPath = Join-Path $batchDir ('oracle-batch-summary-' + $utc + '.json')
} else {
    $batchDir = Join-Path $scratchRoot ('oxforms-oracle-batch-' + $utc)
    New-Item -ItemType Directory -Force -Path $batchDir | Out-Null
    $summaryPath = Join-Path $batchDir ('oracle-batch-summary-' + $utc + '.json')
}
$summary | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Host "Batch summary written: $summaryPath"

# Checksum the summary when it lives under docs/evidence (shared Write-Checksums shape).
if ($underEvidence) {
    $checksumPath = Join-Path $batchDir 'checksums.sha256'
    $sep = $batchDir.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $files = Get-ChildItem -LiteralPath $batchDir -Recurse -File | Where-Object { $_.FullName -ne $checksumPath } | Sort-Object FullName
    $lines = foreach ($file in $files) {
        $rel = $file.FullName.Substring($sep.Length).Replace([System.IO.Path]::DirectorySeparatorChar, '/').Replace([System.IO.Path]::AltDirectorySeparatorChar, '/')
        "$(Get-Sha256Hex -Path $file.FullName)  $rel"
    }
    Set-Content -LiteralPath $checksumPath -Value $lines -Encoding ASCII
    Write-Host "Batch checksums written: $checksumPath"
}

# ---- exit policy ----
# Honest blocker == batch success. Exit non-zero ONLY on a real harness bug.
if ($harnessBug) {
    Write-Host 'Batch FAILED: at least one capture died outside its own blocker path (harness bug).'
    exit 1
}
Write-Host 'Batch complete. Blocked/skipped captures are honest outcomes, not failures.'
exit 0
