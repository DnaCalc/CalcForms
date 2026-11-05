//! The Scene: a control-agnostic, serializable, retained primitive tree.
//!
//! VBA controls paint themselves in immediate mode by emitting the §6.2 primitive
//! vocabulary under a stable [`NodeId`]; this kernel retains those primitives as a
//! keyed arena it diffs to repaint minimally. The kernel knows pixels, geometry,
//! color, glyphs, clips, transforms — never "TextBox"/"Label". See
//! `docs/specs/RENDERING_ARCHITECTURE.md`.
//!
//! Invariants this module upholds (and tests assert):
//! - `render_damage(full surface)` is pixel-identical to `render_full` (permanent);
//! - a one-node FillRect scene reproduces the historical W002 framebuffer hash
//!   (a Scene-native fixture; the pre-Scene immediate `DisplayList` path and its
//!   transitional `flatten` check — RENDERING_ARCHITECTURE.md §12 step 8 — were removed
//!   in bead `oxforms-rq5.1`).

use std::collections::{BTreeMap, HashSet};

use serde::{Deserialize, Serialize};

use crate::input::DpiScale;
use crate::{fnv1a64, Color, Rect, SurfaceSize, BYTES_PER_PIXEL, FRAMEBUFFER_HASH_ALGORITHM};

/// Scene wire/storage schema version.
pub const SCENE_VERSION: u16 = 1;
/// Scene patch wire schema version.
pub const SCENE_PATCH_VERSION: u16 = 1;

/// Opaque, stable per-node identity. VBA interns it from
/// `(form_id, control_id, sub_part_tag)`. The kernel never interprets it beyond
/// `Eq`/`Hash`/`Ord`.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash, Ord, PartialOrd, Serialize, Deserialize)]
pub struct NodeId(pub u64);

/// Logical-coordinate rectangle (points). The kernel never bakes pixels.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct RectF {
    pub x: f32,
    pub y: f32,
    pub w: f32,
    pub h: f32,
}

impl RectF {
    #[must_use]
    pub const fn new(x: f32, y: f32, w: f32, h: f32) -> Self {
        Self { x, y, w, h }
    }

    #[must_use]
    pub fn intersect(self, other: RectF) -> RectF {
        let x = self.x.max(other.x);
        let y = self.y.max(other.y);
        let right = (self.x + self.w).min(other.x + other.w);
        let bottom = (self.y + self.h).min(other.y + other.h);
        RectF::new(x, y, (right - x).max(0.0), (bottom - y).max(0.0))
    }

    #[must_use]
    pub fn intersects(self, other: RectF) -> bool {
        self.x < other.x + other.w
            && other.x < self.x + self.w
            && self.y < other.y + other.h
            && other.y < self.y + self.h
    }

    #[must_use]
    pub fn contains(self, p: PointF) -> bool {
        p.x >= self.x && p.y >= self.y && p.x < self.x + self.w && p.y < self.y + self.h
    }

    #[must_use]
    pub fn is_empty(self) -> bool {
        self.w <= 0.0 || self.h <= 0.0
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct PointF {
    pub x: f32,
    pub y: f32,
}

impl PointF {
    #[must_use]
    pub const fn new(x: f32, y: f32) -> Self {
        Self { x, y }
    }
}

/// Translate + uniform scale only for v1 (covers DPI, scroll, control offset).
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct Affine {
    pub sx: f32,
    pub sy: f32,
    pub tx: f32,
    pub ty: f32,
}

impl Affine {
    pub const IDENTITY: Affine = Affine {
        sx: 1.0,
        sy: 1.0,
        tx: 0.0,
        ty: 0.0,
    };

    #[must_use]
    pub const fn translate(tx: f32, ty: f32) -> Self {
        Self {
            sx: 1.0,
            sy: 1.0,
            tx,
            ty,
        }
    }

    /// `self` ∘ `inner`: apply `inner` first (a node's own transform), then `self`
    /// (its accumulated ancestor transform).
    #[must_use]
    pub fn compose(self, inner: Affine) -> Affine {
        Affine {
            sx: self.sx * inner.sx,
            sy: self.sy * inner.sy,
            tx: self.sx * inner.tx + self.tx,
            ty: self.sy * inner.ty + self.ty,
        }
    }

    #[must_use]
    pub fn apply_rect(self, r: RectF) -> RectF {
        RectF::new(
            r.x * self.sx + self.tx,
            r.y * self.sy + self.ty,
            r.w * self.sx,
            r.h * self.sy,
        )
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum Paint {
    Solid(Color),
    LinearGradient {
        stops: Vec<(f32, Color)>,
        angle: f32,
    },
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Stroke {
    pub paint: Paint,
    pub width: f32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TextAlign {
    Left,
    Center,
    Right,
}

/// Text rendering flags (accelerator underline, disabled state). Kept as data so
/// the kernel never decides control state.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct TextFlags {
    pub underline_accelerator: bool,
    pub disabled: bool,
}

/// Opaque handle to a font registered with the kernel text service.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash, Serialize, Deserialize)]
pub struct FontId(pub u64);

/// Opaque handle to a measured text run (see the text-metrics service). Paint
/// references runs, never raw strings, so a recolor/reposition re-measures nothing.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash, Serialize, Deserialize)]
pub struct TextRunId(pub u64);

/// Opaque handle to a decoded image.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash, Serialize, Deserialize)]
pub struct ImageHandle(pub u64);

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ImageMode {
    Stretch,
    Clip,
    Zoom,
    Tile,
}

/// Generic 3D edge style (GDI `BDR_*`-flavored). MSForms `SpecialEffect` maps onto
/// this in VBA theme code; the kernel just draws the edge.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EdgeEffect {
    Flat,
    Raised,
    Sunken,
    Etched,
    Bump,
}

/// Which edges of the rect the edge effect draws.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct EdgeBorder {
    pub left: bool,
    pub top: bool,
    pub right: bool,
    pub bottom: bool,
}

impl EdgeBorder {
    pub const ALL: EdgeBorder = EdgeBorder {
        left: true,
        top: true,
        right: true,
        bottom: true,
    };
}

// ── Text-metrics seam: the retained shaped run (RENDERING_ARCHITECTURE.md §8) ──
//
// Following every retained-mode stack (SkTextBlob / IDWriteTextLayout / cosmic
// `Buffer` / cc `DrawTextBlobOp`), text is retained as a *shaped run* — positioned
// glyphs + a metrics block — never the raw string as a draw payload. A
// [`TextShaper`] produces a [`TextRun`] once per content change; the visible
// backend blits the glyphs (scaled to device) on every VM-free repaint without
// re-shaping. All geometry here is in logical points; the renderer applies the
// device scale. The string is retained only as side-metadata (caret/a11y/re-shape).

/// One positioned glyph within a shaped run, in logical (point) units. The renderer
/// scales position + em to device pixels at paint time; shaping is never repeated.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct PositionedGlyph {
    /// Font-specific glyph index (valid against the run's [`FontId`]).
    pub glyph_id: u16,
    pub x: f32,
    pub y: f32,
}

/// Metrics of a shaped run, in logical points. This is the deterministic seam
/// (§8): VBA layout (AutoSize/wrap) consumes these exactly; only the raster layer
/// carries tolerance. `ascent`/`descent` are positive distances from the baseline.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct RunMetrics {
    /// Total pen advance (the run's logical width).
    pub advance: f32,
    /// Distance above the baseline (positive).
    pub ascent: f32,
    /// Distance below the baseline (positive).
    pub descent: f32,
    /// Extra leading between lines (positive).
    pub line_gap: f32,
}

impl RunMetrics {
    /// `ascent + descent + line_gap`.
    #[must_use]
    pub fn line_height(&self) -> f32 {
        self.ascent + self.descent + self.line_gap
    }
}

/// Caret x-stops in logical points: `stops[i]` is the caret x before caret stop `i`,
/// `stops.len() == stops_produced + 1` (last entry = run end). The granularity of a
/// "stop" is the shaper's contract: [`StubShaper`] (and the v1 ab_glyph shaper) emit
/// one stop per `char` (Unicode scalar); grapheme-cluster carets are a real-shaper
/// concern for later (cosmic-text). Supersedes the fixed 6px cell in `calcforms-core`
/// `controls.rs`; wired to TextBox caret work later.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct CaretTable {
    pub stops: Vec<f32>,
}

/// The style identity of a text run (everything but the text itself). The
/// [`TextRunId`] is the content hash of `(this, text)`, so identical runs collapse
/// to one id automatically. Sizes are in 1/1000 pt to be locale/float-stable.
///
/// DPI/device scale is deliberately **not** part of the key: glyph positions are
/// logical and the renderer applies the device scale affinely at paint, so one run
/// serves every DPI. (A future hinted/subpixel shaper that bakes DPI into shaping
/// would add it here.)
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct TextKey {
    pub font: FontId,
    pub size_milli_pt: u32,
    /// Wrap width in 1/1000 pt; `None` = single line / no wrap.
    pub wrap_width_milli_pt: Option<u32>,
    /// Explicit display-character index to underline. Text itself is always literal.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub accelerator_index: Option<u32>,
}

