# Office Oracle Harness Tools

This directory is reserved for tooling that observes real
Excel/MSForms behavior as a black-box oracle.

The tools here are not OxForms runtime APIs or adapter APIs. They are local
harness utilities for generating, opening, capturing, or checking Office oracle
fixtures and their evidence artifacts.

Current tools:

- `Test-OfficeOracleScaffold.ps1` checks that every required fixture, tool, and
  evidence scaffold path is a file leaf. It does not start Excel, automate Office,
  capture screenshots, or create a UserForm fixture.
- `Capture-Window.ps1` discovers visible top-level Windows desktop windows
  using public Win32 APIs through PowerShell/.NET, records structured metadata,
  and can optionally capture a PNG screenshot. Screenshot capture briefly raises
  the selected target window, then brackets the coordinate-based `CopyFromScreen`
  read with exact title/class/PID/start/path/bounds/visibility/foreground metadata.
  The PNG still requires visual review and is not proof of an HWND-owned surface.
  It is a black-box evidence helper only; it is not an OxForms runtime API.
- `msforms_member_oracle.py` validates immutable ledger-linked probe manifests,
  freezes/verifies compact selected-row ledger slices, emits deterministic
  direct early-bound VBA, and replays committed result/event/workbook/render/
  export evidence without starting Office. Successful result expectations pin
  exact `TypeName` and numeric `VarType`, not only display text. XLSM replay
  checks strict, direct, one-to-one OPC relationships/namespaces/content types;
  derives the VBA text encoding from MS-OVBA `PROJECTCODEPAGE`; closes the
  complete PROJECT/module-table/storage graph; requires empty
  workbook/worksheet code;
  and binds the known-VBIDE-normalized form/runtime sources to deterministic
  generation.
  It does not claim semantic MS-OFORMS control-graph or optional
  compiled-cache/p-code execution binding; `oxforms-jbjp.67` owns those gates.
- `Capture-MSFormsMemberOracle.ps1` performs a two-phase live run. Each phase
  requires zero observed Excel processes, pins the sole registered
  `EXCEL.EXE`, creates it directly with the sole `/safe` switch and its initial
  thread suspended, assigns it to a kill-on-close Job, verifies membership,
  and only then resumes it. The first contained process builds/exports/saves
  the fixture while hidden; the second executes it visibly. The narrow
  suspended creation-to-Job-assignment interval is disclosed rather than
  described as atomic creation-time association. Functional tests prove that
  closing the completed-launch Job kills both root and descendant, including
  after abrupt supervisor death. Before phase two opens the workbook, the
  strict headless source/OPC/VBA validator must accept it. A retained read handle
  then pins the exact non-renamable file object and verifies the same hash before
  and after `Workbooks.Open`, while still allowing Excel's required read/write
  sharing; the opened workbook must match the exact path and must not be
  read-only. The runner observes the caller/pre-create/post-create Excel PID
  sets, rejects any foreign process, binds to the exact process through
  `EXCEL7`/`OBJID_NATIVEOM`, and records the raw OS command line parsed as the
  exact executable plus `/safe`. It performs three isolation checkpoints per
  phase: complete exact-PID owned-window enumeration with an enabled `XLMAIN`
  and no visible foreign modal/disabled root, exact workbook disposition,
  startup paths, Protected View, Excel `AddIns`/`AddIns2`, and loaded XLLs.
  Where safe-mode Excel returns exact `0x800A03EC` for `Application.COMAddIns`,
  the evidence records an incomplete inventory and makes no COM-add-in
  connection-state claim. It binds the screenshot metadata bracket to the
  second process id and executable, snapshots the runner, combined
  generator/replayer, window tool,
  and strict FRM/CFB validators whose source paths and digests are
  independently pinned by the project-authored manifest, validates checksums
  and the complete staged
  capture, and only then promotes the directory atomically. Source generation,
  capture replay validation, and window capture execute only from byte-pinned
  capture-local snapshots with required self-digests. Each executing snapshot
  stays open read-only with write/delete sharing denied from the final hash
  check through child completion. External child commands are bounded. Once a
  direct process is created and natively bound, all owned COM work in that
  phase is watchdog-bounded;
  each watchdog uses an ARMED handshake, can terminate only the exact verified
  private process, and requires the expected terminal reason. The retained Job
  is the final process-tree cleanup backstop and is deterministically disposed
  after exact exit verification.
  Declarative focus steps pin either success or the exact expected error number,
  description, and source. This lets a mutable `Exit` cancellation prove the
  resulting focus-transfer veto without suppressing unrelated `SetFocus`
  failures. Generated event handlers become inert before normal or failure
  teardown, and failure cleanup makes a second bounded form-close request before
  closing the workbook.
  The build phase explicitly requests `xlWBATWorksheet`, so a user
  `Book.xlt*` template or default-sheet preference cannot alter the owned
  project graph.
