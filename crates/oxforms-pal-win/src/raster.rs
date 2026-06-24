//! tiny-skia rasterizer for the Scene primitive vocabulary.
//!
//! [`SkiaSink`] implements [`oxforms_pal::scene::PrimSink`]: the Scene kernel walks
//! the retained tree, pushing transforms/clips and the §6.2 primitives, and this sink
//! turns them into pixels in a `tiny_skia::Pixmap`. It is the *visible* counterpart to
//! the text-free [`oxforms_pal::scene::HeadlessSink`] golden oracle — same walk, same
//! geometry, but with curved fills, gradients, 3D edges, and ab_glyph text actually
//! rasterized.
//!
//! Geometry is transformed to device space by the sink (mirroring `HeadlessSink`'s
//! `cur`/`clip` stacks) and handed to tiny-skia with an identity transform, so clips —
//! always axis-aligned in v1 — live in device space as a single rect/`Mask`. Text is
//! composited per-pixel against that device clip rect (no `Mask` needed). An ambient
//! *device transform* (physical-pixels ÷ logical-surface) is the sink's initial `cur`,
//! so a 200×120-pt form fills a 600×360-px window crisply.

use ab_glyph::{point as ab_point, Font, PxScale, ScaleFont};
use oxforms_pal::scene::{
    render_full, Affine, EdgeBorder, EdgeEffect, Paint, Prim, PrimSink, RectF, Scene, Stroke,
    TextAlign, TextFlags, TextRunId,
};
use oxforms_pal::Color;
use tiny_skia as ts;

use crate::text::TextResolver;

/// 4-cubic circle/ellipse approximation constant.
const KAPPA: f32 = 0.552_284_8;

/// Render a whole scene into `pixmap`, scaling the logical surface into the
/// (physical-pixel) pixmap. Clears to opaque white first; the scene root is expected
/// to paint the form background over it.
///
/// The ambient device transform is a **uniform** scale (`min(width-fit, height-fit)`),
/// top-left anchored. The Scene `Affine` is translate + uniform-scale in v1 (see
/// `scene::Affine` / `RENDERING_ARCHITECTURE.md`), so deriving an anisotropic device
/// scale here would feed the rest of the pipeline a transform it does not model
/// (round-rect radii and edge/stroke thickness are scalar-scaled). Uniform fit keeps
/// the form's aspect ratio on any window size; if the pixmap aspect differs from the
/// surface, the unused margin shows the white clear.
pub fn render_scene_to_pixmap(scene: &Scene, pixmap: &mut ts::Pixmap, resolver: &dyn TextResolver) {
    pixmap.fill(ts::Color::WHITE);
    let fit_x = pixmap.width() as f32 / (scene.surface.width.max(1) as f32);
    let fit_y = pixmap.height() as f32 / (scene.surface.height.max(1) as f32);
    let scale = fit_x.min(fit_y);
    let device = Affine {
        sx: scale,
        sy: scale,
        tx: 0.0,
        ty: 0.0,
    };
    let mut sink = SkiaSink::new(pixmap, device, resolver);
    render_full(scene, &mut sink);
}

/// A `PrimSink` that paints into a borrowed `tiny_skia::Pixmap`.
pub struct SkiaSink<'a> {
    pixmap: &'a mut ts::Pixmap,
    resolver: &'a dyn TextResolver,
    surface_w: f32,
    surface_h: f32,
    cur: Affine,
    xf_stack: Vec<Affine>,
    /// Current clip in device space (intersection of all active clips).
    clip: RectF,
    clip_stack: Vec<RectF>,
    /// Memoized device-space clip mask; `None` once built means "clip is the whole
    /// surface, no masking needed". `mask_dirty` forces a rebuild after a clip change.
    clip_mask: Option<ts::Mask>,
    mask_dirty: bool,
}

impl<'a> SkiaSink<'a> {
    #[must_use]
    pub fn new(pixmap: &'a mut ts::Pixmap, device: Affine, resolver: &'a dyn TextResolver) -> Self {
        let surface_w = pixmap.width() as f32;
        let surface_h = pixmap.height() as f32;
        Self {
            pixmap,
            resolver,
            surface_w,
            surface_h,
            cur: device,
            xf_stack: Vec::new(),
            clip: RectF::new(0.0, 0.0, surface_w, surface_h),
            clip_stack: Vec::new(),
            clip_mask: None,
            mask_dirty: false,
        }
    }

    /// Device scale for scalar quantities (stroke width, edge thickness, glyph px).
    /// The ambient transform is uniform (see `render_scene_to_pixmap`), so `sx == sy`
    /// and this average is exact; the mean is a safe fallback if that ever changes.
    fn scale(&self) -> f32 {
        (self.cur.sx.abs() + self.cur.sy.abs()) * 0.5
    }

    /// True when the active clip is the whole surface (no masking needed).
    fn clip_is_full(&self) -> bool {
        self.clip.x <= 0.0
            && self.clip.y <= 0.0
            && self.clip.x + self.clip.w >= self.surface_w
            && self.clip.y + self.clip.h >= self.surface_h
    }

    /// Rebuild the device clip mask if a clip change invalidated it. After this,
    /// `self.clip_mask` is the mask to pass (or `None` for the full surface).
    ///
    /// An *empty* clip never reaches a real draw: [`PrimSink::draw`] short-circuits the
    /// whole node when `self.clip.is_empty()`, matching `HeadlessSink` (which suppresses
    /// via clip intersection). So `None` here unambiguously means "full surface, no
    /// masking" — it is never "empty clip, paint everywhere".
    fn ensure_mask(&mut self) {
        if !self.mask_dirty {
            return;
        }
        self.mask_dirty = false;
        if self.clip_is_full() || self.clip.is_empty() {
            self.clip_mask = None;
            return;
        }
        let (w, h) = (self.pixmap.width(), self.pixmap.height());
        let Some(mut mask) = ts::Mask::new(w, h) else {
            self.clip_mask = None;
            return;
        };
        if let Some(rect) = ts::Rect::from_xywh(self.clip.x, self.clip.y, self.clip.w, self.clip.h)
        {
            let mut pb = ts::PathBuilder::new();
            pb.push_rect(rect);
            if let Some(path) = pb.finish() {
                mask.fill_path(
                    &path,
                    ts::FillRule::Winding,
                    false,
                    ts::Transform::identity(),
                );
                self.clip_mask = Some(mask);
                return;
            }
        }
        self.clip_mask = None;
    }

