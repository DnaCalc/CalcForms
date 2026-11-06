$ErrorActionPreference = 'Stop'
python -B "$PSScriptRoot/../office-oracle/validate_lifetime_release.py"
if ($LASTEXITCODE -ne 0) { throw 'W010 lifetime-release evidence failed.' }
