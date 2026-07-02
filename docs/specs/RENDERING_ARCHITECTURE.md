# OxForms Rendering Architecture — The Scene

Status: design accepted (owner-directed foundation pass). Owning bead: `oxforms-rq5`.
Supersedes the W005/W006 control-aware Rust render path (`oxforms-core` probe
display list). Amends charter/spec decision **D7** (see §13).

> **One line:** VBA controls paint themselves in pure immediate mode; the Rust
> kernel retains the emitted primitives as a control-blind, keyed tree (the
> **Scene**) that it diffs to repaint minimally — and a full re-emit is
> byte-identical to the legacy immediate display list, so the retained machinery
> can never silently diverge from the deterministic canonical path.

## 1. Purpose and scope

This document defines how OxForms turns a VBA control tree into pixels, and the
contract between the VBA library and the Rust kernel. It realizes the charter:

- **D1** single window + owner-drawn control tree;
- **D3** purpose-built GDI+/Canvas2D primitive vocabulary;
- **D10** VBA-first (controls, appearance, behavior live in VBA);
- **D11** serializable/replayable render representation;
- **D7 (revised, §13)** reducer-driven state + a retained primitive tree authored
  in immediate mode.

The governing principle (owner-confirmed): **the Rust kernel is control-blind.**
It knows pixels, geometry, color, glyphs, clips, transforms, and input — never
"TextBox" or "Label". All control knowledge, MSForms appearance, and 3D-edge
effect/color selection live in VBA.

## 2. The authoring-vs-storage separation (the key idea)

Two models that are usually conflated are kept orthogonal:

- **Authoring model = immediate.** A control's `Render` method emits a fresh
  primitive stream each time it is asked to paint. This is what D7 protected and
  what keeps control authoring simple; it is invisible to whether Rust retains
  anything.
- **Storage model = retained.** The kernel keeps the emitted primitives in a
  keyed arena so it can diff frame-to-frame and repaint only what changed.

