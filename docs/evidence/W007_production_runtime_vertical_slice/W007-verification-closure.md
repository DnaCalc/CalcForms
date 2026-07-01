# W007 — verification & closure (oxforms-4pn.9)

Current-code note: W007 closed with the then-current `RuntimeRunner`/`oxforms-core` shape. The
later `oxforms-ih6` pivot deleted `oxforms-core` and replaced `RuntimeRunner` with the thin
`OxRuntime` driver over the VBA `OxReducer`; the end-to-end live-window claim remains, but the
ownership names below are historical where they say `RuntimeRunner`.

The W007 "production runtime vertical slice" is complete: **real VBA form code, running
on OxVba, self-renders across the `OxForms.Surface` boundary into a control-blind
retained `Scene`, the desktop backend rasterizes it to a live window, and live OS input
drives the VBA event handlers** — type a name + click OK → "Hello, &lt;name&gt;"; an
AutoSize label hugs its caption and re-fits when the font grows.

## What is proven (and where)

| Capability | Evidence |
|---|---|
| VBA controls self-render → one batched `ScenePatch` → retained `Scene` (framebuffer hash == canonical Rust scene) | `oxvba_surface_render_smoke::vba_self_render_crosses_the_surface_and_matches_the_canonical_scene` |
| Native VBA event dispatch through `WithEvents` (Click/MouseDown/MouseUp/[Exit]) | `oxvba_w006_native_fm20_event_gate` |
| Runtime effect runner: reduce → native OxVba dispatch → property sync → repaint + trace | `oxforms-oxvba-adapter` `runtime_runner` tests |
| `render_frame` (Re-render): VBA self-render → resident revision; a caption change moves the frame token | `oxvba_w007_render_frame` |
| Text-metrics seam: caption crosses once via `MeasureText`, shaped run retained, captions in `Scene.text` | `oxvba_surface_render_smoke` (scene.text Hi/OK/Ready) |
| Captions rasterize through the real ab_glyph shaper (FONT_ID coupling pinned) | `oxvba_surface_render_smoke::vba_self_render_rasterizes_captions_through_the_real_shaper` |
| Repaint reuses the resident shaped run with **no paint-time reshape** | `oxforms-pal-win::raster` `repaint_reuses_the_resident_run_without_re_shaping` |
| AutoSize-hug: measure → layout → paint; bounds = metrics + insets; re-fit on font change | `oxvba_surface_render_smoke::autosize_label_bounds_track_metrics_and_grow_with_font_size` |
| **Live window** (the non-headless path) | captures: `bootstrap-live-window-20260624/`, `text-seam-live-captions-20260626/`, `interaction-loop-live-greeting-20260626/` (type→click→"Hello, World"), `autosize-hug-20260626/` (box hugs + grows) |

Visible-window captures are produced via the gitignored `target/*.ps1` PrintWindow +
PostMessage recipe (occlusion-proof, no foreground steal; sends `WM_MOUSEMOVE` before
each click because winit takes a click's coordinates from the last cursor position).

## Verification gate (this close-out)

- `cargo fmt --all --check` — clean.
- `cargo clippy --workspace --all-targets -- -D warnings` — clean.
- `cargo test --workspace` — **138 tests across 17 suites, all passing.**

## Architectural integrity (close-out drift review)

A holistic review confirmed the §16 invariants hold across the shipped code:
- **Kernel + backend stay control-blind.** `oxforms-pal` / `oxforms-pal-win` carry only
  geometry/scene/pixels/text-shaping/OS-event normalization; `pal-win` depends only on
  `oxforms-pal`. No control vocabulary leaks into non-test code.
- **Ownership topology (§16.3).** Historically, the runtime (`RuntimeRunner`) owned all VBA entry
  (`dispatch` + `render_frame`); the backend owns Repaint + the OS pump and never enters
  VBA; the bootstrap is a thin assembler that neither rasterizes nor owns control behavior. In the
  current code, `OxRuntime` owns the corresponding VBA entry (`Dispatch*`, lifecycle, and `Render`).
- **Test infra did not become the runtime path.** `oxforms-pal-win` is a *test-only*
  dev-dependency of the adapter; quarantine boundaries (SmokeCanvas/W002, `controls.rs`)
  are intact. The one interim is the bootstrap reusing a `vba/smoke/fixtures` form as its
  demo (documented in `main.rs`, promoted to a real `Sub Main` demo project later).

## Claims / non-claims

- **Claimed:** the end-to-end slice above, on the pinned OxVba baseline `95be9ff2`, with
  the §15 desktop stack (winit + softbuffer + tiny-skia + ab_glyph).
- **Not claimed (deferred, tracked):** the incremental-patch render path (full-rebuild
  every frame today — `oxforms-rq5.2`); a real top-level `Sub Main` demo project (the
  bootstrap uses a minimal entrypoint + a shared smoke fixture); multi-font / bold-italic
  text; a VBA-side text→id memo (Rust de-dups today); the JSON wire-format perf
  exploration (owner concern, deferred). One open OxVba divergence is handed over
  (`HANDOVER_OxVba_left_intrinsic_shadowed.md` addendum: a class's own `Left` property
  shadows the `Left$` intrinsic; worked around with `Mid$`).

## Open OxVba divergence handover note

`Left$` is resolved to a class's own `Left` property inside that class's methods (a
same-class recurrence of the earlier shadowing bug, not covered by fix `95be9ff2`).
Worked around with `Mid$`; OxVba fix pending. See the handover.
