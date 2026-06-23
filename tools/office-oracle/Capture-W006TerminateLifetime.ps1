[CmdletBinding()]
param(
    [string]$FixtureDir = 'fixtures\office-oracle\excel-msforms\userforms\terminate-lifetime',
    [string]$OutDir,
    [switch]$Force,
    [switch]$DryRun,
    [switch]$SkipModelessCloseAttempt,
    [switch]$SkipModalReturnAttempt,
    [int]$ActionDelayMilliseconds = 220
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$captureRoot = Join-Path $repoRoot 'docs\evidence\W006_control_implementation_rollout\captures'
$captureBead = 'oxforms-0a0.21'
$windowTitle = 'OxForms W006 Terminate Oracle'
$requiredScenarios = @(
    'hide_held_release',
    'unload_held_release',
    'modeless_system_close_held_release',
    'modal_hide_return_held_release',
    'modal_unload_return_held_release'
)

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
        $Directory = Join-Path $captureRoot ('terminate-lifetime-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))
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
    if ((Test-Path -LiteralPath $fullPath -PathType Container) -and -not $Force) {
        $existing = @(Get-ChildItem -LiteralPath $fullPath -Force)
        if ($existing.Count -gt 0) {
            throw "OutDir '$fullPath' already contains files. Use a fresh capture id or pass -Force."
        }
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
        return $fullPath.Substring($repoWithSeparator.Length).Replace([System.IO.Path]::DirectorySeparatorChar, '/').Replace([System.IO.Path]::AltDirectorySeparatorChar, '/')
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

    $Value | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Write-CaptureGitAttributes {
    param([Parameter(Mandatory = $true)][string]$ResolvedOutDir)

    $lines = @(
        '.gitattributes text eol=crlf diff',
        '*.json text eol=crlf diff',
        '*.csv text eol=crlf diff',
        '*.md text eol=crlf diff',
        '*.txt text eol=crlf diff',
        '*.log text eol=crlf diff',
        'checksums.sha256 text eol=crlf diff',
        '*.xlsm -text -diff',
        '*-window/*.png -text -diff'
    )
    Set-Content -LiteralPath (Join-Path $ResolvedOutDir '.gitattributes') -Value $lines -Encoding ASCII
}

function Write-ProgressStep {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedOutDir,
        [Parameter(Mandatory = $true)][string]$Step
    )

    Add-Content -LiteralPath (Join-Path $ResolvedOutDir 'capture-progress.log') -Value ((Get-Date).ToUniversalTime().ToString('o') + ' ' + $Step) -Encoding UTF8
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

function Release-ComObjectIfPresent {
    param($Object)

    if ($null -ne $Object -and [System.Runtime.InteropServices.Marshal]::IsComObject($Object)) {
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($Object)
    }
}

function Ensure-NativeWindowTypes {
    if (([System.Management.Automation.PSTypeName]'OxForms.W006Terminate.NativeMethods').Type) {
        return
    }

    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace OxForms.W006Terminate
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
        public static extern bool PostMessageW(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
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

function Get-WindowTextValue {
    param([System.IntPtr]$Handle)

    $length = [OxForms.W006Terminate.NativeMethods]::GetWindowTextLengthW($Handle)
    $builder = [System.Text.StringBuilder]::new([Math]::Max($length + 1, 256))
    [void][OxForms.W006Terminate.NativeMethods]::GetWindowTextW($Handle, $builder, $builder.Capacity)
    return $builder.ToString()
}

function Get-ClassNameValue {
    param([System.IntPtr]$Handle)

    $builder = [System.Text.StringBuilder]::new(256)
    [void][OxForms.W006Terminate.NativeMethods]::GetClassNameW($Handle, $builder, $builder.Capacity)
    return $builder.ToString()
}

function Get-TopLevelWindows {
    Ensure-NativeWindowTypes
    $windows = [System.Collections.Generic.List[object]]::new()
    $callback = [OxForms.W006Terminate.NativeMethods+EnumWindowsProc]{
        param([System.IntPtr]$Handle, [System.IntPtr]$Param)

        if (-not [OxForms.W006Terminate.NativeMethods]::IsWindowVisible($Handle)) {
            return $true
        }

        $title = Get-WindowTextValue -Handle $Handle
        if ([string]::IsNullOrWhiteSpace($title)) {
            return $true
        }

        $class = Get-ClassNameValue -Handle $Handle
        $processIdValue = [uint32]0
        [void][OxForms.W006Terminate.NativeMethods]::GetWindowThreadProcessId($Handle, [ref]$processIdValue)
        $processName = $null
        try {
            $processName = (Get-Process -Id ([int]$processIdValue) -ErrorAction Stop).ProcessName
        } catch {
            $processName = $null
        }

        $rect = New-Object OxForms.W006Terminate.NativeMethods+RECT
        [void][OxForms.W006Terminate.NativeMethods]::GetWindowRect($Handle, [ref]$rect)

        $windows.Add([ordered]@{
            handle = ('0x{0:X}' -f $Handle.ToInt64())
            title = $title
            class_name = $class
            process_id = [int]$processIdValue
            process_name = $processName
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

    [void][OxForms.W006Terminate.NativeMethods]::EnumWindows($callback, [System.IntPtr]::Zero)
    return @($windows)
}

function Wait-ForOracleWindow {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [int]$TimeoutSeconds = 20
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $matches = @(Get-TopLevelWindows | Where-Object {
            $_.title.IndexOf($Title, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -and
            $_.class_name -eq 'ThunderDFrame' -and
            $_.process_name -eq 'EXCEL'
        })
        if ($matches.Count -gt 0) {
            return $matches[0]
        }
        Start-Sleep -Milliseconds 100
    } while ((Get-Date) -lt $deadline)

    throw "Timed out waiting for UserForm window title containing '$Title'."
}

function Wait-ForOracleWindowClosed {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [int]$TimeoutSeconds = 10
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $matches = @(Get-TopLevelWindows | Where-Object {
            $_.title.IndexOf($Title, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -and
            $_.class_name -eq 'ThunderDFrame' -and
            $_.process_name -eq 'EXCEL'
        })
        if ($matches.Count -eq 0) {
            return $true
        }
        Start-Sleep -Milliseconds 100
    } while ((Get-Date) -lt $deadline)

    return $false
}

function Invoke-PublicWmClose {
    param(
        [Parameter(Mandatory = $true)]$Window,
        [int]$TimeoutSeconds = 12
    )

    Ensure-NativeWindowTypes
    $handle = ConvertFrom-HandleText -Handle ([string]$Window.handle)
    $posted = [OxForms.W006Terminate.NativeMethods]::PostMessageW($handle, 0x0010, [System.IntPtr]::Zero, [System.IntPtr]::Zero)
    $lastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    Start-Sleep -Milliseconds $ActionDelayMilliseconds
    $closed = Wait-ForOracleWindowClosed -Title $windowTitle -TimeoutSeconds $TimeoutSeconds

    return [ordered]@{
        method = 'public_user32_postmessage_wm_close'
        message = 'WM_CLOSE'
        handle = [string]$Window.handle
        post_message_result = [bool]$posted
        last_win32_error = [int]$lastError
        window_closed = [bool]$closed
        status = if ($posted -and $closed) { 'completed' } else { 'blocked_or_ineffective' }
    }
}

function Invoke-CaptureWindow {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedOutDir,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $windowDir = Join-Path $ResolvedOutDir ($Name + '-window')
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
        -CommandPath (Join-Path $ResolvedOutDir ("capture-window-$Name.command.txt")) `
        -StdoutPath (Join-Path $ResolvedOutDir ("capture-window-$Name.stdout.txt")) `
        -StderrPath (Join-Path $ResolvedOutDir ("capture-window-$Name.stderr.txt"))

    $manifestPath = Join-Path $windowDir 'window-capture-manifest.json'
    return Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
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
        [Parameter(Mandatory = $true)]$Workbook,
        [Parameter(Mandatory = $true)][string]$ResolvedOutDir,
        [Parameter(Mandatory = $true)][object[]]$AutomatedInputs,
        [Parameter(Mandatory = $true)][object[]]$Blockers
    )

    $csvPath = Join-Path $ResolvedOutDir 'w006-terminate-lifetime-event-log.csv'
    if (Test-Path -LiteralPath $csvPath -PathType Leaf) {
        Remove-Item -LiteralPath $csvPath -Force
    }

    $sheet = $Workbook.Worksheets.Item('W006TerminateLog')
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
    $scenarios = @($rows | ForEach-Object { $_.scenario } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $terminateRows = @($rows | Where-Object { $_.event_name -eq 'Terminate' })
    $queryCloseRows = @($rows | Where-Object { $_.event_name -eq 'QueryClose' })

    $scenarioSummaries = foreach ($scenario in $requiredScenarios) {
        $scenarioRows = @($rows | Where-Object { $_.scenario -eq $scenario })
        $scenarioTerminateRows = @($scenarioRows | Where-Object { $_.event_name -eq 'Terminate' })
        $scenarioQueryRows = @($scenarioRows | Where-Object { $_.event_name -eq 'QueryClose' })
        [ordered]@{
            scenario = $scenario
            row_count = $scenarioRows.Count
            observed = $scenarioRows.Count -gt 0
            terminate_sequences = @($scenarioTerminateRows | ForEach-Object { $_.sequence })
            terminate_reference_states = @($scenarioTerminateRows | ForEach-Object {
                [ordered]@{
                    sequence = $_.sequence
                    instance_id = $_.instance_id
                    local_ref_state = $_.local_ref_state
                    held_ref_state = $_.held_ref_state
                    default_instance_state = $_.default_instance_state
                    release_phase = $_.release_phase
                }
            })
            query_close = @($scenarioQueryRows | ForEach-Object {
                [ordered]@{
                    sequence = $_.sequence
                    close_origin = $_.close_origin
                    cancel_before = $_.cancel_before
                    cancel_after = $_.cancel_after
                    close_mode = $_.close_mode
                }
            })
            action_sequence = @($scenarioRows | Where-Object { $_.row_kind -eq 'fixture_action' } | ForEach-Object {
                [ordered]@{
                    sequence = $_.sequence
                    event_name = $_.event_name
                    action = $_.action
                    local_ref_state = $_.local_ref_state
                    held_ref_state = $_.held_ref_state
                    release_phase = $_.release_phase
                }
            })
        }
    }

    $eventLog = [ordered]@{
        schema = 'oxforms.office_oracle.w006_terminate_lifetime_event_log.v1'
        bead = $captureBead
        source = [ordered]@{
            workbook = $null
            worksheet = 'W006TerminateLog'
            fixture = 'fixtures/office-oracle/excel-msforms/userforms/terminate-lifetime/fixture.json'
        }
        public_facts = @(
            'docs/specs/FM20_EVENT_FACTS.md records Initialize, Activate, Deactivate, QueryClose, Resize, and Terminate as public-doc lifecycle event names for the W005/W006 surface.',
            'docs/specs/LIFECYCLE_PUMP_MODEL.md section 5 keeps HideRequested, Unloaded, and Terminated as separate lifecycle inputs.',
            'docs/specs/LIFECYCLE_PUMP_MODEL.md section 9 says Hide does not prove termination and Unload does not imply Terminated.'
        )
        observed_facts = [ordered]@{
            row_count = $rows.Count
            event_names = $eventNames
            scenarios = $scenarios
            scenario_summaries = @($scenarioSummaries)
            terminate_rows = @($terminateRows)
            query_close_rows = @($queryCloseRows)
            rows = @($rows)
        }
        assumptions = @(
            'Rows under observed_facts are worksheet rows emitted by repo-owned VBA while real Excel/MSForms handled UserForm lifecycle behavior.',
            'The local_ref_state, held_ref_state, default_instance_state, and release_phase columns are explicit fixture state, not private Office reference counts.',
            'When the modeless system-close scenario is attempted, it uses public user32 PostMessage(WM_CLOSE) against the visible UserForm window as evidence-driving infrastructure.'
        )
        run_observations = @(
            "Live Excel/MSForms export produced $($rows.Count) W006TerminateLog rows.",
            "Observed scenarios: $((@($scenarios) -join ', ')).",
            "Terminate rows exported: $(@($terminateRows).Count)."
        )
        unknowns = @(
            'Default-instance release timing remains unknown because this fixture does not claim a public, reproducible default-instance release operation.',
            'Rows absent from this run remain unobserved and are not negative MSForms facts.',
            'The fixture does not prove every host shutdown, owner shutdown, cancellation, or error path.'
        )
        blockers = @($Blockers)
        clean_room = [ordered]@{
            source = 'Repo-owned fixture source, public Excel/VBIDE automation, public VBA event handlers, optional public user32 window messaging when attempted, and public worksheet export.'
            prohibited = 'No Office internals, decompilation, disassembly, private source, or OxForms output comparison were used.'
        }
        manual_inputs = @()
        automated_inputs = @($AutomatedInputs)
        non_claims = @(
            'This event log is not an exhaustive MSForms lifecycle parity claim.',
            'This event log is not an OxForms output comparison artifact.',
            'No OxForms runtime Terminate timing behavior is implemented or claimed by this oracle artifact.'
        )
    }

    $jsonPath = Join-Path $ResolvedOutDir 'w006-terminate-lifetime-event-log.json'
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

function Get-FixtureHashes {
    param(
        [Parameter(Mandatory = $true)]$Fixture,
        [Parameter(Mandatory = $true)][string]$FixtureRoot,
        [Parameter(Mandatory = $true)][string]$FixturePath
    )

    $codePath = Join-Path $FixtureRoot ([string]$Fixture.codeBehind.sourcePath)
    $modulePath = Join-Path $FixtureRoot ([string]$Fixture.workbook.additionalModuleSourcePath)
    $toolPath = Join-Path $repoRoot 'tools\office-oracle\Capture-W006TerminateLifetime.ps1'

    return [ordered]@{
        manifest = [ordered]@{
            path = ConvertTo-RepoRelative $FixturePath
            sha256 = Get-Sha256Hex -Path $FixturePath
        }
        form_code_behind = [ordered]@{
            path = ConvertTo-RepoRelative $codePath
            sha256 = Get-Sha256Hex -Path $codePath
        }
        standard_module_extra = [ordered]@{
            path = ConvertTo-RepoRelative $modulePath
            sha256 = Get-Sha256Hex -Path $modulePath
        }
        capture_tool = [ordered]@{
            path = ConvertTo-RepoRelative $toolPath
            sha256 = Get-Sha256Hex -Path $toolPath
        }
    }
}

function New-RunSummary {
    param(
        [Parameter(Mandatory = $true)][string]$CaptureId,
        [Parameter(Mandatory = $true)]$EventLog,
        [Parameter(Mandatory = $true)][object[]]$Blockers
    )

    $scenarioCoverage = [ordered]@{}
    foreach ($scenario in $requiredScenarios) {
        $summary = @($EventLog.scenario_summaries | Where-Object { $_.scenario -eq $scenario })[0]
        $scenarioCoverage[$scenario] = if ($null -ne $summary -and [int]$summary.row_count -gt 0) { 'observed_rows' } else { 'not_observed_in_this_run' }
    }

    return [ordered]@{
        schema = 'oxforms.office_oracle.w006_terminate_lifetime_run_summary.v1'
        bead = $captureBead
        capture_id = $CaptureId
        status = 'captured'
        row_count = $EventLog.row_count
        event_names = $EventLog.event_names
        scenario_coverage = $scenarioCoverage
        terminate_row_count = @($EventLog.terminate_rows).Count
        scenario_summaries = @($EventLog.scenario_summaries)
        blockers = @($Blockers)
        trace_replay_implications = @(
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 5: future object-lifetime rows need ordered sequence, parent_row_id when causal nesting exists, and nesting_depth.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 9: hide_form, unload_form, fire_vba_event, and platform close work must keep effect_requested separate from effect_completed.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 11: lifecycle_pump rows must keep Show, close, hide, unload, and terminate as separate trace concepts.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 14: validators must continue checking reducer/effect/dispatch causal ordering.'
        )
        non_claims = @(
            'Observed Terminate rows are tied to this fixture reference-state sequence only.',
            'No OxForms runtime Terminate behavior is implemented or claimed.',
            'Unloaded and Terminated remain separate concepts; this summary does not collapse them.'
        )
    }
}

function New-BlockedRunSummary {
    param(
        [Parameter(Mandatory = $true)][string]$CaptureId,
        [Parameter(Mandatory = $true)][object[]]$Blockers
    )

    return [ordered]@{
        schema = 'oxforms.office_oracle.w006_terminate_lifetime_run_summary.v1'
        bead = $captureBead
        capture_id = $CaptureId
        status = 'blocked'
        row_count = 0
        event_names = @()
        scenario_coverage = [ordered]@{}
        terminate_row_count = 0
        blockers = @($Blockers)
        non_claims = @(
            'No MSForms Terminate timing is inferred from this blocker.',
            'No OxForms runtime Terminate behavior is implemented or claimed.'
        )
    }
}

function New-Manifest {
    param(
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][string]$ResolvedOutDir,
        [Parameter(Mandatory = $true)][string]$CaptureId,
        [Parameter(Mandatory = $true)]$Fixture,
        [Parameter(Mandatory = $true)]$FixtureHashes,
        [Parameter(Mandatory = $true)][string]$WorkbookPath,
        $ExcelInfo,
        $EventLog,
        [string]$RunSummaryPath,
        [Parameter(Mandatory = $true)][object[]]$Blockers
    )

    $commandLogCandidates = @(
        (Join-Path $ResolvedOutDir 'capture.command.txt'),
        (Join-Path $ResolvedOutDir 'capture-progress.log'),
        (Join-Path $ResolvedOutDir 'generate-workbook.command.txt'),
        (Join-Path $ResolvedOutDir 'generate-workbook.stdout.txt'),
        (Join-Path $ResolvedOutDir 'generate-workbook.stderr.txt'),
        (Join-Path $ResolvedOutDir 'capture-window-modeless-close.command.txt'),
        (Join-Path $ResolvedOutDir 'capture-window-modeless-close.stdout.txt'),
        (Join-Path $ResolvedOutDir 'capture-window-modeless-close.stderr.txt')
    )

    return [ordered]@{
        schema = 'oxforms.office_oracle.w006_terminate_lifetime_capture.v1'
        bead = $captureBead
        capture_id = $CaptureId
        status = $Status
        fixture = [ordered]@{
            id = $Fixture.id
            inputs = $FixtureHashes
        }
        commands = [ordered]@{
            capture = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'capture.command.txt')
            generator = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'generate-workbook.command.txt')
            modeless_window_capture = if (Test-Path -LiteralPath (Join-Path $ResolvedOutDir 'capture-window-modeless-close.command.txt') -PathType Leaf) { ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'capture-window-modeless-close.command.txt') } else { $null }
            progress = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'capture-progress.log')
            rerun_note = 'Run tools/office-oracle/Capture-W006TerminateLifetime.ps1 from the repository root. It generates the workbook, drives the macro scenarios, optionally sends public WM_CLOSE for the modeless close scenario, exports W006TerminateLog, writes manifests, and checksums artifacts. Skip flags preserve explicit blockers for paths that cannot be exported honestly.'
        }
        platform = [ordered]@{
            os = [System.Environment]::OSVersion.VersionString
            is_windows = $true
            powershell = $PSVersionTable.PSVersion.ToString()
        }
        excel = $ExcelInfo
        artifacts = [ordered]@{
            generated_workbook = if (Test-Path -LiteralPath $WorkbookPath -PathType Leaf) {
                [ordered]@{
                    path = ConvertTo-RepoRelative $WorkbookPath
                    sha256 = Get-Sha256Hex -Path $WorkbookPath
                }
            } else {
                $null
            }
            run_summary = if ($RunSummaryPath) { ConvertTo-RepoRelative $RunSummaryPath } else { $null }
            event_log_json = if ($null -ne $EventLog) { $EventLog.json } else { $null }
            event_log_csv = if ($null -ne $EventLog) { $EventLog.csv } else { $null }
            input_actions = if (Test-Path -LiteralPath (Join-Path $ResolvedOutDir 'input-actions.json') -PathType Leaf) { ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'input-actions.json') } else { $null }
            modeless_close_window_capture_manifest = if (Test-Path -LiteralPath (Join-Path $ResolvedOutDir 'modeless-close-window\window-capture-manifest.json') -PathType Leaf) { ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'modeless-close-window\window-capture-manifest.json') } else { $null }
            blocker = if (Test-Path -LiteralPath (Join-Path $ResolvedOutDir 'blocker.json') -PathType Leaf) { ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'blocker.json') } else { $null }
            checksums = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'checksums.sha256')
            command_logs = Get-ExistingRepoRelativeFiles -Paths $commandLogCandidates
        }
        observed_facts = if ($null -ne $EventLog) {
            [ordered]@{
                row_count = $EventLog.row_count
                event_names = $EventLog.event_names
                scenarios = $EventLog.scenarios
                scenario_summaries = @($EventLog.scenario_summaries)
                terminate_rows = @($EventLog.terminate_rows)
                terminate_row_count = @($EventLog.terminate_rows).Count
                manual_inputs = @()
                input_method = 'Excel/VBA macro scenario calls, plus public user32 PostMessage(WM_CLOSE) only when the modeless close branch is attempted.'
            }
        } else {
            [ordered]@{
                row_count = 0
                event_names = @()
                scenarios = @()
                scenario_summaries = @()
                terminate_rows = @()
                terminate_row_count = 0
                manual_inputs = @()
                input_method = 'not completed'
            }
        }
        run_observations = if ($null -ne $EventLog) {
            @(
                "Live Excel/MSForms export produced $($EventLog.row_count) W006TerminateLog rows.",
                "Observed scenarios: $((@($EventLog.scenarios) -join ', ')).",
                "Terminate rows exported: $(@($EventLog.terminate_rows).Count)."
            )
        } else {
            @(
                'No worksheet rows were exported before the run blocked.',
                "Blocked surfaces: $((@($Blockers | ForEach-Object { $_.surface }) -join ', '))."
            )
        }
        public_facts = @(
            'docs/specs/FM20_EVENT_FACTS.md records Terminate as a public-doc UserForm lifecycle event name.',
            'docs/specs/LIFECYCLE_PUMP_MODEL.md section 9 separates Hide, logical Unload, and object-lifetime Terminate.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 11 requires lifecycle_pump rows to keep Show, close, hide, unload, and terminate separate.'
        )
        blockers = @($Blockers)
        trace_replay_implications = @(
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 5: ordered sequence is decisive; parent_row_id and nesting_depth are required where nested/reentrant causality exists.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 9: hide_form, unload_form, fire_vba_event, and platform close work must keep effect_requested separate from effect_completed.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 11: lifecycle_pump rows must carry close/query/hide/unload/terminate reason and keep Unloaded and Terminated separate.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 14: validators must check parent/nesting and reducer/effect/dispatch causal ordering.'
        )
        warnings = @(
            'This is black-box Excel/MSForms event evidence only; no OxForms output was compared.',
            'The fixture reference-state columns are explicit repo-owned VBA state, not private Office reference counts.',
            'Missing event rows are unobserved rows in this run, not negative facts about all MSForms behavior.',
            'Desktop focus, Excel/MSForms version, macro security, and window-message policy can affect observed rows.'
        )
        assumptions = @(
            'The generated workbook macros and event handlers are repo-owned instrumentation around live Excel/MSForms behavior.',
            'Public WM_CLOSE is treated as a modeless close request only when it is sent to the visible top-level UserForm window and the run can still export its worksheet evidence.'
        )
        unknowns = @(
            'Default-instance release timing remains unknown in this artifact.',
            'Host shutdown, owner shutdown, cancellation, and error paths remain unknown unless future evidence records them.'
        )
        clean_room = [ordered]@{
            source = 'Repo-owned fixture input generated through public Excel/VBIDE automation, public VBA event handlers, optional public user32 window messaging when attempted, and local command/progress logs.'
            prohibited = 'No Office internals, decompilation, disassembly, non-public source, or OxForms output comparison were used.'
        }
        non_claims = @(
            'No OxForms runtime Terminate timing behavior is implemented or claimed.',
            'No Terminate timing parity is inferred from W005 row tails.',
            'Unloaded and Terminated remain separate trace/replay concepts.'
        )
    }
}

