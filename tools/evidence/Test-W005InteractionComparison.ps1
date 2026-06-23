[CmdletBinding()]
param(
    [string]$ManifestPath = 'docs\evidence\W005_input_interaction_model_exploration\comparisons\interaction-events-modeless-vs-headless-probe.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$comparisonRoot = (Resolve-Path -LiteralPath (Join-Path $repoRoot 'docs\evidence\W005_input_interaction_model_exploration\comparisons')).Path
$allowedClassifications = @('implemented_match', 'known_gap', 'uncertain_oracle', 'out_of_scope')
$reservedVerdictTerms = @('pass', 'passed', 'fail', 'failed', 'failure', 'verdict', 'oracle_pass', 'oracle_fail')

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

function Assert-RepoRelativeArtifactPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Context
    )

    if ([System.IO.Path]::IsPathRooted($Path) -or $Path -match '^[\\/]{1,2}') {
        throw "$Context must be a repository-relative path, got '$Path'."
    }
    if ($Path -match '\\') {
        throw "$Context must use forward slashes, got '$Path'."
    }
    if ($Path -split '/' | Where-Object { $_ -eq '' -or $_ -eq '.' -or $_ -eq '..' }) {
        throw "$Context contains an invalid path segment: '$Path'."
    }
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

function Assert-NonEmptyString {
    param(
        [object]$Value,
        [string]$Name
    )

    if (-not ($Value -is [string]) -or [string]::IsNullOrWhiteSpace($Value)) {
        throw "$Name is required."
    }
}

function Assert-ObservationOnlyPosture {
    param([Parameter(Mandatory = $true)][object]$Manifest)

    if ($Manifest.status -ne 'observation_only') {
        throw "Unexpected status '$($Manifest.status)'; comparison manifests must remain observation_only."
    }

    Assert-NonEmptyString -Value (Get-PropertyValue -Object $Manifest -Name 'purpose') -Name 'purpose'
    $purpose = [string](Get-PropertyValue -Object $Manifest -Name 'purpose')
    if ($purpose -notmatch 'observation' -or $purpose -notmatch 'not a final parity oracle') {
        throw 'purpose must explicitly state that the comparison is observational and not a final parity oracle.'
    }

    $nonClaims = @(Get-PropertyValue -Object $Manifest -Name 'non_claims')
    if ($nonClaims.Count -eq 0) {
        throw 'non_claims must list comparison limits.'
    }
    if (-not (($nonClaims -join "`n") -match 'does not claim full MSForms parity')) {
        throw 'non_claims must explicitly avoid full MSForms parity claims.'
    }

    $vocabulary = @(Get-PropertyValue -Object $Manifest -Name 'classification_vocabulary')
    if ($vocabulary.Count -ne $allowedClassifications.Count) {
        throw "classification_vocabulary must contain exactly the observation classifications: $($allowedClassifications -join ', ')."
    }
    foreach ($classification in $allowedClassifications) {
        if ($vocabulary -notcontains $classification) {
            throw "classification_vocabulary is missing '$classification'."
        }
    }
}

function Assert-NoReservedVerdictFields {
    param(
        [object]$Value,
        [string]$JsonPath
    )

    if ($null -eq $Value) {
        return
    }

    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            if ($reservedVerdictTerms -contains ([string]$key).ToLowerInvariant()) {
                throw "Comparison manifest contains reserved pass/fail verdict field at ${JsonPath}.$key."
            }
            Assert-NoReservedVerdictFields -Value $Value[$key] -JsonPath "$JsonPath.$key"
        }
        return
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $index = 0
        foreach ($item in $Value) {
            Assert-NoReservedVerdictFields -Value $item -JsonPath "$JsonPath[$index]"
            $index++
        }
        return
    }

    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        foreach ($property in $Value.PSObject.Properties) {
            if ($reservedVerdictTerms -contains $property.Name.ToLowerInvariant()) {
                throw "Comparison manifest contains reserved pass/fail verdict field at ${JsonPath}.$($property.Name)."
            }
            Assert-NoReservedVerdictFields -Value $property.Value -JsonPath "$JsonPath.$($property.Name)"
        }
        return
    }

    # Any other scalar (DateTime, numbers, booleans) has no nested fields and is a
    # leaf. Without this guard, PowerShell 7's ConvertFrom-Json coerces ISO
    # timestamps to [datetime], whose self-similar .Date/.DateTime properties make
    # the property walk recurse forever.
}

function Assert-CleanRoomPosture {
    param([Parameter(Mandatory = $true)][object]$Manifest)

    $cleanRoom = Get-PropertyValue -Object $Manifest -Name 'clean_room'
    if ($null -eq $cleanRoom) {
        throw 'clean_room is required.'
    }
    Assert-NonEmptyString -Value (Get-PropertyValue -Object $cleanRoom -Name 'source') -Name 'clean_room.source'
    Assert-NonEmptyString -Value (Get-PropertyValue -Object $cleanRoom -Name 'prohibited') -Name 'clean_room.prohibited'
    if ([string](Get-PropertyValue -Object $cleanRoom -Name 'prohibited') -notmatch 'No Office internals') {
        throw 'clean_room.prohibited must explicitly exclude Office internals.'
    }
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
Assert-NonEmptyString -Value $manifest.bead -Name 'bead'
Assert-ObservationOnlyPosture -Manifest $manifest
Assert-NoReservedVerdictFields -Value $manifest -JsonPath '$'
Assert-CleanRoomPosture -Manifest $manifest

$linkedReport = Get-PropertyValue -Object $manifest -Name 'linked_report'
if ([string]::IsNullOrWhiteSpace($linkedReport)) {
    throw 'linked_report is required.'
}
Assert-RepoRelativeArtifactPath -Path $linkedReport -Context 'linked_report'
$resolvedReport = Assert-ComparisonPath -Path $linkedReport
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
    Assert-RepoRelativeArtifactPath -Path $path -Context "Evidence entry '$role' path"

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

if (-not (@($roles.Keys | Where-Object { $_ -like 'msforms_*' }).Count -gt 0)) {
    throw 'evidence_files must include at least one msforms_* source evidence role.'
}
if (-not (@($roles.Keys | Where-Object { $_ -like 'oxforms_*' }).Count -gt 0)) {
    throw 'evidence_files must include at least one oxforms_* source evidence role.'
}

if ($manifest.comparison_id -eq 'interaction-events-modeless-vs-headless-probe') {
    foreach ($requiredRole in @('msforms_modeless_event_log_json', 'oxforms_headless_replay_golden', 'oxforms_headless_display_list_golden')) {
        if (-not $roles.ContainsKey($requiredRole)) {
            throw "Required evidence role '$requiredRole' is missing."
        }
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
if ($manifest.comparison_id -eq 'interaction-events-modeless-vs-headless-probe') {
    foreach ($requiredBead in @('oxforms-9pr', 'oxforms-xvx.20', 'oxforms-xvx.21')) {
        if (-not ($followUps | Where-Object { $_.id -eq $requiredBead })) {
            throw "Required follow-up bead '$requiredBead' is missing."
        }
    }
}

Write-Host 'W005 interaction comparison manifest check: ok'
Write-Host "Manifest: $ManifestPath"
Write-Host "Evidence files checked: $checked"