/// A shaped, retained text run — the SkTextBlob / cosmic-`Buffer` analog (glyph-run
/// tier). Produced once on change by a [`TextShaper`]; the renderer blits its glyphs
/// every repaint without re-shaping. Logical (point) units throughout.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct TextRun {
    /// Content-hash id ([`text_run_id`]); the kernel store keys on `id.0`.
    pub id: TextRunId,
    pub key: TextKey,
    pub glyphs: Vec<PositionedGlyph>,
    pub metrics: RunMetrics,
    pub caret: CaretTable,
    /// Explicit accelerator index, underlined when `DrawText` requests it.
    /// `None` = no accelerator. v1 assumes
    /// 1:1 char↔glyph, so this is also the display-char index.
    pub accelerator: Option<usize>,
    /// Literal display string, retained for re-shape
    /// (DPI/size change) and caret/a11y only — never the draw payload (the glyphs are).
    /// Owned: the shaper copies on register.
    pub source: Box<str>,
}

impl TextRun {
    /// Logical x of the caret before caret stop `index` (`None` past the end). Stop
    /// granularity is the shaper's contract (one per `char` in v1; see [`CaretTable`]).
    #[must_use]
    pub fn caret_x(&self, index: usize) -> Option<f32> {
        self.caret.stops.get(index).copied()
    }

    /// Caret stop nearest the logical x `x` (for hit-testing a click to a caret
    /// position). Returns `0` for an empty run.
    #[must_use]
    pub fn index_at_x(&self, x: f32) -> usize {
        let mut best = 0usize;
        let mut best_d = f32::INFINITY;
        for (i, &stop) in self.caret.stops.iter().enumerate() {
            let d = (stop - x).abs();
            if d < best_d {
                best_d = d;
                best = i;
            }
        }
        best
    }
}

/// Content-hash id for a text run, assigned **Rust-side** (the same `fnv1a64` family
/// as the framebuffer/content hashes) over `(font, size, wrap, text)`.
///
/// The id is computed by whoever registers a run (the Surface `MeasureText` handler,
/// or canonical test scenes), never by VBA: VBA learns the id from the `MeasureText`
/// round-trip and memoizes it by text, so it needs no FNV implementation and the id
/// is an opaque token it just echoes in the patch (held as a decimal/string, not a
/// signed `Long`). Being content-derived, it gives automatic de-dup and a
/// deterministic frame token across runs. 64-bit makes a collision between two live
/// runs astronomically unlikely; the residual is documented on [`Scene::text`] and
/// guarded by [`Scene::upsert_text_run`].
///
/// Encoding (little-endian): font `u64`, size `u32`, a flags byte (bit 0 = wrap
/// width present, bit 1 = explicit accelerator index present), then each present
/// width/index as `u32`, then the literal UTF-8 text. Unadorned run ids retain
/// their existing encoding; explicit underline indices cannot alias that domain.
#[must_use]
pub fn text_run_id(key: &TextKey, text: &str) -> TextRunId {
    let mut buf: Vec<u8> = Vec::new();
    buf.extend_from_slice(&key.font.0.to_le_bytes());
    buf.extend_from_slice(&key.size_milli_pt.to_le_bytes());
    let accelerator_flag = if key.accelerator_index.is_some() {
        2
    } else {
        0
    };
    match key.wrap_width_milli_pt {
        None => buf.push(accelerator_flag),
        Some(w) => {
            buf.push(accelerator_flag | 1);
            buf.extend_from_slice(&w.to_le_bytes());
        }
    }
    if let Some(index) = key.accelerator_index {
        buf.extend_from_slice(&index.to_le_bytes());
    }
    buf.extend_from_slice(text.as_bytes());
    TextRunId(fnv1a64(&buf))
}

/// Shapes a string into a retained [`TextRun`]. The backend owns the font engine
/// (ab_glyph now, cosmic-text later) and implements this; the kernel/adapter only
/// hold the resulting runs. Pure + deterministic for a given font set, called once
/// per content change — never at paint time. `Debug` is required so holders (e.g. the
/// adapter's `SurfaceFactory`) can derive it.
pub trait TextShaper: std::fmt::Debug {
    fn shape(&self, key: &TextKey, text: &str) -> TextRun;
}

/// A deterministic, font-free shaper for tests and headless determinism: each char
/// advances half the em, `glyph_id` = the char's low 16 bits, ascent/descent are
/// fixed fractions. Exact metrics let adapter tests assert without a font file.
#[derive(Clone, Copy, Debug, Default)]
pub struct StubShaper;

impl TextShaper for StubShaper {
    fn shape(&self, key: &TextKey, text: &str) -> TextRun {
        let display = text;
        let accelerator = key
            .accelerator_index
            .map(|index| index as usize)
            .filter(|index| *index < display.chars().count());
        let em = key.size_milli_pt as f32 / 1000.0;
        let advance_per = em * 0.5;
        let mut glyphs = Vec::new();
        let mut stops = vec![0.0_f32];
        let mut pen = 0.0_f32;
        for ch in display.chars() {
            glyphs.push(PositionedGlyph {
                glyph_id: ch as u32 as u16,
                x: pen,
                y: 0.0,
            });
            pen += advance_per;
            stops.push(pen);
        }
        TextRun {
            id: text_run_id(key, text),
            key: key.clone(),
            glyphs,
            metrics: RunMetrics {
                advance: pen,
                ascent: em * 0.8,
                descent: em * 0.2,
                line_gap: 0.0,
            },
            caret: CaretTable { stops },
            accelerator,
            source: display.into(),
        }
    }
}

/// Exactly the spec §6.2 vocabulary. No control words. Transform/clip live on the
/// node, so the prim stream is purely geometric paint.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "op", rename_all = "snake_case")]
pub enum Prim {
    FillRect {
        rect: RectF,
        paint: Paint,
    },
    StrokeRect {
        rect: RectF,
        stroke: Stroke,
    },
    RoundRect {
        rect: RectF,
        radius: f32,
        fill: Option<Paint>,
        stroke: Option<Stroke>,
    },
    Ellipse {
        rect: RectF,
        fill: Option<Paint>,
        stroke: Option<Stroke>,
    },
    Line {
        a: PointF,
        b: PointF,
        stroke: Stroke,
    },
    Polygon {
        pts: Vec<PointF>,
        fill: Option<Paint>,
        stroke: Option<Stroke>,
    },
    Gradient {
        rect: RectF,
        stops: Vec<(f32, Color)>,
        angle: f32,
    },
    DrawText {
        run: TextRunId,
        rect: RectF,
        align: TextAlign,
        wrap: bool,
        clip: bool,
        paint: Paint,
        flags: TextFlags,
    },
    DrawImage {
        image: ImageHandle,
        src: RectF,
        dst: RectF,
        mode: ImageMode,
    },
    DrawEdge {
        rect: RectF,
        effect: EdgeEffect,
        border: EdgeBorder,
        light: Color,
        shadow: Color,
    },
}

/// One retained node. Children are referenced by key (paint order), so a subtree
/// move is a key edit.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SceneNode {
    pub id: NodeId,
    pub parent: Option<NodeId>,
    pub z: i32,
    pub transform: Affine,
    pub clip: Option<RectF>,
    /// Self bounds in parent space (damage + pick).
    pub bounds: RectF,
    pub visible: bool,
    pub prims: Vec<Prim>,
    /// Resolved (z, insert) paint order.
    pub children: Vec<NodeId>,
}

impl SceneNode {
    #[must_use]
    pub fn new(id: NodeId) -> Self {
        Self {
            id,
            parent: None,
            z: 0,
            transform: Affine::IDENTITY,
            clip: None,
            bounds: RectF::new(0.0, 0.0, 0.0, 0.0),
            visible: true,
            prims: Vec::new(),
            children: Vec::new(),
        }
    }

    /// Deterministic content hash over everything that affects paint/damage,
    /// excluding identity. Same FNV family as the framebuffer hash.
    #[must_use]
    pub fn content_hash(&self) -> u64 {
        let mut h = ContentHasher::new();
        h.u8(u8::from(self.visible));
        h.i32(self.z);
        h.affine(self.transform);
        match self.clip {
            Some(c) => {
                h.u8(1);
                h.rect(c);
            }
            None => h.u8(0),
        }
        h.rect(self.bounds);
        h.u32(self.prims.len() as u32);
        for prim in &self.prims {
            h.prim(prim);
        }
        h.u32(self.children.len() as u32);
        for child in &self.children {
            h.u64(child.0);
        }
        h.finish()
    }
}

