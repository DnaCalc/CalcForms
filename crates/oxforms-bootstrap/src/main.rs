//! OxForms thin bootstrap.
//!
//! The minimal native assembler for the live OxForms slice. Per
//! `docs/specs/RENDERING_ARCHITECTURE.md` §16.3 it is a *thin assembler*: it loads the OxVba
//! project, configures the `OxForms.Surface` boundary, attaches the thin `OxRuntime` to a VBA
//! form-document, and runs the platform loop — wiring the control-blind backend
//! (`oxforms-pal-win`) to the runtime (`oxforms-oxvba-adapter`). It holds **no** control or demo
//! behavior (that is VBA, owned by `OxReducer`), and never rasterizes (the backend owns Repaint).
//!
//! Frame model (§16): the runtime owns **Re-render** (`OxRuntime::render` → VBA self-render →
//! `OxForms.Surface` → resident `Scene` revision); the backend owns **Repaint** (resident `Scene`
//! snapshot → pixels). The reducer-pivot design has no Rust reducer: the bootstrap maps a window
//! event to a normalized input, asks the VBA `OxReducer` (via `OxRuntime`) to handle it, and on a
//! state change re-renders and refreshes the held snapshot — so clicks/keys drive the VBA handlers
//! and the form updates live.
//!
//! Demo: the W007 greeting — type a name, click OK (or press Enter) → "Hello, <name>".
//!
//! Run: `cargo run -p oxforms-bootstrap`.

#![forbid(unsafe_code)]

use std::cell::RefCell;
use std::rc::Rc;
use std::sync::Arc;

use oxforms_oxvba_adapter::runtime::OxRuntime;
use oxforms_oxvba_adapter::surface::{register_surface, SurfaceFactory};
use oxforms_pal::scene::{FontId, Scene};
use oxforms_pal::{CoordinatePayload, KeyCode, LogicalPoint, MouseButton, UiEvent, UiEventKind};
use oxforms_pal_win::{
    load_ui_font, run_scene_window, AbGlyphShaper, FontTable, WindowOptions, WindowSignal,
};

use oxvba_com::PortableComProjection;
use oxvba_hal::model::HostPolicy;
use oxvba_host::{Engine, HostConfig, HostProfileProvider, ProjectRuntimeSession};
use oxvba_symbol::manifest::{
    ModuleAttributes, ModuleKind, ModuleUnit, ProjectKind, SymbolProjectManifest,
};

/// The single UI font id the bootstrap registers; matches the VBA `OX_DEFAULT_FONT_ID` so the run
/// ids VBA emits resolve against the face the window rasterizes with.
const FONT_ID: FontId = FontId(1);

/// The demo form-document class + its build entrypoint.
const DEMO_FORM_CLASS: &str = "ReducerGreeterForm";
const DEMO_BUILD_MEMBER: &str = "Build";

/// A precise, stage-tagged bootstrap failure (OxVba load/compile vs OxForms runtime vs
/// PAL/backend vs normal exit are distinguishable).
#[derive(Debug)]
enum BootstrapError {
    /// OxVba project load / bind / elaborate / session prepare (compile-time stage).
    Project(String),
    /// OxForms runtime: attaching `OxRuntime` / driving the VBA reducer + re-render (VBA entry).
    Runtime(String),
    /// PAL/window backend.
    Window(String),
}

impl std::fmt::Display for BootstrapError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Project(m) => write!(f, "OxVba project error: {m}"),
            Self::Runtime(m) => write!(f, "OxForms runtime error: {m}"),
            Self::Window(m) => write!(f, "PAL/window error: {m}"),
        }
    }
}

impl BootstrapError {
    /// Stable exit code per stage so a caller/script can classify the failure.
    fn exit_code(&self) -> i32 {
        match self {
            Self::Project(_) => 2,
            Self::Runtime(_) => 3,
            Self::Window(_) => 4,
        }
    }
}

fn main() {
    match run() {
        Ok(()) => println!("oxforms-bootstrap: window closed; clean exit."),
        Err(err) => {
            eprintln!("oxforms-bootstrap: {err}");
            std::process::exit(err.exit_code());
        }
    }
}

