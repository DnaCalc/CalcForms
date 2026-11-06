#requires -Version 7.2
[CmdletBinding()]
param(
    [string]$ManifestPath = 'fixtures/office-oracle/excel-msforms/member-probes/representative-v1.json',
    [string]$OutDir,
    [string]$CaptureId,
    [switch]$DryRun,
    [switch]$GenerateOnly,
    # Shared capture functions for later versioned oracle contracts. Loading
    # definitions performs no generation, file mutation, or Office automation.
    [switch]$LoadFunctionsOnly,
    [ValidateRange(5, 120)]
    [int]$WindowTimeoutSeconds = 30,
    [ValidateRange(10, 300)]
    [int]$MacroTimeoutSeconds = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$script:EvidenceBeadsRoot = Join-Path $script:RepoRoot 'docs\evidence\W010_complete_msforms_object_model_parity\beads'
$script:ManifestRoot = Join-Path $script:RepoRoot 'fixtures\office-oracle\excel-msforms\member-probes'
$script:GeneratorPath = Join-Path $PSScriptRoot 'msforms_member_oracle.py'
$script:WindowCapturePath = Join-Path $PSScriptRoot 'Capture-Window.ps1'
$script:FrmInventoryPath = Join-Path $script:RepoRoot 'tools\forms-persistence\frm_text_inventory.py'
$script:CfbInventoryPath = Join-Path $script:RepoRoot 'tools\forms-persistence\cfb_inventory.py'
$script:Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Test-IsWindows {
    return [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
        [System.Runtime.InteropServices.OSPlatform]::Windows
    )
}

function Test-PathWithin {
    param(
        [Parameter(Mandatory = $true)][string]$Candidate,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $candidateFull = [System.IO.Path]::GetFullPath($Candidate)
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $prefix = $rootFull + [System.IO.Path]::DirectorySeparatorChar
    return $candidateFull.Equals($rootFull, [System.StringComparison]::OrdinalIgnoreCase) -or
        $candidateFull.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-NoReparsePointInPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $full = [System.IO.Path]::GetFullPath($Path)
    $volume = [System.IO.Path]::GetPathRoot($full)
    if ([string]::IsNullOrWhiteSpace($volume)) { throw "Path has no volume root: '$Path'." }
    $current = $volume
    foreach ($part in @($full.Substring($volume.Length) -split '[\\/]' | Where-Object Length -gt 0)) {
        $current = Join-Path $current $part
        if (-not (Test-Path -LiteralPath $current)) { continue }
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse points are forbidden in oracle paths: '$($item.FullName)'."
        }
    }
}

function Assert-NoReparsePointTree {
    param([Parameter(Mandatory = $true)][string]$Path)

    Assert-NoReparsePointInPath $Path
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return }
    foreach ($item in @(Get-ChildItem -LiteralPath $Path -Force -Recurse)) {
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse points are forbidden in staged oracle output: '$($item.FullName)'."
        }
    }
}

function Resolve-RepoFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$AllowedRoot,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $full = if ([System.IO.Path]::IsPathRooted($Path)) {
        [System.IO.Path]::GetFullPath($Path)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $script:RepoRoot $Path))
    }
    if (-not (Test-PathWithin $full $AllowedRoot)) {
        throw "$Label '$Path' resolves outside '$AllowedRoot'."
    }
    Assert-NoReparsePointInPath $full
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "$Label does not exist: '$full'." }
    return (Get-Item -LiteralPath $full -Force).FullName
}

function Resolve-EvidenceOutDir {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [switch]$AllowExisting
    )

    $full = if ([System.IO.Path]::IsPathRooted($Path)) {
        [System.IO.Path]::GetFullPath($Path)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $script:RepoRoot $Path))
    }
    if (-not (Test-PathWithin $full $script:EvidenceCaptureRoot) -or
        $full.Equals([System.IO.Path]::GetFullPath($script:EvidenceCaptureRoot), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Output must be a child of '$script:EvidenceCaptureRoot'."
    }
    $relative = [System.IO.Path]::GetRelativePath($script:RepoRoot, $full)
    if ($relative.Contains(':') -or $relative.IndexOfAny([char[]]@(0..31 + 127)) -ge 0) {
        throw "Output path contains an alternate-stream separator or control character: '$Path'."
    }
    Assert-NoReparsePointInPath $full
    if (Test-Path -LiteralPath $full) {
        if (-not $AllowExisting) { throw "Fresh capture output already exists: '$full'." }
        if (-not (Test-Path -LiteralPath $full -PathType Container)) { throw "Existing output is not a directory: '$full'." }
    }
    return $full
}

function Convert-ToRepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $full = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-PathWithin $full $script:RepoRoot)) { throw "Path is outside the repository: '$full'." }
    return [System.IO.Path]::GetRelativePath($script:RepoRoot, $full).Replace('\', '/')
}

function New-StagingDirectory {
    param([Parameter(Mandatory = $true)][string]$Target)

    $parent = [System.IO.Path]::GetDirectoryName($Target)
    if ([string]::IsNullOrWhiteSpace($parent)) { throw "Output has no parent: '$Target'." }
    Assert-NoReparsePointInPath $parent
    [void][System.IO.Directory]::CreateDirectory($parent)
    Assert-NoReparsePointInPath $parent
    $name = '.{0}.capture-staging-{1}' -f [System.IO.Path]::GetFileName($Target), [Guid]::NewGuid().ToString('N')
    $stage = Join-Path $parent $name
    if (Test-Path -LiteralPath $stage) { throw "Fresh staging path unexpectedly exists: '$stage'." }
    [void][System.IO.Directory]::CreateDirectory($stage)
    Assert-NoReparsePointInPath $stage
    return $stage
}

function Normalize-Lf {
    param([AllowEmptyString()][string]$Text)
    if ($null -eq $Text) { return '' }
    return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Write-TextLf {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [AllowEmptyString()][string]$Text,
        [switch]$FinalNewline
    )
    $normalized = Normalize-Lf $Text
    if ($FinalNewline -and -not $normalized.EndsWith("`n", [System.StringComparison]::Ordinal)) {
        $normalized += "`n"
    }
    [System.IO.File]::WriteAllText($Path, $normalized, $script:Utf8NoBom)
}

function Write-JsonLf {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )
    $json = $Value | ConvertTo-Json -Depth 100
    Write-TextLf -Path $Path -Text $json -FinalNewline
}

function Add-Progress {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Message
    )
    $line = '{0} {1}' -f [DateTime]::UtcNow.ToString('o'), $Message
    [System.IO.File]::AppendAllText($Path, $line + "`n", $script:Utf8NoBom)
}

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-StreamSha256 {
    param([Parameter(Mandatory = $true)][System.IO.Stream]$Stream)

    if (-not $Stream.CanRead -or -not $Stream.CanSeek) {
        throw 'SHA-256 stream must be readable and seekable.'
    }
    $originalPosition = $Stream.Position
    try {
        $Stream.Position = 0
        $hasher = [System.Security.Cryptography.SHA256]::Create()
        try {
            return [Convert]::ToHexString($hasher.ComputeHash($Stream)).ToLowerInvariant()
        } finally {
            $hasher.Dispose()
        }
    } finally {
        $Stream.Position = $originalPosition
    }
}

function Read-SharedUtf8Lines {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [ValidateRange(100, 10000)][int]$TimeoutMilliseconds = 2000
    )

    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    $lastFailure = $null
    do {
        $stream = $null
        $reader = $null
        try {
            $sharing = [System.IO.FileShare](
                [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
            )
            $stream = [System.IO.File]::Open(
                $Path,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                $sharing
            )
            $reader = [System.IO.StreamReader]::new($stream, $script:Utf8NoBom, $true)
            $normalized = Normalize-Lf $reader.ReadToEnd()
            if ($normalized.EndsWith("`n", [System.StringComparison]::Ordinal)) {
                $normalized = $normalized.Substring(0, $normalized.Length - 1)
            }
            if ($normalized.Length -eq 0) { return @() }
            return @($normalized -split "`n")
        } catch [System.IO.IOException] {
            $lastFailure = $_
            if ([DateTime]::UtcNow -ge $deadline) { break }
            Start-Sleep -Milliseconds 20
        } finally {
            if ($null -ne $reader) {
                $reader.Dispose()
            } elseif ($null -ne $stream) {
                $stream.Dispose()
            }
        }
    } while ($true)
    throw "Shared UTF-8 log remained unavailable for $TimeoutMilliseconds milliseconds: $($lastFailure.Exception.Message)"
}

function Get-BytesSha256 {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes)

    $hasher = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [Convert]::ToHexString($hasher.ComputeHash($Bytes)).ToLowerInvariant()
    } finally {
        $hasher.Dispose()
    }
}

function Assert-FileSha256 {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedSha256,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if ((Get-Sha256 $Path) -cne $ExpectedSha256) {
        throw "$Label changed during the capture."
    }
}

function Read-FrozenUtf8Json {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $digest = Get-BytesSha256 $bytes
    Assert-FileSha256 -Path $Path -ExpectedSha256 $digest -Label "$Label after retained-byte read"
    $strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
    try {
        $text = $strictUtf8.GetString($bytes)
    } catch {
        throw "$Label is not strict UTF-8: $($_.Exception.Message)"
    }
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xfeff) {
        throw "$Label must not begin with a UTF-8 byte-order mark."
    }
    try {
        $value = $text | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "$Label is not valid JSON: $($_.Exception.Message)"
    }
    Assert-FileSha256 -Path $Path -ExpectedSha256 $digest -Label "$Label after retained-byte parse"
    return [pscustomobject][ordered]@{
        bytes = $bytes
        sha256 = $digest
        value = $value
    }
}

function Assert-ReplayValidatorPin {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)]
        [ValidateSet('frm_inventory', 'cfb_inventory')]
        [string]$Role,
        [Parameter(Mandatory = $true)][string]$SourcePath,
        $Snapshot
    )

    $validators = Get-RequiredProperty $Manifest 'replay_validators'
    $pin = Get-RequiredProperty $validators $Role
    $expectedRepoPath = Convert-ToRepoPath $SourcePath
    $pinnedRepoPath = [string](Get-RequiredProperty $pin 'path')
    if ($pinnedRepoPath -cne $expectedRepoPath) {
        throw "Manifest replay-validator path for '$Role' is '$pinnedRepoPath'; expected '$expectedRepoPath'."
    }
    $pinnedDigest = [string](Get-RequiredProperty $pin 'sha256')
    $actualDigest = Get-Sha256 $SourcePath
    if ($pinnedDigest -cne $actualDigest) {
        throw "Manifest replay-validator digest for '$Role' does not match the trusted repo source '$expectedRepoPath'."
    }
    if ($null -ne $Snapshot) {
        $snapshotDigest = [string]$Snapshot.sha256
        if ($snapshotDigest -cnotmatch '^[0-9a-f]{64}$' -or $pinnedDigest -cne $snapshotDigest) {
            throw "New replay-validator snapshot for '$Role' does not match its manifest pin."
        }
    }
}

function Get-RequiredProperty {
    param($Object, [Parameter(Mandatory = $true)][string]$Name)
    if ($Object -is [System.Collections.IDictionary]) {
        if (-not $Object.Contains($Name) -or $null -eq $Object[$Name]) {
            throw "Required value is missing: $Name"
        }
        return $Object[$Name]
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { throw "Required value is missing: $Name" }
    return $property.Value
}

function Get-OptionalProperty {
    param($Object, [Parameter(Mandatory = $true)][string]$Name)
    if ($null -eq $Object) { return $null }
    if ($Object -is [System.Collections.IDictionary]) {
        if (-not $Object.Contains($Name)) { return $null }
        return $Object[$Name]
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [ValidateRange(5, 600)]
        [int]$TimeoutSeconds = 120
    )

    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FilePath
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = $script:Utf8NoBom
    $start.StandardErrorEncoding = $script:Utf8NoBom
    $start.Environment['PYTHONUTF8'] = '1'
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw "Failed to start external command '$FilePath'." }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $terminationFailure = $null
            try {
                if (-not $process.HasExited) { $process.Kill($true) }
                if (-not $process.WaitForExit(5000)) {
                    throw 'the child process did not exit within 5 seconds of termination'
                }
            } catch {
                $terminationFailure = $_
            }
            if ($null -ne $terminationFailure -or -not $process.HasExited) {
                $detail = if ($null -eq $terminationFailure) { 'the child process is still running' } else { $terminationFailure.Exception.Message }
                throw "External command '$FilePath' exceeded its $TimeoutSeconds-second deadline, and exact-child termination could not be confirmed: $detail"
            }
            throw "External command '$FilePath' exceeded its $TimeoutSeconds-second deadline and was terminated."
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        return [ordered]@{
            file = $FilePath
            arguments = @($Arguments)
            exit_code = [int]$process.ExitCode
            stdout = Normalize-Lf $stdout
            stderr = Normalize-Lf $stderr
        }
    } finally {
        $process.Dispose()
    }
}

