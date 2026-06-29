//! oxforms-esq.3 — live-MSForms oracle captures as conformance assertions on the
//! OxForms runtime's dispatched FM20 event orderings.
//!
//! Each committed oracle capture is turned into EITHER a passing conformance test
//! that CITES its source capture path (the runtime already produces the ordering),
//! OR a precise `#[ignore = "GAP: … — pending oxforms-esq.N"]` test that encodes the
//! full oracle ordering as an executable spec the runtime cannot yet satisfy.
//! Un-ignoring a gap test when its bead lands is the proof that the bead closed the
//! gap.
//!
//! Per AC2 we never over-claim parity beyond a capture's rows: absent rows are not
//! treated as negative facts. A PIN asserts only the subsequence of the oracle the
//! runtime is responsible for at this bead; a GAP encodes the full oracle ordering (or
//! its load-bearing invariant, e.g. focus retention) so it stays red until the missing
//! behavior is genuinely produced.
//!
//! Two drive paths are used, matching the two model harnesses in this crate:
//!   * The W007 [`RuntimeRunner`] (oxvba_w007_runtime_runner.rs): events are reduced
//!     and the resulting `FireVbaEvent` effects are dispatched through the controls'
//!     **native** OxVba Perform* members; assertions read `RuntimeStep::native_dispatches`.
//!     This is the closest thing to "the runtime as shipped", so it is preferred.
//!   * The `oxforms-core` [`reduce`] reducer directly (oxvba_w005_event_dispatch_smoke.rs
//!     style): for controls/origins the W007 probe form cannot reach (it has no CheckBox,
//!     and its paste path is gated to drag-drop origin), assertions read the ordered
//!     `FireVbaEvent` event names the reducer emits. This is what the runtime *would*
//!     dispatch natively for those controls; it is the same effect stream the native
//!     path consumes.

use std::path::{Path, PathBuf};

use oxforms_core::{
    materialize_w007_demo_form, reduce, ControlNode, EffectKind, EffectRequest, FocusTarget,
    FormState,
};
use oxforms_oxvba_adapter::runtime_runner::{RuntimeRunner, RuntimeStep};
use oxforms_pal::{
    CharacterInputEvent, ClickCount, ControlId, CoordinatePayload, DataObjectSnapshot,
    DropOrPasteEvent, DropOrPasteOrigin, FocusValidationCompletedEvent, FormId, KeyCode, KeyEvent,
    KeyRepeat, KeyboardModifiers, LogicalPoint, LogicalRect, MouseButton, MouseButtonEvent,
    MouseButtons, PointerId, RawKeyDiagnostics, ServicePayload, ServiceRequestId, UiEvent,
    UiEventId, UiEventKind, UiEventSource,
};

use oxvba_bundle::BundlePackage;
use oxvba_hal::model::HostPolicy;
use oxvba_host::{Engine, HostConfig, ProjectRuntimeSession};
use oxvba_symbol::manifest::{
    ModuleAttributes, ModuleKind, ModuleUnit, ProjectKind, SymbolProjectManifest,
};

// ---------------------------------------------------------------------------
// Capture paths (the ground-truth oracle each test cites).
// ---------------------------------------------------------------------------

const CAP_KEY_MUTATION: &str =
    "docs/evidence/W008_native_event_breadth/captures/w008-key-mutation-20260627T220715Z/\
     w008-key-mutation-event-log.csv";
const CAP_FOCUS_VALIDATION: &str =
    "docs/evidence/W008_native_event_breadth/captures/w008-focus-validation-20260627T223020Z/\
     w008-focus-validation-event-log.csv";
const CAP_CTRLV: &str = "docs/evidence/W006_control_implementation_rollout/captures/\
     ctrlv-keyboard-ordering-20260627T222310Z/ctrlv-keyboard-ordering-event-log.csv";
const CAP_CHECKBOX_KBD: &str = "docs/evidence/W006_control_implementation_rollout/captures/\
     checkbox-keyboard-toggle-20260627T220935Z/checkbox-keyboard-toggle-event-log.csv";
const CAP_CHECKBOX_CLICK: &str = "docs/evidence/W006_control_implementation_rollout/captures/\
     checkbox-click-change-20260627T162407Z/checkbox-click-change-event-log.csv";

// ---------------------------------------------------------------------------
// W007 RuntimeRunner harness (mirrors oxvba_w007_runtime_runner.rs::prepare_session).
// ---------------------------------------------------------------------------

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

