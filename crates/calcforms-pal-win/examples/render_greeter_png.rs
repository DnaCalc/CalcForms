//! Render the W007 greeter fixture scene to a PNG — a deterministic visual artifact
//! for the rasterizer (no window needed), usable as 4pn.6 evidence.
//!
//! Run: `cargo run -p calcforms-pal-win --example render_greeter_png -- <out.png> [scale]`

use calcforms_pal_win::fixture::greeter;
use calcforms_pal_win::{load_ui_font, render_scene_to_pixmap};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let out = args
        .get(1)
        .cloned()
        .unwrap_or_else(|| "w007-greeter.png".to_string());
    let scale: u32 = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(3);

    let font = match load_ui_font() {
        Ok(font) => font,
        Err(err) => {
            eprintln!("could not load a platform UI font: {err}");
            std::process::exit(1);
        }
    };

    let (scene, fonts) = greeter(font);
    let width = scene.surface.width * scale;
    let height = scene.surface.height * scale;

    let mut pixmap = tiny_skia::Pixmap::new(width, height).expect("non-zero pixmap");
    render_scene_to_pixmap(&scene, &mut pixmap, &fonts);
    pixmap.save_png(&out).expect("save png");
    println!("wrote {out} ({width}x{height})");
}