Retention is justified **now, not deferred**, because the per-control
invalidation signal we *already* compute (`OxControlCore.MarkDirty` →
`IOxControlHost.OnControlInvalidated` → `UserForm.InvalidatedControls`, and the
reducer's `RenderInvalidation`) is currently discarded at the PAL boundary. The
Scene is where that signal is cashed out into incremental repaint, scrolling,
animation, designer reuse, and subtree caching — without putting any control
type in Rust. A full rebuild degenerates to pure immediate mode, so we lose
nothing by retaining.

## 3. The Rust kernel — `oxforms_pal::scene` (control-agnostic)

A new module under `oxforms-pal` (keeps `#![forbid(unsafe_code)]`). It reuses
`Color` and adds f32 logical geometry alongside the existing i32 `Rect` (which
the FillRect smoke path keeps until superseded). Identity is opaque to the
kernel.

```rust
pub const SCENE_VERSION: u16 = 1;
pub const SCENE_PATCH_VERSION: u16 = 1;

/// Opaque, stable per-node identity. VBA interns it from
/// (form_id, control_id, sub_part_tag). The kernel NEVER interprets it beyond Eq/Hash/Ord.
#[derive(Clone, Copy, Eq, PartialEq, Hash, Ord, PartialOrd, Serialize, Deserialize)]
pub struct NodeId(pub u64);

#[derive(Clone, Copy, Serialize, Deserialize)] pub struct RectF { pub x: f32, pub y: f32, pub w: f32, pub h: f32 }
#[derive(Clone, Copy, Serialize, Deserialize)] pub struct PointF { pub x: f32, pub y: f32 }
/// Translate + uniform scale only for v1 (covers DPI, scroll, offset).
#[derive(Clone, Copy, Serialize, Deserialize)] pub struct Affine { pub sx: f32, pub sy: f32, pub tx: f32, pub ty: f32 }

#[derive(Clone, PartialEq, Serialize, Deserialize)]
pub enum Paint { Solid(Color), LinearGradient { stops: Vec<(f32, Color)>, angle: f32 } }
#[derive(Clone, PartialEq, Serialize, Deserialize)]
pub struct Stroke { pub paint: Paint, pub width: f32 }

/// Exactly the spec §6.2 vocabulary. No control words. Transform/clip are on the
/// NODE, so the prim stream is purely geometric paint.
#[derive(Clone, PartialEq, Serialize, Deserialize)]
pub enum Prim {
    FillRect   { rect: RectF, paint: Paint },
    StrokeRect { rect: RectF, stroke: Stroke },
    RoundRect  { rect: RectF, radius: f32, fill: Option<Paint>, stroke: Option<Stroke> },
    Ellipse    { rect: RectF, fill: Option<Paint>, stroke: Option<Stroke> },
    Line       { a: PointF, b: PointF, stroke: Stroke },
    Polygon    { pts: Vec<PointF>, fill: Option<Paint>, stroke: Option<Stroke> },
    Gradient   { rect: RectF, stops: Vec<(f32, Color)>, angle: f32 },
    DrawText   { run: TextRunId, rect: RectF, align: TextAlign, wrap: bool, clip: bool, paint: Paint, flags: TextFlags },
    DrawImage  { image: ImageHandle, src: RectF, dst: RectF, mode: ImageMode },
    /// MSForms 3D look, composed from light/shadow Line/StrokeRect in ONE shared Rust helper.
    DrawEdge   { rect: RectF, effect: EdgeEffect, border: EdgeBorder, light: Color, shadow: Color },
}

/// One retained node. Children referenced by key, so a subtree move is a key edit.
#[derive(Clone, Serialize, Deserialize)]
pub struct SceneNode {
    pub id: NodeId,
    pub parent: Option<NodeId>,
    pub z: i32,
    pub transform: Affine,          // identity for most controls
    pub clip: Option<RectF>,        // Frame / MultiPage page
    pub bounds: RectF,              // self bounds in parent space (damage + pick)
    pub visible: bool,
    pub content_hash: u64,          // fnv1a64 over prims + geometry
    pub prims: Vec<Prim>,
    pub children: Vec<NodeId>,      // resolved (z, insert) paint order
    #[serde(skip)] pub cache: Option<CacheHandle>, // §4.6 backend-native layer cache
}

/// Canonical retained representation: a flat arena keyed by NodeId.
#[derive(Default, Serialize, Deserialize)]
pub struct Scene {
    pub version: u16,
    pub surface: SurfaceSize,
    pub dpi: DpiScale,
    pub root: NodeId,
    pub nodes: HashMap<NodeId, SceneNode>,
    #[serde(default)] pub text: BTreeMap<u64, TextRun>, // resident shaped runs by TextRunId;
                                          // serialized so a snapshot is self-contained. The
                                          // persistent interning/LRU cache is Surface-held;
                                          // this is its per-frame projection (referenced runs).
    #[serde(skip)] pub damage: DamageSet,
    #[serde(skip)] pub frame_hash: u64,   // rolled-up content hash, used as base_hash
}

#[derive(Default)] pub struct DamageSet { pub rects: Vec<RectF>, pub dirty: HashSet<NodeId> }

/// The unit that crosses the boundary. Versioned, serde-shaped, hand-inspectable.
#[derive(Serialize, Deserialize)]
pub struct ScenePatch {
    pub version: u16, pub base_hash: u64, pub surface: SurfaceSize,
    pub dpi: DpiScale, pub edits: Vec<NodeEdit>,
}
#[derive(Serialize, Deserialize)]
pub enum NodeEdit {
    Upsert(SceneNode),                            // new or changed full node
    Retain(NodeId),                               // unchanged: zero-prim wire signal
    Remove(NodeId),
    Reorder { id: NodeId, z: i32, parent: Option<NodeId> },
}

/// Parallel hit geometry, keyed identically to paint, STRUCTURALLY separate from it.
#[derive(Serialize, Deserialize)]
pub struct HitNode { pub id: NodeId, pub bounds: RectF, pub clip: Option<RectF>, pub transform: Affine, pub z: i32, pub transparent: bool }
```

Entry points (all control-blind):

- `Scene::apply_patch(&mut self, &ScenePatch) -> Result<DamageSet, SceneError>` —
  if `patch.base_hash != self.frame_hash`, return `SceneError::StaleBase` and the
  runtime resubmits a full rebuild (self-healing). Otherwise each `Upsert`
  compares incoming `content_hash` against the resident node: equal → no damage
  (collapses an over-invalidation to a no-op); different → replace prims, add
  old ∪ new bounds to damage. `Remove`/`Reorder` damage old and new bounds.
  `Retain` costs nothing. Bounds-checked decode fails deterministically.
- `render_full(&Scene, &mut dyn PrimSink)` — walks nodes in (parent, z, insert)
  order applying transform/clip, replaying prims; the deterministic golden path
  uses `HeadlessSink`, which owns the canonical `framebuffer_hash`.
- `render_damage(&Scene, &mut dyn PrimSink, &DamageSet)` — clips the walk to nodes
  intersecting coalesced damage rects, z-aware so overlaps/transparent controls
  recomposite correctly.
- `pick(&[HitNode], PointF) -> Option<NodeId>` — pure-geometry topmost-by-(z,order)
  respecting clip/transform.

Backends implement one trait, `PrimSink` (push/pop clip + transform; fill/stroke
rect; round_rect; ellipse; line; polygon; gradient; draw_text; draw_image;
draw_edge). `HeadlessSink` is the deterministic reference oracle; tiny-skia is
the first visible CPU rasterizer; Direct2D/Canvas2D/WebGPU are thin walkers. The
scene types live in `oxforms-pal`; the `Variant`↔`ScenePatch` marshalling and
`NodeId`↔`IOxControl` map live in `oxforms-oxvba-adapter`.

## 4. DrawEdge composition

`SpecialEffect` (Flat/Raised/Sunken/Etched/Bump per §5.6) maps to `EdgeEffect`;
`DrawEdge` is composed from light/shadow `Line`/`StrokeRect` in **one shared Rust
helper**, not per backend, so the MSForms 3D looks are pixel-consistent
everywhere and golden tolerance is confined to text rasterization. The kernel
draws "a sunken edge on this rect" — never "a TextBox border".

## 5. The VBA control model

Control authors write pure immediate-mode paint. `IOxControl` grows one method:

```vb
' IOxControl.cls
Public Sub Render(ByVal Surface As Object)   ' Surface = OxSceneSurface (the builder)
End Sub
```

`OxControlCore` gains the appearance band + identity (each render-affecting setter
calls the existing `MarkDirty` seam): `NodeId` (interned from
form+control+subpart) + a `content_version`; `BackColor`/`ForeColor`/`BorderColor`
(OLE_COLOR Longs incl. `0x80000000` system indices), `SpecialEffect`,
`BorderStyle` — the §5.6 owned appearance data. Per-control default `SpecialEffect`
(morph controls Sunken, ToggleButton MUST be Sunken, Form/Label/Image Flat) is a
VBA default set in `Class_Initialize`, never kernel knowledge.

The surface/builder contract (immediate, GDI-like, accumulates VBA-side, **zero
per-call crossings**):

```vb
Surface.OpenNode key:=Me.NodeId, parent:=mParentId, z:=Me.ZOrder, bounds:=Me.Bounds
Surface.FillRect Me.Bounds, faceColor
Surface.DrawEdge Me.Bounds, effect, border, lightColor, shadowColor
Surface.DrawText runId, textRect, fmAlignLeft, wrap:=False, paint:=foreColor
Surface.CloseNode
```

Theming (relocated from `probe.rs`'s `probe_face_color`/`ProbeDisplayRole`/
`build_probe_display_list`): an **`OxTheme`** ThemePainter seam maps
(logical role × SpecialEffect × BorderStyle × MSForms color bands × state
{normal,pressed,disabled,focused,selected})
→ resolved Paint/Stroke/EdgeEffect/light+shadow colors and common Scene primitives.
As of `oxforms-zhz.18`, `OxTheme.bas` owns representative v1 helpers for frames,
text, selection, and caret color; the tokens are internal vocabulary, while
MSForms properties remain authoritative. "Classic MSForms" is the default table;
alternate themes are just different data, touching no kernel and no control code.
`OLE_COLOR` with the `0x80000000` high bit resolves through a PAL service
`Surface.ResolveSysColor(oleColor) -> RGBA`: VBA decides *which* system color;
the platform resolves the *value*.

### The "add a control" recipe

1. New `Foo.cls` (the Forms 2.0 control name, no `Ox` prefix) `Implements IOxControl`,
   holding an `OxControlCore` for geometry/flags/appearance/NodeId.
2. Set its default `fmSpecialEffect`/`fmBorderStyle` in `Class_Initialize`.
3. Implement `Render`: open node → ask `OxTheme`/ThemePainter for the role's resolved
   primitives → emit them → close node. Give any high-frequency / independently
   damaged element (caret, focus rect, checkbox glyph) its **own sub-part NodeId**
   so a caret blink re-emits one tiny node.
4. Implement the native event surface (`PerformClick`/`ApplyUserText`/… →
   `RaiseEvent`; ByRef cancel via `ReturnInteger`/`ReturnBoolean`).
5. Register a theme row for its role.
6. Add a Case mapping its Forms 2.0 ProgID (`"Forms.Foo.1"`) in `OxFormsModel`'s
   `OxKindFromProgId` + `OxCreateControl`, so `Controls.Add "Forms.Foo.1", name` creates it.

No Rust change. No new primitive. The kernel never learns the word "Foo". The public
creation surface is Forms 2.0 (`Controls.Add` by ProgID); `OxControlKind`/`OxCreateControl`
are OxForms-internal machinery behind it.

## 6. Cross-boundary protocol

The boundary stays the D2 shape proven by W002 (an injected
`PortableComProjection` object, flat value-typed members), generalized from
`SmokeCanvas` (CreateSurface/FillRect/Flush) into **`OxForms.Surface`**. The
non-negotiable rule: **never one crossing per primitive; one batched `ScenePatch`
per frame.**

VBA-side authoring (buffered, does NOT cross): `OpenNode`/`CloseNode` + the ~12
primitive recorders + `RetainNode(key)` mutate a VBA-side `OxSceneBuilder`.

The crossings (flat Variants, serde-shaped payload):

- `BeginScene(w, h, dpiX, dpiY)` — rare (resize / first show / DPI change).
- `RegisterFont(family, sizePt, bold, italic, underline) -> FontId` — once per font.
- `MeasureBatch(requests) -> results[]` — one batched call measuring every run a frame
  needs (oxforms-98v): typed `SAFEARRAY`s of `OxMeasureRequest`/`OxMeasureResult` records, so
  captions cross as native `String` fields (no packing/escaping) and metrics return as typed
  `Long`s (no VBA-side parsing). As of `oxforms-zhz.11`, results also carry the shaped run's
  caret stops as a milli-point CSV field; as of `oxforms-zhz.16`, VBA `OxTextService`
  consumes those results for TextBox caret placement, selection geometry, x-to-index
  hit-testing, and horizontal scroll/clipped single-line draw. The single-run
  `MeasureText(fontId, sizeMilliPt, caption)` remains for one-off measures. Cached both sides,
  so steady-state frames need zero new-text crossings.
- `SubmitPatch(payload) -> RenderDiagnostics` — **the** per-frame crossing (folds
  Render in via a flag). Returns `command_count` + `framebuffer_hash`. Carries
  `base_hash`; on `StaleBase` the runtime resubmits a full rebuild.
- `HitTest(x, y) -> NodeId` — one crossing per pointer event needing geometry;
  skipped under capture (route by captured NodeId) and answered from a VBA-side
  bounds cache for hover.
- `ResolveSysColor(index) -> RGBA`, `DecodeImage(bytes) -> ImageHandle` — cached
  services.

**Crossing budget** (measured P6 acceptance gates, not assumptions): 50-control
first paint ≈ 3–5 crossings total, *independent of control count*; one keystroke
≈ 1–2 crossings, *independent of the other 49 controls*; drag under capture = 0
hit-test crossings. If the VBA-side encoder profiles hot, only the encoder
migrates to Rust under §4.6 — the contract is unchanged. **Realized + gated
(oxforms-98v):** first paint is `BeginScene + MeasureBatch + SubmitPatch` = 3 crossings
independent of control count (`first_paint_crosses_once_for_all_text_via_batched_measuretext`);
a keystroke is `MeasureBatch + SubmitPatch`, independent of the other controls
(`keystroke_crossing_count_is_independent_of_control_count`).

## 7. Invalidation and damage

Two levels, connected by the retained tree:

- **Level 1 — dirty NODES (VBA, source of truth).**
  `OxControlCore.MarkDirty` → `OnControlInvalidated` → `UserForm` collects
  `InvalidatedControls`, **deduplicated by `NodeId`** (a control invalidated by several
  setters in one frame appears once), and a reentrant `SuspendLayout`/`ResumeLayout` band
  coalesces a bulk multi-setter update into one re-emit (while suspended, setters still
  mark dirty but the host is not notified; resume re-derives the set from the dirty
  controls). `UserForm.Render` drains the set into one **incremental** patch per frame —
  Upsert only the invalidated controls; the root + unchanged controls are retained
  (oxforms-rq5.2).
- **Level 2 — dirty RECTS (Rust, derived).** `apply_patch` compares each Upsert's
  `content_hash` to the resident node: equal → no damage; different →
  old ∪ new bounds into `DamageSet`.

Repaint (§16.2) coalesces damage rects, then `render_damage` walks only nodes
intersecting them in z order (overlapping/transparent controls recomposite
correctly). Node tracking gives O(changed) work; rect tracking gives
pixel-accurate recomposition; both are kept. Correctness is guaranteed by
construction and verified by invariant §10b.

*Who* runs the diff above (re-render) versus *who* walks the resident tree to
pixels (repaint), and *when* each fires, is the frame model defined in **§16** —
the two are deliberately different operations with different owners and clocks.

## 8. Text and metrics

Text crosses **by reference, not by per-frame string** (per-frame measurement
over the projection boundary would be the worst crossing-storm).

- Registration: `FontSpec -> FontId`; a string `-> TextRunId` via `MeasureText`,
  which copies the caption (a BSTR borrow valid only for the call — in-process gives
  no marshaling copy, so retaining the pointer would be a use-after-free), shapes it
  **once** into a retained **shaped run** (positioned glyph ids + metrics + a caret
  offset↔x table — the SkTextBlob / cosmic-`Buffer` analog), and returns the id +
  metrics. The `TextRunId` is a **Rust-assigned content hash** (`fnv1a64` over
  `(FontId, size, wrap, text)`); VBA never computes it — it learns the id from
  `MeasureText` and memoizes it by text, so it needs no FNV and re-emits the id (an
  opaque token) with zero crossing on unchanged frames. The cache key
  `(FontId, size, wrap)` deliberately **excludes DPI**: glyph positions are logical
  and scaled affinely at paint, so one run serves every DPI (a future hinted/subpixel
  shaper would add DPI). Cached both VBA-side (the text→id memo) and kernel-side (the
  persistent interning/LRU store, Surface-held; projected per-frame into `Scene.text`).
- Layout consumes the metrics — the per-frame pipeline is **measure → layout → paint**:
  a control that depends on text extent (e.g. MSForms `AutoSize`, word-wrap, autofit)
  reads the measured run (advance + ascent/descent) and computes its own bounds *before*
  emitting geometry, so the face/border/node bounds shrink-wrap the caption and re-fit
  when the text or font size changes. This is what makes the `MeasureText` round-trip
  load-bearing rather than merely plumbed (proven by the AutoSize-hug demo, oxforms-4pn.14).
- Paint: `Prim::DrawText` references `TextRunId` — a color/position change
  re-emits the same run id → zero re-measure, zero re-marshal.
- Caret/selection/scroll: `OxTextService` consumes the shaped run's caret-stop table
  returned by `MeasureBatch`; the PAL-side source of truth remains `caret_x(run, index)` /
  `index_at_x(run, x)` cached on the run. TextBox uses the same service for caret
  placement, drag/mouse hit-testing, selection rectangles, max-scroll calculation, and
  clipped horizontal single-line draw through a text child Scene node.
- **Determinism strategy (the crux):** enforce determinism at the **metrics**
  layer (layout goldens = measured metrics + scene rects, exact across all
  backends) and confine tolerance to the **raster** layer (pinned, hinting-free,
  grayscale-AA reference text path → reproducible `framebuffer_hash`; platform
  backends compared under §10.1/§12 profiles, never required to hash-match). The
  FontId/TextRunId indirection lets a shaping crate slot in later behind the same
  contract.

## 9. Hit-testing and input

Two tiers: the kernel offers an optional pure-geometry
`pick(point) -> NodeId` over node bounds/clip/transform/z (strictly more correct
than a flat control list for scrolled Frames); authoritative routing — capture,
focus/tab, default/cancel, accelerators, the Enter→BeforeUpdate→AfterUpdate→Exit
chain, MultiPage/Frame nesting — stays in the reducer/VBA L1 and raises native
events via `Perform*`/`RaiseEvent` + `OxReturn*`. Hit geometry is structurally
separate from paint. Current reducer **policy** state is the VBA object model
(`OxControlCore`/`OxControlKind`) plus `OxReducer` routing helpers; the Scene remains
the retained render/hit-geometry contract, not the owner of control behavior.

## 10. Determinism and trace/replay

The retained Scene is a serializable persistent value (D11). Canonical form:
children sorted by (z, insert-index); prims in emit order; HashMap materialized as
a sorted Vec for serialize/render; total `NodeId` ordering. Per-node
`content_hash = fnv1a64` (same family as `FRAMEBUFFER_HASH_ALGORITHM`) over
prims + geometry + child hashes; root rolls up to `frame_hash` (used as
`base_hash`). `SCENE_VERSION`/`SCENE_PATCH_VERSION` travel in every payload. Float
geometry is pinned to `COORDINATE_MODEL.md` half-open + floor-left/ceil-right
rounding so goldens don't churn on formatting.

**Keystone invariants (CI'd):**

- **(a) — transitional, RETIRED in oxforms-rq5.1.** This was `flatten(scene) ==
  legacy DisplayList`, byte-for-byte — a *migration* check that the Scene reproduced
  the pre-Scene W002 immediate display list. It existed only while that list did, and
  was deleted with the whole W002 path in §12 step 8 (`flatten`, `DisplayList`,
  `DisplayCommand::FillRect`, `render_headless`, the `w002_rectangle_fixture_*` helpers,
  and `SceneError::FlattenUnsupportedPrim` all gone). It was **never** a permanent
  property — the permanent determinism guarantees are (b)/(c), which are Scene-native.
  The historical W002 framebuffer hash is now pinned by a Scene-native FillRect fixture.
- **(b) — permanent.** `render_damage(region) == render_full restricted to region`,
  pixel-for-pixel (incremental never diverges from canonical).
- **(c) — permanent.** immediate-scene golden == applied-patch-scene golden ==
  framebuffer hash (a retained bug surfaces as a node-level structural diff before
  a pixel diff).

`BeginScene`/`SubmitPatch`/`HitTest` become trace rows alongside the existing
reducer rows; replay reconstructs the scene from patches (applied from
`base_hash`); the per-frame `DamageSet` is an asserted artifact. Differential vs
MSForms: the Scene's own headless reference rasterizer (`render_full` over a
`HeadlessSink`) feeds any pixel/SSIM harness, and because nodes are keyed by
control identity, each node's bounds can be SSIM-compared per-node, localizing
parity failures to a control. (A serializable *flattened* view, if one is ever
needed for trace artifacts, is new work over the full `Prim` vocabulary — not the
retired FillRect-only W002 `DisplayList`.)

## 11. Portability

The scene is pure data + a primitive replay walk, so backends differ only in how
they execute one `Prim` (D8). Each implements the single `PrimSink` trait.
tiny-skia is the headless reference oracle (fixed grayscale AA, deterministic,
owns the canonical `framebuffer_hash`). Direct2D uses DirectWrite + partial
present clipped to damage; Canvas2D maps each Prim 1:1; WebGPU caches per-node
buffers keyed by stable NodeId. The only sanctioned cross-backend divergence is
text AA/subpixel rounding, bounded by §10.1 profiles. DPI is a single root
`Affine`; the scene never bakes pixels.

## 12. Migration (green at every step)

Ordered, each keeping `cargo fmt`/`clippy --all-targets`/`test` green:

1. **DONE.** Added `oxforms_pal::scene` additively (types + serde + `apply_patch`/
   `render_full`/`render_damage`/`pick` + `PrimSink` headless impl). (The transitional
   `flatten` + the `DisplayList`/`render_headless`/`w002` fixture it mirrored have since
   been removed in step 8.)
2. **DONE.** Pinned to the W002 golden: `render_full` of a one-node FillRect scene
   reproduces the historical W002 framebuffer hash (now a Scene-native fixture).
3. **DONE.** Generalized the seam: `OxForms.Surface` projection in the adapter +
   `Variant`↔`ScenePatch` decoder + `NodeId`↔`IOxControl` map. (`SmokeCanvas` ran in
   parallel during the migration and was retired in step 8.)
4. **DONE.** VBA `OxSceneBuilder` + `OxTheme` (classic table) + text-metrics seam +
   `IOxControl.Render` + the `OxControlCore` appearance band; the appearance logic lives
   in VBA Render/theme code.
5. ~~Parity gate: VBA Render → ScenePatch → `render_full` framebuffer hash ==
   `build_probe_display_list` hash for the same FormState.~~ **SUPERSEDED (oxforms-rq5.1).**
   The literal dual-path hash gate became ill-defined once the W007 VBA control model
   diverged from the probe `FormState` model (probe models CheckBox; the VBA control set
   is Label/TextBox/CommandButton, with no `CheckBox.cls`). It is superseded by W007's
   invariant-(c) proof end-to-end across the real VBA↔Rust boundary
   (`oxvba_w007_render_frame`) plus the existing W005/W006 reducer goldens; a Scene-native
   FillRect-subset fixture pins the W002 framebuffer hash. Per owner direction the probe
   path was then deleted directly (delete-first) behind the green floor rather than gated.
6. **DONE (oxforms-rq5.1).** Superseded the probe renderer: deleted
   `build_probe_display_list`/`build_probe_pal_smoke_display_list`/`ProbeDisplayList`/
   `ProbeDisplayCommand`/`ProbeDisplayRole`/`ProbeColor`/`probe_face_color`. **At this
   rq5 step, kept** `ControlNode`/`ControlKind` as reducer policy and
   `hit_test_control_tree` as routing policy; those later moved into the VBA reducer
   model with the `oxforms-core` deletion. The W005/W006 trace-replay goldens were
   regenerated without the render rows.
7. **DONE (oxforms-rq5.2).** Wired incremental invalidation. `UserForm` dedups the
   invalidation set by NodeId and adds a reentrant `SuspendLayout`/`ResumeLayout` band that
   coalesces a bulk multi-setter update into one node per changed control. `Render` now
   emits an INCREMENTAL patch after the first frame — Upsert only the invalidated controls
   against the resident token (root + unchanged controls are omitted → retained by the
   kernel), an unchanged frame does no crossing (no new revision), and a stale base
   self-heals to a full rebuild. Added the invariant-(c) show-hide/shuffle determinism
   golden (incremental omit-and-retain reaches the full-rebuild scene byte-for-byte).
8. **DONE (oxforms-rq5.1, landed together with step 6 per the delete-first direction).**
   Retired the entire pre-Scene W002 immediate path. Relocated the W002 rectangle proof
   as a Scene-native one-node FillRect fixture (and through `OxForms.Surface`), then
   **deleted** `SmokeCanvas`, `DisplayList`, `DisplayCommand::FillRect`,
   `render_headless`/`HeadlessRender`/`RenderDiagnostics`, the `w002_rectangle_fixture_*`
   helpers, `flatten`/`SceneError::FlattenUnsupportedPrim`, and `RenderError`. Invariant
   (a) retired with them. Kept `Color`/`SurfaceSize`/`Rect`/`fnv1a64`/`BYTES_PER_PIXEL`/
   `FRAMEBUFFER_HASH_ALGORITHM` — the Scene rasterizer uses them.
9. **DONE (oxforms-rq5.3).** (a) Crossing-budget P6 gate as a deterministic crossing-count
   test (asserting the exact Surface `calls`): a steady-state one-control change crosses a
   constant set of crossings — one `MeasureText` + one `SubmitPatch` — **independent of
   control count** (the §6 keystroke budget — the rq5.2 payoff). (Hit-testing is reducer-side,
   so there is no `HitTest` crossing to make under drag-capture — that crossing is simply
   unimplemented, not a separately gated property.)
   First paint is `BeginScene + MeasureBatch + SubmitPatch` (constant in control count) since
   **oxforms-98v** batched the measure crossing (§6); a keystroke is `MeasureBatch +
   SubmitPatch`. Both are gated by exact-`calls` tests.
   (b) `render_damage` wired into the present loop: the backend retains the framebuffer and
   repaints only the scene's damage (per damage rect: clear + `render_damage` clipped to that
   rect), full-rendering only on first frame / resize. Pixel-identical to a full repaint
   (invariant (b)), proven headlessly.

