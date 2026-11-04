//! Reducer-pivot increment 1 (oxforms-ih6.1): the VBA InteractionManager, reached through
//! the stable OxReducer facade, routes pointer input and raises controls' ordered FM20 events,
//! with NO Rust reducer (calcforms-core) in the loop. This is the spine of the reducer pivot
//! (docs/specs/MESSAGE_HANDLING_AND_UPDATE_FLOW.md): geometric routing + interaction state
//! (capture, pressed) + ordered event raising + a real surface repaint, all in VBA.
//!
//! Session assembly mirrors calcvba_w007_object_model.rs; the CalcForms.Surface registration
//! mirrors calcvba_w007_render_frame.rs (the reducer drives UserForm.Render, which crosses the
//! surface). Fixtures hold WithEvents sinks so the tests assert the REAL events fired in order,
//! not just the reducer's own effect log; the headless framebuffer hash proves the pressed
//! face actually rendered and reverted.

use std::path::{Path, PathBuf};
use std::sync::Arc;

use calcforms_calcvba_adapter::surface::{register_surface, SurfaceFactory};
use calcforms_pal::scene::{
    render_headless_report, EdgeEffect, FontId, NodeId, Paint, Prim, RectF, StubShaper, TextRunId,
};
use calcforms_pal::Color;
use calcforms_pal_win::{load_ui_font, AbGlyphShaper};

