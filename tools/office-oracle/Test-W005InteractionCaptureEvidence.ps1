[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CaptureDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

function Resolve-RepoPath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        $fullPath = [System.IO.Path]::GetFullPath($Path)
    } else {
        $fullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
    }

    $repoWithSeparator = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not ($fullPath.Equals($repoRoot, [System.StringComparison]::OrdinalIgnoreCase) -or $fullPath.StartsWith($repoWithSeparator, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Path '$Path' resolves outside repository root '$repoRoot'."
    }

    return $fullPath
}

function Get-Sha256Hex {
    param([string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try {
            return ([System.BitConverter]::ToString($sha256.ComputeHash($stream)) -replace '-', '').ToLowerInvariant()
        } finally {
            $sha256.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Assert-File {
    param([string]$Path)

    $fullPath = Resolve-RepoPath $Path
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Expected file does not exist: $Path"
    }

    return $fullPath
}

function Assert-EventLog {
    param(
        [string]$Path,
        [string[]]$RequiredEvents
    )

    $fullPath = Assert-File $Path
    $log = Get-Content -Raw -LiteralPath $fullPath | ConvertFrom-Json
    if ($log.schema -ne 'oxforms.office_oracle.w005_interaction_event_log.v1') {
        throw "Unexpected event log schema in $Path"
    }
    if ($log.bead -ne 'oxforms-xvx.3') {
        throw "Unexpected bead in event log $Path"
    }
    if ($null -eq $log.observed_facts -or [int]$log.observed_facts.row_count -le 0) {
        throw "Event log has no observed rows: $Path"
    }
    if ($null -eq $log.assumptions -or @($log.assumptions).Count -eq 0) {
        throw "Event log must separate assumptions from observed facts: $Path"
    }
    if ($null -eq $log.manual_inputs) {
        throw "Event log must include manual_inputs, even when empty: $Path"
    }

    $eventNames = @($log.observed_facts.event_names)
    foreach ($eventName in $RequiredEvents) {
        if ($eventName -notin $eventNames) {
            throw "Event log '$Path' is missing expected observed event '$eventName'. Observed: $($eventNames -join ', ')"
        }
    }

    return $log
}

$resolvedCaptureDir = Resolve-RepoPath $CaptureDir
$manifestPath = Join-Path $resolvedCaptureDir 'oracle-capture-manifest.json'
$checksumPath = Join-Path $resolvedCaptureDir 'checksums.sha256'

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Manifest not found: $manifestPath"
}
if (-not (Test-Path -LiteralPath $checksumPath -PathType Leaf)) {
    throw "Checksum file not found: $checksumPath"
}

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
if ($manifest.schema -ne 'oxforms.office_oracle.w005_interaction_event_capture.v1') {
    throw "Unexpected capture manifest schema: $($manifest.schema)"
}
if ($manifest.bead -ne 'oxforms-xvx.3') {
    throw "Unexpected bead in manifest: $($manifest.bead)"
}
if ($manifest.fixture.id -ne 'excel-msforms-w005-interaction-events-v1') {
    throw "Unexpected fixture id: $($manifest.fixture.id)"
}
if ($null -eq $manifest.warnings -or @($manifest.warnings).Count -eq 0) {
    throw 'Manifest must include warnings/non-claims.'
}
if (($manifest.warnings -join "`n") -notmatch 'not an exhaustive MSForms event parity claim') {
    throw 'Manifest must explicitly avoid exhaustive parity claims.'
}

$captureRootRelative = "docs/evidence/W005_input_interaction_model_exploration/captures/$($manifest.capture_id)"

$artifactPaths = @(
    $manifest.artifacts.generated_workbook.path,
    $manifest.artifacts.run_summary,
    $manifest.artifacts.modeless.window_capture_manifest,
    $manifest.artifacts.modeless.screenshot,
    $manifest.artifacts.modeless.coordinate_calibration,
    $manifest.artifacts.modeless.input_actions,
    $manifest.artifacts.modeless.event_log_json,
    $manifest.artifacts.modeless.event_log_csv,
    "$captureRootRelative/README.md",
    "$captureRootRelative/oracle-capture-manifest.json"
)

foreach ($path in $artifactPaths) {
    [void](Assert-File $path)
}

[void](Assert-EventLog -Path $manifest.artifacts.modeless.event_log_json -RequiredEvents @('Initialize', 'MouseDown', 'MouseUp', 'Click', 'Change', 'KeyDown', 'KeyPress', 'KeyUp', 'Enter', 'Exit', 'QueryClose'))

if ($null -ne $manifest.artifacts.modal) {
    [void](Assert-File $manifest.artifacts.modal.window_capture_manifest)
    [void](Assert-File $manifest.artifacts.modal.screenshot)
    [void](Assert-File $manifest.artifacts.modal.coordinate_calibration)
    [void](Assert-File $manifest.artifacts.modal.input_actions)
    [void](Assert-File $manifest.artifacts.modal.event_log_json)
    [void](Assert-File $manifest.artifacts.modal.event_log_csv)
    [void](Assert-EventLog -Path $manifest.artifacts.modal.event_log_json -RequiredEvents @('Initialize', 'MouseDown', 'MouseUp', 'Click', 'Change', 'KeyDown', 'KeyPress', 'KeyUp', 'Enter', 'Exit', 'QueryClose'))
}

$checksumLines = Get-Content -LiteralPath $checksumPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
if ($checksumLines.Count -eq 0) {
    throw 'Checksum file is empty.'
}

foreach ($line in $checksumLines) {
    if ($line -notmatch '^([0-9a-f]{64})\s\s(.+)$') {
        throw "Malformed checksum line: $line"
    }

    $expectedHash = $Matches[1]
    $relativePath = $Matches[2]
    $fullPath = Assert-File $relativePath
    $actualHash = Get-Sha256Hex -Path $fullPath
    if ($actualHash -ne $expectedHash) {
        throw "Checksum mismatch for '$relativePath': expected $expectedHash, got $actualHash"
    }
}

Write-Host "W005 interaction capture evidence check: ok"
Write-Host "Capture: $($manifest.capture_id)"
Write-Host "Checksum entries: $($checksumLines.Count)"
