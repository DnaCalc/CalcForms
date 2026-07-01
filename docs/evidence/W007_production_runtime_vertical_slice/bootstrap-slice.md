# W007 thin bootstrap slice (oxforms-4pn.7)

Records the thin bootstrap that assembles the OxForms runtime and the desktop backend
into the first **live, end-to-end** W007 window: real VBA control code, running on
OxVba, self-renders across the `OxForms.Surface` boundary into a Rust-side retained
`Scene`, which the `oxforms-pal-win` window rasterizes to screen.

## What this slice delivers

- **The render_frame Re-render seam** (the runtime half of `RENDERING_ARCHITECTURE.md`
  §16). `UserForm.Render(DpiX, DpiY)` is the form's self-render: it `CreateObject`s
  `OxForms.Surface`, `BeginScene`s at its own size, builds one batched `ScenePatch`, and
  `SubmitPatch`es it — then clears the reconciled invalidation set. Historically,
  `RuntimeRunner::render_frame()` invoked it; after `oxforms-ih6`, `OxRuntime::render()` invokes the
  form-document's VBA `Render` member. The runtime remains the **sole owner of all VBA entry** (input
  dispatch/lifecycle/render), so VM re-entrancy stays safe. Full-rebuild v1 (`BeginScene` each
  frame); incremental patching is `oxforms-rq5.2`. The original headless proof was
  `crates/oxforms-oxvba-adapter/tests/oxvba_w007_render_frame.rs`; current runtime wiring is covered
  by `oxvba_runtime_greeter.rs` plus the surface render smoke tests.

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

- **Captions now render (resolved in oxforms-4pn.10–.13).** Controls emit real
  content-hash run ids: the per-frame measure pre-pass crosses each caption once via
  `OxForms.Surface.MeasureText`, which shapes it into a resident `TextRun`; the backend
  blits those runs. The live bootstrap window shows "OK" on the button and "(idle)" on
  the label — see `captures/text-seam-live-captions-20260626/bootstrap-live-captions.png`.
  *(static post-load state.)*
- **The live type → click → greeting works (oxforms-4pn.8e).** The bootstrap's
  `run_scene_window` callback is the interaction consumer loop: it maps client pixels →
  form-logical points (the uniform device-fit scale, mirrored from the rasterizer), asks
  the runtime to `dispatch` the event, and on a requested repaint `render_frame`s +
  refreshes the held `Scene` from the resident snapshot + returns `Redraw`. Driving the
  live window (type "World" into the field, click OK) runs the VBA `OkButton_Click`
  handler and the label updates to "Hello, World" on screen — see
  `captures/interaction-loop-live-greeting-20260626/live-type-click-greeting.png`. Drive
  recipe note: winit derives a click's coordinates from the last cursor position, so the
  PrintWindow/PostMessage recipe sends `WM_MOUSEMOVE` to the target before each
  `WM_LBUTTONDOWN/UP` (a `WM_LBUTTON` with no prior move lands at the stale cursor).
- **The startup entrypoint is minimal.** The bootstrap invokes the VBA startup by
  constructing + building the demo form via the runtime; a real top-level `Sub Main`
  in a loaded demo project is the generalization.
- **The OutputLabel currently paints a solid fill** (its VBA `Render`/theme), which is
  not MSForms-faithful for a transparent label; that is VBA appearance/theme work, not a
  bootstrap concern.
