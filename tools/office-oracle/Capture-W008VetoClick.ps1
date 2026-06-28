[CmdletBinding()]
param(
    [string]$FixtureDir = 'fixtures\office-oracle\excel-msforms\userforms\w008-veto-click',
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
$captureBead = 'oxforms-esq.10'
$worksheetName = 'W008VetoClickLog'
$logColumns = @('sequence', 'scenario', 'control_name', 'event_name', 'arg_name', 'arg_before', 'arg_after', 'focus_owner_after', 'text_value_after', 'notes')
$requiredScenarios = @('nonveto_click_baseline', 'veto_exit_click')

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
        $Directory = Join-Path $captureRoot ('w008-veto-click-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))
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
    if (([System.Management.Automation.PSTypeName]'OxForms.W008VetoClick.NativeMethods').Type) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
namespace OxForms.W008VetoClick
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
        // Size = 32 pins this union to sizeof(MOUSEINPUT) so Marshal.SizeOf(INPUT) == 40 on x64;
        // otherwise cbSize is 32 and SendInput rejects every event (ERROR_INVALID_PARAMETER 87).
        [StructLayout(LayoutKind.Explicit, Size = 32)] public struct INPUTUNION { [FieldOffset(0)] public KEYBDINPUT ki; }
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
    $callback = [OxForms.W008VetoClick.NativeMethods+EnumWindowsProc]{
        param([System.IntPtr]$Handle, [System.IntPtr]$Param)
        if (-not [OxForms.W008VetoClick.NativeMethods]::IsWindowVisible($Handle)) { return $true }
        $sbT = [System.Text.StringBuilder]::new(512); [void][OxForms.W008VetoClick.NativeMethods]::GetWindowTextW($Handle, $sbT, 512); $title = $sbT.ToString()
        if ($title.IndexOf($Title, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { return $true }
        $sbC = [System.Text.StringBuilder]::new(128); [void][OxForms.W008VetoClick.NativeMethods]::GetClassNameW($Handle, $sbC, 128)
        if ($sbC.ToString() -ne 'ThunderDFrame') { return $true }
        $pid2 = [uint32]0; [void][OxForms.W008VetoClick.NativeMethods]::GetWindowThreadProcessId($Handle, [ref]$pid2)
        if ($excelIds.Count -gt 0 -and ($excelIds -notcontains [int]$pid2)) { return $true }
        $rect = New-Object OxForms.W008VetoClick.NativeMethods+RECT
        [void][OxForms.W008VetoClick.NativeMethods]::GetWindowRect($Handle, [ref]$rect)
        $script:found = [ordered]@{
            handle = ('0x{0:X}' -f $Handle.ToInt64())
            title  = $title
            bounds = [ordered]@{ left = $rect.Left; top = $rect.Top; right = $rect.Right; bottom = $rect.Bottom; width = [Math]::Max(0, $rect.Right - $rect.Left); height = [Math]::Max(0, $rect.Bottom - $rect.Top) }
        }
        return $false
    }
    [void][OxForms.W008VetoClick.NativeMethods]::EnumWindows($callback, [System.IntPtr]::Zero)
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
    # ThunderDFrame window bounds include a title bar (~ default caption height) and
    # thin borders. Approximate the client origin so the click lands inside the
    # target control; controls are laid out non-overlapping with margin so exact
    # chrome metrics are not required.
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
            fixture = 'fixtures/office-oracle/excel-msforms/userforms/w008-veto-click/fixture.json'
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
            'Rows are worksheet rows emitted by repo-owned VBA handlers while real Excel/MSForms dispatched an injected focus-changing mouse click.',
            'arg_before is the Cancel ReturnBoolean .Value read at handler entry; arg_after is that argument .Value after the (flag-gated) Exit veto set it True.',
            'focus_owner_after is Me.ActiveControl.Name (empty when ActiveControl Is Nothing); text_value_after is the relevant TextBox .Text at handler exit.'
        )
        unknowns = @(
            'Rows absent from this run remain unobserved and are not negative MSForms facts.',
            'This capture exercises a non-vetoing baseline click and a vetoing-Exit mouse click; it does not exhaust right-click, double-click, drag-focus, or programmatic SetFocus paths.'
        )
        clean_room = [ordered]@{
            source = 'Repo-owned fixture input generated through public Excel/VBIDE automation and driven through public Windows input APIs.'
            prohibited = 'No Office internals, decompilation, disassembly, non-public source, or OxForms output comparison.'
        }
        non_claims = @(
            'No OxForms runtime focus/validation event behavior is implemented or claimed by this oracle.',
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
            'No OxForms runtime focus/validation behavior is implemented or claimed.',
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
$manifestSchema = 'oxforms.office_oracle.w008_veto_click_capture.v1'
$eventLogSchema = 'oxforms.office_oracle.w008_veto_click_event_log.v1'
$inputActionsSchema = 'oxforms.office_oracle.w008_veto_click_input_actions.v1'
$runSummarySchema = 'oxforms.office_oracle.w008_veto_click_run_summary.v1'
$blockerSchema = 'oxforms.office_oracle.w008_veto_click_blocker.v1'
$idPrefix = 'w008-veto-click-'

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
    # Bring the modeless form foreground and let it settle before the first injected click: the
    # first SendInput after Show otherwise races the form becoming foreground, and the opening
    # scenario's mouse event can be dropped.
    [void](Set-W005ForegroundWindow -Handle $handle -DelayMilliseconds $ActionDelayMilliseconds)
    Start-Sleep -Milliseconds ($ActionDelayMilliseconds * 3)

    # Scenario 1: nonveto_click_baseline -- focus TextBox1 (no veto), then a focus-changing
    # mouse click onto TextBox2. Records the known non-vetoing order (TextBox1 Exit Cancel F->F,
    # TextBox2 Enter + MouseDown/MouseUp, focus_owner=TextBox2) as a baseline on THIS fixture.
    $excel.Run('SetW008ScenarioNonVetoClickBaseline')
    $inputActions.Add((Invoke-ControlClick -Window $window -Fixture $fixture -ControlName 'TextBox1')) | Out-Null
    # A coordinate click alone did not reliably move focus between controls; a VBA SetFocus
    # (FocusControlW008VetoClick) guarantees TextBox1 owns focus before the scenario drives.
    $excel.Run('FocusControlW008VetoClick', 'TextBox1')
    Start-Sleep -Milliseconds $ActionDelayMilliseconds
    $inputActions.Add((Invoke-ControlClick -Window $window -Fixture $fixture -ControlName 'TextBox2')) | Out-Null
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'scenario_nonveto_click_baseline_driven'
    Start-Sleep -Milliseconds $ActionDelayMilliseconds

    # Scenario 2: veto_exit_click -- THE QUESTION. Refocus TextBox1 with veto flags CLEARED
    # (SetW008ScenarioNonVetoClickBaseline clears them) so the refocus itself cannot be vetoed,
    # then arm the Exit veto (gVetoExit + gVetoControl='TextBox1') and inject a focus-changing
    # mouse click onto TextBox2. The worksheet records whether TextBox1 Exit shows Cancel F->T,
    # whether TextBox2 MouseDown/MouseUp/Enter fire AT ALL, and focus_owner_after (TextBox1 if
    # the veto held).
    $excel.Run('SetW008ScenarioNonVetoClickBaseline')
    $inputActions.Add((Invoke-ControlClick -Window $window -Fixture $fixture -ControlName 'TextBox1')) | Out-Null
    $excel.Run('FocusControlW008VetoClick', 'TextBox1')
    $excel.Run('SetW008ScenarioVetoExitClick')
    Start-Sleep -Milliseconds $ActionDelayMilliseconds
    $inputActions.Add((Invoke-ControlClick -Window $window -Fixture $fixture -ControlName 'TextBox2')) | Out-Null
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'scenario_veto_exit_click_driven'
    Start-Sleep -Milliseconds $ActionDelayMilliseconds

    Write-JsonFile -Path (Join-Path $resolvedOutDir 'input-actions.json') -Value ([ordered]@{
        schema = $inputActionsSchema
        bead = $captureBead
        manual_inputs = @()
        automated_inputs = @($inputActions)
        notes = @(
            'Per-scenario Set... macro calls precede each scenario''s injected click so one W008VetoClickLog covers both the baseline and the vetoing-click scenario.',
            'Control clicks are public user32 SendInput mouse clicks at window-bounds + fixture-layout points.',
            'A VBA SetFocus pins the starting focus owner (TextBox1) before each scenario drives its focus-changing click.'
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
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 5: focus/validation fold-back under a mouse-driven focus change needs ordered Exit/Enter/MouseDown/MouseUp rows with the active-control owner.',
            'docs/specs/FM20_EVENT_FACTS.md: whether a vetoing Exit (Cancel=True) absorbs a focus-changing mouse click is settled by this oracle for the W008 surface (feeds esq.10/esq.11).'
        )
        warnings = @('Black-box Excel/MSForms evidence only; no OxForms output was compared.', 'Covers a non-vetoing baseline click and a vetoing-Exit mouse click; not an exhaustive mouse/focus matrix.')
        clean_room = [ordered]@{ source = 'Repo-owned fixture input generated through public Excel/VBIDE automation and driven through public Windows input APIs.'; prohibited = 'No Office internals, decompilation, disassembly, non-public source, or OxForms output comparison.' }
        non_claims = @('No OxForms runtime focus/validation event behavior is implemented or claimed.', 'This capture is not an exhaustive mouse/focus parity matrix.', 'Absence of a row is not a negative parity fact.')
    }
    Write-JsonFile -Path (Join-Path $resolvedOutDir 'oracle-capture-manifest.json') -Value $manifest
    $readme = @(
        '# W008 Veto-Click Oracle Capture', '',
        "Capture id: $captureId", ('Bead: `' + $captureBead + '`'), 'Status: `captured`', '',
        'Black-box Excel/MSForms evidence for the load-bearing question: **Does a vetoing Exit (Cancel=True) absorb a focus-changing mouse click -- i.e. do TextBox2''s MouseDown/MouseUp/Enter fire, and where does focus end up?** This feeds esq.10/esq.11. Not an OxForms output comparison and not an exhaustive parity claim.', '',
        '## Facts', '',
        "- Observed scenarios: ``$((@($eventLog.scenarios) -join ', '))``; total rows: ``$($eventLog.row_count)``.",
        '- `nonveto_click_baseline` records the known non-vetoing order (TextBox1 Exit Cancel F->F, TextBox2 Enter + MouseDown/MouseUp, focus_owner=TextBox2) as a baseline on this fixture.',
        '- `veto_exit_click` arms a TextBox1 Exit veto then injects a focus-changing click onto TextBox2; the rows show whether TextBox1 Exit reports Cancel F->T, whether TextBox2 MouseDown/MouseUp/Enter fire at all, and the post-click focus owner (TextBox1 if the veto held).',
        ('- `' + $idPrefix + 'event-log.json`/`.csv` are W008VetoClickLog rows from repo-owned VBA handlers while live Excel handled the injected mouse click.'), '',
        '## Clean-room Note', '',
        'Repo-owned fixture sources, public Excel/VBIDE automation, public Windows input, and worksheet export only. No Office internals, decompilation, disassembly, or OxForms output comparison.'
    )
    Set-Content -LiteralPath (Join-Path $resolvedOutDir 'README.md') -Value $readme -Encoding UTF8
    Write-Checksums -ResolvedOutDir $resolvedOutDir
    Write-Host "W008 Veto-Click capture complete: $resolvedOutDir"
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
    Write-Host "W008 Veto-Click capture blocked: $resolvedOutDir"
    Write-Host "Blocker: $($_.Exception.Message)"
} finally {
    if ($null -ne $workbook) { try { $workbook.Close($true) } catch { Write-Warning "Failed to close workbook: $($_.Exception.Message)" } }
    if ($null -ne $excel) { try { $excel.Quit() } catch { Write-Warning "Failed to quit Excel: $($_.Exception.Message)" } }
    Release-ComObjectIfPresent $workbook
    Release-ComObjectIfPresent $excel
}