fn prepare_session() -> ProjectRuntimeSession {
    let manifest = SymbolProjectManifest {
        project_name: "OxFormsEsq3Conformance".to_string(),
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
        .expect("bind esq3 conformance project");
    let bundle = oxvba_bundle::linearize(&program).expect("linearize esq3 conformance project");

    let mut engine = Engine::new(HostConfig { enable_jit: false });
    engine.set_host_policy(HostPolicy::interactive_dev());
    engine
        .prepare_bundle_package_session(BundlePackage::single(bundle))
        .expect("prepare esq3 conformance session")
}

fn attach_runner() -> RuntimeRunner {
    let session = prepare_session();
    let runtime_form = materialize_w007_demo_form().expect("materialize W007 demo form");
    RuntimeRunner::attach(
        session,
        runtime_form,
        "W007ObjectModelProbeForm",
        "Build",
        "Form",
    )
    .expect("attach runtime runner to the OxVba session")
}

// ---- W007 event builders -------------------------------------------------

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

fn key_down_event(id: u64, character: &str, virtual_key: u32) -> UiEvent {
    ui_event(
        id,
        UiEventKind::KeyDown(KeyEvent {
            key: KeyCode::Character(character.to_string()),
            modifiers: KeyboardModifiers::default(),
            repeat: KeyRepeat::default(),
            raw: RawKeyDiagnostics {
                virtual_key: Some(virtual_key),
                ..RawKeyDiagnostics::default()
            },
        }),
    )
}

fn key_up_event(id: u64, character: &str, virtual_key: u32) -> UiEvent {
    ui_event(
        id,
        UiEventKind::KeyUp(KeyEvent {
            key: KeyCode::Character(character.to_string()),
            modifiers: KeyboardModifiers::default(),
            repeat: KeyRepeat::default(),
            raw: RawKeyDiagnostics {
                virtual_key: Some(virtual_key),
                ..RawKeyDiagnostics::default()
            },
        }),
    )
}

fn enter_key_event(id: u64, down: bool) -> UiEvent {
    let event = KeyEvent {
        key: KeyCode::Enter,
        modifiers: KeyboardModifiers::default(),
        repeat: KeyRepeat::default(),
        raw: RawKeyDiagnostics {
            virtual_key: Some(13),
            ..RawKeyDiagnostics::default()
        },
    };
    ui_event(
        id,
        if down {
            UiEventKind::KeyDown(event)
        } else {
            UiEventKind::KeyUp(event)
        },
    )
}

/// The four key events of a Ctrl+V chord on the focused control: KeyDown(Ctrl 17),
/// KeyDown(V 86), KeyUp(V 86), KeyUp(Ctrl 17), with Ctrl held through the V press and
/// release (oxforms-esq.9). Drives the keyboard paste path through the runner.
fn ctrl_v_chord() -> [UiEvent; 4] {
    let ctrl_held = KeyboardModifiers {
        control: true,
        ..KeyboardModifiers::default()
    };
    [
        ui_event(
            1,
            UiEventKind::KeyDown(KeyEvent {
                key: KeyCode::Other("Control".to_string()),
                modifiers: ctrl_held,
                repeat: KeyRepeat::default(),
                raw: RawKeyDiagnostics {
                    virtual_key: Some(17),
                    ..RawKeyDiagnostics::default()
                },
            }),
        ),
        ui_event(
            2,
            UiEventKind::KeyDown(KeyEvent {
                key: KeyCode::Character("v".to_string()),
                modifiers: ctrl_held,
                repeat: KeyRepeat::default(),
                raw: RawKeyDiagnostics {
                    virtual_key: Some(86),
                    ..RawKeyDiagnostics::default()
                },
            }),
        ),
        key_up_event(3, "v", 86),
        ui_event(
            4,
            UiEventKind::KeyUp(KeyEvent {
                key: KeyCode::Other("Control".to_string()),
                modifiers: KeyboardModifiers::default(),
                repeat: KeyRepeat::default(),
                raw: RawKeyDiagnostics {
                    virtual_key: Some(17),
                    ..RawKeyDiagnostics::default()
                },
            }),
        ),
    ]
}

/// The runtime's `Exit`-Cancel fold-back, modeled for reduce()-path tests: a focus
/// validation completing uncancelled (or vetoed) for the given form (oxforms-esq.4).
fn focus_validation_completed_event(id: u64, form_id: &str, cancelled: bool) -> UiEvent {
    UiEvent::new(
        UiEventId(id),
        UiEventSource::Service,
        UiEventKind::FocusValidationCompleted(FocusValidationCompletedEvent {
            form_id: FormId::new(form_id),
            cancelled,
            dispatch_diagnostics: Vec::new(),
        }),
    )
}

fn character_input_event(id: u64, text: &str) -> UiEvent {
    ui_event(
        id,
        UiEventKind::CharacterInput(CharacterInputEvent {
            text: text.to_string(),
            modifiers: KeyboardModifiers::default(),
            raw: Vec::new(),
        }),
    )
}

/// Focus the InputField (press + release inside its bounds 12,12,120,18).
fn focus_input_field(runner: &mut RuntimeRunner) {
    runner
        .dispatch(ui_event(
            900,
            UiEventKind::MouseDown(mouse_event(true, 20.0, 18.0)),
        ))
        .expect("press InputField");
    runner
        .dispatch(ui_event(
            901,
            UiEventKind::MouseUp(mouse_event(false, 20.0, 18.0)),
        ))
        .expect("release InputField");
}

/// The ordered list of natively-dispatched FM20 event names in a step.
fn dispatched_event_names(step: &RuntimeStep) -> Vec<String> {
    step.native_dispatches
        .iter()
        .map(|dispatch| dispatch.event_name.clone())
        .collect()
}

// ---- reduce()-path helpers (for controls the W007 form cannot reach) -----

/// The ordered FM20 event names a reducer output emits (`fire_vba_event:Name`
/// effects, in effect order), matching the native dispatch order the runtime would
/// drive for the same control.
fn reduced_event_names(effects: &[EffectRequest]) -> Vec<String> {
    effects
        .iter()
        .filter_map(|effect| match &effect.kind {
            EffectKind::FireVbaEvent { event_name, .. } => Some(event_name.clone()),
            _ => None,
        })
        .collect()
}

fn reduce_mouse(
    state: FormState,
    id: u64,
    down: bool,
    x: f64,
    y: f64,
) -> oxforms_core::ReducerOutput {
    let kind = if down {
        UiEventKind::MouseDown(mouse_event(down, x, y))
    } else {
        UiEventKind::MouseUp(mouse_event(down, x, y))
    };
    reduce(state, ui_event(id, kind))
}

fn reduce_space(state: FormState, id: u64, down: bool) -> oxforms_core::ReducerOutput {
    let event = KeyEvent {
        key: KeyCode::Space,
        modifiers: KeyboardModifiers::default(),
        repeat: KeyRepeat::default(),
        raw: RawKeyDiagnostics::default(),
    };
    let kind = if down {
        UiEventKind::KeyDown(event)
    } else {
        UiEventKind::KeyUp(event)
    };
    reduce(state, ui_event(id, kind))
}

/// A single-CheckBox form, focused, with the value state allocated — the reducer
/// shape behind both checkbox captures.
fn check_box_form() -> FormState {
    let mut state = FormState::new("form-checkbox");
    state.controls = vec![ControlNode::check_box(
        "ToggleCheck",
        LogicalRect::new(0.0, 0.0, 96.0, 18.0),
        0,
        0,
    )];
    state.focus_owner = Some(FocusTarget::Control(ControlId::new("ToggleCheck")));
    state.ensure_check_box(ControlId::new("ToggleCheck"));
    state
}

// ===========================================================================
// PINS — orderings the runtime already produces. Each asserts a subsequence of
// the cited oracle that the runtime is responsible for at this bead (AC2: we do
// not assert absent rows as facts).
// ===========================================================================

/// PIN — char-key mutation ordering KeyDown -> KeyPress -> Change -> KeyUp.
///
/// This pins the EVENT ORDER (value-independent); the test types 'A' and asserts the
/// order, not the KeyAscii value. Oracle: [`CAP_FOCUS_VALIDATION`] rows 3-6 (scenario
/// `tab_transfer` prefix) exhibit the full order for a typed 'a': KeyDown 65 ->
/// KeyPress 97 -> Change "a" -> KeyUp 65. [`CAP_KEY_MUTATION`] rows 18-20 (scenario
/// `change_timing`) additionally show KeyDown 65 -> KeyPress 97 -> KeyUp 65 on a
/// CommandButton (no Change row — a button has no editable value). The
/// runtime emits a typed character as a KeyDown event, a CharacterInput event (which
/// dispatches KeyPress then Change on the focused TextBox), and a KeyUp event. Driven
/// through the W007 runner's native Perform* dispatch, the aggregate native-dispatch
/// order across the three events is exactly KeyDown, KeyPress, Change, KeyUp.
#[test]
fn pin_char_key_mutation_keydown_keypress_change_keyup() {
    let mut runner = attach_runner();
    focus_input_field(&mut runner);

    let mut order = Vec::new();
    order.extend(dispatched_event_names(
        &runner
            .dispatch(key_down_event(1, "A", 65))
            .expect("KeyDown A"),
    ));
    order.extend(dispatched_event_names(
        &runner
            .dispatch(character_input_event(2, "A"))
            .expect("type A"),
    ));
    order.extend(dispatched_event_names(
        &runner.dispatch(key_up_event(3, "A", 65)).expect("KeyUp A"),
    ));

    assert_eq!(
        order,
        vec!["KeyDown", "KeyPress", "Change", "KeyUp"],
        "char-key native dispatch order matches the oracle (see {CAP_KEY_MUTATION} \
         change_timing and {CAP_FOCUS_VALIDATION} tab_transfer prefix)"
    );
}

/// PIN — the runtime records the post-handler swallow readback values verbatim.
///
/// Oracle: [`CAP_KEY_MUTATION`] row 11 (`swallow_keydown`: KeyDown KeyCode 65 -> 0),
/// row 14 (`swallow_keypress`: KeyPress KeyAscii 97 -> 0), and row 18
/// (`change_timing`: KeyDown KeyCode 65 -> 65, un-swallowed). The W007 probe form's
/// handlers swallow Escape (KeyDown/KeyUp KeyCode 27 -> 0) and 'Z' (KeyPress
/// KeyAscii 90 -> 0); the runtime reads the post-handler value back through the
/// MSForms.ReturnInteger helper and records it on the NativeDispatch.
///
/// AC: the readback is RECORDED, not folded back (no suppression yet) — that folding
/// is the esq.4 gap below. This pins only the recorded value. The probe handlers
/// swallow different keys than the oracle (Escape 27->0 / 'Z' 90->0 here vs the
/// oracle's 65->0 / 97->0); the pinned fact is the STRUCTURAL post-handler readback
/// (mutated to 0 when swallowed, unchanged otherwise), not the specific key value.
#[test]
fn pin_key_swallow_readback_values_are_recorded() {
    let mut runner = attach_runner();
    focus_input_field(&mut runner);

    // Swallowed KeyDown (Escape, VK 27) reads back KeyCode 0.
    let escape = runner
        .dispatch(key_down_event(1, "\u{1b}", 27))
        .expect("KeyDown Escape");
    let escape_keydown = escape
        .native_dispatches
        .iter()
        .find(|d| d.event_name == "KeyDown")
        .expect("KeyDown dispatched");
    assert_eq!(
        escape_keydown.returned.as_deref(),
        Some("0"),
        "a swallowed KeyDown records KeyCode 0 (oracle {CAP_KEY_MUTATION} swallow_keydown 65->0)"
    );

    // Un-swallowed KeyDown ('A', VK 65) reads back KeyCode 65 unchanged.
    let letter = runner
        .dispatch(key_down_event(2, "A", 65))
        .expect("KeyDown A");
    let letter_keydown = letter
        .native_dispatches
        .iter()
        .find(|d| d.event_name == "KeyDown")
        .expect("KeyDown dispatched");
    assert_eq!(
        letter_keydown.returned.as_deref(),
        Some("65"),
        "an un-swallowed KeyDown records KeyCode 65 (oracle {CAP_KEY_MUTATION} change_timing 65->65)"
    );

    // Swallowed KeyPress ('Z', KeyAscii 90) reads back KeyAscii 0.
    let zed = runner
        .dispatch(character_input_event(3, "Z"))
        .expect("type Z");
    let zed_keypress = zed
        .native_dispatches
        .iter()
        .find(|d| d.event_name == "KeyPress")
        .expect("KeyPress dispatched");
    assert_eq!(
        zed_keypress.returned.as_deref(),
        Some("0"),
        "a swallowed KeyPress records KeyAscii 0 (oracle {CAP_KEY_MUTATION} swallow_keypress 97->0)"
    );
}

/// PIN — CheckBox mouse toggle ordering MouseUp -> Change -> Click, value-change-first.
///
/// Oracle: [`CAP_CHECKBOX_CLICK`] rows 2-3 (Change True, then Click True — both see
/// the toggled value). Already enforced per oxforms-p41; pinned here to the live
/// capture. The W007 probe form has no CheckBox, so this drives the reducer directly
/// over a single-CheckBox form. A press+release inside the control toggles the value,
/// then queues MouseUp, Change, Click — the same FireVbaEvent stream the runtime would
/// dispatch natively.
///
/// AC2: the cited capture logs only the Change/Click rows (it does not log MouseUp);
/// the runtime additionally emits MouseUp first. The load-bearing oracle fact is
/// Change strictly before Click, both on the toggled value — this asserts the full
/// truthful emission (MouseUp, Change, Click) and verifies the Change-before-Click
/// invariant the capture pins.
#[test]
fn pin_checkbox_mouse_toggle_change_before_click() {
    let down = reduce_mouse(check_box_form(), 1, true, 10.0, 9.0);
    // The press alone does not toggle / Click yet (toggle is on release).
    let up = reduce_mouse(down.state, 2, false, 10.0, 9.0);

    let order = reduced_event_names(&up.effects);
    assert_eq!(
        order,
        vec!["MouseUp", "Change", "Click"],
        "CheckBox mouse toggle fires MouseUp, then Change before Click, both on the \
         toggled value (oracle {CAP_CHECKBOX_CLICK} rows 2-3 pin Change-before-Click)"
    );
    let change = order.iter().position(|name| name == "Change");
    let click = order.iter().position(|name| name == "Click");
    assert!(
        change < click,
        "the oracle's value-change-first fact: Change strictly precedes Click \
         (oracle {CAP_CHECKBOX_CLICK} rows 2-3)"
    );
}

/// PIN — focus gain natively dispatches Enter (oxforms-esq.6). Focusing InputField
/// (None -> InputField) commits focus SYNCHRONOUSLY and dispatches Enter on the gaining
/// control via its native `PerformEnter` member -- the runtime half of the
/// default-button/tab Enter emission proven at the reducer level by
/// [`gap_default_button_enter_transfers_focus`].
///
/// Oracle: the W005 modeless oracle (Enter on the initially-focused control, sequence 2).
/// This pins only that Enter is natively dispatched on the gaining control on the
/// SYNCHRONOUS initial-focus path. The DEFERRED control->control path's Enter-vs-MouseDown
/// ordering is the separate gap [`gap_focus_changing_click_enter_precedes_mousedown`].
#[test]
fn pin_enter_dispatched_on_focus_gain() {
    let mut runner = attach_runner();
    let step = runner
        .dispatch(ui_event(
            900,
            UiEventKind::MouseDown(mouse_event(true, 20.0, 18.0)),
        ))
        .expect("press InputField");
    assert!(
        step.native_dispatches
            .iter()
            .any(|dispatch| dispatch.event_name == "Enter"
                && dispatch.control_id == ControlId::new("InputField")),
        "focusing InputField natively dispatches Enter on it (PerformEnter), got {:?}",
        step.native_dispatches
    );
}

/// PIN — a dirty data control's focus-out natively dispatches BeforeUpdate -> AfterUpdate
/// -> Exit (oxforms-esq.7). Editing InputField marks it dirty; moving focus off it then
/// drives PerformBeforeUpdate, PerformAfterUpdate, and PerformExit in order (the
/// non-vetoing two-stage path, esq.11). The vetoing BeforeUpdate fold-back is asserted
/// end-to-end by oxvba_w007_runtime_runner::runner_honors_before_update_veto_end_to_end.
///
/// Oracle: [`CAP_FOCUS_VALIDATION`] tab_transfer rows 8-10 (BeforeUpdate -> AfterUpdate ->
/// Exit on the edited, leaving control).
#[test]
fn pin_before_after_update_dispatched_on_dirty_focus_out() {
    let mut runner = attach_runner();
    focus_input_field(&mut runner);
    // Edit InputField so its value is dirty (committable).
    runner
        .dispatch(character_input_event(1, "X"))
        .expect("type X into InputField");
    // Move focus off the dirty InputField -> BeforeUpdate -> AfterUpdate -> Exit.
    let moved = runner
        .dispatch(ui_event(
            2,
            UiEventKind::MouseDown(mouse_event(true, 150.0, 20.0)),
        ))
        .expect("press OkButton");
    let order: Vec<&str> = moved
        .native_dispatches
        .iter()
        .map(|dispatch| dispatch.event_name.as_str())
        .filter(|name| matches!(*name, "BeforeUpdate" | "AfterUpdate" | "Exit"))
        .collect();
    assert_eq!(
        order,
        vec!["BeforeUpdate", "AfterUpdate", "Exit"],
        "a dirty focus-out natively dispatches BeforeUpdate -> AfterUpdate -> Exit on the \
         leaving control — oracle {CAP_FOCUS_VALIDATION} tab_transfer rows 8-10"
    );
}

// ===========================================================================
// GAPS — orderings the runtime cannot yet produce. Each encodes the FULL oracle
// ordering and is mapped to the bead that will close it. Un-ignoring the test
// when that bead lands is the proof.
// ===========================================================================

/// GAP — a focus-CHANGING click fires Exit -> Enter -> MouseDown on the gaining control.
/// The W005 modeless oracle fires the gaining control's Enter BEFORE its MouseDown on
/// every focus-changing click (capture sequences 565-567, 626-628, 868-870, 983-985).
/// The runtime emits Exit (in-line) -> MouseDown (in-line) -> Enter (on the esq.4 deferred
/// focus commit, where esq.6's Enter rides), inverting Enter/MouseDown, because the mouse
/// press is not deferred through the focus validation. Driven over the reducer on a
/// non-vetoing form (the W007 InputField_Exit vetoes, which would block the transfer).
///
/// CLOSED by oxforms-esq.10: a focus-changing click defers the mouse press through the
/// Exit validation, so the press replays after the gaining control's Enter on commit.
#[test]
fn gap_focus_changing_click_enter_precedes_mousedown() {
    let mut state = FormState::new("form-click");
    state.controls = vec![
        ControlNode::text_box("TextBox1", LogicalRect::new(0.0, 0.0, 80.0, 18.0), 0, 0),
        ControlNode::text_box("TextBox2", LogicalRect::new(0.0, 24.0, 80.0, 18.0), 1, 1),
    ];
    state.focus_owner = Some(FocusTarget::Control(ControlId::new("TextBox1")));

    let mut order = Vec::new();
    // Click TextBox2 (focus-changing): Exit (TextBox1) and the MouseDown (TextBox2) are
    // emitted in-line; the deferred completion then fires Enter (TextBox2).
    let pressed = reduce_mouse(state, 1, true, 10.0, 30.0);
    order.extend(reduced_event_names(&pressed.effects));
    let committed = reduce(
        pressed.state,
        focus_validation_completed_event(2, "form-click", false),
    );
    order.extend(reduced_event_names(&committed.effects));

    assert_eq!(
        order,
        vec!["Exit", "Enter", "MouseDown"],
        "a focus-changing click must fire Exit (leaver), Enter (enterer), then MouseDown \
         (enterer) — W005 modeless oracle seq 565-567/626-628/868-870/983-985"
    );
}

/// PIN (closed by oxforms-esq.6; was a GAP) — default-button Enter transfers focus:
/// TextBox Exit then OkButton Enter, before the button Click and the KeyUp on the button.
///
/// Oracle: [`CAP_KEY_MUTATION`] rows 3-7 (scenario `default_button_enter`):
///   TextBox1 KeyDown(13) -> TextBox1 Exit -> OkButton Enter -> OkButton Click ->
///   OkButton KeyUp(13).
///
/// Driven through the reducer (not the W007 runner): the W007 probe form's InputField_Exit
/// unconditionally vetoes (see [`gap_exit_veto_keeps_focus`]), which would correctly BLOCK
/// the default-button transfer (a vetoed Exit suppresses the Enter/Click). The oracle
/// capture's TextBox1_Exit does NOT veto, so this exercises the non-vetoing transfer on a
/// reducer form -- the same FireVbaEvent stream the runtime dispatches natively. The Exit
/// veto is folded back by the runtime as `FocusValidationCompleted`, modeled here by the
/// injected uncancelled completion (oxforms-esq.4 channel).
#[test]
fn gap_default_button_enter_transfers_focus() {
    let mut state = FormState::new("form-default-button");
    state.controls = vec![
        ControlNode::text_box("TextBox1", LogicalRect::new(0.0, 0.0, 80.0, 18.0), 0, 0),
        ControlNode::command_button("OkButton", LogicalRect::new(0.0, 24.0, 64.0, 20.0), 0, 1),
    ];
    state.focus_owner = Some(FocusTarget::Control(ControlId::new("TextBox1")));
    state.default_button = Some(ControlId::new("OkButton"));

    let mut order = Vec::new();
    let down = reduce(state, enter_key_event(1, true));
    order.extend(reduced_event_names(&down.effects));
    let committed = reduce(
        down.state,
        focus_validation_completed_event(2, "form-default-button", false),
    );
    order.extend(reduced_event_names(&committed.effects));
    let up = reduce(committed.state, enter_key_event(3, false));
    order.extend(reduced_event_names(&up.effects));

    assert_eq!(
        order,
        vec!["KeyDown", "Exit", "Enter", "Click", "KeyUp"],
        "default-button Enter must fire (on TextBox1) KeyDown, Exit; then (on OkButton) \
         Enter, Click, KeyUp — oracle {CAP_KEY_MUTATION} default_button_enter rows 3-7"
    );
}

/// PIN (closed by oxforms-esq.6 + esq.7; was a GAP) — full Tab focus-out ordering
/// KeyDown -> BeforeUpdate -> AfterUpdate -> Exit -> Enter. esq.7 emits BeforeUpdate then
/// AfterUpdate (on a dirty data control) before the Exit; esq.6's Enter fires on the
/// deferred focus-commit. The test spans the Tab reduce AND the injected (uncancelled)
/// completion (where the commit + Enter land), and edits TextBox1 first so it is dirty
/// (BeforeUpdate/AfterUpdate are gated on a changed value).
///
/// Oracle: [`CAP_FOCUS_VALIDATION`] rows 7-11 (scenario `tab_transfer` after editing):
///   TextBox1 KeyDown(9) -> BeforeUpdate -> AfterUpdate -> Exit -> TextBox2 Enter.
#[test]
fn gap_tab_out_full_focus_ordering() {
    let mut state = FormState::new("form-tab");
    state.controls = vec![
        ControlNode::text_box("TextBox1", LogicalRect::new(0.0, 0.0, 80.0, 18.0), 0, 0),
        ControlNode::text_box("TextBox2", LogicalRect::new(0.0, 24.0, 80.0, 18.0), 1, 1),
    ];
    state.focus_owner = Some(FocusTarget::Control(ControlId::new("TextBox1")));
    // The oracle's tab_transfer is "after editing": mark TextBox1 dirty so the focus-out
    // fires BeforeUpdate/AfterUpdate (they are gated on a committable, changed value).
    state.ensure_text_box(ControlId::new("TextBox1")).dirty = true;

    let mut order = Vec::new();
    // Tab off the dirty TextBox1: stage one fires only KeyDown -> BeforeUpdate, held
    // pending (oxforms-esq.11).
    let tab = reduce(
        state,
        ui_event(
            1,
            UiEventKind::KeyDown(KeyEvent {
                key: KeyCode::Tab,
                modifiers: KeyboardModifiers::default(),
                repeat: KeyRepeat::default(),
                raw: RawKeyDiagnostics::default(),
            }),
        ),
    );
    order.extend(reduced_event_names(&tab.effects));
    // The uncancelled BeforeUpdate completion fires AfterUpdate -> Exit, held pending again.
    let after_before_update = reduce(
        tab.state,
        focus_validation_completed_event(2, "form-tab", false),
    );
    order.extend(reduced_event_names(&after_before_update.effects));
    // The uncancelled Exit completion commits focus to TextBox2 and fires its Enter.
    let committed = reduce(
        after_before_update.state,
        focus_validation_completed_event(3, "form-tab", false),
    );
    order.extend(reduced_event_names(&committed.effects));

    assert_eq!(
        order,
        vec!["KeyDown", "BeforeUpdate", "AfterUpdate", "Exit", "Enter"],
        "Tab commit must fire KeyDown, BeforeUpdate, AfterUpdate, Exit (TextBox1), \
         Enter (TextBox2) — oracle {CAP_FOCUS_VALIDATION} tab_transfer rows 7-11"
    );
}

/// PIN (closed by oxforms-esq.4; was a GAP) — Exit veto keeps focus. When InputField_Exit
/// sets Cancel = True the focus stays on the same control. The runtime now folds the Exit
/// Cancel readback back as `FocusValidationCompleted`: the focus commit was held pending
/// (never committed), so a veto retains focus on the originating control.
///
/// Oracle: [`CAP_FOCUS_VALIDATION`] rows 19-23 (scenario `exit_veto_keeps_focus`):
///   TextBox1 KeyDown(9) -> BeforeUpdate -> AfterUpdate -> Exit (Cancel False->True)
///   -> TextBox1 KeyUp(9). Focus stays on TextBox1 (no TextBox2 Enter). This drives the
/// W007 runner where InputField_Exit vetoes; it asserts the post-veto invariant that
/// focus is retained (the BeforeUpdate/AfterUpdate/Enter ordering remains esq.6 + esq.7).
#[test]
fn gap_exit_veto_keeps_focus() {
    let mut runner = attach_runner();
    // Arm the InputField_Exit veto (off by default since oxforms-esq.11, so the demo flow
    // can click OK); this test exercises the veto path.
    runner
        .invoke_form_sub("ArmExitVeto")
        .expect("arm the InputField_Exit veto");
    focus_input_field(&mut runner);

    // Move focus off InputField -> InputField_Exit vetoes (Cancel = True).
    runner
        .dispatch(ui_event(
            1,
            UiEventKind::MouseDown(mouse_event(true, 150.0, 20.0)),
        ))
        .expect("press OkButton");

    // Per the oracle the veto retains focus on InputField, now honored by the esq.4
    // fold-back (the focus commit was held pending and is abandoned on veto).
    assert_eq!(
        runner.form().state.focus_owner,
        Some(FocusTarget::Control(ControlId::new("InputField"))),
        "a vetoing Exit (Cancel=True) must keep focus on InputField — oracle \
         {CAP_FOCUS_VALIDATION} exit_veto_keeps_focus rows 22-23 (focus_owner stays TextBox1)"
    );
}

/// PIN (closed by oxforms-esq.11; was a GAP) — BeforeUpdate veto suppresses
/// AfterUpdate/Exit/Enter. When BeforeUpdate sets Cancel = True, NO AfterUpdate, Exit, or
/// Enter fires and focus stays on the leaving control; the value stays dirty (uncommitted).
/// The two-stage validation folds the BeforeUpdate Cancel back as the first
/// `FocusValidationCompleted`, which gates AfterUpdate/Exit (here modeled by injecting the
/// vetoing BeforeUpdate-stage completion). A non-vetoing BeforeUpdate instead advances to
/// AfterUpdate -> Exit (see [`gap_tab_out_full_focus_ordering`]).
///
/// Oracle: [`CAP_FOCUS_VALIDATION`] rows 28-30 (scenario `before_update_veto`):
///   TextBox1 KeyDown(9) -> BeforeUpdate (Cancel False->True) -> TextBox1 KeyUp(9).
///   No AfterUpdate, no Exit, no TextBox2 Enter.
#[test]
fn gap_before_update_veto_suppresses_commit() {
    let mut state = FormState::new("form-tab");
    state.controls = vec![
        ControlNode::text_box("TextBox1", LogicalRect::new(0.0, 0.0, 80.0, 18.0), 0, 0),
        ControlNode::text_box("TextBox2", LogicalRect::new(0.0, 24.0, 80.0, 18.0), 1, 1),
    ];
    state.focus_owner = Some(FocusTarget::Control(ControlId::new("TextBox1")));
    // The control must be dirty for BeforeUpdate to fire at all (esq.7 gate).
    state.ensure_text_box(ControlId::new("TextBox1")).dirty = true;

    // Tab off the dirty TextBox1: stage one fires only KeyDown -> BeforeUpdate, held pending.
    let tab = reduce(
        state,
        ui_event(
            1,
            UiEventKind::KeyDown(KeyEvent {
                key: KeyCode::Tab,
                modifiers: KeyboardModifiers::default(),
                repeat: KeyRepeat::default(),
                raw: RawKeyDiagnostics::default(),
            }),
        ),
    );
    assert_eq!(
        reduced_event_names(&tab.effects),
        vec!["KeyDown", "BeforeUpdate"],
        "stage one fires only KeyDown then BeforeUpdate — oracle {CAP_FOCUS_VALIDATION} \
         before_update_veto rows 28-30"
    );

    // The VETOING BeforeUpdate completion (Cancel = True) suppresses everything past it:
    // no AfterUpdate, no Exit, no Enter, and focus stays on TextBox1.
    let vetoed = reduce(
        tab.state,
        focus_validation_completed_event(2, "form-tab", true),
    );
    assert_eq!(
        reduced_event_names(&vetoed.effects),
        Vec::<String>::new(),
        "a vetoing BeforeUpdate suppresses AfterUpdate/Exit/Enter"
    );
    assert_eq!(
        vetoed.state.focus_owner,
        Some(FocusTarget::Control(ControlId::new("TextBox1"))),
        "a vetoing BeforeUpdate keeps focus on TextBox1"
    );
    assert!(
        vetoed.state.validation.pending.is_none(),
        "the validation is resolved (no dangling pending stage)"
    );
    // The value was never committed, so TextBox1 stays dirty (a later focus-out refires
    // BeforeUpdate).
    assert!(
        vetoed
            .state
            .text_boxes
            .iter()
            .any(|entry| entry.control_id == ControlId::new("TextBox1") && entry.dirty),
        "a vetoed BeforeUpdate keeps the value dirty (uncommitted)"
    );
}

/// PIN (closed by oxforms-esq.4; was a GAP) — KeyDown KeyCode swallow suppresses KeyPress.
/// When a KeyDown handler sets KeyCode = 0, the subsequent KeyPress must NOT fire. The
/// runtime folds the swallowed KeyCode (`returned == "0"`, pinned above) back as
/// `KeyDownSwallowed`, which arms the reducer to drop the paired character's
/// KeyPress/Change.
///
/// Oracle: [`CAP_KEY_MUTATION`] rows 11-12 (scenario `swallow_keydown`):
///   KeyDown KeyCode 65 -> 0, then KeyUp 65 — NO KeyPress between them; and rows 16-17
///   (`arrow_swallow`: KeyDown 37 -> 0, KeyUp 37, no KeyPress). Encoded over the W007
/// runner whose InputField_KeyDown swallows Escape (27 -> 0): a swallowed KeyDown
/// followed by the printable character input that would carry the KeyPress must NOT
/// dispatch that KeyPress (nor the resulting Change). The fold-back bridges the otherwise
/// independent KeyDown and CharacterInput events with the swallow linkage.
#[test]
fn gap_keydown_swallow_suppresses_keypress() {
    let mut runner = attach_runner();
    focus_input_field(&mut runner);

    // InputField_KeyDown swallows Escape (KeyCode 27 -> 0; the swallow is recorded —
    // see pin_key_swallow_readback_values_are_recorded). A genuine swallow must drop
    // the KeyPress (and its Change) for the keystroke. We model the keystroke as the
    // swallowed KeyDown followed by the printable character input that carries the
    // KeyPress; once esq.4 folds the swallow back, neither KeyPress nor Change fires.
    // This drives the fold-back MECHANISM end-to-end through the native runner; the
    // realistic flag-lifecycle edges (consume, KeyUp/focus-boundary disarm, insert after)
    // are covered by oxforms-core unit tests (swallowed_keydown_suppresses_the_paired_
    // character_input, focus_change_disarms_a_stale_key_swallow).
    let swallowed = runner
        .dispatch(key_down_event(1, "\u{1b}", 27))
        .expect("KeyDown Escape (swallowed)");
    assert_eq!(
        swallowed
            .native_dispatches
            .iter()
            .find(|d| d.event_name == "KeyDown")
            .and_then(|d| d.returned.as_deref()),
        Some("0"),
        "precondition: the KeyDown is recorded as swallowed (KeyCode -> 0)"
    );

    let mut order = dispatched_event_names(&swallowed);
    order.extend(dispatched_event_names(
        &runner
            .dispatch(character_input_event(2, "A"))
            .expect("printable character carrying the paired KeyPress"),
    ));

    assert_eq!(
        order,
        vec!["KeyDown"],
        "a swallowed KeyDown (KeyCode -> 0) must suppress the paired KeyPress/Change — \
         oracle {CAP_KEY_MUTATION} swallow_keydown rows 11-12 (no KeyPress) and \
         arrow_swallow rows 16-17"
    );
}

/// GAP — CheckBox keyboard toggle ordering Change -> Click -> KeyDown -> KeyUp. A
/// Space/Enter keystroke on a focused CheckBox toggles the value (already toggled at
/// KeyDown handler entry), firing Change then Click before the KeyDown/KeyUp. The
/// reducer emits ONLY KeyDown (and KeyUp); it neither toggles the value nor queues
/// Change/Click for a keyboard-driven CheckBox.
///
/// Oracle: [`CAP_CHECKBOX_KBD`] rows 2-5 (Space toggle): Change True -> Click True ->
/// KeyDown(32, value True) -> KeyUp(32, value True). Encoded as the full keyboard
/// toggle ordering the runtime must produce once the CheckBox keyboard toggle lands.
///
/// CLOSED by oxforms-esq.8: a Space (or Enter, when no default button consumes it) on a
/// focused CheckBox toggles the value and fires Change then Click ahead of the KeyDown.
#[test]
fn gap_checkbox_keyboard_toggle_change_click_keydown_keyup() {
    let down = reduce_space(check_box_form(), 1, true);
    let up = reduce_space(down.state, 2, false);

    let mut order = reduced_event_names(&down.effects);
    order.extend(reduced_event_names(&up.effects));

    assert_eq!(
        order,
        vec!["Change", "Click", "KeyDown", "KeyUp"],
        "a CheckBox Space toggle must fire Change, Click (value-first), then KeyDown, \
         KeyUp — oracle {CAP_CHECKBOX_KBD} rows 2-5"
    );
}

/// GAP — Ctrl+V keyboard paste ordering. A Ctrl+V keystroke fires
/// KeyDown(Ctrl) -> KeyDown(V) -> BeforeDropOrPaste(Action=2) -> Change ->
/// KeyUp(V) -> KeyUp(Ctrl), with NO KeyPress anywhere. The runtime's paste path
/// (`reduce_drop_or_paste`) is gated to the drag-drop origin and is not wired to a
/// keyboard Ctrl+V chord, so the keystroke produces no BeforeDropOrPaste/Change at all.
///
/// Oracle: [`CAP_CTRLV`] rows 2-7: KeyDown 17 -> KeyDown 86 -> BeforeDropOrPaste
/// (Action=2) -> Change -> KeyUp 86 -> KeyUp 17. Encoded over the W007 runner as the
/// full chord; once the keyboard paste path lands, the native dispatch order must match.
///
/// CLOSED by oxforms-esq.9: the V KeyDown requests the clipboard (ClipboardGet); the
/// runner folds the seeded clipboard back as a ClipboardResult, driving the existing
/// paste path (BeforeDropOrPaste -> Change) within the same dispatch. This pins the native
/// dispatch ORDER; the BeforeDropOrPaste `Shift=2` arg value (oracle {CAP_CTRLV} row 4) is
/// threaded through the clipboard round-trip and pinned by the reducer test
/// oxforms_core::ctrl_v_keydown_requests_clipboard_then_pastes_on_the_folded_result
/// (oxforms-esq.13).
#[test]
fn gap_ctrl_v_keyboard_paste_ordering() {
    let mut runner = attach_runner();
    focus_input_field(&mut runner);
    // The host owns clipboard provenance; seed the text Ctrl+V pastes (the capture's
    // OxFormsClipboardSeed). An empty clipboard would fold back nothing.
    runner.set_clipboard_text("OxFormsClipboardSeed");

    let mut order = Vec::new();
    for event in ctrl_v_chord() {
        order.extend(dispatched_event_names(
            &runner.dispatch(event).expect("dispatch Ctrl+V chord event"),
        ));
    }

    assert_eq!(
        order,
        vec![
            "KeyDown",
            "KeyDown",
            "BeforeDropOrPaste",
            "Change",
            "KeyUp",
            "KeyUp"
        ],
        "Ctrl+V must fire KeyDown(Ctrl), KeyDown(V), BeforeDropOrPaste(Action=2), \
         Change, KeyUp(V), KeyUp(Ctrl) with no KeyPress — oracle {CAP_CTRLV} rows 2-7"
    );
}

/// PIN — an empty clipboard makes Ctrl+V a traced no-op: the `ClipboardGet` folds back a
/// no-text `ClipboardResult` the reducer diagnoses as a no-op paste, so NO
/// `BeforeDropOrPaste`/`Change` fires and only the key events dispatch -- and the pending
/// paste is consumed (no leak; oxforms-esq.13). This is the deferred-OS-clipboard boundary
/// (oxforms-esq.9/esq.16): the host seeds the clipboard; without a seed there is nothing to
/// paste. AC2: this is a structural no-paste fact, not an oracle row.
#[test]
fn pin_ctrl_v_empty_clipboard_is_a_no_paste() {
    let mut runner = attach_runner();
    focus_input_field(&mut runner);
    // No set_clipboard_text: the clipboard is empty.

    let mut order = Vec::new();
    for event in ctrl_v_chord() {
        order.extend(dispatched_event_names(
            &runner.dispatch(event).expect("dispatch Ctrl+V chord event"),
        ));
    }

    assert_eq!(
        order,
        vec!["KeyDown", "KeyDown", "KeyUp", "KeyUp"],
        "an empty clipboard folds back a no-text ClipboardResult (no paste), so Ctrl+V \
         dispatches only the key events -- no BeforeDropOrPaste/Change (oxforms-esq.9)"
    );
    assert!(
        runner.form().state.pending_clipboard_paste.is_none(),
        "the empty-clipboard result still consumes the pending paste -- no stale leak \
         (oxforms-esq.13)"
    );
}

/// PIN (oxforms-esq.17) — a VETOING BeforeDropOrPaste suppresses the keyboard Ctrl+V paste
/// end-to-end through the real runner. With the InputField_BeforeDropOrPaste veto armed
/// (Cancel=True), the runner folds the readback back as BeforeDropOrPasteCompleted and the
/// reducer drops the deferred paste: BeforeDropOrPaste still fires but NO Change, and the
/// pending paste is consumed. Mirrors oracle w008-paste-veto-20260629T003400Z paste_veto.
#[test]
fn runner_honors_paste_veto_end_to_end() {
    let mut runner = attach_runner();
    focus_input_field(&mut runner);
    runner.set_clipboard_text("OxFormsClipboardSeed");
    runner
        .invoke_form_sub("ArmPasteVeto")
        .expect("arm the InputField BeforeDropOrPaste veto");

    let mut order = Vec::new();
    for event in ctrl_v_chord() {
        order.extend(dispatched_event_names(
            &runner.dispatch(event).expect("dispatch Ctrl+V chord event"),
        ));
    }

    assert_eq!(
        order,
        vec!["KeyDown", "KeyDown", "BeforeDropOrPaste", "KeyUp", "KeyUp"],
        "a vetoing BeforeDropOrPaste suppresses the paste: BeforeDropOrPaste fires but NO Change \
         (oxforms-esq.17, oracle w008-paste-veto paste_veto)"
    );
    assert!(
        runner.form().state.pending_paste_commit.is_none(),
        "the veto completion consumes the deferred paste -- no leak"
    );
    assert!(
        runner
            .form()
            .state
            .text_boxes
            .iter()
            .find(|entry| entry.control_id == ControlId::new("InputField"))
            .map(|entry| entry.text.is_empty())
            .unwrap_or(true),
        "the vetoed paste inserted nothing -- InputField value unchanged"
    );
}

/// PIN (oxforms-esq.16) — when no host seed is set, a keyboard Ctrl+V reads the LIVE clipboard
/// via the injected reader; the set_clipboard_text seed still takes precedence. The reader here
/// is a deterministic test closure (the real desktop wiring is
/// oxforms_pal_win::read_clipboard_text); headless tests never touch the OS clipboard.
#[test]
fn injected_clipboard_reader_supplies_text_when_no_seed_is_set() {
    fn input_field_text(runner: &RuntimeRunner) -> String {
        runner
            .form()
            .state
            .text_boxes
            .iter()
            .find(|entry| entry.control_id == ControlId::new("InputField"))
            .map(|entry| entry.text.clone())
            .unwrap_or_default()
    }

    // (a) No seed + a wired live reader -> the keyboard paste reads the reader's text.
    let mut runner = attach_runner();
    focus_input_field(&mut runner);
    runner.set_clipboard_reader(|| Some("FromReader".to_string()));
    for event in ctrl_v_chord() {
        runner.dispatch(event).expect("dispatch Ctrl+V chord event");
    }
    assert_eq!(
        input_field_text(&runner),
        "FromReader",
        "with no seed, the keyboard paste reads the injected live clipboard reader"
    );

    // (b) A set_clipboard_text seed OVERRIDES the live reader (deterministic host/test override).
    let mut seeded = attach_runner();
    focus_input_field(&mut seeded);
    seeded.set_clipboard_reader(|| Some("FromReader".to_string()));
    seeded.set_clipboard_text("FromSeed");
    for event in ctrl_v_chord() {
        seeded.dispatch(event).expect("dispatch Ctrl+V chord event");
    }
    assert_eq!(
        input_field_text(&seeded),
        "FromSeed",
        "the set_clipboard_text seed takes precedence over the live reader"
    );

    // (c) A reader that returns None (empty/no-text clipboard) is a no-op paste.
    let mut empty = attach_runner();
    focus_input_field(&mut empty);
    empty.set_clipboard_reader(|| None);
    for event in ctrl_v_chord() {
        empty.dispatch(event).expect("dispatch Ctrl+V chord event");
    }
    assert_eq!(
        input_field_text(&empty),
        "",
        "a reader returning None pastes nothing (no-op)"
    );
}

/// PIN — a drag-drop text paste natively dispatches BeforeDropOrPaste -> Change. esq.9
/// added BeforeDropOrPaste to the native-dispatch allowlist, which also routes the
/// pre-existing drag-drop paste path (`reduce_drop_or_paste`) through
/// PerformBeforeDropOrPaste instead of acknowledge-only; this locks that the unified
/// dispatch fires for the drag origin too (not just the keyboard Ctrl+V path).
#[test]
fn pin_drag_drop_text_paste_dispatches_before_drop_or_paste_and_change() {
    let mut runner = attach_runner();
    focus_input_field(&mut runner);

    let drop = ui_event(
        1,
        UiEventKind::DropOrPaste(DropOrPasteEvent {
            transfer_session_id: "drag-1".to_string(),
            origin: DropOrPasteOrigin::DragDrop,
            coordinates: CoordinatePayload {
                form_logical: Some(LogicalPoint::new(20.0, 18.0)),
                ..CoordinatePayload::default()
            },
            modifiers: KeyboardModifiers::default(),
            action: 2,
            effect: 1,
            data: DataObjectSnapshot {
                snapshot_id: ServiceRequestId::new("drag-1"),
                formats: vec!["text/plain".to_string()],
                payload: Some(ServicePayload {
                    content_type: Some("text/plain".to_string()),
                    text: Some("DRAGGED".to_string()),
                    bytes_sha256: None,
                    metadata: Vec::new(),
                }),
                metadata: Vec::new(),
            },
        }),
    );

    let order = dispatched_event_names(&runner.dispatch(drop).expect("dispatch drag-drop paste"));
    assert_eq!(
        order,
        vec!["BeforeDropOrPaste", "Change"],
        "a drag-drop text paste natively dispatches BeforeDropOrPaste then Change \
         (esq.9 unified the native dispatch of both paste origins)"
    );
}
