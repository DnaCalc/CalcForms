[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$runner = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'Capture-MSFormsMemberOracle.ps1'))
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $runner,
    [ref]$tokens,
    [ref]$parseErrors
)
if ($parseErrors.Count -ne 0) {
    throw "Capture runner has PowerShell parse errors: $($parseErrors.Message -join '; ')"
}

foreach ($functionName in @(
    'Normalize-Lf',
    'Assert-NoReparsePointInPath',
    'Get-Sha256',
    'Get-StreamSha256',
    'Read-SharedUtf8Lines',
    'Get-BytesSha256',
    'Assert-FileSha256',
    'Read-FrozenUtf8Json',
    'Get-RequiredProperty',
    'Invoke-ExternalCommand',
    'Invoke-HashPinnedChildScript',
    'Release-ComObject',
    'Initialize-NativeMethods',
    'Open-HashPinnedWorkbook',
    'Add-CleanupFailure',
    'ConvertTo-ExactUtcDateTimeOffset',
    'Start-PrivateProcessWatchdog',
    'Authorize-PrivateProcessExpectedExit',
    'Complete-PrivateProcessWatchdog',
    'Stop-ExactPrivateProcess'
)) {
    $definition = @($ast.FindAll(
        {
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $functionName
        },
        $true
    ))
    if ($definition.Count -ne 1) {
        throw "Expected exactly one $functionName definition, found $($definition.Count)."
    }
    Invoke-Expression $definition[0].Extent.Text
}

$jsonUtc = ('{"value":"2026-08-23T23:39:10.7676857Z"}' | ConvertFrom-Json).value
if ($jsonUtc -isnot [DateTime] -or $jsonUtc.Kind -ne [DateTimeKind]::Utc) {
    throw 'The JSON timestamp regression fixture did not exercise PowerShell DateTime coercion.'
}
$exactJsonUtc = ConvertTo-ExactUtcDateTimeOffset -Value $jsonUtc -Label 'JSON UTC regression fixture'
$exactStringUtc = ConvertTo-ExactUtcDateTimeOffset -Value '2026-08-23T23:39:10.7676857Z' -Label 'String UTC regression fixture'
if ($exactJsonUtc.UtcTicks -ne 639231251507676857 -or $exactStringUtc.UtcTicks -ne $exactJsonUtc.UtcTicks) {
    throw 'Exact UTC conversion lost fractional ticks or applied the local timezone twice.'
}

foreach ($callerName in @('New-OracleWorkbook', 'Invoke-LiveOracle')) {
    $caller = @($ast.FindAll(
        {
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $callerName
        },
        $true
    ))
    if ($caller.Count -ne 1) { throw "Expected exactly one $callerName definition, found $($caller.Count)." }
    $callerText = $caller[0].Extent.Text
    if ($callerText -notmatch '\[System\.Collections\.Generic\.List\[string\]\]::new\(\)') {
        throw "$callerName does not aggregate cleanup failures."
    }
    $phasePrefix = if ($callerName -eq 'New-OracleWorkbook') { 'Build' } else { 'Live' }
    $catchClauses = @($caller[0].FindAll(
        {
            param($node)
            $node -is [System.Management.Automation.Language.CatchClauseAst]
        },
        $true
    ))
    $cleanupPaths = @(
        [pscustomobject]@{
            failure = "$phasePrefix shutdown request"
            emergency = "$phasePrefix shutdown request emergency exact-process cleanup"
        },
        [pscustomobject]@{
            failure = "$phasePrefix shutdown watchdog completion"
            emergency = "$phasePrefix shutdown watchdog emergency exact-process cleanup"
        },
        [pscustomobject]@{
            failure = "$phasePrefix shutdown wait"
            emergency = "$phasePrefix shutdown wait emergency exact-process cleanup"
        }
    )
    foreach ($cleanupPath in $cleanupPaths) {
        $failureOperation = [string]$cleanupPath.failure
        $emergencyOperation = [string]$cleanupPath.emergency
        $matchingCatch = @($catchClauses | Where-Object {
            $_.Extent.Text.Contains("-Operation '$failureOperation'", [System.StringComparison]::Ordinal) -and
            $_.Extent.Text.Contains('Stop-ExactPrivateProcess', [System.StringComparison]::Ordinal) -and
            $_.Extent.Text.Contains("-Operation '$emergencyOperation'", [System.StringComparison]::Ordinal)
        })
        if ($matchingCatch.Count -ne 1) {
            throw "$callerName does not exact-clean and aggregate the '$failureOperation' catch path."
        }
    }
    $phaseCompletionOperation = "$phasePrefix phase watchdog completion"
    $phaseCompletionEmergency = "$phasePrefix phase watchdog completion emergency exact-process cleanup"
    $phaseCompletionCatch = @($catchClauses | Where-Object {
        $_.Extent.Text.Contains('$phaseWatchdogCompletionFailed = $true', [System.StringComparison]::Ordinal) -and
        $_.Extent.Text.Contains("-Operation '$phaseCompletionOperation'", [System.StringComparison]::Ordinal) -and
        $_.Extent.Text.Contains('Stop-ExactPrivateProcess', [System.StringComparison]::Ordinal) -and
        $_.Extent.Text.Contains("-Operation '$phaseCompletionEmergency'", [System.StringComparison]::Ordinal)
    })
    if (-not $callerText.Contains('$phaseWatchdogCompletionFailed = $false', [System.StringComparison]::Ordinal) -or
        -not $callerText.Contains('if (-not $phaseWatchdogCompletionFailed -and $ownsExcelProcess', [System.StringComparison]::Ordinal) -or
        $phaseCompletionCatch.Count -ne 1) {
        throw "$callerName can arm an orderly shutdown watchdog after phase-watchdog completion failed or remained non-quiescent."
    }
}

$runnerText = [System.IO.File]::ReadAllText($runner)
foreach ($forbiddenActivation in @(
    'New-Object -ComObject Excel.Application',
    'Marshal]::GetActiveObject',
    'GetActiveObject(',
    'GetRunningObjectTable'
)) {
    if ($runnerText.Contains($forbiddenActivation, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Capture runner contains forbidden non-owned Excel activation text: $forbiddenActivation"
    }
}

$safeLaunchDefinition = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Start-OwnedSafeExcelProcess'
    },
    $true
))[0].Extent.Text
foreach ($requiredSafeLaunchText in @(
    '[OxForms.MemberOracle.SafeModeExcelContainment]::Launch($excelPath)',
    '$containment.ContainsProcess($process.Handle)',
    'Get-RunningExcelProcessIds',
    'Get-StreamSha256 $stream',
    '$identity[''startup_mode''] = ''safe''',
    '$identity[''launch_arguments''] = @(''/safe'')',
    '$identity[''containment_method''] = ''create_process_suspended_then_job_object_kill_on_close''',
    '$identity[''containment_membership_verified''] = $true',
    '$identity[''process_exclusivity_observation'']'
)) {
    if (-not $safeLaunchDefinition.Contains($requiredSafeLaunchText, [System.StringComparison]::Ordinal)) {
        throw "Direct safe-mode Excel launch lacks required behavior: $requiredSafeLaunchText"
    }
}
if ($safeLaunchDefinition.Contains('Get-ObservedSafeExcelLaunch', [System.StringComparison]::Ordinal)) {
    throw 'OS command-line observation runs before either phase watchdog is armed.'
}

$observedLaunchDefinition = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Get-ObservedSafeExcelLaunch'
    },
    $true
))[0].Extent.Text
foreach ($requiredObservationText in @(
    'Get-CimInstance',
    '-ClassName Win32_Process',
    '-OperationTimeoutSec 5',
    'ParseCommandLine($commandLine)',
    '$arguments.Count -ne 2',
    '[string]$arguments[1] -cne ''/safe'''
)) {
    if (-not $observedLaunchDefinition.Contains($requiredObservationText, [System.StringComparison]::Ordinal)) {
        throw "Safe-mode command-line observation lacks required behavior: $requiredObservationText"
    }
}

$loadedModuleResolverDefinition = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Resolve-LoadedModulePath'
    },
    $true
))[0].Extent.Text
foreach ($requiredVfsMapping in @(
    "marker = 'ProgramFilesCommonX64'",
    "marker = 'ProgramFilesCommonX86'",
    "marker = 'System'",
    "marker = 'SystemX86'",
    "marker = 'Windows'"
)) {
    if (-not $loadedModuleResolverDefinition.Contains($requiredVfsMapping, [System.StringComparison]::Ordinal)) {
        throw "Loaded-module resolution lacks deterministic Click-to-Run VFS mapping: $requiredVfsMapping"
    }
}