fn run() -> Result<(), BootstrapError> {
    // 1. Load + configure the project: the OxForms VBA library + the OxReducer + the greeter
    //    form-document, with the OxForms.Surface boundary registered so the form self-renders.
    let (session, surface, fonts) = build_session()?;

    // 2. Attach the thin runtime, which constructs + builds the VBA form (and its OxReducer) and
    //    produces the first resident Scene revision.
    let mut rt = OxRuntime::attach(session, DEMO_FORM_CLASS, DEMO_BUILD_MEMBER)
        .map_err(BootstrapError::Runtime)?;
    rt.render().map_err(BootstrapError::Runtime)?;
    let scene = current_scene(&surface)?;

    println!(
        "oxforms-bootstrap: showing the live VBA-rendered W007 greeting. Type a name, click OK \
         (or press Enter) to greet; close or press Escape to exit."
    );

    // 3. Run the platform loop. The window owns Repaint (resident Scene snapshot -> pixels). The
    //    callback maps client pixels -> form-logical points (the uniform device-fit scale), asks
    //    the VBA reducer (via OxRuntime) to handle the input, re-renders, refreshes the held Scene
    //    from the resident snapshot, and asks for a Redraw. The bootstrap never rasterizes.
    let options = WindowOptions::new("OxForms - W007 greeting (bootstrap)", 600.0, 360.0);
    let (form_w, form_h) = (
        f64::from(scene.surface.width.max(1)),
        f64::from(scene.surface.height.max(1)),
    );
    let mut window_px = (options.logical_width, options.logical_height);
    let surface_cb = surface.clone();
    let cb_error: Rc<RefCell<Option<String>>> = Rc::new(RefCell::new(None));
    let cb_error_inner = cb_error.clone();

    let window_result = run_scene_window(
        options,
        scene,
        fonts,
        move |event: &UiEvent, scene: &mut Scene| {
            // A window-manager close request runs the form's QueryClose: a veto (nonzero Cancel)
            // keeps the window open; otherwise it closes. Escape force-closes the demo regardless.
            match &event.kind {
                UiEventKind::CloseRequest(_) => {
                    return match rt.perform_query_close(0) {
                        Ok(0) => WindowSignal::Close,
                        Ok(_) => WindowSignal::Ignore,
                        Err(err) => {
                            *cb_error_inner.borrow_mut() = Some(format!("query close: {err}"));
                            WindowSignal::Close
                        }
                    };
                }
                UiEventKind::KeyDown(e) if e.key == KeyCode::Escape => {
                    return WindowSignal::Close;
                }
                _ => {}
            }
            if let UiEventKind::Resize(e) = &event.kind {
                if let Some(size) = e.client_size {
                    window_px = (size.width, size.height);
                }
                return WindowSignal::Ignore;
            }

            let scale = (window_px.0 / form_w).min(window_px.1 / form_h);
            let scale = if scale > 0.0 { scale } else { 1.0 };

            // Route the event to the VBA reducer; a non-empty effect log means state changed and a
            // repaint is due. An unhandled event kind returns None (Ignore).
            let outcome = match dispatch_event(&mut rt, event, scale) {
                Ok(Some(effects)) => effects,
                Ok(None) => return WindowSignal::Ignore,
                Err(err) => {
                    *cb_error_inner.borrow_mut() = Some(err);
                    return WindowSignal::Close;
                }
            };
            if outcome.is_empty() {
                return WindowSignal::Ignore;
            }

            if let Err(err) = rt.render() {
                *cb_error_inner.borrow_mut() = Some(format!("render: {err}"));
                return WindowSignal::Close;
            }
            match surface_cb.snapshot() {
                Ok(snap) => {
                    if let Some(next) = snap.scene {
                        *scene = next;
                    }
                    WindowSignal::Redraw
                }
                Err(err) => {
                    *cb_error_inner.borrow_mut() = Some(format!("surface snapshot: {err}"));
                    WindowSignal::Close
                }
            }
        },
    );

    if let Some(err) = cb_error.borrow_mut().take() {
        return Err(BootstrapError::Runtime(err));
    }
    window_result.map_err(|err| BootstrapError::Window(err.to_string()))
}

