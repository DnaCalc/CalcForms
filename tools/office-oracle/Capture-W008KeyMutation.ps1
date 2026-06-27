[CmdletBinding()]
param(
    [string]$FixtureDir = 'fixtures\office-oracle\excel-msforms\userforms\w008-focus-key-breadth',
    [string]$OutDir,
    [switch]$Force,
    [switch]$DryRun,
    [switch]$GenerateOnly,
    [int]$ActionDelayMilliseconds = 220
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$captureRoot = Join-Path $repoRoot 'docs\evidence\W008_native_event_breadth\captures'
$captureBead = 'oxforms-esq.3'
$worksheetName = 'W008BreadthLog'
$logColumns = @('sequence', 'scenario', 'control_name', 'event_name', 'arg_name', 'arg_before', 'arg_after', 'focus_owner_after', 'text_value_after', 'notes')
$requiredScenarios = @('default_button_enter', 'swallow_keydown', 'swallow_keypress', 'arrow_swallow', 'change_timing')

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
        $Directory = Join-Path $captureRoot ('w008-key-mutation-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))
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
    $Value | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $Path -Encoding UTF8
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
            # COM path; Default/accelerator properties are set at runtime in
            # UserForm_Initialize instead of via fixture.json controls).
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
    if (([System.Management.Automation.PSTypeName]'OxForms.W008KeyMutation.NativeMethods').Type) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
namespace OxForms.W008KeyMutation
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
    Ensure-WindowEnumTypes
    # Reset at script scope each call: the EnumWindows callback assigns
    # $script:found, and under Set-StrictMode reading an unset $script:found (a
    # poll that matched no window) would throw instead of returning $null.
    $script:found = $null
    $excelIds = @(Get-Process EXCEL -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    $callback = [OxForms.W008KeyMutation.NativeMethods+EnumWindowsProc]{
        param([System.IntPtr]$Handle, [System.IntPtr]$Param)
        if (-not [OxForms.W008KeyMutation.NativeMethods]::IsWindowVisible($Handle)) { return $true }
        $sbT = [System.Text.StringBuilder]::new(512); [void][OxForms.W008KeyMutation.NativeMethods]::GetWindowTextW($Handle, $sbT, 512); $title = $sbT.ToString()
        if ($title.IndexOf($Title, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { return $true }
        $sbC = [System.Text.StringBuilder]::new(128); [void][OxForms.W008KeyMutation.NativeMethods]::GetClassNameW($Handle, $sbC, 128)
        if ($sbC.ToString() -ne 'ThunderDFrame') { return $true }
        $pid2 = [uint32]0; [void][OxForms.W008KeyMutation.NativeMethods]::GetWindowThreadProcessId($Handle, [ref]$pid2)
        if ($excelIds.Count -gt 0 -and ($excelIds -notcontains [int]$pid2)) { return $true }
        $rect = New-Object OxForms.W008KeyMutation.NativeMethods+RECT
        [void][OxForms.W008KeyMutation.NativeMethods]::GetWindowRect($Handle, [ref]$rect)
        $script:found = [ordered]@{
            handle = ('0x{0:X}' -f $Handle.ToInt64())
            title  = $title
            bounds = [ordered]@{ left = $rect.Left; top = $rect.Top; right = $rect.Right; bottom = $rect.Bottom; width = [Math]::Max(0, $rect.Right - $rect.Left); height = [Math]::Max(0, $rect.Bottom - $rect.Top) }
        }
        return $false
    }
    [void][OxForms.W008KeyMutation.NativeMethods]::EnumWindows($callback, [System.IntPtr]::Zero)
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

function Invoke-ControlClick {
    param(
        [Parameter(Mandatory = $true)]$Window,
        [Parameter(Mandatory = $true)]$Fixture,
        [Parameter(Mandatory = $true)][string]$ControlName
    )
    # Map a fixture control's point rect (relative to the form client area) to a
    # screen click. MSForms client points map 1:1 to pixels at 100% DPI; the form
    # title bar/border offset is approximated by aligning the client top-left with
    # the window bounds top-left plus a small chrome inset. This is evidence-driving
    # infrastructure only: the worksheet rows, not the click pixel, carry the facts.
    $control = @($Fixture.form.controls | Where-Object { $_.name -eq $ControlName })[0]
    if ($null -eq $control) { throw "Fixture control not found for click targeting: $ControlName" }
    $chromeLeft = 4
    $chromeTop = 24
    $controlCx = [double]$control.leftPt + ([double]$control.widthPt / 2.0)
    $controlCy = [double]$control.topPt + ([double]$control.heightPt / 2.0)
    $cx = [int][Math]::Round([double]$Window.bounds.left + $chromeLeft + $controlCx)
    $cy = [int][Math]::Round([double]$Window.bounds.top + $chromeTop + $controlCy)
    $handle = ConvertFrom-W005HandleText -Handle ([string]$Window.handle)
    $foreground = Set-W005ForegroundWindow -Handle $handle -DelayMilliseconds $ActionDelayMilliseconds
    $input = Invoke-W005SendInputMouseClick -ScreenX $cx -ScreenY $cy -TargetHandle $handle -DownUpDelayMilliseconds 60 -AfterDelayMilliseconds $ActionDelayMilliseconds
    return [ordered]@{ label = ('click_' + $ControlName); control = $ControlName; screen_x = $cx; screen_y = $cy; foreground = $foreground; input = $input }
}

function New-KeyboardInput {
    param([Parameter(Mandatory = $true)][UInt16]$VirtualKey, [Parameter(Mandatory = $true)][UInt32]$Flags)
    $keyboard = New-Object OxForms.W008KeyMutation.NativeMethods+KEYBDINPUT
    $keyboard.wVk = $VirtualKey
    $keyboard.wScan = 0
    $keyboard.dwFlags = $Flags
    $keyboard.time = 0
    $keyboard.dwExtraInfo = [UIntPtr]::Zero
    $union = New-Object OxForms.W008KeyMutation.NativeMethods+INPUTUNION
    $union.ki = $keyboard
    $input = New-Object OxForms.W008KeyMutation.NativeMethods+INPUT
    $input.type = 1
    $input.u = $union
    return $input
}

function Invoke-SendInputKeys {
    param(
        [Parameter(Mandatory = $true)][UInt16[]]$VirtualKeys,
        [Parameter(Mandatory = $true)][System.IntPtr]$TargetHandle,
        [Parameter(Mandatory = $true)][string]$Label,
        [int]$AfterDelayMilliseconds = 180
    )
    # Emit a key-down then key-up INPUT for every VK in order through one SendInput
    # call, snapshot the public W005 input diagnostics before/after, and report the
    # requested/sent counts. status='completed' iff sent==requested; the CALLER MUST
    # throw when status != completed so a dead-keyboard desktop yields an honest
    # blocker.json rather than a silent 'no rows'.
    Ensure-WindowEnumTypes
    $before = Get-W005InputDiagnosticsSnapshot -TargetHandle $TargetHandle -Phase ('before_sendinput_keys_' + $Label)
    $inputs = [System.Collections.Generic.List[object]]::new()
    foreach ($vk in $VirtualKeys) {
        $inputs.Add((New-KeyboardInput -VirtualKey $vk -Flags 0)) | Out-Null
        $inputs.Add((New-KeyboardInput -VirtualKey $vk -Flags 0x0002)) | Out-Null
    }
    $inputArray = [OxForms.W008KeyMutation.NativeMethods+INPUT[]]$inputs.ToArray()
    $sent = [OxForms.W008KeyMutation.NativeMethods]::SendInput(
        [uint32]$inputArray.Length,
        $inputArray,
        [System.Runtime.InteropServices.Marshal]::SizeOf([type][OxForms.W008KeyMutation.NativeMethods+INPUT]))
    $lastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    if ($AfterDelayMilliseconds -gt 0) { Start-Sleep -Milliseconds $AfterDelayMilliseconds }
    $after = Get-W005InputDiagnosticsSnapshot -TargetHandle $TargetHandle -Phase ('after_sendinput_keys_' + $Label)
    return [ordered]@{
        schema = 'oxforms.office_oracle.w008_sendinput_keyboard_action.v1'
        input_driver = 'public_user32_sendinput_keyboard'
        label = $Label
        virtual_keys = @($VirtualKeys | ForEach-Object { '0x{0:X2}' -f $_ })
        requested = [int]$inputArray.Length
        sent = [int]$sent
        last_win32_error = [int]$lastError
        status = if ($sent -eq [uint32]$inputArray.Length) { 'completed' } else { 'blocked' }
        diagnostics = [ordered]@{ before = $before; after = $after }
    }
}

function Assert-KeyInjection {
    param([Parameter(Mandatory = $true)]$Result)
    if ([string]$Result.status -ne 'completed') {
        throw "SendInput keyboard injection '$($Result.label)' did not complete: requested=$($Result.requested) sent=$($Result.sent) last_win32_error=$($Result.last_win32_error). Refusing to infer behavior from a dead-keyboard desktop."
    }
}

function Export-WorksheetLog {
    param(
        [Parameter(Mandatory = $true)]$Workbook,
        [Parameter(Mandatory = $true)][string]$ResolvedOutDir,
        [Parameter(Mandatory = $true)][string]$IdPrefix,
        [Parameter(Mandatory = $true)][string]$Schema,
        [Parameter(Mandatory = $true)][object[]]$AutomatedInputs
    )
    $sheet = $Workbook.Worksheets.Item($worksheetName)
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
    $csvPath = Join-Path $ResolvedOutDir ($IdPrefix + 'event-log.csv')
    $rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

    $observedScenarios = @($rows | ForEach-Object { $_.scenario } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $eventNames = @($rows | ForEach-Object { $_.event_name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $scenarioSummaries = foreach ($scenario in $requiredScenarios) {
        $scenarioRows = @($rows | Where-Object { $_.scenario -eq $scenario })
        [ordered]@{
            scenario = $scenario
            row_count = $scenarioRows.Count
            observed = $scenarioRows.Count -gt 0
            event_names = @($scenarioRows | ForEach-Object { $_.event_name })
            rows = @($scenarioRows | ForEach-Object {
                [ordered]@{
                    sequence = $_.sequence
                    control_name = $_.control_name
                    event_name = $_.event_name
                    arg_name = $_.arg_name
                    arg_before = $_.arg_before
                    arg_after = $_.arg_after
                    focus_owner_after = $_.focus_owner_after
                    text_value_after = $_.text_value_after
                }
            })
        }
    }

    $eventLog = [ordered]@{
        schema = $Schema
        bead = $captureBead
        source = [ordered]@{
            worksheet = $worksheetName
            columns = $logColumns
            fixture = 'fixtures/office-oracle/excel-msforms/userforms/w008-focus-key-breadth/fixture.json'
        }
        observed_facts = [ordered]@{
            row_count = $rows.Count
            scenarios = $observedScenarios
            event_names = $eventNames
            scenario_summaries = @($scenarioSummaries)
            rows = $rows
        }
        manual_inputs = @()
        automated_inputs = @($AutomatedInputs)
        assumptions = @(
            'Rows are worksheet rows emitted by repo-owned VBA handlers while real Excel/MSForms dispatched injected keyboard input.',
            'arg_before is the ReturnInteger KeyCode/KeyAscii .Value read at handler entry; arg_after is that argument .Value after the (flag-gated) handler swallowed it (set to 0).',
            'focus_owner_after is Me.ActiveControl.Name (empty when ActiveControl Is Nothing); text_value_after is the relevant TextBox .Text at handler exit, so a swallowed key shows no Change-driven text mutation.'
        )
        unknowns = @(
            'Rows absent from this run remain unobserved and are not negative MSForms facts.',
            'This capture exercises default-button Enter, KeyDown swallow, KeyPress swallow, an arrow-key swallow, and Change timing; it does not exhaust every virtual key, IME composition, or auto-repeat path.'
        )
        clean_room = [ordered]@{
            source = 'Repo-owned fixture input generated through public Excel/VBIDE automation and driven through public Windows input APIs.'
            prohibited = 'No Office internals, decompilation, disassembly, non-public source, or OxForms output comparison.'
        }
        non_claims = @(
            'No OxForms runtime keyboard event behavior is implemented or claimed by this oracle.',
            'Absence of a row is not a negative parity fact.'
        )
    }
    $jsonPath = Join-Path $ResolvedOutDir ($IdPrefix + 'event-log.json')
    Write-JsonFile -Value $eventLog -Path $jsonPath
    return [ordered]@{
        csv = ConvertTo-RepoRelative $csvPath
        json = ConvertTo-RepoRelative $jsonPath
        row_count = $rows.Count
        scenarios = $observedScenarios
        event_names = $eventNames
        scenario_summaries = @($scenarioSummaries)
        rows = $rows
    }
}

function New-RunSummary {
    param(
        [Parameter(Mandatory = $true)][string]$CaptureId,
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][string]$Schema,
        $EventLog
    )
    $scenarioCoverage = [ordered]@{}
    foreach ($scenario in $requiredScenarios) {
        $summary = if ($null -ne $EventLog) { @($EventLog.scenario_summaries | Where-Object { $_.scenario -eq $scenario })[0] } else { $null }
        $scenarioCoverage[$scenario] = if ($null -ne $summary -and [int]$summary.row_count -gt 0) { 'observed_rows' } else { 'not_observed_in_this_run' }
    }
    return [ordered]@{
        schema = $Schema
        bead = $captureBead
        capture_id = $CaptureId
        status = $Status
        row_count = if ($null -ne $EventLog) { $EventLog.row_count } else { 0 }
        scenarios = if ($null -ne $EventLog) { $EventLog.scenarios } else { @() }
        scenario_coverage = $scenarioCoverage
        scenario_summaries = if ($null -ne $EventLog) { @($EventLog.scenario_summaries) } else { @() }
        non_claims = @(
            'Scenario coverage reports observed worksheet rows in this run only.',
            'No OxForms runtime keyboard behavior is implemented or claimed.',
            'not_observed_in_this_run is not a negative MSForms fact.'
        )
    }
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

# ---- schema ids ----
$manifestSchema = 'oxforms.office_oracle.w008_key_mutation_capture.v1'
$eventLogSchema = 'oxforms.office_oracle.w008_key_mutation_event_log.v1'
$inputActionsSchema = 'oxforms.office_oracle.w008_key_mutation_input_actions.v1'
$runSummarySchema = 'oxforms.office_oracle.w008_key_mutation_run_summary.v1'
$blockerSchema = 'oxforms.office_oracle.w008_key_mutation_blocker.v1'
$idPrefix = 'w008-key-mutation-'

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
$excel = $null; $workbook = $null; $eventLog = $null; $excelInfo = $null; $runSummaryPath = $null

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
    $handle = ConvertFrom-W005HandleText -Handle ([string]$window.handle)

    # Scenario 1: default_button_enter -- focus TextBox1, Enter (fires OkButton
    # Default), then re-focus TextBox1 and Esc.
    $excel.Run('SetW008ScenarioDefaultEnter')
    $inputActions.Add((Invoke-ControlClick -Window $window -Fixture $fixture -ControlName 'TextBox1')) | Out-Null
    $enterResult = Invoke-SendInputKeys -VirtualKeys @([UInt16]0x0D) -TargetHandle $handle -Label 'default_enter'
    Assert-KeyInjection -Result $enterResult
    $inputActions.Add([ordered]@{ scenario = 'default_button_enter'; label = 'enter'; key_action = $enterResult }) | Out-Null
    Start-Sleep -Milliseconds $ActionDelayMilliseconds
    $inputActions.Add((Invoke-ControlClick -Window $window -Fixture $fixture -ControlName 'TextBox1')) | Out-Null
    $escResult = Invoke-SendInputKeys -VirtualKeys @([UInt16]0x1B) -TargetHandle $handle -Label 'default_escape'
    Assert-KeyInjection -Result $escResult
    $inputActions.Add([ordered]@{ scenario = 'default_button_enter'; label = 'escape'; key_action = $escResult }) | Out-Null
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'scenario_default_button_enter_driven'
    Start-Sleep -Milliseconds $ActionDelayMilliseconds

    # Scenario 2: swallow_keydown -- KeyDown sets KeyCode=0 for 'A'.
    $excel.Run('SetW008ScenarioSwallowKeyDown')
    $inputActions.Add((Invoke-ControlClick -Window $window -Fixture $fixture -ControlName 'TextBox1')) | Out-Null
    $kdResult = Invoke-SendInputKeys -VirtualKeys @([UInt16]0x41) -TargetHandle $handle -Label 'swallow_keydown_A'
    Assert-KeyInjection -Result $kdResult
    $inputActions.Add([ordered]@{ scenario = 'swallow_keydown'; label = 'type_A'; key_action = $kdResult }) | Out-Null
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'scenario_swallow_keydown_driven'
    Start-Sleep -Milliseconds $ActionDelayMilliseconds

    # Scenario 3: swallow_keypress -- KeyPress sets KeyAscii=0 for 'A'.
    $excel.Run('SetW008ScenarioSwallowKeyPress')
    $inputActions.Add((Invoke-ControlClick -Window $window -Fixture $fixture -ControlName 'TextBox1')) | Out-Null
    $kpResult = Invoke-SendInputKeys -VirtualKeys @([UInt16]0x41) -TargetHandle $handle -Label 'swallow_keypress_A'
    Assert-KeyInjection -Result $kpResult
    $inputActions.Add([ordered]@{ scenario = 'swallow_keypress'; label = 'type_A'; key_action = $kpResult }) | Out-Null
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'scenario_swallow_keypress_driven'
    Start-Sleep -Milliseconds $ActionDelayMilliseconds

    # Scenario 4: arrow_swallow -- KeyDown sets KeyCode=0 for ArrowLeft (no KeyPress).
    $excel.Run('SetW008ScenarioArrowSwallow')
    $inputActions.Add((Invoke-ControlClick -Window $window -Fixture $fixture -ControlName 'TextBox1')) | Out-Null
    $arrowResult = Invoke-SendInputKeys -VirtualKeys @([UInt16]0x25) -TargetHandle $handle -Label 'arrow_swallow_left'
    Assert-KeyInjection -Result $arrowResult
    $inputActions.Add([ordered]@{ scenario = 'arrow_swallow'; label = 'arrow_left'; key_action = $arrowResult }) | Out-Null
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'scenario_arrow_swallow_driven'
    Start-Sleep -Milliseconds $ActionDelayMilliseconds

    # Scenario 5: change_timing -- 'A' with no swallow flags so Change fires and
    # text_value_after shows the committed character.
    $excel.Run('SetW008ScenarioChangeTiming')
    $inputActions.Add((Invoke-ControlClick -Window $window -Fixture $fixture -ControlName 'TextBox1')) | Out-Null
    $changeResult = Invoke-SendInputKeys -VirtualKeys @([UInt16]0x41) -TargetHandle $handle -Label 'change_timing_A'
    Assert-KeyInjection -Result $changeResult
    $inputActions.Add([ordered]@{ scenario = 'change_timing'; label = 'type_A'; key_action = $changeResult }) | Out-Null
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'scenario_change_timing_driven'
    Start-Sleep -Milliseconds 600

    Write-JsonFile -Path (Join-Path $resolvedOutDir 'input-actions.json') -Value ([ordered]@{
        schema = $inputActionsSchema
        bead = $captureBead
        manual_inputs = @()
        automated_inputs = @($inputActions)
        notes = @(
            'Per-scenario Set... macro calls precede each scenario''s injected input so one W008BreadthLog covers every keyboard scenario.',
            'Control clicks are public user32 SendInput mouse clicks at window-bounds + fixture-layout points; all keys are public user32 SendInput keyboard events.',
            'Every key injection asserted sent==requested before the run continued; a non-completed injection throws and yields a blocker.'
        )
    })

    $eventLog = Export-WorksheetLog -Workbook $workbook -ResolvedOutDir $resolvedOutDir -IdPrefix $idPrefix -Schema $eventLogSchema -AutomatedInputs @($inputActions)
    $runSummaryPath = Join-Path $resolvedOutDir 'run-summary.json'
    Write-JsonFile -Path $runSummaryPath -Value (New-RunSummary -CaptureId $captureId -Status 'captured' -Schema $runSummarySchema -EventLog $eventLog)
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('event_log_exported_rows=' + $eventLog.row_count)

    $workbook.Save(); $workbook.Close($true); Release-ComObjectIfPresent $workbook; $workbook = $null
    $excel.Quit(); Release-ComObjectIfPresent $excel; $excel = $null
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'excel_closed_before_manifest'

    $manifest = [ordered]@{
        schema = $manifestSchema
        bead = $captureBead
        capture_id = $captureId
        status = 'captured'
        fixture = [ordered]@{ id = $fixture.id; inputs = $fixtureHashes }
        platform = [ordered]@{ os = [System.Environment]::OSVersion.VersionString; is_windows = $true; powershell = $PSVersionTable.PSVersion.ToString() }
        excel = $excelInfo
        artifacts = [ordered]@{
            generated_workbook = if (Test-Path -LiteralPath $workbookPath -PathType Leaf) { [ordered]@{ path = ConvertTo-RepoRelative $workbookPath; sha256 = Get-Sha256Hex -Path $workbookPath } } else { $null }
            run_summary = ConvertTo-RepoRelative $runSummaryPath
            event_log_json = $eventLog.json
            event_log_csv = $eventLog.csv
            input_actions = ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'input-actions.json')
        }
        observed_coverage = [ordered]@{ row_count = $eventLog.row_count; scenarios = $eventLog.scenarios }
        trace_replay_implications = @(
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 5: key fold-back needs ordered KeyDown/KeyPress/KeyUp rows carrying the ReturnInteger before/after value.',
            'docs/specs/FM20_EVENT_FACTS.md: KeyCode/KeyAscii=0 swallow, default-button Enter, and Change-after-keystroke timing are settled by this oracle for the W008 surface.'
        )
        warnings = @('Black-box Excel/MSForms evidence only; no OxForms output was compared.', 'Covers default Enter, KeyDown/KeyPress/arrow swallow, and Change timing; not an exhaustive keyboard matrix.')
        clean_room = [ordered]@{ source = 'Repo-owned fixture input generated through public Excel/VBIDE automation and driven through public Windows input APIs.'; prohibited = 'No Office internals, decompilation, disassembly, non-public source, or OxForms output comparison.' }
        non_claims = @('No OxForms runtime keyboard event behavior is implemented or claimed.', 'This capture is not an exhaustive keyboard event parity matrix.', 'Absence of a row is not a negative parity fact.')
    }
    Write-JsonFile -Path (Join-Path $resolvedOutDir 'oracle-capture-manifest.json') -Value $manifest
    $readme = @(
        '# W008 Key-Mutation Oracle Capture', '',
        "Capture id: $captureId", ('Bead: `' + $captureBead + '`'), 'Status: `captured`', '',
        'Black-box Excel/MSForms evidence for UserForm keyboard fold-back (KeyCode/KeyAscii swallow), default-button Enter, and Change timing. Not an OxForms output comparison and not an exhaustive parity claim.', '',
        '## Facts', '',
        "- Observed scenarios: ``$((@($eventLog.scenarios) -join ', '))``; total rows: ``$($eventLog.row_count)``.",
        ('- `' + $idPrefix + 'event-log.json`/`.csv` are W008BreadthLog rows from repo-owned VBA handlers while live Excel handled injected keyboard input.'), '',
        '## Clean-room Note', '',
        'Repo-owned fixture sources, public Excel/VBIDE automation, public Windows input, and worksheet export only. No Office internals, decompilation, disassembly, or OxForms output comparison.'
    )
    Set-Content -LiteralPath (Join-Path $resolvedOutDir 'README.md') -Value $readme -Encoding UTF8
    Write-Checksums -ResolvedOutDir $resolvedOutDir
    Write-Host "W008 Key-Mutation capture complete: $resolvedOutDir"
    Write-Host "Rows: $($eventLog.row_count); scenarios: $((@($eventLog.scenarios) -join ', '))"
} catch {
    $progressPath = Join-Path $resolvedOutDir 'capture-progress.log'
    $lastEntry = if (Test-Path -LiteralPath $progressPath -PathType Leaf) { @(Get-Content -LiteralPath $progressPath)[-1] } else { '<no progress entry>' }
    $blocker = [ordered]@{
        schema = $blockerSchema
        bead = $captureBead; capture_id = $captureId; status = 'blocked'
        reason = $_.Exception.Message
        facts = @('Repo-owned fixture loaded before the live capture path.', ('Last capture-progress entry: ' + $lastEntry))
        non_claims = @('No OxForms runtime behavior is implemented or claimed.', 'No missing row is treated as a negative MSForms fact.')
        clean_room = [ordered]@{ source = 'Repo-owned fixture input + public Excel/VBIDE/Windows automation.'; prohibited = 'No Office internals, decompilation, disassembly, non-public source, or OxForms output comparison.' }
    }
    Write-JsonFile -Path (Join-Path $resolvedOutDir 'blocker.json') -Value $blocker
    $runSummaryPath = Join-Path $resolvedOutDir 'run-summary.json'
    Write-JsonFile -Path $runSummaryPath -Value (New-RunSummary -CaptureId $captureId -Status 'blocked' -Schema $runSummarySchema -EventLog $null)
    Write-Checksums -ResolvedOutDir $resolvedOutDir
    Write-Host "W008 Key-Mutation capture blocked: $resolvedOutDir"
    Write-Host "Blocker: $($_.Exception.Message)"
} finally {
    if ($null -ne $workbook) { try { $workbook.Close($true) } catch { Write-Warning "Failed to close workbook: $($_.Exception.Message)" } }
    if ($null -ne $excel) { try { $excel.Quit() } catch { Write-Warning "Failed to quit Excel: $($_.Exception.Message)" } }
    Release-ComObjectIfPresent $workbook
    Release-ComObjectIfPresent $excel
}
