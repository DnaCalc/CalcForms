# W003 Excel Forms Oracle Evidence

This directory is reserved for generated W003 evidence and evidence manifests.

It separates captured black-box Office/MSForms outputs from repo-owned fixture
inputs under `fixtures/office-oracle/excel-msforms/`.

Contents:

- `captures/` holds Excel/MSForms oracle screenshots, metadata, logs, hashes,
  and platform/Excel notes from `oxforms-fg9.5`.
- `comparisons/` holds comparison manifests or reports relating the Excel
  oracle to current OxForms artifacts from `oxforms-fg9.6`.
- The first fixture input from `oxforms-fg9.4` is
  `fixtures/office-oracle/excel-msforms/userforms/rectangle-label/fixture.json`.
  It can be validated without Excel, or generated/opened through
  `tools/office-oracle/Open-ExcelUserFormFixture.ps1` when local Excel/VBIDE
  policy allows it.
- The capture primitive self-test can write generated PNG/JSON artifacts under
  `captures/self-test/` with:

  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Capture-Window.ps1 -SelfTest -OutDir docs\evidence\W003_excel_forms_oracle_capture\captures\self-test
  ```

  On Windows, this self-test opens a small native sample window, captures it,
  and records an expected no-target diagnostic. On non-Windows hosts, it writes
  an explicit unsupported manifest. The output is harness evidence for
  `oxforms-fg9.2`; it is not an Excel/MSForms oracle capture and should not be
  used as a parity claim.

Files added by `oxforms-fg9.1` were path guides only, not captured evidence.
The live Excel/MSForms evidence starts with `oxforms-fg9.5`.

Current Excel/MSForms oracle capture from `oxforms-fg9.5`:

- `captures/rectangle-label-20260622T170958Z/` contains the first successful
  live Excel UserForm capture for
  `excel-msforms-rectangle-label-v1`.
- `captures/rectangle-label-20260622T170958Z/oracle-capture-manifest.json`
  records the open/capture commands, platform notes, Excel executable version,
  window identity and bounds, screenshot hash, generated workbook hash, fixture
  input hash, and DPI/theme/scaling warnings.
- `captures/rectangle-label-20260622T170958Z/window-capture.png` is black-box
  Office/MSForms evidence, not an OxForms pixel-parity claim.
- `captures/rectangle-label-20260622T170958Z/checksums.sha256` records hashes
  for the fixture input, command text, preserved stdout/stderr logs, manifests,
  generated workbook, and screenshot.

W003 evidence records at least:

- fixture input paths and hashes;
- command or manual steps used to open/generate the fixture;
- Windows, DPI/theme/scaling, and Excel/Office version notes where available;
- window identity, bounds, screenshot path, screenshot hash, and capture log;
- warnings or blockers for macro policy, missing Excel, capture permissions, or
  unstable desktop state.
