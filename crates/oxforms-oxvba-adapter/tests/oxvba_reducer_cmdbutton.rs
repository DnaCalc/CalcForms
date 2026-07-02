//! Reducer-pivot increment 1 (oxforms-ih6.1): the VBA InteractionManager, reached through
//! the stable OxReducer facade, routes pointer input and raises controls' ordered FM20 events,
//! with NO Rust reducer (oxforms-core) in the loop. This is the spine of the reducer pivot
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
use oxforms_pal::scene::{EdgeEffect, FontId, NodeId, Paint, Prim, RectF, StubShaper, TextRunId};
use oxforms_pal::Color;
use oxforms_pal_win::{load_ui_font, AbGlyphShaper};

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
    prepare_session_with_surface(Arc::new(SurfaceFactory::with_shaper(Arc::new(StubShaper))))
}

fn prepare_session_with_surface(
    surface: Arc<SurfaceFactory>,
) -> (ProjectRuntimeSession, Arc<SurfaceFactory>) {
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
        module_unit(
            "OxTextService",
            ModuleKind::Class,
            "vba/oxforms/OxTextService.cls",
        ),
        module_unit("TextBox", ModuleKind::Class, "vba/oxforms/TextBox.cls"),
        module_unit(
            "CommandButton",
            ModuleKind::Class,
            "vba/oxforms/CommandButton.cls",
        ),
        module_unit("CheckBox", ModuleKind::Class, "vba/oxforms/CheckBox.cls"),
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
        module_unit(
            "OxInteractionManager",
            ModuleKind::Class,
            "vba/oxforms/OxInteractionManager.cls",
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
        module_unit(
            "ReducerCheckBoxForm",
            ModuleKind::Class,
            "vba/smoke/fixtures/reducer_checkbox_form.cls",
        ),
        module_unit(
            "ReducerTextBoxForm",
            ModuleKind::Class,
            "vba/smoke/fixtures/reducer_textbox_form.cls",
        ),
        module_unit(
            "ReducerButtonsForm",
            ModuleKind::Class,
            "vba/smoke/fixtures/reducer_buttons_form.cls",
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
    dispatch_mouse(session, form, kind, x, y, button, 0)
}

fn dispatch_mouse(
    session: &mut ProjectRuntimeSession,
    form: &ObjectRef,
    kind: &str,
    x: i32,
    y: i32,
    button: i16,
    shift: i16,
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
            Variant::from_i16(shift),
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

fn value(session: &mut ProjectRuntimeSession, form: &ObjectRef) -> bool {
    call(
        session,
        form.clone(),
        "Value",
        ProjectMemberKind::PropertyGet,
        Vec::new(),
    )
    .as_bool()
    .unwrap_or_else(|| panic!("Value should return a boolean"))
}

fn bool_get(session: &mut ProjectRuntimeSession, form: &ObjectRef, member: &str) -> bool {
    call(
        session,
        form.clone(),
        member,
        ProjectMemberKind::PropertyGet,
        Vec::new(),
    )
    .as_bool()
    .unwrap_or_else(|| panic!("{member} should return a boolean"))
}

fn i32_get(session: &mut ProjectRuntimeSession, form: &ObjectRef, member: &str) -> i32 {
    call(
        session,
        form.clone(),
        member,
        ProjectMemberKind::PropertyGet,
        Vec::new(),
    )
    .as_i32()
    .unwrap_or_else(|| panic!("{member} should return a Long-compatible integer"))
}

fn dispatch_key_shift(
    session: &mut ProjectRuntimeSession,
    form: &ObjectRef,
    kind: &str,
    key_code: i16,
    shift: i16,
) -> String {
    call(
        session,
        form.clone(),
        "DispatchKey",
        ProjectMemberKind::Method,
        vec![
            Variant::from_string(kind),
            Variant::from_i16(key_code),
            Variant::from_i16(shift),
        ],
    )
    .as_bstr()
    .unwrap_or_else(|| panic!("DispatchKey should return the effect log"))
    .as_str()
}

fn dispatch_key(
    session: &mut ProjectRuntimeSession,
    form: &ObjectRef,
    kind: &str,
    key_code: i16,
) -> String {
    dispatch_key_shift(session, form, kind, key_code, 0)
}

fn dispatch_char(session: &mut ProjectRuntimeSession, form: &ObjectRef, text: &str) -> String {
    call(
        session,
        form.clone(),
        "DispatchChar",
        ProjectMemberKind::Method,
        vec![Variant::from_string(text)],
    )
    .as_bstr()
    .unwrap_or_else(|| panic!("DispatchChar should return the effect log"))
    .as_str()
}

fn string_get(session: &mut ProjectRuntimeSession, form: &ObjectRef, member: &str) -> String {
    call(
        session,
        form.clone(),
        member,
        ProjectMemberKind::PropertyGet,
        Vec::new(),
    )
    .as_bstr()
    .unwrap_or_else(|| panic!("{member} should return a string"))
    .as_str()
}

fn invoke_sub(session: &mut ProjectRuntimeSession, form: &ObjectRef, member: &str) {
    call(
        session,
        form.clone(),
        member,
        ProjectMemberKind::Method,
        Vec::new(),
    );
}

fn set_clipboard_text(session: &mut ProjectRuntimeSession, form: &ObjectRef, text: &str) {
    call(
        session,
        form.clone(),
        "SetClipboardText",
        ProjectMemberKind::Method,
        vec![Variant::from_string(text)],
    );
}

fn set_t1_text(session: &mut ProjectRuntimeSession, form: &ObjectRef, text: &str) {
    call(
        session,
        form.clone(),
        "SetT1Text",
        ProjectMemberKind::Method,
        vec![Variant::from_string(text)],
    );
}

fn set_t1_selection(
    session: &mut ProjectRuntimeSession,
    form: &ObjectRef,
    start: i32,
    length: i32,
) {
    call(
        session,
        form.clone(),
        "SetT1Selection",
        ProjectMemberKind::Method,
        vec![Variant::from_i32(start), Variant::from_i32(length)],
    );
}

fn dispatch_drop(session: &mut ProjectRuntimeSession, form: &ObjectRef, text: &str) -> String {
    call(
        session,
        form.clone(),
        "DispatchDrop",
        ProjectMemberKind::Method,
        vec![Variant::from_string(text)],
    )
    .as_bstr()
    .unwrap_or_else(|| panic!("DispatchDrop should return the effect log"))
    .as_str()
}

/// Focus a TextBox in the textbox fixture via a mouse press + release on it, then clear the log
/// so a test asserts only the events that follow.
fn focus_and_clear(session: &mut ProjectRuntimeSession, form: &ObjectRef, x: i32, y: i32) {
    dispatch(session, form, "mousedown", x, y);
    dispatch(session, form, "mouseup", x, y);
    invoke_sub(session, form, "ClearLog");
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

fn fill_rect_count(surface: &Arc<SurfaceFactory>, node: NodeId) -> usize {
    let snapshot = surface.snapshot().expect("surface snapshot");
    let scene = snapshot.scene.expect("scene snapshot");
    scene
        .get(node)
        .unwrap_or_else(|| panic!("node {node:?} should exist"))
        .prims
        .iter()
        .filter(|prim| matches!(prim, Prim::FillRect { .. }))
        .count()
}

const TEXT_SELECTION_COLOR: Color = Color::rgba(0x0a, 0x24, 0x6a, 0xff);
const TEXT_SELECTION_FORE_COLOR: Color = Color::rgba(0xff, 0xff, 0xff, 0xff);
const TEXT_CARET_COLOR: Color = Color::rgba(0x00, 0x00, 0x00, 0xff);
const THEME_COMMAND_FACE: Color = Color::rgba(0xdc, 0xdc, 0xdc, 0xff);
const THEME_COMMAND_PRESSED: Color = Color::rgba(0xb8, 0xc7, 0xdd, 0xff);
const THEME_TEXT: Color = Color::rgba(0x00, 0x00, 0x00, 0xff);
const THEME_DISABLED_TEXT: Color = Color::rgba(0x80, 0x80, 0x80, 0xff);

fn solid_color(paint: &Paint) -> Option<Color> {
    match paint {
        Paint::Solid(color) => Some(*color),
        Paint::LinearGradient { .. } => None,
    }
}

fn fill_rect_with_color(prims: &[Prim], color: Color) -> Option<RectF> {
    prims.iter().find_map(|prim| match prim {
        Prim::FillRect { rect, paint } if solid_color(paint) == Some(color) => Some(*rect),
        _ => None,
    })
}

fn draw_text_with_color(prims: &[Prim], color: Color) -> Option<(TextRunId, RectF)> {
    prims.iter().find_map(|prim| match prim {
        Prim::DrawText {
            run, rect, paint, ..
        } if solid_color(paint) == Some(color) => Some((*run, *rect)),
        _ => None,
    })
}

fn draw_text_style(prims: &[Prim]) -> Option<(Color, bool)> {
    prims.iter().find_map(|prim| match prim {
        Prim::DrawText { paint, flags, .. } => {
            solid_color(paint).map(|color| (color, flags.disabled))
        }
        _ => None,
    })
}

fn draw_text_prim(prims: &[Prim]) -> Option<(TextRunId, RectF)> {
    prims.iter().find_map(|prim| match prim {
        Prim::DrawText { run, rect, .. } => Some((*run, *rect)),
        _ => None,
    })
}

fn draw_edge_effect(prims: &[Prim]) -> Option<EdgeEffect> {
    prims.iter().find_map(|prim| match prim {
        Prim::DrawEdge { effect, .. } => Some(*effect),
        _ => None,
    })
}

fn assert_rect_close(actual: RectF, expected: RectF, label: &str) {
    let close = |a: f32, b: f32| (a - b).abs() < 0.01;
    assert!(
        close(actual.x, expected.x)
            && close(actual.y, expected.y)
            && close(actual.w, expected.w)
            && close(actual.h, expected.h),
        "{label}: actual {actual:?}, expected {expected:?}"
    );
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
    {
        let snapshot = surface.snapshot().expect("surface snapshot");
        let scene = snapshot.scene.expect("scene snapshot");
        let button = scene.get(NodeId(1)).expect("button scene node");
        assert!(
            fill_rect_with_color(&button.prims, THEME_COMMAND_FACE).is_some(),
            "ThemePainter should resolve the idle CommandButton face"
        );
        assert_eq!(
            draw_edge_effect(&button.prims),
            Some(EdgeEffect::Raised),
            "ThemePainter should map the CommandButton raised edge"
        );
    }

    // Press inside the button: focus arrives (Enter) before MouseDown, then pressed armed, repaint.
    let down = dispatch(&mut session, &form, "mousedown", INSIDE.0, INSIDE.1);
    assert_eq!(down, "enter:Btn1|mousedown:Btn1|press:Btn1|repaint");
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
    {
        let snapshot = surface.snapshot().expect("surface snapshot");
        let scene = snapshot.scene.expect("scene snapshot");
        let button = scene.get(NodeId(1)).expect("button scene node");
        assert!(
            fill_rect_with_color(&button.prims, THEME_COMMAND_PRESSED).is_some(),
            "ThemePainter should resolve the pressed CommandButton face"
        );
        assert_eq!(
            draw_edge_effect(&button.prims),
            Some(EdgeEffect::Raised),
            "pressing changes the face token, not the edge contract"
        );
    }

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

    // Non-overlap regions route to the unique control under the point. Each focusable control
    // gains focus (Enter) before its MouseDown; moving focus to a sibling fires Exit on the loser.
    assert_eq!(
        dispatch(&mut session, &form, "mousedown", 25, 30),
        "enter:A|mousedown:A|press:A|repaint",
        "the A-only region routes to A and focuses it"
    );
    dispatch(&mut session, &form, "mouseup", 25, 30);
    assert_eq!(
        dispatch(&mut session, &form, "mousedown", 110, 30),
        "exit:A|enter:B|mousedown:B|press:B|repaint",
        "the B-only region routes to B; focus transfers A -> B"
    );
    dispatch(&mut session, &form, "mouseup", 110, 30);

    // Overlap with equal z: the later-added control (B) wins, matching the kernel's
    // (z_order, index) tie-break. Focus is already on B, so no Enter/Exit.
    assert_eq!(
        dispatch(&mut session, &form, "mousedown", 60, 30),
        "mousedown:B|press:B|repaint",
        "an equal-z overlap routes to the last-added control"
    );
    dispatch(&mut session, &form, "mouseup", 60, 30);

    // Raise A above B: the overlap now routes to A (higher z wins regardless of add order);
    // focus transfers B -> A.
    set_z_order(&mut session, &form, "A", 5);
    assert_eq!(
        dispatch(&mut session, &form, "mousedown", 60, 30),
        "exit:B|enter:A|mousedown:A|press:A|repaint",
        "a higher z wins the overlap"
    );
}

#[test]
fn capture_routes_mouseup_to_the_pressed_control_across_a_sibling() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerHitRoutingForm");

    // Press in the A-only region (captures A), then release in the overlap (over B too).
    dispatch(&mut session, &form, "mousedown", 25, 30);
    let state = string_get(&mut session, &form, "InteractionStateSummary");
    assert!(
        state.contains("focus=A;capture=A;pressed=A;hover=A;cursor_target=A;cursor=0"),
        "InteractionManager should own focus/capture/pressed/hover state after press: {state}"
    );
    assert_eq!(
        dispatch_btn(&mut session, &form, "mousemove", 110, 30, 0),
        "mousemove:A",
        "capture should keep drag motion routed to A even over B/outside A"
    );
    let state = string_get(&mut session, &form, "InteractionStateSummary");
    assert!(
        state.contains("focus=A;capture=A;pressed=A;hover=A;cursor_target=A;cursor=0"),
        "captured motion should keep the pointer target on A: {state}"
    );
    let up = dispatch(&mut session, &form, "mouseup", 60, 30);
    // Capture keeps the up on A; the release is still inside A's bounds, so A fires Click --
    // B never sees the event despite being under the release point.
    assert_eq!(up, "mouseup:A|click:A|release:A|repaint");
    let state = string_get(&mut session, &form, "InteractionStateSummary");
    assert!(
        state.contains("focus=A;capture=;pressed=;hover=A;cursor_target=A;cursor=0"),
        "release should clear capture/pressed while preserving the last pointer target: {state}"
    );
    assert_eq!(
        handler_log(&mut session, &form).lines().collect::<Vec<_>>(),
        vec!["A.Click"],
        "the captured control A fired Click; the sibling B did not"
    );
}

// The check box fixture control is at Left=20, Top=20, Width=120, Height=20 -> x in [20,140),
// y in [20,40).
const CHK_INSIDE: (i32, i32) = (30, 30);

#[test]
fn checkbox_mouse_click_toggles_value_with_change_before_click() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerCheckBoxForm");

    assert!(!value(&mut session, &form), "check box starts unchecked");

    // Press arms the pressed visual (CheckBox has one) but does NOT toggle the value yet; focus
    // arrives first (Enter).
    let down = dispatch(&mut session, &form, "mousedown", CHK_INSIDE.0, CHK_INSIDE.1);
    assert_eq!(down, "enter:Chk1|mousedown:Chk1|press:Chk1|repaint");
    assert!(
        !value(&mut session, &form),
        "the value flips on click (mouse up), not on mouse down"
    );

    // Release inside toggles: value flips, then Change, then Click (value-before-Click).
    let up = dispatch(&mut session, &form, "mouseup", CHK_INSIDE.0, CHK_INSIDE.1);
    assert_eq!(up, "mouseup:Chk1|click:Chk1|release:Chk1|repaint");
    assert!(value(&mut session, &form), "the click toggled the value on");

    assert_eq!(
        handler_log(&mut session, &form).lines().collect::<Vec<_>>(),
        vec!["MouseDown", "MouseUp", "Change=True", "Click=True"],
        "MSForms order MouseUp -> Change -> Click, value already flipped at both"
    );
}

#[test]
fn checkbox_second_click_toggles_back_off() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerCheckBoxForm");

    dispatch(&mut session, &form, "mousedown", CHK_INSIDE.0, CHK_INSIDE.1);
    dispatch(&mut session, &form, "mouseup", CHK_INSIDE.0, CHK_INSIDE.1);
    assert!(value(&mut session, &form), "first click checks");

    dispatch(&mut session, &form, "mousedown", CHK_INSIDE.0, CHK_INSIDE.1);
    dispatch(&mut session, &form, "mouseup", CHK_INSIDE.0, CHK_INSIDE.1);
    assert!(
        !value(&mut session, &form),
        "a second click toggles back to unchecked"
    );
}

// The textbox fixture controls: T1 at (20,20,100,18) -> x in [20,120), y in [20,38);
// T2 at (20,50,100,18) -> x in [20,120), y in [50,68).
const T1_IN: (i32, i32) = (40, 28);
const T2_IN: (i32, i32) = (40, 58);
const KEY_A: i16 = 65;
const KEY_C: i16 = 67;
const KEY_X: i16 = 88;
const KEY_BACKSPACE: i16 = 8;
const KEY_HOME: i16 = 36;
const KEY_END: i16 = 35;
const KEY_LEFT: i16 = 37;
const KEY_DELETE: i16 = 46;
const SHIFT_SHIFT: i16 = 1;

#[test]
fn typing_into_focused_textbox_fires_keydown_keypress_change_keyup() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);

    // Type 'A': KeyDown, then the character (KeyPress -> insert -> Change), then KeyUp.
    dispatch_key(&mut session, &form, "keydown", KEY_A);
    dispatch_char(&mut session, &form, "A");
    dispatch_key(&mut session, &form, "keyup", KEY_A);

    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["T1.KeyDown", "T1.KeyPress", "T1.Change", "T1.KeyUp"],
        "the focused TextBox fires KeyDown -> KeyPress -> Change -> KeyUp"
    );
    assert_eq!(
        string_get(&mut session, &form, "T1Text"),
        "A",
        "the character was inserted"
    );
    assert_eq!(string_get(&mut session, &form, "FocusName"), "T1");
}

