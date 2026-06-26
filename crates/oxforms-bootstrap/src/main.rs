//! W007 thin bootstrap (oxforms-4pn.7).
//!
//! The minimal native assembler for the W007 vertical slice. Per
//! `docs/specs/RENDERING_ARCHITECTURE.md` §16.3 it is a *thin assembler*: it loads the
//! OxVba project, configures the `OxForms.Surface` boundary, invokes the VBA startup
//! (here: construct + build the demo form via the runtime), and runs the platform
//! loop — wiring the control-blind backend (`oxforms-pal-win`) to the runtime
//! (`oxforms-oxvba-adapter`). It holds **no** control or demo behavior (that is VBA),
//! never calls VBA directly (the runtime owns all VBA entry), and never rasterizes
//! (the backend owns Repaint).
//!
//! Frame model (§16): the runtime owns **Re-render** (`render_frame` → VBA self-render
//! → `OxForms.Surface` → resident `Scene` revision); the backend owns **Repaint**
//! (resident `Scene` snapshot → pixels). This bootstrap produces the first resident
//! revision, hands the snapshot to the window, and runs the loop.
//!
//! Scope: the live window shows the VBA-rendered form with **captions** (the text seam,
//! oxforms-4pn.10–.13) and an **interaction loop** (oxforms-4pn.8e): the callback maps
//! input to form-logical points, asks the runtime to `dispatch` it, and on a requested
//! repaint `render_frame`s + refreshes the held snapshot — so typing + clicking OK drives
//! the VBA handlers and the greeting updates live.
//!
//! Run: `cargo run -p oxforms-bootstrap`

#![forbid(unsafe_code)]

use std::cell::RefCell;
use std::rc::Rc;
use std::sync::Arc;

use oxforms_core::materialize_w007_demo_form;
use oxforms_oxvba_adapter::runtime_runner::RuntimeRunner;
use oxforms_oxvba_adapter::surface::{register_surface, SurfaceFactory};
use oxforms_pal::scene::{FontId, Scene};
use oxforms_pal::{CoordinatePayload, LogicalPoint, UiEvent, UiEventKind};
use oxforms_pal_win::{
    load_ui_font, run_scene_window, AbGlyphShaper, FontTable, WindowOptions, WindowSignal,
};

/// The single UI font id the bootstrap registers; matches the VBA `OX_DEFAULT_FONT_ID`
/// so the run ids VBA emits resolve against the face the window rasterizes with.
const FONT_ID: FontId = FontId(1);

use oxvba_bundle::BundlePackage;
use oxvba_com::PortableComProjection;
use oxvba_hal::model::HostPolicy;
use oxvba_host::{Engine, HostConfig, HostProfileProvider, ProjectRuntimeSession};
use oxvba_symbol::manifest::{
    ModuleAttributes, ModuleKind, ModuleUnit, ProjectKind, SymbolProjectManifest,
};

/// The W007 demo form class the bootstrap instantiates (its controls/handlers are
/// VBA; the bootstrap only names the entrypoint, never the layout).
///
/// Interim: this reuses the `vba/smoke/fixtures` object-model form (shared with the
/// runtime tests) so the slice is runnable now. The next increment (oxforms-4pn.8)
/// promotes it to a proper demo module with a real `Sub Main` startup; the bootstrap
/// then loads that demo project rather than embedding a smoke fixture.
const DEMO_FORM_CLASS: &str = "W007ObjectModelProbeForm";
const DEMO_BUILD_MEMBER: &str = "Build";
const DEMO_FORM_ACCESSOR: &str = "Form";

/// A precise, stage-tagged bootstrap failure (acceptance: OxVba load/compile vs
/// OxForms runtime vs PAL/backend vs normal exit are distinguishable).
#[derive(Debug)]
enum BootstrapError {
    /// OxVba project load / bind / linearize / session prepare (compile-time stage).
    Project(String),
    /// OxForms runtime: form materialization (pure Rust) or attaching the runner /
    /// re-rendering the form (the latter two are VBA entry).
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
    // 1. Load + configure the project: the OxForms VBA library + the demo form, with
    //    the OxForms.Surface boundary registered so the form can self-render.
    let (session, surface, fonts) = build_session()?;