$nativeDefinition = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Initialize-NativeMethods'
    },
    $true
))[0].Extent.Text
foreach ($requiredNativeText in @(
    'SafeModeExcelContainment',
    'JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE',
    'CREATE_SUSPENDED',
    'CreateJobObjectW',
    'SetInformationJobObject',
    'CreateProcessW',
    'AssignProcessToJobObject',
    'IsProcessInJob',
    'previousSuspendCount != 1',
    'TerminateJobObject',
    'TerminateProcess',
    'WaitForSingleObject',
    'EnumerateOwnedWindows',
    'const int WindowLimit = 512',
    'EnumWindows(',
    'EnumChildWindows(',
    'IsWindowEnabled(',
    'AccessibleObjectFromWindow',
    'CommandLineToArgvW',
    'LocalFree(argv)'
)) {
    if (-not $nativeDefinition.Contains($requiredNativeText, [System.StringComparison]::Ordinal)) {
        throw "Native safe-mode binding support lacks required behavior: $requiredNativeText"
    }
}
$jobCreateIndex = $nativeDefinition.IndexOf('result.jobHandle = CreateJobObjectW', [System.StringComparison]::Ordinal)
$jobLimitIndex = $nativeDefinition.IndexOf('SetInformationJobObject(result.jobHandle', [System.StringComparison]::Ordinal)
$processCreateIndex = $nativeDefinition.IndexOf('if (!CreateProcessW(', [System.StringComparison]::Ordinal)
$assignIndex = $nativeDefinition.IndexOf('if (!AssignProcessToJobObject(', [System.StringComparison]::Ordinal)
$membershipIndex = $nativeDefinition.IndexOf('if (!IsProcessInJob(', [System.StringComparison]::Ordinal)
$resumeIndex = $nativeDefinition.IndexOf('uint previousSuspendCount = ResumeThread(', [System.StringComparison]::Ordinal)
if ($jobCreateIndex -lt 0 -or $jobLimitIndex -le $jobCreateIndex -or
    $processCreateIndex -le $jobLimitIndex -or $assignIndex -le $processCreateIndex -or
    $membershipIndex -le $assignIndex -or $resumeIndex -le $membershipIndex) {
    throw 'Safe-mode containment does not create/configure the Job, create suspended, assign, verify, and resume in the required order.'
}

$attachmentDefinition = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Get-ExcelApplicationFromOwnedProcess'
    },
    $true
))[0].Extent.Text
foreach ($requiredAttachmentText in @(
    '$Process.Refresh()',
    '$Process.HasExited',
    'EnumerateOwnedWindows',
    '[string]$_.ClassName -cnotin @(''XLMAIN'', ''MSOSPLASH'', ''MsoSplash'')',
    '[string]$_.ClassName -ceq ''XLMAIN'' -and -not [bool]$_.Enabled',
    '[string]$_.ClassName -ceq ''XLMAIN'' -and [bool]$_.Enabled',
    '$enabledExcelRoots.Count -eq 0',
    '[uint32]4294967280',
    "[Guid]'00020400-0000-0000-C000-000000000046'",
    'GetObjectForIUnknown($rawDispatch)',
    'Marshal]::Release($rawDispatch)',
    'native_window = $nativeWindow'
)) {
    if (-not $attachmentDefinition.Contains($requiredAttachmentText, [System.StringComparison]::Ordinal)) {
        throw "Exact-process OBJID_NATIVEOM attachment lacks required behavior: $requiredAttachmentText"
    }
}
if ([regex]::Matches($attachmentDefinition, 'Marshal\]::Release\(\$rawDispatch\)').Count -ne 2 -or
    -not $attachmentDefinition.Contains('$rawDispatch = [IntPtr]::Zero', [System.StringComparison]::Ordinal)) {
    throw 'OBJID_NATIVEOM raw interface pointers are not balanced on both success and failure paths.'
}

$isolationDefinition = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Get-SafeModeIsolationObservation'
    },
    $true
))[0].Extent.Text
foreach ($requiredIsolationText in @(
    'Get-ExactProcessWindowIsolationObservation',
    '$Workbooks.Count',
    '$collectionWorkbook = $Workbooks.Item(1)',
    'Test-SameComObjectIdentity -Left $collectionWorkbook -Right $ExpectedWorkbook',
    '$collectionWorkbook.Path',
    'Marshal]::ReleaseComObject($collectionWorkbook)',
    '$Excel.GetType().InvokeMember(',
    '''COMAddIns''',
    '''unavailable_exact_excel_error_nonclaim''',
    '$errorNumber -ne -2146827284',
    'inventory_complete = $false',
    'connection_state_claim = ''not_made''',
    'error_hex = (''0x{0:X8}''',
    '$Excel.AddIns',
    '$Excel.AddIns2',
    '$Excel.ProtectedViewWindows',
    "Equals('.xll'",
    '$connectedCount -ne 0',
    '$openAddInCount -ne 0',
    '$openAddIn2Count -ne 0',
    '$protectedViewWindowCount -ne 0'
)) {
    if (-not $isolationDefinition.Contains($requiredIsolationText, [System.StringComparison]::Ordinal)) {
        throw "Safe-mode isolation inventory lacks required behavior: $requiredIsolationText"
    }
}

$comIdentityDefinition = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Test-SameComObjectIdentity'
    },
    $true
))[0].Extent.Text
if ([regex]::Matches($comIdentityDefinition, 'Marshal\]::GetIUnknownForObject').Count -ne 2 -or
    [regex]::Matches($comIdentityDefinition, 'Marshal\]::Release\(').Count -ne 2 -or
    -not $comIdentityDefinition.Contains('return $leftUnknown -eq $rightUnknown', [System.StringComparison]::Ordinal)) {
    throw 'Workbook collection authority must use a balanced canonical-IUnknown identity comparison.'
}

$windowIsolationDefinition = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Get-ExactProcessWindowIsolationObservation'
    },
    $true
))[0].Extent.Text
foreach ($requiredWindowIsolationText in @(
    'EnumerateOwnedWindows',
    '$enumeration.Limit -ne 512',
    '$enumeration.ErrorCode -ne 0',
    '[bool]$_.IsTopLevel',
    '[bool]$_.Visible -and [string]$_.ClassName',
    '[string]$_.ClassName -cnotin @(''XLMAIN'', ''MSOSPLASH'', ''MsoSplash'')',
    '[string]$_.ClassName -ceq ''XLMAIN'' -and -not [bool]$_.Enabled',
    '[string]$_.ClassName -ceq ''XLMAIN'' -and [bool]$_.Enabled',
    '$enabledExcelRoots.Count -eq 0',
    'top_level_windows',
    'visible = [bool]$_.Visible'
)) {
    if (-not $windowIsolationDefinition.Contains($requiredWindowIsolationText, [System.StringComparison]::Ordinal)) {
        throw "Exact-process checkpoint window isolation lacks required behavior: $requiredWindowIsolationText"
    }
}
if ($isolationDefinition.Contains('Release-ComObject $Workbooks', [System.StringComparison]::Ordinal) -or
    $isolationDefinition.Contains('Release-ComObject $ExpectedWorkbook', [System.StringComparison]::Ordinal) -or
    $isolationDefinition.Contains('FinalReleaseComObject($collectionWorkbook)', [System.StringComparison]::Ordinal)) {
    throw 'Safe-mode isolation inspection can FinalRelease a caller-owned workbook RCW.'
}

foreach ($callerName in @('New-OracleWorkbook', 'Invoke-LiveOracle')) {
    $caller = @($ast.FindAll(
        {
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $callerName
        },
        $true
    ))[0].Extent.Text
    foreach ($requiredCallerText in @(
        'Start-OwnedSafeExcelProcess',
        'Start-PrivateProcessWatchdog',
        'Add-ObservedSafeExcelLaunch',
        'Get-ExcelApplicationFromOwnedProcess',
        'Close-SafeModeStartupWorkbook -Workbooks $workbooks',
        'Get-SafeModeIsolationObservation',
        'Release-ComObject $nativeWindow',
        'Close-OwnedSafeExcelLaunch'
    )) {
        if (-not $caller.Contains($requiredCallerText, [System.StringComparison]::Ordinal)) {
            throw "$callerName lacks required direct-safe-mode lifecycle behavior: $requiredCallerText"
        }
    }
    if ([regex]::Matches($caller, 'Get-SafeModeIsolationObservation').Count -ne 3) {
        throw "$callerName must perform exactly three recorded safe-mode isolation checks."
    }
    if ([regex]::Matches($caller, 'Close-OwnedSafeExcelLaunch').Count -ne 1) {
        throw "$callerName must deterministically close its retained Job containment exactly once."
    }
    $launchIndex = $caller.IndexOf('Start-OwnedSafeExcelProcess', [System.StringComparison]::Ordinal)
    $watchdogIndex = $caller.IndexOf('Start-PrivateProcessWatchdog', $launchIndex, [System.StringComparison]::Ordinal)
    $observationIndex = $caller.IndexOf('Add-ObservedSafeExcelLaunch', [System.StringComparison]::Ordinal)
    $attachmentIndex = $caller.IndexOf('Get-ExcelApplicationFromOwnedProcess', [System.StringComparison]::Ordinal)
    if ($launchIndex -lt 0 -or $watchdogIndex -le $launchIndex -or
        $observationIndex -le $watchdogIndex -or $attachmentIndex -le $observationIndex) {
        throw "$callerName does not arm its phase watchdog before bounded command-line observation and native attachment."
    }
}

$containmentCloseDefinition = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Close-OwnedSafeExcelLaunch'
    },
    $true
))[0].Extent.Text
foreach ($requiredContainmentCloseText in @(
    '$containment.TerminateAndWait(15000)',
    '$managedProcess.HasExited',
    '$managedProcess.Dispose()',
    '$containment.Dispose()',
    'Add-CleanupFailure'
)) {
    if (-not $containmentCloseDefinition.Contains($requiredContainmentCloseText, [System.StringComparison]::Ordinal)) {
        throw "Deterministic safe-mode containment cleanup lacks required behavior: $requiredContainmentCloseText"
    }
}
$managedDisposeIndex = $containmentCloseDefinition.LastIndexOf('$managedProcess.Dispose()', [System.StringComparison]::Ordinal)
$containmentDisposeIndex = $containmentCloseDefinition.LastIndexOf('$containment.Dispose()', [System.StringComparison]::Ordinal)
if ($managedDisposeIndex -lt 0 -or $containmentDisposeIndex -le $managedDisposeIndex) {
    throw 'Managed Process disposal must precede final Job-containment disposal.'
}

