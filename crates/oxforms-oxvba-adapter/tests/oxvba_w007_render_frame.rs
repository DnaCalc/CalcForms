//! W007 Re-render seam end to end on OxVba (oxforms-4pn.7).
//!
//! Proves the §16 Re-render the runtime owns: `RuntimeRunner::render_frame` invokes
//! the form's VBA `OxUserForm.Render`, which self-renders the whole form into one
//! batched `ScenePatch` and submits it across the injected `OxForms.Surface`,
//! advancing the resident control-blind `Scene` the backend repaints. This is the
//! runtime half of the frame model (`RENDERING_ARCHITECTURE.md` §16): the runtime is
//! the sole owner of all VBA entry — both `dispatch` and `render_frame` — and the
//! resident `Scene` (in `OxForms.Surface`) is the producer/consumer seam.
//!
//! Non-claim: caption *text* is not yet in the resident scene. `DrawText` carries run
//! id 0 because the `MeasureText`/`RegisterFont` text-run crossing is deferred
//! (`RENDERING_ARCHITECTURE.md` §6/§8), so a text-only change leaves the chrome token
//! unchanged. The resident scene carries the form chrome (fills + 3D edges); caption
//! rendering across the live boundary lands with the text-run crossing.

use std::path::{Path, PathBuf};
use std::sync::Arc;

use oxforms_core::materialize_w007_demo_form;
use oxforms_oxvba_adapter::runtime_runner::RuntimeRunner;
use oxforms_oxvba_adapter::surface::{register_surface, SurfaceFactory};
use oxforms_pal::{
    CharacterInputEvent, ClickCount, ControlId, CoordinatePayload, KeyboardModifiers, LogicalPoint,
    MouseButton, MouseButtonEvent, MouseButtons, PointerId, UiEvent, UiEventId, UiEventKind,
    UiEventSource,
};

use oxvba_bundle::BundlePackage;
use oxvba_com::PortableComProjection;
use oxvba_hal::model::HostPolicy;
use oxvba_host::{Engine, HostConfig, HostProfileProvider, ProjectRuntimeSession};
use oxvba_symbol::manifest::{
    ModuleAttributes, ModuleKind, ModuleUnit, ProjectKind, SymbolProjectManifest,
};

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("..").join("..")
}

fn read_source(relative: &str) -> String {
    let path = repo_root().join(relative);
    std::fs::read_to_string(&path).unwrap_or_else(|err| panic!("read {}: {err}", path.display()))
}

fn module_unit(name: &str, kind: ModuleKind, relative: &str) -> ModuleUnit {
    let mut attributes = ModuleAttributes::named(name);
    attributes.vb_exposed = true;
    attributes.vb_creatable = true;
    ModuleUnit {
        module_name: name.to_string(),
        module_kind: kind,
        attributes,
        source: read_source(relative),
    }
}

/// Build a session with the OxForms VBA library + the object-model fixture, and the
/// `OxForms.Surface` boundary registered so the form's `Render` can self-render.
fn prepare_session_with_surface() -> (ProjectRuntimeSession, Arc<SurfaceFactory>) {
    let manifest = SymbolProjectManifest {
        project_name: "W007RenderFrame".to_string(),
        project_kind: ProjectKind::Library,
        modules: vec![
            module_unit(
                "OxFormsModel",
                ModuleKind::Procedural,
                "vba/oxforms/OxFormsModel.bas",
            ),
            module_unit(
                "IOxControl",
                ModuleKind::Class,
                "vba/oxforms/IOxControl.cls",
            ),
            module_unit(
                "IOxControlHost",
                ModuleKind::Class,
                "vba/oxforms/IOxControlHost.cls",
            ),
            module_unit(
                "OxControlCore",
                ModuleKind::Class,
                "vba/oxforms/OxControlCore.cls",
            ),
            module_unit(
                "OxReturnInteger",
                ModuleKind::Class,
                "vba/oxforms/OxReturnInteger.cls",
            ),
            module_unit(
                "OxReturnBoolean",
                ModuleKind::Class,
                "vba/oxforms/OxReturnBoolean.cls",
            ),
            module_unit("Label", ModuleKind::Class, "vba/oxforms/Label.cls"),
            module_unit("TextBox", ModuleKind::Class, "vba/oxforms/TextBox.cls"),
            module_unit(
                "CommandButton",
                ModuleKind::Class,
                "vba/oxforms/CommandButton.cls",
            ),
            module_unit(
                "OxUserForm",
                ModuleKind::Class,
                "vba/oxforms/OxUserForm.cls",
            ),
            module_unit("OxTheme", ModuleKind::Procedural, "vba/oxforms/OxTheme.bas"),
            module_unit(
                "OxControlPaint",
                ModuleKind::Procedural,
                "vba/oxforms/OxControlPaint.bas",
            ),
            module_unit(
                "OxSceneBuilder",
                ModuleKind::Class,
                "vba/oxforms/OxSceneBuilder.cls",
            ),
            module_unit(
                "W007ObjectModelProbeForm",
                ModuleKind::Class,
                "vba/smoke/fixtures/w007_object_model_probe_form.cls",
            ),
        ],
        references: Vec::new(),
        reference_projects: Vec::new(),
        conditional_constants: Default::default(),
    };

    let program = oxvba_bind::bind_program(&manifest, &oxvba_symbol::CatalogTypeLibResolver)
        .expect("bind W007 render-frame project");
    let bundle = oxvba_bundle::linearize(&program).expect("linearize W007 render-frame project");

    let projection = Arc::new(PortableComProjection::new());
    let surface = Arc::new(SurfaceFactory::new());
    register_surface(&projection, surface.clone());

    let profile = HostProfileProvider::new()
        .with_portable_com_projection(projection)
        .with_host_policy(HostPolicy::interactive_dev());
    let engine = Engine::new(HostConfig { enable_jit: false }).with_host_profile_provider(profile);
    let session = engine
        .prepare_bundle_package_session(BundlePackage::single(bundle))
        .expect("prepare W007 render-frame session");
    (session, surface)
}