#[test]
fn textbox_character_input_replaces_selection_and_moves_caret() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);
    set_t1_text(&mut session, &form, "abc");
    set_t1_selection(&mut session, &form, 1, 1);

    let log = dispatch_char(&mut session, &form, "X");
    assert_eq!(log, "char:T1|repaint");
    assert_eq!(string_get(&mut session, &form, "T1Text"), "aXc");
    assert_eq!(i32_get(&mut session, &form, "T1SelStart"), 2);
    assert_eq!(i32_get(&mut session, &form, "T1SelLength"), 0);
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["T1.KeyPress", "T1.Change"],
        "user character input fires KeyPress before the replacement Change"
    );
}

#[test]
fn textbox_backspace_delete_and_navigation_edit_at_the_caret() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);
    set_t1_text(&mut session, &form, "abc");

    let backspace = dispatch_key(&mut session, &form, "keydown", KEY_BACKSPACE);
    assert_eq!(backspace, "keydown:T1|repaint");
    assert_eq!(string_get(&mut session, &form, "T1Text"), "ab");
    assert_eq!(i32_get(&mut session, &form, "T1SelStart"), 2);
    assert_eq!(i32_get(&mut session, &form, "T1SelLength"), 0);

    invoke_sub(&mut session, &form, "ClearLog");
    let home = dispatch_key(&mut session, &form, "keydown", KEY_HOME);
    assert_eq!(home, "keydown:T1|repaint");
    assert_eq!(i32_get(&mut session, &form, "T1SelStart"), 0);

    let delete = dispatch_key(&mut session, &form, "keydown", KEY_DELETE);
    assert_eq!(delete, "keydown:T1|repaint");
    assert_eq!(string_get(&mut session, &form, "T1Text"), "b");
    assert_eq!(i32_get(&mut session, &form, "T1SelStart"), 0);

    let end = dispatch_key(&mut session, &form, "keydown", KEY_END);
    assert_eq!(end, "keydown:T1|repaint");
    assert_eq!(i32_get(&mut session, &form, "T1SelStart"), 1);

    let left = dispatch_key(&mut session, &form, "keydown", KEY_LEFT);
    assert_eq!(left, "keydown:T1|repaint");
    assert_eq!(i32_get(&mut session, &form, "T1SelStart"), 0);
}

