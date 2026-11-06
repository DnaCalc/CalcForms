$ErrorActionPreference = 'Stop'
python -B "$PSScriptRoot/../office-oracle/validate_run9_parity.py"
if ($LASTEXITCODE -ne 0) { throw 'W010 run 9 font/Escape evidence failed.' }
