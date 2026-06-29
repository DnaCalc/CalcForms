//! W007 runtime/effect runner end to end on OxVba (oxforms-4pn.5).
//!
//! Proves the runtime layer drives the W007 demo path through real OxVba:
//! - a TextBox character input reduces to a `Change` effect, which the runner
//!   dispatches by calling the control's native `ApplyUserText` member;
//! - a CommandButton click reduces to a `Click` effect, dispatched via the native
//!   `PerformClick` member (NOT the W005 `RaiseDispatch` carrier);
//! - the VBA `OkButton_Click` handler runs and sets `OutputLabel.Caption`;
//! - the runner reads that VBA-set caption back and folds it into reducer state
//!   through the reducer-owned sync, and requests a repaint.

use std::path::{Path, PathBuf};

use oxforms_core::{materialize_w007_demo_form, FocusTarget, LifecycleState};
use oxforms_oxvba_adapter::runtime_runner::{
    RuntimeError, RuntimeRunner, RuntimeStep, RuntimeTraceRow,
};
use oxforms_pal::{
    ActivationEvent, ActivationReason, CharacterInputEvent, ClickCount, CloseQueryPolicy,
    CloseReason, CloseRequestEvent, CloseRequestOrigin, ControlId, CoordinatePayload,
    FormLoadedEvent, KeyCode, KeyEvent, KeyRepeat, KeyboardModifiers, LifecycleReason,
    LogicalPoint, MouseButton, MouseButtonEvent, MouseButtons, PointerId, RawKeyDiagnostics,
    TerminatedEvent, UiEvent, UiEventId, UiEventKind, UiEventSource,
};

use oxvba_hal::model::HostPolicy;
use oxvba_host::{Engine, HostConfig, Vm3RuntimeSession};
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

