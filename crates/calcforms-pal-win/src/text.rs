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

use ab_glyph::{Font, FontArc, PxScale, ScaleFont};
use calcforms_pal::scene::{
    parse_accelerator, text_run_id, CaretTable, FontId, PositionedGlyph, RunMetrics, Scene,
    TextKey, TextRun, TextRunId, TextShaper,
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
        // The id is over the raw caption (so "&OK" and "OK" differ); glyphs/caret/metrics
        // are over the display text with the accelerator marker removed.
        let (display, accelerator) = parse_accelerator(text);
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
pub fn load_ui_font_family(family: &str) -> io::Result<FontArc> {
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
    let bytes = std::fs::read(font_directory().join(file))?;
    let font = FontArc::try_from_vec(bytes)
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidData, "font failed to parse"))?;
    eprintln!("CALCFORMS_FONT requested={family} file={file}");
    Ok(font)
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

    fn key(size_pt: u32) -> TextKey {
        TextKey {
            font: FontId(1),
            size_milli_pt: size_pt * 1000,
            wrap_width_milli_pt: None,
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
        let run = shaper.shape(&key(12), "E&xit");
        assert_eq!(&*run.source, "Exit");
        assert_eq!(run.accelerator, Some(1));
        assert_eq!(run.glyphs.len(), 4);
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