/// The canonical retained representation: a node arena kept sorted by `NodeId` for
/// deterministic serialization and O(log n) lookup. Paint order is via `children`.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Scene {
    pub version: u16,
    pub surface: SurfaceSize,
    pub dpi: DpiScale,
    pub root: NodeId,
    /// Sorted by `NodeId` (canonical). Use [`Scene::get`] for lookup.
    pub nodes: Vec<SceneNode>,
    /// Resident shaped-run store, keyed by [`TextRunId`]`.0`. A `DrawText` prim
    /// references a run here; the backend resolves + blits it on repaint with no
    /// re-shaping. Populated Rust-side (the adapter projects measured runs in), not
    /// carried in a [`ScenePatch`].
    ///
    /// Deliberately excluded from `frame_hash` (see [`Scene::recompute_frame_hash`]):
    /// a content-derived [`text_run_id`] moves whenever the text changes, so the
    /// `DrawText` prim's `run.0` (which *is* hashed) already reflects the change. This
    /// is sound while ids are unique across the live working set. The residual: a
    /// 64-bit hash collision between two distinct live runs would map both to one
    /// store entry and (because only `run.0` is hashed) suppress the token bump for
    /// the second — a missed repaint, not benign de-dup. At 64 bits this is
    /// astronomically unlikely; [`Scene::upsert_text_run`] debug-asserts against the
    /// silent-overwrite case so any collision surfaces in tests rather than on screen.
    #[serde(default)]
    pub text: BTreeMap<u64, TextRun>,
    #[serde(skip)]
    pub damage: DamageSet,
    #[serde(skip)]
    pub frame_hash: u64,
}

impl Scene {
    #[must_use]
    pub fn new(surface: SurfaceSize, dpi: DpiScale, root: NodeId) -> Self {
        let mut scene = Self {
            version: SCENE_VERSION,
            surface,
            dpi,
            root,
            nodes: Vec::new(),
            text: BTreeMap::new(),
            damage: DamageSet::default(),
            frame_hash: 0,
        };
        scene.recompute_frame_hash();
        scene
    }

    /// Insert or replace a shaped run by its content-hash id. Idempotent: re-inserting
    /// the same content is a no-op-equivalent (identical id → identical run, since the
    /// shaper is deterministic). In debug builds, asserts that an existing entry under
    /// the same id is content-equal — so a [`text_run_id`] collision between two
    /// distinct live runs (which would otherwise silently overwrite and miss a
    /// repaint, see [`Scene::text`]) fails loudly in tests rather than on screen.
    pub fn upsert_text_run(&mut self, run: TextRun) {
        debug_assert!(
            self.text
                .get(&run.id.0)
                .is_none_or(|existing| *existing == run),
            "text_run_id collision: id {:#x} maps to two distinct runs ({:?} vs {:?})",
            run.id.0,
            self.text.get(&run.id.0).map(|r| &r.source),
            run.source,
        );
        self.text.insert(run.id.0, run);
    }

    /// Resolve a `DrawText` prim's run handle to its retained shaped run.
    #[must_use]
    pub fn text_run(&self, id: TextRunId) -> Option<&TextRun> {
        self.text.get(&id.0)
    }

    #[must_use]
    pub fn get(&self, id: NodeId) -> Option<&SceneNode> {
        self.index_of(id).map(|i| &self.nodes[i])
    }

    fn index_of(&self, id: NodeId) -> Option<usize> {
        self.nodes.binary_search_by_key(&id, |n| n.id).ok()
    }

    fn upsert_node(&mut self, node: SceneNode) {
        match self.nodes.binary_search_by_key(&node.id, |n| n.id) {
            Ok(i) => self.nodes[i] = node,
            Err(i) => self.nodes.insert(i, node),
        }
    }

    fn remove_node(&mut self, id: NodeId) -> Option<SceneNode> {
        self.index_of(id).map(|i| self.nodes.remove(i))
    }

    /// Rolled-up content hash used as the patch `base_hash`. Order-independent of
    /// arena layout because nodes are visited in `NodeId` order.
    pub fn recompute_frame_hash(&mut self) {
        let mut h = ContentHasher::new();
        h.u32(self.nodes.len() as u32);
        for node in &self.nodes {
            h.u64(node.id.0);
            h.u64(node.content_hash());
        }
        self.frame_hash = h.finish();
    }

    /// Absolute (surface-space) transform accumulated from the root to `id`.
    #[must_use]
    pub fn absolute_transform(&self, id: NodeId) -> Affine {
        let mut chain = Vec::new();
        let mut cur = Some(id);
        while let Some(node_id) = cur {
            let Some(node) = self.get(node_id) else { break };
            chain.push(node.transform);
            cur = node.parent;
        }
        let mut xf = Affine::IDENTITY;
        for t in chain.into_iter().rev() {
            xf = xf.compose(t);
        }
        xf
    }

    /// Apply a batched patch. Returns the damage produced, or [`SceneError::StaleBase`]
    /// (the runtime then resubmits a full rebuild). Content-equal upserts are no-ops,
    /// which absorbs over-invalidation.
    pub fn apply_patch(&mut self, patch: &ScenePatch) -> Result<DamageSet, SceneError> {
        if patch.version != SCENE_PATCH_VERSION {
            return Err(SceneError::UnsupportedVersion {
                actual: patch.version,
                expected: SCENE_PATCH_VERSION,
            });
        }
        if patch.base_hash != self.frame_hash {
            return Err(SceneError::StaleBase {
                expected: self.frame_hash,
                actual: patch.base_hash,
            });
        }

        self.surface = patch.surface;
        self.dpi = patch.dpi;
        let mut damage = DamageSet::default();

        for edit in &patch.edits {
            match edit {
                NodeEdit::Retain(_) => {}
                NodeEdit::Upsert(node) => {
                    let incoming_hash = node.content_hash();
                    let unchanged = self
                        .get(node.id)
                        .is_some_and(|existing| existing.content_hash() == incoming_hash);
                    if unchanged {
                        continue;
                    }
                    if let Some(existing) = self.get(node.id) {
                        damage.add(
                            existing.id,
                            self.absolute_transform(existing.id)
                                .apply_rect(existing.bounds),
                        );
                    }
                    let id = node.id;
                    self.upsert_node(node.clone());
                    damage.add(id, self.absolute_transform(id).apply_rect(node.bounds));
                }
                NodeEdit::Remove(id) => {
                    if let Some(removed) = self.remove_node(*id) {
                        damage.add(*id, self.absolute_transform(*id).apply_rect(removed.bounds));
                    }
                }
                NodeEdit::Reorder { id, z, parent } => {
                    if let Some(i) = self.index_of(*id) {
                        let before = self
                            .absolute_transform(*id)
                            .apply_rect(self.nodes[i].bounds);
                        self.nodes[i].z = *z;
                        self.nodes[i].parent = *parent;
                        let after = self
                            .absolute_transform(*id)
                            .apply_rect(self.nodes[i].bounds);
                        damage.add(*id, before);
                        damage.add(*id, after);
                    }
                }
            }
        }

        self.recompute_frame_hash();
        self.damage = damage.clone();
        Ok(damage)
    }
}

/// Damage accrued by a patch: dirty node ids plus the surface-space rects to
/// recomposite.
#[derive(Clone, Debug, Default)]
pub struct DamageSet {
    pub rects: Vec<RectF>,
    pub dirty: HashSet<NodeId>,
}

impl DamageSet {
    fn add(&mut self, id: NodeId, rect: RectF) {
        self.dirty.insert(id);
        if !rect.is_empty() {
            self.rects.push(rect);
        }
    }

    #[must_use]
    pub fn covers(&self, rect: RectF) -> bool {
        self.rects.iter().any(|d| d.intersects(rect))
    }
}

/// The unit that crosses the VBA↔Rust boundary. Versioned, serde-shaped,
/// hand-inspectable; `base_hash` makes a stale incremental patch self-heal to a
/// full rebuild rather than corrupt.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ScenePatch {
    pub version: u16,
    pub base_hash: u64,
    pub surface: SurfaceSize,
    pub dpi: DpiScale,
    pub edits: Vec<NodeEdit>,
}

/// Externally tagged (not internally tagged) on purpose: `Retain`/`Remove` carry a
/// bare [`NodeId`] (a numeric newtype), which serde cannot internally tag. The
/// external `{"upsert": {…}}` / `{"retain": 7}` shape round-trips every variant
/// through JSON and is what the VBA `OxSceneBuilder` emits across the boundary.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NodeEdit {
    Upsert(SceneNode),
    Retain(NodeId),
    Remove(NodeId),
    Reorder {
        id: NodeId,
        z: i32,
        parent: Option<NodeId>,
    },
}

/// Geometry-only hit node, keyed identically to paint but structurally separate
/// (authoritative routing is reducer/VBA policy, not the kernel).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct HitNode {
    pub id: NodeId,
    pub bounds: RectF,
    pub clip: Option<RectF>,
    pub transform: Affine,
    pub z: i32,
    pub transparent: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SceneError {
    UnsupportedVersion { actual: u16, expected: u16 },
    StaleBase { expected: u64, actual: u64 },
}

