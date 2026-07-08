//! OxForms thin bootstrap.
//!
//! The minimal native assembler for the live OxForms slice. Per
//! `docs/specs/RENDERING_ARCHITECTURE.md` §16.3 it is a *thin assembler*: it loads the OxVba
//! project, configures the `OxForms.Surface` boundary, attaches the thin `OxRuntime` to a VBA
//! form-document, and runs the platform loop — wiring the control-blind backend
//! (`oxforms-pal-win`) to the runtime (`oxforms-oxvba-adapter`). It holds **no** control or demo
//! behavior (that is VBA, owned by `OxInteractionManager` behind the `OxReducer` facade), and never
//! rasterizes (the backend owns Repaint).
//!
//! Frame model (§16): the runtime owns **Re-render** (`OxRuntime::render` → VBA self-render →
//! `OxForms.Surface` → resident `Scene` revision); the backend owns **Repaint** (resident `Scene`
//! snapshot → pixels). The reducer-pivot design has no Rust reducer: the bootstrap maps a window
//! event to a normalized input, asks the VBA `OxReducer` (via `OxRuntime`) to handle it, and on a
//! state change re-renders and refreshes the held snapshot — so clicks/keys drive the VBA handlers
//! and the form updates live.
//!
//! Default demo: the living full-surface showcase — current controls, methods, and events.
//! Greeter remains available with `cargo run -p oxforms-bootstrap -- greeter`.
//!
//! Run: `cargo run -p oxforms-bootstrap`.

#![forbid(unsafe_code)]

use std::cell::RefCell;
use std::rc::Rc;
use std::sync::Arc;

use oxforms_oxvba_adapter::host_services::HostServices;
use oxforms_oxvba_adapter::runtime::{
    OxRuntime, RuntimeEventTurn, RuntimeInput, RuntimeKeyKind, RuntimeMouseKind,
};
use oxforms_oxvba_adapter::surface::{register_surface, SurfaceFactory};
use oxforms_pal::scene::{FontId, Scene};
use oxforms_pal::{
    CoordinatePayload, KeyCode, LogicalPoint, MouseButton, MouseButtons, UiEvent, UiEventKind,
};
use oxforms_pal_win::{
    load_ui_font, run_scene_window, AbGlyphShaper, FontTable, WindowOptions, WindowSignal,
};

use oxvba_com::PortableComProjection;
use oxvba_hal::model::HostPolicy;
use oxvba_host::{Engine, HostConfig, HostProfileProvider, ProjectRuntimeSession};
use oxvba_runtime::Variant;
use oxvba_symbol::manifest::{
    ModuleAttributes, ModuleKind, ModuleUnit, ProjectKind, SymbolProjectManifest,
};

/// The single UI font id the bootstrap registers; matches the VBA `OX_DEFAULT_FONT_ID` so the run
/// ids VBA emits resolve against the face the window rasterizes with.
const FONT_ID: FontId = FontId(1);

/// The selected VBA form-document class + its build entrypoint.
#[derive(Clone, Copy)]
struct DemoSpec {
    marker_name: &'static str,
    form_class: &'static str,
    build_member: &'static str,
    build_arg: Option<&'static str>,
    window_title: &'static str,
    window_width: f64,
    window_height: f64,
    intro: &'static str,
    escape_closes: bool,
}

const SHOWCASE_DEMO: DemoSpec = DemoSpec {
    marker_name: "showcase",
    form_class: "FullSurfaceShowcaseForm",
    build_member: "Build",
    build_arg: None,
    window_title: "OxForms - full surface showcase",
    window_width: 960.0,
    window_height: 640.0,
    intro: "showing the living VBA-rendered full-surface showcase. Interact with the current \
            controls, or close the window to exit.",
    escape_closes: false,
};

const MATERIALIZED_W009_DEMO: DemoSpec = DemoSpec {
    marker_name: "materialized-w009",
    form_class: "FrmMaterializationProbeForm",
    build_member: "BuildFromText",
    build_arg: Some(include_str!(
        "../../../fixtures/frm/w009-materialization/w009-representative.frm"
    )),
    window_title: "OxForms - W009 materialized frm",
    window_width: 760.0,
    window_height: 560.0,
    intro: "showing the W009 materialized .frm fixture through OxFrmMaterializer, OxRuntime, \
            and the live TextBox reducer path.",
    escape_closes: false,
};

