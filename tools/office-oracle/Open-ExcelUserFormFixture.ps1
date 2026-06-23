[CmdletBinding()]
param(
    [string]$FixtureDir = (Join-Path $PSScriptRoot '..\..\fixtures\office-oracle\excel-msforms\userforms\rectangle-label'),
    [string]$OutputWorkbook,
    [switch]$Open,
    [int]$HoldSeconds = 0,
    [switch]$KeepExcelOpen,
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))

function Resolve-InRepoPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        $fullPath = [System.IO.Path]::GetFullPath($Path)
    } else {
        $fullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
    }

    $repoPrefix = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if ($fullPath -ne $repoRoot -and -not $fullPath.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path must stay inside the repository: $Path"
    }

    return $fullPath
}

function Get-RequiredValue {
    param(
        [Parameter(Mandatory = $true)]
        $Object,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [switch]$AllowEmpty
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        throw "Fixture manifest is missing required value: $Name"
    }

    if (-not $AllowEmpty -and $property.Value -is [string] -and [string]::IsNullOrWhiteSpace($property.Value)) {
        throw "Fixture manifest has an empty required value: $Name"
    }

    return $property.Value
}

function Get-OptionalValue {
    param(
        $Object,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Release-ComObjectIfPresent {
    param($Object)

    if ($null -ne $Object -and [System.Runtime.InteropServices.Marshal]::IsComObject($Object)) {
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($Object)
    }
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
            return ([System.BitConverter]::ToString($bytes) -replace '-', '').ToUpperInvariant()
        } finally {
            $sha256.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function ConvertTo-VbaStringLiteral {
    param([string]$Value)
    return '"' + ($Value -replace '"', '""') + '"'
}

function ConvertTo-VbaBooleanLiteral {
    param([object]$Value)
    if ([bool]$Value) {
        return 'True'
    }

    return 'False'
}

function ConvertTo-VbaNumberLiteral {
    param([object]$Value)
    return ([double]$Value).ToString([System.Globalization.CultureInfo]::InvariantCulture)
}

function Resolve-FixtureSourcePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FixtureRoot,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        $fullPath = Resolve-InRepoPath $Path
    } else {
        $fullPath = [System.IO.Path]::GetFullPath((Join-Path $FixtureRoot $Path))
        $repoPrefix = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
        if ($fullPath -ne $repoRoot -and -not $fullPath.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Fixture source path must stay inside the repository: $Path"
        }
    }

    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Fixture source file not found: $fullPath"
    }

    return $fullPath
}

function Set-ControlPropertyIfPresent {
    param(
        [Parameter(Mandatory = $true)]
        $ControlObject,
        [Parameter(Mandatory = $true)]
        [string]$FixtureId,
        [Parameter(Mandatory = $true)]
        [string]$ControlName,
        [Parameter(Mandatory = $true)]
        $Spec,
        [Parameter(Mandatory = $true)]
        [string]$ManifestName,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Apply
    )

    $value = Get-OptionalValue $Spec $ManifestName
    if ($null -eq $value) {
        return
    }

    try {
        & $Apply $ControlObject $value
    }
    catch {
        throw "Failed to apply optional control property '$ManifestName' to '$ControlName' from fixture '$FixtureId': $($_.Exception.Message)"
    }
}