impl std::fmt::Display for SceneError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::UnsupportedVersion { actual, expected } => {
                write!(f, "unsupported scene patch version {actual}; expected {expected}")
            }
            Self::StaleBase { expected, actual } => write!(
                f,
                "scene patch base_hash {actual} does not match resident frame_hash {expected}; resubmit a full rebuild"
            ),
        }
    }
}

impl std::error::Error for SceneError {}

/// A backend draws a scene by implementing this trait; the kernel walks the tree
/// and pushes transform/clip + primitives. Backends are control-blind.
pub trait PrimSink {
    fn push_transform(&mut self, t: Affine);
    fn pop_transform(&mut self);
    fn push_clip(&mut self, rect: RectF);
    fn pop_clip(&mut self);
    fn draw(&mut self, prim: &Prim);
}

/// Walk the whole scene in (parent, child-order) applying transform/clip — the
/// deterministic canonical render path. `render_headless` generalized to the full
/// vocabulary.
pub fn render_full(scene: &Scene, sink: &mut dyn PrimSink) {
    render_node(scene, scene.root, sink, None);
}

/// Render only nodes intersecting the damage rects (z/clip-aware via the same
/// walk). With damage covering the whole surface this equals [`render_full`].
pub fn render_damage(scene: &Scene, sink: &mut dyn PrimSink, damage: &DamageSet) {
    render_node(scene, scene.root, sink, Some(damage));
}

fn render_node(scene: &Scene, id: NodeId, sink: &mut dyn PrimSink, damage: Option<&DamageSet>) {
    let Some(node) = scene.get(id) else { return };
    if !node.visible {
        return;
    }
    sink.push_transform(node.transform);
    if let Some(clip) = node.clip {
        sink.push_clip(clip);
    }

    let abs = scene.absolute_transform(id).apply_rect(node.bounds);
    let paint_self = match damage {
        None => true,
        Some(d) => node.bounds.is_empty() || d.covers(abs),
    };
    if paint_self {
        for prim in &node.prims {
            sink.draw(prim);
        }
    }

    for child in &node.children {
        render_node(scene, *child, sink, damage);
    }

    if node.clip.is_some() {
        sink.pop_clip();
    }
    sink.pop_transform();
}

/// Topmost (by z, then arena order) hit node whose absolute bounds contain the
/// point and whose clip admits it. Pure geometry — routing policy lives elsewhere.
#[must_use]
pub fn pick(hits: &[HitNode], point: PointF) -> Option<NodeId> {
    hits.iter()
        .filter(|h| !h.transparent)
        .filter(|h| h.transform.apply_rect(h.bounds).contains(point))
        .filter(|h| {
            h.clip
                .is_none_or(|c| h.transform.apply_rect(c).contains(point))
        })
        .enumerate()
        .max_by_key(|(order, h)| (h.z, *order))
        .map(|(_, h)| h.id)
}

/// Round a logical rect to device pixels (floor-left / ceil-right per
/// `COORDINATE_MODEL.md`). Returns `None` for non-finite or degenerate rects.
fn rect_to_device(r: RectF) -> Option<Rect> {
    if !(r.x.is_finite() && r.y.is_finite() && r.w.is_finite() && r.h.is_finite()) {
        return None;
    }
    let left = r.x.floor();
    let top = r.y.floor();
    let right = (r.x + r.w).ceil();
    let bottom = (r.y + r.h).ceil();
    let width = right - left;
    let height = bottom - top;
    if width <= 0.0 || height <= 0.0 {
        return None;
    }
    Some(Rect::new(
        left as i32,
        top as i32,
        width as i32,
        height as i32,
    ))
}

/// Deterministic headless rasterizer (the reference oracle). It rasterizes every
/// primitive in the Scene vocabulary. Curves, text, gradients, and images use small
/// deterministic reference approximations rather than platform font/image engines,
/// so every supported primitive perturbs the framebuffer hash without making the
/// headless oracle depend on host resources.
pub struct HeadlessSink {
    surface: SurfaceSize,
    pixels: Vec<u8>,
    cur: Affine,
    xf_stack: Vec<Affine>,
    clip: RectF,
    clip_stack: Vec<RectF>,
    draw_count: usize,
}

impl HeadlessSink {
    #[must_use]
    pub fn new(surface: SurfaceSize) -> Self {
        let count = (surface.width as usize) * (surface.height as usize) * BYTES_PER_PIXEL;
        let clip = RectF::new(0.0, 0.0, surface.width as f32, surface.height as f32);
        Self {
            surface,
            pixels: vec![0; count],
            cur: Affine::IDENTITY,
            xf_stack: Vec::new(),
            clip,
            clip_stack: Vec::new(),
            draw_count: 0,
        }
    }

    #[must_use]
    pub fn into_pixels(self) -> Vec<u8> {
        self.pixels
    }

    #[must_use]
    pub fn framebuffer_hash(&self) -> u64 {
        fnv1a64(&self.pixels)
    }

    /// Number of primitives walked (drawn or recorded) since construction — the
    /// scene analog of `RenderDiagnostics::command_count`.
    #[must_use]
    pub fn command_count(&self) -> usize {
        self.draw_count
    }

    fn fill_solid(&mut self, rect: RectF, color: Color) {
        let device = self.cur.apply_rect(rect).intersect(self.clip);
        let Some(device) = rect_to_device(device) else {
            return;
        };
        let left = device.x.max(0);
        let top = device.y.max(0);
        let right = (device.x + device.width).min(self.surface.width as i32);
        let bottom = (device.y + device.height).min(self.surface.height as i32);
        if left >= right || top >= bottom {
            return;
        }
        let stride = self.surface.width as usize;
        let rgba = color.to_rgba8();
        for y in top..bottom {
            for x in left..right {
                let offset = ((y as usize * stride) + x as usize) * BYTES_PER_PIXEL;
                self.pixels[offset..offset + BYTES_PER_PIXEL].copy_from_slice(&rgba);
            }
        }
    }

    fn solid_of(paint: &Paint) -> Option<Color> {
        match paint {
            Paint::Solid(c) => Some(*c),
            Paint::LinearGradient { stops, .. } => stops.first().map(|(_, c)| *c),
        }
    }

    fn stroke_border(&mut self, rect: RectF, stroke: &Stroke) {
        let Some(color) = Self::solid_of(&stroke.paint) else {
            return;
        };
        let t = stroke.width.max(1.0);
        // top, bottom, left, right thin fills (logical space; transformed on fill).
        self.fill_solid(RectF::new(rect.x, rect.y, rect.w, t), color);
        self.fill_solid(RectF::new(rect.x, rect.y + rect.h - t, rect.w, t), color);
        self.fill_solid(RectF::new(rect.x, rect.y, t, rect.h), color);
        self.fill_solid(RectF::new(rect.x + rect.w - t, rect.y, t, rect.h), color);
    }

    fn fill_device_solid(&mut self, rect: RectF, color: Color) {
        let device = rect.intersect(self.clip);
        let Some(device) = rect_to_device(device) else {
            return;
        };
        let left = device.x.max(0);
        let top = device.y.max(0);
        let right = (device.x + device.width).min(self.surface.width as i32);
        let bottom = (device.y + device.height).min(self.surface.height as i32);
        if left >= right || top >= bottom {
            return;
        }
        let stride = self.surface.width as usize;
        let rgba = color.to_rgba8();
        for y in top..bottom {
            for x in left..right {
                let offset = ((y as usize * stride) + x as usize) * BYTES_PER_PIXEL;
                self.pixels[offset..offset + BYTES_PER_PIXEL].copy_from_slice(&rgba);
            }
        }
    }

    fn scalar_scale(&self) -> f32 {
        ((self.cur.sx.abs() + self.cur.sy.abs()) * 0.5).max(1.0)
    }

    fn stroke_line(&mut self, a: PointF, b: PointF, stroke: &Stroke) {
        let Some(color) = Self::solid_of(&stroke.paint) else {
            return;
        };
        let (ax, ay) = (
            a.x * self.cur.sx + self.cur.tx,
            a.y * self.cur.sy + self.cur.ty,
        );
        let (bx, by) = (
            b.x * self.cur.sx + self.cur.tx,
            b.y * self.cur.sy + self.cur.ty,
        );
        let steps = ((bx - ax).abs().max((by - ay).abs()).ceil() as u32).max(1);
        let t = (stroke.width * self.scalar_scale()).max(1.0);
        for step in 0..=steps {
            let f = step as f32 / steps as f32;
            let x = ax + (bx - ax) * f;
            let y = ay + (by - ay) * f;
            self.fill_device_solid(RectF::new(x - t * 0.5, y - t * 0.5, t, t), color);
        }
    }

    fn polygon_bounds(&self, pts: &[PointF]) -> Option<RectF> {
        let first = pts.first()?;
        let (mut min_x, mut min_y, mut max_x, mut max_y) = (first.x, first.y, first.x, first.y);
        for p in &pts[1..] {
            min_x = min_x.min(p.x);
            min_y = min_y.min(p.y);
            max_x = max_x.max(p.x);
            max_y = max_y.max(p.y);
        }
        Some(RectF::new(min_x, min_y, max_x - min_x, max_y - min_y))
    }