    fn dev_point(&self, x: f32, y: f32) -> (f32, f32) {
        (x * self.cur.sx + self.cur.tx, y * self.cur.sy + self.cur.ty)
    }

    /// A solid `tiny_skia::Paint` for a paint, falling back to a representative solid
    /// for gradients when no usable gradient line exists. `dev_rect` bounds gradients.
    fn build_paint(
        &self,
        paint: &Paint,
        dev_rect: RectF,
        anti_alias: bool,
    ) -> Option<ts::Paint<'a>> {
        let mut p = ts::Paint {
            anti_alias,
            ..ts::Paint::default()
        };
        match paint {
            Paint::Solid(c) => {
                p.set_color(sk_color(*c));
                Some(p)
            }
            Paint::LinearGradient { stops, angle } => {
                if let Some(shader) = linear_gradient(dev_rect, stops, *angle) {
                    p.shader = shader;
                    Some(p)
                } else {
                    let c = stops.first().map(|(_, c)| *c)?;
                    p.set_color(sk_color(c));
                    Some(p)
                }
            }
        }
    }

    fn fill_device_rect(&mut self, dev: RectF, paint: &Paint, anti_alias: bool) {
        let Some(rect) = ts::Rect::from_xywh(dev.x, dev.y, dev.w, dev.h) else {
            return;
        };
        let Some(p) = self.build_paint(paint, dev, anti_alias) else {
            return;
        };
        self.ensure_mask();
        let mask = self.clip_mask.as_ref();
        self.pixmap
            .fill_rect(rect, &p, ts::Transform::identity(), mask);
    }

    /// Fill a solid device rect (helper for edges/strokes), AA off for crisp pixels.
    fn fill_solid_device(&mut self, dev: RectF, color: Color) {
        self.fill_device_rect(dev, &Paint::Solid(color), false);
    }

    fn fill_and_stroke_path(
        &mut self,
        path: &ts::Path,
        dev_rect: RectF,
        fill: Option<&Paint>,
        stroke: Option<&Stroke>,
    ) {
        self.ensure_mask();
        if let Some(fill) = fill {
            if let Some(p) = self.build_paint(fill, dev_rect, true) {
                let mask = self.clip_mask.as_ref();
                self.pixmap.fill_path(
                    path,
                    &p,
                    ts::FillRule::Winding,
                    ts::Transform::identity(),
                    mask,
                );
            }
        }
        if let Some(stroke) = stroke {
            if let Some(p) = self.build_paint(&stroke.paint, dev_rect, true) {
                let sk_stroke = ts::Stroke {
                    width: (stroke.width * self.scale()).max(1.0),
                    ..ts::Stroke::default()
                };
                let mask = self.clip_mask.as_ref();
                self.pixmap
                    .stroke_path(path, &p, &sk_stroke, ts::Transform::identity(), mask);
            }
        }
    }

    fn draw_edge(
        &mut self,
        local: RectF,
        effect: EdgeEffect,
        border: EdgeBorder,
        light: Color,
        shadow: Color,
    ) {
        let dev = self.cur.apply_rect(local);
        let t = self.scale().max(1.0);
        match effect {
            EdgeEffect::Flat => self.edge_pass(dev, border, t, shadow, shadow),
            EdgeEffect::Raised => self.edge_pass(dev, border, t, light, shadow),
            EdgeEffect::Sunken => self.edge_pass(dev, border, t, shadow, light),
            EdgeEffect::Etched => {
                // Outer shadow/light, inner light/shadow (GDI EDGE_ETCHED).
                self.edge_pass(dev, border, t, shadow, light);
                self.edge_pass(inset(dev, t), border, t, light, shadow);
            }
            EdgeEffect::Bump => {
                self.edge_pass(dev, border, t, light, shadow);
                self.edge_pass(inset(dev, t), border, t, shadow, light);
            }
        }
    }

    /// Paint one edge frame: `tl` on the top/left edges, `br` on the bottom/right.
    fn edge_pass(&mut self, dev: RectF, border: EdgeBorder, t: f32, tl: Color, br: Color) {
        if dev.w <= 0.0 || dev.h <= 0.0 {
            return;
        }
        if border.top {
            self.fill_solid_device(RectF::new(dev.x, dev.y, dev.w, t), tl);
        }
        if border.left {
            self.fill_solid_device(RectF::new(dev.x, dev.y, t, dev.h), tl);
        }
        if border.bottom {
            self.fill_solid_device(RectF::new(dev.x, dev.y + dev.h - t, dev.w, t), br);
        }
        if border.right {
            self.fill_solid_device(RectF::new(dev.x + dev.w - t, dev.y, t, dev.h), br);
        }
    }

    /// Lay out and composite a single line of text. v1 is single-line: the `wrap`
    /// flag is carried by the contract (and content hash) but multi-line wrapping is
    /// not yet implemented — the demo controls are single-line. Vertical centering and
    /// left/center/right horizontal alignment are honored.
    fn draw_text(
        &mut self,
        run: TextRunId,
        local_rect: RectF,
        align: TextAlign,
        clip: bool,
        paint: &Paint,
        flags: TextFlags,
    ) {
        let Some(resolved) = self.resolver.resolve(run) else {
            return;
        };
        let Some(font) = self.resolver.font(resolved.font) else {
            return;
        };
        let color = match paint {
            Paint::Solid(c) => *c,
            Paint::LinearGradient { stops, .. } => match stops.first() {
                Some((_, c)) => *c,
                None => return,
            },
        };

        let dev_rect = self.cur.apply_rect(local_rect);
        let scale = PxScale {
            x: (resolved.px * self.cur.sx.abs()).max(1.0),
            y: (resolved.px * self.cur.sy.abs()).max(1.0),
        };
        let scaled = font.as_scaled(scale);

        // Measure (advance + kerning) for horizontal alignment.
        let mut text_w = 0.0_f32;
        let mut prev: Option<ab_glyph::GlyphId> = None;
        for ch in resolved.text.chars() {
            let gid = font.glyph_id(ch);
            if let Some(p) = prev {
                text_w += scaled.kern(p, gid);
            }
            text_w += scaled.h_advance(gid);
            prev = Some(gid);
        }

        let pen_start = match align {
            TextAlign::Left => dev_rect.x,
            TextAlign::Center => dev_rect.x + (dev_rect.w - text_w) * 0.5,
            TextAlign::Right => dev_rect.x + dev_rect.w - text_w,
        };
        let line_h = scaled.ascent() - scaled.descent();
        let baseline = dev_rect.y + (dev_rect.h - line_h) * 0.5 + scaled.ascent();

        // Device clip rect for compositing: the active clip, optionally ∩ this rect.
        // Round all four edges to the nearest pixel so the text clip boundary matches
        // the fill/stroke `Mask` (built with anti_alias = false, i.e. pixel-center
        // sampling == the round rule). floor/ceil here would round the clip outward by
        // up to a pixel and let clipped glyphs leak past where a fill is cut.
        let clip_rect = if clip {
            self.clip.intersect(dev_rect)
        } else {
            self.clip
        };
        let (cl, ct, cr, cb) = (
            clip_rect.x.round() as i32,
            clip_rect.y.round() as i32,
            (clip_rect.x + clip_rect.w).round() as i32,
            (clip_rect.y + clip_rect.h).round() as i32,
        );

        let stride = self.pixmap.width() as i32;
        let surf_w = self.pixmap.width() as i32;
        let surf_h = self.pixmap.height() as i32;
        let data = self.pixmap.data_mut();

        let mut pen_x = pen_start;
        let mut prev: Option<ab_glyph::GlyphId> = None;
        let mut accel_underline: Option<(f32, f32)> = None;
        for (byte_idx, ch) in resolved.text.char_indices() {
            let gid = font.glyph_id(ch);
            if let Some(p) = prev {
                pen_x += scaled.kern(p, gid);
            }
            let advance = scaled.h_advance(gid);
            if flags.underline_accelerator && resolved.accelerator == Some(byte_idx) {
                accel_underline = Some((pen_x, pen_x + advance));
            }
            let glyph = gid.with_scale_and_position(scale, ab_point(pen_x, baseline));
            if let Some(outline) = font.outline_glyph(glyph) {
                let bb = outline.px_bounds();
                let ox = bb.min.x;
                let oy = bb.min.y;
                outline.draw(|gx, gy, cov| {
                    let px = ox as i32 + gx as i32;
                    let py = oy as i32 + gy as i32;
                    blend_pixel(
                        data, stride, surf_w, surf_h, px, py, color, cov, cl, ct, cr, cb,
                    );
                });
            }
            pen_x += advance;
            prev = Some(gid);
        }

        if let Some((x0, x1)) = accel_underline {
            let uy = (baseline + 1.0).round() as i32;
            for px in (x0.round() as i32)..(x1.round() as i32) {
                blend_pixel(
                    data, stride, surf_w, surf_h, px, uy, color, 1.0, cl, ct, cr, cb,
                );
            }
        }
    }
}