- `Test-CaptureWindowOutputPath.ps1` exercises accepted legacy workset capture
  paths and exact numbered W010 bead capture paths, including traversal,
  reparse-point, wrong-shape, and file-component rejection. On Windows it also
  attacks the retained output-directory handle chain from another process with
  a rename-then-junction substitution and requires the attempt to fail.
- `Test-PrivateProcessWatchdog.ps1` exercises suspended Job creation,
  pre-resume membership, descendant kill-on-close, abrupt-supervisor cleanup,
  watchdog handshake, clean disarm, exact-process timeout termination, and
  identity-mismatch refusal with disposable repo-local processes. It also
  proves snapshot sharing blocks self-overwrite and that a post-digest tamper
  cannot execute.
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
- `Capture-W006NestedModalLifecycle.ps1` generates the W006 two-UserForm
  nested modal lifecycle fixture, opens live Excel/MSForms, drives outer and
  inner public hide/unload/system-close paths, and exports lifecycle evidence
  or a precise public automation blocker.
- `Test-W006NestedModalCaptureEvidence.ps1` validates the W006 nested modal
  capture/blocker evidence, including command logs, manual-input notes,
  trace/replay non-claims, and checksums.
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
combined with `-ProcessId` to avoid ambiguous matches. If multiple windows still match, the tool
reports `ambiguous_target` unless `-AllowAmbiguous` is supplied. Any written
manifest or screenshot must be under a documented workset capture path like
`docs/evidence/<workset>/captures/...` or the exact reusable W010 form
`docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.<number>/captures/...`.

## Manifest-driven W010 member oracle

Headless validation and deterministic generation:

```powershell
python -B tools/office-oracle/msforms_member_oracle.py validate-manifest `
  --manifest fixtures/office-oracle/excel-msforms/member-probes/representative-v1.json
python -B tools/office-oracle/msforms_member_oracle.py verify-current-ledger-snapshot `
  --manifest fixtures/office-oracle/excel-msforms/member-probes/representative-v1.json
python -B tools/office-oracle/msforms_member_oracle.py generate `
  --manifest fixtures/office-oracle/excel-msforms/member-probes/representative-v1.json `
  --output-dir <fresh-directory>
```

Dry run, live capture, and Office-independent replay:

```powershell
pwsh -NoProfile -File tools/office-oracle/Capture-MSFormsMemberOracle.ps1 -DryRun
pwsh -NoProfile -File tools/office-oracle/Test-PrivateProcessWatchdog.ps1
pwsh -NoProfile -File tools/office-oracle/Capture-MSFormsMemberOracle.ps1
pwsh -NoProfile -File tools/evidence/Test-W010MSFormsMemberOracle.ps1
```

Each manifest declares a safe numbered W010 bead and binds exact selected
ledger rows through an immutable slice. Scalar-capability batches can add rows
without changing the engine. New object/putref/array/collection/Page/Tab/HTML
host capabilities require a new compatible schema branch; v1 generation and
replay semantics remain frozen so later ledger/tool work cannot rot historical
captures. Replay executes FRM/CFB inventory snapshots only after their source
roles and digests match the independent manifest pins. Project-authored
expectations remain separate from live worksheet, screenshot, workbook, and
export observations, and no OxForms output may enter either side of the oracle
boundary.

