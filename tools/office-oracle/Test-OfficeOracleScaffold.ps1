[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$requiredRelativePaths = @(
    'tools/office-oracle/README.md',
    'tools/office-oracle/Open-ExcelUserFormFixture.ps1',
    'fixtures/office-oracle/README.md',
    'fixtures/office-oracle/excel-msforms/README.md',
    'fixtures/office-oracle/excel-msforms/userforms/README.md',
    'fixtures/office-oracle/excel-msforms/userforms/rectangle-label/README.md',
    'fixtures/office-oracle/excel-msforms/userforms/rectangle-label/fixture.json',
    'docs/evidence/W003_excel_forms_oracle_capture/README.md',
    'docs/evidence/W003_excel_forms_oracle_capture/captures/README.md',
    'docs/evidence/W003_excel_forms_oracle_capture/comparisons/README.md',
    'docs/evidence/W004_text_label_oracle_pixels/README.md',
    'docs/evidence/W004_text_label_oracle_pixels/captures/README.md'
)

$missing = @()

foreach ($relativePath in $requiredRelativePaths) {
    $path = Join-Path $repoRoot $relativePath
    if (-not (Test-Path -LiteralPath $path)) {
        $missing += $relativePath
    }
}

if ($missing.Count -gt 0) {
    Write-Error ("Office oracle scaffold is incomplete. Missing: " + ($missing -join ', '))
    exit 1
}

Write-Host 'Office oracle scaffold check: ok'
Write-Host 'No Excel automation, screenshot capture, or fixture generation was run.'