#[test]
fn textbox_shift_arrow_selection_and_backspace_repeat_are_headless_stateful() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);
    set_t1_text(&mut session, &form, "abcdef");

    for expected_start in [5, 4, 3] {
        let log = dispatch_key_shift(&mut session, &form, "keydown", KEY_LEFT, SHIFT_SHIFT);
        assert_eq!(log, "keydown:T1|repaint");
        assert_eq!(i32_get(&mut session, &form, "T1SelStart"), expected_start);
    }
    assert_eq!(i32_get(&mut session, &form, "T1SelLength"), 3);
    assert_eq!(string_get(&mut session, &form, "T1SelText"), "def");

    let backspace = dispatch_key(&mut session, &form, "keydown", KEY_BACKSPACE);
    assert_eq!(backspace, "keydown:T1|repaint");
    assert_eq!(string_get(&mut session, &form, "T1Text"), "abc");
    assert_eq!(i32_get(&mut session, &form, "T1SelStart"), 3);
    assert_eq!(i32_get(&mut session, &form, "T1SelLength"), 0);

    let repeat = dispatch_key(&mut session, &form, "keydown", KEY_BACKSPACE);
    assert_eq!(repeat, "keydown:T1|repaint");
    assert_eq!(
        string_get(&mut session, &form, "T1Text"),
        "ab",
        "a held Backspace repeat must mutate immediately, not wait for another key"
    );
}