Kept at the rq5 step: reducer policy (`ControlNode`/`ControlKind`/routing), `input.rs`
UiEvent, and the shared value types above. Later, the reducer policy moved into
VBA (`OxControlCore`/`OxInteractionManager` behind the `OxReducer` facade) with the `oxforms-core` deletion. Relocated: appearance → VBA theme. Deleted (no
fallback/compat path survives initial development): the probe render code and the whole
W002 immediate display-list path incl. `SmokeCanvas` and `flatten` (both removed in
oxforms-rq5.1). Incremental invalidation landed in rq5.2; incremental-by-default repaint +
the crossing-budget gates in rq5.3. **The rq5 migration is complete.** The first-paint
crossing budget closed in **oxforms-98v** (batched `MeasureBatch`); both the first-paint and
keystroke budgets are now met and gated.

## 13. D7 amendment

**D7 (revised).** Reducer-driven state + a control-agnostic, serializable retained
primitive tree (the **Scene**) rendered with dirty-node invalidation, authored in
immediate mode by VBA. Each VBA control paints itself by emitting a platform-neutral
primitive stream (the §6.2 vocabulary) under a stable, control-derived `NodeId`
into a per-node builder; the Rust kernel retains the emitted primitives as a keyed
arena of control-blind nodes (geometry/transform/clip/z/prims only — never control
types, appearance, or behavior), diffs incoming patches against the resident tree
by `NodeId` + `content_hash` so only changed subtrees cross the VBA↔Rust boundary
and are repainted, and derives dirty-rect damage from the node diff. Authoring is
ALWAYS immediate; retention is a kernel-side storage/diff optimization invisible to
control authors. A full-rebuild patch MUST be byte-identical to the equivalent
immediate display list (`flatten(scene) == legacy list`), and incremental repaint
MUST be pixel-identical to full repaint restricted to the damage region — both are
permanent golden invariants — so retained mode can never silently diverge from the
deterministic canonical path. The retained tree is justified now, not deferred,
because the per-control invalidation signal the reducer and `OxControlCore` already
produce is otherwise discarded at the PAL boundary. Cross-frame batching over
`PortableComProjection` is the dominant cost target; first-paint crossings
independent of control count, one-keystroke crossings independent of other
controls, and zero hit-test crossings under capture are measured P6 acceptance
gates. Backend-native subtree caching and JIT-style render fast paths remain
measured optimizations under §4.6. Pure-immediate full-rebuild remains the default
and the fallback until those invariants and the crossing-budget benchmark justify
enabling incremental patching.