if (-not $runnerText.Contains(
    '[System.IO.File]::WriteAllBytes($manifestSnapshotPath, $sourceManifestBytes)',
    [System.StringComparison]::Ordinal
)) {
    throw 'Capture-local manifest snapshot is not written from the retained bytes that drove parsing and routing.'
}

$pinnedChildCalls = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Invoke-HashPinnedChildScript'
    },
    $true
))
if ($pinnedChildCalls.Count -ne 8) {
    throw "Expected eight hash-pinned generator/window snapshot executions, found $($pinnedChildCalls.Count)."
}
foreach ($call in $pinnedChildCalls) {
    $callText = $call.Extent.Text
    foreach ($requiredBinding in @('-ScriptPath', '-ScriptArgumentIndex', '-ExpectedScriptSha256')) {
        if (-not $callText.Contains($requiredBinding, [System.StringComparison]::Ordinal)) {
            throw "Hash-pinned child-script call lacks ${requiredBinding}: $callText"
        }
    }
}
$directExternalCalls = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Invoke-ExternalCommand'
    },
    $true
))
if ($directExternalCalls.Count -ne 2) {
    throw "Only the hash-pinned wrapper and non-script Python-version probe may call Invoke-ExternalCommand directly; found $($directExternalCalls.Count)."
}

$pinnedWrapperDefinition = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Invoke-HashPinnedChildScript'
    },
    $true
))[0]
$pinnedWrapperText = $pinnedWrapperDefinition.Extent.Text
$reparseChecks = @($pinnedWrapperDefinition.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Assert-NoReparsePointInPath'
    },
    $true
))
$openIndex = $pinnedWrapperText.IndexOf('[System.IO.File]::Open(', [System.StringComparison]::Ordinal)
if ($reparseChecks.Count -ne 2 -or
    $reparseChecks[0].Extent.StartOffset -ge $pinnedWrapperDefinition.Extent.StartOffset + $openIndex -or
    $reparseChecks[1].Extent.StartOffset -le $pinnedWrapperDefinition.Extent.StartOffset + $openIndex) {
    throw 'Hash-pinned child-script execution must reject reparse paths immediately before and after opening the retained snapshot handle.'
}

$watchdogDefinition = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Start-PrivateProcessWatchdog'
    },
    $true
))[0].Extent.Text
if ([regex]::Matches(
    $watchdogDefinition,
    'if \(-not \(Test-ExactProcessAliveForAuthorization\)\) \{ return \}'
).Count -ne 2) {
    throw 'Expected-exit acknowledgement paths do not both revalidate exact live process identity immediately before acknowledgement.'
}
$sharedLogReaderCalls = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Read-SharedUtf8Lines'
    },
    $true
))
if ($sharedLogReaderCalls.Count -ne 2 -or
    $runnerText.Contains('[System.IO.File]::ReadAllLines', [System.StringComparison]::Ordinal)) {
    throw 'Watchdog ARMED handshake and terminal verification must be the only two runner call sites and must both use the shared/retrying log reader.'
}
$exactStopDefinition = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Stop-ExactPrivateProcess'
    },
    $true
))[0].Extent.Text
if (-not $exactStopDefinition.Contains('$process.WaitForExit(15000)', [System.StringComparison]::Ordinal) -or
    -not $exactStopDefinition.Contains('within 15 seconds', [System.StringComparison]::Ordinal) -or
    -not $runnerText.Contains('shutdown_timeout_seconds = 15', [System.StringComparison]::Ordinal)) {
    throw 'Emergency exact-process cleanup and recorded shutdown policy are not pinned to the same 15-second confirmation deadline.'
}

$pinnedWorkbookDefinition = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Open-HashPinnedWorkbook'
    },
    $true
))[0].Extent.Text
foreach ($requiredPinnedOpenText in @(
    '[System.IO.FileShare]::ReadWrite',
    'Get-StreamSha256 $stream',
    '$Workbooks.Open($resolvedWorkbookPath)',
    '[bool]$openedWorkbook.ReadOnly',
    '$openedWorkbook.Close($false)',
    '$stream.Dispose()'
)) {
    if (-not $pinnedWorkbookDefinition.Contains($requiredPinnedOpenText, [System.StringComparison]::Ordinal)) {
        throw "Pinned workbook opening lacks required retained-handle behavior: $requiredPinnedOpenText"
    }
}
if ($pinnedWorkbookDefinition.Contains('[System.IO.FileShare]::Delete', [System.StringComparison]::Ordinal) -or
    [regex]::Matches($pinnedWorkbookDefinition, 'Get-StreamSha256 \$stream').Count -ne 2) {
    throw 'Pinned workbook opening must deny rename/delete and hash the same retained stream exactly before and after Workbooks.Open.'
}
$liveOracleAst = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Invoke-LiveOracle'
    },
    $true
))[0]
$liveOracleDefinition = $liveOracleAst.Extent.Text
foreach ($requiredInitializer in @(
    [pscustomobject]@{ variable = '$macroExecutionStarted'; value = '$false' },
    [pscustomobject]@{ variable = '$oracleFormClosed'; value = '$false' },
    [pscustomobject]@{ variable = '$macroBookName'; value = "''" }
)) {
    $initializerVariable = $requiredInitializer.variable
    $initializerValue = $requiredInitializer.value
    $matchingInitializers = @($liveOracleAst.FindAll(
        {
            param($node)
            $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left.Extent.Text -ceq $initializerVariable -and
            $node.Right.Extent.Text -ceq $initializerValue
        },
        $true
    ))
    if ($matchingInitializers.Count -ne 1) {
        throw "Invoke-LiveOracle must contain exactly one $initializerVariable = $initializerValue cleanup-state initializer; found $($matchingInitializers.Count)."
    }
}
if ([regex]::Matches($liveOracleDefinition, 'Open-HashPinnedWorkbook').Count -ne 1 -or
    $liveOracleDefinition.Contains('$workbooks.Open(', [System.StringComparison]::Ordinal) -or
    $liveOracleDefinition.Contains('Get-Sha256 $WorkbookPath', [System.StringComparison]::Ordinal)) {
    throw 'Live oracle bypasses the retained-handle workbook-open handoff or reopens the live workbook path for hashing.'
}

$preflightDefinition = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Invoke-GeneratorPreflight'
    },
    $true
))[0].Extent.Text
foreach ($requiredPreflightText in @(
    '$preflightGeneratorPath',
    '[System.IO.File]::WriteAllBytes($preflightManifestPath, $ManifestBytes)',
    'Assert-NoReparsePointTree $resolvedCleanupStage',
    '[System.IO.Directory]::Delete($resolvedCleanupStage, $true)',
    "-Operation 'Generator preflight snapshot cleanup'"
)) {
    if (-not $preflightDefinition.Contains($requiredPreflightText, [System.StringComparison]::Ordinal)) {
        throw "Generator preflight lacks required snapshot/pin/cleanup behavior: $requiredPreflightText"
    }
}
if ([regex]::Matches($preflightDefinition, "'--expected-self-sha256'").Count -ne 2) {
    throw 'Generator preflight commands are not both self-hash pinned.'
}
$preflightCallIndex = $runnerText.LastIndexOf('$preflight = Invoke-GeneratorPreflight', [System.StringComparison]::Ordinal)
$dryRunIndex = $runnerText.LastIndexOf('if ($DryRun) {', [System.StringComparison]::Ordinal)
if ($preflightCallIndex -lt 0 -or $dryRunIndex -lt 0 -or $preflightCallIndex -gt $dryRunIndex) {
    throw 'Dry-run can complete without executing the transient snapshot-bound generator preflight.'
}
if (-not $runnerText.Contains(
    'if ([string]$toolSnapshots.generator_validator.sha256 -cne $preflightGeneratorSha256)',
    [System.StringComparison]::Ordinal
)) {
    throw 'Capture-local generator snapshot is not digest-bound to the preflight snapshot.'
}
foreach ($manifestGuardLabel in @(
    'before snapshot validation', 'after snapshot validation',
    'before snapshot ledger verification', 'after snapshot ledger verification',
    'before source generation', 'after source generation',
    'before pre-open validation', 'after pre-open validation',
    'before final replay validation', 'after final replay validation',
    'before generate-only checksums', 'after generate-only checksums', 'before generate-only promotion',
    'before live-capture checksums', 'after live-capture checksums', 'before live-capture promotion'
)) {
    if (-not $runnerText.Contains($manifestGuardLabel, [System.StringComparison]::Ordinal)) {
        throw "Frozen manifest guard is missing: $manifestGuardLabel"
    }
}

$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
Initialize-NativeMethods
$pwshPath = Join-Path $PSHOME 'pwsh.exe'
if (-not (Test-Path -LiteralPath $pwshPath -PathType Leaf)) {
    throw "Disposable watchdog-test host is unavailable: '$pwshPath'."
}

