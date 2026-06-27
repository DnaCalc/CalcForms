[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$CaptureDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$expectedBead = 'oxforms-0a0.25'
$requiredScenarios = @('modeless_system_close', 'modal_hide_return', 'modal_unload_return')

function Resolve-RepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $fullPath = if ([System.IO.Path]::IsPathRooted($Path)) { [System.IO.Path]::GetFullPath($Path) } else { [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path)) }
    $repoWithSeparator = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not ($fullPath.Equals($repoRoot, [System.StringComparison]::OrdinalIgnoreCase) -or $fullPath.StartsWith($repoWithSeparator, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Path '$Path' resolves outside repository root '$repoRoot'."
    }
    return $fullPath
}

function Get-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required JSON file not found: $Path" }
    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Assert-ContainsText {
    param([Parameter(Mandatory = $true)][string]$Haystack, [Parameter(Mandatory = $true)][string]$Needle, [Parameter(Mandatory = $true)][string]$Description)
    if ($Haystack.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { throw "Expected $Description to contain '$Needle'." }
}

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][string]$Path)
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try { return ([System.BitConverter]::ToString($sha256.ComputeHash($stream)) -replace '-', '').ToLowerInvariant() } finally { $sha256.Dispose() }
    } finally { $stream.Dispose() }
}

function Assert-RepoArtifactExists {
    param([Parameter(Mandatory = $true)][string]$RepoRelativePath, [Parameter(Mandatory = $true)][string]$Description)
    $path = Resolve-RepoPath $RepoRelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "$Description does not exist: $RepoRelativePath" }
}

function Assert-RepoArtifactHash {
    param([Parameter(Mandatory = $true)]$Artifact, [Parameter(Mandatory = $true)][string]$Description)
    if ($null -eq $Artifact.path -or [string]::IsNullOrWhiteSpace([string]$Artifact.path)) { throw "$Description is missing path." }
    if ($null -eq $Artifact.sha256 -or [string]::IsNullOrWhiteSpace([string]$Artifact.sha256)) { throw "$Description is missing sha256." }
    $path = Resolve-RepoPath ([string]$Artifact.path)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "$Description does not exist: $($Artifact.path)" }
    $expected = ([string]$Artifact.sha256).ToLowerInvariant()
    $actual = Get-Sha256Hex -Path $path
    if ($actual -ne $expected) { throw "$Description checksum mismatch; expected $expected actual $actual" }
}

function Assert-ChecksumFile {
    param([Parameter(Mandatory = $true)][string]$ResolvedCaptureDir)
    $checksumPath = Join-Path $ResolvedCaptureDir 'checksums.sha256'
    if (-not (Test-Path -LiteralPath $checksumPath -PathType Leaf)) { throw "checksums.sha256 not found: $checksumPath" }
    foreach ($line in Get-Content -LiteralPath $checksumPath) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -notmatch '^([0-9a-fA-F]{64})  (.+)$') { throw "Malformed checksum line: $line" }
        $expected = $matches[1].ToLowerInvariant()
        $relative = $matches[2]
        $path = Join-Path $ResolvedCaptureDir ($relative -replace '/', [System.IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Checksummed file is missing: $relative" }
        $actual = Get-Sha256Hex -Path $path
        if ($actual -ne $expected) { throw "Checksum mismatch for $relative; expected $expected actual $actual" }
    }
}

$resolvedCaptureDir = Resolve-RepoPath $CaptureDir
if (-not (Test-Path -LiteralPath $resolvedCaptureDir -PathType Container)) { throw "Capture directory not found: $resolvedCaptureDir" }

$manifest = Get-JsonFile -Path (Join-Path $resolvedCaptureDir 'oracle-capture-manifest.json')
if ($manifest.schema -ne 'oxforms.office_oracle.w006_held_ref_residuals_capture.v1') { throw "Unexpected manifest schema: $($manifest.schema)" }
if ($manifest.bead -ne $expectedBead) { throw "Unexpected manifest bead: $($manifest.bead)" }
if ($manifest.status -notin @('captured', 'blocked')) { throw "Unexpected manifest status: $($manifest.status)" }

# Re-hash every declared fixture input artifact against the manifest sha256.
Assert-RepoArtifactHash -Artifact $manifest.fixture.inputs.manifest -Description 'fixture manifest'
foreach ($source in @($manifest.fixture.inputs.form_code_behind)) {
    Assert-RepoArtifactHash -Artifact $source -Description ('form source ' + $source.form_identity)
}
Assert-RepoArtifactHash -Artifact $manifest.fixture.inputs.standard_module -Description 'standard module source'
Assert-RepoArtifactHash -Artifact $manifest.fixture.inputs.capture_tool -Description 'capture tool source'

Assert-RepoArtifactExists -RepoRelativePath $manifest.artifacts.run_summary -Description 'run summary'
foreach ($commandLog in @($manifest.artifacts.command_logs)) {
    Assert-RepoArtifactExists -RepoRelativePath $commandLog -Description 'command log'
}

