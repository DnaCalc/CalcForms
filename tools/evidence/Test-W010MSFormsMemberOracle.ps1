[CmdletBinding()]
param(
    [string]$ManifestPath = 'fixtures/office-oracle/excel-msforms/member-probes/representative-v1.json',
    [string]$CaptureDir = 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.5/captures/W010RepresentativeMemberOracleV1',
    [switch]$RequireCurrentLedgerSnapshot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$oracleTool = Join-Path $repoRoot 'tools\office-oracle\msforms_member_oracle.py'
$captureRunner = Join-Path $repoRoot 'tools\office-oracle\Capture-MSFormsMemberOracle.ps1'
$pathPolicyTest = Join-Path $repoRoot 'tools\office-oracle\Test-CaptureWindowOutputPath.ps1'
$watchdogTest = Join-Path $repoRoot 'tools\office-oracle\Test-PrivateProcessWatchdog.ps1'
$checksumTest = Join-Path $repoRoot 'tools\evidence\Test-ChecksumManifest.ps1'

function Resolve-RepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $full = if ([System.IO.Path]::IsPathRooted($Path)) {
        [System.IO.Path]::GetFullPath($Path)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
    }
    $prefix = $repoRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not ($full.Equals($repoRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        $full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Path resolves outside the repository: '$Path'."
    }
    return $full
}

function Invoke-PythonCheck {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    $global:LASTEXITCODE = 0
    $output = & python @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed (exit $LASTEXITCODE): $(@($output) -join [Environment]::NewLine)"
    }
    Write-Host "  [ok] $Label"
}

$manifest = Resolve-RepoPath $ManifestPath
$capture = Resolve-RepoPath $CaptureDir
foreach ($required in @($oracleTool, $captureRunner, $pathPolicyTest, $watchdogTest, $checksumTest, $manifest)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required file is missing: '$required'." }
}

Invoke-PythonCheck 'member-oracle adversarial tests' @(
    '-B', '-m', 'unittest', 'discover',
    '-s', (Join-Path $repoRoot 'tools\office-oracle\tests'),
    '-p', 'test_*.py'
)
Invoke-PythonCheck 'member-oracle manifest' @(
    '-B', $oracleTool, '--repo-root', $repoRoot,
    'validate-manifest', '--manifest', $manifest
)
if ($RequireCurrentLedgerSnapshot) {
    Invoke-PythonCheck 'current-ledger selected-row snapshot' @(
        '-B', $oracleTool, '--repo-root', $repoRoot,
        'verify-current-ledger-snapshot', '--manifest', $manifest
    )
}

& $pathPolicyTest | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Capture-Window path-policy test failed with exit $LASTEXITCODE." }
Write-Host '  [ok] Capture-Window path policy'

& $watchdogTest | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Private-process watchdog test failed with exit $LASTEXITCODE." }
Write-Host '  [ok] exact-process macro watchdog'

$parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
    $captureRunner,
    [ref]$null,
    [ref]$parseErrors
)
if ($parseErrors.Count -ne 0) {
    throw "Capture runner has PowerShell parse errors: $(@($parseErrors | ForEach-Object ToString) -join [Environment]::NewLine)"
}
Write-Host '  [ok] capture-runner PowerShell syntax'

$dryRunOutput = & $captureRunner -ManifestPath $manifest -DryRun 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Capture runner dry run failed (exit $LASTEXITCODE): $(@($dryRunOutput) -join [Environment]::NewLine)"
}
$dryRun = @($dryRunOutput) -join [Environment]::NewLine | ConvertFrom-Json
if ([string]$dryRun.status -cne 'ok' -or [string]$dryRun.mode -cne 'dry_run' -or $dryRun.excel_started -ne $false) {
    throw 'Capture runner dry run did not prove a successful no-Excel preflight.'
}
Write-Host '  [ok] capture-runner no-Excel dry run'

if (-not (Test-Path -LiteralPath $capture -PathType Container)) {
    throw "Canonical member-oracle capture is missing after successful preflight checks: '$capture'."
}

Invoke-PythonCheck 'canonical member-oracle capture replay' @(
    '-B', $oracleTool, '--repo-root', $repoRoot,
    'validate-capture', '--manifest', $manifest, '--capture-dir', $capture
)
& $checksumTest -Directory $capture
if ($LASTEXITCODE -ne 0) { throw "Capture checksum validation failed with exit $LASTEXITCODE." }
Write-Host '  [ok] canonical capture checksums'

Write-Host 'W010 manifest-driven MSForms member-oracle evidence passed without starting Office.'
