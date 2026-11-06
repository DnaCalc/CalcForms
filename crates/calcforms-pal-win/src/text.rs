//! Text shaping and resolution for the desktop backend.
//!
//! Per RENDERING_ARCHITECTURE.md §8 text is retained as a *shaped run* — the kernel's
//! [`calcforms_pal::scene::TextRun`] (positioned glyphs + metrics + caret), produced
//! once per content change by a [`TextShaper`] and stored in [`Scene::text`]. This
//! module owns the backend's [`AbGlyphShaper`] (the ab_glyph implementation of that
//! shaping), the platform UI-font loader, a [`FontTable`] of loaded faces, and the
//! [`SceneTextResolver`] the rasterizer uses to turn a run id + font id into the
//! resident `TextRun` and `FontArc` at paint time.
//!
//! The rasterizer **blits the run's positioned glyphs and never re-shapes** — shaping
//! happens here, on change. The headless oracle ([`calcforms_pal::scene::HeadlessSink`])
//! renders no text and needs none of this — text lives in the *visible* backend so the
//! golden hash stays font-independent.

use std::collections::BTreeMap;
use std::io;
use std::sync::Arc;

use ab_glyph::{Font, FontArc, PxScale, ScaleFont};
use calcforms_pal::scene::{
    text_run_id, CaretTable, FontEmRounding, FontId, PositionedGlyph, RunMetrics, Scene, TextKey,
    TextRun, TextRunId, TextShaper,
};

/// Resolves the opaque handles a Scene carries (run ids, font ids) into the resident
/// shaped run and font face. The rasterizer depends on this trait, not a concrete
/// store, so the resident text table can be sourced however the caller likes.
pub trait TextResolver {
    fn run(&self, run: TextRunId) -> Option<&TextRun>;
    fn font(&self, font: FontId) -> Option<&FontArc>;
}

/// A table of loaded font faces, keyed by [`FontId`]. The backend loads faces once
/// (e.g. the platform UI font) and keeps them for the window's lifetime; runs
/// reference a face by id, never by value.
#[derive(Clone, Default)]
pub struct FontTable {
    fonts: BTreeMap<u64, FontArc>,
}

impl FontTable {
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Register a face under an id; returns the id for convenience.
    pub fn add(&mut self, id: FontId, font: FontArc) -> FontId {
        self.fonts.insert(id.0, font);
        id
    }

    #[must_use]
    pub fn get(&self, id: FontId) -> Option<&FontArc> {
        self.fonts.get(&id.0)
    }

    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.fonts.is_empty()
    }
}

/// Resolves runs from a [`Scene`]'s resident text store and fonts from a [`FontTable`].
/// Both borrows are immutable, so the rasterizer can hold one while the kernel walks
/// the same scene.
pub struct SceneTextResolver<'a> {
    scene: &'a Scene,
    fonts: &'a FontTable,
}

impl<'a> SceneTextResolver<'a> {
    #[must_use]
    pub fn new(scene: &'a Scene, fonts: &'a FontTable) -> Self {
        Self { scene, fonts }
    }
}

impl TextResolver for SceneTextResolver<'_> {
    fn run(&self, run: TextRunId) -> Option<&TextRun> {
        self.scene.text_run(run)
    }

    fn font(&self, font: FontId) -> Option<&FontArc> {
        self.fonts.get(font)
    }
}

/// The ab_glyph implementation of [`TextShaper`]: shapes a caption into positioned
/// glyphs + metrics in **logical points** (the renderer applies the device scale), so
/// repaint blits without re-shaping. Holds one face under one [`FontId`] for v1.
#[derive(Clone)]
pub struct AbGlyphShaper {
    font_id: FontId,
    font: FontArc,
}

impl AbGlyphShaper {
    #[must_use]
    pub fn new(font_id: FontId, font: FontArc) -> Self {
        Self { font_id, font }
    }

    #[must_use]
    pub fn font_id(&self) -> FontId {
        self.font_id
    }

    #[must_use]
    pub fn font(&self) -> &FontArc {
        &self.font
    }
}

