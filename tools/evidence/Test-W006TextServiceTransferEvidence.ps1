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

$resolvedCaptureDir = Resolve-InRepoPath $CaptureDir
$manifest = Read-Json (Join-Path $resolvedCaptureDir 'oracle-capture-manifest.json')
$summary = Read-Json (Join-Path $resolvedCaptureDir 'run-summary.json')
$eventLog = Read-Json (Join-Path $resolvedCaptureDir 'w006-transfer-event-log.json')
$actions = Read-Json (Join-Path $resolvedCaptureDir 'input-actions.json')

if ($manifest.schema -ne 'oxforms.office_oracle.w006_text_service_transfer_capture.v1') {
    throw "Unexpected manifest schema: $($manifest.schema)"
}
if ($manifest.bead -ne 'oxforms-0a0.13' -or $summary.bead -ne 'oxforms-0a0.13' -or $eventLog.bead -ne 'oxforms-0a0.13') {
    throw 'Capture files must all name bead oxforms-0a0.13.'
}
if (-not [bool]$summary.final_text_equals_clipboard_seed) {
    throw 'Expected final_text_equals_clipboard_seed=true.'
}

$eventNames = @($eventLog.observed_facts.event_names)
foreach ($requiredEvent in @('BeforeDropOrPaste', 'Change')) {
    if ($eventNames -notcontains $requiredEvent) {
        throw "Expected observed event '$requiredEvent'."
    }
}

$beforeDropRows = @($eventLog.observed_facts.rows | Where-Object { $_.event_name -eq 'BeforeDropOrPaste' })
if ($beforeDropRows.Count -ne 1) {
    throw "Expected exactly one BeforeDropOrPaste row, found $($beforeDropRows.Count)."
}

$beforeDrop = $beforeDropRows[0]
foreach ($field in @('cancel_before', 'cancel_after', 'effect_before', 'effect_after', 'action_or_drag_state')) {
    if ([string]::IsNullOrWhiteSpace([string]$beforeDrop.$field)) {
        throw "BeforeDropOrPaste row is missing field '$field'."
    }
}
if ($beforeDrop.data_object_observation -notlike '*data_object=present*') {
    throw 'BeforeDropOrPaste row must record a present DataObject.'
}
if ($beforeDrop.data_object_observation -notlike '*text_payload=repo_seed:repo_owned_text_seed_v1*') {
    throw 'DataObject observation must identify only the repo-owned seed payload.'
}
if ($beforeDrop.data_object_observation -match '0x[0-9a-fA-F]+') {
    throw 'DataObject observation must not store live object identity.'
}

$keyboardAction = @($actions.automated_inputs | Where-Object { $_.action -eq 'ctrl_v' })[0]
if ($null -eq $keyboardAction -or $keyboardAction.result.status -ne 'blocked') {
    throw 'Expected Ctrl+V action to record the current keyboard-driver blocker.'
}
$pasteAction = @($actions.automated_inputs | Where-Object { $_.action -eq 'textbox_paste' })[0]
if ($null -eq $pasteAction -or $pasteAction.result.status -ne 'completed') {
    throw 'Expected public TextBox.Paste fallback to complete.'
}

$blockerSurfaces = @($actions.blockers | ForEach-Object { $_.surface })
foreach ($surface in @('clipboard_shortcut_ctrl_v', 'ime_composition', 'dead_keys', 'ole_drag_drop')) {
    if ($blockerSurfaces -notcontains $surface) {
        throw "Missing blocker surface '$surface'."
    }
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

Write-Host "W006 text-service transfer evidence OK: $resolvedCaptureDir"
