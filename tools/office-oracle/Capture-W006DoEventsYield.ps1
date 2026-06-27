[CmdletBinding()]
param(
    [string]$FixtureDir = 'fixtures\office-oracle\excel-msforms\userforms\doevents-yield',
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
$captureBead = 'oxforms-0a0.23'

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
        $Directory = Join-Path $captureRoot ('doevents-yield-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))
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
            # COM path; not load-bearing for a DoEvents/timing oracle).
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
    if (([System.Management.Automation.PSTypeName]'OxForms.W006DoEvents.NativeMethods').Type) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
namespace OxForms.W006DoEvents
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
    $callback = [OxForms.W006DoEvents.NativeMethods+EnumWindowsProc]{
        param([System.IntPtr]$Handle, [System.IntPtr]$Param)
        if (-not [OxForms.W006DoEvents.NativeMethods]::IsWindowVisible($Handle)) { return $true }
        $sbT = [System.Text.StringBuilder]::new(512); [void][OxForms.W006DoEvents.NativeMethods]::GetWindowTextW($Handle, $sbT, 512); $title = $sbT.ToString()
        if ($title.IndexOf($Title, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { return $true }
        $sbC = [System.Text.StringBuilder]::new(128); [void][OxForms.W006DoEvents.NativeMethods]::GetClassNameW($Handle, $sbC, 128)
        if ($sbC.ToString() -ne 'ThunderDFrame') { return $true }
        $pid2 = [uint32]0; [void][OxForms.W006DoEvents.NativeMethods]::GetWindowThreadProcessId($Handle, [ref]$pid2)
        if ($excelIds.Count -gt 0 -and ($excelIds -notcontains [int]$pid2)) { return $true }
        $rect = New-Object OxForms.W006DoEvents.NativeMethods+RECT
        [void][OxForms.W006DoEvents.NativeMethods]::GetWindowRect($Handle, [ref]$rect)
        $script:found = [ordered]@{
            handle = ('0x{0:X}' -f $Handle.ToInt64())
            title  = $title
            bounds = [ordered]@{ left = $rect.Left; top = $rect.Top; right = $rect.Right; bottom = $rect.Bottom; width = [Math]::Max(0, $rect.Right - $rect.Left); height = [Math]::Max(0, $rect.Bottom - $rect.Top) }
        }
        return $false
    }
    [void][OxForms.W006DoEvents.NativeMethods]::EnumWindows($callback, [System.IntPtr]::Zero)
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

function Export-WorksheetLog {
    param([Parameter(Mandatory = $true)]$Workbook, [Parameter(Mandatory = $true)][string]$ResolvedOutDir)
    $sheet = $Workbook.Worksheets.Item('W006DoEventsLog')
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
    $csvPath = Join-Path $ResolvedOutDir 'doevents-yield-event-log.csv'
    $rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
    $maxDepth = 0
    foreach ($row in $rows) { $d = 0; [void][int]::TryParse([string]$row.handler_depth, [ref]$d); if ($d -gt $maxDepth) { $maxDepth = $d } }
    $reentrantRows = @($rows | Where-Object { $_.row_kind -eq 'reentrant_handler' })
    $eventLog = [ordered]@{
        schema = 'oxforms.office_oracle.w006_doevents_yield_event_log.v1'
        bead = $captureBead
        source = [ordered]@{
            worksheet = 'W006DoEventsLog'
            fixture = 'fixtures/office-oracle/excel-msforms/userforms/doevents-yield/fixture.json'
            trace_schema = [ordered]@{
                ordering = 'docs/specs/TRACE_REPLAY_SCHEMA.md#5-Ordering-Model'
                lifecycle_pump = 'docs/specs/TRACE_REPLAY_SCHEMA.md#11-Lifecycle-And-Pump-Rows'
            }
        }
        observed_facts = [ordered]@{
            row_count = $rows.Count
            max_handler_depth = $maxDepth
            reentrant_during_doevents = ($reentrantRows.Count -gt 0)
            event_names = @($rows | ForEach-Object { $_.event_name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
            rows = $rows
        }
        assumptions = @(
            'Rows are worksheet rows emitted by repo-owned VBA handlers while real Excel/MSForms handled the injected clicks and the DoEvents pump.',
            'handler_depth is explicit VBA instrumentation (enter/exit counter), not a private Office call-stack metric.'
        )
        unknowns = @(
            'This capture exercises one reentrant click during one DoEvents pump; it does not enumerate all DoEvents/yield scenarios, queued services, timers, or modal-frame yields.'
        )
        non_claims = @(
            'No OxForms runtime DoEvents, forms-owned event loop, or yield/resume behavior is implemented or claimed by this oracle.',
            'Absence of a row is not a negative parity fact.'
        )
    }
    $jsonPath = Join-Path $ResolvedOutDir 'doevents-yield-event-log.json'
    Write-JsonFile -Value $eventLog -Path $jsonPath
    return [ordered]@{ csv = ConvertTo-RepoRelative $csvPath; json = ConvertTo-RepoRelative $jsonPath; row_count = $rows.Count; max_handler_depth = $maxDepth; reentrant_during_doevents = ($reentrantRows.Count -gt 0); rows = $rows }
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
$blockers = [System.Collections.Generic.List[object]]::new()
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
    # First click: enters YieldButton_Click (depth 1), which pumps DoEvents ~2.5s.
    $inputActions.Add((Invoke-CenterClick -Window $window -Label 'outer_click_enters_doevents_pump')) | Out-Null
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'outer_click_sent'
    Start-Sleep -Milliseconds 900
    # Second click while the first handler is still pumping: reenters at depth 2.
    $inputActions.Add((Invoke-CenterClick -Window $window -Label 'reentrant_click_during_doevents_pump')) | Out-Null
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'reentrant_click_sent'
    # Wait out the remainder of the outer 2.5s pump loop plus margin.
    Start-Sleep -Milliseconds 3000

    Write-JsonFile -Path (Join-Path $resolvedOutDir 'input-actions.json') -Value ([ordered]@{
        schema = 'oxforms.office_oracle.w006_doevents_yield_input_actions.v1'
        bead = $captureBead
        manual_inputs = @()
        automated_inputs = @($inputActions)
        notes = @('Public user32 SendInput mouse clicks at the form window centre are evidence-driving infrastructure only.', 'Two clicks at the same point: the second is injected while the first Click handler is pumping DoEvents, so it reenters the handler through the pump.')
    })

    $eventLog = Export-WorksheetLog -Workbook $workbook -ResolvedOutDir $resolvedOutDir
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('event_log_exported_rows=' + $eventLog.row_count)

    $workbook.Save(); $workbook.Close($true); Release-ComObjectIfPresent $workbook; $workbook = $null
    $excel.Quit(); Release-ComObjectIfPresent $excel; $excel = $null
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'excel_closed_before_manifest'

    $manifest = [ordered]@{
        schema = 'oxforms.office_oracle.w006_doevents_yield_capture.v1'
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
        observed_coverage = [ordered]@{ row_count = $eventLog.row_count; max_handler_depth = $eventLog.max_handler_depth; reentrant_during_doevents = $eventLog.reentrant_during_doevents }
        blockers = @($blockers)
        trace_replay_implications = @(
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 5: reentrant dispatch during a DoEvents yield needs ordered sequence and nesting depth.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 11: lifecycle_pump rows must carry pump term and reentrancy depth for a DoEvents-like yield.'
        )
        warnings = @('Black-box Excel/MSForms evidence only; no OxForms output was compared.', 'Desktop focus, DPI, and Excel/MSForms version can affect whether the reentrant click is dispatched during the pump.')
        clean_room = [ordered]@{ source = 'Repo-owned fixture input generated through public Excel/VBIDE automation and driven through public Windows input APIs.'; prohibited = 'No Office internals, decompilation, disassembly, non-public source, or OxForms output comparison.' }
        non_claims = @('No OxForms runtime DoEvents/yield/reentrant-pump behavior is implemented or claimed.', 'This capture is not an exhaustive DoEvents parity matrix.')
    }
    Write-JsonFile -Path (Join-Path $resolvedOutDir 'oracle-capture-manifest.json') -Value $manifest
    $readme = @(
        '# W006 DoEvents-Yield Oracle Capture', '',
        "Capture id: $captureId", ('Bead: `' + $captureBead + '`'), 'Status: `captured`', '',
        'Black-box Excel/MSForms evidence for reentrant event dispatch during a `DoEvents` pump. Not an OxForms output comparison and not an exhaustive parity claim.', '',
        '## Facts', '',
        '- `doevents-yield-event-log.json`/`.csv` are worksheet rows from repo-owned VBA handlers while live Excel handled two injected clicks.',
        '- The outer `YieldButton_Click` (handler_depth 1) logs `BeforeDoEvents`, pumps `DoEvents`, then logs `AfterDoEvents`. A second click injected during the pump reenters the handler at `handler_depth` 2 (`ReentrantClick`), sandwiched between those rows.', '',
        '## Clean-room Note', '',
        'Repo-owned fixture sources, public Excel/VBIDE automation, public Windows input, and worksheet export only. No Office internals, decompilation, disassembly, or OxForms output comparison.'
    )
    Set-Content -LiteralPath (Join-Path $resolvedOutDir 'README.md') -Value $readme -Encoding UTF8
    Write-Checksums -ResolvedOutDir $resolvedOutDir
    Write-Host "W006 DoEvents-yield capture complete: $resolvedOutDir"
    Write-Host "Rows: $($eventLog.row_count); max_handler_depth: $($eventLog.max_handler_depth); reentrant_during_doevents: $($eventLog.reentrant_during_doevents)"
} catch {
    $progressPath = Join-Path $resolvedOutDir 'capture-progress.log'
    $lastEntry = if (Test-Path -LiteralPath $progressPath -PathType Leaf) { @(Get-Content -LiteralPath $progressPath)[-1] } else { '<no progress entry>' }
    $blocker = [ordered]@{
        schema = 'oxforms.office_oracle.w006_doevents_yield_blocker.v1'
        bead = $captureBead; capture_id = $captureId; status = 'blocked'
        reason = $_.Exception.Message
        facts = @('Repo-owned fixture loaded before the live capture path.', ('Last capture-progress entry: ' + $lastEntry))
        non_claims = @('No OxForms runtime behavior is implemented or claimed.', 'No missing row is treated as a negative MSForms fact.')
        clean_room = [ordered]@{ source = 'Repo-owned fixture input + public Excel/VBIDE/Windows automation.'; prohibited = 'No Office internals, decompilation, disassembly, non-public source, or OxForms output comparison.' }
    }
    Write-JsonFile -Path (Join-Path $resolvedOutDir 'blocker.json') -Value $blocker
    Write-Checksums -ResolvedOutDir $resolvedOutDir
    Write-Host "W006 DoEvents-yield capture blocked: $resolvedOutDir"
    Write-Host "Blocker: $($_.Exception.Message)"
} finally {
    if ($null -ne $workbook) { try { $workbook.Close($true) } catch { Write-Warning "Failed to close workbook: $($_.Exception.Message)" } }
    if ($null -ne $excel) { try { $excel.Quit() } catch { Write-Warning "Failed to quit Excel: $($_.Exception.Message)" } }
    Release-ComObjectIfPresent $workbook
    Release-ComObjectIfPresent $excel
}