impl std::fmt::Debug for AbGlyphShaper {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        // FontArc is not Debug; identify the shaper by its font id only.
        f.debug_struct("AbGlyphShaper")
            .field("font_id", &self.font_id)
            .finish_non_exhaustive()
    }
}

impl TextShaper for AbGlyphShaper {
    fn shape(&self, key: &TextKey, text: &str) -> TextRun {
        // The shaper's face must be the one the key names, or the stamped run.key.font
        // would not match the glyphs (a latent face/id mismatch).
        debug_assert_eq!(
            key.font, self.font_id,
            "AbGlyphShaper face {:?} does not match the requested key font {:?}",
            self.font_id, key.font
        );
        // MSForms Caption/Text/list strings are literal. Underlining is explicit.
        let display = text;
        let accelerator = key
            .accelerator_index
            .map(|index| index as usize)
            .filter(|index| *index < display.chars().count());
        // Shape at the true logical em (1pt == 1px in logical space); ab_glyph advances
        // scale linearly, so the renderer multiplies positions + em by the device scale.
        // A tiny floor only avoids a zero/degenerate `PxScale`; it does NOT clamp to 1pt
        // (that would distort sub-1pt advances — the renderer floors the *device* px).
        let em = (key.size_milli_pt as f32 / 1000.0).max(f32::MIN_POSITIVE);
        let scaled = self
            .font
            .as_scaled(PxScale::from(em_height(&self.font, em)));

        let mut glyphs = Vec::new();
        let mut stops = vec![0.0_f32];
        let mut pen = 0.0_f32;
        let mut prev: Option<ab_glyph::GlyphId> = None;
        for ch in display.chars() {
            let gid = self.font.glyph_id(ch);
            if let Some(p) = prev {
                pen += scaled.kern(p, gid);
            }
            glyphs.push(PositionedGlyph {
                glyph_id: gid.0,
                x: pen,
                y: 0.0,
            });
            pen += scaled.h_advance(gid);
            stops.push(pen);
            prev = Some(gid);
        }

        TextRun {
            id: text_run_id(key, text),
            key: key.clone(),
            glyphs,
            metrics: RunMetrics {
                advance: pen,
                ascent: scaled.ascent(),
                // ab_glyph's descent is negative (below baseline); store the magnitude.
                descent: -scaled.descent(),
                line_gap: scaled.line_gap(),
            },
            caret: CaretTable { stops },
            accelerator,
            source: display.into(),
        }
    }
}

/// ab_glyph's scale is ascent-to-descent height, whereas a point size describes
/// the design em. Shape and rasterization must use the same conversion; device
/// DPI is applied later by the Scene transform, once.
pub(crate) fn em_height(font: &FontArc, points: f32) -> f32 {
    points * font.height_unscaled() / font.units_per_em().unwrap_or(font.height_unscaled())
}

#[cfg(windows)]
pub(crate) struct GlyphMask {
    pub left: i32,
    pub top: i32,
    pub width: usize,
    pub pixels: Vec<u8>,
}