/// Map a window event to the VBA reducer call. Returns `Ok(Some(effect_log))` for a dispatched
/// event (empty log = no state change), `Ok(None)` for an event kind the demo ignores.
fn dispatch_event(
    rt: &mut OxRuntime,
    event: &UiEvent,
    scale: f64,
) -> Result<Option<String>, String> {
    let shift = |m: &oxforms_pal::KeyboardModifiers| -> i16 {
        (if m.shift { 1 } else { 0 })
            | (if m.control { 2 } else { 0 })
            | (if m.alt { 4 } else { 0 })
    };
    match &event.kind {
        UiEventKind::MouseDown(e) | UiEventKind::MouseUp(e) => {
            let (x, y) = logical_point(&e.coordinates, scale);
            let kind = if matches!(event.kind, UiEventKind::MouseDown(_)) {
                "mousedown"
            } else {
                "mouseup"
            };
            rt.dispatch_mouse(kind, x, y, mouse_button(e.button), shift(&e.modifiers))
                .map(Some)
        }
        UiEventKind::KeyDown(e) | UiEventKind::KeyUp(e) => {
            let kind = if matches!(event.kind, UiEventKind::KeyDown(_)) {
                // Push the live OS clipboard so a Ctrl+V pastes the real clipboard contents.
                let _ = rt.set_clipboard_text(
                    &oxforms_pal_win::read_clipboard_text().unwrap_or_default(),
                );
                "keydown"
            } else {
                "keyup"
            };
            rt.dispatch_key(kind, keycode_to_vk(&e.key), shift(&e.modifiers))
                .map(Some)
        }
        UiEventKind::CharacterInput(e) => rt.dispatch_char(&e.text).map(Some),
        _ => Ok(None),
    }
}

fn mouse_button(button: MouseButton) -> i16 {
    match button {
        MouseButton::Left => 1,
        MouseButton::Right => 2,
        MouseButton::Middle => 3,
        _ => 0,
    }
}

/// Client pixels divided by the uniform device-fit `scale` -> form-logical integer point.
fn logical_point(coords: &CoordinatePayload, scale: f64) -> (i32, i32) {
    if let Some(form) = coords.form_logical {
        return (form.x.round() as i32, form.y.round() as i32);
    }
    if let Some(px) = coords.client_pixels {
        let p = LogicalPoint::new(px.x / scale, px.y / scale);
        return (p.x.round() as i32, p.y.round() as i32);
    }
    (0, 0)
}

/// Read the current resident `Scene` snapshot the runtime produced via `OxForms.Surface`.
fn current_scene(surface: &Arc<SurfaceFactory>) -> Result<Scene, BootstrapError> {
    let snap = surface
        .snapshot()
        .map_err(|err| BootstrapError::Runtime(format!("surface snapshot: {err}")))?;
    snap.scene
        .ok_or_else(|| BootstrapError::Runtime("no resident scene after render".to_string()))
}

/// Map the structured `KeyCode` (the PAL populates this; it does NOT populate the raw virtual-key
/// diagnostic) to the MSForms/Windows virtual-key number the VBA reducer routes by (Tab=9,
/// Enter=13, Escape=27, Space=32, edit keys, and a letter/digit's uppercased ASCII byte so
/// e.g. 'v' -> 86 for Ctrl+V). Unknown keys map to 0 (no special routing).
fn keycode_to_vk(key: &KeyCode) -> i16 {
    match key {
        KeyCode::Backspace => 8,
        KeyCode::Tab => 9,
        KeyCode::Enter => 13,
        KeyCode::Escape => 27,
        KeyCode::Space => 32,
        KeyCode::End => 35,
        KeyCode::Home => 36,
        KeyCode::ArrowLeft => 37,
        KeyCode::ArrowUp => 38,
        KeyCode::ArrowRight => 39,
        KeyCode::ArrowDown => 40,
        KeyCode::Delete => 46,
        KeyCode::Character(s) => s
            .chars()
            .next()
            .map_or(0, |c| i16::from(c.to_ascii_uppercase() as u8)),
        _ => 0,
    }
}

/// Build the OxVba session for the OxForms library + greeter, with `OxForms.Surface` registered.
fn build_session() -> Result<(ProjectRuntimeSession, Arc<SurfaceFactory>, FontTable), BootstrapError>
{
    let manifest = SymbolProjectManifest {
        project_name: "OxFormsBootstrap".to_string(),
        project_kind: ProjectKind::Library,
        modules: oxforms_modules(),
        references: Vec::new(),
        reference_projects: Vec::new(),
        conditional_constants: Default::default(),
    };

    let program = oxvba_bind::bind_program(&manifest, &oxvba_symbol::CatalogTypeLibResolver)
        .map_err(|err| BootstrapError::Project(format!("bind: {err:?}")))?;
    let bundle = oxvba_oxir::elaborate::elaborate(&program)
        .map_err(|err| BootstrapError::Project(format!("elaborate: {err:?}")))?;

    let font =
        load_ui_font().map_err(|err| BootstrapError::Window(format!("load UI font: {err}")))?;
    let shaper = AbGlyphShaper::new(FONT_ID, font.clone());
    let mut fonts = FontTable::new();
    fonts.add(FONT_ID, font);

    let projection = Arc::new(PortableComProjection::new());
    let surface = Arc::new(SurfaceFactory::with_shaper(Arc::new(shaper)));
    register_surface(&projection, surface.clone());

    let profile = HostProfileProvider::new()
        .with_portable_com_projection(projection)
        .with_host_policy(HostPolicy::interactive_dev());
    let engine = Engine::new(HostConfig { enable_jit: false }).with_host_profile_provider(profile);
    let session = engine
        .prepare_image_session(oxvba_oxir::OxImage::new(vec![bundle]))
        .map_err(|err| BootstrapError::Project(format!("prepare session: {err:?}")))?;
    Ok((session, surface, fonts))
}