W003 kept Office-specific commands explicit and local:

- `oxforms-fg9.4` added repo-owned Excel/VBA fixture inputs under
  `fixtures/office-oracle/excel-msforms/`.
- `oxforms-fg9.5` wrote generated capture artifacts under
  `docs/evidence/W003_excel_forms_oracle_capture/captures/`.
- `oxforms-kgn` / W004 uses
  `docs/evidence/W004_text_label_oracle_pixels/captures/` for text-bearing
  Label oracle evidence.

W010 member-oracle toolchain prerequisites, including headless validation:

- Python 3.12 or newer for junction-aware path-safety checks.
- PowerShell 7.2 or newer for the representative member-oracle runner.

Additional local Office prerequisites when a command actually uses Excel:

- Microsoft Excel installed on the Windows host.
- Macro/VBA project access policy configured enough to open or generate the
  repo-owned fixture.
- An unlocked desktop session where the UserForm can be shown and captured.
- Microsoft Office and VBA UI language `LCID 1033` (English - United States);
  the runner checks and records it because the representative manifest pins
  both the worksheet-safe display form and exact raw UTF-16 code units of
  English `Err.Description`. The display form removes at most one final U+0000
  for worksheet storage, while the raw field preserves it. The 22-column result
  row also records and replays exact `Err.Number`, `Err.LastDllError`,
  `Err.Source`, `Err.HelpFile`, `Err.HelpContext`, `Erl`, and execution stage.
- VBE **Tools > Options > General > Error Trapping** manually set to **Break on
  Unhandled Errors**, not **Break on All Errors**. This is a user-wide setting;
  the runner never changes it.

The headless `Test-OfficeOracleScaffold.ps1` check requires each listed scaffold
artifact to be a file leaf; it does not require Office/desktop prerequisites.

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

W006 nested modal lifecycle fixture dry run and evidence validation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Capture-W006NestedModalLifecycle.ps1 -DryRun
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Test-W006NestedModalCaptureEvidence.ps1 -CaptureDir docs\evidence\W006_control_implementation_rollout\captures\nested-modal-lifecycle-20260627T141239Z
```

Comparison manifest validation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Test-OracleComparisonManifest.ps1 -ManifestPath docs\evidence\W003_excel_forms_oracle_capture\comparisons\rectangle-label-vs-w002-smoke.json
```

## Blocked captures: lightweight note vs full evidence directory

Pick the lightest form that is honest:

- **Rows captured (full or partial):** write the full capture directory
  (manifest + run-summary + checksums + command/progress logs). If some
  scenarios were blocked, record those inline in the run-summary/manifest
  `blockers[]` array next to the real rows -- see the W006 nested-modal and
  terminate captures, where the modal-return / modeless-close paths are precise
  inline blockers alongside the observed scenarios.
- **Nothing captured, blocked by the environment or a tooling capability:** use
  the one-file `BLOCKED-CAPTURE-NOTE.template.md` (copy to
  `docs/evidence/<workset>/captures/<capture-id>/BLOCKED.md`) instead of a full
  directory that checksums no observed behavior. This keeps the
  evidence-to-capability ratio honest and avoids churn.

Never infer MSForms behavior from missing rows, in either form.

### Consolidation decision (oxforms-sut)

The earlier suggestion to consolidate the per-scenario "harden timeout" beads
(`oxforms-0a0.24`, `oxforms-0a0.25`, `oxforms-k1i`) behind a single
"environment-blocked" decision is **not applicable**: this host has live Excel
with VBA-project access, and those beads were each resolved on their own merits,
not blocked --
`oxforms-0a0.24` now captures 42 live nested-modal rows (the timeout was a
design-time-font / SaveAs-dialog defect, fixed),
`oxforms-k1i` added a bounded screenshot retry, and
`oxforms-0a0.25` narrowed its remaining blocks to the held-reference dimension
with the ordering captured elsewhere. There is no environment-blocked class to
consolidate.
