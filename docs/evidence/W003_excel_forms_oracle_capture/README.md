# W003 Excel Forms Oracle Evidence

This directory is reserved for generated W003 evidence and evidence manifests.

It separates captured black-box Office/MSForms outputs from repo-owned fixture
inputs under `fixtures/office-oracle/excel-msforms/`.

Current scaffold:

- `captures/` will hold Excel/MSForms oracle screenshots, metadata, logs,
  hashes, and platform/Excel notes from `oxforms-fg9.5`.
- `comparisons/` will hold comparison manifests or reports relating the Excel
  oracle to current OxForms artifacts from `oxforms-fg9.6`.
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

No capture has been performed by `oxforms-fg9.1`. Files added here by this bead
are path guides only, not captured evidence.

W003 evidence should record at least:

- fixture input paths and hashes;
- command or manual steps used to open/generate the fixture;
- Windows, DPI/theme/scaling, and Excel/Office version notes where available;
- window identity, bounds, screenshot path, screenshot hash, and capture log;
- warnings or blockers for macro policy, missing Excel, capture permissions, or
  unstable desktop state.
