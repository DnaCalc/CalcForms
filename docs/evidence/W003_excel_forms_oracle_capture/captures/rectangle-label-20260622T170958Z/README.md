# Excel MSForms Rectangle Label Capture

Capture ID: `rectangle-label-20260622T170958Z`
Bead: `oxforms-fg9.5`

This folder contains the first successful live Excel/MSForms UserForm oracle
capture for W003. It was generated from the repo-owned fixture manifest at
`fixtures/office-oracle/excel-msforms/userforms/rectangle-label/fixture.json`.

Rerun from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Open-ExcelUserFormFixture.ps1 -FixtureDir fixtures\office-oracle\excel-msforms\userforms\rectangle-label -OutputWorkbook docs\evidence\W003_excel_forms_oracle_capture\captures\rectangle-label-20260622T170958Z\rectangle-label-oracle.xlsm -Open -HoldSeconds 60
```

While the UserForm is visible during the hold window:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Capture-Window.ps1 -OutDir docs\evidence\W003_excel_forms_oracle_capture\captures\rectangle-label-20260622T170958Z -TitleContains "OxForms W003 Rectangle Oracle" -ProcessName EXCEL -CaptureScreenshot
```

See `oracle-capture-manifest.json` for platform, Excel executable version,
window identity, bounds, artifact hashes, and warnings about DPI/theme/scaling.
`window-capture.png` is a live desktop screenshot of the Excel/MSForms UserForm,
not an OxForms parity claim.

The preserved command logs are:

- `open-fixture.stdout.log` / `open-fixture.stderr.log`
- `capture-window.stdout.log` / `capture-window.stderr.log`

The stderr logs are intentionally empty for this successful capture. Hashes for
the command files, logs, manifests, workbook, and screenshot are recorded in
`checksums.sha256`.