    // 2. Invoke the VBA startup (minimal entrypoint): materialize the demo form into
    //    runtime state and attach the runtime, which constructs + builds the VBA form.
    let runtime_form = materialize_w007_demo_form()
        .map_err(|err| BootstrapError::Runtime(format!("materialize demo form: {err}")))?;
    let mut runner = RuntimeRunner::attach(
        session,
        runtime_form,
        DEMO_FORM_CLASS,
        DEMO_BUILD_MEMBER,
        DEMO_FORM_ACCESSOR,
    )
    .map_err(|err| BootstrapError::Runtime(format!("attach runtime: {err}")))?;

    // 3. Produce the first resident Scene revision (the runtime's Re-render).
    runner
        .render_frame()
        .map_err(|err| BootstrapError::Runtime(format!("initial render_frame: {err}")))?;
    let scene = current_scene(&surface)?;

    println!(
        "oxforms-bootstrap: showing the live VBA-rendered W007 form. Type a name, click \
         OK to greet; close or press Escape to exit."
    );

    // 4. Run the platform loop with the interaction consumer loop (oxforms-4pn.8e). The
    //    window owns Repaint (resident Scene snapshot -> pixels). The callback is the
    //    consumer: it maps client pixels -> form-logical points (the uniform device-fit
    //    scale, mirrored from the rasterizer), asks the runtime to `dispatch` the event
    //    (a VM entry the runtime owns), and — when the runtime requests a repaint —
    //    `render_frame`s, refreshes the held Scene from the resident snapshot, and asks
    //    for a `Redraw`. The bootstrap never calls VBA or rasterizes directly.
    let options = WindowOptions::new("OxForms - W007 (bootstrap)", 600.0, 360.0);
    let (form_w, form_h) = (
        f64::from(scene.surface.width.max(1)),
        f64::from(scene.surface.height.max(1)),
    );
    // Tracks the PHYSICAL window size for the client->logical scale. Seeded with the
    // logical option size as a placeholder — winit fires a Resize on window creation
    // (before any input), which overwrites it with the true physical inner size, so the
    // logical-vs-physical unit mismatch in this seed is never used to map a real event.
    let mut window_px = (options.logical_width, options.logical_height);
    let surface_cb = surface.clone();
    // Interaction errors (a VBA dispatch / render failure) propagate to the exit code
    // rather than silently closing the window as a clean exit.
    let cb_error: Rc<RefCell<Option<String>>> = Rc::new(RefCell::new(None));
    let cb_error_inner = cb_error.clone();