use calcvba_bundle::ProjectMemberKind;
use calcvba_com::PortableComProjection;
use calcvba_engine::{Engine, HostConfig, HostProfileProvider, ProjectRuntimeSession};
use calcvba_hal::model::HostPolicy;
use calcvba_runtime::{ObjectRef, Variant};
use calcvba_symbol::manifest::{
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

/// The CalcForms VBA library + the OxReducer + the increment-1 fixtures, with the
/// `CalcForms.Surface` boundary registered so the reducer's `UserForm.Render` self-renders.
/// Returns the surface so a test can read back the resident-scene revision + framebuffer hash.
fn prepare_session() -> (ProjectRuntimeSession, Arc<SurfaceFactory>) {
    prepare_session_with_surface(Arc::new(SurfaceFactory::with_shaper(Arc::new(StubShaper))))
}

fn prepare_session_with_surface(
    surface: Arc<SurfaceFactory>,
) -> (ProjectRuntimeSession, Arc<SurfaceFactory>) {
    let modules = vec![
        module_unit(
            "CalcFormsModel",
            ModuleKind::Procedural,
            "vba/calcforms/CalcFormsModel.bas",
        ),
        module_unit(
            "IOxControl",
            ModuleKind::Class,
            "vba/calcforms/IOxControl.cls",
        ),
        module_unit(
            "IOxControlHost",
            ModuleKind::Class,
            "vba/calcforms/IOxControlHost.cls",
        ),
        module_unit(
            "IOxControlContainer",
            ModuleKind::Class,
            "vba/calcforms/IOxControlContainer.cls",
        ),
        module_unit(
            "OxControlCore",
            ModuleKind::Class,
            "vba/calcforms/OxControlCore.cls",
        ),
        module_unit("Controls", ModuleKind::Class, "vba/calcforms/Controls.cls"),
        module_unit(
            "ReturnInteger",
            ModuleKind::Class,
            "vba/calcforms/ReturnInteger.cls",
        ),
        module_unit(
            "ReturnBoolean",
            ModuleKind::Class,
            "vba/calcforms/ReturnBoolean.cls",
        ),
        module_unit("Label", ModuleKind::Class, "vba/calcforms/Label.cls"),
        module_unit(
            "OxTextService",
            ModuleKind::Class,
            "vba/calcforms/OxTextService.cls",
        ),
        module_unit("TextBox", ModuleKind::Class, "vba/calcforms/TextBox.cls"),
        module_unit(
            "CommandButton",
            ModuleKind::Class,
            "vba/calcforms/CommandButton.cls",
        ),
        module_unit("CheckBox", ModuleKind::Class, "vba/calcforms/CheckBox.cls"),
        module_unit("ListBox", ModuleKind::Class, "vba/calcforms/ListBox.cls"),
        module_unit("ComboBox", ModuleKind::Class, "vba/calcforms/ComboBox.cls"),
        module_unit("Frame", ModuleKind::Class, "vba/calcforms/Frame.cls"),
        module_unit("Image", ModuleKind::Class, "vba/calcforms/Image.cls"),
        module_unit(
            "SpinButton",
            ModuleKind::Class,
            "vba/calcforms/SpinButton.cls",
        ),
        module_unit(
            "ScrollBar",
            ModuleKind::Class,
            "vba/calcforms/ScrollBar.cls",
        ),
        module_unit("Tab", ModuleKind::Class, "vba/calcforms/Tab.cls"),
        module_unit("Tabs", ModuleKind::Class, "vba/calcforms/Tabs.cls"),
        module_unit("TabStrip", ModuleKind::Class, "vba/calcforms/TabStrip.cls"),
        module_unit(
            "MultiPage",
            ModuleKind::Class,
            "vba/calcforms/MultiPage.cls",
        ),
        module_unit("Page", ModuleKind::Class, "vba/calcforms/Page.cls"),
        module_unit("Pages", ModuleKind::Class, "vba/calcforms/Pages.cls"),
        module_unit(
            "ToggleButton",
            ModuleKind::Class,
            "vba/calcforms/ToggleButton.cls",
        ),
        module_unit(
            "OptionButtonControl",
            ModuleKind::Class,
            "vba/calcforms/OptionButtonControl.cls",
        ),
        module_unit("UserForm", ModuleKind::Class, "vba/calcforms/UserForm.cls"),
        module_unit(
            "OxTheme",
            ModuleKind::Procedural,
            "vba/calcforms/OxTheme.bas",
        ),
        module_unit(
            "OxControlPaint",
            ModuleKind::Procedural,
            "vba/calcforms/OxControlPaint.bas",
        ),
        module_unit(
            "OxSceneBuilder",
            ModuleKind::Class,
            "vba/calcforms/OxSceneBuilder.cls",
        ),
        module_unit(
            "OxAccessibilityService",
            ModuleKind::Class,
            "vba/calcforms/OxAccessibilityService.cls",
        ),
        module_unit(
            "OxInteractionManager",
            ModuleKind::Class,
            "vba/calcforms/OxInteractionManager.cls",
        ),
        module_unit(
            "OxReducer",
            ModuleKind::Class,
            "vba/calcforms/OxReducer.cls",
        ),
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
        module_unit(
            "ReducerListBoxForm",
            ModuleKind::Class,
            "vba/smoke/fixtures/reducer_listbox_form.cls",
        ),
        module_unit(
            "ReducerComboBoxForm",
            ModuleKind::Class,
            "vba/smoke/fixtures/reducer_combobox_form.cls",
        ),
        module_unit(
            "ReducerFrameForm",
            ModuleKind::Class,
            "vba/smoke/fixtures/reducer_frame_form.cls",
        ),
        module_unit(
            "ReducerSpinButtonForm",
            ModuleKind::Class,
            "vba/smoke/fixtures/reducer_spinbutton_form.cls",
        ),
        module_unit(
            "ReducerScrollBarForm",
            ModuleKind::Class,
            "vba/smoke/fixtures/reducer_scrollbar_form.cls",
        ),
        module_unit(
            "ReducerTabStripForm",
            ModuleKind::Class,
            "vba/smoke/fixtures/reducer_tabstrip_form.cls",
        ),
        module_unit(
            "ReducerMultiPageForm",
            ModuleKind::Class,
            "vba/smoke/fixtures/reducer_multipage_form.cls",
        ),
        module_unit(
            "ReducerToggleButtonForm",
            ModuleKind::Class,
            "vba/smoke/fixtures/reducer_togglebutton_form.cls",
        ),
        module_unit(
            "ReducerOptionButtonForm",
            ModuleKind::Class,
            "vba/smoke/fixtures/reducer_optionbutton_form.cls",
        ),
    ];

    let manifest = SymbolProjectManifest {
        project_name: "ReducerCmdButton".to_string(),
        project_kind: ProjectKind::Library,
        modules,
        references: Vec::new(),
        reference_projects: Vec::new(),
        conditional_constants: Default::default(),
        conditional_compilation_target: Default::default(),
    };

    let program = calcvba_bind::bind_program(&manifest, &calcvba_symbol::CatalogTypeLibResolver)
        .expect("bind reducer cmd-button project");
    let bundle =
        calcvba_oxir::elaborate::elaborate(&program).expect("elaborate reducer cmd-button project");

    let projection = Arc::new(PortableComProjection::new());
    register_surface(&projection, surface.clone());

    let profile = HostProfileProvider::new()
        .with_portable_com_projection(projection)
        .with_host_policy(HostPolicy::native());
    let engine = Engine::new(HostConfig::vm3()).with_host_profile_provider(profile);
    let session = engine
        .prepare_image_session(calcvba_oxir::OxImage::new(vec![bundle]))
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

fn set_t1_value(session: &mut ProjectRuntimeSession, form: &ObjectRef, text: &str) {
    call(
        session,
        form.clone(),
        "SetT1Value",
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

fn set_t1_sel_text(session: &mut ProjectRuntimeSession, form: &ObjectRef, text: &str) {
    call(
        session,
        form.clone(),
        "SetT1SelText",
        ProjectMemberKind::Method,
        vec![Variant::from_string(text)],
    );
}

fn set_t1_hide_selection(session: &mut ProjectRuntimeSession, form: &ObjectRef, value: bool) {
    call(
        session,
        form.clone(),
        "SetT1HideSelection",
        ProjectMemberKind::Method,
        vec![Variant::from_bool(value)],
    );
}

fn set_t1_multiline(session: &mut ProjectRuntimeSession, form: &ObjectRef, value: bool) {
    call(
        session,
        form.clone(),
        "SetT1MultiLine",
        ProjectMemberKind::Method,
        vec![Variant::from_bool(value)],
    );
}

fn t1_update_composition(session: &mut ProjectRuntimeSession, form: &ObjectRef, text: &str) {
    call(
        session,
        form.clone(),
        "T1UpdateComposition",
        ProjectMemberKind::Method,
        vec![Variant::from_string(text)],
    );
}

fn t1_commit_composition(session: &mut ProjectRuntimeSession, form: &ObjectRef, text: &str) {
    call(
        session,
        form.clone(),
        "T1CommitComposition",
        ProjectMemberKind::Method,
        vec![Variant::from_string(text)],
    );
}

fn t1_cancel_composition(session: &mut ProjectRuntimeSession, form: &ObjectRef) {
    invoke_sub(session, form, "T1CancelComposition");
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
    let snapshot = surface.snapshot().expect("surface snapshot");
    render_headless_report(snapshot.scene.as_ref().expect("scene snapshot")).framebuffer_hash
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

fn scene_has_node(surface: &Arc<SurfaceFactory>, node: NodeId) -> bool {
    let snapshot = surface.snapshot().expect("surface snapshot");
    let scene = snapshot.scene.expect("scene snapshot");
    scene.get(node).is_some()
}

const TEXT_SELECTION_COLOR: Color = Color::rgba(0x00, 0x78, 0xd7, 0xff);
const TEXT_SELECTION_FORE_COLOR: Color = Color::rgba(0xff, 0xff, 0xff, 0xff);
const TEXT_CARET_COLOR: Color = Color::rgba(0x00, 0x00, 0x00, 0xff);
const THEME_COMMAND_FACE: Color = Color::rgba(0xf0, 0xf0, 0xf0, 0xff);
const THEME_COMMAND_PRESSED: Color = Color::rgba(0xf8, 0xf8, 0xf8, 0xff);
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

fn stroke_rect_with_color(prims: &[Prim], color: Color) -> Option<RectF> {
    prims.iter().find_map(|prim| match prim {
        Prim::StrokeRect { rect, stroke } if solid_color(&stroke.paint) == Some(color) => {
            Some(*rect)
        }
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
        assert_rect_close(
            stroke_rect_with_color(&button.prims, Color::rgba(0, 0, 0, 0xff))
                .expect("focused CommandButton should emit a focus adorner stroke"),
            RectF::new(20.0, 20.0, 80.0, 30.0),
            "CommandButton focus adorner",
        );
    }

    // Release inside: MouseUp then Click then release, repaint.
    let up = dispatch(&mut session, &form, "mouseup", INSIDE.0, INSIDE.1);
    assert_eq!(up, "mouseup:Btn1|click:Btn1|release:Btn1|repaint");
    assert!(
        !pressed(&mut session, &form),
        "the press releases on mouse up"
    );
    // The release reverts the face to idle while preserving focused-state pixels.
    assert_ne!(
        framebuffer_hash(&surface),
        hash_pressed,
        "releasing the press changes the rendered face"
    );
    {
        let snapshot = surface.snapshot().expect("surface snapshot");
        let scene = snapshot.scene.expect("scene snapshot");
        let button = scene.get(NodeId(1)).expect("button scene node");
        assert!(
            fill_rect_with_color(&button.prims, THEME_COMMAND_FACE).is_some(),
            "release should restore the idle CommandButton face"
        );
        assert_rect_close(
            stroke_rect_with_color(&button.prims, Color::rgba(0, 0, 0, 0xff))
                .expect("focused CommandButton should keep its focus adorner after release"),
            RectF::new(20.0, 20.0, 80.0, 30.0),
            "CommandButton focused release adorner",
        );
    }

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
    let (mut session, surface) = prepare_session();
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
    let snapshot = surface.snapshot().expect("surface snapshot");
    let scene = snapshot.scene.expect("scene snapshot");
    let checkbox = scene.get(NodeId(1)).expect("CheckBox node");
    let focus = stroke_rect_with_color(&checkbox.prims, Color::rgba(0, 0, 0, 0xff))
        .expect("focused CheckBox should emit a caption focus adorner");
    assert!(focus.x >= 32.0 && focus.w < 100.0);
    assert!(focus.y >= 20.0 && focus.y + focus.h <= 40.0);

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

// The ToggleButton fixture control is at Left=20, Top=20, Width=110, Height=24.
const TOGGLE_INSIDE: (i32, i32) = (35, 32);

#[test]
fn togglebutton_factory_diagnostics_and_accessibility_are_live() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerToggleButtonForm");

    let diagnostics = string_get(&mut session, &form, "Diagnostics");
    assert!(
        diagnostics.contains("caption=Toggle;value=False")
            && diagnostics.contains("capabilities=kind=ToggleButton;focusable=True;tabstop=True;click=True;pressed=True;text=False;paste=False;value=True;toggle=True")
            && diagnostics.contains("accessibility=togglebutton/False/toggle,value"),
        "ToggleButton diagnostics should expose value, capabilities, and accessibility: {diagnostics}"
    );
}

#[test]
fn togglebutton_mouse_and_keyboard_toggle_value_first() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerToggleButtonForm");

    let down = dispatch(
        &mut session,
        &form,
        "mousedown",
        TOGGLE_INSIDE.0,
        TOGGLE_INSIDE.1,
    );
    assert_eq!(down, "enter:Tog|mousedown:Tog|press:Tog|repaint");
    assert!(!value(&mut session, &form), "mouse down does not toggle");
    let up = dispatch(
        &mut session,
        &form,
        "mouseup",
        TOGGLE_INSIDE.0,
        TOGGLE_INSIDE.1,
    );
    assert_eq!(up, "mouseup:Tog|click:Tog|release:Tog|repaint");
    assert!(value(&mut session, &form), "mouse up toggles on");

    invoke_sub(&mut session, &form, "ClearLog");
    let key = dispatch_key(&mut session, &form, "keydown", KEY_SPACE);
    assert_eq!(key, "activate:Tog|keydown:Tog|repaint");
    assert!(!value(&mut session, &form), "Space toggles off");
    let key_up = dispatch_key(&mut session, &form, "keyup", KEY_SPACE);
    assert_eq!(key_up, "keyup:Tog");

    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["Change=False", "Click=False", "KeyDown:32", "KeyUp:32",],
        "keyboard activation should match the CheckBox value-first event order"
    );
}

#[test]
fn togglebutton_value_latches_pressed_face_and_accessibility_selected() {
    let (mut session, surface) = prepare_session();
    let form = build_form(&mut session, "ReducerToggleButtonForm");

    {
        let snapshot = surface.snapshot().expect("surface snapshot");
        let scene = snapshot.scene.expect("scene snapshot");
        let button = scene.get(NodeId(1)).expect("ToggleButton node");
        assert!(
            fill_rect_with_color(&button.prims, THEME_COMMAND_FACE).is_some(),
            "unchecked ToggleButton should start with the idle button face"
        );
    }

    invoke_sub(&mut session, &form, "SetValueTrue");
    {
        let snapshot = surface.snapshot().expect("surface snapshot");
        let scene = snapshot.scene.expect("scene snapshot");
        let button = scene.get(NodeId(1)).expect("ToggleButton node");
        assert!(
            fill_rect_with_color(&button.prims, THEME_COMMAND_PRESSED).is_some(),
            "programmatic Value=True should latch the pressed button face"
        );
        assert_eq!(
            draw_edge_effect(&button.prims),
            Some(EdgeEffect::Sunken),
            "latched ToggleButton should use the pressed/sunken edge"
        );
    }

    let accessibility = string_get(&mut session, &form, "AccessibilitySnapshot");
    assert!(
        accessibility.contains(
            "role=togglebutton;name=Tog;value=True;enabled=True;visible=True;focused=False;selected=True;sel_start=0;sel_length=0;sel_text=;patterns=toggle,value"
        ),
        "ToggleButton accessibility should expose toggled value and selected state: {accessibility}"
    );
}

// The OptionButton fixture controls: One at (20,18,110,24), Two at (20,48,110,24),
// Other at (150,18,110,24).
const OPTION_ONE_INSIDE: (i32, i32) = (35, 30);
const OPTION_TWO_INSIDE: (i32, i32) = (35, 60);

#[test]
fn optionbutton_factory_diagnostics_and_accessibility_are_live() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerOptionButtonForm");

    let diagnostics = string_get(&mut session, &form, "Diagnostics");
    assert!(
        diagnostics.contains("one=True;two=False;other=True;group=Mode")
            && diagnostics.contains("capabilities=kind=OptionButton;focusable=True;tabstop=True;click=True;pressed=True;text=False;paste=False;value=True;toggle=True")
            && diagnostics.contains("accessibility=radio/True/selection,value"),
        "OptionButton diagnostics should expose group value, capabilities, and accessibility: {diagnostics}"
    );

    let accessibility = string_get(&mut session, &form, "AccessibilitySnapshot");
    assert!(
        accessibility.contains("role=radio;name=One;value=True;enabled=True;visible=True;focused=False;selected=True")
            && accessibility.contains("role=radio;name=Two;value=False;enabled=True;visible=True;focused=False;selected=False")
            && accessibility.contains("role=radio;name=Other;value=True;enabled=True;visible=True;focused=False;selected=True"),
        "OptionButton accessibility should expose selected state without collapsing different groups: {accessibility}"
    );
}

#[test]
fn optionbutton_mouse_and_keyboard_select_with_group_exclusion() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerOptionButtonForm");

    let down = dispatch(
        &mut session,
        &form,
        "mousedown",
        OPTION_TWO_INSIDE.0,
        OPTION_TWO_INSIDE.1,
    );
    assert_eq!(down, "enter:Two|mousedown:Two|press:Two|repaint");
    let up = dispatch(
        &mut session,
        &form,
        "mouseup",
        OPTION_TWO_INSIDE.0,
        OPTION_TWO_INSIDE.1,
    );
    assert_eq!(up, "mouseup:Two|click:Two|release:Two|repaint");
    assert_eq!(
        string_get(&mut session, &form, "Values"),
        "False/True/True",
        "selecting Two should clear only the same GroupName peer"
    );

    invoke_sub(&mut session, &form, "ClearLog");
    let key = dispatch_key(&mut session, &form, "keydown", KEY_SPACE);
    assert_eq!(key, "activate:Two|keydown:Two");
    assert_eq!(
        string_get(&mut session, &form, "Values"),
        "False/True/True",
        "Space on an already-selected OptionButton should not toggle it off"
    );
    let key_up = dispatch_key(&mut session, &form, "keyup", KEY_SPACE);
    assert_eq!(key_up, "keyup:Two");
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["Two.Click=True", "Two.KeyDown:32", "Two.KeyUp:32"],
        "re-selecting an already-selected OptionButton should Click without Change"
    );

    invoke_sub(&mut session, &form, "ClearLog");
    dispatch(
        &mut session,
        &form,
        "mousedown",
        OPTION_ONE_INSIDE.0,
        OPTION_ONE_INSIDE.1,
    );
    dispatch(
        &mut session,
        &form,
        "mouseup",
        OPTION_ONE_INSIDE.0,
        OPTION_ONE_INSIDE.1,
    );
    assert_eq!(
        string_get(&mut session, &form, "Values"),
        "True/False/True",
        "selecting One should clear Two and leave the other group alone"
    );
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec![
            "Two.BeforeUpdate",
            "Two.AfterUpdate",
            "Two.Exit",
            "One.Enter",
            "One.MouseDown",
            "One.MouseUp",
            "Two.Change=False",
            "One.Change=True",
            "One.Click=True",
        ],
        "mouse selection should route focus, clear same-group peer, then click target"
    );
}

