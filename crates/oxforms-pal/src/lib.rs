//! Experimental PAL crate for the W002 rectangle smoke.
//!
//! This crate currently exposes only the smoke display-list contract needed by
//! W002: a versioned logical surface, RGBA8 colors, `FillRect`, and a
//! deterministic headless renderer. Later beads should reuse these types instead
//! of adding parallel VBA or Windows command paths.

#![forbid(unsafe_code)]

use std::error::Error;
use std::fmt;

/// First display-list version for the W002 smoke contract.
pub const DISPLAY_LIST_VERSION: u16 = 1;

/// Number of bytes per pixel in the headless RGBA8 framebuffer.
pub const BYTES_PER_PIXEL: usize = 4;

/// Stable hash identifier used by [`RenderDiagnostics::framebuffer_hash`].
pub const FRAMEBUFFER_HASH_ALGORITHM: &str = "fnv1a64-rgba8-framebuffer-v1";

/// Conservative allocation ceiling for the smoke headless renderer.
pub const MAX_HEADLESS_PIXELS: usize = 16_777_216;

/// Smoke-only diagnostic command emitted by the W002 VBA fixture for surface setup.
pub const SMOKE_TRACE_CANVAS: &str = "OXFORMS_SMOKE_CANVAS";

/// Smoke-only diagnostic command emitted by the W002 VBA fixture for `FillRect`.
pub const SMOKE_TRACE_FILL_RECT: &str = "OXFORMS_SMOKE_FILLRECT";

/// Smoke-only diagnostic command emitted by the W002 VBA fixture to submit a batch.
pub const SMOKE_TRACE_FLUSH: &str = "OXFORMS_SMOKE_FLUSH";

const FNV_OFFSET_BASIS: u64 = 0xcbf29ce484222325;
const FNV_PRIME: u64 = 0x0000_0100_0000_01b3;

type SmokeTraceFields<'a> = Vec<(&'a str, &'a str)>;

/// Logical pixel dimensions for a render target.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
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

    fn right(self) -> Result<i32, RenderError> {
        self.x
            .checked_add(self.width)
            .ok_or(RenderError::RectangleOverflow { rect: self })
    }

    fn bottom(self) -> Result<i32, RenderError> {
        self.y
            .checked_add(self.height)
            .ok_or(RenderError::RectangleOverflow { rect: self })
    }
}

/// Explicit RGBA byte order used by display-list colors and headless buffers.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
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

/// Platform-neutral drawing commands for the current smoke slice.
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum DisplayCommand {
    FillRect { rect: Rect, color: Color },
}

/// Versioned command batch for a single logical surface.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct DisplayList {
    pub version: u16,
    pub surface: SurfaceSize,
    pub commands: Vec<DisplayCommand>,
}

impl DisplayList {
    #[must_use]
    pub fn new(surface: SurfaceSize) -> Self {
        Self {
            version: DISPLAY_LIST_VERSION,
            surface,
            commands: Vec::new(),
        }
    }

    #[must_use]
    pub fn with_fill_rect(mut self, rect: Rect, color: Color) -> Self {
        self.commands.push(DisplayCommand::FillRect { rect, color });
        self
    }

    pub fn validate(&self) -> Result<(), RenderError> {
        if self.version != DISPLAY_LIST_VERSION {
            return Err(RenderError::UnsupportedDisplayListVersion {
                actual: self.version,
                expected: DISPLAY_LIST_VERSION,
            });
        }

        validate_surface(self.surface)?;

        for command in &self.commands {
            match command {
                DisplayCommand::FillRect { rect, .. } => validate_rect(*rect)?,
            }
        }

        Ok(())
    }
}

/// The W002 rectangle fixture originally proven by `oxforms-dwm.3`.
#[must_use]
pub fn w002_rectangle_fixture_display_list() -> DisplayList {
    DisplayList::new(SurfaceSize::new(4, 3))
        .with_fill_rect(Rect::new(1, 1, 2, 1), Color::rgba(0x10, 0x20, 0x30, 0xff))
}