    let window_result = run_scene_window(
        options,
        scene,
        fonts,
        move |event: &UiEvent, scene: &mut Scene| {
            if is_close(event) {
                return WindowSignal::Close;
            }
            // Track the physical window size so client->logical uses the live device scale.
            if let UiEventKind::Resize(e) = &event.kind {
                if let Some(size) = e.client_size {
                    window_px = (size.width, size.height);
                }
                return WindowSignal::Ignore;
            }
            // Only route events the runtime acts on (skip moves/focus/etc. for the demo).
            let dispatchable = matches!(
                &event.kind,
                UiEventKind::MouseDown(_)
                    | UiEventKind::MouseUp(_)
                    | UiEventKind::CharacterInput(_)
                    | UiEventKind::KeyDown(_)
                    | UiEventKind::KeyUp(_)
            );
            if !dispatchable {
                return WindowSignal::Ignore;
            }

            let scale = (window_px.0 / form_w).min(window_px.1 / form_h);
            let scale = if scale > 0.0 { scale } else { 1.0 };
            let routed = fill_form_logical(event, scale);

            match runner.dispatch(routed) {
                Ok(step) => {
                    if !step.repaint_requested {
                        return WindowSignal::Ignore;
                    }
                    if let Err(err) = runner.render_frame() {
                        *cb_error_inner.borrow_mut() = Some(format!("render_frame: {err}"));
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
                }
                Err(err) => {
                    *cb_error_inner.borrow_mut() = Some(format!("dispatch: {err}"));
                    WindowSignal::Close
                }
            }
        },
    );

    // A stored interaction (VBA dispatch/render) error is the more actionable root cause:
    // surface it BEFORE a window/surface error so a teardown-time window failure cannot
    // mask the real cause, and the exit stage is correct (Runtime=3, not Window=4).
    if let Some(err) = cb_error.borrow_mut().take() {
        return Err(BootstrapError::Runtime(err));
    }
    window_result.map_err(|err| BootstrapError::Window(err.to_string()))
}

/// Clone `event`, filling each mouse coordinate payload's `form_logical` from its
/// `client_pixels` divided by the uniform device-fit `scale` (the same scale the
/// rasterizer applies), so the reducer routes the event by form-logical points. Non-mouse
/// events are returned unchanged.
fn fill_form_logical(event: &UiEvent, scale: f64) -> UiEvent {
    let mut ev = event.clone();
    let remap = |coords: &mut CoordinatePayload| {
        if let Some(px) = coords.client_pixels {
            coords.form_logical = Some(LogicalPoint::new(px.x / scale, px.y / scale));
        }
    };
    match &mut ev.kind {
        UiEventKind::MouseDown(e) | UiEventKind::MouseUp(e) => remap(&mut e.coordinates),
        UiEventKind::MouseMove(e) => remap(&mut e.coordinates),
        _ => {}
    }
    ev
}

/// Read the current resident `Scene` snapshot the runtime produced via `OxForms.Surface`.
fn current_scene(surface: &Arc<SurfaceFactory>) -> Result<Scene, BootstrapError> {
    let snap = surface
        .snapshot()
        .map_err(|err| BootstrapError::Runtime(format!("surface snapshot: {err}")))?;
    snap.scene
        .ok_or_else(|| BootstrapError::Runtime("no resident scene after render_frame".to_string()))
}

fn is_close(event: &UiEvent) -> bool {
    matches!(&event.kind, UiEventKind::CloseRequest(_))
        || matches!(
            &event.kind,
            UiEventKind::KeyDown(e) if e.key == oxforms_pal::KeyCode::Escape
        )
}

/// Build the OxVba session for the OxForms library + demo form, with `OxForms.Surface`
/// registered. The VBA sources are embedded so the bootstrap runs from anywhere.
fn build_session() -> Result<(ProjectRuntimeSession, Arc<SurfaceFactory>, FontTable), BootstrapError>
{
    let manifest = SymbolProjectManifest {
        project_name: "OxFormsW007Bootstrap".to_string(),
        project_kind: ProjectKind::Library,
        modules: oxforms_modules(),
        references: Vec::new(),
        reference_projects: Vec::new(),
        conditional_constants: Default::default(),
    };

    let program = oxvba_bind::bind_program(&manifest, &oxvba_symbol::CatalogTypeLibResolver)
        .map_err(|err| BootstrapError::Project(format!("bind: {err:?}")))?;
    let bundle = oxvba_bundle::linearize(&program)
        .map_err(|err| BootstrapError::Project(format!("linearize: {err:?}")))?;

    // Load the UI font once: the shaper (Surface-side, shapes captions into the resident
    // scene on MeasureText) and the rasterizer's FontTable (window-side) share the same
    // face under FONT_ID, so VBA-emitted run ids resolve at paint time. VBA now always
    // measures text, so a shaper is required (no longer chrome-only).
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
        .prepare_bundle_package_session(BundlePackage::single(bundle))
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

/// The OxForms VBA library modules + the W007 demo form, embedded at build time.
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
            "OxReturnInteger",
            Class,
            include_str!("../../../vba/oxforms/OxReturnInteger.cls"),
        ),
        unit(
            "OxReturnBoolean",
            Class,
            include_str!("../../../vba/oxforms/OxReturnBoolean.cls"),
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
            "OxUserForm",
            Class,
            include_str!("../../../vba/oxforms/OxUserForm.cls"),
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
            DEMO_FORM_CLASS,
            Class,
            include_str!("../../../vba/smoke/fixtures/w007_object_model_probe_form.cls"),
        ),
    ]
}
