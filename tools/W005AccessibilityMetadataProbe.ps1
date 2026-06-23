param(
    [string]$WindowHandle,
    [string]$TitleContains,
    [string]$ProcessName,
    [int]$ChildrenDepth = 1,
    [string]$OutFile,
    [switch]$SelfCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ensure-W005AccessibilityProbeTypes {
    if (([System.Management.Automation.PSTypeName]'OxForms.W005AccessibilityProbe.NativeMethods').Type) {
        return
    }

    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes

    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace OxForms.W005AccessibilityProbe
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
        public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

        [DllImport("user32.dll")]
        public static extern bool IsWindowVisible(IntPtr hWnd);

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
    }
}
'@
}

function ConvertTo-W005ProbeHandleText {
    param([System.IntPtr]$Handle)

    if ($Handle -eq [System.IntPtr]::Zero) {
        return $null
    }

    return ('0x{0:X}' -f $Handle.ToInt64())
}

function ConvertFrom-W005ProbeHandleText {
    param([Parameter(Mandatory = $true)][string]$Handle)

    if ($Handle.StartsWith('0x', [System.StringComparison]::OrdinalIgnoreCase)) {
        return [System.IntPtr]::new([Convert]::ToInt64($Handle.Substring(2), 16))
    }

    return [System.IntPtr]::new([Convert]::ToInt64($Handle, 10))
}

function Get-W005ProbeWindowTitle {
    param([System.IntPtr]$Handle)

    $length = [OxForms.W005AccessibilityProbe.NativeMethods]::GetWindowTextLengthW($Handle)
    $builder = [System.Text.StringBuilder]::new([Math]::Max($length + 1, 256))
    [void][OxForms.W005AccessibilityProbe.NativeMethods]::GetWindowTextW($Handle, $builder, $builder.Capacity)
    return $builder.ToString()
}

function Get-W005ProbeWindowClassName {
    param([System.IntPtr]$Handle)

    $builder = [System.Text.StringBuilder]::new(256)
    [void][OxForms.W005AccessibilityProbe.NativeMethods]::GetClassNameW($Handle, $builder, $builder.Capacity)
    return $builder.ToString()
}