function Write-InputActions {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedOutDir,
        [Parameter(Mandatory = $true)][object[]]$Actions,
        [Parameter(Mandatory = $true)][object[]]$Blockers
    )

    Write-JsonFile -Path (Join-Path $ResolvedOutDir 'input-actions.json') -Value ([ordered]@{
        schema = 'oxforms.office_oracle.w006_terminate_lifetime_input_actions.v1'
        bead = $captureBead
        manual_inputs = @()
        automated_inputs = @($Actions)
        blockers = @($Blockers)
        notes = @(
            'Excel.Run macro calls and optional public user32 PostMessage(WM_CLOSE) are evidence-driving infrastructure only.',
            'Reference release steps are emitted by repo-owned VBA fixture rows before/after Set ... = Nothing call sites.'
        )
    })
}

function Write-CaptureReadme {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedOutDir,
        [Parameter(Mandatory = $true)]$Manifest
    )

    $blockerLines = @()
    if (@($Manifest.blockers).Count -gt 0) {
        $blockerLines += ''
        $blockerLines += '## Blockers'
        $blockerLines += ''
        foreach ($blocker in @($Manifest.blockers)) {
            $blockerLines += ('- `' + [string]$blocker['surface'] + '`: ' + [string]$blocker['reason'])
        }
    }

    $lines = @(
        '# W006 Terminate Lifetime Oracle Capture',
        '',
        "Capture id: $($Manifest.capture_id)",
        ('Bead: `' + [string]$Manifest.bead + '`'),
        "Status: $($Manifest.status)",
        '',
        'This directory contains black-box Excel/MSForms evidence for focused UserForm object-lifetime scenarios. It is not an OxForms output comparison and it does not claim exhaustive lifecycle parity.',
        '',
        '## Observed Facts',
        '',
        '- `w006-terminate-lifetime-event-log.json` and `.csv` contain worksheet rows emitted by the fixture VBA handlers and action macros.',
        '- `input-actions.json` records macro calls, optional public window-message attempts, and explicit skipped-path blockers; `manual_inputs` is empty.',
        '- Terminate rows, when present, include the fixture reference-state columns visible at handler entry.',
        '',
        '## Run Observations',
        ''
    ) + @($Manifest.run_observations | ForEach-Object { "- $_" }) + @(
        '',
        '## Assumptions',
        '',
        '- Fixture reference-state columns are explicit repo-owned VBA state, not private Office reference counts.',
        '- Public `WM_CLOSE` is treated as a modeless close request only when it is sent to the visible UserForm window and the run can still export its worksheet evidence.'
    ) + $blockerLines + @(
        '',
        '## Non-claims',
        '',
        '- No OxForms runtime Terminate timing behavior is implemented or claimed.',
        '- Missing rows are unobserved in this run, not negative MSForms facts.',
        '- `Unloaded` and `Terminated` remain separate trace/replay concepts.',
        '',
        '## Clean-room Note',
        '',
        'The capture used repo-owned fixture sources, public Excel/VBIDE automation, public VBA event handlers, optional public user32 window messaging when attempted, and public worksheet export. It did not use private Office internals, decompilation, disassembly, or OxForms output comparison.'
    )
    Set-Content -LiteralPath (Join-Path $ResolvedOutDir 'README.md') -Value $lines -Encoding UTF8
}