$testId = [Guid]::NewGuid().ToString('N')
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$tempParent = Join-Path $repoRoot 'target\test-office-oracle'
[void][System.IO.Directory]::CreateDirectory($tempParent)
$tempRoot = [System.IO.Path]::GetFullPath((Join-Path $tempParent "private-process-watchdog-$testId"))
$tempPrefix = [System.IO.Path]::GetFullPath($tempParent).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
if (-not $tempRoot.StartsWith($tempPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
    -not ([System.IO.Path]::GetFileName($tempRoot)).StartsWith('private-process-watchdog-', [System.StringComparison]::Ordinal)) {
    throw "Refusing unsafe watchdog-test root: '$tempRoot'."
}
[void][System.IO.Directory]::CreateDirectory($tempRoot)
$ownedProcesses = [System.Collections.Generic.List[object]]::new()
$jobs = [System.Collections.Generic.List[object]]::new()

$containmentFixtureSource = Join-Path $tempRoot 'safe-containment-fixture.rs'
$containmentFixtureExe = Join-Path $tempRoot 'safe-containment-fixture.exe'
$containmentNativeDefinitionPath = Join-Path $tempRoot 'Initialize-NativeMethods.ps1'
[System.IO.File]::WriteAllText($containmentFixtureSource, @'
use std::{env, ffi::OsStr, fs, process::{self, Command}, thread, time::Duration};

fn required(name: &str) -> String {
    env::var(name).unwrap_or_else(|_| panic!("missing {name}"))
}

fn park() -> ! {
    loop { thread::sleep(Duration::from_secs(60)); }
}

fn main() {
    let arguments: Vec<_> = env::args_os().skip(1).collect();
    if arguments.len() == 1 && arguments[0].as_os_str() == OsStr::new("--descendant") {
        fs::write(
            required("OXFORMS_CONTAINMENT_CHILD_PID_PATH"),
            process::id().to_string()
        ).unwrap();
        park();
    }
    if arguments.len() != 1 || arguments[0].as_os_str() != OsStr::new("/safe") {
        process::exit(81);
    }
    let _child = Command::new(env::current_exe().unwrap())
        .arg("--descendant")
        .spawn()
        .unwrap();
    fs::write(
        required("OXFORMS_CONTAINMENT_ROOT_PID_PATH"),
        process::id().to_string()
    ).unwrap();
    park();
}
'@, $script:Utf8NoBom)
$rustc = (Get-Command rustc -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$containmentCompileOutput = @(& $rustc --edition=2021 $containmentFixtureSource -o $containmentFixtureExe 2>&1)
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $containmentFixtureExe -PathType Leaf)) {
    throw "Could not compile the native safe-containment fixture: $($containmentCompileOutput -join ' | ')"
}
[System.IO.File]::WriteAllText($containmentNativeDefinitionPath, $nativeDefinition, $script:Utf8NoBom)

function Start-OwnedTestProcess {
    param(
        [string]$ExitSignalPath,
        [ValidateRange(1, 1000)][int]$ExitPollMilliseconds = 50
    )

    $processArguments = @('-NoProfile', '-NonInteractive')
    if ([string]::IsNullOrWhiteSpace($ExitSignalPath)) {
        $processArguments += @('-Command', 'Start-Sleep -Seconds 30')
    } else {
        $escapedExitSignal = $ExitSignalPath.Replace("'", "''")
        $exitCommand = "while (-not [System.IO.File]::Exists('$escapedExitSignal')) { Start-Sleep -Milliseconds $ExitPollMilliseconds }; exit 0"
        $encodedExitCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($exitCommand))
        $processArguments += @('-EncodedCommand', $encodedExitCommand)
    }
    $process = Start-Process `
        -FilePath $pwshPath `
        -ArgumentList $processArguments `
        -WindowStyle Hidden `
        -PassThru
    $process.Refresh()
    if ($process.HasExited) {
        throw "Disposable watchdog-test process exited prematurely with code $($process.ExitCode)."
    }
    $identity = [pscustomobject][ordered]@{
        process = $process
        process_id = [int64]$process.Id
        process_start_utc = [OxForms.MemberOracle.NativeMethods]::GetProcessStartTimeUtc($process.Handle)
        path = [System.IO.Path]::GetFullPath($pwshPath)
    }
    $ownedProcesses.Add($identity)
    return $identity
}

function Assert-OwnedProcessRunning {
    param([Parameter(Mandatory = $true)]$Identity)
    $process = Get-Process -Id ([int]$Identity.process_id) -ErrorAction SilentlyContinue
    if ($null -eq $process) { throw "Expected disposable process $($Identity.process_id) to remain running." }
    try {
        if ($process.StartTime.ToUniversalTime().ToString('o') -cne $Identity.process_start_utc -or
            -not ([string]$process.Path).Equals($Identity.path, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Disposable process identity changed for PID $($Identity.process_id)."
        }
    } finally {
        $process.Dispose()
    }
}

function Wait-ForContainmentPidFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            $text = [System.IO.File]::ReadAllText($Path).Trim()
            $processIdValue = [int]0
            if ([int]::TryParse($text, [ref]$processIdValue) -and $processIdValue -gt 0) {
                return $processIdValue
            }
        }
        Start-Sleep -Milliseconds 20
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "$Label did not publish a valid process id within the bounded wait."
}

function Test-SafeModeContainmentDisposeTree {
    $rootPidPath = Join-Path $tempRoot 'containment-dispose-root.pid'
    $childPidPath = Join-Path $tempRoot 'containment-dispose-child.pid'
    $oldRootPidPath = [Environment]::GetEnvironmentVariable('OXFORMS_CONTAINMENT_ROOT_PID_PATH')
    $oldChildPidPath = [Environment]::GetEnvironmentVariable('OXFORMS_CONTAINMENT_CHILD_PID_PATH')
    $containment = $null
    $rootProcess = $null
    $childProcess = $null
    try {
        [Environment]::SetEnvironmentVariable('OXFORMS_CONTAINMENT_ROOT_PID_PATH', $rootPidPath)
        [Environment]::SetEnvironmentVariable('OXFORMS_CONTAINMENT_CHILD_PID_PATH', $childPidPath)
        $containment = [OxForms.MemberOracle.SafeModeExcelContainment]::Launch($containmentFixtureExe)
        $publishedRootId = Wait-ForContainmentPidFile -Path $rootPidPath -Label 'Contained fixture root'
        $publishedChildId = Wait-ForContainmentPidFile -Path $childPidPath -Label 'Contained fixture descendant'
        if ($publishedRootId -ne [int]$containment.ProcessId) {
            throw 'Contained fixture root PID differs from the retained production-containment PID.'
        }
        $rootProcess = Get-Process -Id $publishedRootId -ErrorAction Stop
        $childProcess = Get-Process -Id $publishedChildId -ErrorAction Stop
        if (-not $containment.ContainsProcess($rootProcess.Handle) -or
            -not $containment.ContainsProcess($childProcess.Handle)) {
            throw 'Production safe-mode Job does not contain both the exact root and its descendant.'
        }
        $containment.Dispose()
        $containment = $null
        if (-not $rootProcess.WaitForExit(10000) -or -not $childProcess.WaitForExit(10000) -or
            -not $rootProcess.HasExited -or -not $childProcess.HasExited) {
            throw 'Closing the production Job handle did not terminate both root and descendant.'
        }
    } finally {
        if ($null -ne $containment) { try { $containment.Dispose() } catch { } }
        foreach ($candidate in @($rootProcess, $childProcess)) {
            if ($null -eq $candidate) { continue }
            try {
                $candidate.Refresh()
                if (-not $candidate.HasExited) {
                    $candidate.Kill()
                    [void]$candidate.WaitForExit(10000)
                }
            } catch { } finally { $candidate.Dispose() }
        }
        [Environment]::SetEnvironmentVariable('OXFORMS_CONTAINMENT_ROOT_PID_PATH', $oldRootPidPath)
        [Environment]::SetEnvironmentVariable('OXFORMS_CONTAINMENT_CHILD_PID_PATH', $oldChildPidPath)
    }
}

