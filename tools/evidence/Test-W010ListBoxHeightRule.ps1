[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
& python -B (Join-Path $root 'tools/office-oracle/listbox_height_rule.py')
if ($LASTEXITCODE -ne 0) { throw 'ListBox Height rule replay against the retained native observations failed.' }
