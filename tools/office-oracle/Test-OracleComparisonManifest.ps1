[CmdletBinding()]
param(
    [string]$ManifestPath = 'docs\evidence\W003_excel_forms_oracle_capture\comparisons\rectangle-label-vs-w002-smoke.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$comparisonRoot = (Resolve-Path -LiteralPath (Join-Path $repoRoot 'docs\evidence\W003_excel_forms_oracle_capture\comparisons')).Path

function Resolve-RepoPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'Path value is empty.'
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        $fullPath = [System.IO.Path]::GetFullPath($Path)
    }
    else {
        $fullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
    }

    $repoWithSeparator = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    if (-not ($fullPath.Equals($repoRoot, $comparison) -or $fullPath.StartsWith($repoWithSeparator, $comparison))) {
        throw "Path '$Path' resolves outside repository root '$repoRoot'."
    }

    return $fullPath
}

function Assert-ComparisonPath {
    param([string]$Path)

    $fullPath = Resolve-RepoPath -Path $Path
    $comparisonWithSeparator = $comparisonRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    if (-not ($fullPath.Equals($comparisonRoot, $comparison) -or $fullPath.StartsWith($comparisonWithSeparator, $comparison))) {
        throw "Manifest path '$Path' is outside comparison root '$comparisonRoot'."
    }

    return $fullPath
}

function Get-PropertyValue {
    param(
        [object]$Object,
        [string]$Name
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

$resolvedManifest = Assert-ComparisonPath -Path $ManifestPath
if (-not (Test-Path -LiteralPath $resolvedManifest -PathType Leaf)) {
    throw "Comparison manifest '$resolvedManifest' does not exist."
}

$manifest = Get-Content -Raw -LiteralPath $resolvedManifest | ConvertFrom-Json

if ($manifest.schema -ne 'oxforms.office_oracle.comparison_manifest.v1') {
    throw "Unexpected schema '$($manifest.schema)'."
}

if ([string]::IsNullOrWhiteSpace($manifest.comparison_id)) {
    throw 'comparison_id is required.'
}

if ($manifest.status -ne 'calibration_only') {
    throw "Expected status 'calibration_only', got '$($manifest.status)'."
}

$linkedReport = Get-PropertyValue -Object $manifest -Name 'linked_report'
if ([string]::IsNullOrWhiteSpace($linkedReport)) {
    throw 'linked_report is required.'
}

$resolvedReport = Resolve-RepoPath -Path $linkedReport
if (-not (Test-Path -LiteralPath $resolvedReport -PathType Leaf)) {
    throw "Linked report '$linkedReport' does not exist."
}

$evidenceFiles = @(Get-PropertyValue -Object $manifest -Name 'evidence_files')
if ($evidenceFiles.Count -eq 0) {
    throw 'evidence_files must contain at least one file.'
}

$checked = 0
foreach ($entry in $evidenceFiles) {
    $role = Get-PropertyValue -Object $entry -Name 'role'
    $path = Get-PropertyValue -Object $entry -Name 'path'
    if ([string]::IsNullOrWhiteSpace($role)) {
        throw 'Each evidence_files entry requires role.'
    }
    if ([string]::IsNullOrWhiteSpace($path)) {
        throw "Evidence entry '$role' requires path."
    }

    $resolvedPath = Resolve-RepoPath -Path $path
    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        throw "Evidence path '$path' for role '$role' does not exist."
    }

    $expectedHash = Get-PropertyValue -Object $entry -Name 'sha256'
    if (-not [string]::IsNullOrWhiteSpace($expectedHash)) {
        $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedPath).Hash.ToLowerInvariant()
        if ($actualHash -ne $expectedHash.ToLowerInvariant()) {
            throw "SHA-256 mismatch for '$path': expected $expectedHash, got $actualHash."
        }
    }

    $checked++
}

Write-Host "Oracle comparison manifest check: ok"
Write-Host "Manifest: $ManifestPath"
Write-Host "Evidence files checked: $checked"
