# W004 Text Label Oracle Pixels

Status: `OPEN`
Epic bead: `oxforms-kgn`
Depends on: `W003_excel_forms_oracle_capture`
Owning plan bead: `oxforms-kgn.1`

## Purpose

Add text to the first Excel/MSForms oracle shape and observe the resulting
pixels before OxForms implements text rendering. W003 gave us a blank
rectangle-like `Label` capture. W004 keeps the fixture just as small but gives
the label a simple caption, normal regular font settings, and explicit colors so
we can see how MSForms places and rasterizes text inside the control.

The smallest useful W004 loop is:

```text
repo-owned text Label fixture
  -> real Excel/MSForms UserForm window
  -> Windows discovery/capture
  -> screenshot + text pixel facts + metadata + hashes
  -> closure notes for future OxForms Label text rendering
```

This deliberately observes MSForms text before implementing OxForms text. Text
metrics, anti-aliasing, baseline placement, and clipping are compatibility
surfaces; guessing here would bake in bad assumptions.

## Non-goals

- No OxForms text renderer implementation.
- No `UserForm.Show` implementation in OxForms.
- No `.frm` / `.frx` ingestion.
- No pixel-exact parity claim.
- No pass/fail typography tolerance policy.
- No wasm, Tauri, browser, macOS, or Linux backend implementation.
- No Office internals, decompilation, disassembly, or non-public source.

W004 is oracle/capture/pixel-fact work. It should improve our ability to
observe real MSForms text output, not expand the OxForms runtime surface.

## Clean-room Boundary

Allowed evidence is the same as W003:

- repo-owned fixture manifests;
- public Excel/VBIDE automation;
- public Windows APIs through the local capture harness;
- screenshots, window metadata, logs, hashes, and pixel facts captured from a
  normal Excel process.

Excluded:

- Office binary reverse engineering;
- proprietary implementation details;
- broad typography rules copied from non-public sources.

## Architecture Slice

### 1. Workset And Bead Graph

`oxforms-kgn.1` writes this workset, updates the register, and creates the W004
bead graph. The graph is intentionally linear because the later beads build on
the same fixture and evidence path.

### 2. Harness Generalization

W003 capture tooling was correctly conservative and wrote only under the W003
evidence directory. W004 should generalize that guard without making arbitrary
filesystem writes possible:

- Office oracle capture outputs may live under documented workset evidence
  directories inside `docs/evidence/`.
- The capture script must still reject paths outside the repository evidence
  tree.
- Tool docs must describe the evidence-only role of these scripts.
- The fixture generator should continue to support the W003 blank fixture while
  adding optional manifest fields for text-bearing labels.

The first text fields needed are:

- `caption`;
- `foreColorOle` / RGB notes;
- `font.name`;
- `font.sizePt`;
- `font.bold`, `italic`, `underline`, and `strikethrough` if set;
- `textAlign`;
- `wordWrap`;
- `autoSize`.

The generator should not invent a general form designer. It should support the
manifest fields W004 needs and fail clearly when a required value is missing.

### 3. Text-bearing Label Fixture

Create a new fixture directory rather than changing the closed W003 fixture.
The fixture should be boring:

- one Excel `UserForm`;
- one `Forms.Label.1`;
- fixed form and label geometry in points;
- simple caption text;
- explicit normal regular font settings;
- fixed `BackColor`, `ForeColor`, and border;
- controlled `TextAlign`, `WordWrap`, and `AutoSize` values.

Suggested first caption: `OxForms`.

Suggested first font: `Tahoma`, `8.25` points, regular. This matches the
classic MSForms default closely enough to be a useful starting point while still
being explicit in the fixture. If the host substitutes the font, the capture
evidence must record that limitation rather than pretending the glyph source is
known.

### 4. Live Text Capture And Pixel Facts

The capture bead should run the fixture on a Windows host with Excel available
and write W004 artifacts under:

```text
docs/evidence/W004_text_label_oracle_pixels/
```

The artifact set should include:

- fixture input path and hash;
- generated workbook and hash;
- exact open and capture commands;
- stdout/stderr logs;
- window capture manifest;
- screenshot and hash;
- platform, DPI, theme, and Excel version notes;
- checksum file for committed artifacts.

