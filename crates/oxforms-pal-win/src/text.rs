//! Text resolution for the desktop backend.
//!
//! The Scene `DrawText` primitive references a [`TextRunId`] only — never an inline
//! string — so a recolor or reposition re-measures nothing and the kernel stays
//! text-source-agnostic. The rasterizer therefore needs a *resolver* that turns a
//! run id into the concrete string + font + size to lay out. This module owns that
//! resolver contract and a simple in-memory registry, plus loading the platform UI
//! font as an `ab_glyph` face.
//!
//! In the full architecture the run table is interned by the text-metrics service
//! and crosses the boundary alongside the scene patch; for the W007 vertical slice
//! the fixture/bootstrap populates a [`TextRegistry`] directly. The headless oracle
//! ([`oxforms_pal::scene::HeadlessSink`]) renders no text and needs none of this —
//! text lives in the *visible* backend so the golden hash stays font-independent.

use std::collections::BTreeMap;
use std::io;

use ab_glyph::FontArc;
use oxforms_pal::scene::{FontId, TextRunId};

/// A run resolved to everything the rasterizer needs to lay it out. Color comes from
/// the `DrawText` primitive's `paint` (a recolor must not re-intern the run), so it is
/// deliberately absent here.
#[derive(Clone, Debug, PartialEq)]
pub struct ResolvedTextRun {
    pub text: String,
    pub font: FontId,
    /// Em size in logical points (scaled to device pixels by the rasterizer transform).
    pub px: f32,
    /// Byte index, into `text`, of the accelerator character to underline when the
    /// `DrawText` flags request it (the `&` is already stripped from `text`). `None`
    /// means no accelerator.
    pub accelerator: Option<usize>,
}

impl ResolvedTextRun {
    #[must_use]
    pub fn new(text: impl Into<String>, font: FontId, px: f32) -> Self {
        Self {
            text: text.into(),
            font,
            px,
            accelerator: None,
        }
    }

    #[must_use]
    pub fn with_accelerator(mut self, byte_index: usize) -> Self {
        self.accelerator = Some(byte_index);
        self
    }
}

/// Resolves the opaque handles a Scene carries (run ids, font ids) into concrete
/// strings and font faces. The rasterizer depends on this trait, not on any concrete
/// store, so a real boundary run-table can drop in later without touching raster code.
pub trait TextResolver {
    fn resolve(&self, run: TextRunId) -> Option<&ResolvedTextRun>;
    fn font(&self, font: FontId) -> Option<&FontArc>;
}

/// A straightforward in-memory run/font table. Deterministic iteration (sorted keys)
/// keeps it debug-friendly.
#[derive(Clone, Default)]
pub struct TextRegistry {
    runs: BTreeMap<u64, ResolvedTextRun>,
    fonts: BTreeMap<u64, FontArc>,
}

impl TextRegistry {
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Register a font face under an id and return that id for convenience.
    pub fn add_font(&mut self, id: FontId, font: FontArc) -> FontId {
        self.fonts.insert(id.0, font);
        id
    }

    /// Register a resolved run under an id and return that id for convenience.
    pub fn add_run(&mut self, id: TextRunId, run: ResolvedTextRun) -> TextRunId {
        self.runs.insert(id.0, run);
        id
    }

    #[must_use]
    pub fn run_count(&self) -> usize {
        self.runs.len()
    }
}

impl TextResolver for TextRegistry {
    fn resolve(&self, run: TextRunId) -> Option<&ResolvedTextRun> {
        self.runs.get(&run.0)
    }

    fn font(&self, font: FontId) -> Option<&FontArc> {
        self.fonts.get(&font.0)
    }
}

/// Candidate platform UI fonts, most MSForms-authentic first. `micross` is
/// Microsoft Sans Serif (the literal classic MSForms default), `tahoma` the modern
/// dialog font; the rest are robust fallbacks.
const UI_FONT_CANDIDATES: &[&str] = &[
    "micross.ttf",
    "tahoma.ttf",
    "segoeui.ttf",
    "arial.ttf",
    "verdana.ttf",
];

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

    #[test]
    fn registry_resolves_runs_and_fonts_by_id() {
        let mut reg = TextRegistry::new();
        // A run resolves only after registration; unknown ids stay None.
        assert!(reg.resolve(TextRunId(1)).is_none());
        reg.add_run(
            TextRunId(1),
            ResolvedTextRun::new("OK", FontId(7), 8.0).with_accelerator(0),
        );
        let run = reg.resolve(TextRunId(1)).expect("registered run resolves");
        assert_eq!(run.text, "OK");
        assert_eq!(run.font, FontId(7));
        assert_eq!(run.accelerator, Some(0));
        assert_eq!(reg.run_count(), 1);
    }

    #[test]
    fn ui_font_loads_on_this_host_or_reports_a_clear_error() {
        // On the Windows dev/demo host this loads a real face; elsewhere it must be a
        // precise NotFound rather than a panic. Either way the call never aborts.
        match load_ui_font() {
            Ok(font) => {
                let mut reg = TextRegistry::new();
                reg.add_font(FontId(1), font);
                assert!(reg.font(FontId(1)).is_some());
            }
            Err(err) => assert_eq!(err.kind(), io::ErrorKind::NotFound),
        }
    }
}
