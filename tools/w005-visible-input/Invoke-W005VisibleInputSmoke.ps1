[CmdletBinding()]
param(
    [string]$OutDir,
    [switch]$Force,
    [int]$HoldMilliseconds = 15000,
    [int]$ActionDelayMilliseconds = 180
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$captureRoot = Join-Path $repoRoot 'docs\evidence\W005_input_interaction_model_exploration\captures'
$title = 'OxForms W005 Visible Input Smoke'
$processName = 'w005_visible_input_smoke'
Import-Module (Join-Path $repoRoot 'tools\W005WindowsInputDiagnostics.psm1') -Force

function Resolve-CaptureDir {
    param([string]$Directory)

    if ([string]::IsNullOrWhiteSpace($Directory)) {
        $Directory = Join-Path $captureRoot ('visible-input-smoke-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))
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

    if ((Test-Path -LiteralPath $fullPath) -and -not $Force) {
        throw "OutDir already exists: $fullPath. Pass -Force to reuse it."
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

function ConvertTo-DirectoryRelative {
    param(
        [Parameter(Mandatory = $true)][string]$Directory,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $directoryFull = [System.IO.Path]::GetFullPath($Directory).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    $directoryWithSeparator = $directoryFull + [System.IO.Path]::DirectorySeparatorChar
    if (-not $pathFull.StartsWith($directoryWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path '$Path' is not under '$Directory'."
    }

    return $pathFull.Substring($directoryWithSeparator.Length).Replace([System.IO.Path]::DirectorySeparatorChar, '/').Replace([System.IO.Path]::AltDirectorySeparatorChar, '/')
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

    $Value | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Invoke-LoggedProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
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
    Set-Content -LiteralPath $CommandPath -Encoding UTF8 -Value ($FilePath + ' ' + $argumentString)
    $process = Start-Process -FilePath $FilePath -ArgumentList $argumentString -Wait -PassThru -NoNewWindow -RedirectStandardOutput $StdoutPath -RedirectStandardError $StderrPath
    if ($process.ExitCode -ne 0) {
        throw "Command failed with exit code $($process.ExitCode): $FilePath $argumentString"
    }
}

function Ensure-NativeTypes {
    if (([System.Management.Automation.PSTypeName]'OxForms.W005VisibleInput.NativeMethods').Type) {
        return
    }

    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace OxForms.W005VisibleInput
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

        [StructLayout(LayoutKind.Sequential)]
        public struct POINT
        {
            public int X;
            public int Y;
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

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool GetClientRect(IntPtr hWnd, out RECT rect);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool ClientToScreen(IntPtr hWnd, ref POINT point);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern bool PostMessageW(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    }
}
'@
}

function Get-WindowTextValue {
    param([System.IntPtr]$Handle)
    $length = [OxForms.W005VisibleInput.NativeMethods]::GetWindowTextLengthW($Handle)
    $builder = [System.Text.StringBuilder]::new([Math]::Max($length + 1, 256))
    [void][OxForms.W005VisibleInput.NativeMethods]::GetWindowTextW($Handle, $builder, $builder.Capacity)
    return $builder.ToString()
}

function Get-ClassNameValue {
    param([System.IntPtr]$Handle)
    $builder = [System.Text.StringBuilder]::new(256)
    [void][OxForms.W005VisibleInput.NativeMethods]::GetClassNameW($Handle, $builder, $builder.Capacity)
    return $builder.ToString()
}

function Get-TopLevelWindows {
    Ensure-NativeTypes
    $windows = [System.Collections.Generic.List[object]]::new()
    $callback = [OxForms.W005VisibleInput.NativeMethods+EnumWindowsProc]{
        param([System.IntPtr]$Handle, [System.IntPtr]$Param)

        if (-not [OxForms.W005VisibleInput.NativeMethods]::IsWindowVisible($Handle)) {
            return $true
        }

        $text = Get-WindowTextValue -Handle $Handle
        if ([string]::IsNullOrWhiteSpace($text)) {
            return $true
        }

        $processId = [uint32]0
        [void][OxForms.W005VisibleInput.NativeMethods]::GetWindowThreadProcessId($Handle, [ref]$processId)
        $rect = New-Object OxForms.W005VisibleInput.NativeMethods+RECT
        [void][OxForms.W005VisibleInput.NativeMethods]::GetWindowRect($Handle, [ref]$rect)
        $process = $null
        try {
            $process = Get-Process -Id ([int]$processId) -ErrorAction Stop
        } catch {
            $process = $null
        }

        $windows.Add([ordered]@{
            handle = ('0x{0:X}' -f $Handle.ToInt64())
            title = $text
            class_name = Get-ClassNameValue -Handle $Handle
            process_id = [int]$processId
            process_name = if ($null -ne $process) { $process.ProcessName } else { $null }
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

    [void][OxForms.W005VisibleInput.NativeMethods]::EnumWindows($callback, [System.IntPtr]::Zero)
    return @($windows)
}

function Wait-ForSmokeWindow {
    param([int]$TimeoutSeconds = 20)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $matches = @(Get-TopLevelWindows | Where-Object {
            $_.title.IndexOf($title, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -and
            $_.process_name -eq $processName
        })
        if ($matches.Count -gt 0) {
            return $matches[0]
        }
        Start-Sleep -Milliseconds 100
    } while ((Get-Date) -lt $deadline)

    throw "Timed out waiting for visible smoke window '$title'."
}

function Get-ClientGeometry {
    param([object]$Window)

    $handle = [System.IntPtr]::new([Convert]::ToInt64($Window.handle.Substring(2), 16))
    $client = New-Object OxForms.W005VisibleInput.NativeMethods+RECT
    if (-not [OxForms.W005VisibleInput.NativeMethods]::GetClientRect($handle, [ref]$client)) {
        throw "GetClientRect failed for $($Window.handle)."
    }
    $origin = New-Object OxForms.W005VisibleInput.NativeMethods+POINT
    $origin.X = 0
    $origin.Y = 0
    if (-not [OxForms.W005VisibleInput.NativeMethods]::ClientToScreen($handle, [ref]$origin)) {
        throw "ClientToScreen failed for $($Window.handle)."
    }

    return [ordered]@{
        handle = $handle
        origin_screen_pixels = [ordered]@{ x = $origin.X; y = $origin.Y }
        client_size_pixels = [ordered]@{
            width = $client.Right - $client.Left
            height = $client.Bottom - $client.Top
        }
        scale = [ordered]@{
            x = [double]($client.Right - $client.Left) / 260.0
            y = [double]($client.Bottom - $client.Top) / 128.0
        }
    }
}

function Focus-SmokeWindow {
    param([System.IntPtr]$Handle)

    return Set-W005ForegroundWindow -Handle $Handle -DelayMilliseconds $ActionDelayMilliseconds
}

function Invoke-SmokeClick {
    param(
        [object]$ClientGeometry,
        [double]$FormX,
        [double]$FormY
    )

    $screenX = [int][Math]::Round([double]$ClientGeometry.origin_screen_pixels.x + ($FormX * [double]$ClientGeometry.scale.x))
    $screenY = [int][Math]::Round([double]$ClientGeometry.origin_screen_pixels.y + ($FormY * [double]$ClientGeometry.scale.y))
    $inputDiagnostics = Invoke-W005SendInputMouseClick -ScreenX $screenX -ScreenY $screenY -TargetHandle $ClientGeometry.handle -DownUpDelayMilliseconds 60 -AfterDelayMilliseconds $ActionDelayMilliseconds

    return [ordered]@{
        form_logical = [ordered]@{ x = $FormX; y = $FormY }
        client_pixels = [ordered]@{
            x = $FormX * [double]$ClientGeometry.scale.x
            y = $FormY * [double]$ClientGeometry.scale.y
        }
        screen_pixels = [ordered]@{ x = $screenX; y = $screenY }
        diagnostics = $inputDiagnostics
    }
}

function Invoke-SmokeKeys {
    param(
        [System.IntPtr]$Handle,
        [string]$Keys
    )

    Add-Type -AssemblyName System.Windows.Forms
    $focusDiagnostics = Focus-SmokeWindow -Handle $Handle
    [System.Windows.Forms.SendKeys]::SendWait($Keys)
    Start-Sleep -Milliseconds $ActionDelayMilliseconds
    return [ordered]@{
        schema = 'oxforms.w005.sendkeys_action.v1'
        input_driver = 'system_windows_forms_sendkeys'
        diagnostics = [ordered]@{
            foreground = $focusDiagnostics
            after = Get-W005InputDiagnosticsSnapshot -TargetHandle $Handle -Phase 'after_sendkeys'
        }
    }
}

function Invoke-SmokeCloseRequest {
    param([System.IntPtr]$Handle)

    [void][OxForms.W005VisibleInput.NativeMethods]::PostMessageW($Handle, 0x0010, [System.IntPtr]::Zero, [System.IntPtr]::Zero)
    Start-Sleep -Milliseconds $ActionDelayMilliseconds
}

function Add-Action {
    param(
        [System.Collections.Generic.List[object]]$Actions,
        [string]$TargetIntent,
        [string]$Action,
        [object]$Coordinates,
        [string]$Keys,
        [string]$Notes,
        [object]$Diagnostics = $null
    )

    $method = if ($Action -eq 'post_window_close') {
        'automated_user32_post_message'
    } elseif ([string]::IsNullOrEmpty($Keys)) {
        'automated_sendinput_mouse'
    } else {
        'automated_sendkeys'
    }

    $inputDriver = if ($method -eq 'automated_sendinput_mouse') {
        'public_user32_sendinput'
    } elseif ($method -eq 'automated_sendkeys') {
        'system_windows_forms_sendkeys'
    } elseif ($method -eq 'automated_user32_post_message') {
        'public_user32_postmessage'
    } else {
        $method
    }

    $coordinatePayload = if ($null -eq $Coordinates) {
        $null
    } else {
        [ordered]@{
            form_logical = $Coordinates.form_logical
            client_pixels = $Coordinates.client_pixels
            screen_pixels = $Coordinates.screen_pixels
        }
    }

    $Actions.Add([ordered]@{
        sequence = $Actions.Count + 1
        input_method = $method
        input_driver = $inputDriver
        manual = $false
        target_intent = $TargetIntent
        action = $Action
        coordinates = $coordinatePayload
        keys = $Keys
        diagnostics = if ($null -ne $Diagnostics) { $Diagnostics } elseif ($null -ne $Coordinates) { $Coordinates.diagnostics } else { $null }
        notes = $Notes
    }) | Out-Null
}

function Test-TraceEvidence {
    param([string]$TracePath)

    if (-not (Test-Path -LiteralPath $TracePath -PathType Leaf)) {
        throw "Trace evidence was not written: $TracePath"
    }

    $trace = Get-Content -Raw -LiteralPath $TracePath | ConvertFrom-Json
    if ($trace.schema -ne 'oxforms.w005.visible_input_smoke.v1') {
        throw "Unexpected trace schema: $($trace.schema)"
    }
    if ($trace.bead -ne 'oxforms-xvx.11') {
        throw "Unexpected bead in trace: $($trace.bead)"
    }
    if ($trace.status -ne 'closed_by_platform') {
        throw "Expected platform close status, got '$($trace.status)'."
    }
    if ([string]$trace.coverage.text_box_text -ne 'ab') {
        throw "Expected TextBox text 'ab', got '$($trace.coverage.text_box_text)'."
    }

    $rows = @($trace.rows)
    $json = $rows | ConvertTo-Json -Depth 30
    foreach ($needle in @('mouse_down', 'mouse_up', 'character_input', 'form_logical', 'client_pixels')) {
        if ($json -notmatch [regex]::Escape($needle)) {
            throw "Trace is missing expected evidence token: $needle"
        }
    }
    foreach ($eventName in @('Click', 'QueryClose')) {
        if ($json -notmatch ('"event_name"\s*:\s*"' + [regex]::Escape($eventName) + '"')) {
            throw "Trace is missing expected FireVbaEvent '$eventName'."
        }
    }

    return [ordered]@{
        row_count = $rows.Count
        ui_event_count = [int]$trace.coverage.ui_event_count
        effect_count = [int]$trace.coverage.effect_count
        text_box_text = [string]$trace.coverage.text_box_text
        final_lifecycle = [string]$trace.coverage.final_lifecycle
        framebuffer_hash = [string]$trace.coverage.framebuffer_hash
    }
}

function Write-Checksums {
    param([string]$Directory)

    $checksumPath = Join-Path $Directory 'checksums.sha256'
    $files = Get-ChildItem -LiteralPath $Directory -Recurse -File |
        Where-Object { $_.FullName -ne $checksumPath } |
        Sort-Object @{ Expression = { ConvertTo-DirectoryRelative -Directory $Directory -Path $_.FullName } }

    $lines = foreach ($file in $files) {
        "$(Get-Sha256Hex -Path $file.FullName)  $(ConvertTo-DirectoryRelative -Directory $Directory -Path $file.FullName)"
    }
    Set-Content -LiteralPath $checksumPath -Encoding ASCII -Value $lines
}

function Write-Readme {
    param(
        [string]$Directory,
        [object]$Manifest
    )

    $lines = @(
        '# W005 Visible Input Smoke Capture',
        '',
        "Capture id: $($Manifest.capture_id)",
        "Bead: $($Manifest.bead)",
        '',
        'This capture opens the OxForms W005 probe smoke window, drives public Windows input into it, and records the normalized `UiEvent` and reducer/effect evidence emitted by `crates/oxforms-core/examples/w005_visible_input_smoke.rs`.',
        '',
        '## Scope',
        '',
        '- Evidence/test infrastructure only; not a final host, runtime, or `UserForm.Show` parity claim.',
        '- The visible path supplements headless reducer tests and the deterministic trace/replay runner; it is not the only verification path.',
        '- Coordinates record both driver-side screen/client injection points and smoke-side normalized `client_pixels` / `form_logical` payloads.',
        '',
        '## Validation',
        '',
        'Run from the repository root:',
        '',
        '```powershell',
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\evidence\Test-ChecksumManifest.ps1 -Directory docs\evidence\W005_input_interaction_model_exploration\captures\$($Manifest.capture_id) -GitTrackedOnly",
        '```',
        '',
        'Checksum entries are relative to this capture directory and use forward slashes for nested paths, for example `window/window-capture.png`.'
    )
    Set-Content -LiteralPath (Join-Path $Directory 'README.md') -Encoding UTF8 -Value $lines
}

$resolvedOutDir = Resolve-CaptureDir -Directory $OutDir
Set-Location $repoRoot

$buildArgs = @('build', '-p', 'oxforms-core', '--example', 'w005_visible_input_smoke')
Invoke-LoggedProcess -FilePath 'cargo' -Arguments $buildArgs `
    -CommandPath (Join-Path $resolvedOutDir 'build-visible-smoke.command.txt') `
    -StdoutPath (Join-Path $resolvedOutDir 'build-visible-smoke.stdout.txt') `
    -StderrPath (Join-Path $resolvedOutDir 'build-visible-smoke.stderr.txt')

$exePath = Join-Path $repoRoot 'target\debug\examples\w005_visible_input_smoke.exe'
if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) {
    throw "Built smoke executable not found: $exePath"
}

$runArgs = @('--hold-ms', [string]$HoldMilliseconds, '--evidence-dir', $resolvedOutDir)
Set-Content -LiteralPath (Join-Path $resolvedOutDir 'run-visible-smoke.command.txt') -Encoding UTF8 -Value ($exePath + ' ' + (($runArgs | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }) -join ' '))
$process = Start-Process -FilePath $exePath -ArgumentList (($runArgs | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }) -join ' ') -PassThru -RedirectStandardOutput (Join-Path $resolvedOutDir 'run-visible-smoke.stdout.txt') -RedirectStandardError (Join-Path $resolvedOutDir 'run-visible-smoke.stderr.txt')

$actions = [System.Collections.Generic.List[object]]::new()
$window = $null
$clientGeometry = $null
$captureManifestPath = Join-Path $resolvedOutDir 'window\window-capture-manifest.json'

try {
    $window = Wait-ForSmokeWindow
    $clientGeometry = Get-ClientGeometry -Window $window
    $initialFocusDiagnostics = Focus-SmokeWindow -Handle $clientGeometry.handle

    $captureArgs = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', (Join-Path $repoRoot 'tools\office-oracle\Capture-Window.ps1'),
        '-OutDir', (Join-Path $resolvedOutDir 'window'),
        '-TitleContains', $title,
        '-ProcessName', $processName,
        '-CaptureScreenshot',
        '-AllowAmbiguous'
    )
    Invoke-LoggedProcess -FilePath 'powershell.exe' -Arguments $captureArgs `
        -CommandPath (Join-Path $resolvedOutDir 'capture-window.command.txt') `
        -StdoutPath (Join-Path $resolvedOutDir 'capture-window.stdout.txt') `
        -StderrPath (Join-Path $resolvedOutDir 'capture-window.stderr.txt')

    $coords = Invoke-SmokeClick -ClientGeometry $clientGeometry -FormX 54 -FormY 24
    Add-Action -Actions $actions -TargetIntent 'Label center mouse routing' -Action 'click' -Coordinates $coords -Keys '' -Notes 'Click probes non-focus mouse path.'

    $coords = Invoke-SmokeClick -ClientGeometry $clientGeometry -FormX 74 -FormY 66
    Add-Action -Actions $actions -TargetIntent 'TextBox center focus' -Action 'click' -Coordinates $coords -Keys '' -Notes 'Click transfers focus to the TextBox probe.'

    $keyDiagnostics = Invoke-SmokeKeys -Handle $clientGeometry.handle -Keys 'ab'
    Add-Action -Actions $actions -TargetIntent 'TextBox character input' -Action 'key_sequence' -Coordinates $null -Keys 'ab' -Diagnostics $keyDiagnostics -Notes 'SendKeys drives real platform character input through minifb callback.'

    $coords = Invoke-SmokeClick -ClientGeometry $clientGeometry -FormX 196 -FormY 66
    Add-Action -Actions $actions -TargetIntent 'CommandButton direct click' -Action 'click' -Coordinates $coords -Keys '' -Notes 'Click probes CommandButton pressed/click path.'

    $closeKeyDiagnostics = Invoke-SmokeKeys -Handle $clientGeometry.handle -Keys '%{F4}'
    Add-Action -Actions $actions -TargetIntent 'Platform close request attempt' -Action 'key_sequence' -Coordinates $null -Keys '%{F4}' -Diagnostics $closeKeyDiagnostics -Notes 'Alt+F4 is attempted first because it is a normal user close accelerator.'

    Invoke-SmokeCloseRequest -Handle $clientGeometry.handle
    Add-Action -Actions $actions -TargetIntent 'Platform close request' -Action 'post_window_close' -Coordinates $null -Keys '' -Diagnostics (Get-W005InputDiagnosticsSnapshot -TargetHandle $clientGeometry.handle -Phase 'after_post_window_close') -Notes 'Public user32 PostMessageW(WM_CLOSE) closes the smoke window when Alt+F4 is not sufficient under minifb.'

    if (-not $process.WaitForExit(10000)) {
        Stop-Process -Id $process.Id -ErrorAction SilentlyContinue
        throw "Visible smoke process did not exit after close input."
    }
    $process.Refresh()
    if ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) {
        throw "Visible smoke process exited with code $($process.ExitCode)."
    }
} catch {
    if ($null -ne $process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -ErrorAction SilentlyContinue
    }
    throw
}

$inputActionsPath = Join-Path $resolvedOutDir 'visible-input-actions.json'
Write-JsonFile -Value ([ordered]@{
    schema = 'oxforms.w005.visible_input_actions.v1'
    bead = 'oxforms-xvx.11'
    title = $title
    manual_inputs = @()
    automated_inputs = @($actions)
    focus_diagnostics = [ordered]@{
        initial_foreground = $initialFocusDiagnostics
        final = Get-W005InputDiagnosticsSnapshot -TargetHandle $clientGeometry.handle -Phase 'after_visible_smoke_drive'
    }
    client_geometry = [ordered]@{
        handle = $window.handle
        origin_screen_pixels = $clientGeometry.origin_screen_pixels
        client_size_pixels = $clientGeometry.client_size_pixels
        scale = $clientGeometry.scale
    }
    coordinate_vocabulary = @('screen_pixels', 'client_pixels', 'form_logical')
    assumptions = @(
        'The smoke window uses minifb Scale::X2; driver coordinates derive client pixels from the actual client rectangle and the 260x128 logical surface.',
        'The input driver is public Windows evidence infrastructure only and not runtime architecture.',
        'Mouse actions use public user32 SendInput after SetCursorPos; SendKeys remains only for text/accelerator input in this W005 smoke.'
    )
}) -Path $inputActionsPath

$tracePath = Join-Path $resolvedOutDir 'visible-input-trace.json'
$traceSummary = Test-TraceEvidence -TracePath $tracePath

$manifest = [ordered]@{
    schema = 'oxforms.w005.visible_input_smoke_capture.v1'
    bead = 'oxforms-xvx.11'
    capture_id = Split-Path -Leaf $resolvedOutDir
    captured_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    platform = [ordered]@{
        os = [System.Environment]::OSVersion.VersionString
        is_windows = $true
        powershell = $PSVersionTable.PSVersion.ToString()
    }
    commands = [ordered]@{
        build = ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'build-visible-smoke.command.txt')
        run = ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'run-visible-smoke.command.txt')
        capture_window = ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'capture-window.command.txt')
    }
    artifacts = [ordered]@{
        trace = ConvertTo-RepoRelative $tracePath
        input_actions = ConvertTo-RepoRelative $inputActionsPath
        window_capture_manifest = ConvertTo-RepoRelative $captureManifestPath
        screenshot = ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'window\window-capture.png')
        frame_ppm = ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'visible-input-frame.ppm')
        command_logs = @(
            (ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'build-visible-smoke.stdout.txt')),
            (ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'build-visible-smoke.stderr.txt')),
            (ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'run-visible-smoke.stdout.txt')),
            (ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'run-visible-smoke.stderr.txt')),
            (ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'capture-window.stdout.txt')),
            (ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'capture-window.stderr.txt'))
        )
    }
    observed_coverage = $traceSummary
    manual_inputs = @()
    automated_input_method = 'public user32 SetCursorPos/SendInput and System.Windows.Forms.SendKeys'
    non_claims = @(
        'This is W005 evidence/test infrastructure, not final host/runtime architecture.',
        'The visible smoke supplements headless reducer tests and future trace/replay; it is not the only verification path.',
        'The smoke does not claim full UserForm.Show or MSForms coordinate/lifecycle parity.'
    )
    clean_room = [ordered]@{
        source = 'Repo-owned Rust smoke, public Windows APIs, and committed OxForms reducer/PAL contracts.'
        prohibited = 'No Office internals, decompilation, disassembly, or non-public source were used.'
    }
}

Write-JsonFile -Value $manifest -Path (Join-Path $resolvedOutDir 'visible-input-smoke-manifest.json')
Write-Readme -Directory $resolvedOutDir -Manifest $manifest
Write-Checksums -Directory $resolvedOutDir

Write-Host "W005 visible input smoke capture complete: $resolvedOutDir"
Write-Host "Rows: $($traceSummary.row_count)"
Write-Host "TextBox text: $($traceSummary.text_box_text)"
