[CmdletBinding()]
param(
    [string]$FixtureDir = 'fixtures\office-oracle\excel-msforms\userforms\drag-drop-transfer',
    [string]$OutDir,
    [switch]$Force,
    [int]$ActionDelayMilliseconds = 220
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$captureRoot = Join-Path $repoRoot 'docs\evidence\W006_control_implementation_rollout\captures'
$windowTitle = 'OxForms W006 OLE Drag Drop Oracle'
$dragSeedText = 'OXFORMS_W006_DRAG_TEXT'
$dragSeedId = 'repo_owned_drag_text_seed_v1'

Import-Module (Join-Path $repoRoot 'tools\W005WindowsInputDiagnostics.psm1') -Force

function Resolve-InRepoPath {
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

function Resolve-CaptureDir {
    param([string]$Directory)

    if ([string]::IsNullOrWhiteSpace($Directory)) {
        $Directory = Join-Path $captureRoot ('ole-drag-drop-transfer-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))
    }

    $fullPath = if ([System.IO.Path]::IsPathRooted($Directory)) {
        [System.IO.Path]::GetFullPath($Directory)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Directory))
    }

    $root = [System.IO.Path]::GetFullPath($captureRoot)
    $rootWithSeparator = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "OutDir '$fullPath' must be under '$root'."
    }

    New-Item -ItemType Directory -Force -Path $fullPath | Out-Null
    return (Resolve-Path -LiteralPath $fullPath).Path
}

