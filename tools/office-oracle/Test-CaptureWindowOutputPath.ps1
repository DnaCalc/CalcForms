[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$captureTool = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'Capture-Window.ps1'))
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $captureTool,
    [ref]$tokens,
    [ref]$parseErrors
)
if ($parseErrors.Count -gt 0) {
    throw "Capture-Window.ps1 has PowerShell parse errors: $($parseErrors.Message -join '; ')"
}

$captureText = [System.IO.File]::ReadAllText($captureTool)
foreach ($requiredNativeProcessIdentityText in @(
    'private static extern bool GetProcessTimes(',
    'DateTime.FromFileTimeUtc(fileTime).ToString("o", CultureInfo.InvariantCulture)',
    '[OxForms.OfficeOracle.NativeMethods]::GetProcessStartTimeUtc($process.Handle)'
)) {
    if (-not $captureText.Contains($requiredNativeProcessIdentityText, [System.StringComparison]::Ordinal)) {
        throw "Capture-Window.ps1 lacks native exact process-start identity behavior: $requiredNativeProcessIdentityText"
    }
}
if ($captureText.Contains('.StartTime.ToUniversalTime()', [System.StringComparison]::Ordinal)) {
    throw 'Capture-Window.ps1 uses timezone-sensitive managed Process.StartTime for exact identity.'
}

$parameterNames = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
foreach ($requiredParameter in @('RepoRoot', 'ExpectedScriptSha256')) {
    if ($requiredParameter -notin $parameterNames) {
        throw "Capture-Window.ps1 must expose the explicit -$requiredParameter input."
    }
}

$scriptParameterNames = @($ast.ParamBlock.Parameters | ForEach-Object {
    $_.Name.VariablePath.UserPath.ToLowerInvariant()
})
$scriptContextCollisions = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
        $node.Left.VariablePath.IsScript -and
        $scriptParameterNames -contains $node.Left.VariablePath.UserPath.ToLowerInvariant()
    },
    $true
))
if ($scriptContextCollisions.Count -ne 0) {
    throw "Capture-Window.ps1 script-context assignments collide case-insensitively with script parameters: $($scriptContextCollisions.Left.Extent.Text -join ', ')."
}

$contextInitializers = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Initialize-CaptureContext'
    },
    $true
))
if ($contextInitializers.Count -ne 1) {
    throw "Expected exactly one capture-context initialization call, found $($contextInitializers.Count)."
}
$contextInitializationText = $contextInitializers[0].Extent.Text
foreach ($requiredBinding in @('$RepoRoot', '$ExpectedScriptSha256', '$PSCommandPath')) {
    if ($contextInitializationText.IndexOf($requiredBinding, [System.StringComparison]::Ordinal) -lt 0) {
        throw "Capture context initialization must bind $requiredBinding."
    }
}

$resolverDefinitions = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Resolve-CaptureOutDir'
    },
    $true
))
if ($resolverDefinitions.Count -ne 1) {
    throw "Expected exactly one Resolve-CaptureOutDir definition, found $($resolverDefinitions.Count)."
}

