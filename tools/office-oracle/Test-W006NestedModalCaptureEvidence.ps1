[CmdletBinding()]
param(
    [string]$CaptureDir = 'docs\evidence\W006_control_implementation_rollout\captures\nested-modal-lifecycle-20260623T120737Z'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

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

function Assert-RepoArtifactExists {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRelativePath,
        [Parameter(Mandatory = $true)][string]$Description
    )

    $path = Resolve-RepoPath $RepoRelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "$Description does not exist: $RepoRelativePath"
    }
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

    $path = Resolve-RepoPath ([string]$Artifact.path)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "$Description does not exist: $($Artifact.path)"
    }

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

    foreach ($line in Get-Content -LiteralPath $checksumPath) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        if ($line -notmatch '^([0-9a-fA-F]{64})  (.+)$') {
            throw "Malformed checksum line: $line"
        }
        $expected = $matches[1].ToLowerInvariant()
        $relative = $matches[2]
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

$resolvedCaptureDir = Resolve-RepoPath $CaptureDir
if (-not (Test-Path -LiteralPath $resolvedCaptureDir -PathType Container)) {
    throw "Capture directory not found: $resolvedCaptureDir"
}

$manifest = Get-JsonFile -Path (Join-Path $resolvedCaptureDir 'oracle-capture-manifest.json')
if ($manifest.schema -ne 'oxforms.office_oracle.w006_nested_modal_lifecycle_capture.v1') {
    throw "Unexpected manifest schema: $($manifest.schema)"
}
if ($manifest.bead -ne 'oxforms-0a0.19') {
    throw "Unexpected manifest bead: $($manifest.bead)"
}
if ($manifest.status -notin @('captured', 'blocked')) {
    throw "Unexpected manifest status: $($manifest.status)"
}

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
Assert-ContainsText -Haystack $traceText -Needle 'parent_row_id' -Description 'trace/replay implications'
Assert-ContainsText -Haystack $traceText -Needle 'nesting_depth' -Description 'trace/replay implications'
Assert-ContainsText -Haystack $traceText -Needle 'lifecycle_pump' -Description 'trace/replay implications'
Assert-ContainsText -Haystack $traceText -Needle 'effect_requested' -Description 'trace/replay implications'
Assert-ContainsText -Haystack $traceText -Needle 'effect_completed' -Description 'trace/replay implications'

$warningText = (@($manifest.warnings) + @($manifest.non_claims)) -join "`n"
Assert-ContainsText -Haystack $warningText -Needle 'Missing event rows are unobserved' -Description 'warning/non-claim text'
Assert-ContainsText -Haystack $warningText -Needle 'No OxForms runtime' -Description 'warning/non-claim text'

$inputActions = Get-JsonFile -Path (Join-Path $resolvedCaptureDir 'input-actions.json')
if ($null -eq $inputActions.manual_inputs) {
    throw 'input-actions.json must preserve manual_inputs, even when empty.'
}

$runSummaryPath = Resolve-RepoPath $manifest.artifacts.run_summary
$runSummary = Get-JsonFile -Path $runSummaryPath
if ($runSummary.schema -ne 'oxforms.office_oracle.w006_nested_modal_run_summary.v1') {
    throw "Unexpected run summary schema: $($runSummary.schema)"
}
if ($runSummary.bead -ne 'oxforms-0a0.19') {
    throw "Unexpected run summary bead: $($runSummary.bead)"
}

if ($manifest.status -eq 'blocked') {
    $blocker = Get-JsonFile -Path (Join-Path $resolvedCaptureDir 'blocker.json')
    if ($blocker.status -ne 'blocked') {
        throw "Expected blocker status=blocked; got $($blocker.status)"
    }
    if ($runSummary.status -ne 'blocked') {
        throw "Expected blocked run summary status=blocked; got $($runSummary.status)"
    }
    if ([int]$runSummary.row_count -ne 0) {
        throw "Blocked run summary must have row_count=0; got $($runSummary.row_count)"
    }
    foreach ($field in @('event sequence', 'outer and inner form identity', 'show mode', 'active form/window/control', 'close origin', 'QueryClose Cancel before and after values', 'CloseMode', 'hide/unload/Terminate rows')) {
        if ($field -notin @($blocker.blocked_recording_fields)) {
            throw "Blocked evidence is missing recording field: $field"
        }
    }
} else {
    $eventLogPath = Resolve-RepoPath $manifest.artifacts.event_log_json
    $eventLog = Get-JsonFile -Path $eventLogPath
    if ([int]$eventLog.observed_facts.row_count -le 0) {
        throw 'Captured evidence must contain at least one observed row.'
    }
    foreach ($identity in @('outer', 'inner')) {
        if ($identity -notin @($eventLog.observed_facts.form_identities)) {
            throw "Captured event log is missing form identity: $identity"
        }
    }
}

Assert-ChecksumFile -ResolvedCaptureDir $resolvedCaptureDir

Write-Host "W006 nested modal capture evidence OK: $resolvedCaptureDir"
