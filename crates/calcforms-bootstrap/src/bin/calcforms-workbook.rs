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
use calcvba_bundle::ProjectMemberKind;

fn observe(
    runtime: &mut calcforms_calcvba_adapter::runtime::OxRuntime,
    member: Option<&str>,
) -> Result<(), String> {
    if let Some(member) = member {
        let form = runtime.form();
        let value = runtime
            .session_mut()
            .invoke_member_values(form, member, Some(ProjectMemberKind::Method), vec![])
            .map_err(|error| format!("observe {member}: {error}"))?;
        let value = value
            .as_bstr()
            .ok_or_else(|| format!("observe {member}: expected a String result"))?
            .as_str();
        println!(
            "CALCFORMS_WORKBOOK_OBSERVATION {}",
            serde_json::json!({"member": member, "state": value})
        );
    }
    Ok(())
}

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
    let font = load_ui_font().map_err(|error| format!("load font: {error}"))?;
    let mut fonts = FontTable::new();
    fonts.add(FontId(1), font.clone());
    let (mut runtime, surface) = form.runtime(
        Arc::new(AbGlyphShaper::new(FontId(1), font)),
        HostServices::windows(calcforms_pal_win::read_clipboard_text),
    )?;
    let scene = surface.snapshot()?.scene.ok_or("no initial form Scene")?;
    if let Some(path) = scene_path {
        std::fs::write(
            path,
            serde_json::to_vec_pretty(&scene).map_err(|e| e.to_string())?,
        )
        .map_err(|e| e.to_string())?;
    }
    observe(&mut runtime, observation_member.as_deref())?;
    let options = WindowOptions::new(
        &form.caption,
        form.width * 96.0 / 72.0 * scale,
        form.height * 96.0 / 72.0 * scale,
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
            observe(&mut runtime, observation_member.as_deref())?;
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
