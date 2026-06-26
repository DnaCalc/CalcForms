//! W007 Re-render seam end to end on OxVba (oxforms-4pn.7).
//!
//! Proves the §16 Re-render the runtime owns: `RuntimeRunner::render_frame` invokes
//! the form's VBA `UserForm.Render`, which self-renders the whole form into one
//! batched `ScenePatch` and submits it across the injected `OxForms.Surface`,
//! advancing the resident control-blind `Scene` the backend repaints. This is the
//! runtime half of the frame model (`RENDERING_ARCHITECTURE.md` §16): the runtime is
//! the sole owner of all VBA entry — both `dispatch` and `render_frame` — and the
//! resident `Scene` (in `OxForms.Surface`) is the producer/consumer seam.
//!
//! Caption text now crosses via `MeasureText` (oxforms-4pn.13): each `DrawText` carries
//! a content-hash run id derived from the caption (`RENDERING_ARCHITECTURE.md` §8), so a
//! VBA-side text change re-measures to a new run id and moves the resident frame token.
//! The resident scene carries the form chrome (fills + 3D edges) *and* the shaped caption
//! runs (`Scene.text`). This test injects the deterministic `StubShaper`.

use std::path::{Path, PathBuf};
use std::sync::Arc;

use oxforms_core::materialize_w007_demo_form;
use oxforms_oxvba_adapter::runtime_runner::RuntimeRunner;
use oxforms_oxvba_adapter::surface::{register_surface, SurfaceFactory};
use oxforms_pal::scene::{NodeId, StubShaper};
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

/// Build a session with the OxForms VBA library + ONE demo form `(module_name, path)`, and
/// the `OxForms.Surface` boundary registered so the form's `Render` can self-render. One
/// form per bundle: two `WithEvents CommandButton_Click` handlers in one bundle collide in
/// OxVba's per-project event routing (see the handover note).
fn prepare_session_with_surface(
    demo_form: (&str, &str),
) -> (ProjectRuntimeSession, Arc<SurfaceFactory>) {
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
            module_unit("Controls", ModuleKind::Class, "vba/oxforms/Controls.cls"),
            module_unit(
                "ReturnInteger",
                ModuleKind::Class,
                "vba/oxforms/ReturnInteger.cls",
            ),
            module_unit(
                "ReturnBoolean",
                ModuleKind::Class,
                "vba/oxforms/ReturnBoolean.cls",
            ),
            module_unit("Label", ModuleKind::Class, "vba/oxforms/Label.cls"),
            module_unit("TextBox", ModuleKind::Class, "vba/oxforms/TextBox.cls"),
            module_unit(
                "CommandButton",
                ModuleKind::Class,
                "vba/oxforms/CommandButton.cls",
            ),
            module_unit("UserForm", ModuleKind::Class, "vba/oxforms/UserForm.cls"),
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
            module_unit(demo_form.0, ModuleKind::Class, demo_form.1),
        ],
        references: Vec::new(),
        reference_projects: Vec::new(),
        conditional_constants: Default::default(),
    };

    let program = oxvba_bind::bind_program(&manifest, &oxvba_symbol::CatalogTypeLibResolver)
        .expect("bind W007 render-frame project");
    let bundle = oxvba_bundle::linearize(&program).expect("linearize W007 render-frame project");

    let projection = Arc::new(PortableComProjection::new());
    // The VBA render now measures text via Surface.MeasureText, so a shaper must be
    // present; StubShaper is deterministic and font-free (the headless framebuffer is
    // text-free, so this does not affect the golden hash).
    let surface = Arc::new(SurfaceFactory::with_shaper(Arc::new(StubShaper)));
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
    let (session, surface) = prepare_session_with_surface((
        "W007ObjectModelProbeForm",
        "vba/smoke/fixtures/w007_object_model_probe_form.cls",
    ));
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

    // Re-render again with no state change: nothing was invalidated, so the incremental
    // path (oxforms-rq5.2) does NO crossing — the resident frame is untouched, keeping both
    // the token AND the revision (there is no new frame to repaint). This is the efficiency
    // win over the old full-rebuild-every-frame path, which bumped the revision uncondition-
    // ally even when the content was identical.
    runner.render_frame().expect("render_frame #2");
    let snap2 = surface.snapshot().expect("snapshot");
    assert_eq!(
        snap2.frame_token,
        Some(token1),
        "unchanged content keeps the identical resident token (determinism)"
    );
    assert_eq!(
        snap2.revision, snap1.revision,
        "an unchanged re-render produces no new resident revision (no wasted repaint)"
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

    // Re-render after the runtime-driven caption change. OkButton_Click set
    // OutputLabel.Caption to "Hello, World", which re-measures to a NEW content-hash run
    // id — so the resident frame token must MOVE (the live text seam, 4pn.13), and the
    // new caption must be a resident shaped run.
    runner.render_frame().expect("render_frame #3");
    let snap3 = surface.snapshot().expect("snapshot");
    assert_eq!(snap3.node_count, 4, "the form still renders four nodes");
    assert!(
        snap3.revision > snap2.revision,
        "the post-change render produced a new revision"
    );
    assert_ne!(
        snap3.frame_token,
        Some(token1),
        "a VBA-side caption change re-measures to a new run id and moves the frame token"
    );
    let scene3 = snap3.scene.expect("a resident scene");
    let sources: Vec<String> = scene3.text.values().map(|r| r.source.to_string()).collect();
    assert!(
        sources.iter().any(|s| s == "Hello, World"),
        "the new label caption crossed via MeasureText as a resident shaped run; got {sources:?}"
    );
}