/// Rasterize the retained glyph ids and positions; this never shapes text.
/// DirectWrite's safe bitmap wrapper owns its memory DC and all COM resources.
#[cfg(windows)]
pub(crate) fn gdi_glyph_mask(
    font: &FontArc,
    run: &TextRun,
    em_px: f32,
    scale: f32,
    origin: (f32, f32),
) -> Result<GlyphMask, String> {
    let face = dwrote::FontFile::new_from_buffer(Arc::new(font.font_data().to_vec()))
        .ok_or("DirectWrite font file")?
        .create_face(0, 0)
        .map_err(|error| format!("DirectWrite font face: {error}"))?;
    let ids: Vec<_> = run.glyphs.iter().map(|glyph| glyph.glyph_id).collect();
    if ids.is_empty() {
        return Ok(GlyphMask {
            left: 0,
            top: 0,
            width: 0,
            pixels: vec![],
        });
    }
    let metrics = face
        .design_glyph_metrics(&ids, false)
        .map_err(|error| format!("DirectWrite glyph metrics: {error}"))?;
    let factor = em_px / font.units_per_em().ok_or("font has no design em")?;
    let (ox, oy) = (origin.0.round(), origin.1.round());
    let mut left = f32::INFINITY;
    let mut top = f32::INFINITY;
    let mut right = f32::NEG_INFINITY;
    let mut bottom = f32::NEG_INFINITY;
    for (glyph, metric) in run.glyphs.iter().zip(metrics) {
        let x = ox + glyph.x * scale;
        let y = oy + glyph.y * scale;
        left = left.min(x + metric.leftSideBearing as f32 * factor);
        right =
            right.max(x + (metric.advanceWidth as f32 - metric.rightSideBearing as f32) * factor);
        top = top.min(y + (metric.topSideBearing as f32 - metric.verticalOriginY as f32) * factor);
        bottom = bottom.max(
            y + (metric.advanceHeight as f32
                - metric.bottomSideBearing as f32
                - metric.verticalOriginY as f32)
                * factor,
        );
    }
    // Hinting can move an outline edge to the adjacent device pixel. This
    // allocation margin does not change the glyph's position or ink bounds.
    let left = left.floor() as i32 - 3;
    let top = top.floor() as i32 - 3;
    let width = (right.ceil() as i32 - left + 3).max(1) as u32;
    let height = (bottom.ceil() as i32 - top + 3).max(1) as u32;
    if u64::from(width) * u64::from(height) > 16_777_216 {
        return Err("glyph mask exceeds the raster allocation limit".into());
    }
    let target = dwrote::GdiInterop::create().create_bitmap_render_target(width, height);
    target.set_pixels_per_dip(1.0);
    if target
        .get_opaque_values_as_mask()
        .iter()
        .skip(3)
        .step_by(4)
        .any(|alpha| *alpha != 0)
    {
        return Err("new DirectWrite bitmap is not a clear coverage surface".into());
    }
    let advances: Vec<_> = run
        .glyphs
        .iter()
        .enumerate()
        .map(|(i, glyph)| {
            (run.glyphs
                .get(i + 1)
                .map_or(run.metrics.advance, |next| next.x)
                - glyph.x)
                * scale
        })
        .collect();
    let offsets: Vec<_> = run
        .glyphs
        .iter()
        .map(|glyph| dwrote::GlyphOffset {
            advanceOffset: 0.0,
            ascenderOffset: -glyph.y * scale,
        })
        .collect();
    target.draw_glyph_run(
        ox - left as f32,
        oy - top as f32,
        dwrote::DWRITE_MEASURING_MODE_GDI_CLASSIC,
        &face,
        em_px,
        &ids,
        &advances,
        &offsets,
        &dwrote::RenderingParams::create_for_primary_monitor(),
        &(1.0, 1.0, 1.0),
    );
    let pixels = target
        .get_opaque_values_as_mask()
        .into_iter()
        .skip(3)
        .step_by(4)
        .collect();
    Ok(GlyphMask {
        left,
        top,
        width: width as usize,
        pixels,
    })
}

/// Candidate UI faces. The owned Excel 16 greeter's default is Tahoma; hosts
/// loading a persisted form should select its named face explicitly instead.
const UI_FONT_CANDIDATES: &[&str] = &[
    "tahoma.ttf",
    "micross.ttf",
    "segoeui.ttf",
    "arial.ttf",
    "verdana.ttf",
];

/// Load a persisted family in the current outline-font subset, with no
/// unrelated fallback. Legacy MS Sans Serif uses a reported outline
/// substitute; exact bitmap-font parity is outside this backend's subset.
fn family_file(family: &str) -> io::Result<&'static str> {
    let file = if family.eq_ignore_ascii_case("Tahoma") {
        "tahoma.ttf"
    } else if family.eq_ignore_ascii_case("Microsoft Sans Serif")
        || family.eq_ignore_ascii_case("MS Sans Serif")
    {
        if family.eq_ignore_ascii_case("MS Sans Serif") {
            eprintln!(
                "CALCFORMS_FONT_SUBSTITUTION requested=MS Sans Serif resolved=Microsoft Sans Serif"
            );
        }
        "micross.ttf"
    } else {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("unsupported font family {family:?}"),
        ));
    };
    Ok(file)
}

