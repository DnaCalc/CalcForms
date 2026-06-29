use std::path::{Path, PathBuf};

use oxforms_core::{reduce, ControlNode, EffectKind, FormState};
use oxforms_oxvba_adapter::event_dispatch::{
    VbaEventDispatchCompletion as AdapterDispatchCompletion,
    VbaEventDispatchRequest as AdapterDispatchRequest,
};
use oxforms_pal::{
    CharacterInputEvent, ClickCount, ControlId, KeyboardModifiers, LogicalPoint, LogicalRect,
    MouseButton, MouseButtonEvent, MouseButtons, PointerId, RawKeyDiagnostics, UiEvent, UiEventId,
    UiEventKind, UiEventSource,
};
use oxvba_bundle::ProjectMemberKind;
use oxvba_hal::model::HostPolicy;
use oxvba_host::{Engine, HostConfig};
use oxvba_runtime::{ObjectRef, Variant};
use oxvba_symbol::manifest::{
    ModuleAttributes, ModuleKind, ModuleUnit, ProjectKind, SymbolProjectManifest,
};

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("..").join("..")
}

fn fixture_source(name: &str) -> String {
    std::fs::read_to_string(
        repo_root()
            .join("vba")
            .join("smoke")
            .join("fixtures")
            .join(name),
    )
    .unwrap_or_else(|err| panic!("read fixture {name}: {err}"))
}

fn exposed_class(name: &str, source: String) -> ModuleUnit {
    let mut attributes = ModuleAttributes::named(name);
    attributes.vb_exposed = true;
    attributes.vb_creatable = true;
    ModuleUnit {
        module_name: name.to_string(),
        module_kind: ModuleKind::Class,
        attributes,
        source,
    }
}

fn event_smoke_manifest() -> SymbolProjectManifest {
    SymbolProjectManifest {
        project_name: "W005EventDispatchSmoke".to_string(),
        project_kind: ProjectKind::Library,
        modules: vec![
            exposed_class(
                "W005ProbeEventSource",
                fixture_source("w005_probe_event_source.cls"),
            ),
            exposed_class(
                "W005ProbeEventHarness",
                fixture_source("w005_probe_event_harness.cls"),
            ),
        ],
        references: Vec::new(),
        reference_projects: Vec::new(),
        conditional_constants: Default::default(),
    }
}

fn prepare_event_smoke_session() -> oxvba_host::Vm3RuntimeSession {
    let manifest = event_smoke_manifest();
    let program = oxvba_bind::bind_program(&manifest, &oxvba_symbol::CatalogTypeLibResolver)
        .expect("bind W005 event smoke fixture");
    let bundle =
        oxvba_oxir::elaborate::elaborate(&program).expect("elaborate W005 event smoke fixture");

    let mut engine = Engine::new(HostConfig { enable_jit: false });
    engine.set_host_policy(HostPolicy::interactive_dev());
    engine
        .prepare_image_session(oxvba_oxir::OxImage::new(vec![bundle]))
        .expect("prepare W005 event smoke package session")
}

fn w005_probe_state() -> FormState {
    let mut state = FormState::new("form-main");
    state.controls = vec![
        ControlNode::label("label", LogicalRect::new(4.0, 4.0, 60.0, 16.0), 0)
            .with_caption("Probe Label"),
        ControlNode::text_box("text-1", LogicalRect::new(4.0, 24.0, 80.0, 18.0), 0, 0),
        ControlNode::command_button("ok", LogicalRect::new(4.0, 48.0, 44.0, 20.0), 0, 1)
            .with_caption("&OK"),
    ];
    state.default_button = Some(ControlId::new("ok"));
    state
}

fn mouse_button_event(left_down: bool, x: f64, y: f64) -> UiEvent {
    UiEvent::new(
        UiEventId(0),
        UiEventSource::Replay,
        UiEventKind::MouseDown(MouseButtonEvent {
            pointer_id: Some(PointerId(1)),
            button: MouseButton::Left,
            buttons_down: MouseButtons {
                left: left_down,
                ..MouseButtons::default()
            },
            modifiers: KeyboardModifiers::default(),
            click_count: ClickCount(1),
            coordinates: oxforms_pal::CoordinatePayload {
                form_logical: Some(LogicalPoint::new(x, y)),
                ..Default::default()
            },
        }),
    )
}

fn mouse_up_event(x: f64, y: f64) -> UiEvent {
    let mut event = mouse_button_event(false, x, y);
    let UiEventKind::MouseDown(payload) = event.kind else {
        unreachable!("mouse_button_event creates MouseDown")
    };
    event.kind = UiEventKind::MouseUp(payload);
    event
}