#[test]
fn optionbutton_render_uses_radio_dot_for_selected_value() {
    let (mut session, surface) = prepare_session();
    let _form = build_form(&mut session, "ReducerOptionButtonForm");

    let snapshot = surface.snapshot().expect("surface snapshot");
    let scene = snapshot.scene.expect("scene snapshot");
    let one = scene.get(NodeId(1)).expect("OptionButton One node");
    let two = scene.get(NodeId(2)).expect("OptionButton Two node");

    assert!(
        fill_rect_with_color(&one.prims, THEME_TEXT).is_some(),
        "selected OptionButton should render an inner radio dot"
    );
    assert!(
        fill_rect_with_color(&two.prims, THEME_TEXT).is_none(),
        "unselected OptionButton should render only the outer radio glyph"
    );
}

// The textbox fixture controls: T1 at (20,20,100,18) -> x in [20,120), y in [20,38);
// T2 at (20,50,100,18) -> x in [20,120), y in [50,68).
const T1_IN: (i32, i32) = (40, 28);
const T2_IN: (i32, i32) = (40, 58);
const KEY_A: i16 = 65;
const KEY_C: i16 = 67;
const KEY_X: i16 = 88;
const KEY_Y: i16 = 89;
const KEY_Z: i16 = 90;
const KEY_BACKSPACE: i16 = 8;
const KEY_ENTER_TEXTBOX: i16 = 13;
const KEY_HOME: i16 = 36;
const KEY_END: i16 = 35;
const KEY_LEFT: i16 = 37;
const KEY_RIGHT: i16 = 39;
const KEY_DELETE: i16 = 46;
const KEY_F4: i16 = 115;
const SHIFT_SHIFT: i16 = 1;
const SHIFT_CTRL: i16 = 2;

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
fn textbox_programmatic_value_selection_and_diagnostics_are_side_effect_safe() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);
    set_t1_value(&mut session, &form, "abcdef");
    assert_eq!(string_get(&mut session, &form, "HandlerLog"), "");
    assert_eq!(string_get(&mut session, &form, "T1Text"), "abcdef");
    assert_eq!(string_get(&mut session, &form, "T1Value"), "abcdef");

    set_t1_selection(&mut session, &form, 2, 99);
    assert_eq!(i32_get(&mut session, &form, "T1SelStart"), 2);
    assert_eq!(
        i32_get(&mut session, &form, "T1SelLength"),
        4,
        "SelLength setter should clamp to the end of the current text"
    );
    assert_eq!(string_get(&mut session, &form, "T1SelText"), "cdef");

    set_t1_sel_text(&mut session, &form, "XY");
    assert_eq!(string_get(&mut session, &form, "T1Text"), "abXY");
    assert_eq!(string_get(&mut session, &form, "T1Value"), "abXY");
    assert_eq!(i32_get(&mut session, &form, "T1SelStart"), 4);
    assert_eq!(i32_get(&mut session, &form, "T1SelLength"), 0);
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog"),
        "",
        "programmatic Value/SelText/selection setters should not raise Change"
    );

    set_t1_hide_selection(&mut session, &form, false);
    assert!(
        !bool_get(&mut session, &form, "T1HideSelection"),
        "HideSelection setter should update the live TextBox property"
    );
    let diagnostics = string_get(&mut session, &form, "T1Diagnostics");
    assert!(
        diagnostics.contains("text=abXY;value=abXY;sel_start=4;sel_length=0")
            && diagnostics.contains(";hide_selection=False;")
            && diagnostics.contains("capabilities=kind=TextBox")
            && diagnostics.contains(";text=True;paste=True;value=True"),
        "TextBox diagnostics should expose the representative property/capability surface: {diagnostics}"
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
fn textbox_undo_redo_tracks_user_edits_without_programmatic_noise() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);
    set_t1_text(&mut session, &form, "seed");
    assert!(
        !bool_get(&mut session, &form, "T1CanUndo"),
        "programmatic setup should not create user undo history"
    );

    dispatch_char(&mut session, &form, "!");
    assert_eq!(string_get(&mut session, &form, "T1Text"), "seed!");
    assert!(bool_get(&mut session, &form, "T1CanUndo"));
    assert!(!bool_get(&mut session, &form, "T1CanRedo"));

    let undo = dispatch_key_shift(&mut session, &form, "keydown", KEY_Z, SHIFT_CTRL);
    assert_eq!(undo, "keydown:T1|repaint");
    assert_eq!(string_get(&mut session, &form, "T1Text"), "seed");
    assert!(bool_get(&mut session, &form, "T1CanRedo"));

    let redo = dispatch_key_shift(&mut session, &form, "keydown", KEY_Y, SHIFT_CTRL);
    assert_eq!(redo, "keydown:T1|repaint");
    assert_eq!(string_get(&mut session, &form, "T1Text"), "seed!");

    invoke_sub(&mut session, &form, "T1Undo");
    assert_eq!(string_get(&mut session, &form, "T1Text"), "seed");
    invoke_sub(&mut session, &form, "T1Redo");
    assert_eq!(string_get(&mut session, &form, "T1Text"), "seed!");
}