$traceText = (@($manifest.trace_replay_implications) -join "`n")
foreach ($section in @('section 5', 'section 9', 'section 11', 'section 14')) {
    Assert-ContainsText -Haystack $traceText -Needle $section -Description 'trace/replay implications'
}
Assert-ContainsText -Haystack $traceText -Needle 'effect_requested' -Description 'trace/replay implications'
Assert-ContainsText -Haystack $traceText -Needle 'effect_completed' -Description 'trace/replay implications'

$warningText = (@($manifest.warnings) + @($manifest.non_claims)) -join "`n"
Assert-ContainsText -Haystack $warningText -Needle 'Missing event rows are unobserved' -Description 'warning/non-claim text'
Assert-ContainsText -Haystack $warningText -Needle 'No OxForms runtime' -Description 'warning/non-claim text'
Assert-ContainsText -Haystack $warningText -Needle 'only the held-reference state dimension is in scope here' -Description 'held-reference scope non-claim'

$inputActions = Get-JsonFile -Path (Join-Path $resolvedCaptureDir 'input-actions.json')
if ($inputActions.schema -ne 'oxforms.office_oracle.w006_held_ref_residuals_input_actions.v1') { throw "Unexpected input-actions schema: $($inputActions.schema)" }
if ($null -eq $inputActions.manual_inputs) { throw 'input-actions.json must preserve manual_inputs, even when empty.' }

$runSummaryPath = Resolve-RepoPath $manifest.artifacts.run_summary
$runSummary = Get-JsonFile -Path $runSummaryPath
if ($runSummary.schema -ne 'oxforms.office_oracle.w006_held_ref_residuals_run_summary.v1') { throw "Unexpected run summary schema: $($runSummary.schema)" }
if ($runSummary.bead -ne $expectedBead) { throw "Unexpected run summary bead: $($runSummary.bead)" }
if ($runSummary.status -ne $manifest.status) { throw "Run summary status '$($runSummary.status)' does not match manifest status '$($manifest.status)'." }

# scenario_coverage must carry an entry for every required scenario.
if ($null -eq $runSummary.scenario_coverage) { throw 'Run summary is missing scenario_coverage.' }
foreach ($scenario in $requiredScenarios) {
    $property = $runSummary.scenario_coverage.PSObject.Properties[$scenario]
    if ($null -eq $property) { throw "Run summary scenario_coverage is missing scenario: $scenario" }
    $state = [string]$property.Value
    if ($state -notin @('observed_rows', 'blocked_in_this_run', 'not_observed_in_this_run')) {
        throw "Run summary scenario_coverage[$scenario] has unexpected state: $state"
    }
}

if ($manifest.status -eq 'blocked') {
    $blocker = Get-JsonFile -Path (Join-Path $resolvedCaptureDir 'blocker.json')
    if ($blocker.schema -ne 'oxforms.office_oracle.w006_held_ref_residuals_blocker.v1') { throw "Unexpected blocker schema: $($blocker.schema)" }
    if ($blocker.status -ne 'blocked') { throw "Expected blocker status=blocked; got $($blocker.status)" }
    if ([int]$runSummary.row_count -ne 0) { throw "Blocked run summary must have row_count=0; got $($runSummary.row_count)" }
    foreach ($field in @('event sequence', 'scenario', 'instance id', 'show mode', 'held reference state', 'release phase', 'Terminate rows')) {
        if ($field -notin @($blocker.blocked_recording_fields)) { throw "Blocked evidence is missing recording field: $field" }
    }
} else {
    # Captured: re-hash the event log against the manifest sha256 and assert the
    # declared scenarios/rows are present.
    $eventLogArtifactPath = Resolve-RepoPath ([string]$manifest.artifacts.event_log_json)
    if (-not (Test-Path -LiteralPath $eventLogArtifactPath -PathType Leaf)) { throw "Captured manifest declares a missing event log: $($manifest.artifacts.event_log_json)" }
    $eventLog = Get-JsonFile -Path $eventLogArtifactPath
    if ($eventLog.schema -ne 'oxforms.office_oracle.w006_held_ref_residuals_event_log.v1') { throw "Unexpected event log schema: $($eventLog.schema)" }
    if ([int]$eventLog.observed_facts.row_count -le 0) { throw 'Captured evidence must contain at least one observed row.' }

    # At least one required scenario must be observed in a captured run; partial
    # results (other scenarios blocked) are acceptable and recorded in coverage.
    $observedScenarios = @($runSummary.scenario_coverage.PSObject.Properties | Where-Object { [string]$_.Value -eq 'observed_rows' } | ForEach-Object { $_.Name })
    if ($observedScenarios.Count -eq 0) { throw 'Captured run summary records no observed scenario rows; expected at least one.' }
    foreach ($scenario in $observedScenarios) {
        if ($scenario -notin @($eventLog.observed_facts.scenarios)) {
            throw "Run summary marks '$scenario' observed_rows but the event log scenarios do not include it."
        }
    }
    foreach ($identity in @('launcher', 'held')) {
        $hasIdentity = @($eventLog.observed_facts.rows | Where-Object { $_.form_identity -eq $identity }).Count -gt 0
        if (-not $hasIdentity) { throw "Captured event log is missing rows for form identity: $identity" }
    }
}

Assert-ChecksumFile -ResolvedCaptureDir $resolvedCaptureDir

Write-Host "W006 held-reference residuals capture evidence OK: $resolvedCaptureDir (status=$($manifest.status))"