/// Stable diagnostics for [`w002_rectangle_fixture_display_list`].
#[must_use]
pub fn w002_rectangle_fixture_diagnostics() -> RenderDiagnostics {
    RenderDiagnostics {
        width: 4,
        height: 3,
        command_count: 1,
        framebuffer_hash: 13_797_848_596_963_948_501,
        hash_algorithm: FRAMEBUFFER_HASH_ALGORITHM,
    }
}

/// Deterministic render result for the headless oracle.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct HeadlessRender {
    /// Row-major RGBA8 pixels.
    pub pixels: Vec<u8>,
    pub diagnostics: RenderDiagnostics,
}

/// Stable diagnostics returned by the headless renderer.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RenderDiagnostics {
    pub width: u32,
    pub height: u32,
    pub command_count: usize,
    pub framebuffer_hash: u64,
    pub hash_algorithm: &'static str,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum RenderError {
    UnsupportedDisplayListVersion { actual: u16, expected: u16 },
    EmptySurface { width: u32, height: u32 },
    SurfaceTooLarge { width: u32, height: u32 },
    InvalidRectangle { rect: Rect },
    RectangleOverflow { rect: Rect },
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum SmokeTraceError {
    UnknownCommand {
        line: String,
    },
    MissingField {
        command: &'static str,
        field: &'static str,
        line: String,
    },
    InvalidField {
        command: &'static str,
        field: &'static str,
        value: String,
        line: String,
    },
    DuplicateCanvas {
        line: String,
    },
    CommandBeforeCanvas {
        command: &'static str,
        line: String,
    },
    MissingCanvas,
    MissingFlush,
    CommandAfterFlush {
        line: String,
    },
    Render(RenderError),
}

impl fmt::Display for RenderError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::UnsupportedDisplayListVersion { actual, expected } => write!(
                formatter,
                "unsupported display-list version {actual}; expected {expected}"
            ),
            Self::EmptySurface { width, height } => {
                write!(
                    formatter,
                    "surface dimensions must be nonzero, got {width}x{height}"
                )
            }
            Self::SurfaceTooLarge { width, height } => {
                write!(
                    formatter,
                    "surface dimensions are too large to render: {width}x{height}"
                )
            }
            Self::InvalidRectangle { rect } => write!(
                formatter,
                "rectangle dimensions must be positive, got {:?}",
                rect
            ),
            Self::RectangleOverflow { rect } => {
                write!(
                    formatter,
                    "rectangle coordinate math overflowed for {:?}",
                    rect
                )
            }
        }
    }
}

impl Error for RenderError {}

impl fmt::Display for SmokeTraceError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::UnknownCommand { line } => {
                write!(formatter, "unknown OxForms smoke trace command: {line}")
            }
            Self::MissingField {
                command,
                field,
                line,
            } => write!(
                formatter,
                "missing field `{field}` for smoke command `{command}` in line: {line}"
            ),
            Self::InvalidField {
                command,
                field,
                value,
                line,
            } => write!(
                formatter,
                "invalid field `{field}` value `{value}` for smoke command `{command}` in line: {line}"
            ),
            Self::DuplicateCanvas { line } => {
                write!(formatter, "duplicate smoke canvas declaration in line: {line}")
            }
            Self::CommandBeforeCanvas { command, line } => write!(
                formatter,
                "smoke command `{command}` appeared before `{SMOKE_TRACE_CANVAS}` in line: {line}"
            ),
            Self::MissingCanvas => write!(
                formatter,
                "smoke trace never emitted `{SMOKE_TRACE_CANVAS}` before flush"
            ),
            Self::MissingFlush => write!(
                formatter,
                "smoke trace never emitted `{SMOKE_TRACE_FLUSH}` to submit the display list"
            ),
            Self::CommandAfterFlush { line } => {
                write!(formatter, "smoke trace command appeared after flush: {line}")
            }
            Self::Render(err) => {
                write!(formatter, "smoke trace reached PAL but render failed: {err}")
            }
        }
    }
}

