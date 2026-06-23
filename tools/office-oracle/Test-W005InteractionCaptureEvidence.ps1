[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CaptureDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

function Resolve-RepoPath {
    param([string]$Path)

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

function Get-Sha256Hex {
    param([string]$Path)

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

function Assert-File {
    param([string]$Path)

    $fullPath = Resolve-RepoPath $Path
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Expected file does not exist: $Path"
    }

    return $fullPath
}

function Assert-CaptureChecksumFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$CaptureDir
    )

    try {
        return Assert-File $Path
    } catch {
        if ($Path -match '\\' -or $Path -match '^[A-Za-z]:|^/|^//') {
            throw
        }

        $capturePath = [System.IO.Path]::GetFullPath((Join-Path $CaptureDir $Path))
        $captureWithSeparator = $CaptureDir.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
        if (-not $capturePath.StartsWith($captureWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw
        }
        if (-not (Test-Path -LiteralPath $capturePath -PathType Leaf)) {
            throw
        }

        return $capturePath
    }
}

function Assert-EventCsv {
    param([string]$Path)

    $fullPath = Assert-File $Path
    $firstLine = Get-Content -LiteralPath $fullPath -TotalCount 1
    foreach ($requiredHeader in @('sequence', 'event_name', 'target_name', 'coordinate_space')) {
        if ($firstLine -notmatch ('(^|,)"?' + [regex]::Escape($requiredHeader) + '"?(,|$)')) {
            throw "Event CSV '$Path' is missing expected header '$requiredHeader'. Header: $firstLine"
        }
    }
}

function Assert-EventLog {
    param(
        [string]$Path,
        [string[]]$RequiredEvents
    )

    $fullPath = Assert-File $Path
    $log = Get-Content -Raw -LiteralPath $fullPath | ConvertFrom-Json
    if ($log.schema -ne 'oxforms.office_oracle.w005_interaction_event_log.v1') {
        throw "Unexpected event log schema in $Path"
    }
    if ($log.bead -ne 'oxforms-xvx.3') {
        throw "Unexpected bead in event log $Path"
    }
    if ($null -eq $log.observed_facts -or [int]$log.observed_facts.row_count -le 0) {
        throw "Event log has no observed rows: $Path"
    }
    if ($null -eq $log.assumptions -or @($log.assumptions).Count -eq 0) {
        throw "Event log must separate assumptions from observed facts: $Path"
    }
    if ($null -eq $log.manual_inputs) {
        throw "Event log must include manual_inputs, even when empty: $Path"
    }

    $eventNames = @($log.observed_facts.event_names)
    foreach ($eventName in $RequiredEvents) {
        if ($eventName -notin $eventNames) {
            throw "Event log '$Path' is missing expected observed event '$eventName'. Observed: $($eventNames -join ', ')"
        }
    }

    return $log
}

function Assert-TargetEventCounts {
    param(
        [object]$Log,
        [string]$TargetName,
        [hashtable]$RequiredMinimums
    )

    $rows = @($Log.observed_facts.event_rows | Where-Object { $_.target_name -eq $TargetName })
    if ($rows.Count -eq 0) {
        throw "Event log '$($Log.source.workbook)' has no observed rows for target '$TargetName'."
    }

    foreach ($eventName in $RequiredMinimums.Keys) {
        $actual = @($rows | Where-Object { $_.event_name -eq $eventName }).Count
        $minimum = [int]$RequiredMinimums[$eventName]
        if ($actual -lt $minimum) {
            throw "Event log '$($Log.source.workbook)' target '$TargetName' has $actual '$eventName' rows; expected at least $minimum."
        }

        $countRows = @($Log.observed_facts.target_event_counts | Where-Object {
            $_.target_name -eq $TargetName -and $_.event_name -eq $eventName
        })
        if ($countRows.Count -ne 1 -or [int]$countRows[0].row_count -ne $actual) {
            throw "Event log '$($Log.source.workbook)' target_event_counts does not match observed rows for '$TargetName'/'$eventName'."
        }
    }
}

function Assert-CoordinateCalibration {
    param(
        [string]$Path,
        [object]$Fixture
    )

    $fullPath = Assert-File $Path
    $calibration = Get-Content -Raw -LiteralPath $fullPath | ConvertFrom-Json
    if ($calibration.schema -ne 'oxforms.office_oracle.w005_coordinate_calibration.v1') {
        throw "Unexpected coordinate calibration schema in $Path"
    }
    if ($calibration.bead -ne 'oxforms-xvx.3') {
        throw "Unexpected bead in coordinate calibration $Path"
    }
    if ($calibration.label_rect_source -eq 'exact_border_color_region' -or $calibration.label_rect_source -like 'fallback*') {
        throw "Coordinate calibration '$Path' uses unscoped or fallback label_rect_source '$($calibration.label_rect_source)'."
    }
    if ($calibration.label_rect_source -notin @(
        'exact_border_color_region_scoped_to_label_fill_neighborhood',
        'derived_from_exact_fill_region_expanded_by_known_single_border_pixels'
    )) {
        throw "Coordinate calibration '$Path' has unknown label_rect_source '$($calibration.label_rect_source)'."
    }

    $fill = $calibration.label_fill_rect_screenshot_pixels
    $border = $calibration.label_border_rect_screenshot_pixels
    if ($null -eq $fill -or $null -eq $border) {
        throw "Coordinate calibration '$Path' must include fill and border rectangles."
    }
    if ([int]$border.x -gt [int]$fill.x -or [int]$border.y -gt [int]$fill.y -or
        ([int]$border.x + [int]$border.width) -lt ([int]$fill.x + [int]$fill.width) -or
        ([int]$border.y + [int]$border.height) -lt ([int]$fill.y + [int]$fill.height)) {
        throw "Coordinate calibration '$Path' label border rectangle does not contain the fill rectangle."
    }

    $label = @($Fixture.controls | Where-Object { $_.name -eq 'OracleProbeLabel' })
    if ($label.Count -ne 1) {
        throw 'Fixture must define exactly one OracleProbeLabel for calibration validation.'
    }

    $scale = [double]$calibration.points_to_pixels
    $expectedWidth = [int][Math]::Round([double]$label[0].widthPt * $scale)
    $expectedHeight = [int][Math]::Round([double]$label[0].heightPt * $scale)
    if ([Math]::Abs([int]$border.width - $expectedWidth) -gt 2 -or [Math]::Abs([int]$border.height - $expectedHeight) -gt 2) {
        throw "Coordinate calibration '$Path' label border dimensions $($border.width)x$($border.height) do not match fixture-derived size near ${expectedWidth}x$expectedHeight."
    }

    $expectedOriginX = [double]$border.x - ([double]$label[0].leftPt * $scale)
    $expectedOriginY = [double]$border.y - ([double]$label[0].topPt * $scale)
    if ([Math]::Abs([double]$calibration.form_origin_screenshot_pixels.x - $expectedOriginX) -gt 0.0001 -or
        [Math]::Abs([double]$calibration.form_origin_screenshot_pixels.y - $expectedOriginY) -gt 0.0001) {
        throw "Coordinate calibration '$Path' form origin is inconsistent with the label border rectangle and fixture point geometry."
    }

    if ($null -eq $calibration.label_border_search_rect_screenshot_pixels) {
        throw "Coordinate calibration '$Path' must record the scoped border search rectangle."
    }
    if ($calibration.label_rect_source -eq 'exact_border_color_region_scoped_to_label_fill_neighborhood' -and
        $null -eq $calibration.rejected_global_border_color_region_screenshot_pixels) {
        throw "Coordinate calibration '$Path' must record the rejected unscoped global border-color diagnostic."
    }

    return $calibration
}

function Assert-InputActions {
    param(
        [string]$Path,
        [object]$Calibration,
        [object]$Fixture
    )

    $fullPath = Assert-File $Path
    $actions = Get-Content -Raw -LiteralPath $fullPath | ConvertFrom-Json
    if ($actions.schema -ne 'oxforms.office_oracle.w005_input_actions.v1') {
        throw "Unexpected input actions schema in $Path"
    }
    if ($actions.bead -ne 'oxforms-xvx.3') {
        throw "Unexpected bead in input actions $Path"
    }
    if ($null -eq $actions.manual_inputs) {
        throw "Input actions must include manual_inputs, even when empty: $Path"
    }
    if ($null -eq $actions.automated_inputs -or @($actions.automated_inputs).Count -eq 0) {
        throw "Input actions must include automated_inputs: $Path"
    }

    $label = @($Fixture.controls | Where-Object { $_.name -eq 'OracleProbeLabel' })
    if ($label.Count -ne 1) {
        throw 'Fixture must define exactly one OracleProbeLabel for input-action validation.'
    }

    $scale = [double]$Calibration.points_to_pixels
    $expectedCenterX = [double]$Calibration.form_origin_screenshot_pixels.x + (([double]$label[0].leftPt + ([double]$label[0].widthPt * 0.5)) * $scale)
    $expectedCenterY = [double]$Calibration.form_origin_screenshot_pixels.y + (([double]$label[0].topPt + ([double]$label[0].heightPt * 0.5)) * $scale)

    $centerActions = @($actions.automated_inputs | Where-Object {
        $_.target_intent -eq 'OracleProbeLabel center' -and $_.action -eq 'click'
    })
    if ($centerActions.Count -ne 1) {
        throw "Input actions '$Path' must contain exactly one OracleProbeLabel center click; found $($centerActions.Count)."
    }

    $center = $centerActions[0].screenshot_pixels
    if ($null -eq $center) {
        throw "Input actions '$Path' OracleProbeLabel center click is missing screenshot_pixels."
    }
    if ([Math]::Abs([double]$center.x - $expectedCenterX) -gt 0.001 -or
        [Math]::Abs([double]$center.y - $expectedCenterY) -gt 0.001) {
        throw "Input actions '$Path' OracleProbeLabel center click used screenshot_pixels x=$($center.x) y=$($center.y), expected calibrated x=$expectedCenterX y=$expectedCenterY."
    }
}

$resolvedCaptureDir = Resolve-RepoPath $CaptureDir
$manifestPath = Join-Path $resolvedCaptureDir 'oracle-capture-manifest.json'
$checksumPath = Join-Path $resolvedCaptureDir 'checksums.sha256'

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Manifest not found: $manifestPath"
}
if (-not (Test-Path -LiteralPath $checksumPath -PathType Leaf)) {
    throw "Checksum file not found: $checksumPath"
}

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
if ($manifest.schema -ne 'oxforms.office_oracle.w005_interaction_event_capture.v1') {
    throw "Unexpected capture manifest schema: $($manifest.schema)"
}
if ($manifest.bead -ne 'oxforms-xvx.3') {
    throw "Unexpected bead in manifest: $($manifest.bead)"
}
if ($manifest.fixture.id -ne 'excel-msforms-w005-interaction-events-v1') {
    throw "Unexpected fixture id: $($manifest.fixture.id)"
}
if ($null -eq $manifest.warnings -or @($manifest.warnings).Count -eq 0) {
    throw 'Manifest must include warnings/non-claims.'
}
if (($manifest.warnings -join "`n") -notmatch 'not an exhaustive MSForms event parity claim') {
    throw 'Manifest must explicitly avoid exhaustive parity claims.'
}