impl PrimSink for SkiaSink<'_> {
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
        self.mask_dirty = true;
    }

    fn pop_clip(&mut self) {
        if let Some(prev) = self.clip_stack.pop() {
            self.clip = prev;
            self.mask_dirty = true;
        }
    }

    fn draw(&mut self, prim: &Prim) {
        // An empty active clip suppresses the whole node — nothing it paints can be
        // visible. This matches `HeadlessSink` (which draws nothing once the clip
        // intersection is empty) and covers every primitive uniformly, so fills/paths/
        // edges cannot leak across the surface on a degenerate/non-overlapping clip.
        if self.clip.is_empty() {
            return;
        }
        match prim {
            Prim::FillRect { rect, paint } => {
                let dev = self.cur.apply_rect(*rect);
                self.fill_device_rect(dev, paint, false);
            }
            Prim::StrokeRect { rect, stroke } => {
                let dev = self.cur.apply_rect(*rect);
                if let Some(r) = ts::Rect::from_xywh(dev.x, dev.y, dev.w, dev.h) {
                    let mut pb = ts::PathBuilder::new();
                    pb.push_rect(r);
                    if let Some(path) = pb.finish() {
                        self.fill_and_stroke_path(&path, dev, None, Some(stroke));
                    }
                }
            }
            Prim::RoundRect {
                rect,
                radius,
                fill,
                stroke,
            } => {
                let dev = self.cur.apply_rect(*rect);
                if let Some(path) = round_rect_path(dev, *radius * self.scale()) {
                    self.fill_and_stroke_path(&path, dev, fill.as_ref(), stroke.as_ref());
                }
            }
            Prim::Ellipse { rect, fill, stroke } => {
                let dev = self.cur.apply_rect(*rect);
                if let Some(path) = ellipse_path(dev) {
                    self.fill_and_stroke_path(&path, dev, fill.as_ref(), stroke.as_ref());
                }
            }
            Prim::Line { a, b, stroke } => {
                let (ax, ay) = self.dev_point(a.x, a.y);
                let (bx, by) = self.dev_point(b.x, b.y);
                let mut pb = ts::PathBuilder::new();
                pb.move_to(ax, ay);
                pb.line_to(bx, by);
                if let Some(path) = pb.finish() {
                    let bounds =
                        RectF::new(ax.min(bx), ay.min(by), (ax - bx).abs(), (ay - by).abs());
                    self.fill_and_stroke_path(&path, bounds, None, Some(stroke));
                }
            }
            Prim::Polygon { pts, fill, stroke } => {
                if pts.len() < 2 {
                    return;
                }
                let mut pb = ts::PathBuilder::new();
                let (mut minx, mut miny, mut maxx, mut maxy) =
                    (f32::MAX, f32::MAX, f32::MIN, f32::MIN);
                for (i, p) in pts.iter().enumerate() {
                    let (x, y) = self.dev_point(p.x, p.y);
                    minx = minx.min(x);
                    miny = miny.min(y);
                    maxx = maxx.max(x);
                    maxy = maxy.max(y);
                    if i == 0 {
                        pb.move_to(x, y);
                    } else {
                        pb.line_to(x, y);
                    }
                }
                pb.close();
                if let Some(path) = pb.finish() {
                    let bounds = RectF::new(minx, miny, maxx - minx, maxy - miny);
                    self.fill_and_stroke_path(&path, bounds, fill.as_ref(), stroke.as_ref());
                }
            }
            Prim::Gradient { rect, stops, angle } => {
                let dev = self.cur.apply_rect(*rect);
                self.fill_device_rect(
                    dev,
                    &Paint::LinearGradient {
                        stops: stops.clone(),
                        angle: *angle,
                    },
                    false,
                );
            }
            Prim::DrawText {
                run,
                rect,
                align,
                wrap: _,
                clip,
                paint,
                flags,
            } => {
                self.draw_text(*run, *rect, *align, *clip, paint, *flags);
            }
            Prim::DrawEdge {
                rect,
                effect,
                border,
                light,
                shadow,
            } => {
                self.draw_edge(*rect, *effect, *border, *light, *shadow);
            }
            // Images are part of the contract but unused by the W007 slice; the demo
            // form carries no DrawImage. Decoding lands when a control needs it.
            Prim::DrawImage { .. } => {}
        }
    }
}