fn character_event(text: &str) -> UiEvent {
    UiEvent::new(
        UiEventId(0),
        UiEventSource::Replay,
        UiEventKind::CharacterInput(CharacterInputEvent {
            text: text.to_string(),
            modifiers: KeyboardModifiers {
                shift: true,
                ..KeyboardModifiers::default()
            },
            raw: Vec::new(),
        }),
    )
}

fn key_down_event() -> UiEvent {
    UiEvent::new(
        UiEventId(0),
        UiEventSource::Replay,
        UiEventKind::KeyDown(oxforms_pal::KeyEvent {
            key: oxforms_pal::KeyCode::Character("A".to_string()),
            modifiers: KeyboardModifiers {
                shift: true,
                ..KeyboardModifiers::default()
            },
            repeat: oxforms_pal::KeyRepeat::default(),
            raw: RawKeyDiagnostics {
                virtual_key: Some(0x41),
                scan_code: Some(0x1e),
                native_code: None,
                is_extended: Some(false),
            },
        }),
    )
}

fn key_up_event() -> UiEvent {
    UiEvent::new(
        UiEventId(0),
        UiEventSource::Replay,
        UiEventKind::KeyUp(oxforms_pal::KeyEvent {
            key: oxforms_pal::KeyCode::Character("A".to_string()),
            modifiers: KeyboardModifiers::default(),
            repeat: oxforms_pal::KeyRepeat::default(),
            raw: RawKeyDiagnostics::default(),
        }),
    )
}

fn with_event_id(mut event: UiEvent, id: u64) -> UiEvent {
    event.event_id = UiEventId(id);
    event
}

fn focus_validation_completed_event(form_id: &oxforms_pal::FormId, cancelled: bool) -> UiEvent {
    UiEvent::new(
        UiEventId(0),
        UiEventSource::Service,
        UiEventKind::FocusValidationCompleted(oxforms_pal::FocusValidationCompletedEvent {
            form_id: form_id.clone(),
            cancelled,
            dispatch_diagnostics: Vec::new(),
        }),
    )
}

fn dispatch_effects(
    session: &mut oxvba_host::Vm3RuntimeSession,
    source: ObjectRef,
    effects: &[oxforms_core::EffectRequest],
    next_dispatch_id: &mut u64,
    trace: &mut Vec<oxforms_oxvba_adapter::event_dispatch::VbaEventDispatchTraceRow>,
) {
    for effect in effects {
        if !matches!(effect.kind, EffectKind::FireVbaEvent { .. }) {
            continue;
        }

        *next_dispatch_id += 1;
        let request = AdapterDispatchRequest::from_effect(*next_dispatch_id, effect)
            .expect("W005 smoke effect should map to a VBA event raise method");
        trace.push(request.trace_row(AdapterDispatchCompletion::Requested));
        session
            .invoke_member_values(
                source.clone(),
                &request.raise_member,
                Some(ProjectMemberKind::Method),
                request
                    .to_oxvba_variants()
                    .expect("convert smoke event args to OxVba variants"),
            )
            .unwrap_or_else(|err| {
                panic!(
                    "raise {} for {:?}: {}",
                    request.event_name,
                    request.target,
                    err.message()
                )
            });
        trace.push(request.trace_row(AdapterDispatchCompletion::Succeeded));
    }
}