(The clause "retained scene caching is deferred until profiling demands it" is
removed from D7. D1, D3, D10, D11 are unchanged.)

## 14. Open risks

- **Over-invalidation** is a confirmed defect (per-setter `MarkDirty` + no dedup);
  the dedup fix + `content_hash` no-op + Suspend/Resume band must actually land
  and be benchmarked.
- **NodeId stability** is the single point of failure: keys must derive from
  (form_id, control_id, sub_part), never position; held by a shuffle/show-hide
  determinism golden.
- **Text raster determinism**: `HeadlessSink` now draws deterministic text
  placeholders so text primitives affect hashes, but a pinned real-glyph
  reference path (hinting/AA) is still needed before broad pixel text goldens are
  recorded.
- **Patch/base divergence**: `base_hash` + mandatory full-rebuild fallback;
  exercise the `StaleBase` path in CI.
- **VBA-side encoder cost** per frame is VM work the crossing budget doesn't
  price; keep the builder tight, migrate only the encoder under §4.6 if hot.
- **Kernel control-awareness creep**: NodeId stays opaque, prims carry no
  identity; review the kernel for any control vocabulary on every change.
- **Memory growth**: large lists need virtualization (visible-row nodes +
  scroll-as-transform), text-run LRU, bounded arenas — deferred, not forgotten.