fn mouse_event(left_down: bool, x: f64, y: f64) -> MouseButtonEvent {
    MouseButtonEvent {
        pointer_id: Some(PointerId(1)),
        button: MouseButton::Left,
        buttons_down: MouseButtons {
            left: left_down,
            ..MouseButtons::default()
        },
        modifiers: KeyboardModifiers::default(),
        click_count: ClickCount(1),
        coordinates: CoordinatePayload {
            form_logical: Some(LogicalPoint::new(x, y)),
            ..CoordinatePayload::default()
        },
    }
}

fn ui_event(id: u64, kind: UiEventKind) -> UiEvent {
    UiEvent::new(UiEventId(id), UiEventSource::Replay, kind)
}

fn label_caption(runner: &RuntimeRunner, name: &str) -> String {
    runner
        .form()
        .state
        .controls
        .iter()
        .find(|control| control.control_id == ControlId::new(name))
        .map(|control| control.caption.clone())
        .unwrap_or_else(|| panic!("control {name} present in runtime state"))
}

#[test]
fn render_frame_drives_vba_self_render_into_the_resident_scene() {
    let (session, surface) = prepare_session_with_surface();
    let runtime_form = materialize_w007_demo_form().expect("materialize W007 demo form");
    let mut runner = RuntimeRunner::attach(
        session,
        runtime_form,
        "W007ObjectModelProbeForm",
        "Build",
        "Form",
    )
    .expect("attach runtime runner");

    // Attach does not paint: the surface is untouched until the runtime re-renders.
    assert_eq!(
        surface.snapshot().expect("snapshot").revision,
        0,
        "attach performs no Surface crossing"
    );

    // Re-render: the form self-renders its 4-node chrome across OxForms.Surface.
    runner.render_frame().expect("render_frame");
    let snap1 = surface.snapshot().expect("snapshot");
    assert_eq!(
        snap1.node_count, 4,
        "the form root plus three controls become four retained nodes"
    );
    assert!(
        !snap1.last_stale_base,
        "a full rebuild applies against its own fresh BeginScene base"
    );
    let report1 = snap1.last_report.expect("a render report");
    assert_eq!(
        (report1.width, report1.height),
        (200, 120),
        "surface extent crossed from the form geometry"
    );
    let token1 = snap1.frame_token.expect("a resident frame token");
    assert!(
        snap1.revision >= 1,
        "the first render advanced the revision"
    );

    // Re-render again with no state change: deterministic full rebuild → identical
    // resident content (same token), but a fresh frame (revision advances).
    runner.render_frame().expect("render_frame #2");
    let snap2 = surface.snapshot().expect("snapshot");
    assert_eq!(
        snap2.frame_token,
        Some(token1),
        "unchanged content re-renders to an identical resident token (determinism)"
    );
    assert!(
        snap2.revision > snap1.revision,
        "each render_frame produces a new resident revision"
    );

    // The runtime drives both dispatch and render: focus the field, type, click OK
    // (its native VBA handler sets the label from the typed text).
    runner
        .dispatch(ui_event(
            1,
            UiEventKind::MouseDown(mouse_event(true, 20.0, 18.0)),
        ))
        .expect("press field");
    runner
        .dispatch(ui_event(
            2,
            UiEventKind::MouseUp(mouse_event(false, 20.0, 18.0)),
        ))
        .expect("release field");
    runner
        .dispatch(ui_event(
            3,
            UiEventKind::CharacterInput(CharacterInputEvent {
                text: "World".to_string(),
                modifiers: KeyboardModifiers::default(),
                raw: Vec::new(),
            }),
        ))
        .expect("type into field");
    runner
        .dispatch(ui_event(
            4,
            UiEventKind::MouseDown(mouse_event(true, 164.0, 22.0)),
        ))
        .expect("press OK");
    runner
        .dispatch(ui_event(
            5,
            UiEventKind::MouseUp(mouse_event(false, 164.0, 22.0)),
        ))
        .expect("release OK");

    assert!(
        label_caption(&runner, "OutputLabel").contains("World"),
        "the VBA OkButton_Click handler set the label from the typed text; got {:?}",
        label_caption(&runner, "OutputLabel")
    );

    // Re-render after the runtime-driven state change still produces the valid 4-node
    // chrome scene. The chrome token is unchanged because caption *text* is not yet in
    // the resident scene (DrawText run id 0; the text-run crossing is deferred — see
    // the module note). Caption rendering across the live boundary lands with that
    // crossing (4pn.8+).
    runner.render_frame().expect("render_frame #3");
    let snap3 = surface.snapshot().expect("snapshot");
    assert_eq!(snap3.node_count, 4, "the form still renders four nodes");
    assert!(
        snap3.revision > snap2.revision,
        "the post-change render produced a new revision"
    );
}