function Invoke-HashPinnedChildScript {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][ValidateRange(0, 100)][int]$ScriptArgumentIndex,
        [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{64}$')][string]$ExpectedScriptSha256,
        [ValidateRange(5, 600)][int]$TimeoutSeconds = 120
    )

    $resolvedScriptPath = [System.IO.Path]::GetFullPath($ScriptPath)
    if ($ScriptArgumentIndex -ge $Arguments.Count) {
        throw "Pinned child-script argument index $ScriptArgumentIndex is outside the $($Arguments.Count)-argument command line."
    }
    $boundScriptPath = [System.IO.Path]::GetFullPath([string]$Arguments[$ScriptArgumentIndex])
    if (-not $boundScriptPath.Equals($resolvedScriptPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Pinned child-script argument '$boundScriptPath' does not bind the guarded snapshot '$resolvedScriptPath'."
    }

    Assert-NoReparsePointInPath -Path $resolvedScriptPath
    $stream = [System.IO.File]::Open(
        $resolvedScriptPath,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::Read
    )
    try {
        Assert-NoReparsePointInPath -Path $resolvedScriptPath
        $hasher = [System.Security.Cryptography.SHA256]::Create()
        try {
            $actualDigest = [Convert]::ToHexString($hasher.ComputeHash($stream)).ToLowerInvariant()
        } finally {
            $hasher.Dispose()
        }
        if ($actualDigest -cne $ExpectedScriptSha256) {
            throw "Pinned child-script SHA-256 mismatch for '$resolvedScriptPath': expected $ExpectedScriptSha256, observed $actualDigest."
        }
        return Invoke-ExternalCommand `
            -FilePath $FilePath `
            -Arguments $Arguments `
            -TimeoutSeconds $TimeoutSeconds
    } finally {
        $stream.Dispose()
    }
}

function Release-ComObject {
    param($Object)
    if ($null -ne $Object -and [System.Runtime.InteropServices.Marshal]::IsComObject($Object)) {
        try { [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($Object) } catch {}
    }
}

function Test-SameComObjectIdentity {
    param(
        [Parameter(Mandatory = $true)]$Left,
        [Parameter(Mandatory = $true)]$Right
    )

    if (-not [System.Runtime.InteropServices.Marshal]::IsComObject($Left) -or
        -not [System.Runtime.InteropServices.Marshal]::IsComObject($Right)) {
        throw 'COM identity comparison requires two COM objects.'
    }
    $leftUnknown = [IntPtr]::Zero
    $rightUnknown = [IntPtr]::Zero
    try {
        $leftUnknown = [System.Runtime.InteropServices.Marshal]::GetIUnknownForObject($Left)
        $rightUnknown = [System.Runtime.InteropServices.Marshal]::GetIUnknownForObject($Right)
        return $leftUnknown -eq $rightUnknown
    } finally {
        if ($rightUnknown -ne [IntPtr]::Zero) {
            [void][System.Runtime.InteropServices.Marshal]::Release($rightUnknown)
        }
        if ($leftUnknown -ne [IntPtr]::Zero) {
            [void][System.Runtime.InteropServices.Marshal]::Release($leftUnknown)
        }
    }
}

function Open-HashPinnedWorkbook {
    param(
        [Parameter(Mandatory = $true)]$Workbooks,
        [Parameter(Mandatory = $true)][string]$WorkbookPath,
        [Parameter(Mandatory = $true)][string]$ExpectedSha256
    )

    $resolvedWorkbookPath = [System.IO.Path]::GetFullPath($WorkbookPath)
    Assert-NoReparsePointInPath -Path $resolvedWorkbookPath
    if (-not (Test-Path -LiteralPath $resolvedWorkbookPath -PathType Leaf)) {
        throw "Pre-open workbook is missing: '$resolvedWorkbookPath'."
    }

    # Retain the exact file object across Workbooks.Open. Read/write sharing lets
    # Excel open it normally; deliberately omitting delete sharing prevents a
    # rename/replacement handoff between the two hashes and the COM open call.
    $stream = [System.IO.File]::Open(
        $resolvedWorkbookPath,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::ReadWrite
    )
    $openedWorkbook = $null
    try {
        Assert-NoReparsePointInPath -Path $resolvedWorkbookPath
        if ((Get-StreamSha256 $stream) -cne $ExpectedSha256) {
            throw 'The phase-1 workbook changed after strict pre-open validation and before Workbooks.Open.'
        }

        try {
            $openedWorkbook = $Workbooks.Open($resolvedWorkbookPath)
            $openedFullName = [System.IO.Path]::GetFullPath([string]$openedWorkbook.FullName)
            if (-not $openedFullName.Equals($resolvedWorkbookPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Excel opened '$openedFullName'; expected the exact pre-validated workbook '$resolvedWorkbookPath'."
            }
            if ([bool]$openedWorkbook.ReadOnly) {
                throw 'Excel opened the exact pre-validated workbook read-only; writable evidence capture is required.'
            }
            if ((Get-StreamSha256 $stream) -cne $ExpectedSha256) {
                throw 'The phase-1 workbook bytes changed during Workbooks.Open before any explicit save.'
            }
            return $openedWorkbook
        } catch {
            $openFailure = $_
            $closeFailure = $null
            if ($null -ne $openedWorkbook) {
                try { $openedWorkbook.Close($false) } catch { $closeFailure = $_ }
                Release-ComObject $openedWorkbook
                $openedWorkbook = $null
            }
            if ($null -ne $closeFailure) {
                throw "$($openFailure.Exception.Message) Workbook-open cleanup also failed: $($closeFailure.Exception.Message)"
            }
            throw $openFailure
        }
    } finally {
        $stream.Dispose()
    }
}

function Add-CleanupFailure {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$Failures,
        [Parameter(Mandatory = $true)][string]$Operation,
        [Parameter(Mandatory = $true)]$Failure
    )

    $message = if ($Failure -is [System.Management.Automation.ErrorRecord]) {
        $Failure.Exception.Message
    } elseif ($Failure -is [System.Exception]) {
        $Failure.Message
    } else {
        [string]$Failure
    }
    if ([string]::IsNullOrWhiteSpace($message)) { $message = '<no error detail>' }
    $Failures.Add(('{0}: {1}' -f $Operation, $message))
}

function ConvertTo-ExactUtcDateTimeOffset {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if ($Value -is [DateTimeOffset]) {
        return ([DateTimeOffset]$Value).ToUniversalTime()
    }
    if ($Value -is [DateTime]) {
        $dateTime = [DateTime]$Value
        if ($dateTime.Kind -ne [DateTimeKind]::Utc) {
            throw "$Label was JSON-coerced to a non-UTC DateTime and cannot preserve exact process identity."
        }
        return [DateTimeOffset]::new($dateTime)
    }
    $text = [string]$Value
    if ($text -cnotmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{7}Z$') {
        throw "$Label is not an exact seven-fraction UTC round-trip timestamp."
    }
    return [DateTimeOffset]::ParseExact(
        $text,
        'o',
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None
    ).ToUniversalTime()
}

function Add-CleanupProgress {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$Failures,
        [Parameter(Mandatory = $true)][string]$Operation
    )

    try {
        Add-Progress -Path $Path -Message $Message
    } catch {
        Add-CleanupFailure -Failures $Failures -Operation $Operation -Failure $_
    }
}

function Wait-ForPrivateProcessExit {
    param(
        [Parameter(Mandatory = $true)][int64]$ProcessId,
        [Parameter(Mandatory = $true)][string]$Label,
        [int]$TimeoutSeconds = 12
    )
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $process = Get-Process -Id ([int]$ProcessId) -ErrorAction SilentlyContinue
        if ($null -eq $process) { return }
        $process.Dispose()
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "$Label private Excel process $ProcessId did not exit within $TimeoutSeconds seconds; it was not terminated."
}

function Start-PrivateProcessWatchdog {
    param(
        [Parameter(Mandatory = $true)][int64]$ProcessId,
        [Parameter(Mandatory = $true)][string]$ExpectedStartUtc,
        [Parameter(Mandatory = $true)][string]$ExpectedPath,
        [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
        [Parameter(Mandatory = $true)][string]$SignalPath,
        [Parameter(Mandatory = $true)][string]$LogPath,
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-z][a-z0-9_]{0,39}$')]
        [string]$Operation,
        [ValidateSet('disarm', 'expected_exit')]
        [string]$TerminalMode = 'disarm'
    )
    if (Test-Path -LiteralPath $SignalPath) { throw "Watchdog signal path unexpectedly exists: '$SignalPath'." }
    if (Test-Path -LiteralPath ($SignalPath + '.tmp')) { throw "Watchdog signal staging path unexpectedly exists: '$SignalPath.tmp'." }
    $acknowledgementPath = $SignalPath + '.ack'
    if (Test-Path -LiteralPath $acknowledgementPath) { throw "Watchdog acknowledgement path unexpectedly exists: '$acknowledgementPath'." }
    if (Test-Path -LiteralPath ($acknowledgementPath + '.tmp')) { throw "Watchdog acknowledgement staging path unexpectedly exists: '$acknowledgementPath.tmp'." }
    $observationPath = $SignalPath + '.observed'
    if (Test-Path -LiteralPath $observationPath) { throw "Watchdog authorization-observation path unexpectedly exists: '$observationPath'." }
    if (Test-Path -LiteralPath ($observationPath + '.tmp')) { throw "Watchdog authorization-observation staging path unexpectedly exists: '$observationPath.tmp'." }
    $confirmationPath = $SignalPath + '.confirm'
    if (Test-Path -LiteralPath $confirmationPath) { throw "Watchdog authorization-confirmation path unexpectedly exists: '$confirmationPath'." }
    if (Test-Path -LiteralPath ($confirmationPath + '.tmp')) { throw "Watchdog authorization-confirmation staging path unexpectedly exists: '$confirmationPath.tmp'." }
    $job = Start-Job -Name ("OxFormsMemberOracleWatchdog_{0}_{1}" -f $ProcessId, [Guid]::NewGuid().ToString('N')) -ArgumentList @(
        $ProcessId,
        $ExpectedStartUtc,
        $ExpectedPath,
        $TimeoutSeconds,
        $SignalPath,
        $LogPath,
        $Operation,
        $TerminalMode
    ) -ScriptBlock {
        param($OwnedProcessId, $OwnedStartUtc, $OwnedPath, $DeadlineSeconds, $DisarmPath, $WatchdogLog, $OperationName, $ExpectedTerminalMode)
        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

        function Write-WatchdogLine {
            param([Parameter(Mandatory = $true)][string]$Message)
            $line = [DateTime]::UtcNow.ToString('o') + ' ' + $Message + "`n"
            $lastWriteFailure = $null
            for ($attempt = 1; $attempt -le 100; $attempt++) {
                try {
                    [System.IO.File]::AppendAllText($WatchdogLog, $line, $utf8NoBom)
                    return
                } catch [System.IO.IOException] {
                    $lastWriteFailure = $_
                    Start-Sleep -Milliseconds 20
                }
            }
            throw "Watchdog log remained unavailable for 2 seconds: $($lastWriteFailure.Exception.Message)"
        }

        function Get-WatchdogProcessIdentity {
            param([Parameter(Mandatory = $true)]$Process)
            try {
                $Process.Refresh()
                if ($Process.HasExited) { return $null }
                $start = $Process.StartTime.ToUniversalTime()
                # MainModule can become null between Get-Process and this read.
                # Do not dereference it under StrictMode until it is present.
                $module = $Process.MainModule
                if ($null -eq $module) {
                    throw 'Process main module was unavailable during identity observation.'
                }
                $path = [System.IO.Path]::GetFullPath([string]$module.FileName)
                return @{ Start = $start; Path = $path }
            } catch {
                $identityFailure = $_
                $Process.Refresh()
                # An exit is an observation, never permission to kill or to
                # acknowledge an expected exit. Live/unknown errors still fail.
                if ($Process.HasExited) { return $null }
                throw $identityFailure
            }
        }

        function Test-ExpectedExitAuthorization {
            if (-not (Test-Path -LiteralPath $DisarmPath -PathType Leaf)) { return $false }
            $authorization = [System.IO.File]::ReadAllText($DisarmPath, $utf8NoBom)
            if ($authorization -cne "expect_exit`n") {
                Write-WatchdogLine "INVALID_SIGNAL operation=$OperationName pid=$OwnedProcessId reason=malformed_expected_exit"
                throw 'Watchdog expected-exit authorization content is malformed.'
            }
            return $true
        }

        function Test-ExactProcessAliveForAuthorization {
            $authorizationProcess = Get-Process -Id ([int]$OwnedProcessId) -ErrorAction SilentlyContinue
            if ($null -eq $authorizationProcess) {
                Write-WatchdogLine "PROCESS_EXITED operation=$OperationName pid=$OwnedProcessId reason=unexpected_exit"
                return $false
            }
            try {
                $identity = Get-WatchdogProcessIdentity $authorizationProcess
                if ($null -eq $identity) {
                    Write-WatchdogLine "PROCESS_EXITED operation=$OperationName pid=$OwnedProcessId reason=unexpected_exit"
                    return $false
                }
                if ($identity.Start -ne $expectedStart -or
                    -not $identity.Path.Equals($expectedFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                    Write-WatchdogLine "IDENTITY_MISMATCH operation=$OperationName pid=$OwnedProcessId reason=authorization_identity_changed"
                    throw 'Watchdog refused expected-exit authorization because PID/start/path identity changed.'
                }
                return $true
            } finally {
                $authorizationProcess.Dispose()
            }
        }

        function Wait-ExpectedExitConfirmation {
            $confirmationDeadline = [DateTime]::UtcNow.AddSeconds(5)
            do {
                if (Test-Path -LiteralPath $expectedExitConfirmation -PathType Leaf) {
                    $confirmation = [System.IO.File]::ReadAllText($expectedExitConfirmation, $utf8NoBom)
                    if ($confirmation -cne "confirm`n") {
                        Write-WatchdogLine "INVALID_SIGNAL operation=$OperationName pid=$OwnedProcessId reason=malformed_expected_exit_confirmation"
                        throw 'Watchdog expected-exit confirmation content is malformed.'
                    }
                    return $true
                }
                if (-not (Test-ExactProcessAliveForAuthorization)) { return $false }
                Start-Sleep -Milliseconds 20
            } while ([DateTime]::UtcNow -lt $confirmationDeadline)
            Write-WatchdogLine "INVALID_SIGNAL operation=$OperationName pid=$OwnedProcessId reason=missing_expected_exit_confirmation"
            throw 'Watchdog expected-exit confirmation was not published within 5 seconds.'
        }

        $expectedStart = [DateTime]::Parse(
            $OwnedStartUtc,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind
        ).ToUniversalTime()
        $expectedFullPath = [System.IO.Path]::GetFullPath($OwnedPath)
        $expectedExitAcknowledgement = $DisarmPath + '.ack'
        $expectedExitObservation = $DisarmPath + '.observed'
        $expectedExitConfirmation = $DisarmPath + '.confirm'
        $exitAuthorized = $false
        Write-WatchdogLine "ARMED operation=$OperationName pid=$OwnedProcessId timeout_seconds=$DeadlineSeconds terminal_mode=$ExpectedTerminalMode"
        $deadline = [DateTime]::UtcNow.AddSeconds($DeadlineSeconds)
        do {
            $observed = Get-Process -Id ([int]$OwnedProcessId) -ErrorAction SilentlyContinue
            if ($null -eq $observed) {
                $exitReason = if ($ExpectedTerminalMode -eq 'expected_exit' -and $exitAuthorized) {
                    'expected_exit'
                } else {
                    'unexpected_exit'
                }
                Write-WatchdogLine "PROCESS_EXITED operation=$OperationName pid=$OwnedProcessId reason=$exitReason"
                return
            }
            try {
                $identity = Get-WatchdogProcessIdentity $observed
                if ($null -eq $identity) {
                    $exitReason = if ($ExpectedTerminalMode -eq 'expected_exit' -and $exitAuthorized) { 'expected_exit' } else { 'unexpected_exit' }
                    Write-WatchdogLine "PROCESS_EXITED operation=$OperationName pid=$OwnedProcessId reason=$exitReason"
                    return
                }
                if ($identity.Start -ne $expectedStart -or
                    -not $identity.Path.Equals($expectedFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                    Write-WatchdogLine "IDENTITY_MISMATCH operation=$OperationName pid=$OwnedProcessId reason=poll_identity_changed"
                    throw 'Watchdog observed a changed PID/start/path identity.'
                }
            } finally {
                $observed.Dispose()
            }
            if (Test-Path -LiteralPath $DisarmPath -PathType Leaf) {
                if ($ExpectedTerminalMode -eq 'expected_exit') {
                    [void](Test-ExpectedExitAuthorization)
                    if (-not $exitAuthorized) {
                        $observationStaging = $expectedExitObservation + '.tmp'
                        [System.IO.File]::WriteAllText($observationStaging, "observed`n", $utf8NoBom)
                        [System.IO.File]::Move($observationStaging, $expectedExitObservation)
                        if (-not (Wait-ExpectedExitConfirmation)) { return }
                        if (-not (Test-ExactProcessAliveForAuthorization)) { return }
                        $acknowledgementStaging = $expectedExitAcknowledgement + '.tmp'
                        [System.IO.File]::WriteAllText($acknowledgementStaging, "authorized`n", $utf8NoBom)
                        [System.IO.File]::Move($acknowledgementStaging, $expectedExitAcknowledgement)
                        $exitAuthorized = $true
                    }
                } else {
                    $signalText = [System.IO.File]::ReadAllText($DisarmPath, $utf8NoBom)
                    if ($signalText -cne "disarm`n") {
                        Write-WatchdogLine "INVALID_SIGNAL operation=$OperationName pid=$OwnedProcessId reason=malformed_disarm"
                        throw 'Watchdog disarm signal content is malformed.'
                    }
                    Write-WatchdogLine "DISARMED operation=$OperationName pid=$OwnedProcessId reason=explicit_disarm"
                    return
                }
            }
            Start-Sleep -Milliseconds 100
        } while ([DateTime]::UtcNow -lt $deadline)

        $owned = Get-Process -Id ([int]$OwnedProcessId) -ErrorAction SilentlyContinue
        if ($null -eq $owned) {
            $exitReason = if ($ExpectedTerminalMode -eq 'expected_exit' -and $exitAuthorized) {
                'expected_exit'
            } else {
                'unexpected_exit'
            }
            Write-WatchdogLine "PROCESS_EXITED operation=$OperationName pid=$OwnedProcessId reason=$exitReason"
            return
        }
        try {
            $identity = Get-WatchdogProcessIdentity $owned
            if ($null -eq $identity) {
                $exitReason = if ($ExpectedTerminalMode -eq 'expected_exit' -and $exitAuthorized) { 'expected_exit' } else { 'unexpected_exit' }
                Write-WatchdogLine "PROCESS_EXITED operation=$OperationName pid=$OwnedProcessId reason=$exitReason"
                return
            }
            if ($identity.Start -ne $expectedStart -or
                -not $identity.Path.Equals($expectedFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-WatchdogLine "IDENTITY_MISMATCH operation=$OperationName pid=$OwnedProcessId"
                throw 'Watchdog refused to terminate a process whose identity changed.'
            }
            if (Test-Path -LiteralPath $DisarmPath -PathType Leaf) {
                if ($ExpectedTerminalMode -eq 'expected_exit') {
                    [void](Test-ExpectedExitAuthorization)
                    if (-not $exitAuthorized) {
                        $observationStaging = $expectedExitObservation + '.tmp'
                        [System.IO.File]::WriteAllText($observationStaging, "observed`n", $utf8NoBom)
                        [System.IO.File]::Move($observationStaging, $expectedExitObservation)
                        if (-not (Wait-ExpectedExitConfirmation)) { return }
                        if (-not (Test-ExactProcessAliveForAuthorization)) { return }
                        $acknowledgementStaging = $expectedExitAcknowledgement + '.tmp'
                        [System.IO.File]::WriteAllText($acknowledgementStaging, "authorized`n", $utf8NoBom)
                        [System.IO.File]::Move($acknowledgementStaging, $expectedExitAcknowledgement)
                        $exitAuthorized = $true
                    }
                } else {
                    $signalText = [System.IO.File]::ReadAllText($DisarmPath, $utf8NoBom)
                    if ($signalText -cne "disarm`n") {
                        Write-WatchdogLine "INVALID_SIGNAL operation=$OperationName pid=$OwnedProcessId reason=malformed_disarm"
                        throw 'Watchdog disarm signal content is malformed.'
                    }
                    Write-WatchdogLine "DISARMED operation=$OperationName pid=$OwnedProcessId reason=explicit_disarm"
                    return
                }
            }
            $owned.Kill()
            if (-not $owned.WaitForExit(5000)) {
                Write-WatchdogLine "TERMINATION_FAILED operation=$OperationName pid=$OwnedProcessId reason=operation_timeout"
                throw 'Watchdog could not confirm exact-process termination within 5 seconds.'
            }
            Write-WatchdogLine "TERMINATED operation=$OperationName pid=$OwnedProcessId reason=operation_timeout"
        } finally {
            $owned.Dispose()
        }
    }
    $handshakeFailure = $null
    $handshakeCleanupFailures = [System.Collections.Generic.List[string]]::new()
    $armed = $false
    try {
        $handshakeDeadline = [DateTime]::UtcNow.AddSeconds(10)
        do {
            if (Test-Path -LiteralPath $LogPath -PathType Leaf) {
                $armedPattern = ' ARMED operation=' + [regex]::Escape($Operation) + ' pid=' + $ProcessId + ' timeout_seconds=' + $TimeoutSeconds + ' terminal_mode=' + [regex]::Escape($TerminalMode) + '$'
                if (@(Read-SharedUtf8Lines $LogPath | Where-Object { $_ -match $armedPattern }).Count -eq 1) {
                    $armed = $true
                    break
                }
            }
            if ($job.State -in @('Completed', 'Failed', 'Stopped', 'Disconnected')) {
                $jobErrors = @(Receive-Job -Job $job -ErrorAction Continue 2>&1)
                throw "Private-process watchdog failed before its ARMED handshake (state $($job.State)): $($jobErrors -join [Environment]::NewLine)"
            }
            Start-Sleep -Milliseconds 50
        } while ([DateTime]::UtcNow -lt $handshakeDeadline)
        if (-not $armed) { throw 'Private-process watchdog did not publish its ARMED handshake within 10 seconds.' }
    } catch {
        $handshakeFailure = $_
    } finally {
        if (-not $armed) {
            try {
                if ($job.State -notin @('Completed', 'Failed', 'Stopped', 'Disconnected')) {
                    Stop-Job -Job $job -ErrorAction Stop
                }
            } catch {
                Add-CleanupFailure -Failures $handshakeCleanupFailures -Operation "Watchdog '$Operation' failed-handshake stop" -Failure $_
            }
            try {
                Remove-Job -Job $job -Force -ErrorAction Stop
            } catch {
                Add-CleanupFailure -Failures $handshakeCleanupFailures -Operation "Watchdog '$Operation' failed-handshake job removal" -Failure $_
            }
        }
    }
    if ($null -ne $handshakeFailure) {
        if ($handshakeCleanupFailures.Count -gt 0) {
            throw "$($handshakeFailure.Exception.Message) Cleanup also failed: $($handshakeCleanupFailures -join ' | ')"
        }
        throw $handshakeFailure
    }
    if ($handshakeCleanupFailures.Count -gt 0) { throw "Watchdog handshake cleanup failed: $($handshakeCleanupFailures -join ' | ')" }
    return $job
}

function Authorize-PrivateProcessExpectedExit {
    param([Parameter(Mandatory = $true)][string]$SignalPath)

    if (Test-Path -LiteralPath $SignalPath) {
        throw "Expected-exit authorization path unexpectedly exists: '$SignalPath'."
    }
    $signalStagingPath = $SignalPath + '.tmp'
    [System.IO.File]::WriteAllText($signalStagingPath, "expect_exit`n", $script:Utf8NoBom)
    [System.IO.File]::Move($signalStagingPath, $SignalPath)
    $observationPath = $SignalPath + '.observed'
    $observationDeadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        if (Test-Path -LiteralPath $observationPath -PathType Leaf) {
            if ([System.IO.File]::ReadAllText($observationPath, $script:Utf8NoBom) -cne "observed`n") {
                throw 'Expected-exit watchdog authorization observation is malformed.'
            }
            break
        }
        Start-Sleep -Milliseconds 20
    } while ([DateTime]::UtcNow -lt $observationDeadline)
    if (-not (Test-Path -LiteralPath $observationPath -PathType Leaf)) {
        throw 'Expected-exit watchdog did not observe authorization while the exact process was alive.'
    }
    $confirmationPath = $SignalPath + '.confirm'
    $confirmationStagingPath = $confirmationPath + '.tmp'
    [System.IO.File]::WriteAllText($confirmationStagingPath, "confirm`n", $script:Utf8NoBom)
    [System.IO.File]::Move($confirmationStagingPath, $confirmationPath)
    $acknowledgementPath = $SignalPath + '.ack'
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        if (Test-Path -LiteralPath $acknowledgementPath -PathType Leaf) {
            if ([System.IO.File]::ReadAllText($acknowledgementPath, $script:Utf8NoBom) -cne "authorized`n") {
                throw 'Expected-exit watchdog acknowledgement is malformed.'
            }
            return
        }
        Start-Sleep -Milliseconds 20
    } while ([DateTime]::UtcNow -lt $deadline)
    throw 'Expected-exit watchdog did not acknowledge authorization while the exact process was alive.'
}

function Complete-PrivateProcessWatchdog {
    param(
        [Parameter(Mandatory = $true)]$Job,
        [Parameter(Mandatory = $true)][string]$SignalPath,
        [Parameter(Mandatory = $true)][string]$LogPath,
        [Parameter(Mandatory = $true)][int64]$ProcessId,
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-z][a-z0-9_]{0,39}$')]
        [string]$Operation,
        [ValidateSet('disarm', 'expected_exit')]
        [string]$ExpectedTerminal = 'disarm'
    )

    $completionFailure = $null
    $cleanupFailures = [System.Collections.Generic.List[string]]::new()
    try {
        if ($ExpectedTerminal -eq 'disarm') {
            $signalStagingPath = $SignalPath + '.tmp'
            [System.IO.File]::WriteAllText($signalStagingPath, "disarm`n", $script:Utf8NoBom)
            [System.IO.File]::Move($signalStagingPath, $SignalPath)
        }
        $completionTimeoutSeconds = if ($ExpectedTerminal -eq 'expected_exit') { 25 } else { 15 }
        $completed = Wait-Job -Job $Job -Timeout $completionTimeoutSeconds
        if ($null -eq $completed) {
            try {
                Stop-Job -Job $Job -ErrorAction Stop
            } catch {
                Add-CleanupFailure -Failures $cleanupFailures -Operation "Watchdog '$Operation' completion-timeout stop" -Failure $_
            }
            throw "Private-process watchdog did not reach expected terminal '$ExpectedTerminal' within $completionTimeoutSeconds seconds."
        }
        $jobErrors = @(Receive-Job -Job $Job -ErrorAction Continue 2>&1)
        if ($Job.State -ne 'Completed') {
            throw "Private-process watchdog ended in state '$($Job.State)': $($jobErrors -join [Environment]::NewLine)"
        }
        if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) {
            throw "Private-process watchdog log is missing: '$LogPath'."
        }
        $operationPattern = [regex]::Escape($Operation)
        $terminalLines = @(Read-SharedUtf8Lines $LogPath | Where-Object {
            $_ -match " (?:DISARMED|PROCESS_EXITED|TERMINATED|TERMINATION_FAILED|IDENTITY_MISMATCH|INVALID_SIGNAL) operation=$operationPattern pid=$ProcessId(?: |$)"
        })
        if ($terminalLines.Count -ne 1) {
            throw "Private-process watchdog operation '$Operation' has $($terminalLines.Count) terminal records; expected exactly one."
        }
        $expectedPattern = if ($ExpectedTerminal -eq 'disarm') {
            " DISARMED operation=$operationPattern pid=$ProcessId reason=explicit_disarm$"
        } else {
            " PROCESS_EXITED operation=$operationPattern pid=$ProcessId reason=expected_exit$"
        }
        if ($terminalLines[0] -notmatch $expectedPattern) {
            throw "Private-process watchdog operation '$Operation' ended with an unexpected terminal record: $($terminalLines[0])"
        }
    } catch {
        $completionFailure = $_
    } finally {
        try {
            Remove-Job -Job $Job -Force -ErrorAction Stop
        } catch {
            Add-CleanupFailure -Failures $cleanupFailures -Operation "Watchdog '$Operation' job removal" -Failure $_
        }
        $signalStagingPath = $SignalPath + '.tmp'
        $acknowledgementPath = $SignalPath + '.ack'
        $acknowledgementStaging = $acknowledgementPath + '.tmp'
        $observationPath = $SignalPath + '.observed'
        $observationStaging = $observationPath + '.tmp'
        $confirmationPath = $SignalPath + '.confirm'
        $confirmationStaging = $confirmationPath + '.tmp'
        foreach ($cleanupPath in @(
            $SignalPath,
            $signalStagingPath,
            $acknowledgementPath,
            $acknowledgementStaging,
            $observationPath,
            $observationStaging,
            $confirmationPath,
            $confirmationStaging
        )) {
            try {
                if (Test-Path -LiteralPath $cleanupPath) {
                    if (-not (Test-Path -LiteralPath $cleanupPath -PathType Leaf)) {
                        throw "Watchdog cleanup path is not a file: '$cleanupPath'."
                    }
                    [System.IO.File]::Delete($cleanupPath)
                    if (Test-Path -LiteralPath $cleanupPath) {
                        throw "Watchdog cleanup path remains after deletion: '$cleanupPath'."
                    }
                }
            } catch {
                Add-CleanupFailure -Failures $cleanupFailures -Operation "Watchdog '$Operation' signal cleanup" -Failure $_
            }
        }
    }
    if ($null -ne $completionFailure) {
        if ($cleanupFailures.Count -gt 0) {
            throw "$($completionFailure.Exception.Message) Cleanup also failed: $($cleanupFailures -join ' | ')"
        }
        throw $completionFailure
    }
    if ($cleanupFailures.Count -gt 0) { throw "Watchdog cleanup failed: $($cleanupFailures -join ' | ')" }
}

