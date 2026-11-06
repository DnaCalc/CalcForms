[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
& python -B (Join-Path $repo 'tools/office-oracle/greeter_setter_reference.py')
if ($LASTEXITCODE -ne 0) { throw 'Genuine greeter setter evidence differs' }