function Get-W005ProbeWindowSummary {
    param([System.IntPtr]$Handle)

    $processId = [uint32]0
    $threadId = [OxForms.W005AccessibilityProbe.NativeMethods]::GetWindowThreadProcessId($Handle, [ref]$processId)
    $rect = New-Object OxForms.W005AccessibilityProbe.NativeMethods+RECT
    $hasRect = [OxForms.W005AccessibilityProbe.NativeMethods]::GetWindowRect($Handle, [ref]$rect)
    $process = $null
    try {
        $process = Get-Process -Id ([int]$processId) -ErrorAction Stop
    } catch {
        $process = $null
    }

    return [ordered]@{
        handle = ConvertTo-W005ProbeHandleText -Handle $Handle
        title = Get-W005ProbeWindowTitle -Handle $Handle
        class_name = Get-W005ProbeWindowClassName -Handle $Handle
        process_id = [int]$processId
        process_name = if ($null -ne $process) { $process.ProcessName } else { $null }
        process_path = if ($null -ne $process) {
            try { $process.Path } catch { $null }
        } else {
            $null
        }
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

function Find-W005ProbeTopLevelWindows {
    param(
        [string]$TitleContains,
        [string]$ProcessName
    )

    $windows = [System.Collections.Generic.List[object]]::new()
    $callback = [OxForms.W005AccessibilityProbe.NativeMethods+EnumWindowsProc]{
        param([System.IntPtr]$Handle, [System.IntPtr]$Param)

        if (-not [OxForms.W005AccessibilityProbe.NativeMethods]::IsWindowVisible($Handle)) {
            return $true
        }

        $summary = Get-W005ProbeWindowSummary -Handle $Handle
        if ([string]::IsNullOrWhiteSpace($summary.title)) {
            return $true
        }

        if (-not [string]::IsNullOrWhiteSpace($TitleContains) -and
            $summary.title.IndexOf($TitleContains, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            return $true
        }

        if (-not [string]::IsNullOrWhiteSpace($ProcessName) -and
            -not [string]::Equals($summary.process_name, $ProcessName, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }

        $windows.Add($summary)
        return $true
    }

    [void][OxForms.W005AccessibilityProbe.NativeMethods]::EnumWindows($callback, [System.IntPtr]::Zero)
    return @($windows)
}

function Convert-W005UiaControlType {
    param($ControlType)

    if ($null -eq $ControlType) {
        return $null
    }

    return [ordered]@{
        id = $ControlType.Id
        programmatic_name = $ControlType.ProgrammaticName
    }
}

function Get-W005UiaPatternNames {
    param([System.Windows.Automation.AutomationElement]$Element)

    $patterns = @()
    foreach ($pattern in $Element.GetSupportedPatterns()) {
        $patterns += [ordered]@{
            id = $pattern.Id
            programmatic_name = $pattern.ProgrammaticName
        }
    }

    return @($patterns)
}

function Get-W005UiaElementMetadata {
    param(
        [System.Windows.Automation.AutomationElement]$Element,
        [int]$Depth,
        [int]$MaxDepth
    )

    if ($null -eq $Element) {
        return $null
    }

    $current = $Element.Current
    $children = @()
    if ($Depth -lt $MaxDepth) {
        $childElements = $Element.FindAll(
            [System.Windows.Automation.TreeScope]::Children,
            [System.Windows.Automation.Condition]::TrueCondition
        )
        foreach ($child in $childElements) {
            $children += Get-W005UiaElementMetadata -Element $child -Depth ($Depth + 1) -MaxDepth $MaxDepth
        }
    }

    return [ordered]@{
        name = $current.Name
        automation_id = $current.AutomationId
        class_name = $current.ClassName
        framework_id = $current.FrameworkId
        localized_control_type = $current.LocalizedControlType
        control_type = Convert-W005UiaControlType -ControlType $current.ControlType
        process_id = $current.ProcessId
        native_window_handle = if ($current.NativeWindowHandle -ne 0) { ('0x{0:X}' -f $current.NativeWindowHandle) } else { $null }
        bounding_rectangle = [ordered]@{
            left = $current.BoundingRectangle.Left
            top = $current.BoundingRectangle.Top
            width = $current.BoundingRectangle.Width
            height = $current.BoundingRectangle.Height
        }
        is_enabled = $current.IsEnabled
        is_keyboard_focusable = $current.IsKeyboardFocusable
        has_keyboard_focus = $current.HasKeyboardFocus
        supported_patterns = Get-W005UiaPatternNames -Element $Element
        children = $children
    }
}

Ensure-W005AccessibilityProbeTypes

if ($SelfCheck) {
    $result = [ordered]@{
        schema = 'oxforms.w005.accessibility_metadata_probe.self_check.v1'
        status = 'ok'
        captured_at_utc = (Get-Date).ToUniversalTime().ToString('o')
        tool = 'tools/W005AccessibilityMetadataProbe.ps1'
        checks = @(
            'PowerShell parsed the script.',
            'UIAutomationClient and UIAutomationTypes assemblies loaded.',
            'Public user32 metadata interop type compiled.'
        )
        non_claims = @(
            'Self-check does not enumerate, inspect, or automate any live window.',
            'Self-check does not validate MSForms or OxForms behavior.'
        )
    }

    $json = $result | ConvertTo-Json -Depth 8
    if (-not [string]::IsNullOrWhiteSpace($OutFile)) {
        $json | Set-Content -Encoding UTF8 -Path $OutFile
    } else {
        $json
    }
    exit 0
}

if (-not [string]::IsNullOrWhiteSpace($WindowHandle)) {
    $selectedHandle = ConvertFrom-W005ProbeHandleText -Handle $WindowHandle
    $candidates = @(Get-W005ProbeWindowSummary -Handle $selectedHandle)
} else {
    $candidates = @(Find-W005ProbeTopLevelWindows -TitleContains $TitleContains -ProcessName $ProcessName)
    if ($candidates.Count -ne 1) {
        $result = [ordered]@{
            schema = 'oxforms.w005.accessibility_metadata_probe.v1'
            status = if ($candidates.Count -eq 0) { 'no_match' } else { 'ambiguous' }
            captured_at_utc = (Get-Date).ToUniversalTime().ToString('o')
            query = [ordered]@{
                window_handle = $WindowHandle
                title_contains = $TitleContains
                process_name = $ProcessName
            }
            candidates = $candidates
            notes = @(
                'This W005 probe records public top-level UI Automation discoverability metadata only.',
                'It is not an OxForms runtime accessibility provider and is not behavioral truth for MSForms or OxForms controls.'
            )
        }
        $json = $result | ConvertTo-Json -Depth 32
        if (-not [string]::IsNullOrWhiteSpace($OutFile)) {
            $json | Set-Content -Encoding UTF8 -Path $OutFile
        } else {
            $json
        }
        exit 2
    }
    $selectedHandle = ConvertFrom-W005ProbeHandleText -Handle $candidates[0].handle
}

$windowSummary = Get-W005ProbeWindowSummary -Handle $selectedHandle
$uiaStatus = 'ok'
$uiaError = $null
$uiaRoot = $null
try {
    $element = [System.Windows.Automation.AutomationElement]::FromHandle($selectedHandle)
    $uiaRoot = Get-W005UiaElementMetadata -Element $element -Depth 0 -MaxDepth ([Math]::Max(0, $ChildrenDepth))
} catch {
    $uiaStatus = 'error'
    $uiaError = $_.Exception.Message
}

$result = [ordered]@{
    schema = 'oxforms.w005.accessibility_metadata_probe.v1'
    status = 'ok'
    captured_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    tool = 'tools/W005AccessibilityMetadataProbe.ps1'
    query = [ordered]@{
        window_handle = $WindowHandle
        title_contains = $TitleContains
        process_name = $ProcessName
        children_depth = $ChildrenDepth
    }
    public_windows_metadata = $windowSummary
    uia = [ordered]@{
        status = $uiaStatus
        error = $uiaError
        root = $uiaRoot
    }
    msaa = [ordered]@{
        status = 'deferred'
        reason = 'MSAA probing is intentionally not implemented in W005 because UIA top-level metadata is enough to record discoverability, and adding IAccessible traversal would not improve W005 input behavior evidence.'
    }
    non_claims = @(
        'Diagnostics-only public UI Automation metadata; not an OxForms runtime accessibility implementation.',
        'No OxForms control semantics are inferred from UIA properties or supported patterns.',
        'MSForms event behavior remains grounded in the fixture event logs, not UIA discoverability.',
        'OxForms visible-smoke behavior remains grounded in repo-owned traces and screenshots, not UIA discoverability.'
    )
    clean_room = [ordered]@{
        source = 'Public user32 top-level window metadata and public .NET UIAutomationClient APIs.'
        prohibited = 'No private Windows or Office internals, decompilation, disassembly, or non-public source.'
    }
}

$json = $result | ConvertTo-Json -Depth 64
if (-not [string]::IsNullOrWhiteSpace($OutFile)) {
    $json | Set-Content -Encoding UTF8 -Path $OutFile
} else {
    $json
}
