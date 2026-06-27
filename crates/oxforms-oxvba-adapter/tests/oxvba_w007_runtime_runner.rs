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

use oxforms_core::materialize_w007_demo_form;
use oxforms_oxvba_adapter::runtime_runner::{RuntimeError, RuntimeRunner, RuntimeTraceRow};
use oxforms_pal::{
    CharacterInputEvent, ClickCount, ControlId, CoordinatePayload, KeyCode, KeyEvent, KeyRepeat,
    KeyboardModifiers, LogicalPoint, MouseButton, MouseButtonEvent, MouseButtons, PointerId,
    RawKeyDiagnostics, UiEvent, UiEventId, UiEventKind, UiEventSource,
};

use oxvba_bundle::BundlePackage;
use oxvba_hal::model::HostPolicy;
use oxvba_host::{Engine, HostConfig, ProjectRuntimeSession};
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

fn prepare_session() -> ProjectRuntimeSession {
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
    let bundle = oxvba_bundle::linearize(&program).expect("linearize W007 runtime runner project");

    let mut engine = Engine::new(HostConfig { enable_jit: false });
    engine.set_host_policy(HostPolicy::interactive_dev());
    engine
        .prepare_bundle_package_session(BundlePackage::single(bundle))
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

    // Press + release on the OkButton (bounds 140,12,48,20) -> a Click effect.
    runner
        .dispatch(ui_event(
            4,
            UiEventKind::MouseDown(mouse_event(true, 150.0, 20.0)),
        ))
        .expect("press OkButton");
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

    // The reducer-routed mouse events are acknowledged (explicit non-claim), never
    // natively dispatched in this slice.
    for event in ["MouseDown", "MouseUp"] {
        assert!(
            trace.iter().any(|row| matches!(
                row,
                RuntimeTraceRow::EventAcknowledged { event_name, .. } if event_name == event
            )),
            "{event} is acknowledged in the trace"
        );
        assert!(
            !trace.iter().any(|row| matches!(
                row,
                RuntimeTraceRow::NativeDispatch { event_name, .. } if event_name == event
            )),
            "{event} is not natively dispatched"
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
