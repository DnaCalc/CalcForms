//! OxForms desktop PAL backend (Windows-first).
//!
//! The first *visible* backend for the W007 vertical slice. It turns a control-blind
//! [`oxforms_pal::scene::Scene`] into pixels in a real window and OS events into
//! normalized [`oxforms_pal::UiEvent`]s — nothing more. Control behavior, routing, and
//! the form object model stay in `oxforms-core`/runtime; this crate deliberately does
//! not depend on them (see `Cargo.toml`). See `docs/specs/RENDERING_ARCHITECTURE.md`
//! §15 for the (revisitable) stack decision: winit + softbuffer + tiny-skia + ab_glyph.
//!
//! Layers:
//! - [`raster`] — a `tiny_skia` [`oxforms_pal::scene::PrimSink`] (the visible twin of
//!   the text-free `HeadlessSink` golden oracle), plus [`raster::render_scene_to_pixmap`].
//! - [`text`] — the [`text::AbGlyphShaper`] (caption → shaped [`oxforms_pal::scene::TextRun`]),
//!   the [`text::TextResolver`] contract + [`text::SceneTextResolver`] (run id → resident
//!   run, font id → face), a [`text::FontTable`], and the platform-font loader.
//! - [`input`] — pure winit → [`oxforms_pal::UiEvent`] normalization (headless-testable).
//! - [`window`] — the winit + softbuffer present loop ([`window::run_scene_window`]).
//! - [`fixture`] — a raw-primitive greeter scene standing in for VBA self-render output
//!   until the OxVba integration is wired (oxforms-4pn.7/.8).

#![forbid(unsafe_code)]

pub mod fixture;
pub mod input;
pub mod raster;
pub mod text;
pub mod window;

pub use raster::{render_scene_to_pixmap, render_scene_to_rgba, SkiaSink};
pub use text::{load_ui_font, AbGlyphShaper, FontTable, SceneTextResolver, TextResolver};
pub use window::{run_scene_window, WindowError, WindowOptions, WindowSignal};