$captureRootRelative = "docs/evidence/W005_input_interaction_model_exploration/captures/$($manifest.capture_id)"
$fixtureManifestPath = Assert-File $manifest.fixture.inputs.manifest.path
$fixture = Get-Content -Raw -LiteralPath $fixtureManifestPath | ConvertFrom-Json

$artifactPaths = @(
    $manifest.artifacts.generated_workbook.path,
    $manifest.artifacts.run_summary,
    $manifest.artifacts.modeless.window_capture_manifest,
    $manifest.artifacts.modeless.screenshot,
    $manifest.artifacts.modeless.coordinate_calibration,
    $manifest.artifacts.modeless.input_actions,
    $manifest.artifacts.modeless.event_log_json,
    $manifest.artifacts.modeless.event_log_csv,
    "$captureRootRelative/README.md",
    "$captureRootRelative/oracle-capture-manifest.json"
)

foreach ($path in $artifactPaths) {
    [void](Assert-File $path)
}

$commandLogs = @($manifest.artifacts.command_logs)
if ($commandLogs.Count -lt 4) {
    throw "Manifest must list command stdout/stderr logs; found $($commandLogs.Count)."
}
foreach ($path in $commandLogs) {
    [void](Assert-File $path)
}

$modelessLog = Assert-EventLog -Path $manifest.artifacts.modeless.event_log_json -RequiredEvents @('Initialize', 'MouseDown', 'MouseUp', 'Click', 'Change', 'KeyDown', 'KeyPress', 'KeyUp', 'Enter', 'Exit', 'QueryClose')
[void](Assert-EventCsv -Path $manifest.artifacts.modeless.event_log_csv)
$modelessCalibration = Assert-CoordinateCalibration -Path $manifest.artifacts.modeless.coordinate_calibration -Fixture $fixture
[void](Assert-InputActions -Path $manifest.artifacts.modeless.input_actions -Calibration $modelessCalibration -Fixture $fixture)
Assert-TargetEventCounts -Log $modelessLog -TargetName 'OracleProbeLabel' -RequiredMinimums @{
    MouseMove = 1
    MouseDown = 1
    MouseUp = 1
    Click = 1
}