#[test]
fn textbox_ctrl_a_paste_copy_and_cut_use_selection_and_clipboard_stub() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);
    set_t1_text(&mut session, &form, "abcd");

    let select_all = dispatch_key_shift(&mut session, &form, "keydown", KEY_A, SHIFT_CTRL);
    assert_eq!(select_all, "keydown:T1|repaint");
    assert_eq!(i32_get(&mut session, &form, "T1SelStart"), 0);
    assert_eq!(i32_get(&mut session, &form, "T1SelLength"), 4);
    assert_eq!(string_get(&mut session, &form, "T1SelText"), "abcd");

    let copy = dispatch_key_shift(&mut session, &form, "keydown", KEY_C, SHIFT_CTRL);
    assert_eq!(copy, "keydown:T1|copy:T1");
    assert_eq!(string_get(&mut session, &form, "ClipboardText"), "abcd");
    assert_eq!(string_get(&mut session, &form, "T1Text"), "abcd");

    let cut = dispatch_key_shift(&mut session, &form, "keydown", KEY_X, SHIFT_CTRL);
    assert_eq!(cut, "keydown:T1|cut:T1|repaint");
    assert_eq!(string_get(&mut session, &form, "ClipboardText"), "abcd");
    assert_eq!(string_get(&mut session, &form, "T1Text"), "");
    assert_eq!(i32_get(&mut session, &form, "T1SelStart"), 0);
    assert_eq!(i32_get(&mut session, &form, "T1SelLength"), 0);

    set_clipboard_text(&mut session, &form, "X");
    let paste = dispatch_key_shift(&mut session, &form, "keydown", KEY_V, SHIFT_CTRL);
    assert_eq!(paste, "keydown:T1|paste:T1|repaint");
    assert_eq!(string_get(&mut session, &form, "T1Text"), "X");
    assert_eq!(i32_get(&mut session, &form, "T1SelStart"), 1);
}

#[test]
fn textbox_scene_emits_caret_and_selection_fill_primitives() {
    let (mut session, surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    assert_eq!(
        fill_rect_count(&surface, NodeId(1)),
        1,
        "unfocused empty TextBox starts with only the field face fill"
    );

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);
    assert!(
        fill_rect_count(&surface, NodeId(1)) >= 2,
        "focused TextBox emits a caret FillRect in addition to the field face"
    );
    {
        let snapshot = surface.snapshot().expect("surface snapshot");
        let scene = snapshot.scene.expect("scene snapshot");
        let text_box = scene.get(NodeId(1)).expect("T1 scene node");
        assert!(
            fill_rect_with_color(&text_box.prims, TEXT_CARET_COLOR).is_some(),
            "ThemePainter should resolve the TextBox caret color"
        );
    }

    set_t1_text(&mut session, &form, "abcd");
    set_t1_selection(&mut session, &form, 1, 2);
    dispatch_key_shift(&mut session, &form, "keydown", KEY_C, SHIFT_CTRL);
    assert!(
        fill_rect_count(&surface, NodeId(1)) >= 2,
        "selected TextBox emits a selection FillRect in addition to the field face"
    );
}