$fixtureRoot = Resolve-InRepoPath $FixtureDir
$fixturePath = Join-Path $fixtureRoot 'fixture.json'
if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) {
    throw "Fixture manifest not found: $fixturePath"
}
$fixture = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json

if ($DryRun) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'tools\office-oracle\Open-ExcelUserFormFixture.ps1') -FixtureDir $fixtureRoot -DryRun
    exit $LASTEXITCODE
}

$resolvedOutDir = Resolve-CaptureDir -Directory $OutDir
$captureId = Split-Path -Leaf $resolvedOutDir
$workbookPath = Join-Path $resolvedOutDir ([string]$fixture.workbook.fileName)
$fixtureHashes = Get-FixtureHashes -Fixture $fixture -FixtureRoot $fixtureRoot -FixturePath $fixturePath
$actions = [System.Collections.Generic.List[object]]::new()
$blockers = [System.Collections.Generic.List[object]]::new()
$excel = $null
$workbook = $null
$eventLog = $null
$runSummaryPath = $null
$excelInfo = $null

Write-CaptureGitAttributes -ResolvedOutDir $resolvedOutDir
Set-Content -LiteralPath (Join-Path $resolvedOutDir 'capture.command.txt') -Value ([System.Environment]::CommandLine) -Encoding UTF8
Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'capture_directory_prepared'
Set-Location $repoRoot