impl Error for SmokeTraceError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Self::Render(err) => Some(err),
            _ => None,
        }
    }
}

/// Render a display list into a transparent RGBA8 buffer and return stable
/// diagnostics over the final framebuffer.
pub fn render_headless(display_list: &DisplayList) -> Result<HeadlessRender, RenderError> {
    display_list.validate()?;

    let pixel_count = pixel_count(display_list.surface)?;
    let mut pixels = vec![0; pixel_count * BYTES_PER_PIXEL];

    for command in &display_list.commands {
        match command {
            DisplayCommand::FillRect { rect, color } => {
                fill_rect(&mut pixels, display_list.surface, *rect, *color)?;
            }
        }
    }

    let diagnostics = RenderDiagnostics {
        width: display_list.surface.width,
        height: display_list.surface.height,
        command_count: display_list.commands.len(),
        framebuffer_hash: fnv1a64(&pixels),
        hash_algorithm: FRAMEBUFFER_HASH_ALGORITHM,
    };

    Ok(HeadlessRender {
        pixels,
        diagnostics,
    })
}

/// Decode the smoke-only OxVba debug trace into the PAL display list it submits.
pub fn display_list_from_smoke_trace(lines: &[String]) -> Result<DisplayList, SmokeTraceError> {
    let mut display_list = None;
    let mut flushed = false;

    for line in lines {
        if flushed {
            return Err(SmokeTraceError::CommandAfterFlush { line: line.clone() });
        }

        let (command, fields) = parse_smoke_trace_line(line)?;
        match command {
            SMOKE_TRACE_CANVAS => {
                if display_list.is_some() {
                    return Err(SmokeTraceError::DuplicateCanvas { line: line.clone() });
                }
                let width = parse_required_field::<u32>(command, &fields, "width", line)?;
                let height = parse_required_field::<u32>(command, &fields, "height", line)?;
                display_list = Some(DisplayList::new(SurfaceSize::new(width, height)));
            }
            SMOKE_TRACE_FILL_RECT => {
                let Some(list) = display_list.as_mut() else {
                    return Err(SmokeTraceError::CommandBeforeCanvas {
                        command,
                        line: line.clone(),
                    });
                };
                let rect = Rect::new(
                    parse_required_field::<i32>(command, &fields, "x", line)?,
                    parse_required_field::<i32>(command, &fields, "y", line)?,
                    parse_required_field::<i32>(command, &fields, "width", line)?,
                    parse_required_field::<i32>(command, &fields, "height", line)?,
                );
                let color = Color::rgba(
                    parse_required_field::<u8>(command, &fields, "red", line)?,
                    parse_required_field::<u8>(command, &fields, "green", line)?,
                    parse_required_field::<u8>(command, &fields, "blue", line)?,
                    parse_required_field::<u8>(command, &fields, "alpha", line)?,
                );
                list.commands.push(DisplayCommand::FillRect { rect, color });
            }
            SMOKE_TRACE_FLUSH => {
                if display_list.is_none() {
                    return Err(SmokeTraceError::MissingCanvas);
                }
                flushed = true;
            }
            _ => unreachable!("parse_smoke_trace_line filters commands"),
        }
    }

    if !flushed {
        return Err(SmokeTraceError::MissingFlush);
    }

    display_list.ok_or(SmokeTraceError::MissingCanvas)
}

/// Submit an OxVba-emitted smoke trace through the headless PAL diagnostic path.
pub fn render_smoke_trace_headless(lines: &[String]) -> Result<HeadlessRender, SmokeTraceError> {
    let display_list = display_list_from_smoke_trace(lines)?;
    render_headless(&display_list).map_err(SmokeTraceError::Render)
}

