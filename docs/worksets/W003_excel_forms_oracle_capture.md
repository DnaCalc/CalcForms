# W003 Excel Forms Oracle And Windows Capture

Status: `OPEN`
Epic bead: `oxforms-fg9`
Depends on: `W002_initial_windows_rectangle`
Owning plan bead: `oxforms-fg9.3`

## Purpose

Build the first repeatable black-box oracle path against real Microsoft Forms
running inside Excel/VBA. W002 proved that OxForms can move a tiny VBA-authored
rectangle command into the PAL and paint it; W003 gives future rendering work a
measuring stick from the thing we need to match.

The smallest useful W003 loop is:

```text
repo-owned Excel/VBA UserForm fixture
  -> real Excel/MSForms window
  -> Windows discovery/capture
  -> screenshot + metadata + hashes
  -> first comparison manifest against current OxForms output
```

This workset deliberately comes before wasm/Tauri/web backend work and before a
larger render/invalidation architecture push. Without an Excel/MSForms oracle,
those directions can drift toward plausible architecture instead of measured
compatibility.

## Non-goals

- No `.frm` / `.frx` ingestion in OxForms.
- No `UserForm.Show` implementation in OxForms.
- No intrinsic control implementation in OxForms.
- No pixel-exact parity claim yet.
- No wasm, Tauri, browser, macOS, or Linux backend implementation.
- No broad accessibility framework beyond the capture primitives W003 needs.
- No Office internals, decompilation, disassembly, or non-public source.

W003 is oracle and capture plumbing. It should improve our ability to observe
real MSForms, not expand the OxForms runtime surface.

## Clean-room Boundary

Allowed evidence:

- public Office/VBA/MSForms documentation;
- public Windows APIs and UI Automation surfaces;
- Office COM automation and black-box execution;
- screenshots, window metadata, accessibility metadata, and logs captured from
  a normal Excel process;
- repo-owned fixture inputs and generated evidence artifacts.

Excluded:

- Office binary reverse engineering;
- proprietary implementation details;
- copied behavior tables without reproducible provenance.

If a bead needs sibling-repo work in `OxVba`, `OxDoc`, `Foundation`, or a DNA
Calc host, it should create a handover under `docs/handovers/` rather than
editing outside this repo.

## Architecture Slice

### 1. Oracle Harness Layout

Create a small, explicit layout for:

- fixture inputs that describe or generate the Excel/VBA UserForm;
- harness code or scripts that launch/generate/open the fixture;
- generated capture outputs;
- evidence manifests and summaries.

The layout must distinguish repo-owned source inputs from generated evidence.
Generated binary Office artifacts should either be excluded, placed under an
evidence path with hashes, or justified in text.

Current scaffold from `oxforms-fg9.1`:

- `tools/office-oracle/` contains Office oracle harness utilities. These tools
  are test/evidence helpers, not OxForms runtime APIs.
- `fixtures/office-oracle/excel-msforms/` contains repo-owned Excel/MSForms
  fixture inputs. `oxforms-fg9.4` adds the first real UserForm fixture under
  `userforms/rectangle-label/`.
- `docs/evidence/W003_excel_forms_oracle_capture/captures/` is the destination
  for generated screenshots, metadata, logs, platform/Excel notes, and hashes.
- `docs/evidence/W003_excel_forms_oracle_capture/comparisons/` is the
  destination for the first oracle comparison manifest from `oxforms-fg9.6`.