pub fn load_ui_font_family(family: &str) -> io::Result<FontArc> {
    let file = family_file(family)?;
    let bytes = std::fs::read(font_directory().join(file))?;
    let font = FontArc::try_from_vec(bytes)
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidData, "font failed to parse"))?;
    eprintln!("CALCFORMS_FONT requested={family} file={file}");
    Ok(font)
}

/// Load the desktop face and shaper for a window's initial device context.
/// Windows uses DirectWrite's GDI-classic advances; other platforms use logical
/// outline metrics. Both return the same retained, control-blind run contract.
pub fn load_desktop_text(
    font_id: FontId,
    family: &str,
    pixels_per_point: f32,
) -> io::Result<(FontArc, Arc<dyn TextShaper + Send + Sync>)> {
    if !pixels_per_point.is_finite() || !(0.25..=16.0).contains(&pixels_per_point) {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "invalid text device scale",
        ));
    }
    let bytes = std::fs::read(font_directory().join(family_file(family)?))?;
    let font = FontArc::try_from_vec(bytes.clone())
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidData, "font failed to parse"))?;
    #[cfg(windows)]
    {
        let bytes = Arc::new(bytes);
        dwrote::FontFile::new_from_buffer(bytes.clone())
            .and_then(|file| file.create_face(0, 0).ok())
            .ok_or_else(|| {
                io::Error::new(
                    io::ErrorKind::InvalidData,
                    "DirectWrite could not load the exact face",
                )
            })?;
        let shaper = GdiClassicShaper {
            font_id,
            font: font.clone(),
            bytes,
            scale_micros: (pixels_per_point * 1_000_000.0).round() as u32,
            pixels_per_point,
        };
        Ok((font, Arc::new(shaper)))
    }
    #[cfg(not(windows))]
    Ok((font.clone(), Arc::new(AbGlyphShaper::new(font_id, font))))
}

#[cfg(windows)]
struct GdiClassicShaper {
    font_id: FontId,
    font: FontArc,
    bytes: Arc<Vec<u8>>,
    scale_micros: u32,
    pixels_per_point: f32,
}

#[cfg(windows)]
impl std::fmt::Debug for GdiClassicShaper {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("GdiClassicShaper")
            .field("font", &self.font_id)
            .field("scale_micros", &self.scale_micros)
            .finish()
    }
}

#[cfg(windows)]
impl TextShaper for GdiClassicShaper {
    fn shape(&self, key: &TextKey, text: &str) -> TextRun {
        self.shape_with_font_rounding(key, text, FontEmRounding::Nearest)
    }

