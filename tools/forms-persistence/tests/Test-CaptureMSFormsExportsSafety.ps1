[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$captureTool = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\Capture-MSFormsExports.ps1'))
$tokens = $null
$parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
    $captureTool,
    [ref]$tokens,
    [ref]$parseErrors
)
if ($parseErrors.Count -gt 0) {
    throw "Capture tool has PowerShell parse errors: $($parseErrors.Message -join '; ')"
}

# Both modes are deliberately non-COM: the self-test exercises staged
# validation, successful promotion, injected-failure rollback, exact file-set
# rejection, junction rejection, blank ProcessModule metadata, and deterministic
# Click-to-Run VFS backing and geometry-normalization validation; the check-only
# mode verifies the frozen output and Excel executable identity without
# launching Excel.
& $captureTool -RunSafetySelfTest
& $captureTool -SafetyCheckOnly

Write-Host 'Capture-MSFormsExports safety checks passed without launching Excel.'
