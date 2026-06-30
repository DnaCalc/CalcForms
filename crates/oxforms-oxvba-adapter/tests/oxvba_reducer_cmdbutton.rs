//! Reducer-pivot increment 1 (oxforms-ih6.1): the VBA interaction reducer (OxReducer) routes
//! pointer input and raises controls' ordered FM20 events, with NO Rust reducer (oxforms-core)
//! in the loop. This is the spine of the reducer pivot
//! (docs/specs/MESSAGE_HANDLING_AND_UPDATE_FLOW.md): geometric routing + interaction state
//! (capture, pressed) + ordered event raising + a real surface repaint, all in VBA.
//!
//! Session assembly mirrors oxvba_w007_object_model.rs; the OxForms.Surface registration
//! mirrors oxvba_w007_render_frame.rs (the reducer drives UserForm.Render, which crosses the
//! surface). Fixtures hold WithEvents sinks so the tests assert the REAL events fired in order,
//! not just the reducer's own effect log; the headless framebuffer hash proves the pressed
//! face actually rendered and reverted.

use std::path::{Path, PathBuf};
use std::sync::Arc;

use oxforms_oxvba_adapter::surface::{register_surface, SurfaceFactory};
use oxforms_pal::scene::StubShaper;

use oxvba_bundle::ProjectMemberKind;
use oxvba_com::PortableComProjection;
use oxvba_hal::model::HostPolicy;
use oxvba_host::{Engine, HostConfig, HostProfileProvider, ProjectRuntimeSession};
use oxvba_runtime::{ObjectRef, Variant};
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

/// The OxForms VBA library + the OxReducer + the increment-1 fixtures, with the
/// `OxForms.Surface` boundary registered so the reducer's `UserForm.Render` self-renders.
/// Returns the surface so a test can read back the resident-scene revision + framebuffer hash.
fn prepare_session() -> (ProjectRuntimeSession, Arc<SurfaceFactory>) {
    let modules = vec![
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
        module_unit("OxReducer", ModuleKind::Class, "vba/oxforms/OxReducer.cls"),
        module_unit(
            "ReducerCmdButtonForm",
            ModuleKind::Class,
            "vba/smoke/fixtures/reducer_cmdbutton_form.cls",
        ),
        module_unit(
            "ReducerHitRoutingForm",
            ModuleKind::Class,
            "vba/smoke/fixtures/reducer_hit_routing_form.cls",
        ),
    ];

    let manifest = SymbolProjectManifest {
        project_name: "ReducerCmdButton".to_string(),
        project_kind: ProjectKind::Library,
        modules,
        references: Vec::new(),
        reference_projects: Vec::new(),
        conditional_constants: Default::default(),
    };

    let program = oxvba_bind::bind_program(&manifest, &oxvba_symbol::CatalogTypeLibResolver)
        .expect("bind reducer cmd-button project");
    let bundle =
        oxvba_oxir::elaborate::elaborate(&program).expect("elaborate reducer cmd-button project");

    let projection = Arc::new(PortableComProjection::new());
    let surface = Arc::new(SurfaceFactory::with_shaper(Arc::new(StubShaper)));
    register_surface(&projection, surface.clone());

    let profile = HostProfileProvider::new()
        .with_portable_com_projection(projection)
        .with_host_policy(HostPolicy::interactive_dev());
    let engine = Engine::new(HostConfig { enable_jit: false }).with_host_profile_provider(profile);
    let session = engine
        .prepare_image_session(oxvba_oxir::OxImage::new(vec![bundle]))
        .expect("prepare reducer cmd-button session");
    (session, surface)
}

fn call(
    session: &mut ProjectRuntimeSession,
    object: ObjectRef,
    member: &str,
    kind: ProjectMemberKind,
    args: Vec<Variant>,
) -> Variant {
    session
        .invoke_member_values(object, member, Some(kind), args)
        .unwrap_or_else(|err| panic!("invoke {member}: {}", err.message()))
}

fn build_form(session: &mut ProjectRuntimeSession, class: &str) -> ObjectRef {
    let form = session
        .create_class_instance(class)
        .unwrap_or_else(|err| panic!("create {class}: {err}"));
    call(
        session,
        form.clone(),
        "Build",
        ProjectMemberKind::Method,
        Vec::new(),
    );
    form
}

