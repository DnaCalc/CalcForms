# W007 desktop backend slice (oxforms-4pn.6)

Records the first *visible* OxForms backend: the `oxforms-pal-win` crate that turns a
control-blind [`Scene`] into pixels in a real window and OS events into normalized
`UiEvent`s, and how it was verified (windows cannot be checked by the headless golden
oracle, so this slice is proven by rendering to screen).

## What this slice delivers

- **A control-blind desktop backend crate.** `crates/oxforms-pal-win` depends on
  **only** `oxforms-pal` (the host-neutral Scene + input contracts) — not
  `oxforms-core`/runtime. Control and routing policy stay out of the backend by
  construction; the bootstrap exe (`oxforms-4pn.7`) is what wires the two together.
  Stack per `docs/specs/RENDERING_ARCHITECTURE.md` §15 (revisitable): **winit 0.30 +
  softbuffer 0.4 + tiny-skia 0.11 + ab_glyph 0.2**.

- **A tiny-skia `PrimSink` rasterizer** (`raster.rs`, `SkiaSink`): the visible twin of
  the text-free `HeadlessSink` golden oracle. Same Scene walk and transform/clip
  semantics, but it actually rasterizes the §6.2 vocabulary — `FillRect`, `StrokeRect`,
  `RoundRect`, `Ellipse`, `Line`, `Polygon`, `Gradient`, `DrawEdge` (3D light/shadow for
  raised/sunken/etched/bump), and `DrawText` (ab_glyph). Geometry is taken to device
  space by the sink (mirroring `HeadlessSink`'s `cur`/`clip` stacks); clips become a
  device-space rect/`Mask`; text composites per-pixel against the device clip. An
  ambient device transform (physical px ÷ logical surface) scales a 200×120-pt form to
  fill the window crisply. `DrawImage` is the one recorded-but-unused prim (the demo
  form has none); single-line text only for now (`wrap` is carried but not yet laid out).

- **A shaped-run text seam** (`text.rs`, RENDERING_ARCHITECTURE.md §8). The Scene
  `DrawText` prim references a `TextRunId` only — never an inline string — and text is
  retained as a *shaped run* (`oxforms_pal::scene::TextRun`: positioned glyphs +
  metrics + caret) in `Scene.text`. `AbGlyphShaper` shapes a caption into that run once
  per change; the rasterizer **blits the positioned glyphs and never re-shapes** at
  paint. `TextResolver`/`SceneTextResolver` resolves a run id → the resident `TextRun`
  and a font id → a face held in a `FontTable`; the platform UI font loads from
  `%WINDIR%\Fonts` (Microsoft Sans Serif / Tahoma / Segoe UI fallback). The golden
  `HeadlessSink` renders no text and needs none of this, so the framebuffer hash stays
  font-independent. *(This replaced the earlier per-paint `TextRegistry`/`ResolvedTextRun`
  resolver in oxforms-4pn.12.)*

- **Pure winit → `UiEvent` normalization** (`input.rs`): headless-testable functions
  mapping winit leaf events (cursor, mouse button, keyboard, character, focus, resize)
  to the W005 normalized contract, filling client-pixel coordinates + DPI. Mapping
  client px → form-logical points (the bootstrap's job, which knows the render scale) is
  the pure `with_form_logical` helper, kept here but layered so the normalizer never
  needs a form's geometry.

- **A winit + softbuffer present loop** (`window.rs`, `run_scene_window`): on each
  redraw it rasterizes the current `Scene` into a `tiny_skia::Pixmap` and blits it to
  the softbuffer surface (RGBA → `0RGB`), and routes normalized input to a caller
  callback returning a `WindowSignal` (Ignore/Redraw/Close). The window is itself
  control-blind.

- **A raw-primitive fixture + visible smoke** (`fixture.rs`, `bin/w007_window_smoke.rs`).
  The greeter fixture is **hand-authored `Prim` data** (only `oxforms-pal` Scene types)
  standing in for what VBA self-render (`OxControlPaint` → `OxSceneBuilder`) will emit
  across `OxForms.Surface`; it mirrors the demo greeter's shape in its post-interaction
  state ("World" typed, "Hello, World" shown). It lets the backend be proven end-to-end
  before the OxVba integration is wired (`oxforms-4pn.7/.8`).

## Verification

Headless floor (deterministic, in CI scope): `cargo fmt`, `cargo clippy -D warnings`,
and 24 `oxforms-pal-win` unit tests. These include real pixel assertions on `SkiaSink`
(fills, ambient device scale, raised- and sunken-edge light/shadow placement, clip
confinement, glyph coverage, accelerator underline, gradient direction + single-stop
fallback, fractional/degenerate device scale), a **whole-frame golden hash** over a
geometry showcase (every prim + all five edge effects), a **cross-oracle agreement**
test (`SkiaSink` matches the text-free `HeadlessSink` pixel-for-pixel for opaque integer
fills), an **empty-clip suppression** regression, and the pure input normalizers.

Because a window cannot be checked by the golden oracle, on-screen artifacts in
`captures/desktop-backend-window-smoke-20260624/` close the loop (the live window is
captured via `PrintWindow`, which reads the window's own pixels even when occluded):

- **`rasterizer-greeter.png`** — the greeter fixture rendered through
  `render_scene_to_pixmap` to a PNG (the Scene→pixels path), at 4× scale.
- **`live-window.png`** — a capture of the running `w007_window_smoke` winit window
  (the winit + softbuffer **present** path): native title bar plus the sunken "World"
  field, the raised default "OK" button, and the "Hello, World" label.
- **`live-window-ok-pressed.png`** — the same window captured mid-click, with the OK
  button nudged into its pressed offset — evidence that the input→scene-mutation→`Redraw`
  loop actually repaints (the callback offsets the button on `MouseDown` and restores it
  on `MouseUp`).
- **`input-event-log.txt`** — the smoke's normalized-event log from driving the live
  window: `Resize` → `MouseDown`/`MouseUp` (the press/restore mutation) → `CloseRequest`
  → clean close (process exit 0). A separate run exercised keyboard input (Shift+`H` →
  `KeyDown Character("H")` + `CharacterInput "H"`, control characters filtered).

## Non-claims (deferred to later W007 beads)

- No OxVba in the loop yet: the live window renders the raw-primitive fixture, not a
  VBA-emitted `ScenePatch`. Wiring `OxForms.Surface` → resident `Scene` →
  `run_scene_window` and runtime routing on `with_form_logical` coordinates is
  `oxforms-4pn.7` (bootstrap exe) / `oxforms-4pn.8` (runnable demo).
- Text is single-line (no `wrap` layout); `DrawImage` is not yet rasterized; the
  accelerator-underline path exists but the demo does not exercise it. Raster backends
  behind a `PrimSink` (Direct2D/GDI) and a font abstraction beyond ab_glyph remain the
  §15 revisitable seam.
