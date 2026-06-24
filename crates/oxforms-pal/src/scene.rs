//! The Scene: a control-agnostic, serializable, retained primitive tree.
//!
//! VBA controls paint themselves in immediate mode by emitting the §6.2 primitive
//! vocabulary under a stable [`NodeId`]; this kernel retains those primitives as a
//! keyed arena it diffs to repaint minimally. The kernel knows pixels, geometry,
//! color, glyphs, clips, transforms — never "TextBox"/"Label". See
//! `docs/specs/RENDERING_ARCHITECTURE.md`.
//!
//! Invariants this module upholds (and tests assert):
//! - `flatten(scene)` reproduces the legacy [`DisplayList`] for the FillRect
//!   vocabulary, so a full re-emit degenerates to the immediate path;
//! - `render_damage(full surface)` is pixel-identical to `render_full`;
//! - a one-node FillRect scene reproduces the historical W002 framebuffer hash.

use std::collections::HashSet;

use serde::{Deserialize, Serialize};

use crate::input::DpiScale;
use crate::{fnv1a64, Color, DisplayCommand, DisplayList, Rect, SurfaceSize, BYTES_PER_PIXEL};

/// Scene wire/storage schema version (mirrors `DISPLAY_LIST_VERSION`).
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
            damage: DamageSet::default(),
            frame_hash: 0,
        };
        scene.recompute_frame_hash();
        scene
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
    UnsupportedVersion {
        actual: u16,
        expected: u16,
    },
    StaleBase {
        expected: u64,
        actual: u64,
    },
    /// `flatten` met a primitive outside the legacy FillRect vocabulary.
    FlattenUnsupportedPrim,
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
            Self::FlattenUnsupportedPrim => {
                write!(f, "flatten currently supports only the FillRect legacy vocabulary")
            }
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

/// Produce the legacy [`DisplayList`] for the FillRect vocabulary, so existing
/// W002/golden infrastructure and the immediate fallback keep working. Errors on
/// any primitive outside that legacy subset.
pub fn flatten(scene: &Scene) -> Result<DisplayList, SceneError> {
    let mut list = DisplayList::new(scene.surface);
    flatten_node(scene, scene.root, Affine::IDENTITY, &mut list)?;
    Ok(list)
}

fn flatten_node(
    scene: &Scene,
    id: NodeId,
    parent_xf: Affine,
    list: &mut DisplayList,
) -> Result<(), SceneError> {
    let Some(node) = scene.get(id) else {
        return Ok(());
    };
    if !node.visible {
        return Ok(());
    }
    let xf = parent_xf.compose(node.transform);
    for prim in &node.prims {
        match prim {
            Prim::FillRect {
                rect,
                paint: Paint::Solid(color),
            } => {
                if let Some(rect) = rect_to_device(xf.apply_rect(*rect)) {
                    list.commands.push(DisplayCommand::FillRect {
                        rect,
                        color: *color,
                    });
                }
            }
            _ => return Err(SceneError::FlattenUnsupportedPrim),
        }
    }
    for child in &node.children {
        flatten_node(scene, *child, xf, list)?;
    }
    Ok(())
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

/// Deterministic headless rasterizer (the reference oracle). Rasterizes the
/// geometric subset needed today (FillRect fully; StrokeRect/Line/DrawEdge as thin
/// fills); text/image/curved fills are recorded by the contract and rasterized by
/// the visible backend / a later reference-rasterizer step.
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
            Prim::DrawEdge {
                rect,
                effect,
                shadow,
                light,
                ..
            } => {
                // Placeholder edge: a single-color outline. The exact raised/sunken
                // light/shadow composition lands with the control parity gate.
                let color = match effect {
                    EdgeEffect::Flat => *shadow,
                    _ => *light,
                };
                self.stroke_border(
                    *rect,
                    &Stroke {
                        paint: Paint::Solid(color),
                        width: 1.0,
                    },
                );
            }
            // Lines, curved fills, text, and images are part of the contract and
            // content hash; the headless reference rasterizes them in a later step.
            _ => {}
        }
    }
}

/// Stable diagnostics from rendering a [`Scene`] through the headless reference.
/// Mirrors [`crate::RenderDiagnostics`] so the Scene seam reports the same shape
/// the W002 `SmokeCanvas` did.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct SceneRenderReport {
    pub width: u32,
    pub height: u32,
    pub command_count: usize,
    pub framebuffer_hash: u64,
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
    use crate::{w002_rectangle_fixture_diagnostics, w002_rectangle_fixture_display_list};

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

    #[test]
    fn render_full_reproduces_the_w002_framebuffer_hash() {
        let scene = w002_scene();
        assert_eq!(
            render_headless_hash(&scene),
            w002_rectangle_fixture_diagnostics().framebuffer_hash,
            "scene render must reproduce the historical W002 framebuffer hash"
        );
    }

    #[test]
    fn flatten_reproduces_the_w002_display_list() {
        let scene = w002_scene();
        assert_eq!(
            flatten(&scene).expect("FillRect-only scene flattens"),
            w002_rectangle_fixture_display_list(),
            "flatten must byte-match the legacy immediate display list (invariant a)"
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
        assert_eq!(
            render_headless_hash(&scene),
            w002_rectangle_fixture_diagnostics().framebuffer_hash
        );

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
        assert_eq!(
            report.framebuffer_hash,
            w002_rectangle_fixture_diagnostics().framebuffer_hash
        );
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