function Set-ComponentPropertyValue {
    param(
        [Parameter(Mandatory = $true)]
        $Component,
        [Parameter(Mandatory = $true)]
        [string]$PropertyName,
        [Parameter(Mandatory = $true)]
        $Value
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

function Add-FontSetupLines {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Lines,
        [Parameter(Mandatory = $true)]
        [string]$ControlName,
        $ControlFont
    )

    if ($null -eq $ControlFont) {
        return
    }

    $fontLines = [System.Collections.Generic.List[string]]::new()
    $fontName = Get-OptionalValue $ControlFont 'name'
    $fontSizePt = Get-OptionalValue $ControlFont 'sizePt'
    $fontBold = Get-OptionalValue $ControlFont 'bold'
    $fontItalic = Get-OptionalValue $ControlFont 'italic'
    $fontUnderline = Get-OptionalValue $ControlFont 'underline'
    $fontStrikethrough = Get-OptionalValue $ControlFont 'strikethrough'

    if ($null -ne $fontName -and -not [string]::IsNullOrWhiteSpace([string]$fontName)) {
        $fontLines.Add("        .Font.Name = $(ConvertTo-VbaStringLiteral ([string]$fontName))")
    }
    if ($null -ne $fontSizePt) {
        $fontLines.Add("        .Font.Size = $(ConvertTo-VbaNumberLiteral $fontSizePt)")
    }
    if ($null -ne $fontBold) {
        $fontLines.Add("        .Font.Bold = $(ConvertTo-VbaBooleanLiteral $fontBold)")
    }
    if ($null -ne $fontItalic) {
        $fontLines.Add("        .Font.Italic = $(ConvertTo-VbaBooleanLiteral $fontItalic)")
    }
    if ($null -ne $fontUnderline) {
        $fontLines.Add("        .Font.Underline = $(ConvertTo-VbaBooleanLiteral $fontUnderline)")
    }
    if ($null -ne $fontStrikethrough) {
        $fontLines.Add("        .Font.Strikethrough = $(ConvertTo-VbaBooleanLiteral $fontStrikethrough)")
    }

    if ($fontLines.Count -eq 0) {
        return
    }

    $controlNameLiteral = ConvertTo-VbaStringLiteral $ControlName
    $Lines.Add("    With $formName.Controls($controlNameLiteral)")
    foreach ($line in $fontLines) {
        $Lines.Add($line)
    }
    $Lines.Add('    End With')
}

$fixtureRoot = Resolve-InRepoPath $FixtureDir
$manifestPath = Join-Path $fixtureRoot 'fixture.json'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Fixture manifest not found: $manifestPath"
}

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$fixtureId = Get-RequiredValue $manifest 'id'
$form = Get-RequiredValue $manifest 'form'
$legacyControl = Get-OptionalValue $manifest 'control'
$controlsValue = Get-OptionalValue $manifest 'controls'
$workbookSpec = Get-RequiredValue $manifest 'workbook'
$evidenceSpec = Get-OptionalValue $manifest 'evidence'
$codeBehindSpec = Get-OptionalValue $manifest 'codeBehind'

$formName = Get-RequiredValue $form 'name'
$formCaption = Get-RequiredValue $form 'caption'
$formWidthPt = [single](Get-RequiredValue $form 'widthPt')
$formHeightPt = [single](Get-RequiredValue $form 'heightPt')
$formStartupPosition = [int](Get-RequiredValue $form 'startupPosition')
$workbookFileName = Get-RequiredValue $workbookSpec 'fileName'
$vbaModuleName = Get-RequiredValue $workbookSpec 'vbaModuleName'
$showMacroName = Get-RequiredValue $workbookSpec 'showMacroName'
$hideMacroName = Get-RequiredValue $workbookSpec 'hideMacroName'
$additionalModuleSourcePath = Get-OptionalValue $workbookSpec 'additionalModuleSourcePath'

if ($null -ne $controlsValue) {
    $controls = @($controlsValue)
} elseif ($null -ne $legacyControl) {
    $controls = @($legacyControl)
} else {
    throw "Fixture manifest is missing required value: control or controls"
}

if ($controls.Count -eq 0) {
    throw "Fixture manifest must define at least one control."
}

foreach ($control in $controls) {
    [void](Get-RequiredValue $control 'name')
    [void](Get-RequiredValue $control 'type')
    [void](Get-RequiredValue $control 'leftPt')
    [void](Get-RequiredValue $control 'topPt')
    [void](Get-RequiredValue $control 'widthPt')
    [void](Get-RequiredValue $control 'heightPt')
}