#[test]
fn textbox_selection_geometry_uses_shaped_caret_stops_and_recolors_text() {
    let Ok(font) = load_ui_font() else {
        eprintln!("skipping proportional TextBox geometry test: no UI font available");
        return;
    };
    let surface = Arc::new(SurfaceFactory::with_shaper(Arc::new(AbGlyphShaper::new(
        FontId(1),
        font,
    ))));
    let (mut session, surface) = prepare_session_with_surface(surface);
    let form = build_form(&mut session, "ReducerTextBoxForm");

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);
    set_t1_text(&mut session, &form, "iiiiWW");
    set_t1_selection(&mut session, &form, 1, 4);
    invoke_sub(&mut session, &form, "Render");

    let snapshot = surface.snapshot().expect("surface snapshot");
    let scene = snapshot.scene.expect("scene snapshot");
    let parent = scene.get(NodeId(1)).expect("T1 scene node");
    let text_id = NodeId(1900);
    let overlay_id = NodeId(1901);
    assert!(
        parent.children.contains(&text_id) && parent.children.contains(&overlay_id),
        "TextBox parent should paint the normal text and selected-text recolor overlay as children"
    );

    let selection_rect = fill_rect_with_color(&parent.prims, TEXT_SELECTION_COLOR)
        .expect("selection background fill");
    let text_node = scene.get(text_id).expect("normal TextBox text node");
    assert!(text_node.visible, "normal text node should be visible");
    let (run_id, text_rect) = draw_text_prim(&text_node.prims).expect("normal DrawText prim");
    let run = scene.text_run(run_id).expect("projected shaped text run");
    assert_eq!(&*run.source, "iiiiWW");

    let widths: Vec<f32> = run.caret.stops.windows(2).map(|w| w[1] - w[0]).collect();
    if (widths[0] - widths[4]).abs() <= 0.1 {
        eprintln!("skipping proportional TextBox geometry assertion: UI font appears monospaced");
        return;
    }

    let expected = RectF::new(
        text_rect.x + run.caret.stops[1],
        text_rect.y,
        run.caret.stops[5] - run.caret.stops[1],
        text_rect.h,
    );
    assert_rect_close(
        selection_rect,
        expected,
        "selection fill from shaped caret stops",
    );

    let overlay = scene.get(overlay_id).expect("selection overlay node");
    assert!(
        overlay.visible,
        "selection overlay should be visible while selecting"
    );
    assert_rect_close(
        overlay.clip.expect("selection overlay clip"),
        expected,
        "selection overlay clip",
    );
    let (overlay_run, overlay_rect) =
        draw_text_with_color(&overlay.prims, TEXT_SELECTION_FORE_COLOR)
            .expect("selected text recolor DrawText");
    assert_eq!(overlay_run, run_id, "overlay redraws the same shaped run");
    assert_rect_close(
        overlay_rect,
        text_rect,
        "overlay text rect must match the normal text rect exactly",
    );
}

#[test]
fn textbox_textservice_scrolls_and_clips_long_text_to_caret() {
    let (mut session, surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);
    set_t1_text(&mut session, &form, "abcdefghijklmnopqrstuvwxyz");
    invoke_sub(&mut session, &form, "Render");

    let snapshot = surface.snapshot().expect("surface snapshot");
    let scene = snapshot.scene.expect("scene snapshot");
    let text_node = scene.get(NodeId(1900)).expect("normal TextBox text node");
    let clip = text_node.clip.expect("TextBox text viewport clip");
    assert_rect_close(
        clip,
        RectF::new(24.0, 23.0, 92.0, 12.0),
        "TextBox viewport clip",
    );
    let (_run_id, text_rect) = draw_text_prim(&text_node.prims).expect("long text DrawText");
    assert!(
        text_rect.x < clip.x,
        "long text should scroll left under the clipped viewport: text={text_rect:?}, clip={clip:?}"
    );
    assert!(
        text_rect.w >= clip.w,
        "text draw width should cover the viewport after scrolling"
    );

    let log = dispatch_key(&mut session, &form, "keydown", KEY_HOME);
    assert_eq!(log, "keydown:T1|repaint");
    let snapshot = surface.snapshot().expect("surface snapshot after Home");
    let scene = snapshot.scene.expect("scene snapshot after Home");
    let text_node = scene.get(NodeId(1900)).expect("normal TextBox text node");
    let clip = text_node
        .clip
        .expect("TextBox text viewport clip after Home");
    let (_run_id, text_rect) = draw_text_prim(&text_node.prims).expect("long text DrawText");
    assert_rect_close(
        RectF::new(text_rect.x, text_rect.y, clip.w, text_rect.h),
        RectF::new(clip.x, clip.y, clip.w, clip.h),
        "Home returns the scrolled text origin to the viewport",
    );
}

#[test]
fn textbox_mouse_down_places_caret_from_control_local_x() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);
    set_t1_text(&mut session, &form, "abcd");
    dispatch_key(&mut session, &form, "keydown", KEY_END);
    invoke_sub(&mut session, &form, "ClearLog");

    let log = dispatch(&mut session, &form, "mousedown", 32, T1_IN.1);
    assert_eq!(log, "mousedown:T1|repaint");
    assert_eq!(
        i32_get(&mut session, &form, "T1SelStart"),
        2,
        "caret hit testing must use reducer-provided control-local X, not subtract Left twice"
    );
    assert_eq!(i32_get(&mut session, &form, "T1SelLength"), 0);
}

#[test]
fn textbox_mouse_drag_extends_selection_through_mousemove_capture() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    set_t1_text(&mut session, &form, "abcdef");
    invoke_sub(&mut session, &form, "Render");

    let down = dispatch(&mut session, &form, "mousedown", 28, T1_IN.1);
    assert_eq!(down, "enter:T1|mousedown:T1|repaint");
    assert_eq!(i32_get(&mut session, &form, "T1SelStart"), 1);

    let drag = dispatch_mouse(&mut session, &form, "mousemove", 39, T1_IN.1, 1, 0);
    assert_eq!(drag, "mousemove:T1|repaint");
    assert_eq!(i32_get(&mut session, &form, "T1SelStart"), 1);
    assert_eq!(i32_get(&mut session, &form, "T1SelLength"), 3);
    assert_eq!(string_get(&mut session, &form, "T1SelText"), "bcd");

    let up = dispatch(&mut session, &form, "mouseup", 39, T1_IN.1);
    assert_eq!(up, "mouseup:T1|repaint");
    assert_eq!(
        string_get(&mut session, &form, "T1SelText"),
        "bcd",
        "selection survives the release"
    );
}

#[test]
fn clean_focus_change_fires_exit_then_enter() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);

    // Click T2: focus transfers T1 -> T2 BEFORE the MouseDown (no edit, so no BeforeUpdate).
    let log = dispatch(&mut session, &form, "mousedown", T2_IN.0, T2_IN.1);
    assert_eq!(log, "exit:T1|enter:T2|mousedown:T2|repaint");
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["T1.Exit", "T2.Enter"],
        "a clean focus change fires Exit on the loser then Enter on the gainer"
    );
    assert_eq!(string_get(&mut session, &form, "FocusName"), "T2");
}

#[test]
fn dirty_focus_out_fires_two_stage_then_exit_enter() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    // Focus T1 and type (now dirty), then clear the log and change focus.
    dispatch(&mut session, &form, "mousedown", T1_IN.0, T1_IN.1);
    dispatch(&mut session, &form, "mouseup", T1_IN.0, T1_IN.1);
    dispatch_char(&mut session, &form, "x");
    invoke_sub(&mut session, &form, "ClearLog");

    let log = dispatch(&mut session, &form, "mousedown", T2_IN.0, T2_IN.1);
    assert_eq!(
        log, "beforeupdate:T1|afterupdate:T1|exit:T1|enter:T2|mousedown:T2|repaint",
        "a dirty focus-out runs the full two-stage validation before Enter + MouseDown"
    );
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["T1.BeforeUpdate", "T1.AfterUpdate", "T1.Exit", "T2.Enter"],
    );
    assert_eq!(string_get(&mut session, &form, "FocusName"), "T2");
    assert_eq!(string_get(&mut session, &form, "T1Text"), "x");
}