fn unit(name: &str, kind: ModuleKind, source: &str) -> ModuleUnit {
    let mut attributes = ModuleAttributes::named(name);
    attributes.vb_exposed = true;
    attributes.vb_creatable = true;
    ModuleUnit {
        module_name: name.to_string(),
        module_kind: kind,
        attributes,
        source: source.to_string(),
    }
}

/// The OxForms VBA library + OxReducer + the greeter form-document, embedded at build time.
fn oxforms_modules() -> Vec<ModuleUnit> {
    use ModuleKind::{Class, Procedural};
    vec![
        unit(
            "OxFormsModel",
            Procedural,
            include_str!("../../../vba/oxforms/OxFormsModel.bas"),
        ),
        unit(
            "IOxControl",
            Class,
            include_str!("../../../vba/oxforms/IOxControl.cls"),
        ),
        unit(
            "IOxControlHost",
            Class,
            include_str!("../../../vba/oxforms/IOxControlHost.cls"),
        ),
        unit(
            "OxControlCore",
            Class,
            include_str!("../../../vba/oxforms/OxControlCore.cls"),
        ),
        unit(
            "Controls",
            Class,
            include_str!("../../../vba/oxforms/Controls.cls"),
        ),
        unit(
            "ReturnInteger",
            Class,
            include_str!("../../../vba/oxforms/ReturnInteger.cls"),
        ),
        unit(
            "ReturnBoolean",
            Class,
            include_str!("../../../vba/oxforms/ReturnBoolean.cls"),
        ),
        unit(
            "Label",
            Class,
            include_str!("../../../vba/oxforms/Label.cls"),
        ),
        unit(
            "TextBox",
            Class,
            include_str!("../../../vba/oxforms/TextBox.cls"),
        ),
        unit(
            "CommandButton",
            Class,
            include_str!("../../../vba/oxforms/CommandButton.cls"),
        ),
        unit(
            "CheckBox",
            Class,
            include_str!("../../../vba/oxforms/CheckBox.cls"),
        ),
        unit(
            "UserForm",
            Class,
            include_str!("../../../vba/oxforms/UserForm.cls"),
        ),
        unit(
            "OxTheme",
            Procedural,
            include_str!("../../../vba/oxforms/OxTheme.bas"),
        ),
        unit(
            "OxControlPaint",
            Procedural,
            include_str!("../../../vba/oxforms/OxControlPaint.bas"),
        ),
        unit(
            "OxSceneBuilder",
            Class,
            include_str!("../../../vba/oxforms/OxSceneBuilder.cls"),
        ),
        unit(
            "OxReducer",
            Class,
            include_str!("../../../vba/oxforms/OxReducer.cls"),
        ),
        unit(
            "ReducerGreeterForm",
            Class,
            include_str!("../../../vba/smoke/fixtures/reducer_greeter_form.cls"),
        ),
    ]
}

#[cfg(test)]
mod tests {
    use super::keycode_to_vk;
    use oxforms_pal::KeyCode;

    #[test]
    fn keycode_maps_to_the_reducer_virtual_keys() {
        assert_eq!(keycode_to_vk(&KeyCode::Tab), 9);
        assert_eq!(keycode_to_vk(&KeyCode::Enter), 13);
        assert_eq!(keycode_to_vk(&KeyCode::Escape), 27);
        assert_eq!(keycode_to_vk(&KeyCode::Space), 32);
        // A letter maps to its uppercased ASCII byte (so Ctrl+V resolves to V=86 in the reducer).
        assert_eq!(keycode_to_vk(&KeyCode::Character("v".to_string())), 86);
        assert_eq!(keycode_to_vk(&KeyCode::Character("A".to_string())), 65);
        assert_eq!(keycode_to_vk(&KeyCode::Unidentified), 0);
    }
}