$codeBehindSourcePath = $null
if ($null -ne $codeBehindSpec) {
    $sourcePath = Get-RequiredValue $codeBehindSpec 'sourcePath'
    $codeBehindSourcePath = Resolve-FixtureSourcePath -FixtureRoot $fixtureRoot -Path $sourcePath
}

$additionalModuleFullPath = $null
if (-not [string]::IsNullOrWhiteSpace([string]$additionalModuleSourcePath)) {
    $additionalModuleFullPath = Resolve-FixtureSourcePath -FixtureRoot $fixtureRoot -Path ([string]$additionalModuleSourcePath)
}

if ([string]::IsNullOrWhiteSpace($OutputWorkbook)) {
    $defaultGeneratedWorkbookDir = Get-OptionalValue $evidenceSpec 'defaultGeneratedWorkbookDir'
    if ([string]::IsNullOrWhiteSpace([string]$defaultGeneratedWorkbookDir)) {
        $defaultGeneratedWorkbookDir = 'docs\evidence\W003_excel_forms_oracle_capture\captures\generated-workbooks'
    }

    $OutputWorkbook = Join-Path $repoRoot (Join-Path $defaultGeneratedWorkbookDir $workbookFileName)
} else {
    $OutputWorkbook = Resolve-InRepoPath $OutputWorkbook
}

Write-Host "Fixture: $fixtureId"
Write-Host "Manifest: $manifestPath"
Write-Host "Output workbook: $OutputWorkbook"
Write-Host "Form: $formName / '$formCaption'"
Write-Host "Controls: $($controls.Count)"
foreach ($control in $controls) {
    $controlName = Get-RequiredValue $control 'name'
    $controlType = Get-RequiredValue $control 'type'
    Write-Host "Control: $controlType $controlName"
}
if ($null -ne $codeBehindSourcePath) {
    Write-Host "Form code-behind: $codeBehindSourcePath"
}
if ($null -ne $additionalModuleFullPath) {
    Write-Host "Additional module code: $additionalModuleFullPath"
}

if ($DryRun) {
    Write-Host 'Dry run only: manifest and repository paths are valid. Excel was not started.'
    exit 0
}

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    throw 'Excel COM automation requires Windows. Use -DryRun on non-Windows hosts.'
}

$outputParent = Split-Path -Parent $OutputWorkbook
New-Item -ItemType Directory -Force -Path $outputParent | Out-Null

if (Test-Path -LiteralPath $OutputWorkbook) {
    if (-not $Force) {
        throw "Output workbook already exists. Pass -Force to replace it: $OutputWorkbook"
    }

    Remove-Item -LiteralPath $OutputWorkbook -Force
}

$excel = $null
$workbook = $null
$vbProject = $null
$formComponent = $null
$standardModule = $null
$generatedWorkbookPath = $null

