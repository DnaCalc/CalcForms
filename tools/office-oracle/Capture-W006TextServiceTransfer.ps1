[CmdletBinding()]
param(
    [string]$FixtureDir = 'fixtures\office-oracle\excel-msforms\userforms\text-service-transfer',
    [string]$OutDir,
    [switch]$Force,
    [int]$ActionDelayMilliseconds = 250
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$captureRoot = Join-Path $repoRoot 'docs\evidence\W006_control_implementation_rollout\captures'
$windowTitle = 'OxForms W006 Text Service Transfer Oracle'
$clipboardSeedText = 'OXFORMS_W006_CLIPBOARD_TEXT'
$clipboardSeedId = 'repo_owned_text_seed_v1'
$captureBead = 'oxforms-0a0.17'

Import-Module (Join-Path $repoRoot 'tools\W005WindowsInputDiagnostics.psm1') -Force

function Resolve-InRepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = if ([System.IO.Path]::IsPathRooted($Path)) {
        [System.IO.Path]::GetFullPath($Path)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
    }

    $repoWithSeparator = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not ($fullPath.Equals($repoRoot, [System.StringComparison]::OrdinalIgnoreCase) -or $fullPath.StartsWith($repoWithSeparator, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Path '$Path' resolves outside repository root '$repoRoot'."
    }

    return $fullPath
}

function Resolve-CaptureDir {
    param([string]$Directory)

    if ([string]::IsNullOrWhiteSpace($Directory)) {
        $Directory = Join-Path $captureRoot ('text-service-transfer-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))
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

function Write-CaptureGitAttributes {
    param([string]$ResolvedOutDir)

    $lines = @(
        '.gitattributes text eol=crlf diff',
        '*.json text eol=crlf diff',
        '*.csv text eol=crlf diff',
        '*.md text eol=crlf diff',
        '*.txt text eol=crlf diff',
        'checksums.sha256 text eol=crlf diff',
        '*.xlsm -text -diff',
        'window/*.png -text -diff'
    )
    Set-Content -LiteralPath (Join-Path $ResolvedOutDir '.gitattributes') -Value $lines -Encoding ASCII
}

function Write-ProgressStep {
    param(
        [string]$ResolvedOutDir,
        [string]$Step
    )

    $line = ((Get-Date).ToUniversalTime().ToString('o') + ' ' + $Step)
    Add-Content -LiteralPath (Join-Path $ResolvedOutDir 'capture-progress.log') -Value $line -Encoding UTF8
}

function Invoke-LoggedPowerShell {
    param(
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
    Set-Content -LiteralPath $CommandPath -Value ('powershell.exe ' + $argumentString) -Encoding UTF8

    $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $argumentString -Wait -PassThru -NoNewWindow -RedirectStandardOutput $StdoutPath -RedirectStandardError $StderrPath
    if ($process.ExitCode -ne 0) {
        throw "Command failed with exit code $($process.ExitCode): powershell.exe $argumentString"
    }
}

function Invoke-CaptureWindow {
    param([string]$ResolvedOutDir)

    $windowDir = Join-Path $ResolvedOutDir 'window'
    New-Item -ItemType Directory -Force -Path $windowDir | Out-Null
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', (Join-Path $repoRoot 'tools\office-oracle\Capture-Window.ps1'),
        '-OutDir', $windowDir,
        '-TitleContains', $windowTitle,
        '-ProcessName', 'EXCEL'
    )

    Invoke-LoggedPowerShell -Arguments $arguments `
        -CommandPath (Join-Path $ResolvedOutDir 'capture-window.command.txt') `
        -StdoutPath (Join-Path $ResolvedOutDir 'capture-window.stdout.txt') `
        -StderrPath (Join-Path $ResolvedOutDir 'capture-window.stderr.txt')

    $manifestPath = Join-Path $windowDir 'window-capture-manifest.json'
    return Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
}

function Ensure-NativeInputTypes {
    if (([System.Management.Automation.PSTypeName]'OxForms.W006Transfer.NativeMethods').Type) {
        return
    }

    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace OxForms.W006Transfer
{
    public static class NativeMethods
    {
        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        [StructLayout(LayoutKind.Sequential)]
        public struct INPUT
        {
            public uint type;
            public INPUTUNION u;
        }

        [StructLayout(LayoutKind.Explicit)]
        public struct INPUTUNION
        {
            [FieldOffset(0)]
            public KEYBDINPUT ki;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct KEYBDINPUT
        {
            public ushort wVk;
            public ushort wScan;
            public uint dwFlags;
            public uint time;
            public UIntPtr dwExtraInfo;
        }

        [DllImport("user32.dll", SetLastError = true)]
        public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
    }
}
'@
}

function ConvertFrom-HandleText {
    param([Parameter(Mandatory = $true)][string]$Handle)

    if ($Handle.StartsWith('0x', [System.StringComparison]::OrdinalIgnoreCase)) {
        return [System.IntPtr]([System.Convert]::ToInt64($Handle.Substring(2), 16))
    }

    return [System.IntPtr]([System.Convert]::ToInt64($Handle, 10))
}

function Set-OracleWindowForeground {
    param([Parameter(Mandatory = $true)][object]$WindowManifest)

    Ensure-NativeInputTypes
    $handle = ConvertFrom-HandleText -Handle ([string]$WindowManifest.selected_window.handle)
    return [OxForms.W006Transfer.NativeMethods]::SetForegroundWindow($handle)
}

function New-KeyboardInput {
    param(
        [Parameter(Mandatory = $true)][UInt16]$VirtualKey,
        [Parameter(Mandatory = $true)][UInt32]$Flags
    )

    $keyboard = New-Object OxForms.W006Transfer.NativeMethods+KEYBDINPUT
    $keyboard.wVk = $VirtualKey
    $keyboard.wScan = 0
    $keyboard.dwFlags = $Flags
    $keyboard.time = 0
    $keyboard.dwExtraInfo = [UIntPtr]::Zero

    $union = New-Object OxForms.W006Transfer.NativeMethods+INPUTUNION
    $union.ki = $keyboard

    $input = New-Object OxForms.W006Transfer.NativeMethods+INPUT
    $input.type = 1
    $input.u = $union
    return $input
}

function Invoke-SendInputCtrlV {
    param(
        [Parameter(Mandatory = $true)][System.IntPtr]$TargetHandle,
        [int]$AfterDelayMilliseconds = 180
    )

    Ensure-NativeInputTypes
    $before = Get-W005InputDiagnosticsSnapshot -TargetHandle $TargetHandle -Phase 'before_sendinput_ctrl_v'
    $inputs = [OxForms.W006Transfer.NativeMethods+INPUT[]]@(
        (New-KeyboardInput -VirtualKey 0x11 -Flags 0),
        (New-KeyboardInput -VirtualKey 0x56 -Flags 0),
        (New-KeyboardInput -VirtualKey 0x56 -Flags 0x0002),
        (New-KeyboardInput -VirtualKey 0x11 -Flags 0x0002)
    )

    $sent = [OxForms.W006Transfer.NativeMethods]::SendInput(
        [uint32]$inputs.Length,
        $inputs,
        [System.Runtime.InteropServices.Marshal]::SizeOf([type][OxForms.W006Transfer.NativeMethods+INPUT]))
    $lastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    if ($AfterDelayMilliseconds -gt 0) {
        Start-Sleep -Milliseconds $AfterDelayMilliseconds
    }
    $after = Get-W005InputDiagnosticsSnapshot -TargetHandle $TargetHandle -Phase 'after_sendinput_ctrl_v'

    return [ordered]@{
        schema = 'oxforms.office_oracle.w006_sendinput_keyboard_action.v1'
        input_driver = 'public_user32_sendinput_keyboard'
        action = 'ctrl_v'
        virtual_keys = [ordered]@{
            control = '0x11'
            v = '0x56'
        }
        send_input = [ordered]@{
            requested = [int]$inputs.Length
            sent = [int]$sent
            last_win32_error = [int]$lastError
        }
        status = if ($sent -eq [uint32]$inputs.Length) { 'completed' } else { 'blocked' }
        diagnostics = [ordered]@{
            before = $before
            after = $after
        }
    }
}

function ConvertTo-CsvFieldText {
    param($Value)

    if ($null -eq $Value) {
        return ''
    }
    return [string]$Value
}

function Export-WorksheetLog {
    param(
        [object]$Excel,
        [object]$Workbook,
        [string]$ResolvedOutDir
    )

    $csvPath = Join-Path $ResolvedOutDir 'w006-transfer-event-log.csv'
    if (Test-Path -LiteralPath $csvPath) {
        Remove-Item -LiteralPath $csvPath -Force
    }

    $sheet = $Workbook.Worksheets.Item('W006TransferEventLog')
    $range = $sheet.UsedRange
    $rowCount = [int]$range.Rows.Count
    $columnCount = [int]$range.Columns.Count
    $values = $range.Value2

    $headers = [System.Collections.Generic.List[string]]::new()
    for ($column = 1; $column -le $columnCount; $column++) {
        $headers.Add((ConvertTo-CsvFieldText $values[1, $column])) | Out-Null
    }

    $records = [System.Collections.Generic.List[object]]::new()
    if ($rowCount -ge 2) {
        for ($row = 2; $row -le $rowCount; $row++) {
            $record = [ordered]@{}
            for ($column = 1; $column -le $columnCount; $column++) {
                $record[$headers[$column - 1]] = ConvertTo-CsvFieldText $values[$row, $column]
            }
            $records.Add([pscustomobject]$record) | Out-Null
        }
    }

    @($records) | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
    $rows = @($records)

    $eventNames = @($rows | ForEach-Object { $_.event_name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $targetNames = @($rows | ForEach-Object { $_.target_name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $eventLog = [ordered]@{
        schema = 'oxforms.office_oracle.w006_text_service_transfer_event_log.v1'
        bead = $captureBead
        fact_source = [ordered]@{
            event_facts = 'docs/specs/FM20_EVENT_FACTS.md#W006-Deferred-Input-Surface-Fact-Split'
            input_model = 'docs/specs/INPUT_INTERACTION_MODEL.md#54-W006-Text-service-Clipboard-Paste-And-Dragdrop-Design'
            trace_schema = 'docs/specs/TRACE_REPLAY_SCHEMA.md#10-VBA-Dispatch-Rows'
        }
        observed_facts = [ordered]@{
            row_count = $rows.Count
            event_names = $eventNames
            targets = $targetNames
            rows = @($rows)
        }
        clean_room = [ordered]@{
            source = 'Repo-owned VBA event handlers in a generated Excel/MSForms workbook, public Windows clipboard, public keyboard input, and public worksheet export.'
            data_object_policy = 'Only public MSForms.DataObject method summaries are recorded. The known repo-owned clipboard seed text may be identified by seed id; unexpected text payloads are not recorded.'
            prohibited = 'No Office internals, decompilation, disassembly, private source, or binary inspection.'
        }
        assumptions = @(
            'Rows under observed_facts are worksheet rows emitted by repo-owned VBA handlers while real Excel/MSForms handled the driven input.',
            'Absence of an event row is not a negative parity fact; this capture records only rows raised by this fixture and input run.',
            'WinForms Clipboard, SendKeys, and public MSForms TextBox.Paste are evidence-driving infrastructure only and are not OxForms runtime architecture.'
        )
        non_claims = @(
            'This event log is not an exhaustive MSForms event parity claim.',
            'This event log is not an OxForms output comparison artifact.',
            'Reserved trace names from oxforms-0a0.6 are not implemented or emitted by this artifact.'
        )
    }

    $jsonPath = Join-Path $ResolvedOutDir 'w006-transfer-event-log.json'
    Write-JsonFile -Value $eventLog -Path $jsonPath

    return [ordered]@{
        csv = ConvertTo-RepoRelative $csvPath
        json = ConvertTo-RepoRelative $jsonPath
        row_count = $rows.Count
        event_names = $eventNames
        targets = $targetNames
        rows = @($rows)
    }
}

function Write-Checksums {
    param([string]$ResolvedOutDir)

    $checksumPath = Join-Path $ResolvedOutDir 'checksums.sha256'
    $directoryWithSeparator = $ResolvedOutDir.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $files = Get-ChildItem -LiteralPath $ResolvedOutDir -Recurse -File |
        Where-Object { $_.FullName -ne $checksumPath } |
        Sort-Object FullName

    $lines = foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($directoryWithSeparator.Length).Replace([System.IO.Path]::DirectorySeparatorChar, '/').Replace([System.IO.Path]::AltDirectorySeparatorChar, '/')
        "$(Get-Sha256Hex -Path $file.FullName)  $relativePath"
    }
    Set-Content -LiteralPath $checksumPath -Value $lines -Encoding ASCII
}

function Release-ComObjectIfPresent {
    param($Object)

    if ($null -ne $Object -and [System.Runtime.InteropServices.Marshal]::IsComObject($Object)) {
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($Object)
    }
}

function Get-ExistingRepoRelativeFiles {
    param([string[]]$Paths)

    $existing = [System.Collections.Generic.List[string]]::new()
    foreach ($path in $Paths) {
        if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path -PathType Leaf)) {
            $existing.Add((ConvertTo-RepoRelative $path)) | Out-Null
        }
    }
    return @($existing)
}

function Write-CaptureReadme {
    param(
        [string]$ResolvedOutDir,
        [object]$Manifest
    )

    $lines = @(
        '# W006 Text-service Transfer Oracle Capture',
        '',
        "Capture id: $($Manifest.capture_id)",
        ('Bead: `' + [string]$Manifest.bead + '`'),
        '',
        'This directory contains black-box Excel/MSForms evidence for a focused text-only clipboard paste attempt. It is not an OxForms output comparison and it does not claim exhaustive MSForms parity.',
        '',
        '## Observed Facts',
        '',
        '- `w006-transfer-event-log.json` and `w006-transfer-event-log.csv` contain worksheet rows emitted by the fixture VBA event handlers.',
        '- `input-actions.json` records the public Windows clipboard and keyboard actions used to drive the form; `manual_inputs` is empty.',
        '- `window/` records the top-level Excel/MSForms window metadata before the paste attempt.',
        '',
        '## Blocked Or Non-observed Surfaces',
        '',
        '- IME/composition was not driven by this capture.',
        '- Dead-key preedit was not driven by this capture.',
        '- True OLE drag/drop was not driven by this capture.',
        '- Missing `BeforeDragOver` or `BeforeDropOrPaste` rows are non-claims, not negative facts about all MSForms behavior.',
        '',
        '## Clean-room Note',
        '',
        'The capture used repo-owned fixture sources, public Excel/VBIDE automation, public VBA event handlers, the public Windows clipboard, public Windows keyboard input APIs, and public top-level window capture. It did not use private Office internals, decompilation, disassembly, or OxForms output comparison.'
    )

    Set-Content -LiteralPath (Join-Path $ResolvedOutDir 'README.md') -Value $lines -Encoding UTF8
}

$resolvedOutDir = Resolve-CaptureDir -Directory $OutDir
$fixtureRoot = Resolve-InRepoPath $FixtureDir
$fixturePath = Join-Path $fixtureRoot 'fixture.json'
$fixture = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
$captureId = Split-Path -Leaf $resolvedOutDir
$workbookPath = Join-Path $resolvedOutDir 'w006-text-service-transfer-oracle.xlsm'

Write-CaptureGitAttributes -ResolvedOutDir $resolvedOutDir
Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'capture_directory_prepared'
Set-Location $repoRoot

$generatorArgs = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', (Join-Path $repoRoot 'tools\office-oracle\Open-ExcelUserFormFixture.ps1'),
    '-FixtureDir', $fixtureRoot,
    '-OutputWorkbook', $workbookPath
)
if ($Force) {
    $generatorArgs += '-Force'
}

Invoke-LoggedPowerShell -Arguments $generatorArgs `
    -CommandPath (Join-Path $resolvedOutDir 'generate-workbook.command.txt') `
    -StdoutPath (Join-Path $resolvedOutDir 'generate-workbook.stdout.txt') `
    -StderrPath (Join-Path $resolvedOutDir 'generate-workbook.stderr.txt')
Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'workbook_generated'

$excel = $null
$workbook = $null
$windowManifest = $null
$eventLog = $null
$excelInfo = $null

try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $true
    $excel.DisplayAlerts = $false
    try {
        $excel.AutomationSecurity = 1
    } catch {
        Write-Warning "Could not set Excel AutomationSecurity for this instance: $($_.Exception.Message)"
    }

    $excelPath = Join-Path $excel.Path 'EXCEL.EXE'
    if (Test-Path -LiteralPath $excelPath -PathType Leaf) {
        $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($excelPath)
        $excelInfo = [ordered]@{
            path = $excelPath
            file_version = $versionInfo.FileVersion
            product_version = $versionInfo.ProductVersion
            product_name = $versionInfo.ProductName
            company_name = $versionInfo.CompanyName
        }
    }

    $workbook = $excel.Workbooks.Open($workbookPath)
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'workbook_opened'
    $excel.Run('ClearW006TransferLog')
    $excel.Run($fixture.workbook.showMacroName)
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'form_shown_modeless'
    Start-Sleep -Milliseconds ($ActionDelayMilliseconds * 2)

    $windowManifest = Invoke-CaptureWindow -ResolvedOutDir $resolvedOutDir
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'window_captured'

    $inputActions = [System.Collections.Generic.List[object]]::new()
    $inputActions.Add([ordered]@{
        sequence = 1
        method = 'excel_vba_public_macro'
        action = 'focus_textbox'
        target_intent = 'OracleTextBox receives subsequent Ctrl+V'
        manual = $false
        notes = 'Focus is prepared through a repo-owned public VBA fixture macro before public keyboard input is sent.'
    }) | Out-Null
    $excel.Run('FocusW006TransferTextBox')
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'textbox_focus_macro_completed'
    Start-Sleep -Milliseconds $ActionDelayMilliseconds

    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Clipboard]::SetText($clipboardSeedText)
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'clipboard_seed_set'
    $inputActions.Add([ordered]@{
        sequence = 2
        method = 'public_windows_clipboard'
        action = 'set_clipboard_text'
        target_intent = 'Clipboard contains repo-owned text seed before Ctrl+V'
        manual = $false
        clipboard_seed_id = $clipboardSeedId
        payload_policy = 'Repo-owned seed text may be identified by seed id in evidence.'
    }) | Out-Null

    Add-Type -AssemblyName Microsoft.VisualBasic
    try {
        [void][Microsoft.VisualBasic.Interaction]::AppActivate($windowTitle)
    } catch {
        Write-Warning "AppActivate by UserForm title failed before Ctrl+V: $($_.Exception.Message)"
    }
    $targetHandle = ConvertFrom-W005HandleText -Handle ([string]$windowManifest.selected_window.handle)
    $foregroundTransition = Set-W005ForegroundWindow -Handle $targetHandle -DelayMilliseconds $ActionDelayMilliseconds
    $foregroundResult = [bool]$foregroundTransition.set_foreground_result
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('set_foreground_result=' + $foregroundResult)
    Start-Sleep -Milliseconds $ActionDelayMilliseconds
    $inputActions.Add([ordered]@{
        sequence = 3
        method = 'public_user32_showwindow_setforegroundwindow'
        action = 'focus_userform'
        target_intent = 'Prepare the modeless UserForm for public Ctrl+V keyboard input'
        manual = $false
        result = $foregroundTransition
    }) | Out-Null

    $sendInputStatus = Invoke-SendInputCtrlV -TargetHandle $targetHandle -AfterDelayMilliseconds ($ActionDelayMilliseconds * 3)
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('sendinput_ctrl_v_status=' + $sendInputStatus.status)
    Start-Sleep -Milliseconds ($ActionDelayMilliseconds * 2)
    $textAfterSendInput = [string]($excel.Run('W006TransferTextBoxText'))
    $sendInputStatus['textbox_text_equals_clipboard_seed_after'] = ($textAfterSendInput -eq $clipboardSeedText)
    $inputActions.Add([ordered]@{
        sequence = 4
        method = 'public_user32_sendinput_keyboard'
        action = 'ctrl_v'
        keys = 'Ctrl down, V down, V up, Ctrl up'
        target_intent = 'Paste the repo-owned clipboard text into OracleTextBox'
        manual = $false
        result = $sendInputStatus
        notes = 'This is evidence-driving infrastructure, not OxForms runtime architecture.'
    }) | Out-Null

    $sendKeysStatus = [ordered]@{
        attempted = $true
        driver = 'System.Windows.Forms.SendKeys.SendWait'
        keys = '^v'
        set_foreground_result = [bool]$foregroundResult
        status = if ($textAfterSendInput -eq $clipboardSeedText) { 'not_needed' } else { 'not_completed' }
        error = $null
    }
    if ($textAfterSendInput -ne $clipboardSeedText) {
        try {
            [System.Windows.Forms.SendKeys]::SendWait('^v')
            $sendKeysStatus.status = 'completed'
            Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'sendkeys_ctrl_v_sent'
        } catch {
            $sendKeysStatus.status = 'blocked'
            $sendKeysStatus.error = $_.Exception.Message
            Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('sendkeys_ctrl_v_blocked=' + $_.Exception.Message)
        }
        Start-Sleep -Milliseconds ($ActionDelayMilliseconds * 3)
    }
    $textAfterShortcut = [string]($excel.Run('W006TransferTextBoxText'))
    $sendKeysStatus['textbox_text_equals_clipboard_seed_after'] = ($textAfterShortcut -eq $clipboardSeedText)
    $inputActions.Add([ordered]@{
        sequence = 5
        method = 'system_windows_forms_sendkeys'
        action = 'ctrl_v'
        keys = '^v'
        target_intent = 'Paste the repo-owned clipboard text into OracleTextBox'
        manual = $false
        result = $sendKeysStatus
        notes = 'Secondary public keyboard driver retained for diagnostics because oxforms-0a0.13 blocked on SendKeys access denied.'
    }) | Out-Null

    $keyboardShortcutObserved = ($textAfterShortcut -eq $clipboardSeedText)
    $keyboardShortcutStatus = [ordered]@{
        attempted = $true
        primary_driver = 'public_user32_sendinput_keyboard'
        secondary_driver = 'System.Windows.Forms.SendKeys.SendWait'
        status = if ($keyboardShortcutObserved) { 'completed' } elseif ($sendInputStatus.status -eq 'blocked' -and $sendKeysStatus.status -eq 'blocked') { 'blocked' } else { 'attempted_but_ineffective' }
        sendinput_result = $sendInputStatus
        sendkeys_result = $sendKeysStatus
        textbox_text_equals_clipboard_seed_after = [bool]$keyboardShortcutObserved
    }

    $publicPasteMethodStatus = [ordered]@{
        attempted = $false
        status = 'not_needed'
        error = $null
    }
    if ($textAfterShortcut -ne $clipboardSeedText) {
        $publicPasteMethodStatus.attempted = $true
        $publicPasteMethodStatus.status = 'not_completed'
        try {
            $excel.Run('PasteW006TransferTextBoxViaPublicMethod')
            Start-Sleep -Milliseconds ($ActionDelayMilliseconds * 2)
            $publicPasteMethodStatus.status = 'completed'
            Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'public_textbox_paste_method_completed'
        } catch {
            $publicPasteMethodStatus.status = 'blocked'
            $publicPasteMethodStatus.error = $_.Exception.Message
            Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('public_textbox_paste_method_blocked=' + $_.Exception.Message)
        }
        $inputActions.Add([ordered]@{
            sequence = 6
            method = 'public_msforms_textbox_paste_method'
            action = 'textbox_paste'
            target_intent = 'Paste the repo-owned clipboard text into OracleTextBox after keyboard shortcut driver failed or produced no text'
            manual = $false
            result = $publicPasteMethodStatus
            notes = 'This is a narrower paste/DataObject oracle and is not evidence that Ctrl+V ordering worked.'
        }) | Out-Null
    }

    $finalText = $excel.Run('W006TransferTextBoxText')
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('final_text_length=' + ([string]$finalText).Length)

    $excel.Run($fixture.workbook.hideMacroName)
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'hide_macro_completed'
    Start-Sleep -Milliseconds $ActionDelayMilliseconds
    $eventLog = Export-WorksheetLog -Excel $excel -Workbook $workbook -ResolvedOutDir $resolvedOutDir
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('event_log_exported_rows=' + $eventLog.row_count)

    $inputActionsPath = Join-Path $resolvedOutDir 'input-actions.json'
    Write-JsonFile -Path $inputActionsPath -Value ([ordered]@{
        schema = 'oxforms.office_oracle.w006_text_service_transfer_input_actions.v1'
        bead = $captureBead
        manual_inputs = @()
        automated_inputs = @($inputActions)
        blockers = @(
            if (-not $keyboardShortcutObserved) {
                [ordered]@{
                    surface = 'clipboard_shortcut_ctrl_v'
                    reason = 'The public keyboard drivers did not deliver Ctrl+V to the W006 TextBox fixture in this desktop session.'
                    detail = $keyboardShortcutStatus
                    non_claim = 'No MSForms Ctrl+V keyboard ordering or ReturnInteger interaction is claimed from this run.'
                }
            }
            [ordered]@{
                surface = 'ime_composition'
                reason = 'No deterministic repo-owned IME composition driver or active input-method setup is defined for this bead.'
                non_claim = 'No IME/composition ordering, helper mutation, or TextBox value behavior is claimed.'
            },
            [ordered]@{
                surface = 'dead_keys'
                reason = 'No deterministic keyboard-layout/dead-key driver is defined for this bead; SendKeys text input does not prove dead-key preedit behavior.'
                non_claim = 'No dead-key ordering, preedit, or committed text behavior is claimed.'
            },
            [ordered]@{
                surface = 'ole_drag_drop'
                reason = 'The existing public SendInput mouse helper moves the pointer but does not create a live OLE/MSForms DataObject drag session.'
                non_claim = 'No BeforeDragOver ordering, DataObject format behavior, or drop-effect negotiation is claimed unless rows appear in the event log.'
            }
        )
        notes = @(
            'WinForms Clipboard, user32 SendInput keyboard input, SendKeys, and the public MSForms TextBox.Paste method are evidence-driving tools around live Excel/MSForms.',
            'The fixture does not store platform clipboard objects, COM DataObject identities, or private implementation details.'
        )
    })

    $runSummaryPath = Join-Path $resolvedOutDir 'run-summary.json'
    $beforeDropOrPasteRows = @($eventLog.rows | Where-Object { $_.event_name -eq 'BeforeDropOrPaste' })
    $beforeDragOverRows = @($eventLog.rows | Where-Object { $_.event_name -eq 'BeforeDragOver' })
    $changeRows = @($eventLog.rows | Where-Object { $_.event_name -eq 'Change' })
    $keyPressRows = @($eventLog.rows | Where-Object { $_.event_name -eq 'KeyPress' })
    Write-JsonFile -Path $runSummaryPath -Value ([ordered]@{
        schema = 'oxforms.office_oracle.w006_text_service_transfer_run_summary.v1'
        bead = $captureBead
        capture_id = $captureId
        final_text_equals_clipboard_seed = ([string]$finalText -eq $clipboardSeedText)
        final_text_policy = 'The compared text is the repo-owned clipboard seed from the fixture manifest.'
        row_count = $eventLog.row_count
        event_names = $eventLog.event_names
        selected_surface_status = [ordered]@{
            clipboard_shortcut_paste = if ($keyboardShortcutObserved) { 'observed_textbox_text_equals_repo_seed_after_ctrl_v' } else { 'blocked_keyboard_driver_' + $keyboardShortcutStatus.status }
            public_textbox_paste_method = if ($publicPasteMethodStatus.attempted -and [string]$finalText -eq $clipboardSeedText) { 'observed_textbox_text_equals_repo_seed_after_public_paste_method' } elseif ($publicPasteMethodStatus.attempted) { 'attempted_but_textbox_text_did_not_equal_repo_seed' } else { 'not_attempted' }
            change = if ($changeRows.Count -gt 0) { 'observed' } else { 'not_observed_in_this_run' }
            key_press = if ($keyPressRows.Count -gt 0) { 'observed' } else { 'not_observed_in_this_run' }
            before_drop_or_paste = if ($beforeDropOrPasteRows.Count -gt 0) { 'observed' } else { 'not_observed_in_this_run' }
            before_drag_over = if ($beforeDragOverRows.Count -gt 0) { 'observed' } else { 'not_observed_in_this_run' }
            ime_composition = 'blocked_no_deterministic_driver'
            dead_keys = 'blocked_no_deterministic_driver'
            true_ole_drag_drop = 'blocked_no_data_object_drag_driver'
        }
        non_claims = @(
            'A missing event row is not a negative claim about all MSForms inputs.',
            'This run does not implement or validate OxForms runtime paste, IME, dead-key, or drag/drop behavior.',
            'This run does not emit reserved trace/replay row names from oxforms-0a0.6.'
        )
    })

    $workbook.Save()
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'workbook_saved'
} finally {
    if ($null -ne $workbook) {
        try {
            $workbook.Close($true)
        } catch {
            Write-Warning "Failed to close workbook: $($_.Exception.Message)"
        }
    }
    if ($null -ne $excel) {
        try {
            $excel.Quit()
        } catch {
            Write-Warning "Failed to quit Excel: $($_.Exception.Message)"
        }
    }
    Release-ComObjectIfPresent $workbook
    Release-ComObjectIfPresent $excel
}

$fixtureHashes = [ordered]@{
    manifest = [ordered]@{
        path = ConvertTo-RepoRelative $fixturePath
        sha256 = Get-Sha256Hex -Path $fixturePath
    }
    form_code_behind = [ordered]@{
        path = ConvertTo-RepoRelative (Join-Path $fixtureRoot $fixture.codeBehind.sourcePath)
        sha256 = Get-Sha256Hex -Path (Join-Path $fixtureRoot $fixture.codeBehind.sourcePath)
    }
    standard_module_extra = [ordered]@{
        path = ConvertTo-RepoRelative (Join-Path $fixtureRoot $fixture.workbook.additionalModuleSourcePath)
        sha256 = Get-Sha256Hex -Path (Join-Path $fixtureRoot $fixture.workbook.additionalModuleSourcePath)
    }
}

$commandLogs = Get-ExistingRepoRelativeFiles -Paths @(
    (Join-Path $resolvedOutDir 'generate-workbook.command.txt'),
    (Join-Path $resolvedOutDir 'generate-workbook.stdout.txt'),
    (Join-Path $resolvedOutDir 'generate-workbook.stderr.txt'),
    (Join-Path $resolvedOutDir 'capture-window.command.txt'),
    (Join-Path $resolvedOutDir 'capture-window.stdout.txt'),
    (Join-Path $resolvedOutDir 'capture-window.stderr.txt')
)

$screenshotPath = Join-Path $resolvedOutDir 'window\window-capture.png'

$manifest = [ordered]@{
    schema = 'oxforms.office_oracle.w006_text_service_transfer_capture.v1'
    bead = $captureBead
    capture_id = $captureId
    fixture = [ordered]@{
        id = $fixture.id
        inputs = $fixtureHashes
    }
    commands = [ordered]@{
        generator = ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'generate-workbook.command.txt')
        window_capture = ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'capture-window.command.txt')
        rerun_note = 'Run this script from the repository root. It generates the workbook, opens Excel, attempts Ctrl+V paste into the modeless UserForm with public user32 SendInput keyboard input and then SendKeys diagnostics, falls back to public MSForms TextBox.Paste when keyboard drivers are blocked or ineffective, exports W006TransferEventLog, writes manifests, and checksums artifacts.'
    }
    platform = [ordered]@{
        os = [System.Environment]::OSVersion.VersionString
        is_windows = $true
        powershell = $PSVersionTable.PSVersion.ToString()
    }
    excel = $excelInfo
    artifacts = [ordered]@{
        generated_workbook = [ordered]@{
            path = ConvertTo-RepoRelative $workbookPath
            sha256 = Get-Sha256Hex -Path $workbookPath
        }
        run_summary = ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'run-summary.json')
        event_log_json = ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'w006-transfer-event-log.json')
        event_log_csv = ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'w006-transfer-event-log.csv')
        input_actions = ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'input-actions.json')
        window_capture_manifest = ConvertTo-RepoRelative (Join-Path $resolvedOutDir 'window\window-capture-manifest.json')
        screenshot = if (Test-Path -LiteralPath $screenshotPath -PathType Leaf) { ConvertTo-RepoRelative $screenshotPath } else { $null }
        command_logs = $commandLogs
    }
    observed_coverage = [ordered]@{
        event_names = $eventLog.event_names
        row_count = $eventLog.row_count
        manual_inputs = @()
        input_method = 'WinForms Clipboard plus attempted public user32 SendInput Ctrl+V and System.Windows.Forms.SendKeys Ctrl+V diagnostics and, when needed, public MSForms TextBox.Paste around live Excel/MSForms'
    }
    warnings = @(
        'This is black-box Excel/MSForms event evidence only; no OxForms output was compared.',
        'The capture is not an exhaustive MSForms event parity claim.',
        'Missing BeforeDragOver or BeforeDropOrPaste rows are unobserved rows, not negative facts about all MSForms behavior.',
        'Desktop focus, keyboard layout, clipboard policy, theme, DPI, and Excel/MSForms version can affect observed rows.'
    )
    clean_room = [ordered]@{
        source = 'Repo-owned fixture generated through public Excel/VBIDE automation and driven through WinForms Clipboard, public user32 SendInput keyboard input, SendKeys diagnostics, and public MSForms TextBox.Paste.'
        data_object_policy = 'Public MSForms.DataObject method summaries only; no live object identity is stored.'
        prohibited = 'No Office internals, decompilation, disassembly, private source, or non-public implementation details were used.'
    }
}

Write-JsonFile -Path (Join-Path $resolvedOutDir 'oracle-capture-manifest.json') -Value $manifest
Write-CaptureReadme -ResolvedOutDir $resolvedOutDir -Manifest $manifest
Write-Checksums -ResolvedOutDir $resolvedOutDir

Write-Host "W006 text-service transfer capture complete: $resolvedOutDir"
Write-Host "Rows: $($eventLog.row_count)"
Write-Host "Events: $(@($eventLog.event_names) -join ', ')"
