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

function Assert-RelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Directory
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        throw 'Checksum entry path is empty.'
    }
    if ($RelativePath -match '\\') {
        throw "Checksum entry must use forward slashes, got: $RelativePath"
    }
    if ($RelativePath -match '^[A-Za-z]:|^/|^//') {
        throw "Checksum entry must be directory-relative, got: $RelativePath"
    }

    $parts = $RelativePath -split '/'
    if ($parts | Where-Object { $_ -eq '' -or $_ -eq '.' -or $_ -eq '..' }) {
        throw "Checksum entry contains an invalid path segment: $RelativePath"
    }

    $localPath = $RelativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $Directory $localPath))
    $directoryWithSeparator = $Directory.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($directoryWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Checksum entry escapes the evidence directory: $RelativePath"
    }

    return $fullPath
}

$resolvedDirectory = Resolve-RepoPath $Directory
if (-not (Test-Path -LiteralPath $resolvedDirectory -PathType Container)) {
    throw "Evidence directory not found: $resolvedDirectory"
}

$checksumPath = Assert-RelativePath -RelativePath $ChecksumFile -Directory $resolvedDirectory
if (-not (Test-Path -LiteralPath $checksumPath -PathType Leaf)) {
    throw "Checksum file not found: $checksumPath"
}

$entries = [ordered]@{}
$lines = Get-Content -LiteralPath $checksumPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
if ($lines.Count -eq 0) {
    throw "Checksum file is empty: $checksumPath"
}

foreach ($line in $lines) {
    if ($line -notmatch '^([0-9a-f]{64})\s\s(.+)$') {
        throw "Malformed checksum line: $line"
    }

    $expectedHash = $Matches[1]
    $relativePath = $Matches[2]
    if ($entries.Contains($relativePath)) {
        throw "Duplicate checksum entry: $relativePath"
    }

    $entryPath = Assert-RelativePath -RelativePath $relativePath -Directory $resolvedDirectory
    if (-not (Test-Path -LiteralPath $entryPath -PathType Leaf)) {
        throw "Checksum entry file does not exist: $relativePath"
    }

    $actualHash = Get-Sha256Hex -Path $entryPath
    if ($actualHash -ne $expectedHash) {
        throw "Checksum mismatch for '$relativePath': expected $expectedHash, got $actualHash"
    }

    $entries[$relativePath] = $true
}

if ($GitTrackedOnly) {
    $repoRelativeDirectory = ConvertTo-ForwardSlashRelative -Root $repoRoot -Path $resolvedDirectory
    $trackedFiles = @(git -C $repoRoot ls-files -- $repoRelativeDirectory)
    if ($LASTEXITCODE -ne 0) {
        throw "git ls-files failed for $repoRelativeDirectory"
    }

    $expectedFiles = @(
        foreach ($path in $trackedFiles) {
            $relative = $path.Substring($repoRelativeDirectory.Length).TrimStart('/')
            if ($relative -ne $ChecksumFile) {
                $relative
            }
        }
    )
} else {
    $expectedFiles = @(
        Get-ChildItem -LiteralPath $resolvedDirectory -Recurse -File |
            Where-Object { $_.FullName -ne $checksumPath } |
            ForEach-Object { ConvertTo-ForwardSlashRelative -Root $resolvedDirectory -Path $_.FullName }
    )
}

$expectedSet = @{}
foreach ($path in ($expectedFiles | Sort-Object)) {
    $expectedSet[$path] = $true
}

$missing = @($expectedSet.Keys | Where-Object { -not $entries.Contains($_) } | Sort-Object)
$extra = @($entries.Keys | Where-Object { -not $expectedSet.ContainsKey($_) } | Sort-Object)

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

Write-Host "Checksum manifest ok: $checksumPath"
Write-Host "Entries: $($entries.Count)"
if ($GitTrackedOnly) {
    Write-Host 'Coverage: git-tracked files'
} else {
    Write-Host 'Coverage: files present on disk'
}