    fn shape_with_font_rounding(
        &self,
        key: &TextKey,
        text: &str,
        rounding: FontEmRounding,
    ) -> TextRun {
        assert_eq!(
            key.font, self.font_id,
            "requested face differs from loaded face"
        );
        // Keep the supplied scale for integer font fitting. Reconstructing 4/3
        // from its rounded micro-unit identity would turn an exact 11 into
        // 10.999997 and incorrectly truncate it to ten pixels.
        let scale = self.pixels_per_point;
        let requested_em = key.size_milli_pt as f32 / 1000.0 * scale;
        let nearest = requested_em.round().max(1.0);
        let em_px = match rounding {
            FontEmRounding::Nearest => nearest,
            FontEmRounding::NearestTiesDown => (requested_em - 0.5).ceil().max(1.0),
        };
        let glyph_ids: Vec<_> = text.chars().map(|c| self.font.glyph_id(c).0).collect();
        // COM faces stay on this call's thread. Only owned font bytes cross threads;
        // dwrote supplies safe, RAII wrappers for the public DirectWrite operations.
        let face = dwrote::FontFile::new_from_buffer(self.bytes.clone())
            .expect("validated font bytes")
            .create_face(0, 0)
            .expect("validated font face");
        let metrics = if glyph_ids.is_empty() {
            vec![]
        } else {
            face.gdi_compatible_glyph_metrics(
                em_px,
                1.0,
                std::ptr::null(),
                false,
                &glyph_ids,
                false,
            )
            .expect("GDI-compatible metrics for valid face glyphs")
        };
        let units = self.font.units_per_em().expect("TrueType design em");
        let mut glyphs = Vec::with_capacity(glyph_ids.len());
        let mut stops = vec![0.0];
        let mut pen_px = 0.0;
        for (glyph_id, metric) in glyph_ids.into_iter().zip(metrics) {
            glyphs.push(PositionedGlyph {
                glyph_id,
                x: pen_px / scale,
                y: 0.0,
            });
            pen_px += (metric.advanceWidth as f32 * em_px / units).round();
            stops.push(pen_px / scale);
        }
        let scaled = self
            .font
            .as_scaled(PxScale::from(em_height(&self.font, em_px)));
        let mut key = key.clone();
        key.device_scale_micros = Some(self.scale_micros);
        let encoded_scale = self.scale_micros as f32 / 1_000_000.0;
        let encoded_nearest = (key.size_milli_pt as f32 / 1000.0 * encoded_scale)
            .round()
            .max(1.0);
        key.device_em_pixels = (em_px != encoded_nearest).then_some(em_px as u32);
        TextRun {
            id: text_run_id(&key, text),
            accelerator: key
                .accelerator_index
                .map(|i| i as usize)
                .filter(|i| *i < text.chars().count()),
            key,
            glyphs,
            caret: CaretTable { stops },
            source: text.into(),
            metrics: RunMetrics {
                advance: pen_px / scale,
                ascent: scaled.ascent().round() / scale,
                descent: (-scaled.descent()).round() / scale,
                line_gap: scaled.line_gap().round() / scale,
            },
        }
    }
}

/// Load the platform UI font face, trying the MSForms-authentic candidates under the
/// Windows font directory in order. Returns the first that loads and parses.
///
/// # Errors
/// Returns [`io::ErrorKind::NotFound`] if none of the candidates can be read/parsed
/// (e.g. on a non-Windows host) — callers decide whether that is fatal (the visible
/// binary) or a skip (a text raster test on a host without these fonts).
pub fn load_ui_font() -> io::Result<FontArc> {
    let dir = font_directory();
    let mut last_err: Option<io::Error> = None;
    for name in UI_FONT_CANDIDATES {
        let path = dir.join(name);
        match std::fs::read(&path) {
            Ok(bytes) => match FontArc::try_from_vec(bytes) {
                Ok(font) => return Ok(font),
                Err(_) => {
                    last_err = Some(io::Error::new(
                        io::ErrorKind::InvalidData,
                        format!("font {} failed to parse", path.display()),
                    ));
                }
            },
            Err(err) => last_err = Some(err),
        }
    }
    Err(last_err.unwrap_or_else(|| {
        io::Error::new(
            io::ErrorKind::NotFound,
            "no platform UI font candidate was found",
        )
    }))
}

fn font_directory() -> std::path::PathBuf {
    // %WINDIR%\Fonts, falling back to the conventional location.
    if let Some(windir) = std::env::var_os("WINDIR") {
        std::path::Path::new(&windir).join("Fonts")
    } else {
        std::path::PathBuf::from(r"C:\Windows\Fonts")
    }
}