function Invoke-BoundedExcelRun {
    param(
        [Parameter(Mandatory = $true)]$Excel,
        [Parameter(Mandatory = $true)][string]$MacroName,
        [Parameter(Mandatory = $true)]$Identity,
        [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
        [Parameter(Mandatory = $true)][string]$Stage,
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-z][a-z0-9_]{0,39}$')]
        [string]$Operation
    )
    $signalPath = Join-Path $Stage ('.macro-watchdog-{0}-disarm' -f $Operation)
    $logPath = Join-Path $Stage 'macro-watchdog.log'
    $job = Start-PrivateProcessWatchdog `
        -ProcessId ([int64]$Identity.process_id) `
        -ExpectedStartUtc ([string]$Identity.process_start_utc) `
        -ExpectedPath ([string]$Identity.path) `
        -TimeoutSeconds $TimeoutSeconds `
        -SignalPath $signalPath `
        -LogPath $logPath `
        -Operation $Operation
    $macroFailure = $null
    $watchdogFailure = $null
    $resultValue = $null
    try {
        $resultValue = $Excel.Run($MacroName)
    } catch {
        $macroFailure = $_
    } finally {
        try {
            Complete-PrivateProcessWatchdog `
                -Job $job `
                -SignalPath $signalPath `
                -LogPath $logPath `
                -ProcessId ([int64]$Identity.process_id) `
                -Operation $Operation `
                -ExpectedTerminal 'disarm'
        } catch {
            $watchdogFailure = $_
        }
    }
    if ($null -ne $macroFailure) {
        if ($null -ne $watchdogFailure) {
            throw "$($macroFailure.Exception.Message) Macro watchdog also failed: $($watchdogFailure.Exception.Message)"
        }
        throw $macroFailure
    }
    if ($null -ne $watchdogFailure) { throw $watchdogFailure }
    return $resultValue
}

function Convert-ManifestScalar {
    param([Parameter(Mandatory = $true)]$Scalar)
    $kind = [string](Get-RequiredProperty $Scalar 'kind')
    switch ($kind) {
        'string' { return [string](Get-RequiredProperty $Scalar 'value') }
        'integer' { return [int64](Get-RequiredProperty $Scalar 'value') }
        'single' { return [single](Get-RequiredProperty $Scalar 'value') }
        'boolean' { return [bool](Get-RequiredProperty $Scalar 'value') }
        'empty' { return $null }
        default { throw "Unsupported manifest scalar kind '$kind'." }
    }
}

function Set-ComponentProperty {
    param(
        [Parameter(Mandatory = $true)]$Component,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)]$Value
    )
    $property = $null
    try {
        $property = $Component.Properties.Item($Name)
        [void]$property.GetType().InvokeMember(
            'Value',
            [System.Reflection.BindingFlags]::SetProperty,
            $null,
            $property,
            @($Value),
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } finally {
        Release-ComObject $property
    }
}

function Set-ControlProperty {
    param(
        [Parameter(Mandatory = $true)]$Control,
        [Parameter(Mandatory = $true)][string]$Name,
        $Value
    )
    $property = $Control.PSObject.Properties[$Name]
    if ($null -eq $property) { throw "MSForms control does not expose required property '$Name'." }
    $property.Value = $Value
}

function Initialize-NativeMethods {
    if ($null -ne ('OxForms.MemberOracle.NativeMethods' -as [type])) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Text;
namespace OxForms.MemberOracle {
    public sealed class SafeModeExcelContainment : IDisposable {
        [StructLayout(LayoutKind.Sequential)]
        private struct IO_COUNTERS {
            public ulong ReadOperationCount;
            public ulong WriteOperationCount;
            public ulong OtherOperationCount;
            public ulong ReadTransferCount;
            public ulong WriteTransferCount;
            public ulong OtherTransferCount;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct JOBOBJECT_BASIC_LIMIT_INFORMATION {
            public long PerProcessUserTimeLimit;
            public long PerJobUserTimeLimit;
            public uint LimitFlags;
            public UIntPtr MinimumWorkingSetSize;
            public UIntPtr MaximumWorkingSetSize;
            public uint ActiveProcessLimit;
            public UIntPtr Affinity;
            public uint PriorityClass;
            public uint SchedulingClass;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION {
            public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation;
            public IO_COUNTERS IoInfo;
            public UIntPtr ProcessMemoryLimit;
            public UIntPtr JobMemoryLimit;
            public UIntPtr PeakProcessMemoryUsed;
            public UIntPtr PeakJobMemoryUsed;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct STARTUPINFO {
            public uint cb;
            public string lpReserved;
            public string lpDesktop;
            public string lpTitle;
            public uint dwX;
            public uint dwY;
            public uint dwXSize;
            public uint dwYSize;
            public uint dwXCountChars;
            public uint dwYCountChars;
            public uint dwFillAttribute;
            public uint dwFlags;
            public ushort wShowWindow;
            public ushort cbReserved2;
            public IntPtr lpReserved2;
            public IntPtr hStdInput;
            public IntPtr hStdOutput;
            public IntPtr hStdError;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct PROCESS_INFORMATION {
            public IntPtr hProcess;
            public IntPtr hThread;
            public uint dwProcessId;
            public uint dwThreadId;
        }

        private const uint JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x00002000;
        private const int JobObjectExtendedLimitInformation = 9;
        private const uint CREATE_SUSPENDED = 0x00000004;
        private const uint WAIT_OBJECT_0 = 0;
        private const uint WAIT_TIMEOUT = 258;
        private static readonly uint ResumeFailure = UInt32.MaxValue;

        private IntPtr jobHandle;
        private IntPtr processHandle;
        private int processId;

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true, ExactSpelling = true)]
        private static extern IntPtr CreateJobObjectW(IntPtr attributes, string name);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool SetInformationJobObject(IntPtr job, int infoClass, IntPtr info, uint length);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool IsProcessInJob(IntPtr process, IntPtr job, out bool result);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool TerminateJobObject(IntPtr job, uint exitCode);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool TerminateProcess(IntPtr process, uint exitCode);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern uint ResumeThread(IntPtr thread);
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool CloseHandle(IntPtr handle);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true, ExactSpelling = true)]
        private static extern bool CreateProcessW(
            string applicationName,
            StringBuilder commandLine,
            IntPtr processAttributes,
            IntPtr threadAttributes,
            bool inheritHandles,
            uint creationFlags,
            IntPtr environment,
            string currentDirectory,
            ref STARTUPINFO startupInfo,
            out PROCESS_INFORMATION processInformation);

        private SafeModeExcelContainment() { }

        public int ProcessId { get { return processId; } }

        public static SafeModeExcelContainment Launch(string executablePath) {
            if (String.IsNullOrWhiteSpace(executablePath) || executablePath.IndexOf('"') >= 0) {
                throw new ArgumentException("Safe-mode Excel executable path is empty or contains a quote.", nameof(executablePath));
            }
            SafeModeExcelContainment result = new SafeModeExcelContainment();
            IntPtr threadHandle = IntPtr.Zero;
            bool assignedToJob = false;
            try {
                result.jobHandle = CreateJobObjectW(IntPtr.Zero, null);
                if (result.jobHandle == IntPtr.Zero) {
                    throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "CreateJobObjectW failed.");
                }
                JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();
                limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
                int limitSize = Marshal.SizeOf<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>();
                IntPtr limitBuffer = Marshal.AllocHGlobal(limitSize);
                try {
                    Marshal.StructureToPtr(limits, limitBuffer, false);
                    if (!SetInformationJobObject(result.jobHandle, JobObjectExtendedLimitInformation, limitBuffer, (uint)limitSize)) {
                        throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "SetInformationJobObject failed.");
                    }
                } finally {
                    Marshal.FreeHGlobal(limitBuffer);
                }

                STARTUPINFO startupInfo = new STARTUPINFO();
                startupInfo.cb = (uint)Marshal.SizeOf<STARTUPINFO>();
                PROCESS_INFORMATION processInformation;
                StringBuilder commandLine = new StringBuilder("\"" + executablePath + "\" /safe");
                string currentDirectory = System.IO.Path.GetDirectoryName(executablePath);
                if (!CreateProcessW(
                    executablePath,
                    commandLine,
                    IntPtr.Zero,
                    IntPtr.Zero,
                    false,
                    CREATE_SUSPENDED,
                    IntPtr.Zero,
                    currentDirectory,
                    ref startupInfo,
                    out processInformation)) {
                    throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "Suspended CreateProcessW for safe-mode Excel failed.");
                }
                result.processHandle = processInformation.hProcess;
                result.processId = checked((int)processInformation.dwProcessId);
                threadHandle = processInformation.hThread;
                if (!AssignProcessToJobObject(result.jobHandle, result.processHandle)) {
                    throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "AssignProcessToJobObject failed before Excel resume.");
                }
                assignedToJob = true;
                bool contained;
                if (!IsProcessInJob(result.processHandle, result.jobHandle, out contained)) {
                    throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "Excel process Job membership could not be verified before resume.");
                }
                if (!contained) {
                    throw new InvalidOperationException("Excel process was not a member of the kill-on-close Job immediately before resume.");
                }
                uint previousSuspendCount = ResumeThread(threadHandle);
                if (previousSuspendCount == ResumeFailure) {
                    throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "ResumeThread failed after Excel Job assignment.");
                }
                if (previousSuspendCount != 1) {
                    throw new InvalidOperationException("ResumeThread did not observe the exact CREATE_SUSPENDED count of one.");
                }
                if (!CloseHandle(threadHandle)) {
                    throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "Closing Excel's initial thread handle failed after resume.");
                }
                threadHandle = IntPtr.Zero;
                return result;
            } catch (Exception primaryFailure) {
                List<Exception> cleanupFailures = new List<Exception>();
                if (result.processHandle != IntPtr.Zero) {
                    bool terminationRequested = false;
                    if (assignedToJob && result.jobHandle != IntPtr.Zero) {
                        if (TerminateJobObject(result.jobHandle, 1)) {
                            terminationRequested = true;
                        }
                    }
                    if (!terminationRequested) {
                        if (TerminateProcess(result.processHandle, 1)) {
                            terminationRequested = true;
                        } else {
                            cleanupFailures.Add(new System.ComponentModel.Win32Exception(
                                Marshal.GetLastWin32Error(),
                                "Exact suspended Excel process termination failed during launch cleanup."
                            ));
                        }
                    }
                    if (terminationRequested) {
                        uint wait = WaitForSingleObject(result.processHandle, 15000);
                        if (wait == WAIT_TIMEOUT) {
                            cleanupFailures.Add(new TimeoutException("Exact suspended Excel process did not terminate during launch cleanup."));
                        } else if (wait != WAIT_OBJECT_0) {
                            cleanupFailures.Add(new System.ComponentModel.Win32Exception(
                                Marshal.GetLastWin32Error(),
                                "Waiting for the exact suspended Excel process failed during launch cleanup."
                            ));
                        }
                    }
                }
                if (threadHandle != IntPtr.Zero) {
                    if (!CloseHandle(threadHandle)) {
                        cleanupFailures.Add(new System.ComponentModel.Win32Exception(
                            Marshal.GetLastWin32Error(),
                            "Closing Excel's initial thread handle failed during launch cleanup."
                        ));
                    }
                    threadHandle = IntPtr.Zero;
                }
                try {
                    result.Dispose();
                } catch (Exception cleanupFailure) {
                    cleanupFailures.Add(cleanupFailure);
                }
                if (cleanupFailures.Count != 0) {
                    cleanupFailures.Insert(0, primaryFailure);
                    throw new AggregateException("Safe-mode Excel launch and exact-process cleanup both failed.", cleanupFailures);
                }
                throw;
            }
        }

        public bool ContainsProcess(IntPtr candidateProcessHandle) {
            if (jobHandle == IntPtr.Zero) throw new ObjectDisposedException(nameof(SafeModeExcelContainment));
            bool contained;
            if (!IsProcessInJob(candidateProcessHandle, jobHandle, out contained)) {
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "IsProcessInJob failed.");
            }
            return contained;
        }

        public void TerminateAndWait(int milliseconds) {
            if (jobHandle == IntPtr.Zero || processHandle == IntPtr.Zero) {
                throw new ObjectDisposedException(nameof(SafeModeExcelContainment));
            }
            if (!TerminateJobObject(jobHandle, 1)) {
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "TerminateJobObject failed.");
            }
            uint wait = WaitForSingleObject(processHandle, checked((uint)milliseconds));
            if (wait == WAIT_TIMEOUT) throw new TimeoutException("Contained Excel process did not terminate before timeout.");
            if (wait != WAIT_OBJECT_0) {
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "WaitForSingleObject failed after Job termination.");
            }
        }

        public void Dispose() {
            List<Exception> failures = new List<Exception>();
            if (jobHandle != IntPtr.Zero) {
                if (CloseHandle(jobHandle)) {
                    jobHandle = IntPtr.Zero;
                } else {
                    failures.Add(new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "Closing the safe-mode Excel Job handle failed."));
                }
            }
            if (processHandle != IntPtr.Zero) {
                if (CloseHandle(processHandle)) {
                    processHandle = IntPtr.Zero;
                } else {
                    failures.Add(new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "Closing the retained safe-mode Excel process handle failed."));
                }
            }
            if (jobHandle == IntPtr.Zero && processHandle == IntPtr.Zero) {
                GC.SuppressFinalize(this);
            }
            if (failures.Count != 0) {
                throw new AggregateException("Safe-mode Excel containment handle cleanup failed.", failures);
            }
        }

        ~SafeModeExcelContainment() {
            try { Dispose(); } catch { }
        }
    }

    public sealed class NativeWindowCandidate {
        public long Hwnd { get; set; }
        public long TopLevelHwnd { get; set; }
        public bool IsTopLevel { get; set; }
        public uint ProcessId { get; set; }
        public string ClassName { get; set; }
        public string Title { get; set; }
        public bool Visible { get; set; }
        public bool Enabled { get; set; }
    }

    public sealed class NativeWindowEnumeration {
        public NativeWindowCandidate[] Windows { get; set; }
        public bool Truncated { get; set; }
        public int Limit { get; set; }
        public bool Succeeded { get; set; }
        public int ErrorCode { get; set; }
    }

    public static class NativeMethods {
        public delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr parameter);
        [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);
        [DllImport("user32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr parameter);
        [DllImport("user32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool EnumChildWindows(IntPtr parent, EnumWindowsProc callback, IntPtr parameter);
        [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool IsWindowVisible(IntPtr hwnd);
        [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool IsWindowEnabled(IntPtr hwnd);
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern int GetClassNameW(IntPtr hwnd, StringBuilder value, int count);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowTextLengthW(IntPtr hwnd);
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern int GetWindowTextW(IntPtr hwnd, StringBuilder value, int count);
        [DllImport("oleacc.dll")] public static extern int AccessibleObjectFromWindow(IntPtr hwnd, uint objectId, ref Guid interfaceId, out IntPtr nativeObject);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool GetProcessTimes(IntPtr processHandle, out long creationTime, out long exitTime, out long kernelTime, out long userTime);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] private static extern bool QueryFullProcessImageNameW(IntPtr processHandle, uint flags, StringBuilder value, ref uint size);
        [DllImport("shell32.dll", SetLastError = true)] private static extern IntPtr CommandLineToArgvW([MarshalAs(UnmanagedType.LPWStr)] string commandLine, out int argumentCount);
        [DllImport("kernel32.dll")] private static extern IntPtr LocalFree(IntPtr memory);

        public static string GetProcessStartTimeUtc(IntPtr processHandle) {
            long creationTime;
            long exitTime;
            long kernelTime;
            long userTime;
            if (!GetProcessTimes(processHandle, out creationTime, out exitTime, out kernelTime, out userTime)) {
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "GetProcessTimes failed while binding exact Excel process identity.");
            }
            return DateTime.FromFileTimeUtc(creationTime).ToString("o", CultureInfo.InvariantCulture);
        }

        public static string GetProcessImagePath(IntPtr processHandle) {
            StringBuilder value = new StringBuilder(32768);
            uint size = (uint)value.Capacity;
            if (!QueryFullProcessImageNameW(processHandle, 0, value, ref size)) {
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "QueryFullProcessImageNameW failed while checking exact cleanup identity.");
            }
            return value.ToString(0, checked((int)size));
        }

        private static string ReadClassName(IntPtr hwnd) {
            StringBuilder value = new StringBuilder(257);
            int count = GetClassNameW(hwnd, value, value.Capacity);
            if (count <= 0) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "GetClassNameW failed during exact-process window enumeration.");
            return value.ToString(0, count);
        }

        private static string ReadWindowTitle(IntPtr hwnd) {
            int length = GetWindowTextLengthW(hwnd);
            if (length <= 0) return String.Empty;
            StringBuilder value = new StringBuilder(length + 1);
            int count = GetWindowTextW(hwnd, value, value.Capacity);
            if (count <= 0) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "GetWindowTextW failed during exact-process window enumeration.");
            return value.ToString(0, count);
        }

        private static NativeWindowCandidate DescribeWindow(IntPtr hwnd, IntPtr topLevel, bool isTopLevel, uint expectedProcessId) {
            uint processId;
            if (GetWindowThreadProcessId(hwnd, out processId) == 0 || processId != expectedProcessId) {
                throw new InvalidOperationException("Window changed exact process identity during enumeration.");
            }
            return new NativeWindowCandidate {
                Hwnd = hwnd.ToInt64(),
                TopLevelHwnd = topLevel.ToInt64(),
                IsTopLevel = isTopLevel,
                ProcessId = processId,
                ClassName = ReadClassName(hwnd),
                Title = ReadWindowTitle(hwnd),
                Visible = IsWindowVisible(hwnd),
                Enabled = IsWindowEnabled(hwnd)
            };
        }

        public static NativeWindowEnumeration EnumerateOwnedWindows(uint expectedProcessId) {
            const int WindowLimit = 512;
            var windows = new System.Collections.Generic.List<NativeWindowCandidate>();
            bool truncated = false;
            bool inspectionFailed = false;
            EnumWindowsProc callback = delegate(IntPtr topLevel, IntPtr ignored) {
                try {
                    uint processId;
                    if (GetWindowThreadProcessId(topLevel, out processId) == 0 || processId != expectedProcessId) return true;
                    if (windows.Count >= WindowLimit) { truncated = true; return false; }
                    windows.Add(DescribeWindow(topLevel, topLevel, true, expectedProcessId));
                    EnumChildWindows(topLevel, delegate(IntPtr child, IntPtr childIgnored) {
                        uint childProcessId;
                        if (GetWindowThreadProcessId(child, out childProcessId) == 0 || childProcessId != expectedProcessId) return true;
                        if (windows.Count >= WindowLimit) { truncated = true; return false; }
                        windows.Add(DescribeWindow(child, topLevel, false, expectedProcessId));
                        return true;
                    }, IntPtr.Zero);
                    return !truncated;
                } catch {
                    inspectionFailed = true;
                    return false;
                }
            };
            bool completed = EnumWindows(callback, IntPtr.Zero);
            int errorCode = inspectionFailed ? -1 : (completed || truncated ? 0 : Marshal.GetLastWin32Error());
            return new NativeWindowEnumeration {
                Windows = windows.ToArray(),
                Truncated = truncated,
                Limit = WindowLimit,
                Succeeded = completed && !truncated && !inspectionFailed,
                ErrorCode = errorCode
            };
        }

        public static string[] ParseCommandLine(string commandLine) {
            int count;
            IntPtr argv = CommandLineToArgvW(commandLine, out count);
            if (argv == IntPtr.Zero) {
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "CommandLineToArgvW failed.");
            }
            try {
                string[] arguments = new string[count];
                for (int index = 0; index < count; index++) {
                    IntPtr value = Marshal.ReadIntPtr(argv, index * IntPtr.Size);
                    arguments[index] = Marshal.PtrToStringUni(value);
                }
                return arguments;
            } finally {
                LocalFree(argv);
            }
        }
    }
}
'@
}

function Get-PeBitness {
    param([Parameter(Mandatory = $true)][string]$Path)
    $stream = [System.IO.File]::OpenRead($Path)
    $reader = [System.IO.BinaryReader]::new($stream)
    try {
        $stream.Position = 0x3c
        $peOffset = $reader.ReadInt32()
        $stream.Position = $peOffset
        if ($reader.ReadUInt32() -ne 0x00004550) { throw "Not a PE executable: '$Path'." }
        $machine = $reader.ReadUInt16()
        switch ($machine) {
            0x014c { return 'x86' }
            0x8664 { return 'x64' }
            0xaa64 { return 'arm64' }
            default { throw ('Unsupported PE machine 0x{0:X4} in {1}.' -f $machine, $Path) }
        }
    } finally {
        $reader.Dispose()
        $stream.Dispose()
    }
}

function Get-ExcelExecutablePath {
    $candidates = [System.Collections.Generic.List[string]]::new()
    foreach ($keyPath in @(
        'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\excel.exe',
        'Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\excel.exe'
    )) {
        if (-not (Test-Path -LiteralPath $keyPath)) { continue }
        $candidate = [string](Get-Item -LiteralPath $keyPath -ErrorAction Stop).GetValue('')
        if ([string]::IsNullOrWhiteSpace($candidate) -or -not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        $resolved = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $candidate -ErrorAction Stop).Path)
        if (-not $candidates.Contains($resolved)) { $candidates.Add($resolved) }
    }
    if ($candidates.Count -ne 1) {
        throw "Expected exactly one registered Excel executable, found $($candidates.Count)."
    }
    Assert-NoReparsePointInPath -Path $candidates[0]
    if ([System.IO.Path]::GetFileName($candidates[0]) -cne 'EXCEL.EXE') {
        throw "Registered Excel executable does not have the exact EXCEL.EXE leaf: '$($candidates[0])'."
    }
    return $candidates[0]
}

function Get-RunningExcelProcessIds {
    $ids = [System.Collections.Generic.List[int64]]::new()
    foreach ($candidate in @(Get-Process EXCEL -ErrorAction SilentlyContinue)) {
        try { $ids.Add([int64]$candidate.Id) } finally { $candidate.Dispose() }
    }
    return @($ids | Sort-Object -Unique)
}

function Get-ExcelProcessIdentityFromProcess {
    param(
        [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)][string]$ExpectedPath,
        [Parameter(Mandatory = $true)][string]$ExpectedSha256
    )
    Initialize-NativeMethods
    $path = $null
    $startTimeUtc = $null
    $lastIdentityFailure = $null
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        try {
            $Process.Refresh()
            if ($Process.HasExited) { throw 'The directly launched safe-mode Excel process exited before identity capture.' }
            $module = $Process.MainModule
            if ($null -eq $module -or [string]::IsNullOrWhiteSpace([string]$module.FileName)) {
                throw 'The directly launched safe-mode Excel process has not exposed its main module yet.'
            }
            $path = [System.IO.Path]::GetFullPath([string]$module.FileName)
            $startTimeUtc = [OxForms.MemberOracle.NativeMethods]::GetProcessStartTimeUtc($Process.Handle)
            break
        } catch {
            $lastIdentityFailure = $_
            if ($Process.HasExited -or [DateTime]::UtcNow -ge $deadline) { break }
            Start-Sleep -Milliseconds 20
        }
    } while ($true)
    if ([string]::IsNullOrWhiteSpace($path) -or [string]::IsNullOrWhiteSpace($startTimeUtc)) {
        throw "The directly launched safe-mode Excel process did not expose stable PID/start/path identity within 5 seconds: $($lastIdentityFailure.Exception.Message)"
    }
    if (-not $path.Equals([System.IO.Path]::GetFullPath($ExpectedPath), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "The directly launched process path '$path' differs from the pinned Excel executable '$ExpectedPath'."
    }
    $file = Get-Item -LiteralPath $path -Force -ErrorAction Stop
    $actualSha256 = Get-Sha256 $path
    if ($actualSha256 -cne $ExpectedSha256) {
        throw "The directly launched Excel binary digest changed: expected $ExpectedSha256, observed $actualSha256."
    }
    return [ordered]@{
        path = $file.FullName
        file_version = Get-NonemptyVersionValue ([string]$file.VersionInfo.FileVersion) 'Excel.FileVersion'
        product_version = Get-NonemptyVersionValue ([string]$file.VersionInfo.ProductVersion) 'Excel.ProductVersion'
        product_name = Get-NonemptyVersionValue ([string]$file.VersionInfo.ProductName) 'Excel.ProductName'
        company_name = Get-NonemptyVersionValue ([string]$file.VersionInfo.CompanyName) 'Excel.CompanyName'
        sha256 = $actualSha256
        process_id = [int64]$Process.Id
        process_start_utc = $startTimeUtc
        bitness = Get-PeBitness $file.FullName
    }
}

function Get-ObservedSafeExcelLaunch {
    param([Parameter(Mandatory = $true)]$Identity)

    Initialize-NativeMethods
    $processId = [int64](Get-RequiredProperty $Identity 'process_id')
    $expectedPath = [System.IO.Path]::GetFullPath([string](Get-RequiredProperty $Identity 'path'))
    $expectedStart = [DateTime]::Parse(
        [string](Get-RequiredProperty $Identity 'process_start_utc'),
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::RoundtripKind
    ).ToUniversalTime()
    $rows = @(
        Get-CimInstance `
            -ClassName Win32_Process `
            -Filter "ProcessId = $processId" `
            -OperationTimeoutSec 5 `
            -ErrorAction Stop
    )
    if ($rows.Count -ne 1) {
        throw "Win32_Process returned $($rows.Count) rows for directly launched Excel process $processId; expected exactly one."
    }
    $row = $rows[0]
    $observedPath = [System.IO.Path]::GetFullPath([string]$row.ExecutablePath)
    if (-not $observedPath.Equals($expectedPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Win32_Process executable path '$observedPath' differs from the directly launched Excel path '$expectedPath'."
    }
    $observedStart = ([DateTime]$row.CreationDate).ToUniversalTime()
    if ([Math]::Abs(($observedStart - $expectedStart).TotalSeconds) -gt 1) {
        throw "Win32_Process creation time does not match the directly launched Excel process start time for PID $processId."
    }
    $commandLine = [string]$row.CommandLine
    if ([string]::IsNullOrWhiteSpace($commandLine)) {
        throw "Win32_Process exposed no command line for directly launched Excel process $processId."
    }
    $arguments = @([OxForms.MemberOracle.NativeMethods]::ParseCommandLine($commandLine))
    if ($arguments.Count -ne 2 -or
        -not [System.IO.Path]::GetFullPath([string]$arguments[0]).Equals($expectedPath, [System.StringComparison]::OrdinalIgnoreCase) -or
        [string]$arguments[1] -cne '/safe') {
        throw "Observed Excel command line did not contain the exact executable followed by the sole /safe argument: '$commandLine'."
    }
    return [ordered]@{
        method = 'cim_win32_process_command_line_to_argv_w'
        raw_command_line = $commandLine
        argv = @($arguments)
    }
}

function Add-ObservedSafeExcelLaunch {
    param([Parameter(Mandatory = $true)]$Identity)

    $observation = Get-ObservedSafeExcelLaunch -Identity $Identity
    $Identity['command_line_observation_method'] = [string]$observation.method
    $Identity['observed_command_line'] = [string]$observation.raw_command_line
    $Identity['observed_launch_argv'] = @($observation.argv)
}

function Start-OwnedSafeExcelProcess {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][int64[]]$ExistingExcelProcessIds)

    if ($ExistingExcelProcessIds.Count -ne 0) {
        throw "Safe-mode oracle capture requires zero pre-existing Excel processes; found $($ExistingExcelProcessIds.Count)."
    }
    $excelPath = Get-ExcelExecutablePath
    $stream = [System.IO.File]::Open(
        $excelPath,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::Read
    )
    $process = $null
    $containment = $null
    $identity = $null
    try {
        Initialize-NativeMethods
        $expectedSha256 = Get-StreamSha256 $stream
        $preCreateExcelProcessIds = @(Get-RunningExcelProcessIds)
        if ($preCreateExcelProcessIds.Count -ne 0) {
            throw "Safe-mode oracle capture found an Excel process after its caller snapshot but before contained creation: $($preCreateExcelProcessIds -join ', ')."
        }
        $containment = [OxForms.MemberOracle.SafeModeExcelContainment]::Launch($excelPath)
        $process = Get-Process -Id ([int]$containment.ProcessId) -ErrorAction Stop
        if (-not $containment.ContainsProcess($process.Handle)) {
            throw 'Suspended safe-mode Excel launch resumed without verified kill-on-close Job membership.'
        }
        $identity = Get-ExcelProcessIdentityFromProcess `
            -Process $process `
            -ExpectedPath $excelPath `
            -ExpectedSha256 $expectedSha256
        if ($ExistingExcelProcessIds -contains [int64]$identity.process_id) {
            throw "Direct safe-mode launch returned pre-existing Excel process $($identity.process_id)."
        }
        $postCreateExcelProcessIds = @(Get-RunningExcelProcessIds)
        if ($postCreateExcelProcessIds.Count -ne 1 -or
            [int64]$postCreateExcelProcessIds[0] -ne [int64]$identity.process_id) {
            throw "Contained safe-mode creation did not leave the exact sole Excel process; observed: $($postCreateExcelProcessIds -join ', ')."
        }
        if ((Get-StreamSha256 $stream) -cne $expectedSha256) {
            throw 'The retained Excel executable changed across direct safe-mode process launch.'
        }
        $identity['startup_mode'] = 'safe'
        $identity['launch_arguments'] = @('/safe')
        $identity['containment_method'] = 'create_process_suspended_then_job_object_kill_on_close'
        $identity['containment_membership_verified'] = $true
        $identity['process_exclusivity_observation'] = [ordered]@{
            caller_snapshot_process_ids = @($ExistingExcelProcessIds)
            pre_create_process_ids = @($preCreateExcelProcessIds)
            post_create_process_ids = @($postCreateExcelProcessIds)
        }
        return [pscustomobject]@{
            process = $process
            identity = $identity
            containment = $containment
        }
    } catch {
        $primaryFailure = $_
        $launchCleanupFailures = [System.Collections.Generic.List[string]]::new()
        if ($null -ne $containment -or $null -ne $process) {
            Close-OwnedSafeExcelLaunch `
                -SafeLaunch ([pscustomobject]@{ process = $process; containment = $containment }) `
                -Failures $launchCleanupFailures `
                -Label 'Safe-mode launch failure'
        }
        if ($launchCleanupFailures.Count -ne 0) {
            throw "Safe-mode Excel launch failed: $($primaryFailure.Exception.Message) Cleanup also failed: $($launchCleanupFailures -join ' | ')"
        }
        throw $primaryFailure
    } finally {
        $stream.Dispose()
    }
}

function Close-OwnedSafeExcelLaunch {
    param(
        $SafeLaunch,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$Failures,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if ($null -eq $SafeLaunch) { return }
    $managedProcess = $SafeLaunch.process
    $containment = $SafeLaunch.containment
    try {
        $exitConfirmed = $false
        if ($null -eq $managedProcess) {
            Add-CleanupFailure `
                -Failures $Failures `
                -Operation "$Label contained-process verification" `
                -Failure ([InvalidOperationException]::new('The safe launch did not retain its managed Process object.'))
        } else {
            try {
                $managedProcess.Refresh()
                $exitConfirmed = [bool]$managedProcess.HasExited
            } catch {
                Add-CleanupFailure -Failures $Failures -Operation "$Label contained-process verification" -Failure $_
            }
        }
        if (-not $exitConfirmed) {
            Add-CleanupFailure `
                -Failures $Failures `
                -Operation "$Label contained-process verification" `
                -Failure ([InvalidOperationException]::new('Excel remained alive after orderly shutdown and required the kill-on-close containment backstop.'))
            if ($null -eq $containment) {
                Add-CleanupFailure `
                    -Failures $Failures `
                    -Operation "$Label containment termination" `
                    -Failure ([InvalidOperationException]::new('The safe launch did not retain its Job containment object.'))
            } else {
                try {
                    $containment.TerminateAndWait(15000)
                    if ($null -ne $managedProcess) {
                        $managedProcess.Refresh()
                        if (-not [bool]$managedProcess.HasExited) {
                            throw 'Contained Excel termination returned without an exited retained process.'
                        }
                    }
                } catch {
                    Add-CleanupFailure -Failures $Failures -Operation "$Label containment termination" -Failure $_
                }
            }
        }
    } finally {
        if ($null -ne $managedProcess) {
            try { $managedProcess.Dispose() } catch {
                Add-CleanupFailure -Failures $Failures -Operation "$Label managed-process disposal" -Failure $_
            }
        }
        if ($null -ne $containment) {
            try { $containment.Dispose() } catch {
                Add-CleanupFailure -Failures $Failures -Operation "$Label containment disposal" -Failure $_
            }
        }
    }
}