try {
    try {
        $excel = New-Object -ComObject Excel.Application
    } catch {
        throw "Microsoft Excel COM automation is unavailable: $($_.Exception.Message)"
    }

    $excel.Visible = [bool]$Open
    $excel.DisplayAlerts = $false

    $workbook = $excel.Workbooks.Add()

    try {
        $vbProject = $workbook.VBProject
    } catch {
        throw "Excel blocked access to the VBA project object model. Enable 'Trust access to the VBA project object model' or use the documented manual procedure."
    }

    $vbextCtStdModule = 1
    $vbextCtMsForm = 3

    $formComponent = $vbProject.VBComponents.Add($vbextCtMsForm)
    $formComponent.Name = $formName

    $designer = $formComponent.Designer
    # Keep component property writes behind one helper: PowerShell's COM binder
    # can otherwise cache the VBIDE .Value setter too narrowly across types.
    Set-ComponentPropertyValue $formComponent 'Caption' $formCaption
    Set-ComponentPropertyValue $formComponent 'Width' $formWidthPt
    Set-ComponentPropertyValue $formComponent 'Height' $formHeightPt
    Set-ComponentPropertyValue $formComponent 'StartUpPosition' ([single]$formStartupPosition)

    $fontSetupLines = [System.Collections.Generic.List[string]]::new()
    foreach ($control in $controls) {
        $controlName = Get-RequiredValue $control 'name'
        $controlType = Get-RequiredValue $control 'type'
        $controlLeftPt = [single](Get-RequiredValue $control 'leftPt')
        $controlTopPt = [single](Get-RequiredValue $control 'topPt')
        $controlWidthPt = [single](Get-RequiredValue $control 'widthPt')
        $controlHeightPt = [single](Get-RequiredValue $control 'heightPt')

        $createdControl = $designer.Controls.Add($controlType, $controlName, $true)
        $createdControl.Left = $controlLeftPt
        $createdControl.Top = $controlTopPt
        $createdControl.Width = $controlWidthPt
        $createdControl.Height = $controlHeightPt

        Set-ControlPropertyIfPresent $createdControl $fixtureId $controlName $control 'caption' { param($c, $v) $c.Caption = [string]$v }
        Set-ControlPropertyIfPresent $createdControl $fixtureId $controlName $control 'text' { param($c, $v) $c.Text = [string]$v }
        Set-ControlPropertyIfPresent $createdControl $fixtureId $controlName $control 'value' { param($c, $v) $c.Value = $v }
        Set-ControlPropertyIfPresent $createdControl $fixtureId $controlName $control 'backColorOle' { param($c, $v) $c.BackColor = [int]$v }
        Set-ControlPropertyIfPresent $createdControl $fixtureId $controlName $control 'foreColorOle' { param($c, $v) $c.ForeColor = [int]$v }
        Set-ControlPropertyIfPresent $createdControl $fixtureId $controlName $control 'borderStyle' { param($c, $v) $c.BorderStyle = [int]$v }
        Set-ControlPropertyIfPresent $createdControl $fixtureId $controlName $control 'textAlign' { param($c, $v) $c.TextAlign = [int]$v }
        Set-ControlPropertyIfPresent $createdControl $fixtureId $controlName $control 'wordWrap' { param($c, $v) $c.WordWrap = [bool]$v }
        Set-ControlPropertyIfPresent $createdControl $fixtureId $controlName $control 'autoSize' { param($c, $v) $c.AutoSize = [bool]$v }
        Set-ControlPropertyIfPresent $createdControl $fixtureId $controlName $control 'enabled' { param($c, $v) $c.Enabled = [bool]$v }
        Set-ControlPropertyIfPresent $createdControl $fixtureId $controlName $control 'visible' { param($c, $v) $c.Visible = [bool]$v }
        Set-ControlPropertyIfPresent $createdControl $fixtureId $controlName $control 'tabIndex' { param($c, $v) $c.TabIndex = [int]$v }
        Set-ControlPropertyIfPresent $createdControl $fixtureId $controlName $control 'tabStop' { param($c, $v) $c.TabStop = [bool]$v }
        Set-ControlPropertyIfPresent $createdControl $fixtureId $controlName $control 'default' { param($c, $v) $c.Default = [bool]$v }
        Set-ControlPropertyIfPresent $createdControl $fixtureId $controlName $control 'cancel' { param($c, $v) $c.Cancel = [bool]$v }
        Set-ControlPropertyIfPresent $createdControl $fixtureId $controlName $control 'accelerator' { param($c, $v) $c.Accelerator = [string]$v }
        Set-ControlPropertyIfPresent $createdControl $fixtureId $controlName $control 'takeFocusOnClick' { param($c, $v) $c.TakeFocusOnClick = [bool]$v }
        Set-ControlPropertyIfPresent $createdControl $fixtureId $controlName $control 'multiLine' { param($c, $v) $c.MultiLine = [bool]$v }
        Set-ControlPropertyIfPresent $createdControl $fixtureId $controlName $control 'enterKeyBehavior' { param($c, $v) $c.EnterKeyBehavior = [bool]$v }
        Set-ControlPropertyIfPresent $createdControl $fixtureId $controlName $control 'hideSelection' { param($c, $v) $c.HideSelection = [bool]$v }

        Add-FontSetupLines -Lines $fontSetupLines -ControlName $controlName -ControlFont (Get-OptionalValue $control 'font')
    }

    if ($null -ne $codeBehindSourcePath) {
        $formCodeBehind = Get-Content -Raw -LiteralPath $codeBehindSourcePath
        $formComponent.CodeModule.AddFromString($formCodeBehind)
    }

    $standardModule = $vbProject.VBComponents.Add($vbextCtStdModule)
    $standardModule.Name = $vbaModuleName

    if ($fontSetupLines.Count -gt 0) {
        $fontSetupBody = $fontSetupLines -join "`r`n"
    } else {
        $fontSetupBody = "    ' No runtime font requests in this fixture."
    }

    $additionalModuleCode = ''
    if ($null -ne $additionalModuleFullPath) {
        $additionalModuleCode = (Get-Content -Raw -LiteralPath $additionalModuleFullPath).TrimEnd() + "`r`n`r`n"
    }

    $moduleCode = @"
Option Explicit

$additionalModuleCode
Private Sub ConfigureOracleControls()
$fontSetupBody
End Sub

Public Sub $showMacroName()
    ConfigureOracleControls
    $formName.Tag = "show_mode=modeless"
    $formName.Show vbModeless
End Sub

Public Sub $hideMacroName()
    Unload $formName
End Sub
"@

    $standardModule.CodeModule.AddFromString($moduleCode)

    $xlOpenXmlWorkbookMacroEnabled = 52
    $workbook.SaveAs($OutputWorkbook, $xlOpenXmlWorkbookMacroEnabled)
    $generatedWorkbookPath = $OutputWorkbook
    Write-Host "Generated workbook: $OutputWorkbook"

    if ($Open) {
        Write-Host "Opening UserForm with macro: $showMacroName"
        $excel.Run($showMacroName)

        if ($HoldSeconds -gt 0) {
            Write-Host "Holding Excel/UserForm open for $HoldSeconds second(s)."
            Start-Sleep -Seconds $HoldSeconds
        } elseif (-not $KeepExcelOpen) {
            Write-Host 'UserForm is open. Press Enter to close Excel.'
            [void][System.Console]::ReadLine()
        }
    }
} finally {
    if ($null -ne $excel) {
        if (-not $KeepExcelOpen) {
            if ($null -ne $workbook) {
                try {
                    $workbook.Close($false)
                } catch {
                    Write-Warning "Failed to close workbook cleanly: $($_.Exception.Message)"
                }
            }

            try {
                $excel.Quit()
            } catch {
                Write-Warning "Failed to quit Excel cleanly: $($_.Exception.Message)"
            }

            if (-not [string]::IsNullOrWhiteSpace($generatedWorkbookPath) -and (Test-Path -LiteralPath $generatedWorkbookPath)) {
                try {
                    $hash = Get-Sha256Hex -Path $generatedWorkbookPath
                    Write-Host "Generated workbook SHA256: $hash"
                } catch {
                    Write-Warning "Failed to hash generated workbook after closing Excel: $($_.Exception.Message)"
                }
            }
        } else {
            Write-Host 'Leaving Excel open because -KeepExcelOpen was supplied.'
        }
    }

    Release-ComObjectIfPresent $standardModule
    Release-ComObjectIfPresent $formComponent
    Release-ComObjectIfPresent $vbProject
    Release-ComObjectIfPresent $workbook
    Release-ComObjectIfPresent $excel
}
