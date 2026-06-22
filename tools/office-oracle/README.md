# Office Oracle Harness Tools

This directory is reserved for W003 tooling that observes real
Excel/MSForms behavior as a black-box oracle.

The tools here are not OxForms runtime APIs, adapter APIs, or compatibility
bridges. They are local harness utilities for generating, opening, capturing,
or checking Office oracle fixtures and their evidence artifacts.

Current scaffold:

- `Test-OfficeOracleScaffold.ps1` checks that the W003 fixture, tool, capture,
  and comparison directories exist. It does not start Excel, automate Office,
  capture screenshots, or create a UserForm fixture.
- `Capture-Window.ps1` discovers visible top-level Windows desktop windows
  using public Win32 APIs through PowerShell/.NET, records structured metadata,
  and can optionally capture a PNG screenshot. Screenshot capture briefly raises
  the selected target window before copying pixels so an occluding desktop
  window is not accidentally recorded as the oracle. It is a black-box evidence
  helper only; it is not an OxForms runtime API.
- `Open-ExcelUserFormFixture.ps1` validates or generates the first
  Excel/MSForms UserForm oracle workbook from repo-owned manifest input. Live
  generation uses public Excel/VBIDE automation and requires local Excel macro
  and VBA project access policy to allow it.
- `Test-OracleComparisonManifest.ps1` validates W003 comparison manifests by
  checking their schema, linked report, evidence paths, and SHA-256 values. It
  does not start Excel, capture screenshots, run OxForms, or perform pixel
  parity checks.

Safe self-test, no Excel required:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Capture-Window.ps1 -SelfTest -OutDir docs\evidence\W003_excel_forms_oracle_capture\captures\self-test
```

On Windows, the self-test records an expected no-target diagnostic and captures
a small repo-owned native sample window. On non-Windows hosts, it writes an
explicit unsupported diagnostic manifest instead of attempting desktop capture.

Live window capture shape for later Excel/UserForm beads:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Capture-Window.ps1 -OutDir docs\evidence\W003_excel_forms_oracle_capture\captures\<capture-id> -TitleContains "<form caption>" -ProcessName EXCEL -CaptureScreenshot
```

`-TitleContains`, `-ProcessName`, `-ProcessContains`, and `-ClassName` may be
combined to avoid ambiguous matches. If multiple windows still match, the tool
reports `ambiguous_target` unless `-AllowAmbiguous` is supplied. Any written
manifest or screenshot must be under
`docs/evidence/W003_excel_forms_oracle_capture/captures/`.

Future W003 beads should keep Office-specific commands explicit and local:

- `oxforms-fg9.4` adds repo-owned Excel/VBA fixture inputs under
  `fixtures/office-oracle/excel-msforms/`.
- `oxforms-fg9.5` should write generated capture artifacts under
  `docs/evidence/W003_excel_forms_oracle_capture/captures/`.

Local Office prerequisites, when a future command actually uses Excel:

- Microsoft Excel installed on the Windows host.
- Macro/VBA project access policy configured enough to open or generate the
  repo-owned fixture.
- A desktop session where the UserForm can be shown and captured.

Non-Office scaffold checks must not require those prerequisites.

Safe fixture validation, no Excel required:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Open-ExcelUserFormFixture.ps1 -FixtureDir fixtures\office-oracle\excel-msforms\userforms\rectangle-label -DryRun
```

Live fixture generation/opening shape:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Open-ExcelUserFormFixture.ps1 -FixtureDir fixtures\office-oracle\excel-msforms\userforms\rectangle-label -Open -HoldSeconds 300
```

Comparison manifest validation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Test-OracleComparisonManifest.ps1 -ManifestPath docs\evidence\W003_excel_forms_oracle_capture\comparisons\rectangle-label-vs-w002-smoke.json
```