fn sk_color(c: Color) -> ts::Color {
    ts::Color::from_rgba8(c.red, c.green, c.blue, c.alpha)
}

fn inset(r: RectF, by: f32) -> RectF {
    RectF::new(
        r.x + by,
        r.y + by,
        (r.w - 2.0 * by).max(0.0),
        (r.h - 2.0 * by).max(0.0),
    )
}

fn linear_gradient(
    dev_rect: RectF,
    stops: &[(f32, Color)],
    angle: f32,
) -> Option<ts::Shader<'static>> {
    if stops.len() < 2 || dev_rect.is_empty() {
        return None;
    }
    let cx = dev_rect.x + dev_rect.w * 0.5;
    let cy = dev_rect.y + dev_rect.h * 0.5;
    let (dx, dy) = (angle.cos(), angle.sin());
    let half = (dev_rect.w.abs() * dx.abs() + dev_rect.h.abs() * dy.abs()) * 0.5;
    let start = ts::Point::from_xy(cx - dx * half, cy - dy * half);
    let end = ts::Point::from_xy(cx + dx * half, cy + dy * half);
    let sk_stops: Vec<ts::GradientStop> = stops
        .iter()
        .map(|(pos, c)| ts::GradientStop::new(*pos, sk_color(*c)))
        .collect();
    ts::LinearGradient::new(
        start,
        end,
        sk_stops,
        ts::SpreadMode::Pad,
        ts::Transform::identity(),
    )
}

fn round_rect_path(r: RectF, radius: f32) -> Option<ts::Path> {
    if r.w <= 0.0 || r.h <= 0.0 {
        return None;
    }
    let rad = radius.clamp(0.0, r.w.min(r.h) * 0.5);
    if rad <= 0.0 {
        let rect = ts::Rect::from_xywh(r.x, r.y, r.w, r.h)?;
        let mut pb = ts::PathBuilder::new();
        pb.push_rect(rect);
        return pb.finish();
    }
    let (x, y, w, h) = (r.x, r.y, r.w, r.h);
    let mut pb = ts::PathBuilder::new();
    pb.move_to(x + rad, y);
    pb.line_to(x + w - rad, y);
    pb.quad_to(x + w, y, x + w, y + rad);
    pb.line_to(x + w, y + h - rad);
    pb.quad_to(x + w, y + h, x + w - rad, y + h);
    pb.line_to(x + rad, y + h);
    pb.quad_to(x, y + h, x, y + h - rad);
    pb.line_to(x, y + rad);
    pb.quad_to(x, y, x + rad, y);
    pb.close();
    pb.finish()
}

fn ellipse_path(r: RectF) -> Option<ts::Path> {
    if r.w <= 0.0 || r.h <= 0.0 {
        return None;
    }
    let (rx, ry) = (r.w * 0.5, r.h * 0.5);
    let (cx, cy) = (r.x + rx, r.y + ry);
    let (kx, ky) = (rx * KAPPA, ry * KAPPA);
    let mut pb = ts::PathBuilder::new();
    pb.move_to(cx + rx, cy);
    pb.cubic_to(cx + rx, cy + ky, cx + kx, cy + ry, cx, cy + ry);
    pb.cubic_to(cx - kx, cy + ry, cx - rx, cy + ky, cx - rx, cy);
    pb.cubic_to(cx - rx, cy - ky, cx - kx, cy - ry, cx, cy - ry);
    pb.cubic_to(cx + kx, cy - ry, cx + rx, cy - ky, cx + rx, cy);
    pb.close();
    pb.finish()
}

