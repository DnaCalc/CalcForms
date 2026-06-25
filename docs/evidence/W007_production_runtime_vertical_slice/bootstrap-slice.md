# W007 thin bootstrap slice (oxforms-4pn.7)

Records the thin bootstrap that assembles the OxForms runtime and the desktop backend
into the first **live, end-to-end** W007 window: real VBA control code, running on
OxVba, self-renders across the `OxForms.Surface` boundary into a Rust-side retained
`Scene`, which the `oxforms-pal-win` window rasterizes to screen.

## What this slice delivers

- **The render_frame Re-render seam** (the runtime half of `RENDERING_ARCHITECTURE.md`
  §16). `OxUserForm.Render(DpiX, DpiY)` is the form's self-render: it `CreateObject`s
  `OxForms.Surface`, `BeginScene`s at its own size, builds one batched `ScenePatch`, and
  `SubmitPatch`es it — then clears the reconciled invalidation set. `RuntimeRunner::render_frame()`
  invokes it; the runtime is the **sole owner of all VBA entry** (both `dispatch` and
  `render_frame`), so VM re-entrancy stays safe. Full-rebuild v1 (`BeginScene` each
  frame); incremental patching is `oxforms-rq5.2`. Proven headlessly by
  `crates/oxforms-oxvba-adapter/tests/oxvba_w007_render_frame.rs` (render_frame drives
  VBA self-render into a resident 4-node 200×120 scene; deterministic token; the
  monotonic revision advances; the runtime drives both dispatch and render).

- **The thin bootstrap** (`crates/oxforms-bootstrap`). Per §16.3 it is a *thin
  assembler*: it loads the OxVba project (the OxForms VBA library + the demo form,
  embedded), registers the `OxForms.Surface` boundary, invokes the VBA startup
  (constructs + builds the demo form via the runtime), produces the first resident
  `Scene` revision, and runs the `oxforms-pal-win` platform loop. It holds **no**
  control or demo behavior (that is VBA), never calls VBA directly (the runtime owns
  all VBA entry), and never rasterizes (the backend owns Repaint). Stage-tagged
  diagnostics distinguish OxVba project (load/bind/linearize/prepare, exit 2), OxForms
  runtime (attach/render, exit 3), and PAL/window (exit 4) from a clean exit (0).

## Verification

`captures/bootstrap-live-window-20260625/`:

- **`bootstrap-live-window.png`** — a `PrintWindow` capture of the running
  `oxforms-bootstrap` window. Everything inside the client area is from **real VBA
  self-render** through the full spine (VBA `Render` → `OxForms.Surface` → retained
  `Scene` → tiny-skia): the form face, the **sunken** white input field, the **raised**
  gray OK button, and the OutputLabel fill. No window/runtime hand-drawing.
- **`bootstrap-run-log.txt`** — the run log, ending in `window closed; clean exit.`
  (the window was driven to close via a targeted `WM_CLOSE` → normalized `CloseRequest`
  → callback `Close` → loop exit, returning `Ok(())`).

Floor: `cargo fmt`, `cargo clippy --workspace -D warnings`, `cargo build --workspace`,
and the headless `render_frame` integration test, all green.

## Non-claims (the next increment, oxforms-4pn.8)

- **Captions are not yet on screen.** Controls emit `DrawText` with run id 0 because
  the `MeasureText`/`RegisterFont` text-run crossing is deferred
  (`RENDERING_ARCHITECTURE.md` §6/§8), so the resident scene carries control **chrome**
  (fills + 3D edges) but not caption text. Rendering captions across the live boundary
  (and so the live "Hello, &lt;name&gt;" greeting on type → click) lands with the
  text-run crossing.
- **The startup entrypoint is minimal.** The bootstrap invokes the VBA startup by
  constructing + building the demo form via the runtime; a real top-level `Sub Main`
  in a loaded demo project is the generalization.
- **The OutputLabel currently paints a solid fill** (its VBA `Render`/theme), which is
  not MSForms-faithful for a transparent label; that is VBA appearance/theme work, not a
  bootstrap concern.