#[test]
fn textbox_multiline_enter_home_end_and_crlf_delete_are_vba_owned() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);
    set_t1_multiline(&mut session, &form, true);
    set_t1_text(&mut session, &form, "ab");

    let enter = dispatch_key(&mut session, &form, "keydown", KEY_ENTER_TEXTBOX);
    assert_eq!(enter, "keydown:T1|repaint");
    assert_eq!(string_get(&mut session, &form, "T1Text"), "ab\r\n");
    assert_eq!(i32_get(&mut session, &form, "T1SelStart"), 4);

    dispatch_char(&mut session, &form, "cd");
    assert_eq!(string_get(&mut session, &form, "T1Text"), "ab\r\ncd");
    let home = dispatch_key(&mut session, &form, "keydown", KEY_HOME);
    assert_eq!(home, "keydown:T1|repaint");
    assert_eq!(
        i32_get(&mut session, &form, "T1SelStart"),
        4,
        "Home in multiline mode should move to the current logical line start"
    );
    let end = dispatch_key(&mut session, &form, "keydown", KEY_END);
    assert_eq!(end, "keydown:T1|repaint");
    assert_eq!(i32_get(&mut session, &form, "T1SelStart"), 6);

    set_t1_selection(&mut session, &form, 4, 0);
    let backspace = dispatch_key(&mut session, &form, "keydown", KEY_BACKSPACE);
    assert_eq!(backspace, "keydown:T1|repaint");
    assert_eq!(
        string_get(&mut session, &form, "T1Text"),
        "abcd",
        "Backspace at a CRLF boundary should remove the CRLF as one text boundary"
    );
}

#[test]
fn textbox_grapheme_boundaries_keep_surrogates_and_combining_marks_together() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);
    set_t1_text(&mut session, &form, "a\u{301}b");
    dispatch_key(&mut session, &form, "keydown", KEY_HOME);
    let right = dispatch_key(&mut session, &form, "keydown", KEY_RIGHT);
    assert_eq!(right, "keydown:T1|repaint");
    assert_eq!(
        i32_get(&mut session, &form, "T1SelStart"),
        2,
        "Right should skip the base letter plus combining mark as one cluster"
    );
    dispatch_key(&mut session, &form, "keydown", KEY_DELETE);
    assert_eq!(string_get(&mut session, &form, "T1Text"), "a\u{301}");

    set_t1_text(&mut session, &form, "x\u{1f600}y");
    // MSForms positions count UTF-16 units: x + the surrogate pair occupies 3.
    set_t1_selection(&mut session, &form, 3, 0);
    let delete_smile = dispatch_key(&mut session, &form, "keydown", KEY_BACKSPACE);
    assert_eq!(delete_smile, "keydown:T1|repaint");
    assert_eq!(
        string_get(&mut session, &form, "T1Text"),
        "xy",
        "Backspace should delete a UTF-16 surrogate pair as one text boundary"
    );
}

#[test]
fn textbox_composition_preedit_commits_or_cancels_without_leaving_rust_semantics() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTextBoxForm");

    focus_and_clear(&mut session, &form, T1_IN.0, T1_IN.1);
    set_t1_text(&mut session, &form, "pre");
    t1_update_composition(&mut session, &form, "e'");
    assert!(bool_get(&mut session, &form, "T1CompositionActive"));
    assert_eq!(string_get(&mut session, &form, "T1CompositionText"), "e'");
    t1_cancel_composition(&mut session, &form);
    assert!(!bool_get(&mut session, &form, "T1CompositionActive"));
    assert_eq!(string_get(&mut session, &form, "T1Text"), "pre");

    t1_update_composition(&mut session, &form, "e'");
    t1_commit_composition(&mut session, &form, "é");
    assert_eq!(string_get(&mut session, &form, "T1Text"), "preé");
    assert!(!bool_get(&mut session, &form, "T1CompositionActive"));
    assert!(
        string_get(&mut session, &form, "HandlerLog").contains("T1.Change"),
        "committing composition uses the ordinary user-edit Change path"
    );

    set_t1_text(&mut session, &form, "abXYcd");
    set_t1_selection(&mut session, &form, 2, 2);
    t1_update_composition(&mut session, &form, "zz");
    set_t1_selection(&mut session, &form, 6, 0);
    t1_commit_composition(&mut session, &form, "Ω");
    assert_eq!(
        string_get(&mut session, &form, "T1Text"),
        "abΩcd",
        "composition commit replaces the selection captured at BeginComposition"
    );
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
const LIST_RED_IN: (i32, i32) = (42, 28);
const LIST_GREEN_IN: (i32, i32) = (42, 42);
const FRAME_INNER_IN: (i32, i32) = (42, 62);
const FRAME_CLIPPED_VISIBLE_IN: (i32, i32) = (42, 98);
const FRAME_CLIPPED_OUTSIDE_CLIENT_IN: (i32, i32) = (42, 106);
const KEY_ENTER: i16 = 13;
const KEY_ESCAPE: i16 = 27;
const KEY_SPACE: i16 = 32;
const KEY_G: i16 = 71;
const KEY_DOWN: i16 = 40;
const KEY_UP_ARROW: i16 = 38;
const SHIFT_ALT: i16 = 4;

#[test]
fn listbox_object_model_and_capability_descriptor_live_on_the_vba_control() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerListBoxForm");

    assert_eq!(i32_get(&mut session, &form, "ListCount"), 3);
    assert_eq!(string_get(&mut session, &form, "FirstItem"), "Red");
    assert_eq!(i32_get(&mut session, &form, "ListIndex"), -1);
    assert_eq!(string_get(&mut session, &form, "ListValue"), "");

    invoke_sub(&mut session, &form, "SelectBlueProgrammatically");
    assert_eq!(i32_get(&mut session, &form, "ListIndex"), 2);
    assert_eq!(string_get(&mut session, &form, "ListValue"), "Blue");
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog"),
        "",
        "programmatic ListIndex assignment should not raise Change"
    );

    let catalog = string_get(&mut session, &form, "CapabilityCatalog");
    assert!(
        catalog.contains("Choices:kind=ListBox;focusable=True;tabstop=True;click=True;pressed=False;text=False;paste=False;value=True;toggle=False;accelerator=False;default=False;cancel=False;cursor=0"),
        "ListBox descriptor missing expected routing policy:\n{catalog}"
    );
}

#[test]
fn listbox_mouse_click_selects_a_row_and_renders_selection() {
    let (mut session, surface) = prepare_session();
    let form = build_form(&mut session, "ReducerListBoxForm");

    let down = dispatch(
        &mut session,
        &form,
        "mousedown",
        LIST_GREEN_IN.0,
        LIST_GREEN_IN.1,
    );
    assert_eq!(down, "enter:Choices|mousedown:Choices|repaint");
    let up = dispatch(
        &mut session,
        &form,
        "mouseup",
        LIST_GREEN_IN.0,
        LIST_GREEN_IN.1,
    );
    assert_eq!(up, "mouseup:Choices|click:Choices|repaint");

    assert_eq!(i32_get(&mut session, &form, "ListIndex"), 1);
    assert_eq!(string_get(&mut session, &form, "ListValue"), "Green");
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec![
            "Choices.Enter",
            "Choices.MouseDown",
            "Choices.Change:Green",
            "Choices.MouseUp",
            "Choices.Click:Green",
        ],
        "mouse selection should raise Enter, MouseDown, Change, MouseUp, Click in order"
    );

    let snapshot = surface.snapshot().expect("surface snapshot");
    let scene = snapshot.scene.expect("scene snapshot");
    let list = scene.get(NodeId(1)).expect("list scene node");
    assert!(
        fill_rect_with_color(&list.prims, TEXT_SELECTION_COLOR).is_some(),
        "selected row should paint through the ThemePainter selection color"
    );
}

#[test]
fn listbox_keyboard_focus_and_accessibility_rows_are_exposed() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerListBoxForm");

    dispatch(
        &mut session,
        &form,
        "mousedown",
        LIST_RED_IN.0,
        LIST_RED_IN.1,
    );
    dispatch(&mut session, &form, "mouseup", LIST_RED_IN.0, LIST_RED_IN.1);
    invoke_sub(&mut session, &form, "ClearLog");

    let down = dispatch_key(&mut session, &form, "keydown", KEY_DOWN);
    assert_eq!(down, "keydown:Choices|repaint");
    assert_eq!(i32_get(&mut session, &form, "ListIndex"), 1);
    assert_eq!(string_get(&mut session, &form, "ListValue"), "Green");

    let up = dispatch_key(&mut session, &form, "keydown", KEY_UP_ARROW);
    assert_eq!(up, "keydown:Choices|repaint");
    assert_eq!(i32_get(&mut session, &form, "ListIndex"), 0);
    assert_eq!(string_get(&mut session, &form, "ListValue"), "Red");

    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec![
            "Choices.KeyDown:40",
            "Choices.Change:Green",
            "Choices.KeyDown:38",
            "Choices.Change:Red",
        ],
        "keyboard navigation should raise KeyDown before each default selection Change"
    );

    let accessibility = string_get(&mut session, &form, "AccessibilitySnapshot");
    assert!(
        accessibility.contains("role=listbox;name=Choices;value=Red")
            && accessibility.contains(";selected=True;sel_start=0;sel_length=1;sel_text=Red")
            && accessibility.contains(";patterns=selection,value;row_count=3;column_count=1"),
        "ListBox accessibility snapshot should expose selection and row count:\n{accessibility}"
    );

    invoke_sub(&mut session, &form, "ClearLog");
    let tab = dispatch_key(&mut session, &form, "keydown", KEY_TAB);
    assert_eq!(
        tab,
        "keydown:Choices|beforeupdate:Choices|afterupdate:Choices|exit:Choices|enter:Field|repaint"
    );
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec![
            "Choices.KeyDown:9",
            "Choices.BeforeUpdate",
            "Choices.AfterUpdate",
            "Choices.Exit",
            "Field.Enter",
        ],
        "dirty ListBox selection should participate in focus-out validation"
    );

    let form = build_form(&mut session, "ReducerListBoxForm");
    invoke_sub(&mut session, &form, "DisableChoices");
    let miss = dispatch(
        &mut session,
        &form,
        "mousedown",
        LIST_GREEN_IN.0,
        LIST_GREEN_IN.1,
    );
    assert_eq!(
        miss, "",
        "disabled ListBox should not receive mouse focus/input"
    );

    let form = build_form(&mut session, "ReducerListBoxForm");
    invoke_sub(&mut session, &form, "HideChoices");
    let miss = dispatch(
        &mut session,
        &form,
        "mousedown",
        LIST_GREEN_IN.0,
        LIST_GREEN_IN.1,
    );
    assert_eq!(
        miss, "",
        "hidden ListBox should not receive mouse focus/input"
    );
}