/// Blend a straight-alpha color over an opaque device pixel at `cov` coverage,
/// inside both the surface and the integer device clip box. Output alpha stays 255
/// (the window is opaque), so premultiplied == straight and the store is exact.
#[allow(clippy::too_many_arguments)]
fn blend_pixel(
    data: &mut [u8],
    stride: i32,
    surf_w: i32,
    surf_h: i32,
    x: i32,
    y: i32,
    color: Color,
    cov: f32,
    cl: i32,
    ct: i32,
    cr: i32,
    cb: i32,
) {
    if x < 0 || y < 0 || x >= surf_w || y >= surf_h {
        return;
    }
    if x < cl || x >= cr || y < ct || y >= cb {
        return;
    }
    let a = (cov * (color.alpha as f32 / 255.0)).clamp(0.0, 1.0);
    if a <= 0.0 {
        return;
    }
    let off = ((y * stride + x) * 4) as usize;
    data[off] = lerp_u8(data[off], color.red, a);
    data[off + 1] = lerp_u8(data[off + 1], color.green, a);
    data[off + 2] = lerp_u8(data[off + 2], color.blue, a);
    data[off + 3] = 255;
}

fn lerp_u8(dst: u8, src: u8, a: f32) -> u8 {
    (src as f32 * a + dst as f32 * (1.0 - a))
        .round()
        .clamp(0.0, 255.0) as u8
}

#[cfg(test)]
mod tests {
    use super::*;
    use oxforms_pal::scene::{
        render_full, FontId, HeadlessSink, NodeId, Paint, PointF, RectF, Scene, SceneNode,
        TextRunId,
    };
    use oxforms_pal::{DpiScale, SurfaceSize};

    use crate::text::{ResolvedTextRun, TextRegistry};

    fn dpi() -> DpiScale {
        DpiScale::new(96.0, 96.0)
    }

    /// Dependency-free FNV-1a (oxforms-pal's is pub(crate)); for golden hashing.
    fn fnv1a64(bytes: &[u8]) -> u64 {
        bytes.iter().fold(0xcbf2_9ce4_8422_2325_u64, |h, b| {
            (h ^ u64::from(*b)).wrapping_mul(0x0000_0100_0000_01b3)
        })
    }

    fn pixel(pixmap: &ts::Pixmap, x: u32, y: u32) -> [u8; 4] {
        let stride = pixmap.width() as usize;
        let off = ((y as usize * stride) + x as usize) * 4;
        let d = pixmap.data();
        [d[off], d[off + 1], d[off + 2], d[off + 3]]
    }

    /// A scene whose root fills the surface blue and paints a red rect in the middle.
    fn two_rect_scene() -> Scene {
        let mut scene = Scene::new(SurfaceSize::new(20, 20), dpi(), NodeId(0));
        let mut root = SceneNode::new(NodeId(0));
        root.bounds = RectF::new(0.0, 0.0, 20.0, 20.0);
        root.prims = vec![
            Prim::FillRect {
                rect: RectF::new(0.0, 0.0, 20.0, 20.0),
                paint: Paint::Solid(Color::rgba(0, 0, 0xFF, 0xFF)),
            },
            Prim::FillRect {
                rect: RectF::new(5.0, 5.0, 10.0, 10.0),
                paint: Paint::Solid(Color::rgba(0xFF, 0, 0, 0xFF)),
            },
        ];
        scene.nodes.push(root);
        scene.recompute_frame_hash();
        scene
    }

    #[test]
    fn fills_paint_in_device_space_at_unit_scale() {
        let scene = two_rect_scene();
        let mut pixmap = ts::Pixmap::new(20, 20).expect("pixmap");
        let reg = TextRegistry::new();
        render_scene_to_pixmap(&scene, &mut pixmap, &reg);

        // Corner is the blue background; center is the red rect.
        assert_eq!(pixel(&pixmap, 0, 0), [0, 0, 0xFF, 0xFF]);
        assert_eq!(pixel(&pixmap, 10, 10), [0xFF, 0, 0, 0xFF]);
        // Just outside the red rect (x=4) is still blue.
        assert_eq!(pixel(&pixmap, 4, 10), [0, 0, 0xFF, 0xFF]);
    }

    #[test]
    fn ambient_device_scale_maps_logical_to_physical() {
        // 20x20 logical scene into a 40x40 pixmap: the red rect [5,15) scales to
        // [10,30), so device pixel (20,20) is red and (8,8) is background.
        let scene = two_rect_scene();
        let mut pixmap = ts::Pixmap::new(40, 40).expect("pixmap");
        let reg = TextRegistry::new();
        render_scene_to_pixmap(&scene, &mut pixmap, &reg);
        assert_eq!(pixel(&pixmap, 20, 20), [0xFF, 0, 0, 0xFF]);
        assert_eq!(pixel(&pixmap, 8, 8), [0, 0, 0xFF, 0xFF]);
    }

    #[test]
    fn raised_edge_paints_light_top_left_and_shadow_bottom_right() {
        let mut scene = Scene::new(SurfaceSize::new(10, 10), dpi(), NodeId(0));
        let mut root = SceneNode::new(NodeId(0));
        root.bounds = RectF::new(0.0, 0.0, 10.0, 10.0);
        root.prims = vec![
            Prim::FillRect {
                rect: RectF::new(0.0, 0.0, 10.0, 10.0),
                paint: Paint::Solid(Color::rgba(0xC0, 0xC0, 0xC0, 0xFF)),
            },
            Prim::DrawEdge {
                rect: RectF::new(0.0, 0.0, 10.0, 10.0),
                effect: EdgeEffect::Raised,
                border: EdgeBorder::ALL,
                light: Color::rgba(0xFF, 0xFF, 0xFF, 0xFF),
                shadow: Color::rgba(0x40, 0x40, 0x40, 0xFF),
            },
        ];
        scene.nodes.push(root);
        scene.recompute_frame_hash();

        let mut pixmap = ts::Pixmap::new(10, 10).expect("pixmap");
        let reg = TextRegistry::new();
        render_scene_to_pixmap(&scene, &mut pixmap, &reg);

        assert_eq!(
            pixel(&pixmap, 0, 0),
            [0xFF, 0xFF, 0xFF, 0xFF],
            "top-left light"
        );
        assert_eq!(
            pixel(&pixmap, 9, 9),
            [0x40, 0x40, 0x40, 0xFF],
            "bottom-right shadow"
        );
    }