function Test-SafeModeContainmentAbruptSupervisorDeath {
    $rootPidPath = Join-Path $tempRoot 'containment-abrupt-root.pid'
    $childPidPath = Join-Path $tempRoot 'containment-abrupt-child.pid'
    $readyPath = Join-Path $tempRoot 'containment-abrupt.ready'
    $supervisorScript = Join-Path $tempRoot 'containment-abrupt-supervisor.ps1'
    [System.IO.File]::WriteAllText($supervisorScript, @'
param(
    [Parameter(Mandatory = $true)][string]$NativeDefinitionPath,
    [Parameter(Mandatory = $true)][string]$FixtureExe,
    [Parameter(Mandatory = $true)][string]$RootPidPath,
    [Parameter(Mandatory = $true)][string]$ChildPidPath,
    [Parameter(Mandatory = $true)][string]$ReadyPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. $NativeDefinitionPath
Initialize-NativeMethods
[Environment]::SetEnvironmentVariable('OXFORMS_CONTAINMENT_ROOT_PID_PATH', $RootPidPath)
[Environment]::SetEnvironmentVariable('OXFORMS_CONTAINMENT_CHILD_PID_PATH', $ChildPidPath)
$containment = [OxForms.MemberOracle.SafeModeExcelContainment]::Launch($FixtureExe)
$root = Get-Process -Id ([int]$containment.ProcessId) -ErrorAction Stop
$deadline = [DateTime]::UtcNow.AddSeconds(10)
while (-not (Test-Path -LiteralPath $ChildPidPath -PathType Leaf) -and [DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Milliseconds 20
}
if (-not (Test-Path -LiteralPath $ChildPidPath -PathType Leaf)) { throw 'Descendant PID was not published.' }
$childId = [int]([System.IO.File]::ReadAllText($ChildPidPath).Trim())
$child = Get-Process -Id $childId -ErrorAction Stop
if (-not $containment.ContainsProcess($root.Handle) -or -not $containment.ContainsProcess($child.Handle)) {
    throw 'Supervisor could not prove root and descendant Job membership.'
}
[System.IO.File]::WriteAllText($ReadyPath, 'ready')
while ($true) { Start-Sleep -Seconds 60 }
'@, $script:Utf8NoBom)

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $pwshPath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    foreach ($argument in @(
        '-NoProfile', '-NonInteractive', '-File', $supervisorScript,
        '-NativeDefinitionPath', $containmentNativeDefinitionPath,
        '-FixtureExe', $containmentFixtureExe,
        '-RootPidPath', $rootPidPath,
        '-ChildPidPath', $childPidPath,
        '-ReadyPath', $readyPath
    )) { [void]$startInfo.ArgumentList.Add($argument) }
    $supervisor = $null
    $rootProcess = $null
    $childProcess = $null
    try {
        $supervisor = [System.Diagnostics.Process]::Start($startInfo)
        $deadline = [DateTime]::UtcNow.AddSeconds(15)
        while (-not (Test-Path -LiteralPath $readyPath -PathType Leaf) -and
            -not $supervisor.HasExited -and [DateTime]::UtcNow -lt $deadline) {
            Start-Sleep -Milliseconds 20
            $supervisor.Refresh()
        }
        if ($supervisor.HasExited -or -not (Test-Path -LiteralPath $readyPath -PathType Leaf)) {
            throw "Independent containment supervisor did not reach its membership-proven ready state; exited=$($supervisor.HasExited)."
        }
        $rootProcess = Get-Process -Id (Wait-ForContainmentPidFile -Path $rootPidPath -Label 'Abrupt-case root') -ErrorAction Stop
        $childProcess = Get-Process -Id (Wait-ForContainmentPidFile -Path $childPidPath -Label 'Abrupt-case descendant') -ErrorAction Stop
        $supervisor.Kill()
        if (-not $supervisor.WaitForExit(10000)) { throw 'Independent containment supervisor did not exit after exact-process kill.' }
        if (-not $rootProcess.WaitForExit(10000) -or -not $childProcess.WaitForExit(10000) -or
            -not $rootProcess.HasExited -or -not $childProcess.HasExited) {
            throw 'Abrupt supervisor death did not close the Job and terminate both contained processes.'
        }
    } finally {
        if ($null -ne $supervisor) {
            try { if (-not $supervisor.HasExited) { $supervisor.Kill(); [void]$supervisor.WaitForExit(10000) } } catch { }
        }
        foreach ($candidate in @($rootProcess, $childProcess)) {
            if ($null -eq $candidate) { continue }
            try {
                $candidate.Refresh()
                if (-not $candidate.HasExited) { $candidate.Kill(); [void]$candidate.WaitForExit(10000) }
            } catch { } finally { $candidate.Dispose() }
        }
        if ($null -ne $supervisor) { $supervisor.Dispose() }
    }
}

function New-FakeWorkbookCollection {
    param(
        [Parameter(Mandatory = $true)][string]$ReportedFullName,
        [bool]$ReadOnly = $false,
        [AllowNull()][byte[]]$MutationBytes = $null
    )

    $collection = [pscustomobject]@{
        ReportedFullName = $ReportedFullName
        ReportedReadOnly = $ReadOnly
        MutationBytes = $MutationBytes
        LastWorkbook = $null
    }
    $collection | Add-Member -MemberType ScriptMethod -Name Open -Value {
        param([Parameter(Mandatory = $true)][string]$Path)

        $handle = [System.IO.File]::Open(
            $Path,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::Read
        )
        try {
            if ($null -ne $this.MutationBytes) {
                $handle.SetLength(0)
                $handle.Position = 0
                $handle.Write($this.MutationBytes, 0, $this.MutationBytes.Length)
                $handle.Flush($true)
            }
            $workbook = [pscustomobject]@{
                FullName = $this.ReportedFullName
                ReadOnly = $this.ReportedReadOnly
                Handle = $handle
                CloseCount = 0
            }
            $workbook | Add-Member -MemberType ScriptMethod -Name Close -Value {
                param([bool]$SaveChanges)
                $this.CloseCount++
                if ($null -ne $this.Handle) {
                    $this.Handle.Dispose()
                    $this.Handle = $null
                }
            }
            $this.LastWorkbook = $workbook
            $handle = $null
            return $workbook
        } finally {
            if ($null -ne $handle) { $handle.Dispose() }
        }
    }
    return $collection
}

try {
    Test-SafeModeContainmentDisposeTree
    Test-SafeModeContainmentAbruptSupervisorDeath

    $pinnedWorkbookPath = Join-Path $tempRoot 'pinned-workbook.xlsm'
    $pinnedWorkbookBytes = $script:Utf8NoBom.GetBytes('exact-preopen-workbook-bytes')
    [System.IO.File]::WriteAllBytes($pinnedWorkbookPath, $pinnedWorkbookBytes)
    $pinnedWorkbookDigest = Get-Sha256 $pinnedWorkbookPath
    $fakeWorkbooks = New-FakeWorkbookCollection -ReportedFullName $pinnedWorkbookPath
    $fakeWorkbook = Open-HashPinnedWorkbook `
        -Workbooks $fakeWorkbooks `
        -WorkbookPath $pinnedWorkbookPath `
        -ExpectedSha256 $pinnedWorkbookDigest
    if ($null -eq $fakeWorkbook -or $fakeWorkbooks.LastWorkbook.CloseCount -ne 0) {
        throw 'Pinned workbook handoff did not return the exact still-open workbook.'
    }
    $ordinaryPathHashFailure = $null
    try { [void](Get-Sha256 $pinnedWorkbookPath) } catch { $ordinaryPathHashFailure = $_ }
    if ($null -eq $ordinaryPathHashFailure -or
        $ordinaryPathHashFailure.Exception -isnot [System.IO.IOException]) {
        throw 'Fake Excel lock did not prove that a fresh post-open path hash is invalid for this lifecycle.'
    }
    $fakeWorkbook.Close($false)
    if ($fakeWorkbooks.LastWorkbook.CloseCount -ne 1) {
        throw 'Successful pinned workbook handoff did not leave workbook ownership with its caller.'
    }

    $mutatedWorkbookBytes = $script:Utf8NoBom.GetBytes('mutated-during-open-workbook')
    $mutatingWorkbooks = New-FakeWorkbookCollection `
        -ReportedFullName $pinnedWorkbookPath `
        -MutationBytes $mutatedWorkbookBytes
    $mutationFailure = $null
    try {
        [void](Open-HashPinnedWorkbook `
            -Workbooks $mutatingWorkbooks `
            -WorkbookPath $pinnedWorkbookPath `
            -ExpectedSha256 $pinnedWorkbookDigest)
    } catch {
        $mutationFailure = $_
    }
    if ($null -eq $mutationFailure -or
        $mutationFailure.Exception.Message -notmatch 'bytes changed during Workbooks.Open' -or
        $mutatingWorkbooks.LastWorkbook.CloseCount -ne 1) {
        throw 'Pinned workbook handoff did not reject and close a workbook mutated during Open.'
    }
    [System.IO.File]::WriteAllBytes($pinnedWorkbookPath, $pinnedWorkbookBytes)

    foreach ($invalidOpenCase in @(
        [pscustomobject]@{
            workbooks = New-FakeWorkbookCollection -ReportedFullName (Join-Path $tempRoot 'wrong-workbook.xlsm')
            message = 'expected the exact pre-validated workbook'
        },
        [pscustomobject]@{
            workbooks = New-FakeWorkbookCollection -ReportedFullName $pinnedWorkbookPath -ReadOnly $true
            message = 'opened the exact pre-validated workbook read-only'
        }
    )) {
        $invalidOpenFailure = $null
        try {
            [void](Open-HashPinnedWorkbook `
                -Workbooks $invalidOpenCase.workbooks `
                -WorkbookPath $pinnedWorkbookPath `
                -ExpectedSha256 $pinnedWorkbookDigest)
        } catch {
            $invalidOpenFailure = $_
        }
        if ($null -eq $invalidOpenFailure -or
            $invalidOpenFailure.Exception.Message -notmatch $invalidOpenCase.message -or
            $invalidOpenCase.workbooks.LastWorkbook.CloseCount -ne 1) {
            throw "Pinned workbook handoff accepted or leaked invalid Open case '$($invalidOpenCase.message)'."
        }
    }

    $compatibleLogPath = Join-Path $tempRoot 'share-compatible-watchdog.log'
    $compatibleLogWriter = [System.IO.File]::Open(
        $compatibleLogPath,
        [System.IO.FileMode]::CreateNew,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::Read
    )
    try {
        $compatibleLogBytes = $script:Utf8NoBom.GetBytes("while-writer-open`n")
        $compatibleLogWriter.Write($compatibleLogBytes, 0, $compatibleLogBytes.Length)
        $compatibleLogWriter.Flush($true)
        $compatibleLines = @(Read-SharedUtf8Lines $compatibleLogPath)
        if ($compatibleLines.Count -ne 1 -or $compatibleLines[0] -cne 'while-writer-open') {
            throw 'Share-compatible watchdog-log reader could not read a flushed transcript while its writer remained open.'
        }
    } finally {
        $compatibleLogWriter.Dispose()
    }

    $sharedLogPath = Join-Path $tempRoot 'shared-watchdog.log'
    $sharedLogReadyPath = Join-Path $tempRoot 'shared-watchdog.ready'
    $sharedLogReleasePath = Join-Path $tempRoot 'shared-watchdog.release'
    $sharedLogJob = Start-Job -ArgumentList $sharedLogPath, $sharedLogReadyPath, $sharedLogReleasePath -ScriptBlock {
        param($LogPath, $ReadyPath, $ReleasePath)
        $encoding = [System.Text.UTF8Encoding]::new($false)
        $writer = [System.IO.File]::Open(
            $LogPath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None
        )
        try {
            $bytes = $encoding.GetBytes("first`nsecond`n")
            $writer.Write($bytes, 0, $bytes.Length)
            $writer.Flush($true)
            [System.IO.File]::WriteAllText($ReadyPath, "ready`n", $encoding)
            while (-not [System.IO.File]::Exists($ReleasePath)) {
                Start-Sleep -Milliseconds 20
            }
        } finally {
            $writer.Dispose()
        }
    }
    $jobs.Add($sharedLogJob)
    try {
        $sharedLogReadyDeadline = [DateTime]::UtcNow.AddSeconds(5)
        while (-not (Test-Path -LiteralPath $sharedLogReadyPath -PathType Leaf) -and
            [DateTime]::UtcNow -lt $sharedLogReadyDeadline) {
            Start-Sleep -Milliseconds 20
        }
        if (-not (Test-Path -LiteralPath $sharedLogReadyPath -PathType Leaf)) {
            throw 'Watchdog-log sharing fixture did not acquire its writer lock.'
        }
        $ordinaryLogReadFailure = $null
        try { [void][System.IO.File]::ReadAllLines($sharedLogPath) } catch { $ordinaryLogReadFailure = $_ }
        $ordinaryLogIOException = $null -ne $ordinaryLogReadFailure -and (
            $ordinaryLogReadFailure.Exception -is [System.IO.IOException] -or
            $ordinaryLogReadFailure.Exception.InnerException -is [System.IO.IOException]
        )
        if (-not $ordinaryLogIOException) {
            throw 'Watchdog-log fixture did not reproduce the writer/ReadAllLines sharing collision.'
        }
        [System.IO.File]::WriteAllText($sharedLogReleasePath, "release`n", $script:Utf8NoBom)
        $sharedLines = @(Read-SharedUtf8Lines $sharedLogPath)
        if ($sharedLines.Count -ne 2 -or $sharedLines[0] -cne 'first' -or $sharedLines[1] -cne 'second') {
            throw 'Share-compatible watchdog-log reader did not return the complete concurrent transcript.'
        }
    } finally {
        if (-not (Test-Path -LiteralPath $sharedLogReleasePath -PathType Leaf)) {
            [System.IO.File]::WriteAllText($sharedLogReleasePath, "release`n", $script:Utf8NoBom)
        }
        [void](Wait-Job -Job $sharedLogJob -Timeout 5)
        [void](Receive-Job -Job $sharedLogJob -ErrorAction SilentlyContinue 2>&1)
        Remove-Job -Job $sharedLogJob -Force -ErrorAction SilentlyContinue
        [void]$jobs.Remove($sharedLogJob)
    }

    $sharingGuardScript = Join-Path $tempRoot 'sharing-guard-child.ps1'
    $sharingGuardSource = @'
$ErrorActionPreference = 'Stop'
try {
    [System.IO.File]::WriteAllText($PSCommandPath, 'tampered')
    [Console]::Write('write-succeeded')
    exit 9
} catch {
    [Console]::Write('sharing-blocked')
    exit 0
}
'@
    [System.IO.File]::WriteAllText($sharingGuardScript, $sharingGuardSource, $script:Utf8NoBom)
    $sharingGuardDigest = (Get-FileHash -LiteralPath $sharingGuardScript -Algorithm SHA256).Hash.ToLowerInvariant()
    $sharingGuardArguments = @('-NoProfile', '-NonInteractive', '-File', $sharingGuardScript)
    $sharingGuardResult = Invoke-HashPinnedChildScript `
        -FilePath $pwshPath `
        -Arguments $sharingGuardArguments `
        -ScriptPath $sharingGuardScript `
        -ScriptArgumentIndex 3 `
        -ExpectedScriptSha256 $sharingGuardDigest `
        -TimeoutSeconds 10
    if ($sharingGuardResult.exit_code -ne 0 -or
        $sharingGuardResult.stdout -cne 'sharing-blocked' -or
        (Get-FileHash -LiteralPath $sharingGuardScript -Algorithm SHA256).Hash.ToLowerInvariant() -cne $sharingGuardDigest) {
        throw 'Hash-pinned child guard did not hold a deterministic read-only sharing lock through child completion.'
    }

    $tamperGuardScript = Join-Path $tempRoot 'tamper-guard-child.ps1'
    $tamperMarker = Join-Path $tempRoot 'tamper-guard-executed.marker'
    [System.IO.File]::WriteAllText(
        $tamperGuardScript,
        "[System.IO.File]::WriteAllText('$($tamperMarker.Replace("'", "''"))', 'executed')",
        $script:Utf8NoBom
    )
    $preTamperDigest = (Get-FileHash -LiteralPath $tamperGuardScript -Algorithm SHA256).Hash.ToLowerInvariant()
    [System.IO.File]::AppendAllText($tamperGuardScript, "`n# tampered", $script:Utf8NoBom)
    $tamperGuardFailure = $null
    try {
        [void](Invoke-HashPinnedChildScript `
            -FilePath $pwshPath `
            -Arguments @('-NoProfile', '-NonInteractive', '-File', $tamperGuardScript) `
            -ScriptPath $tamperGuardScript `
            -ScriptArgumentIndex 3 `
            -ExpectedScriptSha256 $preTamperDigest `
            -TimeoutSeconds 10)
    } catch {
        $tamperGuardFailure = $_
    }
    if ($null -eq $tamperGuardFailure -or
        $tamperGuardFailure.Exception.Message -notmatch 'Pinned child-script SHA-256 mismatch' -or
        (Test-Path -LiteralPath $tamperMarker)) {
        throw 'Hash-pinned child guard did not reject tampered bytes before child execution.'
    }

    $frozenJsonPath = Join-Path $tempRoot 'frozen-input.json'
    $frozenJsonBytes = $script:Utf8NoBom.GetBytes('{"marker":"retained"}')
    [System.IO.File]::WriteAllBytes($frozenJsonPath, $frozenJsonBytes)
    $frozenJson = Read-FrozenUtf8Json -Path $frozenJsonPath -Label 'Disposable frozen JSON'
    if ([string]$frozenJson.value.marker -cne 'retained' -or
        [string]$frozenJson.sha256 -cne (Get-BytesSha256 $frozenJsonBytes) -or
        [Convert]::ToHexString([byte[]]$frozenJson.bytes) -cne [Convert]::ToHexString($frozenJsonBytes)) {
        throw 'Frozen JSON parsing did not bind the parsed value, digest, and retained bytes.'
    }
    $invalidUtf8Path = Join-Path $tempRoot 'invalid-utf8.json'
    [System.IO.File]::WriteAllBytes($invalidUtf8Path, [byte[]](0x7b, 0x22, 0x78, 0x22, 0x3a, 0xff, 0x7d))
    $invalidUtf8Failure = $null
    try {
        [void](Read-FrozenUtf8Json -Path $invalidUtf8Path -Label 'Disposable invalid JSON')
    } catch {
        $invalidUtf8Failure = $_
    }
    if ($null -eq $invalidUtf8Failure -or $invalidUtf8Failure.Exception.Message -notmatch 'is not strict UTF-8') {
        throw 'Frozen JSON parser did not reject invalid UTF-8 bytes.'
    }

    $aggregateFailures = [System.Collections.Generic.List[string]]::new()
    try { throw [System.InvalidOperationException]::new('first cleanup fault') } catch {
        Add-CleanupFailure -Failures $aggregateFailures -Operation 'first stage' -Failure $_
    }
    Add-CleanupFailure `
        -Failures $aggregateFailures `
        -Operation 'second stage' `
        -Failure ([System.ApplicationException]::new('second cleanup fault'))
    if ($aggregateFailures.Count -ne 2 -or
        $aggregateFailures[0] -cne 'first stage: first cleanup fault' -or
        $aggregateFailures[1] -cne 'second stage: second cleanup fault') {
        throw "Cleanup failure aggregation lost or reordered failures: $($aggregateFailures -join ' | ')"
    }

    $externalSuccess = Invoke-ExternalCommand `
        -FilePath $pwshPath `
        -Arguments @('-NoProfile', '-NonInteractive', '-Command', '[Console]::Write("bounded-ok")') `
        -TimeoutSeconds 5
    if ($externalSuccess.exit_code -ne 0 -or $externalSuccess.stdout -cne 'bounded-ok') {
        throw 'Bounded external-command success case did not preserve output and exit status.'
    }
    $externalTimeoutFailure = $null
    $externalTimeoutPidPath = Join-Path $tempRoot 'external-timeout.pid'
    $escapedTimeoutPidPath = $externalTimeoutPidPath.Replace("'", "''")
    $externalTimeoutCommand = "[System.IO.File]::WriteAllText('$escapedTimeoutPidPath', [string]`$PID); Start-Sleep -Seconds 30"
    $encodedExternalTimeoutCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($externalTimeoutCommand))
    try {
        [void](Invoke-ExternalCommand `
            -FilePath $pwshPath `
            -Arguments @('-NoProfile', '-NonInteractive', '-EncodedCommand', $encodedExternalTimeoutCommand) `
            -TimeoutSeconds 5)
    } catch {
        $externalTimeoutFailure = $_
    }
    if ($null -eq $externalTimeoutFailure -or
        $externalTimeoutFailure.Exception.Message -notmatch 'exceeded its 5-second deadline and was terminated') {
        throw 'Bounded external-command timeout case did not fail closed.'
    }
    if (-not (Test-Path -LiteralPath $externalTimeoutPidPath -PathType Leaf)) {
        throw 'Bounded external-command timeout child did not publish its PID.'
    }
    $externalTimeoutPid = [int][System.IO.File]::ReadAllText($externalTimeoutPidPath)
    $externalTimeoutSurvivor = Get-Process -Id $externalTimeoutPid -ErrorAction SilentlyContinue
    if ($null -ne $externalTimeoutSurvivor) {
        $externalTimeoutSurvivor.Dispose()
        throw "Bounded external-command timeout left exact child PID $externalTimeoutPid running."
    }

    $handshakeFailureIdentity = Start-OwnedTestProcess
    $handshakeFailureSignal = Join-Path $tempRoot 'handshake-failure.signal'
    $handshakeFailureLogDirectory = Join-Path $tempRoot 'handshake-failure.log'
    [void][System.IO.Directory]::CreateDirectory($handshakeFailureLogDirectory)
    $handshakeFailure = $null
    try {
        [void](Start-PrivateProcessWatchdog `
            -ProcessId $handshakeFailureIdentity.process_id `
            -ExpectedStartUtc $handshakeFailureIdentity.process_start_utc `
            -ExpectedPath $handshakeFailureIdentity.path `
            -TimeoutSeconds 5 `
            -SignalPath $handshakeFailureSignal `
            -LogPath $handshakeFailureLogDirectory `
            -Operation 'handshake_failure_case')
    } catch {
        $handshakeFailure = $_
    }
    if ($null -eq $handshakeFailure -or
        $handshakeFailure.Exception.Message -notmatch 'failed before its ARMED handshake') {
        throw 'Watchdog start did not fail closed when its ARMED transcript could not be written.'
    }
    $leakedHandshakeJobs = @(Get-Job | Where-Object {
        $_.Name -like "OxFormsMemberOracleWatchdog_$($handshakeFailureIdentity.process_id)_*"
    })
    if ($leakedHandshakeJobs.Count -ne 0) {
        throw 'Watchdog start leaked a background job after its ARMED handshake failed.'
    }
    Assert-OwnedProcessRunning $handshakeFailureIdentity

    $emergencyIdentity = Start-OwnedTestProcess
    Stop-ExactPrivateProcess -Identity $emergencyIdentity -Label 'Disposable emergency-cleanup case'
    $emergencySurvivor = Get-Process -Id ([int]$emergencyIdentity.process_id) -ErrorAction SilentlyContinue
    if ($null -ne $emergencySurvivor) {
        $emergencySurvivor.Dispose()
        throw 'Exact emergency cleanup left its disposable process running.'
    }

    $emergencyMismatchIdentity = Start-OwnedTestProcess
    $wrongEmergencyIdentity = [pscustomobject][ordered]@{
        process_id = $emergencyMismatchIdentity.process_id
        process_start_utc = ([DateTime]::Parse($emergencyMismatchIdentity.process_start_utc).AddSeconds(-1)).ToString('o')
        path = $emergencyMismatchIdentity.path
    }
    $emergencyMismatchFailure = $null
    try {
        Stop-ExactPrivateProcess -Identity $wrongEmergencyIdentity -Label 'Disposable identity-mismatch cleanup case'
    } catch {
        $emergencyMismatchFailure = $_
    }
    if ($null -eq $emergencyMismatchFailure -or
        $emergencyMismatchFailure.Exception.Message -notmatch 'refused emergency cleanup because PID/start/path identity changed') {
        throw 'Exact emergency cleanup did not fail closed for a mismatched identity.'
    }
    Assert-OwnedProcessRunning $emergencyMismatchIdentity

    $disarmIdentity = Start-OwnedTestProcess
    $disarmSignal = Join-Path $tempRoot 'disarm.signal'
    $disarmLog = Join-Path $tempRoot 'disarm.log'
    $disarmJob = Start-PrivateProcessWatchdog `
        -ProcessId $disarmIdentity.process_id `
        -ExpectedStartUtc $disarmIdentity.process_start_utc `
        -ExpectedPath $disarmIdentity.path `
        -TimeoutSeconds 5 `
        -SignalPath $disarmSignal `
        -LogPath $disarmLog `
        -Operation 'disarm_case'
    $jobs.Add($disarmJob)
    Complete-PrivateProcessWatchdog `
        -Job $disarmJob `
        -SignalPath $disarmSignal `
        -LogPath $disarmLog `
        -ProcessId $disarmIdentity.process_id `
        -Operation 'disarm_case' `
        -ExpectedTerminal 'disarm'
    [void]$jobs.Remove($disarmJob)
    Assert-OwnedProcessRunning $disarmIdentity
    $disarmLines = [System.IO.File]::ReadAllLines($disarmLog)
    if ($disarmLines.Count -ne 2 -or
        $disarmLines[0] -notmatch ' ARMED operation=disarm_case .* terminal_mode=disarm$' -or
        $disarmLines[1] -notmatch ' DISARMED operation=disarm_case .* reason=explicit_disarm$') {
        throw 'Watchdog disarm transcript is incomplete.'
    }

    $unexpectedExitIdentity = Start-OwnedTestProcess
    $unexpectedExitSignal = Join-Path $tempRoot 'unexpected-exit.signal'
    $unexpectedExitLog = Join-Path $tempRoot 'unexpected-exit.log'
    $unexpectedExitJob = Start-PrivateProcessWatchdog `
        -ProcessId $unexpectedExitIdentity.process_id `
        -ExpectedStartUtc $unexpectedExitIdentity.process_start_utc `
        -ExpectedPath $unexpectedExitIdentity.path `
        -TimeoutSeconds 5 `
        -SignalPath $unexpectedExitSignal `
        -LogPath $unexpectedExitLog `
        -Operation 'unexpected_exit_case' `
        -TerminalMode 'disarm'
    $jobs.Add($unexpectedExitJob)
    $unexpectedExitIdentity.process.Kill()
    [void]$unexpectedExitIdentity.process.WaitForExit(5000)
    if ($null -eq (Wait-Job -Job $unexpectedExitJob -Timeout 10)) {
        throw 'Unexpected-exit watchdog case did not reach a terminal record.'
    }
    $unexpectedFailure = $null
    try {
        Complete-PrivateProcessWatchdog `
            -Job $unexpectedExitJob `
            -SignalPath $unexpectedExitSignal `
            -LogPath $unexpectedExitLog `
            -ProcessId $unexpectedExitIdentity.process_id `
            -Operation 'unexpected_exit_case' `
            -ExpectedTerminal 'disarm'
    } catch {
        $unexpectedFailure = $_
    }
    [void]$jobs.Remove($unexpectedExitJob)
    if ($null -eq $unexpectedFailure -or
        $unexpectedFailure.Exception.Message -notmatch 'unexpected terminal record') {
        $observed = if ($null -eq $unexpectedFailure) { '<no failure>' } else { $unexpectedFailure.Exception.Message }
        throw "An ordinary watchdog phase accepted an unexpected process exit. Observed: $observed"
    }
    if ([System.IO.File]::ReadAllText($unexpectedExitLog) -notmatch ' PROCESS_EXITED operation=unexpected_exit_case .* reason=unexpected_exit$') {
        throw 'Unexpected process exit transcript is not explicit.'
    }

    $unauthorizedExitIdentity = Start-OwnedTestProcess
    $unauthorizedExitSignal = Join-Path $tempRoot 'unauthorized-expected-exit.signal'
    $unauthorizedExitLog = Join-Path $tempRoot 'unauthorized-expected-exit.log'
    $unauthorizedExitJob = Start-PrivateProcessWatchdog `
        -ProcessId $unauthorizedExitIdentity.process_id `
        -ExpectedStartUtc $unauthorizedExitIdentity.process_start_utc `
        -ExpectedPath $unauthorizedExitIdentity.path `
        -TimeoutSeconds 5 `
        -SignalPath $unauthorizedExitSignal `
        -LogPath $unauthorizedExitLog `
        -Operation 'unauthorized_exit_case' `
        -TerminalMode 'expected_exit'
    $jobs.Add($unauthorizedExitJob)
    $unauthorizedExitIdentity.process.Kill()
    [void]$unauthorizedExitIdentity.process.WaitForExit(5000)
    [System.IO.File]::WriteAllText($unauthorizedExitSignal, "expect_exit`n", $script:Utf8NoBom)
    if ($null -eq (Wait-Job -Job $unauthorizedExitJob -Timeout 10)) {
        throw 'Unauthorized expected-exit watchdog case did not reach a terminal record.'
    }
    $unauthorizedExitFailure = $null
    $unauthorizedSignalLock = [System.IO.File]::Open(
        $unauthorizedExitSignal,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::None
    )
    try {
        try {
            Complete-PrivateProcessWatchdog `
                -Job $unauthorizedExitJob `
                -SignalPath $unauthorizedExitSignal `
                -LogPath $unauthorizedExitLog `
                -ProcessId $unauthorizedExitIdentity.process_id `
                -Operation 'unauthorized_exit_case' `
                -ExpectedTerminal 'expected_exit'
        } catch {
            $unauthorizedExitFailure = $_
        }
    } finally {
        $unauthorizedSignalLock.Dispose()
        if (Test-Path -LiteralPath $unauthorizedExitSignal -PathType Leaf) {
            [System.IO.File]::Delete($unauthorizedExitSignal)
        }
    }
    [void]$jobs.Remove($unauthorizedExitJob)
    if ($null -eq $unauthorizedExitFailure -or
        $unauthorizedExitFailure.Exception.Message -notmatch 'unexpected terminal record.*Cleanup also failed' -or
        [System.IO.File]::ReadAllText($unauthorizedExitLog) -notmatch ' PROCESS_EXITED operation=unauthorized_exit_case .* reason=unexpected_exit$') {
        throw 'Expected-exit mode accepted an unauthorized exit or hid its concurrent signal-cleanup failure.'
    }

    $authorizationRaceSignal = Join-Path $tempRoot 'authorization-race.signal'
    $authorizationObservedSignal = $authorizationRaceSignal + '.observed'
    $authorizationRaceIdentity = Start-OwnedTestProcess
    $authorizationRaceLog = Join-Path $tempRoot 'authorization-race.log'
    $authorizationRaceJob = Start-PrivateProcessWatchdog `
        -ProcessId $authorizationRaceIdentity.process_id `
        -ExpectedStartUtc $authorizationRaceIdentity.process_start_utc `
        -ExpectedPath $authorizationRaceIdentity.path `
        -TimeoutSeconds 5 `
        -SignalPath $authorizationRaceSignal `
        -LogPath $authorizationRaceLog `
        -Operation 'authorization_race_case' `
        -TerminalMode 'expected_exit'
    $jobs.Add($authorizationRaceJob)
    $authorizationRaceStaging = $authorizationRaceSignal + '.tmp'
    [System.IO.File]::WriteAllText($authorizationRaceStaging, "expect_exit`n", $script:Utf8NoBom)
    [System.IO.File]::Move($authorizationRaceStaging, $authorizationRaceSignal)
    $authorizationObservationDeadline = [DateTime]::UtcNow.AddSeconds(5)
    while (-not (Test-Path -LiteralPath $authorizationObservedSignal -PathType Leaf) -and
        [DateTime]::UtcNow -lt $authorizationObservationDeadline) {
        Start-Sleep -Milliseconds 10
    }
    if (-not (Test-Path -LiteralPath $authorizationObservedSignal -PathType Leaf)) {
        throw 'Authorization-race watchdog did not publish its pre-ack observation marker.'
    }
    $authorizationRaceIdentity.process.Kill()
    [void]$authorizationRaceIdentity.process.WaitForExit(5000)
    if ($null -eq (Wait-Job -Job $authorizationRaceJob -Timeout 10)) {
        throw 'Expected-exit authorization-race watchdog case did not reach a terminal record.'
    }
    $authorizationRaceFailure = $null
    try {
        Complete-PrivateProcessWatchdog `
            -Job $authorizationRaceJob `
            -SignalPath $authorizationRaceSignal `
            -LogPath $authorizationRaceLog `
            -ProcessId $authorizationRaceIdentity.process_id `
            -Operation 'authorization_race_case' `
            -ExpectedTerminal 'expected_exit'
    } catch {
        $authorizationRaceFailure = $_
    }
    [void]$jobs.Remove($authorizationRaceJob)
    if ($null -eq $authorizationRaceFailure -or
        $authorizationRaceFailure.Exception.Message -notmatch 'unexpected terminal record' -or
        [System.IO.File]::ReadAllText($authorizationRaceLog) -notmatch ' PROCESS_EXITED operation=authorization_race_case .* reason=unexpected_exit$') {
        throw 'Expected-exit mode acknowledged a process that exited after authorization observation but before final exact-identity revalidation.'
    }

    $expectedChildExitSignal = Join-Path $tempRoot 'expected-child-exit.signal'
    $expectedExitIdentity = Start-OwnedTestProcess -ExitSignalPath $expectedChildExitSignal
    $expectedExitSignal = Join-Path $tempRoot 'expected-exit.signal'
    $expectedExitLog = Join-Path $tempRoot 'expected-exit.log'
    $expectedExitJob = Start-PrivateProcessWatchdog `
        -ProcessId $expectedExitIdentity.process_id `
        -ExpectedStartUtc $expectedExitIdentity.process_start_utc `
        -ExpectedPath $expectedExitIdentity.path `
        -TimeoutSeconds 5 `
        -SignalPath $expectedExitSignal `
        -LogPath $expectedExitLog `
        -Operation 'expected_exit_case' `
        -TerminalMode 'expected_exit'
    $jobs.Add($expectedExitJob)
    Authorize-PrivateProcessExpectedExit -SignalPath $expectedExitSignal
    [System.IO.File]::WriteAllText($expectedChildExitSignal, "exit`n", $script:Utf8NoBom)
    Complete-PrivateProcessWatchdog `
        -Job $expectedExitJob `
        -SignalPath $expectedExitSignal `
        -LogPath $expectedExitLog `
        -ProcessId $expectedExitIdentity.process_id `
        -Operation 'expected_exit_case' `
        -ExpectedTerminal 'expected_exit'
    [void]$jobs.Remove($expectedExitJob)
    if ([System.IO.File]::ReadAllText($expectedExitLog) -notmatch ' PROCESS_EXITED operation=expected_exit_case .* reason=expected_exit$') {
        throw 'Expected shutdown exit transcript is not explicit.'
    }

    $timeoutIdentity = Start-OwnedTestProcess
    $timeoutSignal = Join-Path $tempRoot 'timeout.signal'
    $timeoutLog = Join-Path $tempRoot 'timeout.log'
    $timeoutJob = Start-PrivateProcessWatchdog `
        -ProcessId $timeoutIdentity.process_id `
        -ExpectedStartUtc $timeoutIdentity.process_start_utc `
        -ExpectedPath $timeoutIdentity.path `
        -TimeoutSeconds 2 `
        -SignalPath $timeoutSignal `
        -LogPath $timeoutLog `
        -Operation 'timeout_case'
    $jobs.Add($timeoutJob)
    $completed = Wait-Job -Job $timeoutJob -Timeout 10
    if ($null -eq $completed) { throw 'Watchdog timeout case did not complete.' }
    [void](Receive-Job -Job $timeoutJob -ErrorAction SilentlyContinue 2>&1)
    Remove-Job -Job $timeoutJob -Force -ErrorAction SilentlyContinue
    [void]$jobs.Remove($timeoutJob)
    Start-Sleep -Milliseconds 200
    $timeoutSurvivor = Get-Process -Id ([int]$timeoutIdentity.process_id) -ErrorAction SilentlyContinue
    if ($null -ne $timeoutSurvivor) {
        $timeoutSurvivor.Dispose()
        throw 'Watchdog did not terminate its exact disposable process after timeout.'
    }
    if ([System.IO.File]::ReadAllText($timeoutLog) -notmatch ' TERMINATED operation=timeout_case ') {
        throw 'Watchdog timeout transcript does not record exact-process termination.'
    }

    $mismatchIdentity = Start-OwnedTestProcess
    $mismatchSignal = Join-Path $tempRoot 'mismatch.signal'
    $mismatchLog = Join-Path $tempRoot 'mismatch.log'
    $wrongStart = ([DateTime]::Parse($mismatchIdentity.process_start_utc).AddSeconds(-1)).ToString('o')
    $mismatchJob = Start-PrivateProcessWatchdog `
        -ProcessId $mismatchIdentity.process_id `
        -ExpectedStartUtc $wrongStart `
        -ExpectedPath $mismatchIdentity.path `
        -TimeoutSeconds 2 `
        -SignalPath $mismatchSignal `
        -LogPath $mismatchLog `
        -Operation 'identity_mismatch_case'
    $jobs.Add($mismatchJob)
    $completed = Wait-Job -Job $mismatchJob -Timeout 10
    if ($null -eq $completed) { throw 'Watchdog identity-mismatch case did not complete.' }
    $mismatchJobErrors = @(Receive-Job -Job $mismatchJob -ErrorAction SilentlyContinue 2>&1)
    if ($mismatchJob.State -ne 'Failed') {
        throw "Identity-mismatch watchdog should fail closed, observed state '$($mismatchJob.State)'."
    }
    Remove-Job -Job $mismatchJob -Force -ErrorAction SilentlyContinue
    [void]$jobs.Remove($mismatchJob)
    Assert-OwnedProcessRunning $mismatchIdentity
    $mismatchTranscript = [System.IO.File]::ReadAllText($mismatchLog)
    if ($mismatchTranscript -notmatch ' IDENTITY_MISMATCH operation=identity_mismatch_case .*reason=poll_identity_changed') {
        throw "Watchdog identity-mismatch transcript is incomplete: $mismatchTranscript Job output: $($mismatchJobErrors -join ' | ')"
    }

    Write-Host 'Suspended Job containment (including descendant and abrupt-supervisor death), pinned workbook handoff, shared-log reading, private-process watchdog handshake, cleanup aggregation, exact emergency cleanup, terminal-mode, timeout, and identity-mismatch checks passed.'
} finally {
    foreach ($job in @($jobs)) {
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
    foreach ($identity in @($ownedProcesses)) {
        $process = Get-Process -Id ([int]$identity.process_id) -ErrorAction SilentlyContinue
        if ($null -eq $process) { continue }
        try {
            if ($process.StartTime.ToUniversalTime().ToString('o') -cne $identity.process_start_utc -or
                -not ([string]$process.Path).Equals($identity.path, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Refusing to clean up PID $($identity.process_id) because its identity changed."
            }
            $process.Kill()
        } finally {
            $process.Dispose()
        }
    }
    foreach ($identity in @($ownedProcesses)) { $identity.process.Dispose() }
    if ([System.IO.Directory]::Exists($tempRoot)) {
        [System.IO.Directory]::Delete($tempRoot, $true)
    }
}