if ($null -ne $manifest.artifacts.modal) {
    [void](Assert-File $manifest.artifacts.modal.window_capture_manifest)
    [void](Assert-File $manifest.artifacts.modal.screenshot)
    [void](Assert-File $manifest.artifacts.modal.coordinate_calibration)
    [void](Assert-File $manifest.artifacts.modal.input_actions)
    [void](Assert-File $manifest.artifacts.modal.event_log_json)
    [void](Assert-File $manifest.artifacts.modal.event_log_csv)
    $modalLog = Assert-EventLog -Path $manifest.artifacts.modal.event_log_json -RequiredEvents @('Initialize', 'MouseDown', 'MouseUp', 'Click', 'Change', 'KeyDown', 'KeyPress', 'KeyUp', 'Enter', 'Exit', 'QueryClose')
    [void](Assert-EventCsv -Path $manifest.artifacts.modal.event_log_csv)
    $modalCalibration = Assert-CoordinateCalibration -Path $manifest.artifacts.modal.coordinate_calibration -Fixture $fixture
    [void](Assert-InputActions -Path $manifest.artifacts.modal.input_actions -Calibration $modalCalibration -Fixture $fixture)
    Assert-TargetEventCounts -Log $modalLog -TargetName 'OracleProbeLabel' -RequiredMinimums @{
        MouseMove = 1
        MouseDown = 1
        MouseUp = 1
        Click = 1
    }
}

$checksumLines = Get-Content -LiteralPath $checksumPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
if ($checksumLines.Count -eq 0) {
    throw 'Checksum file is empty.'
}

foreach ($line in $checksumLines) {
    if ($line -notmatch '^([0-9a-f]{64})\s\s(.+)$') {
        throw "Malformed checksum line: $line"
    }

    $expectedHash = $Matches[1]
    $relativePath = $Matches[2]
    $fullPath = Assert-CaptureChecksumFile -Path $relativePath -CaptureDir $resolvedCaptureDir
    $actualHash = Get-Sha256Hex -Path $fullPath
    if ($actualHash -ne $expectedHash) {
        throw "Checksum mismatch for '$relativePath': expected $expectedHash, got $actualHash"
    }
}

Write-Host "W005 interaction capture evidence check: ok"
Write-Host "Capture: $($manifest.capture_id)"
Write-Host "Checksum entries: $($checksumLines.Count)"
