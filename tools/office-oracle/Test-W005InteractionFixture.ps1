[CmdletBinding()]
param(
    [string]$FixtureDir = 'fixtures\office-oracle\excel-msforms\userforms\interaction-events'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

function Resolve-RepoPath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        $fullPath = [System.IO.Path]::GetFullPath($Path)
    }
    else {
        $fullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
    }

    $repoWithSeparator = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    if (-not ($fullPath.Equals($repoRoot, $comparison) -or $fullPath.StartsWith($repoWithSeparator, $comparison))) {
        throw "Path '$Path' resolves outside repository root '$repoRoot'."
    }

    return $fullPath
}

function Get-PropertyValue {
    param(
        [object]$Object,
        [string]$Name
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Assert-Contains {
    param(
        [string]$Content,
        [string]$Needle,
        [string]$Description
    )

    if (-not $Content.Contains($Needle)) {
        throw "Missing $Description ('$Needle')."
    }
}

$fixtureRoot = Resolve-RepoPath -Path $FixtureDir
$manifestPath = Join-Path $fixtureRoot 'fixture.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Fixture manifest not found: $manifestPath"
}

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
if ($manifest.id -ne 'excel-msforms-w005-interaction-events-v1') {
    throw "Unexpected W005 fixture id '$($manifest.id)'."
}

if ([string]::IsNullOrWhiteSpace([string]$manifest.form.name)) {
    throw 'W005 fixture is missing form.name.'
}
if ([string]$manifest.form.name -ne [string]$manifest.codeBehind.targetModule) {
    throw "W005 fixture form.name '$($manifest.form.name)' must match codeBehind.targetModule '$($manifest.codeBehind.targetModule)'."
}
if ([string]$manifest.form.name -notmatch '^[A-Za-z][A-Za-z0-9_]{0,30}$') {
    throw "W005 fixture form.name '$($manifest.form.name)' is not a valid VBA component identifier of 31 characters or fewer."
}

$controls = @(Get-PropertyValue -Object $manifest -Name 'controls')
if ($controls.Count -lt 4) {
    throw "W005 fixture should define at least four controls; found $($controls.Count)."
}

$controlKinds = @($controls | ForEach-Object { $_.kind })
foreach ($requiredKind in @('MSForms.Label', 'MSForms.TextBox', 'MSForms.CommandButton')) {
    if ($requiredKind -notin $controlKinds) {
        throw "W005 fixture is missing required control kind '$requiredKind'."
    }
}

$defaultButton = @($controls | Where-Object { $_.kind -eq 'MSForms.CommandButton' -and $_.default -eq $true })
$cancelButton = @($controls | Where-Object { $_.kind -eq 'MSForms.CommandButton' -and $_.cancel -eq $true })
if ($defaultButton.Count -eq 0) {
    throw 'W005 fixture is missing a default CommandButton.'
}
if ($cancelButton.Count -eq 0) {
    throw 'W005 fixture is missing a cancel CommandButton.'
}

$codeBehind = Get-PropertyValue -Object $manifest -Name 'codeBehind'
$codeBehindSourcePath = Get-PropertyValue -Object $codeBehind -Name 'sourcePath'
if ([string]::IsNullOrWhiteSpace($codeBehindSourcePath)) {
    throw 'W005 fixture is missing codeBehind.sourcePath.'
}

$codePath = Join-Path $fixtureRoot $codeBehindSourcePath
if (-not (Test-Path -LiteralPath $codePath -PathType Leaf)) {
    throw "Code-behind source not found: $codePath"
}

$code = Get-Content -Raw -LiteralPath $codePath
foreach ($needle in @(
    'MOUSE_COORDINATE_SPACE As String = "msforms_event_args"',
    'Private Sub UserForm_Initialize()',
    'Private Sub UserForm_Activate()',
    'Private Sub UserForm_Deactivate()',
    'Private Sub UserForm_QueryClose(Cancel As Integer, CloseMode As Integer)',
    'Private Sub UserForm_Terminate()',
    'Private Sub OracleProbeLabel_Click()',
    'Private Sub OracleProbeLabel_MouseDown',
    'Private Sub OracleDefaultButton_Click()',
    'Private Sub OracleDefaultButton_KeyDown',
    'Private Sub OracleCancelButton_Click()',
    'Private Sub OracleCancelButton_KeyDown',
    'Private Sub OracleTextBox_Change()',
    'Private Sub OracleTextBox_BeforeUpdate',
    'Private Sub OracleTextBox_AfterUpdate()',
    'Private Sub OracleTextBox_KeyPress',
    'sheet.Cells(1, 1).Value = "sequence"',
    'sheet.Cells(1, 9).Value = "coordinate_space"',
    'sheet.Cells(1, 22).Value = "textbox_text"',
    'sheet.Cells(1, 23).Value = "textbox_value"'
)) {
    Assert-Contains -Content $code -Needle $needle -Description 'required W005 code-behind surface'
}

$extraSourcePath = Get-PropertyValue -Object $manifest.workbook -Name 'additionalModuleSourcePath'
if ([string]::IsNullOrWhiteSpace($extraSourcePath)) {
    throw 'W005 fixture is missing workbook.additionalModuleSourcePath.'
}

$extraPath = Join-Path $fixtureRoot $extraSourcePath
if (-not (Test-Path -LiteralPath $extraPath -PathType Leaf)) {
    throw "Additional module source not found: $extraPath"
}

$extraCode = Get-Content -Raw -LiteralPath $extraPath
Assert-Contains -Content $extraCode -Needle 'Public Sub ShowW005InteractionOracleModal()' -Description 'modal show macro'
Assert-Contains -Content $extraCode -Needle 'Public Sub ExportW005InteractionLogCsv()' -Description 'log export macro'

$readmePath = Join-Path $fixtureRoot 'README.md'
if (-not (Test-Path -LiteralPath $readmePath -PathType Leaf)) {
    throw "Fixture README not found: $readmePath"
}

$readme = Get-Content -Raw -LiteralPath $readmePath
foreach ($needle in @(
    'Capture Script For oxforms-xvx.3',
    'Coordinate calibration steps',
    'Lifecycle observations',
    'Do not infer final MSForms event-order rules from this source file.'
)) {
    Assert-Contains -Content $readme -Needle $needle -Description 'fixture README capture guidance'
}

Write-Host 'W005 interaction fixture check: ok'
Write-Host "Controls checked: $($controls.Count)"
Write-Host "Code-behind: $codeBehindSourcePath"