    #[test]
    fn clip_confines_a_fill_to_the_clip_rect() {
        // Root clips to the left half; a full-surface red fill must not cross x>=10.
        let mut scene = Scene::new(SurfaceSize::new(20, 20), dpi(), NodeId(0));
        let mut root = SceneNode::new(NodeId(0));
        root.bounds = RectF::new(0.0, 0.0, 20.0, 20.0);
        root.clip = Some(RectF::new(0.0, 0.0, 10.0, 20.0));
        root.prims = vec![Prim::FillRect {
            rect: RectF::new(0.0, 0.0, 20.0, 20.0),
            paint: Paint::Solid(Color::rgba(0xFF, 0, 0, 0xFF)),
        }];
        scene.nodes.push(root);
        scene.recompute_frame_hash();

        let mut pixmap = ts::Pixmap::new(20, 20).expect("pixmap");
        let reg = TextRegistry::new();
        render_scene_to_pixmap(&scene, &mut pixmap, &reg);

        assert_eq!(
            pixel(&pixmap, 2, 10),
            [0xFF, 0, 0, 0xFF],
            "inside clip is red"
        );
        assert_eq!(
            pixel(&pixmap, 15, 10),
            [0xFF, 0xFF, 0xFF, 0xFF],
            "outside clip stays base"
        );
    }

    #[test]
    fn text_draws_glyph_coverage_when_a_font_is_available() {
        // On Windows the UI font must load (honest skip only off-Windows).
        let Some(font) = crate::text::host_font_or_skip() else {
            return;
        };
        let mut reg = TextRegistry::new();
        reg.add_font(FontId(1), font);
        reg.add_run(TextRunId(1), ResolvedTextRun::new("OK", FontId(1), 24.0));

        let mut scene = Scene::new(SurfaceSize::new(80, 40), dpi(), NodeId(0));
        let mut root = SceneNode::new(NodeId(0));
        root.bounds = RectF::new(0.0, 0.0, 80.0, 40.0);
        root.prims = vec![
            Prim::FillRect {
                rect: RectF::new(0.0, 0.0, 80.0, 40.0),
                paint: Paint::Solid(Color::rgba(0xFF, 0xFF, 0xFF, 0xFF)),
            },
            Prim::DrawText {
                run: TextRunId(1),
                rect: RectF::new(0.0, 0.0, 80.0, 40.0),
                align: TextAlign::Center,
                wrap: false,
                clip: true,
                paint: Paint::Solid(Color::rgba(0, 0, 0, 0xFF)),
                flags: TextFlags::default(),
            },
        ];
        scene.nodes.push(root);
        scene.recompute_frame_hash();

        let mut pixmap = ts::Pixmap::new(80, 40).expect("pixmap");
        render_scene_to_pixmap(&scene, &mut pixmap, &reg);

        // At least some near-black pixels exist (glyphs actually rasterized).
        let dark = dark_pixels(&pixmap);
        assert!(dark > 0, "expected rasterized glyph coverage, found none");
    }

    fn dark_pixels(pixmap: &ts::Pixmap) -> usize {
        pixmap
            .data()
            .chunks_exact(4)
            .filter(|p| p[0] < 0x40 && p[1] < 0x40 && p[2] < 0x40 && p[3] == 0xFF)
            .count()
    }

    /// A single-node scene exercising every geometry primitive + all five edge
    /// effects (no text, so it is host-independent and deterministic).
    fn geometry_showcase_scene() -> Scene {
        let mut scene = Scene::new(SurfaceSize::new(64, 48), dpi(), NodeId(0));
        let mut root = SceneNode::new(NodeId(0));
        root.bounds = RectF::new(0.0, 0.0, 64.0, 48.0);
        let black = Stroke {
            paint: Paint::Solid(Color::rgba(0, 0, 0, 0xFF)),
            width: 1.0,
        };
        root.prims = vec![
            Prim::FillRect {
                rect: RectF::new(0.0, 0.0, 64.0, 48.0),
                paint: Paint::Solid(Color::rgba(0xC0, 0xC0, 0xC0, 0xFF)),
            },
            Prim::StrokeRect {
                rect: RectF::new(2.0, 2.0, 18.0, 10.0),
                stroke: black.clone(),
            },
            Prim::RoundRect {
                rect: RectF::new(24.0, 2.0, 18.0, 10.0),
                radius: 4.0,
                fill: Some(Paint::Solid(Color::rgba(0x20, 0x40, 0xC0, 0xFF))),
                stroke: Some(black.clone()),
            },
            Prim::Ellipse {
                rect: RectF::new(46.0, 2.0, 16.0, 10.0),
                fill: Some(Paint::Solid(Color::rgba(0x20, 0xA0, 0x20, 0xFF))),
                stroke: None,
            },
            Prim::Line {
                a: PointF::new(2.0, 16.0),
                b: PointF::new(62.0, 16.0),
                stroke: Stroke {
                    paint: Paint::Solid(Color::rgba(0xC0, 0x20, 0x20, 0xFF)),
                    width: 1.0,
                },
            },
            Prim::Polygon {
                pts: vec![
                    PointF::new(4.0, 30.0),
                    PointF::new(12.0, 20.0),
                    PointF::new(20.0, 30.0),
                ],
                fill: Some(Paint::Solid(Color::rgba(0xC0, 0x20, 0xC0, 0xFF))),
                stroke: None,
            },
            Prim::Gradient {
                rect: RectF::new(26.0, 20.0, 16.0, 12.0),
                stops: vec![
                    (0.0, Color::rgba(0, 0, 0, 0xFF)),
                    (1.0, Color::rgba(0xFF, 0xFF, 0xFF, 0xFF)),
                ],
                angle: 0.0,
            },
            edge_prim(RectF::new(2.0, 34.0, 12.0, 10.0), EdgeEffect::Raised),
            edge_prim(RectF::new(16.0, 34.0, 12.0, 10.0), EdgeEffect::Sunken),
            edge_prim(RectF::new(30.0, 34.0, 12.0, 10.0), EdgeEffect::Etched),
            edge_prim(RectF::new(44.0, 34.0, 12.0, 10.0), EdgeEffect::Bump),
            edge_prim(RectF::new(2.0, 44.0, 20.0, 3.0), EdgeEffect::Flat),
        ];
        scene.nodes.push(root);
        scene.recompute_frame_hash();
        scene
    }