#[test]
fn listbox_multiselect_mouse_and_space_toggle_rows() {
    let (mut session, surface) = prepare_session();
    let form = build_form(&mut session, "ReducerListBoxForm");
    invoke_sub(&mut session, &form, "UseMultiSelect");

    dispatch(
        &mut session,
        &form,
        "mousedown",
        LIST_RED_IN.0,
        LIST_RED_IN.1,
    );
    dispatch(&mut session, &form, "mouseup", LIST_RED_IN.0, LIST_RED_IN.1);
    assert_eq!(string_get(&mut session, &form, "SelectedSummary"), "0");

    dispatch_mouse(
        &mut session,
        &form,
        "mousedown",
        LIST_GREEN_IN.0,
        LIST_GREEN_IN.1,
        1,
        SHIFT_CTRL,
    );
    dispatch(
        &mut session,
        &form,
        "mouseup",
        LIST_GREEN_IN.0,
        LIST_GREEN_IN.1,
    );
    assert_eq!(string_get(&mut session, &form, "SelectedSummary"), "0,1");
    assert_eq!(i32_get(&mut session, &form, "ListIndex"), 1);

    let key = dispatch_key(&mut session, &form, "keydown", KEY_SPACE);
    assert_eq!(key, "keydown:Choices|repaint");
    assert_eq!(
        string_get(&mut session, &form, "SelectedSummary"),
        "0",
        "Space toggles the focused row in fmMultiSelectMulti"
    );

    let snapshot = surface.snapshot().expect("surface snapshot");
    let scene = snapshot.scene.expect("scene snapshot");
    let list = scene.get(NodeId(1)).expect("list scene node");
    let selected_rects = list
        .prims
        .iter()
        .filter(|prim| {
            matches!(
                prim,
                Prim::FillRect { paint, .. } if solid_color(paint) == Some(TEXT_SELECTION_COLOR)
            )
        })
        .count();
    assert_eq!(
        selected_rects, 1,
        "multi-select render should reflect the selected row set"
    );
}

#[test]
fn listbox_extended_shift_range_and_columns_are_vba_state() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerListBoxForm");

    invoke_sub(&mut session, &form, "ConfigureColumns");
    assert_eq!(string_get(&mut session, &form, "BlueCode"), "B");
    dispatch(
        &mut session,
        &form,
        "mousedown",
        LIST_GREEN_IN.0,
        LIST_GREEN_IN.1,
    );
    dispatch(
        &mut session,
        &form,
        "mouseup",
        LIST_GREEN_IN.0,
        LIST_GREEN_IN.1,
    );
    assert_eq!(
        string_get(&mut session, &form, "ListValue"),
        "G",
        "BoundColumn=2 should make Value read the second column"
    );

    let form = build_form(&mut session, "ReducerListBoxForm");
    invoke_sub(&mut session, &form, "UseExtendedMultiSelect");
    dispatch(
        &mut session,
        &form,
        "mousedown",
        LIST_RED_IN.0,
        LIST_RED_IN.1,
    );
    dispatch(&mut session, &form, "mouseup", LIST_RED_IN.0, LIST_RED_IN.1);
    let range = dispatch_key_shift(&mut session, &form, "keydown", KEY_DOWN, SHIFT_SHIFT);
    assert_eq!(range, "keydown:Choices|repaint");
    assert_eq!(
        string_get(&mut session, &form, "SelectedSummary"),
        "0,1",
        "Shift+Down should extend selection from the anchor"
    );

    let accessibility = string_get(&mut session, &form, "AccessibilitySnapshot");
    assert!(
        accessibility.contains(";sel_start=1;sel_length=2;sel_text=Red|Green")
            && accessibility.contains(";row_count=3;column_count=1"),
        "extended ListBox accessibility should expose selected count/text:\n{accessibility}"
    );
}

// The ComboBox fixture control is at (20,20,120,22); the drop button is the
// rightmost 18 points, so x=132 hits the button.
const COMBO_BUTTON_IN: (i32, i32) = (132, 31);

#[test]
fn combobox_object_model_dropdown_keyboard_and_paste_are_live() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerComboBoxForm");

    let diagnostics = string_get(&mut session, &form, "ComboDiagnostics");
    assert!(
        diagnostics.contains("count=3;index=0;text=Red;value=Red;dropdown=False")
            && diagnostics.contains("rows=Red|Green|Blue")
            && diagnostics.contains("capabilities=kind=ComboBox;focusable=True;tabstop=True;click=True;pressed=False;text=True;paste=True;value=True"),
        "ComboBox diagnostics should expose edit/list/dropdown state and routing policy: {diagnostics}"
    );

    dispatch(
        &mut session,
        &form,
        "mousedown",
        COMBO_BUTTON_IN.0,
        COMBO_BUTTON_IN.1,
    );
    dispatch(
        &mut session,
        &form,
        "mouseup",
        COMBO_BUTTON_IN.0,
        COMBO_BUTTON_IN.1,
    );
    assert!(bool_get(&mut session, &form, "ComboDropDownOpen"));
    assert!(
        string_get(&mut session, &form, "HandlerLog").contains("DropButtonClick|Click"),
        "drop button should raise DropButtonClick and the normal click path"
    );

    let down = dispatch_key(&mut session, &form, "keydown", KEY_DOWN);
    assert_eq!(down, "keydown:Choice|repaint");
    assert_eq!(string_get(&mut session, &form, "ComboValue"), "Green");
    assert_eq!(i32_get(&mut session, &form, "ComboListIndex"), 1);

    let close = dispatch_key(&mut session, &form, "keydown", KEY_F4);
    assert_eq!(close, "keydown:Choice|repaint");
    assert!(!bool_get(&mut session, &form, "ComboDropDownOpen"));

    let paste = dispatch_drop(&mut session, &form, "!");
    assert_eq!(paste, "drop:Choice|repaint");
    assert_eq!(string_get(&mut session, &form, "ComboValue"), "Green!");
    assert_eq!(i32_get(&mut session, &form, "ComboListIndex"), -1);

    let accessibility = string_get(&mut session, &form, "AccessibilitySnapshot");
    assert!(
        accessibility.contains("role=combobox;name=Choice;value=Green!")
            && accessibility.contains(";patterns=textbox/list/value,expand-collapse,selection;row_count=3;column_count=1"),
        "ComboBox accessibility should expose editable value, popup/list affordance, and row count:\n{accessibility}"
    );
}

const SPIN_UP_IN: (i32, i32) = (34, 32);
const SPIN_DOWN_IN: (i32, i32) = (34, 64);

