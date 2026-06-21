use std::error::Error;

use oxforms_pal::{render_headless, w002_rectangle_fixture_display_list};

const DEFAULT_HOLD_MS: u64 = 1_200;
const DEFAULT_SCALE: usize = 48;

fn main() -> Result<(), Box<dyn Error>> {
    let config = SmokeConfig::from_args(std::env::args().skip(1))?;
    let display_list = w002_rectangle_fixture_display_list();
    let rendered = render_headless(&display_list)?;

    println!(
        "oxforms-pal W002 visible smoke: {}x{}, commands={}, hash={} ({})",
        rendered.diagnostics.width,
        rendered.diagnostics.height,
        rendered.diagnostics.command_count,
        rendered.diagnostics.framebuffer_hash,
        rendered.diagnostics.hash_algorithm
    );

    run_visible_smoke(
        rendered.pixels,
        rendered.diagnostics.width,
        rendered.diagnostics.height,
        config,
    )
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
struct SmokeConfig {
    dry_run: bool,
    hold_ms: u64,
    scale: usize,
}

impl Default for SmokeConfig {
    fn default() -> Self {
        Self {
            dry_run: false,
            hold_ms: DEFAULT_HOLD_MS,
            scale: DEFAULT_SCALE,
        }
    }
}

impl SmokeConfig {
    fn from_args(args: impl IntoIterator<Item = String>) -> Result<Self, Box<dyn Error>> {
        let mut config = Self::default();
        let mut args = args.into_iter();

        while let Some(arg) = args.next() {
            match arg.as_str() {
                "--dry-run" => config.dry_run = true,
                "--hold-ms" => {
                    let value = args.next().ok_or("--hold-ms requires a value")?;
                    config.hold_ms = value.parse()?;
                }
                "--scale" => {
                    let value = args.next().ok_or("--scale requires a value")?;
                    config.scale = value.parse()?;
                    if config.scale == 0 {
                        return Err("--scale must be greater than zero".into());
                    }
                }
                "--help" | "-h" => {
                    println!(
                        "Usage: cargo run -p oxforms-pal --example visible_rectangle_smoke -- [--dry-run] [--hold-ms N] [--scale N]"
                    );
                    std::process::exit(0);
                }
                _ => return Err(format!("unknown argument: {arg}").into()),
            }
        }

        Ok(config)
    }
}

#[cfg(windows)]
fn run_visible_smoke(
    pixels: Vec<u8>,
    width: u32,
    height: u32,
    config: SmokeConfig,
) -> Result<(), Box<dyn Error>> {
    use std::thread;
    use std::time::{Duration, Instant};

    use minifb::{Key, Window, WindowOptions};

    if config.dry_run {
        println!("dry run: Windows visible window creation skipped");
        return Ok(());
    }

    let width = usize::try_from(width)?;
    let height = usize::try_from(height)?;
    let present_width = width
        .checked_mul(config.scale)
        .ok_or("scaled smoke width overflowed")?;
    let present_height = height
        .checked_mul(config.scale)
        .ok_or("scaled smoke height overflowed")?;
    let present = scale_rgba8_for_minifb(&pixels, width, height, config.scale)?;

    let mut window = Window::new(
        "OxForms W002 FillRect smoke",
        present_width,
        present_height,
        WindowOptions::default(),
    )?;

    let deadline = Instant::now() + Duration::from_millis(config.hold_ms);
    while window.is_open() && !window.is_key_down(Key::Escape) && Instant::now() < deadline {
        window.update_with_buffer(&present, present_width, present_height)?;
        thread::sleep(Duration::from_millis(16));
    }

    println!(
        "visible smoke presented for up to {} ms in a native Windows window",
        config.hold_ms
    );
    Ok(())
}

#[cfg(not(windows))]
fn run_visible_smoke(
    _pixels: Vec<u8>,
    _width: u32,
    _height: u32,
    config: SmokeConfig,
) -> Result<(), Box<dyn Error>> {
    let _ = (config.dry_run, config.hold_ms, config.scale);
    println!("unsupported: the OxForms W002 visible smoke opens a native window only on Windows");
    Ok(())
}

#[cfg(windows)]
fn scale_rgba8_for_minifb(
    pixels: &[u8],
    width: usize,
    height: usize,
    scale: usize,
) -> Result<Vec<u32>, Box<dyn Error>> {
    const BYTES_PER_PIXEL: usize = 4;
    const BACKGROUND: u32 = 0x00f0_f0f0;

    let source_len = width
        .checked_mul(height)
        .and_then(|pixels| pixels.checked_mul(BYTES_PER_PIXEL))
        .ok_or("RGBA8 source dimensions overflowed")?;
    if pixels.len() != source_len {
        return Err("RGBA8 buffer length does not match dimensions".into());
    }

    let present_width = width
        .checked_mul(scale)
        .ok_or("scaled smoke width overflowed")?;
    let present_height = height
        .checked_mul(scale)
        .ok_or("scaled smoke height overflowed")?;
    let present_len = present_width
        .checked_mul(present_height)
        .ok_or("scaled smoke buffer length overflowed")?;
    let mut present = vec![BACKGROUND; present_len];

    for y in 0..height {
        for x in 0..width {
            let source = ((y * width) + x) * BYTES_PER_PIXEL;
            let red = u32::from(pixels[source]);
            let green = u32::from(pixels[source + 1]);
            let blue = u32::from(pixels[source + 2]);
            let alpha = u32::from(pixels[source + 3]);
            let rgb = if alpha == 0 {
                BACKGROUND
            } else {
                (red << 16) | (green << 8) | blue
            };

            for scaled_y in (y * scale)..((y + 1) * scale) {
                let row = scaled_y * present_width;
                for scaled_x in (x * scale)..((x + 1) * scale) {
                    present[row + scaled_x] = rgb;
                }
            }
        }
    }

    Ok(present)
}