const GREETER_DEMO: DemoSpec = DemoSpec {
    marker_name: "greeter",
    form_class: "ReducerGreeterForm",
    build_member: "Build",
    build_arg: None,
    window_title: "OxForms - W007 greeting (bootstrap)",
    window_width: 600.0,
    window_height: 360.0,
    intro: "showing the W007 greeting. Type a name, click OK (or press Enter) to greet; close or \
            press Escape to exit.",
    escape_closes: true,
};

fn selected_demo() -> Result<DemoSpec, String> {
    let Some(arg) = std::env::args().nth(1) else {
        return Ok(SHOWCASE_DEMO);
    };
    demo_from_arg(Some(arg.as_str()))
}

fn demo_from_arg(arg: Option<&str>) -> Result<DemoSpec, String> {
    let Some(arg) = arg else {
        return Ok(SHOWCASE_DEMO);
    };
    let key = arg.trim_start_matches('-').to_ascii_lowercase();
    match key.as_str() {
        "showcase" | "full-surface" | "surface" => Ok(SHOWCASE_DEMO),
        "materialized-w009" | "w009-materialized" | "w009-frm" | "frm" => {
            Ok(MATERIALIZED_W009_DEMO)
        }
        "greeter" | "w007" => Ok(GREETER_DEMO),
        "help" | "h" => Err(
            "usage: cargo run -p oxforms-bootstrap -- [showcase|materialized-w009|greeter]\n\
             default: showcase"
                .to_string(),
        ),
        other => Err(format!(
            "unknown demo {other:?}; expected showcase, materialized-w009, or greeter"
        )),
    }
}

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
    let demo = selected_demo().map_err(BootstrapError::Project)?;

    // 1. Load + configure the project: the OxForms VBA library + the OxReducer + the selected
    //    form-document, with the OxForms.Surface boundary registered so the form self-renders.
    let (session, surface, fonts) = build_session()?;

    // 2. Attach the thin runtime, which constructs + builds the VBA form (and its OxReducer) and
    //    produces the first resident Scene revision.
    let build_args = demo
        .build_arg
        .map(|arg| vec![Variant::from_string(arg)])
        .unwrap_or_default();
    let mut rt = OxRuntime::attach_with_host_services_and_args(
        session,
        demo.form_class,
        demo.build_member,
        build_args,
        HostServices::windows(oxforms_pal_win::read_clipboard_text),
    )
    .map_err(BootstrapError::Runtime)?;
    rt.render().map_err(BootstrapError::Runtime)?;
    let scene = current_scene(&surface)?;

    println!("oxforms-bootstrap: {}", demo.intro);
    print_visible_ready_marker(demo, &surface, &mut rt);

    // 3. Run the platform loop. The window owns Repaint (resident Scene snapshot -> pixels). The
    //    callback maps client pixels -> form-logical points (the uniform device-fit scale), asks
    //    the VBA reducer (via OxRuntime) to handle the input, re-renders, refreshes the held Scene
    //    from the resident snapshot, and asks for a Redraw. The bootstrap never rasterizes.
    let options = WindowOptions::new(demo.window_title, demo.window_width, demo.window_height);
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
                UiEventKind::KeyDown(e) if demo.escape_closes && e.key == KeyCode::Escape => {
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
            let turn = match dispatch_event(&mut rt, event, scale) {
                Ok(Some(turn)) => turn,
                Ok(None) => return WindowSignal::Ignore,
                Err(err) => {
                    *cb_error_inner.borrow_mut() = Some(err);
                    return WindowSignal::Close;
                }
            };
            if turn.effect_log.is_empty() {
                return WindowSignal::Ignore;
            }

            let already_rendered = turn.repainted;
            if !already_rendered && is_deferred_plain_text_key(event) {
                return WindowSignal::Ignore;
            }

            if !already_rendered {
                if let Err(err) = rt.render() {
                    *cb_error_inner.borrow_mut() = Some(format!("render: {err}"));
                    return WindowSignal::Close;
                }
            }
            match surface_cb.snapshot() {
                Ok(snap) => {
                    let revision = snap.revision;
                    let node_count = snap.node_count;
                    if let Some(next) = snap.scene {
                        *scene = next;
                    }
                    print_visible_turn_marker(demo, &mut rt, &turn, revision, node_count);
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
        eprintln!(
            "OXFORMS_VISIBLE_CLOSE demo={};status=runtime_error;error={}",
            demo.marker_name,
            marker_escape(&err)
        );
        return Err(BootstrapError::Runtime(err));
    }
    match window_result {
        Ok(()) => {
            println!(
                "OXFORMS_VISIBLE_CLOSE demo={};status=clean",
                demo.marker_name
            );
            Ok(())
        }
        Err(err) => {
            eprintln!(
                "OXFORMS_VISIBLE_CLOSE demo={};status=window_error;error={}",
                demo.marker_name,
                marker_escape(&err.to_string())
            );
            Err(BootstrapError::Window(err.to_string()))
        }
    }
}

fn print_visible_ready_marker(demo: DemoSpec, surface: &Arc<SurfaceFactory>, rt: &mut OxRuntime) {
    let (revision, node_count) = match surface.snapshot() {
        Ok(snap) => (snap.revision, snap.node_count),
        Err(_) => (0, 0),
    };
    println!(
        "OXFORMS_VISIBLE_READY demo={};window={};revision={};nodes={};textbox={}",
        demo.marker_name,
        marker_escape(demo.window_title),
        revision,
        node_count,
        textbox_marker(rt)
    );
}

fn print_visible_turn_marker(
    demo: DemoSpec,
    rt: &mut OxRuntime,
    turn: &RuntimeEventTurn,
    revision: u64,
    node_count: usize,
) {
    println!(
        "OXFORMS_VISIBLE_TURN demo={};action={};effects={};host={};repainted={};revision={};nodes={};textbox={}",
        demo.marker_name,
        marker_escape(&turn.action),
        marker_escape(&turn.effect_log),
        marker_escape(&turn.host_service_effects.join("|")),
        turn.repainted,
        revision,
        node_count,
        textbox_marker(rt)
    );
}

fn textbox_marker(rt: &mut OxRuntime) -> String {
    rt.read_string("TextBoxDiagnostics")
        .unwrap_or_else(|err| format!("unavailable={}", marker_escape(&err)))
        .replace('\r', "\\r")
        .replace('\n', "\\n")
}

fn marker_escape(value: &str) -> String {
    value
        .replace('\r', "\\r")
        .replace('\n', "\\n")
        .replace('\t', "\\t")
}

/// Map a window event to the VBA reducer call. Returns `Ok(Some(effect_log))` for a dispatched
/// event (empty log = no state change), `Ok(None)` for an event kind the demo ignores.
fn dispatch_event(
    rt: &mut OxRuntime,
    event: &UiEvent,
    scale: f64,
) -> Result<Option<RuntimeEventTurn>, String> {
    let shift = |m: &oxforms_pal::KeyboardModifiers| -> i16 {
        (if m.shift { 1 } else { 0 })
            | (if m.control { 2 } else { 0 })
            | (if m.alt { 4 } else { 0 })
    };
    match &event.kind {
        UiEventKind::MouseDown(e) | UiEventKind::MouseUp(e) => {
            let (x, y) = logical_point(&e.coordinates, scale);
            let kind = if matches!(event.kind, UiEventKind::MouseDown(_)) {
                RuntimeMouseKind::Down
            } else {
                RuntimeMouseKind::Up
            };
            rt.dispatch_event_turn(RuntimeInput::Mouse {
                kind,
                x,
                y,
                button: mouse_button(e.button),
                shift: shift(&e.modifiers),
            })
            .map(Some)
        }
        UiEventKind::MouseMove(e) => {
            let (x, y) = logical_point(&e.coordinates, scale);
            rt.dispatch_event_turn(RuntimeInput::Mouse {
                kind: RuntimeMouseKind::Move,
                x,
                y,
                button: mouse_buttons(&e.buttons_down),
                shift: shift(&e.modifiers),
            })
            .map(Some)
        }
        UiEventKind::KeyDown(e) | UiEventKind::KeyUp(e) => {
            let vk = keycode_to_vk(&e.key);
            let shift_bits = shift(&e.modifiers);
            let input =
                if matches!(event.kind, UiEventKind::KeyDown(_)) && is_ctrl_v(vk, shift_bits) {
                    // Read the live OS clipboard only for Ctrl+V. The HostServices trace stays
                    // attached to this event turn.
                    RuntimeInput::PasteFromClipboard
                } else {
                    let kind = if matches!(event.kind, UiEventKind::KeyDown(_)) {
                        RuntimeKeyKind::Down
                    } else {
                        RuntimeKeyKind::Up
                    };
                    RuntimeInput::Key {
                        kind,
                        key_code: vk,
                        shift: shift_bits,
                    }
                };
            rt.dispatch_event_turn(input).map(Some)
        }
        UiEventKind::CharacterInput(e) => rt
            .dispatch_event_turn(RuntimeInput::CharacterInput(e.text.clone()))
            .map(Some),
        _ => Ok(None),
    }
}

fn is_ctrl_v(vk: i16, shift: i16) -> bool {
    (shift & 2) != 0 && vk == 86
}

fn is_deferred_plain_text_key(event: &UiEvent) -> bool {
    match &event.kind {
        UiEventKind::KeyDown(e) | UiEventKind::KeyUp(e) => {
            !e.modifiers.control
                && !e.modifiers.alt
                && matches!(e.key, KeyCode::Character(_) | KeyCode::Space)
        }
        _ => false,
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

fn mouse_buttons(buttons: &MouseButtons) -> i16 {
    if buttons.left {
        1
    } else if buttons.right {
        2
    } else if buttons.middle {
        3
    } else {
        0
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
        KeyCode::Character(s) => s.chars().next().map_or(0, char_to_vk),
        _ => 0,
    }
}

fn char_to_vk(c: char) -> i16 {
    match c.to_ascii_uppercase() {
        'A'..='Z' | '0'..='9' => i16::from(c.to_ascii_uppercase() as u8),
        ' ' => 32,
        ';' | ':' => 0xBA,
        '=' | '+' => 0xBB,
        ',' | '<' => 0xBC,
        '-' | '_' => 0xBD,
        '.' | '>' => 0xBE,
        '/' | '?' => 0xBF,
        '`' | '~' => 0xC0,
        '[' | '{' => 0xDB,
        '\\' | '|' => 0xDC,
        ']' | '}' => 0xDD,
        '\'' | '"' => 0xDE,
        _ => 0,
    }
}

/// Build the OxVba session for the OxForms library + selectable demos, with `OxForms.Surface`
/// registered.
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

/// The OxForms VBA library + OxReducer + selectable form-documents, embedded at build time.
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
            "IOxControlContainer",
            Class,
            include_str!("../../../vba/oxforms/IOxControlContainer.cls"),
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
            "OxTextService",
            Class,
            include_str!("../../../vba/oxforms/OxTextService.cls"),
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
            "ListBox",
            Class,
            include_str!("../../../vba/oxforms/ListBox.cls"),
        ),
        unit(
            "ComboBox",
            Class,
            include_str!("../../../vba/oxforms/ComboBox.cls"),
        ),
        unit(
            "Frame",
            Class,
            include_str!("../../../vba/oxforms/Frame.cls"),
        ),
        unit(
            "Image",
            Class,
            include_str!("../../../vba/oxforms/Image.cls"),
        ),
        unit(
            "MultiPage",
            Class,
            include_str!("../../../vba/oxforms/MultiPage.cls"),
        ),
        unit("Page", Class, include_str!("../../../vba/oxforms/Page.cls")),
        unit(
            "Pages",
            Class,
            include_str!("../../../vba/oxforms/Pages.cls"),
        ),
        unit(
            "SpinButton",
            Class,
            include_str!("../../../vba/oxforms/SpinButton.cls"),
        ),
        unit(
            "ScrollBar",
            Class,
            include_str!("../../../vba/oxforms/ScrollBar.cls"),
        ),
        unit("Tab", Class, include_str!("../../../vba/oxforms/Tab.cls")),
        unit("Tabs", Class, include_str!("../../../vba/oxforms/Tabs.cls")),
        unit(
            "TabStrip",
            Class,
            include_str!("../../../vba/oxforms/TabStrip.cls"),
        ),
        unit(
            "ToggleButton",
            Class,
            include_str!("../../../vba/oxforms/ToggleButton.cls"),
        ),
        unit(
            "OptionButtonControl",
            Class,
            include_str!("../../../vba/oxforms/OptionButtonControl.cls"),
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
            "OxAccessibilityService",
            Class,
            include_str!("../../../vba/oxforms/OxAccessibilityService.cls"),
        ),
        unit(
            "OxInteractionManager",
            Class,
            include_str!("../../../vba/oxforms/OxInteractionManager.cls"),
        ),
        unit(
            "OxReducer",
            Class,
            include_str!("../../../vba/oxforms/OxReducer.cls"),
        ),
        unit(
            "OxFrmMaterializer",
            Class,
            include_str!("../../../vba/oxforms/OxFrmMaterializer.cls"),
        ),
        unit(
            "ReducerGreeterForm",
            Class,
            include_str!("../../../vba/smoke/fixtures/reducer_greeter_form.cls"),
        ),
        unit(
            "FullSurfaceShowcaseForm",
            Class,
            include_str!("../../../vba/smoke/fixtures/full_surface_showcase_form.cls"),
        ),
        unit(
            "FrmMaterializationProbeForm",
            Class,
            include_str!("../../../vba/smoke/fixtures/frm_materialization_probe_form.cls"),
        ),
    ]
}

