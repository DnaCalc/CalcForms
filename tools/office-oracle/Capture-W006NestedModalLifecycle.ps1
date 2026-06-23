[CmdletBinding()]
param(
    [string]$FixtureDir = 'fixtures\office-oracle\excel-msforms\userforms\nested-modal-lifecycle',
    [string]$OutDir,
    [switch]$Force,
    [switch]$DryRun,
    [int]$ActionDelayMilliseconds = 240
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$captureRoot = Join-Path $repoRoot 'docs\evidence\W006_control_implementation_rollout\captures'
$captureBead = 'oxforms-0a0.19'
$outerTitle = 'OxForms W006 Nested Outer'
$innerTitle = 'OxForms W006 Nested Inner'

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
        $Directory = Join-Path $captureRoot ('nested-modal-lifecycle-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))
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

function Get-RequiredValue {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        throw "Fixture manifest is missing required value: $Name"
    }
    if ($property.Value -is [string] -and [string]::IsNullOrWhiteSpace($property.Value)) {
        throw "Fixture manifest has an empty required value: $Name"
    }
    return $property.Value
}

function Get-OptionalValue {
    param($Object, [Parameter(Mandatory = $true)][string]$Name)

    if ($null -eq $Object) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Resolve-FixtureSourcePath {
    param(
        [Parameter(Mandatory = $true)][string]$FixtureRoot,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $fullPath = if ([System.IO.Path]::IsPathRooted($Path)) {
        Resolve-InRepoPath $Path
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $FixtureRoot $Path))
    }

    $repoWithSeparator = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not ($fullPath.Equals($repoRoot, [System.StringComparison]::OrdinalIgnoreCase) -or $fullPath.StartsWith($repoWithSeparator, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Fixture source path must stay inside the repository: $Path"
    }
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Fixture source file not found: $fullPath"
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

    $Value | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $Path -Encoding UTF8
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

function Set-ComponentPropertyValue {
    param(
        [Parameter(Mandatory = $true)]$Component,
        [Parameter(Mandatory = $true)][string]$PropertyName,
        [Parameter(Mandatory = $true)]$Value
    )

    $property = $Component.Properties.Item($PropertyName)
    $property.GetType().InvokeMember(
        'Value',
        [System.Reflection.BindingFlags]::SetProperty,
        $null,
        $property,
        @($Value),
        [System.Globalization.CultureInfo]::InvariantCulture
    )
}

function Set-ControlPropertyIfPresent {
    param(
        [Parameter(Mandatory = $true)]$ControlObject,
        [Parameter(Mandatory = $true)]$Spec,
        [Parameter(Mandatory = $true)][string]$ManifestName,
        [Parameter(Mandatory = $true)][scriptblock]$Apply
    )

    $value = Get-OptionalValue $Spec $ManifestName
    if ($null -eq $value) {
        return
    }
    & $Apply $ControlObject $value
}

function Set-ControlFontIfPresent {
    param(
        [Parameter(Mandatory = $true)]$ControlObject,
        $FontSpec
    )

    if ($null -eq $FontSpec) {
        return
    }

    Set-ControlPropertyIfPresent $ControlObject $FontSpec 'name' { param($c, $v) $c.Font.Name = [string]$v }
    Set-ControlPropertyIfPresent $ControlObject $FontSpec 'sizePt' { param($c, $v) $c.Font.Size = [double]$v }
    Set-ControlPropertyIfPresent $ControlObject $FontSpec 'bold' { param($c, $v) $c.Font.Bold = [bool]$v }
    Set-ControlPropertyIfPresent $ControlObject $FontSpec 'italic' { param($c, $v) $c.Font.Italic = [bool]$v }
    Set-ControlPropertyIfPresent $ControlObject $FontSpec 'underline' { param($c, $v) $c.Font.Underline = [bool]$v }
    Set-ControlPropertyIfPresent $ControlObject $FontSpec 'strikethrough' { param($c, $v) $c.Font.Strikethrough = [bool]$v }
}

function Add-UserFormComponent {
    param(
        [Parameter(Mandatory = $true)]$VbProject,
        [Parameter(Mandatory = $true)]$FormSpec,
        [Parameter(Mandatory = $true)][string]$FixtureRoot
    )

    $vbextCtMsForm = 3
    $component = $VbProject.VBComponents.Add($vbextCtMsForm)
    $component.Name = [string](Get-RequiredValue $FormSpec 'name')
    $designer = $component.Designer

    Set-ComponentPropertyValue $component 'Caption' ([string](Get-RequiredValue $FormSpec 'caption'))
    Set-ComponentPropertyValue $component 'Width' ([single](Get-RequiredValue $FormSpec 'widthPt'))
    Set-ComponentPropertyValue $component 'Height' ([single](Get-RequiredValue $FormSpec 'heightPt'))
    Set-ComponentPropertyValue $component 'StartUpPosition' ([single](Get-RequiredValue $FormSpec 'startupPosition'))

    foreach ($control in @($FormSpec.controls)) {
        $controlName = [string](Get-RequiredValue $control 'name')
        $controlType = [string](Get-RequiredValue $control 'type')
        $createdControl = $designer.Controls.Add($controlType, $controlName, $true)
        $createdControl.Left = [single](Get-RequiredValue $control 'leftPt')
        $createdControl.Top = [single](Get-RequiredValue $control 'topPt')
        $createdControl.Width = [single](Get-RequiredValue $control 'widthPt')
        $createdControl.Height = [single](Get-RequiredValue $control 'heightPt')

        Set-ControlPropertyIfPresent $createdControl $control 'caption' { param($c, $v) $c.Caption = [string]$v }
        Set-ControlPropertyIfPresent $createdControl $control 'backColorOle' { param($c, $v) $c.BackColor = [int]$v }
        Set-ControlPropertyIfPresent $createdControl $control 'foreColorOle' { param($c, $v) $c.ForeColor = [int]$v }
        Set-ControlPropertyIfPresent $createdControl $control 'borderStyle' { param($c, $v) $c.BorderStyle = [int]$v }
        Set-ControlPropertyIfPresent $createdControl $control 'backStyle' { param($c, $v) $c.BackStyle = [int]$v }
        Set-ControlPropertyIfPresent $createdControl $control 'tabIndex' { param($c, $v) $c.TabIndex = [int]$v }
        Set-ControlPropertyIfPresent $createdControl $control 'tabStop' { param($c, $v) $c.TabStop = [bool]$v }
        Set-ControlPropertyIfPresent $createdControl $control 'takeFocusOnClick' { param($c, $v) $c.TakeFocusOnClick = [bool]$v }
        Set-ControlFontIfPresent $createdControl (Get-OptionalValue $control 'font')
    }

    $codePath = Resolve-FixtureSourcePath -FixtureRoot $FixtureRoot -Path ([string](Get-RequiredValue $FormSpec 'codeBehindSourcePath'))
    $component.CodeModule.AddFromString((Get-Content -Raw -LiteralPath $codePath))
    return $component
}

function New-WorkbookFromFixture {
    param(
        [Parameter(Mandatory = $true)]$Fixture,
        [Parameter(Mandatory = $true)][string]$FixtureRoot,
        [Parameter(Mandatory = $true)][string]$WorkbookPath
    )

    if (Test-Path -LiteralPath $WorkbookPath -PathType Leaf) {
        if (-not $Force) {
            throw "Output workbook already exists. Pass -Force to replace it: $WorkbookPath"
        }
        Remove-Item -LiteralPath $WorkbookPath -Force
    }

    $excel = $null
    $workbook = $null
    $vbProject = $null
    $components = [System.Collections.Generic.List[object]]::new()
    $standardModule = $null

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
            throw "Excel blocked access to the VBA project object model. Enable 'Trust access to the VBA project object model' or use the documented manual procedure."
        }

        foreach ($formSpec in @($Fixture.forms)) {
            $components.Add((Add-UserFormComponent -VbProject $vbProject -FormSpec $formSpec -FixtureRoot $FixtureRoot)) | Out-Null
        }

        $vbextCtStdModule = 1
        $standardModule = $vbProject.VBComponents.Add($vbextCtStdModule)
        $standardModule.Name = [string](Get-RequiredValue $Fixture.workbook 'vbaModuleName')
        $standardModulePath = Resolve-FixtureSourcePath -FixtureRoot $FixtureRoot -Path ([string](Get-RequiredValue $Fixture.workbook 'standardModuleSourcePath'))
        $standardModule.CodeModule.AddFromString((Get-Content -Raw -LiteralPath $standardModulePath))

        $xlOpenXmlWorkbookMacroEnabled = 52
        $workbook.SaveAs($WorkbookPath, $xlOpenXmlWorkbookMacroEnabled)
    } finally {
        if ($null -ne $workbook) {
            try {
                $workbook.Close($true)
            } catch {
                Write-Warning "Failed to close generated workbook cleanly: $($_.Exception.Message)"
            }
        }
        if ($null -ne $excel) {
            try {
                $excel.Quit()
            } catch {
                Write-Warning "Failed to quit Excel after generation: $($_.Exception.Message)"
            }
        }
        foreach ($component in $components) {
            Release-ComObjectIfPresent $component
        }
        Release-ComObjectIfPresent $standardModule
        Release-ComObjectIfPresent $vbProject
        Release-ComObjectIfPresent $workbook
        Release-ComObjectIfPresent $excel
    }
}

function Ensure-WindowEnumTypes {
    if (([System.Management.Automation.PSTypeName]'OxForms.W006Nested.NativeMethods').Type) {
        return
    }

    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace OxForms.W006Nested
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
    }
}
'@
}