#[test]
fn spinbutton_keyboard_mouse_range_and_accessibility_are_live() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerSpinButtonForm");

    let diagnostics = string_get(&mut session, &form, "SpinDiagnostics");
    assert!(
        diagnostics.contains("value=0;min=-2;max=4;small_change=2;pressed_direction=0")
            && diagnostics.contains("capabilities=kind=SpinButton;focusable=True;tabstop=True;click=False;pressed=True;text=False;paste=False;value=True"),
        "SpinButton diagnostics should expose range, value, repeat state, and routing policy: {diagnostics}"
    );

    let down = dispatch(&mut session, &form, "mousedown", SPIN_UP_IN.0, SPIN_UP_IN.1);
    assert_eq!(down, "enter:Spin|mousedown:Spin|press:Spin|repaint");
    assert_eq!(i32_get(&mut session, &form, "SpinValue"), 2);
    let up = dispatch(&mut session, &form, "mouseup", SPIN_UP_IN.0, SPIN_UP_IN.1);
    assert_eq!(up, "mouseup:Spin|release:Spin|repaint");

    let key_up = dispatch_key(&mut session, &form, "keydown", KEY_UP_ARROW);
    assert_eq!(key_up, "keydown:Spin|repaint");
    assert_eq!(
        i32_get(&mut session, &form, "SpinValue"),
        4,
        "keyboard Up should step by SmallChange and clamp to Max"
    );
    let repeat_at_max = dispatch_key(&mut session, &form, "keydown", KEY_UP_ARROW);
    assert_eq!(
        repeat_at_max, "keydown:Spin",
        "a clamped no-op key turn should raise KeyDown without repaint"
    );
    assert_eq!(i32_get(&mut session, &form, "SpinValue"), 4);

    let key_down = dispatch_key(&mut session, &form, "keydown", KEY_DOWN);
    assert_eq!(key_down, "keydown:Spin|repaint");
    assert_eq!(i32_get(&mut session, &form, "SpinValue"), 2);
    let key_up = dispatch_key(&mut session, &form, "keyup", KEY_DOWN);
    assert_eq!(key_up, "keyup:Spin");

    let mouse_down_half = dispatch(
        &mut session,
        &form,
        "mousedown",
        SPIN_DOWN_IN.0,
        SPIN_DOWN_IN.1,
    );
    assert_eq!(
        mouse_down_half, "mousedown:Spin|press:Spin|repaint",
        "bottom half press should start SpinDown without changing focus"
    );
    assert_eq!(i32_get(&mut session, &form, "SpinValue"), 0);
    dispatch(
        &mut session,
        &form,
        "mouseup",
        SPIN_DOWN_IN.0,
        SPIN_DOWN_IN.1,
    );

    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec![
            "Spin.Enter",
            "Spin.MouseDown",
            "Spin.SpinUp=2",
            "Spin.Change=2",
            "Spin.MouseUp",
            "Spin.KeyDown:38",
            "Spin.SpinUp=4",
            "Spin.Change=4",
            "Spin.KeyDown:38",
            "Spin.KeyDown:40",
            "Spin.SpinDown=2",
            "Spin.Change=2",
            "Spin.KeyUp:40",
            "Spin.MouseDown",
            "Spin.SpinDown=0",
            "Spin.Change=0",
            "Spin.MouseUp",
        ],
        "SpinButton should raise routed keys before keyboard spin events and mouse events before mouse spin events"
    );

    let accessibility = string_get(&mut session, &form, "AccessibilitySnapshot");
    assert!(
        accessibility.contains("role=spinbutton;name=Spin;value=0")
            && accessibility.contains(";patterns=range,value;row_count=0;column_count=0"),
        "SpinButton accessibility should expose range/value semantics:\n{accessibility}"
    );

    let form = build_form(&mut session, "ReducerSpinButtonForm");
    invoke_sub(&mut session, &form, "DisableSpin");
    let disabled = dispatch(&mut session, &form, "mousedown", SPIN_UP_IN.0, SPIN_UP_IN.1);
    assert_eq!(
        disabled, "",
        "disabled SpinButton should not receive pointer input"
    );

    let form = build_form(&mut session, "ReducerSpinButtonForm");
    invoke_sub(&mut session, &form, "HideSpin");
    let hidden = dispatch(&mut session, &form, "mousedown", SPIN_UP_IN.0, SPIN_UP_IN.1);
    assert_eq!(
        hidden, "",
        "hidden SpinButton should not receive pointer input"
    );
}

const SCROLL_LEFT_BUTTON_IN: (i32, i32) = (24, 29);
const SCROLL_RIGHT_BUTTON_IN: (i32, i32) = (174, 29);
const SCROLL_PAGE_RIGHT_IN: (i32, i32) = (126, 29);
const SCROLL_THUMB_DRAG_IN: (i32, i32) = (150, 29);
const TABSTRIP_BETA_IN: (i32, i32) = (90, 30);
const MULTIPAGE_BETA_TAB_IN: (i32, i32) = (150, 30);
const MULTIPAGE_BETA_FIELD_IN: (i32, i32) = (136, 55);

#[test]
fn scrollbar_range_page_thumb_and_events_are_live() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerScrollBarForm");

    let diagnostics = string_get(&mut session, &form, "ScrollDiagnostics");
    assert!(
        diagnostics.contains("value=40;min=0;max=100;small_change=5;large_change=20;pressed_part=")
            && diagnostics.contains("capabilities=kind=ScrollBar;focusable=True;tabstop=True;click=False;pressed=True;text=False;paste=False;value=True"),
        "ScrollBar diagnostics should expose range/value and routing policy: {diagnostics}"
    );

    let right = dispatch(
        &mut session,
        &form,
        "mousedown",
        SCROLL_RIGHT_BUTTON_IN.0,
        SCROLL_RIGHT_BUTTON_IN.1,
    );
    assert_eq!(right, "enter:Amount|mousedown:Amount|press:Amount|repaint");
    assert_eq!(i32_get(&mut session, &form, "ScrollValue"), 45);
    dispatch(
        &mut session,
        &form,
        "mouseup",
        SCROLL_RIGHT_BUTTON_IN.0,
        SCROLL_RIGHT_BUTTON_IN.1,
    );

    let page = dispatch(
        &mut session,
        &form,
        "mousedown",
        SCROLL_PAGE_RIGHT_IN.0,
        SCROLL_PAGE_RIGHT_IN.1,
    );
    assert_eq!(page, "mousedown:Amount|press:Amount|repaint");
    assert_eq!(i32_get(&mut session, &form, "ScrollValue"), 65);
    dispatch(
        &mut session,
        &form,
        "mouseup",
        SCROLL_PAGE_RIGHT_IN.0,
        SCROLL_PAGE_RIGHT_IN.1,
    );

    let key_left = dispatch_key(&mut session, &form, "keydown", KEY_LEFT);
    assert_eq!(key_left, "keydown:Amount|repaint");
    assert_eq!(i32_get(&mut session, &form, "ScrollValue"), 60);
    let key_up = dispatch_key(&mut session, &form, "keyup", KEY_LEFT);
    assert_eq!(key_up, "keyup:Amount");

    let end = dispatch_key(&mut session, &form, "keydown", KEY_END);
    assert_eq!(end, "keydown:Amount|repaint");
    assert_eq!(i32_get(&mut session, &form, "ScrollValue"), 100);
    let clamped = dispatch_key(&mut session, &form, "keydown", KEY_END);
    assert_eq!(clamped, "keydown:Amount");

    dispatch(
        &mut session,
        &form,
        "mousedown",
        SCROLL_LEFT_BUTTON_IN.0,
        SCROLL_LEFT_BUTTON_IN.1,
    );
    dispatch(
        &mut session,
        &form,
        "mouseup",
        SCROLL_LEFT_BUTTON_IN.0,
        SCROLL_LEFT_BUTTON_IN.1,
    );
    assert_eq!(i32_get(&mut session, &form, "ScrollValue"), 95);

    dispatch(
        &mut session,
        &form,
        "mousedown",
        SCROLL_THUMB_DRAG_IN.0,
        SCROLL_THUMB_DRAG_IN.1,
    );
    let dragged = dispatch(
        &mut session,
        &form,
        "mousemove",
        SCROLL_LEFT_BUTTON_IN.0,
        SCROLL_LEFT_BUTTON_IN.1,
    );
    assert_eq!(dragged, "mousemove:Amount|repaint");
    assert!(
        i32_get(&mut session, &form, "ScrollValue") < 95,
        "thumb drag should set value from pointer position"
    );
    dispatch(
        &mut session,
        &form,
        "mouseup",
        SCROLL_LEFT_BUTTON_IN.0,
        SCROLL_LEFT_BUTTON_IN.1,
    );

    let log = string_get(&mut session, &form, "HandlerLog");
    for expected in [
        "Scroll.Enter",
        "Scroll.MouseDown",
        "Scroll.Scroll=45",
        "Scroll.Change=45",
        "Scroll.Scroll=65",
        "Scroll.Change=65",
        "Scroll.KeyDown:37",
        "Scroll.Scroll=60",
        "Scroll.Change=60",
        "Scroll.KeyUp:37",
        "Scroll.KeyDown:35",
        "Scroll.Scroll=100",
        "Scroll.Change=100",
    ] {
        assert!(
            log.lines().any(|line| line == expected),
            "ScrollBar log missing {expected:?}; log was:\n{log}"
        );
    }

    let accessibility = string_get(&mut session, &form, "AccessibilitySnapshot");
    assert!(
        accessibility.contains("role=scrollbar;name=Amount;")
            && accessibility.contains(";patterns=range,value;row_count=0;column_count=0"),
        "ScrollBar accessibility should expose range/value semantics:\n{accessibility}"
    );

    let form = build_form(&mut session, "ReducerScrollBarForm");
    invoke_sub(&mut session, &form, "DisableScroll");
    assert_eq!(
        dispatch(
            &mut session,
            &form,
            "mousedown",
            SCROLL_RIGHT_BUTTON_IN.0,
            SCROLL_RIGHT_BUTTON_IN.1,
        ),
        "",
        "disabled ScrollBar should not receive pointer input"
    );

    let form = build_form(&mut session, "ReducerScrollBarForm");
    invoke_sub(&mut session, &form, "HideScroll");
    assert_eq!(
        dispatch(
            &mut session,
            &form,
            "mousedown",
            SCROLL_RIGHT_BUTTON_IN.0,
            SCROLL_RIGHT_BUTTON_IN.1,
        ),
        "",
        "hidden ScrollBar should not receive pointer input"
    );
}