try {
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
    $excel.Run('ClearW006TerminateLog')
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'log_cleared'

    $macroSequence = 1
    foreach ($macro in @('RunW006TerminateHideHeldScenario', 'RunW006TerminateUnloadHeldScenario')) {
        $actions.Add([ordered]@{
            sequence = $macroSequence
            method = 'excel_vba_public_macro'
            action = $macro
            manual = $false
            target_intent = 'Drive UserForm Terminate lifetime scenario through repo-owned VBA fixture macro.'
        }) | Out-Null
        $macroSequence++
        $excel.Run($macro)
        Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('macro_completed=' + $macro)
        Start-Sleep -Milliseconds $ActionDelayMilliseconds
    }

    if ($SkipModelessCloseAttempt) {
        $blockers.Add([ordered]@{
            surface = 'modeless_system_close_held_release'
            reason = 'This stable row capture was run with -SkipModelessCloseAttempt after the live public WM_CLOSE branch made Excel COM unavailable before the held-reference release/export step could complete.'
            detail = 'The modeless close branch remains blocked unless a future capture can close the visible modeless UserForm and still export W006TerminateLog after releasing the held reference.'
            non_claim = 'No modeless system-close Terminate timing is claimed from this stable row capture.'
        }) | Out-Null
        $actions.Add([ordered]@{
            sequence = $macroSequence
            method = 'capture_policy'
            action = 'skip_modeless_system_close_attempt'
            manual = $false
            target_intent = 'Preserve stable Hide/Unload row capture while recording modeless system close as blocked.'
        }) | Out-Null
        $macroSequence++
        Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'modeless_close_attempt_skipped_with_blocker'
    } else {
        $actions.Add([ordered]@{
            sequence = $macroSequence
            method = 'excel_vba_public_macro'
            action = 'StartW006TerminateModelessCloseHeldScenario'
            manual = $false
            target_intent = 'Open modeless UserForm with only the global held fixture reference remaining before public WM_CLOSE.'
        }) | Out-Null
        $macroSequence++
        $excel.Run('StartW006TerminateModelessCloseHeldScenario')
        Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'modeless_close_scenario_started'
        Start-Sleep -Milliseconds ($ActionDelayMilliseconds * 2)

        $modelessWindow = Wait-ForOracleWindow -Title $windowTitle -TimeoutSeconds 20
        try {
            [void](Invoke-CaptureWindow -ResolvedOutDir $resolvedOutDir -Name 'modeless-close')
            Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'modeless_close_window_captured'
        } catch {
            $blockers.Add([ordered]@{
                surface = 'modeless_close_window_manifest'
                reason = 'The external Capture-Window helper could not preserve a modeless close window manifest, but the in-process public window enumeration already found the UserForm handle used for WM_CLOSE.'
                detail = $_.Exception.Message
                non_claim = 'Window-manifest failure is not treated as a Terminate timing observation.'
            }) | Out-Null
            Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('modeless_close_window_capture_blocked=' + $_.Exception.Message)
        }
        $closeResult = Invoke-PublicWmClose -Window $modelessWindow -TimeoutSeconds 12
        $actions.Add([ordered]@{
            sequence = $macroSequence
            method = 'public_user32_postmessage_wm_close'
            action = 'wm_close'
            manual = $false
            target_intent = 'Modeless UserForm close request while the fixture global held reference remains active.'
            result = $closeResult
        }) | Out-Null
        $macroSequence++
        Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('wm_close_status=' + $closeResult.status)

        if (-not [bool]$closeResult.window_closed) {
            $blockers.Add([ordered]@{
                surface = 'modeless_system_close_held_release'
                reason = 'Public PostMessage(WM_CLOSE) did not close the visible modeless UserForm window within the bounded wait.'
                detail = $closeResult
                non_claim = 'No modeless system-close Terminate timing is claimed unless matching rows appear in the event log.'
            }) | Out-Null
            $excel.Run('CleanupW006TerminateHeldForm')
            Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'modeless_close_cleanup_unload_completed'
        }

        $actions.Add([ordered]@{
            sequence = $macroSequence
            method = 'excel_vba_public_macro'
            action = 'FinishW006TerminateModelessCloseHeldScenario'
            manual = $false
            target_intent = 'Release the global held reference after the modeless close attempt.'
        }) | Out-Null
        $macroSequence++
        $excel.Run('FinishW006TerminateModelessCloseHeldScenario')
        Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'modeless_close_scenario_finished'
        Start-Sleep -Milliseconds $ActionDelayMilliseconds
    }

    if ($SkipModalReturnAttempt) {
        foreach ($scenarioName in @('modal_hide_return_held_release', 'modal_unload_return_held_release')) {
            $blockers.Add([ordered]@{
                surface = $scenarioName
                reason = 'This stable row capture was run with -SkipModalReturnAttempt after the modal auto-return macro path left Excel blocked inside the modal Show call before the capture could export evidence.'
                detail = 'The fixture plan distinguishes the modal Hide-return and modal Unload-return paths, but this run does not claim either path because public automation did not produce a bounded modal return/export sequence.'
                non_claim = "No $scenarioName Terminate timing is claimed from this stable row capture."
            }) | Out-Null
        }
        $actions.Add([ordered]@{
            sequence = $macroSequence
            method = 'capture_policy'
            action = 'skip_modal_return_attempts'
            manual = $false
            target_intent = 'Preserve stable Hide/Unload row capture while recording modal return scenarios as blocked.'
        }) | Out-Null
        $macroSequence++
        Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'modal_return_attempts_skipped_with_blockers'
    } else {
        foreach ($macro in @('RunW006TerminateModalHideHeldScenario', 'RunW006TerminateModalUnloadHeldScenario')) {
            $actions.Add([ordered]@{
                sequence = $macroSequence
                method = 'excel_vba_public_macro'
                action = $macro
                manual = $false
                target_intent = 'Drive modal UserForm return and reference-release scenario through repo-owned VBA fixture macro.'
            }) | Out-Null
            $macroSequence++
            $excel.Run($macro)
            Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('macro_completed=' + $macro)
            Start-Sleep -Milliseconds $ActionDelayMilliseconds
        }
    }

    Write-InputActions -ResolvedOutDir $resolvedOutDir -Actions @($actions) -Blockers @($blockers)
    $eventLog = Export-WorksheetLog -Workbook $workbook -ResolvedOutDir $resolvedOutDir -AutomatedInputs @($actions) -Blockers @($blockers)
    $eventLogPath = Resolve-InRepoPath $eventLog.json
    $eventLogObject = Get-Content -Raw -LiteralPath $eventLogPath | ConvertFrom-Json
    $eventLogObject.source.workbook = ConvertTo-RepoRelative $workbookPath
    Write-JsonFile -Value $eventLogObject -Path $eventLogPath
    $eventLog = [ordered]@{
        csv = $eventLog.csv
        json = $eventLog.json
        row_count = $eventLog.row_count
        event_names = $eventLog.event_names
        scenarios = $eventLog.scenarios
        scenario_summaries = $eventLog.scenario_summaries
        terminate_rows = $eventLog.terminate_rows
        rows = $eventLog.rows
    }

    $runSummaryPath = Join-Path $resolvedOutDir 'run-summary.json'
    Write-JsonFile -Path $runSummaryPath -Value (New-RunSummary -CaptureId $captureId -EventLog $eventLog -Blockers @($blockers))
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('event_log_exported_rows=' + $eventLog.row_count)

    $workbook.Save()
    $workbook.Close($true)
    Release-ComObjectIfPresent $workbook
    $workbook = $null
    $excel.Quit()
    Release-ComObjectIfPresent $excel
    $excel = $null
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'excel_closed_before_manifest'

    $manifest = New-Manifest -Status 'captured' -ResolvedOutDir $resolvedOutDir -CaptureId $captureId -Fixture $fixture -FixtureHashes $fixtureHashes -WorkbookPath $workbookPath -ExcelInfo $excelInfo -EventLog $eventLog -RunSummaryPath $runSummaryPath -Blockers @($blockers)
    Write-JsonFile -Path (Join-Path $resolvedOutDir 'oracle-capture-manifest.json') -Value $manifest
    Write-CaptureReadme -ResolvedOutDir $resolvedOutDir -Manifest $manifest
    Write-Checksums -ResolvedOutDir $resolvedOutDir

    Write-Host "W006 Terminate lifetime capture complete: $resolvedOutDir"
    Write-Host "Rows: $($eventLog.row_count)"
    Write-Host "Terminate rows: $(@($eventLog.terminate_rows).Count)"
} catch {
    $progressPath = Join-Path $resolvedOutDir 'capture-progress.log'
    $progressEntries = if (Test-Path -LiteralPath $progressPath -PathType Leaf) {
        @(Get-Content -LiteralPath $progressPath)
    } else {
        @()
    }
    $lastProgressEntry = if ($progressEntries.Count -gt 0) {
        [string]$progressEntries[$progressEntries.Count - 1]
    } else {
        '<no progress log entry>'
    }

    $blocker = [ordered]@{
        schema = 'oxforms.office_oracle.w006_terminate_lifetime_blocker.v1'
        bead = $captureBead
        capture_id = $captureId
        captured_at_utc = (Get-Date).ToUniversalTime().ToString('o')
        surface = 'terminate_lifetime_oracle_capture'
        status = 'blocked'
        reason = $_.Exception.Message
        category = 'public_excel_vbide_or_windows_window_message_capture_blocker'
        facts = @(
            'The repo-owned fixture manifest and source files were loaded before the live capture path.',
            ('Last capture-progress entry: ' + $lastProgressEntry),
            'No worksheet event-log rows are included in this blocker artifact unless an event log file is listed in the manifest.'
        )
        assumptions = @(
            'The failure belongs to public Excel/VBIDE automation, public Windows window-message automation, or the fixture code path named by the exception.'
        )
        unknowns = @(
            'No Hide, Unload, modeless close, modal return, held-reference, or reference-release Terminate timing is proven by this blocker.',
            'Rows absent from this run remain unknown and are not negative MSForms facts.'
        )
        blocked_recording_fields = @(
            'event sequence',
            'scenario',
            'instance id',
            'show mode',
            'Hide action rows',
            'Unload action rows',
            'modeless close rows',
            'modal return rows',
            'held reference state',
            'reference release phase',
            'QueryClose values',
            'Terminate rows'
        )
        trace_replay_implications = @(
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 5 still requires ordered sequence, parent_row_id, and nesting_depth where causal nesting exists.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 9 still requires effect_requested and effect_completed rows to remain separate.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 11 still requires lifecycle_pump rows to keep Show, close, hide, unload, and terminate separate.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 14 still requires validators to check causal ordering.'
        )
        clean_room = [ordered]@{
            source = 'Repo-owned fixture input, public Excel/VBIDE automation attempt, public user32 window messaging attempt, and local command/progress logs.'
            prohibited = 'No Office internals, decompilation, disassembly, non-public source, or OxForms output comparison were used.'
        }
        non_claims = @(
            'No OxForms runtime behavior is implemented or claimed.',
            'No Terminate timing is inferred from this blocker.',
            'No missing event row is treated as a negative MSForms fact.'
        )
    }
    $blockers.Add($blocker) | Out-Null
    Write-JsonFile -Path (Join-Path $resolvedOutDir 'blocker.json') -Value $blocker
    Write-InputActions -ResolvedOutDir $resolvedOutDir -Actions @($actions) -Blockers @($blockers)
    $runSummaryPath = Join-Path $resolvedOutDir 'run-summary.json'
    Write-JsonFile -Path $runSummaryPath -Value (New-BlockedRunSummary -CaptureId $captureId -Blockers @($blockers))
    if ($null -ne $workbook) {
        try {
            $workbook.Save()
            $workbook.Close($true)
        } catch {
            Write-Warning "Failed to close workbook before blocked manifest: $($_.Exception.Message)"
        }
        Release-ComObjectIfPresent $workbook
        $workbook = $null
    }
    if ($null -ne $excel) {
        try {
            $excel.Quit()
        } catch {
            Write-Warning "Failed to quit Excel before blocked manifest: $($_.Exception.Message)"
        }
        Release-ComObjectIfPresent $excel
        $excel = $null
    }
    $manifest = New-Manifest -Status 'blocked' -ResolvedOutDir $resolvedOutDir -CaptureId $captureId -Fixture $fixture -FixtureHashes $fixtureHashes -WorkbookPath $workbookPath -ExcelInfo $excelInfo -EventLog $eventLog -RunSummaryPath $runSummaryPath -Blockers @($blockers)
    Write-JsonFile -Path (Join-Path $resolvedOutDir 'oracle-capture-manifest.json') -Value $manifest
    Write-CaptureReadme -ResolvedOutDir $resolvedOutDir -Manifest $manifest
    Write-Checksums -ResolvedOutDir $resolvedOutDir
    Write-Host "W006 Terminate lifetime capture blocked: $resolvedOutDir"
    Write-Host "Blocker: $($_.Exception.Message)"
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