#[test]
fn exit_veto_keeps_focus() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    invoke_sub(&mut session, &form, "ArmT1ExitVeto");
    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);

    // Clicking T2 fires T1.Exit, which vetoes: focus stays on T1 and no MouseDown reaches T2.
    let log = dispatch(&mut session, &form, "mousedown", T2_IN.0, T2_IN.1);
    assert_eq!(log, "exit:T1|repaint");
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["T1.Exit"],
        "the vetoing Exit fires; no Enter on T2"
    );
    assert_eq!(string_get(&mut session, &form, "FocusName"), "T1");
}

#[test]
fn before_update_veto_keeps_focus_and_value_dirty() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    invoke_sub(&mut session, &form, "ArmT1BeforeUpdateVeto");
    dispatch(&mut session, &form, "mousedown", T1_IN.0, T1_IN.1);
    dispatch(&mut session, &form, "mouseup", T1_IN.0, T1_IN.1);
    dispatch_char(&mut session, &form, "x"); // dirty
    invoke_sub(&mut session, &form, "ClearLog");

    // BeforeUpdate vetoes: no AfterUpdate/Exit/Enter, focus stays, value stays dirty/uncommitted.
    let log = dispatch(&mut session, &form, "mousedown", T2_IN.0, T2_IN.1);
    assert_eq!(log, "beforeupdate:T1|repaint");
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["T1.BeforeUpdate"],
        "the vetoing BeforeUpdate fires; no AfterUpdate/Exit/Enter"
    );
    assert_eq!(string_get(&mut session, &form, "FocusName"), "T1");
    assert_eq!(string_get(&mut session, &form, "T1Text"), "x");
}

const KEY_TAB: i16 = 9;
const KEY_Q: i16 = 81; // the textbox fixture's T1 KeyDown swallows 'Q'
const LBL_IN: (i32, i32) = (40, 84);

#[test]
fn tab_moves_focus_to_the_next_control() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);

    // Tab: KeyDown fires on T1, then (not swallowed) focus transfers T1 -> T2 (clean: Exit/Enter).
    let log = dispatch_key(&mut session, &form, "keydown", KEY_TAB);
    assert_eq!(log, "keydown:T1|exit:T1|enter:T2|repaint");
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["T1.KeyDown", "T1.Exit", "T2.Enter"],
        "Tab fires KeyDown then the focus-out validation then Enter on the next control"
    );
    assert_eq!(string_get(&mut session, &form, "FocusName"), "T2");
}

#[test]
fn shift_tab_wraps_focus_to_the_previous_control() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    // From T1, Shift+Tab moves backward; with only T1/T2 participating it wraps to T2.
    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);
    let log = dispatch_key_shift(&mut session, &form, "keydown", KEY_TAB, 1);
    assert_eq!(log, "keydown:T1|exit:T1|enter:T2|repaint");
    assert_eq!(string_get(&mut session, &form, "FocusName"), "T2");
}

#[test]
fn ctrl_tab_does_not_reverse_tab_order() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);
    let log = dispatch_key_shift(&mut session, &form, "keydown", KEY_TAB, SHIFT_CTRL);
    assert_eq!(
        log, "keydown:T1",
        "Ctrl+Tab is not Shift+Tab just because the MSForms Shift bitmask is nonzero"
    );
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["T1.KeyDown"]
    );
    assert_eq!(string_get(&mut session, &form, "FocusName"), "T1");
}

#[test]
fn swallowed_keydown_suppresses_the_following_character() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);

    // 'Q' KeyDown is swallowed by the handler (KeyCode -> 0); the character is then dropped.
    dispatch_key(&mut session, &form, "keydown", KEY_Q);
    let chr = dispatch_char(&mut session, &form, "Q");
    assert_eq!(chr, "char-swallowed");
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["T1.KeyDown"],
        "a swallowed KeyDown leaves no KeyPress or Change"
    );
    assert_eq!(
        string_get(&mut session, &form, "T1Text"),
        "",
        "the suppressed character is not inserted"
    );
}

#[test]
fn swallowed_non_character_key_does_not_eat_the_next_character() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);

    let esc = dispatch_key(&mut session, &form, "keydown", KEY_ESCAPE);
    assert_eq!(esc, "keydown:T1");
    let chr = dispatch_char(&mut session, &form, "A");
    assert_eq!(
        chr, "char:T1|repaint",
        "Escape has no paired CharacterInput, so it cannot poison the next typed character"
    );
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["T1.KeyDown", "T1.KeyPress", "T1.Change"]
    );
    assert_eq!(string_get(&mut session, &form, "T1Text"), "A");
}

#[test]
fn label_click_routes_without_taking_focus() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    // A Label is not focusable: a press takes no focus and arms no pressed visual, but a release
    // inside still fires Click (Label SupportsClick).
    let down = dispatch(&mut session, &form, "mousedown", LBL_IN.0, LBL_IN.1);
    assert_eq!(down, "mousedown:Lbl");
    let up = dispatch(&mut session, &form, "mouseup", LBL_IN.0, LBL_IN.1);
    assert_eq!(up, "mouseup:Lbl|click:Lbl|repaint");
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["Lbl.Click"],
        "the Label fired Click"
    );
    assert_eq!(
        string_get(&mut session, &form, "FocusName"),
        "",
        "clicking a Label never moves focus"
    );
}

// The buttons fixture: Field TextBox at (20,20,100,18); Chk CheckBox at (20,95,100,18).
const FIELD_IN: (i32, i32) = (40, 28);
const CHK2_IN: (i32, i32) = (40, 104);
const KEY_ENTER: i16 = 13;
const KEY_ESCAPE: i16 = 27;
const KEY_SPACE: i16 = 32;
const KEY_G: i16 = 71;
const SHIFT_ALT: i16 = 4;