#[cfg(test)]
mod tests {
    use super::{
        demo_from_arg, is_ctrl_v, is_deferred_plain_text_key, keycode_to_vk, marker_escape,
    };
    use oxforms_oxvba_adapter::runtime::effect_log_contains_repaint;
    use oxforms_pal::{
        KeyCode, KeyEvent, KeyRepeat, KeyboardModifiers, RawKeyDiagnostics, UiEvent, UiEventId,
        UiEventKind, UiEventSource,
    };

    #[test]
    fn keycode_maps_to_the_reducer_virtual_keys() {
        assert_eq!(keycode_to_vk(&KeyCode::Tab), 9);
        assert_eq!(keycode_to_vk(&KeyCode::Enter), 13);
        assert_eq!(keycode_to_vk(&KeyCode::Escape), 27);
        assert_eq!(keycode_to_vk(&KeyCode::Space), 32);
        // A letter maps to its uppercased ASCII byte (so Ctrl+V resolves to V=86 in the reducer).
        assert_eq!(keycode_to_vk(&KeyCode::Character("v".to_string())), 86);
        assert_eq!(keycode_to_vk(&KeyCode::Character("A".to_string())), 65);
        assert_eq!(keycode_to_vk(&KeyCode::Character(".".to_string())), 0xBE);
        assert_eq!(keycode_to_vk(&KeyCode::Character("?".to_string())), 0xBF);
        assert_eq!(keycode_to_vk(&KeyCode::Unidentified), 0);
    }

