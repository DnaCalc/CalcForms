[CmdletBinding()]
param(
    [string]$SpecPath = (Join-Path $PSScriptRoot 'capture_spec.v1.json'),
    [string]$OutputDir = 'fixtures/forms-persistence/office-vba-userform-export/20260715-excel-16.0.20131.20112',
    [switch]$Force,
    [switch]$SafetyCheckOnly,
    [switch]$RunSafetySelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$identifiedExporterAttributionBasis = 'Unique loaded Excel-process module whose ModuleName matches VBE[0-9]*.DLL.'
$identifiedExporterClaimScope = 'Exact loaded VBE binary identity; this does not independently prove which binary owns VBComponent.Export.'
$directModulePathResolutionBasis = 'module_reported_path_is_directly_readable'
$directModulePathResolutionCaveat = 'Bytes were hashed from the exact path reported by the loaded Excel process module.'
$clickToRunModulePathResolutionBasis = 'office_click_to_run_vfs_common_files_backing'
$clickToRunModulePathResolutionCaveat = 'The loaded module path was not directly readable; bytes were hashed from the unique deterministic Click-to-Run VFS backing path under the frozen Excel Office root.'
$designerAddRejectedHresult = '0x80070057'

function Resolve-InRepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $full = if ([System.IO.Path]::IsPathRooted($Path)) {
        [System.IO.Path]::GetFullPath($Path)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
    }
    $rootWithSeparator = $repoRoot.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path '$Path' resolves outside repository root '$repoRoot'."
    }
    return $full
}

function Test-PathIsWithin {
    param(
        [Parameter(Mandatory = $true)][string]$Candidate,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $candidateFull = [System.IO.Path]::GetFullPath($Candidate)
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $rootWithSeparator = $rootFull + [System.IO.Path]::DirectorySeparatorChar
    return $candidateFull.Equals($rootFull, [System.StringComparison]::OrdinalIgnoreCase) -or
        $candidateFull.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-NoReparsePointInPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $full = [System.IO.Path]::GetFullPath($Path)
    $volumeRoot = [System.IO.Path]::GetPathRoot($full)
    if ([string]::IsNullOrWhiteSpace($volumeRoot)) {
        throw "Path has no volume root: '$Path'."
    }

    $current = $volumeRoot
    if (Test-Path -LiteralPath $current) {
        $rootItem = Get-Item -LiteralPath $current -Force
        if (($rootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse point is forbidden in capture path: '$($rootItem.FullName)'."
        }
    }

    $relative = $full.Substring($volumeRoot.Length)
    foreach ($part in @($relative -split '[\\/]' | Where-Object { $_.Length -gt 0 })) {
        $current = Join-Path $current $part
        if (-not (Test-Path -LiteralPath $current)) { continue }
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse point is forbidden in capture path: '$($item.FullName)'."
        }
    }
}

function Assert-PhysicalRepoContainment {
    param([Parameter(Mandatory = $true)][string]$Path)

    $full = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-PathIsWithin $full $repoRoot)) {
        throw "Path '$Path' is not physically contained by repository root '$repoRoot'."
    }
    $relative = [System.IO.Path]::GetRelativePath($repoRoot, $full)
    if ($relative.Contains(':') -or $relative.IndexOfAny([char[]]@(0..31 + 127)) -ge 0) {
        throw "Capture path contains an alternate-stream separator or control character: '$Path'."
    }

    # With every existing path component proven not to be a reparse point, the
    # normalized lexical path and the physical path have the same ancestry.
    Assert-NoReparsePointInPath $repoRoot
    Assert-NoReparsePointInPath $full
}

function Assert-NoReparsePointTree {
    param([Parameter(Mandatory = $true)][string]$Path)

    Assert-PhysicalRepoContainment $Path
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $rootItem = Get-Item -LiteralPath $Path -Force
    if (($rootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Reparse point is forbidden in capture tree: '$($rootItem.FullName)'."
    }
    if (-not $rootItem.PSIsContainer) { return }
    $pending = [System.Collections.Generic.Stack[string]]::new()
    $pending.Push($rootItem.FullName)
    while ($pending.Count -gt 0) {
        $directory = $pending.Pop()
        foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force)) {
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Reparse point is forbidden in capture tree: '$($item.FullName)'."
            }
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
}

function Remove-SafeCaptureDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return }
    Assert-NoReparsePointTree $Path
    $item = Get-Item -LiteralPath $Path -Force
    if (-not $item.PSIsContainer) {
        throw "Refusing to remove non-directory capture path '$Path'."
    }
    [System.IO.Directory]::Delete($item.FullName, $true)
}

function New-CaptureStagingDirectory {
    param([Parameter(Mandatory = $true)][string]$TargetDirectory)

    $targetFull = [System.IO.Path]::GetFullPath($TargetDirectory)
    $parent = [System.IO.Path]::GetDirectoryName($targetFull)
    if ([string]::IsNullOrWhiteSpace($parent) -or -not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw "Capture output parent must already exist: '$parent'."
    }
    Assert-PhysicalRepoContainment $parent
    $stageName = '.{0}.capture-staging-{1}' -f [System.IO.Path]::GetFileName($targetFull), [Guid]::NewGuid().ToString('N')
    $stage = Join-Path $parent $stageName
    Assert-PhysicalRepoContainment $stage
    if (Test-Path -LiteralPath $stage) {
        throw "Fresh capture staging path unexpectedly exists: '$stage'."
    }
    [void][System.IO.Directory]::CreateDirectory($stage)
    Assert-PhysicalRepoContainment $stage
    return $stage
}

function Convert-ToRepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $relative = [System.IO.Path]::GetRelativePath($repoRoot, [System.IO.Path]::GetFullPath($Path))
    return $relative.Replace([System.IO.Path]::DirectorySeparatorChar, '/')
}

function Get-RequiredValue {
    param($Object, [Parameter(Mandatory = $true)][string]$Name)

    if ($Object -is [System.Collections.IDictionary]) {
        if (-not $Object.Contains($Name) -or $null -eq $Object[$Name]) {
            throw "Required capture-spec value is missing: $Name"
        }
        return $Object[$Name]
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        throw "Required capture-spec value is missing: $Name"
    }
    return $property.Value
}

