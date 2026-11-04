//! Load an Office UserForm and run the same VBA runtime used by headless tests.
#![forbid(unsafe_code)]

#[path = "../input.rs"]
mod input;

use std::cell::RefCell;
use std::rc::Rc;
use std::sync::Arc;

use calcforms_calcvba_adapter::host_services::HostServices;
use calcforms_calcvba_adapter::office::WorkbookForm;
use calcforms_pal::scene::FontId;
use calcforms_pal::{UiEvent, UiEventKind};
use calcforms_pal_win::{
    load_ui_font, run_scene_window, AbGlyphShaper, FontTable, WindowOptions, WindowSignal,
};

fn run() -> Result<(), String> {
    let args: Vec<_> = std::env::args().skip(1).collect();
    if args.len() != 2 || args.iter().any(|value| value == "--help") {
        return Err("Usage: calcforms-workbook <workbook.xlsm> <UserFormName>".into());
    }
    let form = WorkbookForm::open(&args[0], &args[1])?;
    let font = load_ui_font().map_err(|error| format!("load font: {error}"))?;
    let mut fonts = FontTable::new();
    fonts.add(FontId(1), font.clone());
    let (mut runtime, surface) = form.runtime(
        Arc::new(AbGlyphShaper::new(FontId(1), font)),
        HostServices::windows(calcforms_pal_win::read_clipboard_text),
    )?;
    let scene = surface.snapshot()?.scene.ok_or("no initial form Scene")?;
    let options = WindowOptions::new(
        &form.caption,
        form.width * 96.0 / 72.0,
        form.height * 96.0 / 72.0,
    );
    let (width, height) = (
        f64::from(scene.surface.width),
        f64::from(scene.surface.height),
    );
    let mut window_size = (options.logical_width, options.logical_height);
    let failure = Rc::new(RefCell::new(None));
    let callback_failure = failure.clone();
    println!(
        "CALCFORMS_WORKBOOK_READY pid={} form={} controls={} width={} height={}",
        std::process::id(),
        form.name,
        form.controls.len(),
        form.width,
        form.height
    );
    run_scene_window(options, scene, fonts, move |event: &UiEvent, scene| {
        let mut turn = || -> Result<WindowSignal, String> {
            match &event.kind {
                UiEventKind::CloseRequest(_) => {
                    if runtime.perform_query_close(0)? != 0 {
                        return Ok(WindowSignal::Ignore);
                    }
                    runtime.perform("PerformDeactivate")?;
                    runtime.perform("PerformTerminate")?;
                    return Ok(WindowSignal::Close);
                }
                UiEventKind::Activate(_) => {
                    runtime.perform("PerformActivate")?;
                }
                UiEventKind::Deactivate(_) => {
                    runtime.perform("PerformDeactivate")?;
                }
                UiEventKind::Resize(event) => {
                    if let Some(size) = event.client_size {
                        window_size = (size.width, size.height);
                    }
                    return Ok(WindowSignal::Ignore);
                }
                _ => {}
            }
            let scale = (window_size.0 / width)
                .min(window_size.1 / height)
                .max(f64::EPSILON);
            let Some(turn) = input::dispatch_event(&mut runtime, event, scale)? else {
                return Ok(WindowSignal::Ignore);
            };
            if turn.effect_log.is_empty()
                || (!turn.repainted && input::is_deferred_plain_text_key(event))
            {
                return Ok(WindowSignal::Ignore);
            }
            if !turn.repainted {
                runtime.render()?;
            }
            if let Some(next) = surface.snapshot()?.scene {
                *scene = next;
            }
            println!(
                "CALCFORMS_WORKBOOK_TURN action={} effects={} focus={} text={}",
                turn.action,
                turn.effect_log,
                runtime.read_string("FocusName")?,
                runtime.read_string("InputText")?
            );
            Ok(WindowSignal::Redraw)
        };
        match turn() {
            Ok(signal) => signal,
            Err(error) => {
                *callback_failure.borrow_mut() = Some(error);
                WindowSignal::Close
            }
        }
    })
    .map_err(|error| error.to_string())?;
    if let Some(error) = failure.borrow_mut().take() {
        return Err(error);
    }
    Ok(())
}

fn main() {
    if let Err(error) = run() {
        eprintln!("calcforms-workbook: {error}");
        std::process::exit(1);
    }
}
