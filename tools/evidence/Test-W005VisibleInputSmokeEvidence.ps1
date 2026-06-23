[CmdletBinding()]
param(
    [string]$CaptureDir = 'docs\evidence\W005_input_interaction_model_exploration\captures\visible-input-smoke-20260623T035500Z'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$allowedCoordinateSpaces = @(
    'screen_pixels',
    'window_rect',
    'screenshot_pixels',
    'client_pixels',
    'form_logical',
    'control_local',
    'display_list_logical',
    'msforms_event_args',
    'raw_diagnostic'
)

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
        throw "$Context must be repository-relative, got '$Path'."
    }
    if ($Path -match '\\') {
        throw "$Context must use forward slashes, got '$Path'."
    }
    if ($Path -split '/' | Where-Object { $_ -eq '' -or $_ -eq '.' -or $_ -eq '..' }) {
        throw "$Context contains an invalid path segment: '$Path'."
    }
}

function Assert-File {
    param([Parameter(Mandatory = $true)][string]$Path)

    Assert-RepoRelativeArtifactPath -Path $Path -Context 'artifact path'
    $fullPath = Resolve-RepoPath -Path $Path
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Expected file does not exist: $Path"
    }

    return $fullPath
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

function Get-PropertyValue {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

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

function Assert-CoordinateVocabulary {
    param(
        [Parameter(Mandatory = $true)][object[]]$Spaces,
        [Parameter(Mandatory = $true)][string]$Context,
        [string[]]$RequiredSpaces = @()
    )

    if ($Spaces.Count -eq 0) {
        throw "$Context must list coordinate spaces."
    }
    foreach ($space in $Spaces) {
        if ($allowedCoordinateSpaces -notcontains [string]$space) {
            throw "$Context contains unknown coordinate space '$space'."
        }
    }
    foreach ($requiredSpace in $RequiredSpaces) {
        if ($Spaces -notcontains $requiredSpace) {
            throw "$Context is missing required coordinate space '$requiredSpace'."
        }
    }
}

function Assert-CleanRoomPosture {
    param([Parameter(Mandatory = $true)][object]$Manifest)

    $cleanRoom = Get-PropertyValue -Object $Manifest -Name 'clean_room'
    if ($null -eq $cleanRoom) {
        throw 'Manifest clean_room is required.'
    }
    Assert-NonEmptyString -Value (Get-PropertyValue -Object $cleanRoom -Name 'source') -Name 'clean_room.source'
    Assert-NonEmptyString -Value (Get-PropertyValue -Object $cleanRoom -Name 'prohibited') -Name 'clean_room.prohibited'
    if ([string](Get-PropertyValue -Object $cleanRoom -Name 'prohibited') -notmatch 'No Office internals') {
        throw 'clean_room.prohibited must explicitly exclude Office internals.'
    }

    $nonClaims = @(Get-PropertyValue -Object $Manifest -Name 'non_claims')
    if ($nonClaims.Count -eq 0) {
        throw 'Manifest non_claims must list visible-smoke limits.'
    }
    if (($nonClaims -join "`n") -notmatch 'not final host/runtime architecture|not claim full UserForm\.Show') {
        throw 'Manifest non_claims must explicitly avoid runtime/UserForm parity claims.'
    }
}

function Assert-ActionCoordinates {
    param(
        [object]$Action,
        [string]$Context
    )

    $coordinates = Get-PropertyValue -Object $Action -Name 'coordinates'
    if ($null -eq $coordinates) {
        return
    }

    foreach ($space in @('form_logical', 'client_pixels', 'screen_pixels')) {
        $point = Get-PropertyValue -Object $coordinates -Name $space
        if ($null -eq $point) {
            throw "$Context coordinates must include $space."
        }
        if ($null -eq (Get-PropertyValue -Object $point -Name 'x') -or $null -eq (Get-PropertyValue -Object $point -Name 'y')) {
            throw "$Context $space point must include x and y."
        }
    }
}

$resolvedCaptureDir = Resolve-RepoPath -Path $CaptureDir
if (-not (Test-Path -LiteralPath $resolvedCaptureDir -PathType Container)) {
    throw "Visible smoke capture directory not found: $resolvedCaptureDir"
}

$manifestPath = Join-Path $resolvedCaptureDir 'visible-input-smoke-manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Visible smoke manifest not found: $manifestPath"
}

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
if ($manifest.schema -ne 'oxforms.w005.visible_input_smoke_capture.v1') {
    throw "Unexpected visible smoke manifest schema '$($manifest.schema)'."
}
Assert-NonEmptyString -Value $manifest.bead -Name 'manifest.bead'
Assert-NonEmptyString -Value $manifest.capture_id -Name 'manifest.capture_id'
Assert-CleanRoomPosture -Manifest $manifest