function Get-WindowTextValue {
    param([System.IntPtr]$Handle)

    $length = [OxForms.W006Nested.NativeMethods]::GetWindowTextLengthW($Handle)
    $builder = [System.Text.StringBuilder]::new([Math]::Max($length + 1, 256))
    [void][OxForms.W006Nested.NativeMethods]::GetWindowTextW($Handle, $builder, $builder.Capacity)
    return $builder.ToString()
}

function Get-ClassNameValue {
    param([System.IntPtr]$Handle)

    $builder = [System.Text.StringBuilder]::new(256)
    [void][OxForms.W006Nested.NativeMethods]::GetClassNameW($Handle, $builder, $builder.Capacity)
    return $builder.ToString()
}

function Get-TopLevelWindows {
    Ensure-WindowEnumTypes
    $windows = [System.Collections.Generic.List[object]]::new()
    $callback = [OxForms.W006Nested.NativeMethods+EnumWindowsProc]{
        param([System.IntPtr]$Handle, [System.IntPtr]$Param)

        if (-not [OxForms.W006Nested.NativeMethods]::IsWindowVisible($Handle)) {
            return $true
        }

        $title = Get-WindowTextValue -Handle $Handle
        if ([string]::IsNullOrWhiteSpace($title)) {
            return $true
        }

        $class = Get-ClassNameValue -Handle $Handle
        $processIdValue = [uint32]0
        [void][OxForms.W006Nested.NativeMethods]::GetWindowThreadProcessId($Handle, [ref]$processIdValue)
        $processName = $null
        try {
            $processName = (Get-Process -Id ([int]$processIdValue) -ErrorAction Stop).ProcessName
        } catch {
            $processName = $null
        }
        $rect = New-Object OxForms.W006Nested.NativeMethods+RECT
        [void][OxForms.W006Nested.NativeMethods]::GetWindowRect($Handle, [ref]$rect)

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

    [void][OxForms.W006Nested.NativeMethods]::EnumWindows($callback, [System.IntPtr]::Zero)
    return @($windows)
}

function Wait-ForOracleWindow {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [int]$TimeoutSeconds = 25
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
        [int]$TimeoutSeconds = 12
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

function Invoke-CaptureWindow {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedOutDir,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Title
    )

    $windowDir = Join-Path $ResolvedOutDir "$Name-window"
    New-Item -ItemType Directory -Force -Path $windowDir | Out-Null
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', (Join-Path $repoRoot 'tools\office-oracle\Capture-Window.ps1'),
        '-OutDir', $windowDir,
        '-TitleContains', $Title,
        '-ProcessName', 'EXCEL',
        '-CaptureScreenshot'
    )

    Invoke-LoggedPowerShell -Arguments $arguments `
        -CommandPath (Join-Path $ResolvedOutDir "capture-window-$Name.command.txt") `
        -StdoutPath (Join-Path $ResolvedOutDir "capture-window-$Name.stdout.txt") `
        -StderrPath (Join-Path $ResolvedOutDir "capture-window-$Name.stderr.txt")

    $manifestPath = Join-Path $windowDir 'window-capture-manifest.json'
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    if ($manifest.status -ne 'ok') {
        throw "Window capture '$Name' did not complete with status=ok; status=$($manifest.status)."
    }
    return $manifest
}

function Get-ControlSpec {
    param(
        [Parameter(Mandatory = $true)]$FormSpec,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $matches = @($FormSpec.controls | Where-Object { $_.name -eq $Name })
    if ($matches.Count -ne 1) {
        throw "Expected exactly one control named '$Name' on form '$($FormSpec.name)'."
    }
    return $matches[0]
}

function Get-FormSpec {
    param(
        [Parameter(Mandatory = $true)]$Fixture,
        [Parameter(Mandatory = $true)][string]$Identity
    )

    $matches = @($Fixture.forms | Where-Object { $_.identity -eq $Identity })
    if ($matches.Count -ne 1) {
        throw "Expected exactly one fixture form with identity '$Identity'."
    }
    return $matches[0]
}

function Get-ColorBounds {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bitmap,
        [Parameter(Mandatory = $true)][int]$Red,
        [Parameter(Mandatory = $true)][int]$Green,
        [Parameter(Mandatory = $true)][int]$Blue
    )

    $minX = $Bitmap.Width
    $minY = $Bitmap.Height
    $maxX = -1
    $maxY = -1
    $count = 0

    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            $pixel = $Bitmap.GetPixel($x, $y)
            if ($pixel.R -eq $Red -and $pixel.G -eq $Green -and $pixel.B -eq $Blue) {
                $count++
                if ($x -lt $minX) { $minX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }

    if ($count -eq 0) {
        return $null
    }

    return [ordered]@{
        x = $minX
        y = $minY
        width = $maxX - $minX + 1
        height = $maxY - $minY + 1
        pixel_count = $count
    }
}

function Analyze-FormCoordinates {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedOutDir,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)]$FormSpec,
        [Parameter(Mandatory = $true)]$WindowManifest,
        [Parameter(Mandatory = $true)][string]$AnchorControlName
    )

    Add-Type -AssemblyName System.Drawing
    $screenshotPath = [string]$WindowManifest.screenshot.path
    if (-not (Test-Path -LiteralPath $screenshotPath -PathType Leaf)) {
        throw "Screenshot path missing for '$Name': $screenshotPath"
    }

    $anchor = Get-ControlSpec -FormSpec $FormSpec -Name $AnchorControlName
    $rgb = $anchor.backColorRgb
    $dpi = $WindowManifest.selected_window.dpi
    if ($null -eq $dpi -or [double]$dpi -le 0) {
        $dpi = 96
    }
    $pointsToPixels = [double]$dpi / 72.0
    $bitmap = [System.Drawing.Bitmap]::new($screenshotPath)
    try {
        $anchorBounds = Get-ColorBounds -Bitmap $bitmap -Red ([int]$rgb.red) -Green ([int]$rgb.green) -Blue ([int]$rgb.blue)
    } finally {
        $bitmap.Dispose()
    }

    if ($null -eq $anchorBounds) {
        throw "Could not detect anchor control '$AnchorControlName' color in screenshot '$screenshotPath'."
    }

    $formOrigin = [ordered]@{
        x = [double]$anchorBounds.x - ([double]$anchor.leftPt * $pointsToPixels)
        y = [double]$anchorBounds.y - ([double]$anchor.topPt * $pointsToPixels)
        source = 'exact_anchor_label_fill_color'
    }

    $calibration = [ordered]@{
        schema = 'oxforms.office_oracle.w006_nested_modal_coordinate_derivation.v1'
        bead = $captureBead
        run = $Name
        form_identity = $FormSpec.identity
        screenshot = [ordered]@{
            path = ConvertTo-RepoRelative $screenshotPath
            width = $WindowManifest.screenshot.width
            height = $WindowManifest.screenshot.height
            sha256 = $WindowManifest.screenshot.sha256
            coordinate_origin = 'top_left_of_captured_top_level_window'
        }
        dpi = [double]$dpi
        points_to_pixels = $pointsToPixels
        anchor_control = [ordered]@{
            name = $AnchorControlName
            rgb = $rgb
            rect_screenshot_pixels = $anchorBounds
        }
        form_origin_screenshot_pixels = $formOrigin
        notes = @(
            'Coordinates drive public Windows input only; worksheet rows remain the observed MSForms lifecycle facts.',
            'The derived form origin uses a repo-owned colored Label anchor and does not assert pixel parity.'
        )
    }

    $path = Join-Path $ResolvedOutDir "$Name-coordinate-derivation.json"
    Write-JsonFile -Path $path -Value $calibration
    return $calibration
}

function New-ScreenshotPointForControl {
    param(
        [Parameter(Mandatory = $true)]$Control,
        [Parameter(Mandatory = $true)]$Calibration
    )

    $scale = [double]$Calibration.points_to_pixels
    return [ordered]@{
        x = [double]$Calibration.form_origin_screenshot_pixels.x + (([double]$Control.leftPt + ([double]$Control.widthPt / 2.0)) * $scale)
        y = [double]$Calibration.form_origin_screenshot_pixels.y + (([double]$Control.topPt + ([double]$Control.heightPt / 2.0)) * $scale)
    }
}

function Convert-ScreenshotToScreenPoint {
    param(
        [Parameter(Mandatory = $true)]$Window,
        [Parameter(Mandatory = $true)]$Point
    )

    return [ordered]@{
        x = [int][Math]::Round([double]$Window.bounds.left + [double]$Point.x)
        y = [int][Math]::Round([double]$Window.bounds.top + [double]$Point.y)
    }
}

function Add-InputAction {
    param(
        [Parameter(Mandatory = $true)][System.Collections.Generic.List[object]]$Actions,
        [Parameter(Mandatory = $true)][string]$Scenario,
        [Parameter(Mandatory = $true)][string]$Method,
        [Parameter(Mandatory = $true)][string]$Action,
        [Parameter(Mandatory = $true)][string]$TargetIntent,
        [object]$Window,
        [object]$ScreenshotPoint,
        [object]$ScreenPoint,
        [object]$Result,
        [string]$Notes = ''
    )

    $Actions.Add([ordered]@{
        sequence = $Actions.Count + 1
        scenario = $Scenario
        method = $Method
        input_driver = if ($Method -eq 'automated_sendinput_mouse') { 'public_user32_sendinput' } elseif ($Method -eq 'automated_sendkeys') { 'system_windows_forms_sendkeys' } else { $Method }
        manual = $false
        action = $Action
        target_intent = $TargetIntent
        window = if ($null -ne $Window) {
            [ordered]@{
                title = $Window.title
                handle = $Window.handle
                bounds = $Window.bounds
            }
        } else {
            $null
        }
        screenshot_pixels = $ScreenshotPoint
        screen_pixels = $ScreenPoint
        result = $Result
        notes = $Notes
    }) | Out-Null
}

function Invoke-ClickControl {
    param(
        [Parameter(Mandatory = $true)]$Window,
        [Parameter(Mandatory = $true)]$FormSpec,
        [Parameter(Mandatory = $true)]$Calibration,
        [Parameter(Mandatory = $true)][string]$ControlName,
        [Parameter(Mandatory = $true)][System.Collections.Generic.List[object]]$Actions,
        [Parameter(Mandatory = $true)][string]$Scenario,
        [Parameter(Mandatory = $true)][string]$TargetIntent
    )

    $control = Get-ControlSpec -FormSpec $FormSpec -Name $ControlName
    $screenshotPoint = New-ScreenshotPointForControl -Control $control -Calibration $Calibration
    $screenPoint = Convert-ScreenshotToScreenPoint -Window $Window -Point $screenshotPoint
    $handleValue = ConvertFrom-W005HandleText -Handle ([string]$Window.handle)
    $foreground = Set-W005ForegroundWindow -Handle $handleValue -DelayMilliseconds $ActionDelayMilliseconds
    $input = Invoke-W005SendInputMouseClick -ScreenX $screenPoint.x -ScreenY $screenPoint.y -TargetHandle $handleValue -DownUpDelayMilliseconds 70 -AfterDelayMilliseconds $ActionDelayMilliseconds

    Add-InputAction -Actions $Actions -Scenario $Scenario -Method 'automated_sendinput_mouse' -Action 'click' -TargetIntent $TargetIntent -Window $Window -ScreenshotPoint $screenshotPoint -ScreenPoint $screenPoint -Result ([ordered]@{ foreground = $foreground; input = $input }) -Notes 'Mouse event was injected with public user32 SendInput after SetCursorPos.'
}

function Invoke-AltF4 {
    param(
        [Parameter(Mandatory = $true)]$Window,
        [Parameter(Mandatory = $true)][System.Collections.Generic.List[object]]$Actions,
        [Parameter(Mandatory = $true)][string]$Scenario,
        [Parameter(Mandatory = $true)][string]$TargetIntent
    )

    Add-Type -AssemblyName System.Windows.Forms
    $handleValue = ConvertFrom-W005HandleText -Handle ([string]$Window.handle)
    $foreground = Set-W005ForegroundWindow -Handle $handleValue -DelayMilliseconds $ActionDelayMilliseconds
    $before = Get-W005InputDiagnosticsSnapshot -TargetHandle $handleValue -Phase 'before_sendkeys_alt_f4'
    [System.Windows.Forms.SendKeys]::SendWait('%{F4}')
    Start-Sleep -Milliseconds ($ActionDelayMilliseconds * 2)
    $after = Get-W005InputDiagnosticsSnapshot -TargetHandle $handleValue -Phase 'after_sendkeys_alt_f4'

    Add-InputAction -Actions $Actions -Scenario $Scenario -Method 'automated_sendkeys' -Action 'alt_f4' -TargetIntent $TargetIntent -Window $Window -ScreenshotPoint $null -ScreenPoint $null -Result ([ordered]@{ foreground = $foreground; before = $before; after = $after }) -Notes 'Alt+F4 was sent with System.Windows.Forms.SendKeys to drive the public system close path.'
}

function Export-WorksheetLog {
    param(
        [Parameter(Mandatory = $true)]$Workbook,
        [Parameter(Mandatory = $true)][string]$ResolvedOutDir,
        [Parameter(Mandatory = $true)][array]$AutomatedInputs
    )

    $sheet = $Workbook.Worksheets.Item('W006NestedModalLog')
    $range = $sheet.UsedRange
    $rowCount = [int]$range.Rows.Count
    $columnCount = [int]$range.Columns.Count
    $values = $range.Value2

    $headers = [System.Collections.Generic.List[string]]::new()
    for ($column = 1; $column -le $columnCount; $column++) {
        $headers.Add([string]($values[1, $column])) | Out-Null
    }

    $records = [System.Collections.Generic.List[object]]::new()
    if ($rowCount -ge 2) {
        for ($row = 2; $row -le $rowCount; $row++) {
            $record = [ordered]@{}
            for ($column = 1; $column -le $columnCount; $column++) {
                $value = $values[$row, $column]
                if ($null -eq $value) {
                    $record[$headers[$column - 1]] = ''
                } else {
                    $record[$headers[$column - 1]] = [string]$value
                }
            }
            $records.Add([pscustomobject]$record) | Out-Null
        }
    }

    $rows = @($records)
    $csvPath = Join-Path $ResolvedOutDir 'nested-modal-event-log.csv'
    $rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

    $eventLog = [ordered]@{
        schema = 'oxforms.office_oracle.w006_nested_modal_event_log.v1'
        bead = $captureBead
        source = [ordered]@{
            worksheet = 'W006NestedModalLog'
            fixture = 'fixtures/office-oracle/excel-msforms/userforms/nested-modal-lifecycle/fixture.json'
            trace_schema = [ordered]@{
                ordering = 'docs/specs/TRACE_REPLAY_SCHEMA.md#5-Ordering-Model'
                effects = 'docs/specs/TRACE_REPLAY_SCHEMA.md#9-Reducer-And-Effects'
                lifecycle_pump = 'docs/specs/TRACE_REPLAY_SCHEMA.md#11-Lifecycle-And-Pump-Rows'
                validator = 'docs/specs/TRACE_REPLAY_SCHEMA.md#14-Validator-And-Sample'
            }
        }
        observed_facts = [ordered]@{
            row_count = $rows.Count
            event_names = @($rows | ForEach-Object { $_.event_name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
            form_identities = @($rows | ForEach-Object { $_.form_identity } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
            show_modes = @($rows | ForEach-Object { $_.show_mode } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
            rows = $rows
        }
        assumptions = @(
            'Rows under observed_facts are worksheet rows emitted by repo-owned VBA handlers while real Excel/MSForms handled the shown forms and public input.',
            'Fixture action rows such as BeforeHide and BeforeUnload record the public VBA path taken by the fixture; they are not MSForms event rows.',
            'Absence of an event row is not a negative parity fact; this capture records only rows raised or logged by this fixture and input run.'
        )
        unknowns = @(
            'This capture does not prove all modal owner-window policies, all host shutdown paths, or all QueryClose CloseMode values.',
            'Terminate timing remains tied to this fixture run and does not isolate every default-instance/reference lifetime case.'
        )
        blockers = @()
        manual_inputs = @()
        automated_inputs = @($AutomatedInputs)
        non_claims = @(
            'This event log is not an exhaustive MSForms event parity claim.',
            'This event log is not an OxForms output comparison artifact.',
            'No OxForms runtime modal, reentrant pump, hide/unload, or Terminate behavior is implemented or claimed by this artifact.'
        )
    }

    $jsonPath = Join-Path $ResolvedOutDir 'nested-modal-event-log.json'
    Write-JsonFile -Path $jsonPath -Value $eventLog
    return [ordered]@{
        csv = ConvertTo-RepoRelative $csvPath
        json = ConvertTo-RepoRelative $jsonPath
        row_count = $rows.Count
        event_names = $eventLog.observed_facts.event_names
        form_identities = $eventLog.observed_facts.form_identities
        rows = $rows
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

function Write-CaptureReadme {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedOutDir,
        [Parameter(Mandatory = $true)]$Manifest
    )

    $statusLine = if ($Manifest.status -eq 'captured') {
        'This directory contains black-box Excel/MSForms nested modal lifecycle evidence. It is not an OxForms output comparison and it does not claim exhaustive MSForms parity.'
    } else {
        'This directory records a precise blocker for the nested modal lifecycle oracle capture. It does not infer MSForms behavior from missing rows.'
    }

    $lines = @(
        '# W006 Nested Modal Lifecycle Oracle Capture',
        '',
        "Capture id: $($Manifest.capture_id)",
        ('Bead: `' + [string]$Manifest.bead + '`'),
        ('Status: `' + [string]$Manifest.status + '`'),
        '',
        $statusLine,
        '',
        '## Facts',
        '',
        '- `oracle-capture-manifest.json` records the capture status, fixture hashes, command logs, clean-room notes, and trace/replay implications.',
        '- `input-actions.json` records public Windows input actions; `manual_inputs` is empty.',
        '- `nested-modal-event-log.json` and `.csv`, when present, contain worksheet rows emitted by repo-owned VBA handlers while live Excel/MSForms handled the forms.',
        '- `*-window/` directories, when present, record top-level UserForm window metadata and screenshots.',
        '',
        '## Assumptions',
        '',
        '- Input target points are derived from fixture point geometry and screenshot anchor labels.',
        '- Fixture action rows identify the public VBA path taken by the scenario; they are not extra MSForms events.',
        '',
        '## Unknowns And Blockers',
        '',
        '- Missing event rows are unobserved rows in this run, not negative facts about MSForms.',
        '- If `blocker.json` is present, it names the exact public automation or fixture capability that prevented a full recording.',
        '',
        '## Clean-room Note',
        '',
        'The capture used repo-owned fixture sources, public Excel/VBIDE automation, public VBA event handlers, public Windows desktop input/capture APIs, and worksheet export. It did not use private Office internals, decompilation, disassembly, or OxForms output comparison.'
    )

    Set-Content -LiteralPath (Join-Path $ResolvedOutDir 'README.md') -Value $lines -Encoding UTF8
}

function New-RunSummary {
    param(
        [Parameter(Mandatory = $true)][string]$CaptureId,
        [Parameter(Mandatory = $true)]$EventLog,
        [Parameter(Mandatory = $true)][array]$Blockers
    )

    $rows = @($EventLog.rows)
    $innerRows = @($rows | Where-Object { $_.form_identity -eq 'inner' })
    $innerParentRows = @($innerRows | Where-Object { -not [string]::IsNullOrWhiteSpace($_.parent_row_id) })
    $queryCloseRows = @($rows | Where-Object { $_.event_name -eq 'QueryClose' })

    return [ordered]@{
        schema = 'oxforms.office_oracle.w006_nested_modal_run_summary.v1'
        bead = $captureBead
        capture_id = $CaptureId
        row_count = $EventLog.row_count
        event_names = $EventLog.event_names
        form_identities = $EventLog.form_identities
        selected_surface_status = [ordered]@{
            nested_modal_entry = if ($innerRows.Count -gt 0 -and $innerParentRows.Count -gt 0) { 'observed_inner_rows_with_parent_row_id' } else { 'not_observed_in_this_run' }
            inner_hide_path = if (@($rows | Where-Object { $_.form_identity -eq 'inner' -and $_.event_name -eq 'BeforeHide' }).Count -gt 0) { 'observed_fixture_hide_rows' } else { 'not_observed_in_this_run' }
            inner_unload_path = if (@($rows | Where-Object { $_.form_identity -eq 'inner' -and $_.event_name -eq 'BeforeUnload' }).Count -gt 0) { 'observed_fixture_unload_rows' } else { 'not_observed_in_this_run' }
            inner_system_close_path = if (@($queryCloseRows | Where-Object { $_.form_identity -eq 'inner' -and $_.close_origin -eq 'inner_system_close_alt_f4' }).Count -gt 0) { 'observed_queryclose_row' } else { 'not_observed_in_this_run' }
            outer_hide_path = if (@($rows | Where-Object { $_.form_identity -eq 'outer' -and $_.event_name -eq 'BeforeHide' }).Count -gt 0) { 'observed_fixture_hide_rows' } else { 'not_observed_in_this_run' }
            outer_unload_path = if (@($rows | Where-Object { $_.form_identity -eq 'outer' -and $_.event_name -eq 'BeforeUnload' }).Count -gt 0) { 'observed_fixture_unload_rows' } else { 'not_observed_in_this_run' }
            query_close_values = if ($queryCloseRows.Count -gt 0) { 'observed_cancel_before_cancel_after_close_mode_rows' } else { 'not_observed_in_this_run' }
            terminate_rows = if (@($rows | Where-Object { $_.event_name -eq 'Terminate' }).Count -gt 0) { 'observed' } else { 'not_observed_in_this_run' }
        }
        facts = @(
            'The event log records outer and inner form identity, show mode, active control/window caption, close origin, QueryClose Cancel before/after values, CloseMode, and nesting metadata where rows were emitted.',
            'Inner modal rows carry nesting_depth=1 and parent_row_id pointing at the outer BeforeInnerShowModal row when the fixture logger had that parent context.',
            'Fixture action rows record Hide and Unload call sites separately from MSForms QueryClose and Terminate rows.'
        )
        assumptions = @(
            'Public input actions target controls by screenshot anchor derivation and manifest point geometry.',
            'Window screenshots and active-window captions are diagnostics for this run, not final active-window parity rules.'
        )
        unknowns = @(
            'This capture does not settle all owner-window policies, host shutdown close modes, cancellation variants, or object-lifetime reference-release timing.',
            'Rows absent from this run remain unknown for this fixture and are not negative MSForms facts.'
        )
        blockers = @($Blockers)
        trace_replay_implications = @(
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 5 requires nested modal activity to carry parent_row_id and nesting_depth rather than prose-only causality.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 9 requires modal show, hide, unload, VBA dispatch, and platform work to preserve separate effect_requested and effect_completed rows.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 11 requires lifecycle_pump rows to carry modal depth, active form/window/focus, close/query/hide/unload/terminate reasons, cancellation status, and causal row ids.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 14 validates parent/nesting relationships and reducer/effect/dispatch causal ordering.'
        )
        non_claims = @(
            'No OxForms runtime modal or reentrant pump behavior is implemented or claimed by this capture.',
            'This capture is oracle evidence, not a pass/fail comparison artifact.'
        )
    }
}

function New-BlockedRunSummary {
    param(
        [Parameter(Mandatory = $true)][string]$CaptureId,
        [Parameter(Mandatory = $true)][array]$Blockers
    )

    return [ordered]@{
        schema = 'oxforms.office_oracle.w006_nested_modal_run_summary.v1'
        bead = $captureBead
        capture_id = $CaptureId
        status = 'blocked'
        row_count = 0
        event_names = @()
        form_identities = @()
        selected_surface_status = [ordered]@{
            nested_modal_entry = 'blocked_before_complete_recording'
            inner_hide_path = 'blocked_before_complete_recording'
            inner_unload_path = 'blocked_before_complete_recording'
            inner_system_close_path = 'blocked_before_complete_recording'
            outer_hide_path = 'blocked_before_complete_recording'
            outer_unload_path = 'blocked_before_complete_recording'
            query_close_values = 'blocked_before_complete_recording'
            terminate_rows = 'blocked_before_complete_recording'
        }
        facts = @(
            'The fixture plan and capture driver exist in the repo.',
            'No worksheet event rows were exported by this blocked attempt.'
        )
        assumptions = @(
            'The blocker category and progress log narrow where public Excel/VBIDE or Windows input automation stopped.'
        )
        unknowns = @(
            'All nested modal lifecycle ordering fields remain unknown for live MSForms until a future capture reaches visible UserForms and worksheet export.',
            'Rows absent from this run remain unknown and are not negative MSForms facts.'
        )
        blockers = @($Blockers)
        trace_replay_implications = @(
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 5: future nested modal rows need parent_row_id and nesting_depth.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 9: future modal show/hide/unload paths need effect_requested/effect_completed separation.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 11: future lifecycle_pump rows need modal depth, active form/window/control, close/query/hide/unload/terminate reasons, cancellation status, and causal row ids.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 14: future validators need parent/nesting and causal-order checks.'
        )
        non_claims = @(
            'No OxForms runtime behavior is implemented or claimed.',
            'No missing rows are treated as negative MSForms facts.'
        )
    }
}

function Write-BlockedInputActions {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedOutDir,
        [Parameter(Mandatory = $true)][array]$Blockers
    )

    Write-JsonFile -Path (Join-Path $ResolvedOutDir 'input-actions.json') -Value ([ordered]@{
        schema = 'oxforms.office_oracle.w006_nested_modal_input_actions.v1'
        bead = $captureBead
        manual_inputs = @()
        automated_inputs = @()
        blockers = @($Blockers)
        notes = @(
            'No public Windows input was recorded for this blocked attempt.',
            'Rows absent from this run remain unknown and are not negative MSForms facts.'
        )
    })
}

function Get-FixtureHashes {
    param(
        [Parameter(Mandatory = $true)]$Fixture,
        [Parameter(Mandatory = $true)][string]$FixtureRoot,
        [Parameter(Mandatory = $true)][string]$FixturePath
    )

    $formSources = @()
    foreach ($form in @($Fixture.forms)) {
        $path = Resolve-FixtureSourcePath -FixtureRoot $FixtureRoot -Path ([string](Get-RequiredValue $form 'codeBehindSourcePath'))
        $formSources += [ordered]@{
            form_identity = $form.identity
            path = ConvertTo-RepoRelative $path
            sha256 = Get-Sha256Hex -Path $path
        }
    }

    $modulePath = Resolve-FixtureSourcePath -FixtureRoot $FixtureRoot -Path ([string](Get-RequiredValue $Fixture.workbook 'standardModuleSourcePath'))
    return [ordered]@{
        manifest = [ordered]@{
            path = ConvertTo-RepoRelative $FixturePath
            sha256 = Get-Sha256Hex -Path $FixturePath
        }
        form_code_behind = $formSources
        standard_module = [ordered]@{
            path = ConvertTo-RepoRelative $modulePath
            sha256 = Get-Sha256Hex -Path $modulePath
        }
        capture_tool = [ordered]@{
            path = ConvertTo-RepoRelative $PSCommandPath
            sha256 = Get-Sha256Hex -Path $PSCommandPath
        }
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
        $RunSummaryPath,
        [array]$Blockers
    )

    $commandLogCandidates = @(
        (Join-Path $ResolvedOutDir 'capture.command.txt'),
        (Join-Path $ResolvedOutDir 'capture-progress.log'),
        (Join-Path $ResolvedOutDir 'capture-window-outer-initial.command.txt'),
        (Join-Path $ResolvedOutDir 'capture-window-outer-initial.stdout.txt'),
        (Join-Path $ResolvedOutDir 'capture-window-outer-initial.stderr.txt'),
        (Join-Path $ResolvedOutDir 'capture-window-inner-hide.command.txt'),
        (Join-Path $ResolvedOutDir 'capture-window-inner-hide.stdout.txt'),
        (Join-Path $ResolvedOutDir 'capture-window-inner-hide.stderr.txt'),
        (Join-Path $ResolvedOutDir 'capture-window-inner-unload.command.txt'),
        (Join-Path $ResolvedOutDir 'capture-window-inner-unload.stdout.txt'),
        (Join-Path $ResolvedOutDir 'capture-window-inner-unload.stderr.txt'),
        (Join-Path $ResolvedOutDir 'capture-window-inner-close.command.txt'),
        (Join-Path $ResolvedOutDir 'capture-window-inner-close.stdout.txt'),
        (Join-Path $ResolvedOutDir 'capture-window-inner-close.stderr.txt'),
        (Join-Path $ResolvedOutDir 'capture-window-outer-after-hide.command.txt'),
        (Join-Path $ResolvedOutDir 'capture-window-outer-after-hide.stdout.txt'),
        (Join-Path $ResolvedOutDir 'capture-window-outer-after-hide.stderr.txt')
    )

    return [ordered]@{
        schema = 'oxforms.office_oracle.w006_nested_modal_lifecycle_capture.v1'
        bead = $captureBead
        capture_id = $CaptureId
        status = $Status
        fixture = [ordered]@{
            id = $Fixture.id
            inputs = $FixtureHashes
        }
        commands = [ordered]@{
            capture = ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'capture.command.txt')
            rerun_note = 'Run this script from the repository root. It generates the workbook, opens Excel, drives the outer and inner UserForms with public Windows input, exports W006NestedModalLog, writes manifests, and checksums artifacts.'
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
            run_summary = if ($null -ne $RunSummaryPath) { ConvertTo-RepoRelative $RunSummaryPath } else { $null }
            event_log_json = if ($null -ne $EventLog) { $EventLog.json } else { $null }
            event_log_csv = if ($null -ne $EventLog) { $EventLog.csv } else { $null }
            input_actions = if (Test-Path -LiteralPath (Join-Path $ResolvedOutDir 'input-actions.json') -PathType Leaf) { ConvertTo-RepoRelative (Join-Path $ResolvedOutDir 'input-actions.json') } else { $null }
            command_logs = Get-ExistingRepoRelativeFiles -Paths $commandLogCandidates
        }
        observed_coverage = if ($null -ne $EventLog) {
            [ordered]@{
                row_count = $EventLog.row_count
                event_names = $EventLog.event_names
                form_identities = $EventLog.form_identities
                manual_inputs = @()
                input_method = 'automated public Windows SendInput and SendKeys'
            }
        } else {
            [ordered]@{
                row_count = 0
                event_names = @()
                form_identities = @()
                manual_inputs = @()
                input_method = 'not completed'
            }
        }
        blockers = @($Blockers)
        trace_replay_implications = @(
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 5: nested modal rows require parent_row_id and nesting_depth.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 9: modal show, hide, unload, dispatch, and platform work must record effect_requested rows separately from effect_completed rows.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 11: lifecycle_pump rows must carry modal depth, active form/window/control, close/query/hide/unload/terminate reasons, cancellation status, and causal row ids.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 14: validators must check parent/nesting and reducer/effect/dispatch causal ordering.'
        )
        warnings = @(
            'This is black-box Excel/MSForms event evidence only; no OxForms output was compared.',
            'Missing event rows are unobserved rows in this run, not negative facts about all MSForms behavior.',
            'Desktop theme, DPI, input focus, Excel/MSForms version, and macro security can affect observed rows.'
        )
        clean_room = [ordered]@{
            source = 'Repo-owned fixture input generated through public Excel/VBIDE automation and driven through public Windows input APIs.'
            prohibited = 'No Office internals, decompilation, disassembly, non-public source, or OxForms output comparison were used.'
        }
        non_claims = @(
            'No OxForms runtime modal, reentrant pump, hide/unload, QueryClose, or Terminate behavior is implemented or claimed.',
            'This capture is not an exhaustive MSForms parity matrix.'
        )
    }
}

$fixtureRoot = Resolve-InRepoPath $FixtureDir
$fixturePath = Join-Path $fixtureRoot 'fixture.json'
if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) {
    throw "Fixture manifest not found: $fixturePath"
}

$fixture = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
[void](Get-RequiredValue $fixture 'id')
[void](Get-RequiredValue $fixture 'forms')
[void](Get-RequiredValue $fixture 'workbook')
$outerForm = Get-FormSpec -Fixture $fixture -Identity 'outer'
$innerForm = Get-FormSpec -Fixture $fixture -Identity 'inner'
[void](Resolve-FixtureSourcePath -FixtureRoot $fixtureRoot -Path ([string](Get-RequiredValue $outerForm 'codeBehindSourcePath')))
[void](Resolve-FixtureSourcePath -FixtureRoot $fixtureRoot -Path ([string](Get-RequiredValue $innerForm 'codeBehindSourcePath')))
[void](Resolve-FixtureSourcePath -FixtureRoot $fixtureRoot -Path ([string](Get-RequiredValue $fixture.workbook 'standardModuleSourcePath')))

if ($DryRun) {
    Write-Host "Fixture: $($fixture.id)"
    Write-Host "Manifest: $fixturePath"
    Write-Host "Forms: $(@($fixture.forms).Count)"
    Write-Host 'Dry run only: manifest and repository paths are valid. Excel was not started.'
    exit 0
}

$resolvedOutDir = Resolve-CaptureDir -Directory $OutDir
$captureId = Split-Path -Leaf $resolvedOutDir
$workbookPath = Join-Path $resolvedOutDir ([string](Get-RequiredValue $fixture.workbook 'fileName'))
$fixtureHashes = Get-FixtureHashes -Fixture $fixture -FixtureRoot $fixtureRoot -FixturePath $fixturePath
$inputActions = [System.Collections.Generic.List[object]]::new()
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
    New-WorkbookFromFixture -Fixture $fixture -FixtureRoot $fixtureRoot -WorkbookPath $workbookPath
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
    $excel.Run([string](Get-RequiredValue $fixture.workbook 'clearLogMacroName'))
    $excel.Run([string](Get-RequiredValue $fixture.workbook 'showMacroName'))
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'outer_form_shown_modeless'
    Start-Sleep -Milliseconds ($ActionDelayMilliseconds * 2)

    $outerWindow = Wait-ForOracleWindow -Title $outerTitle -TimeoutSeconds 30
    $outerInitialManifest = Invoke-CaptureWindow -ResolvedOutDir $resolvedOutDir -Name 'outer-initial' -Title $outerTitle
    $outerCalibration = Analyze-FormCoordinates -ResolvedOutDir $resolvedOutDir -Name 'outer-initial' -FormSpec $outerForm -WindowManifest $outerInitialManifest -AnchorControlName 'OuterAnchorLabel'
    $outerWindow = Wait-ForOracleWindow -Title $outerTitle -TimeoutSeconds 10

    Invoke-ClickControl -Window $outerWindow -FormSpec $outerForm -Calibration $outerCalibration -ControlName 'OuterShowInnerHideButton' -Actions $inputActions -Scenario 'inner_hide_button' -TargetIntent 'Outer button enters inner modal form for inner Hide path'
    $innerWindow = Wait-ForOracleWindow -Title $innerTitle -TimeoutSeconds 30
    $innerHideManifest = Invoke-CaptureWindow -ResolvedOutDir $resolvedOutDir -Name 'inner-hide' -Title $innerTitle
    $innerHideCalibration = Analyze-FormCoordinates -ResolvedOutDir $resolvedOutDir -Name 'inner-hide' -FormSpec $innerForm -WindowManifest $innerHideManifest -AnchorControlName 'InnerAnchorLabel'
    $innerWindow = Wait-ForOracleWindow -Title $innerTitle -TimeoutSeconds 10
    Invoke-ClickControl -Window $innerWindow -FormSpec $innerForm -Calibration $innerHideCalibration -ControlName 'InnerHideButton' -Actions $inputActions -Scenario 'inner_hide_button' -TargetIntent 'Inner button calls Me.Hide from the inner modal handler'
    [void](Wait-ForOracleWindowClosed -Title $innerTitle -TimeoutSeconds 12)

    $outerWindow = Wait-ForOracleWindow -Title $outerTitle -TimeoutSeconds 20
    Invoke-ClickControl -Window $outerWindow -FormSpec $outerForm -Calibration $outerCalibration -ControlName 'OuterShowInnerUnloadButton' -Actions $inputActions -Scenario 'inner_unload_button' -TargetIntent 'Outer button enters inner modal form for inner Unload path'
    $innerWindow = Wait-ForOracleWindow -Title $innerTitle -TimeoutSeconds 30
    $innerUnloadManifest = Invoke-CaptureWindow -ResolvedOutDir $resolvedOutDir -Name 'inner-unload' -Title $innerTitle
    $innerUnloadCalibration = Analyze-FormCoordinates -ResolvedOutDir $resolvedOutDir -Name 'inner-unload' -FormSpec $innerForm -WindowManifest $innerUnloadManifest -AnchorControlName 'InnerAnchorLabel'
    $innerWindow = Wait-ForOracleWindow -Title $innerTitle -TimeoutSeconds 10
    Invoke-ClickControl -Window $innerWindow -FormSpec $innerForm -Calibration $innerUnloadCalibration -ControlName 'InnerUnloadButton' -Actions $inputActions -Scenario 'inner_unload_button' -TargetIntent 'Inner button calls Unload Me from the inner modal handler'
    [void](Wait-ForOracleWindowClosed -Title $innerTitle -TimeoutSeconds 12)

    $outerWindow = Wait-ForOracleWindow -Title $outerTitle -TimeoutSeconds 20
    Invoke-ClickControl -Window $outerWindow -FormSpec $outerForm -Calibration $outerCalibration -ControlName 'OuterShowInnerCloseButton' -Actions $inputActions -Scenario 'inner_system_close_alt_f4' -TargetIntent 'Outer button enters inner modal form for public system close path'
    $innerWindow = Wait-ForOracleWindow -Title $innerTitle -TimeoutSeconds 30
    $innerCloseManifest = Invoke-CaptureWindow -ResolvedOutDir $resolvedOutDir -Name 'inner-close' -Title $innerTitle
    $innerWindow = Wait-ForOracleWindow -Title $innerTitle -TimeoutSeconds 10
    try {
        Invoke-AltF4 -Window $innerWindow -Actions $inputActions -Scenario 'inner_system_close_alt_f4' -TargetIntent 'Public system close path for the inner modal UserForm'
        if (-not (Wait-ForOracleWindowClosed -Title $innerTitle -TimeoutSeconds 12)) {
            throw 'Inner modal window remained visible after Alt+F4.'
        }
    } catch {
        $blockers.Add([ordered]@{
            surface = 'inner_system_close_alt_f4'
            reason = 'Public SendKeys Alt+F4 did not close the inner modal window in this desktop session.'
            detail = $_.Exception.Message
            non_claim = 'No inner system-close QueryClose ordering is claimed from this run unless matching rows appear in the event log.'
        }) | Out-Null
        $innerCloseCleanupCalibration = Analyze-FormCoordinates -ResolvedOutDir $resolvedOutDir -Name 'inner-close-cleanup' -FormSpec $innerForm -WindowManifest $innerCloseManifest -AnchorControlName 'InnerAnchorLabel'
        $innerWindow = Wait-ForOracleWindow -Title $innerTitle -TimeoutSeconds 10
        Invoke-ClickControl -Window $innerWindow -FormSpec $innerForm -Calibration $innerCloseCleanupCalibration -ControlName 'InnerUnloadButton' -Actions $inputActions -Scenario 'inner_system_close_alt_f4_cleanup' -TargetIntent 'Cleanup inner modal window after Alt+F4 blocker'
        [void](Wait-ForOracleWindowClosed -Title $innerTitle -TimeoutSeconds 12)
    }

    $outerWindow = Wait-ForOracleWindow -Title $outerTitle -TimeoutSeconds 20
    Invoke-ClickControl -Window $outerWindow -FormSpec $outerForm -Calibration $outerCalibration -ControlName 'OuterHideButton' -Actions $inputActions -Scenario 'outer_hide_button' -TargetIntent 'Outer button calls Me.Hide'
    [void](Wait-ForOracleWindowClosed -Title $outerTitle -TimeoutSeconds 12)

    $excel.Run([string](Get-RequiredValue $fixture.workbook 'showMacroName'))
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step 'outer_form_reshown_after_hide'
    Start-Sleep -Milliseconds ($ActionDelayMilliseconds * 2)
    $outerWindow = Wait-ForOracleWindow -Title $outerTitle -TimeoutSeconds 20
    $outerAfterHideManifest = Invoke-CaptureWindow -ResolvedOutDir $resolvedOutDir -Name 'outer-after-hide' -Title $outerTitle
    $outerAfterHideCalibration = Analyze-FormCoordinates -ResolvedOutDir $resolvedOutDir -Name 'outer-after-hide' -FormSpec $outerForm -WindowManifest $outerAfterHideManifest -AnchorControlName 'OuterAnchorLabel'
    $outerWindow = Wait-ForOracleWindow -Title $outerTitle -TimeoutSeconds 10
    Invoke-ClickControl -Window $outerWindow -FormSpec $outerForm -Calibration $outerAfterHideCalibration -ControlName 'OuterUnloadButton' -Actions $inputActions -Scenario 'outer_unload_button' -TargetIntent 'Outer button calls Unload Me'
    [void](Wait-ForOracleWindowClosed -Title $outerTitle -TimeoutSeconds 12)

    $inputActionsPath = Join-Path $resolvedOutDir 'input-actions.json'
    Write-JsonFile -Path $inputActionsPath -Value ([ordered]@{
        schema = 'oxforms.office_oracle.w006_nested_modal_input_actions.v1'
        bead = $captureBead
        manual_inputs = @()
        automated_inputs = @($inputActions)
        blockers = @($blockers)
        notes = @(
            'Public user32 SendInput and SendKeys are evidence-driving infrastructure only.',
            'Input coordinates are derived from repo-owned fixture geometry and screenshot anchor labels.'
        )
    })

    $eventLog = Export-WorksheetLog -Workbook $workbook -ResolvedOutDir $resolvedOutDir -AutomatedInputs @($inputActions)
    $runSummary = New-RunSummary -CaptureId $captureId -EventLog $eventLog -Blockers @($blockers)
    $runSummaryPath = Join-Path $resolvedOutDir 'run-summary.json'
    Write-JsonFile -Path $runSummaryPath -Value $runSummary
    $workbook.Save()
    Write-ProgressStep -ResolvedOutDir $resolvedOutDir -Step ('event_log_exported_rows=' + $eventLog.row_count)

    $manifest = New-Manifest -Status 'captured' -ResolvedOutDir $resolvedOutDir -CaptureId $captureId -Fixture $fixture -FixtureHashes $fixtureHashes -WorkbookPath $workbookPath -ExcelInfo $excelInfo -EventLog $eventLog -RunSummaryPath $runSummaryPath -Blockers @($blockers)
    Write-JsonFile -Path (Join-Path $resolvedOutDir 'oracle-capture-manifest.json') -Value $manifest
    Write-CaptureReadme -ResolvedOutDir $resolvedOutDir -Manifest $manifest
    Write-Checksums -ResolvedOutDir $resolvedOutDir

    Write-Host "W006 nested modal lifecycle capture complete: $resolvedOutDir"
    Write-Host "Rows: $($eventLog.row_count)"
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
        schema = 'oxforms.office_oracle.w006_nested_modal_blocker.v1'
        bead = $captureBead
        capture_id = $captureId
        captured_at_utc = (Get-Date).ToUniversalTime().ToString('o')
        surface = 'nested_modal_lifecycle_oracle_capture'
        status = 'blocked'
        reason = $_.Exception.Message
        category = 'public_excel_vbide_or_windows_input_capture_blocker'
        facts = @(
            'The repo-owned fixture manifest and source files were loaded before the live capture path.',
            ('Last capture-progress entry: ' + $lastProgressEntry),
            'No worksheet event-log rows are included in this blocker artifact.'
        )
        assumptions = @(
            'The failure belongs to public Excel/VBIDE automation, public Windows input/capture automation, or the fixture code path named by the exception.'
        )
        unknowns = @(
            'No nested modal MSForms event sequence, outer/inner form identity rows, show-mode rows, active form/window/control rows, close-origin rows, QueryClose Cancel values, CloseMode values, hide/unload rows, or Terminate rows are proven by this blocker.',
            'Rows absent from this run remain unknown and are not negative MSForms facts.'
        )
        blocked_recording_fields = @(
            'event sequence',
            'outer and inner form identity',
            'show mode',
            'active form/window/control',
            'close origin',
            'QueryClose Cancel before and after values',
            'CloseMode',
            'hide/unload/Terminate rows'
        )
        trace_replay_implications = @(
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 5 still requires any future nested modal rows to carry parent_row_id and nesting_depth.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 9 still requires modal show, hide, unload, VBA dispatch, and platform work to preserve separate effect_requested and effect_completed rows.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 11 still requires lifecycle_pump rows to carry modal depth, active form/window/control, close/query/hide/unload/terminate reasons, cancellation status, and causal row ids.',
            'docs/specs/TRACE_REPLAY_SCHEMA.md section 14 still requires validators to check parent/nesting relationships and reducer/effect/dispatch causal ordering.'
        )
        clean_room = [ordered]@{
            source = 'Repo-owned fixture input, public Excel/VBIDE automation attempt, public Windows process/window/input/capture APIs, and local command/progress logs.'
            prohibited = 'No Office internals, decompilation, disassembly, non-public source, or OxForms output comparison were used.'
        }
        non_claims = @(
            'No OxForms runtime behavior is implemented or claimed.',
            'No nested modal MSForms ordering is inferred from this blocker.',
            'No missing event row is treated as a negative MSForms fact.'
        )
    }
    $blockers.Add($blocker) | Out-Null
    Write-JsonFile -Path (Join-Path $resolvedOutDir 'blocker.json') -Value $blocker
    Write-BlockedInputActions -ResolvedOutDir $resolvedOutDir -Blockers @($blockers)
    $runSummaryPath = Join-Path $resolvedOutDir 'run-summary.json'
    Write-JsonFile -Path $runSummaryPath -Value (New-BlockedRunSummary -CaptureId $captureId -Blockers @($blockers))
    $manifest = New-Manifest -Status 'blocked' -ResolvedOutDir $resolvedOutDir -CaptureId $captureId -Fixture $fixture -FixtureHashes $fixtureHashes -WorkbookPath $workbookPath -ExcelInfo $excelInfo -EventLog $eventLog -RunSummaryPath $runSummaryPath -Blockers @($blockers)
    Write-JsonFile -Path (Join-Path $resolvedOutDir 'oracle-capture-manifest.json') -Value $manifest
    Write-CaptureReadme -ResolvedOutDir $resolvedOutDir -Manifest $manifest
    Write-Checksums -ResolvedOutDir $resolvedOutDir
    Write-Host "W006 nested modal lifecycle capture blocked: $resolvedOutDir"
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
