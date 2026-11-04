//! Shared native window host for a VBA form runtime. No control behavior lives here.
#![forbid(unsafe_code)]
mod input;
use calcforms_calcvba_adapter::{runtime::OxRuntime, surface::SurfaceFactory};
use calcforms_pal::{UiEvent, UiEventKind};
use calcforms_pal_win::{run_scene_window, FontTable, WindowOptions, WindowSignal};
use calcvba_bundle::ProjectMemberKind;
use std::{cell::RefCell, path::PathBuf, rc::Rc, sync::Arc};

/// Window geometry is in form points; scale is form zoom at the current monitor DPI.
pub struct FormWindowConfig {
    pub title: String,
    pub width_pt: f64,
    pub height_pt: f64,
    pub scale: f64,
    pub observation_member: Option<String>,
    pub scene_path: Option<PathBuf>,
}

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
            "CALCFORMS_FORM_OBSERVATION {}",
            serde_json::json!({"member": member, "state": value})
        );
    }
    Ok(())
}

/// Run the canonical retained-Scene window and route real input through VBA.
pub fn run_form_window(
    mut runtime: OxRuntime,
    surface: Arc<SurfaceFactory>,
    fonts: FontTable,
    configuration: FormWindowConfig,
) -> Result<(), String> {
    if !configuration.scale.is_finite() || !(0.5..=2.0).contains(&configuration.scale) {
        return Err("scale must be between 0.5 and 2.0".into());
    }
    let observation_member = configuration.observation_member;
    let scene_path = configuration.scene_path;
    let scale = configuration.scale;
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
        &configuration.title,
        configuration.width_pt * 96.0 / 72.0 * scale,
        configuration.height_pt * 96.0 / 72.0 * scale,
    );
    let (width, height) = (
        f64::from(scene.surface.width),
        f64::from(scene.surface.height),
    );
    let mut window_size = (options.logical_width, options.logical_height);
    let failure = Rc::new(RefCell::new(None));
    let callback_failure = failure.clone();
    println!(
        "CALCFORMS_FORM_READY pid={} width_pt={} height_pt={}",
        std::process::id(),
        configuration.width_pt,
        configuration.height_pt
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
                "CALCFORMS_FORM_TURN action={} effects={} focus={} text={}",
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
