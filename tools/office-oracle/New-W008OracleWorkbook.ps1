[CmdletBinding()]
<#
.SYNOPSIS
    Build (and optionally show) an Excel/MSForms oracle workbook from a repo-owned
    fixture, for a computer-use-driven W008 capture.

.DESCRIPTION
    The W008 follow-up captures (esq.14 dirty-focus-out, esq.17 paste-veto) are driven
    by computer-use vision (precise clicks + genuine key holds), not the best-effort
    SendInput path of the per-scenario Capture-*.ps1 scripts. This shared tool does the
    deterministic, non-disruptive half: it generates the .xlsm from a fixture.json
    (controls + code-behind + standard module) via public Excel/VBIDE COM automation,
    exactly as New-WorkbookFromFixture does in the existing capture scripts.

    Modes:
      -DryRun       validate the fixture manifest + repo paths only (no Excel).
      -CompileCheck build the workbook, then run the fixture's clear-log macro, which
                    forces a project-wide VBA compile (incl. the form code-behind) so a
                    syntax error surfaces headlessly before the live session. Excel runs
                    invisible; the form is NOT shown.
      -Show         build the workbook, open it VISIBLE, run the clear-log + show macros
                    (modeless form on screen) so a computer-use step can drive it, then
                    leave Excel running and return the window title. The caller drives the
                    scenario, exports the worksheet, and formalizes the capture.

    Clean-room: repo-owned fixture input + public Excel/VBIDE automation only. No Office
    internals, decompilation, disassembly, or OxForms output comparison.

.NOTES
    This tool generates the workbook and is recorded as the `capture_tool` in the
    capture manifest; the actual input is computer-use-driven and documented in the
    capture's run-summary/README.
#>
param(
    [Parameter(Mandatory = $true)][string]$FixtureDir,
    [string]$OutPath,
    [switch]$DryRun,
    [switch]$CompileCheck,
    [switch]$Show,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

function Resolve-InRepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $full = if ([System.IO.Path]::IsPathRooted($Path)) { [System.IO.Path]::GetFullPath($Path) } else { [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path)) }
    $rootSep = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not ($full.Equals($repoRoot, [System.StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith($rootSep, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Path '$Path' resolves outside repository root '$repoRoot'."
    }
    return $full
}

function Get-Req { param($o, [string]$n) $p = $o.PSObject.Properties[$n]; if ($null -eq $p -or $null -eq $p.Value) { throw "Fixture manifest is missing required value: $n" }; if ($p.Value -is [string] -and [string]::IsNullOrWhiteSpace($p.Value)) { throw "Fixture manifest has an empty required value: $n" }; return $p.Value }
function Get-Opt { param($o, [string]$n) if ($null -eq $o) { return $null }; $p = $o.PSObject.Properties[$n]; if ($null -eq $p) { return $null }; return $p.Value }
function Release { param($o) if ($null -ne $o -and [System.Runtime.InteropServices.Marshal]::IsComObject($o)) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($o) } }
function Set-CompProp { param($c, [string]$n, $v) $p = $c.Properties.Item($n); $p.GetType().InvokeMember('Value', [System.Reflection.BindingFlags]::SetProperty, $null, $p, @($v), [System.Globalization.CultureInfo]::InvariantCulture) }

function Resolve-FixtureSource {
    param([string]$FixtureRoot, [string]$Path)
    $full = [System.IO.Path]::GetFullPath((Join-Path $FixtureRoot $Path))
    $rootSep = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($rootSep, [System.StringComparison]::OrdinalIgnoreCase)) { throw "Fixture source path must stay inside the repository: $Path" }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Fixture source file not found: $full" }
    return $full
}

