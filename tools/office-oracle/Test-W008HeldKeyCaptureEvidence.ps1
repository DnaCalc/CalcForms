[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$CaptureDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

$manifestSchema = 'oxforms.office_oracle.w008_held_key_capture.v1'
$eventLogSchema = 'oxforms.office_oracle.w008_held_key_event_log.v1'
$runSummarySchema = 'oxforms.office_oracle.w008_held_key_run_summary.v1'
$expectedBead = 'oxforms-esq.12'
$declaredScenarios = @('held_space_checkbox', 'held_enter_default')

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

function Assert-RepoArtifactExists {
    param([Parameter(Mandatory = $true)][string]$RepoRelativePath, [Parameter(Mandatory = $true)][string]$Description)
    $path = Resolve-RepoPath $RepoRelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "$Description does not exist: $RepoRelativePath" }
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
if ($manifest.schema -ne $manifestSchema) { throw "Unexpected manifest schema: $($manifest.schema)" }
if ($manifest.bead -ne $expectedBead) { throw "Unexpected manifest bead: $($manifest.bead)" }
if ($manifest.status -notin @('captured', 'blocked')) { throw "Unexpected manifest status: $($manifest.status)" }

Assert-RepoArtifactHash -Artifact $manifest.fixture.inputs.manifest -Description 'fixture manifest'
Assert-RepoArtifactHash -Artifact $manifest.fixture.inputs.form_code_behind -Description 'form code-behind source'
Assert-RepoArtifactHash -Artifact $manifest.fixture.inputs.standard_module -Description 'standard module source'
Assert-RepoArtifactHash -Artifact $manifest.fixture.inputs.capture_tool -Description 'capture tool source'

if ($null -ne $manifest.artifacts.generated_workbook) {
    Assert-RepoArtifactHash -Artifact $manifest.artifacts.generated_workbook -Description 'generated workbook'
}
Assert-RepoArtifactExists -RepoRelativePath $manifest.artifacts.run_summary -Description 'run summary'
Assert-RepoArtifactExists -RepoRelativePath $manifest.artifacts.input_actions -Description 'input actions'

$runSummary = Get-JsonFile -Path (Resolve-RepoPath $manifest.artifacts.run_summary)
if ($runSummary.schema -ne $runSummarySchema) { throw "Unexpected run summary schema: $($runSummary.schema)" }
if ($runSummary.bead -ne $expectedBead) { throw "Unexpected run summary bead: $($runSummary.bead)" }

$inputActions = Get-JsonFile -Path (Resolve-RepoPath $manifest.artifacts.input_actions)
if ($null -eq $inputActions.manual_inputs) { throw 'input-actions.json must preserve manual_inputs, even when empty.' }

if ($manifest.status -eq 'blocked') {
    $blocker = Get-JsonFile -Path (Join-Path $resolvedCaptureDir 'blocker.json')
    if ($blocker.status -ne 'blocked') { throw "Expected blocker status=blocked; got $($blocker.status)" }
    if ($runSummary.status -ne 'blocked') { throw "Expected blocked run summary status=blocked; got $($runSummary.status)" }
    if ([int]$runSummary.row_count -ne 0) { throw "Blocked run summary must have row_count=0; got $($runSummary.row_count)" }
} else {
    Assert-RepoArtifactExists -RepoRelativePath $manifest.artifacts.event_log_json -Description 'event log json'
    Assert-RepoArtifactExists -RepoRelativePath $manifest.artifacts.event_log_csv -Description 'event log csv'
    $eventLog = Get-JsonFile -Path (Resolve-RepoPath $manifest.artifacts.event_log_json)
    if ($eventLog.schema -ne $eventLogSchema) { throw "Unexpected event log schema: $($eventLog.schema)" }
    if ($eventLog.bead -ne $expectedBead) { throw "Unexpected event log bead: $($eventLog.bead)" }
    if ([int]$eventLog.observed_facts.row_count -le 0) { throw 'Captured evidence must contain at least one observed row.' }
    $observedScenarios = @($eventLog.observed_facts.scenarios)
    foreach ($scenario in $declaredScenarios) {
        if ($scenario -notin $observedScenarios) {
            throw "Captured event log is missing declared scenario: $scenario"
        }
    }
}

Assert-ChecksumFile -ResolvedCaptureDir $resolvedCaptureDir

Write-Host "W008 held-key capture evidence OK: $resolvedCaptureDir"