#[test]
fn capability_catalog_is_the_single_policy_source_for_current_controls() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerButtonsForm");

    let catalog = string_get(&mut session, &form, "CapabilityCatalog");
    assert!(
        catalog.contains("Field:kind=TextBox;focusable=True;tabstop=True;click=False;pressed=False;text=True;paste=True;value=True;toggle=False;accelerator=False;default=False;cancel=False;cursor=3"),
        "TextBox descriptor missing expected edit/paste policy:\n{catalog}"
    );
    assert!(
        catalog.contains("Ok:kind=CommandButton;focusable=True;tabstop=True;click=True;pressed=True;text=False;paste=False;value=False;toggle=False;accelerator=True;default=True;cancel=True;cursor=0"),
        "CommandButton descriptor missing click/default/accelerator policy:\n{catalog}"
    );
    assert!(
        catalog.contains("Chk:kind=CheckBox;focusable=True;tabstop=True;click=True;pressed=True;text=False;paste=False;value=True;toggle=True;accelerator=False;default=False;cancel=False;cursor=0"),
        "CheckBox descriptor missing toggle/value policy:\n{catalog}"
    );
}

#[test]
fn interaction_index_caches_tab_default_cancel_and_accelerator_maps() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerButtonsForm");

    assert_eq!(
        i32_get(&mut session, &form, "InteractionIndexBuildCount"),
        0,
        "the reducer should build the interaction index lazily"
    );

    let summary = string_get(&mut session, &form, "InteractionIndexSummary");
    assert!(
        summary.contains(";first=Field;last=Chk;default=Ok;cancel=CancelBtn;"),
        "summary should cache tab/default/cancel choices: {summary}"
    );
    assert!(
        summary.contains(";alt+G=Go"),
        "summary should cache the &Go accelerator: {summary}"
    );
    assert_eq!(
        i32_get(&mut session, &form, "InteractionIndexBuildCount"),
        1,
        "reading the summary builds the index exactly once"
    );

    focus_and_clear(&mut session, &form, FIELD_IN.0, FIELD_IN.1);
    let log = dispatch_key(&mut session, &form, "keydown", KEY_TAB);
    assert_eq!(log, "keydown:Field|exit:Field|enter:Ok|repaint");
    assert_eq!(
        i32_get(&mut session, &form, "InteractionIndexBuildCount"),
        1,
        "dispatch reuses the warm index while the form interaction revision is stable"
    );

    invoke_sub(&mut session, &form, "DisableDefaultButton");
    assert_eq!(
        i32_get(&mut session, &form, "InteractionIndexBuildCount"),
        1,
        "a routing-affecting property change marks the cache stale without rebuilding immediately"
    );
    let after_disable = string_get(&mut session, &form, "InteractionIndexSummary");
    assert!(
        after_disable.contains(";first=Field;last=Chk;default=;cancel=CancelBtn;"),
        "disabling the default button should rebuild without Ok as default: {after_disable}"
    );
    assert_eq!(
        i32_get(&mut session, &form, "InteractionIndexBuildCount"),
        2,
        "the next interaction-index read rebuilds after the revision changes"
    );
}

#[test]
fn interaction_manager_tracks_hover_and_cursor_without_capture() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerButtonsForm");

    let log = dispatch_btn(&mut session, &form, "mousemove", FIELD_IN.0, FIELD_IN.1, 0);
    assert_eq!(log, "mousemove:Field");
    let state = string_get(&mut session, &form, "InteractionStateSummary");
    assert!(
        state.contains("focus=;capture=;pressed=;hover=Field;cursor_target=Field;cursor=3"),
        "TextBox hover should own the I-beam cursor target: {state}"
    );

    let miss = dispatch_btn(&mut session, &form, "mousemove", 170, 120, 0);
    assert_eq!(miss, "");
    let state = string_get(&mut session, &form, "InteractionStateSummary");
    assert!(
        state.contains("focus=;capture=;pressed=;hover=;cursor_target=;cursor=0"),
        "a miss should clear hover/cursor target: {state}"
    );
}

#[test]
fn interaction_manager_rebuilds_tab_maps_after_mutations() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerButtonsForm");

    let summary = string_get(&mut session, &form, "InteractionIndexSummary");
    assert!(
        summary.contains(";first=Field;last=Chk;default=Ok;cancel=CancelBtn;"),
        "initial tab/default maps should include every live participant: {summary}"
    );
    assert_eq!(
        i32_get(&mut session, &form, "InteractionIndexBuildCount"),
        1
    );

    invoke_sub(&mut session, &form, "HideCheckBox");
    let summary = string_get(&mut session, &form, "InteractionIndexSummary");
    assert!(
        summary.contains(";first=Field;last=Go;default=Ok;cancel=CancelBtn;"),
        "hidden controls should leave the tab map: {summary}"
    );
    assert_eq!(
        i32_get(&mut session, &form, "InteractionIndexBuildCount"),
        2
    );

    invoke_sub(&mut session, &form, "DisableFieldTabStop");
    let summary = string_get(&mut session, &form, "InteractionIndexSummary");
    assert!(
        summary.contains(";first=Ok;last=Go;default=Ok;cancel=CancelBtn;"),
        "TabStop=False should leave the tab map without affecting default/cancel: {summary}"
    );
    assert_eq!(
        i32_get(&mut session, &form, "InteractionIndexBuildCount"),
        3
    );

    invoke_sub(&mut session, &form, "AddLateTextBox");
    let summary = string_get(&mut session, &form, "InteractionIndexSummary");
    assert!(
        summary.contains(";first=Ok;last=Late;default=Ok;cancel=CancelBtn;"),
        "runtime Controls.Add should invalidate and rebuild the tab map: {summary}"
    );
    assert_eq!(
        i32_get(&mut session, &form, "InteractionIndexBuildCount"),
        4
    );
}

#[test]
fn theme_painter_maps_disabled_text_and_edges_for_standard_controls() {
    let (mut session, surface) = prepare_session();
    let form = build_form(&mut session, "ReducerButtonsForm");

    let snapshot = surface.snapshot().expect("surface snapshot");
    let scene = snapshot.scene.expect("scene snapshot");
    let ok = scene.get(NodeId(2)).expect("Ok button scene node");
    assert_eq!(
        draw_edge_effect(&ok.prims),
        Some(EdgeEffect::Raised),
        "standard controls should emit their themed edge effect"
    );
    let (color, disabled) = draw_text_style(&ok.prims).expect("Ok DrawText style");
    assert_eq!(color, THEME_TEXT);
    assert!(!disabled, "enabled text should not carry the disabled flag");

    invoke_sub(&mut session, &form, "DisableDefaultButton");
    invoke_sub(&mut session, &form, "Render");

    let snapshot = surface.snapshot().expect("surface snapshot");
    let scene = snapshot.scene.expect("scene snapshot");
    let ok = scene.get(NodeId(2)).expect("Ok button scene node");
    let (color, disabled) = draw_text_style(&ok.prims).expect("disabled Ok DrawText style");
    assert_eq!(
        color, THEME_DISABLED_TEXT,
        "ThemePainter should resolve disabled standard text"
    );
    assert!(disabled, "disabled text should carry the Scene text flag");
}