The pixel-fact report should record observations such as:

- screenshot dimensions;
- top-level window identity and bounds;
- label fill crop;
- text bounding crop within the label where detectable;
- representative non-background text/anti-aliasing colors;
- assumptions and uncertainty.

For W004, a text bounding crop can be derived from the known label crop and
pixels that differ from the label fill, border, and surrounding form background.
That is a sample-specific observation, not a general MSForms text metric rule.

### 5. Closure Review

W004 closes only after the text fixture/capture/pixel facts are recorded or a
concrete blocker bead exists. The closure review must check that:

- W004 does not mutate W003 evidence to make history cleaner;
- logs ignored by global `*.log` are explicitly tracked when they are evidence;
- text observations are presented as observed facts, not broad typography rules;
- no runtime adapter, fallback path, shim, or parity claim has crept into the
  evidence docs.

## Bead Plan

| Bead | Purpose | Depends on | Acceptance |
|---|---|---|---|
| `oxforms-kgn.1` | Define W004 workset and bead rollout | `oxforms-kgn` | Workset doc, register row, and bead graph agree. |
| `oxforms-kgn.2` | Generalize Office oracle harness for text-label evidence | `oxforms-kgn.1` | W004 evidence paths and optional text/font fields are supported without breaking W003. |
| `oxforms-kgn.3` | Create text-bearing Excel Label oracle fixture | `oxforms-kgn.2` | Repo-owned text Label fixture exists and dry-run validation passes. |
| `oxforms-kgn.4` | Capture text-bearing MSForms Label pixels | `oxforms-kgn.3` | Live capture artifacts and pixel facts exist, or a blocker bead records why capture could not complete. |
| `oxforms-kgn.5` | Record text oracle evidence and closure review | `oxforms-kgn.4` | Evidence, workset/register status, and closure review are complete. |

## Closure Condition

W004 closes when all of these are true:

1. A repo-owned text-bearing Excel/MSForms Label fixture exists with explicit
   caption, geometry, colors, font, alignment, wrapping, and sizing fields.
2. Live Windows/Excel capture artifacts exist for that fixture, or a concrete
   blocker bead records why capture could not complete.
3. Evidence artifacts are stored under documented W004 paths and include
   manifests, command logs, hashes, and screenshot pixels where capture
   succeeded.
4. A pixel-fact report records observed label/text crops and representative
   anti-aliasing colors while separating facts from assumptions.
5. Docs remain precise that W004 is text oracle/capture work, not OxForms text
   rendering or text parity.
6. Any blocker or out-of-scope discovery has a follow-up bead before closure.

## Verification Shape

| Surface | Check |
|---|---|
| Rust formatting | `cargo fmt --check` |
| Rust lint | `cargo clippy --workspace -- -D warnings` |
| Rust tests | `cargo test --workspace` |
| Fixture dry run | `powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Open-ExcelUserFormFixture.ps1 -FixtureDir <fixture-dir> -DryRun` |
| Windows capture | Targeted `Open-ExcelUserFormFixture.ps1` plus `Capture-Window.ps1` commands, or explicit blocker |
| Pixel facts | Scripted or documented read of committed screenshot pixels |
| Capture checksums | SHA-256 validation of committed evidence files |
| Bead graph | `br dep cycles` and `br ready --json` |

## Risks And Controls

| Risk | Control |
|---|---|
| Text rendering varies by font availability, DPI, theme, and anti-aliasing settings. | Record font assumptions, platform/theme/DPI notes, and treat the result as a first sample. |
| The fixture is too rich and hides the first text issue. | Use one label, one caption, one font, and one capture. |
| W004 accidentally mutates W003 history. | Add a new fixture/evidence path and link back to W003 instead of rewriting it. |
| Capture tooling becomes a general automation framework. | Generalize only evidence root handling and text fixture fields needed by W004. |
| The text pixel report implies pass/fail parity too early. | Label W004 output as observed MSForms pixel facts and defer tolerances. |
| Clean-room boundaries blur. | Use only public APIs, black-box Office automation, screenshots, metadata, logs, and repo-owned fixture inputs. |
