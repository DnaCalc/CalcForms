//! CalcForms thin bootstrap.
//!
//! The minimal native assembler for the live CalcForms slice. Per
//! `docs/specs/RENDERING_ARCHITECTURE.md` §16.3 it is a *thin assembler*: it loads the CalcVBA
//! project, configures the `CalcForms.Surface` boundary, attaches the thin `OxRuntime` to a VBA
//! form-document, and runs the platform loop — wiring the control-blind backend
//! (`calcforms-pal-win`) to the runtime (`calcforms-calcvba-adapter`). It holds **no** control or demo
//! behavior (that is VBA, owned by `OxInteractionManager` behind the `OxReducer` facade), and never
//! rasterizes (the backend owns Repaint).
//!
//! Frame model (§16): the runtime owns **Re-render** (`OxRuntime::render` → VBA self-render →
//! `CalcForms.Surface` → resident `Scene` revision); the backend owns **Repaint** (resident `Scene`
//! snapshot → pixels). The reducer-pivot design has no Rust reducer: the bootstrap maps a window
//! event to a normalized input, asks the VBA `OxReducer` (via `OxRuntime`) to handle it, and on a
//! state change re-renders and refreshes the held snapshot — so clicks/keys drive the VBA handlers
//! and the form updates live.
//!
//! Default demo: the living full-surface showcase — current controls, methods, and events.
//! Greeter remains available with `cargo run -p calcforms-bootstrap -- greeter`.
//!
//! Run: `cargo run -p calcforms-bootstrap`.

#![forbid(unsafe_code)]

mod input;
use input::{dispatch_event, is_deferred_plain_text_key};
#[cfg(test)]
use input::{is_ctrl_v, keycode_to_vk};

use std::cell::RefCell;
use std::rc::Rc;
use std::sync::Arc;

use calcforms_calcvba_adapter::host_services::HostServices;
use calcforms_calcvba_adapter::runtime::{OxRuntime, RuntimeEventTurn};
use calcforms_calcvba_adapter::surface::{register_surface, SurfaceFactory};
use calcforms_pal::scene::{FontId, Scene};
use calcforms_pal::{KeyCode, UiEvent, UiEventKind};
use calcforms_pal_win::{
    load_ui_font, run_scene_window, AbGlyphShaper, FontTable, WindowOptions, WindowSignal,
};

use calcvba_com::PortableComProjection;
use calcvba_engine::{Engine, HostConfig, HostProfileProvider, ProjectRuntimeSession};
use calcvba_hal::model::HostPolicy;
use calcvba_runtime::Variant;
use calcvba_symbol::manifest::{
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
    window_title: "CalcForms - full surface showcase",
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
    window_title: "CalcForms - W009 materialized frm",
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
    window_title: "CalcForms - W007 greeting (bootstrap)",
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
            "usage: cargo run -p calcforms-bootstrap -- [showcase|materialized-w009|greeter]\n\
             default: showcase"
                .to_string(),
        ),
        other => Err(format!(
            "unknown demo {other:?}; expected showcase, materialized-w009, or greeter"
        )),
    }
}

/// A precise, stage-tagged bootstrap failure (CalcVBA load/compile vs CalcForms runtime vs
/// PAL/backend vs normal exit are distinguishable).
#[derive(Debug)]
enum BootstrapError {
    /// CalcVBA project load / bind / elaborate / session prepare (compile-time stage).
    Project(String),
    /// CalcForms runtime: attaching `OxRuntime` / driving the VBA reducer + re-render (VBA entry).
    Runtime(String),
    /// PAL/window backend.
    Window(String),
}

impl std::fmt::Display for BootstrapError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Project(m) => write!(f, "CalcVBA project error: {m}"),
            Self::Runtime(m) => write!(f, "CalcForms runtime error: {m}"),
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
        Ok(()) => println!("calcforms-bootstrap: window closed; clean exit."),
        Err(err) => {
            eprintln!("calcforms-bootstrap: {err}");
            std::process::exit(err.exit_code());
        }
    }
}