/// Drive the VBA reducer with one normalized pointer event; return its ordered effect log.
fn dispatch_btn(
    session: &mut ProjectRuntimeSession,
    form: &ObjectRef,
    kind: &str,
    x: i32,
    y: i32,
    button: i16,
) -> String {
    call(
        session,
        form.clone(),
        "Dispatch",
        ProjectMemberKind::Method,
        vec![
            Variant::from_string(kind),
            Variant::from_i32(x),
            Variant::from_i32(y),
            Variant::from_i16(button),
            Variant::from_i16(0), // Shift
        ],
    )
    .as_bstr()
    .unwrap_or_else(|| panic!("Dispatch should return the effect log string"))
    .as_str()
}

/// Left-button dispatch (the common case).
fn dispatch(
    session: &mut ProjectRuntimeSession,
    form: &ObjectRef,
    kind: &str,
    x: i32,
    y: i32,
) -> String {
    dispatch_btn(session, form, kind, x, y, 1)
}

fn handler_log(session: &mut ProjectRuntimeSession, form: &ObjectRef) -> String {
    call(
        session,
        form.clone(),
        "HandlerLog",
        ProjectMemberKind::PropertyGet,
        Vec::new(),
    )
    .as_bstr()
    .unwrap_or_else(|| panic!("HandlerLog should return a string"))
    .as_str()
}

fn pressed(session: &mut ProjectRuntimeSession, form: &ObjectRef) -> bool {
    call(
        session,
        form.clone(),
        "Pressed",
        ProjectMemberKind::PropertyGet,
        Vec::new(),
    )
    .as_bool()
    .unwrap_or_else(|| panic!("Pressed should return a boolean"))
}

fn set_z_order(session: &mut ProjectRuntimeSession, form: &ObjectRef, name: &str, z: i32) {
    call(
        session,
        form.clone(),
        "SetZOrder",
        ProjectMemberKind::Method,
        vec![Variant::from_string(name), Variant::from_i32(z)],
    );
}

/// The resident-scene revision (bumps only on a content-changing submitted patch) and the
/// headless framebuffer hash of the last render — the real-render proof.
fn revision(surface: &Arc<SurfaceFactory>) -> u64 {
    surface.snapshot().expect("surface snapshot").revision
}

fn framebuffer_hash(surface: &Arc<SurfaceFactory>) -> u64 {
    surface
        .snapshot()
        .expect("surface snapshot")
        .last_report
        .expect("a render report")
        .framebuffer_hash
}

// The cmd-button fixture button is at Left=20, Top=20, Width=80, Height=30 -> x in [20,100),
// y in [20,50).
const INSIDE: (i32, i32) = (40, 30);
const OUTSIDE: (i32, i32) = (5, 5);
const FAR_OUTSIDE: (i32, i32) = (140, 70);

#[test]
fn command_button_mouse_click_runs_the_vba_reducer() {
    let (mut session, surface) = prepare_session();
    let form = build_form(&mut session, "ReducerCmdButtonForm");

    let rev0 = revision(&surface);
    let hash_idle = framebuffer_hash(&surface);

    // Press inside the button: MouseDown raised, pressed armed, repaint.
    let down = dispatch(&mut session, &form, "mousedown", INSIDE.0, INSIDE.1);
    assert_eq!(down, "mousedown:Btn1|press:Btn1|repaint");
    assert!(
        pressed(&mut session, &form),
        "press arms the pressed visual"
    );
    // The press actually rendered: the resident scene advanced and the pressed face changed
    // the pixels (not merely the self-emitted "repaint" token).
    assert!(
        revision(&surface) > rev0,
        "the press submitted a new resident frame"
    );
    let hash_pressed = framebuffer_hash(&surface);
    assert_ne!(
        hash_pressed, hash_idle,
        "the pressed face renders different pixels"
    );

    // Release inside: MouseUp then Click then release, repaint.
    let up = dispatch(&mut session, &form, "mouseup", INSIDE.0, INSIDE.1);
    assert_eq!(up, "mouseup:Btn1|click:Btn1|release:Btn1|repaint");
    assert!(
        !pressed(&mut session, &form),
        "the press releases on mouse up"
    );
    // The release reverted the face to the idle pixels.
    assert_eq!(
        framebuffer_hash(&surface),
        hash_idle,
        "releasing the press reverts the rendered face"
    );

    // The REAL FM20 events fired, in MSForms order (MouseDown, MouseUp, Click).
    assert_eq!(
        handler_log(&mut session, &form).lines().collect::<Vec<_>>(),
        vec!["MouseDown", "MouseUp", "Click"],
        "native control events reach the VBA handlers in FM20 order"
    );
}

