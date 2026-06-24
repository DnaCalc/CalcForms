//! OxForms desktop PAL backend (Windows-first).
//!
//! The first visible backend for the W007 vertical slice: a winit window +
//! softbuffer present loop, a tiny-skia rasterizer for the `oxforms_pal::scene`
//! primitive vocabulary, and ab_glyph text. It contains no control or demo
//! behavior — routing stays in OxForms core/runtime; this crate only turns scenes
//! into pixels and OS events into normalized `UiEvent`s. See
//! `docs/specs/RENDERING_ARCHITECTURE.md` s15 for the (revisitable) stack decision.

#![forbid(unsafe_code)]

use oxforms_pal::SurfaceSize;

/// Smoke check that the tiny-skia raster dependency builds and runs on this target:
/// allocate a surface and clear it to a known color, returning the byte length.
/// Replaced by the real `PrimSink` rasterizer in the next step of oxforms-4pn.6.
#[must_use]
pub fn raster_smoke(surface: SurfaceSize) -> usize {
    let mut pixmap = tiny_skia::Pixmap::new(surface.width, surface.height)
        .expect("non-zero surface for the raster smoke");
    pixmap.fill(tiny_skia::Color::from_rgba8(0xF0, 0xF0, 0xF0, 0xFF));
    pixmap.data().len()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn raster_smoke_allocates_an_rgba_surface() {
        // 200x120 RGBA = 200*120*4 bytes.
        assert_eq!(raster_smoke(SurfaceSize::new(200, 120)), 200 * 120 * 4);
    }
}
