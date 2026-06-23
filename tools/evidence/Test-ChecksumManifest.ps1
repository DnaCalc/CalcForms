[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Directory,

    [string]$ChecksumFile = 'checksums.sha256',

    [switch]$GitTrackedOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

function Resolve-RepoPath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        $fullPath = [System.IO.Path]::GetFullPath($Path)
    } else {
        $fullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
    }

    $repoWithSeparator = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not ($fullPath.Equals($repoRoot, [System.StringComparison]::OrdinalIgnoreCase) -or $fullPath.StartsWith($repoWithSeparator, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Path '$Path' resolves outside repository root '$repoRoot'."
    }

    return $fullPath
}

function ConvertTo-ForwardSlashRelative {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    $rootWithSeparator = $rootFull + [System.IO.Path]::DirectorySeparatorChar
    if (-not $pathFull.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path '$Path' is not under '$Root'."
    }

    return $pathFull.Substring($rootWithSeparator.Length).Replace([System.IO.Path]::DirectorySeparatorChar, '/').Replace([System.IO.Path]::AltDirectorySeparatorChar, '/')
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

# Validate that an entry path is a safe relative path (forward slashes, no
# absolute/rooted prefix, no empty/./.. segments) and return its local form.
function Assert-SafeRelativePath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        throw 'Checksum entry path is empty.'
    }
    if ($RelativePath -match '\\') {
        throw "Checksum entry must use forward slashes, got: $RelativePath"
    }
    if ($RelativePath -match '^[A-Za-z]:|^/|^//') {
        throw "Checksum entry must be relative, got: $RelativePath"
    }

    $parts = $RelativePath -split '/'
    if ($parts | Where-Object { $_ -eq '' -or $_ -eq '.' -or $_ -eq '..' }) {
        throw "Checksum entry contains an invalid path segment: $RelativePath"
    }

    return $RelativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
}

# Resolve an entry under the evidence directory (the canonical convention).
function Resolve-DirectoryEntry {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Directory
    )

    $localPath = Assert-SafeRelativePath -RelativePath $RelativePath
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $Directory $localPath))
    $directoryWithSeparator = $Directory.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($directoryWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Checksum entry escapes the evidence directory: $RelativePath"
    }

    return $fullPath
}

# Resolve an entry from the repository root (legacy convention used by early
# capture manifests that also pin a shared upstream fixture outside their own
# directory). Repo-root containment is still enforced by Resolve-RepoPath.
function Resolve-RepoRootEntry {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    [void](Assert-SafeRelativePath -RelativePath $RelativePath)
    return Resolve-RepoPath -Path $RelativePath
}

$resolvedDirectory = Resolve-RepoPath $Directory
if (-not (Test-Path -LiteralPath $resolvedDirectory -PathType Container)) {
    throw "Evidence directory not found: $resolvedDirectory"
}

$checksumPath = Resolve-DirectoryEntry -RelativePath $ChecksumFile -Directory $resolvedDirectory
if (-not (Test-Path -LiteralPath $checksumPath -PathType Leaf)) {
    throw "Checksum file not found: $checksumPath"
}

$lines = @(Get-Content -LiteralPath $checksumPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if ($lines.Count -eq 0) {
    throw "Checksum file is empty: $checksumPath"
}

# First pass: parse entries and decide the manifest's path convention. An entry
# is "directory-relative" if it resolves to an existing file under the evidence
# directory, otherwise "repo-root-relative". A manifest must use one convention
# consistently; this avoids a missing directory-relative file silently matching a
# same-named file at the repository root.
$parsed = [System.Collections.Generic.List[object]]::new()
$seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$directoryConventionCount = 0
$repoRootConventionCount = 0

foreach ($line in $lines) {
    if ($line -notmatch '^([0-9a-f]{64})\s\s(.+)$') {
        throw "Malformed checksum line: $line"
    }

    $expectedHash = $Matches[1]
    $relativePath = $Matches[2]
    if (-not $seen.Add($relativePath)) {
        throw "Duplicate checksum entry: $relativePath"
    }

    [void](Assert-SafeRelativePath -RelativePath $relativePath)

    $directoryCandidate = [System.IO.Path]::GetFullPath((Join-Path $resolvedDirectory ($relativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar))))
    if (Test-Path -LiteralPath $directoryCandidate -PathType Leaf) {
        $convention = 'directory'
        $directoryConventionCount++
    } else {
        $convention = 'repo-root'
        $repoRootConventionCount++
    }

    $parsed.Add([pscustomobject]@{
            RelativePath = $relativePath
            ExpectedHash = $expectedHash
            Convention   = $convention
        })
}