#[test]
fn enter_activates_the_default_button() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerButtonsForm");

    focus_and_clear(&mut session, &form, FIELD_IN.0, FIELD_IN.1);

    // Enter on the field: KeyDown fires, then focus moves to the default OK button and it clicks.
    let log = dispatch_key(&mut session, &form, "keydown", KEY_ENTER);
    assert_eq!(log, "keydown:Field|exit:Field|enter:Ok|click:Ok|repaint");
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["Field.KeyDown", "Field.Exit", "Ok.Enter", "Ok.Click"],
    );
    assert_eq!(string_get(&mut session, &form, "FocusName"), "Ok");
}

#[test]
fn escape_activates_the_cancel_button_in_place() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerButtonsForm");

    focus_and_clear(&mut session, &form, FIELD_IN.0, FIELD_IN.1);

    // Escape clicks the cancel button without moving focus.
    let log = dispatch_key(&mut session, &form, "keydown", KEY_ESCAPE);
    assert_eq!(log, "keydown:Field|click:CancelBtn");
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["Field.KeyDown", "Cancel.Click"],
    );
    assert_eq!(
        string_get(&mut session, &form, "FocusName"),
        "Field",
        "Escape does not move focus"
    );
}

#[test]
fn alt_accelerator_activates_the_matching_button() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerButtonsForm");

    focus_and_clear(&mut session, &form, FIELD_IN.0, FIELD_IN.1);

    // Alt+G matches the "&Go" button: focus moves to it and it clicks.
    let log = dispatch_key_shift(&mut session, &form, "keydown", KEY_G, SHIFT_ALT);
    assert_eq!(log, "keydown:Field|exit:Field|enter:Go|click:Go|repaint");
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["Field.KeyDown", "Field.Exit", "Go.Enter", "Go.Click"],
    );
    assert_eq!(string_get(&mut session, &form, "FocusName"), "Go");
}

#[test]
fn space_toggles_the_focused_checkbox_value_first() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerButtonsForm");

    // Click the CheckBox to focus + check it (value True), then clear the log.
    dispatch(&mut session, &form, "mousedown", CHK2_IN.0, CHK2_IN.1);
    dispatch(&mut session, &form, "mouseup", CHK2_IN.0, CHK2_IN.1);
    assert!(
        bool_get(&mut session, &form, "ChkValue"),
        "click checked it"
    );
    invoke_sub(&mut session, &form, "ClearLog");

    // Space toggles it back off: Change/Click fire BEFORE KeyDown (value-first keyboard order).
    let log = dispatch_key(&mut session, &form, "keydown", KEY_SPACE);
    assert_eq!(log, "activate:Chk|keydown:Chk|repaint");
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["Chk.Change", "Chk.Click", "Chk.KeyDown"],
        "Space toggles the value (Change/Click) before the KeyDown"
    );
    assert!(
        !bool_get(&mut session, &form, "ChkValue"),
        "Space toggled the value back off"
    );
}

const KEY_CTRL: i16 = 17;
const KEY_V: i16 = 86;
const SHIFT_CTRL: i16 = 2;

#[test]
fn ctrl_v_pastes_clipboard_into_the_focused_textbox() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    set_clipboard_text(&mut session, &form, "PASTED");
    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);

    // Ctrl down, then V down: KeyDown(Ctrl), KeyDown(V), then BeforeDropOrPaste -> Change. No KeyPress.
    dispatch_key_shift(&mut session, &form, "keydown", KEY_CTRL, SHIFT_CTRL);
    let log = dispatch_key_shift(&mut session, &form, "keydown", KEY_V, SHIFT_CTRL);
    assert_eq!(log, "keydown:T1|paste:T1|repaint");
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec![
            "T1.KeyDown",
            "T1.KeyDown",
            "T1.BeforeDropOrPaste",
            "T1.Change"
        ],
        "Ctrl+V: KeyDown(Ctrl), KeyDown(V), BeforeDropOrPaste, Change -- no KeyPress"
    );
    assert_eq!(string_get(&mut session, &form, "T1Text"), "PASTED");
}

#[test]
fn ctrl_v_with_empty_clipboard_is_a_no_op() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    set_clipboard_text(&mut session, &form, "");
    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);

    dispatch_key_shift(&mut session, &form, "keydown", KEY_CTRL, SHIFT_CTRL);
    let log = dispatch_key_shift(&mut session, &form, "keydown", KEY_V, SHIFT_CTRL);
    assert_eq!(log, "keydown:T1", "empty clipboard pastes nothing");
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["T1.KeyDown", "T1.KeyDown"],
        "no BeforeDropOrPaste or Change for an empty clipboard"
    );
    assert_eq!(string_get(&mut session, &form, "T1Text"), "");
}

#[test]
fn paste_veto_suppresses_the_change() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    invoke_sub(&mut session, &form, "ArmT1PasteVeto");
    set_clipboard_text(&mut session, &form, "X");
    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);

    dispatch_key_shift(&mut session, &form, "keydown", KEY_CTRL, SHIFT_CTRL);
    dispatch_key_shift(&mut session, &form, "keydown", KEY_V, SHIFT_CTRL);
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["T1.KeyDown", "T1.KeyDown", "T1.BeforeDropOrPaste"],
        "a vetoing BeforeDropOrPaste suppresses the insert + Change"
    );
    assert_eq!(string_get(&mut session, &form, "T1Text"), "");
}

#[test]
fn swallowed_keypress_suppresses_the_character_insert() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);

    // 'Z' is swallowed at the KeyPress level (KeyAscii -> 0): the KeyPress fires but the character
    // is neither inserted nor does Change fire.
    let chr = dispatch_char(&mut session, &form, "Z");
    assert_eq!(
        chr, "char:T1|repaint",
        "the char dispatched (KeyPress fired) but inserted nothing"
    );
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["T1.KeyPress"],
        "a swallowed KeyPress leaves no Change"
    );
    assert_eq!(
        string_get(&mut session, &form, "T1Text"),
        "",
        "the swallowed character is not inserted"
    );
}

#[test]
fn drag_drop_pastes_text_into_the_focused_textbox() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);

    // A drop fires the same BeforeDropOrPaste -> Change path as a paste, different origin.
    let log = dispatch_drop(&mut session, &form, "DROP");
    assert_eq!(log, "drop:T1|repaint");
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["T1.BeforeDropOrPaste", "T1.Change"],
    );
    assert_eq!(string_get(&mut session, &form, "T1Text"), "DROP");
}
