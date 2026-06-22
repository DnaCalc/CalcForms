# Windows top-level window discovery and screenshot capture for Office
# oracle evidence. This is local test tooling, not an OxForms runtime API.
[CmdletBinding()]
param(
    [switch]$SelfTest,
    [string]$TitleContains,
    [string]$ProcessName,
    [string]$ProcessContains,
    [string]$ClassName,
    [string]$OutDir,
    [switch]$CaptureScreenshot,
    [switch]$AllowAmbiguous
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Script:EvidenceRoot = (Resolve-Path -LiteralPath (Join-Path $Script:RepoRoot 'docs\evidence')).Path

function Test-RunningOnWindows {
    if ($PSVersionTable.PSEdition -eq 'Core') {
        return $IsWindows
    }

    return [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
}

function New-Diagnostic {
    param(
        [string]$Code,
        [string]$Message,
        [ValidateSet('info', 'warning', 'error')]
        [string]$Severity = 'error'
    )

    [ordered]@{
        code = $Code
        severity = $Severity
        message = $Message
    }
}

function New-Result {
    param(
        [string]$Mode,
        [hashtable]$Query
    )

    [ordered]@{
        schema = 'oxforms.office_oracle.window_capture.v1'
        tool = 'tools/office-oracle/Capture-Window.ps1'
        mode = $Mode
        timestamp_utc = (Get-Date).ToUniversalTime().ToString('o')
        command = [System.Environment]::CommandLine
        host = [ordered]@{
            os = [System.Environment]::OSVersion.VersionString
            is_windows = (Test-RunningOnWindows)
            powershell = $PSVersionTable.PSVersion.ToString()
        }
        query = $Query
        status = 'failed'
        diagnostics = @()
        visible_top_level_window_count = $null
        match_count = 0
        candidates = @()
        selected_window = $null
        screenshot = $null
        manifest_path = $null
    }
}

function ConvertTo-JsonText {
    param([object]$Value)
    $Value | ConvertTo-Json -Depth 12
}

function Write-Manifest {
    param(
        [object]$Result,
        [string]$Directory,
        [string]$FileName
    )

    if ([string]::IsNullOrWhiteSpace($Directory)) {
        return
    }

    $manifestPath = Join-Path $Directory $FileName
    $Result.manifest_path = [System.IO.Path]::GetFullPath($manifestPath)
    ConvertTo-JsonText -Value $Result | Set-Content -LiteralPath $manifestPath -Encoding UTF8
}

function Resolve-CaptureOutDir {
    param([string]$Directory)

    if ([string]::IsNullOrWhiteSpace($Directory)) {
        throw 'An output directory is required when writing a manifest or screenshot.'
    }

    if ([System.IO.Path]::IsPathRooted($Directory)) {
        $fullPath = [System.IO.Path]::GetFullPath($Directory)
    }
    else {
        $fullPath = [System.IO.Path]::GetFullPath((Join-Path $Script:RepoRoot $Directory))
    }

    $evidenceRoot = [System.IO.Path]::GetFullPath($Script:EvidenceRoot)
    $rootWithSeparator = $evidenceRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    if (-not $fullPath.StartsWith($rootWithSeparator, $comparison)) {
        throw "Output directory '$fullPath' is outside the repository evidence root '$evidenceRoot'."
    }

    $relativePath = $fullPath.Substring($rootWithSeparator.Length).Replace([System.IO.Path]::AltDirectorySeparatorChar, [System.IO.Path]::DirectorySeparatorChar)
    $segments = @($relativePath.Split([System.IO.Path]::DirectorySeparatorChar, [System.StringSplitOptions]::RemoveEmptyEntries))
    if ($segments.Count -lt 2 -or -not $segments[1].Equals('captures', $comparison)) {
        throw "Output directory '$fullPath' must be under a documented workset capture path like 'docs\\evidence\\<workset>\\captures\\...'."
    }

    if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
        throw "Output path '$fullPath' exists as a file; expected a directory."
    }

    New-Item -ItemType Directory -Force -Path $fullPath | Out-Null
    return (Resolve-Path -LiteralPath $fullPath).Path
}

function Ensure-WindowsNativeTypes {
    if (-not (Test-RunningOnWindows)) {
        return
    }

    if (([System.Management.Automation.PSTypeName]'OxForms.OfficeOracle.NativeMethods').Type) {
        return
    }

    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace OxForms.OfficeOracle
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
        public static extern uint GetDpiForWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    }
}
'@
}

