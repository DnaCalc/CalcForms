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

function Set-DesignerProperty {
    param(
        [Parameter(Mandatory = $true)]
        $Target,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        $Value
    )

    try {
        if ($null -ne $Target.PSObject.Properties['Properties']) {
            $Target.Properties.Item($Name).Value = $Value
        } else {
            $Target.$Name = $Value
        }
    } catch {
        try {
            $Target.$Name = $Value
        } catch {
            throw "Failed to set designer property '$Name' to '$Value': $($_.Exception.Message)"
        }
    }
}

function Release-ComObjectIfPresent {
    param($Object)

    if ($null -ne $Object -and [System.Runtime.InteropServices.Marshal]::IsComObject($Object)) {
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($Object)
    }
}

$fixtureRoot = Resolve-InRepoPath $FixtureDir
$manifestPath = Join-Path $fixtureRoot 'fixture.json'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Fixture manifest not found: $manifestPath"
}

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$fixtureId = Get-RequiredValue $manifest 'id'
$form = Get-RequiredValue $manifest 'form'
$control = Get-RequiredValue $manifest 'control'
$workbookSpec = Get-RequiredValue $manifest 'workbook'

$formName = Get-RequiredValue $form 'name'
$formCaption = Get-RequiredValue $form 'caption'
$formWidthPt = [single](Get-RequiredValue $form 'widthPt')
$formHeightPt = [single](Get-RequiredValue $form 'heightPt')
$formStartupPosition = [int](Get-RequiredValue $form 'startupPosition')
$controlName = Get-RequiredValue $control 'name'
$controlType = Get-RequiredValue $control 'type'
$controlCaption = [string](Get-RequiredValue $control 'caption' -AllowEmpty)
$controlLeftPt = [single](Get-RequiredValue $control 'leftPt')
$controlTopPt = [single](Get-RequiredValue $control 'topPt')
$controlWidthPt = [single](Get-RequiredValue $control 'widthPt')
$controlHeightPt = [single](Get-RequiredValue $control 'heightPt')
$controlBackColorOle = [int](Get-RequiredValue $control 'backColorOle')
$controlBorderStyle = [int](Get-RequiredValue $control 'borderStyle')
$workbookFileName = Get-RequiredValue $workbookSpec 'fileName'
$vbaModuleName = Get-RequiredValue $workbookSpec 'vbaModuleName'
$showMacroName = Get-RequiredValue $workbookSpec 'showMacroName'
$hideMacroName = Get-RequiredValue $workbookSpec 'hideMacroName'

if ([string]::IsNullOrWhiteSpace($OutputWorkbook)) {
    $OutputWorkbook = Join-Path $repoRoot (Join-Path 'docs\evidence\W003_excel_forms_oracle_capture\captures\generated-workbooks' $workbookFileName)
} else {
    $OutputWorkbook = Resolve-InRepoPath $OutputWorkbook
}

Write-Host "Fixture: $fixtureId"
Write-Host "Manifest: $manifestPath"
Write-Host "Output workbook: $OutputWorkbook"
Write-Host "Form: $formName / '$formCaption'"
Write-Host "Control: $controlType $controlName"

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
    Set-DesignerProperty $designer 'Caption' $formCaption
    Set-DesignerProperty $designer 'Width' $formWidthPt
    Set-DesignerProperty $designer 'Height' $formHeightPt
    Set-DesignerProperty $designer 'StartUpPosition' $formStartupPosition

    $label = $designer.Controls.Add($controlType, $controlName, $true)
    $label.Caption = $controlCaption
    $label.Left = $controlLeftPt
    $label.Top = $controlTopPt
    $label.Width = $controlWidthPt
    $label.Height = $controlHeightPt
    $label.BackColor = $controlBackColorOle
    $label.BorderStyle = $controlBorderStyle

    $standardModule = $vbProject.VBComponents.Add($vbextCtStdModule)
    $standardModule.Name = $vbaModuleName

    $moduleCode = @"
Option Explicit

Public Sub $showMacroName()
    $formName.Show vbModeless
End Sub

Public Sub $hideMacroName()
    Unload $formName
End Sub
"@

    $standardModule.CodeModule.AddFromString($moduleCode)

    $xlOpenXmlWorkbookMacroEnabled = 52
    $workbook.SaveAs($OutputWorkbook, $xlOpenXmlWorkbookMacroEnabled)

    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $OutputWorkbook
    Write-Host "Generated workbook SHA256: $($hash.Hash)"

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