function Get-OptionalValue {
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

function Release-ComObject {
    param($Object)

    if ($null -ne $Object -and [System.Runtime.InteropServices.Marshal]::IsComObject($Object)) {
        try {
            [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($Object)
        } catch {
            Write-Warning "COM release failed: $($_.Exception.Message)"
        }
    }
}

function Convert-CaptureValue {
    param(
        [Parameter(Mandatory = $true)][string]$Kind,
        $Value
    )

    switch ($Kind) {
        'string' { return [string]$Value }
        'boolean' { return [bool]$Value }
        'int16' { return [int16]$Value }
        'int32' { return [int32]$Value }
        'single' { return [single]$Value }
        default { throw "Unsupported capture value kind '$Kind'." }
    }
}

function Convert-ObservedValue {
    param($Value)

    if ($null -eq $Value) {
        return [ordered]@{ kind = 'null'; value = $null }
    }
    if ($Value -is [bool]) {
        return [ordered]@{ kind = 'boolean'; value = [bool]$Value }
    }
    if ($Value -is [string]) {
        return [ordered]@{ kind = 'string'; value = [string]$Value }
    }
    if ($Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or $Value -is [int64]) {
        return [ordered]@{ kind = 'integer'; value = [int64]$Value }
    }
    if ($Value -is [single] -or $Value -is [double] -or $Value -is [decimal]) {
        return [ordered]@{
            kind = 'number'
            value = [double]$Value
            invariant = ([double]$Value).ToString('R', [System.Globalization.CultureInfo]::InvariantCulture)
        }
    }
    if ([System.Runtime.InteropServices.Marshal]::IsComObject($Value)) {
        return [ordered]@{ kind = 'com_object'; value = $null }
    }
    return [ordered]@{ kind = 'other'; value = [string]$Value; dotnet_type = $Value.GetType().FullName }
}

function Convert-GeometryValues {
    param(
        [Parameter(Mandatory = $true)]$Geometry,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $result = [ordered]@{}
    foreach ($name in @('left', 'top', 'width', 'height')) {
        $value = [double](Get-RequiredValue $Geometry $name)
        if ([double]::IsNaN($value) -or [double]::IsInfinity($value)) {
            throw "$Label '$name' must be finite, observed '$value'."
        }
        if ($name -in @('width', 'height') -and $value -le 0) {
            throw "$Label '$name' must be positive, observed '$value'."
        }
        $result[$name] = $value
    }
    return $result
}

function Get-GeometryObservationResult {
    param(
        [Parameter(Mandatory = $true)]$ControlSpec,
        [Parameter(Mandatory = $true)]$Readback
    )

    $controlName = [string](Get-RequiredValue $ControlSpec 'name')
    $requested = Convert-GeometryValues (Get-RequiredValue $ControlSpec 'geometry') "Control '$controlName' requested geometry"
    $actual = Convert-GeometryValues $Readback "Control '$controlName' geometry readback"
    $expectation = Get-OptionalValue $ControlSpec 'geometry_readback_expectation'
    $classification = 'exact'
    $basis = $null
    $expected = $requested
    if ($null -ne $expectation) {
        Assert-ExactObjectKeys $expectation @('classification', 'values', 'basis') "Control '$controlName' geometry_readback_expectation"
        $classification = [string](Get-RequiredValue $expectation 'classification')
        if ($classification -cne 'expected_msforms_normalization') {
            throw "Control '$controlName' has unsupported geometry expectation classification '$classification'."
        }
        $basis = [string](Get-RequiredValue $expectation 'basis')
        if ([string]::IsNullOrWhiteSpace($basis)) { throw "Control '$controlName' geometry normalization basis is empty." }
        $expected = Convert-GeometryValues (Get-RequiredValue $expectation 'values') "Control '$controlName' expected geometry readback"
    }

    $changedFields = [System.Collections.Generic.List[string]]::new()
    foreach ($name in @('left', 'top', 'width', 'height')) {
        if ([double]$actual[$name] -ne [double]$requested[$name]) { $changedFields.Add($name) }
        if ([double]$actual[$name] -ne [double]$expected[$name]) {
            throw "Control '$controlName' geometry '$name' drift: requested '$($requested[$name])', expected readback '$($expected[$name])', observed '$($actual[$name])'."
        }
    }
    if ($classification -eq 'exact' -and $changedFields.Count -ne 0) {
        throw "Control '$controlName' unexpectedly normalized geometry fields: $($changedFields -join ', ')."
    }
    if ($classification -eq 'expected_msforms_normalization' -and $changedFields.Count -eq 0) {
        throw "Control '$controlName' expected an MSForms geometry normalization, but no field changed."
    }
    return [ordered]@{
        requested = $requested
        result = [ordered]@{
            classification = $classification
            changed_fields = @($changedFields)
            basis = $basis
        }
    }
}

function Set-ComponentProperty {
    param(
        [Parameter(Mandatory = $true)]$Component,
        [Parameter(Mandatory = $true)]$Spec
    )

    $name = [string](Get-RequiredValue $Spec 'name')
    $kind = [string](Get-RequiredValue $Spec 'kind')
    $requested = Convert-CaptureValue $kind (Get-RequiredValue $Spec 'value')
    $required = [bool](Get-RequiredValue $Spec 'required')
    $errorMessage = $null
    $hresult = $null
    $readback = $null
    try {
        $property = $Component.Properties.Item($name)
        [void]$property.GetType().InvokeMember(
            'Value',
            [System.Reflection.BindingFlags]::SetProperty,
            $null,
            $property,
            @($requested),
            [System.Globalization.CultureInfo]::InvariantCulture
        )
        $readback = $property.Value
    } catch {
        $errorMessage = $_.Exception.Message
        $hresult = ('0x{0:X8}' -f ([int64]$_.Exception.HResult -band 0xFFFFFFFFL))
        if ($required) {
            throw "Required component property '$name' failed: $errorMessage"
        }
    }
    return [ordered]@{
        name = $name
        requested = Convert-ObservedValue $requested
        required = $required
        readback = Convert-ObservedValue $readback
        succeeded = ($null -eq $errorMessage)
        error = $errorMessage
        hresult = $hresult
    }
}

function Set-ControlProperty {
    param(
        [Parameter(Mandatory = $true)]$Control,
        [Parameter(Mandatory = $true)]$Spec
    )

    $name = [string](Get-RequiredValue $Spec 'name')
    $kind = [string](Get-RequiredValue $Spec 'kind')
    $requested = Convert-CaptureValue $kind (Get-RequiredValue $Spec 'value')
    $required = [bool](Get-RequiredValue $Spec 'required')
    $errorMessage = $null
    $hresult = $null
    $readback = $null
    try {
        $property = $Control.PSObject.Properties[$name]
        if ($null -eq $property) {
            throw "COM property '$name' is not exposed."
        }
        $property.Value = $requested
        $readback = $property.Value
    } catch {
        $errorMessage = $_.Exception.Message
        $hresult = ('0x{0:X8}' -f ([int64]$_.Exception.HResult -band 0xFFFFFFFFL))
        if ($required) {
            throw "Required control property '$name' failed: $errorMessage"
        }
    }
    return [ordered]@{
        name = $name
        requested = Convert-ObservedValue $requested
        required = $required
        readback = Convert-ObservedValue $readback
        succeeded = ($null -eq $errorMessage)
        error = $errorMessage
        hresult = $hresult
    }
}

function Get-FileFact {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$ReportedPath = $Path
    )

    $item = Get-Item -LiteralPath $Path
    return [ordered]@{
        path = Convert-ToRepoPath ([System.IO.Path]::GetFullPath($ReportedPath))
        length = [int64]$item.Length
        sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

function Assert-FrozenOutputIdentity {
    param(
        [Parameter(Mandatory = $true)]$Spec,
        [Parameter(Mandatory = $true)][string]$OutputDirectory
    )

    $identity = Get-RequiredValue $Spec 'frozen_capture_identity'
    $captureDate = [string](Get-RequiredValue $identity 'capture_date_utc')
    if ($captureDate -notmatch '^\d{4}-\d{2}-\d{2}$') {
        throw "Frozen capture date must use YYYY-MM-DD: '$captureDate'."
    }
    $dateToken = $captureDate.Replace('-', '')
    $captureId = [string](Get-RequiredValue $Spec 'capture_id')
    if (-not $captureId.Contains($dateToken, [System.StringComparison]::Ordinal)) {
        throw "Capture id '$captureId' is not bound to frozen date '$captureDate'."
    }

    $expectedOutput = Resolve-InRepoPath ([string](Get-RequiredValue $identity 'output_directory'))
    if (-not $expectedOutput.Equals(
        [System.IO.Path]::GetFullPath($OutputDirectory),
        [System.StringComparison]::Ordinal
    )) {
        throw "Output '$OutputDirectory' does not match frozen capture output '$expectedOutput'."
    }
    if (-not ([System.IO.Path]::GetFileName($expectedOutput)).Contains($dateToken, [System.StringComparison]::Ordinal)) {
        throw "Frozen capture output name is not bound to date '$captureDate'."
    }
    $excelExecutable = Get-RequiredValue $identity 'excel_executable'
    $excelFileVersion = [string](Get-RequiredValue $excelExecutable 'file_version')
    $requiredLeaf = "$dateToken-excel-$excelFileVersion"
    $actualLeaf = [System.IO.Path]::GetFileName($expectedOutput)
    if ($actualLeaf -cne $requiredLeaf) {
        throw "Frozen capture output leaf must be exactly '$requiredLeaf', observed '$actualLeaf'."
    }
    Assert-PhysicalRepoContainment $expectedOutput
    return $identity
}

function Assert-FrozenCaptureDate {
    param(
        [Parameter(Mandatory = $true)]$FrozenIdentity,
        [DateTime]$UtcNow = [DateTime]::UtcNow
    )

    $expectedDate = [string](Get-RequiredValue $FrozenIdentity 'capture_date_utc')
    $actualDate = $UtcNow.ToUniversalTime().ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    if ($actualDate -cne $expectedDate) {
        throw "Frozen capture date drift: expected UTC date '$expectedDate', actual UTC date '$actualDate'."
    }
}

function Assert-FrozenExcelExecutableIdentity {
    param(
        [Parameter(Mandatory = $true)]$FrozenIdentity,
        [Parameter(Mandatory = $true)]$ExcelFile
    )

    $expected = Get-RequiredValue $FrozenIdentity 'excel_executable'
    $actual = [ordered]@{
        length = [int64]$ExcelFile.Length
        sha256 = (Get-FileHash -LiteralPath $ExcelFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        file_version = [string]$ExcelFile.VersionInfo.FileVersion
        product_version = [string]$ExcelFile.VersionInfo.ProductVersion
    }
    foreach ($name in @('length', 'sha256', 'file_version', 'product_version')) {
        $expectedValue = [string](Get-RequiredValue $expected $name)
        $actualValue = [string]$actual[$name]
        if (-not $actualValue.Equals($expectedValue, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Frozen Excel executable identity drift for '$name': expected '$expectedValue', observed '$actualValue'."
        }
    }
    return $actual
}

function Assert-FrozenExcelAutomationIdentity {
    param(
        [Parameter(Mandatory = $true)]$FrozenIdentity,
        [Parameter(Mandatory = $true)]$ExcelAutomation
    )

    $expected = Get-RequiredValue $FrozenIdentity 'excel_automation'
    foreach ($name in @('version', 'build', 'vbe_version')) {
        $expectedValue = [string](Get-RequiredValue $expected $name)
        $actualValue = [string](Get-RequiredValue $ExcelAutomation $name)
        if (-not $actualValue.Equals($expectedValue, [System.StringComparison]::Ordinal)) {
            throw "Frozen Excel automation identity drift for '$name': expected '$expectedValue', observed '$actualValue'."
        }
    }
}

function Initialize-ExporterModuleDiscovery {
    if ($null -ne ('OxFormsCapture.NativeMethods' -as [type])) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace OxFormsCapture {
    public static class NativeMethods {
        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    }
}
'@
}

function Get-ExcelHostProcessIdentity {
    param([Parameter(Mandatory = $true)]$ExcelApplication)

    Initialize-ExporterModuleDiscovery
    $excelProcessIdValue = [uint32]0
    $windowHandle = [IntPtr]([int64]$ExcelApplication.Hwnd)
    [void][OxFormsCapture.NativeMethods]::GetWindowThreadProcessId($windowHandle, [ref]$excelProcessIdValue)
    if ($excelProcessIdValue -eq 0) { throw 'Excel window handle did not resolve to a process id.' }
    $process = Get-Process -Id $excelProcessIdValue -ErrorAction Stop
    $executablePath = [string]$process.MainModule.FileName
    if ([string]::IsNullOrWhiteSpace($executablePath) -or -not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
        throw "Excel host process executable could not be resolved for process $excelProcessIdValue."
    }
    $file = Get-Item -LiteralPath $executablePath -Force
    return [ordered]@{
        process_id = [int64]$excelProcessIdValue
        path = $file.FullName
        length = [int64]$file.Length
        sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        file_version = [string]$file.VersionInfo.FileVersion
        product_version = [string]$file.VersionInfo.ProductVersion
    }
}

function Assert-FrozenExcelProcessIdentity {
    param(
        [Parameter(Mandatory = $true)]$FrozenIdentity,
        [Parameter(Mandatory = $true)]$ProcessIdentity
    )

    $expected = Get-RequiredValue $FrozenIdentity 'excel_executable'
    foreach ($name in @('length', 'sha256', 'file_version', 'product_version')) {
        $expectedValue = [string](Get-RequiredValue $expected $name)
        $actualValue = [string](Get-RequiredValue $ProcessIdentity $name)
        if (-not $expectedValue.Equals($actualValue, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Actual Excel COM host identity drift for '$name': expected '$expectedValue', observed '$actualValue'."
        }
    }
}

function Resolve-LoadedModuleBinaryPath {
    param(
        [Parameter(Mandatory = $true)][string]$ModuleReportedPath,
        [Parameter(Mandatory = $true)][string]$ExcelExecutablePath
    )

    $reportedFull = [System.IO.Path]::GetFullPath($ModuleReportedPath)
    if (Test-Path -LiteralPath $reportedFull -PathType Leaf) {
        return [ordered]@{
            module_reported_path = $reportedFull
            path = (Get-Item -LiteralPath $reportedFull -Force).FullName
            path_resolution_basis = $directModulePathResolutionBasis
            path_resolution_caveat = $directModulePathResolutionCaveat
        }
    }

    $excelFull = [System.IO.Path]::GetFullPath($ExcelExecutablePath)
    $officeVersionDirectory = [System.IO.Path]::GetDirectoryName($excelFull)
    $officeRoot = [System.IO.Path]::GetDirectoryName($officeVersionDirectory)
    if ([string]::IsNullOrWhiteSpace($officeRoot) -or -not (Test-Path -LiteralPath $officeRoot -PathType Container)) {
        throw "Actual Excel Office root could not be resolved from '$excelFull'."
    }

    $mappings = [System.Collections.Generic.List[object]]::new()
    foreach ($mapping in @(
        [ordered]@{ root = [string]$env:CommonProgramFiles; marker = 'ProgramFilesCommonX64' },
        [ordered]@{ root = [string]${env:CommonProgramFiles(x86)}; marker = 'ProgramFilesCommonX86' }
    )) {
        if ([string]::IsNullOrWhiteSpace([string]$mapping.root)) { continue }
        $commonRoot = [System.IO.Path]::GetFullPath([string]$mapping.root).TrimEnd(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        )
        $commonPrefix = $commonRoot + [System.IO.Path]::DirectorySeparatorChar
        if (-not $reportedFull.StartsWith($commonPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        $suffix = [System.IO.Path]::GetRelativePath($commonRoot, $reportedFull)
        if ([System.IO.Path]::IsPathRooted($suffix) -or $suffix -eq '..' -or
            $suffix.StartsWith('..' + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::Ordinal) -or
            $suffix.Contains(':')) {
            throw "Loaded module path has an unsafe Common Files suffix: '$suffix'."
        }
        $candidate = [System.IO.Path]::GetFullPath((Join-Path $officeRoot (Join-Path "vfs\$([string]$mapping.marker)" $suffix)))
        if (-not (Test-PathIsWithin $candidate $officeRoot)) {
            throw "Click-to-Run VFS backing candidate escapes the actual Excel Office root: '$candidate'."
        }
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $mappings.Add([ordered]@{ path = (Get-Item -LiteralPath $candidate -Force).FullName; suffix = $suffix })
        }
    }
    if ($mappings.Count -ne 1) {
        throw "Loaded module path '$reportedFull' was unreadable and resolved to $($mappings.Count) Click-to-Run VFS backing files under '$officeRoot'; exactly one is required."
    }
    return [ordered]@{
        module_reported_path = $reportedFull
        path = [string]$mappings[0].path
        path_resolution_basis = $clickToRunModulePathResolutionBasis
        path_resolution_caveat = $clickToRunModulePathResolutionCaveat
    }
}

function Get-LoadedVbeBinaryCandidates {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()]$Modules,
        [Parameter(Mandatory = $true)][string]$ExcelExecutablePath
    )

    $candidates = [System.Collections.Generic.List[object]]::new()
    foreach ($module in @($Modules)) {
        $moduleName = [string]$module.ModuleName
        if ($moduleName -notmatch '^(?i:VBE\d*\.DLL)$') { continue }
        $reportedPath = [string]$module.FileName
        if ([string]::IsNullOrWhiteSpace($reportedPath)) {
            throw "Loaded VBE module '$moduleName' did not expose a reported file path."
        }
        $resolution = Resolve-LoadedModuleBinaryPath $reportedPath $ExcelExecutablePath
        $file = Get-Item -LiteralPath ([string]$resolution.path) -Force
        $originalName = [string]$file.VersionInfo.OriginalFilename
        $candidates.Add([ordered]@{
            module_name = $moduleName
            module_reported_path = [string]$resolution.module_reported_path
            path = $file.FullName
            path_resolution_basis = [string]$resolution.path_resolution_basis
            path_resolution_caveat = [string]$resolution.path_resolution_caveat
            length = [int64]$file.Length
            sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            file_version = [string]$file.VersionInfo.FileVersion
            product_version = [string]$file.VersionInfo.ProductVersion
            original_filename = if ([string]::IsNullOrWhiteSpace($originalName)) { $null } else { $originalName }
        })
    }
    return @($candidates)
}

function Get-ExporterBinaryIdentity {
    param(
        [Parameter(Mandatory = $true)]$ExcelApplication,
        [int64]$HostProcessId = 0,
        [Parameter(Mandatory = $true)][string]$ExcelExecutablePath
    )

    $unknownClaim = 'No exact exporter binary identity is asserted.'
    $excelProcessIdValue = [uint32]$HostProcessId
    try {
        Initialize-ExporterModuleDiscovery
        if ($excelProcessIdValue -eq 0) {
            $windowHandle = [IntPtr]([int64]$ExcelApplication.Hwnd)
            [void][OxFormsCapture.NativeMethods]::GetWindowThreadProcessId($windowHandle, [ref]$excelProcessIdValue)
        }
        if ($excelProcessIdValue -eq 0) { throw 'Excel window handle did not resolve to a process id.' }
        $process = Get-Process -Id $excelProcessIdValue -ErrorAction Stop
        $candidates = @(Get-LoadedVbeBinaryCandidates @($process.Modules) $ExcelExecutablePath)
        if ($candidates.Count -eq 1) {
            return [ordered]@{
                status = 'identified_loaded_vbe_binary'
                host_process_id = [int64]$excelProcessIdValue
                attribution_basis = $identifiedExporterAttributionBasis
                claim_scope = $identifiedExporterClaimScope
                binary = $candidates[0]
            }
        }
        return [ordered]@{
            status = 'unknown'
            host_process_id = [int64]$excelProcessIdValue
            reason_code = if ($candidates.Count -eq 0) { 'no_loaded_vbe_binary_candidate' } else { 'multiple_loaded_vbe_binary_candidates' }
            nonclaim = $unknownClaim
            candidates = @($candidates)
        }
    } catch {
        return [ordered]@{
            status = 'unknown'
            host_process_id = if ($excelProcessIdValue -eq 0) { $null } else { [int64]$excelProcessIdValue }
            reason_code = 'loaded_module_discovery_failed'
            nonclaim = $unknownClaim
            error = $_.Exception.Message
            candidates = @()
        }
    }
}

function Assert-FrozenExporterBinaryIdentity {
    param(
        [Parameter(Mandatory = $true)]$FrozenIdentity,
        [Parameter(Mandatory = $true)]$ExporterIdentity,
        [string]$ExcelExecutablePath
    )

    $expected = Get-RequiredValue $FrozenIdentity 'vbe_binary'
    $status = [string](Get-RequiredValue $ExporterIdentity 'status')
    if ($status -eq 'unknown') {
        $nonclaim = [string](Get-RequiredValue $ExporterIdentity 'nonclaim')
        if ([string]::IsNullOrWhiteSpace($nonclaim)) {
            throw 'Unknown exporter binary identity must carry an explicit nonclaim.'
        }
        $reasonCode = [string](Get-OptionalValue $ExporterIdentity 'reason_code')
        $discoveryError = [string](Get-OptionalValue $ExporterIdentity 'error')
        $candidateValue = Get-OptionalValue $ExporterIdentity 'candidates'
        $candidateCount = if ($null -eq $candidateValue) { 0 } else { @($candidateValue).Count }
        throw "Frozen capture requires the exact uniquely loaded VBE binary; discovery returned unknown (reason_code='$reasonCode', candidate_count=$candidateCount, error='$discoveryError'). $nonclaim"
    }
    if ($status -ne 'identified_loaded_vbe_binary') {
        throw "Unexpected exporter binary identity status '$status'."
    }
    if ([string](Get-RequiredValue $ExporterIdentity 'attribution_basis') -cne $identifiedExporterAttributionBasis) {
        throw 'Identified exporter attribution_basis drifted from the bounded loaded-module observation.'
    }
    if ([string](Get-RequiredValue $ExporterIdentity 'claim_scope') -cne $identifiedExporterClaimScope) {
        throw 'Identified exporter claim_scope drifted from the required non-ownership caveat.'
    }

    $actual = Get-RequiredValue $ExporterIdentity 'binary'
    foreach ($name in @('module_name', 'length', 'sha256', 'file_version', 'product_version')) {
        $expectedValue = [string](Get-RequiredValue $expected $name)
        $actualValue = [string](Get-RequiredValue $actual $name)
        if (-not $expectedValue.Equals($actualValue, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Frozen VBE binary identity drift for '$name': expected '$expectedValue', observed '$actualValue'."
        }
    }
    if ([string]::IsNullOrWhiteSpace($ExcelExecutablePath)) {
        throw 'Identified exporter binary validation requires the actual Excel executable path.'
    }
    $resolution = Resolve-LoadedModuleBinaryPath `
        ([string](Get-RequiredValue $actual 'module_reported_path')) `
        $ExcelExecutablePath
    foreach ($name in @('path', 'path_resolution_basis', 'path_resolution_caveat')) {
        $expectedValue = [string]$resolution[$name]
        $actualValue = [string](Get-RequiredValue $actual $name)
        $comparison = if ($name -eq 'path') { [System.StringComparison]::OrdinalIgnoreCase } else { [System.StringComparison]::Ordinal }
        if (-not $expectedValue.Equals($actualValue, $comparison)) {
            throw "Loaded VBE binary '$name' does not match deterministic module-path resolution."
        }
    }
    Assert-BinaryPathFactMatches $actual 'Loaded VBE binary'
    $actualFileName = [System.IO.Path]::GetFileName([string](Get-RequiredValue $actual 'path'))
    if (-not $actualFileName.Equals([string](Get-RequiredValue $actual 'module_name'), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Loaded VBE binary path leaf '$actualFileName' does not match its module name."
    }
    $reportedFileName = [System.IO.Path]::GetFileName([string](Get-RequiredValue $actual 'module_reported_path'))
    if (-not $reportedFileName.Equals([string](Get-RequiredValue $actual 'module_name'), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Loaded VBE module-reported path leaf '$reportedFileName' does not match its module name."
    }
}

function Get-ProgIdRegistration {
    param([Parameter(Mandatory = $true)][string]$ProgId)

    $progidPath = "Registry::HKEY_CLASSES_ROOT\$ProgId"
    $clsid = Get-ItemPropertyValue -LiteralPath (Join-Path $progidPath 'CLSID') -Name '(default)' -ErrorAction SilentlyContinue
    $className = $null
    $serverPath = $null
    if ($null -ne $clsid) {
        $clsidPath = "Registry::HKEY_CLASSES_ROOT\CLSID\$clsid"
        $className = Get-ItemPropertyValue -LiteralPath $clsidPath -Name '(default)' -ErrorAction SilentlyContinue
        $serverPath = Get-ItemPropertyValue -LiteralPath (Join-Path $clsidPath 'InprocServer32') -Name '(default)' -ErrorAction SilentlyContinue
    }
    $serverFact = $null
    if ($null -ne $serverPath -and (Test-Path -LiteralPath $serverPath -PathType Leaf)) {
        $serverItem = Get-Item -LiteralPath $serverPath
        $serverFact = [ordered]@{
            path = $serverItem.FullName
            length = [int64]$serverItem.Length
            sha256 = (Get-FileHash -LiteralPath $serverItem.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            file_version = $serverItem.VersionInfo.FileVersion
            product_version = $serverItem.VersionInfo.ProductVersion
        }
    }
    return [ordered]@{
        progid = $ProgId
        clsid = $clsid
        class_name = $className
        inproc_server = $serverFact
    }
}

function Get-GitCaptureState {
    $head = (& git -C $repoRoot rev-parse HEAD 2>$null).Trim()
    $status = @(& git -C $repoRoot status --porcelain=v1 --untracked-files=all 2>$null)
    return [ordered]@{
        head = $head
        dirty = ($status.Count -gt 0)
        status_line_count = $status.Count
    }
}

function Assert-SequenceEqual {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()]$Expected,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()]$Actual,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $expectedValues = @($Expected | ForEach-Object { [string]$_ })
    $actualValues = @($Actual | ForEach-Object { [string]$_ })
    if ($expectedValues.Count -ne $actualValues.Count) {
        throw "$Label count drift: expected $($expectedValues.Count), observed $($actualValues.Count)."
    }
    for ($i = 0; $i -lt $expectedValues.Count; $i++) {
        if (-not $expectedValues[$i].Equals($actualValues[$i], [System.StringComparison]::Ordinal)) {
            throw "$Label drift at index ${i}: expected '$($expectedValues[$i])', observed '$($actualValues[$i])'."
        }
    }
}

function Get-ObjectKeyNames {
    param([Parameter(Mandatory = $true)]$Object)

    if ($Object -is [System.Collections.IDictionary]) { return @($Object.Keys | ForEach-Object { [string]$_ }) }
    return @($Object.PSObject.Properties.Name)
}

function Assert-ExactObjectKeys {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$ExpectedKeys,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $actual = @(Get-ObjectKeyNames $Object | Sort-Object -CaseSensitive)
    $expected = @($ExpectedKeys | Sort-Object -CaseSensitive)
    Assert-SequenceEqual $expected $actual "$Label keys"
}

function Assert-JsonValueEqual {
    param(
        [AllowNull()]$Expected,
        [AllowNull()]$Actual,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $expectedJson = $Expected | ConvertTo-Json -Depth 20 -Compress
    $actualJson = $Actual | ConvertTo-Json -Depth 20 -Compress
    if (-not ([string]$expectedJson).Equals([string]$actualJson, [System.StringComparison]::Ordinal)) {
        throw "$Label drift: expected $expectedJson, observed $actualJson."
    }
}

function Assert-ObservedPropertyBinding {
    param(
        [Parameter(Mandatory = $true)]$PropertySpec,
        [Parameter(Mandatory = $true)]$Observation,
        [Parameter(Mandatory = $true)][string]$Label
    )

    Assert-ExactObjectKeys $Observation @('name', 'requested', 'required', 'readback', 'succeeded', 'error', 'hresult') $Label
    $expectedName = [string](Get-RequiredValue $PropertySpec 'name')
    if ([string](Get-RequiredValue $Observation 'name') -cne $expectedName) { throw "$Label name drift." }
    $kind = [string](Get-RequiredValue $PropertySpec 'kind')
    $expectedRequested = Convert-ObservedValue (Convert-CaptureValue $kind (Get-RequiredValue $PropertySpec 'value'))
    Assert-JsonValueEqual $expectedRequested (Get-RequiredValue $Observation 'requested') "$Label requested value"
    $required = [bool](Get-RequiredValue $PropertySpec 'required')
    if ([bool](Get-RequiredValue $Observation 'required') -ne $required) { throw "$Label required flag drift." }
    $succeeded = [bool](Get-RequiredValue $Observation 'succeeded')
    if ($required -and -not $succeeded) { throw "$Label records failure for a required property." }
    $errorValue = Get-OptionalValue $Observation 'error'
    $hresultValue = Get-OptionalValue $Observation 'hresult'
    if ($succeeded -and ($null -ne $errorValue -or $null -ne $hresultValue)) {
        throw "$Label succeeded but carries error provenance."
    }
    if (-not $succeeded -and ([string]::IsNullOrWhiteSpace([string]$errorValue) -or [string]::IsNullOrWhiteSpace([string]$hresultValue))) {
        throw "$Label failed without error/HRESULT provenance."
    }
    foreach ($valueName in @('requested', 'readback')) {
        $value = Get-RequiredValue $Observation $valueName
        $valueKind = [string](Get-RequiredValue $value 'kind')
        $keys = switch ($valueKind) {
            'number' { @('kind', 'value', 'invariant') }
            'other' { @('kind', 'value', 'dotnet_type') }
            default { @('kind', 'value') }
        }
        Assert-ExactObjectKeys $value $keys "$Label $valueName"
    }
}

function Assert-FileFactMatches {
    param(
        [Parameter(Mandatory = $true)]$Fact,
        [Parameter(Mandatory = $true)][string]$PhysicalPath,
        [Parameter(Mandatory = $true)][string]$ReportedPath,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $actual = Get-FileFact $PhysicalPath $ReportedPath
    foreach ($name in @('path', 'length', 'sha256')) {
        $expectedValue = [string](Get-RequiredValue $Fact $name)
        $actualValue = [string]$actual[$name]
        if (-not $expectedValue.Equals($actualValue, [System.StringComparison]::Ordinal)) {
            throw "$Label '$name' drift: manifest '$expectedValue', actual '$actualValue'."
        }
    }
}

function Assert-BinaryPathFactMatches {
    param(
        [Parameter(Mandatory = $true)]$Fact,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $path = [string](Get-RequiredValue $Fact 'path')
    if (-not [System.IO.Path]::IsPathRooted($path) -or -not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "$Label path is not an existing rooted file: '$path'."
    }
    $file = Get-Item -LiteralPath $path -Force
    $actual = [ordered]@{
        length = [int64]$file.Length
        sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        file_version = [string]$file.VersionInfo.FileVersion
        product_version = [string]$file.VersionInfo.ProductVersion
    }
    foreach ($name in @('length', 'sha256', 'file_version', 'product_version')) {
        $expectedValue = [string](Get-RequiredValue $Fact $name)
        $actualValue = [string]$actual[$name]
        if (-not $expectedValue.Equals($actualValue, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "$Label '$name' does not match the file at '$path'."
        }
    }
}

function Assert-CaptureManifestStructureAndBindings {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)]$Spec
    )

    Assert-ExactObjectKeys $Manifest @(
        'schema', 'capture_id', 'profile', 'frozen_capture_identity', 'authority_class',
        'capture_started_utc', 'capture_completed_utc', 'clean_room', 'git', 'capture_tool',
        'capture_spec', 'environment', 'excel_file', 'excel_automation',
        'exporter_binary_identity', 'progid_registrations', 'forms', 'designer_add_probes'
    ) 'Capture manifest'
    if ([string](Get-RequiredValue $Manifest 'authority_class') -cne 'observed_real_office_export') {
        throw 'Capture manifest authority_class drift.'
    }
    $frozen = Get-RequiredValue $Manifest 'frozen_capture_identity'
    Assert-ExactObjectKeys $frozen @(
        'capture_date_utc', 'output_directory', 'excel_executable', 'excel_automation', 'vbe_binary'
    ) 'frozen_capture_identity'
    Assert-ExactObjectKeys (Get-RequiredValue $frozen 'excel_executable') @(
        'length', 'sha256', 'file_version', 'product_version'
    ) 'frozen_capture_identity.excel_executable'
    Assert-ExactObjectKeys (Get-RequiredValue $frozen 'excel_automation') @(
        'version', 'build', 'vbe_version'
    ) 'frozen_capture_identity.excel_automation'
    Assert-ExactObjectKeys (Get-RequiredValue $frozen 'vbe_binary') @(
        'module_name', 'length', 'sha256', 'file_version', 'product_version'
    ) 'frozen_capture_identity.vbe_binary'

    $cleanRoom = Get-RequiredValue $Manifest 'clean_room'
    Assert-ExactObjectKeys $cleanRoom @(
        'project_authored_inputs', 'third_party_form_content', 'public_automation_only', 'transient_workbook_saved'
    ) 'clean_room'
    if (-not [bool](Get-RequiredValue $cleanRoom 'project_authored_inputs') -or
        [bool](Get-RequiredValue $cleanRoom 'third_party_form_content') -or
        -not [bool](Get-RequiredValue $cleanRoom 'public_automation_only') -or
        [bool](Get-RequiredValue $cleanRoom 'transient_workbook_saved')) {
        throw 'Capture manifest clean-room claims drifted from the controlled capture contract.'
    }

    $git = Get-RequiredValue $Manifest 'git'
    Assert-ExactObjectKeys $git @('head', 'dirty', 'status_line_count') 'git'
    if ([string](Get-RequiredValue $git 'head') -notmatch '^[0-9a-fA-F]{40}$') { throw 'Capture git head is not a full object id.' }
    $statusLineCount = [int](Get-RequiredValue $git 'status_line_count')
    if ($statusLineCount -lt 0 -or [bool](Get-RequiredValue $git 'dirty') -ne ($statusLineCount -gt 0)) {
        throw 'Capture git dirty/count provenance is inconsistent.'
    }

    Assert-ExactObjectKeys (Get-RequiredValue $Manifest 'environment') @(
        'os_version', 'os_architecture', 'process_architecture', 'culture', 'ui_culture',
        'ansi_code_page', 'oem_code_page', 'powershell_version'
    ) 'environment'
    Assert-ExactObjectKeys (Get-RequiredValue $Manifest 'excel_file') @(
        'process_id', 'path', 'length', 'sha256', 'file_version', 'product_version'
    ) 'excel_file'
    $excelAutomation = Get-RequiredValue $Manifest 'excel_automation'
    Assert-ExactObjectKeys $excelAutomation @(
        'application_name', 'version', 'build', 'vbe_version', 'access_vbom',
        'component_type', 'export_api', 'workbook_saved'
    ) 'excel_automation'
    if ([string](Get-RequiredValue $excelAutomation 'application_name') -cne 'Microsoft Excel' -or
        -not [bool](Get-RequiredValue $excelAutomation 'access_vbom') -or
        [int](Get-RequiredValue $excelAutomation 'component_type') -ne 3 -or
        [string](Get-RequiredValue $excelAutomation 'export_api') -cne 'VBComponent.Export' -or
        [bool](Get-RequiredValue $excelAutomation 'workbook_saved')) {
        throw 'Excel automation provenance drifted from the public transient export contract.'
    }

    foreach ($factName in @('capture_tool', 'capture_spec')) {
        Assert-ExactObjectKeys (Get-RequiredValue $Manifest $factName) @('path', 'length', 'sha256') $factName
    }
    $exporter = Get-RequiredValue $Manifest 'exporter_binary_identity'
    Assert-ExactObjectKeys $exporter @('status', 'host_process_id', 'attribution_basis', 'claim_scope', 'binary') 'exporter_binary_identity'
    Assert-ExactObjectKeys (Get-RequiredValue $exporter 'binary') @(
        'module_name', 'module_reported_path', 'path', 'path_resolution_basis',
        'path_resolution_caveat', 'length', 'sha256', 'file_version', 'product_version',
        'original_filename'
    ) 'exporter_binary_identity.binary'

    $expectedProgIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($formSpec in @($Spec.forms)) {
        foreach ($controlSpec in @($formSpec.controls)) {
            [void]$expectedProgIds.Add([string](Get-RequiredValue $controlSpec 'progid'))
        }
    }
    foreach ($probeSpec in @($Spec.designer_add_probes)) {
        [void]$expectedProgIds.Add([string](Get-RequiredValue $probeSpec 'progid'))
    }
    $registrations = @($Manifest.progid_registrations)
    $actualProgIds = @($registrations | ForEach-Object { [string](Get-RequiredValue $_ 'progid') })
    Assert-SequenceEqual @($expectedProgIds | Sort-Object -CaseSensitive) $actualProgIds 'ProgID registration order'
    foreach ($registration in $registrations) {
        Assert-ExactObjectKeys $registration @('progid', 'clsid', 'class_name', 'inproc_server') 'ProgID registration'
        $server = Get-OptionalValue $registration 'inproc_server'
        if ($null -ne $server) {
            Assert-ExactObjectKeys $server @('path', 'length', 'sha256', 'file_version', 'product_version') 'ProgID in-process server'
            Assert-BinaryPathFactMatches $server 'ProgID in-process server'
        }
    }

    $formSpecs = @($Spec.forms)
    $forms = @($Manifest.forms)
    if ($formSpecs.Count -ne $forms.Count) { throw 'Capture manifest form count drift.' }
    for ($formIndex = 0; $formIndex -lt $formSpecs.Count; $formIndex++) {
        $formSpec = $formSpecs[$formIndex]
        $form = $forms[$formIndex]
        $formLabel = "form[$formIndex]"
        Assert-ExactObjectKeys $form @(
            'fixture_id', 'component_name', 'component_properties', 'controls', 'code_input', 'exported_files'
        ) $formLabel
        foreach ($pair in @(
            @('fixture_id', 'fixture_id'),
            @('component_name', 'name')
        )) {
            if ([string](Get-RequiredValue $form $pair[0]) -cne [string](Get-RequiredValue $formSpec $pair[1])) {
                throw "$formLabel '$($pair[0])' drift."
            }
        }
        $componentSpecs = @($formSpec.component_properties)
        $componentObservations = @($form.component_properties)
        if ($componentSpecs.Count -ne $componentObservations.Count) { throw "$formLabel component-property count drift." }
        for ($propertyIndex = 0; $propertyIndex -lt $componentSpecs.Count; $propertyIndex++) {
            Assert-ObservedPropertyBinding $componentSpecs[$propertyIndex] $componentObservations[$propertyIndex] "$formLabel component_property[$propertyIndex]"
        }

        $controlSpecs = @($formSpec.controls)
        $controls = @($form.controls)
        if ($controlSpecs.Count -ne $controls.Count) { throw "$formLabel control count drift." }
        for ($controlIndex = 0; $controlIndex -lt $controlSpecs.Count; $controlIndex++) {
            $controlSpec = $controlSpecs[$controlIndex]
            $control = $controls[$controlIndex]
            $controlLabel = "$formLabel control[$controlIndex]"
            Assert-ExactObjectKeys $control @(
                'name', 'family', 'progid', 'container', 'geometry_requested',
                'geometry_readback', 'geometry_result', 'properties',
                'requested_list_items', 'list_items_readback', 'pages', 'tabs'
            ) $controlLabel
            foreach ($name in @('name', 'family', 'progid', 'container')) {
                if ([string](Get-RequiredValue $control $name) -cne [string](Get-RequiredValue $controlSpec $name)) {
                    throw "$controlLabel '$name' drift."
                }
            }
            $geometryRequested = Get-RequiredValue $control 'geometry_requested'
            $geometry = Get-RequiredValue $control 'geometry_readback'
            $geometryResult = Get-RequiredValue $control 'geometry_result'
            Assert-ExactObjectKeys $geometryRequested @('left', 'top', 'width', 'height') "$controlLabel geometry_requested"
            Assert-ExactObjectKeys $geometry @('left', 'top', 'width', 'height') "$controlLabel geometry"
            Assert-ExactObjectKeys $geometryResult @('classification', 'changed_fields', 'basis') "$controlLabel geometry_result"
            $expectedGeometryObservation = Get-GeometryObservationResult $controlSpec $geometry
            Assert-JsonValueEqual $expectedGeometryObservation.requested $geometryRequested "$controlLabel geometry_requested"
            Assert-JsonValueEqual $expectedGeometryObservation.result $geometryResult "$controlLabel geometry_result"
            $propertySpecs = @($controlSpec.properties)
            $propertyObservations = @($control.properties)
            if ($propertySpecs.Count -ne $propertyObservations.Count) { throw "$controlLabel property count drift." }
            for ($propertyIndex = 0; $propertyIndex -lt $propertySpecs.Count; $propertyIndex++) {
                Assert-ObservedPropertyBinding $propertySpecs[$propertyIndex] $propertyObservations[$propertyIndex] "$controlLabel property[$propertyIndex]"
            }
            foreach ($collectionName in @('pages', 'tabs')) {
                $requestedValue = Get-OptionalValue $controlSpec $collectionName
                [object[]]$requestedCollection = @()
                if ($null -ne $requestedValue) { $requestedCollection = @($requestedValue) }
                $observedCollection = @($control.$collectionName)
                if ($requestedCollection.Count -ne $observedCollection.Count) { throw "$controlLabel $collectionName count drift." }
                for ($itemIndex = 0; $itemIndex -lt $requestedCollection.Count; $itemIndex++) {
                    $requestedItem = $requestedCollection[$itemIndex]
                    $observedItem = $observedCollection[$itemIndex]
                    Assert-ExactObjectKeys $observedItem @('index', 'name', 'caption') "$controlLabel $collectionName[$itemIndex]"
                    $requestedName = Get-OptionalValue $requestedItem 'name'
                    if ($null -eq $requestedName) { $requestedName = Get-RequiredValue $requestedItem 'add_name' }
                    if ([string](Get-RequiredValue $observedItem 'name') -cne [string]$requestedName -or
                        [string](Get-RequiredValue $observedItem 'caption') -cne [string](Get-RequiredValue $requestedItem 'caption')) {
                        throw "$controlLabel $collectionName[$itemIndex] drift."
                    }
                    $requestedIndex = Get-OptionalValue $requestedItem 'index'
                    if ($null -ne $requestedIndex -and [int](Get-RequiredValue $observedItem 'index') -ne [int]$requestedIndex) {
                        throw "$controlLabel $collectionName[$itemIndex] index drift."
                    }
                }
            }
        }

        $codeInput = Get-RequiredValue $form 'code_input'
        Assert-ExactObjectKeys $codeInput @('line_count', 'utf8_sha256') "$formLabel code_input"
        $codeLines = @($formSpec.code_lines | ForEach-Object { [string]$_ })
        $codeText = ($codeLines -join "`r`n") + "`r`n"
        $codeHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($utf8NoBom.GetBytes($codeText))).ToLowerInvariant()
        if ([int](Get-RequiredValue $codeInput 'line_count') -ne $codeLines.Count -or
            [string](Get-RequiredValue $codeInput 'utf8_sha256') -cne $codeHash) {
            throw "$formLabel code_input drift."
        }
        foreach ($exportFact in @($form.exported_files)) {
            Assert-ExactObjectKeys $exportFact @('path', 'length', 'sha256') "$formLabel exported file"
        }
    }

    $probeSpecs = @($Spec.designer_add_probes)
    $probes = @($Manifest.designer_add_probes)
    if ($probeSpecs.Count -ne $probes.Count) { throw 'Designer-add probe count drift.' }
    for ($probeIndex = 0; $probeIndex -lt $probeSpecs.Count; $probeIndex++) {
        $probeSpec = $probeSpecs[$probeIndex]
        $probe = $probes[$probeIndex]
        Assert-ExactObjectKeys $probe @('family', 'progid', 'expected', 'added', 'error', 'hresult') "designer_add_probe[$probeIndex]"
        foreach ($name in @('family', 'progid', 'expected')) {
            if ([string](Get-RequiredValue $probe $name) -cne [string](Get-RequiredValue $probeSpec $name)) {
                throw "designer_add_probe[$probeIndex] '$name' drift."
            }
        }
        $expected = [string](Get-RequiredValue $probeSpec 'expected')
        $addedValue = Get-RequiredValue $probe 'added'
        if ($addedValue -isnot [bool]) {
            throw "designer_add_probe[$probeIndex] 'added' must be a boolean."
        }
        $added = [bool]$addedValue
        if (($expected -eq 'rejected' -and $added) -or ($expected -eq 'added' -and -not $added)) {
            throw "designer_add_probe[$probeIndex] outcome drift."
        }
        if (-not $added) {
            $rejectionError = [string](Get-OptionalValue $probe 'error')
            $rejectionHresult = [string](Get-OptionalValue $probe 'hresult')
            if ([string]::IsNullOrWhiteSpace($rejectionError) -or [string]::IsNullOrWhiteSpace($rejectionHresult)) {
                throw "designer_add_probe[$probeIndex] rejection lacks error/HRESULT provenance."
            }
            if ($expected -eq 'rejected' -and $rejectionHresult -cne $designerAddRejectedHresult) {
                throw "designer_add_probe[$probeIndex] rejection HRESULT drift: expected $designerAddRejectedHresult, observed $rejectionHresult."
            }
        }
    }
}

function Test-StagedCapture {
    param(
        [Parameter(Mandatory = $true)][string]$CaptureDirectory,
        [Parameter(Mandatory = $true)][string]$FinalOutputDirectory,
        [Parameter(Mandatory = $true)]$Spec,
        [string]$ExpectedSpecPath
    )

    Assert-NoReparsePointTree $CaptureDirectory
    Assert-PhysicalRepoContainment $FinalOutputDirectory
    $captureItem = Get-Item -LiteralPath $CaptureDirectory -Force
    if (-not $captureItem.PSIsContainer) { throw "Capture staging path is not a directory: '$CaptureDirectory'." }

    $expectedNames = [System.Collections.Generic.List[string]]::new()
    foreach ($formSpec in @($Spec.forms)) {
        $formName = [string](Get-RequiredValue $formSpec 'name')
        $expectedNames.Add("$formName.frm")
        $expectedNames.Add("$formName.frx")
    }
    $expectedNames.Add('capture_manifest.v2.json')
    $expectedSorted = @($expectedNames | Sort-Object -CaseSensitive)
    $entries = @(Get-ChildItem -LiteralPath $CaptureDirectory -Force)
    foreach ($entry in $entries) {
        if ($entry.PSIsContainer) { throw "Unexpected directory in staged capture: '$($entry.Name)'." }
        if (($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Unexpected reparse point in staged capture: '$($entry.Name)'."
        }
    }
    $actualSorted = @($entries.Name | Sort-Object -CaseSensitive)
    Assert-SequenceEqual $expectedSorted $actualSorted 'Staged capture file set'

    $manifestPath = Join-Path $CaptureDirectory 'capture_manifest.v2.json'
    if ((Get-Item -LiteralPath $manifestPath -Force).Length -le 0) {
        throw 'Staged capture manifest is empty.'
    }
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    if ([string](Get-RequiredValue $manifest 'schema') -ne 'oxforms.forms-persistence.live-export-capture.v2') {
        throw 'Unexpected staged capture manifest schema.'
    }
    Assert-CaptureManifestStructureAndBindings $manifest $Spec
    foreach ($name in @('capture_id', 'profile')) {
        $expectedValue = [string](Get-RequiredValue $Spec $name)
        $actualValue = [string](Get-RequiredValue $manifest $name)
        if (-not $expectedValue.Equals($actualValue, [System.StringComparison]::Ordinal)) {
            throw "Staged manifest '$name' drift: expected '$expectedValue', observed '$actualValue'."
        }
    }

    $frozenIdentity = Get-RequiredValue $Spec 'frozen_capture_identity'
    $manifestIdentity = Get-RequiredValue $manifest 'frozen_capture_identity'
    $expectedIdentityJson = $frozenIdentity | ConvertTo-Json -Depth 10 -Compress
    $manifestIdentityJson = $manifestIdentity | ConvertTo-Json -Depth 10 -Compress
    if (-not $expectedIdentityJson.Equals($manifestIdentityJson, [System.StringComparison]::Ordinal)) {
        throw 'Staged manifest frozen_capture_identity does not exactly match the capture spec.'
    }
    $captureTimes = [System.Collections.Generic.List[DateTimeOffset]]::new()
    foreach ($timeName in @('capture_started_utc', 'capture_completed_utc')) {
        $timeText = [string](Get-RequiredValue $manifest $timeName)
        $parsedTime = [DateTimeOffset]::MinValue
        $parsed = [DateTimeOffset]::TryParse(
            $timeText,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal,
            [ref]$parsedTime
        )
        if (-not $parsed -or $parsedTime.Offset -ne [TimeSpan]::Zero) {
            throw "Staged manifest '$timeName' is not a valid UTC timestamp: '$timeText'."
        }
        $frozenDate = [string](Get-RequiredValue $frozenIdentity 'capture_date_utc')
        if ($parsedTime.UtcDateTime.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) -cne $frozenDate) {
            throw "Staged manifest '$timeName' is outside frozen UTC date '$frozenDate'."
        }
        $captureTimes.Add($parsedTime)
    }
    if ($captureTimes[1] -lt $captureTimes[0]) {
        throw 'Staged manifest capture_completed_utc precedes capture_started_utc.'
    }

    $expectedFormNames = @($Spec.forms | ForEach-Object { [string](Get-RequiredValue $_ 'name') })
    $manifestForms = @($manifest.forms)
    $actualFormNames = @($manifestForms | ForEach-Object { [string](Get-RequiredValue $_ 'component_name') })
    Assert-SequenceEqual $expectedFormNames $actualFormNames 'Staged manifest form order'
    for ($formIndex = 0; $formIndex -lt $expectedFormNames.Count; $formIndex++) {
        $formSpec = @($Spec.forms)[$formIndex]
        $form = $manifestForms[$formIndex]
        $formName = $expectedFormNames[$formIndex]
        $expectedExportNames = @("$formName.frm", "$formName.frx")
        $exportedFiles = @($form.exported_files)
        $actualExportNames = @($exportedFiles | ForEach-Object { [System.IO.Path]::GetFileName([string](Get-RequiredValue $_ 'path')) })
        Assert-SequenceEqual $expectedExportNames $actualExportNames "Exported file order for $formName"
        for ($fileIndex = 0; $fileIndex -lt $expectedExportNames.Count; $fileIndex++) {
            $fileName = $expectedExportNames[$fileIndex]
            if ((Get-Item -LiteralPath (Join-Path $CaptureDirectory $fileName) -Force).Length -le 0) {
                throw "Exported file is empty: '$fileName'."
            }
            Assert-FileFactMatches `
                $exportedFiles[$fileIndex] `
                (Join-Path $CaptureDirectory $fileName) `
                (Join-Path $FinalOutputDirectory $fileName) `
                "Exported file $fileName"
        }

        $controlSpecs = @($formSpec.controls)
        $controls = @($form.controls)
        $expectedControlNames = @($controlSpecs | ForEach-Object { [string](Get-RequiredValue $_ 'name') })
        $actualControlNames = @($controls | ForEach-Object { [string](Get-RequiredValue $_ 'name') })
        Assert-SequenceEqual $expectedControlNames $actualControlNames "Control order for $formName"
        for ($controlIndex = 0; $controlIndex -lt $controlSpecs.Count; $controlIndex++) {
            $requested = Get-OptionalValue $controlSpecs[$controlIndex] 'list_items'
            $manifestRequested = Get-OptionalValue $controls[$controlIndex] 'requested_list_items'
            $manifestReadback = Get-OptionalValue $controls[$controlIndex] 'list_items_readback'
            if ($null -eq $requested) {
                if ($null -ne $manifestRequested -or $null -ne $manifestReadback) {
                    throw "Unexpected list-item provenance for control '$($expectedControlNames[$controlIndex])'."
                }
                continue
            }
            if ($null -eq $manifestRequested -or $null -eq $manifestReadback) {
                throw "Missing list-item provenance for control '$($expectedControlNames[$controlIndex])'."
            }
            Assert-SequenceEqual @($requested) @($manifestRequested) "Requested list items for $($expectedControlNames[$controlIndex])"
            $readbackItems = @((Get-RequiredValue $manifestReadback 'items'))
            $readbackCount = [int](Get-RequiredValue $manifestReadback 'list_count')
            if ($readbackCount -ne $readbackItems.Count) {
                throw "ListCount/readback-item count drift for control '$($expectedControlNames[$controlIndex])'."
            }
            Assert-SequenceEqual @($requested) $readbackItems "Actual list-item readback for $($expectedControlNames[$controlIndex])"
        }
    }

    $expectedSourcePaths = @{
        capture_tool = [System.IO.Path]::GetFullPath($PSCommandPath)
        capture_spec = if ([string]::IsNullOrWhiteSpace($ExpectedSpecPath)) { $null } else { [System.IO.Path]::GetFullPath($ExpectedSpecPath) }
    }
    foreach ($sourceName in @('capture_tool', 'capture_spec')) {
        $sourceFact = Get-RequiredValue $manifest $sourceName
        $sourcePath = Resolve-InRepoPath ([string](Get-RequiredValue $sourceFact 'path'))
        $expectedSourcePath = $expectedSourcePaths[$sourceName]
        if ($null -ne $expectedSourcePath -and -not $sourcePath.Equals($expectedSourcePath, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Manifest $sourceName path drift: expected '$expectedSourcePath', observed '$sourcePath'."
        }
        Assert-FileFactMatches $sourceFact $sourcePath $sourcePath "Manifest $sourceName"
    }
    $expectedExcel = Get-RequiredValue $frozenIdentity 'excel_executable'
    $manifestExcel = Get-RequiredValue $manifest 'excel_file'
    Assert-BinaryPathFactMatches $manifestExcel 'Actual Excel COM host executable'
    $excelProcessId = [int64](Get-RequiredValue $manifestExcel 'process_id')
    if ($excelProcessId -le 0) { throw 'Actual Excel COM host process_id must be positive.' }
    foreach ($name in @('length', 'sha256', 'file_version', 'product_version')) {
        $expectedValue = [string](Get-RequiredValue $expectedExcel $name)
        $actualValue = [string](Get-RequiredValue $manifestExcel $name)
        if (-not $expectedValue.Equals($actualValue, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Staged manifest Excel executable '$name' drift."
        }
    }
    $expectedAutomation = Get-RequiredValue $frozenIdentity 'excel_automation'
    $manifestAutomation = Get-RequiredValue $manifest 'excel_automation'
    foreach ($name in @('version', 'build', 'vbe_version')) {
        $expectedValue = [string](Get-RequiredValue $expectedAutomation $name)
        $actualValue = [string](Get-RequiredValue $manifestAutomation $name)
        if (-not $expectedValue.Equals($actualValue, [System.StringComparison]::Ordinal)) {
            throw "Staged manifest Excel automation '$name' drift."
        }
    }
    $exporterIdentity = Get-RequiredValue $manifest 'exporter_binary_identity'
    Assert-FrozenExporterBinaryIdentity `
        $frozenIdentity `
        $exporterIdentity `
        ([string](Get-RequiredValue $manifestExcel 'path'))
    if ([string](Get-RequiredValue $exporterIdentity 'status') -eq 'identified_loaded_vbe_binary') {
        if ([int64](Get-RequiredValue $exporterIdentity 'host_process_id') -ne $excelProcessId) {
            throw 'Loaded VBE binary provenance refers to a different process than the actual Excel COM host.'
        }
    }
    return $manifest
}

function Move-CapturePathToQuarantine {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Parent,
        [Parameter(Mandatory = $true)][string]$TargetLeaf
    )

    Assert-NoReparsePointTree $Path
    $quarantine = Join-Path $Parent ('.{0}.capture-obstruction-{1}' -f $TargetLeaf, [Guid]::NewGuid().ToString('N'))
    Assert-PhysicalRepoContainment $quarantine
    if (Test-Path -LiteralPath $quarantine) { throw "Fresh capture quarantine path unexpectedly exists: '$quarantine'." }
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer) {
        [System.IO.Directory]::Move($item.FullName, $quarantine)
    } else {
        [System.IO.File]::Move($item.FullName, $quarantine)
    }
    return $quarantine
}

function Publish-StagedCapture {
    param(
        [Parameter(Mandatory = $true)][string]$StagingDirectory,
        [Parameter(Mandatory = $true)][string]$TargetDirectory,
        [Parameter(Mandatory = $true)]$Spec,
        [string]$ExpectedSpecPath,
        [switch]$InjectFailureAfterBackup,
        [switch]$InjectTargetObstructionBeforeStageMove,
        [switch]$InjectPostPromotionValidationFailure
    )

    [void](Test-StagedCapture $StagingDirectory $TargetDirectory $Spec $ExpectedSpecPath)
    Assert-PhysicalRepoContainment $TargetDirectory
    if (Test-Path -LiteralPath $TargetDirectory) {
        Assert-NoReparsePointTree $TargetDirectory
        if (-not (Get-Item -LiteralPath $TargetDirectory -Force).PSIsContainer) {
            throw "Capture target is not a directory: '$TargetDirectory'."
        }
    }

    $parent = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($TargetDirectory))
    $backup = Join-Path $parent ('.{0}.capture-backup-{1}' -f [System.IO.Path]::GetFileName($TargetDirectory), [Guid]::NewGuid().ToString('N'))
    Assert-PhysicalRepoContainment $backup
    if (Test-Path -LiteralPath $backup) { throw "Fresh capture backup path unexpectedly exists: '$backup'." }

    $hadTarget = Test-Path -LiteralPath $TargetDirectory
    $targetMovedToBackup = $false
    $stageMovedToTarget = $false
    $quarantinedPath = $null
    try {
        if ($hadTarget) {
            [System.IO.Directory]::Move($TargetDirectory, $backup)
            $targetMovedToBackup = $true
        }
        if ($InjectFailureAfterBackup) { throw 'Injected promotion failure after authoritative-output backup.' }
        if ($InjectTargetObstructionBeforeStageMove) {
            [void][System.IO.Directory]::CreateDirectory($TargetDirectory)
            [System.IO.File]::WriteAllText((Join-Path $TargetDirectory 'injected-obstruction.marker'), 'obstruction', $utf8NoBom)
        }
        [System.IO.Directory]::Move($StagingDirectory, $TargetDirectory)
        $stageMovedToTarget = $true
        if ($InjectPostPromotionValidationFailure) { throw 'Injected post-promotion validation failure.' }
        [void](Test-StagedCapture $TargetDirectory $TargetDirectory $Spec $ExpectedSpecPath)
    } catch {
        $promotionError = $_
        if ($stageMovedToTarget -and (Test-Path -LiteralPath $TargetDirectory) -and -not (Test-Path -LiteralPath $StagingDirectory)) {
            try {
                [System.IO.Directory]::Move($TargetDirectory, $StagingDirectory)
                $stageMovedToTarget = $false
            } catch {
                try {
                    $quarantinedPath = Move-CapturePathToQuarantine $TargetDirectory $parent ([System.IO.Path]::GetFileName($TargetDirectory))
                    $stageMovedToTarget = $false
                } catch {
                    throw "Capture promotion failed and the promoted output could not be quarantined for rollback. Backup='$backup'; target='$TargetDirectory'; error='$($promotionError.Exception.Message)'; rollback_error='$($_.Exception.Message)'."
                }
            }
        }
        if ($targetMovedToBackup -and (Test-Path -LiteralPath $TargetDirectory)) {
            try {
                $quarantinedPath = Move-CapturePathToQuarantine $TargetDirectory $parent ([System.IO.Path]::GetFileName($TargetDirectory))
            } catch {
                throw "Capture promotion failed and an obstructing target could not be quarantined for rollback. Backup='$backup'; target='$TargetDirectory'; error='$($promotionError.Exception.Message)'; rollback_error='$($_.Exception.Message)'."
            }
        }
        if ($targetMovedToBackup) {
            if (-not (Test-Path -LiteralPath $backup -PathType Container) -or (Test-Path -LiteralPath $TargetDirectory)) {
                throw "Capture promotion failed and authoritative-output rollback prerequisites were not met. Backup='$backup'; target='$TargetDirectory'; error='$($promotionError.Exception.Message)'."
            }
            try {
                [System.IO.Directory]::Move($backup, $TargetDirectory)
                $targetMovedToBackup = $false
            } catch {
                throw "Capture promotion failed and authoritative-output rollback failed. Backup='$backup'; target='$TargetDirectory'; error='$($promotionError.Exception.Message)'; rollback_error='$($_.Exception.Message)'."
            }
        }
        if ($null -ne $quarantinedPath) {
            Write-Warning "Capture rollback restored the authoritative target and preserved an obstruction at '$quarantinedPath'."
        }
        throw $promotionError
    }

    if ($targetMovedToBackup -and (Test-Path -LiteralPath $backup)) {
        try {
            Remove-SafeCaptureDirectory $backup
        } catch {
            Write-Warning "Capture promotion succeeded, but the old-output backup could not be removed: '$backup': $($_.Exception.Message)"
        }
    }
}

function New-SafetySelfTestCapture {
    param(
        [Parameter(Mandatory = $true)][string]$StagingDirectory,
        [Parameter(Mandatory = $true)][string]$TargetDirectory,
        [Parameter(Mandatory = $true)]$Spec,
        [Parameter(Mandatory = $true)][string]$ActualSpecPath
    )

    $formName = [string](Get-RequiredValue @($Spec.forms)[0] 'name')
    $frmPath = Join-Path $StagingDirectory "$formName.frm"
    $frxPath = Join-Path $StagingDirectory "$formName.frx"
    [System.IO.File]::WriteAllText($frmPath, "VERSION 5.00`r`n", $utf8NoBom)
    [System.IO.File]::WriteAllBytes($frxPath, [byte[]](0..31))
    $controlRecords = @(@($Spec.forms)[0].controls | ForEach-Object {
        $requestedItems = @((Get-RequiredValue $_ 'list_items') | ForEach-Object { [string]$_ })
        $geometry = Get-RequiredValue $_ 'geometry'
        $geometryReadback = [ordered]@{
            left = [double](Get-RequiredValue $geometry 'left')
            top = [double](Get-RequiredValue $geometry 'top')
            width = [double](Get-RequiredValue $geometry 'width')
            height = [double](Get-RequiredValue $geometry 'height')
        }
        $geometryObservation = Get-GeometryObservationResult $_ $geometryReadback
        [ordered]@{
            name = [string](Get-RequiredValue $_ 'name')
            family = [string](Get-RequiredValue $_ 'family')
            progid = [string](Get-RequiredValue $_ 'progid')
            container = [string](Get-RequiredValue $_ 'container')
            geometry_requested = $geometryObservation.requested
            geometry_readback = $geometryReadback
            geometry_result = $geometryObservation.result
            properties = @()
            requested_list_items = $requestedItems
            list_items_readback = [ordered]@{
                list_count = $requestedItems.Count
                items = $requestedItems
            }
            pages = @()
            tabs = @()
        }
    })
    $testFrozenIdentity = Get-RequiredValue $Spec 'frozen_capture_identity'
    $testVbeBinary = Get-RequiredValue $testFrozenIdentity 'vbe_binary'
    $testExcelBinary = Get-RequiredValue $testFrozenIdentity 'excel_executable'
    $testCaptureDate = [string](Get-RequiredValue $testFrozenIdentity 'capture_date_utc')
    $testProcessPath = [Environment]::ProcessPath
    $testCodeLines = @(@($Spec.forms)[0].code_lines | ForEach-Object { [string]$_ })
    $testCodeText = ($testCodeLines -join "`r`n") + "`r`n"
    $testCodeHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($utf8NoBom.GetBytes($testCodeText))).ToLowerInvariant()
    $manifest = [ordered]@{
        schema = 'oxforms.forms-persistence.live-export-capture.v2'
        capture_id = [string](Get-RequiredValue $Spec 'capture_id')
        profile = [string](Get-RequiredValue $Spec 'profile')
        frozen_capture_identity = Get-RequiredValue $Spec 'frozen_capture_identity'
        authority_class = 'observed_real_office_export'
        capture_started_utc = "${testCaptureDate}T00:00:00.0000000Z"
        capture_completed_utc = "${testCaptureDate}T00:00:01.0000000Z"
        clean_room = [ordered]@{
            project_authored_inputs = $true
            third_party_form_content = $false
            public_automation_only = $true
            transient_workbook_saved = $false
        }
        git = [ordered]@{ head = ('0' * 40); dirty = $false; status_line_count = 0 }
        capture_tool = Get-FileFact $PSCommandPath
        capture_spec = Get-FileFact $ActualSpecPath
        environment = [ordered]@{
            os_version = 'self-test'
            os_architecture = 'self-test'
            process_architecture = 'self-test'
            culture = 'self-test'
            ui_culture = 'self-test'
            ansi_code_page = 1252
            oem_code_page = 437
            powershell_version = $PSVersionTable.PSVersion.ToString()
        }
        excel_file = [ordered]@{
            process_id = [int64]$PID
            path = $testProcessPath
            length = [int64](Get-RequiredValue $testExcelBinary 'length')
            sha256 = [string](Get-RequiredValue $testExcelBinary 'sha256')
            file_version = [string](Get-RequiredValue $testExcelBinary 'file_version')
            product_version = [string](Get-RequiredValue $testExcelBinary 'product_version')
        }
        excel_automation = [ordered]@{
            application_name = 'Microsoft Excel'
            version = 'self-test'
            build = 'self-test'
            vbe_version = 'self-test'
            access_vbom = $true
            component_type = 3
            export_api = 'VBComponent.Export'
            workbook_saved = $false
        }
        exporter_binary_identity = [ordered]@{
            status = 'identified_loaded_vbe_binary'
            host_process_id = [int64]$PID
            attribution_basis = $identifiedExporterAttributionBasis
            claim_scope = $identifiedExporterClaimScope
            binary = [ordered]@{
                module_name = [string](Get-RequiredValue $testVbeBinary 'module_name')
                module_reported_path = Join-Path ([System.IO.Path]::GetDirectoryName($TargetDirectory)) 'VBE7.DLL'
                path = Join-Path ([System.IO.Path]::GetDirectoryName($TargetDirectory)) 'VBE7.DLL'
                path_resolution_basis = $directModulePathResolutionBasis
                path_resolution_caveat = $directModulePathResolutionCaveat
                length = [int64](Get-RequiredValue $testVbeBinary 'length')
                sha256 = [string](Get-RequiredValue $testVbeBinary 'sha256')
                file_version = [string](Get-RequiredValue $testVbeBinary 'file_version')
                product_version = [string](Get-RequiredValue $testVbeBinary 'product_version')
                original_filename = [string](Get-RequiredValue $testVbeBinary 'module_name')
            }
        }
        progid_registrations = @(@(
            @($Spec.forms | ForEach-Object { @($_.controls) }) | ForEach-Object {
                [string](Get-RequiredValue $_ 'progid')
            }
            @($Spec.designer_add_probes | ForEach-Object {
                [string](Get-RequiredValue $_ 'progid')
            })
        ) | Sort-Object -CaseSensitive -Unique | ForEach-Object {
            [ordered]@{
                progid = $_
                clsid = $null
                class_name = $null
                inproc_server = $null
            }
        })
        forms = @(
            [ordered]@{
                fixture_id = [string](Get-RequiredValue @($Spec.forms)[0] 'fixture_id')
                component_name = $formName
                component_properties = @()
                controls = $controlRecords
                code_input = [ordered]@{
                    line_count = $testCodeLines.Count
                    utf8_sha256 = $testCodeHash
                }
                exported_files = @(
                    Get-FileFact $frmPath (Join-Path $TargetDirectory "$formName.frm")
                    Get-FileFact $frxPath (Join-Path $TargetDirectory "$formName.frx")
                )
            }
        )
        designer_add_probes = @($Spec.designer_add_probes | ForEach-Object {
            [ordered]@{
                family = [string](Get-RequiredValue $_ 'family')
                progid = [string](Get-RequiredValue $_ 'progid')
                expected = [string](Get-RequiredValue $_ 'expected')
                added = $false
                error = 'Safety self-test designer-add rejection.'
                hresult = $designerAddRejectedHresult
            }
        })
    }
    $manifestPath = Join-Path $StagingDirectory 'capture_manifest.v2.json'
    [System.IO.File]::WriteAllText(
        $manifestPath,
        ($manifest | ConvertTo-Json -Depth 20) + "`n",
        $utf8NoBom
    )
}

function Invoke-CaptureSafetySelfTest {
    param([Parameter(Mandatory = $true)][string]$ActualSpecPath)

    Initialize-ExporterModuleDiscovery
    if ($null -eq ('OxFormsCapture.NativeMethods' -as [type])) {
        throw 'Safety self-test failed: exporter module-discovery native type did not compile.'
    }
    if ($null -eq (Get-Command Assert-FrozenExporterBinaryIdentity -CommandType Function -ErrorAction SilentlyContinue)) {
        throw 'Safety self-test failed: frozen exporter identity validator is unavailable.'
    }

    $fixtureRoot = Resolve-InRepoPath 'fixtures/forms-persistence'
    Assert-PhysicalRepoContainment $fixtureRoot
    $testId = [Guid]::NewGuid().ToString('N')
    $testRoot = Join-Path $fixtureRoot ".capture-safety-self-test-$testId"
    $testNow = [DateTime]::UtcNow
    $testDate = $testNow.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $testDateToken = $testDate.Replace('-', '')
    $testProcessFile = Get-Item -LiteralPath ([Environment]::ProcessPath) -Force
    $testExcelVersion = [string]$testProcessFile.VersionInfo.FileVersion
    $target = Join-Path $testRoot "$testDateToken-excel-$testExcelVersion"
    $stage = Join-Path $testRoot '.capture-staging'
    $junction = Join-Path $testRoot '.capture-junction'
    $testVbePath = Join-Path $testRoot 'VBE7.DLL'
    $testVbeBytes = [Text.Encoding]::ASCII.GetBytes('OxForms VBE identity self-test')
    $testVbeSha = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($testVbeBytes)).ToLowerInvariant()
    $identity = [ordered]@{
        capture_date_utc = $testDate
        output_directory = Convert-ToRepoPath $target
        excel_executable = [ordered]@{
            length = [int64]$testProcessFile.Length
            sha256 = (Get-FileHash -LiteralPath $testProcessFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            file_version = $testExcelVersion
            product_version = [string]$testProcessFile.VersionInfo.ProductVersion
        }
        excel_automation = [ordered]@{ version = 'self-test'; build = 'self-test'; vbe_version = 'self-test' }
        vbe_binary = [ordered]@{
            module_name = 'VBE7.DLL'
            length = [int64]$testVbeBytes.Length
            sha256 = $testVbeSha
            file_version = ''
            product_version = ''
        }
    }
    $testSpec = [pscustomobject][ordered]@{
        schema = 'oxforms.forms-persistence.capture-spec.v1'
        capture_id = "safety-self-test-$testDateToken"
        profile = 'office_vba_userform_export'
        frozen_capture_identity = [pscustomobject]$identity
        designer_add_probes = @(
            [pscustomobject][ordered]@{
                family = 'HTMLSubmit'
                progid = 'SelfTest.HTMLSubmit.1'
                expected = 'rejected'
            }
        )
        forms = @(
            [pscustomobject][ordered]@{
                fixture_id = 'safety-self-test'
                name = 'SafetySelfTestForm'
                component_properties = @()
                controls = @(
                    [pscustomobject][ordered]@{
                        name = 'SafetyList'
                        family = 'ListBox'
                        progid = 'SelfTest.ListBox.1'
                        container = 'root'
                        geometry = [pscustomobject][ordered]@{
                            left = 1.0
                            top = 2.0
                            width = 3.0
                            height = 4.0
                        }
                        list_items = @('one', 'two')
                        properties = @()
                    }
                )
                code_lines = @('Option Explicit')
            }
        )
    }

    try {
        Assert-PhysicalRepoContainment $testRoot
        [void][System.IO.Directory]::CreateDirectory($testRoot)
        Assert-PhysicalRepoContainment $testRoot
        [System.IO.File]::WriteAllBytes($testVbePath, $testVbeBytes)

        # ProcessModule.FileVersionInfo may be blank even when ModuleName and
        # FileName are usable. Discovery must filter on ModuleName first and
        # derive every version/hash fact from the resolved backing file.
        $fakeOfficeRoot = Join-Path $testRoot 'fake-office-root'
        $fakeExcelPath = Join-Path $fakeOfficeRoot 'Office16\EXCEL.EXE'
        [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($fakeExcelPath))
        [System.IO.File]::WriteAllBytes($fakeExcelPath, [byte[]](1..8))
        $fakeSuffix = Join-Path "OxFormsCaptureSelfTest-$testId" 'VBE7.DLL'
        $fakeReportedPath = Join-Path ([string]$env:CommonProgramFiles) $fakeSuffix
        if (Test-Path -LiteralPath $fakeReportedPath) { throw "Safety self-test virtual module path unexpectedly exists: '$fakeReportedPath'." }
        $fakeBackingPath = Join-Path $fakeOfficeRoot (Join-Path 'vfs\ProgramFilesCommonX64' $fakeSuffix)
        [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($fakeBackingPath))
        [System.IO.File]::WriteAllBytes($fakeBackingPath, $testVbeBytes)
        $blankModuleMetadata = [pscustomobject]@{ OriginalFilename = ''; FileVersion = '' }
        $fakeModules = @(
            [pscustomobject]@{ ModuleName = 'UNRELATED.DLL'; FileName = ''; FileVersionInfo = $blankModuleMetadata },
            [pscustomobject]@{ ModuleName = 'VBE7.DLL'; FileName = $fakeReportedPath; FileVersionInfo = $blankModuleMetadata }
        )
        $fakeCandidates = @(Get-LoadedVbeBinaryCandidates $fakeModules $fakeExcelPath)
        if ($fakeCandidates.Count -ne 1 -or
            [string]$fakeCandidates[0].path_resolution_basis -cne $clickToRunModulePathResolutionBasis -or
            -not ([string]$fakeCandidates[0].path).Equals($fakeBackingPath, [System.StringComparison]::OrdinalIgnoreCase) -or
            [string]$fakeCandidates[0].sha256 -cne $testVbeSha) {
            throw 'Safety self-test failed: blank module metadata / Click-to-Run backing resolution drift.'
        }
        [void](Assert-FrozenOutputIdentity $testSpec $target)
        Assert-FrozenCaptureDate $identity $testNow
        $dateDriftRejected = $false
        try { Assert-FrozenCaptureDate $identity ($testNow.AddDays(1)) } catch { $dateDriftRejected = $true }
        if (-not $dateDriftRejected) { throw 'Safety self-test failed: frozen UTC date drift was accepted.' }
        $unknownExporterRejected = $false
        try {
            Assert-FrozenExporterBinaryIdentity $identity ([ordered]@{
                status = 'unknown'
                reason_code = 'safety_self_test'
                nonclaim = 'No exact exporter binary identity is asserted.'
            })
        } catch {
            $unknownExporterRejected = $true
        }
        if (-not $unknownExporterRejected) { throw 'Safety self-test failed: unknown exporter identity was accepted.' }

        $normalizationBasis = 'Safety self-test deterministic MSForms normalization.'
        $normalizationSpec = [pscustomobject][ordered]@{
            name = 'NormalizedGeometry'
            geometry = [pscustomobject][ordered]@{ left = 1.0; top = 2.0; width = 120.0; height = 60.0 }
            geometry_readback_expectation = [pscustomobject][ordered]@{
                classification = 'expected_msforms_normalization'
                values = [pscustomobject][ordered]@{ left = 1.0; top = 2.0; width = 120.0; height = 49.150001525878906 }
                basis = $normalizationBasis
            }
        }
        $normalizedReadback = [ordered]@{ left = 1.0; top = 2.0; width = 120.0; height = 49.150001525878906 }
        $normalizationResult = Get-GeometryObservationResult $normalizationSpec $normalizedReadback
        if ([string]$normalizationResult.result.classification -cne 'expected_msforms_normalization' -or
            @($normalizationResult.result.changed_fields).Count -ne 1 -or
            [string]$normalizationResult.result.changed_fields[0] -cne 'height' -or
            [string]$normalizationResult.result.basis -cne $normalizationBasis) {
            throw 'Safety self-test failed: expected geometry normalization provenance drift.'
        }
        $unexpectedGeometryRejected = $false
        try {
            [void](Get-GeometryObservationResult $normalizationSpec ([ordered]@{
                left = 1.0; top = 2.0; width = 120.0; height = 49.0
            }))
        } catch { $unexpectedGeometryRejected = $true }
        if (-not $unexpectedGeometryRejected) { throw 'Safety self-test failed: unpinned geometry normalization was accepted.' }
        $nonFiniteGeometryRejected = $false
        try {
            [void](Get-GeometryObservationResult $normalizationSpec ([ordered]@{
                left = 1.0; top = 2.0; width = [double]::PositiveInfinity; height = 49.150001525878906
            }))
        } catch { $nonFiniteGeometryRejected = $true }
        if (-not $nonFiniteGeometryRejected) { throw 'Safety self-test failed: non-finite geometry readback was accepted.' }

        # A complete validated stage replaces the target only after the target
        # has been renamed to a rollback location.
        [void][System.IO.Directory]::CreateDirectory($target)
        [System.IO.File]::WriteAllText((Join-Path $target 'authoritative.marker'), 'old', $utf8NoBom)
        [void][System.IO.Directory]::CreateDirectory($stage)
        New-SafetySelfTestCapture $stage $target $testSpec $ActualSpecPath
        Publish-StagedCapture $stage $target $testSpec -ExpectedSpecPath $ActualSpecPath
        if (Test-Path -LiteralPath (Join-Path $target 'authoritative.marker')) {
            throw 'Safety self-test failed: old target survived successful promotion.'
        }
        [void](Test-StagedCapture $target $target $testSpec $ActualSpecPath)
        Remove-SafeCaptureDirectory $target

        # An injected failure after backup must restore the authoritative
        # directory and preserve the fully validated stage.
        [void][System.IO.Directory]::CreateDirectory($target)
        [System.IO.File]::WriteAllText((Join-Path $target 'authoritative.marker'), 'old', $utf8NoBom)
        [void][System.IO.Directory]::CreateDirectory($stage)
        New-SafetySelfTestCapture $stage $target $testSpec $ActualSpecPath
        $injectedFailureObserved = $false
        try {
            Publish-StagedCapture $stage $target $testSpec -ExpectedSpecPath $ActualSpecPath -InjectFailureAfterBackup
        } catch {
            $injectedFailureObserved = $_.Exception.Message.Contains('Injected promotion failure', [System.StringComparison]::Ordinal)
        }
        if (-not $injectedFailureObserved -or -not (Test-Path -LiteralPath (Join-Path $target 'authoritative.marker'))) {
            throw 'Safety self-test failed: promotion rollback did not restore the authoritative target.'
        }
        if (-not (Test-Path -LiteralPath $stage -PathType Container)) {
            throw 'Safety self-test failed: validated stage was not preserved after promotion failure.'
        }
        Remove-SafeCaptureDirectory $target
        Remove-SafeCaptureDirectory $stage

        # A target path appearing after backup must be quarantined so the old
        # authoritative directory can still be restored.
        [void][System.IO.Directory]::CreateDirectory($target)
        [System.IO.File]::WriteAllText((Join-Path $target 'authoritative.marker'), 'old', $utf8NoBom)
        [void][System.IO.Directory]::CreateDirectory($stage)
        New-SafetySelfTestCapture $stage $target $testSpec $ActualSpecPath
        $obstructedFailureObserved = $false
        try {
            Publish-StagedCapture $stage $target $testSpec -ExpectedSpecPath $ActualSpecPath -InjectTargetObstructionBeforeStageMove
        } catch {
            $obstructedFailureObserved = $true
        }
        if (-not $obstructedFailureObserved -or -not (Test-Path -LiteralPath (Join-Path $target 'authoritative.marker'))) {
            throw 'Safety self-test failed: obstructed promotion did not restore the authoritative target.'
        }
        $quarantines = @(Get-ChildItem -LiteralPath $testRoot -Force -Directory | Where-Object Name -like '*.capture-obstruction-*')
        if ($quarantines.Count -lt 1) { throw 'Safety self-test failed: promotion obstruction was not preserved in quarantine.' }
        Remove-SafeCaptureDirectory $target
        Remove-SafeCaptureDirectory $stage

        # A failure after stage->target must move the promoted output back out
        # and restore the prior authoritative directory.
        [void][System.IO.Directory]::CreateDirectory($target)
        [System.IO.File]::WriteAllText((Join-Path $target 'authoritative.marker'), 'old', $utf8NoBom)
        [void][System.IO.Directory]::CreateDirectory($stage)
        New-SafetySelfTestCapture $stage $target $testSpec $ActualSpecPath
        $postValidationFailureObserved = $false
        try {
            Publish-StagedCapture $stage $target $testSpec -ExpectedSpecPath $ActualSpecPath -InjectPostPromotionValidationFailure
        } catch {
            $postValidationFailureObserved = $_.Exception.Message.Contains('Injected post-promotion', [System.StringComparison]::Ordinal)
        }
        if (-not $postValidationFailureObserved -or -not (Test-Path -LiteralPath (Join-Path $target 'authoritative.marker'))) {
            throw 'Safety self-test failed: post-promotion failure did not restore the authoritative target.'
        }
        if (-not (Test-Path -LiteralPath $stage -PathType Container)) {
            throw 'Safety self-test failed: promoted stage was not recovered after post-promotion failure.'
        }
        Remove-SafeCaptureDirectory $target
        Remove-SafeCaptureDirectory $stage

        # Exact staged file-set validation must reject additions.
        [void][System.IO.Directory]::CreateDirectory($stage)
        New-SafetySelfTestCapture $stage $target $testSpec $ActualSpecPath
        [System.IO.File]::WriteAllText((Join-Path $stage 'unexpected.txt'), 'unexpected', $utf8NoBom)
        $unexpectedRejected = $false
        try { [void](Test-StagedCapture $stage $target $testSpec $ActualSpecPath) } catch { $unexpectedRejected = $true }
        if (-not $unexpectedRejected) { throw 'Safety self-test failed: unexpected staged file was accepted.' }
        Remove-SafeCaptureDirectory $stage

        # Requested list content and indexed list readback are distinct fields,
        # but the controlled fixture must still prove that they match.
        [void][System.IO.Directory]::CreateDirectory($stage)
        New-SafetySelfTestCapture $stage $target $testSpec $ActualSpecPath
        $listManifestPath = Join-Path $stage 'capture_manifest.v2.json'
        $listManifest = Get-Content -Raw -LiteralPath $listManifestPath | ConvertFrom-Json
        $listManifest.forms[0].controls[0].list_items_readback.items[1] = 'drifted'
        [System.IO.File]::WriteAllText(
            $listManifestPath,
            ($listManifest | ConvertTo-Json -Depth 20) + "`n",
            $utf8NoBom
        )
        $listDriftRejected = $false
        try { [void](Test-StagedCapture $stage $target $testSpec $ActualSpecPath) } catch { $listDriftRejected = $true }
        if (-not $listDriftRejected) { throw 'Safety self-test failed: list-item readback drift was accepted.' }
        Remove-SafeCaptureDirectory $stage

        # Designer-add rejection is an exact observed contract: neither a
        # different HRESULT nor a truthy/falsy non-boolean may reach promotion.
        [void][System.IO.Directory]::CreateDirectory($stage)
        New-SafetySelfTestCapture $stage $target $testSpec $ActualSpecPath
        $probeManifestPath = Join-Path $stage 'capture_manifest.v2.json'
        $probeManifest = Get-Content -Raw -LiteralPath $probeManifestPath | ConvertFrom-Json
        $probeManifest.designer_add_probes[0].hresult = '0x80004005'
        [System.IO.File]::WriteAllText(
            $probeManifestPath,
            ($probeManifest | ConvertTo-Json -Depth 20) + "`n",
            $utf8NoBom
        )
        $wrongHresultRejected = $false
        try { [void](Test-StagedCapture $stage $target $testSpec $ActualSpecPath) } catch {
            $wrongHresultRejected = $_.Exception.Message.Contains('rejection HRESULT drift', [System.StringComparison]::Ordinal)
        }
        if (-not $wrongHresultRejected) { throw 'Safety self-test failed: wrong designer-add rejection HRESULT was accepted.' }
        Remove-SafeCaptureDirectory $stage

        [void][System.IO.Directory]::CreateDirectory($stage)
        New-SafetySelfTestCapture $stage $target $testSpec $ActualSpecPath
        $probeManifestPath = Join-Path $stage 'capture_manifest.v2.json'
        $probeManifest = Get-Content -Raw -LiteralPath $probeManifestPath | ConvertFrom-Json
        $probeManifest.designer_add_probes[0].added = ''
        [System.IO.File]::WriteAllText(
            $probeManifestPath,
            ($probeManifest | ConvertTo-Json -Depth 20) + "`n",
            $utf8NoBom
        )
        $nonBooleanAddedRejected = $false
        try { [void](Test-StagedCapture $stage $target $testSpec $ActualSpecPath) } catch {
            $nonBooleanAddedRejected = $_.Exception.Message.Contains("'added' must be a boolean", [System.StringComparison]::Ordinal)
        }
        if (-not $nonBooleanAddedRejected) { throw 'Safety self-test failed: non-boolean designer-add outcome was accepted.' }
        Remove-SafeCaptureDirectory $stage

        # A staged export changed after manifest hashing must be rejected before
        # the authoritative directory is renamed or otherwise touched.
        [void][System.IO.Directory]::CreateDirectory($target)
        [System.IO.File]::WriteAllText((Join-Path $target 'authoritative.marker'), 'old', $utf8NoBom)
        [void][System.IO.Directory]::CreateDirectory($stage)
        New-SafetySelfTestCapture $stage $target $testSpec $ActualSpecPath
        [System.IO.File]::AppendAllText((Join-Path $stage 'SafetySelfTestForm.frm'), "changed`r`n", $utf8NoBom)
        $hashDriftRejected = $false
        try {
            Publish-StagedCapture $stage $target $testSpec -ExpectedSpecPath $ActualSpecPath
        } catch {
            $hashDriftRejected = $true
        }
        if (-not $hashDriftRejected -or -not (Test-Path -LiteralPath (Join-Path $target 'authoritative.marker'))) {
            throw 'Safety self-test failed: staged hash drift touched the authoritative target.'
        }
        Remove-SafeCaptureDirectory $target
        Remove-SafeCaptureDirectory $stage

        # A junction in any output path component must be rejected before use.
        [void](New-Item -ItemType Junction -Path $junction -Target $fixtureRoot -ErrorAction Stop)
        $junctionRejected = $false
        try { Assert-PhysicalRepoContainment (Join-Path $junction 'child') } catch { $junctionRejected = $true }
        if (-not $junctionRejected) { throw 'Safety self-test failed: junction path was accepted.' }
        [System.IO.Directory]::Delete($junction)
        $junction = $null
    } finally {
        foreach ($path in @($stage, $target)) {
            if ($null -ne $path -and (Test-Path -LiteralPath $path)) {
                try { Remove-SafeCaptureDirectory $path } catch { Write-Warning $_.Exception.Message }
            }
        }
        if ($null -ne $junction -and (Test-Path -LiteralPath $junction)) {
            try { [System.IO.Directory]::Delete($junction) } catch { Write-Warning $_.Exception.Message }
        }
        if (Test-Path -LiteralPath $testRoot) {
            try { Remove-SafeCaptureDirectory $testRoot } catch { Write-Warning $_.Exception.Message }
        }
    }
    Write-Host 'Capture safety self-test passed without launching Excel.'
}

if ($RunSafetySelfTest) {
    Invoke-CaptureSafetySelfTest (Resolve-InRepoPath $SpecPath)
    return
}

$resolvedSpecPath = Resolve-InRepoPath $SpecPath
if (-not (Test-Path -LiteralPath $resolvedSpecPath -PathType Leaf)) {
    throw "Capture spec not found: $resolvedSpecPath"
}
$spec = Get-Content -Raw -LiteralPath $resolvedSpecPath | ConvertFrom-Json
if ([string](Get-RequiredValue $spec 'schema') -ne 'oxforms.forms-persistence.capture-spec.v1') {
    throw "Unexpected capture spec schema."
}

$resolvedOutputDir = Resolve-InRepoPath $OutputDir
$requiredOutputRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'fixtures\forms-persistence'))
if (-not (Test-PathIsWithin $resolvedOutputDir $requiredOutputRoot) -or $resolvedOutputDir.Equals(
    $requiredOutputRoot,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Capture output must be below fixtures/forms-persistence."
}
$frozenCaptureIdentity = Assert-FrozenOutputIdentity $spec $resolvedOutputDir
if (-not $SafetyCheckOnly) {
    Assert-FrozenCaptureDate $frozenCaptureIdentity
}
Assert-PhysicalRepoContainment $requiredOutputRoot
if (Test-Path -LiteralPath $resolvedOutputDir) {
    Assert-NoReparsePointTree $resolvedOutputDir
    if (-not (Get-Item -LiteralPath $resolvedOutputDir -Force).PSIsContainer) {
        throw "Capture output exists but is not a directory: '$resolvedOutputDir'."
    }
}

$captureStartedUtc = [DateTime]::UtcNow.ToString('o')
$gitState = Get-GitCaptureState
$scriptFact = Get-FileFact $PSCommandPath
$specFact = Get-FileFact $resolvedSpecPath

$excelCommand = Get-Command excel.exe -ErrorAction SilentlyContinue
$excelPath = if ($null -ne $excelCommand) { $excelCommand.Source } else { $null }
if ([string]::IsNullOrWhiteSpace($excelPath)) {
    $excelPath = Get-ItemPropertyValue -LiteralPath 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\excel.exe' -Name '(default)' -ErrorAction SilentlyContinue
}
if ([string]::IsNullOrWhiteSpace($excelPath) -or -not (Test-Path -LiteralPath $excelPath -PathType Leaf)) {
    throw 'Microsoft Excel executable was not found.'
}
$excelFile = Get-Item -LiteralPath $excelPath
$excelExecutableIdentity = Assert-FrozenExcelExecutableIdentity $frozenCaptureIdentity $excelFile

if ($SafetyCheckOnly) {
    Write-Host 'Capture safety check passed without launching Excel.'
    Write-Host "Frozen output: $resolvedOutputDir"
    Write-Host "Excel binary: $($excelFile.FullName)"
    return
}
if ((Test-Path -LiteralPath $resolvedOutputDir) -and -not $Force) {
    throw "Frozen capture output already exists. Pass -Force to stage and replace it only after complete validation: $resolvedOutputDir"
}

$distinctProgIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($formSpec in @($spec.forms)) {
    foreach ($controlSpec in @($formSpec.controls)) {
        [void]$distinctProgIds.Add([string](Get-RequiredValue $controlSpec 'progid'))
    }
}
foreach ($probeSpec in @($spec.designer_add_probes)) {
    [void]$distinctProgIds.Add([string](Get-RequiredValue $probeSpec 'progid'))
}
$registrations = @($distinctProgIds | Sort-Object | ForEach-Object { Get-ProgIdRegistration $_ })

$captureWorkingDir = New-CaptureStagingDirectory $resolvedOutputDir
$promotionAttempted = $false

$excel = $null
$workbook = $null
$vbProject = $null
$probeComponent = $null
$probeDesigner = $null
$formObservations = [System.Collections.Generic.List[object]]::new()
$addProbeObservations = [System.Collections.Generic.List[object]]::new()
$excelAutomation = $null
$excelHostProcessIdentity = $null
$exporterBinaryIdentity = [ordered]@{
    status = 'unknown'
    host_process_id = $null
    reason_code = 'not_observed'
    nonclaim = 'No exact exporter binary identity is asserted.'
    candidates = @()
}

try {
try {
    try {
        $excel = New-Object -ComObject Excel.Application
    } catch {
        throw "Microsoft Excel COM automation is unavailable: $($_.Exception.Message)"
    }
    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    $workbook = $excel.Workbooks.Add()
    try {
        $vbProject = $workbook.VBProject
    } catch {
        throw "Excel blocked access to the VBA project object model. Enable 'Trust access to the VBA project object model'."
    }

    $vbeVersion = $null
    try { $vbeVersion = [string]$excel.VBE.Version } catch {}
    $excelAutomation = [ordered]@{
        application_name = [string]$excel.Name
        version = [string]$excel.Version
        build = [string]$excel.Build
        vbe_version = $vbeVersion
        access_vbom = $true
        component_type = 3
        export_api = 'VBComponent.Export'
        workbook_saved = $false
    }
    Assert-FrozenExcelAutomationIdentity $frozenCaptureIdentity $excelAutomation
    $excelHostProcessIdentity = Get-ExcelHostProcessIdentity $excel
    Assert-FrozenExcelProcessIdentity $frozenCaptureIdentity $excelHostProcessIdentity
    $exporterBinaryIdentity = Get-ExporterBinaryIdentity `
        $excel `
        ([int64]$excelHostProcessIdentity.process_id) `
        ([string]$excelHostProcessIdentity.path)
    Assert-FrozenExporterBinaryIdentity `
        $frozenCaptureIdentity `
        $exporterBinaryIdentity `
        ([string]$excelHostProcessIdentity.path)

    foreach ($formSpec in @($spec.forms)) {
        $component = $null
        $designer = $null
        $trackedComObjects = [System.Collections.Generic.List[object]]::new()
        try {
            $component = $vbProject.VBComponents.Add(3)
            $trackedComObjects.Add($component)
            $component.Name = [string](Get-RequiredValue $formSpec 'name')
            $designer = $component.Designer
            $trackedComObjects.Add($designer)

            $componentPropertyObservations = [System.Collections.Generic.List[object]]::new()
            foreach ($propertySpec in @($formSpec.component_properties)) {
                $componentPropertyObservations.Add((Set-ComponentProperty $component $propertySpec))
            }

            $controlMap = @{}
            $pageMap = @{}
            $controlObservations = [System.Collections.Generic.List[object]]::new()
            foreach ($controlSpec in @($formSpec.controls)) {
                $controlName = [string](Get-RequiredValue $controlSpec 'name')
                $progid = [string](Get-RequiredValue $controlSpec 'progid')
                $container = [string](Get-RequiredValue $controlSpec 'container')
                $controlsCollection = $null
                if ($container -eq 'root') {
                    $controlsCollection = $designer.Controls
                } elseif ($container.StartsWith('control:', [System.StringComparison]::Ordinal)) {
                    $parentName = $container.Substring('control:'.Length)
                    if (-not $controlMap.ContainsKey($parentName)) { throw "Unknown parent control '$parentName'." }
                    $controlsCollection = $controlMap[$parentName].Controls
                } elseif ($container.StartsWith('page:', [System.StringComparison]::Ordinal)) {
                    $pageName = $container.Substring('page:'.Length)
                    if (-not $pageMap.ContainsKey($pageName)) { throw "Unknown page '$pageName'." }
                    $controlsCollection = $pageMap[$pageName].Controls
                } else {
                    throw "Unsupported container reference '$container'."
                }
                $trackedComObjects.Add($controlsCollection)
                $created = $controlsCollection.Add($progid, $controlName, $true)
                $trackedComObjects.Add($created)
                $controlMap[$controlName] = $created

                $geometry = Get-RequiredValue $controlSpec 'geometry'
                $created.Left = [single](Get-RequiredValue $geometry 'left')
                $created.Top = [single](Get-RequiredValue $geometry 'top')
                $created.Width = [single](Get-RequiredValue $geometry 'width')
                $created.Height = [single](Get-RequiredValue $geometry 'height')

                $requestedListItemValues = $null
                $listItemsReadback = $null
                $requestedListItems = Get-OptionalValue $controlSpec 'list_items'
                if ($null -ne $requestedListItems) {
                    $requestedListItemValues = @($requestedListItems | ForEach-Object { [string]$_ })
                    foreach ($item in @($requestedListItems)) {
                        [void]$created.AddItem([string]$item)
                    }
                    $actualListCount = [int]$created.ListCount
                    $actualListItems = [System.Collections.Generic.List[string]]::new()
                    for ($listIndex = 0; $listIndex -lt $actualListCount; $listIndex++) {
                        $actualListItems.Add([string]$created.List($listIndex, 0))
                    }
                    $listItemsReadback = [ordered]@{
                        list_count = $actualListCount
                        items = @($actualListItems)
                    }
                }

                $pageObservations = @()
                $requestedPages = Get-OptionalValue $controlSpec 'pages'
                if ($null -ne $requestedPages) {
                    $pages = $created.Pages
                    $trackedComObjects.Add($pages)
                    foreach ($pageSpec in @($requestedPages)) {
                        $page = $pages.Item([int](Get-RequiredValue $pageSpec 'index'))
                        $trackedComObjects.Add($page)
                        $page.Name = [string](Get-RequiredValue $pageSpec 'name')
                        $page.Caption = [string](Get-RequiredValue $pageSpec 'caption')
                        $pageMap[[string]$page.Name] = $page
                        $pageObservations += [ordered]@{
                            index = [int]$page.Index
                            name = [string]$page.Name
                            caption = [string]$page.Caption
                        }
                    }
                }

                $tabObservations = @()
                $requestedTabs = Get-OptionalValue $controlSpec 'tabs'
                if ($null -ne $requestedTabs) {
                    $tabs = $created.Tabs
                    $trackedComObjects.Add($tabs)
                    foreach ($tabSpec in @($requestedTabs)) {
                        $index = Get-OptionalValue $tabSpec 'index'
                        if ($null -ne $index) {
                            $tab = $tabs.Item([int]$index)
                            $tab.Name = [string](Get-RequiredValue $tabSpec 'name')
                            $tab.Caption = [string](Get-RequiredValue $tabSpec 'caption')
                        } else {
                            $tab = $tabs.Add(
                                [string](Get-RequiredValue $tabSpec 'add_name'),
                                [string](Get-RequiredValue $tabSpec 'caption')
                            )
                        }
                        $trackedComObjects.Add($tab)
                        $tabObservations += [ordered]@{
                            index = [int]$tab.Index
                            name = [string]$tab.Name
                            caption = [string]$tab.Caption
                        }
                    }
                }

                $propertyObservations = [System.Collections.Generic.List[object]]::new()
                foreach ($propertySpec in @($controlSpec.properties)) {
                    $propertyObservations.Add((Set-ControlProperty $created $propertySpec))
                }
                $geometryReadback = [ordered]@{
                    left = [double]$created.Left
                    top = [double]$created.Top
                    width = [double]$created.Width
                    height = [double]$created.Height
                }
                $geometryObservation = Get-GeometryObservationResult $controlSpec $geometryReadback
                $controlObservations.Add([ordered]@{
                    name = $controlName
                    family = [string](Get-RequiredValue $controlSpec 'family')
                    progid = $progid
                    container = $container
                    geometry_requested = $geometryObservation.requested
                    geometry_readback = $geometryReadback
                    geometry_result = $geometryObservation.result
                    properties = @($propertyObservations)
                    requested_list_items = $requestedListItemValues
                    list_items_readback = $listItemsReadback
                    pages = $pageObservations
                    tabs = $tabObservations
                })
            }

            $codeLines = @($formSpec.code_lines | ForEach-Object { [string]$_ })
            $codeText = ($codeLines -join "`r`n") + "`r`n"
            $component.CodeModule.AddFromString($codeText)

            $formName = [string](Get-RequiredValue $formSpec 'name')
            $frmPath = Join-Path $captureWorkingDir "$formName.frm"
            $frxPath = Join-Path $captureWorkingDir "$formName.frx"
            if ((Test-Path -LiteralPath $frmPath) -or (Test-Path -LiteralPath $frxPath)) {
                throw "Export destination already exists for '$formName'."
            }
            $component.Export($frmPath)
            if (-not (Test-Path -LiteralPath $frmPath -PathType Leaf)) { throw "Export did not create '$frmPath'." }
            if (-not (Test-Path -LiteralPath $frxPath -PathType Leaf)) { throw "Export did not create '$frxPath'." }

            $formObservations.Add([ordered]@{
                fixture_id = [string](Get-RequiredValue $formSpec 'fixture_id')
                component_name = $formName
                component_properties = @($componentPropertyObservations)
                controls = @($controlObservations)
                code_input = [ordered]@{
                    line_count = $codeLines.Count
                    utf8_sha256 = [System.Convert]::ToHexString(
                        [System.Security.Cryptography.SHA256]::HashData($utf8NoBom.GetBytes($codeText))
                    ).ToLowerInvariant()
                }
                exported_files = @(
                    Get-FileFact $frmPath (Join-Path $resolvedOutputDir "$formName.frm")
                    Get-FileFact $frxPath (Join-Path $resolvedOutputDir "$formName.frx")
                )
            })
        } finally {
            for ($i = $trackedComObjects.Count - 1; $i -ge 0; $i--) {
                Release-ComObject $trackedComObjects[$i]
            }
        }
    }

    $probeComponent = $vbProject.VBComponents.Add(3)
    $probeComponent.Name = 'W010DesignerAddProbe'
    $probeDesigner = $probeComponent.Designer
    $probeIndex = 0
    foreach ($probeSpec in @($spec.designer_add_probes)) {
        $probeIndex++
        $createdProbe = $null
        $errorMessage = $null
        $hresult = $null
        try {
            $createdProbe = $probeDesigner.Controls.Add(
                [string](Get-RequiredValue $probeSpec 'progid'),
                "Probe$probeIndex",
                $true
            )
        } catch {
            $errorMessage = $_.Exception.Message
            $hresult = ('0x{0:X8}' -f ([int64]$_.Exception.HResult -band 0xFFFFFFFFL))
        }
        $added = ($null -ne $createdProbe)
        $expected = [string](Get-RequiredValue $probeSpec 'expected')
        if (($expected -eq 'rejected' -and $added) -or ($expected -eq 'added' -and -not $added)) {
            throw "Designer-add probe drift for $([string](Get-RequiredValue $probeSpec 'progid'))."
        }
        $addProbeObservations.Add([ordered]@{
            family = [string](Get-RequiredValue $probeSpec 'family')
            progid = [string](Get-RequiredValue $probeSpec 'progid')
            expected = $expected
            added = $added
            error = $errorMessage
            hresult = $hresult
        })
        Release-ComObject $createdProbe
    }
} finally {
    if ($null -ne $workbook) {
        try { $workbook.Close($false) } catch { Write-Warning "Workbook close failed: $($_.Exception.Message)" }
    }
    if ($null -ne $excel) {
        try { $excel.Quit() } catch { Write-Warning "Excel quit failed: $($_.Exception.Message)" }
    }
    Release-ComObject $probeDesigner
    Release-ComObject $probeComponent
    Release-ComObject $vbProject
    Release-ComObject $workbook
    Release-ComObject $excel
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}

$manifestPath = Join-Path $captureWorkingDir 'capture_manifest.v2.json'
$manifest = [ordered]@{
    schema = 'oxforms.forms-persistence.live-export-capture.v2'
    capture_id = [string](Get-RequiredValue $spec 'capture_id')
    profile = [string](Get-RequiredValue $spec 'profile')
    frozen_capture_identity = $frozenCaptureIdentity
    authority_class = 'observed_real_office_export'
    capture_started_utc = $captureStartedUtc
    capture_completed_utc = [DateTime]::UtcNow.ToString('o')
    clean_room = [ordered]@{
        project_authored_inputs = $true
        third_party_form_content = $false
        public_automation_only = $true
        transient_workbook_saved = $false
    }
    git = $gitState
    capture_tool = $scriptFact
    capture_spec = $specFact
    environment = [ordered]@{
        os_version = [Environment]::OSVersion.VersionString
        os_architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
        process_architecture = [Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
        culture = [Globalization.CultureInfo]::CurrentCulture.Name
        ui_culture = [Globalization.CultureInfo]::CurrentUICulture.Name
        ansi_code_page = [Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage
        oem_code_page = [Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage
        powershell_version = $PSVersionTable.PSVersion.ToString()
    }
    excel_file = $excelHostProcessIdentity
    excel_automation = $excelAutomation
    exporter_binary_identity = $exporterBinaryIdentity
    progid_registrations = $registrations
    forms = @($formObservations)
    designer_add_probes = @($addProbeObservations)
}
$json = $manifest | ConvertTo-Json -Depth 30
[System.IO.File]::WriteAllText($manifestPath, $json + "`n", $utf8NoBom)

[void](Test-StagedCapture $captureWorkingDir $resolvedOutputDir $spec $resolvedSpecPath)
$promotionAttempted = $true
Publish-StagedCapture $captureWorkingDir $resolvedOutputDir $spec -ExpectedSpecPath $resolvedSpecPath

Write-Host "Captured $($formObservations.Count) real Excel/MSForms UserForm exports."
Write-Host "Manifest: $(Join-Path $resolvedOutputDir 'capture_manifest.v2.json')"
foreach ($file in Get-ChildItem -LiteralPath $resolvedOutputDir -File | Sort-Object Name) {
    Write-Host ("  {0} ({1} bytes)" -f $file.Name, $file.Length)
}
} catch {
    if (-not $promotionAttempted -and (Test-Path -LiteralPath $captureWorkingDir)) {
        try {
            Remove-SafeCaptureDirectory $captureWorkingDir
        } catch {
            Write-Warning "Incomplete staging directory could not be removed safely: '$captureWorkingDir': $($_.Exception.Message)"
        }
    } elseif ($promotionAttempted -and (Test-Path -LiteralPath $captureWorkingDir)) {
        Write-Warning "Validated staging output was preserved after promotion failure: '$captureWorkingDir'."
    }
    throw
}
