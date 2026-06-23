# W005 Interaction Events Excel UserForm Oracle Fixture

This is the repo-owned Excel/MSForms fixture input for
`oxforms-xvx.2`. It prepares the live oracle capture bead
`oxforms-xvx.3`; it is not OxForms runtime code and its source is not itself
oracle evidence.

## Fixture Shape

Input files:

- `fixture.json` - manifest, form geometry, control geometry, source paths,
  clean-room notes, and the intended interaction script.
- `form-code-behind.bas` - UserForm event handlers and structured logging.
- `standard-module-extra.bas` - modal-show and log-export helper macros appended
  to the generated standard module.

The generated workbook contains one Excel-hosted `UserForm`:

- form name: `OxFormsW005InteractionForm`
- caption: `OxForms W005 Interaction Oracle`
- form size: `240 x 180` points
- startup position: `2` / `CenterScreen`

Controls:

- `OracleProbeLabel`: `MSForms.Label`, caption `Probe Label`, position
  `Left 24`, `Top 24`, size `96 x 48` points. This deliberately reuses the
  W003/W004 label geometry for coordinate calibration continuity.
- `OracleTextBox`: `MSForms.TextBox`, position `Left 132`, `Top 24`, size
  `72 x 24` points.
- `OracleDefaultButton`: `MSForms.CommandButton`, caption `&OK`,
  `Default=True`, accelerator `O`.
- `OracleCancelButton`: `MSForms.CommandButton`, caption `&Cancel`,
  `Cancel=True`, accelerator `C`.

The UserForm code-behind logs to worksheet `W005EventLog`. Each row records a
sequence number, event name, target, argument summary, mouse `X`/`Y` tagged as
`msforms_event_args`, button/shift/key data, cancel/helper before and after
values, close mode, active control/window state, Label caption, TextBox
`Text`/`Value`, and notes.

## Generate Or Validate

Safe dry run from the repo root, no Excel required:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Open-ExcelUserFormFixture.ps1 -FixtureDir fixtures\office-oracle\excel-msforms\userforms\interaction-events -DryRun
```

Live modeless generation/opening shape:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Open-ExcelUserFormFixture.ps1 -FixtureDir fixtures\office-oracle\excel-msforms\userforms\interaction-events -OutputWorkbook docs\evidence\W005_input_interaction_model_exploration\captures\<capture-id>\w005-interaction-events-oracle.xlsm -Open -HoldSeconds 300
```

The generated default show macro is `ShowW005InteractionOracleModeless`.
`standard-module-extra.bas` adds `ShowW005InteractionOracleModal`,
`ClearW005InteractionLog`, and `ExportW005InteractionLogCsv`.

## Capture Script For oxforms-xvx.3

Before interacting, capture the visible top-level window and platform metadata:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Capture-Window.ps1 -OutDir docs\evidence\W005_input_interaction_model_exploration\captures\<capture-id> -TitleContains "OxForms W005 Interaction Oracle" -ProcessName EXCEL -CaptureScreenshot
```

Manual interaction script:

1. Click and move over `OracleProbeLabel` near its top-left and center.
2. Press inside `OracleProbeLabel`, drag outside the label bounds, and release.
3. Click `OracleTextBox`, type `ab`, press Backspace, press Tab, then press
   Shift+Tab back into the TextBox.
4. Press Enter, Escape, Alt+O, and Alt+C.
5. Click both command buttons directly and double-click each probe where
   practical.
6. Close with the window close button to capture `QueryClose` and later
   lifecycle rows.
7. Repeat with `ShowW005InteractionOracleModal` for modal lifecycle/pump
   observations.

Coordinate calibration steps for `oxforms-xvx.3`:

- Preserve the fixture point geometry from `fixture.json`.
- Preserve the capture manifest `window_rect`, screenshot size, DPI, and hash.
- Detect the `OracleProbeLabel` border/fill rectangle in `screenshot_pixels`
  using the same half-open convention as `docs/specs/COORDINATE_MODEL.md`.
- For each mouse action, preserve the manual or automated raw screen point,
  derived `screenshot_pixels`, derived `form_logical`, derived `control_local`,
  and the live `msforms_event_args` `X`/`Y` values logged by the fixture.
- Keep negative or out-of-bounds values for drag/capture observations.

Lifecycle observations for `oxforms-xvx.3`:

- Record whether the run used modeless or modal show.
- Preserve `Initialize`, `Activate`, `Deactivate`, `Resize`, `QueryClose`, and
  `Terminate` rows when observed.
- Preserve `QueryClose.Cancel` before/after values and `CloseMode`.
- Preserve the generated workbook, exported `W005EventLog` sheet, command logs,
  stdout/stderr, screenshot, manifest, and SHA-256 hashes under W005 evidence.

Do not infer final MSForms event-order rules from this source file. Live output
from `oxforms-xvx.3` is the oracle evidence.
