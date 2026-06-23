[CmdletBinding()]
param(
    [string]$FixtureDir = 'fixtures\office-oracle\excel-msforms\userforms\interaction-events',
    [string]$OutDir,
    [switch]$Force,
    [switch]$SkipModal,
    [switch]$DriveOnly,
    [string]$RunName = 'modeless',
    [string]$WindowTitle = 'OxForms W005 Interaction Oracle',
    [int]$ActionDelayMilliseconds = 180
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$w005CaptureRoot = Join-Path $repoRoot 'docs\evidence\W005_input_interaction_model_exploration\captures'

function Resolve-RepoPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        $fullPath = [System.IO.Path]::GetFullPath($Path)
    } else {
        $fullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
    }

    $repoWithSeparator = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    if (-not ($fullPath.Equals($repoRoot, $comparison) -or $fullPath.StartsWith($repoWithSeparator, $comparison))) {
        throw "Path '$Path' resolves outside repository root '$repoRoot'."
    }

    return $fullPath
}

function Resolve-CaptureDir {
    param([string]$Directory)

    if ([string]::IsNullOrWhiteSpace($Directory)) {
        $captureId = 'interaction-events-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
        $Directory = Join-Path $w005CaptureRoot $captureId
    }

    if ([System.IO.Path]::IsPathRooted($Directory)) {
        $fullPath = [System.IO.Path]::GetFullPath($Directory)
    } else {
        $fullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Directory))
    }

    $root = [System.IO.Path]::GetFullPath($w005CaptureRoot)
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
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try {
            $bytes = $sha256.ComputeHash($stream)
            return ([System.BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant()
        } finally {
            $sha256.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Value,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $Value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Ensure-NativeTypes {
    if (([System.Management.Automation.PSTypeName]'OxForms.W005Interaction.NativeMethods').Type) {
        return
    }

    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace OxForms.W005Interaction
{
    public static class NativeMethods
    {
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [StructLayout(LayoutKind.Sequential)]
        public struct RECT
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        [DllImport("user32.dll")]
        public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

        [DllImport("user32.dll")]
        public static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern int GetWindowTextLengthW(IntPtr hWnd);

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern int GetWindowTextW(IntPtr hWnd, StringBuilder text, int maxCount);

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern int GetClassNameW(IntPtr hWnd, StringBuilder className, int maxCount);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        [DllImport("user32.dll")]
        public static extern bool SetCursorPos(int X, int Y);

        [DllImport("user32.dll")]
        public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
    }
}
'@
}

function Get-WindowTextValue {
    param([System.IntPtr]$Handle)

    $length = [OxForms.W005Interaction.NativeMethods]::GetWindowTextLengthW($Handle)
    $capacity = [Math]::Max($length + 1, 256)
    $builder = [System.Text.StringBuilder]::new($capacity)
    [void][OxForms.W005Interaction.NativeMethods]::GetWindowTextW($Handle, $builder, $builder.Capacity)
    return $builder.ToString()
}

function Get-ClassNameValue {
    param([System.IntPtr]$Handle)

    $builder = [System.Text.StringBuilder]::new(256)
    [void][OxForms.W005Interaction.NativeMethods]::GetClassNameW($Handle, $builder, $builder.Capacity)
    return $builder.ToString()
}

function Get-TopLevelWindows {
    Ensure-NativeTypes
    $windows = [System.Collections.Generic.List[object]]::new()

    $callback = [OxForms.W005Interaction.NativeMethods+EnumWindowsProc]{
        param([System.IntPtr]$Handle, [System.IntPtr]$Param)

        if (-not [OxForms.W005Interaction.NativeMethods]::IsWindowVisible($Handle)) {
            return $true
        }

        $title = Get-WindowTextValue -Handle $Handle
        if ([string]::IsNullOrWhiteSpace($title)) {
            return $true
        }

        $class = Get-ClassNameValue -Handle $Handle
        $processIdValue = [uint32]0
        [void][OxForms.W005Interaction.NativeMethods]::GetWindowThreadProcessId($Handle, [ref]$processIdValue)

        $rect = New-Object OxForms.W005Interaction.NativeMethods+RECT
        [void][OxForms.W005Interaction.NativeMethods]::GetWindowRect($Handle, [ref]$rect)

        $windows.Add([ordered]@{
            handle = ('0x{0:X}' -f $Handle.ToInt64())
            title = $title
            class_name = $class
            process_id = [int]$processIdValue
            bounds = [ordered]@{
                left = $rect.Left
                top = $rect.Top
                right = $rect.Right
                bottom = $rect.Bottom
                width = [Math]::Max(0, $rect.Right - $rect.Left)
                height = [Math]::Max(0, $rect.Bottom - $rect.Top)
            }
        }) | Out-Null

        return $true
    }

    [void][OxForms.W005Interaction.NativeMethods]::EnumWindows($callback, [System.IntPtr]::Zero)
    return @($windows)
}

function Wait-ForOracleWindow {
    param(
        [string]$Title,
        [int]$TimeoutSeconds = 20
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $matches = @(Get-TopLevelWindows | Where-Object {
            $_.title.IndexOf($Title, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -and
            $_.class_name -eq 'ThunderDFrame'
        })

        if ($matches.Count -gt 0) {
            return $matches[0]
        }

        Start-Sleep -Milliseconds 100
    } while ((Get-Date) -lt $deadline)

    throw "Timed out waiting for UserForm window title containing '$Title'."
}

function Wait-ForOracleWindowClosed {
    param(
        [string]$Title,
        [int]$TimeoutSeconds = 10
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $matches = @(Get-TopLevelWindows | Where-Object {
            $_.title.IndexOf($Title, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -and
            $_.class_name -eq 'ThunderDFrame'
        })
        if ($matches.Count -eq 0) {
            return
        }
        Start-Sleep -Milliseconds 100
    } while ((Get-Date) -lt $deadline)
}

function Invoke-LoggedPowerShell {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [Parameter(Mandatory = $true)]
        [string]$CommandPath,
        [Parameter(Mandatory = $true)]
        [string]$StdoutPath,
        [Parameter(Mandatory = $true)]
        [string]$StderrPath
    )

    $argumentString = (($Arguments | ForEach-Object {
        if ($_ -match '\s|"' ) {
            '"' + ($_ -replace '"', '\"') + '"'
        } else {
            $_
        }
    }) -join ' ')
    $commandText = 'powershell.exe ' + $argumentString
    Set-Content -LiteralPath $CommandPath -Value $commandText -Encoding UTF8

    $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $argumentString -Wait -PassThru -NoNewWindow -RedirectStandardOutput $StdoutPath -RedirectStandardError $StderrPath
    if ($process.ExitCode -ne 0) {
        throw "Command failed with exit code $($process.ExitCode): $commandText"
    }
}

function Invoke-CaptureWindow {
    param(
        [string]$ResolvedOutDir,
        [string]$CurrentRunName,
        [string]$Title
    )

    $captureDir = Join-Path $ResolvedOutDir "$CurrentRunName-window"
    New-Item -ItemType Directory -Force -Path $captureDir | Out-Null

    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', (Join-Path $repoRoot 'tools\office-oracle\Capture-Window.ps1'),
        '-OutDir', $captureDir,
        '-TitleContains', $Title,
        '-ProcessName', 'EXCEL',
        '-CaptureScreenshot'
    )

    Invoke-LoggedPowerShell -Arguments $arguments `
        -CommandPath (Join-Path $ResolvedOutDir "capture-window-$CurrentRunName.command.txt") `
        -StdoutPath (Join-Path $ResolvedOutDir "capture-window-$CurrentRunName.stdout.log") `
        -StderrPath (Join-Path $ResolvedOutDir "capture-window-$CurrentRunName.stderr.log")

    $manifestPath = Join-Path $captureDir 'window-capture-manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Capture manifest was not written: $manifestPath"
    }

    return Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
}

function Get-ColorBounds {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$Red,
        [int]$Green,
        [int]$Blue,
        [object]$SearchRect = $null
    )

    $minX = $Bitmap.Width
    $minY = $Bitmap.Height
    $maxX = -1
    $maxY = -1
    $count = 0

    if ($null -ne $SearchRect) {
        $startX = [Math]::Max(0, [int]$SearchRect.x)
        $startY = [Math]::Max(0, [int]$SearchRect.y)
        $endX = [Math]::Min($Bitmap.Width - 1, [int]$SearchRect.x + [int]$SearchRect.width - 1)
        $endY = [Math]::Min($Bitmap.Height - 1, [int]$SearchRect.y + [int]$SearchRect.height - 1)
    } else {
        $startX = 0
        $startY = 0
        $endX = $Bitmap.Width - 1
        $endY = $Bitmap.Height - 1
    }

    if ($endX -lt $startX -or $endY -lt $startY) {
        throw "Invalid color search rectangle: $($SearchRect | ConvertTo-Json -Compress)"
    }

    for ($y = $startY; $y -le $endY; $y++) {
        for ($x = $startX; $x -le $endX; $x++) {
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

function Expand-Rectangle {
    param(
        [object]$Rect,
        [int]$Margin,
        [int]$MaxWidth,
        [int]$MaxHeight
    )

    $x = [Math]::Max(0, [int]$Rect.x - $Margin)
    $y = [Math]::Max(0, [int]$Rect.y - $Margin)
    $right = [Math]::Min($MaxWidth, [int]$Rect.x + [int]$Rect.width + $Margin)
    $bottom = [Math]::Min($MaxHeight, [int]$Rect.y + [int]$Rect.height + $Margin)

    return [ordered]@{
        x = $x
        y = $y
        width = $right - $x
        height = $bottom - $y
    }
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

function Analyze-CaptureCoordinates {
    param(
        [string]$ResolvedOutDir,
        [string]$CurrentRunName,
        [object]$Fixture,
        [object]$WindowManifest
    )

    Add-Type -AssemblyName System.Drawing

    $screenshotPath = $WindowManifest.screenshot.path
    if ([string]::IsNullOrWhiteSpace($screenshotPath) -or -not (Test-Path -LiteralPath $screenshotPath -PathType Leaf)) {
        throw "Screenshot path missing from capture manifest for run '$CurrentRunName'."
    }

    $assumptions = [System.Collections.Generic.List[string]]::new()
    $label = Get-ControlSpec -Fixture $Fixture -Name 'OracleProbeLabel'
    $dpi = $WindowManifest.selected_window.dpi
    if ($null -eq $dpi -or [double]$dpi -le 0) {
        $dpi = 96
        $assumptions.Add('Window DPI was unavailable from the capture manifest; used 96 DPI for point-to-pixel action derivations.') | Out-Null
    }

    $pointsToPixels = [double]$dpi / 72.0
    $bitmap = [System.Drawing.Bitmap]::new($screenshotPath)
    try {
        $fillBounds = Get-ColorBounds -Bitmap $bitmap -Red 32 -Green 112 -Blue 192
        if ($null -eq $fillBounds) {
            throw "Could not find the exact OracleProbeLabel fill color in screenshot '$screenshotPath'."
        }

        $globalBorderBounds = Get-ColorBounds -Bitmap $bitmap -Red 100 -Green 100 -Blue 100
        $borderSearchRect = Expand-Rectangle -Rect $fillBounds -Margin 12 -MaxWidth $bitmap.Width -MaxHeight $bitmap.Height
        $borderBounds = Get-ColorBounds -Bitmap $bitmap -Red 100 -Green 100 -Blue 100 -SearchRect $borderSearchRect
    } finally {
        $bitmap.Dispose()
    }

    if ($null -ne $borderBounds) {
        $labelRect = $borderBounds
        $labelRectSource = 'exact_border_color_region_scoped_to_label_fill_neighborhood'
    } else {
        $labelRect = [ordered]@{
            x = [int]$fillBounds.x - 1
            y = [int]$fillBounds.y - 1
            width = [int]$fillBounds.width + 2
            height = [int]$fillBounds.height + 2
            pixel_count = 0
            derived_from_fill_pixel_count = $fillBounds.pixel_count
        }
        $labelRectSource = 'derived_from_exact_fill_region_expanded_by_known_single_border_pixels'
        $assumptions.Add('Exact border color was not detected in the scoped label neighborhood; because the fixture sets OracleProbeLabel.BorderStyle=fmBorderStyleSingle and the exact fill rectangle was detected, the label border rectangle was derived by expanding the fill bounds by one pixel per side.') | Out-Null
    }

    $formOrigin = [ordered]@{
        x = [double]$labelRect.x - ([double]$label.leftPt * $pointsToPixels)
        y = [double]$labelRect.y - ([double]$label.topPt * $pointsToPixels)
        source = $labelRectSource
    }

    $calibration = [ordered]@{
        schema = 'oxforms.office_oracle.w005_coordinate_calibration.v1'
        bead = 'oxforms-xvx.3'
        run = $CurrentRunName
        coordinate_spaces = @('window_rect', 'screenshot_pixels', 'form_logical', 'control_local', 'msforms_event_args', 'screen_pixels')
        dpi = [double]$dpi
        points_to_pixels = $pointsToPixels
        screenshot = [ordered]@{
            path = ConvertTo-RepoRelative $screenshotPath
            width = $WindowManifest.screenshot.width
            height = $WindowManifest.screenshot.height
            sha256 = $WindowManifest.screenshot.sha256
            coordinate_origin = 'top_left_of_captured_top_level_window'
        }
        label_fill_rect_screenshot_pixels = $fillBounds
        label_border_rect_screenshot_pixels = $labelRect
        label_rect_source = $labelRectSource
        label_border_search_rect_screenshot_pixels = $borderSearchRect
        rejected_global_border_color_region_screenshot_pixels = $globalBorderBounds
        form_origin_screenshot_pixels = $formOrigin
        assumptions = @($assumptions)
        notes = @(
            'Rectangles use the W005 half-open convention: x <= point_x < x + width and y <= point_y < y + height.',
            'Border detection is scoped to the exact label-fill neighborhood so unrelated window, title, or sibling-control pixels with the same border color cannot expand the label rectangle.',
            'The derived form origin is an action-target calibration aid, not a final MSForms coordinate parity claim.'
        )
    }

    $calibrationPath = Join-Path $ResolvedOutDir "$CurrentRunName-coordinate-calibration.json"
    Write-JsonFile -Value $calibration -Path $calibrationPath
    return $calibration
}

function New-ScreenshotPointForControl {
    param(
        [object]$Control,
        [object]$Calibration,
        [double]$FractionX,
        [double]$FractionY
    )

    $scale = [double]$Calibration.points_to_pixels
    return [ordered]@{
        x = [double]$Calibration.form_origin_screenshot_pixels.x + (([double]$Control.leftPt + ([double]$Control.widthPt * $FractionX)) * $scale)
        y = [double]$Calibration.form_origin_screenshot_pixels.y + (([double]$Control.topPt + ([double]$Control.heightPt * $FractionY)) * $scale)
    }
}

function Convert-ScreenshotToScreenPoint {
    param(
        [object]$Window,
        [object]$Point
    )

    return [ordered]@{
        x = [int][Math]::Round([double]$Window.bounds.left + [double]$Point.x)
        y = [int][Math]::Round([double]$Window.bounds.top + [double]$Point.y)
    }
}

function Focus-Window {
    param([object]$Window)

    $handleValue = [System.IntPtr]::new([Convert]::ToInt64($Window.handle.Substring(2), 16))
    [void][OxForms.W005Interaction.NativeMethods]::ShowWindow($handleValue, 5)
    [void][OxForms.W005Interaction.NativeMethods]::SetForegroundWindow($handleValue)
    Start-Sleep -Milliseconds $ActionDelayMilliseconds
}

function Add-InputAction {
    param(
        [System.Collections.Generic.List[object]]$Actions,
        [string]$CurrentRunName,
        [string]$Method,
        [string]$TargetIntent,
        [string]$Action,
        [object]$ScreenshotPoint,
        [object]$ScreenPoint,
        [string]$Keys,
        [string]$Notes
    )

    $Actions.Add([ordered]@{
        sequence = $Actions.Count + 1
        run = $CurrentRunName
        input_method = $Method
        manual = $false
        target_intent = $TargetIntent
        action = $Action
        screenshot_pixels = $ScreenshotPoint
        screen_pixels = $ScreenPoint
        keys = $Keys
        notes = $Notes
    }) | Out-Null
}

function Invoke-Click {
    param(
        [object]$Window,
        [object]$Point,
        [System.Collections.Generic.List[object]]$Actions,
        [string]$CurrentRunName,
        [string]$TargetIntent,
        [string]$Action = 'click'
    )

    Focus-Window -Window $Window
    $screenPoint = Convert-ScreenshotToScreenPoint -Window $Window -Point $Point
    [void][OxForms.W005Interaction.NativeMethods]::SetCursorPos($screenPoint.x, $screenPoint.y)
    Start-Sleep -Milliseconds $ActionDelayMilliseconds
    [OxForms.W005Interaction.NativeMethods]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [OxForms.W005Interaction.NativeMethods]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds $ActionDelayMilliseconds

    Add-InputAction -Actions $Actions -CurrentRunName $CurrentRunName -Method 'automated_sendinput_mouse' -TargetIntent $TargetIntent -Action $Action -ScreenshotPoint $Point -ScreenPoint $screenPoint -Keys $null -Notes 'Mouse event was injected with public user32 mouse_event after SetCursorPos.'
}

function Invoke-DoubleClick {
    param(
        [object]$Window,
        [object]$Point,
        [System.Collections.Generic.List[object]]$Actions,
        [string]$CurrentRunName,
        [string]$TargetIntent
    )

    Invoke-Click -Window $Window -Point $Point -Actions $Actions -CurrentRunName $CurrentRunName -TargetIntent $TargetIntent -Action 'double_click_first_click'
    Start-Sleep -Milliseconds 80
    Invoke-Click -Window $Window -Point $Point -Actions $Actions -CurrentRunName $CurrentRunName -TargetIntent $TargetIntent -Action 'double_click_second_click'
}

function Invoke-Drag {
    param(
        [object]$Window,
        [object]$StartPoint,
        [object]$EndPoint,
        [System.Collections.Generic.List[object]]$Actions,
        [string]$CurrentRunName,
        [string]$TargetIntent
    )

    Focus-Window -Window $Window
    $startScreen = Convert-ScreenshotToScreenPoint -Window $Window -Point $StartPoint
    $endScreen = Convert-ScreenshotToScreenPoint -Window $Window -Point $EndPoint
    [void][OxForms.W005Interaction.NativeMethods]::SetCursorPos($startScreen.x, $startScreen.y)
    Start-Sleep -Milliseconds $ActionDelayMilliseconds
    [OxForms.W005Interaction.NativeMethods]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds $ActionDelayMilliseconds
    [void][OxForms.W005Interaction.NativeMethods]::SetCursorPos($endScreen.x, $endScreen.y)
    Start-Sleep -Milliseconds ($ActionDelayMilliseconds * 2)
    [OxForms.W005Interaction.NativeMethods]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds $ActionDelayMilliseconds

    Add-InputAction -Actions $Actions -CurrentRunName $CurrentRunName -Method 'automated_sendinput_mouse' -TargetIntent $TargetIntent -Action 'drag_outside_bounds' -ScreenshotPoint ([ordered]@{ start = $StartPoint; end = $EndPoint }) -ScreenPoint ([ordered]@{ start = $startScreen; end = $endScreen }) -Keys $null -Notes 'Drag starts inside the label and releases outside the label half-open bounds to probe capture/out-of-bounds coordinates.'
}

function Invoke-KeySequence {
    param(
        [object]$Window,
        [string]$Keys,
        [System.Collections.Generic.List[object]]$Actions,
        [string]$CurrentRunName,
        [string]$TargetIntent,
        [string]$Notes = ''
    )

    Add-Type -AssemblyName System.Windows.Forms
    Focus-Window -Window $Window
    [System.Windows.Forms.SendKeys]::SendWait($Keys)
    Start-Sleep -Milliseconds ($ActionDelayMilliseconds * 2)

    Add-InputAction -Actions $Actions -CurrentRunName $CurrentRunName -Method 'automated_sendkeys' -TargetIntent $TargetIntent -Action 'key_sequence' -ScreenshotPoint $null -ScreenPoint $null -Keys $Keys -Notes $Notes
}

function Invoke-DriveExistingWindow {
    param(
        [string]$ResolvedOutDir,
        [string]$CurrentRunName,
        [object]$Fixture,
        [string]$Title
    )

    $window = Wait-ForOracleWindow -Title $Title -TimeoutSeconds 30
    $captureManifest = Invoke-CaptureWindow -ResolvedOutDir $ResolvedOutDir -CurrentRunName $CurrentRunName -Title $Title
    $calibration = Analyze-CaptureCoordinates -ResolvedOutDir $ResolvedOutDir -CurrentRunName $CurrentRunName -Fixture $Fixture -WindowManifest $captureManifest
    $window = Wait-ForOracleWindow -Title $Title -TimeoutSeconds 5

    $label = Get-ControlSpec -Fixture $Fixture -Name 'OracleProbeLabel'
    $textBox = Get-ControlSpec -Fixture $Fixture -Name 'OracleTextBox'
    $defaultButton = Get-ControlSpec -Fixture $Fixture -Name 'OracleDefaultButton'
    $cancelButton = Get-ControlSpec -Fixture $Fixture -Name 'OracleCancelButton'
    $actions = [System.Collections.Generic.List[object]]::new()

    $labelTopLeft = New-ScreenshotPointForControl -Control $label -Calibration $calibration -FractionX 0.08 -FractionY 0.12
    $labelCenter = New-ScreenshotPointForControl -Control $label -Calibration $calibration -FractionX 0.50 -FractionY 0.50
    $labelOutside = [ordered]@{
        x = [double]$calibration.form_origin_screenshot_pixels.x + (([double]$label.leftPt + [double]$label.widthPt + 12.0) * [double]$calibration.points_to_pixels)
        y = [double]$calibration.form_origin_screenshot_pixels.y + (([double]$label.topPt + [double]$label.heightPt + 8.0) * [double]$calibration.points_to_pixels)
    }
    $textBoxCenter = New-ScreenshotPointForControl -Control $textBox -Calibration $calibration -FractionX 0.50 -FractionY 0.50
    $okCenter = New-ScreenshotPointForControl -Control $defaultButton -Calibration $calibration -FractionX 0.50 -FractionY 0.50
    $cancelCenter = New-ScreenshotPointForControl -Control $cancelButton -Calibration $calibration -FractionX 0.50 -FractionY 0.50

    Invoke-Click -Window $window -Point $labelTopLeft -Actions $actions -CurrentRunName $CurrentRunName -TargetIntent 'OracleProbeLabel near top-left'
    Invoke-Click -Window $window -Point $labelCenter -Actions $actions -CurrentRunName $CurrentRunName -TargetIntent 'OracleProbeLabel center'
    Invoke-Drag -Window $window -StartPoint $labelCenter -EndPoint $labelOutside -Actions $actions -CurrentRunName $CurrentRunName -TargetIntent 'OracleProbeLabel capture/out-of-bounds drag'

    Invoke-Click -Window $window -Point $textBoxCenter -Actions $actions -CurrentRunName $CurrentRunName -TargetIntent 'OracleTextBox center focus'
    Invoke-KeySequence -Window $window -Keys 'ab' -Actions $actions -CurrentRunName $CurrentRunName -TargetIntent 'OracleTextBox character input' -Notes 'Printable text input intended to produce KeyDown/KeyPress/Change/KeyUp rows where MSForms raises them.'
    Invoke-KeySequence -Window $window -Keys '{BACKSPACE}' -Actions $actions -CurrentRunName $CurrentRunName -TargetIntent 'OracleTextBox Backspace'
    Invoke-KeySequence -Window $window -Keys '{TAB}' -Actions $actions -CurrentRunName $CurrentRunName -TargetIntent 'Tab focus transfer from TextBox'
    Invoke-KeySequence -Window $window -Keys '+{TAB}' -Actions $actions -CurrentRunName $CurrentRunName -TargetIntent 'Shift+Tab focus transfer back toward TextBox'
    Invoke-KeySequence -Window $window -Keys '{ENTER}' -Actions $actions -CurrentRunName $CurrentRunName -TargetIntent 'Default CommandButton Enter path'
    Invoke-KeySequence -Window $window -Keys '{ESC}' -Actions $actions -CurrentRunName $CurrentRunName -TargetIntent 'Cancel CommandButton Escape path'
    Invoke-KeySequence -Window $window -Keys '%o' -Actions $actions -CurrentRunName $CurrentRunName -TargetIntent 'Alt+O default button accelerator'
    Invoke-KeySequence -Window $window -Keys '%c' -Actions $actions -CurrentRunName $CurrentRunName -TargetIntent 'Alt+C cancel button accelerator'

    $window = Wait-ForOracleWindow -Title $Title -TimeoutSeconds 5
    Invoke-Click -Window $window -Point $okCenter -Actions $actions -CurrentRunName $CurrentRunName -TargetIntent 'OracleDefaultButton direct click'
    Invoke-Click -Window $window -Point $cancelCenter -Actions $actions -CurrentRunName $CurrentRunName -TargetIntent 'OracleCancelButton direct click'
    Invoke-DoubleClick -Window $window -Point $labelCenter -Actions $actions -CurrentRunName $CurrentRunName -TargetIntent 'OracleProbeLabel double-click probe'
    Invoke-DoubleClick -Window $window -Point $textBoxCenter -Actions $actions -CurrentRunName $CurrentRunName -TargetIntent 'OracleTextBox double-click probe'
    Invoke-DoubleClick -Window $window -Point $okCenter -Actions $actions -CurrentRunName $CurrentRunName -TargetIntent 'OracleDefaultButton double-click probe'

    Invoke-KeySequence -Window $window -Keys '%{F4}' -Actions $actions -CurrentRunName $CurrentRunName -TargetIntent 'UserForm close request via Alt+F4' -Notes 'Intended to produce QueryClose and Terminate/lifecycle rows if MSForms raises them for this run.'
    Wait-ForOracleWindowClosed -Title $Title -TimeoutSeconds 10

    $actionLog = [ordered]@{
        schema = 'oxforms.office_oracle.w005_input_actions.v1'
        bead = 'oxforms-xvx.3'
        run = $CurrentRunName
        manual_inputs = @()
        automated_inputs = @($actions)
        coordinate_vocabulary = @('screen_pixels', 'window_rect', 'screenshot_pixels', 'form_logical', 'control_local', 'msforms_event_args')
        assumptions = @(
            'Automated input target points are derived from fixture point geometry and the scoped probe-label calibration rectangle; live event rows remain the observed MSForms facts.',
            'The use of SendKeys and user32 mouse_event is evidence-driving infrastructure only and is not an OxForms runtime architecture decision.'
        )
    }
    $actionLogPath = Join-Path $ResolvedOutDir "$CurrentRunName-input-actions.json"
    Write-JsonFile -Value $actionLog -Path $actionLogPath

    return [ordered]@{
        run = $CurrentRunName
        capture_manifest = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir "$CurrentRunName-window\window-capture-manifest.json")
        coordinate_calibration = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir "$CurrentRunName-coordinate-calibration.json")
        input_actions = ConvertTo-RepoRelative $actionLogPath
    }
}

function Export-WorksheetLog {
    param(
        [object]$Workbook,
        [string]$ResolvedOutDir,
        [string]$CurrentRunName,
        [array]$AutomatedInputs
    )

    $sheet = $Workbook.Worksheets.Item('W005EventLog')
    $range = $sheet.UsedRange
    $rowCount = [int]$range.Rows.Count
    $columnCount = [int]$range.Columns.Count
    $values = $range.Value2

    $headers = @()
    for ($c = 1; $c -le $columnCount; $c++) {
        $headers += [string]$values[1, $c]
    }

    $rows = [System.Collections.Generic.List[object]]::new()
    for ($r = 2; $r -le $rowCount; $r++) {
        $row = [ordered]@{}
        for ($c = 1; $c -le $columnCount; $c++) {
            $row[$headers[$c - 1]] = $values[$r, $c]
        }
        $rows.Add([pscustomobject]$row) | Out-Null
    }

    $csvPath = Join-Path $ResolvedOutDir "$CurrentRunName-event-log.csv"
    @($rows) | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

    $eventLog = [ordered]@{
        schema = 'oxforms.office_oracle.w005_interaction_event_log.v1'
        bead = 'oxforms-xvx.3'
        run = $CurrentRunName
        source = [ordered]@{
            workbook = ConvertTo-RepoRelative $Workbook.FullName
            worksheet = 'W005EventLog'
            fixture = 'fixtures/office-oracle/excel-msforms/userforms/interaction-events/fixture.json'
        }
        observed_facts = [ordered]@{
            row_count = $rows.Count
            event_names = @($rows | ForEach-Object { $_.event_name } | Sort-Object -Unique)
            targets = @($rows | ForEach-Object { $_.target_name } | Sort-Object -Unique)
            event_rows = @($rows)
        }
        assumptions = @(
            'Rows under observed_facts are worksheet rows emitted by repo-owned VBA handlers while real Excel/MSForms handled the driven input.',
            'Absence of an event row is not a negative parity fact; this capture records only the events raised by this fixture and input run.',
            'Coordinate values in observed rows with coordinate_space=msforms_event_args are live VBA event arguments; derived screen/screenshot/form/control points live in the input action and coordinate calibration artifacts.'
        )
        manual_inputs = @()
        automated_inputs = @($AutomatedInputs)
        non_claims = @(
            'This event log is not an exhaustive MSForms event parity claim.',
            'This event log is not an OxForms comparison artifact.'
        )
    }

    $jsonPath = Join-Path $ResolvedOutDir "$CurrentRunName-event-log.json"
    Write-JsonFile -Value $eventLog -Path $jsonPath

    return [ordered]@{
        csv = ConvertTo-RepoRelative $csvPath
        json = ConvertTo-RepoRelative $jsonPath
        row_count = $rows.Count
        event_names = $eventLog.observed_facts.event_names
        targets = $eventLog.observed_facts.targets
    }
}

function Release-ComObjectIfPresent {
    param($Object)

    if ($null -ne $Object -and [System.Runtime.InteropServices.Marshal]::IsComObject($Object)) {
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($Object)
    }
}

function Write-CaptureReadme {
    param(
        [string]$ResolvedOutDir,
        [object]$Manifest
    )

    $lines = @(
        '# W005 Interaction Event Oracle Capture',
        '',
        "Capture id: $($Manifest.capture_id)",
        "Bead: $($Manifest.bead)",
        '',
        'This directory contains black-box Excel/MSForms event evidence for the W005 interaction fixture. It is not an OxForms output comparison and it does not claim exhaustive MSForms event parity.',
        '',
        '## Observed Facts',
        '',
        '- `modeless-event-log.json` and `modeless-event-log.csv` contain observed worksheet rows emitted by the fixture''s VBA event handlers.',
        '- `modeless-input-actions.json` records the automated public Windows input used to drive the form; `manual_inputs` is empty.',
        '- `modeless-coordinate-calibration.json` records screenshot-to-fixture coordinate derivations using the W005 coordinate vocabulary and scopes border-color detection to the probe-label fill neighborhood.',
        '',
        '## Assumptions',
        '',
        '- Input target points are derived from fixture point geometry and the scoped probe-label calibration rectangle.',
        '- Missing event rows are not negative facts about MSForms; they are simply unobserved in this run.',
        '- The automation helper is evidence infrastructure only and not runtime architecture.',
        '',
        '## Clean-room Note',
        '',
        'The capture used repo-owned fixture sources, public Excel/VBIDE automation, public VBA event handlers, and public Windows desktop input/capture APIs. It did not use private Office internals, decompilation, disassembly, or OxForms output comparison.'
    )

    Set-Content -LiteralPath (Join-Path $ResolvedOutDir 'README.md') -Value $lines -Encoding UTF8
}

function Write-Checksums {
    param(
        [string]$ResolvedOutDir
    )

    $checksumPath = Join-Path $ResolvedOutDir 'checksums.sha256'
    $files = Get-ChildItem -LiteralPath $ResolvedOutDir -Recurse -File |
        Where-Object { $_.FullName -ne $checksumPath } |
        Sort-Object FullName

    $lines = foreach ($file in $files) {
        try {
            "$(Get-Sha256Hex -Path $file.FullName)  $(ConvertTo-RepoRelative $file.FullName)"
        } catch {
            Write-Warning "Skipping checksum for file that is not readable yet: $($file.FullName): $($_.Exception.Message)"
        }
    }

    Set-Content -LiteralPath $checksumPath -Value $lines -Encoding ASCII
}

function Invoke-MainCapture {
    param([string]$ResolvedOutDir)

    $fixtureRoot = Resolve-RepoPath $FixtureDir
    $fixturePath = Join-Path $fixtureRoot 'fixture.json'
    $fixture = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
    $captureId = Split-Path -Leaf $ResolvedOutDir
    $workbookPath = Join-Path $ResolvedOutDir 'w005-interaction-events-oracle.xlsm'

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
        -CommandPath (Join-Path $ResolvedOutDir 'generate-workbook.command.txt') `
        -StdoutPath (Join-Path $ResolvedOutDir 'generate-workbook.stdout.log') `
        -StderrPath (Join-Path $ResolvedOutDir 'generate-workbook.stderr.log')

    $excel = $null
    $workbook = $null
    $modelessDrive = $null
    $modalDrive = $null
    $modelessLog = $null
    $modalLog = $null
    $excelInfo = $null

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
        $version = $null
        if (Test-Path -LiteralPath $excelPath -PathType Leaf) {
            $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($excelPath)
            $version = [ordered]@{
                path = $excelPath
                file_version = $versionInfo.FileVersion
                product_version = $versionInfo.ProductVersion
                product_name = $versionInfo.ProductName
                company_name = $versionInfo.CompanyName
            }
        }
        $excelInfo = $version

        $workbook = $excel.Workbooks.Open($workbookPath)

        $excel.Run('ClearW005InteractionLog')
        $excel.Run($fixture.workbook.showMacroName)
        $modelessDrive = Invoke-DriveExistingWindow -ResolvedOutDir $ResolvedOutDir -CurrentRunName 'modeless' -Fixture $fixture -Title $WindowTitle
        $modelessActionsPath = Join-Path $ResolvedOutDir 'modeless-input-actions.json'
        $modelessActions = @((Get-Content -Raw -LiteralPath $modelessActionsPath | ConvertFrom-Json).automated_inputs)
        $modelessLog = Export-WorksheetLog -Workbook $workbook -ResolvedOutDir $ResolvedOutDir -CurrentRunName 'modeless' -AutomatedInputs $modelessActions

        if (-not $SkipModal) {
            $excel.Run('ClearW005InteractionLog')

            $driveArgs = @(
                '-NoProfile',
                '-ExecutionPolicy', 'Bypass',
                '-File', (Join-Path $repoRoot 'tools\office-oracle\Capture-W005InteractionEvents.ps1'),
                '-DriveOnly',
                '-OutDir', $ResolvedOutDir,
                '-RunName', 'modal',
                '-WindowTitle', $WindowTitle,
                '-ActionDelayMilliseconds', [string]$ActionDelayMilliseconds
            )
            $driveCommandText = 'powershell.exe ' + (($driveArgs | ForEach-Object {
                if ($_ -match '\s|"' ) {
                    '"' + ($_ -replace '"', '\"') + '"'
                } else {
                    $_
                }
            }) -join ' ')
            Set-Content -LiteralPath (Join-Path $ResolvedOutDir 'drive-modal.command.txt') -Value $driveCommandText -Encoding UTF8
            $job = Start-Job -ScriptBlock {
                param([string[]]$Arguments)
                & powershell.exe @Arguments
                exit $LASTEXITCODE
            } -ArgumentList (, $driveArgs)

            $excel.Run('ShowW005InteractionOracleModal')

            Wait-Job -Job $job -Timeout 60 | Out-Null
            $modalJobOutput = Receive-Job -Job $job -Keep 4>&1
            $modalJobOutput | Set-Content -LiteralPath (Join-Path $ResolvedOutDir 'drive-modal.stdout.log') -Encoding UTF8
            if ($job.State -ne 'Completed') {
                Stop-Job -Job $job -ErrorAction SilentlyContinue
                throw "Modal drive job did not complete; state=$($job.State)."
            }
            if ($job.ChildJobs[0].JobStateInfo.Reason) {
                throw "Modal drive job failed: $($job.ChildJobs[0].JobStateInfo.Reason.Message)"
            }
            Set-Content -LiteralPath (Join-Path $ResolvedOutDir 'drive-modal.stderr.log') -Value '' -Encoding UTF8
            Remove-Job -Job $job

            $modalDrive = [ordered]@{
                run = 'modal'
                capture_manifest = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'modal-window\window-capture-manifest.json')
                coordinate_calibration = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'modal-coordinate-calibration.json')
                input_actions = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'modal-input-actions.json')
            }
            $modalActions = @((Get-Content -Raw -LiteralPath (Join-Path $ResolvedOutDir 'modal-input-actions.json') | ConvertFrom-Json).automated_inputs)
            $modalLog = Export-WorksheetLog -Workbook $workbook -ResolvedOutDir $ResolvedOutDir -CurrentRunName 'modal' -AutomatedInputs $modalActions
        }

        $workbook.Save()
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

    $runSummary = [ordered]@{
        schema = 'oxforms.office_oracle.w005_interaction_run_summary.v1'
        bead = 'oxforms-xvx.3'
        capture_id = $captureId
        runs = @(
            [ordered]@{
                name = 'modeless'
                show_mode = 'show_mode=modeless'
                row_count = $modelessLog.row_count
                event_names = $modelessLog.event_names
                targets = $modelessLog.targets
                drive_artifacts = $modelessDrive
                event_log = $modelessLog
            }
        )
        notes = @(
            'Observed event rows are facts from the generated workbook W005EventLog sheet.',
            'The capture does not compare OxForms output and does not claim exhaustive MSForms event parity.'
        )
    }
    if ($null -ne $modalLog) {
        $runSummary.runs += [ordered]@{
            name = 'modal'
            show_mode = 'show_mode=modal'
            row_count = $modalLog.row_count
            event_names = $modalLog.event_names
            targets = $modalLog.targets
            drive_artifacts = $modalDrive
            event_log = $modalLog
        }
    }
    $runSummaryPath = Join-Path $ResolvedOutDir 'run-summary.json'
    Write-JsonFile -Value $runSummary -Path $runSummaryPath

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
        schema = 'oxforms.office_oracle.w005_interaction_event_capture.v1'
        bead = 'oxforms-xvx.3'
        capture_id = $captureId
        fixture = [ordered]@{
            id = $fixture.id
            inputs = $fixtureHashes
        }
        commands = [ordered]@{
            generator = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'generate-workbook.command.txt')
            modeless_capture_window = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'capture-window-modeless.command.txt')
            modal_drive = if ($SkipModal) { $null } else { ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'drive-modal.command.txt') }
            rerun_note = 'Run this script from the repository root. It generates the workbook, opens Excel, drives modeless input, optionally drives modal input, exports W005EventLog, writes manifests, and checksums artifacts.'
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
            modeless = [ordered]@{
                window_capture_manifest = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'modeless-window\window-capture-manifest.json')
                screenshot = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'modeless-window\window-capture.png')
                coordinate_calibration = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'modeless-coordinate-calibration.json')
                input_actions = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'modeless-input-actions.json')
                event_log_json = $modelessLog.json
                event_log_csv = $modelessLog.csv
            }
            modal = if ($null -ne $modalLog) {
                [ordered]@{
                    window_capture_manifest = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'modal-window\window-capture-manifest.json')
                    screenshot = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'modal-window\window-capture.png')
                    coordinate_calibration = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'modal-coordinate-calibration.json')
                    input_actions = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'modal-input-actions.json')
                    event_log_json = $modalLog.json
                    event_log_csv = $modalLog.csv
                }
            } else {
                $null
            }
            command_logs = (@(
                ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'capture-w005.stdout.log'),
                ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'capture-w005.stderr.log'),
                ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'generate-workbook.stdout.log'),
                ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'generate-workbook.stderr.log'),
                ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'capture-window-modeless.stdout.log'),
                ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'capture-window-modeless.stderr.log'),
                ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'capture-window-modal.stdout.log'),
                ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'capture-window-modal.stderr.log'),
                ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'drive-modal.stdout.log'),
                ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'drive-modal.stderr.log')
            ) | Where-Object { $null -ne $_ -and (Test-Path -LiteralPath (Join-Path $repoRoot $_) -PathType Leaf) })
        }
        observed_coverage = [ordered]@{
            modeless_event_names = $modelessLog.event_names
            modal_event_names = if ($null -ne $modalLog) { $modalLog.event_names } else { @() }
            manual_inputs = @()
            input_method = 'automated public Windows SendKeys/user32 mouse_event'
        }
        warnings = @(
            'This is black-box Excel/MSForms event evidence only; no OxForms output was compared.',
            'The capture is not an exhaustive MSForms event parity claim.',
            'Automation target coordinates are derived evidence annotations; live MSForms event X/Y values remain in event log rows tagged msforms_event_args.',
            'Probe label border calibration scopes exact border-color matching to the label fill neighborhood so unrelated window or sibling-control pixels cannot expand the label rectangle.',
            'Desktop theme, DPI, input focus, and Excel/MSForms version can affect observed ordering and screenshots.'
        )
        clean_room = [ordered]@{
            source = 'Repo-owned fixture input generated through public Excel/VBIDE automation and driven through public Windows input APIs.'
            prohibited = 'No Office internals, decompilation, disassembly, or non-public source were used.'
        }
    }

    $manifestPath = Join-Path $ResolvedOutDir 'oracle-capture-manifest.json'
    Write-JsonFile -Value $manifest -Path $manifestPath
    Write-CaptureReadme -ResolvedOutDir $ResolvedOutDir -Manifest $manifest
    Write-Checksums -ResolvedOutDir $ResolvedOutDir

    Write-Host "W005 interaction capture complete: $ResolvedOutDir"
    Write-Host "Modeless rows: $($modelessLog.row_count)"
    if ($null -ne $modalLog) {
        Write-Host "Modal rows: $($modalLog.row_count)"
    }
}

$resolvedOutDir = Resolve-CaptureDir -Directory $OutDir
Set-Location $repoRoot

if ($DriveOnly) {
    $fixtureRoot = Resolve-RepoPath $FixtureDir
    $fixturePath = Join-Path $fixtureRoot 'fixture.json'
    $fixture = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
    [void](Invoke-DriveExistingWindow -ResolvedOutDir $resolvedOutDir -CurrentRunName $RunName -Fixture $fixture -Title $WindowTitle)
    exit 0
}

Invoke-MainCapture -ResolvedOutDir $resolvedOutDir
