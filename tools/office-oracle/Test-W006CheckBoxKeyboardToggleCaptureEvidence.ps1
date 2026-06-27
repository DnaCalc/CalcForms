[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$CaptureDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

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
if ($manifest.schema -ne 'oxforms.office_oracle.w006_checkbox_keyboard_toggle_capture.v1') { throw "Unexpected manifest schema: $($manifest.schema)" }
if ($manifest.bead -ne 'oxforms-0a0.12') { throw "Unexpected manifest bead: $($manifest.bead)" }
if ($manifest.status -notin @('captured', 'blocked')) { throw "Unexpected manifest status: $($manifest.status)" }

# Re-hash every declared fixture input artifact against the manifest sha256.
Assert-RepoArtifactHash -Artifact $manifest.fixture.inputs.manifest -Description 'fixture manifest'
Assert-RepoArtifactHash -Artifact $manifest.fixture.inputs.form_code_behind -Description 'form code-behind source'
Assert-RepoArtifactHash -Artifact $manifest.fixture.inputs.standard_module -Description 'standard module source'
Assert-RepoArtifactHash -Artifact $manifest.fixture.inputs.capture_tool -Description 'capture tool source'

$warningText = (@($manifest.warnings) + @($manifest.non_claims)) -join "`n"
Assert-ContainsText -Haystack $warningText -Needle 'No OxForms runtime' -Description 'warning/non-claim text'
Assert-ContainsText -Haystack $warningText -Needle 'not a negative' -Description 'warning/non-claim text'

$cleanRoomText = (@($manifest.clean_room.source) + @($manifest.clean_room.prohibited)) -join "`n"
Assert-ContainsText -Haystack $cleanRoomText -Needle 'No Office internals' -Description 'clean-room text'

if ($manifest.status -eq 'blocked') {
    $blocker = Get-JsonFile -Path (Join-Path $resolvedCaptureDir 'blocker.json')
    if ($blocker.schema -ne 'oxforms.office_oracle.w006_checkbox_keyboard_toggle_blocker.v1') { throw "Unexpected blocker schema: $($blocker.schema)" }
    if ($blocker.status -ne 'blocked') { throw "Expected blocker status=blocked; got $($blocker.status)" }
    $blockerText = (@($blocker.non_claims)) -join "`n"
    Assert-ContainsText -Haystack $blockerText -Needle 'No Space/Enter keyboard toggle ordering is inferred' -Description 'blocker non-claims'
} else {
    # captured: input-actions, Space+Enter SendInput completed status, event log.
    $inputActions = Get-JsonFile -Path (Resolve-RepoPath $manifest.artifacts.input_actions)
    if ($inputActions.schema -ne 'oxforms.office_oracle.w006_checkbox_keyboard_toggle_input_actions.v1') { throw "Unexpected input-actions schema: $($inputActions.schema)" }
    if ($null -eq $inputActions.manual_inputs) { throw 'input-actions.json must preserve manual_inputs, even when empty.' }
    foreach ($expectedAction in @('space', 'enter')) {
        # PSObject.Properties guard: input-actions entries are PSCustomObjects after JSON load,
        # and not all carry an 'action' property; bare $_.action throws under Set-StrictMode.
        $action = $inputActions.automated_inputs | Where-Object { $_.PSObject.Properties['action'] -and $_.action -eq $expectedAction } | Select-Object -First 1
        if ($null -eq $action) { throw "Captured input-actions.json is missing the $expectedAction automated input." }
        if ($action.result.status -ne 'completed') { throw "Captured $expectedAction SendInput status must be completed; got $($action.result.status)" }
        if ([int]$action.result.send_input.sent -ne [int]$action.result.send_input.requested) { throw "Captured $expectedAction SendInput sent must equal requested; got sent=$($action.result.send_input.sent) requested=$($action.result.send_input.requested)" }
    }

    Assert-RepoArtifactHash -Artifact $manifest.artifacts.generated_workbook -Description 'generated workbook'

    $eventLog = Get-JsonFile -Path (Resolve-RepoPath $manifest.artifacts.event_log_json)
    if ($eventLog.schema -ne 'oxforms.office_oracle.w006_checkbox_keyboard_toggle_event_log.v1') { throw "Unexpected event-log schema: $($eventLog.schema)" }
    if ($eventLog.bead -ne 'oxforms-0a0.12') { throw "Unexpected event-log bead: $($eventLog.bead)" }
    if ([int]$eventLog.observed_facts.row_count -le 0) { throw 'Captured evidence must contain at least one observed row.' }
    $observedEvents = @($eventLog.observed_facts.event_names)
    foreach ($expected in @('KeyDown', 'KeyUp')) {
        if ($expected -notin $observedEvents) { throw "Captured event log is missing expected keyboard event: $expected" }
    }
    if (-not (Test-Path -LiteralPath (Resolve-RepoPath $manifest.artifacts.event_log_csv) -PathType Leaf)) { throw 'Captured event log CSV is missing.' }
}

Assert-ChecksumFile -ResolvedCaptureDir $resolvedCaptureDir

Write-Host "W006 CheckBox keyboard-toggle capture evidence OK: $resolvedCaptureDir"
