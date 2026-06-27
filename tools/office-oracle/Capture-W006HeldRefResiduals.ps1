[CmdletBinding()]
param(
    [string]$FixtureDir = 'fixtures\office-oracle\excel-msforms\userforms\w006-held-ref-residuals',
    [string]$OutDir,
    [switch]$Force,
    [switch]$DryRun,
    [switch]$GenerateOnly,
    [int]$ActionDelayMilliseconds = 240
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$captureRoot = Join-Path $repoRoot 'docs\evidence\W006_control_implementation_rollout\captures'
$captureBead = 'oxforms-0a0.25'
$launcherTitle = 'OxForms W006 HeldRef Launcher'
$heldTitle = 'OxForms W006 HeldRef Form'
$requiredScenarios = @(
    'modeless_system_close',
    'modal_hide_return',
    'modal_unload_return'
)

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
        $Directory = Join-Path $captureRoot ('held-ref-residuals-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))
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
    if ($fullPath.Equals($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) { return '.' }
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
    # FileShare.ReadWrite so the workbook can be hashed even while the live Excel
    # instance still has it open (manifest hashing runs before Excel is released).
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
    $lines = @('.gitattributes text eol=crlf diff', '*.json text eol=crlf diff', '*.csv text eol=crlf diff', '*.md text eol=crlf diff', '*.txt text eol=crlf diff', '*.log text eol=crlf diff', 'checksums.sha256 text eol=crlf diff', '*.xlsm -text -diff', '*-window/*.png -text -diff')
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

function Set-ControlPropertyIfPresent {
    param([Parameter(Mandatory = $true)]$ControlObject, [Parameter(Mandatory = $true)]$Spec, [Parameter(Mandatory = $true)][string]$ManifestName, [Parameter(Mandatory = $true)][scriptblock]$Apply)
    $value = Get-OptionalValue $Spec $ManifestName
    if ($null -eq $value) { return }
    & $Apply $ControlObject $value
}

function Add-UserFormComponent {
    param([Parameter(Mandatory = $true)]$VbProject, [Parameter(Mandatory = $true)]$FormSpec, [Parameter(Mandatory = $true)][string]$FixtureRoot)
    $component = $VbProject.VBComponents.Add(3)
    $component.Name = [string](Get-RequiredValue $FormSpec 'name')
    $designer = $component.Designer
    Set-ComponentPropertyValue $component 'Caption' ([string](Get-RequiredValue $FormSpec 'caption'))
    Set-ComponentPropertyValue $component 'Width' ([single](Get-RequiredValue $FormSpec 'widthPt'))
    Set-ComponentPropertyValue $component 'Height' ([single](Get-RequiredValue $FormSpec 'heightPt'))
    Set-ComponentPropertyValue $component 'StartUpPosition' ([single](Get-RequiredValue $FormSpec 'startupPosition'))

    foreach ($control in @($FormSpec.controls)) {
        $created = $designer.Controls.Add([string](Get-RequiredValue $control 'type'), [string](Get-RequiredValue $control 'name'), $true)
        $created.Left = [single](Get-RequiredValue $control 'leftPt')
        $created.Top = [single](Get-RequiredValue $control 'topPt')
        $created.Width = [single](Get-RequiredValue $control 'widthPt')
        $created.Height = [single](Get-RequiredValue $control 'heightPt')
        Set-ControlPropertyIfPresent $created $control 'caption' { param($c, $v) $c.Caption = [string]$v }
        # Other design-time control properties (colors, border/back style, tab order,
        # TakeFocusOnClick) are intentionally NOT set here: design-time property writes
        # through the VBIDE designer can block the headless SaveAs (the same class of
        # hang as design-time fonts), and none are load-bearing for this oracle (it
        # keys on event rows + held-reference state, and clicks buttons by geometry,
        # not tab order). The fixture may still declare them for documentation.
    }

    $codePath = Resolve-FixtureSourcePath -FixtureRoot $FixtureRoot -Path ([string](Get-RequiredValue $FormSpec 'codeBehindSourcePath'))
    $component.CodeModule.AddFromString((Get-Content -Raw -LiteralPath $codePath))
    return $component
}

function New-WorkbookFromFixture {
    param([Parameter(Mandatory = $true)]$Fixture, [Parameter(Mandatory = $true)][string]$FixtureRoot, [Parameter(Mandatory = $true)][string]$WorkbookPath)
    if (Test-Path -LiteralPath $WorkbookPath -PathType Leaf) {
        if (-not $Force) { throw "Output workbook already exists. Pass -Force to replace it: $WorkbookPath" }
        Remove-Item -LiteralPath $WorkbookPath -Force
    }
    $excel = $null; $workbook = $null; $vbProject = $null; $standardModule = $null
    $components = [System.Collections.Generic.List[object]]::new()
    try {
        try { $excel = New-Object -ComObject Excel.Application } catch { throw "Microsoft Excel COM automation is unavailable: $($_.Exception.Message)" }
        $excel.Visible = $false; $excel.DisplayAlerts = $false
        $workbook = $excel.Workbooks.Add()
        try { $vbProject = $workbook.VBProject } catch { throw "Excel blocked access to the VBA project object model. Enable 'Trust access to the VBA project object model'." }

        foreach ($formSpec in @($Fixture.forms)) {
            $components.Add((Add-UserFormComponent -VbProject $vbProject -FormSpec $formSpec -FixtureRoot $FixtureRoot)) | Out-Null
        }

        $standardModule = $vbProject.VBComponents.Add(1)
        $standardModule.Name = [string](Get-RequiredValue $Fixture.workbook 'vbaModuleName')
        $stdPath = Resolve-FixtureSourcePath -FixtureRoot $FixtureRoot -Path ([string](Get-RequiredValue $Fixture.workbook 'standardModuleSourcePath'))
        $standardModule.CodeModule.AddFromString((Get-Content -Raw -LiteralPath $stdPath))

        $workbook.SaveAs($WorkbookPath, 52)
    } finally {
        if ($null -ne $workbook) { try { $workbook.Close($true) } catch { Write-Warning "Failed to close generated workbook: $($_.Exception.Message)" } }
        if ($null -ne $excel) { try { $excel.Quit() } catch { Write-Warning "Failed to quit Excel after generation: $($_.Exception.Message)" } }
        foreach ($component in $components) { Release-ComObjectIfPresent $component }
        Release-ComObjectIfPresent $standardModule
        Release-ComObjectIfPresent $vbProject
        Release-ComObjectIfPresent $workbook
        Release-ComObjectIfPresent $excel
    }
}

function Ensure-WindowEnumTypes {
    if (([System.Management.Automation.PSTypeName]'OxForms.W006HeldRef.NativeMethods').Type) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
namespace OxForms.W006HeldRef
{
    public static class NativeMethods
    {
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
        [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
        [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
        [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern int GetWindowTextLengthW(IntPtr hWnd);
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern int GetWindowTextW(IntPtr hWnd, StringBuilder text, int maxCount);
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern int GetClassNameW(IntPtr hWnd, StringBuilder className, int maxCount);
        [DllImport("user32.dll", SetLastError = true)] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
        [DllImport("user32.dll", SetLastError = true)] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    }
}
'@
}

function Get-WindowTextValue {
    param([System.IntPtr]$Handle)
    $length = [OxForms.W006HeldRef.NativeMethods]::GetWindowTextLengthW($Handle)
    $builder = [System.Text.StringBuilder]::new([Math]::Max($length + 1, 256))
    [void][OxForms.W006HeldRef.NativeMethods]::GetWindowTextW($Handle, $builder, $builder.Capacity)
    return $builder.ToString()
}

function Get-ClassNameValue {
    param([System.IntPtr]$Handle)
    $builder = [System.Text.StringBuilder]::new(256)
    [void][OxForms.W006HeldRef.NativeMethods]::GetClassNameW($Handle, $builder, $builder.Capacity)
    return $builder.ToString()
}

function Get-TopLevelWindows {
    Ensure-WindowEnumTypes
    # Initialize the accumulator before the callback assigns into it (StrictMode).
    $windows = [System.Collections.Generic.List[object]]::new()
    $callback = [OxForms.W006HeldRef.NativeMethods+EnumWindowsProc]{
        param([System.IntPtr]$Handle, [System.IntPtr]$Param)
        if (-not [OxForms.W006HeldRef.NativeMethods]::IsWindowVisible($Handle)) { return $true }
        $title = Get-WindowTextValue -Handle $Handle
        if ([string]::IsNullOrWhiteSpace($title)) { return $true }
        $class = Get-ClassNameValue -Handle $Handle
        $processIdValue = [uint32]0
        [void][OxForms.W006HeldRef.NativeMethods]::GetWindowThreadProcessId($Handle, [ref]$processIdValue)
        $processName = $null
        try { $processName = (Get-Process -Id ([int]$processIdValue) -ErrorAction Stop).ProcessName } catch { $processName = $null }
        $rect = New-Object OxForms.W006HeldRef.NativeMethods+RECT
        [void][OxForms.W006HeldRef.NativeMethods]::GetWindowRect($Handle, [ref]$rect)
        $windows.Add([ordered]@{
            handle = ('0x{0:X}' -f $Handle.ToInt64())
            title = $title
            class_name = $class
            process_id = [int]$processIdValue
            process_name = $processName
            bounds = [ordered]@{ left = $rect.Left; top = $rect.Top; right = $rect.Right; bottom = $rect.Bottom; width = [Math]::Max(0, $rect.Right - $rect.Left); height = [Math]::Max(0, $rect.Bottom - $rect.Top) }
        }) | Out-Null
        return $true
    }
    [void][OxForms.W006HeldRef.NativeMethods]::EnumWindows($callback, [System.IntPtr]::Zero)
    return @($windows)
}

function Wait-ForOracleWindow {
    param([Parameter(Mandatory = $true)][string]$Title, [int]$TimeoutSeconds = 25)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $matches = @(Get-TopLevelWindows | Where-Object {
            $_.title.IndexOf($Title, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -and
            $_.class_name -eq 'ThunderDFrame' -and $_.process_name -eq 'EXCEL'
        })
        if ($matches.Count -gt 0) { return $matches[0] }
        Start-Sleep -Milliseconds 100
    } while ((Get-Date) -lt $deadline)
    throw "Timed out waiting for UserForm window title containing '$Title'."
}

function Wait-ForOracleWindowClosed {
    param([Parameter(Mandatory = $true)][string]$Title, [int]$TimeoutSeconds = 12)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $matches = @(Get-TopLevelWindows | Where-Object {
            $_.title.IndexOf($Title, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -and
            $_.class_name -eq 'ThunderDFrame' -and $_.process_name -eq 'EXCEL'
        })
        if ($matches.Count -eq 0) { return $true }
        Start-Sleep -Milliseconds 100
    } while ((Get-Date) -lt $deadline)
    return $false
}

function Get-FormSpec {
    param([Parameter(Mandatory = $true)]$Fixture, [Parameter(Mandatory = $true)][string]$Identity)
    $matches = @($Fixture.forms | Where-Object { $_.identity -eq $Identity })
    if ($matches.Count -ne 1) { throw "Expected exactly one fixture form with identity '$Identity'." }
    return $matches[0]
}

function Get-ControlSpec {
    param([Parameter(Mandatory = $true)]$FormSpec, [Parameter(Mandatory = $true)][string]$Name)
    $matches = @($FormSpec.controls | Where-Object { $_.name -eq $Name })
    if ($matches.Count -ne 1) { throw "Expected exactly one control named '$Name' on form '$($FormSpec.name)'." }
    return $matches[0]
}

function Add-InputAction {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Actions,
        [Parameter(Mandatory = $true)][string]$Scenario,
        [Parameter(Mandatory = $true)][string]$Method,
        [Parameter(Mandatory = $true)][string]$Action,
        [Parameter(Mandatory = $true)][string]$TargetIntent,
        [object]$Window,
        [object]$ScreenPoint,
        [object]$Result,
        [string]$Notes = ''
    )
    $Actions.Add([ordered]@{
        sequence = $Actions.Count + 1
        scenario = $Scenario
        method = $Method
        input_driver = if ($Method -eq 'automated_sendinput_mouse') { 'public_user32_sendinput' } elseif ($Method -eq 'automated_sendkeys') { 'system_windows_forms_sendkeys' } else { $Method }
        manual = $false
        action = $Action
        target_intent = $TargetIntent
        window = if ($null -ne $Window) { [ordered]@{ title = $Window.title; handle = $Window.handle; bounds = $Window.bounds } } else { $null }
        screen_pixels = $ScreenPoint
        result = $Result
        notes = $Notes
    }) | Out-Null
}

function Invoke-ClickControl {
    param(
        [Parameter(Mandatory = $true)]$Window,
        [Parameter(Mandatory = $true)]$FormSpec,
        [Parameter(Mandatory = $true)][string]$ControlName,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Actions,
        [Parameter(Mandatory = $true)][string]$Scenario,
        [Parameter(Mandatory = $true)][string]$TargetIntent
    )
    # Point geometry: the control centre in form points, converted to screen
    # pixels via the window bounds. The non-client title-bar offset is small
    # relative to the button targets, and the buttons are sized generously; this
    # is evidence-driving infrastructure, not a pixel-parity claim.
    $control = Get-ControlSpec -FormSpec $FormSpec -Name $ControlName
    $dpi = 96.0
    $scale = $dpi / 72.0
    $clientLeftOffsetPx = 4
    $titleBarPx = 30
    $cx = [int][Math]::Round([double]$Window.bounds.left + $clientLeftOffsetPx + (([double]$control.leftPt + ([double]$control.widthPt / 2.0)) * $scale))
    $cy = [int][Math]::Round([double]$Window.bounds.top + $titleBarPx + (([double]$control.topPt + ([double]$control.heightPt / 2.0)) * $scale))
    $handle = ConvertFrom-W005HandleText -Handle ([string]$Window.handle)
    $foreground = Set-W005ForegroundWindow -Handle $handle -DelayMilliseconds $ActionDelayMilliseconds
    $input = Invoke-W005SendInputMouseClick -ScreenX $cx -ScreenY $cy -TargetHandle $handle -DownUpDelayMilliseconds 70 -AfterDelayMilliseconds $ActionDelayMilliseconds
    Add-InputAction -Actions $Actions -Scenario $Scenario -Method 'automated_sendinput_mouse' -Action 'click' -TargetIntent $TargetIntent -Window $Window -ScreenPoint ([ordered]@{ x = $cx; y = $cy }) -Result ([ordered]@{ foreground = $foreground; input = $input }) -Notes ('Public user32 SendInput mouse click targeting control ' + $ControlName + ' by form point geometry.')
}

function Invoke-AltF4 {
    param(
        [Parameter(Mandatory = $true)]$Window,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Actions,
        [Parameter(Mandatory = $true)][string]$Scenario,
        [Parameter(Mandatory = $true)][string]$TargetIntent
    )
    # Public system close. SendKeys Alt+F4 closed UserForms cleanly without
    # destabilizing Excel COM in oxforms-0a0.24; PostMessage(WM_CLOSE) is NEVER
    # used here because it kills Excel COM (RPC 0x800706BA).
    Add-Type -AssemblyName System.Windows.Forms
    $handle = ConvertFrom-W005HandleText -Handle ([string]$Window.handle)
    $foreground = Set-W005ForegroundWindow -Handle $handle -DelayMilliseconds $ActionDelayMilliseconds
    $before = Get-W005InputDiagnosticsSnapshot -TargetHandle $handle -Phase 'before_sendkeys_alt_f4'
    [System.Windows.Forms.SendKeys]::SendWait('%{F4}')
    Start-Sleep -Milliseconds ($ActionDelayMilliseconds * 2)
    $after = Get-W005InputDiagnosticsSnapshot -TargetHandle $handle -Phase 'after_sendkeys_alt_f4'
    Add-InputAction -Actions $Actions -Scenario $Scenario -Method 'automated_sendkeys' -Action 'alt_f4' -TargetIntent $TargetIntent -Window $Window -ScreenPoint $null -Result ([ordered]@{ foreground = $foreground; before = $before; after = $after }) -Notes 'Alt+F4 sent with System.Windows.Forms.SendKeys to drive the public system close path.'
}

function Export-WorksheetLog {
    param([Parameter(Mandatory = $true)]$Workbook, [Parameter(Mandatory = $true)][string]$ResolvedOutDir, [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$AutomatedInputs, [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Blockers)
    $sheet = $Workbook.Worksheets.Item('W006HeldRefResidualsLog')
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
    $csvPath = Join-Path $ResolvedOutDir 'held-ref-residuals-event-log.csv'
    $rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

    $eventNames = @($rows | ForEach-Object { $_.event_name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $scenarios = @($rows | ForEach-Object { $_.scenario } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $terminateRows = @($rows | Where-Object { $_.event_name -eq 'Terminate' })

    $scenarioSummaries = foreach ($scenario in $requiredScenarios) {
        $scenarioRows = @($rows | Where-Object { $_.scenario -eq $scenario })
        $scenarioTerminateRows = @($scenarioRows | Where-Object { $_.event_name -eq 'Terminate' })
        [ordered]@{
            scenario = $scenario
            row_count = $scenarioRows.Count
            observed = $scenarioRows.Count -gt 0
            terminate_sequences = @($scenarioTerminateRows | ForEach-Object { $_.sequence })
            terminate_reference_states = @($scenarioTerminateRows | ForEach-Object {
                [ordered]@{ sequence = $_.sequence; instance_id = $_.instance_id; local_ref_state = $_.local_ref_state; held_ref_state = $_.held_ref_state; default_instance_state = $_.default_instance_state; release_phase = $_.release_phase }
            })
            held_ref_release_rows = @($scenarioRows | Where-Object { $_.action -eq 'release_held_ref' -or $_.action -eq 'release_held_ref_return' } | ForEach-Object {
                [ordered]@{ sequence = $_.sequence; event_name = $_.event_name; action = $_.action; local_ref_state = $_.local_ref_state; held_ref_state = $_.held_ref_state; release_phase = $_.release_phase }
            })
        }
    }

    $eventLog = [ordered]@{
        schema = 'oxforms.office_oracle.w006_held_ref_residuals_event_log.v1'
        bead = $captureBead
        source = [ordered]@{
            worksheet = 'W006HeldRefResidualsLog'
            fixture = 'fixtures/office-oracle/excel-msforms/userforms/w006-held-ref-residuals/fixture.json'
            trace_schema = [ordered]@{
                ordering = 'docs/specs/TRACE_REPLAY_SCHEMA.md#5-Ordering-Model'
                effects = 'docs/specs/TRACE_REPLAY_SCHEMA.md#9-Reducer-And-Effects'
                lifecycle_pump = 'docs/specs/TRACE_REPLAY_SCHEMA.md#11-Lifecycle-And-Pump-Rows'
                validator = 'docs/specs/TRACE_REPLAY_SCHEMA.md#14-Validator-And-Sample'
            }
        }
        public_facts = @(
            'docs/specs/FM20_EVENT_FACTS.md records Initialize, Activate, Deactivate, QueryClose, and Terminate as public-doc lifecycle event names for the W005/W006 surface.',
            'docs/specs/LIFECYCLE_PUMP_MODEL.md section 9 says Hide does not prove termination and Unload does not imply Terminated.'
        )
        observed_facts = [ordered]@{
            row_count = $rows.Count
            event_names = $eventNames
            scenarios = $scenarios
            scenario_summaries = @($scenarioSummaries)
            terminate_rows = @($terminateRows)
            rows = @($rows)
        }
        assumptions = @(
            'Rows under observed_facts are worksheet rows emitted by repo-owned VBA while real Excel/MSForms handled the launcher/held forms and public input.',
            'The local_ref_state, held_ref_state, default_instance_state, and release_phase columns are explicit fixture state, not private Office reference counts.',
            'Modal scenarios were entered only from a launcher button _Click handler driven by injected input; the script never called excel.Run Show vbModal.',
            'The modeless system-close scenario used public SendKeys Alt+F4 against the visible held UserForm window, never PostMessage(WM_CLOSE).'
        )
        unknowns = @(
            'Default-instance release timing remains unknown; this fixture has no public reproducible default-instance release operation.',
            'Rows absent from this run remain unobserved and are not negative MSForms facts.'
        )
        blockers = @($Blockers)
        manual_inputs = @()
        automated_inputs = @($AutomatedInputs)
        non_claims = @(
            'This event log is not an exhaustive MSForms lifecycle parity claim.',
            'This event log is not an OxForms output comparison artifact.',
            'No OxForms runtime held-reference, Hide/Unload, or Terminate behavior is implemented or claimed by this artifact.',
            'Close ordering is already captured in oxforms-0a0.24 (nested-modal-lifecycle); only the held-reference state dimension is in scope here.'
        )
    }
    $jsonPath = Join-Path $ResolvedOutDir 'held-ref-residuals-event-log.json'
    Write-JsonFile -Value $eventLog -Path $jsonPath
    return [ordered]@{
        csv = ConvertTo-RepoRelative $csvPath
        json = ConvertTo-RepoRelative $jsonPath
        row_count = $rows.Count
        event_names = $eventNames
        scenarios = $scenarios
        scenario_summaries = @($scenarioSummaries)
        terminate_rows = @($terminateRows)
        rows = @($rows)
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

function Get-ExistingRepoRelativeFiles {
    param([string[]]$Paths)
    $existing = [System.Collections.Generic.List[string]]::new()
    foreach ($path in $Paths) {
        if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path -PathType Leaf)) { $existing.Add((ConvertTo-RepoRelative $path)) | Out-Null }
    }
    return @($existing)
}

function Get-FixtureHashes {
    param([Parameter(Mandatory = $true)]$Fixture, [Parameter(Mandatory = $true)][string]$FixtureRoot, [Parameter(Mandatory = $true)][string]$FixturePath)
    $formSources = @()
    foreach ($form in @($Fixture.forms)) {
        $path = Resolve-FixtureSourcePath -FixtureRoot $FixtureRoot -Path ([string](Get-RequiredValue $form 'codeBehindSourcePath'))
        $formSources += [ordered]@{ form_identity = $form.identity; path = ConvertTo-RepoRelative $path; sha256 = Get-Sha256Hex -Path $path }
    }
    $modulePath = Resolve-FixtureSourcePath -FixtureRoot $FixtureRoot -Path ([string](Get-RequiredValue $Fixture.workbook 'standardModuleSourcePath'))
    return [ordered]@{
        manifest = [ordered]@{ path = ConvertTo-RepoRelative $FixturePath; sha256 = Get-Sha256Hex -Path $FixturePath }
        form_code_behind = $formSources
        standard_module = [ordered]@{ path = ConvertTo-RepoRelative $modulePath; sha256 = Get-Sha256Hex -Path $modulePath }
        capture_tool = [ordered]@{ path = ConvertTo-RepoRelative $PSCommandPath; sha256 = Get-Sha256Hex -Path $PSCommandPath }
    }
}

function Get-ScenarioCoverage {
    param($EventLog, [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Blockers)
    $coverage = [ordered]@{}
    foreach ($scenario in $requiredScenarios) {
        $summary = if ($null -ne $EventLog) { @($EventLog.scenario_summaries | Where-Object { $_.scenario -eq $scenario })[0] } else { $null }
        $blocked = @($Blockers | Where-Object { $_.surface -eq $scenario })
        if ($null -ne $summary -and [int]$summary.row_count -gt 0) {
            $coverage[$scenario] = 'observed_rows'
        } elseif ($blocked.Count -gt 0) {
            $coverage[$scenario] = 'blocked_in_this_run'
        } else {
            $coverage[$scenario] = 'not_observed_in_this_run'
        }
    }
    return $coverage
}

function New-RunSummary {
    param([Parameter(Mandatory = $true)][string]$CaptureId, [Parameter(Mandatory = $true)][string]$Status, $EventLog, [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Blockers)
    return [ordered]@{
        schema = 'oxforms.office_oracle.w006_held_ref_residuals_run_summary.v1'
        bead = $captureBead
        capture_id = $CaptureId
        status = $Status
        row_count = if ($null -ne $EventLog) { $EventLog.row_count } else { 0 }
        event_names = if ($null -ne $EventLog) { $EventLog.event_names } else { @() }
        scenario_coverage = Get-ScenarioCoverage -EventLog $EventLog -Blockers @($Blockers)
        terminate_row_count = if ($null -ne $EventLog) { @($EventLog.terminate_rows).Count } else { 0 }
        scenario_summaries = if ($null -ne $EventLog) { @($EventLog.scenario_summaries) } else { @() }
        blockers = @($Blockers)
        trace_replay_implications = @(
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 5: future object-lifetime rows need ordered sequence, parent_row_id when causal nesting exists, and nesting_depth.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 9: hide_form, unload_form, fire_vba_event, and platform close work must keep effect_requested separate from effect_completed.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 11: lifecycle_pump rows must keep Show, close, hide, unload, and terminate as separate trace concepts.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 14: validators must continue checking reducer/effect/dispatch causal ordering.'
        )
        non_claims = @(
            'Observed Terminate rows are tied to this fixture held-reference-state sequence only.',
            'No OxForms runtime held-reference or Terminate behavior is implemented or claimed.',
            'Close ordering is already captured in oxforms-0a0.24 (nested-modal-lifecycle); only the held-reference state dimension is in scope here.',
            'Unloaded and Terminated remain separate concepts; this summary does not collapse them.'
        )
    }
}

function New-Manifest {
    param(
        [Parameter(Mandatory = $true)][string]$Status, [Parameter(Mandatory = $true)][string]$ResolvedOutDir, [Parameter(Mandatory = $true)][string]$CaptureId,
        [Parameter(Mandatory = $true)]$Fixture, [Parameter(Mandatory = $true)]$FixtureHashes, [Parameter(Mandatory = $true)][string]$WorkbookPath,
        $ExcelInfo, $EventLog, [string]$RunSummaryPath, [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Blockers
    )
    $commandLogCandidates = @(
        (Join-Path $ResolvedOutDir 'capture.command.txt'),
        (Join-Path $ResolvedOutDir 'capture-progress.log')
    )
    return [ordered]@{
        schema = 'oxforms.office_oracle.w006_held_ref_residuals_capture.v1'
        bead = $captureBead
        capture_id = $CaptureId
        status = $Status
        fixture = [ordered]@{ id = $Fixture.id; inputs = $FixtureHashes }
        commands = [ordered]@{
            capture = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'capture.command.txt')
            progress = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'capture-progress.log')
            rerun_note = 'Run tools/office-oracle/Capture-W006HeldRefResiduals.ps1 from the repository root. It generates the workbook, shows the launcher modeless, drives the three held-reference residual scenarios (modal scenarios entered only via an injected click on a launcher button; the modeless system close via public SendKeys Alt+F4), exports W006HeldRefResidualsLog, and writes manifests + run-summary + checksums. A partial result still ships a clean run-summary with per-scenario blockers.'
        }
        platform = [ordered]@{ os = [System.Environment]::OSVersion.VersionString; is_windows = $true; powershell = $PSVersionTable.PSVersion.ToString() }
        excel = $ExcelInfo
        artifacts = [ordered]@{
            generated_workbook = if (Test-Path -LiteralPath $WorkbookPath -PathType Leaf) { [ordered]@{ path = ConvertTo-RepoRelative $WorkbookPath; sha256 = Get-Sha256Hex -Path $WorkbookPath } } else { $null }
            run_summary = if ($RunSummaryPath) { ConvertTo-RepoRelative $RunSummaryPath } else { $null }
            event_log_json = if ($null -ne $EventLog) { $EventLog.json } else { $null }
            event_log_csv = if ($null -ne $EventLog) { $EventLog.csv } else { $null }
            input_actions = if (Test-Path -LiteralPath (Join-Path $ResolvedOutDir 'input-actions.json') -PathType Leaf) { ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'input-actions.json') } else { $null }
            blocker = if (Test-Path -LiteralPath (Join-Path $ResolvedOutDir 'blocker.json') -PathType Leaf) { ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'blocker.json') } else { $null }
            checksums = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'checksums.sha256')
            command_logs = Get-ExistingRepoRelativeFiles -Paths $commandLogCandidates
        }
        observed_coverage = if ($null -ne $EventLog) {
            [ordered]@{
                row_count = $EventLog.row_count
                event_names = $EventLog.event_names
                scenarios = $EventLog.scenarios
                scenario_summaries = @($EventLog.scenario_summaries)
                terminate_row_count = @($EventLog.terminate_rows).Count
                manual_inputs = @()
                input_method = 'Launcher shown via excel.Run; modal scenarios entered by injected click on a launcher button; modeless system close via public SendKeys Alt+F4.'
            }
        } else {
            [ordered]@{ row_count = 0; event_names = @(); scenarios = @(); scenario_summaries = @(); terminate_row_count = 0; manual_inputs = @(); input_method = 'not completed' }
        }
        blockers = @($Blockers)
        public_facts = @(
            'docs/specs/FM20_EVENT_FACTS.md records Terminate as a public-doc UserForm lifecycle event name.',
            'docs/specs/LIFECYCLE_PUMP_MODEL.md section 9 separates Hide, logical Unload, and object-lifetime Terminate.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 11 requires lifecycle_pump rows to keep Show, close, hide, unload, and terminate separate.'
        )
        trace_replay_implications = @(
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 5: ordered sequence is decisive; parent_row_id and nesting_depth are required where nested/reentrant causality exists.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 9: hide_form, unload_form, fire_vba_event, and platform close work must keep effect_requested separate from effect_completed.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 11: lifecycle_pump rows must carry close/query/hide/unload/terminate reason and keep Unloaded and Terminated separate.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 14: validators must check reducer/effect/dispatch causal ordering.'
        )
        warnings = @(
            'This is black-box Excel/MSForms event evidence only; no OxForms output was compared.',
            'The fixture reference-state columns are explicit repo-owned VBA state, not private Office reference counts.',
            'Missing event rows are unobserved rows in this run, not negative facts about all MSForms behavior.',
            'Desktop focus, Excel/MSForms version, macro security, and input policy can affect observed rows.'
        )
        clean_room = [ordered]@{
            source = 'Repo-owned fixture input generated through public Excel/VBIDE automation, public VBA event handlers, public Windows input (SendInput mouse + SendKeys Alt+F4), and public worksheet export.'
            prohibited = 'No Office internals, decompilation, disassembly, non-public source, or OxForms output comparison were used.'
        }
        non_claims = @(
            'No OxForms runtime held-reference, Hide/Unload, or Terminate behavior is implemented or claimed.',
            'Close ordering is already captured in oxforms-0a0.24 (nested-modal-lifecycle); only the held-reference state dimension is in scope here.',
            'This capture is not an exhaustive MSForms held-reference parity matrix.',
            'Unloaded and Terminated remain separate trace/replay concepts.'
        )
    }
}

function Write-CaptureReadme {
    param([Parameter(Mandatory = $true)][string]$ResolvedOutDir, [Parameter(Mandatory = $true)]$Manifest, [Parameter(Mandatory = $true)]$RunSummary)
    $coverageLines = @()
    foreach ($property in $RunSummary.scenario_coverage.PSObject.Properties) {
        $coverageLines += ('- `' + $property.Name + '`: ' + [string]$property.Value)
    }
    $blockerLines = @()
    if (@($Manifest.blockers).Count -gt 0) {
        $blockerLines += @('', '## Blockers', '')
        foreach ($blocker in @($Manifest.blockers)) {
            $blockerLines += ('- `' + [string]$blocker['surface'] + '`: ' + [string]$blocker['reason'])
        }
    }
    $lines = @(
        '# W006 Held-Reference Residuals Oracle Capture', '',
        "Capture id: $($Manifest.capture_id)",
        ('Bead: `' + [string]$Manifest.bead + '`'),
        ('Status: `' + [string]$Manifest.status + '`'), '',
        'Black-box Excel/MSForms evidence for the held-reference state residual of three close paths. It is not an OxForms output comparison and not an exhaustive parity claim. Close ordering is already captured in `oxforms-0a0.24` (nested-modal-lifecycle); only the held-reference state dimension is in scope here.', '',
        '## Scenario coverage', ''
    ) + $coverageLines + @(
        '',
        '## Facts', '',
        '- `held-ref-residuals-event-log.json`/`.csv` are worksheet rows emitted by repo-owned VBA handlers while live Excel/MSForms handled the launcher/held forms and public input.',
        '- `input-actions.json` records public Windows input; modal scenarios are entered only by an injected click on a launcher button (never excel.Run Show vbModal); the modeless system close uses public SendKeys Alt+F4 (never PostMessage WM_CLOSE).',
        '- Terminate rows, when present, carry the fixture held-reference state columns visible at handler entry.'
    ) + $blockerLines + @(
        '',
        '## Non-claims', '',
        '- No OxForms runtime held-reference or Terminate behavior is implemented or claimed.',
        '- Missing rows are unobserved in this run, not negative MSForms facts.',
        '- `Unloaded` and `Terminated` remain separate trace/replay concepts.', '',
        '## Clean-room Note', '',
        'Repo-owned fixture sources, public Excel/VBIDE automation, public VBA event handlers, public Windows input (SendInput mouse + SendKeys Alt+F4), and worksheet export only. No Office internals, decompilation, disassembly, or OxForms output comparison.'
    )
    Set-Content -LiteralPath (Join-Path $ResolvedOutDir 'README.md') -Value $lines -Encoding UTF8
}

# ---- main ----
$fixtureRoot = Resolve-InRepoPath $FixtureDir
$fixturePath = Join-Path $fixtureRoot 'fixture.json'
if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) { throw "Fixture manifest not found: $fixturePath" }
$fixture = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
[void](Get-RequiredValue $fixture 'id')
[void](Get-RequiredValue $fixture 'forms')
[void](Get-RequiredValue $fixture 'workbook')
$launcherForm = Get-FormSpec -Fixture $fixture -Identity 'launcher'
$heldForm = Get-FormSpec -Fixture $fixture -Identity 'held'
[void](Resolve-FixtureSourcePath -FixtureRoot $fixtureRoot -Path ([string](Get-RequiredValue $launcherForm 'codeBehindSourcePath')))
[void](Resolve-FixtureSourcePath -FixtureRoot $fixtureRoot -Path ([string](Get-RequiredValue $heldForm 'codeBehindSourcePath')))
[void](Resolve-FixtureSourcePath -FixtureRoot $fixtureRoot -Path ([string](Get-RequiredValue $fixture.workbook 'standardModuleSourcePath')))

if ($DryRun) {
    Write-Host "Fixture: $($fixture.id)"
    Write-Host "Manifest: $fixturePath"
    Write-Host "Forms: $(@($fixture.forms).Count)"
    Write-Host 'Dry run only: manifest and repository paths are valid. Excel was not started.'
    exit 0
}

$resolvedOutDir = Resolve-CaptureDir -Directory $OutDir
$captureId = Split-Path -Leaf $resolvedOutDir
$workbookPath = Join-Path $resolvedOutDir ([string](Get-RequiredValue $fixture.workbook 'fileName'))
$fixtureHashes = Get-FixtureHashes -Fixture $fixture -FixtureRoot $fixtureRoot -FixturePath $fixturePath
$inputActions = [System.Collections.Generic.List[object]]::new()
$blockers = [System.Collections.Generic.List[object]]::new()
$excel = $null; $workbook = $null; $eventLog = $null; $runSummaryPath = $null; $excelInfo = $null

# Reusable per-scenario blocker non-claim (the in-scope residual is held-ref state).
$orderingNonClaim = 'ordering already captured in oxforms-0a0.24 (nested-modal-lifecycle); only the held-reference state dimension is in scope here'

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
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'log_cleared'

    # ---- scenario 1: modeless_system_close ----
    # Modeless Show returns to COM, so excel.Run is safe here. Public Alt+F4
    # closes the held window; excel.Run releases gHeldRef and logs.
    try {
        $excel.Run('SetW006HeldRefScenarioModelessSystemClose')
        $excel.Run('StartW006HeldRefModelessSystemCloseScenario')
        Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'modeless_system_close_started'
        Start-Sleep -Milliseconds ($ActionDelayMilliseconds * 2)
        $heldWindow = Wait-ForOracleWindow -Title $heldTitle -TimeoutSeconds 20
        Invoke-AltF4 -Window $heldWindow -Actions $inputActions -Scenario 'modeless_system_close' -TargetIntent 'Public system close path for the modeless held UserForm while only the global held reference remains.'
        if (-not (Wait-ForOracleWindowClosed -Title $heldTitle -TimeoutSeconds 12)) {
            $excel.Run('CleanupW006HeldRefModelessSystemCloseScenario')
            Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'modeless_system_close_cleanup_unload'
            $blockers.Add([ordered]@{
                surface = 'modeless_system_close'
                reason = 'Public SendKeys Alt+F4 did not close the modeless held UserForm window within the bounded wait; the held reference was released via cleanup unload instead of a system close.'
                detail = 'A cleanup unload still released the held reference, but the held-reference state observed under a real system close was not captured in this run.'
                non_claim = $orderingNonClaim
            }) | Out-Null
        }
        $excel.Run('FinishW006HeldRefModelessSystemCloseScenario')
        Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'modeless_system_close_finished'
        Start-Sleep -Milliseconds $ActionDelayMilliseconds
    } catch {
        $blockers.Add([ordered]@{
            surface = 'modeless_system_close'
            reason = 'The modeless system-close held-reference scenario could not complete: ' + $_.Exception.Message
            detail = $_.Exception.Message
            non_claim = $orderingNonClaim
        }) | Out-Null
        Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('modeless_system_close_blocked=' + $_.Exception.Message)
        try { $excel.Run('CleanupW006HeldRefModelessSystemCloseScenario') } catch { Write-Warning "Cleanup after modeless block failed: $($_.Exception.Message)" }
        try { $excel.Run('FinishW006HeldRefModelessSystemCloseScenario') } catch { Write-Warning "Finish after modeless block failed: $($_.Exception.Message)" }
    }

    # Re-show the launcher (it may still be modeless-visible; the show macro is
    # idempotent enough because Show on a visible modeless form is a no-op-ish
    # re-show). Ensure the launcher window exists for the modal scenarios.
    $excel.Run([string](Get-RequiredValue $fixture.workbook 'showMacroName'))
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'launcher_shown_modeless'
    Start-Sleep -Milliseconds ($ActionDelayMilliseconds * 2)

    # ---- scenarios 2 & 3: modal entered ONLY via injected launcher-button click ----
    $modalScenarios = @(
        [ordered]@{ scenario = 'modal_hide_return'; flagMacro = 'SetW006HeldRefScenarioModalHideReturn'; launcherButton = 'LauncherModalHideButton'; heldButton = 'HeldHideButton'; returnKind = 'hide' }
        [ordered]@{ scenario = 'modal_unload_return'; flagMacro = 'SetW006HeldRefScenarioModalUnloadReturn'; launcherButton = 'LauncherModalUnloadButton'; heldButton = 'HeldUnloadButton'; returnKind = 'unload' }
    )
    foreach ($modal in $modalScenarios) {
        try {
            $excel.Run([string]$modal.flagMacro)
            $launcherWindow = Wait-ForOracleWindow -Title $launcherTitle -TimeoutSeconds 20
            # Injected click on the launcher button enters the modal from its
            # _Click handler (event-driven; does NOT block the COM thread).
            Invoke-ClickControl -Window $launcherWindow -FormSpec $launcherForm -ControlName ([string]$modal.launcherButton) -Actions $inputActions -Scenario ([string]$modal.scenario) -TargetIntent ('Launcher button enters the held form via Show vbModal for the ' + $modal.scenario + ' held-reference path')
            Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('modal_launcher_button_clicked=' + $modal.scenario)
            $heldWindow = Wait-ForOracleWindow -Title $heldTitle -TimeoutSeconds 20
            # Injected click on the held button returns the modal (Hide/Unload).
            Invoke-ClickControl -Window $heldWindow -FormSpec $heldForm -ControlName ([string]$modal.heldButton) -Actions $inputActions -Scenario ([string]$modal.scenario) -TargetIntent ('Held button drives the modal ' + $modal.returnKind + ' return from inside the held modal handler')
            Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('modal_held_button_clicked=' + $modal.scenario)
            if (-not (Wait-ForOracleWindowClosed -Title $heldTitle -TimeoutSeconds 12)) {
                throw ('Held modal window remained visible after the ' + $modal.returnKind + ' click.')
            }
            # Give the launcher _Click handler time to finish its held-reference
            # release sequence after the modal returns.
            Start-Sleep -Milliseconds ($ActionDelayMilliseconds * 2)
            [void](Wait-ForOracleWindow -Title $launcherTitle -TimeoutSeconds 12)
            Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('modal_scenario_returned=' + $modal.scenario)
        } catch {
            $blockers.Add([ordered]@{
                surface = [string]$modal.scenario
                reason = 'The ' + $modal.scenario + ' held-reference scenario could not complete: ' + $_.Exception.Message
                detail = $_.Exception.Message
                non_claim = $orderingNonClaim
            }) | Out-Null
            Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('modal_scenario_blocked=' + $modal.scenario + ':' + $_.Exception.Message)
            # Best-effort: if the held window is still up, close it so later
            # scenarios and the export are not blocked by a stuck modal.
            try {
                $stuck = @(Get-TopLevelWindows | Where-Object { $_.title.IndexOf($heldTitle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -and $_.class_name -eq 'ThunderDFrame' -and $_.process_name -eq 'EXCEL' })
                if ($stuck.Count -gt 0) {
                    Invoke-AltF4 -Window $stuck[0] -Actions $inputActions -Scenario ([string]$modal.scenario + '_cleanup') -TargetIntent 'Cleanup stuck held modal window after a blocked modal scenario.'
                    [void](Wait-ForOracleWindowClosed -Title $heldTitle -TimeoutSeconds 12)
                }
            } catch { Write-Warning "Cleanup of stuck held modal failed: $($_.Exception.Message)" }
        }
    }

    # Close the launcher with public Alt+F4 (never PostMessage WM_CLOSE).
    try {
        $launcherWindow = Wait-ForOracleWindow -Title $launcherTitle -TimeoutSeconds 12
        Invoke-AltF4 -Window $launcherWindow -Actions $inputActions -Scenario 'launcher_close' -TargetIntent 'Close the launcher UserForm via the public system close path.'
        [void](Wait-ForOracleWindowClosed -Title $launcherTitle -TimeoutSeconds 12)
        Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'launcher_closed'
    } catch { Write-Warning "Launcher close attempt failed: $($_.Exception.Message)" }

    Write-JsonFile -Path (Join-Path $resolvedOutDir 'input-actions.json') -Value ([ordered]@{
        schema = 'oxforms.office_oracle.w006_held_ref_residuals_input_actions.v1'
        bead = $captureBead
        manual_inputs = @()
        automated_inputs = @($inputActions)
        blockers = @($blockers)
        notes = @(
            'Public user32 SendInput mouse clicks enter modals via a launcher button and drive the held form return; public SendKeys Alt+F4 drives the modeless system close.',
            'The script never calls excel.Run Show vbModal and never uses PostMessage(WM_CLOSE).',
            'Rows absent from this run remain unknown and are not negative MSForms facts.'
        )
    })

    $eventLog = Export-WorksheetLog -Workbook $workbook -ResolvedOutDir $resolvedOutDir -AutomatedInputs @($inputActions) -Blockers @($blockers)
    $runSummary = New-RunSummary -CaptureId $captureId -Status 'captured' -EventLog $eventLog -Blockers @($blockers)
    $runSummaryPath = Join-Path $resolvedOutDir 'run-summary.json'
    Write-JsonFile -Path $runSummaryPath -Value $runSummary
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('event_log_exported_rows=' + $eventLog.row_count)

    $workbook.Save(); $workbook.Close($true); Release-ComObjectIfPresent $workbook; $workbook = $null
    $excel.Quit(); Release-ComObjectIfPresent $excel; $excel = $null
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'excel_closed_before_manifest'

    $manifest = New-Manifest -Status 'captured' -ResolvedOutDir $resolvedOutDir -CaptureId $captureId -Fixture $fixture -FixtureHashes $fixtureHashes -WorkbookPath $workbookPath -ExcelInfo $excelInfo -EventLog $eventLog -RunSummaryPath $runSummaryPath -Blockers @($blockers)
    Write-JsonFile -Path (Join-Path $resolvedOutDir 'oracle-capture-manifest.json') -Value $manifest
    Write-CaptureReadme -ResolvedOutDir $resolvedOutDir -Manifest $manifest -RunSummary $runSummary
    Write-Checksums -ResolvedOutDir $resolvedOutDir
    Write-Host "W006 held-reference residuals capture complete: $resolvedOutDir"
    Write-Host "Rows: $($eventLog.row_count); terminate rows: $(@($eventLog.terminate_rows).Count); blockers: $(@($blockers).Count)"
} catch {
    $progressPath = Join-Path $resolvedOutDir 'capture-progress.log'
    $lastEntry = if (Test-Path -LiteralPath $progressPath -PathType Leaf) { @(Get-Content -LiteralPath $progressPath)[-1] } else { '<no progress entry>' }
    $blocker = [ordered]@{
        schema = 'oxforms.office_oracle.w006_held_ref_residuals_blocker.v1'
        bead = $captureBead
        capture_id = $captureId
        captured_at_utc = (Get-Date).ToUniversalTime().ToString('o')
        surface = 'held_ref_residuals_oracle_capture'
        status = 'blocked'
        reason = $_.Exception.Message
        category = 'public_excel_vbide_or_windows_input_capture_blocker'
        facts = @(
            'The repo-owned fixture manifest and source files were loaded before the live capture path.',
            ('Last capture-progress entry: ' + $lastEntry),
            'No worksheet event-log rows are included in this blocker artifact unless an event log file is listed in the manifest.'
        )
        blocked_recording_fields = @(
            'event sequence', 'scenario', 'instance id', 'show mode', 'held reference state', 'local reference state', 'release phase', 'QueryClose values', 'Terminate rows'
        )
        trace_replay_implications = @(
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 5 still requires ordered sequence, parent_row_id, and nesting_depth where causal nesting exists.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 9 still requires effect_requested and effect_completed rows to remain separate.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 11 still requires lifecycle_pump rows to keep Show, close, hide, unload, and terminate separate.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 14 still requires validators to check causal ordering.'
        )
        clean_room = [ordered]@{
            source = 'Repo-owned fixture input, public Excel/VBIDE automation attempt, public Windows input automation attempt, and local command/progress logs.'
            prohibited = 'No Office internals, decompilation, disassembly, non-public source, or OxForms output comparison were used.'
        }
        non_claims = @(
            'No OxForms runtime behavior is implemented or claimed.',
            'No held-reference or Terminate timing is inferred from this blocker.',
            'Close ordering is already captured in oxforms-0a0.24 (nested-modal-lifecycle); only the held-reference state dimension is in scope here.',
            'No missing event row is treated as a negative MSForms fact.'
        )
    }
    $blockers.Add($blocker) | Out-Null
    Write-JsonFile -Path (Join-Path $resolvedOutDir 'blocker.json') -Value $blocker
    Write-JsonFile -Path (Join-Path $resolvedOutDir 'input-actions.json') -Value ([ordered]@{
        schema = 'oxforms.office_oracle.w006_held_ref_residuals_input_actions.v1'
        bead = $captureBead
        manual_inputs = @()
        automated_inputs = @($inputActions)
        blockers = @($blockers)
        notes = @('Capture blocked before completing; see blocker.json. Rows absent from this run are not negative MSForms facts.')
    })
    if ($null -ne $workbook) {
        try { $workbook.Save(); $workbook.Close($true) } catch { Write-Warning "Failed to close workbook before blocked manifest: $($_.Exception.Message)" }
        Release-ComObjectIfPresent $workbook; $workbook = $null
    }
    if ($null -ne $excel) {
        try { $excel.Quit() } catch { Write-Warning "Failed to quit Excel before blocked manifest: $($_.Exception.Message)" }
        Release-ComObjectIfPresent $excel; $excel = $null
    }
    $runSummary = New-RunSummary -CaptureId $captureId -Status 'blocked' -EventLog $eventLog -Blockers @($blockers)
    $runSummaryPath = Join-Path $resolvedOutDir 'run-summary.json'
    Write-JsonFile -Path $runSummaryPath -Value $runSummary
    $manifest = New-Manifest -Status 'blocked' -ResolvedOutDir $resolvedOutDir -CaptureId $captureId -Fixture $fixture -FixtureHashes $fixtureHashes -WorkbookPath $workbookPath -ExcelInfo $excelInfo -EventLog $eventLog -RunSummaryPath $runSummaryPath -Blockers @($blockers)
    Write-JsonFile -Path (Join-Path $resolvedOutDir 'oracle-capture-manifest.json') -Value $manifest
    Write-CaptureReadme -ResolvedOutDir $resolvedOutDir -Manifest $manifest -RunSummary $runSummary
    Write-Checksums -ResolvedOutDir $resolvedOutDir
    Write-Host "W006 held-reference residuals capture blocked: $resolvedOutDir"
    Write-Host "Blocker: $($_.Exception.Message)"
} finally {
    if ($null -ne $workbook) { try { $workbook.Close($true) } catch { Write-Warning "Failed to close workbook: $($_.Exception.Message)" } }
    if ($null -ne $excel) { try { $excel.Quit() } catch { Write-Warning "Failed to quit Excel: $($_.Exception.Message)" } }
    Release-ComObjectIfPresent $workbook
    Release-ComObjectIfPresent $excel
}
