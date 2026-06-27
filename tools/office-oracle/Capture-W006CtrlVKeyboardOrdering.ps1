[CmdletBinding()]
param(
    [string]$FixtureDir = 'fixtures\office-oracle\excel-msforms\userforms\ctrlv-keyboard-ordering',
    [string]$OutDir,
    [switch]$Force,
    [switch]$DryRun,
    [switch]$GenerateOnly,
    [int]$ActionDelayMilliseconds = 220
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$captureRoot = Join-Path $repoRoot 'docs\evidence\W006_control_implementation_rollout\captures'
$captureBead = 'oxforms-0a0.17'
$clipboardSeedText = 'OxFormsClipboardSeed'
$clipboardSeedId = 'repo_owned_ctrlv_text_seed_v1'

Import-Module (Join-Path $repoRoot 'tools\W005WindowsInputDiagnostics.psm1') -Force

function Resolve-InRepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $fullPath = if ([System.IO.Path]::IsPathRooted($Path)) { [System.IO.Path]::GetFullPath($Path) } else { [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path)) }
    $repoWithSeparator = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not ($fullPath.Equals($repoRoot, [System.StringComparison]::OrdinalIgnoreCase) -or $fullPath.StartsWith($repoWithSeparator, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Path '$Path' resolves outside repository root '$repoRoot'."
    }
    return $fullPath
}

function Resolve-CaptureDir {
    param([string]$Directory)
    if ([string]::IsNullOrWhiteSpace($Directory)) {
        $Directory = Join-Path $captureRoot ('ctrlv-keyboard-ordering-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))
    }
    $fullPath = if ([System.IO.Path]::IsPathRooted($Directory)) { [System.IO.Path]::GetFullPath($Directory) } else { [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Directory)) }
    $root = [System.IO.Path]::GetFullPath($captureRoot)
    $rootWithSeparator = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "OutDir '$fullPath' must be under '$root'."
    }
    if ((Test-Path -LiteralPath $fullPath -PathType Container) -and -not $Force) {
        if (@(Get-ChildItem -LiteralPath $fullPath -Force).Count -gt 0) {
            throw "OutDir '$fullPath' already contains files. Use a fresh capture id or pass -Force."
        }
    }
    New-Item -ItemType Directory -Force -Path $fullPath | Out-Null
    return (Resolve-Path -LiteralPath $fullPath).Path
}

function ConvertTo-RepoRelative {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $repoWithSeparator = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if ($fullPath.StartsWith($repoWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $fullPath.Substring($repoWithSeparator.Length).Replace([System.IO.Path]::DirectorySeparatorChar, '/').Replace([System.IO.Path]::AltDirectorySeparatorChar, '/')
    }
    return $fullPath
}

function Get-RequiredValue {
    param([Parameter(Mandatory = $true)]$Object, [Parameter(Mandatory = $true)][string]$Name)
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { throw "Fixture manifest is missing required value: $Name" }
    if ($property.Value -is [string] -and [string]::IsNullOrWhiteSpace($property.Value)) { throw "Fixture manifest has an empty required value: $Name" }
    return $property.Value
}

function Get-OptionalValue {
    param($Object, [Parameter(Mandatory = $true)][string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Resolve-FixtureSourcePath {
    param([Parameter(Mandatory = $true)][string]$FixtureRoot, [Parameter(Mandatory = $true)][string]$Path)
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $FixtureRoot $Path))
    $repoWithSeparator = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($repoWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) { throw "Fixture source path must stay inside the repository: $Path" }
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw "Fixture source file not found: $fullPath" }
    return $fullPath
}

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][string]$Path)
    # FileShare.ReadWrite so the workbook can be hashed even if the just-quit
    # Excel process is still briefly releasing its (shared-read) handle.
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try { return ([System.BitConverter]::ToString($sha256.ComputeHash($stream)) -replace '-', '').ToLowerInvariant() } finally { $sha256.Dispose() }
    } finally { $stream.Dispose() }
}

function Write-JsonFile {
    param([Parameter(Mandatory = $true)][object]$Value, [Parameter(Mandatory = $true)][string]$Path)
    $Value | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Write-CaptureGitAttributes {
    param([Parameter(Mandatory = $true)][string]$ResolvedOutDir)
    $lines = @('.gitattributes text eol=crlf diff', '*.json text eol=crlf diff', '*.csv text eol=crlf diff', '*.md text eol=crlf diff', '*.txt text eol=crlf diff', '*.log text eol=crlf diff', 'checksums.sha256 text eol=crlf diff', '*.xlsm -text -diff')
    Set-Content -LiteralPath (Join-Path $ResolvedOutDir '.gitattributes') -Value $lines -Encoding ASCII
}

function Write-ProgressStep {
    param([Parameter(Mandatory = $true)][string]$ResolvedOutDir, [Parameter(Mandatory = $true)][string]$Step)
    Add-Content -LiteralPath (Join-Path $ResolvedOutDir 'capture-progress.log') -Value ((Get-Date).ToUniversalTime().ToString('o') + ' ' + $Step) -Encoding UTF8
}

function Release-ComObjectIfPresent {
    param($Object)
    if ($null -ne $Object -and [System.Runtime.InteropServices.Marshal]::IsComObject($Object)) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($Object) }
}