/// The interactive AutoSize demo (the runnable `cargo run -p oxforms-bootstrap -- autosize`
/// window) end to end: clicking "Grow font" fires the native `GrowButton_Click`, which bumps
/// the label font, so the runtime re-renders incrementally and the bordered AutoSize box
/// re-fits LARGER. Proves the live demo's click → grow → re-fit chain (rq5.2) headlessly.
#[test]
fn autosize_demo_grow_click_refits_the_label_larger() {
    let (session, surface) = prepare_session_with_surface((
        "AutoSizeInteractiveForm",
        "vba/smoke/fixtures/autosize_interactive_form.cls",
    ));
    let runtime_form = oxforms_core::materialize_form_from_frm(&read_source(
        "fixtures/frm/w007-autosize/autosize-interactive.frm",
    ))
    .expect("materialize autosize demo form");
    let mut runner = RuntimeRunner::attach(
        session,
        runtime_form,
        "AutoSizeInteractiveForm",
        "Build",
        "Form",
    )
    .expect("attach autosize demo");

    // First frame: the AutoLabel (NodeId 2; GrowButton is NodeId 1, added first) hugs
    // "Size me" at the default 8pt.
    runner.render_frame().expect("initial render");
    let before = label_size(&surface);

    // Click "Grow font" (form-logical center of the button at Left 12, Top 12, 100x24).
    runner
        .dispatch(ui_event(
            1,
            UiEventKind::MouseDown(mouse_event(true, 62.0, 24.0)),
        ))
        .expect("press grow");
    runner
        .dispatch(ui_event(
            2,
            UiEventKind::MouseUp(mouse_event(false, 62.0, 24.0)),
        ))
        .expect("release grow");
    runner.render_frame().expect("render after grow");
    let after = label_size(&surface);

    assert!(
        after.0 > before.0 && after.1 > before.1,
        "the Grow click re-measured + re-fit the AutoSize box larger: {before:?} -> {after:?}"
    );
}

/// (w, h) of the AutoSize label node (NodeId 2) in the resident scene.
fn label_size(surface: &Arc<SurfaceFactory>) -> (f32, f32) {
    let scene = surface.snapshot().expect("snapshot").scene.expect("scene");
    let node = scene.get(NodeId(2)).expect("the AutoLabel node");
    (node.bounds.w, node.bounds.h)
}