#[test]
fn release_outside_the_button_suppresses_click() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerCmdButtonForm");

    dispatch(&mut session, &form, "mousedown", INSIDE.0, INSIDE.1);
    // Capture routes the up to the originating button even though it landed outside; MouseUp
    // still fires on it, but no Click (the release was not inside the captured control).
    let up = dispatch(&mut session, &form, "mouseup", FAR_OUTSIDE.0, FAR_OUTSIDE.1);
    assert_eq!(up, "mouseup:Btn1|release:Btn1|repaint");
    assert!(!pressed(&mut session, &form), "the press still releases");

    assert_eq!(
        handler_log(&mut session, &form).lines().collect::<Vec<_>>(),
        vec!["MouseDown", "MouseUp"],
        "no Click when the release lands outside the captured control"
    );
}

#[test]
fn mouse_down_outside_any_control_routes_nowhere() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerCmdButtonForm");

    let down = dispatch(&mut session, &form, "mousedown", OUTSIDE.0, OUTSIDE.1);
    assert_eq!(down, "", "a miss produces no effects");
    assert!(!pressed(&mut session, &form), "nothing armed on a miss");
    assert_eq!(
        handler_log(&mut session, &form),
        "",
        "no control events on a miss"
    );
}

#[test]
fn non_left_button_is_ignored() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerCmdButtonForm");

    // Right button (2) inside the control: the reducer bails before any routing.
    let down = dispatch_btn(&mut session, &form, "mousedown", INSIDE.0, INSIDE.1, 2);
    assert_eq!(down, "", "a right press produces no effects");
    assert!(!pressed(&mut session, &form), "a right press arms nothing");
    let up = dispatch_btn(&mut session, &form, "mouseup", INSIDE.0, INSIDE.1, 2);
    assert_eq!(up, "", "a right release produces no effects");
    assert_eq!(
        handler_log(&mut session, &form),
        "",
        "no control events for a non-left button"
    );
}

#[test]
fn overlapping_controls_route_by_z_order_then_last_added() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerHitRoutingForm");

    // Non-overlap regions route to the unique control under the point.
    assert_eq!(
        dispatch(&mut session, &form, "mousedown", 25, 30),
        "mousedown:A|press:A|repaint",
        "the A-only region routes to A"
    );
    dispatch(&mut session, &form, "mouseup", 25, 30);
    assert_eq!(
        dispatch(&mut session, &form, "mousedown", 110, 30),
        "mousedown:B|press:B|repaint",
        "the B-only region routes to B"
    );
    dispatch(&mut session, &form, "mouseup", 110, 30);

    // Overlap with equal z: the later-added control (B) wins, matching the kernel's
    // (z_order, index) tie-break.
    assert_eq!(
        dispatch(&mut session, &form, "mousedown", 60, 30),
        "mousedown:B|press:B|repaint",
        "an equal-z overlap routes to the last-added control"
    );
    dispatch(&mut session, &form, "mouseup", 60, 30);

    // Raise A above B: the overlap now routes to A (higher z wins regardless of add order).
    set_z_order(&mut session, &form, "A", 5);
    assert_eq!(
        dispatch(&mut session, &form, "mousedown", 60, 30),
        "mousedown:A|press:A|repaint",
        "a higher z wins the overlap"
    );
}

#[test]
fn capture_routes_mouseup_to_the_pressed_control_across_a_sibling() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerHitRoutingForm");

    // Press in the A-only region (captures A), then release in the overlap (over B too).
    dispatch(&mut session, &form, "mousedown", 25, 30);
    let up = dispatch(&mut session, &form, "mouseup", 60, 30);
    // Capture keeps the up on A; the release is still inside A's bounds, so A fires Click --
    // B never sees the event despite being under the release point.
    assert_eq!(up, "mouseup:A|click:A|release:A|repaint");
    assert_eq!(
        handler_log(&mut session, &form).lines().collect::<Vec<_>>(),
        vec!["A.Click"],
        "the captured control A fired Click; the sibling B did not"
    );
}
