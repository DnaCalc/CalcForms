#requires -Version 7.2
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$CaptureName, [switch]$GenerateOnly)

$facadeGenerateOnly = $GenerateOnly
$facadeCaptureName = $CaptureName
. (Join-Path $PSScriptRoot 'Capture-MSFormsMemberOracle.ps1') -LoadFunctionsOnly
if ($facadeCaptureName -cnotmatch '^[a-z0-9][a-z0-9-]{0,79}$') { throw 'Use a simple lowercase capture name.' }
$script:EvidenceCaptureRoot = Join-Path $script:EvidenceBeadsRoot 'oxforms-jbjp.6/captures'
$facadeTarget = Resolve-EvidenceOutDir (Join-Path $script:EvidenceCaptureRoot $facadeCaptureName)
$facadeStage = New-StagingDirectory $facadeTarget
$facadeTool = Join-Path $PSScriptRoot 'msforms_facade_probe.py'
& python -B $facadeTool generate $facadeStage
if ($LASTEXITCODE -ne 0) { throw 'Facade probe generation failed.' }
if ($facadeGenerateOnly) { Write-Output $facadeStage; return }
$facadeManifest = Get-Content -LiteralPath (Join-Path $facadeStage 'probe-definition.json') -Raw | ConvertFrom-Json
$facadeWorkbook = Join-Path $facadeStage 'facade-probe.xlsm'
$facadeProgress = Join-Path $facadeStage 'progress.log'
try {
    $build = New-OracleWorkbook -Manifest $facadeManifest `
        -FormCodePath (Join-Path $facadeStage 'W010MemberOracleForm.vba') `
        -ModuleCodePath (Join-Path $facadeStage 'W010MemberOracleRuntime.vba') `
        -WorkbookPath $facadeWorkbook -FormExportPath (Join-Path $facadeStage 'W010MemberOracleForm.frm') `
        -PhaseTimeoutSeconds 180
    Write-JsonLf -Path (Join-Path $facadeStage 'build-identity.json') -Value $build
    $preopenText = & python -B $facadeTool preopen $facadeStage
    if ($LASTEXITCODE -ne 0) { throw 'Facade preopen validation failed.' }
    $preopen = $preopenText | ConvertFrom-Json
    Write-JsonLf -Path (Join-Path $facadeStage 'preopen.json') -Value $preopen
    $live = Invoke-LiveOracle -Manifest $facadeManifest -WorkbookPath $facadeWorkbook `
        -ExpectedPreopenWorkbookSha256 $preopen.workbook_sha256 -Stage $facadeStage -FinalOutDir $facadeTarget `
        -PowerShellPath (Get-Command pwsh).Source -ProgressPath $facadeProgress `
        -WindowCapturePath $script:WindowCapturePath -WindowCaptureSha256 (Get-Sha256 $script:WindowCapturePath) `
        -PhaseTimeoutSeconds 180
    Write-JsonLf -Path (Join-Path $facadeStage 'observations.json') -Value $live
    $replayText = & python -B $facadeTool replay $facadeStage
    if ($LASTEXITCODE -ne 0) { throw 'Facade replay validation failed.' }
    Write-JsonLf -Path (Join-Path $facadeStage 'replay.json') -Value ($replayText | ConvertFrom-Json)
    Write-Checksums $facadeStage
    Assert-NoReparsePointTree $facadeStage
    # Both paths were resolved and checked inside the .6 capture root.
    Move-Item -LiteralPath $facadeStage -Destination $facadeTarget
    Write-Output "Captured and replayed: $facadeTarget"
} catch {
    Write-TextLf -Path (Join-Path $facadeStage 'failure.txt') -Text ([string]$_) -FinalNewline
    throw
}