/// Test helper: the platform UI font, or an honest skip.
///
/// On Windows (the backend's target) the UI fonts are always present, so a load
/// failure is a real test failure — not a silent pass. On any other host the font is
/// genuinely unavailable, so we skip with a *visible* message rather than reporting a
/// green test that asserted nothing.
#[cfg(test)]
pub(crate) fn host_font_or_skip() -> Option<FontArc> {
    match load_ui_font() {
        Ok(font) => Some(font),
        Err(err) => {
            #[cfg(windows)]
            panic!("a platform UI font must load on Windows for text tests: {err}");
            #[cfg(not(windows))]
            {
                eprintln!("SKIP: no platform UI font on this host: {err}");
                None
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[cfg(windows)]
    #[test]
    fn native_raster_bounds_match_independent_frame_caption_ink() {
        // .106/.122 qualified native windows, paired with their public drawing
        // origin/baseline: Details is [0,-8,31,0] / [1,-12,50,0].
        for (scale, expected) in [(96.0 / 72.0, [0, -8, 31, 0]), (2.0, [1, -12, 50, 0])] {
            let (font, shaper) = load_desktop_text(FontId(1), "Tahoma", scale).unwrap();
            let mut style = key(8);
            style.size_milli_pt = 8250;
            let run = shaper.shape(&style, "Details");
            let mask =
                gdi_glyph_mask(&font, &run, (8.25 * scale).round(), scale, (0.0, 0.0)).unwrap();
            let points: Vec<_> = mask
                .pixels
                .iter()
                .enumerate()
                .filter(|(_, coverage)| **coverage > 145)
                .map(|(index, _)| {
                    (
                        mask.left + (index % mask.width) as i32,
                        mask.top + (index / mask.width) as i32,
                    )
                })
                .collect();
            let observed = [
                points.iter().map(|p| p.0).min().unwrap(),
                points.iter().map(|p| p.1).min().unwrap(),
                points.iter().map(|p| p.0).max().unwrap() + 1,
                points.iter().map(|p| p.1).max().unwrap() + 1,
            ];
            assert!(
                observed
                    .iter()
                    .zip(expected)
                    .all(|(a, b)| (a - b).abs() <= 1),
                "{scale}: {observed:?}"
            );
            let again =
                gdi_glyph_mask(&font, &run, (8.25 * scale).round(), scale, (0.0, 0.0)).unwrap();
            assert_eq!(
                mask.pixels, again.pixels,
                "repeated rasterization is deterministic"
            );
        }
    }

    #[cfg(windows)]
    #[test]
    fn midpoint_down_font_matches_native_root_edit_half_pixel_size() {
        // .106 LayoutCommon-150 InputName: public drawing cells at 18,29,38,46;
        // font height/ascent/descent 19/16/3, independently captured before this policy.
        let (_, shaper) = load_desktop_text(FontId(1), "Tahoma", 2.0).unwrap();
        let mut style = key(8);
        style.size_milli_pt = 8250;
        let run = shaper.shape_with_font_rounding(&style, "Ada", FontEmRounding::NearestTiesDown);
        assert_eq!(run.key.device_em_pixels, Some(16));
        assert_eq!(
            run.caret.stops.iter().map(|x| x * 2.0).collect::<Vec<_>>(),
            [0.0, 11.0, 20.0, 28.0]
        );
        assert_eq!((run.metrics.ascent + run.metrics.descent) * 2.0, 19.0);
        assert_ne!(run.id, shaper.shape(&style, "Ada").id);
    }

    #[cfg(windows)]
    #[test]
    fn gdi_classic_advances_and_line_metrics_match_independent_native_drawings() {
        // Public OLE/GDI records in .106 LayoutContainers-100/150 control EMFs.
        // These cells were captured before this shaper existed.
        let mut identifiers = Vec::new();
        for (scale, first, second, details, height) in [
            (
                96.0 / 72.0,
                vec![0., 6., 8., 12., 17., 21.],
                vec![0., 6., 12., 17., 23., 29., 35.],
                32.,
                13.,
            ),
            (
                2.0,
                vec![0., 9., 13., 19., 27., 33.],
                vec![0., 9., 18., 26., 35., 44., 53.],
                52.,
                21.,
            ),
        ] {
            let (_, shaper) = load_desktop_text(FontId(1), "Tahoma", scale).unwrap();
            let mut style = key(8);
            style.size_milli_pt = 8250;
            for (text, cells) in [("First", first), ("Second", second)] {
                let run = shaper.shape(&style, text);
                assert_eq!(run.caret.stops.len(), cells.len());
                for (actual, native) in run.caret.stops.iter().zip(cells) {
                    assert!((actual * scale - native).abs() < 0.001, "{text}: {run:?}");
                }
                assert!(
                    ((run.metrics.ascent + run.metrics.descent) * scale - height).abs() < 0.001
                );
                assert_eq!(run.source.as_ref(), text);
            }
            let run = shaper.shape(&style, "Details");
            assert!(
                (run.metrics.advance * scale - details).abs() < 0.001,
                "{run:?}"
            );
            identifiers.push(run.id);
        }
        assert_ne!(
            identifiers[0], identifiers[1],
            "device contexts cannot alias"
        );
        assert!(load_desktop_text(FontId(1), "Tahoma", f32::NAN).is_err());
    }

    fn key(size_pt: u32) -> TextKey {
        TextKey {
            font: FontId(1),
            size_milli_pt: size_pt * 1000,
            wrap_width_milli_pt: None,
            device_scale_micros: None,
            device_em_pixels: None,
            accelerator_index: None,
        }
    }

    #[test]
    fn ab_glyph_shaper_produces_positioned_glyphs_and_metrics() {
        let Some(font) = host_font_or_skip() else {
            return;
        };
        let shaper = AbGlyphShaper::new(FontId(1), font);
        let run = shaper.shape(&key(12), "OK");
        assert_eq!(run.id, text_run_id(&key(12), "OK"));
        assert_eq!(run.glyphs.len(), 2, "one glyph per display char");
        assert_eq!(
            run.glyphs[0].x, 0.0,
            "the first glyph starts at the run origin"
        );
        assert!(run.glyphs[1].x > 0.0, "the second glyph advances right");
        assert!(
            run.metrics.advance > run.glyphs[1].x,
            "advance covers the last glyph"
        );
        assert!(run.metrics.ascent > 0.0 && run.metrics.descent >= 0.0);
        assert_eq!(
            run.caret.stops.len(),
            3,
            "a stop before each glyph plus the end"
        );
    }

    #[test]
    fn ab_glyph_shaper_marks_the_accelerator() {
        let Some(font) = host_font_or_skip() else {
            return;
        };
        let shaper = AbGlyphShaper::new(FontId(1), font);
        let mut key = key(12);
        key.accelerator_index = Some(2);
        let run = shaper.shape(&key, "E&xit");
        assert_eq!(&*run.source, "E&xit");
        assert_eq!(run.accelerator, Some(2));
        assert_eq!(run.glyphs.len(), 5);
    }

    #[test]
    fn point_sizes_use_the_font_design_em_not_its_line_height() {
        let Some(font) = host_font_or_skip() else {
            return;
        };
        let units = font.units_per_em().expect("outline font design units");
        let expected = font.h_advance_unscaled(font.glyph_id('M')) * 12.0 / units;
        let run = AbGlyphShaper::new(FontId(1), font).shape(&key(12), "M");
        assert!((run.metrics.advance - expected).abs() < 0.0001);
        assert!(
            (run.metrics.ascent + run.metrics.descent - 12.0).abs() > 0.1,
            "Tahoma's design em is not its ascent-to-descent height"
        );
    }

    #[test]
    fn scene_text_resolver_resolves_run_and_font() {
        let Some(font) = host_font_or_skip() else {
            return;
        };
        let shaper = AbGlyphShaper::new(FontId(1), font.clone());
        let run = shaper.shape(&key(12), "OK");
        let id = run.id;

        let mut scene = Scene::new(
            calcforms_pal::SurfaceSize::new(10, 10),
            calcforms_pal::input::DpiScale::new(72.0, 72.0),
            calcforms_pal::scene::NodeId(0),
        );
        scene.upsert_text_run(run);
        let mut fonts = FontTable::new();
        fonts.add(FontId(1), font);

        let resolver = SceneTextResolver::new(&scene, &fonts);
        assert!(resolver.run(id).is_some(), "the resident run resolves");
        assert!(resolver.font(FontId(1)).is_some(), "the font resolves");
        assert!(resolver.run(TextRunId(999)).is_none());
        assert!(resolver.font(FontId(2)).is_none());
    }

    #[test]
    fn ui_font_loads_on_this_host_or_reports_a_clear_error() {
        // On the Windows dev/demo host this loads a real face; elsewhere it must be a
        // precise NotFound rather than a panic. Either way the call never aborts.
        match load_ui_font() {
            Ok(font) => {
                let mut fonts = FontTable::new();
                fonts.add(FontId(1), font);
                assert!(fonts.get(FontId(1)).is_some());
            }
            Err(err) => assert_eq!(err.kind(), io::ErrorKind::NotFound),
        }
    }
}