function Set-ComponentPropertyValue {
    param([Parameter(Mandatory = $true)]$Component, [Parameter(Mandatory = $true)][string]$PropertyName, [Parameter(Mandatory = $true)]$Value)
    $property = $Component.Properties.Item($PropertyName)
    $property.GetType().InvokeMember('Value', [System.Reflection.BindingFlags]::SetProperty, $null, $property, @($Value), [System.Globalization.CultureInfo]::InvariantCulture)
}

function New-WorkbookFromFixture {
    param([Parameter(Mandatory = $true)]$Fixture, [Parameter(Mandatory = $true)][string]$FixtureRoot, [Parameter(Mandatory = $true)][string]$WorkbookPath)
    if (Test-Path -LiteralPath $WorkbookPath -PathType Leaf) {
        if (-not $Force) { throw "Output workbook already exists. Pass -Force to replace it: $WorkbookPath" }
        Remove-Item -LiteralPath $WorkbookPath -Force
    }
    $form = Get-RequiredValue $Fixture 'form'
    $excel = $null; $workbook = $null; $vbProject = $null; $component = $null; $standardModule = $null
    try {
        try { $excel = New-Object -ComObject Excel.Application } catch { throw "Microsoft Excel COM automation is unavailable: $($_.Exception.Message)" }
        $excel.Visible = $false; $excel.DisplayAlerts = $false
        $workbook = $excel.Workbooks.Add()
        try { $vbProject = $workbook.VBProject } catch { throw "Excel blocked access to the VBA project object model. Enable 'Trust access to the VBA project object model'." }

        $component = $vbProject.VBComponents.Add(3)
        $component.Name = [string](Get-RequiredValue $form 'name')
        $designer = $component.Designer
        Set-ComponentPropertyValue $component 'Caption' ([string](Get-RequiredValue $form 'caption'))
        Set-ComponentPropertyValue $component 'Width' ([single](Get-RequiredValue $form 'widthPt'))
        Set-ComponentPropertyValue $component 'Height' ([single](Get-RequiredValue $form 'heightPt'))
        Set-ComponentPropertyValue $component 'StartUpPosition' ([single](Get-RequiredValue $form 'startupPosition'))

        foreach ($control in @($form.controls)) {
            $created = $designer.Controls.Add([string](Get-RequiredValue $control 'type'), [string](Get-RequiredValue $control 'name'), $true)
            $created.Left = [single](Get-RequiredValue $control 'leftPt')
            $created.Top = [single](Get-RequiredValue $control 'topPt')
            $created.Width = [single](Get-RequiredValue $control 'widthPt')
            $created.Height = [single](Get-RequiredValue $control 'heightPt')
            $caption = Get-OptionalValue $control 'caption'
            if ($null -ne $caption) { $created.Caption = [string]$caption }
            # Design-time control fonts are intentionally not set (unreliable VBIDE
            # COM path; not load-bearing for a Ctrl+V keyboard-ordering oracle).
        }

        $codePath = Resolve-FixtureSourcePath -FixtureRoot $FixtureRoot -Path ([string](Get-RequiredValue $form 'codeBehindSourcePath'))
        $component.CodeModule.AddFromString((Get-Content -Raw -LiteralPath $codePath))

        $standardModule = $vbProject.VBComponents.Add(1)
        $standardModule.Name = [string](Get-RequiredValue $Fixture.workbook 'vbaModuleName')
        $stdPath = Resolve-FixtureSourcePath -FixtureRoot $FixtureRoot -Path ([string](Get-RequiredValue $Fixture.workbook 'standardModuleSourcePath'))
        $standardModule.CodeModule.AddFromString((Get-Content -Raw -LiteralPath $stdPath))

        $workbook.SaveAs($WorkbookPath, 52)
    } finally {
        if ($null -ne $workbook) { try { $workbook.Close($true) } catch { Write-Warning "Failed to close generated workbook: $($_.Exception.Message)" } }
        if ($null -ne $excel) { try { $excel.Quit() } catch { Write-Warning "Failed to quit Excel after generation: $($_.Exception.Message)" } }
        Release-ComObjectIfPresent $standardModule
        Release-ComObjectIfPresent $component
        Release-ComObjectIfPresent $vbProject
        Release-ComObjectIfPresent $workbook
        Release-ComObjectIfPresent $excel
    }
}