## 15. Desktop backend stack (oxforms-4pn.6 decision — revisitable)

The first visible backend (`oxforms-pal-win`, the Windows/desktop target of
oxforms-4pn.6) uses **winit** (window + OS event loop + input) + **softbuffer**
(present a CPU framebuffer into the window) + **tiny-skia** (the `PrimSink`
rasterizer) + **ab_glyph** (glyph rasterization), with OxForms' own simple text
layout (align + basic wrap). Rationale: it is the leanest *capable*, cross-platform
(D8) path; tiny-skia maps 1:1 to the §6.2 `Prim` vocabulary and is the named
reference rasterizer; ab_glyph covers the Latin captions a lightweight
Excel-VBA-forms runtime needs without adopting a full shaping/layout engine. The
headless reference (`HeadlessSink`) stays host-resource-free and owns the golden
`framebuffer_hash`; it draws deterministic text/image placeholders so primitives
cannot disappear from hashes. The visible backend rasterizes real text via
ab_glyph and uses an image placeholder until decoded image pixels land behind
the image service lane (the §8 tolerance layer).

**This is a revisitable decision point, intentionally insulated by existing
contracts so switching cost stays low:**
- Text crosses by `FontId`/`TextRunId` (§8), so **ab_glyph → cosmic-text** (complex
  scripts, font fallback, richer layout) is a contained swap behind the text-metrics
  service — adopt when i18n/shaping fidelity demands it.