function Get-WindowTextValue {
    param([System.IntPtr]$Handle)

    $length = [OxForms.OfficeOracle.NativeMethods]::GetWindowTextLengthW($Handle)
    $capacity = [Math]::Max($length + 1, 256)
    $builder = [System.Text.StringBuilder]::new($capacity)
    [void][OxForms.OfficeOracle.NativeMethods]::GetWindowTextW($Handle, $builder, $builder.Capacity)
    return $builder.ToString()
}

function Get-ClassNameValue {
    param([System.IntPtr]$Handle)

    $builder = [System.Text.StringBuilder]::new(256)
    [void][OxForms.OfficeOracle.NativeMethods]::GetClassNameW($Handle, $builder, $builder.Capacity)
    return $builder.ToString()
}

function Get-WindowDpi {
    param([System.IntPtr]$Handle)

    try {
        $dpi = [OxForms.OfficeOracle.NativeMethods]::GetDpiForWindow($Handle)
        if ($dpi -gt 0) {
            return [int]$dpi
        }
    }
    catch {
        return $null
    }

    return $null
}

function Get-TopLevelWindows {
    Ensure-WindowsNativeTypes
    $windows = [System.Collections.Generic.List[object]]::new()

    $callback = [OxForms.OfficeOracle.NativeMethods+EnumWindowsProc]{
        param([System.IntPtr]$Handle, [System.IntPtr]$Param)

        if (-not [OxForms.OfficeOracle.NativeMethods]::IsWindowVisible($Handle)) {
            return $true
        }

        $title = Get-WindowTextValue -Handle $Handle
        if ([string]::IsNullOrWhiteSpace($title)) {
            return $true
        }

        $class = Get-ClassNameValue -Handle $Handle
        $processIdValue = [uint32]0
        [void][OxForms.OfficeOracle.NativeMethods]::GetWindowThreadProcessId($Handle, [ref]$processIdValue)

        $processName = $null
        $processPath = $null
        try {
            $process = Get-Process -Id ([int]$processIdValue) -ErrorAction Stop
            $processName = $process.ProcessName
            try {
                $processPath = $process.Path
            }
            catch {
                $processPath = $null
            }
        }
        catch {
            $processName = $null
        }

        $rect = New-Object OxForms.OfficeOracle.NativeMethods+RECT
        $hasRect = [OxForms.OfficeOracle.NativeMethods]::GetWindowRect($Handle, [ref]$rect)
        $bounds = $null
        if ($hasRect) {
            $bounds = [ordered]@{
                left = $rect.Left
                top = $rect.Top
                right = $rect.Right
                bottom = $rect.Bottom
                width = [Math]::Max(0, $rect.Right - $rect.Left)
                height = [Math]::Max(0, $rect.Bottom - $rect.Top)
            }
        }

        $windows.Add([ordered]@{
            handle = ('0x{0:X}' -f $Handle.ToInt64())
            title = $title
            class_name = $class
            process_id = [int]$processIdValue
            process_name = $processName
            process_path = $processPath
            bounds = $bounds
            dpi = (Get-WindowDpi -Handle $Handle)
        }) | Out-Null

        return $true
    }

    [void][OxForms.OfficeOracle.NativeMethods]::EnumWindows($callback, [System.IntPtr]::Zero)
    return @($windows)
}