fn validate_surface(surface: SurfaceSize) -> Result<(), RenderError> {
    if surface.width == 0 || surface.height == 0 {
        return Err(RenderError::EmptySurface {
            width: surface.width,
            height: surface.height,
        });
    }

    let pixel_count_is_too_large = match pixel_count(surface) {
        Ok(pixel_count) => pixel_count > MAX_HEADLESS_PIXELS,
        Err(_) => true,
    };

    if surface.width > i32::MAX as u32
        || surface.height > i32::MAX as u32
        || pixel_count_is_too_large
    {
        return Err(RenderError::SurfaceTooLarge {
            width: surface.width,
            height: surface.height,
        });
    }

    Ok(())
}

fn validate_rect(rect: Rect) -> Result<(), RenderError> {
    if rect.width <= 0 || rect.height <= 0 {
        return Err(RenderError::InvalidRectangle { rect });
    }

    rect.right()?;
    rect.bottom()?;

    Ok(())
}

fn pixel_count(surface: SurfaceSize) -> Result<usize, RenderError> {
    let width = usize::try_from(surface.width).map_err(|_| RenderError::SurfaceTooLarge {
        width: surface.width,
        height: surface.height,
    })?;
    let height = usize::try_from(surface.height).map_err(|_| RenderError::SurfaceTooLarge {
        width: surface.width,
        height: surface.height,
    })?;

    let pixels = width
        .checked_mul(height)
        .ok_or(RenderError::SurfaceTooLarge {
            width: surface.width,
            height: surface.height,
        })?;

    pixels
        .checked_mul(BYTES_PER_PIXEL)
        .map(|_| pixels)
        .ok_or(RenderError::SurfaceTooLarge {
            width: surface.width,
            height: surface.height,
        })
}

fn fill_rect(
    pixels: &mut [u8],
    surface: SurfaceSize,
    rect: Rect,
    color: Color,
) -> Result<(), RenderError> {
    let left = rect.x.max(0);
    let top = rect.y.max(0);
    let right = rect.right()?.min(surface.width as i32);
    let bottom = rect.bottom()?.min(surface.height as i32);

    if left >= right || top >= bottom {
        return Ok(());
    }

    let surface_width = usize::try_from(surface.width).expect("surface width validated");
    let rgba = color.to_rgba8();

    for y in top..bottom {
        for x in left..right {
            let y = usize::try_from(y).expect("clipped y coordinate is non-negative");
            let x = usize::try_from(x).expect("clipped x coordinate is non-negative");
            let offset = ((y * surface_width) + x) * BYTES_PER_PIXEL;
            pixels[offset..offset + BYTES_PER_PIXEL].copy_from_slice(&rgba);
        }
    }

    Ok(())
}

fn parse_smoke_trace_line(
    line: &str,
) -> Result<(&'static str, SmokeTraceFields<'_>), SmokeTraceError> {
    let mut parts = line.split('|');
    let Some(command) = parts.next() else {
        return Err(SmokeTraceError::UnknownCommand {
            line: line.to_string(),
        });
    };

    let command = match command {
        SMOKE_TRACE_CANVAS => SMOKE_TRACE_CANVAS,
        SMOKE_TRACE_FILL_RECT => SMOKE_TRACE_FILL_RECT,
        SMOKE_TRACE_FLUSH => SMOKE_TRACE_FLUSH,
        _ => {
            return Err(SmokeTraceError::UnknownCommand {
                line: line.to_string(),
            });
        }
    };

    let mut fields = Vec::new();
    for part in parts {
        let Some((key, value)) = part.split_once('=') else {
            return Err(SmokeTraceError::InvalidField {
                command,
                field: "key=value",
                value: part.to_string(),
                line: line.to_string(),
            });
        };
        fields.push((key, value));
    }

    Ok((command, fields))
}

fn parse_required_field<T>(
    command: &'static str,
    fields: &[(&str, &str)],
    field: &'static str,
    line: &str,
) -> Result<T, SmokeTraceError>
where
    T: std::str::FromStr,
{
    let Some((_, value)) = fields.iter().find(|(key, _)| *key == field) else {
        return Err(SmokeTraceError::MissingField {
            command,
            field,
            line: line.to_string(),
        });
    };

    value
        .parse::<T>()
        .map_err(|_| SmokeTraceError::InvalidField {
            command,
            field,
            value: (*value).to_string(),
            line: line.to_string(),
        })
}