    fn edge_prim(rect: RectF, effect: EdgeEffect) -> Prim {
        Prim::DrawEdge {
            rect,
            effect,
            border: EdgeBorder::ALL,
            light: Color::rgba(0xFF, 0xFF, 0xFF, 0xFF),
            shadow: Color::rgba(0x40, 0x40, 0x40, 0xFF),
        }
    }

    #[test]
    fn geometry_showcase_has_a_stable_golden_hash() {
        // Whole-frame golden for the deterministic, text-free geometry path: a shift,
        // recolor, or drop of any primitive across the surface changes this hash even
        // if the handful of spot-checked pixels in other tests stay put.
        let scene = geometry_showcase_scene();
        let mut pixmap = ts::Pixmap::new(64, 48).expect("pixmap");
        render_scene_to_pixmap(&scene, &mut pixmap, &TextRegistry::new());

        // Each colored primitive actually painted its color (so the hash is not merely
        // pinning an all-background frame): RoundRect blue, Ellipse green, Polygon
        // magenta, Line red.
        let count =
            |pred: fn(&[u8]) -> bool| pixmap.data().chunks_exact(4).filter(|p| pred(p)).count();
        assert!(
            count(|p| p[2] > 0xA0 && p[0] < 0x60) > 0,
            "round-rect blue fill present"
        );
        assert!(
            count(|p| p[1] > 0x80 && p[0] < 0x60 && p[2] < 0x60) > 0,
            "ellipse green fill present"
        );
        assert!(
            count(|p| p[0] > 0xA0 && p[2] > 0xA0 && p[1] < 0x60) > 0,
            "polygon magenta fill present"
        );
        // The 1px line is anti-aliased over the gray background, so detect its reddish
        // tint (g and b pulled below the gray) rather than full saturation.
        assert!(
            count(|p| p[0] > 0xA0 && p[1] < 0xA0 && p[2] < 0xA0) > 0,
            "line red present"
        );

        let hash = fnv1a64(pixmap.data());
        assert_eq!(
            hash, 0x612a_1114_73b1_1ab3,
            "geometry golden changed (got {hash:#018x}); update only after a deliberate render change"
        );
    }

    #[test]
    fn skia_matches_headless_oracle_for_opaque_fillrects() {
        // The crate's load-bearing claim: SkiaSink is the visible twin of HeadlessSink.
        // For an opaque, axis-aligned, integer-coordinate FillRect scene at unit device
        // scale the two rasterizers must agree pixel-for-pixel (both place edges on
        // integer pixel boundaries; the surface is fully covered so the differing clears
        // do not matter).
        let scene = two_rect_scene();
        let mut headless = HeadlessSink::new(scene.surface);
        render_full(&scene, &mut headless);
        let head = headless.into_pixels();

        let mut pixmap = ts::Pixmap::new(20, 20).expect("pixmap");
        render_scene_to_pixmap(&scene, &mut pixmap, &TextRegistry::new());

        assert_eq!(
            pixmap.data(),
            head.as_slice(),
            "SkiaSink must match the HeadlessSink golden for opaque integer fills"
        );
    }

    #[test]
    fn empty_clip_suppresses_all_drawing() {
        // A child clipped fully outside its parent's clip yields an empty clip; nothing
        // it paints may appear (mirrors HeadlessSink). Regression for the empty-clip
        // fail-open bug.
        let mut scene = Scene::new(SurfaceSize::new(20, 20), dpi(), NodeId(0));
        let mut root = SceneNode::new(NodeId(0));
        root.bounds = RectF::new(0.0, 0.0, 20.0, 20.0);
        root.clip = Some(RectF::new(0.0, 0.0, 20.0, 20.0));
        root.children = vec![NodeId(1)];
        let mut child = SceneNode::new(NodeId(1));
        child.parent = Some(NodeId(0));
        child.bounds = RectF::new(0.0, 0.0, 20.0, 20.0);
        child.clip = Some(RectF::new(50.0, 50.0, 5.0, 5.0)); // outside the root clip
        child.prims = vec![Prim::FillRect {
            rect: RectF::new(0.0, 0.0, 20.0, 20.0),
            paint: Paint::Solid(Color::rgba(0xFF, 0, 0, 0xFF)),
        }];
        scene.nodes = vec![root, child];
        scene.recompute_frame_hash();

        let mut pixmap = ts::Pixmap::new(20, 20).expect("pixmap");
        render_scene_to_pixmap(&scene, &mut pixmap, &TextRegistry::new());

        let red = pixmap
            .data()
            .chunks_exact(4)
            .filter(|p| p[0] == 0xFF && p[1] == 0 && p[2] == 0)
            .count();
        assert_eq!(
            red, 0,
            "empty clip must suppress the fill, not flood the surface"
        );
    }

