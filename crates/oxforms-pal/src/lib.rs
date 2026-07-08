//! OxForms PAL core contracts and renderers.
//!
//! This crate currently exposes the W002 smoke display-list contract and the
//! W005 normalized input contract: value-typed, serializable event rows that a
//! platform adapter can feed to the core/model reducer path without leaking
//! host-runtime types.
//!
//! The PAL core deliberately has no dependency on any host runtime. Sibling
//! adapter crates own runtime-specific marshalling and project host values into
//! these typed display-list and input contracts. It also deliberately does not
//! own control behavior; the current reducer/object model lives in the OxForms
//! VBA library and is driven by the OxVba adapter runtime.

#![forbid(unsafe_code)]

pub mod accessibility;
pub mod input;
pub mod scene;

use serde::{Deserialize, Serialize};

pub use input::*;

/// Number of bytes per pixel in the headless RGBA8 framebuffer.
pub const BYTES_PER_PIXEL: usize = 4;

/// Stable identifier for the framebuffer-hash algorithm, reported by
/// `scene::SceneRenderReport::hash_algorithm`.
pub const FRAMEBUFFER_HASH_ALGORITHM: &str = "fnv1a64-rgba8-framebuffer-v1";

pub(crate) const FNV_OFFSET_BASIS: u64 = 0xcbf29ce484222325;
pub(crate) const FNV_PRIME: u64 = 0x0000_0100_0000_01b3;

/// Logical pixel dimensions for a render target.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct SurfaceSize {
    pub width: u32,
    pub height: u32,
}

impl SurfaceSize {
    #[must_use]
    pub const fn new(width: u32, height: u32) -> Self {
        Self { width, height }
    }
}

/// Logical-pixel rectangle.
///
/// Coordinates may be outside the surface. Rendering clips valid rectangles to
/// the target. Width and height must be strictly positive.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Rect {
    pub x: i32,
    pub y: i32,
    pub width: i32,
    pub height: i32,
}

impl Rect {
    #[must_use]
    pub const fn new(x: i32, y: i32, width: i32, height: i32) -> Self {
        Self {
            x,
            y,
            width,
            height,
        }
    }
}

/// Explicit RGBA byte order used by display-list colors and headless buffers.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct Color {
    pub red: u8,
    pub green: u8,
    pub blue: u8,
    pub alpha: u8,
}

impl Color {
    #[must_use]
    pub const fn rgba(red: u8, green: u8, blue: u8, alpha: u8) -> Self {
        Self {
            red,
            green,
            blue,
            alpha,
        }
    }

    #[must_use]
    pub const fn to_rgba8(self) -> [u8; BYTES_PER_PIXEL] {
        [self.red, self.green, self.blue, self.alpha]
    }
}

pub(crate) fn fnv1a64(bytes: &[u8]) -> u64 {
    bytes.iter().fold(FNV_OFFSET_BASIS, |hash, byte| {
        (hash ^ u64::from(*byte)).wrapping_mul(FNV_PRIME)
    })
}
