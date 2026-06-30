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
fn clean_focus_change_fires_exit_then_enter() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);

    // Click T2: focus transfers T1 -> T2 BEFORE the MouseDown (no edit, so no BeforeUpdate).
    let log = dispatch(&mut session, &form, "mousedown", T2_IN.0, T2_IN.1);
    assert_eq!(log, "exit:T1|enter:T2|mousedown:T2");
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
        log, "beforeupdate:T1|afterupdate:T1|exit:T1|enter:T2|mousedown:T2",
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
    assert_eq!(log, "keydown:T1|exit:T1|enter:T2");
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
    assert_eq!(log, "keydown:T1|exit:T1|enter:T2");
    assert_eq!(string_get(&mut session, &form, "FocusName"), "T2");
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