function Get-ExcelApplicationFromOwnedProcess {
    param(
        [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)]$Identity,
        [ValidateRange(5, 60)][int]$TimeoutSeconds = 30
    )
    Initialize-NativeMethods
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $lastHResult = $null
    do {
        $Process.Refresh()
        if ($Process.HasExited -or [int64]$Process.Id -ne [int64]$Identity.process_id) {
            throw 'The retained directly launched Excel process handle no longer matches the attachment identity.'
        }
        $retainedStart = [OxForms.MemberOracle.NativeMethods]::GetProcessStartTimeUtc($Process.Handle)
        $retainedPath = [System.IO.Path]::GetFullPath([string]$Process.MainModule.FileName)
        if ($retainedStart -cne [string]$Identity.process_start_utc -or
            -not $retainedPath.Equals([string]$Identity.path, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'The retained directly launched Excel process handle changed start/path identity before attachment.'
        }
        Assert-ExcelProcessIdentity -Identity $Identity -Label 'Safe-mode Excel attachment'
        $enumeration = [OxForms.MemberOracle.NativeMethods]::EnumerateOwnedWindows([uint32]$Identity.process_id)
        if (-not [bool]$enumeration.Succeeded -or [bool]$enumeration.Truncated -or
            [int]$enumeration.Limit -ne 512 -or [int]$enumeration.ErrorCode -ne 0 -or
            @($enumeration.Windows).Count -gt 512) {
            throw "Exact-PID Excel window enumeration was incomplete (succeeded=$($enumeration.Succeeded), truncated=$($enumeration.Truncated), error=$($enumeration.ErrorCode))."
        }
        $windows = @($enumeration.Windows)
        if (@($windows | Where-Object { [int64]$_.ProcessId -ne [int64]$Identity.process_id }).Count -ne 0) {
            throw 'Exact-PID Excel window enumeration returned a foreign-process window.'
        }
        $topLevelWindows = @($windows | Where-Object { [bool]$_.IsTopLevel })
        $blockingWindows = @($topLevelWindows | Where-Object {
            [bool]$_.IsTopLevel -and [bool]$_.Visible -and
            [string]$_.ClassName -cnotin @('XLMAIN', 'MSOSPLASH', 'MsoSplash')
        })
        $disabledExcelRoots = @($topLevelWindows | Where-Object {
            [string]$_.ClassName -ceq 'XLMAIN' -and -not [bool]$_.Enabled
        })
        if ($blockingWindows.Count -gt 0 -or $disabledExcelRoots.Count -gt 0) {
            $detail = @($topLevelWindows | Sort-Object Hwnd | ForEach-Object {
                "HWND=$($_.Hwnd) class='$($_.ClassName)' visible=$($_.Visible) enabled=$($_.Enabled) title='$($_.Title)'"
            }) -join '; '
            throw "Safe-mode Excel exposed an owned visible startup/modal window or disabled Excel root; refusing automation: $detail."
        }
        $enabledExcelRoots = @($topLevelWindows | Where-Object {
            [string]$_.ClassName -ceq 'XLMAIN' -and [bool]$_.Enabled
        })
        if ($enabledExcelRoots.Count -eq 0) {
            Start-Sleep -Milliseconds 100
            continue
        }
        $candidates = @($windows | Where-Object { [string]$_.ClassName -ceq 'EXCEL7' } | Sort-Object Hwnd)
        foreach ($candidate in $candidates) {
            $handle = [IntPtr][int64]$candidate.Hwnd
            $windowProcessId = [uint32]0
            [void][OxForms.MemberOracle.NativeMethods]::GetWindowThreadProcessId($handle, [ref]$windowProcessId)
            if ([int64]$windowProcessId -ne [int64]$Identity.process_id) {
                throw 'The EXCEL7 HWND changed process identity immediately before OBJID_NATIVEOM binding.'
            }
            $rawDispatch = [IntPtr]::Zero
            $nativeWindow = $null
            $application = $null
            try {
                $iidDispatch = [Guid]'00020400-0000-0000-C000-000000000046'
                $lastHResult = [OxForms.MemberOracle.NativeMethods]::AccessibleObjectFromWindow(
                    $handle,
                    [uint32]4294967280,
                    [ref]$iidDispatch,
                    [ref]$rawDispatch
                )
                if ($lastHResult -ge 0 -and $rawDispatch -ne [IntPtr]::Zero) {
                    try {
                        $nativeWindow = [System.Runtime.InteropServices.Marshal]::GetObjectForIUnknown($rawDispatch)
                    } finally {
                        [void][System.Runtime.InteropServices.Marshal]::Release($rawDispatch)
                        $rawDispatch = [IntPtr]::Zero
                    }
                    $application = $nativeWindow.Application
                    $boundIdentity = Get-ExcelProcessIdentity $application
                    if ([int64]$boundIdentity.process_id -ne [int64]$Identity.process_id -or
                        [string]$boundIdentity.process_start_utc -cne [string]$Identity.process_start_utc -or
                        -not [string]::Equals([string]$boundIdentity.path, [string]$Identity.path, [System.StringComparison]::OrdinalIgnoreCase) -or
                        [string]$boundIdentity.sha256 -cne [string]$Identity.sha256) {
                        throw 'OBJID_NATIVEOM returned an Excel Application outside the directly launched process identity.'
                    }
                    $result = [pscustomobject]@{
                        application = $application
                        native_window = $nativeWindow
                        binding_hwnd = [int64]$handle
                        owned_window_count = $windows.Count
                    }
                    $application = $null
                    $nativeWindow = $null
                    return $result
                }
            } finally {
                if ($rawDispatch -ne [IntPtr]::Zero) {
                    [void][System.Runtime.InteropServices.Marshal]::Release($rawDispatch)
                }
                Release-ComObject $application
                Release-ComObject $nativeWindow
            }
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    $hresultDetail = if ($null -eq $lastHResult) { 'not-observed' } else { [string]$lastHResult }
    throw "Safe-mode Excel process $($Identity.process_id) did not expose a bindable exact-PID EXCEL7 OBJID_NATIVEOM object; last HRESULT=$hresultDetail."
}

function Get-ExactProcessWindowIsolationObservation {
    param(
        [Parameter(Mandatory = $true)]$Identity,
        [Parameter(Mandatory = $true)][string]$Checkpoint
    )

    Initialize-NativeMethods
    Assert-ExcelProcessIdentity -Identity $Identity -Label "Safe-mode window isolation at $Checkpoint"
    $enumeration = [OxForms.MemberOracle.NativeMethods]::EnumerateOwnedWindows([uint32]$Identity.process_id)
    $windows = @($enumeration.Windows)
    if (-not [bool]$enumeration.Succeeded -or [bool]$enumeration.Truncated -or
        [int]$enumeration.Limit -ne 512 -or [int]$enumeration.ErrorCode -ne 0 -or
        $windows.Count -gt 512 -or
        @($windows | Where-Object { [int64]$_.ProcessId -ne [int64]$Identity.process_id }).Count -ne 0) {
        throw "Safe-mode window-isolation checkpoint '$Checkpoint' lacked complete exact-PID enumeration authority."
    }
    $topLevel = @($windows | Where-Object { [bool]$_.IsTopLevel } | Sort-Object Hwnd)
    $unexpected = @($topLevel | Where-Object {
        [bool]$_.Visible -and [string]$_.ClassName -cnotin @('XLMAIN', 'MSOSPLASH', 'MsoSplash')
    })
    $disabledExcelRoots = @($topLevel | Where-Object {
        [string]$_.ClassName -ceq 'XLMAIN' -and -not [bool]$_.Enabled
    })
    $enabledExcelRoots = @($topLevel | Where-Object {
        [string]$_.ClassName -ceq 'XLMAIN' -and [bool]$_.Enabled
    })
    if ($unexpected.Count -ne 0 -or $disabledExcelRoots.Count -ne 0 -or
        $enabledExcelRoots.Count -eq 0) {
        $detail = @($topLevel | ForEach-Object {
            "HWND=$($_.Hwnd) class='$($_.ClassName)' visible=$($_.Visible) enabled=$($_.Enabled) title='$($_.Title)'"
        }) -join '; '
        throw "Safe-mode window-isolation checkpoint '$Checkpoint' lacked an enabled Excel root or exposed an unexpected modal/disabled root: $detail."
    }
    return [ordered]@{
        enumeration_succeeded = [bool]$enumeration.Succeeded
        enumeration_truncated = [bool]$enumeration.Truncated
        enumeration_limit = [int]$enumeration.Limit
        enumeration_error_code = [int]$enumeration.ErrorCode
        owned_window_count = $windows.Count
        top_level_windows = @($topLevel | ForEach-Object {
            [ordered]@{
                hwnd = [int64]$_.Hwnd
                class_name = [string]$_.ClassName
                title = [string]$_.Title
                visible = [bool]$_.Visible
                enabled = [bool]$_.Enabled
            }
        })
    }
}

function Close-SafeModeStartupWorkbook {
    param([Parameter(Mandatory = $true)]$Workbooks)
    $startupWorkbook = $null
    try {
        $count = [int]$Workbooks.Count
        if ($count -gt 1) { throw "Safe-mode Excel exposed $count startup workbooks; expected zero or one." }
        $initialWorkbooks = [System.Collections.Generic.List[object]]::new()
        if ($count -eq 1) {
            $startupWorkbook = $Workbooks.Item(1)
            $path = [string]$startupWorkbook.Path
            $fullName = [string]$startupWorkbook.FullName
            $isAddIn = [bool]$startupWorkbook.IsAddin
            $initialWorkbooks.Add([ordered]@{
                path = $path
                full_name = $fullName
                is_addin = $isAddIn
            })
            if (-not [string]::IsNullOrWhiteSpace($path) -or $isAddIn) {
                throw "Safe-mode Excel startup workbook is not a pathless non-add-in workbook: '$fullName'."
            }
            $startupWorkbook.Close($false)
        }
        $postCloseCount = [int]$Workbooks.Count
        if ($postCloseCount -ne 0) {
            throw "Safe-mode Excel retained $postCloseCount workbooks after startup-workbook closure; expected zero."
        }
        return [ordered]@{
            initial_workbook_count = $count
            initial_workbooks = @($initialWorkbooks)
            post_close_workbook_count = $postCloseCount
        }
    } finally {
        Release-ComObject $startupWorkbook
    }
}

function Get-ExcelAddInCollectionInventory {
    param(
        [Parameter(Mandatory = $true)]$Collection,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $items = [System.Collections.Generic.List[object]]::new()
    for ($index = 1; $index -le [int]$Collection.Count; $index++) {
        $addIn = $null
        try {
            $addIn = $Collection.Item($index)
            $items.Add([ordered]@{
                name = [string]$addIn.Name
                title = [string]$addIn.Title
                path = [string]$addIn.Path
                full_name = [string]$addIn.FullName
                installed = [bool]$addIn.Installed
                is_open = [bool]$addIn.IsOpen
            })
        } finally {
            Release-ComObject $addIn
        }
    }
    $sorted = @($items | Sort-Object @{ Expression = { [string]$_.full_name }; Ascending = $true }, @{ Expression = { [string]$_.name }; Ascending = $true })
    $keys = @($sorted | ForEach-Object { ([string]$_.full_name).ToUpperInvariant() + "`0" + ([string]$_.name).ToUpperInvariant() })
    if (@($keys | Group-Object | Where-Object Count -gt 1).Count -ne 0) {
        throw "$Label add-in inventory contains duplicate full-name/name identities."
    }
    return $sorted
}

function Get-SafeModeIsolationObservation {
    param(
        [Parameter(Mandatory = $true)]$Excel,
        [Parameter(Mandatory = $true)]$Identity,
        [Parameter(Mandatory = $true)]$Workbooks,
        [Parameter(Mandatory = $true)][string]$Checkpoint,
        [Parameter(Mandatory = $true)][ValidateSet('none', 'expected_pathless_harness', 'exact_hash_pinned_harness')]
        [string]$WorkbookDisposition,
        [string]$ExpectedWorkbookPath,
        $ExpectedWorkbook
    )

    $workbookInventory = [System.Collections.Generic.List[object]]::new()
    $windowObservation = Get-ExactProcessWindowIsolationObservation `
        -Identity $Identity `
        -Checkpoint $Checkpoint
    $observedWorkbookCount = [int]$Workbooks.Count
    $expectedCount = if ($WorkbookDisposition -eq 'none') { 0 } else { 1 }
    if ($observedWorkbookCount -ne $expectedCount) {
        throw "Safe-mode isolation checkpoint '$Checkpoint' found $observedWorkbookCount workbooks; expected $expectedCount."
    }
    if ($expectedCount -eq 1) {
        if ($null -eq $ExpectedWorkbook) {
            throw "Safe-mode isolation checkpoint '$Checkpoint' lacks its caller-owned expected workbook authority."
        }
        $collectionWorkbook = $null
        try {
            $collectionWorkbook = $Workbooks.Item(1)
            if (-not (Test-SameComObjectIdentity -Left $collectionWorkbook -Right $ExpectedWorkbook)) {
                throw "Safe-mode isolation checkpoint '$Checkpoint' found a sole workbook that is not the caller-owned expected workbook."
            }
            $workbookInventory.Add([ordered]@{
                path = [string]$collectionWorkbook.Path
                full_name = [string]$collectionWorkbook.FullName
                is_addin = [bool]$collectionWorkbook.IsAddin
            })
        } finally {
            if ($null -ne $collectionWorkbook -and
                [System.Runtime.InteropServices.Marshal]::IsComObject($collectionWorkbook)) {
                # Workbooks.Item(1) contributes one RCW reference. Release exactly
                # that reference; never FinalRelease the caller-owned workbook RCW.
                try { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($collectionWorkbook) } catch {}
            }
        }
    } elseif ($null -ne $ExpectedWorkbook) {
        throw "Safe-mode isolation checkpoint '$Checkpoint' supplied an unexpected workbook authority."
    }
    switch ($WorkbookDisposition) {
        'none' {
            if ($workbookInventory.Count -ne 0) { throw "Safe-mode isolation checkpoint '$Checkpoint' expected no workbook inventory." }
        }
        'expected_pathless_harness' {
            if ($workbookInventory.Count -ne 1 -or
                -not [string]::IsNullOrWhiteSpace([string]$workbookInventory[0].path) -or
                [bool]$workbookInventory[0].is_addin) {
                throw "Safe-mode isolation checkpoint '$Checkpoint' did not contain exactly one expected pathless non-add-in harness workbook."
            }
        }
        'exact_hash_pinned_harness' {
            if ([string]::IsNullOrWhiteSpace($ExpectedWorkbookPath)) {
                throw "Safe-mode isolation checkpoint '$Checkpoint' requires an expected workbook path."
            }
            if ($workbookInventory.Count -ne 1 -or [bool]$workbookInventory[0].is_addin -or
                -not [System.IO.Path]::GetFullPath([string]$workbookInventory[0].full_name).Equals(
                    [System.IO.Path]::GetFullPath($ExpectedWorkbookPath),
                    [System.StringComparison]::OrdinalIgnoreCase
                )) {
                throw "Safe-mode isolation checkpoint '$Checkpoint' did not contain exactly the hash-pinned harness workbook."
            }
        }
    }

    $comAddInInventory = [System.Collections.Generic.List[object]]::new()
    $comAddIns = $null
    $comAddInsAccess = $null
    try {
        try {
            $comAddIns = $Excel.GetType().InvokeMember(
                'COMAddIns',
                [System.Reflection.BindingFlags]::GetProperty,
                $null,
                $Excel,
                $null
            )
        } catch [System.Management.Automation.MethodInvocationException] {
            $baseException = $_.Exception
            while ($null -ne $baseException.InnerException) { $baseException = $baseException.InnerException }
            if ($baseException -isnot [System.Runtime.InteropServices.COMException]) { throw }
            $errorNumber = [int64]$baseException.HResult
            if ($errorNumber -ne -2146827284) { throw }
            $comAddInsAccess = [ordered]@{
                status = 'unavailable_exact_excel_error_nonclaim'
                error_number = $errorNumber
                error_hex = ('0x{0:X8}' -f ($errorNumber -band [int64]4294967295))
                inventory_complete = $false
                connection_state_claim = 'not_made'
            }
        }
        if ($null -eq $comAddIns) {
            if ($null -eq $comAddInsAccess) {
                throw 'Excel COMAddIns reflection access returned null without the exact safe-mode Excel error.'
            }
        } else {
            $comAddInsAccess = [ordered]@{
                status = 'available'
                error_number = 0
                error_hex = '0x00000000'
                inventory_complete = $true
                connection_state_claim = 'complete'
            }
            for ($index = 1; $index -le [int]$comAddIns.Count; $index++) {
                $addIn = $null
                try {
                    $addIn = $comAddIns.Item($index)
                    $comAddInInventory.Add([ordered]@{
                        prog_id = [string]$addIn.ProgId
                        description = [string]$addIn.Description
                        connected = [bool]$addIn.Connect
                    })
                } finally {
                    Release-ComObject $addIn
                }
            }
        }
    } finally {
        Release-ComObject $comAddIns
    }

    $sortedComAddIns = @($comAddInInventory | Sort-Object @{ Expression = { [string]$_.prog_id }; Ascending = $true }, @{ Expression = { [string]$_.description }; Ascending = $true })
    $comKeys = @($sortedComAddIns | ForEach-Object { ([string]$_.prog_id).ToUpperInvariant() + "`0" + ([string]$_.description).ToUpperInvariant() })
    if (@($comKeys | Group-Object | Where-Object Count -gt 1).Count -ne 0) {
        throw "Safe-mode isolation checkpoint '$Checkpoint' contains duplicate COM add-in identities."
    }

    $addIns = $null
    $addIns2 = $null
    try {
        $addIns = $Excel.AddIns
        $excelAddIns = @(Get-ExcelAddInCollectionInventory -Collection $addIns -Label 'AddIns')
    } finally {
        Release-ComObject $addIns
    }
    try {
        $addIns2 = $Excel.AddIns2
        $excelAddIns2 = @(Get-ExcelAddInCollectionInventory -Collection $addIns2 -Label 'AddIns2')
    } finally {
        Release-ComObject $addIns2
    }

    $protectedViewWindows = $null
    try {
        $protectedViewWindows = $Excel.ProtectedViewWindows
        $protectedViewWindowCount = [int]$protectedViewWindows.Count
    } finally {
        Release-ComObject $protectedViewWindows
    }

    $process = Get-Process -Id ([int]$Identity.process_id) -ErrorAction Stop
    try {
        $loadedXlls = @($process.Modules | Where-Object {
            [System.IO.Path]::GetExtension([string]$_.ModuleName).Equals('.xll', [System.StringComparison]::OrdinalIgnoreCase)
        } | ForEach-Object {
            [ordered]@{ module_name = [string]$_.ModuleName; path = [string]$_.FileName }
        } | Sort-Object @{ Expression = { [string]$_.path }; Ascending = $true }, @{ Expression = { [string]$_.module_name }; Ascending = $true })
    } finally {
        $process.Dispose()
    }
    $connectedCount = @($sortedComAddIns | Where-Object { [bool]$_.connected }).Count
    $openAddInCount = @($excelAddIns | Where-Object { [bool]$_.is_open }).Count
    $openAddIn2Count = @($excelAddIns2 | Where-Object { [bool]$_.is_open }).Count
    if ($connectedCount -ne 0 -or $openAddInCount -ne 0 -or $openAddIn2Count -ne 0 -or
        $protectedViewWindowCount -ne 0 -or $loadedXlls.Count -ne 0) {
        throw "Safe-mode isolation checkpoint '$Checkpoint' failed: connected COM add-ins=$connectedCount, open AddIns=$openAddInCount, open AddIns2=$openAddIn2Count, protected-view windows=$protectedViewWindowCount, loaded XLL modules=$($loadedXlls.Count)."
    }
    return [ordered]@{
        checkpoint = $Checkpoint
        window_observation = $windowObservation
        workbook_disposition = $WorkbookDisposition
        workbook_count = $observedWorkbookCount
        workbooks = @($workbookInventory)
        startup_path = [string]$Excel.StartupPath
        alt_startup_path = [string]$Excel.AltStartupPath
        protected_view_window_count = $protectedViewWindowCount
        com_addins_access = $comAddInsAccess
        com_addins = @($sortedComAddIns)
        excel_addins = @($excelAddIns)
        excel_addins2 = @($excelAddIns2)
        loaded_xll_modules = @($loadedXlls)
    }
}

function Get-NonemptyVersionValue {
    param(
        [AllowEmptyString()][string]$Value,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if ([string]::IsNullOrWhiteSpace($Value)) { throw "Required binary identity field '$Label' is unavailable." }
    return $Value
}

function Get-ExcelProcessIdentity {
    param([Parameter(Mandatory = $true)]$Excel)
    Initialize-NativeMethods
    $processIdValue = [uint32]0
    [void][OxForms.MemberOracle.NativeMethods]::GetWindowThreadProcessId(
        [IntPtr]([int64]$Excel.Hwnd),
        [ref]$processIdValue
    )
    if ($processIdValue -eq 0) { throw 'The private Excel instance HWND did not resolve to a process id.' }
    $process = Get-Process -Id ([int]$processIdValue) -ErrorAction Stop
    try {
        $path = [string]$process.MainModule.FileName
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Excel process binary is unavailable: '$path'." }
        $file = Get-Item -LiteralPath $path -Force
        return [ordered]@{
            path = $file.FullName
            file_version = Get-NonemptyVersionValue ([string]$file.VersionInfo.FileVersion) 'Excel.FileVersion'
            product_version = Get-NonemptyVersionValue ([string]$file.VersionInfo.ProductVersion) 'Excel.ProductVersion'
            product_name = Get-NonemptyVersionValue ([string]$file.VersionInfo.ProductName) 'Excel.ProductName'
            company_name = Get-NonemptyVersionValue ([string]$file.VersionInfo.CompanyName) 'Excel.CompanyName'
            sha256 = Get-Sha256 $file.FullName
            process_id = [int64]$processIdValue
            process_start_utc = [OxForms.MemberOracle.NativeMethods]::GetProcessStartTimeUtc($process.Handle)
            bitness = Get-PeBitness $file.FullName
        }
    } finally {
        $process.Dispose()
    }
}

function Assert-ExcelProcessIdentity {
    param(
        [Parameter(Mandatory = $true)]$Identity,
        [Parameter(Mandatory = $true)][string]$Label
    )

    Initialize-NativeMethods
    $processId = [int64](Get-RequiredProperty $Identity 'process_id')
    $expectedStart = [string](Get-RequiredProperty $Identity 'process_start_utc')
    $expectedPath = [System.IO.Path]::GetFullPath([string](Get-RequiredProperty $Identity 'path'))
    $process = Get-Process -Id ([int]$processId) -ErrorAction SilentlyContinue
    if ($null -eq $process) { throw "$Label private Excel process $processId is no longer running." }
    try {
        $actualStart = [OxForms.MemberOracle.NativeMethods]::GetProcessStartTimeUtc($process.Handle)
        $actualPath = [System.IO.Path]::GetFullPath([string]$process.MainModule.FileName)
        if ($actualStart -ne $expectedStart -or
            -not $actualPath.Equals($expectedPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "$Label private Excel PID/start/path identity changed for process $processId."
        }
    } finally {
        $process.Dispose()
    }
}

function Stop-ExactPrivateProcess {
    param(
        [Parameter(Mandatory = $true)]$Identity,
        [Parameter(Mandatory = $true)][string]$Label
    )

    Initialize-NativeMethods
    $processId = [int64](Get-RequiredProperty $Identity 'process_id')
    $expectedStart = [string](Get-RequiredProperty $Identity 'process_start_utc')
    $expectedPath = [System.IO.Path]::GetFullPath([string](Get-RequiredProperty $Identity 'path'))
    $process = Get-Process -Id ([int]$processId) -ErrorAction SilentlyContinue
    if ($null -eq $process) { return }
    try {
        if ($process.HasExited) { return }
        $actualStart = [OxForms.MemberOracle.NativeMethods]::GetProcessStartTimeUtc($process.Handle)
        $actualPath = [System.IO.Path]::GetFullPath([OxForms.MemberOracle.NativeMethods]::GetProcessImagePath($process.Handle))
        if ($actualStart -ne $expectedStart -or
            -not $actualPath.Equals($expectedPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "$Label refused emergency cleanup because PID/start/path identity changed."
        }
        $process.Kill()
        if (-not $process.WaitForExit(15000)) {
            throw "$Label could not confirm emergency exact-process termination within 15 seconds."
        }
    } catch {
        $identityFailure = $_
        $process.Refresh()
        if ($process.HasExited) { return }
        throw $identityFailure
    } finally {
        $process.Dispose()
    }
}

function Resolve-LoadedModulePath {
    param(
        [Parameter(Mandatory = $true)][string]$ReportedPath,
        [Parameter(Mandatory = $true)][string]$ExcelPath
    )
    $reported = [System.IO.Path]::GetFullPath($ReportedPath)
    if (Test-Path -LiteralPath $reported -PathType Leaf) { return (Get-Item -LiteralPath $reported -Force).FullName }

    $officeVersionDirectory = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($ExcelPath))
    $officeRoot = [System.IO.Path]::GetDirectoryName($officeVersionDirectory)
    $matches = [System.Collections.Generic.List[string]]::new()
    foreach ($mapping in @(
        [ordered]@{ root = [string]$env:CommonProgramFiles; marker = 'ProgramFilesCommonX64' },
        [ordered]@{ root = [string]${env:CommonProgramFiles(x86)}; marker = 'ProgramFilesCommonX86' },
        [ordered]@{ root = Join-Path ([string]$env:SystemRoot) 'System32'; marker = 'System' },
        [ordered]@{ root = Join-Path ([string]$env:SystemRoot) 'SysWOW64'; marker = 'SystemX86' },
        [ordered]@{ root = [string]$env:SystemRoot; marker = 'Windows' }
    )) {
        if ([string]::IsNullOrWhiteSpace($mapping.root)) { continue }
        $common = [System.IO.Path]::GetFullPath($mapping.root).TrimEnd('\', '/')
        if (-not $reported.StartsWith($common + '\', [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        $suffix = [System.IO.Path]::GetRelativePath($common, $reported)
        if ($suffix -eq '..' -or $suffix.StartsWith('..\') -or $suffix.Contains(':')) { continue }
        $candidate = Join-Path $officeRoot (Join-Path ('vfs\' + $mapping.marker) $suffix)
        if ((Test-PathWithin $candidate $officeRoot) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            $matches.Add((Get-Item -LiteralPath $candidate -Force).FullName)
        }
    }
    if ($matches.Count -ne 1) {
        throw "Loaded module path '$reported' is unreadable and has $($matches.Count) deterministic Click-to-Run backing candidates."
    }
    return $matches[0]
}

function Get-LoadedModuleIdentity {
    param(
        [Parameter(Mandatory = $true)][int64]$ProcessId,
        [Parameter(Mandatory = $true)][string]$ExcelPath,
        [Parameter(Mandatory = $true)][string]$NamePattern,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $process = Get-Process -Id ([int]$ProcessId) -ErrorAction Stop
    try {
        $matches = @($process.Modules | Where-Object { [string]$_.ModuleName -match $NamePattern })
        if ($matches.Count -ne 1) { throw "Expected one loaded $Label module in the private Excel process, found $($matches.Count)." }
        $path = Resolve-LoadedModulePath -ReportedPath ([string]$matches[0].FileName) -ExcelPath $ExcelPath
        $file = Get-Item -LiteralPath $path -Force
        return [ordered]@{
            path = $file.FullName
            file_version = Get-NonemptyVersionValue ([string]$file.VersionInfo.FileVersion) "$Label.FileVersion"
            product_version = Get-NonemptyVersionValue ([string]$file.VersionInfo.ProductVersion) "$Label.ProductVersion"
            sha256 = Get-Sha256 $file.FullName
        }
    } finally {
        $process.Dispose()
    }
}

function Test-OwnedFormWindow {
    param(
        [Parameter(Mandatory = $true)][int64]$ProcessId,
        [Parameter(Mandatory = $true)][string]$Caption,
        [switch]$IncludeHidden
    )
    Initialize-NativeMethods
    $callback = [OxForms.MemberOracle.NativeMethods+EnumWindowsProc]{
        param([IntPtr]$handle, [IntPtr]$parameter)
        if (-not $IncludeHidden -and -not [OxForms.MemberOracle.NativeMethods]::IsWindowVisible($handle)) { return $true }
        $pidValue = [uint32]0
        [void][OxForms.MemberOracle.NativeMethods]::GetWindowThreadProcessId($handle, [ref]$pidValue)
        if ([int64]$pidValue -ne $ProcessId) { return $true }
        $classBuffer = [System.Text.StringBuilder]::new(256)
        $classLength = [OxForms.MemberOracle.NativeMethods]::GetClassNameW(
            $handle,
            $classBuffer,
            $classBuffer.Capacity
        )
        if ($classLength -le 0) {
            $script:OwnedFormInspectionFailure = "GetClassNameW failed for process-owned window $handle."
            return $true
        }
        if (-not [string]::Equals(
            $classBuffer.ToString(),
            'ThunderDFrame',
            [System.StringComparison]::Ordinal
        )) { return $true }
        $length = [OxForms.MemberOracle.NativeMethods]::GetWindowTextLengthW($handle)
        if ($length -le 0) {
            $script:OwnedFormInspectionFailure = "GetWindowTextLengthW returned no title for process-owned ThunderDFrame window $handle."
            return $true
        }
        $buffer = [System.Text.StringBuilder]::new($length + 1)
        $copied = [OxForms.MemberOracle.NativeMethods]::GetWindowTextW($handle, $buffer, $buffer.Capacity)
        if ($copied -le 0) {
            $script:OwnedFormInspectionFailure = "GetWindowTextW failed for process-owned ThunderDFrame window $handle."
            return $true
        }
        if ([string]::Equals(
            $buffer.ToString(),
            $Caption,
            [System.StringComparison]::Ordinal
        )) { $script:OwnedFormFound = $true }
        return $true
    }
    $script:OwnedFormFound = $false
    $script:OwnedFormInspectionFailure = $null
    try {
        if (-not [OxForms.MemberOracle.NativeMethods]::EnumWindows($callback, [IntPtr]::Zero)) {
            throw "EnumWindows failed while locating the exact UserForm '$Caption' in process $ProcessId."
        }
        if (-not [string]::IsNullOrWhiteSpace($script:OwnedFormInspectionFailure)) {
            throw $script:OwnedFormInspectionFailure
        }
        return [bool]$script:OwnedFormFound
    } finally {
        Remove-Variable -Scope Script -Name OwnedFormFound -ErrorAction SilentlyContinue
        Remove-Variable -Scope Script -Name OwnedFormInspectionFailure -ErrorAction SilentlyContinue
    }
}

function Wait-ForOwnedFormWindow {
    param(
        [Parameter(Mandatory = $true)][int64]$ProcessId,
        [Parameter(Mandatory = $true)][string]$Caption,
        [Parameter(Mandatory = $true)][int]$TimeoutSeconds
    )
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        if (Test-OwnedFormWindow -ProcessId $ProcessId -Caption $Caption) { return }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "The private Excel process did not expose the expected UserForm '$Caption' within $TimeoutSeconds seconds."
}

function Wait-ForOwnedFormWindowClosed {
    param(
        [Parameter(Mandatory = $true)][int64]$ProcessId,
        [Parameter(Mandatory = $true)][string]$Caption,
        [Parameter(Mandatory = $true)][int]$TimeoutSeconds
    )
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        if (-not (Test-OwnedFormWindow -ProcessId $ProcessId -Caption $Caption -IncludeHidden)) { return }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "The private Excel process still exposes UserForm '$Caption' after $TimeoutSeconds seconds."
}

function New-OracleWorkbook {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$FormCodePath,
        [Parameter(Mandatory = $true)][string]$ModuleCodePath,
        [Parameter(Mandatory = $true)][string]$WorkbookPath,
        [Parameter(Mandatory = $true)][string]$FormExportPath,
        [Parameter(Mandatory = $true)][ValidateRange(60, 1200)][int]$PhaseTimeoutSeconds
    )
    $excel = $null; $nativeWindow = $null; $workbooks = $null; $workbook = $null; $project = $null
    $components = $null; $formComponent = $null; $designer = $null; $moduleComponent = $null
    $formCodeModule = $null; $moduleCodeModule = $null
    $createdControls = [System.Collections.Generic.List[object]]::new()
    $controlMap = @{}
    $excelProcessId = [int64]0
    $buildIdentity = $null
    $ownsExcelProcess = $false
    $workbookClosed = $false
    $primaryFailure = $null
    $cleanupFailures = [System.Collections.Generic.List[string]]::new()
    $phaseWatchdog = $null
    $phaseWatchdogCompletionFailed = $false
    $safeLaunch = $null
    $isolationChecks = [System.Collections.Generic.List[object]]::new()
    $phaseSignal = Join-Path ([System.IO.Path]::GetDirectoryName($WorkbookPath)) '.macro-watchdog-build_phase-disarm'
    $watchdogLog = Join-Path ([System.IO.Path]::GetDirectoryName($WorkbookPath)) 'macro-watchdog.log'
    $existingExcelProcessIds = @(Get-RunningExcelProcessIds)
    try {
        $safeLaunch = Start-OwnedSafeExcelProcess -ExistingExcelProcessIds $existingExcelProcessIds
        $buildIdentity = $safeLaunch.identity
        $excelProcessId = [int64]$buildIdentity.process_id
        $ownsExcelProcess = $true
        Assert-ExcelProcessIdentity -Identity $buildIdentity -Label 'Build phase'
        $phaseWatchdog = Start-PrivateProcessWatchdog `
            -ProcessId $excelProcessId `
            -ExpectedStartUtc ([string]$buildIdentity.process_start_utc) `
            -ExpectedPath ([string]$buildIdentity.path) `
            -TimeoutSeconds $PhaseTimeoutSeconds `
            -SignalPath $phaseSignal `
            -LogPath $watchdogLog `
            -Operation 'build_phase' `
            -TerminalMode 'disarm'
        Add-ObservedSafeExcelLaunch -Identity $buildIdentity
        $attachment = Get-ExcelApplicationFromOwnedProcess -Process $safeLaunch.process -Identity $buildIdentity
        $excel = $attachment.application
        $nativeWindow = $attachment.native_window
        Assert-ExcelProcessIdentity -Identity $buildIdentity -Label 'Build phase after OBJID_NATIVEOM binding'
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        $workbooks = $excel.Workbooks
        $startupWorkbookObservation = Close-SafeModeStartupWorkbook -Workbooks $workbooks
        $isolationChecks.Add((Get-SafeModeIsolationObservation `
            -Excel $excel `
            -Identity $buildIdentity `
            -Workbooks $workbooks `
            -Checkpoint 'post_startup_close' `
            -WorkbookDisposition 'none'))
        $excel.AutomationSecurity = 3
        if ([int]$excel.AutomationSecurity -ne 3) {
            throw 'Build-phase Excel did not retain msoAutomationSecurityForceDisable.'
        }
        $buildIdentity['binding_method'] = 'oleacc_accessible_object_from_window_excel7_objid_nativeom'
        $buildIdentity['binding_hwnd'] = [int64]$attachment.binding_hwnd
        $buildIdentity['owned_window_count_at_binding'] = [int]$attachment.owned_window_count
        $buildIdentity['startup_workbook_observation'] = $startupWorkbookObservation
        # xlWBATWorksheet (-4167) bypasses any user Book.xltx/Book.xltm
        # template and deterministically creates one plain worksheet.
        $workbook = $workbooks.Add(-4167)
        $isolationChecks.Add((Get-SafeModeIsolationObservation `
            -Excel $excel `
            -Identity $buildIdentity `
            -Workbooks $workbooks `
            -Checkpoint 'pre_vbide_automation' `
            -WorkbookDisposition 'expected_pathless_harness' `
            -ExpectedWorkbook $workbook))
        try { $project = $workbook.VBProject } catch { throw "Excel blocked VBProject access. Enable 'Trust access to the VBA project object model'." }
        $components = $project.VBComponents
        $formComponent = $components.Add(3)
        $form = Get-RequiredProperty $Manifest 'form'
        $formComponent.Name = [string](Get-RequiredProperty $form 'name')
        $designer = $formComponent.Designer
        Set-ComponentProperty $formComponent 'Caption' ([string](Get-RequiredProperty $form 'caption'))
        Set-ComponentProperty $formComponent 'Width' ([single](Get-RequiredProperty $form 'width_pt'))
        Set-ComponentProperty $formComponent 'Height' ([single](Get-RequiredProperty $form 'height_pt'))
        Set-ComponentProperty $formComponent 'StartUpPosition' ([int](Get-RequiredProperty $form 'startup_position'))

        $pendingControls = [System.Collections.Generic.List[object]]::new()
        foreach ($controlSpec in @($form.controls)) { $pendingControls.Add($controlSpec) }
        while ($pendingControls.Count -gt 0) {
            $createdThisPass = 0
            foreach ($controlSpec in @($pendingControls)) {
            $container = [string](Get-OptionalProperty $controlSpec 'container')
            if ([string]::IsNullOrWhiteSpace($container)) { $container = 'root' }
            if ($container.StartsWith('control:', [System.StringComparison]::Ordinal) -and
                -not $controlMap.ContainsKey($container.Substring('control:'.Length))) {
                continue
            }
            $collection = $null
            try {
                if ($container -eq 'root') {
                    $collection = $designer.Controls
                } elseif ($container.StartsWith('control:', [System.StringComparison]::Ordinal)) {
                    $parentId = $container.Substring('control:'.Length)
                    $collection = $controlMap[$parentId].Controls
                } else {
                    throw "Unsupported control container '$container'."
                }
                $created = $collection.Add(
                    [string](Get-RequiredProperty $controlSpec 'prog_id'),
                    [string](Get-RequiredProperty $controlSpec 'name'),
                    $true
                )
            } finally {
                Release-ComObject $collection
            }
            $createdControls.Add($created)
            $controlMap[[string](Get-RequiredProperty $controlSpec 'id')] = $created
            $created.Left = [single](Get-RequiredProperty $controlSpec 'left_pt')
            $created.Top = [single](Get-RequiredProperty $controlSpec 'top_pt')
            $created.Width = [single](Get-RequiredProperty $controlSpec 'width_pt')
            $created.Height = [single](Get-RequiredProperty $controlSpec 'height_pt')
            $initial = Get-RequiredProperty $controlSpec 'initial_properties'
            foreach ($property in @($initial.PSObject.Properties)) {
                Set-ControlProperty $created $property.Name (Convert-ManifestScalar $property.Value)
            }
            [void]$pendingControls.Remove($controlSpec)
            $createdThisPass++
            }
            if ($createdThisPass -eq 0) {
                $blocked = @($pendingControls | ForEach-Object { [string]$_.id }) -join ', '
                throw "Control container graph could not be constructed: $blocked."
            }
        }

        $formCodeModule = $formComponent.CodeModule
        $formCodeModule.AddFromString([System.IO.File]::ReadAllText($FormCodePath, $script:Utf8NoBom))
        $moduleComponent = $components.Add(1)
        $moduleComponent.Name = 'W010MemberOracleRuntime'
        $moduleCodeModule = $moduleComponent.CodeModule
        $moduleCodeModule.AddFromString([System.IO.File]::ReadAllText($ModuleCodePath, $script:Utf8NoBom))
        [void]$formComponent.Export($FormExportPath)
        $frxPath = [System.IO.Path]::ChangeExtension($FormExportPath, '.frx')
        if (-not (Test-Path -LiteralPath $FormExportPath -PathType Leaf) -or -not (Test-Path -LiteralPath $frxPath -PathType Leaf)) {
            throw 'VBComponent.Export did not create the required .frm/.frx pair.'
        }
        $workbook.SaveAs($WorkbookPath, 52)
        if (-not (Test-Path -LiteralPath $WorkbookPath -PathType Leaf) -or (Get-Item -LiteralPath $WorkbookPath).Length -le 0) {
            throw "Excel SaveAs did not create a nonempty macro workbook: '$WorkbookPath'."
        }
        Assert-ExcelProcessIdentity -Identity $buildIdentity -Label 'Build phase after SaveAs'
        $workbook.Close($true)
        $workbookClosed = $true
        $isolationChecks.Add((Get-SafeModeIsolationObservation `
            -Excel $excel `
            -Identity $buildIdentity `
            -Workbooks $workbooks `
            -Checkpoint 'pre_shutdown' `
            -WorkbookDisposition 'none'))
        $buildIdentity['isolation_checks'] = @($isolationChecks)
    } catch {
        $primaryFailure = $_
    } finally {
        if ($ownsExcelProcess -and $null -ne $workbook -and -not $workbookClosed) {
            try { $workbook.Close($false) } catch {
                Add-CleanupFailure -Failures $cleanupFailures -Operation 'Build workbook close' -Failure $_
            }
        }
        Release-ComObject $formCodeModule; Release-ComObject $moduleCodeModule
        for ($index = $createdControls.Count - 1; $index -ge 0; $index--) { Release-ComObject $createdControls[$index] }
        if ($null -ne $controlMap) { $controlMap.Clear() }
        Release-ComObject $moduleComponent; Release-ComObject $designer; Release-ComObject $formComponent
        Release-ComObject $components; Release-ComObject $project; Release-ComObject $workbook
        Release-ComObject $workbooks
        if ($null -ne $phaseWatchdog) {
            try {
                Complete-PrivateProcessWatchdog `
                    -Job $phaseWatchdog `
                    -SignalPath $phaseSignal `
                    -LogPath $watchdogLog `
                    -ProcessId $excelProcessId `
                    -Operation 'build_phase' `
                    -ExpectedTerminal 'disarm'
            } catch {
                $phaseWatchdogCompletionFailed = $true
                Add-CleanupFailure -Failures $cleanupFailures -Operation 'Build phase watchdog completion' -Failure $_
                try {
                    Stop-ExactPrivateProcess -Identity $buildIdentity -Label 'Build phase watchdog completion'
                } catch {
                    Add-CleanupFailure -Failures $cleanupFailures -Operation 'Build phase watchdog completion emergency exact-process cleanup' -Failure $_
                }
            }
            $phaseWatchdog = $null
        }
        if (-not $phaseWatchdogCompletionFailed -and $ownsExcelProcess -and $null -eq $excel -and $null -ne $buildIdentity) {
            try {
                Stop-ExactPrivateProcess -Identity $buildIdentity -Label 'Build attachment failure'
            } catch {
                Add-CleanupFailure -Failures $cleanupFailures -Operation 'Build attachment failure exact-process cleanup' -Failure $_
            }
        }
        $shutdownWatchdog = $null
        $shutdownSignal = Join-Path ([System.IO.Path]::GetDirectoryName($WorkbookPath)) '.macro-watchdog-build_shutdown-disarm'
        if (-not $phaseWatchdogCompletionFailed -and $ownsExcelProcess -and $null -ne $excel -and $null -ne $buildIdentity) {
            try {
                Assert-ExcelProcessIdentity -Identity $buildIdentity -Label 'Build shutdown'
                $shutdownWatchdog = Start-PrivateProcessWatchdog `
                    -ProcessId $excelProcessId `
                    -ExpectedStartUtc ([string]$buildIdentity.process_start_utc) `
                    -ExpectedPath ([string]$buildIdentity.path) `
                    -TimeoutSeconds 15 `
                    -SignalPath $shutdownSignal `
                    -LogPath $watchdogLog `
                    -Operation 'build_shutdown' `
                    -TerminalMode 'expected_exit'
                Authorize-PrivateProcessExpectedExit -SignalPath $shutdownSignal
                $excel.Quit()
            } catch {
                Add-CleanupFailure -Failures $cleanupFailures -Operation 'Build shutdown request' -Failure $_
                try {
                    Stop-ExactPrivateProcess -Identity $buildIdentity -Label 'Build shutdown'
                } catch {
                    Add-CleanupFailure -Failures $cleanupFailures -Operation 'Build shutdown request emergency exact-process cleanup' -Failure $_
                }
            }
        }
        Release-ComObject $excel
        $excel = $null
        Release-ComObject $nativeWindow
        $nativeWindow = $null
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
        if ($null -ne $shutdownWatchdog) {
            try {
                Complete-PrivateProcessWatchdog `
                    -Job $shutdownWatchdog `
                    -SignalPath $shutdownSignal `
                    -LogPath $watchdogLog `
                    -ProcessId $excelProcessId `
                    -Operation 'build_shutdown' `
                    -ExpectedTerminal 'expected_exit'
            } catch {
                Add-CleanupFailure -Failures $cleanupFailures -Operation 'Build shutdown watchdog completion' -Failure $_
                try {
                    Stop-ExactPrivateProcess -Identity $buildIdentity -Label 'Build shutdown'
                } catch {
                    Add-CleanupFailure -Failures $cleanupFailures -Operation 'Build shutdown watchdog emergency exact-process cleanup' -Failure $_
                }
            }
        }
        if ($ownsExcelProcess -and $excelProcessId -gt 0) {
            try { Wait-ForPrivateProcessExit -ProcessId $excelProcessId -Label 'Build phase' } catch {
                Add-CleanupFailure -Failures $cleanupFailures -Operation 'Build shutdown wait' -Failure $_
                try {
                    Stop-ExactPrivateProcess -Identity $buildIdentity -Label 'Build shutdown wait'
                } catch {
                    Add-CleanupFailure -Failures $cleanupFailures -Operation 'Build shutdown wait emergency exact-process cleanup' -Failure $_
                }
            }
        }
        Close-OwnedSafeExcelLaunch `
            -SafeLaunch $safeLaunch `
            -Failures $cleanupFailures `
            -Label 'Build phase'
    }
    if ($null -ne $primaryFailure) {
        if ($cleanupFailures.Count -gt 0) {
            throw "$($primaryFailure.Exception.Message) Cleanup also failed: $($cleanupFailures -join ' | ')"
        }
        throw $primaryFailure
    }
    if ($cleanupFailures.Count -gt 0) { throw "Cleanup failed: $($cleanupFailures -join ' | ')" }
    return $buildIdentity
}

function Get-CellString {
    param($Value)
    if ($null -eq $Value) { return '' }
    return [string]$Value
}

function Get-CellInteger {
    param($Value, [Parameter(Mandatory = $true)][string]$Label)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { throw "Worksheet integer '$Label' is empty." }
    return [int64]$Value
}

function Get-WorksheetRows {
    param(
        [Parameter(Mandatory = $true)]$Workbook,
        [Parameter(Mandatory = $true)][string]$SheetName,
        [Parameter(Mandatory = $true)][string[]]$Headers,
        [Parameter(Mandatory = $true)][string[]]$IntegerFields
    )
    $sheet = $null; $range = $null
    try {
        $sheet = $Workbook.Worksheets.Item($SheetName)
        $range = $sheet.UsedRange
        $values = $range.Value2
        if ($values -isnot [System.Array] -or $values.Rank -ne 2) { throw "Worksheet '$SheetName' has no tabular output." }
        if ($values.GetLength(1) -ne $Headers.Count) {
            throw "Worksheet '$SheetName' has $($values.GetLength(1)) columns; expected $($Headers.Count)."
        }
        for ($column = 1; $column -le $Headers.Count; $column++) {
            $actual = Get-CellString $values.GetValue(1, $column)
            if ($actual -cne $Headers[$column - 1]) { throw "Worksheet '$SheetName' header $column is '$actual'; expected '$($Headers[$column - 1])'." }
        }
        $rows = [System.Collections.Generic.List[object]]::new()
        for ($rowNumber = 2; $rowNumber -le $values.GetLength(0); $rowNumber++) {
            $row = [ordered]@{}
            for ($column = 1; $column -le $Headers.Count; $column++) {
                $name = $Headers[$column - 1]
                $cell = $values.GetValue($rowNumber, $column)
                $row[$name] = if ($IntegerFields -contains $name) {
                    Get-CellInteger $cell "$SheetName.${name}[$rowNumber]"
                } else {
                    Get-CellString $cell
                }
            }
            $rows.Add($row)
        }
        return @($rows)
    } finally {
        Release-ComObject $range
        Release-ComObject $sheet
    }
}

function Invoke-LiveOracle {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$WorkbookPath,
        [Parameter(Mandatory = $true)][string]$ExpectedPreopenWorkbookSha256,
        [Parameter(Mandatory = $true)][string]$Stage,
        [Parameter(Mandatory = $true)][string]$FinalOutDir,
        [Parameter(Mandatory = $true)][string]$PowerShellPath,
        [Parameter(Mandatory = $true)][string]$ProgressPath,
        [Parameter(Mandatory = $true)][string]$WindowCapturePath,
        [Parameter(Mandatory = $true)][string]$WindowCaptureSha256,
        [Parameter(Mandatory = $true)][ValidateRange(60, 1200)][int]$PhaseTimeoutSeconds
    )
    $excel = $null; $nativeWindow = $null; $workbooks = $null; $workbook = $null
    $identity = $null; $result = $null
    $ownsExcelProcess = $false
    $workbookClosed = $false
    $macroExecutionStarted = $false
    $oracleFormClosed = $false
    $macroBookName = ''
    $primaryFailure = $null
    $cleanupFailures = [System.Collections.Generic.List[string]]::new()
    $formDefinition = Get-RequiredProperty $Manifest 'form'
    $formCaption = [string](Get-RequiredProperty $formDefinition 'caption')
    $officeUiLcid = [int]0
    $phaseWatchdog = $null
    $phaseWatchdogCompletionFailed = $false
    $safeLaunch = $null
    $isolationChecks = [System.Collections.Generic.List[object]]::new()
    $phaseSignal = Join-Path $Stage '.macro-watchdog-live_phase-disarm'
    $watchdogLog = Join-Path $Stage 'macro-watchdog.log'
    $existingExcelProcessIds = @(Get-RunningExcelProcessIds)
    try {
        $safeLaunch = Start-OwnedSafeExcelProcess -ExistingExcelProcessIds $existingExcelProcessIds
        $identity = $safeLaunch.identity
        $ownsExcelProcess = $true
        Assert-ExcelProcessIdentity -Identity $identity -Label 'Live phase'
        $phaseWatchdog = Start-PrivateProcessWatchdog `
            -ProcessId ([int64]$identity.process_id) `
            -ExpectedStartUtc ([string]$identity.process_start_utc) `
            -ExpectedPath ([string]$identity.path) `
            -TimeoutSeconds $PhaseTimeoutSeconds `
            -SignalPath $phaseSignal `
            -LogPath $watchdogLog `
            -Operation 'live_phase' `
            -TerminalMode 'disarm'
        Add-ObservedSafeExcelLaunch -Identity $identity
        $attachment = Get-ExcelApplicationFromOwnedProcess -Process $safeLaunch.process -Identity $identity
        $excel = $attachment.application
        $nativeWindow = $attachment.native_window
        Assert-ExcelProcessIdentity -Identity $identity -Label 'Live phase after OBJID_NATIVEOM binding'
        $excel.DisplayAlerts = $false
        $excel.Visible = $true
        $workbooks = $excel.Workbooks
        $startupWorkbookObservation = Close-SafeModeStartupWorkbook -Workbooks $workbooks
        $isolationChecks.Add((Get-SafeModeIsolationObservation `
            -Excel $excel `
            -Identity $identity `
            -Workbooks $workbooks `
            -Checkpoint 'post_startup_close' `
            -WorkbookDisposition 'none'))
        $excel.AutomationSecurity = 1
        if ([int]$excel.AutomationSecurity -ne 1) {
            throw 'Live-phase Excel did not retain msoAutomationSecurityLow before the hash-pinned workbook open.'
        }
        $identity['binding_method'] = 'oleacc_accessible_object_from_window_excel7_objid_nativeom'
        $identity['binding_hwnd'] = [int64]$attachment.binding_hwnd
        $identity['owned_window_count_at_binding'] = [int]$attachment.owned_window_count
        $identity['startup_workbook_observation'] = $startupWorkbookObservation
        $languageSettings = $null
        try {
            $languageSettings = $excel.LanguageSettings
            $officeUiLcid = [int]$languageSettings.LanguageID(2)
        } finally {
            Release-ComObject $languageSettings
        }
        if ($officeUiLcid -ne 1033) {
            throw "The member oracle requires English (United States) Office UI LCID 1033 for exact Err.Description observations; observed $officeUiLcid."
        }
        Add-Progress $ProgressPath "Phase 2: private safe-mode Excel process $($identity.process_id) started, natively bound, and isolation-checked."
        Assert-ExcelProcessIdentity -Identity $identity -Label 'Live phase before Workbooks.Open'
        $workbook = Open-HashPinnedWorkbook `
            -Workbooks $workbooks `
            -WorkbookPath $WorkbookPath `
            -ExpectedSha256 $ExpectedPreopenWorkbookSha256
        Assert-ExcelProcessIdentity -Identity $identity -Label 'Live phase after Workbooks.Open'
        $isolationChecks.Add((Get-SafeModeIsolationObservation `
            -Excel $excel `
            -Identity $identity `
            -Workbooks $workbooks `
            -Checkpoint 'pre_macro_execution' `
            -WorkbookDisposition 'exact_hash_pinned_harness' `
            -ExpectedWorkbookPath $WorkbookPath `
            -ExpectedWorkbook $workbook))
        $macroBookName = ([string]$workbook.Name).Replace("'", "''")
        Add-Progress $ProgressPath "Phase 2: workbook opened; invoking RunMemberOracle with a $MacroTimeoutSeconds-second exact-process watchdog."
        $macroExecutionStarted = $true
        [void](Invoke-BoundedExcelRun `
            -Excel $excel `
            -MacroName "'$macroBookName'!RunMemberOracle" `
            -Identity $identity `
            -TimeoutSeconds $MacroTimeoutSeconds `
            -Stage $Stage `
            -Operation 'run_member_oracle')
        Add-Progress $ProgressPath 'Phase 2: RunMemberOracle returned; querying the harness error snapshot.'
        $harnessError = [string](Invoke-BoundedExcelRun `
            -Excel $excel `
            -MacroName "'$macroBookName'!GetMemberOracleHarnessError" `
            -Identity $identity `
            -TimeoutSeconds $MacroTimeoutSeconds `
            -Stage $Stage `
            -Operation 'read_harness_error')
        if (-not [string]::IsNullOrWhiteSpace($harnessError)) {
            throw "Generated VBA harness failed (number, description, source, step): $harnessError"
        }
        Assert-ExcelProcessIdentity -Identity $identity -Label 'Live phase after generated VBA execution'
        Add-Progress $ProgressPath 'Phase 2: generated VBA completed without a harness-level error.'
        Wait-ForOwnedFormWindow -ProcessId $identity.process_id -Caption $formCaption -TimeoutSeconds $WindowTimeoutSeconds
        Add-Progress $ProgressPath 'Phase 2: the exact private-Excel UserForm window is visible.'

        $windowArguments = @(
            '-NoProfile', '-NonInteractive', '-File', $WindowCapturePath,
            '-RepoRoot', $script:RepoRoot,
            '-ExpectedScriptSha256', $WindowCaptureSha256,
            '-TitleContains', $formCaption,
            '-ClassName', 'ThunderDFrame',
            '-ProcessName', 'EXCEL',
            '-ProcessId', ([string]$identity.process_id),
            '-OutDir', $Stage,
            '-CaptureScreenshot',
            '-ScreenshotMaxAttempts', '6',
            '-ScreenshotRetryDelayMilliseconds', '300'
        )
        $windowCommand = Invoke-HashPinnedChildScript `
            -FilePath $PowerShellPath `
            -Arguments $windowArguments `
            -ScriptPath $WindowCapturePath `
            -ScriptArgumentIndex 3 `
            -ExpectedScriptSha256 $WindowCaptureSha256 `
            -TimeoutSeconds ([Math]::Max(30, $WindowTimeoutSeconds + 15))
        Write-TextLf -Path (Join-Path $Stage 'window-stdout.log') -Text $windowCommand.stdout -FinalNewline
        Write-TextLf -Path (Join-Path $Stage 'window-stderr.log') -Text $windowCommand.stderr
        if ($windowCommand.exit_code -ne 0) {
            throw "Capture-Window failed with exit code $($windowCommand.exit_code): $($windowCommand.stderr.Trim())"
        }
        $windowManifestPath = Join-Path $Stage 'window-capture-manifest.json'
        $windowManifest = Get-Content -Raw -LiteralPath $windowManifestPath | ConvertFrom-Json
        if ([string]$windowManifest.status -cne 'ok') { throw "Capture-Window returned status '$($windowManifest.status)'." }
        if ([int64]$windowManifest.selected_window.process_id -ne [int64]$identity.process_id) {
            throw 'Captured window does not belong to the private Excel instance.'
        }
        $capturedStart = ConvertTo-ExactUtcDateTimeOffset `
            -Value $windowManifest.selected_window.process_start_time_utc `
            -Label 'Captured window process start time'
        $identityStart = ConvertTo-ExactUtcDateTimeOffset `
            -Value $identity.process_start_utc `
            -Label 'Private Excel process start time'
        if ($capturedStart.UtcDateTime -ne $identityStart.UtcDateTime) {
            $differenceTicks = [Math]::Abs(($capturedStart.UtcDateTime - $identityStart.UtcDateTime).Ticks)
            throw "Captured window process start time does not match the private Excel instance (capture=$($capturedStart.ToString('o')); identity=$($identityStart.ToString('o')); difference_ticks=$differenceTicks)."
        }
        if (-not [string]::Equals(
            [System.IO.Path]::GetFullPath([string]$windowManifest.selected_window.process_path),
            [System.IO.Path]::GetFullPath([string]$identity.path),
            [System.StringComparison]::OrdinalIgnoreCase
        )) { throw 'Captured window executable path does not match the private Excel binary.' }
        $screenshotPath = Join-Path $Stage 'window-capture.png'
        if ((Get-Sha256 $screenshotPath) -cne [string]$windowManifest.screenshot.sha256) {
            throw 'Capture-Window screenshot hash does not match the emitted PNG.'
        }
        Assert-ExcelProcessIdentity -Identity $identity -Label 'Live phase after window capture'
        Add-Progress $ProgressPath 'Phase 2: coordinate screenshot and exact before/after window-state metadata bracket were captured and cross-checked; visual review remains required.'
        $windowManifest.manifest_path = Join-Path $FinalOutDir 'window-capture-manifest.json'
        $windowManifest.screenshot.path = Join-Path $FinalOutDir 'window-capture.png'
        Write-JsonLf -Path $windowManifestPath -Value $windowManifest

        $vbe = Get-LoadedModuleIdentity -ProcessId $identity.process_id -ExcelPath $identity.path -NamePattern '^(?i:VBE[0-9]*\.DLL)$' -Label 'VBE'
        $fm20 = Get-LoadedModuleIdentity -ProcessId $identity.process_id -ExcelPath $identity.path -NamePattern '^(?i:FM20\.DLL)$' -Label 'FM20'
        Add-Progress $ProgressPath 'Phase 2: loaded VBE and FM20 module identities were recorded.'

        [void](Invoke-BoundedExcelRun `
            -Excel $excel `
            -MacroName "'$macroBookName'!CloseMemberOracle" `
            -Identity $identity `
            -TimeoutSeconds $MacroTimeoutSeconds `
            -Stage $Stage `
            -Operation 'close_member_oracle')
        Wait-ForOwnedFormWindowClosed `
            -ProcessId ([int64]$identity.process_id) `
            -Caption $formCaption `
            -TimeoutSeconds $WindowTimeoutSeconds
        $oracleFormClosed = $true
        $capture = Get-RequiredProperty $Manifest 'capture'
        $resultHeaders = @('sequence','probe_id','ledger_row_id','target_id','operation','member','outcome','value_text','type_name','var_type','is_object','is_array','error_number','error_last_dll_error','error_hex','error_description','error_description_utf16_hex','error_source','error_help_file','error_help_context','error_line','error_stage')
        $eventHeaders = @('sequence','event_id','ledger_row_id','target_id','target_kind','event_name','arguments_before','arguments_after','trigger_step_id')
        $resultRows = @(Get-WorksheetRows -Workbook $workbook -SheetName ([string]$capture.result_sheet) -Headers $resultHeaders -IntegerFields @('sequence','error_number','error_last_dll_error','error_help_context','error_line'))
        $eventRows = @(Get-WorksheetRows -Workbook $workbook -SheetName ([string]$capture.event_sheet) -Headers $eventHeaders -IntegerFields @('sequence'))
        Add-Progress $ProgressPath "Phase 2: stopped event recording, closed the form, and exported the final $($resultRows.Count) probe rows and $($eventRows.Count) event rows."
        $workbook.Save()
        Assert-ExcelProcessIdentity -Identity $identity -Label 'Live phase after final save'
        $workbook.Close($true)
        $workbookClosed = $true
        $isolationChecks.Add((Get-SafeModeIsolationObservation `
            -Excel $excel `
            -Identity $identity `
            -Workbooks $workbooks `
            -Checkpoint 'pre_shutdown' `
            -WorkbookDisposition 'none'))
        $identity['isolation_checks'] = @($isolationChecks)
        Add-Progress $ProgressPath 'Phase 2: UserForm closed and the evidence workbook was saved and closed.'
        $result = [ordered]@{
            excel = $identity
            vbe = $vbe
            fm20 = $fm20
            office_ui_lcid = $officeUiLcid
            results = $resultRows
            events = $eventRows
            window_command = $windowCommand
        }
    } catch {
        $primaryFailure = $_
    } finally {
        if ($ownsExcelProcess -and $null -ne $workbook -and -not $workbookClosed) {
            if ($macroExecutionStarted -and -not $oracleFormClosed -and -not [string]::IsNullOrWhiteSpace($macroBookName)) {
                $formPresenceCheckSucceeded = $true
                try {
                    $ownedFormPresent = Test-OwnedFormWindow `
                        -ProcessId ([int64]$identity.process_id) `
                        -Caption $formCaption `
                        -IncludeHidden
                } catch {
                    $formPresenceCheckSucceeded = $false
                    Add-CleanupFailure -Failures $cleanupFailures -Operation 'Live generated UserForm presence check' -Failure $_
                    $ownedFormPresent = $false
                }
                if ($ownedFormPresent) {
                    Add-CleanupProgress `
                        -Path $ProgressPath `
                        -Message 'Cleanup: requesting bounded generated-UserForm teardown before workbook close.' `
                        -Failures $cleanupFailures `
                        -Operation 'Live generated UserForm teardown pre-progress'
                    try {
                        [void](Invoke-BoundedExcelRun `
                            -Excel $excel `
                            -MacroName "'$macroBookName'!CloseMemberOracle" `
                            -Identity $identity `
                            -TimeoutSeconds $MacroTimeoutSeconds `
                            -Stage $Stage `
                            -Operation 'cleanup_close_member_oracle')
                        Wait-ForOwnedFormWindowClosed `
                            -ProcessId ([int64]$identity.process_id) `
                            -Caption $formCaption `
                            -TimeoutSeconds $WindowTimeoutSeconds
                        $oracleFormClosed = $true
                    } catch {
                        Add-CleanupFailure -Failures $cleanupFailures -Operation 'Live generated UserForm teardown' -Failure $_
                    }
                } elseif ($formPresenceCheckSucceeded) {
                    $oracleFormClosed = $true
                }
                if ($oracleFormClosed) {
                    Add-CleanupProgress `
                        -Path $ProgressPath `
                        -Message 'Cleanup: generated UserForm teardown returned and the owned window is absent.' `
                        -Failures $cleanupFailures `
                        -Operation 'Live generated UserForm teardown post-progress'
                }
            }
            Add-CleanupProgress `
                -Path $ProgressPath `
                -Message 'Cleanup: closing the live workbook without saving incomplete observations.' `
                -Failures $cleanupFailures `
                -Operation 'Live workbook close pre-progress'
            try {
                $workbook.Close($false)
                $workbookClosed = $true
            } catch {
                Add-CleanupFailure -Failures $cleanupFailures -Operation 'Live workbook close' -Failure $_
            }
            if ($workbookClosed) {
                Add-CleanupProgress `
                    -Path $ProgressPath `
                    -Message 'Cleanup: live workbook close returned.' `
                    -Failures $cleanupFailures `
                    -Operation 'Live workbook close post-progress'
            }
        }
        Release-ComObject $workbook; Release-ComObject $workbooks
        $workbook = $null; $workbooks = $null
        if ($null -ne $phaseWatchdog) {
            try {
                Complete-PrivateProcessWatchdog `
                    -Job $phaseWatchdog `
                    -SignalPath $phaseSignal `
                    -LogPath $watchdogLog `
                    -ProcessId ([int64]$identity.process_id) `
                    -Operation 'live_phase' `
                    -ExpectedTerminal 'disarm'
            } catch {
                $phaseWatchdogCompletionFailed = $true
                Add-CleanupFailure -Failures $cleanupFailures -Operation 'Live phase watchdog completion' -Failure $_
                try {
                    Stop-ExactPrivateProcess -Identity $identity -Label 'Live phase watchdog completion'
                } catch {
                    Add-CleanupFailure -Failures $cleanupFailures -Operation 'Live phase watchdog completion emergency exact-process cleanup' -Failure $_
                }
            }
            $phaseWatchdog = $null
        }
        if (-not $phaseWatchdogCompletionFailed -and $ownsExcelProcess -and $null -eq $excel -and $null -ne $identity) {
            try {
                Stop-ExactPrivateProcess -Identity $identity -Label 'Live attachment failure'
            } catch {
                Add-CleanupFailure -Failures $cleanupFailures -Operation 'Live attachment failure exact-process cleanup' -Failure $_
            }
        }
        $shutdownWatchdog = $null
        $shutdownSignal = Join-Path $Stage '.macro-watchdog-live_shutdown-disarm'
        if (-not $phaseWatchdogCompletionFailed -and $ownsExcelProcess -and $null -ne $excel -and $null -ne $identity) {
            try {
                Assert-ExcelProcessIdentity -Identity $identity -Label 'Live shutdown'
                $shutdownWatchdog = Start-PrivateProcessWatchdog `
                    -ProcessId ([int64]$identity.process_id) `
                    -ExpectedStartUtc ([string]$identity.process_start_utc) `
                    -ExpectedPath ([string]$identity.path) `
                    -TimeoutSeconds 15 `
                    -SignalPath $shutdownSignal `
                    -LogPath $watchdogLog `
                    -Operation 'live_shutdown' `
                    -TerminalMode 'expected_exit'
                Authorize-PrivateProcessExpectedExit -SignalPath $shutdownSignal
                $excel.Quit()
            } catch {
                Add-CleanupFailure -Failures $cleanupFailures -Operation 'Live shutdown request' -Failure $_
                try {
                    Stop-ExactPrivateProcess -Identity $identity -Label 'Live shutdown'
                } catch {
                    Add-CleanupFailure -Failures $cleanupFailures -Operation 'Live shutdown request emergency exact-process cleanup' -Failure $_
                }
            }
        }
        Release-ComObject $excel
        $excel = $null
        Release-ComObject $nativeWindow
        $nativeWindow = $null
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
        if ($null -ne $shutdownWatchdog) {
            try {
                Complete-PrivateProcessWatchdog `
                    -Job $shutdownWatchdog `
                    -SignalPath $shutdownSignal `
                    -LogPath $watchdogLog `
                    -ProcessId ([int64]$identity.process_id) `
                    -Operation 'live_shutdown' `
                    -ExpectedTerminal 'expected_exit'
            } catch {
                Add-CleanupFailure -Failures $cleanupFailures -Operation 'Live shutdown watchdog completion' -Failure $_
                try {
                    Stop-ExactPrivateProcess -Identity $identity -Label 'Live shutdown'
                } catch {
                    Add-CleanupFailure -Failures $cleanupFailures -Operation 'Live shutdown watchdog emergency exact-process cleanup' -Failure $_
                }
            }
        }
        if ($ownsExcelProcess -and $null -ne $identity) {
            try {
                Wait-ForPrivateProcessExit -ProcessId ([int64]$identity.process_id) -Label 'Live phase'
            } catch {
                Add-CleanupFailure -Failures $cleanupFailures -Operation 'Live shutdown wait' -Failure $_
                try {
                    Stop-ExactPrivateProcess -Identity $identity -Label 'Live shutdown wait'
                } catch {
                    Add-CleanupFailure -Failures $cleanupFailures -Operation 'Live shutdown wait emergency exact-process cleanup' -Failure $_
                }
            }
        }
        Close-OwnedSafeExcelLaunch `
            -SafeLaunch $safeLaunch `
            -Failures $cleanupFailures `
            -Label 'Live phase'
    }
    if ($null -ne $primaryFailure) {
        if ($cleanupFailures.Count -gt 0) {
            throw "$($primaryFailure.Exception.Message) Cleanup also failed: $($cleanupFailures -join ' | ')"
        }
        throw $primaryFailure
    }
    if ($cleanupFailures.Count -gt 0) { throw "Cleanup failed: $($cleanupFailures -join ' | ')" }
    return $result
}

function New-ArtifactReference {
    param(
        [Parameter(Mandatory = $true)][string]$Stage,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )
    if ($RelativePath.Contains('\') -or $RelativePath.StartsWith('/') -or $RelativePath -split '/' -contains '..') {
        throw "Unsafe capture-relative artifact path '$RelativePath'."
    }
    $path = Join-Path $Stage $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required artifact is missing: '$RelativePath'." }
    return [ordered]@{ path = $RelativePath; sha256 = Get-Sha256 $path }
}

function New-RepoToolReference {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [ordered]@{ path = Convert-ToRepoPath $Path; sha256 = Get-Sha256 $Path }
}

function New-ToolSnapshot {
    param(
        [Parameter(Mandatory = $true)][string]$Stage,
        [Parameter(Mandatory = $true)][string]$SourcePath
    )
    $snapshotDirectory = Join-Path $Stage 'tool-snapshots'
    [void][System.IO.Directory]::CreateDirectory($snapshotDirectory)
    $leaf = [System.IO.Path]::GetFileName($SourcePath)
    $snapshotPath = Join-Path $snapshotDirectory $leaf
    if (Test-Path -LiteralPath $snapshotPath) { throw "Duplicate tool snapshot leaf: '$leaf'." }
    [System.IO.File]::Copy($SourcePath, $snapshotPath, $false)
    $digest = Get-Sha256 $snapshotPath
    if ((Get-Sha256 $SourcePath) -cne $digest) { throw "Tool changed while its snapshot was captured: '$SourcePath'." }
    return [ordered]@{
        source_path = Convert-ToRepoPath $SourcePath
        snapshot_path = [System.IO.Path]::GetRelativePath($Stage, $snapshotPath).Replace('\', '/')
        sha256 = $digest
    }
}

function Resolve-ToolSnapshotPath {
    param(
        [Parameter(Mandatory = $true)][string]$Stage,
        [Parameter(Mandatory = $true)]$Snapshot,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $relative = [string]$Snapshot.snapshot_path
    $expectedDigest = [string]$Snapshot.sha256
    if ([string]::IsNullOrWhiteSpace($relative) -or $expectedDigest -cnotmatch '^[0-9a-f]{64}$') {
        throw "$Label snapshot metadata is incomplete."
    }
    if ($relative.Contains('\') -or $relative.StartsWith('/') -or $relative -split '/' -contains '..') {
        throw "$Label has an unsafe capture-relative snapshot path '$relative'."
    }
    $path = [System.IO.Path]::GetFullPath((Join-Path $Stage $relative))
    if (-not (Test-PathWithin $path $Stage)) { throw "$Label snapshot resolves outside the capture staging directory." }
    Assert-NoReparsePointInPath $path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "$Label snapshot is missing: '$path'." }
    if ((Get-Sha256 $path) -cne $expectedDigest) {
        throw "$Label snapshot bytes do not match the frozen digest."
    }
    return $path
}

function Assert-ToolSnapshotStillCurrent {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)]$Snapshot
    )
    if ((Get-Sha256 $SourcePath) -cne [string]$Snapshot.sha256) {
        throw "Tool changed during capture after its immutable snapshot was taken: '$SourcePath'."
    }
}

function Invoke-GeneratorPreflight {
    param(
        [Parameter(Mandatory = $true)][string]$SourceGeneratorPath,
        [Parameter(Mandatory = $true)][string]$SourceManifestPath,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$ManifestBytes,
        [Parameter(Mandatory = $true)][string]$ExpectedManifestSha256,
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$PythonPath
    )

    $preflightParent = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot 'target\office-oracle-preflight'))
    if (-not (Test-PathWithin $preflightParent $RepoRoot)) {
        throw "Generator-preflight parent resolves outside the repository: '$preflightParent'."
    }
    Assert-NoReparsePointInPath $preflightParent
    [void][System.IO.Directory]::CreateDirectory($preflightParent)
    Assert-NoReparsePointInPath $preflightParent
    $preflightLeaf = 'generator-' + [Guid]::NewGuid().ToString('N')
    $preflightStage = [System.IO.Path]::GetFullPath((Join-Path $preflightParent $preflightLeaf))
    $preflightPrefix = $preflightParent.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $preflightStage.StartsWith($preflightPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
        $preflightLeaf -cnotmatch '^generator-[0-9a-f]{32}$') {
        throw "Refusing unsafe generator-preflight staging path: '$preflightStage'."
    }
    Assert-NoReparsePointInPath $preflightStage

    $primaryFailure = $null
    $cleanupFailures = [System.Collections.Generic.List[string]]::new()
    $result = $null
    try {
        [void][System.IO.Directory]::CreateDirectory($preflightStage)
        Assert-NoReparsePointInPath $preflightStage
        $preflightSnapshot = New-ToolSnapshot -Stage $preflightStage -SourcePath $SourceGeneratorPath
        $preflightGeneratorPath = Resolve-ToolSnapshotPath `
            -Stage $preflightStage `
            -Snapshot $preflightSnapshot `
            -Label 'Preflight generator/validator'
        $preflightGeneratorSha256 = [string]$preflightSnapshot.sha256
        Assert-FileSha256 -Path $SourceGeneratorPath -ExpectedSha256 $preflightGeneratorSha256 -Label 'Source generator before preflight execution'
        Assert-FileSha256 -Path $SourceManifestPath -ExpectedSha256 $ExpectedManifestSha256 -Label 'Source probe manifest before preflight execution'
        $preflightInputDirectory = Join-Path $preflightStage 'input-snapshots'
        [void][System.IO.Directory]::CreateDirectory($preflightInputDirectory)
        $preflightManifestPath = Join-Path $preflightInputDirectory 'probe-manifest.json'
        [System.IO.File]::WriteAllBytes($preflightManifestPath, $ManifestBytes)
        Assert-FileSha256 -Path $preflightManifestPath -ExpectedSha256 $ExpectedManifestSha256 -Label 'Preflight retained-byte probe-manifest snapshot'

        $validateArguments = @(
            $preflightGeneratorPath,
            '--repo-root', $RepoRoot,
            '--expected-self-sha256', $preflightGeneratorSha256,
            'validate-manifest',
            '--manifest', $preflightManifestPath
        )
        try {
            $validation = Invoke-HashPinnedChildScript `
                -FilePath $PythonPath `
                -Arguments $validateArguments `
                -ScriptPath $preflightGeneratorPath `
                -ScriptArgumentIndex 0 `
                -ExpectedScriptSha256 $preflightGeneratorSha256
        } finally {
            Assert-FileSha256 -Path $preflightGeneratorPath -ExpectedSha256 $preflightGeneratorSha256 -Label 'Preflight generator snapshot after manifest validation'
            Assert-FileSha256 -Path $SourceGeneratorPath -ExpectedSha256 $preflightGeneratorSha256 -Label 'Source generator after preflight manifest validation'
            Assert-FileSha256 -Path $preflightManifestPath -ExpectedSha256 $ExpectedManifestSha256 -Label 'Preflight retained-byte probe-manifest after manifest validation'
            Assert-FileSha256 -Path $SourceManifestPath -ExpectedSha256 $ExpectedManifestSha256 -Label 'Source probe manifest after preflight manifest validation'
        }
        if ($validation.exit_code -ne 0) { throw "Probe manifest validation failed: $($validation.stderr.Trim())" }

        $verifySnapshotArguments = @(
            $preflightGeneratorPath,
            '--repo-root', $RepoRoot,
            '--expected-self-sha256', $preflightGeneratorSha256,
            'verify-current-ledger-snapshot',
            '--manifest', $preflightManifestPath
        )
        try {
            $snapshotVerification = Invoke-HashPinnedChildScript `
                -FilePath $PythonPath `
                -Arguments $verifySnapshotArguments `
                -ScriptPath $preflightGeneratorPath `
                -ScriptArgumentIndex 0 `
                -ExpectedScriptSha256 $preflightGeneratorSha256
        } finally {
            Assert-FileSha256 -Path $preflightGeneratorPath -ExpectedSha256 $preflightGeneratorSha256 -Label 'Preflight generator snapshot after ledger verification'
            Assert-FileSha256 -Path $SourceGeneratorPath -ExpectedSha256 $preflightGeneratorSha256 -Label 'Source generator after preflight ledger verification'
            Assert-FileSha256 -Path $preflightManifestPath -ExpectedSha256 $ExpectedManifestSha256 -Label 'Preflight retained-byte probe-manifest after ledger verification'
            Assert-FileSha256 -Path $SourceManifestPath -ExpectedSha256 $ExpectedManifestSha256 -Label 'Source probe manifest after preflight ledger verification'
        }
        if ($snapshotVerification.exit_code -ne 0) { throw "Current-ledger snapshot verification failed: $($snapshotVerification.stderr.Trim())" }

        $result = [pscustomobject][ordered]@{
            generator_sha256 = $preflightGeneratorSha256
            validate_arguments = @($validateArguments)
            validation = $validation
            verify_snapshot_arguments = @($verifySnapshotArguments)
            snapshot_verification = $snapshotVerification
        }
    } catch {
        $primaryFailure = $_
    } finally {
        try {
            $resolvedCleanupStage = [System.IO.Path]::GetFullPath($preflightStage)
            if (-not $resolvedCleanupStage.StartsWith($preflightPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
                [System.IO.Path]::GetFileName($resolvedCleanupStage) -cne $preflightLeaf) {
                throw "Refusing unsafe generator-preflight cleanup path: '$resolvedCleanupStage'."
            }
            if ([System.IO.Directory]::Exists($resolvedCleanupStage)) {
                Assert-NoReparsePointTree $resolvedCleanupStage
                [System.IO.Directory]::Delete($resolvedCleanupStage, $true)
            }
        } catch {
            Add-CleanupFailure -Failures $cleanupFailures -Operation 'Generator preflight snapshot cleanup' -Failure $_
        }
    }
    if ($null -ne $primaryFailure) {
        if ($cleanupFailures.Count -gt 0) {
            throw "$($primaryFailure.Exception.Message) Cleanup also failed: $($cleanupFailures -join ' | ')"
        }
        throw $primaryFailure
    }
    if ($cleanupFailures.Count -gt 0) { throw "Generator preflight cleanup failed: $($cleanupFailures -join ' | ')" }
    return $result
}

function Write-Checksums {
    param([Parameter(Mandatory = $true)][string]$Stage)
    Assert-NoReparsePointTree $Stage
    $checksumPath = Join-Path $Stage 'checksums.sha256'
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($file in @(Get-ChildItem -LiteralPath $Stage -File -Force -Recurse | Where-Object FullName -ne $checksumPath | Sort-Object FullName)) {
        $relative = [System.IO.Path]::GetRelativePath($Stage, $file.FullName).Replace('\', '/')
        if ($relative.StartsWith('/') -or $relative -split '/' -contains '..') { throw "Unsafe checksum path '$relative'." }
        $lines.Add(('{0}  {1}' -f (Get-Sha256 $file.FullName), $relative))
    }
    Write-TextLf -Path $checksumPath -Text ($lines -join "`n") -FinalNewline
}

if ($LoadFunctionsOnly) { return }

if ($DryRun -and $GenerateOnly) { throw '-DryRun and -GenerateOnly are mutually exclusive.' }

$resolvedManifest = Resolve-RepoFile -Path $ManifestPath -AllowedRoot $script:ManifestRoot -Label 'Probe manifest'
$resolvedGenerator = Resolve-RepoFile -Path $script:GeneratorPath -AllowedRoot $script:RepoRoot -Label 'Generator/validator'
$resolvedWindowCapture = Resolve-RepoFile -Path $script:WindowCapturePath -AllowedRoot $script:RepoRoot -Label 'Window capture tool'
$resolvedFrmInventory = Resolve-RepoFile -Path $script:FrmInventoryPath -AllowedRoot $script:RepoRoot -Label 'FRM inventory validator'
$resolvedCfbInventory = Resolve-RepoFile -Path $script:CfbInventoryPath -AllowedRoot $script:RepoRoot -Label 'CFB inventory validator'
$resolvedRunner = Resolve-RepoFile -Path $PSCommandPath -AllowedRoot $script:RepoRoot -Label 'Capture runner'
$pythonCommand = @(Get-Command python -CommandType Application -ErrorAction Stop)[0]
$pythonPath = [string]$pythonCommand.Source
if ([string]::IsNullOrWhiteSpace($pythonPath)) { $pythonPath = [string]$pythonCommand.Path }
if ([string]::IsNullOrWhiteSpace($pythonPath)) { throw 'The Python interpreter path is unavailable.' }
$powerShellPath = [System.Environment]::ProcessPath
if ([string]::IsNullOrWhiteSpace($powerShellPath) -or -not (Test-Path -LiteralPath $powerShellPath -PathType Leaf)) {
    throw 'The current PowerShell executable path is unavailable.'
}

$frozenManifest = Read-FrozenUtf8Json -Path $resolvedManifest -Label 'Probe manifest'
$sourceManifestBytes = [byte[]]$frozenManifest.bytes
$sourceManifestSha256 = [string]$frozenManifest.sha256
$manifest = $frozenManifest.value
$preflight = Invoke-GeneratorPreflight `
    -SourceGeneratorPath $resolvedGenerator `
    -SourceManifestPath $resolvedManifest `
    -ManifestBytes $sourceManifestBytes `
    -ExpectedManifestSha256 $sourceManifestSha256 `
    -RepoRoot $script:RepoRoot `
    -PythonPath $pythonPath
$preflightGeneratorSha256 = [string]$preflight.generator_sha256
$validateArguments = @($preflight.validate_arguments)
$validation = $preflight.validation
$verifySnapshotArguments = @($preflight.verify_snapshot_arguments)
$snapshotVerification = $preflight.snapshot_verification
Assert-FileSha256 -Path $resolvedGenerator -ExpectedSha256 $preflightGeneratorSha256 -Label 'Source generator after snapshot-bound preflight'
Assert-FileSha256 -Path $resolvedManifest -ExpectedSha256 $sourceManifestSha256 -Label 'Source probe manifest after snapshot-bound preflight'
Assert-ReplayValidatorPin -Manifest $manifest -Role 'frm_inventory' -SourcePath $resolvedFrmInventory
Assert-ReplayValidatorPin -Manifest $manifest -Role 'cfb_inventory' -SourcePath $resolvedCfbInventory
$bead = [string]$manifest.bead
if ($bead -notmatch '^oxforms-jbjp\.[1-9][0-9]*$') { throw "Manifest bead is not a safe numbered W010 bead id: '$bead'." }
$outputKind = if ($GenerateOnly) { 'generated' } else { 'captures' }
$script:EvidenceCaptureRoot = Join-Path $script:EvidenceBeadsRoot (Join-Path $bead $outputKind)
if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = Join-Path $script:EvidenceCaptureRoot ([string]$manifest.id) }
$resolvedOutDir = Resolve-EvidenceOutDir $OutDir -AllowExisting:$DryRun
$effectiveCaptureId = if ([string]::IsNullOrWhiteSpace($CaptureId)) { [System.IO.Path]::GetFileName($resolvedOutDir) } else { $CaptureId }
if ($effectiveCaptureId -cnotmatch '^[A-Za-z][A-Za-z0-9_]{0,39}$') { throw "CaptureId is not a safe schema identifier: '$effectiveCaptureId'." }
if (-not $GenerateOnly -and [System.IO.Path]::GetFileName($resolvedOutDir) -cne $effectiveCaptureId) {
    throw "CaptureId '$effectiveCaptureId' must exactly match the output-directory leaf."
}
$pythonVersion = Invoke-ExternalCommand -FilePath $pythonPath -Arguments @('--version')
if ($pythonVersion.exit_code -ne 0) { throw "Python version probe failed: $($pythonVersion.stderr.Trim())" }
$pythonVersionText = (@($pythonVersion.stdout.Trim(), $pythonVersion.stderr.Trim()) | Where-Object { $_ }) -join '; '
if ([string]::IsNullOrWhiteSpace($pythonVersionText)) { throw 'Python version probe returned no identity.' }

if ($DryRun) {
    Assert-FileSha256 -Path $resolvedGenerator -ExpectedSha256 $preflightGeneratorSha256 -Label 'Source generator before dry-run completion'
    Assert-FileSha256 -Path $resolvedManifest -ExpectedSha256 $sourceManifestSha256 -Label 'Source probe manifest before dry-run completion'
    [pscustomobject][ordered]@{
        status = 'ok'
        mode = 'dry_run'
        manifest_id = [string]$manifest.id
        bead = $bead
        manifest = Convert-ToRepoPath $resolvedManifest
        output = Convert-ToRepoPath $resolvedOutDir
        capture_id = $effectiveCaptureId
        generator = Convert-ToRepoPath $resolvedGenerator
        generator_sha256 = $preflightGeneratorSha256
        window_capture = Convert-ToRepoPath $resolvedWindowCapture
        macro_timeout_seconds = $MacroTimeoutSeconds
        excel_started = $false
    } | ConvertTo-Json -Depth 10
    exit 0
}

if (-not $GenerateOnly -and -not (Test-IsWindows)) { throw 'Live Excel/MSForms capture requires Windows.' }

$stage = New-StagingDirectory $resolvedOutDir
$progressPath = Join-Path $stage 'capture-progress.log'
$startedAtUtc = [DateTime]::UtcNow.ToString('o')
$promoted = $false
$toolSnapshots = $null
try {
    Write-TextLf -Path (Join-Path $stage '.gitattributes') -Text @'
* text=auto eol=lf
*.json text eol=lf diff
*.bas text eol=lf diff
*.log text eol=lf diff
*.md text eol=lf diff
*.txt text eol=lf diff
*.sha256 text eol=lf diff
*.frm -text -diff
*.frx -text -diff
*.xlsm -text -diff
*.png -text -diff
'@ -FinalNewline
    $toolSnapshots = [ordered]@{
        generator_validator = New-ToolSnapshot -Stage $stage -SourcePath $resolvedGenerator
        capture_runner = New-ToolSnapshot -Stage $stage -SourcePath $resolvedRunner
        window_capture = New-ToolSnapshot -Stage $stage -SourcePath $resolvedWindowCapture
        frm_inventory = New-ToolSnapshot -Stage $stage -SourcePath $resolvedFrmInventory
        cfb_inventory = New-ToolSnapshot -Stage $stage -SourcePath $resolvedCfbInventory
    }
    if ([string]$toolSnapshots.generator_validator.sha256 -cne $preflightGeneratorSha256) {
        throw 'The capture-local generator snapshot does not match the self-pinned preflight generator bytes.'
    }
    Assert-FileSha256 -Path $resolvedGenerator -ExpectedSha256 $preflightGeneratorSha256 -Label 'Generator after capture-local snapshot binding'
    Assert-ReplayValidatorPin -Manifest $manifest -Role 'frm_inventory' -SourcePath $resolvedFrmInventory -Snapshot $toolSnapshots.frm_inventory
    Assert-ReplayValidatorPin -Manifest $manifest -Role 'cfb_inventory' -SourcePath $resolvedCfbInventory -Snapshot $toolSnapshots.cfb_inventory
    $generatorSnapshotPath = Resolve-ToolSnapshotPath -Stage $stage -Snapshot $toolSnapshots.generator_validator -Label 'Generator/validator'
    $windowCaptureSnapshotPath = Resolve-ToolSnapshotPath -Stage $stage -Snapshot $toolSnapshots.window_capture -Label 'Window capture tool'
    $cfbInventorySnapshotPath = Resolve-ToolSnapshotPath -Stage $stage -Snapshot $toolSnapshots.cfb_inventory -Label 'CFB inventory validator'
    Assert-FileSha256 -Path $resolvedManifest -ExpectedSha256 $sourceManifestSha256 -Label 'Probe manifest before snapshotting'
    $inputSnapshotDirectory = Join-Path $stage 'input-snapshots'
    [void][System.IO.Directory]::CreateDirectory($inputSnapshotDirectory)
    $manifestSnapshotPath = Join-Path $inputSnapshotDirectory 'probe-manifest.json'
    [System.IO.File]::WriteAllBytes($manifestSnapshotPath, $sourceManifestBytes)
    Assert-FileSha256 -Path $resolvedManifest -ExpectedSha256 $sourceManifestSha256 -Label 'Probe manifest after snapshotting'
    Assert-FileSha256 -Path $manifestSnapshotPath -ExpectedSha256 $sourceManifestSha256 -Label 'Capture-local probe-manifest snapshot'
    Add-Progress $progressPath "Started mode=$(if ($GenerateOnly) { 'generate_only' } else { 'capture' }); manifest=$([string]$manifest.id)."

    $snapshotValidateArguments = @(
        $generatorSnapshotPath,
        '--repo-root', $script:RepoRoot,
        '--expected-self-sha256', ([string]$toolSnapshots.generator_validator.sha256),
        'validate-manifest',
        '--manifest', $manifestSnapshotPath
    )
    Assert-FileSha256 -Path $manifestSnapshotPath -ExpectedSha256 $sourceManifestSha256 -Label 'Capture-local probe-manifest before snapshot validation'
    try {
        $snapshotValidation = Invoke-HashPinnedChildScript `
            -FilePath $pythonPath `
            -Arguments $snapshotValidateArguments `
            -ScriptPath $generatorSnapshotPath `
            -ScriptArgumentIndex 0 `
            -ExpectedScriptSha256 ([string]$toolSnapshots.generator_validator.sha256)
    } finally {
        Assert-FileSha256 -Path $manifestSnapshotPath -ExpectedSha256 $sourceManifestSha256 -Label 'Capture-local probe-manifest after snapshot validation'
    }
    if ($snapshotValidation.exit_code -ne 0) { throw "Snapshot manifest validation failed: $($snapshotValidation.stderr.Trim())" }
    $snapshotLedgerArguments = @(
        $generatorSnapshotPath,
        '--repo-root', $script:RepoRoot,
        '--expected-self-sha256', ([string]$toolSnapshots.generator_validator.sha256),
        'verify-current-ledger-snapshot',
        '--manifest', $manifestSnapshotPath
    )
    Assert-FileSha256 -Path $manifestSnapshotPath -ExpectedSha256 $sourceManifestSha256 -Label 'Capture-local probe-manifest before snapshot ledger verification'
    try {
        $snapshotLedgerVerification = Invoke-HashPinnedChildScript `
            -FilePath $pythonPath `
            -Arguments $snapshotLedgerArguments `
            -ScriptPath $generatorSnapshotPath `
            -ScriptArgumentIndex 0 `
            -ExpectedScriptSha256 ([string]$toolSnapshots.generator_validator.sha256)
    } finally {
        Assert-FileSha256 -Path $manifestSnapshotPath -ExpectedSha256 $sourceManifestSha256 -Label 'Capture-local probe-manifest after snapshot ledger verification'
    }
    if ($snapshotLedgerVerification.exit_code -ne 0) { throw "Snapshot ledger verification failed: $($snapshotLedgerVerification.stderr.Trim())" }

    $generateArguments = @(
        $generatorSnapshotPath,
        '--repo-root', $script:RepoRoot,
        '--expected-self-sha256', ([string]$toolSnapshots.generator_validator.sha256),
        'generate',
        '--manifest', $manifestSnapshotPath,
        '--output-dir', $stage
    )
    Assert-FileSha256 -Path $manifestSnapshotPath -ExpectedSha256 $sourceManifestSha256 -Label 'Capture-local probe-manifest before source generation'
    try {
        $generation = Invoke-HashPinnedChildScript `
            -FilePath $pythonPath `
            -Arguments $generateArguments `
            -ScriptPath $generatorSnapshotPath `
            -ScriptArgumentIndex 0 `
            -ExpectedScriptSha256 ([string]$toolSnapshots.generator_validator.sha256)
    } finally {
        Assert-FileSha256 -Path $manifestSnapshotPath -ExpectedSha256 $sourceManifestSha256 -Label 'Capture-local probe-manifest after source generation'
    }
    $generatorStdoutParts = @($pythonVersion.stdout, $pythonVersion.stderr, $snapshotVerification.stdout, $validation.stdout, $snapshotValidation.stdout, $snapshotLedgerVerification.stdout, $generation.stdout)
    $generatorStderrParts = @($snapshotVerification.stderr, $validation.stderr, $snapshotValidation.stderr, $snapshotLedgerVerification.stderr, $generation.stderr)
    $generatorCommandEntries = @(
        [ordered]@{ purpose = 'python_version'; file = $pythonPath; arguments = @('--version'); exit_code = $pythonVersion.exit_code },
        [ordered]@{ purpose = 'verify_current_ledger_snapshot'; file = $pythonPath; arguments = $verifySnapshotArguments; exit_code = $snapshotVerification.exit_code },
        [ordered]@{ purpose = 'validate_manifest'; file = $pythonPath; arguments = $validateArguments; exit_code = $validation.exit_code },
        [ordered]@{ purpose = 'validate_manifest_from_snapshot'; file = $pythonPath; arguments = $snapshotValidateArguments; exit_code = $snapshotValidation.exit_code },
        [ordered]@{ purpose = 'verify_current_ledger_from_snapshot'; file = $pythonPath; arguments = $snapshotLedgerArguments; exit_code = $snapshotLedgerVerification.exit_code },
        [ordered]@{ purpose = 'generate_sources_from_snapshot'; file = $pythonPath; arguments = $generateArguments; exit_code = $generation.exit_code }
    )
    Write-TextLf -Path (Join-Path $stage 'generator-stdout.log') -Text ((@($generatorStdoutParts) | Where-Object { $_ -ne '' }) -join "`n") -FinalNewline
    Write-TextLf -Path (Join-Path $stage 'generator-stderr.log') -Text ((@($generatorStderrParts) | Where-Object { $_ -ne '' }) -join "`n")
    Write-JsonLf -Path (Join-Path $stage 'generator-command.json') -Value ([ordered]@{
        schema = 'oxforms.office_oracle.command_log.v1'
        commands = $generatorCommandEntries
    })
    if ($generation.exit_code -ne 0) { throw "VBA generation failed: $($generation.stderr.Trim())" }
    Add-Progress $progressPath 'Validated the source manifest and generated deterministic VBA/normalized manifest.'

    if ($GenerateOnly) {
        Write-TextLf -Path (Join-Path $stage 'README.md') -Text "# MSForms member-oracle generated sources`n`nGenerated only; Excel was not started and this directory is not a live capture.`n" -FinalNewline
        Write-JsonLf -Path (Join-Path $stage 'generation-manifest.json') -Value ([ordered]@{
            schema = 'oxforms.office_oracle.msforms_member_generation.v1'
            manifest = [ordered]@{ id = [string]$manifest.id; path = Convert-ToRepoPath $resolvedManifest; sha256 = $sourceManifestSha256 }
            generator = [ordered]@{ path = [string]$toolSnapshots.generator_validator.source_path; sha256 = [string]$toolSnapshots.generator_validator.sha256 }
            generated_at_utc = [DateTime]::UtcNow.ToString('o')
        })
        Assert-FileSha256 -Path $resolvedManifest -ExpectedSha256 $sourceManifestSha256 -Label 'Probe manifest before generate-only promotion'
        Assert-ToolSnapshotStillCurrent -SourcePath $resolvedGenerator -Snapshot $toolSnapshots.generator_validator
        Assert-ToolSnapshotStillCurrent -SourcePath $resolvedRunner -Snapshot $toolSnapshots.capture_runner
        Assert-ToolSnapshotStillCurrent -SourcePath $resolvedWindowCapture -Snapshot $toolSnapshots.window_capture
        Assert-ToolSnapshotStillCurrent -SourcePath $resolvedFrmInventory -Snapshot $toolSnapshots.frm_inventory
        Assert-ToolSnapshotStillCurrent -SourcePath $resolvedCfbInventory -Snapshot $toolSnapshots.cfb_inventory
        Add-Progress $progressPath 'Generate-only output is complete and ready for atomic promotion.'
        Assert-FileSha256 -Path $manifestSnapshotPath -ExpectedSha256 $sourceManifestSha256 -Label 'Capture-local probe-manifest before generate-only checksums'
        Write-Checksums $stage
        Assert-FileSha256 -Path $manifestSnapshotPath -ExpectedSha256 $sourceManifestSha256 -Label 'Capture-local probe-manifest after generate-only checksums'
        Assert-NoReparsePointTree $stage
        Assert-FileSha256 -Path $manifestSnapshotPath -ExpectedSha256 $sourceManifestSha256 -Label 'Capture-local probe-manifest before generate-only promotion'
        [System.IO.Directory]::Move($stage, $resolvedOutDir)
        $promoted = $true
        Write-Host "Generated source bundle: $resolvedOutDir"
        exit 0
    }

    $workbookPath = Join-Path $stage 'member-oracle.xlsm'
    $formName = [string]$manifest.form.name
    $formExportPath = Join-Path $stage ($formName + '.frm')
    $buildPhaseTimeoutSeconds = [Math]::Max(180, $MacroTimeoutSeconds * 2)
    $livePhaseTimeoutSeconds = [Math]::Max(240, [Math]::Max($MacroTimeoutSeconds * 4, $WindowTimeoutSeconds + 60))
    Add-Progress $progressPath 'Phase 1: starting a directly created, suspended-then-Job-contained /safe Excel process for hidden VBIDE construction/export/save.'
    $buildExcelIdentity = New-OracleWorkbook `
        -Manifest $manifest `
        -FormCodePath (Join-Path $stage 'generated-form-code.bas') `
        -ModuleCodePath (Join-Path $stage 'generated-module-code.bas') `
        -WorkbookPath $workbookPath `
        -FormExportPath $formExportPath `
        -PhaseTimeoutSeconds $buildPhaseTimeoutSeconds
    Add-Progress $progressPath 'Phase 1: safe-mode hidden build/export/save completed and the contained private Excel process was closed.'

    $runnerPreopenWorkbookSha256 = Get-Sha256 $workbookPath
    $preopenArguments = @(
        $generatorSnapshotPath,
        '--repo-root', $script:RepoRoot,
        '--expected-self-sha256', ([string]$toolSnapshots.generator_validator.sha256),
        'validate-preopen-workbook',
        '--manifest', $manifestSnapshotPath,
        '--workbook', $workbookPath,
        '--cfb-validator', $cfbInventorySnapshotPath
    )
    Assert-FileSha256 -Path $manifestSnapshotPath -ExpectedSha256 $sourceManifestSha256 -Label 'Capture-local probe-manifest before pre-open validation'
    try {
        $preopenValidation = Invoke-HashPinnedChildScript `
            -FilePath $pythonPath `
            -Arguments $preopenArguments `
            -ScriptPath $generatorSnapshotPath `
            -ScriptArgumentIndex 0 `
            -ExpectedScriptSha256 ([string]$toolSnapshots.generator_validator.sha256)
    } finally {
        Assert-FileSha256 -Path $manifestSnapshotPath -ExpectedSha256 $sourceManifestSha256 -Label 'Capture-local probe-manifest after pre-open validation'
    }
    $generatorStdoutParts += $preopenValidation.stdout
    $generatorStderrParts += $preopenValidation.stderr
    $generatorCommandEntries += [ordered]@{
        purpose = 'validate_preopen_workbook_from_snapshots'
        file = $pythonPath
        arguments = $preopenArguments
        exit_code = $preopenValidation.exit_code
    }
    Write-TextLf -Path (Join-Path $stage 'generator-stdout.log') -Text ((@($generatorStdoutParts) | Where-Object { $_ -ne '' }) -join "`n") -FinalNewline
    Write-TextLf -Path (Join-Path $stage 'generator-stderr.log') -Text ((@($generatorStderrParts) | Where-Object { $_ -ne '' }) -join "`n")
    Write-JsonLf -Path (Join-Path $stage 'generator-command.json') -Value ([ordered]@{
        schema = 'oxforms.office_oracle.command_log.v1'
        commands = $generatorCommandEntries
    })
    if ($preopenValidation.exit_code -ne 0) {
        throw "Strict pre-open workbook validation failed: $($preopenValidation.stderr.Trim()) $($preopenValidation.stdout.Trim())"
    }
    try {
        $preopenResult = $preopenValidation.stdout | ConvertFrom-Json
    } catch {
        throw "Strict pre-open workbook validation returned malformed JSON: $($_.Exception.Message)"
    }
    $preopenResultKeys = @($preopenResult.PSObject.Properties.Name | Sort-Object)
    if (($preopenResultKeys -join ',') -cne 'status,workbook_sha256' -or
        [string]$preopenResult.status -cne 'ok' -or
        [string]$preopenResult.workbook_sha256 -cnotmatch '^[0-9a-f]{64}$') {
        throw 'Strict pre-open workbook validation returned an unexpected result contract.'
    }
    $preopenWorkbookSha256 = [string]$preopenResult.workbook_sha256
    if ($preopenWorkbookSha256 -cne $runnerPreopenWorkbookSha256) {
        throw 'Strict pre-open workbook validator SHA-256 disagrees with the independently pinned runner digest.'
    }
    if ((Get-Sha256 $workbookPath) -cne $preopenWorkbookSha256) {
        throw 'Strict pre-open validation changed the phase-1 workbook bytes.'
    }
    Add-Progress $progressPath "Phase 1.5: strict pre-open XLSM/source validation passed for SHA-256 $preopenWorkbookSha256."

    Add-Progress $progressPath 'Phase 2: starting a directly created, suspended-then-Job-contained /safe visible Excel process with AutomationSecurity=1.'
    $live = Invoke-LiveOracle `
        -Manifest $manifest `
        -WorkbookPath $workbookPath `
        -ExpectedPreopenWorkbookSha256 $preopenWorkbookSha256 `
        -Stage $stage `
        -FinalOutDir $resolvedOutDir `
        -PowerShellPath $powerShellPath `
        -ProgressPath $progressPath `
        -WindowCapturePath $windowCaptureSnapshotPath `
        -WindowCaptureSha256 ([string]$toolSnapshots.window_capture.sha256) `
        -PhaseTimeoutSeconds $livePhaseTimeoutSeconds
    Add-Progress $progressPath 'Phase 2: macro run, owned-window screenshot, worksheet export, CloseMemberOracle, save, close, and private Excel quit completed.'

    Assert-FileSha256 -Path $resolvedManifest -ExpectedSha256 $sourceManifestSha256 -Label 'Probe manifest before result serialization'
    $manifestSha = $sourceManifestSha256
    Write-JsonLf -Path (Join-Path $stage 'probe-results.v1.json') -Value ([ordered]@{
        schema = 'oxforms.office_oracle.msforms_member_probe_results.v1'
        schema_version = 1
        manifest = [ordered]@{ id = [string]$manifest.id; sha256 = $manifestSha }
        rows = @($live.results)
    })
    Write-JsonLf -Path (Join-Path $stage 'event-log.v1.json') -Value ([ordered]@{
        schema = 'oxforms.office_oracle.msforms_member_event_log.v1'
        schema_version = 1
        manifest = [ordered]@{ id = [string]$manifest.id; sha256 = $manifestSha }
        rows = @($live.events)
    })

    $validatorArguments = @(
        $generatorSnapshotPath,
        '--repo-root', $script:RepoRoot,
        '--expected-self-sha256', ([string]$toolSnapshots.generator_validator.sha256),
        'validate-capture',
        '--manifest', $manifestSnapshotPath,
        '--capture-dir', $stage
    )
    Write-JsonLf -Path (Join-Path $stage 'capture-command.json') -Value ([ordered]@{
        schema = 'oxforms.office_oracle.capture_command.v1'
        runner = [ordered]@{
            process_path = $powerShellPath
            environment_command_line = [System.Environment]::CommandLine
            script = Convert-ToRepoPath $resolvedRunner
            bound_parameters = [ordered]@{
                manifest_path = $ManifestPath
                out_dir = $OutDir
                capture_id = $effectiveCaptureId
                bead = $bead
                dry_run = $false
                generate_only = $false
                window_timeout_seconds = $WindowTimeoutSeconds
                macro_timeout_seconds = $MacroTimeoutSeconds
                build_phase_timeout_seconds = $buildPhaseTimeoutSeconds
                live_phase_timeout_seconds = $livePhaseTimeoutSeconds
                shutdown_timeout_seconds = 15
                python_command_timeout_seconds = 120
                window_capture_process_timeout_seconds = [Math]::Max(30, $WindowTimeoutSeconds + 15)
            }
        }
        window_capture = [ordered]@{ file = $live.window_command.file; arguments = $live.window_command.arguments; exit_code = $live.window_command.exit_code }
        staged_validator = [ordered]@{ file = $pythonPath; arguments = $validatorArguments }
    })

    $allIsolationChecks = @($buildExcelIdentity.isolation_checks) + @($live.excel.isolation_checks)
    $incompleteComAddInsChecks = @($allIsolationChecks | Where-Object {
        -not [bool]$_.com_addins_access.inventory_complete
    })
    $comAddInsNonclaimWarning = 'Application.COMAddIns returned exact 0x800A03EC at one or more safe-mode isolation checkpoints; its inventory is incomplete and this capture makes no COM-add-in connection-state claim.'
    $comAddInsReadme = if ($incompleteComAddInsChecks.Count -ne 0) {
        $comAddInsNonclaimWarning
    } else {
        'Application.COMAddIns was completely inventoried at every isolation checkpoint and every observed Connect value was false.'
    }
    $captureWarnings = @(
        'Error descriptions are locale-sensitive; culture and code-page identity are pinned in this manifest.',
        'VBE and FM20 identities name exact loaded-module bytes but do not assert internal ownership of any observed behavior.',
        'The PNG is a screen-coordinate CopyFromScreen observation bracketed by exact HWND/process/window-state metadata; visual review is required and the bytes are not an HWND surface proof.'
    )
    if ($incompleteComAddInsChecks.Count -ne 0) { $captureWarnings += $comAddInsNonclaimWarning }

    Write-TextLf -Path (Join-Path $stage 'README.md') -Text @"
# Live Excel/MSForms representative member oracle

This is a clean-room black-box observation produced from the repo-owned declarative manifest through public Excel/VBIDE automation. It contains no OxForms output and makes no OxForms behavior claim.

The runner used two directly created Excel ``/safe`` processes: a hidden build/export/save phase, then a fresh visible AutomationSecurity=1 execution phase. Each process was created suspended, assigned to a kill-on-close Job, verified as a Job member, and only then resumed. Exact PID/start/path/hash and raw OS command-line observations bind the later ``EXCEL7``/``OBJID_NATIVEOM`` automation object. A narrow suspended creation-to-Job-assignment interval remains, so this evidence does not claim atomic creation-time Job association; functional tests prove descendant termination after completed launch and on abrupt supervisor death.

Each phase closed the sole allowed pathless startup workbook and recorded three exact-process isolation checkpoints covering all owned top-level windows, foreign workbooks, startup paths, Protected View, Excel AddIns/AddIns2, and loaded XLLs. $comAddInsReadme

Exact member errors remain worksheet/result rows. The PNG is a coordinate-based CopyFromScreen observation with an exact selected-window/process metadata bracket immediately before and after the screen read; it requires visual review and is not proof of an HWND-owned surface. The staged tree was checksum-complete and replay-validated before atomic promotion.

The synchronous VBA run was bounded by a separate exact-PID/start-time/executable watchdog and the retained Job is the final process-tree cleanup backstop. A successful capture preserves a disarmed watchdog log; a timeout terminates only that verified private Excel process and cannot be promoted as evidence.
"@ -FinalNewline

    $successCount = @($live.results | Where-Object outcome -eq 'success').Count
    $errorCount = @($live.results | Where-Object outcome -eq 'error').Count
    $controlFamilies = @($manifest.form.controls | ForEach-Object { [string]$_.fm20_type } | Sort-Object -Unique)
    Assert-ToolSnapshotStillCurrent -SourcePath $resolvedGenerator -Snapshot $toolSnapshots.generator_validator
    Assert-ToolSnapshotStillCurrent -SourcePath $resolvedRunner -Snapshot $toolSnapshots.capture_runner
    Assert-ToolSnapshotStillCurrent -SourcePath $resolvedWindowCapture -Snapshot $toolSnapshots.window_capture
    Assert-ToolSnapshotStillCurrent -SourcePath $resolvedFrmInventory -Snapshot $toolSnapshots.frm_inventory
    Assert-ToolSnapshotStillCurrent -SourcePath $resolvedCfbInventory -Snapshot $toolSnapshots.cfb_inventory
    Add-Progress $progressPath 'All capture artifacts are frozen; staged validator replay is the promotion gate.'
    $completedAtUtc = [DateTime]::UtcNow.ToString('o')

    $artifactPaths = [ordered]@{
        capture_attributes = '.gitattributes'
        capture_command = 'capture-command.json'
        capture_progress = 'capture-progress.log'
        generator_command = 'generator-command.json'
        generator_stdout = 'generator-stdout.log'
        generator_stderr = 'generator-stderr.log'
        window_stdout = 'window-stdout.log'
        window_stderr = 'window-stderr.log'
        macro_watchdog = 'macro-watchdog.log'
        workbook = 'member-oracle.xlsm'
        form_export = ($formName + '.frm')
        frx_export = ($formName + '.frx')
        probe_results = 'probe-results.v1.json'
        event_log = 'event-log.v1.json'
        screenshot = 'window-capture.png'
        window_manifest = 'window-capture-manifest.json'
        generated_form_code = 'generated-form-code.bas'
        generated_module_code = 'generated-module-code.bas'
        normalized_manifest = 'normalized-manifest.v1.json'
        readme = 'README.md'
    }
    $artifacts = [ordered]@{}
    foreach ($entry in $artifactPaths.GetEnumerator()) { $artifacts[$entry.Key] = New-ArtifactReference -Stage $stage -RelativePath $entry.Value }

    $captureManifest = [ordered]@{
        schema = 'oxforms.office_oracle.msforms_member_capture.v1'
        schema_version = 1
        bead = $bead
        capture_id = $effectiveCaptureId
        status = 'captured'
        started_at_utc = $startedAtUtc
        completed_at_utc = $completedAtUtc
        probe_manifest = [ordered]@{
            id = [string]$manifest.id
            path = Convert-ToRepoPath $resolvedManifest
            sha256 = $manifestSha
            ledger_canonical_sha256 = [string]$manifest.ledger.canonical_sha256
        }
        tools = $toolSnapshots
        build_excel = $buildExcelIdentity
        preopen_workbook_sha256 = $preopenWorkbookSha256
        platform = [ordered]@{
            os = [System.Environment]::OSVersion.VersionString
            is_windows = $true
            powershell = $PSVersionTable.PSVersion.ToString()
            python = ($pythonVersionText + '; ' + $pythonPath)
            process_architecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
            culture = [System.Globalization.CultureInfo]::CurrentCulture.Name
            ui_culture = [System.Globalization.CultureInfo]::CurrentUICulture.Name
            ansi_code_page = [int][System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage
            oem_code_page = [int][System.Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage
            office_ui_lcid = [int]$live.office_ui_lcid
        }
        excel = $live.excel
        vbe = $live.vbe
        fm20 = $live.fm20
        artifacts = $artifacts
        observed_coverage = [ordered]@{
            control_families = $controlFamilies
            probe_count = @($manifest.steps | Where-Object kind -eq 'probe').Count
            success_count = $successCount
            error_count = $errorCount
            event_row_count = @($live.events).Count
            screenshot_count = 1
            export_pair_count = 1
        }
        provenance = $manifest.provenance
        warnings = @($captureWarnings)
        non_claims = @($manifest.non_claims)
    }
    Write-JsonLf -Path (Join-Path $stage 'oracle-capture-manifest.json') -Value $captureManifest
    Assert-FileSha256 -Path $manifestSnapshotPath -ExpectedSha256 $sourceManifestSha256 -Label 'Capture-local probe-manifest before live-capture checksums'
    Write-Checksums $stage
    Assert-FileSha256 -Path $manifestSnapshotPath -ExpectedSha256 $sourceManifestSha256 -Label 'Capture-local probe-manifest after live-capture checksums'
    Assert-NoReparsePointTree $stage

    Assert-FileSha256 -Path $resolvedManifest -ExpectedSha256 $sourceManifestSha256 -Label 'Probe manifest before final replay validation'
    Assert-FileSha256 -Path $manifestSnapshotPath -ExpectedSha256 $sourceManifestSha256 -Label 'Capture-local probe-manifest before final replay validation'
    try {
        $validator = Invoke-HashPinnedChildScript `
            -FilePath $pythonPath `
            -Arguments $validatorArguments `
            -ScriptPath $generatorSnapshotPath `
            -ScriptArgumentIndex 0 `
            -ExpectedScriptSha256 ([string]$toolSnapshots.generator_validator.sha256)
    } finally {
        Assert-FileSha256 -Path $manifestSnapshotPath -ExpectedSha256 $sourceManifestSha256 -Label 'Capture-local probe-manifest after final replay validation'
        Assert-FileSha256 -Path $resolvedManifest -ExpectedSha256 $sourceManifestSha256 -Label 'Probe manifest after final replay validation'
    }
    if ($validator.exit_code -ne 0) {
        throw "Staged capture validation failed: $($validator.stderr.Trim()) $($validator.stdout.Trim())"
    }
    Assert-ToolSnapshotStillCurrent -SourcePath $resolvedGenerator -Snapshot $toolSnapshots.generator_validator
    Assert-ToolSnapshotStillCurrent -SourcePath $resolvedRunner -Snapshot $toolSnapshots.capture_runner
    Assert-ToolSnapshotStillCurrent -SourcePath $resolvedWindowCapture -Snapshot $toolSnapshots.window_capture
    Assert-ToolSnapshotStillCurrent -SourcePath $resolvedFrmInventory -Snapshot $toolSnapshots.frm_inventory
    Assert-ToolSnapshotStillCurrent -SourcePath $resolvedCfbInventory -Snapshot $toolSnapshots.cfb_inventory
    Assert-FileSha256 -Path $manifestSnapshotPath -ExpectedSha256 $sourceManifestSha256 -Label 'Capture-local probe-manifest before live-capture promotion'
    [System.IO.Directory]::Move($stage, $resolvedOutDir)
    $promoted = $true
    Write-Host "Validated live MSForms member-oracle capture: $resolvedOutDir"
    Write-Host $validator.stdout.Trim()
} catch {
    if (-not $promoted -and (Test-Path -LiteralPath $stage -PathType Container)) {
        try { Add-Progress $progressPath ("FAILED: " + $_.Exception.Message) } catch {}
        Write-Warning "Incomplete staging output was retained for diagnosis: $stage"
    }
    throw
}
