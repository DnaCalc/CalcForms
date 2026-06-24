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
`IOxControlHost.OnControlInvalidated` → `OxUserForm.InvalidatedControls`, and the
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
    #[serde(skip)] pub damage: DamageSet,
    #[serde(skip)] pub text: TextRunCache,
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
  `Retain` costs nothing. Bounds-checked decode fails deterministically like
  `render_headless`'s `SurfaceTooLarge` guards.
- `render_full(&Scene, &mut dyn PrimSink)` — walks nodes in (parent, z, insert)
  order applying transform/clip, replaying prims. `render_headless` generalized
  from FillRect to the full vocabulary; the deterministic golden path.
- `render_damage(&Scene, &mut dyn PrimSink, &DamageSet)` — clips the walk to nodes
  intersecting coalesced damage rects, z-aware so overlaps/transparent controls
  recomposite correctly.
- `flatten(&Scene) -> DisplayList` — depth-first walk producing the legacy
  immediate list, so existing W002/golden infra and the immediate fallback keep
  working (invariant §10a).
- `pick(&[HitNode], PointF) -> Option<NodeId>` — pure-geometry topmost-by-(z,order)
  respecting clip/transform.

Backends implement one trait, `PrimSink` (push/pop clip + transform; fill/stroke
rect; round_rect; ellipse; line; polygon; gradient; draw_text; draw_image;
draw_edge). tiny-skia is the headless reference oracle; Direct2D/Canvas2D/WebGPU
are thin walkers. The scene types live in `oxforms-pal`; the `Variant`↔`ScenePatch`
marshalling and `NodeId`↔`IOxControl` map live in `oxforms-oxvba-adapter`.

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
`build_probe_display_list`): an **`OxTheme`** data table maps
(logical role × SpecialEffect × BorderStyle × state {normal,pressed,disabled,focused})
→ resolved Paint/Stroke/EdgeEffect/light+shadow colors. "Classic MSForms" is the
default table; alternate themes are just different data, touching no kernel and no
control code. `OLE_COLOR` with the `0x80000000` high bit resolves through a PAL
service `Surface.ResolveSysColor(oleColor) -> RGBA`: VBA decides *which* system
color; the platform resolves the *value*.

### The "add a control" recipe

1. New `OxFoo.cls` `Implements IOxControl`, holding an `OxControlCore` for
   geometry/flags/appearance/NodeId.
2. Set its default `SpecialEffect`/`BorderStyle` in `Class_Initialize`.
3. Implement `Render`: open node → ask `OxTheme` for the role's resolved
   primitives → emit them → close node. Give any high-frequency / independently
   damaged element (caret, focus rect, checkbox glyph) its **own sub-part NodeId**
   so a caret blink re-emits one tiny node.
4. Implement the native event surface (`PerformClick`/`ApplyUserText`/… →
   `RaiseEvent`; ByRef cancel via `OxReturnInteger`/`OxReturnBoolean`).
5. Register a theme row for its role.

No Rust change. No new primitive. The kernel never learns the word "Foo".

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
- `MeasureText(batch) -> metrics[] + TextRunId[]` — one batched call for runs
  needing (re)measurement; cached both sides, so steady-state frames need zero
  text crossings.
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
migrates to Rust under §4.6 — the contract is unchanged.

## 7. Invalidation and damage

Two levels, connected by the retained tree:

- **Level 1 — dirty NODES (VBA, source of truth, exists today).**
  `OxControlCore.MarkDirty` → `OnControlInvalidated` → `OxUserForm` collects
  `InvalidatedControls`. **Confirmed defect fix:** the runtime drains this set
  with per-frame **deduplication**; `OxUserForm` dedups at `Add` time; a
  `SuspendLayout`/`ResumeLayout` band coalesces multi-setter updates into one
  re-emit. (Today `MarkDirty` fires per setter and `mInvalidated.Add` never
  dedups, so a multi-setter update lists a control repeatedly.)
- **Level 2 — dirty RECTS (Rust, derived).** `apply_patch` compares each Upsert's
  `content_hash` to the resident node: equal → no damage; different →
  old ∪ new bounds into `DamageSet`.

`present()` coalesces damage rects, then `render_damage` walks only nodes
intersecting them in z order (overlapping/transparent controls recomposite
correctly). Node tracking gives O(changed) work; rect tracking gives
pixel-accurate recomposition; both are kept. Correctness is guaranteed by
construction and verified by invariant §10b.

## 8. Text and metrics

Text crosses **by reference, not by per-frame string** (per-frame measurement
over the projection boundary would be the worst crossing-storm).

- Registration: `FontSpec -> FontId`; a measured string `-> TextRunId` via batched
  `MeasureText` returning advance widths, ascent/descent/line-height, wrap break
  offsets, and a caret offset↔x table. Cache key `(FontId, text, wrap-width, dpi)`
  per `COORDINATE_MODEL.md` rounding; cached both VBA-side (typing TextBox
  re-measures only the edited line) and kernel-side (LRU).
