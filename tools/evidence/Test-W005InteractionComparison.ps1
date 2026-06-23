[CmdletBinding()]
param(
    [string]$ManifestPath = 'docs\evidence\W005_input_interaction_model_exploration\comparisons\interaction-events-modeless-vs-headless-probe.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$comparisonRoot = (Resolve-Path -LiteralPath (Join-Path $repoRoot 'docs\evidence\W005_input_interaction_model_exploration\comparisons')).Path
$allowedClassifications = @('implemented_match', 'known_gap', 'uncertain_oracle', 'out_of_scope')

function Resolve-RepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'Path value is empty.'
    }

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

function Assert-ComparisonPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = Resolve-RepoPath -Path $Path
    $comparisonWithSeparator = $comparisonRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not ($fullPath.Equals($comparisonRoot, [System.StringComparison]::OrdinalIgnoreCase) -or $fullPath.StartsWith($comparisonWithSeparator, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Manifest path '$Path' is outside comparison root '$comparisonRoot'."
    }

    return $fullPath
}

function Get-PropertyValue {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Assert-Classification {
    param(
        [Parameter(Mandatory = $true)][object]$Row,
        [Parameter(Mandatory = $true)][string]$SectionName
    )

    $classification = Get-PropertyValue -Object $Row -Name 'classification'
    if ([string]::IsNullOrWhiteSpace($classification)) {
        throw "$SectionName row is missing classification."
    }
    if ($allowedClassifications -notcontains $classification) {
        throw "$SectionName row has invalid classification '$classification'."
    }

    $summary = Get-PropertyValue -Object $Row -Name 'summary'
    if ([string]::IsNullOrWhiteSpace($summary)) {
        throw "$SectionName row '$classification' is missing summary."
    }
}

$resolvedManifest = Assert-ComparisonPath -Path $ManifestPath
if (-not (Test-Path -LiteralPath $resolvedManifest -PathType Leaf)) {
    throw "Comparison manifest '$resolvedManifest' does not exist."
}

$manifest = Get-Content -Raw -LiteralPath $resolvedManifest | ConvertFrom-Json

if ($manifest.schema -ne 'oxforms.w005.interaction_comparison_manifest.v1') {
    throw "Unexpected schema '$($manifest.schema)'."
}
if ($manifest.schema_version -ne 1) {
    throw "Unexpected schema_version '$($manifest.schema_version)'."
}
if ($manifest.bead -ne 'oxforms-xvx.13') {
    throw "Unexpected bead '$($manifest.bead)'."
}
if ($manifest.status -ne 'observation_only') {
    throw "Unexpected status '$($manifest.status)'."
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
if ($evidenceFiles.Count -lt 2) {
    throw 'evidence_files must list both MSForms and OxForms inputs.'
}

$roles = @{}
$checked = 0
foreach ($entry in $evidenceFiles) {
    $role = Get-PropertyValue -Object $entry -Name 'role'
    $path = Get-PropertyValue -Object $entry -Name 'path'
    $expectedHash = Get-PropertyValue -Object $entry -Name 'sha256'

    if ([string]::IsNullOrWhiteSpace($role)) {
        throw 'Each evidence_files entry requires role.'
    }
    if ($roles.ContainsKey($role)) {
        throw "Duplicate evidence_files role '$role'."
    }
    $roles[$role] = $true

    if ([string]::IsNullOrWhiteSpace($path)) {
        throw "Evidence entry '$role' requires path."
    }
    if ([string]::IsNullOrWhiteSpace($expectedHash)) {
        throw "Evidence entry '$role' requires sha256."
    }

    $resolvedPath = Resolve-RepoPath -Path $path
    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        throw "Evidence path '$path' for role '$role' does not exist."
    }

    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedPath).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash.ToLowerInvariant()) {
        throw "SHA-256 mismatch for '$path': expected $expectedHash, got $actualHash."
    }

    $checked++
}

foreach ($requiredRole in @('msforms_modeless_event_log_json', 'oxforms_headless_replay_golden', 'oxforms_headless_display_list_golden')) {
    if (-not $roles.ContainsKey($requiredRole)) {
        throw "Required evidence role '$requiredRole' is missing."
    }
}

foreach ($sectionName in @('event_order_comparison', 'argument_and_metadata_comparison', 'coordinate_lifecycle_render_notes')) {
    $sectionRows = @(Get-PropertyValue -Object $manifest -Name $sectionName)
    if ($sectionRows.Count -eq 0) {
        throw "Section '$sectionName' must not be empty."
    }
    foreach ($row in $sectionRows) {
        Assert-Classification -Row $row -SectionName $sectionName
    }
}

$allRows = @()
$allRows += @(Get-PropertyValue -Object $manifest -Name 'event_order_comparison')
$allRows += @(Get-PropertyValue -Object $manifest -Name 'argument_and_metadata_comparison')
$allRows += @(Get-PropertyValue -Object $manifest -Name 'coordinate_lifecycle_render_notes')
$classificationsSeen = @{}
foreach ($row in $allRows) {
    $classificationsSeen[$row.classification] = $true
}
foreach ($requiredClassification in $allowedClassifications) {
    if (-not $classificationsSeen.ContainsKey($requiredClassification)) {
        throw "Classification '$requiredClassification' is not represented."
    }
}

$followUps = @(Get-PropertyValue -Object $manifest -Name 'follow_up_beads')
foreach ($requiredBead in @('oxforms-9pr', 'oxforms-xvx.20', 'oxforms-xvx.21')) {
    if (-not ($followUps | Where-Object { $_.id -eq $requiredBead })) {
        throw "Required follow-up bead '$requiredBead' is missing."
    }
}

Write-Host 'W005 interaction comparison manifest check: ok'
Write-Host "Manifest: $ManifestPath"
Write-Host "Evidence files checked: $checked"
