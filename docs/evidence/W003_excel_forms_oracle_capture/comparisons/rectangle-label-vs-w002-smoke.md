# Rectangle Label Oracle vs W002 Smoke

Comparison ID: `rectangle-label-vs-w002-smoke`
Bead: `oxforms-fg9.6`
Status: calibration only

This report explains the first comparison manifest under W003. It relates the
live Excel/MSForms rectangle-label oracle capture from `oxforms-fg9.5` to the
current W002 OxForms rectangle smoke output. It is an observation artifact only.
It is not an OxForms runtime adapter, compatibility bridge, fallback path, final
pass/fail oracle, or pixel-exact parity claim.

## Format

The JSON manifest uses schema `oxforms.office_oracle.comparison_manifest.v1`.
It contains:

- source evidence files with paths and SHA-256 values;
- Excel/MSForms fixture and capture facts;
- current W002 OxForms render diagnostics and source hashes;
- a short statement of what can and cannot be compared now;
- separate `observed_facts`, `assumptions`, and `deferred_items` lists.

Validate paths and hashes with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Test-OracleComparisonManifest.ps1 -ManifestPath docs\evidence\W003_excel_forms_oracle_capture\comparisons\rectangle-label-vs-w002-smoke.json
```

## Observed Facts

Excel oracle:

- Fixture input:
  `fixtures/office-oracle/excel-msforms/userforms/rectangle-label/fixture.json`
  with SHA-256
  `c37aa02ccc771fec0bbdbaa2260744addd7fcafd89d25cbcae1b1076f3feb8b2`.
- Fixture form: `OxFormsRectangleOracleForm`, caption
  `OxForms W003 Rectangle Oracle`, size `240 x 180` points,
  `CenterScreen`.
- Fixture control: empty-caption `Forms.Label.1` named
  `OracleRectangleLabel`, at `Left=24`, `Top=24`, `Width=96`,
  `Height=48` points, `BackColor=#2070C0`, `fmBorderStyleSingle`.
- Capture screenshot:
  `docs/evidence/W003_excel_forms_oracle_capture/captures/rectangle-label-20260622T170958Z/window-capture.png`,
  `320 x 240` PNG pixels, SHA-256
  `382af49ace240ffef41a1334613e200a091623648e7dded90443a98b6b95cf58`.
- Captured top-level window: title `OxForms W003 Rectangle Oracle`, class
  `ThunderDFrame`, process `EXCEL`, screen bounds `800,420` to
  `1120,660`, DPI `96`.
- Exact screenshot fill-color observation: RGB `#2070C0` occupies
  `x=41..166`, `y=64..125`, `126 x 62` pixels, `7812` pixels total.
- Rough label crop including border: `x=40`, `y=63`, `width=128`,
  `height=64`.

Current OxForms W002 counterpart:

- Evidence doc: `docs/evidence/W002_initial_windows_rectangle.md`.
- Targeted test rerun:
  `cargo test -p oxforms-pal fill_rect_renders_expected_pixels_and_diagnostics -- --nocapture`
  returned exit code 0.
- Dry-run visible smoke rerun:
  `cargo run -p oxforms-pal --example visible_rectangle_smoke -- --dry-run`
  returned exit code 0 and reported `4x3`, `commands=1`,
  `hash=13797848596963948501`,
  `fnv1a64-rgba8-framebuffer-v1`.
- W002 display command: `FillRect x=1, y=1, width=2, height=1`,
  RGBA `(16, 32, 48, 255)`, or `#102030` with alpha `255`.

## Assumptions

- The observed `#2070C0` region corresponds to the MSForms Label `BackColor`
  because the RGB value matches the fixture exactly and appears in the visible
  label location.
- The nearby `#646464` crop corresponds to the single label border, but this
  one observation is not enough to generalize MSForms border rendering.
- Screenshot coordinates are top-left origin inside the captured top-level
  window bitmap. They are not calibrated UserForm client coordinates.

## Current Comparison

Meaningful now:

- The Excel artifact gives a measured live MSForms target with screenshot,
  window metadata, platform notes, fixture/workbook hashes, and rough rectangle
  regions.
- The W002 artifact gives the current OxForms rectangle smoke output: one PAL
  `FillRect` into a deterministic `4 x 3` RGBA framebuffer with a stable hash.
- The two can be linked by path, hash, command output, and the fact that each
  contains one rectangle-like visual target.

Not meaningful yet:

- A pixel diff is not justified. The Excel capture is a `320 x 240` themed
  top-level MSForms window with a Label control. W002 is a `4 x 3` PAL
  framebuffer smoke command with a different color and no form chrome.
- The point-to-pixel relationship from this screenshot is not a calibrated
  Twips/points-to-pixels rule.
- This does not prove `UserForm`, `Label`, theme, text, or intrinsic-control
  parity in OxForms.

## Deferred Items

- Calibrated Twips/points-to-pixel mapping.
- Full form chrome and client-area coordinate handling.
- Themed controls across Windows themes, DPI values, and Office versions.
- Pass/fail pixel tolerances.
- Text and font fidelity.
- Exact pixel diff between Excel/MSForms oracle output and OxForms output.
- OxForms UserForm/Label runtime behavior and intrinsic-control rendering.
- Portable golden-image policy for non-Windows backends.

## Clean-Room Note

This comparison uses repo-owned fixture input, committed generated evidence,
public Excel/VBIDE automation outputs, public Win32/.NET screenshot metadata,
and current OxForms W002 evidence. It uses no Office internals, decompilation,
disassembly, or non-public source.