$requiredArtifacts = @(
    $manifest.artifacts.trace,
    $manifest.artifacts.input_actions,
    $manifest.artifacts.window_capture_manifest,
    $manifest.artifacts.screenshot,
    $manifest.artifacts.frame_ppm
)
foreach ($path in $requiredArtifacts) {
    [void](Assert-File $path)
}

$commandPaths = @(
    $manifest.commands.build,
    $manifest.commands.run,
    $manifest.commands.capture_window
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
foreach ($path in $commandPaths) {
    [void](Assert-File $path)
}

$commandLogs = @($manifest.artifacts.command_logs)
if ($commandLogs.Count -lt 6) {
    throw "Visible smoke manifest must list stdout/stderr command logs; found $($commandLogs.Count)."
}
foreach ($path in $commandLogs) {
    [void](Assert-File $path)
}

$tracePath = Assert-File $manifest.artifacts.trace
$trace = Get-Content -Raw -LiteralPath $tracePath | ConvertFrom-Json
if ($trace.schema -ne 'oxforms.w005.visible_input_smoke.v1') {
    throw "Unexpected visible input trace schema '$($trace.schema)'."
}
Assert-NonEmptyString -Value $trace.bead -Name 'trace.bead'
if ([int]$trace.coverage.ui_event_count -le 0) {
    throw 'Visible input trace coverage.ui_event_count must be positive.'
}
if ([int]$trace.coverage.effect_count -le 0) {
    throw 'Visible input trace coverage.effect_count must be positive.'
}
Assert-NonEmptyString -Value ([string]$trace.coverage.final_lifecycle) -Name 'trace.coverage.final_lifecycle'

$rowsJson = @($trace.rows) | ConvertTo-Json -Depth 64
foreach ($needle in @('mouse_down', 'mouse_up', 'character_input', 'client_pixels', 'form_logical', 'QueryClose')) {
    if ($rowsJson -notmatch [regex]::Escape($needle)) {
        throw "Visible input trace is missing expected evidence token '$needle'."
    }
}

$actionsPath = Assert-File $manifest.artifacts.input_actions
$actions = Get-Content -Raw -LiteralPath $actionsPath | ConvertFrom-Json
if ($actions.schema -ne 'oxforms.w005.visible_input_actions.v1') {
    throw "Unexpected visible input actions schema '$($actions.schema)'."
}
if ($null -eq $actions.manual_inputs) {
    throw 'Visible input actions must include manual_inputs, even when empty.'
}
Assert-CoordinateVocabulary -Spaces @($actions.coordinate_vocabulary) -Context 'visible input actions' -RequiredSpaces @('screen_pixels', 'client_pixels', 'form_logical')

$lastSequence = 0
$automatedInputs = @($actions.automated_inputs)
if ($automatedInputs.Count -eq 0) {
    throw 'Visible input actions must include automated_inputs.'
}
foreach ($action in $automatedInputs) {
    if ([int]$action.sequence -le $lastSequence) {
        throw 'Visible input action sequences must increase monotonically.'
    }
    $lastSequence = [int]$action.sequence
    if ($action.manual -ne $false) {
        throw "Visible input action sequence $($action.sequence) must preserve manual=false."
    }
    Assert-NonEmptyString -Value ([string]$action.input_method) -Name "input_method for action $($action.sequence)"
    if ($action.action -eq 'click') {
        Assert-ActionCoordinates -Action $action -Context "click action $($action.sequence)"
    }
}

$windowManifestPath = Assert-File $manifest.artifacts.window_capture_manifest
$windowManifest = Get-Content -Raw -LiteralPath $windowManifestPath | ConvertFrom-Json
if ($windowManifest.schema -ne 'oxforms.office_oracle.window_capture.v1') {
    throw "Unexpected visible smoke window manifest schema '$($windowManifest.schema)'."
}
Assert-NonEmptyString -Value ([string]$windowManifest.screenshot.sha256) -Name 'window screenshot sha256'
$screenshotPath = Assert-File $manifest.artifacts.screenshot
$actualScreenshotHash = Get-Sha256Hex -Path $screenshotPath
if ($actualScreenshotHash -ne ([string]$windowManifest.screenshot.sha256).ToLowerInvariant()) {
    throw "Visible smoke screenshot hash mismatch: expected $($windowManifest.screenshot.sha256), got $actualScreenshotHash."
}

Write-Host 'W005 visible input smoke evidence check: ok'
Write-Host "Capture: $($manifest.capture_id)"
Write-Host "Actions checked: $($automatedInputs.Count)"
Write-Host "Trace rows checked: $(@($trace.rows).Count)"
