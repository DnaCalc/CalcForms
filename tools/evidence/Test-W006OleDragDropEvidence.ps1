[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CaptureDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))

function Resolve-InRepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = if ([System.IO.Path]::IsPathRooted($Path)) {
        [System.IO.Path]::GetFullPath($Path)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
    }

    $repoWithSeparator = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($repoWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path '$Path' resolves outside repository root '$repoRoot'."
    }

    return $fullPath
}

function Read-Json {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing required JSON file: $Path"
    }

    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][string]$Path)

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

function Assert-TransferRow {
    param(
        [Parameter(Mandatory = $true)][object]$Row,
        [Parameter(Mandatory = $true)][string]$EventName
    )

    foreach ($field in @('x', 'y', 'shift', 'cancel_before', 'cancel_after', 'effect_before', 'effect_after', 'action_or_drag_state')) {
        if ([string]::IsNullOrWhiteSpace([string]$Row.$field)) {
            throw "$EventName row is missing field '$field'."
        }
    }
    if ($Row.coordinate_space -ne 'msforms_event_args') {
        throw "$EventName row must use coordinate_space=msforms_event_args."
    }
    if ($Row.data_object_observation -notlike '*data_object=present*') {
        throw "$EventName row must record a present DataObject."
    }
    if ($Row.data_object_observation -notlike '*text_payload=repo_seed:repo_owned_drag_text_seed_v1*') {
        throw "$EventName DataObject observation must identify only the repo-owned drag seed payload."
    }
    if ($Row.data_object_observation -match '0x[0-9a-fA-F]+') {
        throw "$EventName DataObject observation must not store live object identity."
    }
}

$resolvedCaptureDir = Resolve-InRepoPath $CaptureDir
$manifest = Read-Json (Join-Path $resolvedCaptureDir 'oracle-capture-manifest.json')
$summary = Read-Json (Join-Path $resolvedCaptureDir 'run-summary.json')
$eventLog = Read-Json (Join-Path $resolvedCaptureDir 'w006-ole-drag-drop-event-log.json')
$actions = Read-Json (Join-Path $resolvedCaptureDir 'input-actions.json')
$coordinates = Read-Json (Join-Path $resolvedCaptureDir 'coordinate-derivation.json')

if ($manifest.schema -ne 'oxforms.office_oracle.w006_ole_drag_drop_capture.v1') {
    throw "Unexpected manifest schema: $($manifest.schema)"
}
if ($summary.schema -ne 'oxforms.office_oracle.w006_ole_drag_drop_run_summary.v1') {
    throw "Unexpected run summary schema: $($summary.schema)"
}
if ($eventLog.schema -ne 'oxforms.office_oracle.w006_ole_drag_drop_event_log.v1') {
    throw "Unexpected event log schema: $($eventLog.schema)"
}
if ($actions.schema -ne 'oxforms.office_oracle.w006_ole_drag_drop_input_actions.v1') {
    throw "Unexpected input actions schema: $($actions.schema)"
}
foreach ($doc in @($manifest, $summary, $eventLog, $actions)) {
    if ($doc.bead -ne 'oxforms-0a0.16') {
        throw 'Capture files must all name bead oxforms-0a0.16.'
    }
}
if ($coordinates.schema -ne 'oxforms.office_oracle.w006_ole_drag_drop_coordinate_derivation.v1') {
    throw "Unexpected coordinate derivation schema: $($coordinates.schema)"
}

$rows = @($eventLog.observed_facts.rows)
$beforeDragRows = @($rows | Where-Object { $_.event_name -eq 'BeforeDragOver' })
$beforeDropRows = @($rows | Where-Object { $_.event_name -eq 'BeforeDropOrPaste' })
$startDragAttempts = @($rows | Where-Object { $_.event_name -eq 'StartDragAttempt' })
$startDragErrors = @($rows | Where-Object { $_.event_name -eq 'StartDragError' })

if ([bool]$summary.captured_true_drag_drop) {
    if ($beforeDragRows.Count -lt 1) {
        throw 'True drag/drop capture requires at least one BeforeDragOver row.'
    }
    if ($beforeDropRows.Count -lt 1) {
        throw 'True drag/drop capture requires at least one BeforeDropOrPaste row.'
    }
    Assert-TransferRow -Row $beforeDragRows[0] -EventName 'BeforeDragOver'
    Assert-TransferRow -Row $beforeDropRows[0] -EventName 'BeforeDropOrPaste'
    if ($startDragAttempts.Count -lt 1) {
        throw 'True drag/drop capture requires a StartDragAttempt source row.'
    }
} else {
    $blockers = @($actions.blockers | Where-Object { $_.surface -eq 'ole_drag_drop' })
    if ($blockers.Count -ne 1) {
        throw 'Blocked capture must record exactly one ole_drag_drop blocker.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$blockers[0].reason)) {
        throw 'Blocked capture must record a precise blocker reason.'
    }
    if ($beforeDragRows.Count -gt 0 -and $beforeDropRows.Count -gt 0) {
        throw 'Run is marked blocked even though both drag/drop target rows are present.'
    }
}

foreach ($row in ($rows | Where-Object { -not [string]::IsNullOrWhiteSpace($_.data_object_observation) })) {
    if ($row.data_object_observation -match '0x[0-9a-fA-F]+') {
        throw "DataObject observation must not store live object identity: $($row.data_object_observation)"
    }
}

if ($eventLog.fact_source.text_service_paste_evidence -notlike '*text-service-transfer-oracle.md*') {
    throw 'Event log must point to the separated oxforms-0a0.13 paste evidence as adjacent evidence only.'
}
if ($summary.non_claims -notcontains 'This run keeps oxforms-0a0.13 paste DataObject observations separate from true drag/drop observations.') {
    throw 'Run summary must explicitly separate paste observations from true drag/drop observations.'
}
if ($startDragErrors.Count -gt 0 -and [bool]$summary.captured_true_drag_drop) {
    throw 'Capture cannot be marked true drag/drop when StartDragError rows are present.'
}

$checksumPath = Join-Path $resolvedCaptureDir 'checksums.sha256'
if (-not (Test-Path -LiteralPath $checksumPath -PathType Leaf)) {
    throw "Missing checksum manifest: $checksumPath"
}
foreach ($line in Get-Content -LiteralPath $checksumPath) {
    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }
    if ($line -notmatch '^([0-9a-f]{64})  (.+)$') {
        throw "Invalid checksum line: $line"
    }
    $expected = $Matches[1]
    $relative = $Matches[2]
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $resolvedCaptureDir ($relative -replace '/', [System.IO.Path]::DirectorySeparatorChar)))
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Checksum references missing file: $relative"
    }
    $actual = Get-Sha256Hex -Path $fullPath
    if ($actual -ne $expected) {
        throw "Checksum mismatch for $relative. Expected $expected, got $actual."
    }
}

Write-Host "W006 OLE drag/drop evidence OK: $resolvedCaptureDir"
Write-Host "Captured true drag/drop: $([bool]$summary.captured_true_drag_drop)"
