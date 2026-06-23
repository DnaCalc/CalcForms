[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CaptureDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$requiredScenarios = @(
    'hide_held_release',
    'unload_held_release',
    'modeless_system_close_held_release',
    'modal_hide_return_held_release',
    'modal_unload_return_held_release'
)

function Resolve-RepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = if ([System.IO.Path]::IsPathRooted($Path)) {
        [System.IO.Path]::GetFullPath($Path)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
    }

    $repoWithSeparator = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not ($fullPath.Equals($repoRoot, [System.StringComparison]::OrdinalIgnoreCase) -or $fullPath.StartsWith($repoWithSeparator, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Path '$Path' resolves outside repository root '$repoRoot'."
    }
    return $fullPath
}

function Get-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required JSON file not found: $Path"
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

function Assert-ContainsText {
    param(
        [Parameter(Mandatory = $true)][string]$Haystack,
        [Parameter(Mandatory = $true)][string]$Needle,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if ($Haystack.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "Expected $Description to contain '$Needle'."
    }
}

function Assert-RepoArtifactExists {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRelativePath,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if ([System.IO.Path]::IsPathRooted($RepoRelativePath) -or $RepoRelativePath -match '\\') {
        throw "$Description must be repo-relative with forward slashes: $RepoRelativePath"
    }
    $path = Resolve-RepoPath $RepoRelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "$Description does not exist: $RepoRelativePath"
    }
    return $path
}

function Assert-RepoArtifactHash {
    param(
        [Parameter(Mandatory = $true)]$Artifact,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if ($null -eq $Artifact.path -or [string]::IsNullOrWhiteSpace([string]$Artifact.path)) {
        throw "$Description is missing path."
    }
    if ($null -eq $Artifact.sha256 -or [string]::IsNullOrWhiteSpace([string]$Artifact.sha256)) {
        throw "$Description is missing sha256."
    }

    $path = Assert-RepoArtifactExists -RepoRelativePath ([string]$Artifact.path) -Description $Description
    $expected = ([string]$Artifact.sha256).ToLowerInvariant()
    $actual = Get-Sha256Hex -Path $path
    if ($actual -ne $expected) {
        throw "$Description checksum mismatch; expected $expected actual $actual"
    }
}

function Assert-ChecksumFile {
    param([Parameter(Mandatory = $true)][string]$ResolvedCaptureDir)

    $checksumPath = Join-Path $ResolvedCaptureDir 'checksums.sha256'
    if (-not (Test-Path -LiteralPath $checksumPath -PathType Leaf)) {
        throw "checksums.sha256 not found: $checksumPath"
    }

    $lines = Get-Content -LiteralPath $checksumPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($lines.Count -eq 0) {
        throw "checksums.sha256 is empty: $checksumPath"
    }

    foreach ($line in $lines) {
        if ($line -notmatch '^([0-9a-fA-F]{64})  (.+)$') {
            throw "Malformed checksum line: $line"
        }
        $expected = $matches[1].ToLowerInvariant()
        $relative = $matches[2]
        if ($relative -match '\\|^[A-Za-z]:|^/|^//') {
            throw "Checksum entry must be directory-relative with forward slashes: $relative"
        }
        $path = Join-Path $ResolvedCaptureDir ($relative -replace '/', [System.IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Checksummed file is missing: $relative"
        }
        $actual = Get-Sha256Hex -Path $path
        if ($actual -ne $expected) {
            throw "Checksum mismatch for $relative; expected $expected actual $actual"
        }
    }
}

function Assert-SeparatedEvidenceSections {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Description
    )

    foreach ($name in @('public_facts', 'observed_facts', 'run_observations', 'assumptions', 'unknowns', 'blockers', 'non_claims')) {
        $property = $Value.PSObject.Properties[$name]
        if ($null -eq $property) {
            throw "$Description is missing section '$name'."
        }
    }
}

$resolvedCaptureDir = Resolve-RepoPath $CaptureDir
if (-not (Test-Path -LiteralPath $resolvedCaptureDir -PathType Container)) {
    throw "Capture directory not found: $resolvedCaptureDir"
}

$manifest = Get-JsonFile -Path (Join-Path $resolvedCaptureDir 'oracle-capture-manifest.json')
if ($manifest.schema -ne 'oxforms.office_oracle.w006_terminate_lifetime_capture.v1') {
    throw "Unexpected manifest schema: $($manifest.schema)"
}
if ($manifest.bead -ne 'oxforms-0a0.21') {
    throw "Unexpected manifest bead: $($manifest.bead)"
}
if ($manifest.status -notin @('captured', 'blocked')) {
    throw "Unexpected manifest status: $($manifest.status)"
}
if ($manifest.fixture.id -ne 'excel-msforms-w006-terminate-lifetime-v1') {
    throw "Unexpected fixture id: $($manifest.fixture.id)"
}

Assert-SeparatedEvidenceSections -Value $manifest -Description 'manifest'
Assert-RepoArtifactHash -Artifact $manifest.fixture.inputs.manifest -Description 'fixture manifest'
Assert-RepoArtifactHash -Artifact $manifest.fixture.inputs.form_code_behind -Description 'fixture form code-behind'
Assert-RepoArtifactHash -Artifact $manifest.fixture.inputs.standard_module_extra -Description 'fixture standard module extra'
Assert-RepoArtifactHash -Artifact $manifest.fixture.inputs.capture_tool -Description 'capture tool'
Assert-RepoArtifactExists -RepoRelativePath $manifest.artifacts.run_summary -Description 'run summary' | Out-Null
Assert-RepoArtifactExists -RepoRelativePath $manifest.artifacts.input_actions -Description 'input actions' | Out-Null
foreach ($commandLog in @($manifest.artifacts.command_logs)) {
    Assert-RepoArtifactExists -RepoRelativePath $commandLog -Description 'command log' | Out-Null
}

$traceText = (@($manifest.trace_replay_implications) -join "`n")
foreach ($needle in @('section 5', 'section 9', 'section 11', 'section 14', 'lifecycle_pump', 'Unloaded', 'Terminated', 'effect_completed')) {
    Assert-ContainsText -Haystack $traceText -Needle $needle -Description 'trace/replay implications'
}

$nonClaimText = (@($manifest.non_claims) + @($manifest.warnings)) -join "`n"
Assert-ContainsText -Haystack $nonClaimText -Needle 'No OxForms runtime Terminate timing behavior' -Description 'non-claims'
Assert-ContainsText -Haystack $nonClaimText -Needle 'Unloaded and Terminated remain separate' -Description 'non-claims'

$inputActions = Get-JsonFile -Path (Resolve-RepoPath $manifest.artifacts.input_actions)
if ($inputActions.schema -ne 'oxforms.office_oracle.w006_terminate_lifetime_input_actions.v1') {
    throw "Unexpected input actions schema: $($inputActions.schema)"
}
if ($null -eq $inputActions.manual_inputs) {
    throw 'input-actions.json must preserve manual_inputs, even when empty.'
}

$runSummary = Get-JsonFile -Path (Resolve-RepoPath $manifest.artifacts.run_summary)
if ($runSummary.schema -ne 'oxforms.office_oracle.w006_terminate_lifetime_run_summary.v1') {
    throw "Unexpected run summary schema: $($runSummary.schema)"
}
if ($runSummary.bead -ne 'oxforms-0a0.21') {
    throw "Unexpected run summary bead: $($runSummary.bead)"
}

if ($manifest.status -eq 'blocked') {
    if ($manifest.artifacts.blocker -eq $null -or [string]::IsNullOrWhiteSpace([string]$manifest.artifacts.blocker)) {
        throw 'Blocked manifest must list blocker artifact.'
    }
    $blocker = Get-JsonFile -Path (Resolve-RepoPath $manifest.artifacts.blocker)
    if ($blocker.status -ne 'blocked') {
        throw "Expected blocker status=blocked; got $($blocker.status)"
    }
    foreach ($field in @('Hide action rows', 'Unload action rows', 'modeless close rows', 'modal return rows', 'held reference state', 'reference release phase', 'Terminate rows')) {
        if ($field -notin @($blocker.blocked_recording_fields)) {
            throw "Blocked evidence is missing recording field: $field"
        }
    }
} else {
    Assert-RepoArtifactHash -Artifact $manifest.artifacts.generated_workbook -Description 'generated workbook'
    Assert-RepoArtifactExists -RepoRelativePath $manifest.artifacts.event_log_json -Description 'event log json' | Out-Null
    Assert-RepoArtifactExists -RepoRelativePath $manifest.artifacts.event_log_csv -Description 'event log csv' | Out-Null
    $eventLog = Get-JsonFile -Path (Resolve-RepoPath $manifest.artifacts.event_log_json)
    if ($eventLog.schema -ne 'oxforms.office_oracle.w006_terminate_lifetime_event_log.v1') {
        throw "Unexpected event log schema: $($eventLog.schema)"
    }

    $blockerText = (@($manifest.blockers) + @($eventLog.blockers) | ConvertTo-Json -Depth 20)
    $modelessCloseBlocked = $blockerText.IndexOf('modeless_system_close_held_release', [System.StringComparison]::OrdinalIgnoreCase) -ge 0
    if ($manifest.artifacts.modeless_close_window_capture_manifest -eq $null -or [string]::IsNullOrWhiteSpace([string]$manifest.artifacts.modeless_close_window_capture_manifest)) {
        if (-not $modelessCloseBlocked) {
            throw 'Captured manifest must preserve modeless close window capture manifest, or name a modeless_system_close_held_release blocker.'
        }
    } else {
        Assert-RepoArtifactExists -RepoRelativePath $manifest.artifacts.modeless_close_window_capture_manifest -Description 'modeless close window capture manifest' | Out-Null
    }

    Assert-SeparatedEvidenceSections -Value $eventLog -Description 'event log'
    if ([int]$eventLog.observed_facts.row_count -le 0) {
        throw 'Captured event log must contain rows.'
    }
    foreach ($scenario in $requiredScenarios) {
        if ($scenario -notin @($eventLog.observed_facts.scenarios) -and $blockerText.IndexOf($scenario, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw "Event log is missing required scenario '$scenario' and no blocker names it."
        }
    }

    $terminateRows = @($eventLog.observed_facts.terminate_rows)
    if ($terminateRows.Count -eq 0 -and @($manifest.blockers).Count -eq 0) {
        throw 'Captured evidence has no Terminate rows and no blocker explaining why Terminate could not be observed.'
    }
    foreach ($row in $terminateRows) {
        foreach ($field in @('sequence', 'scenario', 'instance_id', 'local_ref_state', 'held_ref_state', 'default_instance_state', 'release_phase')) {
            if ([string]::IsNullOrWhiteSpace([string]$row.$field)) {
                throw "Terminate row is missing reference-state field '$field': $($row | ConvertTo-Json -Compress)"
            }
        }
    }

    $summaryText = ($eventLog.observed_facts.scenario_summaries | ConvertTo-Json -Depth 20)
    foreach ($needle in @('hide_held_release', 'unload_held_release', 'modeless_system_close_held_release', 'modal_hide_return_held_release', 'modal_unload_return_held_release', 'terminate_reference_states', 'query_close')) {
        Assert-ContainsText -Haystack $summaryText -Needle $needle -Description 'scenario summaries'
    }
}

Assert-ChecksumFile -ResolvedCaptureDir $resolvedCaptureDir

Write-Host "W006 Terminate lifetime capture evidence OK: $resolvedCaptureDir"
Write-Host "Status: $($manifest.status)"
