# Office Oracle Harness Tools

This directory is reserved for tooling that observes real
Excel/MSForms behavior as a black-box oracle.

The tools here are not OxForms runtime APIs or adapter APIs. They are local
harness utilities for generating, opening, capturing, or checking Office oracle
fixtures and their evidence artifacts.

Current tools:

- `Test-OfficeOracleScaffold.ps1` checks that the W003 fixture, tool, capture,
  and comparison directories exist. It does not start Excel, automate Office,
  capture screenshots, or create a UserForm fixture.
- `Capture-Window.ps1` discovers visible top-level Windows desktop windows
  using public Win32 APIs through PowerShell/.NET, records structured metadata,
  and can optionally capture a PNG screenshot. Screenshot capture briefly raises
  the selected target window before copying pixels so an occluding desktop
  window is not accidentally recorded as the oracle. It is a black-box evidence
  helper only; it is not an OxForms runtime API.
- `Open-ExcelUserFormFixture.ps1` validates or generates Excel/MSForms
  UserForm oracle workbooks from repo-owned manifest input. Live generation
  uses public Excel/VBIDE automation and requires local Excel macro and VBA
  project access policy to allow it.
- `Test-W005InteractionFixture.ps1` statically validates the W005 interaction
  fixture manifest, required controls, code-behind handler/logging surface, and
  capture README guidance without starting Excel.
- `Capture-W006TextServiceTransfer.ps1` generates the W006 text-service
  transfer fixture, opens live Excel/MSForms, prepares foreground/focus
  diagnostics, attempts `Ctrl+V` with public keyboard drivers, records exact
  blockers when present, falls back to public `TextBox.Paste` only when needed,
  and exports keyboard/`BeforeDropOrPaste`/`Change` oracle evidence.
- `Capture-W006OleDragDropTransfer.ps1` generates the W006 OLE drag/drop
  transfer fixture, opens live Excel/MSForms, drives a public
  `MSForms.DataObject.StartDrag` session with public `user32 SendInput` mouse
  input, and exports `BeforeDragOver`/`BeforeDropOrPaste` oracle evidence or a
  precise blocker.
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

Live window capture shape for Excel/UserForm beads:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Capture-Window.ps1 -OutDir docs\evidence\<workset>\captures\<capture-id> -TitleContains "<form caption>" -ProcessName EXCEL -CaptureScreenshot
```

`-TitleContains`, `-ProcessName`, `-ProcessContains`, and `-ClassName` may be
combined to avoid ambiguous matches. If multiple windows still match, the tool
reports `ambiguous_target` unless `-AllowAmbiguous` is supplied. Any written
manifest or screenshot must be under a documented workset capture path like
`docs/evidence/<workset>/captures/...`.

W003 kept Office-specific commands explicit and local:

- `oxforms-fg9.4` added repo-owned Excel/VBA fixture inputs under
  `fixtures/office-oracle/excel-msforms/`.
- `oxforms-fg9.5` wrote generated capture artifacts under
  `docs/evidence/W003_excel_forms_oracle_capture/captures/`.
- `oxforms-kgn` / W004 uses
  `docs/evidence/W004_text_label_oracle_pixels/captures/` for text-bearing
  Label oracle evidence.

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

Fixture manifests may use the original single `control` object or a `controls`
array. Optional visual and interaction fields include `foreColorOle`,
`textAlign`, `wordWrap`, `autoSize`, `tabIndex`, `tabStop`, `default`, `cancel`,
`accelerator`, TextBox editing flags, and `font` values (`name`, `sizePt`,
`bold`, `italic`, `underline`, `strikethrough`). Font values are emitted into
the generated VBA show macro and applied immediately before the form is shown;
this keeps the request explicit in the generated workbook even when the VBIDE
designer COM wrapper does not reliably expose design-time font setters to
PowerShell.

W005 interaction fixtures may also include:

- `codeBehind.sourcePath`, a fixture-relative UserForm code module input.
- `workbook.additionalModuleSourcePath`, fixture-relative standard-module code
  appended after the generated show/hide macros.

Dry runs validate those source paths without starting Excel:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Open-ExcelUserFormFixture.ps1 -FixtureDir fixtures\office-oracle\excel-msforms\userforms\interaction-events -DryRun
```

W005 interaction fixture static validation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Test-W005InteractionFixture.ps1
```

Comparison manifest validation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Test-OracleComparisonManifest.ps1 -ManifestPath docs\evidence\W003_excel_forms_oracle_capture\comparisons\rectangle-label-vs-w002-smoke.json
```
