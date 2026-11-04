//! Load an Office UserForm and run its original handlers through the shared Windows host.
#![forbid(unsafe_code)]
use calcforms_calcvba_adapter::{host_services::HostServices, office::WorkbookForm};
use calcforms_pal::scene::FontId;
use calcforms_pal_win::{load_ui_font_family, AbGlyphShaper, FontTable};
use std::sync::Arc;
fn run() -> Result<(), String> {
    let args: Vec<_> = std::env::args().skip(1).collect();
    let usage = "Usage: calcforms-workbook <workbook.xlsm> <UserFormName> [--observe-member <StringFunction>] [--scale <factor>] [--dump-scene <file.json>]";
    if args.len() < 2 || args.iter().any(|value| value == "--help") {
        return Err(usage.into());
    }
    let mut observation_member = None;
    let mut scale = 1.0_f64;
    let mut scene_path = None;
    let mut options = args[2..].chunks_exact(2);
    for option in &mut options {
        match option[0].as_str() {
            "--observe-member" => observation_member = Some(option[1].clone()),
            "--scale" => {
                scale = option[1].parse().map_err(|_| "invalid scale")?;
                if !scale.is_finite() || !(0.5..=2.0).contains(&scale) {
                    return Err("scale must be between 0.5 and 2.0".into());
                }
            }
            "--dump-scene" => scene_path = Some(option[1].clone()),
            _ => return Err(usage.into()),
        }
    }
    if !options.remainder().is_empty() {
        return Err(usage.into());
    }
    let form = WorkbookForm::open(&args[0], &args[1])?;
    let font =
        load_ui_font_family(form.font_name()?).map_err(|error| format!("load font: {error}"))?;
    let mut fonts = FontTable::new();
    fonts.add(FontId(1), font.clone());
    let (runtime, surface) = form.runtime(
        Arc::new(AbGlyphShaper::new(FontId(1), font)),
        HostServices::windows(calcforms_pal_win::read_clipboard_text),
    )?;
    calcforms_bootstrap::run_form_window(
        runtime,
        surface,
        fonts,
        calcforms_bootstrap::FormWindowConfig {
            title: form.caption,
            width_pt: form.width,
            height_pt: form.height,
            scale,
            observation_member,
            scene_path: scene_path.map(Into::into),
        },
    )
}

fn main() {
    if let Err(error) = run() {
        eprintln!("calcforms-workbook: {error}");
        std::process::exit(1);
    }
}