function ConvertTo-RepoRelative {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $repoWithSeparator = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if ($fullPath.Equals($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return '.'
    }
    if ($fullPath.StartsWith($repoWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $fullPath.Substring($repoWithSeparator.Length).Replace([System.IO.Path]::DirectorySeparatorChar, '/')
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

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)][object]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $Value | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Invoke-LoggedPowerShell {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$CommandPath,
        [Parameter(Mandatory = $true)][string]$StdoutPath,
        [Parameter(Mandatory = $true)][string]$StderrPath
    )

    $argumentString = (($Arguments | ForEach-Object {
        if ($_ -match '\s|"') {
            '"' + ($_ -replace '"', '\"') + '"'
        } else {
            $_
        }
    }) -join ' ')
    Set-Content -LiteralPath $CommandPath -Value ('powershell.exe ' + $argumentString) -Encoding UTF8

    $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $argumentString -Wait -PassThru -NoNewWindow -RedirectStandardOutput $StdoutPath -RedirectStandardError $StderrPath
    if ($process.ExitCode -ne 0) {
        throw "Command failed with exit code $($process.ExitCode): powershell.exe $argumentString"
    }
}

function Write-CaptureGitAttributes {
    param([string]$ResolvedOutDir)

    $lines = @(
        '.gitattributes text eol=crlf diff',
        '*.json text eol=crlf diff',
        '*.csv text eol=crlf diff',
        '*.md text eol=crlf diff',
        '*.txt text eol=crlf diff',
        'checksums.sha256 text eol=crlf diff',
        '*.xlsm -text -diff',
        'window/*.png -text -diff'
    )
    Set-Content -LiteralPath (Join-Path $ResolvedOutDir '.gitattributes') -Value $lines -Encoding ASCII
}

function Write-ProgressStep {
    param(
        [string]$ResolvedOutDir,
        [string]$Step
    )

    Add-Content -LiteralPath (Join-Path $ResolvedOutDir 'capture-progress.log') -Value ((Get-Date).ToUniversalTime().ToString('o') + ' ' + $Step) -Encoding UTF8
}

function Invoke-CaptureWindow {
    param([string]$ResolvedOutDir)

    $windowDir = Join-Path $ResolvedOutDir 'window'
    New-Item -ItemType Directory -Force -Path $windowDir | Out-Null
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', (Join-Path $repoRoot 'tools\office-oracle\Capture-Window.ps1'),
        '-OutDir', $windowDir,
        '-TitleContains', $windowTitle,
        '-ProcessName', 'EXCEL',
        '-CaptureScreenshot'
    )

    Invoke-LoggedPowerShell -Arguments $arguments `
        -CommandPath (Join-Path $ResolvedOutDir 'capture-window.command.txt') `
        -StdoutPath (Join-Path $ResolvedOutDir 'capture-window.stdout.txt') `
        -StderrPath (Join-Path $ResolvedOutDir 'capture-window.stderr.txt')

    return Get-Content -Raw -LiteralPath (Join-Path $windowDir 'window-capture-manifest.json') | ConvertFrom-Json
}

function Get-ControlSpec {
    param(
        [object]$Fixture,
        [string]$Name
    )

    $matches = @($Fixture.controls | Where-Object { $_.name -eq $Name })
    if ($matches.Count -ne 1) {
        throw "Expected exactly one fixture control named '$Name'."
    }
    return $matches[0]
}

function Get-ColorBounds {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$Red,
        [int]$Green,
        [int]$Blue
    )

    $minX = $Bitmap.Width
    $minY = $Bitmap.Height
    $maxX = -1
    $maxY = -1
    $count = 0

    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            $pixel = $Bitmap.GetPixel($x, $y)
            if ($pixel.R -eq $Red -and $pixel.G -eq $Green -and $pixel.B -eq $Blue) {
                $count++
                if ($x -lt $minX) { $minX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }

    if ($count -eq 0) {
        return $null
    }

    return [ordered]@{
        x = $minX
        y = $minY
        width = $maxX - $minX + 1
        height = $maxY - $minY + 1
        pixel_count = $count
    }
}

function New-DragPoints {
    param(
        [object]$Fixture,
        [object]$WindowManifest
    )

    Add-Type -AssemblyName System.Drawing
    $source = Get-ControlSpec -Fixture $Fixture -Name 'SourceDragLabel'
    $target = Get-ControlSpec -Fixture $Fixture -Name 'TargetDropTextBox'
    $screenshotPath = $WindowManifest.screenshot.path
    if ([string]::IsNullOrWhiteSpace($screenshotPath) -or -not (Test-Path -LiteralPath $screenshotPath -PathType Leaf)) {
        throw "Capture screenshot missing from window manifest."
    }

    $bitmap = [System.Drawing.Bitmap]::new($screenshotPath)
    try {
        $sourceFill = Get-ColorBounds -Bitmap $bitmap -Red 0 -Green 112 -Blue 192
    } finally {
        $bitmap.Dispose()
    }
    if ($null -eq $sourceFill) {
        throw 'Could not find the exact SourceDragLabel fill color in the screenshot.'
    }

    $dpi = $WindowManifest.selected_window.dpi
    if ($null -eq $dpi -or [double]$dpi -le 0) {
        $dpi = 96
    }
    $pointsToPixels = [double]$dpi / 72.0
    $sourceCenter = [ordered]@{
        x = [double]$sourceFill.x + ([double]$sourceFill.width / 2.0)
        y = [double]$sourceFill.y + ([double]$sourceFill.height / 2.0)
    }
    $sourceCenterPt = [ordered]@{
        x = [double]$source.leftPt + ([double]$source.widthPt / 2.0)
        y = [double]$source.topPt + ([double]$source.heightPt / 2.0)
    }
    $targetCenterPt = [ordered]@{
        x = [double]$target.leftPt + ([double]$target.widthPt / 2.0)
        y = [double]$target.topPt + ([double]$target.heightPt / 2.0)
    }
    $targetCenter = [ordered]@{
        x = [double]$sourceCenter.x + (([double]$targetCenterPt.x - [double]$sourceCenterPt.x) * $pointsToPixels)
        y = [double]$sourceCenter.y + (([double]$targetCenterPt.y - [double]$sourceCenterPt.y) * $pointsToPixels)
    }
    $window = $WindowManifest.selected_window
    $startScreen = [ordered]@{
        x = [int][Math]::Round([double]$window.bounds.left + [double]$sourceCenter.x)
        y = [int][Math]::Round([double]$window.bounds.top + [double]$sourceCenter.y)
    }
    $endScreen = [ordered]@{
        x = [int][Math]::Round([double]$window.bounds.left + [double]$targetCenter.x)
        y = [int][Math]::Round([double]$window.bounds.top + [double]$targetCenter.y)
    }

    return [ordered]@{
        schema = 'oxforms.office_oracle.w006_ole_drag_drop_coordinate_derivation.v1'
        coordinate_spaces = @('screen_pixels', 'screenshot_pixels', 'form_logical', 'msforms_event_args')
        dpi = [double]$dpi
        points_to_pixels = $pointsToPixels
        source_fill_rect_screenshot_pixels = $sourceFill
        source_center_screenshot_pixels = $sourceCenter
        target_center_screenshot_pixels = $targetCenter
        source_center_screen_pixels = $startScreen
        target_center_screen_pixels = $endScreen
        assumptions = @(
            'SourceDragLabel center is derived from its exact repo-owned fill color in the screenshot.',
            'TargetDropTextBox center is derived from manifest point geometry relative to the detected source center.',
            'Live MSForms X/Y event arguments remain only the values logged by event handlers with coordinate_space=msforms_event_args.'
        )
    }
}

function ConvertTo-CsvFieldText {
    param($Value)
    if ($null -eq $Value) { return '' }
    return [string]$Value
}

function Export-WorksheetLog {
    param(
        [object]$Workbook,
        [string]$ResolvedOutDir
    )

    $csvPath = Join-Path $ResolvedOutDir 'w006-ole-drag-drop-event-log.csv'
    if (Test-Path -LiteralPath $csvPath) {
        Remove-Item -LiteralPath $csvPath -Force
    }

    $sheet = $Workbook.Worksheets.Item('W006OleDragDropEventLog')
    $range = $sheet.UsedRange
    $rowCount = [int]$range.Rows.Count
    $columnCount = [int]$range.Columns.Count
    $values = $range.Value2

    $headers = [System.Collections.Generic.List[string]]::new()
    for ($column = 1; $column -le $columnCount; $column++) {
        $headers.Add((ConvertTo-CsvFieldText $values[1, $column])) | Out-Null
    }

    $records = [System.Collections.Generic.List[object]]::new()
    if ($rowCount -ge 2) {
        for ($row = 2; $row -le $rowCount; $row++) {
            $record = [ordered]@{}
            for ($column = 1; $column -le $columnCount; $column++) {
                $record[$headers[$column - 1]] = ConvertTo-CsvFieldText $values[$row, $column]
            }
            $records.Add([pscustomobject]$record) | Out-Null
        }
    }

    @($records) | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
    $rows = @($records)
    $eventNames = @($rows | ForEach-Object { $_.event_name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $targetNames = @($rows | ForEach-Object { $_.target_name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)

    $eventLog = [ordered]@{
        schema = 'oxforms.office_oracle.w006_ole_drag_drop_event_log.v1'
        bead = 'oxforms-0a0.16'
        fact_source = [ordered]@{
            event_facts = 'docs/specs/FM20_EVENT_FACTS.md#W006-Deferred-Input-Surface-Fact-Split'
            input_model = 'docs/specs/INPUT_INTERACTION_MODEL.md#54-W006-Text-service-Clipboard-Paste-And-Dragdrop-Design'
            text_service_paste_evidence = 'docs/evidence/W006_control_implementation_rollout/text-service-transfer-oracle.md'
        }
        observed_facts = [ordered]@{
            row_count = $rows.Count
            event_names = $eventNames
            targets = $targetNames
            rows = @($rows)
        }
        clean_room = [ordered]@{
            source = 'Repo-owned VBA event handlers in a generated Excel/MSForms workbook, public MSForms.DataObject.SetText/StartDrag, public user32 SendInput mouse input, and public worksheet export.'
            data_object_policy = 'Only public MSForms.DataObject method summaries are recorded. The known repo-owned drag seed text may be identified by seed id; unexpected text payloads are not recorded.'
            prohibited = 'No Office internals, decompilation, disassembly, private source, or binary inspection.'
        }
        assumptions = @(
            'Rows under observed_facts are worksheet rows emitted by repo-owned VBA handlers while real Excel/MSForms handled the driven input.',
            'Absence of an event row is not a negative parity fact; this capture records only rows raised by this fixture and input run.',
            'This drag/drop evidence is separate from oxforms-0a0.13 TextBox.Paste evidence.'
        )
        non_claims = @(
            'This event log is not an exhaustive MSForms event parity claim.',
            'This event log is not an OxForms output comparison artifact.',
            'This event log does not store live COM object identity or private Office implementation detail.'
        )
    }

    $jsonPath = Join-Path $ResolvedOutDir 'w006-ole-drag-drop-event-log.json'
    Write-JsonFile -Value $eventLog -Path $jsonPath

    return [ordered]@{
        csv = ConvertTo-RepoRelative $csvPath
        json = ConvertTo-RepoRelative $jsonPath
        row_count = $rows.Count
        event_names = $eventNames
        targets = $targetNames
        rows = @($rows)
    }
}

function Write-Checksums {
    param([string]$ResolvedOutDir)

    $checksumPath = Join-Path $ResolvedOutDir 'checksums.sha256'
    $directoryWithSeparator = $ResolvedOutDir.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $files = Get-ChildItem -LiteralPath $ResolvedOutDir -Recurse -File |
        Where-Object { $_.FullName -ne $checksumPath } |
        Sort-Object FullName

    $lines = foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($directoryWithSeparator.Length).Replace([System.IO.Path]::DirectorySeparatorChar, '/').Replace([System.IO.Path]::AltDirectorySeparatorChar, '/')
        "$(Get-Sha256Hex -Path $file.FullName)  $relativePath"
    }
    Set-Content -LiteralPath $checksumPath -Value $lines -Encoding ASCII
}

function Release-ComObjectIfPresent {
    param($Object)

    if ($null -ne $Object -and [System.Runtime.InteropServices.Marshal]::IsComObject($Object)) {
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($Object)
    }
}

function Get-ExistingRepoRelativeFiles {
    param([string[]]$Paths)

    $existing = [System.Collections.Generic.List[string]]::new()
    foreach ($path in $Paths) {
        if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path -PathType Leaf)) {
            $existing.Add((ConvertTo-RepoRelative $path)) | Out-Null
        }
    }
    return @($existing)
}

function Write-CaptureReadme {
    param(
        [string]$ResolvedOutDir,
        [object]$Manifest,
        [bool]$CapturedTrueDragDrop
    )

    $surfaceLine = if ($CapturedTrueDragDrop) {
        'This capture observed true OLE/MSForms drag/drop rows.'
    } else {
        'This capture precisely blocks true OLE/MSForms drag/drop for this run; see `run-summary.json` and `input-actions.json`.'
    }

    $lines = @(
        '# W006 OLE Drag/drop Transfer Oracle Capture',
        '',
        "Capture id: $($Manifest.capture_id)",
        'Bead: `oxforms-0a0.16`',
        '',
        $surfaceLine,
        '',
        '## Observed Facts Or Blocker',
        '',
        '- `w006-ole-drag-drop-event-log.json` and `.csv` contain worksheet rows emitted by fixture VBA event handlers.',
        '- `input-actions.json` records public `MSForms.DataObject.StartDrag` fixture intent plus public `user32 SendInput` mouse input.',
        '- `coordinate-derivation.json` records screenshot/manifest-derived source and target mouse points; live event X/Y values remain only the logged MSForms event arguments.',
        '- `.13` paste observations are referenced only as adjacent evidence and are not mixed into this true drag/drop capture.',
        '',
        '## Clean-room Note',
        '',
        'The capture used repo-owned fixture sources, public Excel/VBIDE automation, public VBA event handlers, public MSForms DataObject methods, public Windows desktop input/capture APIs, and worksheet export. It did not use private Office internals, decompilation, disassembly, or OxForms output comparison.'
    )

    Set-Content -LiteralPath (Join-Path $ResolvedOutDir 'README.md') -Value $lines -Encoding UTF8
}

$resolvedOutDir = Resolve-CaptureDir -Directory $OutDir
$fixtureRoot = Resolve-InRepoPath $FixtureDir
$fixturePath = Join-Path $fixtureRoot 'fixture.json'
$fixture = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
$captureId = Split-Path -Leaf $resolvedOutDir
$workbookPath = Join-Path $resolvedOutDir 'w006-ole-drag-drop-oracle.xlsm'

Write-CaptureGitAttributes -ResolvedOutDir $resolvedOutDir
Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'capture_directory_prepared'
Set-Location $repoRoot

$generatorArgs = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', (Join-Path $repoRoot 'tools\office-oracle\Open-ExcelUserFormFixture.ps1'),
    '-FixtureDir', $fixtureRoot,
    '-OutputWorkbook', $workbookPath
)
if ($Force) {
    $generatorArgs += '-Force'
}

Invoke-LoggedPowerShell -Arguments $generatorArgs `
    -CommandPath (Join-Path $resolvedOutDir 'generate-workbook.command.txt') `
    -StdoutPath (Join-Path $resolvedOutDir 'generate-workbook.stdout.txt') `
    -StderrPath (Join-Path $resolvedOutDir 'generate-workbook.stderr.txt')
Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'workbook_generated'

$excel = $null
$workbook = $null
$windowManifest = $null
$eventLog = $null
$excelInfo = $null
$inputActions = [System.Collections.Generic.List[object]]::new()
$coordinateDerivation = $null
$dragAction = $null
$finalText = ''

try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $true
    $excel.DisplayAlerts = $false
    try {
        $excel.AutomationSecurity = 1
    } catch {
        Write-Warning "Could not set Excel AutomationSecurity for this instance: $($_.Exception.Message)"
    }

    $excelPath = Join-Path $excel.Path 'EXCEL.EXE'
    if (Test-Path -LiteralPath $excelPath -PathType Leaf) {
        $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($excelPath)
        $excelInfo = [ordered]@{
            path = $excelPath
            file_version = $versionInfo.FileVersion
            product_version = $versionInfo.ProductVersion
            product_name = $versionInfo.ProductName
            company_name = $versionInfo.CompanyName
        }
    }

    $workbook = $excel.Workbooks.Open($workbookPath)
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'workbook_opened'
    $excel.Run('ClearW006OleDragDropLog')
    $excel.Run($fixture.workbook.showMacroName)
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'form_shown_modeless'
    Start-Sleep -Milliseconds ($ActionDelayMilliseconds * 3)

    $windowManifest = Invoke-CaptureWindow -ResolvedOutDir $resolvedOutDir
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'window_captured'
    $coordinateDerivation = New-DragPoints -Fixture $fixture -WindowManifest $windowManifest
    $coordinatePath = Join-Path $resolvedOutDir 'coordinate-derivation.json'
    Write-JsonFile -Value $coordinateDerivation -Path $coordinatePath

    $handle = ConvertFrom-W005HandleText -Handle ([string]$windowManifest.selected_window.handle)
    $foreground = Set-W005ForegroundWindow -Handle $handle -DelayMilliseconds $ActionDelayMilliseconds
    $inputActions.Add([ordered]@{
        sequence = 1
        method = 'public_user32_ShowWindow_SetForegroundWindow'
        action = 'focus_userform'
        target_intent = 'Prepare the modeless UserForm for public mouse drag input'
        manual = $false
        result = $foreground
    }) | Out-Null

    try {
        $dragAction = Invoke-W005SendInputMouseDrag `
            -StartScreenX ([int]$coordinateDerivation.source_center_screen_pixels.x) `
            -StartScreenY ([int]$coordinateDerivation.source_center_screen_pixels.y) `
            -EndScreenX ([int]$coordinateDerivation.target_center_screen_pixels.x) `
            -EndScreenY ([int]$coordinateDerivation.target_center_screen_pixels.y) `
            -TargetHandle $handle `
            -StepDelayMilliseconds ($ActionDelayMilliseconds * 2) `
            -AfterDelayMilliseconds ($ActionDelayMilliseconds * 4)
        Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'sendinput_drag_completed'
    } catch {
        $dragAction = [ordered]@{
            schema = 'oxforms.w005.sendinput_mouse_action.v1'
            input_driver = 'public_user32_sendinput'
            action = 'mouse_drag'
            status = 'blocked'
            error = $_.Exception.Message
        }
        Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('sendinput_drag_blocked=' + $_.Exception.Message)
    }
    $inputActions.Add([ordered]@{
        sequence = 2
        method = 'public_user32_sendinput_mouse_drag'
        action = 'drag_source_label_to_target_textbox'
        target_intent = 'Trigger SourceDragLabel DataObject.StartDrag and release over TargetDropTextBox'
        manual = $false
        result = $dragAction
        notes = 'The live OLE drag source is public MSForms.DataObject.StartDrag in repo-owned VBA; SendInput only supplies mouse down/move/up.'
    }) | Out-Null

    Start-Sleep -Milliseconds ($ActionDelayMilliseconds * 3)
    $finalText = [string]($excel.Run('W006OleDragDropTargetText'))
    $excel.Run($fixture.workbook.hideMacroName)
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'hide_macro_completed'
    Start-Sleep -Milliseconds $ActionDelayMilliseconds
    $eventLog = Export-WorksheetLog -Workbook $workbook -ResolvedOutDir $resolvedOutDir
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('event_log_exported_rows=' + $eventLog.row_count)
    $workbook.Save()
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'workbook_saved'
} finally {
    if ($null -ne $workbook) {
        try {
            $workbook.Close($true)
        } catch {
            Write-Warning "Failed to close workbook: $($_.Exception.Message)"
        }
    }
    if ($null -ne $excel) {
        try {
            $excel.Quit()
        } catch {
            Write-Warning "Failed to quit Excel: $($_.Exception.Message)"
        }
    }
    Release-ComObjectIfPresent $workbook
    Release-ComObjectIfPresent $excel
}

$beforeDragOverRows = @($eventLog.rows | Where-Object { $_.event_name -eq 'BeforeDragOver' })
$beforeDropRows = @($eventLog.rows | Where-Object { $_.event_name -eq 'BeforeDropOrPaste' })
$startDragAttempts = @($eventLog.rows | Where-Object { $_.event_name -eq 'StartDragAttempt' })
$startDragErrors = @($eventLog.rows | Where-Object { $_.event_name -eq 'StartDragError' })
$capturedTrueDragDrop = ($beforeDragOverRows.Count -gt 0 -and $beforeDropRows.Count -gt 0)

$inputActionsPath = Join-Path $resolvedOutDir 'input-actions.json'
Write-JsonFile -Path $inputActionsPath -Value ([ordered]@{
    schema = 'oxforms.office_oracle.w006_ole_drag_drop_input_actions.v1'
    bead = 'oxforms-0a0.16'
    manual_inputs = @()
    automated_inputs = @($inputActions)
    public_capability_probe = [ordered]@{
        fm20_data_object_start_drag = 'available_in_public_FM20_type_library_and_attempted_by_fixture_vba'
        source = 'MSForms.DataObject.StartDrag invoked by repo-owned SourceDragLabel_MouseDown handler'
    }
    blockers = @(
        if (-not $capturedTrueDragDrop) {
            [ordered]@{
                surface = 'ole_drag_drop'
                reason = if ($startDragErrors.Count -gt 0) { 'Public MSForms.DataObject.StartDrag was attempted by the fixture but raised an error in live Excel/MSForms.' } elseif ($startDragAttempts.Count -eq 0) { 'Public SendInput mouse drag did not reach the fixture path that invokes MSForms.DataObject.StartDrag in this desktop session.' } else { 'Public MSForms.DataObject.StartDrag was attempted, but this run did not produce both BeforeDragOver and BeforeDropOrPaste target rows.' }
                detail = [ordered]@{
                    start_drag_attempt_rows = $startDragAttempts.Count
                    start_drag_error_rows = $startDragErrors.Count
                    before_drag_over_rows = $beforeDragOverRows.Count
                    before_drop_or_paste_rows = $beforeDropRows.Count
                    sendinput_result = $dragAction
                }
                non_claim = 'No true OLE/MSForms drag/drop ordering, drag-session DataObject behavior, or drop-effect negotiation parity is claimed from this run.'
            }
        }
    )
    notes = @(
        'The fixture keeps oxforms-0a0.13 TextBox.Paste observations separate from this true drag/drop run.',
        'The fixture does not store platform drag objects, COM DataObject identities, or private implementation details.'
    )
})

$runSummaryPath = Join-Path $resolvedOutDir 'run-summary.json'
Write-JsonFile -Path $runSummaryPath -Value ([ordered]@{
    schema = 'oxforms.office_oracle.w006_ole_drag_drop_run_summary.v1'
    bead = 'oxforms-0a0.16'
    capture_id = $captureId
    captured_true_drag_drop = [bool]$capturedTrueDragDrop
    final_text_equals_drag_seed = ([string]$finalText -eq $dragSeedText)
    final_text_policy = 'The compared text is the repo-owned drag seed from the fixture manifest.'
    row_count = $eventLog.row_count
    event_names = $eventLog.event_names
    selected_surface_status = [ordered]@{
        source_start_drag_attempt = if ($startDragAttempts.Count -gt 0) { 'observed' } else { 'not_observed_in_this_run' }
        source_start_drag_error = if ($startDragErrors.Count -gt 0) { 'observed' } else { 'not_observed_in_this_run' }
        before_drag_over = if ($beforeDragOverRows.Count -gt 0) { 'observed' } else { 'not_observed_in_this_run' }
        before_drop_or_paste = if ($beforeDropRows.Count -gt 0) { 'observed' } else { 'not_observed_in_this_run' }
        true_ole_drag_drop = if ($capturedTrueDragDrop) { 'observed_before_drag_over_and_before_drop_or_paste' } else { 'precisely_blocked_for_this_run' }
    }
    blocker = if ($capturedTrueDragDrop) { $null } else { 'See input-actions.json blockers[0] for the exact public driver/capability failure point.' }
    non_claims = @(
        'A missing event row is not a negative claim about all MSForms inputs.',
        'This run does not implement or validate OxForms runtime drag/drop behavior.',
        'This run keeps oxforms-0a0.13 paste DataObject observations separate from true drag/drop observations.'
    )
})

$fixtureHashes = [ordered]@{
    manifest = [ordered]@{
        path = ConvertTo-RepoRelative $fixturePath
        sha256 = Get-Sha256Hex -Path $fixturePath
    }
    form_code_behind = [ordered]@{
        path = ConvertTo-RepoRelative (Join-Path $fixtureRoot $fixture.codeBehind.sourcePath)
        sha256 = Get-Sha256Hex -Path (Join-Path $fixtureRoot $fixture.codeBehind.sourcePath)
    }
    standard_module_extra = [ordered]@{
        path = ConvertTo-RepoRelative (Join-Path $fixtureRoot $fixture.workbook.additionalModuleSourcePath)
        sha256 = Get-Sha256Hex -Path (Join-Path $fixtureRoot $fixture.workbook.additionalModuleSourcePath)
    }
}

$manifest = [ordered]@{
    schema = 'oxforms.office_oracle.w006_ole_drag_drop_capture.v1'
    bead = 'oxforms-0a0.16'
    capture_id = $captureId
    captured_true_drag_drop = [bool]$capturedTrueDragDrop
    fixture = [ordered]@{
        id = $fixture.id
        inputs = $fixtureHashes
    }
    commands = [ordered]@{
        generator = ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'generate-workbook.command.txt')
        window_capture = ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'capture-window.command.txt')
        rerun_note = 'Run this script from the repository root. It generates the workbook, opens Excel, shows the modeless UserForm, captures the window, derives source/target points, injects public mouse drag input, exports W006OleDragDropEventLog, writes manifests, and checksums artifacts.'
    }
    platform = [ordered]@{
        os = [System.Environment]::OSVersion.VersionString
        is_windows = $true
        powershell = $PSVersionTable.PSVersion.ToString()
    }
    excel = $excelInfo
    artifacts = [ordered]@{
        generated_workbook = [ordered]@{
            path = ConvertTo-RepoRelative $workbookPath
            sha256 = Get-Sha256Hex -Path $workbookPath
        }
        run_summary = ConvertTo-RepoRelative $runSummaryPath
        event_log_json = $eventLog.json
        event_log_csv = $eventLog.csv
        input_actions = ConvertTo-RepoRelative $inputActionsPath
        coordinate_derivation = ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'coordinate-derivation.json')
        window_capture_manifest = ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'window\window-capture-manifest.json')
        screenshot = if (Test-Path -LiteralPath (Join-Path $resolvedOutDir 'window\window-capture.png') -PathType Leaf) { ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'window\window-capture.png') } else { $null }
        command_logs = Get-ExistingRepoRelativeFiles -Paths @(
            (Join-Path $resolvedOutDir 'generate-workbook.command.txt'),
            (Join-Path $resolvedOutDir 'generate-workbook.stdout.txt'),
            (Join-Path $resolvedOutDir 'generate-workbook.stderr.txt'),
            (Join-Path $resolvedOutDir 'capture-window.command.txt'),
            (Join-Path $resolvedOutDir 'capture-window.stdout.txt'),
            (Join-Path $resolvedOutDir 'capture-window.stderr.txt')
        )
    }
    observed_coverage = [ordered]@{
        event_names = $eventLog.event_names
        row_count = $eventLog.row_count
        manual_inputs = @()
        input_method = 'public MSForms.DataObject.StartDrag fixture plus public Windows SendInput mouse drag'
    }
    warnings = @(
        'This is black-box Excel/MSForms event evidence only; no OxForms output was compared.',
        'The capture is not an exhaustive MSForms event parity claim.',
        'Missing BeforeDragOver or BeforeDropOrPaste rows are unobserved rows, not negative facts about all MSForms behavior.',
        'Desktop focus, mouse capture, theme, DPI, and Excel/MSForms version can affect observed rows.'
    )
    clean_room = [ordered]@{
        source = 'Repo-owned fixture generated through public Excel/VBIDE automation and driven through public MSForms.DataObject methods plus public Windows SendInput.'
        data_object_policy = 'Public MSForms.DataObject method summaries only; no live object identity is stored.'
        prohibited = 'No Office internals, decompilation, disassembly, private source, or non-public implementation details were used.'
    }
}

Write-JsonFile -Path (Join-Path $resolvedOutDir 'oracle-capture-manifest.json') -Value $manifest
Write-CaptureReadme -ResolvedOutDir $resolvedOutDir -Manifest $manifest -CapturedTrueDragDrop $capturedTrueDragDrop
Write-Checksums -ResolvedOutDir $resolvedOutDir

Write-Host "W006 OLE drag/drop transfer capture complete: $resolvedOutDir"
Write-Host "Rows: $($eventLog.row_count)"
Write-Host "Events: $(@($eventLog.event_names) -join ', ')"
Write-Host "Captured true drag/drop: $capturedTrueDragDrop"