    #[test]
    fn sunken_edge_paints_shadow_top_left_and_light_bottom_right() {
        // Sunken ships in the demo field; it must be the corner-swap of Raised.
        let mut scene = Scene::new(SurfaceSize::new(10, 10), dpi(), NodeId(0));
        let mut root = SceneNode::new(NodeId(0));
        root.bounds = RectF::new(0.0, 0.0, 10.0, 10.0);
        root.prims = vec![
            Prim::FillRect {
                rect: RectF::new(0.0, 0.0, 10.0, 10.0),
                paint: Paint::Solid(Color::rgba(0xC0, 0xC0, 0xC0, 0xFF)),
            },
            edge_prim(RectF::new(0.0, 0.0, 10.0, 10.0), EdgeEffect::Sunken),
        ];
        scene.nodes.push(root);
        scene.recompute_frame_hash();

        let mut pixmap = ts::Pixmap::new(10, 10).expect("pixmap");
        render_scene_to_pixmap(&scene, &mut pixmap, &TextRegistry::new());

        assert_eq!(
            pixel(&pixmap, 0, 0),
            [0x40, 0x40, 0x40, 0xFF],
            "top-left shadow"
        );
        assert_eq!(
            pixel(&pixmap, 9, 9),
            [0xFF, 0xFF, 0xFF, 0xFF],
            "bottom-right light"
        );
    }

    #[test]
    fn linear_gradient_runs_in_its_angle_direction() {
        // angle 0 == left→right: black at the left, white at the right.
        let mut scene = Scene::new(SurfaceSize::new(40, 10), dpi(), NodeId(0));
        let mut root = SceneNode::new(NodeId(0));
        root.bounds = RectF::new(0.0, 0.0, 40.0, 10.0);
        root.prims = vec![Prim::Gradient {
            rect: RectF::new(0.0, 0.0, 40.0, 10.0),
            stops: vec![
                (0.0, Color::rgba(0, 0, 0, 0xFF)),
                (1.0, Color::rgba(0xFF, 0xFF, 0xFF, 0xFF)),
            ],
            angle: 0.0,
        }];
        scene.nodes.push(root);
        scene.recompute_frame_hash();

        let mut pixmap = ts::Pixmap::new(40, 10).expect("pixmap");
        render_scene_to_pixmap(&scene, &mut pixmap, &TextRegistry::new());
        let left = pixel(&pixmap, 2, 5)[0];
        let right = pixel(&pixmap, 37, 5)[0];
        assert!(
            left < right,
            "gradient should darken toward the start: left={left} right={right}"
        );
    }

    #[test]
    fn degenerate_single_stop_gradient_falls_back_to_that_solid() {
        // A 1-stop LinearGradient has no gradient line; it must paint that stop's solid.
        let mut scene = Scene::new(SurfaceSize::new(10, 10), dpi(), NodeId(0));
        let mut root = SceneNode::new(NodeId(0));
        root.bounds = RectF::new(0.0, 0.0, 10.0, 10.0);
        root.prims = vec![Prim::FillRect {
            rect: RectF::new(0.0, 0.0, 10.0, 10.0),
            paint: Paint::LinearGradient {
                stops: vec![(0.0, Color::rgba(0x12, 0x34, 0x56, 0xFF))],
                angle: 0.0,
            },
        }];
        scene.nodes.push(root);
        scene.recompute_frame_hash();

        let mut pixmap = ts::Pixmap::new(10, 10).expect("pixmap");
        render_scene_to_pixmap(&scene, &mut pixmap, &TextRegistry::new());
        assert_eq!(pixel(&pixmap, 5, 5), [0x12, 0x34, 0x56, 0xFF]);
    }

    #[test]
    fn fractional_device_scale_places_geometry_and_survives_tiny_surfaces() {
        // 20×20 logical into 30×30 px → uniform scale 1.5; the red rect [5,15) maps to
        // [7.5,22.5). Interior/exterior pixels checked with margin (not edge-exact).
        let scene = two_rect_scene();
        let mut pixmap = ts::Pixmap::new(30, 30).expect("pixmap");
        render_scene_to_pixmap(&scene, &mut pixmap, &TextRegistry::new());
        assert_eq!(
            pixel(&pixmap, 15, 15),
            [0xFF, 0, 0, 0xFF],
            "interior is red"
        );
        assert_eq!(
            pixel(&pixmap, 2, 2),
            [0, 0, 0xFF, 0xFF],
            "exterior is background"
        );

        // A 1×1 surface must not panic (degenerate but valid).
        let mut tiny = ts::Pixmap::new(1, 1).expect("pixmap");
        render_scene_to_pixmap(&scene, &mut tiny, &TextRegistry::new());
    }

    #[test]
    fn accelerator_underline_adds_pixels_under_the_glyph() {
        let Some(font) = crate::text::host_font_or_skip() else {
            return;
        };
        let mut reg = TextRegistry::new();
        reg.add_font(FontId(1), font);
        reg.add_run(
            TextRunId(1),
            ResolvedTextRun::new("File", FontId(1), 24.0).with_accelerator(0),
        );

        let render = |underline: bool| {
            let mut scene = Scene::new(SurfaceSize::new(80, 40), dpi(), NodeId(0));
            let mut root = SceneNode::new(NodeId(0));
            root.bounds = RectF::new(0.0, 0.0, 80.0, 40.0);
            root.prims = vec![
                Prim::FillRect {
                    rect: RectF::new(0.0, 0.0, 80.0, 40.0),
                    paint: Paint::Solid(Color::rgba(0xFF, 0xFF, 0xFF, 0xFF)),
                },
                Prim::DrawText {
                    run: TextRunId(1),
                    rect: RectF::new(4.0, 0.0, 72.0, 40.0),
                    align: TextAlign::Left,
                    wrap: false,
                    clip: true,
                    paint: Paint::Solid(Color::rgba(0, 0, 0, 0xFF)),
                    flags: TextFlags {
                        underline_accelerator: underline,
                        disabled: false,
                    },
                },
            ];
            scene.nodes.push(root);
            scene.recompute_frame_hash();
            let mut pixmap = ts::Pixmap::new(80, 40).expect("pixmap");
            render_scene_to_pixmap(&scene, &mut pixmap, &reg);
            dark_pixels(&pixmap)
        };

        assert!(
            render(true) > render(false),
            "the accelerator underline must add dark pixels"
        );
    }
}
