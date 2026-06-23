Set-StrictMode -Version Latest

function Ensure-W005InputDiagnosticsNativeTypes {
    if (([System.Management.Automation.PSTypeName]'OxForms.W005InputDiagnostics.NativeMethods').Type) {
        return
    }

    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace OxForms.W005InputDiagnostics
{
    public static class NativeMethods
    {
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

        [StructLayout(LayoutKind.Sequential)]
        public struct GUITHREADINFO
        {
            public int cbSize;
            public int flags;
            public IntPtr hwndActive;
            public IntPtr hwndFocus;
            public IntPtr hwndCapture;
            public IntPtr hwndMenuOwner;
            public IntPtr hwndMoveSize;
            public IntPtr hwndCaret;
            public RECT rcCaret;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct INPUT
        {
            public uint type;
            public MOUSEINPUT mi;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct MOUSEINPUT
        {
            public int dx;
            public int dy;
            public uint mouseData;
            public uint dwFlags;
            public uint time;
            public UIntPtr dwExtraInfo;
        }

        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        public static extern IntPtr GetFocus();

        [DllImport("user32.dll")]
        public static extern bool GetCursorPos(out POINT point);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern int GetWindowTextLengthW(IntPtr hWnd);

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern int GetWindowTextW(IntPtr hWnd, StringBuilder text, int maxCount);

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern int GetClassNameW(IntPtr hWnd, StringBuilder className, int maxCount);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool GetGUIThreadInfo(uint idThread, ref GUITHREADINFO info);

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetCursorPos(int X, int Y);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
    }
}
'@
}

function ConvertTo-W005HandleText {
    param([System.IntPtr]$Handle)

    if ($Handle -eq [System.IntPtr]::Zero) {
        return $null
    }

    return ('0x{0:X}' -f $Handle.ToInt64())
}

function ConvertFrom-W005HandleText {
    param([Parameter(Mandatory = $true)][string]$Handle)

    Ensure-W005InputDiagnosticsNativeTypes
    if ($Handle.StartsWith('0x', [System.StringComparison]::OrdinalIgnoreCase)) {
        return [System.IntPtr]::new([Convert]::ToInt64($Handle.Substring(2), 16))
    }

    return [System.IntPtr]::new([Convert]::ToInt64($Handle, 10))
}

function Get-W005WindowTitle {
    param([System.IntPtr]$Handle)

    Ensure-W005InputDiagnosticsNativeTypes
    if ($Handle -eq [System.IntPtr]::Zero) {
        return $null
    }

    $length = [OxForms.W005InputDiagnostics.NativeMethods]::GetWindowTextLengthW($Handle)
    $builder = [System.Text.StringBuilder]::new([Math]::Max($length + 1, 256))
    [void][OxForms.W005InputDiagnostics.NativeMethods]::GetWindowTextW($Handle, $builder, $builder.Capacity)
    return $builder.ToString()
}

function Get-W005WindowClassName {
    param([System.IntPtr]$Handle)

    Ensure-W005InputDiagnosticsNativeTypes
    if ($Handle -eq [System.IntPtr]::Zero) {
        return $null
    }

    $builder = [System.Text.StringBuilder]::new(256)
    [void][OxForms.W005InputDiagnostics.NativeMethods]::GetClassNameW($Handle, $builder, $builder.Capacity)
    return $builder.ToString()
}

function Get-W005WindowSummary {
    param([System.IntPtr]$Handle)

    Ensure-W005InputDiagnosticsNativeTypes
    if ($Handle -eq [System.IntPtr]::Zero) {
        return $null
    }

    $processId = [uint32]0
    $threadId = [OxForms.W005InputDiagnostics.NativeMethods]::GetWindowThreadProcessId($Handle, [ref]$processId)
    $rect = New-Object OxForms.W005InputDiagnostics.NativeMethods+RECT
    $hasRect = [OxForms.W005InputDiagnostics.NativeMethods]::GetWindowRect($Handle, [ref]$rect)
    $processName = $null
    try {
        $processName = (Get-Process -Id ([int]$processId) -ErrorAction Stop).ProcessName
    } catch {
        $processName = $null
    }

    return [ordered]@{
        handle = ConvertTo-W005HandleText -Handle $Handle
        title = Get-W005WindowTitle -Handle $Handle
        class_name = Get-W005WindowClassName -Handle $Handle
        process_id = [int]$processId
        process_name = $processName
        thread_id = [int]$threadId
        bounds = if ($hasRect) {
            [ordered]@{
                left = $rect.Left
                top = $rect.Top
                right = $rect.Right
                bottom = $rect.Bottom
                width = [Math]::Max(0, $rect.Right - $rect.Left)
                height = [Math]::Max(0, $rect.Bottom - $rect.Top)
            }
        } else {
            $null
        }
    }
}

function Get-W005InputDiagnosticsSnapshot {
    param(
        [System.IntPtr]$TargetHandle = [System.IntPtr]::Zero,
        [string]$Phase = ''
    )

    Ensure-W005InputDiagnosticsNativeTypes
    $foreground = [OxForms.W005InputDiagnostics.NativeMethods]::GetForegroundWindow()
    $focus = [OxForms.W005InputDiagnostics.NativeMethods]::GetFocus()
    $cursor = New-Object OxForms.W005InputDiagnostics.NativeMethods+POINT
    $hasCursor = [OxForms.W005InputDiagnostics.NativeMethods]::GetCursorPos([ref]$cursor)

    $targetThreadId = 0
    if ($TargetHandle -ne [System.IntPtr]::Zero) {
        $pid = [uint32]0
        $targetThreadId = [OxForms.W005InputDiagnostics.NativeMethods]::GetWindowThreadProcessId($TargetHandle, [ref]$pid)
    }

    $guiInfo = $null
    if ($targetThreadId -ne 0) {
        $info = New-Object OxForms.W005InputDiagnostics.NativeMethods+GUITHREADINFO
        $info.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf([type][OxForms.W005InputDiagnostics.NativeMethods+GUITHREADINFO])
        if ([OxForms.W005InputDiagnostics.NativeMethods]::GetGUIThreadInfo([uint32]$targetThreadId, [ref]$info)) {
            $guiInfo = [ordered]@{
                thread_id = [int]$targetThreadId
                active_window = Get-W005WindowSummary -Handle $info.hwndActive
                focus_window = Get-W005WindowSummary -Handle $info.hwndFocus
                capture_window = Get-W005WindowSummary -Handle $info.hwndCapture
                caret_window = Get-W005WindowSummary -Handle $info.hwndCaret
            }
        }
    }

    return [ordered]@{
        schema = 'oxforms.w005.windows_input_diagnostics.v1'
        phase = $Phase
        captured_at_utc = (Get-Date).ToUniversalTime().ToString('o')
        foreground_window = Get-W005WindowSummary -Handle $foreground
        process_thread_focus_window = Get-W005WindowSummary -Handle $focus
        target_window = Get-W005WindowSummary -Handle $TargetHandle
        target_thread_gui = $guiInfo
        cursor_screen_pixels = if ($hasCursor) { [ordered]@{ x = $cursor.X; y = $cursor.Y } } else { $null }
        notes = @(
            'Foreground/focus metadata is public Windows harness diagnostics only.',
            'GetGUIThreadInfo reports the target window thread GUI state; it explains input delivery risk but is not an OxForms runtime contract.'
        )
    }
}

function Set-W005ForegroundWindow {
    param(
        [Parameter(Mandatory = $true)][System.IntPtr]$Handle,
        [int]$DelayMilliseconds = 180
    )

    Ensure-W005InputDiagnosticsNativeTypes
    $before = Get-W005InputDiagnosticsSnapshot -TargetHandle $Handle -Phase 'before_set_foreground'
    [void][OxForms.W005InputDiagnostics.NativeMethods]::ShowWindow($Handle, 5)
    $setForegroundResult = [OxForms.W005InputDiagnostics.NativeMethods]::SetForegroundWindow($Handle)
    if ($DelayMilliseconds -gt 0) {
        Start-Sleep -Milliseconds $DelayMilliseconds
    }
    $after = Get-W005InputDiagnosticsSnapshot -TargetHandle $Handle -Phase 'after_set_foreground'

    return [ordered]@{
        schema = 'oxforms.w005.foreground_transition.v1'
        api = 'public_user32_ShowWindow_SetForegroundWindow'
        set_foreground_result = [bool]$setForegroundResult
        before = $before
        after = $after
    }
}

function Assert-W005SetCursorPosSucceeded {
    param(
        [Parameter(Mandatory = $true)][bool]$Result,
        [Parameter(Mandatory = $true)][string]$Action,
        [Parameter(Mandatory = $true)][string]$PointName,
        [Parameter(Mandatory = $true)][int]$ScreenX,
        [Parameter(Mandatory = $true)][int]$ScreenY,
        [System.IntPtr]$TargetHandle = [System.IntPtr]::Zero
    )

    if ($Result) {
        return
    }

    $lastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    $targetText = ConvertTo-W005HandleText -Handle $TargetHandle
    throw "SetCursorPos failed while preparing W005 $Action input at $PointName screen pixels ($ScreenX,$ScreenY); target_handle=$targetText; last_win32_error=$lastError."
}

function Assert-W005SendInputCount {
    param(
        [Parameter(Mandatory = $true)][uint32]$Sent,
        [Parameter(Mandatory = $true)][uint32]$Requested,
        [Parameter(Mandatory = $true)][string]$Action,
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][int]$ScreenX,
        [Parameter(Mandatory = $true)][int]$ScreenY,
        [System.IntPtr]$TargetHandle = [System.IntPtr]::Zero
    )

    if ($Sent -eq $Requested) {
        return
    }

    $lastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    $targetText = ConvertTo-W005HandleText -Handle $TargetHandle
    throw "SendInput injected fewer W005 $Action $Phase events than requested at screen pixels ($ScreenX,$ScreenY); requested=$Requested; sent=$Sent; target_handle=$targetText; last_win32_error=$lastError."
}

function Invoke-W005BestEffortMouseUpRelease {
    $upMouse = New-Object OxForms.W005InputDiagnostics.NativeMethods+MOUSEINPUT
    $upMouse.dwFlags = 0x0004
    $up = New-Object OxForms.W005InputDiagnostics.NativeMethods+INPUT
    $up.type = 0
    $up.mi = $upMouse

    $sentUp = [OxForms.W005InputDiagnostics.NativeMethods]::SendInput(1, @($up), [System.Runtime.InteropServices.Marshal]::SizeOf([type][OxForms.W005InputDiagnostics.NativeMethods+INPUT]))
    $lastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    return [ordered]@{
        requested_up = 1
        sent_up = [int]$sentUp
        last_win32_error = [int]$lastError
    }
}

function Invoke-W005SendInputMouseClick {
    param(
        [Parameter(Mandatory = $true)][int]$ScreenX,
        [Parameter(Mandatory = $true)][int]$ScreenY,
        [System.IntPtr]$TargetHandle = [System.IntPtr]::Zero,
        [int]$DownUpDelayMilliseconds = 60,
        [int]$AfterDelayMilliseconds = 180
    )

    Ensure-W005InputDiagnosticsNativeTypes
    $before = Get-W005InputDiagnosticsSnapshot -TargetHandle $TargetHandle -Phase 'before_sendinput_mouse_click'
    $setCursorResult = [OxForms.W005InputDiagnostics.NativeMethods]::SetCursorPos($ScreenX, $ScreenY)
    Assert-W005SetCursorPosSucceeded -Result $setCursorResult -Action 'mouse_click' -PointName 'target' -ScreenX $ScreenX -ScreenY $ScreenY -TargetHandle $TargetHandle
    if ($AfterDelayMilliseconds -gt 0) {
        Start-Sleep -Milliseconds $AfterDelayMilliseconds
    }

    $downMouse = New-Object OxForms.W005InputDiagnostics.NativeMethods+MOUSEINPUT
    $downMouse.dwFlags = 0x0002
    $down = New-Object OxForms.W005InputDiagnostics.NativeMethods+INPUT
    $down.type = 0
    $down.mi = $downMouse

    $upMouse = New-Object OxForms.W005InputDiagnostics.NativeMethods+MOUSEINPUT
    $upMouse.dwFlags = 0x0004
    $up = New-Object OxForms.W005InputDiagnostics.NativeMethods+INPUT
    $up.type = 0
    $up.mi = $upMouse

    $sentDown = [OxForms.W005InputDiagnostics.NativeMethods]::SendInput(1, @($down), [System.Runtime.InteropServices.Marshal]::SizeOf([type][OxForms.W005InputDiagnostics.NativeMethods+INPUT]))
    Assert-W005SendInputCount -Sent $sentDown -Requested 1 -Action 'mouse_click' -Phase 'down' -ScreenX $ScreenX -ScreenY $ScreenY -TargetHandle $TargetHandle
    if ($DownUpDelayMilliseconds -gt 0) {
        Start-Sleep -Milliseconds $DownUpDelayMilliseconds
    }
    $sentUp = [OxForms.W005InputDiagnostics.NativeMethods]::SendInput(1, @($up), [System.Runtime.InteropServices.Marshal]::SizeOf([type][OxForms.W005InputDiagnostics.NativeMethods+INPUT]))
    Assert-W005SendInputCount -Sent $sentUp -Requested 1 -Action 'mouse_click' -Phase 'up' -ScreenX $ScreenX -ScreenY $ScreenY -TargetHandle $TargetHandle
    if ($AfterDelayMilliseconds -gt 0) {
        Start-Sleep -Milliseconds $AfterDelayMilliseconds
    }
    $after = Get-W005InputDiagnosticsSnapshot -TargetHandle $TargetHandle -Phase 'after_sendinput_mouse_click'

    return [ordered]@{
        schema = 'oxforms.w005.sendinput_mouse_action.v1'
        input_driver = 'public_user32_sendinput'
        action = 'mouse_click'
        target_screen_pixels = [ordered]@{ x = $ScreenX; y = $ScreenY }
        set_cursor_result = [bool]$setCursorResult
        send_input = [ordered]@{
            requested_down = 1
            sent_down = [int]$sentDown
            requested_up = 1
            sent_up = [int]$sentUp
        }
        diagnostics = [ordered]@{
            before = $before
            after = $after
        }
    }
}

function Invoke-W005SendInputMouseDrag {
    param(
        [Parameter(Mandatory = $true)][int]$StartScreenX,
        [Parameter(Mandatory = $true)][int]$StartScreenY,
        [Parameter(Mandatory = $true)][int]$EndScreenX,
        [Parameter(Mandatory = $true)][int]$EndScreenY,
        [System.IntPtr]$TargetHandle = [System.IntPtr]::Zero,
        [int]$StepDelayMilliseconds = 180,
        [int]$AfterDelayMilliseconds = 180
    )

    Ensure-W005InputDiagnosticsNativeTypes
    $before = Get-W005InputDiagnosticsSnapshot -TargetHandle $TargetHandle -Phase 'before_sendinput_mouse_drag'
    $setStartResult = [OxForms.W005InputDiagnostics.NativeMethods]::SetCursorPos($StartScreenX, $StartScreenY)
    Assert-W005SetCursorPosSucceeded -Result $setStartResult -Action 'mouse_drag' -PointName 'start' -ScreenX $StartScreenX -ScreenY $StartScreenY -TargetHandle $TargetHandle
    if ($StepDelayMilliseconds -gt 0) {
        Start-Sleep -Milliseconds $StepDelayMilliseconds
    }

    $downMouse = New-Object OxForms.W005InputDiagnostics.NativeMethods+MOUSEINPUT
    $downMouse.dwFlags = 0x0002
    $down = New-Object OxForms.W005InputDiagnostics.NativeMethods+INPUT
    $down.type = 0
    $down.mi = $downMouse

    $upMouse = New-Object OxForms.W005InputDiagnostics.NativeMethods+MOUSEINPUT
    $upMouse.dwFlags = 0x0004
    $up = New-Object OxForms.W005InputDiagnostics.NativeMethods+INPUT
    $up.type = 0
    $up.mi = $upMouse

    $sentDown = [OxForms.W005InputDiagnostics.NativeMethods]::SendInput(1, @($down), [System.Runtime.InteropServices.Marshal]::SizeOf([type][OxForms.W005InputDiagnostics.NativeMethods+INPUT]))
    Assert-W005SendInputCount -Sent $sentDown -Requested 1 -Action 'mouse_drag' -Phase 'down' -ScreenX $StartScreenX -ScreenY $StartScreenY -TargetHandle $TargetHandle
    if ($StepDelayMilliseconds -gt 0) {
        Start-Sleep -Milliseconds $StepDelayMilliseconds
    }
    $setEndResult = [OxForms.W005InputDiagnostics.NativeMethods]::SetCursorPos($EndScreenX, $EndScreenY)
    if (-not $setEndResult) {
        $setEndLastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        $release = Invoke-W005BestEffortMouseUpRelease
        $targetText = ConvertTo-W005HandleText -Handle $TargetHandle
        throw "SetCursorPos failed while preparing W005 mouse_drag input at end screen pixels ($EndScreenX,$EndScreenY); target_handle=$targetText; last_win32_error=$setEndLastError; best_effort_release_requested_up=$($release.requested_up); best_effort_release_sent_up=$($release.sent_up); best_effort_release_last_win32_error=$($release.last_win32_error)."
    }
    if ($StepDelayMilliseconds -gt 0) {
        Start-Sleep -Milliseconds ($StepDelayMilliseconds * 2)
    }
    $sentUp = [OxForms.W005InputDiagnostics.NativeMethods]::SendInput(1, @($up), [System.Runtime.InteropServices.Marshal]::SizeOf([type][OxForms.W005InputDiagnostics.NativeMethods+INPUT]))
    Assert-W005SendInputCount -Sent $sentUp -Requested 1 -Action 'mouse_drag' -Phase 'up' -ScreenX $EndScreenX -ScreenY $EndScreenY -TargetHandle $TargetHandle
    if ($AfterDelayMilliseconds -gt 0) {
        Start-Sleep -Milliseconds $AfterDelayMilliseconds
    }
    $after = Get-W005InputDiagnosticsSnapshot -TargetHandle $TargetHandle -Phase 'after_sendinput_mouse_drag'

    return [ordered]@{
        schema = 'oxforms.w005.sendinput_mouse_action.v1'
        input_driver = 'public_user32_sendinput'
        action = 'mouse_drag'
        start_screen_pixels = [ordered]@{ x = $StartScreenX; y = $StartScreenY }
        end_screen_pixels = [ordered]@{ x = $EndScreenX; y = $EndScreenY }
        set_cursor_result = [ordered]@{
            start = [bool]$setStartResult
            end = [bool]$setEndResult
        }
        send_input = [ordered]@{
            requested_down = 1
            sent_down = [int]$sentDown
            requested_up = 1
            sent_up = [int]$sentUp
        }
        diagnostics = [ordered]@{
            before = $before
            after = $after
        }
    }
}

Export-ModuleMember -Function @(
    'ConvertFrom-W005HandleText',
    'ConvertTo-W005HandleText',
    'Get-W005InputDiagnosticsSnapshot',
    'Get-W005WindowSummary',
    'Invoke-W005SendInputMouseClick',
    'Invoke-W005SendInputMouseDrag',
    'Set-W005ForegroundWindow'
)