- Paint: `Prim::DrawText` references `TextRunId` — a color/position change
  re-emits the same run id → zero re-measure, zero re-marshal.
- Caret/selection: replace `probe.rs`'s approximate `6.0`px cell with PAL
  `caret_x(run, index)` / `index_at_x(run, x)` cached on the run.
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
separate from paint. `ControlNode`/`ControlKind`/`hit_test_control_tree` remain
legitimate reducer **policy** state — they are not rendering.

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

- **(a) — transitional, retires in §12 step 8.** `flatten(scene) == legacy
  DisplayList`, byte-for-byte (full re-emit degenerates to the immediate path).
  This is a *migration* check that the Scene reproduces the pre-Scene W002
  immediate display list; it exists only while that list does. It is deleted
  together with the W002 path in step 8 (`flatten`, `DisplayList`,
  `DisplayCommand::FillRect`, `render_headless`, the `w002_rectangle_fixture_*`
  helpers, and `SceneError::FlattenUnsupportedPrim` all go). It is **not** a
  permanent property — the permanent determinism guarantee is (c), which is
  Scene-native and needs no DisplayList.
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

1. Add `oxforms_pal::scene` additively (types + serde + `apply_patch`/`render_full`/
   `render_damage`/`flatten`/`pick` + `PrimSink` headless impl). Leave
   `DisplayList`/`FillRect`/`render_headless`/`w002` fixture untouched. **← this bead.**
2. Pin to the W002 golden: `render_full` of a one-node FillRect scene reproduces
   `w002_rectangle_fixture_diagnostics`; `flatten` == the W002 display list. **← this bead.**
3. Generalize the seam: `OxForms.Surface` projection in the adapter +
   `Variant`↔`ScenePatch` decoder + `NodeId`↔`IOxControl` map; keep `SmokeCanvas`
   registered in parallel (quarantined per CHARTER §3.1).
4. VBA `OxSceneBuilder` + `OxTheme` (classic table) + `OxTextMetricsCache` +
   `IOxControl.Render` + the `OxControlCore` appearance band; port `probe.rs`
   appearance logic into VBA Render/theme code.
5. Parity gate: VBA Render → ScenePatch → `render_full` framebuffer hash ==
   `build_probe_display_list` hash for the same FormState. Delete nothing yet.
6. Supersede: delete `build_probe_display_list`/`ProbeDisplayCommand`/
   `ProbeDisplayRole`/`probe_face_color`. **Keep** `ControlNode`/`ControlKind` as
   reducer policy and `hit_test_control_tree` as routing policy.
7. Wire invalidation (dedup fix + Suspend/Resume + per-frame SubmitPatch); add
   invariant (c) + the shuffle/show-hide determinism golden.
8. Retire the entire pre-Scene W002 immediate path now that nothing consumes it
   (the probe smoke went in step 6; the visible/`SmokeCanvas` smokes go here).
   Relocate the W002 rectangle proof as a one-node `ScenePatch` through
   `OxForms.Surface`, then **delete** `SmokeCanvas`, `DisplayList`,
   `DisplayCommand::FillRect`, `render_headless`/`HeadlessRender`/`RenderDiagnostics`,
   the `w002_rectangle_fixture_*` helpers, `flatten`/`SceneError::FlattenUnsupportedPrim`,
   and any error type left unused (`RenderError`). Invariant (a) retires with them.
   Keep `Color`/`SurfaceSize`/`Rect`/`fnv1a64`/`BYTES_PER_PIXEL`/
   `FRAMEBUFFER_HASH_ALGORITHM` — the Scene rasterizer uses them.
9. Record crossing-budget benchmark traces as P6 gates; enable incremental-by-default
   behind the invariants + budget.

Kept: reducer policy (`ControlNode`/`ControlKind`/routing), `input.rs` UiEvent, and
the shared value types above. Relocated: appearance → VBA theme. Deleted (no
fallback/compat path survives initial development): the probe render code (step 6),
and the whole W002 immediate display-list path incl. `SmokeCanvas` and `flatten`
(step 8).

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
- **Text raster determinism**: the headless reference text path must be pinned
  (hinting/AA) before broad text goldens are recorded.
- **Patch/base divergence**: `base_hash` + mandatory full-rebuild fallback;
  exercise the `StaleBase` path in CI.
- **VBA-side encoder cost** per frame is VM work the crossing budget doesn't
  price; keep the builder tight, migrate only the encoder under §4.6 if hot.
- **Kernel control-awareness creep**: NodeId stays opaque, prims carry no
  identity; review the kernel for any control vocabulary on every change.
- **Memory growth**: large lists need virtualization (visible-row nodes +
  scroll-as-transform), text-run LRU, bounded arenas — deferred, not forgotten.