    fn draw_text_placeholder(&mut self, rect: RectF, paint: &Paint, flags: TextFlags) {
        let Some(color) = Self::solid_of(paint) else {
            return;
        };
        let band_h = 1.0_f32.max(rect.h.min(3.0));
        let y = rect.y + ((rect.h - band_h) * 0.5).max(0.0);
        self.fill_solid(RectF::new(rect.x, y, rect.w, band_h), color);
        if flags.underline_accelerator {
            self.fill_solid(
                RectF::new(rect.x, rect.y + rect.h - 2.0, rect.w.min(12.0), 1.0),
                color,
            );
        }
        if flags.disabled {
            let shadow = Color::rgba(0x80, 0x80, 0x80, color.alpha);
            self.fill_solid(RectF::new(rect.x, y + band_h + 1.0, rect.w, 1.0), shadow);
        }
    }

    fn draw_image_placeholder(&mut self, image: ImageHandle, dst: RectF, mode: ImageMode) {
        let bytes = image.0.to_le_bytes();
        let mode_bias = match mode {
            ImageMode::Stretch => 0x30,
            ImageMode::Clip => 0x60,
            ImageMode::Zoom => 0x78,
            ImageMode::Tile => 0x90,
        };
        let fill = Color::rgba(
            bytes[0].wrapping_add(mode_bias),
            bytes[3].wrapping_add(0x40),
            bytes[5].wrapping_add(0x80),
            0xff,
        );
        self.fill_solid(dst, fill);
        self.stroke_border(
            dst,
            &Stroke {
                paint: Paint::Solid(Color::rgba(0x00, 0x00, 0x00, 0xff)),
                width: 1.0,
            },
        );
    }

    fn draw_edge(
        &mut self,
        rect: RectF,
        effect: EdgeEffect,
        border: EdgeBorder,
        light: Color,
        shadow: Color,
    ) {
        match effect {
            EdgeEffect::Flat => self.edge_pass(rect, border, shadow, shadow),
            EdgeEffect::Raised => self.edge_pass(rect, border, light, shadow),
            EdgeEffect::Sunken => self.edge_pass(rect, border, shadow, light),
            EdgeEffect::Etched => {
                self.edge_pass(rect, border, shadow, light);
                self.edge_pass(inset_rect(rect, 1.0), border, light, shadow);
            }
            EdgeEffect::Bump => {
                self.edge_pass(rect, border, light, shadow);
                self.edge_pass(inset_rect(rect, 1.0), border, shadow, light);
            }
        }
    }

    fn edge_pass(&mut self, rect: RectF, border: EdgeBorder, tl: Color, br: Color) {
        let t = 1.0;
        if rect.w <= 0.0 || rect.h <= 0.0 {
            return;
        }
        if border.top {
            self.fill_solid(RectF::new(rect.x, rect.y, rect.w, t), tl);
        }
        if border.left {
            self.fill_solid(RectF::new(rect.x, rect.y, t, rect.h), tl);
        }
        if border.bottom {
            self.fill_solid(RectF::new(rect.x, rect.y + rect.h - t, rect.w, t), br);
        }
        if border.right {
            self.fill_solid(RectF::new(rect.x + rect.w - t, rect.y, t, rect.h), br);
        }
    }
}

impl PrimSink for HeadlessSink {
    fn push_transform(&mut self, t: Affine) {
        self.xf_stack.push(self.cur);
        self.cur = self.cur.compose(t);
    }

    fn pop_transform(&mut self) {
        if let Some(prev) = self.xf_stack.pop() {
            self.cur = prev;
        }
    }

    fn push_clip(&mut self, rect: RectF) {
        self.clip_stack.push(self.clip);
        self.clip = self.clip.intersect(self.cur.apply_rect(rect));
    }

    fn pop_clip(&mut self) {
        if let Some(prev) = self.clip_stack.pop() {
            self.clip = prev;
        }
    }

    fn draw(&mut self, prim: &Prim) {
        self.draw_count += 1;
        match prim {
            Prim::FillRect { rect, paint } => {
                if let Some(color) = Self::solid_of(paint) {
                    self.fill_solid(*rect, color);
                }
            }
            Prim::StrokeRect { rect, stroke } => self.stroke_border(*rect, stroke),
            Prim::RoundRect {
                rect, fill, stroke, ..
            }
            | Prim::Ellipse { rect, fill, stroke } => {
                if let Some(fill) = fill {
                    if let Some(color) = Self::solid_of(fill) {
                        self.fill_solid(*rect, color);
                    }
                }
                if let Some(stroke) = stroke {
                    self.stroke_border(*rect, stroke);
                }
            }
            Prim::Line { a, b, stroke } => self.stroke_line(*a, *b, stroke),
            Prim::Polygon { pts, fill, stroke } => {
                if let Some(fill) = fill {
                    if let (Some(color), Some(bounds)) =
                        (Self::solid_of(fill), self.polygon_bounds(pts))
                    {
                        self.fill_solid(bounds, color);
                    }
                }
                if let Some(stroke) = stroke {
                    for pair in pts.windows(2) {
                        self.stroke_line(pair[0], pair[1], stroke);
                    }
                    if let (Some(first), Some(last)) = (pts.first(), pts.last()) {
                        self.stroke_line(*last, *first, stroke);
                    }
                }
            }
            Prim::Gradient { rect, stops, .. } => {
                if let Some((_, color)) = stops.first() {
                    self.fill_solid(*rect, *color);
                }
            }
            Prim::DrawText {
                rect, paint, flags, ..
            } => self.draw_text_placeholder(*rect, paint, *flags),
            Prim::DrawImage {
                image, dst, mode, ..
            } => self.draw_image_placeholder(*image, *dst, *mode),
            Prim::DrawEdge {
                rect,
                effect,
                border,
                shadow,
                light,
            } => self.draw_edge(*rect, *effect, *border, *light, *shadow),
        }
    }
}

fn inset_rect(r: RectF, by: f32) -> RectF {
    RectF::new(
        r.x + by,
        r.y + by,
        (r.w - 2.0 * by).max(0.0),
        (r.h - 2.0 * by).max(0.0),
    )
}

/// Stable diagnostics from rendering a [`Scene`] through the headless reference.
/// Reports the same shape the historical W002 headless renderer did
/// (width/height/command_count/framebuffer_hash/hash_algorithm).
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct SceneRenderReport {
    pub width: u32,
    pub height: u32,
    pub command_count: usize,
    pub framebuffer_hash: u64,
    /// Canonical framebuffer-hash algorithm identifier ([`FRAMEBUFFER_HASH_ALGORITHM`]).
    pub hash_algorithm: &'static str,
}

/// Render a scene through the headless reference and return stable diagnostics.
#[must_use]
pub fn render_headless_report(scene: &Scene) -> SceneRenderReport {
    let mut sink = HeadlessSink::new(scene.surface);
    render_full(scene, &mut sink);
    SceneRenderReport {
        width: scene.surface.width,
        height: scene.surface.height,
        command_count: sink.command_count(),
        framebuffer_hash: sink.framebuffer_hash(),
        hash_algorithm: FRAMEBUFFER_HASH_ALGORITHM,
    }
}

/// Convenience: render a scene through the headless reference and return only the
/// framebuffer hash (matches `RenderDiagnostics::framebuffer_hash`).
#[must_use]
pub fn render_headless_hash(scene: &Scene) -> u64 {
    render_headless_report(scene).framebuffer_hash
}

/// Manual, dependency-free canonical byte feed for content hashing (serde_json is
/// dev-only, so node hashing cannot route through it).
struct ContentHasher {
    buf: Vec<u8>,
}