    #[test]
    fn quick_typing_render_filters_identify_repaint_and_plain_text_keys() {
        assert!(effect_log_contains_repaint("keydown:InputField|repaint"));
        assert!(!effect_log_contains_repaint("keydown:InputField"));
        assert!(is_ctrl_v(86, 2));
        assert!(!is_ctrl_v(65, 2));

        let plain = key_event(
            KeyCode::Character("a".to_string()),
            KeyboardModifiers::default(),
        );
        assert!(is_deferred_plain_text_key(&plain));

        let ctrl = key_event(
            KeyCode::Character("v".to_string()),
            KeyboardModifiers {
                control: true,
                ..KeyboardModifiers::default()
            },
        );
        assert!(!is_deferred_plain_text_key(&ctrl));
    }

    fn key_event(key: KeyCode, modifiers: KeyboardModifiers) -> UiEvent {
        UiEvent::new(
            UiEventId(1),
            UiEventSource::Pal,
            UiEventKind::KeyDown(KeyEvent {
                key,
                modifiers,
                repeat: KeyRepeat {
                    is_repeat: false,
                    repeat_count: None,
                },
                raw: RawKeyDiagnostics::default(),
            }),
        )
    }

    #[test]
    fn demo_selector_includes_materialized_w009() {
        let demo = demo_from_arg(Some("materialized-w009")).expect("materialized demo");
        assert_eq!(demo.marker_name, "materialized-w009");
        assert_eq!(demo.form_class, "FrmMaterializationProbeForm");
        assert_eq!(demo.build_member, "BuildFromText");
        assert!(
            demo.build_arg
                .expect("representative .frm text")
                .contains("W009MaterializationForm"),
            "materialized demo should embed the representative .frm text"
        );
    }

    #[test]
    fn visible_marker_escape_keeps_markers_single_line() {
        assert_eq!(marker_escape("a\r\nb\tc"), "a\\r\\nb\\tc");
    }
}