- Raster sits behind the `PrimSink` trait (§3), so a **Direct2D/DirectWrite** (best
  Windows text fidelity) or a **pure-Win32 GDI** (closest to true MSForms parity,
  since MSForms *is* GDI) backend can be added per platform without touching controls,
  the runtime, or the reducer.
- The window/present layer (winit + softbuffer) is likewise swappable (e.g. wgpu/
  pixels, or a native Win32 surface) behind the backend's own seam.

Considered and deferred: cosmic-text (heavier than current Latin-caption scope);
Direct2D (Windows-only, diverges from reference-renderer-first); GPU canvases
(non-deterministic across GPUs — bad for goldens, unneeded for forms). Revisit if
text fidelity, i18n, or performance evidence calls for it.

## 16. Render invocation and the frame model (foundational; owning bead `oxforms-4pn.7`, converges with `oxforms-rq5.2`)

Status: design accepted (owner-directed foundation pass). This is the render-side
analogue of the hosting/message-pump care in `LIFECYCLE_PUMP_MODEL.md`: render
invocation is as subtle as pumping, for the same reason — it crosses into a
single-threaded VM — and it is given the same first-class, revisitable treatment as
the §15 backend-stack decision.

### 16.1 Three clocks, kept separate

A correct UI conflates nothing among these; naïve designs fuse them:

1. **Input arrival** — the OS pump delivers an event.
2. **Content change** — VBA mutates a control, so the resident Scene is now stale.
3. **Paint timing** — the platform is ready to put pixels on screen
   (`RedrawRequested`, resize, expose, occlusion).

The retained Scene + `DamageSet` + `RequestRepaint{invalidations}` machinery already
commits OxForms to the **pull/lazy** model (mutations mark dirty; a frame step
re-renders; the platform decides when to paint), not push/eager (re-render+paint at
the point of each mutation). This section makes that explicit so no layer silently
reintroduces push.

### 16.2 The load-bearing distinction: **Repaint ≠ Re-render**

These are two genuinely different operations. Separating them is what lets backends,
platforms, and (later) threads change without touching the VBA control code or the
Rust Scene model.

| | **Repaint** | **Re-render** |
|---|---|---|
| What | resident `Scene` → pixels | VBA paint code → `ScenePatch` → resident `Scene` |
| Enters the VM (VBA)? | **No** — pure Rust | **Yes** — it is a VM entry |
| Owner | the **backend / window** | the **runtime** (the session owner) |
| Trigger | any platform paint signal (`RedrawRequested`, resize, expose, occlusion) | **invalidation** only (content actually changed) |
| Cost / cadence | frequent, cheap | rare, gated, coalesced to ≤1 per frame |
| Crossing | none | the `SubmitPatch` crossing of §6 |

Repaint is `render_full`/`render_damage` over a resident `Scene` snapshot (§3, §7).
Re-render is the `SubmitPatch`/Render crossing of §6/§8. The W002→Scene migration
(§12) and rq5.2 implement the re-render/invalidation half; this section names the
contract they fill in.

### 16.3 Ownership topology

```
   OS pump / paint signals             normalized UiEvents
        (platform)                            │
            │                                 ▼
            ▼                          ┌────────────────────┐
   ┌──────────────────┐  Scene        │      Runtime        │
   │ Backend / Window │  snapshot     │  sole owner of the  │
   │ • owns OS pump   │ ◄──────────── │  session = ALL VBA  │
   │ • owns Repaint   │  (versioned   │  entry: dispatch +  │
   │   (Scene→pixels) │   resident    │  render_frame       │
   │ • platform/      │   Scene)      │ • platform-AGNOSTIC │
   │   backend        │ ────────────► └────────────────────┘
   │   SPECIFIC       │  UiEvents in           │ VM entry
   └──────────────────┘                        ▼
                                      VBA controls (self-render)
```

- **Runtime** = the sole owner of the `ProjectRuntimeSession` and therefore of *all*
  VBA entry: both `dispatch(event)` and `render_frame()`. Platform-agnostic. It is
  the only place that may call into the VM, which is what keeps the single-threaded
  VM re-entrancy-safe (§16.5). It also owns invalidation union (§16.4).
- **Backend / window** = owns the OS message pump, the window lifecycle, and Repaint.
  It reads the resident `Scene` snapshot and walks it to pixels on any paint signal,
  **never touching VBA**. Platform/backend specific (§11, §15).