impl ContentHasher {
    fn new() -> Self {
        Self { buf: Vec::new() }
    }
    fn u8(&mut self, v: u8) {
        self.buf.push(v);
    }
    fn u32(&mut self, v: u32) {
        self.buf.extend_from_slice(&v.to_le_bytes());
    }
    fn i32(&mut self, v: i32) {
        self.buf.extend_from_slice(&v.to_le_bytes());
    }
    fn u64(&mut self, v: u64) {
        self.buf.extend_from_slice(&v.to_le_bytes());
    }
    fn f32(&mut self, v: f32) {
        self.buf.extend_from_slice(&v.to_bits().to_le_bytes());
    }
    fn color(&mut self, c: Color) {
        self.buf.extend_from_slice(&c.to_rgba8());
    }
    fn point(&mut self, p: PointF) {
        self.f32(p.x);
        self.f32(p.y);
    }
    fn rect(&mut self, r: RectF) {
        self.f32(r.x);
        self.f32(r.y);
        self.f32(r.w);
        self.f32(r.h);
    }
    fn affine(&mut self, a: Affine) {
        self.f32(a.sx);
        self.f32(a.sy);
        self.f32(a.tx);
        self.f32(a.ty);
    }
    fn paint(&mut self, p: &Paint) {
        match p {
            Paint::Solid(c) => {
                self.u8(0);
                self.color(*c);
            }
            Paint::LinearGradient { stops, angle } => {
                self.u8(1);
                self.f32(*angle);
                self.u32(stops.len() as u32);
                for (stop, color) in stops {
                    self.f32(*stop);
                    self.color(*color);
                }
            }
        }
    }
    fn opt_paint(&mut self, p: &Option<Paint>) {
        match p {
            Some(paint) => {
                self.u8(1);
                self.paint(paint);
            }
            None => self.u8(0),
        }
    }
    fn stroke(&mut self, s: &Stroke) {
        self.paint(&s.paint);
        self.f32(s.width);
    }
    fn opt_stroke(&mut self, s: &Option<Stroke>) {
        match s {
            Some(stroke) => {
                self.u8(1);
                self.stroke(stroke);
            }
            None => self.u8(0),
        }
    }
    fn prim(&mut self, prim: &Prim) {
        match prim {
            Prim::FillRect { rect, paint } => {
                self.u8(0);
                self.rect(*rect);
                self.paint(paint);
            }
            Prim::StrokeRect { rect, stroke } => {
                self.u8(1);
                self.rect(*rect);
                self.stroke(stroke);
            }
            Prim::RoundRect {
                rect,
                radius,
                fill,
                stroke,
            } => {
                self.u8(2);
                self.rect(*rect);
                self.f32(*radius);
                self.opt_paint(fill);
                self.opt_stroke(stroke);
            }
            Prim::Ellipse { rect, fill, stroke } => {
                self.u8(3);
                self.rect(*rect);
                self.opt_paint(fill);
                self.opt_stroke(stroke);
            }
            Prim::Line { a, b, stroke } => {
                self.u8(4);
                self.point(*a);
                self.point(*b);
                self.stroke(stroke);
            }
            Prim::Polygon { pts, fill, stroke } => {
                self.u8(5);
                self.u32(pts.len() as u32);
                for p in pts {
                    self.point(*p);
                }
                self.opt_paint(fill);
                self.opt_stroke(stroke);
            }
            Prim::Gradient { rect, stops, angle } => {
                self.u8(6);
                self.rect(*rect);
                self.f32(*angle);
                self.u32(stops.len() as u32);
                for (stop, color) in stops {
                    self.f32(*stop);
                    self.color(*color);
                }
            }
            Prim::DrawText {
                run,
                rect,
                align,
                wrap,
                clip,
                paint,
                flags,
            } => {
                self.u8(7);
                self.u64(run.0);
                self.rect(*rect);
                self.u8(*align as u8);
                self.u8(u8::from(*wrap));
                self.u8(u8::from(*clip));
                self.paint(paint);
                self.u8(u8::from(flags.underline_accelerator));
                self.u8(u8::from(flags.disabled));
            }
            Prim::DrawImage {
                image,
                src,
                dst,
                mode,
            } => {
                self.u8(8);
                self.u64(image.0);
                self.rect(*src);
                self.rect(*dst);
                self.u8(*mode as u8);
            }
            Prim::DrawEdge {
                rect,
                effect,
                border,
                light,
                shadow,
            } => {
                self.u8(9);
                self.rect(*rect);
                self.u8(*effect as u8);
                self.u8(u8::from(border.left));
                self.u8(u8::from(border.top));
                self.u8(u8::from(border.right));
                self.u8(u8::from(border.bottom));
                self.color(*light);
                self.color(*shadow);
            }
        }
    }
    fn finish(self) -> u64 {
        fnv1a64(&self.buf)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The historical W002 rectangle framebuffer hash, now reproduced by a Scene-native
    /// fixture (the pre-Scene `w002_rectangle_fixture_*` helpers retired in oxforms-rq5.1).
    const W002_FRAMEBUFFER_HASH: u64 = 13_797_848_596_963_948_501;

    fn dpi() -> DpiScale {
        DpiScale::new(72.0, 72.0)
    }

    /// One-node FillRect scene equivalent to the W002 fixture.
    fn w002_scene() -> Scene {
        let mut scene = Scene::new(SurfaceSize::new(4, 3), dpi(), NodeId(0));
        let mut root = SceneNode::new(NodeId(0));
        root.bounds = RectF::new(0.0, 0.0, 4.0, 3.0);
        root.prims = vec![Prim::FillRect {
            rect: RectF::new(1.0, 1.0, 2.0, 1.0),
            paint: Paint::Solid(Color::rgba(0x10, 0x20, 0x30, 0xff)),
        }];
        scene.nodes.push(root);
        scene.recompute_frame_hash();
        scene
    }

    fn single_prim_scene(prim: Prim) -> Scene {
        let mut scene = Scene::new(SurfaceSize::new(40, 32), dpi(), NodeId(0));
        let mut root = SceneNode::new(NodeId(0));
        root.bounds = RectF::new(0.0, 0.0, 40.0, 32.0);
        root.prims = vec![
            Prim::FillRect {
                rect: RectF::new(0.0, 0.0, 40.0, 32.0),
                paint: Paint::Solid(Color::rgba(0xf0, 0xf0, 0xf0, 0xff)),
            },
            prim,
        ];
        scene.nodes.push(root);
        scene.recompute_frame_hash();
        scene
    }

    #[test]
    fn headless_reference_rasterizes_every_primitive_variant() {
        let black = Color::rgba(0x00, 0x00, 0x00, 0xff);
        let red = Color::rgba(0xc0, 0x20, 0x20, 0xff);
        let blue = Color::rgba(0x20, 0x40, 0xc0, 0xff);
        let green = Color::rgba(0x20, 0xa0, 0x20, 0xff);
        let magenta = Color::rgba(0xc0, 0x20, 0xc0, 0xff);
        let stroke = |color| Stroke {
            paint: Paint::Solid(color),
            width: 1.0,
        };
        let base = render_headless_hash(&single_prim_scene(Prim::FillRect {
            rect: RectF::new(8.0, 8.0, 10.0, 8.0),
            paint: Paint::Solid(Color::rgba(0xf0, 0xf0, 0xf0, 0xff)),
        }));
        let prims = [
            Prim::StrokeRect {
                rect: RectF::new(2.0, 2.0, 18.0, 10.0),
                stroke: stroke(black),
            },
            Prim::RoundRect {
                rect: RectF::new(4.0, 4.0, 18.0, 10.0),
                radius: 4.0,
                fill: Some(Paint::Solid(blue)),
                stroke: Some(stroke(black)),
            },
            Prim::Ellipse {
                rect: RectF::new(6.0, 6.0, 16.0, 10.0),
                fill: Some(Paint::Solid(green)),
                stroke: Some(stroke(black)),
            },
            Prim::Line {
                a: PointF::new(2.0, 16.0),
                b: PointF::new(30.0, 16.0),
                stroke: stroke(red),
            },
            Prim::Polygon {
                pts: vec![
                    PointF::new(4.0, 28.0),
                    PointF::new(12.0, 18.0),
                    PointF::new(20.0, 28.0),
                ],
                fill: Some(Paint::Solid(magenta)),
                stroke: Some(stroke(black)),
            },
            Prim::Gradient {
                rect: RectF::new(2.0, 2.0, 16.0, 12.0),
                stops: vec![(0.0, black), (1.0, Color::rgba(0xff, 0xff, 0xff, 0xff))],
                angle: 0.0,
            },
            Prim::DrawText {
                run: TextRunId(123),
                rect: RectF::new(3.0, 10.0, 30.0, 10.0),
                align: TextAlign::Left,
                wrap: false,
                clip: true,
                paint: Paint::Solid(black),
                flags: TextFlags {
                    underline_accelerator: true,
                    disabled: false,
                },
            },
            Prim::DrawImage {
                image: ImageHandle(42),
                src: RectF::new(0.0, 0.0, 16.0, 16.0),
                dst: RectF::new(8.0, 8.0, 16.0, 12.0),
                mode: ImageMode::Stretch,
            },
            Prim::DrawEdge {
                rect: RectF::new(2.0, 2.0, 20.0, 12.0),
                effect: EdgeEffect::Bump,
                border: EdgeBorder::ALL,
                light: Color::rgba(0xff, 0xff, 0xff, 0xff),
                shadow: Color::rgba(0x40, 0x40, 0x40, 0xff),
            },
        ];

        for prim in prims {
            let scene = single_prim_scene(prim.clone());
            let hash = render_headless_hash(&scene);
            assert_ne!(
                hash, base,
                "headless rasterizer must not silently drop {prim:?}"
            );

            let full = {
                let mut sink = HeadlessSink::new(scene.surface);
                render_full(&scene, &mut sink);
                sink.into_pixels()
            };
            let damaged = {
                let mut damage = DamageSet::default();
                damage.add(NodeId(0), RectF::new(0.0, 0.0, 40.0, 32.0));
                let mut sink = HeadlessSink::new(scene.surface);
                render_damage(&scene, &mut sink, &damage);
                sink.into_pixels()
            };
            assert_eq!(
                full, damaged,
                "damage==full must hold for primitive {prim:?}"
            );
        }
    }

    #[test]
    fn render_full_reproduces_the_w002_framebuffer_hash() {
        let scene = w002_scene();
        assert_eq!(
            render_headless_hash(&scene),
            W002_FRAMEBUFFER_HASH,
            "scene render must reproduce the historical W002 framebuffer hash"
        );
    }

    // ── Text-metrics seam (4pn.10) ──

    fn text_key(size_pt: u32) -> TextKey {
        TextKey {
            font: FontId(1),
            size_milli_pt: size_pt * 1000,
            wrap_width_milli_pt: None,
            accelerator_index: None,
        }
    }

    #[test]
    fn text_run_id_is_stable_and_content_derived() {
        let key = text_key(12);
        // Stable: same inputs → same id.
        assert_eq!(text_run_id(&key, "OK"), text_run_id(&key, "OK"));
        // Text-sensitive: a caption change yields a different id (so the DrawText
        // prim's run changes → frame_hash changes, with no text-store hashing).
        assert_ne!(text_run_id(&key, "OK"), text_run_id(&key, "Cancel"));
        // Style-sensitive: size and font participate.
        assert_ne!(text_run_id(&key, "OK"), text_run_id(&text_key(14), "OK"));
        let other_font = TextKey {
            font: FontId(2),
            ..key.clone()
        };
        assert_ne!(text_run_id(&key, "OK"), text_run_id(&other_font, "OK"));
    }

    #[test]
    fn text_run_id_golden_vector_is_frozen() {
        // A frozen reference so the canonical encoding cannot drift unnoticed: any
        // change to the byte layout / hash is a deliberate, reviewed break. (The id is
        // Rust-assigned; VBA learns it via MeasureText and never recomputes it.)
        let key = TextKey {
            font: FontId(1),
            size_milli_pt: 12_000,
            wrap_width_milli_pt: None,
            accelerator_index: None,
        };
        assert_eq!(text_run_id(&key, "OK").0, 150_257_306_305_228_244);
    }

    #[test]
    fn ampersands_are_literal_and_keep_caret_indices() {
        let key = text_key(12);
        for text in ["A&B", "A&&B", "tail&", "A&B && C&"] {
            let run = StubShaper.shape(&key, text);
            assert_eq!(&*run.source, text);
            assert_eq!(run.glyphs.len(), text.chars().count());
            assert_eq!(run.caret.stops.len(), text.chars().count() + 1);
            assert_eq!(run.accelerator, None);
        }
    }

    #[test]
    fn stub_shaper_marks_only_an_explicit_accelerator() {
        let mut key = text_key(12);
        let plain_id = text_run_id(&key, "E&xit");
        key.accelerator_index = Some(2);
        let run = StubShaper.shape(&key, "E&xit");
        assert_eq!(&*run.source, "E&xit");
        assert_eq!(run.glyphs.len(), 5);
        assert_eq!(run.accelerator, Some(2), "x is the explicit accelerator");
        // The id is over the RAW caption, so the accelerator variant is distinct.
        assert_eq!(run.id, text_run_id(&key, "E&xit"));
        assert_ne!(
            run.id, plain_id,
            "underline policy belongs to the content key"
        );
    }

    #[test]
    fn stub_shaper_produces_exact_metrics_and_caret() {
        let key = text_key(12); // em = 12.0, half-em advance = 6.0
        let run = StubShaper.shape(&key, "OK");
        assert_eq!(run.id, text_run_id(&key, "OK"));
        assert_eq!(run.glyphs.len(), 2);
        assert_eq!(run.glyphs[0].x, 0.0);
        assert_eq!(run.glyphs[1].x, 6.0);
        assert_eq!(run.metrics.advance, 12.0);
        assert_eq!(run.metrics.ascent, 9.6);
        assert_eq!(run.metrics.descent, 2.4);
        assert_eq!(run.metrics.line_height(), 12.0);
        assert_eq!(run.caret.stops, vec![0.0, 6.0, 12.0]);
        assert_eq!(&*run.source, "OK");
    }

    #[test]
    fn caret_maps_index_and_x_both_ways() {
        let run = StubShaper.shape(&text_key(12), "OK");
        assert_eq!(run.caret_x(0), Some(0.0));
        assert_eq!(run.caret_x(2), Some(12.0)); // end caret
        assert_eq!(run.caret_x(3), None);
        assert_eq!(run.index_at_x(-1.0), 0); // clamps to nearest stop
        assert_eq!(run.index_at_x(5.0), 1); // closer to 6.0 than 0.0
        assert_eq!(run.index_at_x(100.0), 2); // past the end → run end
    }

    #[test]
    fn text_run_serde_round_trips() {
        let run = StubShaper.shape(&text_key(11), "Hello");
        let json = serde_json::to_string(&run).expect("serialize run");
        let back: TextRun = serde_json::from_str(&json).expect("deserialize run");
        assert_eq!(run, back);
    }

    #[test]
    fn scene_text_store_resolves_and_serde_round_trips() {
        let mut scene = w002_scene();
        let run = StubShaper.shape(&text_key(12), "OK");
        let id = run.id;
        scene.upsert_text_run(run.clone());
        assert_eq!(scene.text_run(id), Some(&run));
        // Idempotent: re-inserting identical content does not grow the store.
        scene.upsert_text_run(StubShaper.shape(&text_key(12), "OK"));
        assert_eq!(scene.text.len(), 1);
        // A Scene carrying a text store round-trips (serde(default) keeps the field).
        let json = serde_json::to_string(&scene).expect("serialize scene");
        let back: Scene = serde_json::from_str(&json).expect("deserialize scene");
        assert_eq!(back.text_run(id), Some(&run));
    }

    #[test]
    fn frame_hash_ignores_the_text_store() {
        // Content-hash ids make a caption change move the DrawText prim's run id, so
        // the text store itself is deliberately excluded from frame_hash.
        let mut scene = w002_scene();
        scene.recompute_frame_hash();
        let before = scene.frame_hash;
        scene.upsert_text_run(StubShaper.shape(&text_key(12), "OK"));
        scene.recompute_frame_hash();
        assert_eq!(
            before, scene.frame_hash,
            "the text store must not affect frame_hash"
        );
    }

    #[test]
    fn render_damage_full_surface_equals_render_full() {
        let scene = w002_scene();
        let full = {
            let mut sink = HeadlessSink::new(scene.surface);
            render_full(&scene, &mut sink);
            sink.into_pixels()
        };
        let damaged = {
            let mut damage = DamageSet::default();
            damage.add(NodeId(0), RectF::new(0.0, 0.0, 4.0, 3.0));
            let mut sink = HeadlessSink::new(scene.surface);
            render_damage(&scene, &mut sink, &damage);
            sink.into_pixels()
        };
        assert_eq!(
            full, damaged,
            "render_damage over the whole surface equals render_full (invariant b)"
        );
    }

    #[test]
    fn scene_serde_round_trips() {
        let scene = w002_scene();
        let json = serde_json::to_string(&scene).expect("serialize scene");
        let back: Scene = serde_json::from_str(&json).expect("deserialize scene");
        assert_eq!(back.nodes.len(), scene.nodes.len());
        assert_eq!(back.surface, scene.surface);
        assert_eq!(
            render_headless_hash(&back),
            render_headless_hash(&scene),
            "a round-tripped scene renders identically"
        );
    }

    #[test]
    fn apply_patch_upsert_and_stale_base() {
        let mut scene = Scene::new(SurfaceSize::new(4, 3), dpi(), NodeId(0));
        let mut root = SceneNode::new(NodeId(0));
        root.bounds = RectF::new(0.0, 0.0, 4.0, 3.0);
        root.prims = vec![Prim::FillRect {
            rect: RectF::new(1.0, 1.0, 2.0, 1.0),
            paint: Paint::Solid(Color::rgba(0x10, 0x20, 0x30, 0xff)),
        }];

        let patch = ScenePatch {
            version: SCENE_PATCH_VERSION,
            base_hash: scene.frame_hash,
            surface: scene.surface,
            dpi: scene.dpi,
            edits: vec![NodeEdit::Upsert(root)],
        };
        let damage = scene.apply_patch(&patch).expect("apply on matching base");
        assert!(damage.dirty.contains(&NodeId(0)));
        assert_eq!(render_headless_hash(&scene), W002_FRAMEBUFFER_HASH);

        // A stale base_hash self-heals to StaleBase rather than corrupting.
        let stale = ScenePatch {
            version: SCENE_PATCH_VERSION,
            base_hash: scene.frame_hash.wrapping_add(1),
            surface: scene.surface,
            dpi: scene.dpi,
            edits: Vec::new(),
        };
        assert!(matches!(
            scene.apply_patch(&stale),
            Err(SceneError::StaleBase { .. })
        ));
    }

    #[test]
    fn content_equal_upsert_is_a_noop() {
        let mut scene = w002_scene();
        let resident = scene.get(NodeId(0)).expect("root").clone();
        let patch = ScenePatch {
            version: SCENE_PATCH_VERSION,
            base_hash: scene.frame_hash,
            surface: scene.surface,
            dpi: scene.dpi,
            edits: vec![NodeEdit::Upsert(resident)],
        };
        let damage = scene.apply_patch(&patch).expect("apply");
        assert!(
            damage.dirty.is_empty(),
            "re-upserting identical content produces no damage"
        );
    }

    /// Determinism invariant (c) for the incremental strategy (oxforms-rq5.2): a sequence of
    /// incremental patches that omits unchanged nodes (the kernel RETAINS them) reaches a
    /// resident scene byte-identical to a full rebuild of the same final state — both the
    /// frame hash and the framebuffer. Exercises show-hide and a paint-order shuffle, with
    /// NodeId stable throughout. This is what makes the VBA "Upsert only the invalidated
    /// controls" emission safe.
    #[test]
    fn incremental_show_hide_and_shuffle_reach_the_full_rebuild_scene() {
        let surf = SurfaceSize::new(20, 20);
        let red = Color::rgba(0xff, 0x00, 0x00, 0xff);
        let blue = Color::rgba(0x00, 0x00, 0xff, 0xff);
        let face = Color::rgba(0xf0, 0xf0, 0xf0, 0xff);
        let fill = |x: f32, y: f32, c: Color| Prim::FillRect {
            rect: RectF::new(x, y, 10.0, 10.0),
            paint: Paint::Solid(c),
        };
        let child = |id: u64, x: f32, y: f32, c: Color, visible: bool| {
            let mut n = SceneNode::new(NodeId(id));
            n.parent = Some(NodeId(0));
            n.bounds = RectF::new(x, y, 10.0, 10.0);
            n.visible = visible;
            n.prims = vec![fill(x, y, c)];
            n
        };
        let root = |children: Vec<NodeId>| {
            let mut r = SceneNode::new(NodeId(0));
            r.bounds = RectF::new(0.0, 0.0, 20.0, 20.0);
            r.children = children;
            r.prims = vec![fill(0.0, 0.0, face)];
            r
        };
        let patch = |base: u64, edits: Vec<NodeEdit>| ScenePatch {
            version: SCENE_PATCH_VERSION,
            base_hash: base,
            surface: surf,
            dpi: dpi(),
            edits,
        };
        // n1 and n2 overlap, so paint order (the root children list) changes the pixels.

        // Full rebuild of the FINAL state: children [2,1] (n1 on top), n2 hidden.
        let mut full = Scene::new(surf, dpi(), NodeId(0));
        full.apply_patch(&patch(
            full.frame_hash,
            vec![
                NodeEdit::Upsert(root(vec![NodeId(2), NodeId(1)])),
                NodeEdit::Upsert(child(1, 2.0, 2.0, red, true)),
                NodeEdit::Upsert(child(2, 5.0, 5.0, blue, false)),
            ],
        ))
        .expect("full rebuild");

        // Incremental path to the SAME final state, in three steps that each omit the
        // unchanged nodes (retained by the kernel):
        let mut incr = Scene::new(surf, dpi(), NodeId(0));
        // 1) initial: children [1,2], both visible.
        incr.apply_patch(&patch(
            incr.frame_hash,
            vec![
                NodeEdit::Upsert(root(vec![NodeId(1), NodeId(2)])),
                NodeEdit::Upsert(child(1, 2.0, 2.0, red, true)),
                NodeEdit::Upsert(child(2, 5.0, 5.0, blue, true)),
            ],
        ))
        .expect("initial");
        // 2) show-hide: re-emit ONLY n2 as hidden (root + n1 omitted → retained).
        incr.apply_patch(&patch(
            incr.frame_hash,
            vec![NodeEdit::Upsert(child(2, 5.0, 5.0, blue, false))],
        ))
        .expect("hide n2");
        // 3) shuffle: re-emit ONLY the root with reordered children (n1 + n2 omitted).
        incr.apply_patch(&patch(
            incr.frame_hash,
            vec![NodeEdit::Upsert(root(vec![NodeId(2), NodeId(1)]))],
        ))
        .expect("shuffle paint order");

        assert_eq!(
            incr.frame_hash, full.frame_hash,
            "incremental omit-and-retain reaches the full-rebuild resident frame hash"
        );
        assert_eq!(
            render_headless_hash(&incr),
            render_headless_hash(&full),
            "...and a byte-identical framebuffer"
        );
        assert_eq!(
            incr.nodes.len(),
            full.nodes.len(),
            "NodeId set is stable across show-hide + shuffle (no nodes added/lost)"
        );
    }

    #[test]
    fn pick_returns_topmost_by_z() {
        let hits = vec![
            HitNode {
                id: NodeId(1),
                bounds: RectF::new(0.0, 0.0, 10.0, 10.0),
                clip: None,
                transform: Affine::IDENTITY,
                z: 0,
                transparent: false,
            },
            HitNode {
                id: NodeId(2),
                bounds: RectF::new(2.0, 2.0, 4.0, 4.0),
                clip: None,
                transform: Affine::IDENTITY,
                z: 5,
                transparent: false,
            },
        ];
        assert_eq!(pick(&hits, PointF::new(3.0, 3.0)), Some(NodeId(2)));
        assert_eq!(pick(&hits, PointF::new(8.0, 8.0)), Some(NodeId(1)));
        assert_eq!(pick(&hits, PointF::new(20.0, 20.0)), None);
    }

    #[test]
    fn render_headless_report_counts_commands() {
        let report = render_headless_report(&w002_scene());
        assert_eq!(
            report.command_count, 1,
            "the W002 scene has one FillRect prim"
        );
        assert_eq!(report.width, 4);
        assert_eq!(report.height, 3);
        assert_eq!(report.framebuffer_hash, W002_FRAMEBUFFER_HASH);
    }

    #[test]
    fn node_edit_json_round_trips_every_variant() {
        // The wire path the VBA OxSceneBuilder drives: each NodeEdit shape must
        // survive a JSON round-trip, including the scalar-carrying Retain/Remove
        // that an internally tagged enum could not represent.
        let mut node = SceneNode::new(NodeId(7));
        node.parent = Some(NodeId(0));
        node.bounds = RectF::new(1.0, 2.0, 3.0, 4.0);
        node.prims = vec![
            Prim::FillRect {
                rect: RectF::new(0.0, 0.0, 3.0, 4.0),
                paint: Paint::Solid(Color::rgba(0xaa, 0xbb, 0xcc, 0xff)),
            },
            Prim::DrawEdge {
                rect: RectF::new(0.0, 0.0, 3.0, 4.0),
                effect: EdgeEffect::Sunken,
                border: EdgeBorder::ALL,
                light: Color::rgba(0xff, 0xff, 0xff, 0xff),
                shadow: Color::rgba(0x40, 0x40, 0x40, 0xff),
            },
        ];

        let edits = vec![
            NodeEdit::Upsert(node),
            NodeEdit::Retain(NodeId(7)),
            NodeEdit::Remove(NodeId(9)),
            NodeEdit::Reorder {
                id: NodeId(7),
                z: 3,
                parent: Some(NodeId(0)),
            },
        ];

        for edit in &edits {
            let json = serde_json::to_string(edit).expect("serialize NodeEdit");
            let back: NodeEdit = serde_json::from_str(&json).expect("deserialize NodeEdit");
            let reserialized = serde_json::to_string(&back).expect("reserialize NodeEdit");
            assert_eq!(json, reserialized, "NodeEdit JSON must round-trip stably");
        }

        // Spot-check the external tag shape the VBA encoder targets.
        assert_eq!(serde_json::to_string(&edits[1]).unwrap(), r#"{"retain":7}"#);
        assert_eq!(serde_json::to_string(&edits[2]).unwrap(), r#"{"remove":9}"#);
    }

    #[test]
    fn scene_patch_json_round_trips() {
        let scene = w002_scene();
        let node = scene.get(NodeId(0)).expect("root").clone();
        let patch = ScenePatch {
            version: SCENE_PATCH_VERSION,
            base_hash: 0,
            surface: scene.surface,
            dpi: scene.dpi,
            edits: vec![NodeEdit::Upsert(node), NodeEdit::Retain(NodeId(0))],
        };
        let json = serde_json::to_string(&patch).expect("serialize ScenePatch");
        let back: ScenePatch = serde_json::from_str(&json).expect("deserialize ScenePatch");
        assert_eq!(back.version, patch.version);
        assert_eq!(back.edits.len(), patch.edits.len());
        assert_eq!(
            serde_json::to_string(&back).unwrap(),
            json,
            "ScenePatch JSON must round-trip stably"
        );
    }
}
