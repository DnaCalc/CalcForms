# Windows top-level window discovery and screenshot capture for Office
# oracle evidence. This is local test tooling, not an OxForms runtime API.
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [ValidatePattern('^[0-9A-Fa-f]{64}$')]
    [string]$ExpectedScriptSha256,
    [switch]$SelfTest,
    [string]$TitleContains,
    [string]$ProcessName,
    [string]$ProcessContains,
    [ValidateRange(0, [int]::MaxValue)]
    [int]$ProcessId = 0,
    [string]$ClassName,
    [string]$OutDir,
    [switch]$CaptureScreenshot,
    [switch]$AllowAmbiguous,
    [int]$ScreenshotMaxAttempts = 4,
    [int]$ScreenshotRetryDelayMilliseconds = 250
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Script:CaptureRepoRoot = $null
$Script:EvidenceRoot = $null
$Script:PinnedOutputDirectories = [System.Collections.Generic.List[object]]::new()

function Test-RunningOnWindows {
    if ($PSVersionTable.PSEdition -eq 'Core') {
        return $IsWindows
    }

    return [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
}

function New-Diagnostic {
    param(
        [string]$Code,
        [string]$Message,
        [ValidateSet('info', 'warning', 'error')]
        [string]$Severity = 'error'
    )

    [ordered]@{
        code = $Code
        severity = $Severity
        message = $Message
    }
}

function New-Result {
    param(
        [string]$Mode,
        [hashtable]$Query
    )

    [ordered]@{
        schema = 'oxforms.office_oracle.window_capture.v1'
        tool = 'tools/office-oracle/Capture-Window.ps1'
        mode = $Mode
        timestamp_utc = (Get-Date).ToUniversalTime().ToString('o')
        command = [System.Environment]::CommandLine
        host = [ordered]@{
            os = [System.Environment]::OSVersion.VersionString
            is_windows = (Test-RunningOnWindows)
            powershell = $PSVersionTable.PSVersion.ToString()
        }
        query = $Query
        status = 'failed'
        diagnostics = @()
        visible_top_level_window_count = $null
        match_count = 0
        candidates = @()
        selected_window = $null
        screenshot = $null
        manifest_path = $null
    }
}

function ConvertTo-JsonText {
    param([object]$Value)
    $Value | ConvertTo-Json -Depth 12
}

function Get-Sha256Hex {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try {
            $bytes = $sha256.ComputeHash($stream)
            return ([System.BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant()
        }
        finally {
            $sha256.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Initialize-CaptureContext {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedHash,
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath
    )

    if ($ExpectedHash -notmatch '^[0-9A-Fa-f]{64}$') {
        throw 'ExpectedScriptSha256 must be exactly 64 hexadecimal characters.'
    }

    $resolvedScript = (Resolve-Path -LiteralPath $ScriptPath -ErrorAction Stop).Path
    if (-not (Test-Path -LiteralPath $resolvedScript -PathType Leaf)) {
        throw "Capture script path '$resolvedScript' is not a file."
    }

    $actualHash = Get-Sha256Hex -Path $resolvedScript
    if (-not $actualHash.Equals($ExpectedHash, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Capture script SHA-256 mismatch: expected '$($ExpectedHash.ToLowerInvariant())', observed '$actualHash'."
    }

    $resolvedRoot = (Resolve-Path -LiteralPath $Root -ErrorAction Stop).Path
    if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) {
        throw "Repository root '$resolvedRoot' is not a directory."
    }

    $Script:CaptureRepoRoot = [System.IO.Path]::GetFullPath($resolvedRoot)
    $Script:EvidenceRoot = [System.IO.Path]::GetFullPath((Join-Path $Script:CaptureRepoRoot 'docs\evidence'))
}

function Write-Manifest {
    param(
        [object]$Result,
        [string]$Directory,
        [string]$FileName
    )

    if ([string]::IsNullOrWhiteSpace($Directory)) {
        return
    }

    $manifestPath = Join-Path $Directory $FileName
    $Result.manifest_path = [System.IO.Path]::GetFullPath($manifestPath)
    $json = (ConvertTo-JsonText -Value $Result).Replace("`r`n", "`n").Replace("`r", "`n")
    if (-not $json.EndsWith("`n", [System.StringComparison]::Ordinal)) { $json += "`n" }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    Assert-PinnedOutputDirectory -Directory $Directory
    [System.IO.File]::WriteAllText($manifestPath, $json, $utf8NoBom)
    Assert-PinnedOutputDirectory -Directory $Directory
}

function Resolve-CaptureOutDir {
    param([string]$Directory)

    if ([string]::IsNullOrWhiteSpace($Directory)) {
        throw 'An output directory is required when writing a manifest or screenshot.'
    }

    $inputPath = $Directory.Replace(
        [System.IO.Path]::AltDirectorySeparatorChar,
        [System.IO.Path]::DirectorySeparatorChar
    )
    $inputSegments = @($inputPath.Split(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.StringSplitOptions]::RemoveEmptyEntries
    ))
    if (@($inputSegments | Where-Object { $_ -eq '..' }).Count -gt 0) {
        throw "Output directory '$Directory' must not contain parent-directory traversal segments ('..')."
    }

    if ([System.IO.Path]::IsPathRooted($Directory)) {
        $fullPath = [System.IO.Path]::GetFullPath($Directory)
    }
    else {
        $fullPath = [System.IO.Path]::GetFullPath((Join-Path $Script:CaptureRepoRoot $Directory))
    }

    $evidenceRoot = [System.IO.Path]::GetFullPath($Script:EvidenceRoot)
    $rootWithSeparator = $evidenceRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    if (-not $fullPath.StartsWith($rootWithSeparator, $comparison)) {
        throw "Output directory '$fullPath' is outside the repository evidence root '$evidenceRoot'."
    }
    if (-not (Test-Path -LiteralPath $evidenceRoot -PathType Container)) {
        throw "Repository evidence root '$evidenceRoot' does not exist as a directory."
    }

    $relativePath = $fullPath.Substring($rootWithSeparator.Length).Replace([System.IO.Path]::AltDirectorySeparatorChar, [System.IO.Path]::DirectorySeparatorChar)
    $segments = @($relativePath.Split([System.IO.Path]::DirectorySeparatorChar, [System.StringSplitOptions]::RemoveEmptyEntries))

    $isWorksetCapturePath = (
        $segments.Count -ge 2 -and
        $segments[1].Equals('captures', $comparison)
    )
    $isW010BeadCapturePath = (
        $segments.Count -ge 4 -and
        $segments[0].Equals('W010_complete_msforms_object_model_parity', $comparison) -and
        $segments[1].Equals('beads', $comparison) -and
        $segments[2] -match '^oxforms-jbjp\.[1-9][0-9]*$' -and
        $segments[3].Equals('captures', $comparison)
    )
    if (-not ($isWorksetCapturePath -or $isW010BeadCapturePath)) {
        throw "Output directory '$fullPath' must be under either 'docs\\evidence\\<workset>\\captures\\...' or 'docs\\evidence\\W010_complete_msforms_object_model_parity\\beads\\oxforms-jbjp.<number>\\captures\\...'."
    }

    $cursor = $evidenceRoot
    $pathSegments = @('') + $segments
    foreach ($segment in $pathSegments) {
        if (-not [string]::IsNullOrEmpty([string]$segment)) {
            $cursor = [System.IO.Path]::Combine($cursor, [string]$segment)
        }

        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($null -eq $item) {
            [void][System.IO.Directory]::CreateDirectory($cursor)
            $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        }

        $linkType = $item.PSObject.Properties['LinkType']
        $isLink = (
            ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0 -or
            ($null -ne $linkType -and -not [string]::IsNullOrWhiteSpace([string]$linkType.Value))
        )
        if ($isLink) {
            throw "Output directory '$fullPath' traverses a symlink, junction, or reparse point at '$cursor'."
        }
        if (-not $item.PSIsContainer) {
            throw "Output path '$fullPath' traverses a file at '$cursor'; expected directories only."
        }
    }

    # Hold the validated evidence root and every output descendant open without
    # delete sharing. Starting at docs/evidence avoids conflicting with the
    # child process's own current-directory handle on the repository root.
    # The retained handles prevent a validated path component from being
    # renamed/replaced by a junction while the screenshot and manifest writes
    # are in flight; their file identities and final paths are re-read at each
    # write boundary.
    Add-PinnedOutputDirectoryChain -Directory $fullPath
    return (Resolve-Path -LiteralPath $fullPath).Path
}

function Ensure-WindowsNativeTypes {
    if (-not (Test-RunningOnWindows)) {
        return
    }

    if (([System.Management.Automation.PSTypeName]'OxForms.OfficeOracle.NativeMethods').Type) {
        return
    }

    Add-Type -TypeDefinition @'
using System;
using System.Globalization;
using Microsoft.Win32.SafeHandles;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Text;

namespace OxForms.OfficeOracle
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

        [StructLayout(LayoutKind.Sequential)]
        public struct BY_HANDLE_FILE_INFORMATION
        {
            public uint FileAttributes;
            public FILETIME CreationTime;
            public FILETIME LastAccessTime;
            public FILETIME LastWriteTime;
            public uint VolumeSerialNumber;
            public uint FileSizeHigh;
            public uint FileSizeLow;
            public uint NumberOfLinks;
            public uint FileIndexHigh;
            public uint FileIndexLow;
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern SafeFileHandle CreateFileW(
            string fileName,
            uint desiredAccess,
            uint shareMode,
            IntPtr securityAttributes,
            uint creationDisposition,
            uint flagsAndAttributes,
            IntPtr templateFile);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool GetFileInformationByHandle(
            SafeFileHandle handle,
            out BY_HANDLE_FILE_INFORMATION information);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetProcessTimes(
            IntPtr processHandle,
            out FILETIME creationTime,
            out FILETIME exitTime,
            out FILETIME kernelTime,
            out FILETIME userTime);

        public static string GetProcessStartTimeUtc(IntPtr processHandle)
        {
            FILETIME creationTime;
            FILETIME exitTime;
            FILETIME kernelTime;
            FILETIME userTime;
            if (!GetProcessTimes(processHandle, out creationTime, out exitTime, out kernelTime, out userTime))
            {
                throw new System.ComponentModel.Win32Exception(
                    Marshal.GetLastWin32Error(),
                    "GetProcessTimes failed while binding window process identity.");
            }
            long fileTime = ((long)(uint)creationTime.dwHighDateTime << 32) |
                (uint)creationTime.dwLowDateTime;
            return DateTime.FromFileTimeUtc(fileTime).ToString("o", CultureInfo.InvariantCulture);
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern uint GetFinalPathNameByHandleW(
            SafeFileHandle handle,
            StringBuilder path,
            uint pathLength,
            uint flags);

        [DllImport("user32.dll")]
        public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

        [DllImport("user32.dll")]
        public static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool IsWindow(IntPtr hWnd);

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

        [DllImport("user32.dll")]
        public static extern uint GetDpiForWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    }
}
'@
}

function ConvertFrom-WindowsFinalPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ($Path.StartsWith('\\?\UNC\', [System.StringComparison]::OrdinalIgnoreCase)) {
        return '\\' + $Path.Substring(8)
    }
    if ($Path.StartsWith('\\?\', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $Path.Substring(4)
    }
    return $Path
}

function Get-PinnedDirectoryObservation {
    param(
        [Parameter(Mandatory = $true)]$Handle,
        [Parameter(Mandatory = $true)][string]$ExpectedPath
    )

    $information = New-Object OxForms.OfficeOracle.NativeMethods+BY_HANDLE_FILE_INFORMATION
    if (-not [OxForms.OfficeOracle.NativeMethods]::GetFileInformationByHandle($Handle, [ref]$information)) {
        throw [System.ComponentModel.Win32Exception]::new(
            [Runtime.InteropServices.Marshal]::GetLastWin32Error(),
            "Could not read pinned directory identity for '$ExpectedPath'."
        )
    }
    $builder = [System.Text.StringBuilder]::new(32768)
    $length = [OxForms.OfficeOracle.NativeMethods]::GetFinalPathNameByHandleW(
        $Handle,
        $builder,
        [uint32]$builder.Capacity,
        0
    )
    if ($length -eq 0 -or $length -ge $builder.Capacity) {
        throw [System.ComponentModel.Win32Exception]::new(
            [Runtime.InteropServices.Marshal]::GetLastWin32Error(),
            "Could not resolve pinned directory path for '$ExpectedPath'."
        )
    }
    $finalPath = [System.IO.Path]::GetFullPath((ConvertFrom-WindowsFinalPath -Path $builder.ToString()))
    $expectedFullPath = [System.IO.Path]::GetFullPath($ExpectedPath)
    if (-not $finalPath.TrimEnd('\').Equals(
        $expectedFullPath.TrimEnd('\'),
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Pinned directory handle for '$expectedFullPath' resolves to '$finalPath'."
    }
    return [ordered]@{
        path = $expectedFullPath
        volume_serial_number = [uint32]$information.VolumeSerialNumber
        file_index_high = [uint32]$information.FileIndexHigh
        file_index_low = [uint32]$information.FileIndexLow
    }
}

function Open-PinnedOutputDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    Ensure-WindowsNativeTypes
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $item = Get-Item -LiteralPath $fullPath -Force -ErrorAction Stop
    if (-not $item.PSIsContainer) { throw "Pinned output-chain path is not a directory: '$fullPath'." }
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Pinned output-chain path is a reparse point: '$fullPath'."
    }

    # DELETE access makes rename/delete a sharing-checked operation for this
    # handle; deliberately omitting FILE_SHARE_DELETE then blocks replacement.
    # A READ_ATTRIBUTES-only handle is insufficient: Windows may authorize a
    # rename via DELETE_CHILD on the parent, and the cross-process regression
    # below proved that such a handle allowed rename-then-junction substitution.
    $fileReadAttributes = 0x00000080
    $deleteAccess = 0x00010000
    $fileShareReadWrite = 0x00000003
    $openExisting = 3
    $fileFlagBackupSemantics = 0x02000000
    $handle = [OxForms.OfficeOracle.NativeMethods]::CreateFileW(
        $fullPath,
        ($fileReadAttributes -bor $deleteAccess),
        $fileShareReadWrite,
        [System.IntPtr]::Zero,
        $openExisting,
        $fileFlagBackupSemantics,
        [System.IntPtr]::Zero
    )
    if ($null -eq $handle -or $handle.IsInvalid) {
        if ($null -ne $handle) { $handle.Dispose() }
        throw [System.ComponentModel.Win32Exception]::new(
            [Runtime.InteropServices.Marshal]::GetLastWin32Error(),
            "Could not pin output directory '$fullPath' with no-delete sharing."
        )
    }
    try {
        $identity = Get-PinnedDirectoryObservation -Handle $handle -ExpectedPath $fullPath
        $item = Get-Item -LiteralPath $fullPath -Force -ErrorAction Stop
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Pinned output-chain path became a reparse point: '$fullPath'."
        }
        return [pscustomobject][ordered]@{
            path = [string]$identity.path
            volume_serial_number = [uint32]$identity.volume_serial_number
            file_index_high = [uint32]$identity.file_index_high
            file_index_low = [uint32]$identity.file_index_low
            handle = $handle
        }
    } catch {
        $handle.Dispose()
        throw
    }
}

function Assert-PinnedOutputDirectory {
    param([Parameter(Mandatory = $true)][string]$Directory)

    if (-not (Test-RunningOnWindows)) { return }
    $fullDirectory = [System.IO.Path]::GetFullPath($Directory)
    $matched = $false
    foreach ($pin in @($Script:PinnedOutputDirectories)) {
        $observed = Get-PinnedDirectoryObservation -Handle $pin.handle -ExpectedPath $pin.path
        if ([uint32]$observed.volume_serial_number -ne [uint32]$pin.volume_serial_number -or
            [uint32]$observed.file_index_high -ne [uint32]$pin.file_index_high -or
            [uint32]$observed.file_index_low -ne [uint32]$pin.file_index_low) {
            throw "Pinned output directory identity changed for '$($pin.path)'."
        }
        if ([string]$pin.path -ieq $fullDirectory) { $matched = $true }
    }
    if (-not $matched) { throw "Output directory is not held by the validated no-delete handle chain: '$fullDirectory'." }
}

function Add-PinnedOutputDirectoryChain {
    param([Parameter(Mandatory = $true)][string]$Directory)

    if (-not (Test-RunningOnWindows)) { return }
    if ($null -eq $Script:PinnedOutputDirectories) {
        $Script:PinnedOutputDirectories = [System.Collections.Generic.List[object]]::new()
    }
    $pinRoot = [System.IO.Path]::GetFullPath($Script:EvidenceRoot).TrimEnd('\')
    $fullDirectory = [System.IO.Path]::GetFullPath($Directory)
    $pinPrefix = $pinRoot + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullDirectory.Equals($pinRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
        -not $fullDirectory.StartsWith($pinPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Output directory '$fullDirectory' is outside the pinned evidence root '$pinRoot'."
    }
    $relative = [System.IO.Path]::GetRelativePath($pinRoot, $fullDirectory)
    $segments = @($relative -split '[\\/]' | Where-Object Length -gt 0)
    if ($segments -contains '..') { throw "Pinned output directory contains traversal: '$fullDirectory'." }

    $cursor = $pinRoot
    foreach ($segment in @('') + $segments) {
        if (-not [string]::IsNullOrEmpty([string]$segment)) {
            $cursor = [System.IO.Path]::Combine($cursor, [string]$segment)
        }
        $existingPin = @($Script:PinnedOutputDirectories | Where-Object {
            ([string]$_.path).Equals($cursor, [System.StringComparison]::OrdinalIgnoreCase)
        } | Select-Object -First 1)
        if ($existingPin.Count -eq 1) {
            Assert-PinnedOutputDirectory -Directory $cursor
            continue
        }
        if (-not [System.IO.Directory]::Exists($cursor)) {
            [void][System.IO.Directory]::CreateDirectory($cursor)
        }
        $pin = Open-PinnedOutputDirectory -Path $cursor
        $Script:PinnedOutputDirectories.Add($pin)
    }
    Assert-PinnedOutputDirectory -Directory $fullDirectory
}

function Close-PinnedOutputDirectories {
    if ($null -eq $Script:PinnedOutputDirectories) { return }
    for ($index = $Script:PinnedOutputDirectories.Count - 1; $index -ge 0; $index--) {
        $Script:PinnedOutputDirectories[$index].handle.Dispose()
    }
    $Script:PinnedOutputDirectories.Clear()
}

function Get-WindowTextValue {
    param([System.IntPtr]$Handle)

    $length = [OxForms.OfficeOracle.NativeMethods]::GetWindowTextLengthW($Handle)
    $capacity = [Math]::Max($length + 1, 256)
    $builder = [System.Text.StringBuilder]::new($capacity)
    [void][OxForms.OfficeOracle.NativeMethods]::GetWindowTextW($Handle, $builder, $builder.Capacity)
    return $builder.ToString()
}

function Get-ClassNameValue {
    param([System.IntPtr]$Handle)

    $builder = [System.Text.StringBuilder]::new(256)
    [void][OxForms.OfficeOracle.NativeMethods]::GetClassNameW($Handle, $builder, $builder.Capacity)
    return $builder.ToString()
}

function Get-WindowDpi {
    param([System.IntPtr]$Handle)

    try {
        $dpi = [OxForms.OfficeOracle.NativeMethods]::GetDpiForWindow($Handle)
        if ($dpi -gt 0) {
            return [int]$dpi
        }
    }
    catch {
        return $null
    }

    return $null
}

function Get-TopLevelWindows {
    Ensure-WindowsNativeTypes
    $windows = [System.Collections.Generic.List[object]]::new()

    $callback = [OxForms.OfficeOracle.NativeMethods+EnumWindowsProc]{
        param([System.IntPtr]$Handle, [System.IntPtr]$Param)

        if (-not [OxForms.OfficeOracle.NativeMethods]::IsWindowVisible($Handle)) {
            return $true
        }

        $title = Get-WindowTextValue -Handle $Handle
        if ([string]::IsNullOrWhiteSpace($title)) {
            return $true
        }

        $class = Get-ClassNameValue -Handle $Handle
        $processIdValue = [uint32]0
        [void][OxForms.OfficeOracle.NativeMethods]::GetWindowThreadProcessId($Handle, [ref]$processIdValue)

        $processName = $null
        $processPath = $null
        $processStartTimeUtc = $null
        $process = $null
        try {
            $process = Get-Process -Id ([int]$processIdValue) -ErrorAction Stop
            $processName = $process.ProcessName
            try {
                $processPath = $process.Path
            }
            catch {
                $processPath = $null
            }
            try {
                $processStartTimeUtc = [OxForms.OfficeOracle.NativeMethods]::GetProcessStartTimeUtc($process.Handle)
            }
            catch {
                $processStartTimeUtc = $null
            }
        }
        catch {
            $processName = $null
        }
        finally {
            if ($null -ne $process) { $process.Dispose() }
        }

        $rect = New-Object OxForms.OfficeOracle.NativeMethods+RECT
        $hasRect = [OxForms.OfficeOracle.NativeMethods]::GetWindowRect($Handle, [ref]$rect)
        $bounds = $null
        if ($hasRect) {
            $bounds = [ordered]@{
                left = $rect.Left
                top = $rect.Top
                right = $rect.Right
                bottom = $rect.Bottom
                width = [Math]::Max(0, $rect.Right - $rect.Left)
                height = [Math]::Max(0, $rect.Bottom - $rect.Top)
            }
        }

        $windows.Add([ordered]@{
            handle = ('0x{0:X}' -f $Handle.ToInt64())
            title = $title
            class_name = $class
            process_id = [int]$processIdValue
            process_name = $processName
            process_path = $processPath
            process_start_time_utc = $processStartTimeUtc
            bounds = $bounds
            dpi = (Get-WindowDpi -Handle $Handle)
        }) | Out-Null

        return $true
    }

    [void][OxForms.OfficeOracle.NativeMethods]::EnumWindows($callback, [System.IntPtr]::Zero)
    return @($windows)
}

function Test-WindowMatchesQuery {
    param(
        [object]$Window,
        [hashtable]$Query
    )

    $comparison = [System.StringComparison]::OrdinalIgnoreCase

    if ($Query.process_id -gt 0 -and $Window.process_id -ne $Query.process_id) {
        return $false
    }

    if (-not [string]::IsNullOrWhiteSpace($Query.title_contains)) {
        if ($Window.title.IndexOf($Query.title_contains, $comparison) -lt 0) {
            return $false
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Query.class_name)) {
        if (-not [string]::Equals($Window.class_name, $Query.class_name, $comparison)) {
            return $false
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Query.process_name)) {
        if (-not [string]::Equals($Window.process_name, $Query.process_name, $comparison)) {
            return $false
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Query.process_contains)) {
        $haystack = "$($Window.process_name) $($Window.process_path)"
        if ($haystack.IndexOf($Query.process_contains, $comparison) -lt 0) {
            return $false
        }
    }

    return $true
}

function New-CandidateSummary {
    param([object]$Window)

    [ordered]@{
        handle = $Window.handle
        title = $Window.title
        class_name = $Window.class_name
        process_id = $Window.process_id
        process_name = $Window.process_name
        bounds = $Window.bounds
    }
}

function Get-CurrentWindowCaptureState {
    param(
        [Parameter(Mandatory = $true)]
        [System.IntPtr]$Handle
    )

    if (-not [OxForms.OfficeOracle.NativeMethods]::IsWindow($Handle)) {
        throw "Selected HWND '0x$($Handle.ToInt64().ToString('X'))' is no longer a window."
    }

    $visible = [bool][OxForms.OfficeOracle.NativeMethods]::IsWindowVisible($Handle)
    $foreground = ([OxForms.OfficeOracle.NativeMethods]::GetForegroundWindow() -eq $Handle)
    $title = Get-WindowTextValue -Handle $Handle
    $className = Get-ClassNameValue -Handle $Handle
    $currentProcessId = [uint32]0
    $threadId = [OxForms.OfficeOracle.NativeMethods]::GetWindowThreadProcessId($Handle, [ref]$currentProcessId)
    if ($threadId -eq 0 -or $currentProcessId -eq 0) {
        throw "Could not re-read the process identity for selected HWND '0x$($Handle.ToInt64().ToString('X'))'."
    }

    $process = Get-Process -Id ([int]$currentProcessId) -ErrorAction Stop
    try {
        $currentProcessName = [string]$process.ProcessName
        $currentStartTimeUtc = [OxForms.OfficeOracle.NativeMethods]::GetProcessStartTimeUtc($process.Handle)
        $currentProcessPath = [System.IO.Path]::GetFullPath([string]$process.Path)
    }
    finally {
        $process.Dispose()
    }
    $rect = New-Object OxForms.OfficeOracle.NativeMethods+RECT
    if (-not [OxForms.OfficeOracle.NativeMethods]::GetWindowRect($Handle, [ref]$rect)) {
        throw "Could not re-read bounds for selected HWND '0x$($Handle.ToInt64().ToString('X'))'."
    }
    $currentBounds = [ordered]@{
        left = [int]$rect.Left
        top = [int]$rect.Top
        right = [int]$rect.Right
        bottom = [int]$rect.Bottom
        width = [Math]::Max(0, [int]$rect.Right - [int]$rect.Left)
        height = [Math]::Max(0, [int]$rect.Bottom - [int]$rect.Top)
    }
    if ($currentBounds.width -le 0 -or $currentBounds.height -le 0) {
        throw "Selected HWND '0x$($Handle.ToInt64().ToString('X'))' has empty capture bounds."
    }

    return [ordered]@{
        handle = ('0x{0:X}' -f $Handle.ToInt64())
        title = $title
        class_name = $className
        process_id = [int]$currentProcessId
        process_name = $currentProcessName
        process_start_time_utc = $currentStartTimeUtc
        process_path = $currentProcessPath
        bounds = $currentBounds
        visible = $visible
        foreground = $foreground
    }
}

function Assert-ExactSelectedWindowState {
    param(
        [Parameter(Mandatory = $true)][object]$Selected,
        [Parameter(Mandatory = $true)][object]$Current,
        [Parameter(Mandatory = $true)][string]$Phase
    )

    foreach ($required in @('handle', 'title', 'class_name', 'process_name', 'process_start_time_utc', 'process_path')) {
        if ([string]::IsNullOrWhiteSpace([string]$Selected.$required)) {
            throw "Selected window metadata lacks '$required' required for $Phase revalidation."
        }
    }
    foreach ($required in @('bounds')) {
        if ($null -eq $Selected.$required) { throw "Selected window metadata lacks '$required' required for $Phase revalidation." }
    }

    foreach ($name in @('handle', 'title', 'class_name', 'process_start_time_utc')) {
        if (-not [string]::Equals([string]$Current.$name, [string]$Selected.$name, [System.StringComparison]::Ordinal)) {
            throw "Selected HWND '$($Selected.handle)' changed '$name' during $Phase revalidation."
        }
    }
    if ([int64]$Current.process_id -ne [int64]$Selected.process_id) {
        throw "Selected HWND '$($Selected.handle)' changed process id during $Phase revalidation."
    }
    if (-not [string]::Equals([string]$Current.process_name, [string]$Selected.process_name, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Selected HWND '$($Selected.handle)' changed process name during $Phase revalidation."
    }
    $selectedProcessPath = [System.IO.Path]::GetFullPath([string]$Selected.process_path)
    $currentProcessPath = [System.IO.Path]::GetFullPath([string]$Current.process_path)
    if (-not $currentProcessPath.Equals($selectedProcessPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Selected HWND '$($Selected.handle)' changed executable path during $Phase revalidation."
    }
    foreach ($name in @('left', 'top', 'right', 'bottom', 'width', 'height')) {
        if ([int64]$Current.bounds[$name] -ne [int64]$Selected.bounds.$name) {
            throw "Selected HWND '$($Selected.handle)' changed bounds field '$name' during $Phase revalidation."
        }
    }
    if (-not [bool]$Current.visible) { throw "Selected HWND '$($Selected.handle)' is not visible during $Phase revalidation." }
    if (-not [bool]$Current.foreground) { throw "Selected HWND '$($Selected.handle)' is not foreground during $Phase revalidation." }
}

function Get-RevalidatedWindowCaptureState {
    param(
        [Parameter(Mandatory = $true)][object]$Window,
        [Parameter(Mandatory = $true)][System.IntPtr]$Handle,
        [Parameter(Mandatory = $true)][string]$Phase
    )

    $current = Get-CurrentWindowCaptureState -Handle $Handle
    Assert-ExactSelectedWindowState -Selected $Window -Current $current -Phase $Phase
    return $current
}

function Set-WindowForegroundForCapture {
    param(
        [Parameter(Mandatory = $true)]
        [System.IntPtr]$Handle,
        [int]$MaxAttempts = 4,
        [int]$RetryDelayMilliseconds = 100
    )

    if ($MaxAttempts -lt 1) { $MaxAttempts = 1 }
    if ($RetryDelayMilliseconds -lt 0) { $RetryDelayMilliseconds = 0 }

    $hwndTopMost = [System.IntPtr]::new(-1)
    $swpNoMove = 0x0002
    $swpNoSize = 0x0001
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        [void][OxForms.OfficeOracle.NativeMethods]::ShowWindow($Handle, 5)
        [void][OxForms.OfficeOracle.NativeMethods]::SetWindowPos($Handle, $hwndTopMost, 0, 0, 0, 0, ($swpNoMove -bor $swpNoSize))
        [void][OxForms.OfficeOracle.NativeMethods]::SetForegroundWindow($Handle)

        if ([OxForms.OfficeOracle.NativeMethods]::GetForegroundWindow() -eq $Handle) {
            return $attempt
        }
        if ($attempt -lt $MaxAttempts) {
            Start-Sleep -Milliseconds $RetryDelayMilliseconds
        }
    }

    throw "Selected HWND '0x$($Handle.ToInt64().ToString('X'))' did not become the foreground window after $MaxAttempts attempt(s)."
}

function Save-WindowScreenshot {
    param(
        [object]$Window,
        [string]$Directory,
        [int]$MaxAttempts = 4,
        [int]$RetryDelayMilliseconds = 250
    )

    if ($null -eq $Window.bounds -or $Window.bounds.width -le 0 -or $Window.bounds.height -le 0) {
        throw 'Selected window has empty or unavailable bounds.'
    }
    Assert-PinnedOutputDirectory -Directory $Directory

    if ($MaxAttempts -lt 1) {
        $MaxAttempts = 1
    }

    Add-Type -AssemblyName System.Drawing

    $handleValue = [System.IntPtr]::new([Convert]::ToInt64($Window.handle.Substring(2), 16))
    $hwndNoTopMost = [System.IntPtr]::new(-2)
    $swpNoMove = 0x0002
    $swpNoSize = 0x0001

    $imagePath = Join-Path $Directory 'window-capture.png'
    $width = 0
    $height = 0

    # CopyFromScreen can throw a transient 'The handle is invalid' Win32 GDI error
    # while the just-raised window is still settling under focus/composition churn.
    # Re-assert foreground + topmost and retry a bounded number of times, recording
    # each attempt, so a flake becomes a deterministic retry rather than a failed
    # capture -- and a persistent failure still surfaces a precise error.
    $attempts = [System.Collections.Generic.List[object]]::new()
    $captured = $false
    $lastError = $null
    $captureStateBracket = $null

    try {
        for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
            # Construct bitmap/graphics inside the try so a partial construction
            # (e.g. Graphics.FromImage throwing) is recorded, retried, and disposed
            # like any other attempt instead of escaping the retry loop and leaking.
            $bitmap = $null
            $graphics = $null
            try {
                $foregroundAttempt = Set-WindowForegroundForCapture -Handle $handleValue
                Start-Sleep -Milliseconds 100

                $width = [int]$Window.bounds.width
                $height = [int]$Window.bounds.height
                $bitmap = [System.Drawing.Bitmap]::new($width, $height)
                $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

                # Rebind the selected HWND to the original PID/start/path and
                # require stable bounds immediately before the screen read. A
                # recycled HWND/PID, moved window, or stolen foreground fails
                # closed rather than producing evidence for a different target.
                $captureStateBefore = Get-RevalidatedWindowCaptureState `
                    -Window $Window `
                    -Handle $handleValue `
                    -Phase 'immediately-before-CopyFromScreen'
                $graphics.CopyFromScreen([int]$captureStateBefore.bounds.left, [int]$captureStateBefore.bounds.top, 0, 0, $bitmap.Size)
                $captureStateAfter = Get-RevalidatedWindowCaptureState `
                    -Window $Window `
                    -Handle $handleValue `
                    -Phase 'immediately-after-CopyFromScreen'
                $captureStateBracket = [ordered]@{
                    comparator = 'exact_selected_current_v1'
                    before = $captureStateBefore
                    after = $captureStateAfter
                }
                Assert-PinnedOutputDirectory -Directory $Directory
                $bitmap.Save($imagePath, [System.Drawing.Imaging.ImageFormat]::Png)
                Assert-PinnedOutputDirectory -Directory $Directory
                $captured = $true
                $attempts.Add([ordered]@{ attempt = $attempt; status = 'ok'; foreground_attempt = $foregroundAttempt }) | Out-Null
            }
            catch {
                $lastError = $_.Exception.Message
                $attempts.Add([ordered]@{ attempt = $attempt; status = 'error'; message = $lastError }) | Out-Null
            }
            finally {
                if ($null -ne $graphics) { $graphics.Dispose() }
                if ($null -ne $bitmap) { $bitmap.Dispose() }
            }

            if ($captured) {
                break
            }

            if ($attempt -lt $MaxAttempts) {
                Start-Sleep -Milliseconds $RetryDelayMilliseconds
            }
        }
    }
    finally {
        [void][OxForms.OfficeOracle.NativeMethods]::SetWindowPos($handleValue, $hwndNoTopMost, 0, 0, 0, 0, ($swpNoMove -bor $swpNoSize))
    }

    if (-not $captured) {
        if (Test-Path -LiteralPath $imagePath -PathType Leaf) {
            Remove-Item -LiteralPath $imagePath -Force -ErrorAction SilentlyContinue
        }
        $detail = if ([string]::IsNullOrWhiteSpace($lastError)) { 'unknown error' } else { $lastError }
        throw "Window screenshot capture failed after $MaxAttempts attempt(s): $detail"
    }

    Assert-PinnedOutputDirectory -Directory $Directory
    $imageHash = Get-Sha256Hex -Path $imagePath
    Assert-PinnedOutputDirectory -Directory $Directory
    [ordered]@{
        path = (Resolve-Path -LiteralPath $imagePath).Path
        sha256 = $imageHash
        width = $width
        height = $height
        format = 'png'
        capture_method = 'screen_coordinates'
        visual_review_required = $true
        state_bracket = $captureStateBracket
        attempts = @($attempts)
    }
}

function Invoke-WindowCapture {
    param(
        [hashtable]$Query,
        [string]$Directory,
        [bool]$ShouldCaptureScreenshot,
        [bool]$ShouldAllowAmbiguous,
        [string]$Mode = 'capture'
    )

    $result = New-Result -Mode $Mode -Query $Query
    $resolvedOutDir = $null

    if (-not (Test-RunningOnWindows)) {
        $result.status = 'unsupported'
        $result.diagnostics += New-Diagnostic -Code 'unsupported_platform' -Severity 'info' -Message 'Window discovery and screenshot capture require Windows desktop APIs.'
        return $result
    }

    if ([string]::IsNullOrWhiteSpace($Query.title_contains) -and
        [string]::IsNullOrWhiteSpace($Query.class_name) -and
        [string]::IsNullOrWhiteSpace($Query.process_name) -and
        [string]::IsNullOrWhiteSpace($Query.process_contains) -and
        $Query.process_id -le 0) {
        $result.diagnostics += New-Diagnostic -Code 'invalid_query' -Message 'At least one of -TitleContains, -ProcessName, -ProcessContains, -ProcessId, or -ClassName is required.'
        return $result
    }

    if ($ShouldCaptureScreenshot -and [string]::IsNullOrWhiteSpace($Directory)) {
        $result.diagnostics += New-Diagnostic -Code 'invalid_output_path' -Message 'CaptureScreenshot requires -OutDir so the image can be written under a documented workset capture evidence path.'
        return $result
    }

    if (-not [string]::IsNullOrWhiteSpace($Directory)) {
        try {
            $resolvedOutDir = Resolve-CaptureOutDir -Directory $Directory
        }
        catch {
            $result.diagnostics += New-Diagnostic -Code 'invalid_output_path' -Message $_.Exception.Message
            return $result
        }
    }

    try {
        $windows = Get-TopLevelWindows
        $result.visible_top_level_window_count = $windows.Count
        $matches = @($windows | Where-Object { Test-WindowMatchesQuery -Window $_ -Query $Query })
        $result.match_count = $matches.Count
        $result.candidates = @($matches | Select-Object -First 12 | ForEach-Object { New-CandidateSummary -Window $_ })

        if ($matches.Count -eq 0) {
            $result.diagnostics += New-Diagnostic -Code 'no_matching_window' -Message 'No visible top-level window matched the supplied title/process/class filters.'
            Write-Manifest -Result $result -Directory $resolvedOutDir -FileName 'window-capture-manifest.json'
            return $result
        }

        if ($matches.Count -gt 1 -and -not $ShouldAllowAmbiguous) {
            $result.diagnostics += New-Diagnostic -Code 'ambiguous_target' -Message "The query matched $($matches.Count) windows. Add another filter or pass -AllowAmbiguous to select the first match."
            Write-Manifest -Result $result -Directory $resolvedOutDir -FileName 'window-capture-manifest.json'
            return $result
        }

        $selected = $matches[0]
        $result.selected_window = $selected

        if ($ShouldCaptureScreenshot) {
            try {
                $result.screenshot = Save-WindowScreenshot -Window $selected -Directory $resolvedOutDir -MaxAttempts $ScreenshotMaxAttempts -RetryDelayMilliseconds $ScreenshotRetryDelayMilliseconds
            }
            catch {
                $result.diagnostics += New-Diagnostic -Code 'screenshot_failure' -Message $_.Exception.Message
                Write-Manifest -Result $result -Directory $resolvedOutDir -FileName 'window-capture-manifest.json'
                return $result
            }
        }

        $result.status = 'ok'
        if (-not $ShouldCaptureScreenshot) {
            $result.diagnostics += New-Diagnostic -Code 'metadata_only' -Severity 'info' -Message 'Window metadata was captured without a screenshot because -CaptureScreenshot was not supplied.'
        }
        Write-Manifest -Result $result -Directory $resolvedOutDir -FileName 'window-capture-manifest.json'
        return $result
    }
    catch {
        $result.diagnostics += New-Diagnostic -Code 'window_discovery_failure' -Message $_.Exception.Message
        Write-Manifest -Result $result -Directory $resolvedOutDir -FileName 'window-capture-manifest.json'
        return $result
    }
}

function Invoke-SelfTest {
    param([string]$Directory)

    if ([string]::IsNullOrWhiteSpace($Directory)) {
        $Directory = 'docs\evidence\W003_excel_forms_oracle_capture\captures\self-test'
    }

    $query = @{
        title_contains = $null
        process_name = $null
        process_contains = $null
        process_id = 0
        class_name = $null
    }
    $result = New-Result -Mode 'self-test' -Query $query
    $resolvedOutDir = $null

    try {
        $resolvedOutDir = Resolve-CaptureOutDir -Directory $Directory
    }
    catch {
        $result.diagnostics += New-Diagnostic -Code 'invalid_output_path' -Message $_.Exception.Message
        return $result
    }

    if (-not (Test-RunningOnWindows)) {
        $result.status = 'unsupported'
        $result.diagnostics += New-Diagnostic -Code 'unsupported_platform' -Severity 'info' -Message 'Self-test reports unsupported because this host is not Windows.'
        Write-Manifest -Result $result -Directory $resolvedOutDir -FileName 'self-test-manifest.json'
        return $result
    }

    $noTargetTitle = "OxForms Office Oracle Intentional No Target $PID"
    $noTarget = Invoke-WindowCapture -Mode 'self-test-no-target' -Query @{
        title_contains = $noTargetTitle
        process_name = $null
        process_contains = $null
        process_id = 0
        class_name = $null
    } -Directory (Join-Path $resolvedOutDir 'no-target') -ShouldCaptureScreenshot $false -ShouldAllowAmbiguous $false

    $sample = $null
    $form = $null
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $sampleTitle = "OxForms Office Oracle Capture Self Test $PID"
        $form = [System.Windows.Forms.Form]::new()
        $form.Text = $sampleTitle
        $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
        $form.Location = [System.Drawing.Point]::new(80, 80)
        $form.Size = [System.Drawing.Size]::new(260, 170)
        $form.BackColor = [System.Drawing.Color]::White
        $form.TopMost = $true

        $panel = [System.Windows.Forms.Panel]::new()
        $panel.Location = [System.Drawing.Point]::new(48, 42)
        $panel.Size = [System.Drawing.Size]::new(140, 60)
        $panel.BackColor = [System.Drawing.Color]::FromArgb(32, 96, 168)
        $form.Controls.Add($panel)

        $form.Show()
        $form.Activate()
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 300

        $sample = Invoke-WindowCapture -Mode 'self-test-sample' -Query @{
            title_contains = $sampleTitle
            process_name = (Get-Process -Id $PID).ProcessName
            process_contains = $null
            process_id = $PID
            class_name = $null
        } -Directory (Join-Path $resolvedOutDir 'sample') -ShouldCaptureScreenshot $true -ShouldAllowAmbiguous $false
    }
    catch {
        $sample = New-Result -Mode 'self-test-sample' -Query @{
            title_contains = 'OxForms Office Oracle Capture Self Test'
            process_name = (Get-Process -Id $PID).ProcessName
            process_contains = $null
            process_id = $PID
            class_name = $null
        }
        $sample.diagnostics += New-Diagnostic -Code 'self_test_window_failure' -Message $_.Exception.Message
    }
    finally {
        if ($null -ne $form) {
            $form.Close()
            $form.Dispose()
        }
    }

    $noTargetWasExpected = ($noTarget.status -eq 'failed' -and @($noTarget.diagnostics | Where-Object { $_.code -eq 'no_matching_window' }).Count -gt 0)
    $sampleSucceeded = ($null -ne $sample -and $sample.status -eq 'ok' -and $null -ne $sample.screenshot)

    $result.self_test = [ordered]@{
        no_target_expected_failure = $noTargetWasExpected
        sample_window_capture = $sampleSucceeded
        no_target = $noTarget
        sample = $sample
    }

    if ($noTargetWasExpected -and $sampleSucceeded) {
        $result.status = 'ok'
        $result.diagnostics += New-Diagnostic -Code 'self_test_ok' -Severity 'info' -Message 'Self-test observed the expected no-target diagnostic and captured the native sample window.'
    }
    else {
        $result.diagnostics += New-Diagnostic -Code 'self_test_failure' -Message 'Self-test did not complete both the expected no-target diagnostic and sample-window screenshot capture.'
    }

    Write-Manifest -Result $result -Directory $resolvedOutDir -FileName 'self-test-manifest.json'
    return $result
}

if ([string]::IsNullOrWhiteSpace($PSCommandPath)) {
    throw 'Capture-Window.ps1 must execute from a file so its SHA-256 identity can be validated.'
}
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    # Backward-compatible direct use from the repository source path. Capture
    # snapshots must pass -RepoRoot explicitly because their own directory is
    # intentionally below an evidence staging tree.
    $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
}
if ([string]::IsNullOrWhiteSpace($ExpectedScriptSha256)) {
    # Direct legacy callers get an integrity check against the exact source
    # path they invoked. The W010 capture runner supplies an independent digest
    # pin for its capture-local snapshot.
    $ExpectedScriptSha256 = Get-Sha256Hex -Path $PSCommandPath
}
Initialize-CaptureContext -Root $RepoRoot -ExpectedHash $ExpectedScriptSha256 -ScriptPath $PSCommandPath

$query = @{
    title_contains = $TitleContains
    process_name = $ProcessName
    process_contains = $ProcessContains
    process_id = $ProcessId
    class_name = $ClassName
}

$exitCode = 1
try {
    if ($SelfTest) {
        $captureResult = Invoke-SelfTest -Directory $OutDir
    }
    else {
        $captureResult = Invoke-WindowCapture -Query $query -Directory $OutDir -ShouldCaptureScreenshot ([bool]$CaptureScreenshot) -ShouldAllowAmbiguous ([bool]$AllowAmbiguous)
    }

    ConvertTo-JsonText -Value $captureResult
    if ($captureResult.status -eq 'ok' -or $captureResult.status -eq 'unsupported') {
        $exitCode = 0
    }
}
finally {
    Close-PinnedOutputDirectories
}

exit $exitCode