fn run() -> Result<(), BootstrapError> {
    let demo = selected_demo().map_err(BootstrapError::Project)?;

    // 1. Load + configure the project: the CalcForms VBA library + the OxReducer + the selected
    //    form-document, with the CalcForms.Surface boundary registered so the form self-renders.
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
        HostServices::windows(calcforms_pal_win::read_clipboard_text),
    )
    .map_err(BootstrapError::Runtime)?;
    rt.render().map_err(BootstrapError::Runtime)?;
    let scene = current_scene(&surface)?;

    println!("calcforms-bootstrap: {}", demo.intro);
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
            "CALCFORMS_VISIBLE_CLOSE demo={};status=runtime_error;error={}",
            demo.marker_name,
            marker_escape(&err)
        );
        return Err(BootstrapError::Runtime(err));
    }
    match window_result {
        Ok(()) => {
            println!(
                "CALCFORMS_VISIBLE_CLOSE demo={};status=clean",
                demo.marker_name
            );
            Ok(())
        }
        Err(err) => {
            eprintln!(
                "CALCFORMS_VISIBLE_CLOSE demo={};status=window_error;error={}",
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
        "CALCFORMS_VISIBLE_READY demo={};window={};revision={};nodes={};textbox={}",
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
        "CALCFORMS_VISIBLE_TURN demo={};action={};effects={};host={};repainted={};revision={};nodes={};textbox={}",
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

/// Read the current resident `Scene` snapshot the runtime produced via `CalcForms.Surface`.
fn current_scene(surface: &Arc<SurfaceFactory>) -> Result<Scene, BootstrapError> {
    let snap = surface
        .snapshot()
        .map_err(|err| BootstrapError::Runtime(format!("surface snapshot: {err}")))?;
    snap.scene
        .ok_or_else(|| BootstrapError::Runtime("no resident scene after render".to_string()))
}

/// Build the CalcVBA session for the CalcForms library + selectable demos, with `CalcForms.Surface`
/// registered.
fn build_session() -> Result<(ProjectRuntimeSession, Arc<SurfaceFactory>, FontTable), BootstrapError>
{
    let manifest = SymbolProjectManifest {
        project_name: "CalcFormsBootstrap".to_string(),
        project_kind: ProjectKind::Library,
        modules: calcforms_modules(),
        references: Vec::new(),
        reference_projects: Vec::new(),
        conditional_constants: Default::default(),
        conditional_compilation_target: Default::default(),
    };

    let program = calcvba_bind::bind_program(&manifest, &calcvba_symbol::CatalogTypeLibResolver)
        .map_err(|err| BootstrapError::Project(format!("bind: {err:?}")))?;
    let bundle = calcvba_oxir::elaborate::elaborate(&program)
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
        .with_host_policy(HostPolicy::native());
    let engine = Engine::new(HostConfig::vm3()).with_host_profile_provider(profile);
    let session = engine
        .prepare_image_session(calcvba_oxir::OxImage::new(vec![bundle]))
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

/// The CalcForms VBA library + OxReducer + selectable form-documents, embedded at build time.
fn calcforms_modules() -> Vec<ModuleUnit> {
    use ModuleKind::{Class, Procedural};
    vec![
        unit(
            "CalcFormsModel",
            Procedural,
            include_str!("../../../vba/calcforms/CalcFormsModel.bas"),
        ),
        unit(
            "IOxControl",
            Class,
            include_str!("../../../vba/calcforms/IOxControl.cls"),
        ),
        unit(
            "IOxControlHost",
            Class,
            include_str!("../../../vba/calcforms/IOxControlHost.cls"),
        ),
        unit(
            "IOxControlContainer",
            Class,
            include_str!("../../../vba/calcforms/IOxControlContainer.cls"),
        ),
        unit(
            "OxControlCore",
            Class,
            include_str!("../../../vba/calcforms/OxControlCore.cls"),
        ),
        unit(
            "Controls",
            Class,
            include_str!("../../../vba/calcforms/Controls.cls"),
        ),
        unit(
            "ReturnInteger",
            Class,
            include_str!("../../../vba/calcforms/ReturnInteger.cls"),
        ),
        unit(
            "ReturnBoolean",
            Class,
            include_str!("../../../vba/calcforms/ReturnBoolean.cls"),
        ),
        unit(
            "Label",
            Class,
            include_str!("../../../vba/calcforms/Label.cls"),
        ),
        unit(
            "OxTextService",
            Class,
            include_str!("../../../vba/calcforms/OxTextService.cls"),
        ),
        unit(
            "TextBox",
            Class,
            include_str!("../../../vba/calcforms/TextBox.cls"),
        ),
        unit(
            "CommandButton",
            Class,
            include_str!("../../../vba/calcforms/CommandButton.cls"),
        ),
        unit(
            "CheckBox",
            Class,
            include_str!("../../../vba/calcforms/CheckBox.cls"),
        ),
        unit(
            "ListBox",
            Class,
            include_str!("../../../vba/calcforms/ListBox.cls"),
        ),
        unit(
            "ComboBox",
            Class,
            include_str!("../../../vba/calcforms/ComboBox.cls"),
        ),
        unit(
            "Frame",
            Class,
            include_str!("../../../vba/calcforms/Frame.cls"),
        ),
        unit(
            "Image",
            Class,
            include_str!("../../../vba/calcforms/Image.cls"),
        ),
        unit(
            "MultiPage",
            Class,
            include_str!("../../../vba/calcforms/MultiPage.cls"),
        ),
        unit(
            "Page",
            Class,
            include_str!("../../../vba/calcforms/Page.cls"),
        ),
        unit(
            "Pages",
            Class,
            include_str!("../../../vba/calcforms/Pages.cls"),
        ),
        unit(
            "SpinButton",
            Class,
            include_str!("../../../vba/calcforms/SpinButton.cls"),
        ),
        unit(
            "ScrollBar",
            Class,
            include_str!("../../../vba/calcforms/ScrollBar.cls"),
        ),
        unit("Tab", Class, include_str!("../../../vba/calcforms/Tab.cls")),
        unit(
            "Tabs",
            Class,
            include_str!("../../../vba/calcforms/Tabs.cls"),
        ),
        unit(
            "TabStrip",
            Class,
            include_str!("../../../vba/calcforms/TabStrip.cls"),
        ),
        unit(
            "ToggleButton",
            Class,
            include_str!("../../../vba/calcforms/ToggleButton.cls"),
        ),
        unit(
            "OptionButtonControl",
            Class,
            include_str!("../../../vba/calcforms/OptionButtonControl.cls"),
        ),
        unit(
            "UserForm",
            Class,
            include_str!("../../../vba/calcforms/UserForm.cls"),
        ),
        unit(
            "OxTheme",
            Procedural,
            include_str!("../../../vba/calcforms/OxTheme.bas"),
        ),
        unit(
            "OxControlPaint",
            Procedural,
            include_str!("../../../vba/calcforms/OxControlPaint.bas"),
        ),
        unit(
            "OxSceneBuilder",
            Class,
            include_str!("../../../vba/calcforms/OxSceneBuilder.cls"),
        ),
        unit(
            "OxAccessibilityService",
            Class,
            include_str!("../../../vba/calcforms/OxAccessibilityService.cls"),
        ),
        unit(
            "OxInteractionManager",
            Class,
            include_str!("../../../vba/calcforms/OxInteractionManager.cls"),
        ),
        unit(
            "OxReducer",
            Class,
            include_str!("../../../vba/calcforms/OxReducer.cls"),
        ),
        unit(
            "OxFrmMaterializer",
            Class,
            include_str!("../../../vba/calcforms/OxFrmMaterializer.cls"),
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
    use calcforms_calcvba_adapter::runtime::effect_log_contains_repaint;
    use calcforms_pal::{
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