#[test]
fn w005_probe_effects_reach_vba_withevents_handlers_in_order() {
    let mut session = prepare_event_smoke_session();
    let source = session
        .create_class_instance("W005ProbeEventSource")
        .expect("create probe event source");
    let harness = session
        .create_class_instance("W005ProbeEventHarness")
        .expect("create probe event harness");
    session
        .invoke_member_values(
            harness.clone(),
            "Attach",
            Some(ProjectMemberKind::Method),
            vec![Variant::from_object_ref(source.clone())],
        )
        .expect("attach WithEvents sink to source");

    let mut dispatch_id = 0;
    let mut trace = Vec::new();

    let button_down = reduce(
        w005_probe_state(),
        with_event_id(mouse_button_event(true, 8.0, 52.0), 1),
    );
    dispatch_effects(
        &mut session,
        source.clone(),
        &button_down.effects,
        &mut dispatch_id,
        &mut trace,
    );

    let button_up = reduce(
        button_down.state,
        with_event_id(mouse_up_event(8.0, 52.0), 2),
    );
    dispatch_effects(
        &mut session,
        source.clone(),
        &button_up.effects,
        &mut dispatch_id,
        &mut trace,
    );

    let text_down = reduce(
        button_up.state,
        with_event_id(mouse_button_event(true, 8.0, 28.0), 3),
    );
    dispatch_effects(
        &mut session,
        source.clone(),
        &text_down.effects,
        &mut dispatch_id,
        &mut trace,
    );

    // Pressing text-1 moves focus off `ok`: Exit fires (dispatched above) and the focus
    // commit is held pending (oxforms-esq.4). ok_Exit does not veto, so fold the
    // uncancelled completion back to commit focus to text-1 before the key events route.
    let completion = focus_validation_completed_event(&text_down.state.form_id, false);
    let focus_committed = reduce(text_down.state, with_event_id(completion, 30));
    dispatch_effects(
        &mut session,
        source.clone(),
        &focus_committed.effects,
        &mut dispatch_id,
        &mut trace,
    );

    let key_down = reduce(focus_committed.state, with_event_id(key_down_event(), 4));
    dispatch_effects(
        &mut session,
        source.clone(),
        &key_down.effects,
        &mut dispatch_id,
        &mut trace,
    );

    let typed = reduce(key_down.state, with_event_id(character_event("A"), 5));
    dispatch_effects(
        &mut session,
        source.clone(),
        &typed.effects,
        &mut dispatch_id,
        &mut trace,
    );

    let key_up = reduce(typed.state, with_event_id(key_up_event(), 6));
    dispatch_effects(
        &mut session,
        source.clone(),
        &key_up.effects,
        &mut dispatch_id,
        &mut trace,
    );

    let log = session
        .invoke_member_values(
            harness,
            "LogText",
            Some(ProjectMemberKind::PropertyGet),
            Vec::new(),
        )
        .expect("read VBA handler log")
        .as_bstr()
        .expect("handler log should be a string")
        .as_str();
    let rows: Vec<_> = log.lines().collect();

    assert_eq!(
        rows,
        vec![
            // Pressing `ok` first focuses it: Enter on the gaining control before the
            // MouseDown event (oxforms-esq.6).
            "1|ok|Enter|no arguments",
            "2|ok|MouseDown|Button=1;Shift=0;X=4;Y=4",
            "3|ok|MouseUp|Button=1;Shift=0;X=4;Y=4",
            "4|ok|Click|no arguments",
            // Pressing text-1 moves focus off `ok`, firing Exit on the losing control
            // (oxforms-esq.2); the deferred commit then fires Enter on text-1, and the
            // deferred mouse press replays AFTER that Enter, so the focus-changing click
            // lands Exit -> Enter -> MouseDown -- the live W005 modeless oracle order
            // (seq 565-567 etc.; oxforms-esq.10 on the esq.4/esq.6 model).
            "5|ok|Exit|Cancel=False",
            "6|text-1|Enter|no arguments",
            "7|text-1|MouseDown|Button=1;Shift=0;X=4;Y=4",
            "8|text-1|KeyDown|key=character:A;Shift=1;modifiers=shift;repeat=false;raw_virtual_key=65;KeyCode=65;raw_scan_code=30",
            "9|text-1|KeyPress|text=A;KeyAscii=65;modifiers=shift",
            "10|text-1|Change|no arguments",
            "11|text-1|KeyUp|key=character:A;Shift=0;modifiers=none;repeat=false",
        ],
        "VBA handler should observe reducer event order and serialized W005 smoke args"
    );

    let succeeded: Vec<_> = trace
        .iter()
        .filter(|row| row.completion == AdapterDispatchCompletion::Succeeded)
        .collect();
    assert_eq!(succeeded.len(), 11);
    assert!(succeeded
        .iter()
        .all(|row| row.fact_source.as_deref() == Some("docs/specs/FM20_EVENT_FACTS.md")));
    assert!(succeeded.iter().any(|row| {
        row.event_name == "KeyDown"
            && row
                .argument_summary
                .contains(&"modifiers=shift:byval".to_string())
            // Key events now carry a dispatch-ready Shift mask (by_ref scalar) and a
            // mutable KeyCode -- the MSForms.ReturnInteger value native KeyDown
            // dispatch passes to PerformKeyDown and reads back (oxforms-esq.2),
            // consistent with the clean mouse-event arg shape.
            && row
                .argument_summary
                .contains(&"Shift=1:byval".to_string())
            && row
                .argument_summary
                .contains(&"KeyCode=65:byref_or_mutable".to_string())
    }));
    assert!(succeeded.iter().any(|row| {
        row.event_name == "KeyUp"
            && row
                .argument_summary
                .contains(&"modifiers=none:byval".to_string())
            && row.argument_summary.contains(&"Shift=0:byval".to_string())
    }));
    assert!(succeeded.iter().any(|row| {
        row.event_name == "KeyPress"
            && row
                .argument_summary
                .contains(&"KeyAscii=65:byref_or_mutable".to_string())
            && row.cancel_metadata.as_deref().is_some_and(|metadata| {
                metadata.contains("PerformKeyPress") && metadata.contains("deferred")
            })
    }));
}