#[test]
fn tabstrip_tabs_collection_selection_and_events_are_live() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerTabStripForm");

    assert_eq!(i32_get(&mut session, &form, "TabCount"), 3);
    assert_eq!(string_get(&mut session, &form, "FirstCaption"), "Alpha");
    let diagnostics = string_get(&mut session, &form, "TabDiagnostics");
    assert!(
        diagnostics.contains("count=3;value=0;caption=Alpha;tabs=Alpha|Beta|Gamma")
            && diagnostics.contains("capabilities=kind=TabStrip;focusable=True;tabstop=True;click=False;pressed=False;text=False;paste=False;value=True"),
        "TabStrip diagnostics should expose tabs, selection, and routing policy: {diagnostics}"
    );

    let down = dispatch(
        &mut session,
        &form,
        "mousedown",
        TABSTRIP_BETA_IN.0,
        TABSTRIP_BETA_IN.1,
    );
    assert_eq!(down, "enter:Pages|mousedown:Pages|repaint");
    dispatch(
        &mut session,
        &form,
        "mouseup",
        TABSTRIP_BETA_IN.0,
        TABSTRIP_BETA_IN.1,
    );
    assert_eq!(i32_get(&mut session, &form, "TabValue"), 1);
    assert_eq!(string_get(&mut session, &form, "TabCaption"), "Beta");
    assert!(bool_get(&mut session, &form, "SecondSelected"));

    let right = dispatch_key(&mut session, &form, "keydown", KEY_RIGHT);
    assert_eq!(right, "keydown:Pages|repaint");
    assert_eq!(i32_get(&mut session, &form, "TabValue"), 2);
    let key_up = dispatch_key(&mut session, &form, "keyup", KEY_RIGHT);
    assert_eq!(key_up, "keyup:Pages");

    let log = string_get(&mut session, &form, "HandlerLog");
    for expected in [
        "TabStrip.Enter",
        "TabStrip.MouseDown:70,10",
        "TabStrip.Change=1:Beta",
        "TabStrip.MouseUp",
        "TabStrip.KeyDown:39",
        "TabStrip.Change=2:Gamma",
        "TabStrip.KeyUp:39",
    ] {
        assert!(
            log.lines().any(|line| line == expected),
            "TabStrip log missing {expected:?}; log was:\n{log}"
        );
    }

    let accessibility = string_get(&mut session, &form, "AccessibilitySnapshot");
    assert!(
        accessibility.contains("role=tabstrip;name=Pages;value=Gamma")
            && accessibility.contains(";selected=True;sel_start=2;sel_length=1;sel_text=Gamma;patterns=selection,value;row_count=3;column_count=1"),
        "TabStrip accessibility should expose selected tab semantics:\n{accessibility}"
    );

    let form = build_form(&mut session, "ReducerTabStripForm");
    invoke_sub(&mut session, &form, "DisableTabs");
    assert_eq!(
        dispatch(
            &mut session,
            &form,
            "mousedown",
            TABSTRIP_BETA_IN.0,
            TABSTRIP_BETA_IN.1,
        ),
        "",
        "disabled TabStrip should not receive pointer input"
    );

    let form = build_form(&mut session, "ReducerTabStripForm");
    invoke_sub(&mut session, &form, "HideTabs");
    assert_eq!(
        dispatch(
            &mut session,
            &form,
            "mousedown",
            TABSTRIP_BETA_IN.0,
            TABSTRIP_BETA_IN.1,
        ),
        "",
        "hidden TabStrip should not receive pointer input"
    );
}

#[test]
fn multipage_pages_own_child_trees_selection_focus_scope_and_events() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerMultiPageForm");

    assert_eq!(i32_get(&mut session, &form, "PageCount"), 2);
    assert_eq!(string_get(&mut session, &form, "FirstCaption"), "Alpha");
    let diagnostics = string_get(&mut session, &form, "MultiPageDiagnostics");
    assert!(
        diagnostics.contains("count=2;value=0;caption=Alpha;pages=Alpha|Beta;selected_children=1")
            && diagnostics.contains("capabilities=kind=MultiPage;focusable=True;tabstop=True;click=False;pressed=False;text=False;paste=False;value=True"),
        "MultiPage diagnostics should expose pages, selection, and routing policy: {diagnostics}"
    );
    assert!(
        string_get(&mut session, &form, "SelectedPageDiagnostics")
            .contains("index=0;caption=Alpha;selected=True;children=1"),
        "selected Page diagnostics should expose page-local children"
    );

    let inactive_hit = dispatch(
        &mut session,
        &form,
        "mousedown",
        MULTIPAGE_BETA_FIELD_IN.0,
        MULTIPAGE_BETA_FIELD_IN.1,
    );
    assert!(
        !inactive_hit.contains("BetaField"),
        "inactive page child should not receive pointer input: {inactive_hit}"
    );

    let down = dispatch(
        &mut session,
        &form,
        "mousedown",
        MULTIPAGE_BETA_TAB_IN.0,
        MULTIPAGE_BETA_TAB_IN.1,
    );
    assert_eq!(down, "enter:WizardPages|mousedown:WizardPages|repaint");
    dispatch(
        &mut session,
        &form,
        "mouseup",
        MULTIPAGE_BETA_TAB_IN.0,
        MULTIPAGE_BETA_TAB_IN.1,
    );
    assert_eq!(i32_get(&mut session, &form, "PageValue"), 1);
    assert_eq!(string_get(&mut session, &form, "PageCaption"), "Beta");
    assert!(bool_get(&mut session, &form, "SecondSelected"));

    let beta_down = dispatch(
        &mut session,
        &form,
        "mousedown",
        MULTIPAGE_BETA_FIELD_IN.0,
        MULTIPAGE_BETA_FIELD_IN.1,
    );
    assert!(
        beta_down.contains("enter:BetaField") && beta_down.contains("mousedown:BetaField"),
        "selected page child should receive pointer input after switch: {beta_down}"
    );
    dispatch_char(&mut session, &form, "!");
    assert_eq!(string_get(&mut session, &form, "BetaText"), "!beta");
    assert_eq!(string_get(&mut session, &form, "AlphaText"), "alpha");

    let log = string_get(&mut session, &form, "HandlerLog");
    for expected in [
        "MultiPage.Enter",
        "MultiPage.MouseDown:130,10",
        "MultiPage.Change=1:Beta",
        "MultiPage.MouseUp",
        "MultiPage.Exit",
        "BetaField.Enter",
        "BetaField.Change=!beta",
    ] {
        assert!(
            log.lines().any(|line| line == expected),
            "MultiPage log missing {expected:?}; log was:\n{log}"
        );
    }

    let accessibility = string_get(&mut session, &form, "AccessibilitySnapshot");
    assert!(
        accessibility.contains("role=multipage;name=WizardPages;value=Beta")
            && accessibility.contains(";selected=True;sel_start=1;sel_length=1;sel_text=Beta;patterns=selection,container,value;row_count=2;column_count=1")
            && accessibility.contains("role=textbox;name=AlphaField;value=alpha;enabled=True;visible=False")
            && accessibility.contains("role=page;name=WizardPages.Page1;value=Beta;enabled=True;visible=True")
            && accessibility.contains("role=textbox;name=BetaField;value=!beta"),
        "MultiPage accessibility should expose selected page and selected child tree:\n{accessibility}"
    );

    let index = string_get(&mut session, &form, "InteractionIndexSummary");
    assert!(
        index.contains("first=WizardPages")
            && index.contains("last=BetaField")
            && !index.contains("last=AlphaField"),
        "interaction index should scope tab traversal to the selected page: {index}"
    );
}

#[test]
fn frame_owns_nested_controls_and_renders_a_parented_scene_subtree() {
    let (mut session, surface) = prepare_session();
    let form = build_form(&mut session, "ReducerFrameForm");

    assert_eq!(i32_get(&mut session, &form, "RootControlCount"), 2);
    assert_eq!(i32_get(&mut session, &form, "FrameChildCount"), 3);
    let diagnostics = string_get(&mut session, &form, "FrameDiagnostics");
    assert!(
        diagnostics.contains("caption=Group;children=3")
            && diagnostics
                .contains(";client_left=26;client_top=38;client_width=168;client_height=66;")
            && diagnostics.contains("capabilities=kind=Frame"),
        "Frame diagnostics should expose container state: {diagnostics}"
    );

    let snapshot = surface.snapshot().expect("surface snapshot");
    let scene = snapshot.scene.expect("scene snapshot");
    let root = scene.get(NodeId(0)).expect("root node");
    assert!(
        root.children.contains(&NodeId(1)) && root.children.contains(&NodeId(2)),
        "root should contain the Frame and the outside TextBox"
    );
    let frame = scene.get(NodeId(1)).expect("frame node");
    assert_eq!(
        frame.children,
        vec![NodeId(1001), NodeId(1002), NodeId(1003)]
    );
    assert_rect_close(
        frame.clip.expect("Frame child clip"),
        RectF::new(26.0, 38.0, 168.0, 66.0),
        "Frame scene clip should expose the child client rectangle",
    );
    let inner = scene.get(NodeId(1001)).expect("inner TextBox node");
    assert_eq!(inner.parent, Some(NodeId(1)));
    assert_rect_close(
        inner.bounds,
        RectF::new(36.0, 56.0, 90.0, 20.0),
        "inner TextBox absolute bounds should derive from Frame client offset",
    );
}