if ($directoryConventionCount -gt 0 -and $repoRootConventionCount -gt 0) {
    throw "Checksum manifest mixes directory-relative and repo-root-relative entries: $checksumPath. Use one convention."
}
$convention = if ($repoRootConventionCount -gt 0) { 'repo-root' } else { 'directory' }

# Second pass: resolve, verify existence, and verify hashes.
$entryFullPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($entry in $parsed) {
    if ($convention -eq 'repo-root') {
        $entryPath = Resolve-RepoRootEntry -RelativePath $entry.RelativePath
    } else {
        $entryPath = Resolve-DirectoryEntry -RelativePath $entry.RelativePath -Directory $resolvedDirectory
    }

    if (-not (Test-Path -LiteralPath $entryPath -PathType Leaf)) {
        throw "Checksum entry file does not exist: $($entry.RelativePath)"
    }

    $actualHash = Get-Sha256Hex -Path $entryPath
    if ($actualHash -ne $entry.ExpectedHash) {
        throw "Checksum mismatch for '$($entry.RelativePath)': expected $($entry.ExpectedHash), got $actualHash"
    }

    [void]$entryFullPaths.Add($entryPath)
}

# Coverage: every file present under the evidence directory must be covered.
# Entries that point outside the directory (a shared upstream fixture in repo-root
# mode) are allowed and are not required to live under the directory.
if ($GitTrackedOnly) {
    $repoRelativeDirectory = ConvertTo-ForwardSlashRelative -Root $repoRoot -Path $resolvedDirectory
    $trackedFiles = @(git -C $repoRoot ls-files -- $repoRelativeDirectory)
    if ($LASTEXITCODE -ne 0) {
        throw "git ls-files failed for $repoRelativeDirectory"
    }
    $directoryFiles = @(
        foreach ($path in $trackedFiles) {
            [System.IO.Path]::GetFullPath((Join-Path $repoRoot ($path.Replace('/', [System.IO.Path]::DirectorySeparatorChar))))
        }
    )
} else {
    $directoryFiles = @(
        Get-ChildItem -LiteralPath $resolvedDirectory -Recurse -File | ForEach-Object { $_.FullName }
    )
}

$directorySet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($path in $directoryFiles) {
    if (-not $path.Equals($checksumPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        [void]$directorySet.Add($path)
    }
}

$directoryWithSeparator = $resolvedDirectory.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

$missing = @($directorySet | Where-Object { -not $entryFullPaths.Contains($_) } | ForEach-Object { ConvertTo-ForwardSlashRelative -Root $resolvedDirectory -Path $_ } | Sort-Object)
$extra = @(
    $entryFullPaths |
        Where-Object { $_.StartsWith($directoryWithSeparator, [System.StringComparison]::OrdinalIgnoreCase) -and -not $directorySet.Contains($_) } |
        ForEach-Object { ConvertTo-ForwardSlashRelative -Root $resolvedDirectory -Path $_ } |
        Sort-Object
)

if ($missing.Count -gt 0 -or $extra.Count -gt 0) {
    $message = "Checksum coverage mismatch for $resolvedDirectory."
    if ($missing.Count -gt 0) {
        $message += " Missing: $($missing -join ', ')."
    }
    if ($extra.Count -gt 0) {
        $message += " Extra: $($extra -join ', ')."
    }
    throw $message
}

$externalCount = @($entryFullPaths | Where-Object { -not $_.StartsWith($directoryWithSeparator, [System.StringComparison]::OrdinalIgnoreCase) }).Count

Write-Host "Checksum manifest ok: $checksumPath"
Write-Host "Entries: $($parsed.Count) (convention: $convention)"
if ($externalCount -gt 0) {
    Write-Host "Shared upstream entries outside directory: $externalCount"
}
if ($GitTrackedOnly) {
    Write-Host 'Coverage: git-tracked files'
} else {
    Write-Host 'Coverage: files present on disk'
}