fn fnv1a64(bytes: &[u8]) -> u64 {
    bytes.iter().fold(FNV_OFFSET_BASIS, |hash, byte| {
        (hash ^ u64::from(*byte)).wrapping_mul(FNV_PRIME)
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fill_rect_renders_expected_pixels_and_diagnostics() {
        let display_list = w002_rectangle_fixture_display_list();

        let rendered = render_headless(&display_list).expect("known display list should render");

        assert_eq!(rendered.diagnostics, w002_rectangle_fixture_diagnostics());
        assert_eq!(
            rendered.pixels,
            vec![
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x20, 0x30, 0xff, 0x10, 0x20, 0x30, 0xff,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            ]
        );
    }

    #[test]
    fn renderer_clips_rectangles_to_the_surface() {
        let display_list = DisplayList::new(SurfaceSize::new(2, 2))
            .with_fill_rect(Rect::new(-1, -1, 2, 2), Color::rgba(1, 2, 3, 4));

        let rendered = render_headless(&display_list).expect("clipped rectangle should render");

        assert_eq!(
            rendered.pixels,
            vec![1, 2, 3, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        );
    }

    #[test]
    fn renderer_rejects_invalid_surface_and_rectangles() {
        let empty_surface = DisplayList::new(SurfaceSize::new(0, 4));
        assert_eq!(
            render_headless(&empty_surface).expect_err("empty surface should be rejected"),
            RenderError::EmptySurface {
                width: 0,
                height: 4,
            }
        );

        let zero_width_rect = DisplayList::new(SurfaceSize::new(2, 2))
            .with_fill_rect(Rect::new(0, 0, 0, 1), Color::rgba(1, 2, 3, 4));
        assert_eq!(
            render_headless(&zero_width_rect).expect_err("zero-width rect should be rejected"),
            RenderError::InvalidRectangle {
                rect: Rect::new(0, 0, 0, 1),
            }
        );
    }

    #[test]
    fn renderer_rejects_unsupported_display_list_versions() {
        let mut display_list = DisplayList::new(SurfaceSize::new(1, 1));
        display_list.version = DISPLAY_LIST_VERSION + 1;

        assert_eq!(
            render_headless(&display_list).expect_err("unsupported version should be rejected"),
            RenderError::UnsupportedDisplayListVersion {
                actual: DISPLAY_LIST_VERSION + 1,
                expected: DISPLAY_LIST_VERSION,
            }
        );
    }

    #[test]
    fn renderer_rejects_surfaces_beyond_the_headless_pixel_limit() {
        let too_large = DisplayList::new(SurfaceSize::new(
            u32::try_from(MAX_HEADLESS_PIXELS).expect("limit fits in u32") + 1,
            1,
        ));

        assert_eq!(
            render_headless(&too_large).expect_err("oversized surface should be rejected"),
            RenderError::SurfaceTooLarge {
                width: 16_777_217,
                height: 1,
            }
        );
    }

    #[test]
    fn smoke_trace_submits_fill_rect_to_headless_renderer() {
        let lines = vec![
            format!("{SMOKE_TRACE_CANVAS}|width=4|height=3"),
            format!(
                "{SMOKE_TRACE_FILL_RECT}|x=1|y=1|width=2|height=1|red=16|green=32|blue=48|alpha=255"
            ),
            SMOKE_TRACE_FLUSH.to_string(),
        ];

        let display_list =
            display_list_from_smoke_trace(&lines).expect("smoke trace should decode");
        assert_eq!(display_list, w002_rectangle_fixture_display_list());

        let rendered = render_smoke_trace_headless(&lines).expect("smoke trace should render");
        assert_eq!(rendered.diagnostics, w002_rectangle_fixture_diagnostics());
    }
}
