//! CalcForms desktop PAL backend (Windows-first).
//!
//! The first *visible* backend for the W007 vertical slice. It turns a control-blind
//! [`calcforms_pal::scene::Scene`] into pixels in a real window and OS events into
//! normalized [`calcforms_pal::UiEvent`]s — nothing more. Control behavior, routing, and
//! the form object model stay in the CalcVBA adapter/runtime; this crate deliberately does
//! not depend on it (see `Cargo.toml`). See `docs/specs/RENDERING_ARCHITECTURE.md`
//! §15 for the (revisitable) stack decision: winit + softbuffer + tiny-skia + ab_glyph.
//!
//! Layers:
//! - [`raster`] — a `tiny_skia` [`calcforms_pal::scene::PrimSink`] (the visible twin of
//!   the deterministic `HeadlessSink` golden oracle), plus
//!   [`raster::render_scene_to_pixmap`].
//! - [`text`] — the [`text::AbGlyphShaper`] (caption → shaped [`calcforms_pal::scene::TextRun`]),
//!   the [`text::TextResolver`] contract + [`text::SceneTextResolver`] (run id → resident
//!   run, font id → face), a [`text::FontTable`], and the platform-font loader.
//! - [`input`] — pure winit → [`calcforms_pal::UiEvent`] normalization (headless-testable).
//! - [`window`] — the winit + softbuffer present loop ([`window::run_scene_window`]).
//! - [`fixture`] — a raw-primitive greeter scene standing in for VBA self-render output
//!   until the CalcVBA integration is wired (oxforms-4pn.7/.8).
//! - [`clipboard`] — the live OS clipboard read ([`clipboard::read_clipboard_text`]) the
//!   desktop bootstrap gives the runtime for keyboard Ctrl+V paste; Windows-only, `None`
//!   elsewhere and when the clipboard holds no text.

#![forbid(unsafe_code)]

pub mod clipboard;
pub mod fixture;
pub mod input;
pub mod raster;
pub mod text;
pub mod window;

pub use clipboard::read_clipboard_text;
pub use raster::{
    render_scene_to_pixmap, render_scene_to_png, render_scene_to_rgba, repaint_scene_damage,
    SkiaSink,
};
pub use text::{
    load_desktop_text, load_ui_font, load_ui_font_family, AbGlyphShaper, FontTable,
    SceneTextResolver, TextResolver,
};
pub use window::{run_scene_window, WindowError, WindowOptions, WindowSignal};