function Ensure-WindowEnumTypes {
    if (([System.Management.Automation.PSTypeName]'OxForms.W006CtrlV.NativeMethods').Type) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
namespace OxForms.W006CtrlV
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

        [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);

        [StructLayout(LayoutKind.Sequential)]
        public struct INPUT { public uint type; public INPUTUNION u; }

        // Size = 32 pins this union to sizeof(MOUSEINPUT) so Marshal.SizeOf(INPUT) == 40 on x64;
        // otherwise cbSize is 32 and SendInput rejects every event (ERROR_INVALID_PARAMETER 87).
        [StructLayout(LayoutKind.Explicit, Size = 32)]
        public struct INPUTUNION { [FieldOffset(0)] public KEYBDINPUT ki; }

        [StructLayout(LayoutKind.Sequential)]
        public struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public UIntPtr dwExtraInfo; }

        [DllImport("user32.dll", SetLastError = true)] public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
    }
}
'@
}

function Get-OracleWindow {
    param([Parameter(Mandatory = $true)][string]$Title)
    Ensure-WindowEnumTypes
    # Reset at script scope each call: the EnumWindows callback assigns
    # $script:found, and under Set-StrictMode reading an unset $script:found (a
    # poll that matched no window) would throw instead of returning $null.
    $script:found = $null
    $excelIds = @(Get-Process EXCEL -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    $callback = [OxForms.W006CtrlV.NativeMethods+EnumWindowsProc]{
        param([System.IntPtr]$Handle, [System.IntPtr]$Param)
        if (-not [OxForms.W006CtrlV.NativeMethods]::IsWindowVisible($Handle)) { return $true }
        $sbT = [System.Text.StringBuilder]::new(512); [void][OxForms.W006CtrlV.NativeMethods]::GetWindowTextW($Handle, $sbT, 512); $title = $sbT.ToString()
        if ($title.IndexOf($Title, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { return $true }
        $sbC = [System.Text.StringBuilder]::new(128); [void][OxForms.W006CtrlV.NativeMethods]::GetClassNameW($Handle, $sbC, 128)
        if ($sbC.ToString() -ne 'ThunderDFrame') { return $true }
        $pid2 = [uint32]0; [void][OxForms.W006CtrlV.NativeMethods]::GetWindowThreadProcessId($Handle, [ref]$pid2)
        if ($excelIds.Count -gt 0 -and ($excelIds -notcontains [int]$pid2)) { return $true }
        $rect = New-Object OxForms.W006CtrlV.NativeMethods+RECT
        [void][OxForms.W006CtrlV.NativeMethods]::GetWindowRect($Handle, [ref]$rect)
        $script:found = [ordered]@{
            handle = ('0x{0:X}' -f $Handle.ToInt64())
            title  = $title
            bounds = [ordered]@{ left = $rect.Left; top = $rect.Top; right = $rect.Right; bottom = $rect.Bottom; width = [Math]::Max(0, $rect.Right - $rect.Left); height = [Math]::Max(0, $rect.Bottom - $rect.Top) }
        }
        return $false
    }
    [void][OxForms.W006CtrlV.NativeMethods]::EnumWindows($callback, [System.IntPtr]::Zero)
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

function Invoke-CenterClick {
    param([Parameter(Mandatory = $true)]$Window, [Parameter(Mandatory = $true)][string]$Label)
    $cx = [int][Math]::Round([double]$Window.bounds.left + ([double]$Window.bounds.width / 2.0))
    $cy = [int][Math]::Round([double]$Window.bounds.top + ([double]$Window.bounds.height / 2.0))
    $handle = ConvertFrom-W005HandleText -Handle ([string]$Window.handle)
    $foreground = Set-W005ForegroundWindow -Handle $handle -DelayMilliseconds $ActionDelayMilliseconds
    $input = Invoke-W005SendInputMouseClick -ScreenX $cx -ScreenY $cy -TargetHandle $handle -DownUpDelayMilliseconds 60 -AfterDelayMilliseconds $ActionDelayMilliseconds
    return [ordered]@{ label = $Label; screen_x = $cx; screen_y = $cy; foreground = $foreground; input = $input }
}

function New-KeyboardInput {
    param([Parameter(Mandatory = $true)][UInt16]$VirtualKey, [Parameter(Mandatory = $true)][UInt32]$Flags)
    Ensure-WindowEnumTypes
    $keyboard = New-Object OxForms.W006CtrlV.NativeMethods+KEYBDINPUT
    $keyboard.wVk = $VirtualKey
    $keyboard.wScan = 0
    $keyboard.dwFlags = $Flags
    $keyboard.time = 0
    $keyboard.dwExtraInfo = [UIntPtr]::Zero
    $union = New-Object OxForms.W006CtrlV.NativeMethods+INPUTUNION
    $union.ki = $keyboard
    $input = New-Object OxForms.W006CtrlV.NativeMethods+INPUT
    $input.type = 1
    $input.u = $union
    return $input
}

function Invoke-SendInputCtrlV {
    param([Parameter(Mandatory = $true)][System.IntPtr]$TargetHandle, [int]$AfterDelayMilliseconds = 180)
    Ensure-WindowEnumTypes
    $before = Get-W005InputDiagnosticsSnapshot -TargetHandle $TargetHandle -Phase 'before_sendinput_ctrl_v'
    # Ctrl down (VK 0x11), V down (VK 0x56), V up (flag 0x0002), Ctrl up.
    $inputs = [OxForms.W006CtrlV.NativeMethods+INPUT[]]@(
        (New-KeyboardInput -VirtualKey 0x11 -Flags 0),
        (New-KeyboardInput -VirtualKey 0x56 -Flags 0),
        (New-KeyboardInput -VirtualKey 0x56 -Flags 0x0002),
        (New-KeyboardInput -VirtualKey 0x11 -Flags 0x0002)
    )
    $sent = [OxForms.W006CtrlV.NativeMethods]::SendInput(
        [uint32]$inputs.Length,
        $inputs,
        [System.Runtime.InteropServices.Marshal]::SizeOf([type][OxForms.W006CtrlV.NativeMethods+INPUT]))
    $lastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    if ($AfterDelayMilliseconds -gt 0) { Start-Sleep -Milliseconds $AfterDelayMilliseconds }
    $after = Get-W005InputDiagnosticsSnapshot -TargetHandle $TargetHandle -Phase 'after_sendinput_ctrl_v'
    return [ordered]@{
        schema = 'oxforms.office_oracle.w006_sendinput_keyboard_action.v1'
        input_driver = 'public_user32_sendinput_keyboard'
        action = 'ctrl_v'
        virtual_keys = [ordered]@{ control = '0x11'; v = '0x56' }
        send_input = [ordered]@{ requested = [int]$inputs.Length; sent = [int]$sent; last_win32_error = [int]$lastError }
        status = if ($sent -eq [uint32]$inputs.Length) { 'completed' } else { 'blocked' }
        diagnostics = [ordered]@{ before = $before; after = $after }
    }
}

function Export-WorksheetLog {
    param([Parameter(Mandatory = $true)]$Workbook, [Parameter(Mandatory = $true)][string]$ResolvedOutDir)
    $sheet = $Workbook.Worksheets.Item('W006CtrlVLog')
    $range = $sheet.UsedRange
    $rowCount = [int]$range.Rows.Count
    $columnCount = [int]$range.Columns.Count
    $values = $range.Value2
    $headers = [System.Collections.Generic.List[string]]::new()
    for ($c = 1; $c -le $columnCount; $c++) { $headers.Add([string]($values[1, $c])) | Out-Null }
    $records = [System.Collections.Generic.List[object]]::new()
    if ($rowCount -ge 2) {
        for ($r = 2; $r -le $rowCount; $r++) {
            $record = [ordered]@{}
            for ($c = 1; $c -le $columnCount; $c++) {
                $v = $values[$r, $c]
                $record[$headers[$c - 1]] = if ($null -eq $v) { '' } else { [string]$v }
            }
            $records.Add([pscustomobject]$record) | Out-Null
        }
    }
    $rows = @($records)
    $csvPath = Join-Path $ResolvedOutDir 'ctrlv-keyboard-ordering-event-log.csv'
    $rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

    $eventNames = @($rows | ForEach-Object { $_.event_name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $keyDownRow = @($rows | Where-Object { $_.event_name -eq 'KeyDown' })[0]
    $keyPressRow = @($rows | Where-Object { $_.event_name -eq 'KeyPress' })[0]
    $keyUpRow = @($rows | Where-Object { $_.event_name -eq 'KeyUp' })[0]
    $beforePasteRow = @($rows | Where-Object { $_.event_name -eq 'BeforeDropOrPaste' })[0]
    $changeRow = @($rows | Where-Object { $_.event_name -eq 'Change' })[0]
    $seqOf = { param($row) if ($null -ne $row) { [int]$row.sequence } else { $null } }
    $keyDownSeq = & $seqOf $keyDownRow
    $beforePasteSeq = & $seqOf $beforePasteRow
    $changeSeq = & $seqOf $changeRow
    $keyDownVsPaste = if ($null -ne $keyDownSeq -and $null -ne $beforePasteSeq) {
        if ($keyDownSeq -lt $beforePasteSeq) { 'keydown_before_paste' } else { 'paste_before_keydown' }
    } else { 'incomplete' }

    $eventLog = [ordered]@{
        schema = 'oxforms.office_oracle.w006_ctrlv_keyboard_ordering_event_log.v1'
        bead = $captureBead
        source = [ordered]@{
            worksheet = 'W006CtrlVLog'
            fixture = 'fixtures/office-oracle/excel-msforms/userforms/ctrlv-keyboard-ordering/fixture.json'
            event_facts = 'docs/specs/FM20_EVENT_FACTS.md#W006-Deferred-Input-Surface-Fact-Split'
            trace_schema = 'docs/specs/TRACE_REPLAY_SCHEMA.md#10-VBA-Dispatch-Rows'
        }
        observed_facts = [ordered]@{
            row_count = $rows.Count
            event_names = $eventNames
            keydown_vs_paste_order = $keyDownVsPaste
            keydown_sequence = $keyDownSeq
            keypress_sequence = (& $seqOf $keyPressRow)
            keyup_sequence = (& $seqOf $keyUpRow)
            before_drop_or_paste_sequence = $beforePasteSeq
            change_sequence = $changeSeq
            clipboard_seed_id = $clipboardSeedId
            rows = $rows
        }
        assumptions = @(
            'Rows are worksheet rows emitted by repo-owned VBA handlers while real Excel/MSForms dispatched one injected Ctrl+V (Ctrl down, V down, V up, Ctrl up) into TextBox1.',
            'The repo-owned clipboard seed text may be identified by seed id; unexpected payloads are not recorded.',
            'For every MSForms.Return* helper, arg_before/arg_after are .Value read before/after the handler body; the value column is TextBox1 .Value at handler entry.'
        )
        unknowns = @(
            'This capture exercises one keyboard Ctrl+V into one TextBox; it does not cover menu paste, IME/composition, dead keys, true OLE drag/drop, or Action mutation.',
            'Rows absent from this run remain unobserved and are not negative MSForms facts.'
        )
        non_claims = @(
            'No OxForms runtime Ctrl+V keyboard-ordering behavior is implemented or claimed by this oracle.',
            'Absence of a row is not a negative parity fact.'
        )
    }
    $jsonPath = Join-Path $ResolvedOutDir 'ctrlv-keyboard-ordering-event-log.json'
    Write-JsonFile -Value $eventLog -Path $jsonPath
    return [ordered]@{ csv = ConvertTo-RepoRelative $csvPath; json = ConvertTo-RepoRelative $jsonPath; row_count = $rows.Count; event_names = $eventNames; keydown_vs_paste_order = $keyDownVsPaste; rows = $rows }
}

function Write-Checksums {
    param([Parameter(Mandatory = $true)][string]$ResolvedOutDir)
    $checksumPath = Join-Path $ResolvedOutDir 'checksums.sha256'
    $sep = $ResolvedOutDir.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $files = Get-ChildItem -LiteralPath $ResolvedOutDir -Recurse -File | Where-Object { $_.FullName -ne $checksumPath } | Sort-Object FullName
    $lines = foreach ($file in $files) {
        $rel = $file.FullName.Substring($sep.Length).Replace([System.IO.Path]::DirectorySeparatorChar, '/').Replace([System.IO.Path]::AltDirectorySeparatorChar, '/')
        "$(Get-Sha256Hex -Path $file.FullName)  $rel"
    }
    Set-Content -LiteralPath $checksumPath -Value $lines -Encoding ASCII
}

# ---- main ----
$fixtureRoot = Resolve-InRepoPath $FixtureDir
$fixturePath = Join-Path $fixtureRoot 'fixture.json'
if (-not (Test-Path -LiteralPath $fixturePath)) { throw "Fixture manifest not found: $fixturePath" }
$fixture = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
[void](Get-RequiredValue $fixture 'id')
$form = Get-RequiredValue $fixture 'form'
$formCaption = [string](Get-RequiredValue $form 'caption')
[void](Resolve-FixtureSourcePath -FixtureRoot $fixtureRoot -Path ([string](Get-RequiredValue $form 'codeBehindSourcePath')))
[void](Resolve-FixtureSourcePath -FixtureRoot $fixtureRoot -Path ([string](Get-RequiredValue $fixture.workbook 'standardModuleSourcePath')))

if ($DryRun) {
    Write-Host "Fixture: $($fixture.id)"
    Write-Host "Form: $formCaption"
    Write-Host 'Dry run only: manifest and repository paths are valid. Excel was not started.'
    exit 0
}

$resolvedOutDir = Resolve-CaptureDir -Directory $OutDir
$captureId = Split-Path -Leaf $resolvedOutDir
$workbookPath = Join-Path $resolvedOutDir ([string](Get-RequiredValue $fixture.workbook 'fileName'))
$fixtureHashes = [ordered]@{
    manifest = [ordered]@{ path = ConvertTo-RepoRelative $fixturePath; sha256 = Get-Sha256Hex -Path $fixturePath }
    form_code_behind = [ordered]@{ path = ConvertTo-RepoRelative (Join-Path $fixtureRoot ([string]$form.codeBehindSourcePath)); sha256 = Get-Sha256Hex -Path (Join-Path $fixtureRoot ([string]$form.codeBehindSourcePath)) }
    standard_module = [ordered]@{ path = ConvertTo-RepoRelative (Join-Path $fixtureRoot ([string]$fixture.workbook.standardModuleSourcePath)); sha256 = Get-Sha256Hex -Path (Join-Path $fixtureRoot ([string]$fixture.workbook.standardModuleSourcePath)) }
    capture_tool = [ordered]@{ path = ConvertTo-RepoRelative $PSCommandPath; sha256 = Get-Sha256Hex -Path $PSCommandPath }
}
$inputActions = [System.Collections.Generic.List[object]]::new()
$excel = $null; $workbook = $null; $eventLog = $null; $excelInfo = $null

Write-CaptureGitAttributes -ResolvedOutDir $resolvedOutDir
Set-Content -LiteralPath (Join-Path $resolvedOutDir 'capture.command.txt') -Value ([System.Environment]::CommandLine) -Encoding UTF8
Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'capture_directory_prepared'
Set-Location $repoRoot

try {
    New-WorkbookFromFixture -Fixture $fixture -FixtureRoot $fixtureRoot -WorkbookPath $workbookPath
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'workbook_generated'
    if ($GenerateOnly) {
        Write-Host "GenerateOnly: workbook generated at $workbookPath"
        if (Test-Path -LiteralPath $workbookPath -PathType Leaf) { Write-Host "GenerateOnly: SHA256 $(Get-Sha256Hex -Path $workbookPath)" }
        exit 0
    }

    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $true; $excel.DisplayAlerts = $false
    try { $excel.AutomationSecurity = 1 } catch { Write-Warning "Could not set AutomationSecurity: $($_.Exception.Message)" }
    $excelPath = Join-Path $excel.Path 'EXCEL.EXE'
    if (Test-Path -LiteralPath $excelPath -PathType Leaf) {
        $vi = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($excelPath)
        $excelInfo = [ordered]@{ path = $excelPath; file_version = $vi.FileVersion; product_version = $vi.ProductVersion; product_name = $vi.ProductName; company_name = $vi.CompanyName }
    }
    $workbook = $excel.Workbooks.Open($workbookPath)
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'workbook_opened'
    $excel.Run([string](Get-RequiredValue $fixture.workbook 'clearLogMacroName'))
    $excel.Run([string](Get-RequiredValue $fixture.workbook 'showMacroName'))
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'form_shown_modeless'
    Start-Sleep -Milliseconds ($ActionDelayMilliseconds * 2)

    $window = Wait-ForOracleWindow -Title $formCaption -TimeoutSeconds 25
    # One click at the window centre focuses TextBox1 (it fills the client area).
    $inputActions.Add((Invoke-CenterClick -Window $window -Label 'focus_textbox')) | Out-Null
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'textbox_focus_click_sent'
    Start-Sleep -Milliseconds $ActionDelayMilliseconds

    # Seed the public Windows clipboard with the repo-owned text. WinForms
    # Clipboard requires STA; if this host is MTA, run SetText in a short-lived
    # STA runspace so the seed is honest regardless of apartment state.
    Add-Type -AssemblyName System.Windows.Forms
    if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -eq [System.Threading.ApartmentState]::STA) {
        [System.Windows.Forms.Clipboard]::SetText($clipboardSeedText)
    } else {
        $rs = [runspacefactory]::CreateRunspace()
        $rs.ApartmentState = 'STA'
        $rs.ThreadOptions = 'ReuseThread'
        $rs.Open()
        try {
            $ps = [powershell]::Create()
            $ps.Runspace = $rs
            [void]$ps.AddScript('param($t) Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Clipboard]::SetText($t)').AddArgument($clipboardSeedText)
            [void]$ps.Invoke()
            $ps.Dispose()
        } finally { $rs.Close() }
    }
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'clipboard_seed_set'
    $inputActions.Add([ordered]@{
        sequence = 2
        method = 'public_windows_clipboard'
        action = 'set_clipboard_text'
        manual = $false
        clipboard_seed_id = $clipboardSeedId
        target_intent = 'Clipboard contains repo-owned text seed before Ctrl+V.'
        payload_policy = 'Repo-owned seed text may be identified by seed id in evidence.'
    }) | Out-Null

    # Bring the UserForm foreground and send Ctrl+V via public user32 SendInput.
    $targetHandle = ConvertFrom-W005HandleText -Handle ([string]$window.handle)
    $foregroundTransition = Set-W005ForegroundWindow -Handle $targetHandle -DelayMilliseconds $ActionDelayMilliseconds
    $inputActions.Add([ordered]@{
        sequence = 3
        method = 'public_user32_showwindow_setforegroundwindow'
        action = 'focus_userform'
        manual = $false
        target_intent = 'Prepare the modeless UserForm for public Ctrl+V keyboard input.'
        result = $foregroundTransition
    }) | Out-Null

    $sendInputStatus = Invoke-SendInputCtrlV -TargetHandle $targetHandle -AfterDelayMilliseconds ($ActionDelayMilliseconds * 3)
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('sendinput_ctrl_v_status=' + $sendInputStatus.status)
    $inputActions.Add([ordered]@{
        sequence = 4
        method = 'public_user32_sendinput_keyboard'
        action = 'ctrl_v'
        keys = 'Ctrl down, V down, V up, Ctrl up'
        manual = $false
        target_intent = 'Paste the repo-owned clipboard text into TextBox1 and record keyboard ordering.'
        result = $sendInputStatus
        notes = 'This is evidence-driving infrastructure, not OxForms runtime architecture.'
    }) | Out-Null
    # A dead-keyboard desktop yields an honest blocker, never a false "no rows" claim.
    if ($sendInputStatus.status -ne 'completed') {
        throw "Public user32 SendInput Ctrl+V did not inject all 4 keyboard inputs (requested=$($sendInputStatus.send_input.requested), sent=$($sendInputStatus.send_input.sent), last_win32_error=$($sendInputStatus.send_input.last_win32_error)). The keyboard path is blocked in this desktop session; no Ctrl+V ordering is inferred."
    }
    Start-Sleep -Milliseconds ($ActionDelayMilliseconds * 2)

    Write-JsonFile -Path (Join-Path $resolvedOutDir 'input-actions.json') -Value ([ordered]@{
        schema = 'oxforms.office_oracle.w006_ctrlv_keyboard_ordering_input_actions.v1'
        bead = $captureBead
        manual_inputs = @()
        automated_inputs = @($inputActions)
        notes = @(
            'WinForms Clipboard and public user32 SendInput keyboard input are evidence-driving tools around live Excel/MSForms.',
            'One public mouse click focuses TextBox1; the public Windows clipboard is seeded; then public user32 SendInput sends Ctrl down, V down, V up, Ctrl up.'
        )
    })

    $eventLog = Export-WorksheetLog -Workbook $workbook -ResolvedOutDir $resolvedOutDir
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('event_log_exported_rows=' + $eventLog.row_count + '_order=' + $eventLog.keydown_vs_paste_order)

    $workbook.Save(); $workbook.Close($true); Release-ComObjectIfPresent $workbook; $workbook = $null
    $excel.Quit(); Release-ComObjectIfPresent $excel; $excel = $null
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'excel_closed_before_manifest'

    $manifest = [ordered]@{
        schema = 'oxforms.office_oracle.w006_ctrlv_keyboard_ordering_capture.v1'
        bead = $captureBead
        capture_id = $captureId
        status = 'captured'
        fixture = [ordered]@{ id = $fixture.id; inputs = $fixtureHashes }
        platform = [ordered]@{ os = [System.Environment]::OSVersion.VersionString; is_windows = $true; powershell = $PSVersionTable.PSVersion.ToString() }
        excel = $excelInfo
        artifacts = [ordered]@{
            generated_workbook = if (Test-Path -LiteralPath $workbookPath -PathType Leaf) { [ordered]@{ path = ConvertTo-RepoRelative $workbookPath; sha256 = Get-Sha256Hex -Path $workbookPath } } else { $null }
            event_log_json = $eventLog.json
            event_log_csv = $eventLog.csv
            input_actions = ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'input-actions.json')
        }
        observed_coverage = [ordered]@{ row_count = $eventLog.row_count; event_names = $eventLog.event_names; keydown_vs_paste_order = $eventLog.keydown_vs_paste_order }
        trace_replay_implications = @(
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 10: VBA dispatch rows for a keyboard paste need ordered KeyDown/KeyPress/KeyUp and BeforeDropOrPaste/Change rows.',
            'docs/specs/FM20_EVENT_FACTS.md: this oracle redoes the oxforms-0a0.17 Ctrl+V keyboard-driver blocker on a working-input desktop and records the keyboard-vs-paste ordering.'
        )
        warnings = @(
            'Black-box Excel/MSForms evidence only; no OxForms output was compared.',
            'Covers one keyboard Ctrl+V into one TextBox; menu paste, IME, dead keys, and true drag/drop are not exercised.',
            'Desktop focus, keyboard layout, clipboard policy, theme, DPI, and Excel/MSForms version can affect observed rows.'
        )
        clean_room = [ordered]@{ source = 'Repo-owned fixture generated through public Excel/VBIDE automation and driven through the public Windows clipboard and public user32 SendInput keyboard input.'; prohibited = 'No Office internals, decompilation, disassembly, non-public source, or OxForms output comparison.' }
        non_claims = @('No OxForms runtime Ctrl+V keyboard-ordering behavior is implemented or claimed.', 'This capture is not an exhaustive paste/keyboard event parity matrix.', 'Absence of a row is not a negative MSForms fact.')
    }
    Write-JsonFile -Path (Join-Path $resolvedOutDir 'oracle-capture-manifest.json') -Value $manifest
    $readme = @(
        '# W006 Ctrl+V Keyboard-ordering Oracle Capture', '',
        "Capture id: $captureId", ('Bead: `' + $captureBead + '`'), 'Status: `captured`', '',
        'Black-box Excel/MSForms evidence for the Ctrl+V keyboard ordering (KeyDown/KeyPress/KeyUp vs BeforeDropOrPaste vs Change). Not an OxForms output comparison and not an exhaustive parity claim. This redoes the oxforms-0a0.17 keyboard-driver blocker on a working-input desktop.', '',
        '## Facts', '',
        "- Observed order: ``$($eventLog.keydown_vs_paste_order)``; event names: ``$(@($eventLog.event_names) -join ', ')``.",
        '- `ctrlv-keyboard-ordering-event-log.json`/`.csv` are worksheet rows from repo-owned VBA handlers while live Excel handled one injected Ctrl+V.',
        '- `input-actions.json` records the public mouse focus click, the public Windows clipboard seed, and the public user32 SendInput Ctrl+V; `manual_inputs` is empty.', '',
        '## Clean-room Note', '',
        'Repo-owned fixture sources, public Excel/VBIDE automation, the public Windows clipboard, public user32 SendInput keyboard input, and worksheet export only. No Office internals, decompilation, disassembly, or OxForms output comparison.'
    )
    Set-Content -LiteralPath (Join-Path $resolvedOutDir 'README.md') -Value $readme -Encoding UTF8
    Write-Checksums -ResolvedOutDir $resolvedOutDir
    Write-Host "W006 Ctrl+V keyboard-ordering capture complete: $resolvedOutDir"
    Write-Host "Rows: $($eventLog.row_count); order: $($eventLog.keydown_vs_paste_order); events: $(@($eventLog.event_names) -join ', ')"
} catch {
    $progressPath = Join-Path $resolvedOutDir 'capture-progress.log'
    $lastEntry = if (Test-Path -LiteralPath $progressPath -PathType Leaf) { @(Get-Content -LiteralPath $progressPath)[-1] } else { '<no progress entry>' }
    $blocker = [ordered]@{
        schema = 'oxforms.office_oracle.w006_ctrlv_keyboard_ordering_blocker.v1'
        bead = $captureBead; capture_id = $captureId; status = 'blocked'
        reason = $_.Exception.Message
        facts = @('Repo-owned fixture loaded before the live capture path.', ('Last capture-progress entry: ' + $lastEntry))
        non_claims = @('No OxForms runtime behavior is implemented or claimed.', 'No missing row is treated as a negative MSForms fact.', 'No Ctrl+V keyboard ordering is inferred from a blocked keyboard path.')
        clean_room = [ordered]@{ source = 'Repo-owned fixture input + public Excel/VBIDE/Windows clipboard/keyboard automation.'; prohibited = 'No Office internals, decompilation, disassembly, non-public source, or OxForms output comparison.' }
    }
    Write-JsonFile -Path (Join-Path $resolvedOutDir 'blocker.json') -Value $blocker
    Write-Checksums -ResolvedOutDir $resolvedOutDir
    Write-Host "W006 Ctrl+V keyboard-ordering capture blocked: $resolvedOutDir"
    Write-Host "Blocker: $($_.Exception.Message)"
} finally {
    if ($null -ne $workbook) { try { $workbook.Close($true) } catch { Write-Warning "Failed to close workbook: $($_.Exception.Message)" } }
    if ($null -ne $excel) { try { $excel.Quit() } catch { Write-Warning "Failed to quit Excel: $($_.Exception.Message)" } }
    Release-ComObjectIfPresent $workbook
    Release-ComObjectIfPresent $excel
}