#[test]
fn frame_routes_hit_testing_tab_focus_and_accessibility_recursively() {
    let (mut session, surface) = prepare_session();
    let form = build_form(&mut session, "ReducerFrameForm");

    let down = dispatch(
        &mut session,
        &form,
        "mousedown",
        FRAME_INNER_IN.0,
        FRAME_INNER_IN.1,
    );
    assert_eq!(down, "enter:InnerField|mousedown:InnerField|repaint");
    dispatch(
        &mut session,
        &form,
        "mouseup",
        FRAME_INNER_IN.0,
        FRAME_INNER_IN.1,
    );
    assert_eq!(string_get(&mut session, &form, "FocusName"), "InnerField");
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec!["Inner.Enter", "Inner.MouseDown:6,6", "Inner.MouseUp:6,6"],
        "mouse coordinates should arrive in child-local Frame coordinates"
    );

    invoke_sub(&mut session, &form, "ClearLog");
    dispatch_char(&mut session, &form, "x");
    assert_eq!(string_get(&mut session, &form, "InnerText"), "x");
    let tab = dispatch_key(&mut session, &form, "keydown", KEY_TAB);
    assert_eq!(
        tab,
        "keydown:InnerField|beforeupdate:InnerField|afterupdate:InnerField|exit:InnerField|enter:InnerButton|repaint"
    );
    let tab = dispatch_key(&mut session, &form, "keydown", KEY_TAB);
    assert_eq!(
        tab,
        "keydown:InnerButton|exit:InnerButton|enter:OuterField|repaint"
    );

    invoke_sub(&mut session, &form, "ClearLog");
    let clipped_down = dispatch(
        &mut session,
        &form,
        "mousedown",
        FRAME_CLIPPED_VISIBLE_IN.0,
        FRAME_CLIPPED_VISIBLE_IN.1,
    );
    assert_eq!(
        clipped_down,
        "exit:OuterField|enter:ClippedField|mousedown:ClippedField|repaint"
    );
    dispatch(
        &mut session,
        &form,
        "mouseup",
        FRAME_CLIPPED_VISIBLE_IN.0,
        FRAME_CLIPPED_VISIBLE_IN.1,
    );
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog")
            .lines()
            .collect::<Vec<_>>(),
        vec![
            "Clipped.Enter",
            "Clipped.MouseDown:6,5",
            "Clipped.MouseUp:6,5"
        ],
        "Frame should route inside-client child hits to the clipped child"
    );

    invoke_sub(&mut session, &form, "ClearLog");
    let clipped_outside = dispatch(
        &mut session,
        &form,
        "mousedown",
        FRAME_CLIPPED_OUTSIDE_CLIENT_IN.0,
        FRAME_CLIPPED_OUTSIDE_CLIENT_IN.1,
    );
    assert_eq!(
        clipped_outside, "mousedown:Group",
        "child raw bounds outside the Frame client clip should not receive input"
    );
    assert_eq!(
        string_get(&mut session, &form, "HandlerLog"),
        "",
        "clipped-away child should not receive mouse events"
    );

    let index = string_get(&mut session, &form, "InteractionIndexSummary");
    assert!(
        index.contains(";first=InnerField;last=ClippedField;"),
        "tab map should include nested participants in tree order: {index}"
    );
    let accessibility = string_get(&mut session, &form, "AccessibilitySnapshot");
    assert!(
        accessibility.contains("role=group;name=Group;value=Group")
            && accessibility.contains("role=textbox;name=InnerField;value=x")
            && accessibility.contains("role=button;name=InnerButton;value=Inside")
            && accessibility.contains("role=textbox;name=ClippedField;value=clip"),
        "accessibility snapshot should walk Frame children:\n{accessibility}"
    );

    invoke_sub(&mut session, &form, "RemoveInnerButton");
    assert_eq!(i32_get(&mut session, &form, "FrameChildCount"), 2);
    invoke_sub(&mut session, &form, "Render");
    let snapshot = surface.snapshot().expect("surface snapshot");
    let scene = snapshot.scene.expect("scene snapshot");
    let frame = scene.get(NodeId(1)).expect("frame node after removal");
    assert_eq!(
        frame.children,
        vec![NodeId(1001), NodeId(1003)],
        "Frame repaint should drop the removed child from the parent child list"
    );
    assert!(
        scene.get(NodeId(1002)).is_none(),
        "container structural mutation should rebuild the retained scene so removed child nodes do not linger"
    );
}

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
fn object_model_add_remove_and_name_lookup_drive_structural_state() {
    let (mut session, surface) = prepare_session();
    let form = build_form(&mut session, "ReducerButtonsForm");

    assert_eq!(i32_get(&mut session, &form, "ControlCount"), 5);
    assert!(
        !bool_get(&mut session, &form, "HasLate"),
        "Late does not exist before runtime add"
    );

    invoke_sub(&mut session, &form, "AddLateTextBox");
    assert_eq!(i32_get(&mut session, &form, "ControlCount"), 6);
    assert!(
        bool_get(&mut session, &form, "HasLate"),
        "runtime Controls.Add should update name lookup"
    );
    invoke_sub(&mut session, &form, "Render");
    assert!(
        scene_has_node(&surface, NodeId(6)),
        "a post-first-render Controls.Add should force a structural render that includes the new node"
    );

    invoke_sub(&mut session, &form, "RemoveLateTextBox");
    assert_eq!(i32_get(&mut session, &form, "ControlCount"), 5);
    assert!(
        !bool_get(&mut session, &form, "HasLate"),
        "Controls.Remove should update name lookup"
    );
    invoke_sub(&mut session, &form, "Render");
    assert!(
        !scene_has_node(&surface, NodeId(6)),
        "Controls.Remove should force a structural render that drops the retained node"
    );

    invoke_sub(&mut session, &form, "RenameFieldToRenamed");
    assert_eq!(
        string_get(&mut session, &form, "RenamedFieldLookupName"),
        "RenamedField",
        "runtime ControlByName lookup should use the live Core.Name, not only the original Add key"
    );
    assert_eq!(
        string_get(&mut session, &form, "RenamedFieldItemName"),
        "RenamedField",
        "public Controls.Item(name) lookup should use the live Core.Name too"
    );
}

#[test]
fn focused_hide_disable_and_remove_clear_stale_interaction_state() {
    let (mut session, _surface) = prepare_session();
    let form = build_form(&mut session, "ReducerButtonsForm");

    focus_and_clear(&mut session, &form, FIELD_IN.0, FIELD_IN.1);
    assert_eq!(string_get(&mut session, &form, "FocusName"), "Field");
    invoke_sub(&mut session, &form, "HideFocusedField");
    let state = string_get(&mut session, &form, "InteractionStateSummary");
    assert!(
        state.contains("focus=;capture=;pressed=;hover=;cursor_target=;cursor=0"),
        "hiding the focused field should clear stale focus and pointer state: {state}"
    );
    assert_eq!(
        dispatch_char(&mut session, &form, "x"),
        "",
        "typing after focused hide should not dispatch to the hidden control"
    );

    let form = build_form(&mut session, "ReducerButtonsForm");
    focus_and_clear(&mut session, &form, FIELD_IN.0, FIELD_IN.1);
    invoke_sub(&mut session, &form, "DisableFocusedField");
    let state = string_get(&mut session, &form, "InteractionStateSummary");
    assert!(
        state.contains("focus=;capture=;pressed=;hover=;cursor_target=;cursor=0"),
        "disabling the focused field should clear stale focus and pointer state: {state}"
    );
    assert_eq!(
        dispatch_key(&mut session, &form, "keydown", KEY_SPACE),
        "",
        "keyboard dispatch after focused disable should not reach the disabled control"
    );

    let form = build_form(&mut session, "ReducerButtonsForm");
    focus_and_clear(&mut session, &form, FIELD_IN.0, FIELD_IN.1);
    invoke_sub(&mut session, &form, "RemoveFocusedField");
    assert!(
        !bool_get(&mut session, &form, "HasField"),
        "Controls.Remove should remove the focused control from name lookup"
    );
    let state = string_get(&mut session, &form, "InteractionStateSummary");
    assert!(
        state.contains("focus=;capture=;pressed=;hover=;cursor_target=;cursor=0"),
        "removing the focused field should clear stale focus and pointer state: {state}"
    );
    let summary = string_get(&mut session, &form, "InteractionIndexSummary");
    assert!(
        summary.contains(";first=Ok;last=Chk;default=Ok;cancel=CancelBtn;"),
        "the tab map should rebuild without the removed field: {summary}"
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