function New-WorkbookFromFixture {
    param($Fixture, [string]$FixtureRoot, [string]$WorkbookPath)
    if (Test-Path -LiteralPath $WorkbookPath -PathType Leaf) {
        if (-not $Force) { throw "Output workbook already exists. Pass -Force to replace it: $WorkbookPath" }
        Remove-Item -LiteralPath $WorkbookPath -Force
    }
    $form = Get-Req $Fixture 'form'
    $excel = $null; $wb = $null; $vbp = $null; $comp = $null; $std = $null
    try {
        try { $excel = New-Object -ComObject Excel.Application } catch { throw "Microsoft Excel COM automation is unavailable: $($_.Exception.Message)" }
        $excel.Visible = $false; $excel.DisplayAlerts = $false
        $wb = $excel.Workbooks.Add()
        try { $vbp = $wb.VBProject } catch { throw "Excel blocked access to the VBA project object model. Enable 'Trust access to the VBA project object model'." }
        $comp = $vbp.VBComponents.Add(3)   # vbext_ct_MSForm
        $comp.Name = [string](Get-Req $form 'name')
        $designer = $comp.Designer
        Set-CompProp $comp 'Caption' ([string](Get-Req $form 'caption'))
        Set-CompProp $comp 'Width' ([single](Get-Req $form 'widthPt'))
        Set-CompProp $comp 'Height' ([single](Get-Req $form 'heightPt'))
        Set-CompProp $comp 'StartUpPosition' ([single](Get-Req $form 'startupPosition'))
        foreach ($ctl in @($form.controls)) {
            $created = $designer.Controls.Add([string](Get-Req $ctl 'type'), [string](Get-Req $ctl 'name'), $true)
            $created.Left = [single](Get-Req $ctl 'leftPt'); $created.Top = [single](Get-Req $ctl 'topPt')
            $created.Width = [single](Get-Req $ctl 'widthPt'); $created.Height = [single](Get-Req $ctl 'heightPt')
            $cap = Get-Opt $ctl 'caption'; if ($null -ne $cap) { $created.Caption = [string]$cap }
            # Design-time control fonts are intentionally NOT set (a font set hangs SaveAs);
            # Default/accelerators are set at runtime in UserForm_Initialize.
        }
        $comp.CodeModule.AddFromString((Get-Content -Raw -LiteralPath (Resolve-FixtureSource $FixtureRoot ([string](Get-Req $form 'codeBehindSourcePath')))))
        $std = $vbp.VBComponents.Add(1)    # vbext_ct_StdModule
        $std.Name = [string](Get-Req $Fixture.workbook 'vbaModuleName')
        $std.CodeModule.AddFromString((Get-Content -Raw -LiteralPath (Resolve-FixtureSource $FixtureRoot ([string](Get-Req $Fixture.workbook 'standardModuleSourcePath')))))
        $wb.SaveAs($WorkbookPath, 52)      # xlOpenXMLWorkbookMacroEnabled
    } finally {
        if ($null -ne $wb) { try { $wb.Close($true) } catch { Write-Warning "close generated workbook: $($_.Exception.Message)" } }
        if ($null -ne $excel) { try { $excel.Quit() } catch { Write-Warning "quit Excel after generation: $($_.Exception.Message)" } }
        Release $std; Release $comp; Release $vbp; Release $wb; Release $excel
    }
}

$fixtureRoot = Resolve-InRepoPath $FixtureDir
$fixturePath = Join-Path $fixtureRoot 'fixture.json'
if (-not (Test-Path -LiteralPath $fixturePath)) { throw "Fixture manifest not found: $fixturePath" }
$fixture = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
[void](Get-Req $fixture 'id')
$form = Get-Req $fixture 'form'
$formCaption = [string](Get-Req $form 'caption')
[void](Resolve-FixtureSource $fixtureRoot ([string](Get-Req $form 'codeBehindSourcePath')))
[void](Resolve-FixtureSource $fixtureRoot ([string](Get-Req $fixture.workbook 'standardModuleSourcePath')))

if ($DryRun) {
    Write-Host "Fixture: $($fixture.id)"
    Write-Host "Form: $formCaption"
    Write-Host 'Dry run only: fixture manifest and repository paths are valid. Excel was not started.'
    exit 0
}

if ([string]::IsNullOrWhiteSpace($OutPath)) {
    $OutPath = Join-Path ([System.IO.Path]::GetTempPath()) ([string](Get-Req $fixture.workbook 'fileName'))
}
$OutPath = if ([System.IO.Path]::IsPathRooted($OutPath)) { [System.IO.Path]::GetFullPath($OutPath) } else { [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutPath)) }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutPath) | Out-Null

New-WorkbookFromFixture -Fixture $fixture -FixtureRoot $fixtureRoot -WorkbookPath $OutPath
Write-Host "Built workbook: $OutPath"

if ($CompileCheck -or $Show) {
    $excel = $null; $wb = $null
    try {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = [bool]$Show
        $excel.DisplayAlerts = $false
        try { $excel.AutomationSecurity = 1 } catch {}
        $wb = $excel.Workbooks.Open($OutPath)
        # Running the clear-log macro forces a project-wide VBA compile (form code-behind
        # included), so a syntax error surfaces here rather than mid-live-session.
        $excel.Run([string](Get-Req $fixture.workbook 'clearLogMacroName'))
        if ($Show) {
            $excel.Run([string](Get-Req $fixture.workbook 'showMacroName'))
            Write-Host "Form shown modeless (Excel left running for a computer-use capture): $formCaption"
            Write-Host "Workbook: $OutPath"
            # Excel + the modeless form are intentionally left running for the caller.
            $wb = $null; $excel = $null
        } else {
            Write-Host "CompileCheck OK: the VBA project compiled and '$($fixture.workbook.clearLogMacroName)' ran."
            $wb.Close($false); $wb = $null
            $excel.Quit(); $excel = $null
        }
    } finally {
        if ($null -ne $wb) { try { $wb.Close($false) } catch {} }
        if ($null -ne $excel -and -not $Show) { try { $excel.Quit() } catch {} }
        if (-not $Show) { Release $wb; Release $excel }
    }
}