- **Bootstrap** = a *thin assembler* (the workset's "tiny bootstrap", `oxforms-4pn.7`):
  it constructs a runtime and a backend, wires their two narrow channels (UiEvents in,
  Scene snapshot out), asks the runtime to invoke the VBA startup entrypoint, and runs
  the platform loop. It **neither calls VBA directly (that is the runtime) nor
  rasterizes (that is the backend)**, and holds no control/demo state.

This is a strictly cleaner split than either "the runner gains a render method as a
convenience" or "the bootstrap owns the session": render invocation belongs to the
runtime because re-render *is* a VM entry, and the bootstrap is thinner than both
because it owns neither VBA entry nor paint.

### 16.4 The resident Scene is the one stable seam

The resident `Scene` (held in the adapter's `OxForms.Surface` factory, §6) is the
single architectural hand-off between the two stable halves. The runtime **produces**
monotonically-versioned `Scene` revisions (each successful `SubmitPatch` advances a
revision); the backend **consumes** a read-only snapshot of the latest revision to
paint. Everything meant to stay stable for the long term lives on one side (VBA
controls + the Rust Scene model + the reducer); everything expected to churn lives on
the other (the rasterizer, the windowing/pump, the platform). This seam is what makes
the §11 backends and §15 stack swappable, and it is **forward-compatible with a
render/VM thread split**: producing revisions and consuming snapshots is already the
producer/consumer boundary, so moving paint off the VM thread later needs no change to
VBA or the Scene model. (v1 is single-threaded; the seam is designed not to require it.)

### 16.5 Pull, coalesced, invalidation-driven — and re-entrancy-safe

- **Coarse invalidation is enough.** Because the kernel is retained and diffs by
  `content_hash` (§3, §7), VBA may re-emit liberally — even a whole form — and the
  kernel computes minimal damage. Invalidation therefore only needs to say "this form
  / these controls are dirty"; per-region dirty bookkeeping is not pushed into control
  code. For form-scale scenes this is robust and keeps the VBA control code (the part
  most worth keeping stable) simple.
- **One `render_frame` per frame, max.** Many mutations inside one handler (or one
  `DoEvents` slice) collapse into a single VBA self-render and a single patch. This is
  exactly MSForms `Repaint` / `Suspend`/`Resume` semantics: `SuspendLayout`/
  `ResumeLayout` (§7) gates `render_frame`, it is not a special case.
- **Invalidation has two sources the runtime unions.** Reducer `RequestRepaint`
  effects (structural: focus moved, reducer-owned text) and VBA-side
  `OxControlCore.Dirty`/`MarkDirty` (handler-changed content). The runtime sees both
  and unions them per frame — another reason re-render belongs to the runtime.
- **Re-entrancy safety (the pump analogue).** Re-render is a VM entry, so it obeys the
  same discipline as input dispatch and message pumping (`LIFECYCLE_PUMP_MODEL.md`):
  the VM is never re-entered. `render_frame` runs **between** handler returns at a
  frame boundary, **never synchronously mid-handler** (you let the VM unwind first).
  Conversely, because **Repaint never enters the VM**, the window stays paintable
  during a nested/modal pump or a slow VBA handler — a modal `DoEvents` loop can
  repaint the last good Scene revision even though it must not re-render until the
  current VBA call returns. This is precisely why the split exists, and it is the
  render-side companion to the modal-pump rules in `LIFECYCLE_PUMP_MODEL.md`.
- **The frame clock is event-driven, not a vsync loop.** Forms are not games: after an
  input batch or a timer tick, *if* dirty → `render_frame` → request a repaint
  (`winit ControlFlow::Wait`). Animations/timers schedule a wake via a timer effect;
  there is no busy render loop.

### 16.6 The per-frame loop (normative)

1. Platform pump → backend normalizes OS events → hands `UiEvent`s to the runtime.
2. `runtime.dispatch(event)`: reduce → fire native VBA events → state changes →
   reducer/`Core.Dirty` record invalidations. **Dispatch does not paint and does not
   itself re-render** — it accrues "dirty".
3. If dirty, `runtime.render_frame()`: run VBA self-render for the invalidated nodes
   (coalesced), emit one incremental `ScenePatch` against the resident revision
   (`StaleBase` → full rebuild fallback, §6), advancing the resident `Scene` revision.
4. The backend is handed the new snapshot/revision and schedules a repaint
   (`request_redraw`).
5. On the platform paint signal, the backend Repaints the resident snapshot
   (damage-aware, §7) → pixels → present.
6. Paint signals unrelated to content (resize/expose/occlusion) → the backend Repaints
   the *current* snapshot directly, with **no runtime/VBA involvement**.

### 16.7 Mapping to the current code (and what `4pn.7` lands)

- Repaint already exists: `oxforms-pal-win::run_scene_window` walks the `Scene` it
  holds on each `RedrawRequested` (§15). Under this model the `Scene` it holds is a
  *consumed snapshot*; the smoke binary's direct scene mutation is a stand-in for
  "the runtime produced a new revision" (no VBA in that smoke).
- Re-render is the new seam: the runtime (`OxRuntime`, owner of the session, in
  `crates/oxforms-oxvba-adapter/src/runtime.rs`) drives the VBA self-render through its
  `render()` entrypoint — the coalesced VBA self-render → `SubmitPatch` → resident-revision
  advance. (`4pn.7`/rq5.2 are the historical beads that landed the seam against the then
  `RuntimeRunner`; in the VBA-reducer pivot the Rust reducer was deleted and the runtime is
  now the thin `OxRuntime`, whose `render()` invokes the form-document's VBA `Render` over
  `OxForms.Surface`.) This is the home of rq5.2's per-frame `SubmitPatch` + `MarkDirty` dedup +
  `Suspend`/`Resume` band. Re-render introduces **nothing eager/push**; even where the first
  cut coalesces trivially, Repaint and Re-render stay distinct.
- `OxForms.Surface` (the adapter resident-Scene holder, §6) gains a monotonic
  **revision** + a cheap read-only **snapshot** accessor so the backend consumes a
  stable revision rather than a live-mutating scene.

### 16.8 Revisitability

Like §15, this is an intentionally insulated decision. The contracts that hold it
together — `UiEvent` in, the resident `Scene` snapshot out, `SubmitPatch`/`render_full`
as the only Re-render/Repaint primitives — mean the frame model can later become
multi-threaded (render thread reads snapshots), remote/headless (snapshots serialized
to a viewer), or differently-clocked (vsync/compositor-driven) **without** changing
VBA control code or the Scene model. Revisit if threading, remoting, or animation
cadence evidence calls for it.
