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
$allowedBeads = @('oxforms-0a0.13', 'oxforms-0a0.17')
if ($allowedBeads -notcontains $manifest.bead -or $allowedBeads -notcontains $summary.bead -or $allowedBeads -notcontains $eventLog.bead) {
    throw 'Capture files must all name bead oxforms-0a0.13 or oxforms-0a0.17.'
}
if ($manifest.bead -ne $summary.bead -or $manifest.bead -ne $eventLog.bead) {
    throw 'Manifest, run summary, and event log must agree on bead id.'
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

$keyboardActions = @($actions.automated_inputs | Where-Object { $_.action -eq 'ctrl_v' })
if ($keyboardActions.Count -lt 1) {
    throw 'Expected at least one Ctrl+V action.'
}
$shortcutStatus = [string]$summary.selected_surface_status.clipboard_shortcut_paste
$shortcutObserved = $shortcutStatus -eq 'observed_textbox_text_equals_repo_seed_after_ctrl_v'
if ($shortcutObserved) {
    foreach ($requiredEvent in @('KeyDown', 'KeyUp', 'BeforeDropOrPaste', 'Change')) {
        if ($eventNames -notcontains $requiredEvent) {
            throw "Shortcut-observed capture must include '$requiredEvent' in the event log."
        }
    }
    $orderedRows = @($eventLog.observed_facts.rows | Sort-Object { [int]$_.sequence })
    $keyDownRows = @($orderedRows | Where-Object { $_.event_name -eq 'KeyDown' })
    $keyUpRows = @($orderedRows | Where-Object { $_.event_name -eq 'KeyUp' })
    if ($keyDownRows.Count -lt 1 -or $keyUpRows.Count -lt 1) {
        throw 'Shortcut-observed capture must include KeyDown and KeyUp rows.'
    }
    foreach ($keyRow in @($keyDownRows + $keyUpRows)) {
        if ([string]::IsNullOrWhiteSpace([string]$keyRow.key_code_before) -or [string]::IsNullOrWhiteSpace([string]$keyRow.key_code_after)) {
            throw 'Shortcut key rows must include before/after ReturnInteger helper values.'
        }
    }
    $firstKeyDown = $keyDownRows[0]
    $lastKeyUp = $keyUpRows[$keyUpRows.Count - 1]
    $firstDrop = @($orderedRows | Where-Object { $_.event_name -eq 'BeforeDropOrPaste' })[0]
    $firstChange = @($orderedRows | Where-Object { $_.event_name -eq 'Change' })[0]
    if (-not ([int]$firstKeyDown.sequence -lt [int]$firstDrop.sequence -and [int]$firstDrop.sequence -lt [int]$firstChange.sequence -and [int]$firstChange.sequence -lt [int]$lastKeyUp.sequence)) {
        throw 'Shortcut-observed capture must order KeyDown before BeforeDropOrPaste before Change before final KeyUp.'
    }
    if ($eventNames -notcontains 'KeyPress' -and $summary.selected_surface_status.PSObject.Properties.Name -contains 'key_press' -and $summary.selected_surface_status.key_press -ne 'not_observed_in_this_run') {
        throw 'Shortcut-observed capture without KeyPress rows must mark key_press as not_observed_in_this_run.'
    }
} else {
    $blockedKeyboard = @($keyboardActions | Where-Object { $_.result.status -eq 'blocked' -or $_.result.status -eq 'attempted_but_ineffective' -or $_.result.textbox_text_equals_clipboard_seed_after -eq $false })
    if ($blockedKeyboard.Count -lt 1) {
        throw 'Expected Ctrl+V action to record a precise blocker or ineffective driver when shortcut paste is not observed.'
    }
    $pasteAction = @($actions.automated_inputs | Where-Object { $_.action -eq 'textbox_paste' })[0]
    if ($null -eq $pasteAction -or $pasteAction.result.status -ne 'completed') {
        throw 'Expected public TextBox.Paste fallback to complete when Ctrl+V is not observed.'
    }
}

$blockerSurfaces = @($actions.blockers | ForEach-Object { $_.surface })
foreach ($surface in @('ime_composition', 'dead_keys')) {
    if ($blockerSurfaces -notcontains $surface) {
        throw "Missing blocker surface '$surface'."
    }
}
if (-not $shortcutObserved -and $blockerSurfaces -notcontains 'clipboard_shortcut_ctrl_v') {
    throw "Missing blocker surface 'clipboard_shortcut_ctrl_v'."
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
