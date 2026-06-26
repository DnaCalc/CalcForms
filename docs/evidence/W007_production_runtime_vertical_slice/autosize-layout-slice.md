# W007 evidence — AutoSize layout (measure → layout → paint), oxforms-4pn.14

The text-metrics round-trip is **load-bearing**, not merely plumbed: a control's layout
consumes the measured run. An MSForms `AutoSize` label shrink-wraps its caption — the
per-frame **measure → layout → paint** pipeline derives the label's bounds from
`OxForms.Surface.MeasureText` metrics before any geometry is emitted, so its face,
border, and node bounds hug the text and re-fit when the text or font size changes. A
wrong measurement would be a visibly wrong box.

## Pipeline

1. **Measure** (`OxUserForm.BuildScenePatch`, measure pass): each text control crosses
   its caption once via `Surface.MeasureText` → stamps `Core.RunId` + `Core.MeasuredWidth`
   / `Core.MeasuredHeight` (parsed from the `id:advance:ascent:descent:linegap` result).
2. **Layout** (layout pass): an `AutoSize` control sets `Width`/`Height` from the measured
   run + padding (matching `OxControlPaint`'s 4pt/3pt text insets) — *before* paint.
3. **Paint**: `OxControlPaint` emits the face + hugging border + text at the fitted bounds.

## Proof

- **Headless, deterministic** (`oxvba_surface_render_smoke::autosize_label_bounds_track_metrics_and_grow_with_font_size`,
  StubShaper): the AutoLabel node paints a hugging border (a `StrokeRect`), and after a
  font-size increase (`GrowFont`) the node's bounds **grow in both width and height** —
  i.e. the bounds track the metrics, and a font change re-measures + re-fits.
- **Visible** (real ab_glyph shaper): `captures/autosize-hug-20260626/autosize-small.png`
  and `autosize-big.png` show the bordered box hugging "Size me" and growing with the
  font. Regenerate with `cargo test -p oxforms-oxvba-adapter --test oxvba_surface_render_smoke -- --ignored autosize_evidence`.

Spec: `RENDERING_ARCHITECTURE.md` §8 (the measure → layout → paint pipeline / layout
consumes the metrics).