The scaffold-only check is:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Test-OfficeOracleScaffold.ps1
```

That check validates paths only. It does not automate Excel, create a fixture,
or capture screenshots.

### 2. First Excel UserForm Fixture

Use a fixture that is stable before it is rich. The first useful form should be
rectangle-like, for example:

- one `UserForm` with known caption, size, and startup position;
- one `Label` or `Frame` with fixed `Left`, `Top`, `Width`, `Height`,
  `BackColor`, optional `BorderStyle`, and empty or controlled caption;
- explicit notes about units, colors, theme assumptions, DPI/scaling, and why
  the control was chosen.

The fixture may be generated through Excel automation or opened manually through
a documented procedure, but it must be reproducible from repo-owned inputs.

Current fixture from `oxforms-fg9.4`:

- `fixtures/office-oracle/excel-msforms/userforms/rectangle-label/fixture.json`
  is the repo-owned source input for one Excel-hosted `UserForm` named
  `OxFormsRectangleOracleForm`.
- The form caption is `OxForms W003 Rectangle Oracle`, size is `240 x 180`
  points, and startup position is `CenterScreen`.
- The only control is an empty-caption `Forms.Label.1` named
  `OracleRectangleLabel` at `Left 24`, `Top 24`, `Width 96`, `Height 48`
  points, with BackColor `&H00C07020&` / RGB `(32, 112, 192)` and
  `fmBorderStyleSingle`.
- `tools/office-oracle/Open-ExcelUserFormFixture.ps1` validates the manifest
  with `-DryRun` and can generate/open the `.xlsm` workbook through public
  Excel/VBIDE automation when the host has Excel and macro/VBIDE policy enabled.

### 3. Windows Discovery And Capture

Add only the primitives needed to locate and capture the first UserForm:

- process/window identity;
- title/class where available;
- bounds and screen position;
- screenshot or pixel capture;
- DPI/theme/scaling notes where practical;
- explicit unsupported diagnostics on non-Windows hosts;
- specific failure diagnostics for missing Excel, macro/security restrictions,
  window discovery failure, or screenshot failure.

Windows UI Automation is useful here, but W003 should avoid turning into a broad
accessibility abstraction. The target is reliable oracle capture, not a general
desktop automation framework.

Current implementation from `oxforms-fg9.2`:

- `tools/office-oracle/Capture-Window.ps1` is a PowerShell harness for
  Office/MSForms oracle evidence capture. It is not an OxForms runtime API,
  adapter, bridge, fallback, or compatibility shim.
- `powershell -NoProfile -ExecutionPolicy Bypass -File
  tools\office-oracle\Capture-Window.ps1 -SelfTest -OutDir
  docs\evidence\W003_excel_forms_oracle_capture\captures\self-test` opens a
  small native sample window on Windows, verifies a deliberate no-target
  diagnostic, and writes JSON manifests plus a PNG screenshot. On non-Windows
  hosts it writes an explicit unsupported manifest.
- `powershell -NoProfile -ExecutionPolicy Bypass -File
  tools\office-oracle\Capture-Window.ps1 -OutDir <capture-dir>
  -TitleContains <text> [-ProcessName EXCEL] [-ProcessContains <text>]
  [-ClassName <class>] [-CaptureScreenshot]` records title, class, process
  id/path when available, bounds, DPI when available, screenshot path/hash when
  requested, warnings, and failure diagnostics.
- Written manifests and screenshots are restricted to
  `docs/evidence/W003_excel_forms_oracle_capture/captures/`.
- The implementation uses public Win32 APIs through PowerShell/.NET:
  `EnumWindows`, `IsWindowVisible`, `GetWindowTextLengthW`, `GetWindowTextW`,
  `GetClassNameW`, `GetWindowThreadProcessId`, `GetWindowRect`, and
  `GetDpiForWindow`, plus .NET `System.Drawing.Graphics.CopyFromScreen` for
  screenshot pixels.

### 4. Oracle Artifact Set

For the first captured UserForm, record durable evidence:

- fixture input paths and hashes;
- exact command or manual steps;
- platform and Excel/Office version notes;
- screenshot path and hash;
- window metadata;
- capture log;
- warnings about DPI, theme, font, scaling, or manual steps.

The evidence must be enough for a future agent to rerun or inspect the capture
without relying on this conversation.

Current capture from `oxforms-fg9.5`:

- `docs/evidence/W003_excel_forms_oracle_capture/captures/rectangle-label-20260622T170958Z/`
  contains the first successful live Excel/MSForms UserForm capture.
- `oracle-capture-manifest.json` records the fixture input hash, generated
  workbook hash, screenshot path/hash, open and capture commands, platform and
  Excel executable version notes, window identity, bounds, and warnings about
  DPI/theme/scaling.
- The capture helper briefly raises the selected target window before
  screenshot capture so an occluding desktop window is not accidentally recorded
  as the oracle pixels.

### 5. First Comparison Manifest

Define a small comparison artifact that relates the Excel oracle to OxForms.
For W003, the comparison can be a calibration report rather than a pass/fail
pixel test.

It should record:

- which Excel oracle fixture/capture is being compared;
- which OxForms artifact or command is the current counterpart, starting from
  the W002 rectangle output where meaningful;
- what can be compared now: screenshot dimensions, crop regions, color samples,
  window/control metadata, hashes, or rough geometry;
- what is deferred: Twips-to-pixel calibration, form chrome handling, themed
  controls, pass/fail pixel tolerances, and text/font fidelity.

The report must distinguish observed facts from assumptions.

## Why Other Directions Wait

Other backends still matter, especially wasm/Tauri and browser-hosted wasm.
For W003, treat them as PAL contract constraints only:

- capture artifacts should be portable enough to become golden references later;
- comparison manifests should not assume Win32 is the only future presenter;
- renderer outputs should remain separable from host window plumbing.

Do not build a wasm/Tauri/web backend in W003. The Excel oracle is the priority
because it tells every backend what it is trying to match.

## Bead Plan

| Bead | Purpose | Depends on | Acceptance |
|---|---|---|---|
| `oxforms-fg9.3` | Define this W003 workset and execution plan | `oxforms-fg9` | Workset doc, register, and bead graph agree. |
| `oxforms-fg9.1` | Scaffold Office oracle harness and fixture layout | `oxforms-fg9.3` | Future beads have clear paths for harness code, fixture inputs, generated artifacts, and evidence. |
| `oxforms-fg9.2` | Implement Windows UserForm discovery and capture primitives | `oxforms-fg9.3` | A documented command/test exercises capture primitives or reports unsupported explicitly. |
| `oxforms-fg9.4` | Create first Excel UserForm oracle fixture | `oxforms-fg9.1` | Repo-owned fixture inputs can generate/open a tiny real Excel UserForm with documented properties. |
| `oxforms-fg9.5` | Capture Excel UserForm oracle artifacts on Windows | `oxforms-fg9.2`, `oxforms-fg9.4` | Screenshot, metadata, logs, hashes, and platform/Excel notes are recorded, or a concrete blocker bead exists. |
| `oxforms-fg9.6` | Define first oracle comparison artifact format | `oxforms-fg9.5` | A manifest/report links Excel oracle artifacts to current OxForms output or explicitly defers exact comparison. |
| `oxforms-fg9.7` | Record W003 evidence and fresh-eyes review | `oxforms-fg9.6` | Evidence, workset/register status, and closure review are complete. |

## Closure Condition

W003 closes when all of these are true:

1. A reproducible real Excel/VBA UserForm oracle fixture exists from repo-owned
   inputs.
2. Windows capture/discovery records the fixture's window identity, bounds,
   screenshot/pixels, platform and Excel notes, logs, and hashes.
3. Evidence artifacts are stored under documented paths and are linked from the
   workset or evidence docs.
4. A first comparison manifest relates the Excel oracle capture to current
   OxForms output, or clearly records why exact comparison is deferred.
5. The docs remain precise that this is oracle/capture plumbing, not OxForms
   Forms-runtime parity.
6. Any blocker or out-of-scope discovery has a follow-up bead before closure.

## Verification Shape

| Surface | Check |
|---|---|
| Rust formatting | `cargo fmt --check` |
| Rust lint | `cargo clippy --workspace -- -D warnings` |
| Rust tests | `cargo test --workspace` |
| Excel fixture | Documented generate/open command or explicit blocker bead |
| Windows capture | Targeted command with screenshot/metadata output or explicit unsupported diagnostic |
| Comparison manifest | Path/link scan plus any targeted comparison command |
| Clean-room posture | Read-through of evidence sources and generated artifacts |
| Bead graph | `br dep cycles` and `br ready --json` |

## Risks And Controls

| Risk | Control |
|---|---|
| Excel is unavailable or blocked by macro/security policy on the current host. | Make prerequisites explicit; if capture cannot be run, create a concrete blocker/follow-up bead and do not close W003 optimistically. |
| Captures are unstable because of DPI, theme, fonts, or window chrome. | Record platform/theme/DPI notes and treat W003 comparison as calibration before pass/fail parity. |
| The fixture is too rich and hides the first failure. | Use one small UserForm and one rectangle-like control first. |
| Windows capture work expands into a general automation framework. | Implement only window discovery, metadata, screenshot/pixels, and diagnostics needed for the first fixture. |
| The comparison manifest implies pixel-exact parity too early. | Label W003 comparison as oracle calibration unless exact matching is truly proven. |
| Clean-room boundaries blur. | Use only public APIs, black-box Office automation, screenshots, metadata, logs, and repo-owned fixture inputs. |
