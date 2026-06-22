# W003 Capture Outputs

Generated Excel/MSForms oracle capture outputs belong here.

Expected future artifacts include screenshots or pixel buffers, window metadata,
capture logs, platform and Excel notes, and hashes that tie the capture back to
repo-owned fixture inputs.

`oxforms-fg9.2` adds a capture primitive self-test that may write generated
local artifacts under `self-test/`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Capture-Window.ps1 -SelfTest -OutDir docs\evidence\W003_excel_forms_oracle_capture\captures\self-test
```

Those self-test files are not Excel/MSForms oracle artifacts. The first real
Excel UserForm capture is:

- `rectangle-label-20260622T170958Z/` from `oxforms-fg9.5`.

Its `oracle-capture-manifest.json` is the durable entry point for rerun
commands, fixture/workbook/screenshot hashes, Excel executable version, window
identity, bounds, and DPI/theme/scaling warnings. The PNG is a live
Excel/MSForms oracle screenshot only; exact OxForms comparison is deferred to
the W003 comparison bead.