fn prepare_session() -> Vm3RuntimeSession {
    let manifest = SymbolProjectManifest {
        project_name: "W007RuntimeRunner".to_string(),
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
        .expect("bind W007 runtime runner project");
    let bundle =
        oxvba_oxir::elaborate::elaborate(&program).expect("elaborate W007 runtime runner project");

    let mut engine = Engine::new(HostConfig { enable_jit: false });
    engine.set_host_policy(HostPolicy::interactive_dev());
    engine
        .prepare_image_session(oxvba_oxir::OxImage::new(vec![bundle]))
        .expect("prepare W007 runtime runner session")
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
fn runner_drives_w007_demo_path_through_native_oxvba_dispatch() {
    let session = prepare_session();
    let runtime_form = materialize_w007_demo_form().expect("materialize W007 demo form");

    let mut runner = RuntimeRunner::attach(
        session,
        runtime_form,
        "W007ObjectModelProbeForm",
        "Build",
        "Form",
    )
    .expect("attach runtime runner to the OxVba session");

    // Click into the InputField to focus it (press + release inside 12,12,120,18).
    // The release matters: it frees the mouse capture so the later OkButton click is
    // routed to the button rather than the still-captured InputField.
    runner
        .dispatch(ui_event(
            1,
            UiEventKind::MouseDown(mouse_event(true, 20.0, 18.0)),
        ))
        .expect("press InputField");
    runner
        .dispatch(ui_event(
            2,
            UiEventKind::MouseUp(mouse_event(false, 20.0, 18.0)),
        ))
        .expect("release InputField");

    // Type "World" — reduces to a Change effect the runner dispatches via the native
    // ApplyUserText member, so the VBA TextBox.Text becomes "World".
    let typed = runner
        .dispatch(ui_event(
            3,
            UiEventKind::CharacterInput(CharacterInputEvent {
                text: "World".to_string(),
                modifiers: KeyboardModifiers::default(),
                raw: Vec::new(),
            }),
        ))
        .expect("type into InputField");
    assert!(
        typed
            .native_dispatches
            .iter()
            .any(|dispatch| dispatch.event_name == "Change"
                && dispatch.native_member == "ApplyUserText"),
        "text input dispatches the native ApplyUserText member, got {:?}",
        typed.native_dispatches
    );
    // Isolate the Change leg: the reducer-owned text-box state now holds the typed
    // value (and the native ApplyUserText above pushed it to the VBA control).
    assert_eq!(
        runner
            .form()
            .state
            .text_boxes
            .iter()
            .find(|entry| entry.control_id == ControlId::new("InputField"))
            .map(|entry| entry.text.as_str()),
        Some("World"),
        "the reducer text-box state reflects the typed input"
    );

    // Press the OkButton (bounds 140,12,48,20). InputField is dirty (typed "World"), so this
    // focus-CHANGING press runs the full two-stage focus-out validation end-to-end through
    // the runtime fold-back (oxforms-esq.11): BeforeUpdate is dispatched and its (uncancelled)
    // Cancel folds back, advancing to AfterUpdate -> Exit; the Exit completion commits focus
    // to OkButton (its Enter) and replays the deferred press (MouseDown). None of these veto.
    let pressed_ok = runner
        .dispatch(ui_event(
            4,
            UiEventKind::MouseDown(mouse_event(true, 150.0, 20.0)),
        ))
        .expect("press OkButton");
    let focus_out_order: Vec<&str> = pressed_ok
        .native_dispatches
        .iter()
        .map(|dispatch| dispatch.event_name.as_str())
        .filter(|name| {
            matches!(
                *name,
                "BeforeUpdate" | "AfterUpdate" | "Exit" | "Enter" | "MouseDown"
            )
        })
        .collect();
    assert_eq!(
        focus_out_order,
        vec!["BeforeUpdate", "AfterUpdate", "Exit", "Enter", "MouseDown"],
        "a non-vetoing dirty focus-out validates in two stages then commits + replays the \
         deferred press: BeforeUpdate -> AfterUpdate -> Exit -> Enter -> MouseDown, got {:?}",
        pressed_ok.native_dispatches
    );
    let clicked = runner
        .dispatch(ui_event(
            5,
            UiEventKind::MouseUp(mouse_event(false, 150.0, 20.0)),
        ))
        .expect("release OkButton");

    // The Click was dispatched through the native PerformClick member (never the W005
    // RaiseDispatch carrier).
    assert!(
        clicked
            .native_dispatches
            .iter()
            .any(|dispatch| dispatch.event_name == "Click"
                && dispatch.native_member == "PerformClick"),
        "click dispatches the native PerformClick member, got {:?}",
        clicked.native_dispatches
    );

    // The VBA OkButton_Click handler set OutputLabel.Caption; the runner synced it
    // back into reducer state and requested a repaint.
    assert!(
        clicked
            .property_syncs
            .iter()
            .any(|sync| sync.control_id == ControlId::new("OutputLabel")
                && sync.value == "Hello, World"),
        "OkButton_Click's caption is synced into reducer state, got {:?}",
        clicked.property_syncs
    );
    assert!(
        clicked.repaint_requested,
        "the synced label change requests a repaint"
    );
    assert_eq!(
        label_caption(&runner, "OutputLabel"),
        "Hello, World",
        "the materialized runtime state reflects the VBA handler's caption update"
    );

    // The runtime trace carries native-dispatch + property-sync rows (W005 RaiseDispatch
    // carrier is never used).
    let trace = runner.trace();
    assert!(trace.iter().any(|row| matches!(
        row,
        RuntimeTraceRow::NativeDispatch { native_member, .. } if native_member == "PerformClick"
    )));
    assert!(trace.iter().any(|row| matches!(
        row,
        RuntimeTraceRow::PropertySync { value, .. } if value == "Hello, World"
    )));
    // The trace is rich enough to diagnose the demo (criterion 4): an EffectDrained
    // for the Click effect, and a RepaintRequested row.
    assert!(trace.iter().any(|row| matches!(
        row,
        RuntimeTraceRow::EffectDrained { kind, .. } if kind == "fire_vba_event:Click"
    )));
    assert!(trace
        .iter()
        .any(|row| matches!(row, RuntimeTraceRow::RepaintRequested { .. })));

    // The mouse and keyboard events the W007 path exercises all dispatch natively now
    // (oxforms-esq.2): the setup presses + releases inside InputField and OkButton
    // (all control hits) and types "World" (a KeyPress on the focused InputField).
    for (event, member) in [
        ("MouseDown", "PerformMouseDown"),
        ("MouseUp", "PerformMouseUp"),
        ("KeyPress", "PerformKeyPress"),
    ] {
        assert!(
            trace.iter().any(|row| matches!(
                row,
                RuntimeTraceRow::NativeDispatch { event_name, native_member, .. }
                    if event_name == event && native_member == member
            )),
            "{event} is natively dispatched via {member}"
        );
        assert!(
            !trace.iter().any(|row| matches!(
                row,
                RuntimeTraceRow::EventAcknowledged { event_name, .. } if event_name == event
            )),
            "{event} is no longer merely acknowledged"
        );
    }

    // The W005 RaiseDispatch carrier is never used by the runtime path (criterion 3).
    assert!(
        !trace.iter().any(|row| matches!(
            row,
            RuntimeTraceRow::NativeDispatch { native_member, .. } if native_member == "RaiseDispatch"
        )),
        "the runtime never dispatches through the W005 RaiseDispatch carrier"
    );
}

#[test]
fn attach_failure_is_a_precise_diagnostic_not_a_panic() {
    // A missing OxVba capability (here: a non-existent build member) surfaces as a
    // precise RuntimeError naming the member, not a panic or silent no-op
    // (acceptance criterion 5).
    let session = prepare_session();
    let runtime_form = materialize_w007_demo_form().expect("materialize W007 demo form");

    let result = RuntimeRunner::attach(
        session,
        runtime_form,
        "W007ObjectModelProbeForm",
        "NoSuchBuildMember",
        "Form",
    );

    match result {
        Err(RuntimeError::Invoke { member, .. }) => assert_eq!(member, "NoSuchBuildMember"),
        Err(other) => panic!("expected a precise Invoke diagnostic, got {other:?}"),
        Ok(_) => panic!("attach unexpectedly succeeded with a missing build member"),
    }
}

/// Build a native KeyDown UiEvent for `character` with the given OS virtual key
/// (the MSForms KeyCode). The runtime maps it to the focused control's
/// `PerformKeyDown` and reads back the post-handler KeyCode.
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

#[test]
fn runner_dispatches_native_keydown_with_returninteger_readback() {
    // oxforms-esq.2: native KeyDown dispatches through the control's PerformKeyDown
    // member, and the post-handler KeyCode (the MSForms.ReturnInteger helper the
    // WithEvents handler may swallow) is read back by the runtime -- consuming the
    // oxforms-esq.1 mechanism end to end in the real runtime, not a synthetic gate.
    let session = prepare_session();
    let runtime_form = materialize_w007_demo_form().expect("materialize W007 demo form");
    let mut runner = RuntimeRunner::attach(
        session,
        runtime_form,
        "W007ObjectModelProbeForm",
        "Build",
        "Form",
    )
    .expect("attach runtime runner to the OxVba session");

    // Focus the InputField so key events route to it.
    runner
        .dispatch(ui_event(
            1,
            UiEventKind::MouseDown(mouse_event(true, 20.0, 18.0)),
        ))
        .expect("press InputField");
    runner
        .dispatch(ui_event(
            2,
            UiEventKind::MouseUp(mouse_event(false, 20.0, 18.0)),
        ))
        .expect("release InputField");

    // Escape (VK 27): InputField_KeyDown swallows it (KeyCode -> 0); the runtime
    // reads that back through the ReturnInteger helper.
    let escape = runner
        .dispatch(key_down_event(3, "\u{1b}", 27))
        .expect("dispatch Escape KeyDown");
    let escape_dispatch = escape
        .native_dispatches
        .iter()
        .find(|dispatch| dispatch.event_name == "KeyDown")
        .unwrap_or_else(|| {
            panic!(
                "KeyDown natively dispatched, got {:?}",
                escape.native_dispatches
            )
        });
    assert_eq!(escape_dispatch.native_member, "PerformKeyDown");
    assert_eq!(
        escape_dispatch.returned.as_deref(),
        Some("0"),
        "the handler swallowed Escape; the runtime reads back KeyCode 0 via the ReturnInteger helper"
    );

    // 'A' (VK 65): not swallowed, read back unchanged.
    let letter = runner
        .dispatch(key_down_event(4, "A", 65))
        .expect("dispatch A KeyDown");
    let letter_dispatch = letter
        .native_dispatches
        .iter()
        .find(|dispatch| dispatch.event_name == "KeyDown")
        .unwrap_or_else(|| {
            panic!(
                "KeyDown natively dispatched, got {:?}",
                letter.native_dispatches
            )
        });
    assert_eq!(letter_dispatch.native_member, "PerformKeyDown");
    assert_eq!(
        letter_dispatch.returned.as_deref(),
        Some("65"),
        "an un-swallowed key is read back unchanged through the ReturnInteger helper"
    );
}

#[test]
fn runner_dispatches_native_mousedown_to_perform_mouse_down() {
    // oxforms-esq.2: a control-hit MouseDown dispatches natively to the control's
    // PerformMouseDown (Button, Shift, X, Y) -- X/Y typed as Single. PerformMouseDown
    // is a Sub (RaiseEvent MouseDown), so nothing is read back.
    let session = prepare_session();
    let runtime_form = materialize_w007_demo_form().expect("materialize W007 demo form");
    let mut runner = RuntimeRunner::attach(
        session,
        runtime_form,
        "W007ObjectModelProbeForm",
        "Build",
        "Form",
    )
    .expect("attach runtime runner to the OxVba session");

    // Press inside the OkButton (bounds 140,12,48,20).
    let pressed = runner
        .dispatch(ui_event(
            1,
            UiEventKind::MouseDown(mouse_event(true, 150.0, 20.0)),
        ))
        .expect("press OkButton");
    let mouse_down = pressed
        .native_dispatches
        .iter()
        .find(|dispatch| dispatch.event_name == "MouseDown")
        .unwrap_or_else(|| {
            panic!(
                "MouseDown natively dispatched, got {:?}",
                pressed.native_dispatches
            )
        });
    assert_eq!(mouse_down.native_member, "PerformMouseDown");
    assert_eq!(
        mouse_down.returned, None,
        "PerformMouseDown is a Sub; nothing is read back"
    );
    assert_eq!(mouse_down.control_id, ControlId::new("OkButton"));
}

#[test]
fn runner_acknowledges_form_background_mousedown_without_dispatch() {
    // A MouseDown that misses every control (form background) has no control target,
    // so it is acknowledged, not natively dispatched -- the no-control acknowledge
    // path, distinct from key events which always have a focused control.
    let session = prepare_session();
    let runtime_form = materialize_w007_demo_form().expect("materialize W007 demo form");
    let mut runner = RuntimeRunner::attach(
        session,
        runtime_form,
        "W007ObjectModelProbeForm",
        "Build",
        "Form",
    )
    .expect("attach runtime runner to the OxVba session");

    // The form is 200x120; its controls occupy y<=58 (OutputLabel ends at 40+18), so
    // (60,90) is inside the form but on no control -> a form-background press.
    let pressed = runner
        .dispatch(ui_event(
            1,
            UiEventKind::MouseDown(mouse_event(true, 60.0, 90.0)),
        ))
        .expect("press the form background");
    assert!(
        !pressed
            .native_dispatches
            .iter()
            .any(|dispatch| dispatch.event_name == "MouseDown"),
        "a form-background MouseDown is not natively dispatched, got {:?}",
        pressed.native_dispatches
    );
    // It is acknowledged (emitted by the reducer, recorded by the runtime), not
    // silently absent -- proving the no-control acknowledge path, not a vacuous miss.
    assert!(
        runner.trace().iter().any(|row| matches!(
            row,
            RuntimeTraceRow::EventAcknowledged { event_name, .. } if event_name == "MouseDown"
        )),
        "the form-background MouseDown is acknowledged in the trace"
    );
}

/// Build a native KeyUp UiEvent for `character` with the given OS virtual key.
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

#[test]
fn runner_dispatches_native_mouseup_to_perform_mouse_up() {
    // oxforms-esq.2: a control-hit MouseUp dispatches natively to PerformMouseUp,
    // symmetric to MouseDown. PerformMouseUp is a Sub, so nothing is read back.
    let session = prepare_session();
    let runtime_form = materialize_w007_demo_form().expect("materialize W007 demo form");
    let mut runner = RuntimeRunner::attach(
        session,
        runtime_form,
        "W007ObjectModelProbeForm",
        "Build",
        "Form",
    )
    .expect("attach runtime runner to the OxVba session");

    runner
        .dispatch(ui_event(
            1,
            UiEventKind::MouseDown(mouse_event(true, 150.0, 20.0)),
        ))
        .expect("press OkButton");
    let released = runner
        .dispatch(ui_event(
            2,
            UiEventKind::MouseUp(mouse_event(false, 150.0, 20.0)),
        ))
        .expect("release OkButton");
    let mouse_up = released
        .native_dispatches
        .iter()
        .find(|dispatch| dispatch.event_name == "MouseUp")
        .unwrap_or_else(|| {
            panic!(
                "MouseUp natively dispatched, got {:?}",
                released.native_dispatches
            )
        });
    assert_eq!(mouse_up.native_member, "PerformMouseUp");
    assert_eq!(
        mouse_up.returned, None,
        "PerformMouseUp is a Sub; nothing is read back"
    );
}

#[test]
fn runner_dispatches_native_keyup_with_returninteger_readback() {
    // oxforms-esq.2: KeyUp dispatches to PerformKeyUp with the same ReturnInteger
    // KeyCode readback as KeyDown (the FM20 KeyUp KeyCode is likewise mutable).
    let session = prepare_session();
    let runtime_form = materialize_w007_demo_form().expect("materialize W007 demo form");
    let mut runner = RuntimeRunner::attach(
        session,
        runtime_form,
        "W007ObjectModelProbeForm",
        "Build",
        "Form",
    )
    .expect("attach runtime runner to the OxVba session");

    // Focus the InputField so key events route to it.
    runner
        .dispatch(ui_event(
            1,
            UiEventKind::MouseDown(mouse_event(true, 20.0, 18.0)),
        ))
        .expect("press InputField");
    runner
        .dispatch(ui_event(
            2,
            UiEventKind::MouseUp(mouse_event(false, 20.0, 18.0)),
        ))
        .expect("release InputField");

    // Escape (27): InputField_KeyUp swallows it (KeyCode -> 0).
    let escape = runner
        .dispatch(key_up_event(3, "\u{1b}", 27))
        .expect("dispatch Escape KeyUp");
    let escape_dispatch = escape
        .native_dispatches
        .iter()
        .find(|dispatch| dispatch.event_name == "KeyUp")
        .unwrap_or_else(|| {
            panic!(
                "KeyUp natively dispatched, got {:?}",
                escape.native_dispatches
            )
        });
    assert_eq!(escape_dispatch.native_member, "PerformKeyUp");
    assert_eq!(
        escape_dispatch.returned.as_deref(),
        Some("0"),
        "the handler swallowed Escape on KeyUp; the runtime reads back KeyCode 0"
    );

    // 'A' (65): not swallowed, read back unchanged.
    let letter = runner
        .dispatch(key_up_event(4, "A", 65))
        .expect("dispatch A KeyUp");
    let letter_dispatch = letter
        .native_dispatches
        .iter()
        .find(|dispatch| dispatch.event_name == "KeyUp")
        .unwrap_or_else(|| {
            panic!(
                "KeyUp natively dispatched, got {:?}",
                letter.native_dispatches
            )
        });
    assert_eq!(letter_dispatch.native_member, "PerformKeyUp");
    assert_eq!(
        letter_dispatch.returned.as_deref(),
        Some("65"),
        "an un-swallowed key is read back unchanged on KeyUp"
    );
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

#[test]
fn runner_dispatches_native_keypress_with_returninteger_readback() {
    // oxforms-esq.2: typed character input dispatches KeyPress to PerformKeyPress and
    // reads back the post-handler KeyAscii via the MSForms.ReturnInteger helper.
    let session = prepare_session();
    let runtime_form = materialize_w007_demo_form().expect("materialize W007 demo form");
    let mut runner = RuntimeRunner::attach(
        session,
        runtime_form,
        "W007ObjectModelProbeForm",
        "Build",
        "Form",
    )
    .expect("attach runtime runner to the OxVba session");

    // Focus the InputField so character input routes to it.
    runner
        .dispatch(ui_event(
            1,
            UiEventKind::MouseDown(mouse_event(true, 20.0, 18.0)),
        ))
        .expect("press InputField");
    runner
        .dispatch(ui_event(
            2,
            UiEventKind::MouseUp(mouse_event(false, 20.0, 18.0)),
        ))
        .expect("release InputField");

    // 'Z' (KeyAscii 90): InputField_KeyPress swallows it (KeyAscii -> 0).
    let zed = runner
        .dispatch(character_input_event(3, "Z"))
        .expect("type Z");
    let zed_dispatch = zed
        .native_dispatches
        .iter()
        .find(|dispatch| dispatch.event_name == "KeyPress")
        .unwrap_or_else(|| {
            panic!(
                "KeyPress natively dispatched, got {:?}",
                zed.native_dispatches
            )
        });
    assert_eq!(zed_dispatch.native_member, "PerformKeyPress");
    assert_eq!(
        zed_dispatch.returned.as_deref(),
        Some("0"),
        "the handler swallowed 'Z'; the runtime reads back KeyAscii 0"
    );

    // 'A' (KeyAscii 65): not swallowed, read back unchanged.
    let ay = runner
        .dispatch(character_input_event(4, "A"))
        .expect("type A");
    let ay_dispatch = ay
        .native_dispatches
        .iter()
        .find(|dispatch| dispatch.event_name == "KeyPress")
        .unwrap_or_else(|| {
            panic!(
                "KeyPress natively dispatched, got {:?}",
                ay.native_dispatches
            )
        });
    assert_eq!(ay_dispatch.native_member, "PerformKeyPress");
    assert_eq!(
        ay_dispatch.returned.as_deref(),
        Some("65"),
        "an un-swallowed character is read back unchanged"
    );
}

#[test]
fn runner_dispatches_native_exit_with_returnboolean_veto_readback() {
    // oxforms-esq.2: focus leaving a control fires Exit, dispatched to PerformExit;
    // the handler's veto (Cancel = True) is read back via the MSForms.ReturnBoolean
    // helper -- consuming the OTHER half of the esq.1 proof in the real runtime. The veto
    // is now folded back (oxforms-esq.4): the focus commit is held pending and retained on
    // the veto. This test asserts the dispatch + readback; focus retention is asserted by
    // oxvba_esq3_conformance::gap_exit_veto_keeps_focus.
    let session = prepare_session();
    let runtime_form = materialize_w007_demo_form().expect("materialize W007 demo form");
    let mut runner = RuntimeRunner::attach(
        session,
        runtime_form,
        "W007ObjectModelProbeForm",
        "Build",
        "Form",
    )
    .expect("attach runtime runner to the OxVba session");

    // Arm the InputField_Exit veto (off by default since oxforms-esq.11); this test asserts
    // the Cancel=True readback round-trip.
    runner
        .invoke_form_sub("ArmExitVeto")
        .expect("arm the InputField_Exit veto");

    // Focus the InputField.
    runner
        .dispatch(ui_event(
            1,
            UiEventKind::MouseDown(mouse_event(true, 20.0, 18.0)),
        ))
        .expect("press InputField");
    runner
        .dispatch(ui_event(
            2,
            UiEventKind::MouseUp(mouse_event(false, 20.0, 18.0)),
        ))
        .expect("release InputField");

    // Move focus to OkButton (control -> control): InputField loses focus -> Exit.
    let moved = runner
        .dispatch(ui_event(
            3,
            UiEventKind::MouseDown(mouse_event(true, 150.0, 20.0)),
        ))
        .expect("press OkButton");
    let exit = moved
        .native_dispatches
        .iter()
        .find(|dispatch| dispatch.event_name == "Exit")
        .unwrap_or_else(|| {
            panic!(
                "Exit natively dispatched, got {:?}",
                moved.native_dispatches
            )
        });
    assert_eq!(exit.native_member, "PerformExit");
    assert_eq!(exit.control_id, ControlId::new("InputField"));
    assert_eq!(
        exit.returned.as_deref(),
        Some("true"),
        "InputField_Exit vetoes; the runtime reads back Cancel=true via the ReturnBoolean helper"
    );
}

#[test]
fn runner_honors_before_update_veto_end_to_end_through_native_dispatch() {
    // oxforms-esq.11: a DIRTY control's focus-out validates BeforeUpdate FIRST; a vetoing
    // BeforeUpdate (Cancel=True, read back via PerformBeforeUpdate and folded back as the
    // stage-one FocusValidationCompleted) suppresses AfterUpdate/Exit/Enter and the
    // focus-changing click is absorbed, with focus retained and the value left dirty. This
    // drives the stage-gated fold-back parse + the cancelled BeforeUpdate branch through the
    // REAL VBA dispatch (the pure-reducer gap_before_update_veto_suppresses_commit injects a
    // synthetic completion; this closes the end-to-end seam).
    let session = prepare_session();
    let runtime_form = materialize_w007_demo_form().expect("materialize W007 demo form");
    let mut runner = RuntimeRunner::attach(
        session,
        runtime_form,
        "W007ObjectModelProbeForm",
        "Build",
        "Form",
    )
    .expect("attach runtime runner to the OxVba session");

    // Arm the BeforeUpdate veto (off by default since oxforms-esq.11).
    runner
        .invoke_form_sub("ArmBeforeUpdateVeto")
        .expect("arm the InputField_BeforeUpdate veto");

    // Focus + type into InputField so it is dirty (the BeforeUpdate gate).
    runner
        .dispatch(ui_event(
            1,
            UiEventKind::MouseDown(mouse_event(true, 20.0, 18.0)),
        ))
        .expect("press InputField");
    runner
        .dispatch(ui_event(
            2,
            UiEventKind::MouseUp(mouse_event(false, 20.0, 18.0)),
        ))
        .expect("release InputField");
    runner
        .dispatch(ui_event(
            3,
            UiEventKind::CharacterInput(CharacterInputEvent {
                text: "World".to_string(),
                modifiers: KeyboardModifiers::default(),
                raw: Vec::new(),
            }),
        ))
        .expect("type into InputField");

    // Focus-changing press on OkButton: the dirty focus-out fires BeforeUpdate, which vetoes.
    let pressed_ok = runner
        .dispatch(ui_event(
            4,
            UiEventKind::MouseDown(mouse_event(true, 150.0, 20.0)),
        ))
        .expect("press OkButton");

    // The BeforeUpdate dispatch read back Cancel=true via PerformBeforeUpdate.
    let before_update = pressed_ok
        .native_dispatches
        .iter()
        .find(|dispatch| dispatch.event_name == "BeforeUpdate")
        .unwrap_or_else(|| {
            panic!(
                "BeforeUpdate natively dispatched, got {:?}",
                pressed_ok.native_dispatches
            )
        });
    assert_eq!(before_update.native_member, "PerformBeforeUpdate");
    assert_eq!(before_update.control_id, ControlId::new("InputField"));
    assert_eq!(
        before_update.returned.as_deref(),
        Some("true"),
        "InputField_BeforeUpdate vetoes; the runtime reads back Cancel=true via ReturnBoolean"
    );

    // The veto suppresses everything past BeforeUpdate and absorbs the click: among the
    // focus-out / click events, ONLY BeforeUpdate fired (no AfterUpdate/Exit/Enter, and no
    // MouseDown/Click on OkButton).
    let focus_out_order: Vec<&str> = pressed_ok
        .native_dispatches
        .iter()
        .map(|dispatch| dispatch.event_name.as_str())
        .filter(|name| {
            matches!(
                *name,
                "BeforeUpdate" | "AfterUpdate" | "Exit" | "Enter" | "MouseDown" | "Click"
            )
        })
        .collect();
    assert_eq!(
        focus_out_order,
        vec!["BeforeUpdate"],
        "a vetoing BeforeUpdate suppresses AfterUpdate/Exit/Enter and absorbs the click, got {:?}",
        pressed_ok.native_dispatches
    );

    // Focus stays on InputField and the validation fully resolves (no dangling Exit stage).
    assert_eq!(
        runner.form().state.focus_owner,
        Some(FocusTarget::Control(ControlId::new("InputField"))),
        "a vetoing BeforeUpdate keeps focus on InputField"
    );
    assert!(
        runner.form().state.validation.pending.is_none(),
        "the validation resolves on the veto (no dangling pending stage)"
    );

    // The value was never committed, so InputField stays dirty.
    assert!(
        runner
            .form()
            .state
            .text_boxes
            .iter()
            .any(|entry| entry.control_id == ControlId::new("InputField") && entry.dirty),
        "a vetoed BeforeUpdate keeps the value dirty (uncommitted)"
    );
}

fn close_request_event(id: u64, origin: CloseRequestOrigin) -> UiEvent {
    ui_event(
        id,
        UiEventKind::CloseRequest(CloseRequestEvent {
            origin,
            reason: CloseReason::User,
            query_policy: CloseQueryPolicy::Query,
            coordinates: None,
        }),
    )
}

fn assert_form_dispatch(step: &RuntimeStep, event: &str, member: &str) {
    let dispatch = step
        .native_dispatches
        .iter()
        .find(|dispatch| dispatch.event_name == event)
        .unwrap_or_else(|| {
            panic!(
                "{event} natively dispatched, got {:?}",
                step.native_dispatches
            )
        });
    assert_eq!(dispatch.native_member, member);
    assert_eq!(
        dispatch.returned, None,
        "{member} is a Sub; nothing is read back"
    );
}

#[test]
fn runner_dispatches_native_queryclose_with_cancel_readback() {
    // oxforms-esq.2: a form-targeted QueryClose dispatches to the form module's
    // PerformQueryClose (no control to call Perform* on); the post-handler Cancel is
    // read back via the ReturnInteger helper -- consuming the esq.1 mechanism at form
    // level. The fixture vetoes a control-menu close (CloseMode 0) and allows a code
    // Unload (CloseMode 1), so the readback reflects the handler's decision. The veto
    // is recorded, not yet folded back into the reducer close flow.
    let session = prepare_session();
    let runtime_form = materialize_w007_demo_form().expect("materialize W007 demo form");
    let mut runner = RuntimeRunner::attach(
        session,
        runtime_form,
        "W007ObjectModelProbeForm",
        "Build",
        "Form",
    )
    .expect("attach runtime runner to the OxVba session");

    // CloseButton -> CloseMode 0 -> the handler vetoes (Cancel = -1).
    let menu_close = runner
        .dispatch(close_request_event(1, CloseRequestOrigin::CloseButton))
        .expect("control-menu close request");
    let vetoed = menu_close
        .native_dispatches
        .iter()
        .find(|dispatch| dispatch.event_name == "QueryClose")
        .unwrap_or_else(|| {
            panic!(
                "QueryClose natively dispatched, got {:?}",
                menu_close.native_dispatches
            )
        });
    assert_eq!(vetoed.native_member, "PerformQueryClose");
    assert_eq!(
        vetoed.returned.as_deref(),
        Some("-1"),
        "the handler vetoes a control-menu close; the runtime reads back Cancel=-1"
    );

    // CodeUnload -> CloseMode 1 -> the handler allows the close (Cancel stays 0).
    let code_close = runner
        .dispatch(close_request_event(2, CloseRequestOrigin::CodeUnload))
        .expect("code unload close request");
    let allowed = code_close
        .native_dispatches
        .iter()
        .find(|dispatch| dispatch.event_name == "QueryClose")
        .unwrap_or_else(|| {
            panic!(
                "QueryClose natively dispatched, got {:?}",
                code_close.native_dispatches
            )
        });
    assert_eq!(allowed.native_member, "PerformQueryClose");
    assert_eq!(
        allowed.returned.as_deref(),
        Some("0"),
        "the handler allows a code unload; Cancel reads back 0"
    );
}

#[test]
fn runner_dispatches_native_form_lifecycle_events() {
    // oxforms-esq.2: the form lifecycle events (no readback) dispatch to the form
    // module's Perform* members via the same form-event path as QueryClose.
    let session = prepare_session();
    let runtime_form = materialize_w007_demo_form().expect("materialize W007 demo form");
    let mut runner = RuntimeRunner::attach(
        session,
        runtime_form,
        "W007ObjectModelProbeForm",
        "Build",
        "Form",
    )
    .expect("attach runtime runner to the OxVba session");
    let form_id = runner.form().form_id.clone();

    let init = runner
        .dispatch(ui_event(
            1,
            UiEventKind::FormLoaded(FormLoadedEvent {
                form_id: form_id.clone(),
                load_source: "test".to_string(),
                control_count: None,
            }),
        ))
        .expect("form loaded");
    assert_form_dispatch(&init, "Initialize", "PerformInitialize");

    let activate = runner
        .dispatch(ui_event(
            2,
            UiEventKind::Activate(ActivationEvent {
                reason: ActivationReason::WindowShown,
                previous: None,
                next: None,
            }),
        ))
        .expect("activate");
    assert_form_dispatch(&activate, "Activate", "PerformActivate");

    let deactivate = runner
        .dispatch(ui_event(
            3,
            UiEventKind::Deactivate(ActivationEvent {
                reason: ActivationReason::WindowShown,
                previous: None,
                next: None,
            }),
        ))
        .expect("deactivate");
    assert_form_dispatch(&deactivate, "Deactivate", "PerformDeactivate");

    let terminate = runner
        .dispatch(ui_event(
            4,
            UiEventKind::Terminated(TerminatedEvent {
                form_id,
                reason: LifecycleReason::User,
            }),
        ))
        .expect("terminated");
    assert_form_dispatch(&terminate, "Terminate", "PerformTerminate");
}

#[test]
fn queryclose_veto_foldback_cancels_the_close() {
    // oxforms-esq.4: the QueryClose Cancel readback is folded back into the reducer via
    // a synthesized QueryCloseCompleted re-reduce. A vetoed close (CloseMode 0 -> the
    // handler sets Cancel -1) reaches LifecycleState::CloseCancelled -- the close is
    // genuinely prevented, not just recorded; an allowed close (CloseMode 1 -> Cancel
    // 0) proceeds to HidePending.
    let session = prepare_session();
    let runtime_form = materialize_w007_demo_form().expect("materialize W007 demo form");
    let mut runner = RuntimeRunner::attach(
        session,
        runtime_form,
        "W007ObjectModelProbeForm",
        "Build",
        "Form",
    )
    .expect("attach runtime runner to the OxVba session");

    // CloseButton -> CloseMode 0 -> the handler vetoes -> the close is cancelled.
    runner
        .dispatch(close_request_event(1, CloseRequestOrigin::CloseButton))
        .expect("control-menu close request");
    assert_eq!(
        runner.form().state.lifecycle,
        LifecycleState::CloseCancelled,
        "a vetoed QueryClose folds back to cancel the close"
    );

    // CodeUnload -> CloseMode 1 -> the handler allows -> the close proceeds to hide.
    runner
        .dispatch(close_request_event(2, CloseRequestOrigin::CodeUnload))
        .expect("code unload close request");
    assert_eq!(
        runner.form().state.lifecycle,
        LifecycleState::HidePending,
        "an allowed QueryClose folds back to proceed with hiding the form"
    );
}