# Load only the path/write policy dependencies. This keeps the policy test
# independent of Excel, screenshots, and Capture-Window.ps1's main entry point
# while exercising the production functions verbatim. On Windows the native
# type also supplies directory-handle identity APIs; no desktop API is called.
foreach ($functionName in @(
    'Test-RunningOnWindows',
    'ConvertTo-JsonText',
    'Get-Sha256Hex',
    'Initialize-CaptureContext',
    'Write-Manifest',
    'Resolve-CaptureOutDir',
    'Ensure-WindowsNativeTypes',
    'ConvertFrom-WindowsFinalPath',
    'Get-PinnedDirectoryObservation',
    'Open-PinnedOutputDirectory',
    'Assert-PinnedOutputDirectory',
    'Add-PinnedOutputDirectoryChain',
    'Close-PinnedOutputDirectories'
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

$currentStateDefinitions = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Get-CurrentWindowCaptureState'
    },
    $true
))
$comparatorDefinitions = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Assert-ExactSelectedWindowState'
    },
    $true
))
$revalidationDefinitions = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Get-RevalidatedWindowCaptureState'
    },
    $true
))
$screenshotDefinitions = @($ast.FindAll(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Save-WindowScreenshot'
    },
    $true
))
if ($currentStateDefinitions.Count -ne 1 -or
    $comparatorDefinitions.Count -ne 1 -or
    $revalidationDefinitions.Count -ne 1 -or
    $screenshotDefinitions.Count -ne 1) {
    throw 'Expected exactly one current-state reader, exact comparator, revalidation wrapper, and screenshot function.'
}
$currentStateText = $currentStateDefinitions[0].Extent.Text
$comparatorText = $comparatorDefinitions[0].Extent.Text
$revalidationText = $revalidationDefinitions[0].Extent.Text
$screenshotText = $screenshotDefinitions[0].Extent.Text
foreach ($requiredIdentityRead in @(
    'Get-WindowTextValue',
    'Get-ClassNameValue',
    'GetWindowThreadProcessId',
    'process_start_time_utc',
    'process_path',
    'GetWindowRect',
    'IsWindowVisible',
    'GetForegroundWindow'
)) {
    if ($currentStateText.IndexOf($requiredIdentityRead, [System.StringComparison]::Ordinal) -lt 0) {
        throw "Current screenshot-state read is missing '$requiredIdentityRead'."
    }
}
foreach ($requiredComparison in @('handle', 'title', 'class_name', 'process_id', 'process_start_time_utc', 'process_path', 'bounds', 'visible', 'foreground')) {
    if ($comparatorText.IndexOf($requiredComparison, [System.StringComparison]::Ordinal) -lt 0) {
        throw "Exact selected/current comparator is missing '$requiredComparison'."
    }
}
foreach ($requiredWrapperCheck in @('Get-CurrentWindowCaptureState', 'Assert-ExactSelectedWindowState')) {
    if ($revalidationText.IndexOf($requiredWrapperCheck, [System.StringComparison]::Ordinal) -lt 0) {
        throw "Screenshot revalidation wrapper is missing '$requiredWrapperCheck'."
    }
}
foreach ($requiredCaptureCheck in @('Get-RevalidatedWindowCaptureState', 'CopyFromScreen', 'screen_coordinates', 'visual_review_required', 'state_bracket')) {
    if ($screenshotText.IndexOf($requiredCaptureCheck, [System.StringComparison]::Ordinal) -lt 0) {
        throw "Screenshot capture is missing '$requiredCaptureCheck'."
    }
}
$beforeIndex = $screenshotText.IndexOf('immediately-before-CopyFromScreen', [System.StringComparison]::Ordinal)
$copyIndex = $screenshotText.IndexOf('CopyFromScreen(', [System.StringComparison]::Ordinal)
$afterIndex = $screenshotText.IndexOf('immediately-after-CopyFromScreen', [System.StringComparison]::Ordinal)
if ($beforeIndex -lt 0 -or $copyIndex -le $beforeIndex -or $afterIndex -le $copyIndex) {
    throw 'Screenshot capture must bracket CopyFromScreen with ordered immediate before/after exact-state reads.'
}

$Script:PinnedOutputDirectories = [System.Collections.Generic.List[object]]::new()

function Assert-AcceptedPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Expected
    )

    try {
        $actual = Resolve-CaptureOutDir -Directory $Path
    }
    catch {
        throw "Expected capture output path to be accepted: '$Path': $($_.Exception.Message)"
    }

    $expectedFullPath = [System.IO.Path]::GetFullPath($Expected)
    if (-not $actual.Equals($expectedFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Resolved path mismatch for '$Path': expected '$expectedFullPath', observed '$actual'."
    }
    if (-not (Test-Path -LiteralPath $actual -PathType Container)) {
        throw "Accepted capture output path was not created as a directory: '$actual'."
    }
}

