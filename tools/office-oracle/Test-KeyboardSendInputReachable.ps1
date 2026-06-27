[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$GenerateOnly,
    [int]$ActionDelayMilliseconds = 220
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Fast pre-flight probe for the office-oracle keyboard path.
#
# Builds a tiny one-TextBox UserForm workbook in the session scratchpad (never
# under docs/evidence), opens it, Shows it modeless, focuses the TextBox by
# clicking it, then SendInputs a single known character ('A') and asserts BOTH:
#   (a) SendInput sent == requested (the OS accepted every injected event), AND
#   (b) at least one row appeared in the ProbeLog worksheet (MSForms actually
#       dispatched a KeyPress/Change to the focused control).
#
# Either failure means the interactive desktop is locked / input-incapable, so
# the keyboard-dependent captures would silently produce "no rows". This probe
# exits non-zero in that case with a clear remediation message, so the batch
# runner can abort honestly rather than letting a dead keyboard masquerade as a
# negative MSForms fact.
#
# Clean-room: public Excel/VBIDE automation + public user32 input only. No
# Office internals, decompilation, disassembly, non-public source, or OxForms
# output comparison.
# ---------------------------------------------------------------------------

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Import-Module (Join-Path $repoRoot 'tools\W005WindowsInputDiagnostics.psm1') -Force

$scratchRoot = $env:TEMP
if ([string]::IsNullOrWhiteSpace($scratchRoot)) { $scratchRoot = [System.IO.Path]::GetTempPath() }
$probeDir = Join-Path $scratchRoot ('oxforms-keyboard-probe-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))

$formName = 'OxFormsKeyboardProbe'
$formCaption = 'OxForms Keyboard Probe'
$textBoxName = 'ProbeBox'
$logSheetName = 'ProbeLog'
$standardModuleName = 'OxFormsKeyboardProbeModule'
$workbookFileName = 'oxforms-keyboard-probe.xlsm'

function Release-ComObjectIfPresent {
    param($Object)
    if ($null -ne $Object -and [System.Runtime.InteropServices.Marshal]::IsComObject($Object)) {
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($Object)
    }
}

function Set-ComponentPropertyValue {
    param(
        [Parameter(Mandatory = $true)]$Component,
        [Parameter(Mandatory = $true)][string]$PropertyName,
        [Parameter(Mandatory = $true)]$Value
    )
    $property = $Component.Properties.Item($PropertyName)
    $property.GetType().InvokeMember('Value', [System.Reflection.BindingFlags]::SetProperty, $null, $property, @($Value), [System.Globalization.CultureInfo]::InvariantCulture)
}

# Repo-owned probe VBA. The form logs KeyPress and Change rows; the standard
# module owns the ProbeLog sheet and the Show/Clear macros. Design-time control
# fonts are intentionally never set (VBIDE font setter hangs the SaveAs dialog).
$formCodeBehind = @"
Option Explicit

Private Sub UserForm_Initialize()
    ProbeLog Me.Name, "$textBoxName", "Initialize", CStr($textBoxName.Value)
End Sub

Private Sub ${textBoxName}_KeyPress(ByVal KeyAscii As MSForms.ReturnInteger)
    ProbeLog Me.Name, "$textBoxName", "KeyPress", CStr(KeyAscii)
End Sub

Private Sub ${textBoxName}_Change()
    ProbeLog Me.Name, "$textBoxName", "Change", CStr($textBoxName.Value)
End Sub
"@

$standardModuleCode = @"
Option Explicit

' Worksheet logger + show/clear macros for the keyboard reachability probe.

Private gProbeSeq As Long

Public Sub ProbeLog( _
        ByVal formName As String, _
        ByVal controlName As String, _
        ByVal eventName As String, _
        ByVal valueText As String)
    Dim ws As Worksheet
    Set ws = ProbeSheet()
    gProbeSeq = gProbeSeq + 1
    Dim r As Long
    r = gProbeSeq + 1
    ws.Cells(r, 1).Value = gProbeSeq
    ws.Cells(r, 2).Value = formName
    ws.Cells(r, 3).Value = controlName
    ws.Cells(r, 4).Value = eventName
    ws.Cells(r, 5).Value = valueText
End Sub

Private Function ProbeSheet() As Worksheet
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("$logSheetName")
    On Error GoTo 0
    If ws Is Nothing Then
        Set ws = ThisWorkbook.Worksheets.Add
        ws.Name = "$logSheetName"
    End If
    If Len(CStr(ws.Cells(1, 1).Value)) = 0 Then
        ws.Cells(1, 1).Value = "sequence"
        ws.Cells(1, 2).Value = "form_name"
        ws.Cells(1, 3).Value = "control_name"
        ws.Cells(1, 4).Value = "event_name"
        ws.Cells(1, 5).Value = "value"
    End If
    Set ProbeSheet = ws
End Function

Public Sub ClearProbeLog()
    gProbeSeq = 0
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("$logSheetName")
    On Error GoTo 0
    If Not ws Is Nothing Then
        ws.Cells.Clear
    End If
End Sub

Public Sub ShowProbeModeless()
    $formName.Show vbModeless
End Sub
"@

function New-ProbeWorkbook {
    param([Parameter(Mandatory = $true)][string]$WorkbookPath)

    $excel = $null; $workbook = $null; $vbProject = $null; $component = $null; $standardModule = $null
    try {
        try { $excel = New-Object -ComObject Excel.Application } catch { throw "Microsoft Excel COM automation is unavailable: $($_.Exception.Message)" }
        $excel.Visible = $false; $excel.DisplayAlerts = $false
        $workbook = $excel.Workbooks.Add()
        try { $vbProject = $workbook.VBProject } catch { throw "Excel blocked access to the VBA project object model. Enable 'Trust access to the VBA project object model'." }

        $component = $vbProject.VBComponents.Add(3)   # 3 = vbext_ct_MSForm
        $component.Name = $formName
        $designer = $component.Designer
        Set-ComponentPropertyValue $component 'Caption' $formCaption
        Set-ComponentPropertyValue $component 'Width' ([single]200)
        Set-ComponentPropertyValue $component 'Height' ([single]120)
        Set-ComponentPropertyValue $component 'StartUpPosition' ([single]2)

        # One TextBox filling the client area so a single window-centre click focuses it.
        $created = $designer.Controls.Add('Forms.TextBox.1', $textBoxName, $true)
        $created.Left = [single]8
        $created.Top = [single]8
        $created.Width = [single]184
        $created.Height = [single]104

        $component.CodeModule.AddFromString($formCodeBehind)

        $standardModule = $vbProject.VBComponents.Add(1)   # 1 = vbext_ct_StdModule
        $standardModule.Name = $standardModuleName
        $standardModule.CodeModule.AddFromString($standardModuleCode)

        $workbook.SaveAs($WorkbookPath, 52)   # 52 = xlOpenXMLWorkbookMacroEnabled (.xlsm)
    } finally {
        if ($null -ne $workbook) { try { $workbook.Close($true) } catch { Write-Warning "Failed to close generated probe workbook: $($_.Exception.Message)" } }
        if ($null -ne $excel) { try { $excel.Quit() } catch { Write-Warning "Failed to quit Excel after probe generation: $($_.Exception.Message)" } }
        Release-ComObjectIfPresent $standardModule
        Release-ComObjectIfPresent $component
        Release-ComObjectIfPresent $vbProject
        Release-ComObjectIfPresent $workbook
        Release-ComObjectIfPresent $excel
    }
}

function Ensure-ProbeWindowTypes {
    if (([System.Management.Automation.PSTypeName]'OxForms.KeyboardProbe.NativeMethods').Type) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
namespace OxForms.KeyboardProbe
{
    public static class NativeMethods
    {
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
        [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
        [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
        [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr hWnd, StringBuilder text, int maxCount);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassNameW(IntPtr hWnd, StringBuilder className, int maxCount);
        [DllImport("user32.dll", SetLastError = true)] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
        [DllImport("user32.dll", SetLastError = true)] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

        [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public INPUTUNION u; }
        [StructLayout(LayoutKind.Explicit)] public struct INPUTUNION { [FieldOffset(0)] public KEYBDINPUT ki; }
        [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public UIntPtr dwExtraInfo; }
        [DllImport("user32.dll", SetLastError = true)] public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
    }
}
'@
}

function Get-OracleWindow {
    param([Parameter(Mandatory = $true)][string]$Title)
    Ensure-ProbeWindowTypes
    # Reset at script scope each call (StrictMode: reading an unset $script:found
    # after a poll that matched no window would throw instead of returning null).
    $script:found = $null
    $excelIds = @(Get-Process EXCEL -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    $callback = [OxForms.KeyboardProbe.NativeMethods+EnumWindowsProc]{
        param([System.IntPtr]$Handle, [System.IntPtr]$Param)
        if (-not [OxForms.KeyboardProbe.NativeMethods]::IsWindowVisible($Handle)) { return $true }
        $sbT = [System.Text.StringBuilder]::new(512); [void][OxForms.KeyboardProbe.NativeMethods]::GetWindowTextW($Handle, $sbT, 512); $title = $sbT.ToString()
        if ($title.IndexOf($Title, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { return $true }
        $sbC = [System.Text.StringBuilder]::new(128); [void][OxForms.KeyboardProbe.NativeMethods]::GetClassNameW($Handle, $sbC, 128)
        if ($sbC.ToString() -ne 'ThunderDFrame') { return $true }
        $pid2 = [uint32]0; [void][OxForms.KeyboardProbe.NativeMethods]::GetWindowThreadProcessId($Handle, [ref]$pid2)
        if ($excelIds.Count -gt 0 -and ($excelIds -notcontains [int]$pid2)) { return $true }
        $rect = New-Object OxForms.KeyboardProbe.NativeMethods+RECT
        [void][OxForms.KeyboardProbe.NativeMethods]::GetWindowRect($Handle, [ref]$rect)
        $script:found = [ordered]@{
            handle = ('0x{0:X}' -f $Handle.ToInt64())
            title  = $title
            bounds = [ordered]@{ left = $rect.Left; top = $rect.Top; right = $rect.Right; bottom = $rect.Bottom; width = [Math]::Max(0, $rect.Right - $rect.Left); height = [Math]::Max(0, $rect.Bottom - $rect.Top) }
        }
        return $false
    }
    [void][OxForms.KeyboardProbe.NativeMethods]::EnumWindows($callback, [System.IntPtr]::Zero)
    return $script:found
}

function Wait-ForOracleWindow {
    param([Parameter(Mandatory = $true)][string]$Title, [int]$TimeoutSeconds = 20)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $w = Get-OracleWindow -Title $Title
        if ($null -ne $w) { return $w }
        Start-Sleep -Milliseconds 150
    } while ((Get-Date) -lt $deadline)
    throw "Timed out waiting for UserForm window title containing '$Title'."
}

function New-KeyboardInput {
    param(
        [Parameter(Mandatory = $true)][UInt16]$VirtualKey,
        [Parameter(Mandatory = $true)][UInt32]$Flags   # 0 = keydown, 0x0002 = keyup
    )
    $keyboard = New-Object OxForms.KeyboardProbe.NativeMethods+KEYBDINPUT
    $keyboard.wVk = $VirtualKey
    $keyboard.wScan = 0
    $keyboard.dwFlags = $Flags
    $keyboard.time = 0
    $keyboard.dwExtraInfo = [UIntPtr]::Zero
    $union = New-Object OxForms.KeyboardProbe.NativeMethods+INPUTUNION
    $union.ki = $keyboard
    $input = New-Object OxForms.KeyboardProbe.NativeMethods+INPUT
    $input.type = 1   # INPUT_KEYBOARD
    $input.u = $union
    return $input
}

function Invoke-SendInputKeys {
    param(
        [Parameter(Mandatory = $true)][UInt16[]]$VirtualKeys,
        [System.IntPtr]$TargetHandle = [System.IntPtr]::Zero,
        [int]$AfterDelayMilliseconds = 180
    )
    Ensure-ProbeWindowTypes
    $before = Get-W005InputDiagnosticsSnapshot -TargetHandle $TargetHandle -Phase 'before_sendinput_keys'
    $inputList = [System.Collections.Generic.List[object]]::new()
    foreach ($vk in $VirtualKeys) {
        $inputList.Add((New-KeyboardInput -VirtualKey $vk -Flags 0)) | Out-Null
        $inputList.Add((New-KeyboardInput -VirtualKey $vk -Flags 0x0002)) | Out-Null
    }
    $inputs = [OxForms.KeyboardProbe.NativeMethods+INPUT[]]$inputList.ToArray()
    $sent = [OxForms.KeyboardProbe.NativeMethods]::SendInput(
        [uint32]$inputs.Length,
        $inputs,
        [System.Runtime.InteropServices.Marshal]::SizeOf([type][OxForms.KeyboardProbe.NativeMethods+INPUT]))
    $lastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    if ($AfterDelayMilliseconds -gt 0) { Start-Sleep -Milliseconds $AfterDelayMilliseconds }
    $after = Get-W005InputDiagnosticsSnapshot -TargetHandle $TargetHandle -Phase 'after_sendinput_keys'
    return [ordered]@{
        requested = [int]$inputs.Length
        sent = [int]$sent
        last_win32_error = [int]$lastError
        status = if ($sent -eq [uint32]$inputs.Length) { 'completed' } else { 'blocked' }
        diagnostics = [ordered]@{ before = $before; after = $after }
    }
}

function Get-ProbeRowCount {
    param([Parameter(Mandatory = $true)]$Workbook)
    $sheet = $Workbook.Worksheets.Item($logSheetName)
    $range = $sheet.UsedRange
    $rowCount = [int]$range.Rows.Count
    $values = $range.Value2
    # Row 1 is the header; any data row means MSForms dispatched at least one event.
    if ($rowCount -lt 2) { return 0 }
    $dataRows = 0
    for ($r = 2; $r -le $rowCount; $r++) {
        if ($null -ne $values[$r, 1] -and -not [string]::IsNullOrWhiteSpace([string]$values[$r, 1])) { $dataRows++ }
    }
    return $dataRows
}

# ---- main ----
if ($DryRun -or $GenerateOnly) {
    Write-Host 'Keyboard SendInput probe: DryRun/GenerateOnly requested; the live probe is skipped.'
    Write-Host 'No keyboard reachability assertion was made (this is a skip, not a pass).'
    exit 0
}

New-Item -ItemType Directory -Force -Path $probeDir | Out-Null
$workbookPath = Join-Path $probeDir $workbookFileName

$excel = $null; $workbook = $null
try {
    New-ProbeWorkbook -WorkbookPath $workbookPath

    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $true; $excel.DisplayAlerts = $false
    try { $excel.AutomationSecurity = 1 } catch { Write-Warning "Could not set AutomationSecurity: $($_.Exception.Message)" }
    $workbook = $excel.Workbooks.Open($workbookPath)
    $excel.Run('ClearProbeLog')
    $excel.Run('ShowProbeModeless')
    Start-Sleep -Milliseconds ($ActionDelayMilliseconds * 2)

    $window = Wait-ForOracleWindow -Title $formCaption -TimeoutSeconds 25
    $handle = ConvertFrom-W005HandleText -Handle ([string]$window.handle)
    $foreground = Set-W005ForegroundWindow -Handle $handle -DelayMilliseconds $ActionDelayMilliseconds

    # Click the window centre to focus the TextBox (it fills the client area).
    $cx = [int][Math]::Round([double]$window.bounds.left + ([double]$window.bounds.width / 2.0))
    $cy = [int][Math]::Round([double]$window.bounds.top + ([double]$window.bounds.height / 2.0))
    [void](Invoke-W005SendInputMouseClick -ScreenX $cx -ScreenY $cy -TargetHandle $handle -DownUpDelayMilliseconds 60 -AfterDelayMilliseconds $ActionDelayMilliseconds)

    # SendInput a single known character: VK 0x41 = 'A' (down + up = 2 inputs).
    $keyResult = Invoke-SendInputKeys -VirtualKeys @([UInt16]0x41) -TargetHandle $handle -AfterDelayMilliseconds 400

    $probeRowCount = Get-ProbeRowCount -Workbook $workbook
    $setForegroundResult = [bool]$foreground.set_foreground_result

    # Close the form/Excel before judging (Alt+F4 would also work; here we Quit COM
    # directly since the probe drove no modal). Quit without saving the scratch file.
    try { $workbook.Close($false) } catch { Write-Warning "Failed to close probe workbook: $($_.Exception.Message)" }
    Release-ComObjectIfPresent $workbook; $workbook = $null
    $excel.Quit(); Release-ComObjectIfPresent $excel; $excel = $null

    $sendOk = ($keyResult.status -eq 'completed')
    $rowsOk = ($probeRowCount -ge 1)
    if ($sendOk -and $rowsOk) {
        Write-Host "Keyboard SendInput reachable: set_foreground=$setForegroundResult sent=$($keyResult.sent)/$($keyResult.requested) probe_rows=$probeRowCount"
        Write-Host 'true'
        exit 0
    }

    Write-Host 'Keyboard SendInput probe FAILED.'
    Write-Host "set_foreground_result: $setForegroundResult"
    Write-Host "sent: $($keyResult.sent) (requested $($keyResult.requested), last_win32_error $($keyResult.last_win32_error))"
    Write-Host "probe_row_count: $probeRowCount"
    Write-Host 'interactive desktop is locked or input-incapable; SendInput injected 0 events / SetForegroundWindow=False - reconnect/unlock the console session and rerun'
    exit 2
} catch {
    Write-Host 'Keyboard SendInput probe FAILED (probe harness error).'
    Write-Host "reason: $($_.Exception.Message)"
    Write-Host 'interactive desktop is locked or input-incapable; SendInput injected 0 events / SetForegroundWindow=False - reconnect/unlock the console session and rerun'
    exit 3
} finally {
    if ($null -ne $workbook) { try { $workbook.Close($false) } catch { Write-Warning "Failed to close probe workbook: $($_.Exception.Message)" } }
    if ($null -ne $excel) { try { $excel.Quit() } catch { Write-Warning "Failed to quit Excel: $($_.Exception.Message)" } }
    Release-ComObjectIfPresent $workbook
    Release-ComObjectIfPresent $excel
    # Best-effort scratch cleanup; never fail the probe on a leftover temp file.
    try { if (Test-Path -LiteralPath $probeDir -PathType Container) { Remove-Item -LiteralPath $probeDir -Recurse -Force -ErrorAction SilentlyContinue } } catch { }
}