function Test-WindowMatchesQuery {
    param(
        [object]$Window,
        [hashtable]$Query
    )

    $comparison = [System.StringComparison]::OrdinalIgnoreCase

    if (-not [string]::IsNullOrWhiteSpace($Query.title_contains)) {
        if ($Window.title.IndexOf($Query.title_contains, $comparison) -lt 0) {
            return $false
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Query.class_name)) {
        if (-not [string]::Equals($Window.class_name, $Query.class_name, $comparison)) {
            return $false
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Query.process_name)) {
        if (-not [string]::Equals($Window.process_name, $Query.process_name, $comparison)) {
            return $false
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Query.process_contains)) {
        $haystack = "$($Window.process_name) $($Window.process_path)"
        if ($haystack.IndexOf($Query.process_contains, $comparison) -lt 0) {
            return $false
        }
    }

    return $true
}

function New-CandidateSummary {
    param([object]$Window)

    [ordered]@{
        handle = $Window.handle
        title = $Window.title
        class_name = $Window.class_name
        process_id = $Window.process_id
        process_name = $Window.process_name
        bounds = $Window.bounds
    }
}

function Save-WindowScreenshot {
    param(
        [object]$Window,
        [string]$Directory
    )

    if ($null -eq $Window.bounds -or $Window.bounds.width -le 0 -or $Window.bounds.height -le 0) {
        throw 'Selected window has empty or unavailable bounds.'
    }

    Add-Type -AssemblyName System.Drawing

    $handleValue = [System.IntPtr]::new([Convert]::ToInt64($Window.handle.Substring(2), 16))
    $hwndTopMost = [System.IntPtr]::new(-1)
    $hwndNoTopMost = [System.IntPtr]::new(-2)
    $swpNoMove = 0x0002
    $swpNoSize = 0x0001
    [void][OxForms.OfficeOracle.NativeMethods]::ShowWindow($handleValue, 5)
    [void][OxForms.OfficeOracle.NativeMethods]::SetWindowPos($handleValue, $hwndTopMost, 0, 0, 0, 0, ($swpNoMove -bor $swpNoSize))
    [void][OxForms.OfficeOracle.NativeMethods]::SetForegroundWindow($handleValue)
    Start-Sleep -Milliseconds 300

    $imagePath = Join-Path $Directory 'window-capture.png'
    $bitmap = [System.Drawing.Bitmap]::new([int]$Window.bounds.width, [int]$Window.bounds.height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen([int]$Window.bounds.left, [int]$Window.bounds.top, 0, 0, $bitmap.Size)
        $bitmap.Save($imagePath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
        [void][OxForms.OfficeOracle.NativeMethods]::SetWindowPos($handleValue, $hwndNoTopMost, 0, 0, 0, 0, ($swpNoMove -bor $swpNoSize))
    }

    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $imagePath
    [ordered]@{
        path = (Resolve-Path -LiteralPath $imagePath).Path
        sha256 = $hash.Hash.ToLowerInvariant()
        width = [int]$Window.bounds.width
        height = [int]$Window.bounds.height
        format = 'png'
    }
}

function Invoke-WindowCapture {
    param(
        [hashtable]$Query,
        [string]$Directory,
        [bool]$ShouldCaptureScreenshot,
        [bool]$ShouldAllowAmbiguous,
        [string]$Mode = 'capture'
    )

    $result = New-Result -Mode $Mode -Query $Query
    $resolvedOutDir = $null

    if (-not (Test-RunningOnWindows)) {
        $result.status = 'unsupported'
        $result.diagnostics += New-Diagnostic -Code 'unsupported_platform' -Severity 'info' -Message 'Window discovery and screenshot capture require Windows desktop APIs.'
        return $result
    }

    if ([string]::IsNullOrWhiteSpace($Query.title_contains) -and
        [string]::IsNullOrWhiteSpace($Query.class_name) -and
        [string]::IsNullOrWhiteSpace($Query.process_name) -and
        [string]::IsNullOrWhiteSpace($Query.process_contains)) {
        $result.diagnostics += New-Diagnostic -Code 'invalid_query' -Message 'At least one of -TitleContains, -ProcessName, -ProcessContains, or -ClassName is required.'
        return $result
    }

    if ($ShouldCaptureScreenshot -and [string]::IsNullOrWhiteSpace($Directory)) {
        $result.diagnostics += New-Diagnostic -Code 'invalid_output_path' -Message 'CaptureScreenshot requires -OutDir so the image can be written under a documented workset capture evidence path.'
        return $result
    }

    if (-not [string]::IsNullOrWhiteSpace($Directory)) {
        try {
            $resolvedOutDir = Resolve-CaptureOutDir -Directory $Directory
        }
        catch {
            $result.diagnostics += New-Diagnostic -Code 'invalid_output_path' -Message $_.Exception.Message
            return $result
        }
    }

    try {
        $windows = Get-TopLevelWindows
        $result.visible_top_level_window_count = $windows.Count
        $matches = @($windows | Where-Object { Test-WindowMatchesQuery -Window $_ -Query $Query })
        $result.match_count = $matches.Count
        $result.candidates = @($matches | Select-Object -First 12 | ForEach-Object { New-CandidateSummary -Window $_ })

        if ($matches.Count -eq 0) {
            $result.diagnostics += New-Diagnostic -Code 'no_matching_window' -Message 'No visible top-level window matched the supplied title/process/class filters.'
            Write-Manifest -Result $result -Directory $resolvedOutDir -FileName 'window-capture-manifest.json'
            return $result
        }

        if ($matches.Count -gt 1 -and -not $ShouldAllowAmbiguous) {
            $result.diagnostics += New-Diagnostic -Code 'ambiguous_target' -Message "The query matched $($matches.Count) windows. Add another filter or pass -AllowAmbiguous to select the first match."
            Write-Manifest -Result $result -Directory $resolvedOutDir -FileName 'window-capture-manifest.json'
            return $result
        }

        $selected = $matches[0]
        $result.selected_window = $selected

        if ($ShouldCaptureScreenshot) {
            try {
                $result.screenshot = Save-WindowScreenshot -Window $selected -Directory $resolvedOutDir
            }
            catch {
                $result.diagnostics += New-Diagnostic -Code 'screenshot_failure' -Message $_.Exception.Message
                Write-Manifest -Result $result -Directory $resolvedOutDir -FileName 'window-capture-manifest.json'
                return $result
            }
        }

        $result.status = 'ok'
        if (-not $ShouldCaptureScreenshot) {
            $result.diagnostics += New-Diagnostic -Code 'metadata_only' -Severity 'info' -Message 'Window metadata was captured without a screenshot because -CaptureScreenshot was not supplied.'
        }
        Write-Manifest -Result $result -Directory $resolvedOutDir -FileName 'window-capture-manifest.json'
        return $result
    }
    catch {
        $result.diagnostics += New-Diagnostic -Code 'window_discovery_failure' -Message $_.Exception.Message
        Write-Manifest -Result $result -Directory $resolvedOutDir -FileName 'window-capture-manifest.json'
        return $result
    }
}

function Invoke-SelfTest {
    param([string]$Directory)

    if ([string]::IsNullOrWhiteSpace($Directory)) {
        $Directory = 'docs\evidence\W003_excel_forms_oracle_capture\captures\self-test'
    }

    $query = @{
        title_contains = $null
        process_name = $null
        process_contains = $null
        class_name = $null
    }
    $result = New-Result -Mode 'self-test' -Query $query
    $resolvedOutDir = $null

    try {
        $resolvedOutDir = Resolve-CaptureOutDir -Directory $Directory
    }
    catch {
        $result.diagnostics += New-Diagnostic -Code 'invalid_output_path' -Message $_.Exception.Message
        return $result
    }

    if (-not (Test-RunningOnWindows)) {
        $result.status = 'unsupported'
        $result.diagnostics += New-Diagnostic -Code 'unsupported_platform' -Severity 'info' -Message 'Self-test reports unsupported because this host is not Windows.'
        Write-Manifest -Result $result -Directory $resolvedOutDir -FileName 'self-test-manifest.json'
        return $result
    }

    $noTargetTitle = "OxForms Office Oracle Intentional No Target $PID"
    $noTarget = Invoke-WindowCapture -Mode 'self-test-no-target' -Query @{
        title_contains = $noTargetTitle
        process_name = $null
        process_contains = $null
        class_name = $null
    } -Directory (Join-Path $resolvedOutDir 'no-target') -ShouldCaptureScreenshot $false -ShouldAllowAmbiguous $false

    $sample = $null
    $form = $null
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $sampleTitle = "OxForms Office Oracle Capture Self Test $PID"
        $form = [System.Windows.Forms.Form]::new()
        $form.Text = $sampleTitle
        $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
        $form.Location = [System.Drawing.Point]::new(80, 80)
        $form.Size = [System.Drawing.Size]::new(260, 170)
        $form.BackColor = [System.Drawing.Color]::White
        $form.TopMost = $true

        $panel = [System.Windows.Forms.Panel]::new()
        $panel.Location = [System.Drawing.Point]::new(48, 42)
        $panel.Size = [System.Drawing.Size]::new(140, 60)
        $panel.BackColor = [System.Drawing.Color]::FromArgb(32, 96, 168)
        $form.Controls.Add($panel)

        $form.Show()
        $form.Activate()
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 300

        $sample = Invoke-WindowCapture -Mode 'self-test-sample' -Query @{
            title_contains = $sampleTitle
            process_name = (Get-Process -Id $PID).ProcessName
            process_contains = $null
            class_name = $null
        } -Directory (Join-Path $resolvedOutDir 'sample') -ShouldCaptureScreenshot $true -ShouldAllowAmbiguous $false
    }
    catch {
        $sample = New-Result -Mode 'self-test-sample' -Query @{
            title_contains = 'OxForms Office Oracle Capture Self Test'
            process_name = (Get-Process -Id $PID).ProcessName
            process_contains = $null
            class_name = $null
        }
        $sample.diagnostics += New-Diagnostic -Code 'self_test_window_failure' -Message $_.Exception.Message
    }
    finally {
        if ($null -ne $form) {
            $form.Close()
            $form.Dispose()
        }
    }

    $noTargetWasExpected = ($noTarget.status -eq 'failed' -and @($noTarget.diagnostics | Where-Object { $_.code -eq 'no_matching_window' }).Count -gt 0)
    $sampleSucceeded = ($null -ne $sample -and $sample.status -eq 'ok' -and $null -ne $sample.screenshot)

    $result.self_test = [ordered]@{
        no_target_expected_failure = $noTargetWasExpected
        sample_window_capture = $sampleSucceeded
        no_target = $noTarget
        sample = $sample
    }

    if ($noTargetWasExpected -and $sampleSucceeded) {
        $result.status = 'ok'
        $result.diagnostics += New-Diagnostic -Code 'self_test_ok' -Severity 'info' -Message 'Self-test observed the expected no-target diagnostic and captured the native sample window.'
    }
    else {
        $result.diagnostics += New-Diagnostic -Code 'self_test_failure' -Message 'Self-test did not complete both the expected no-target diagnostic and sample-window screenshot capture.'
    }

    Write-Manifest -Result $result -Directory $resolvedOutDir -FileName 'self-test-manifest.json'
    return $result
}

$query = @{
    title_contains = $TitleContains
    process_name = $ProcessName
    process_contains = $ProcessContains
    class_name = $ClassName
}

if ($SelfTest) {
    $captureResult = Invoke-SelfTest -Directory $OutDir
}
else {
    $captureResult = Invoke-WindowCapture -Query $query -Directory $OutDir -ShouldCaptureScreenshot ([bool]$CaptureScreenshot) -ShouldAllowAmbiguous ([bool]$AllowAmbiguous)
}

ConvertTo-JsonText -Value $captureResult

if ($captureResult.status -eq 'ok' -or $captureResult.status -eq 'unsupported') {
    exit 0
}

exit 1