function Assert-RejectedPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$MessagePattern
    )

    $message = $null
    try {
        [void](Resolve-CaptureOutDir -Directory $Path)
    }
    catch {
        $message = $_.Exception.Message
    }

    if ([string]::IsNullOrWhiteSpace($message)) {
        throw "Expected capture output path to be rejected: '$Path'."
    }
    if ($message -notmatch $MessagePattern) {
        throw "Unexpected rejection for '$Path': '$message' did not match '$MessagePattern'."
    }
}

$testId = [Guid]::NewGuid().ToString('N')
$workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$tempParent = Join-Path $workspaceRoot 'target\test-office-oracle'
[void][System.IO.Directory]::CreateDirectory($tempParent)
$tempRoot = [System.IO.Path]::GetFullPath((Join-Path $tempParent "capture-window-path-policy-$testId"))
$tempRootPrefix = [System.IO.Path]::GetFullPath($tempParent).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
if (-not $tempRoot.StartsWith($tempRootPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
    -not ([System.IO.Path]::GetFileName($tempRoot)).StartsWith('capture-window-path-policy-', [System.StringComparison]::Ordinal)) {
    throw "Refusing unsafe path-policy test root: '$tempRoot'."
}

$Script:CaptureRepoRoot = Join-Path $tempRoot 'repo'
$Script:EvidenceRoot = Join-Path $Script:CaptureRepoRoot 'docs\evidence'
$reparsePath = $null
$renameSource = $null
$renameDestination = $null
$replacementTarget = $null
$renameJob = $null

try {
    $explicitRepoRoot = Join-Path $tempRoot 'repo'
    $explicitEvidenceRoot = Join-Path $explicitRepoRoot 'docs\evidence'
    [void][System.IO.Directory]::CreateDirectory($explicitEvidenceRoot)

    $captureToolHash = Get-Sha256Hex -Path $captureTool
    Initialize-CaptureContext -Root $explicitRepoRoot -ExpectedHash $captureToolHash -ScriptPath $captureTool
    if (-not $Script:CaptureRepoRoot.Equals([System.IO.Path]::GetFullPath($explicitRepoRoot), [System.StringComparison]::OrdinalIgnoreCase) -or
        -not $Script:EvidenceRoot.Equals([System.IO.Path]::GetFullPath($explicitEvidenceRoot), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Explicit repository-root initialization did not bind the expected capture context.'
    }

    $hashMismatch = $null
    try {
        Initialize-CaptureContext -Root $explicitRepoRoot -ExpectedHash ('0' * 64) -ScriptPath $captureTool
    }
    catch {
        $hashMismatch = $_.Exception.Message
    }
    if ([string]::IsNullOrWhiteSpace($hashMismatch) -or $hashMismatch -notmatch 'SHA-256 mismatch') {
        throw 'Capture context initialization must reject a mismatched executing-script SHA-256.'
    }

    # Restore the validated context after the deliberate mismatch probe.
    Initialize-CaptureContext -Root $explicitRepoRoot -ExpectedHash $captureToolHash.ToUpperInvariant() -ScriptPath $captureTool

    $encodingProbeDirectory = Resolve-CaptureOutDir -Directory 'docs\evidence\W010_test\captures\manifest-encoding'
    $pinnedPaths = @($Script:PinnedOutputDirectories | ForEach-Object { [string]$_.path })
    if ($pinnedPaths -notcontains [System.IO.Path]::GetFullPath($Script:EvidenceRoot) -or
        $pinnedPaths -contains [System.IO.Path]::GetFullPath($Script:CaptureRepoRoot)) {
        throw 'The no-delete output chain must start at the validated evidence root, not the process current-directory repository root.'
    }
    $encodingProbe = [pscustomobject][ordered]@{ schema = 'encoding-probe'; manifest_path = $null }
    Write-Manifest -Result $encodingProbe -Directory $encodingProbeDirectory -FileName 'manifest.json'
    $encodingBytes = [System.IO.File]::ReadAllBytes((Join-Path $encodingProbeDirectory 'manifest.json'))
    if ($encodingBytes.Length -lt 2 -or
        ($encodingBytes.Length -ge 3 -and $encodingBytes[0] -eq 0xEF -and $encodingBytes[1] -eq 0xBB -and $encodingBytes[2] -eq 0xBF) -or
        $encodingBytes[-1] -ne 0x0A -or
        $encodingBytes -contains 0x0D) {
        throw 'Capture-Window manifest bytes must be UTF-8 without BOM, LF-only, and final-newline terminated.'
    }

    $legacyExpected = Join-Path $Script:EvidenceRoot 'W010_test\captures\legacy-batch\initial'
    Assert-AcceptedPath -Path 'docs\evidence\W010_test\captures\legacy-batch\initial' -Expected $legacyExpected

    $beadCaptureRoot = Join-Path $Script:EvidenceRoot 'W010_complete_msforms_object_model_parity\beads\oxforms-jbjp.5\captures'
    Assert-AcceptedPath -Path $beadCaptureRoot -Expected $beadCaptureRoot

    $beadExpected = Join-Path $beadCaptureRoot 'representative-batch\after-selection'
    Assert-AcceptedPath -Path $beadExpected -Expected $beadExpected

    if (Test-RunningOnWindows) {
        # Exercise the exact rename-then-junction substitution an attacker
        # would need while a capture write is in flight. This runs in another
        # process while the production no-delete handle chain remains retained.
        $renameSource = $beadExpected
        $renameDestination = "$beadExpected-renamed"
        $replacementTarget = Join-Path $tempRoot 'replacement-target'
        [void][System.IO.Directory]::CreateDirectory($replacementTarget)
        $renameJob = Start-Job -ScriptBlock {
            param($Source, $Destination, $Target)

            $renameStatus = 'not-attempted'
            $junctionStatus = 'not-attempted'
            $message = $null
            try {
                [System.IO.Directory]::Move($Source, $Destination)
                $renameStatus = 'succeeded'
                try {
                    [void](New-Item -ItemType Junction -Path $Source -Target $Target -ErrorAction Stop)
                    $junctionStatus = 'succeeded'
                }
                catch {
                    $junctionStatus = 'failed'
                    $message = $_.Exception.Message
                }
            }
            catch {
                $renameStatus = 'blocked'
                $message = $_.Exception.Message
            }
            [pscustomobject]@{
                rename_status = $renameStatus
                junction_status = $junctionStatus
                message = $message
            }
        } -ArgumentList $renameSource, $renameDestination, $replacementTarget
        $completedRenameJob = Wait-Job -Job $renameJob -Timeout 15
        if ($null -eq $completedRenameJob -or $completedRenameJob.State -ne 'Completed') {
            throw 'Concurrent rename/junction substitution probe did not complete within 15 seconds.'
        }
        $attackResult = @(Receive-Job -Job $renameJob)
        if ($attackResult.Count -ne 1 -or $attackResult[0].rename_status -ne 'blocked') {
            $detail = if ($attackResult.Count -eq 1) {
                "rename=$($attackResult[0].rename_status), junction=$($attackResult[0].junction_status), message=$($attackResult[0].message)"
            }
            else {
                "result-count=$($attackResult.Count)"
            }
            throw "Pinned output directory permitted concurrent rename/junction substitution: $detail"
        }
        Assert-PinnedOutputDirectory -Directory $renameSource
        $renamedItem = Get-Item -LiteralPath $renameSource -Force -ErrorAction Stop
        if (($renamedItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0 -or
            [System.IO.Directory]::Exists($renameDestination)) {
            throw 'Pinned output directory changed after the concurrent rename/junction substitution probe.'
        }
        Remove-Job -Job $renameJob -Force
        $renameJob = $null
    }

    Assert-RejectedPath -Path (Join-Path $Script:EvidenceRoot 'W010_test\oracle\captures\arbitrary') -MessagePattern 'must be under either'
    $laterBeadExpected = Join-Path $Script:EvidenceRoot 'W010_complete_msforms_object_model_parity\beads\oxforms-jbjp.15\captures\later-batch'
    Assert-AcceptedPath -Path $laterBeadExpected -Expected $laterBeadExpected

    Assert-RejectedPath -Path (Join-Path $Script:EvidenceRoot 'W010_test\beads\oxforms-jbjp.4\captures\wrong-workset') -MessagePattern 'must be under either'
    Assert-RejectedPath -Path (Join-Path $Script:EvidenceRoot 'W010_complete_msforms_object_model_parity\beads\other.5\captures\wrong-bead') -MessagePattern 'must be under either'
    Assert-RejectedPath -Path (Join-Path $Script:EvidenceRoot 'W010_complete_msforms_object_model_parity\beads\oxforms-jbjp.5\oracle\captures\wrong-shape') -MessagePattern 'must be under either'
    Assert-RejectedPath -Path (Join-Path $Script:EvidenceRoot 'W010_complete_msforms_object_model_parity\beads\extra\oxforms-jbjp.5\captures\wrong-depth') -MessagePattern 'must be under either'
    Assert-RejectedPath -Path (Join-Path $tempRoot 'outside-evidence\captures\escape') -MessagePattern 'outside the repository evidence root'

    $separator = [System.IO.Path]::DirectorySeparatorChar
    $traversalPath = [string]::Join($separator, @('docs', 'evidence', 'W010_test', 'captures', 'safe', '..', 'traversed'))
    Assert-RejectedPath -Path $traversalPath -MessagePattern 'traversal'

    $fileComponent = Join-Path $Script:EvidenceRoot 'W010_test\captures\file-component'
    [System.IO.File]::WriteAllText($fileComponent, 'not a directory')
    Assert-RejectedPath -Path (Join-Path $fileComponent 'child') -MessagePattern 'traverses a file'

    $reparseTarget = Join-Path $Script:EvidenceRoot 'W010_test\captures\reparse-target'
    [void][System.IO.Directory]::CreateDirectory($reparseTarget)
    $reparsePath = Join-Path $Script:EvidenceRoot 'W010_test\captures\reparse-link'
    if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
        [void](New-Item -ItemType Junction -Path $reparsePath -Target $reparseTarget)
    }
    else {
        [void](New-Item -ItemType SymbolicLink -Path $reparsePath -Target $reparseTarget)
    }
    Assert-RejectedPath -Path (Join-Path $reparsePath 'child') -MessagePattern 'symlink|junction|reparse point'

    Write-Host 'Capture-Window output-path policy checks passed without Windows desktop or Excel dependencies.'
}
finally {
    if ($null -ne $renameJob) {
        Stop-Job -Job $renameJob -ErrorAction SilentlyContinue
        Remove-Job -Job $renameJob -Force -ErrorAction SilentlyContinue
    }
    Close-PinnedOutputDirectories
    if ($null -ne $reparsePath -and (Test-Path -LiteralPath $reparsePath)) {
        [System.IO.Directory]::Delete($reparsePath)
    }
    if ($null -ne $renameSource -and (Test-Path -LiteralPath $renameSource)) {
        $renameSourceItem = Get-Item -LiteralPath $renameSource -Force -ErrorAction SilentlyContinue
        if ($null -ne $renameSourceItem -and
            ($renameSourceItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            [System.IO.Directory]::Delete($renameSource)
        }
    }
    if ([System.IO.Directory]::Exists($tempRoot)) {
        [System.IO.Directory]::Delete($tempRoot, $true)
    }
}
