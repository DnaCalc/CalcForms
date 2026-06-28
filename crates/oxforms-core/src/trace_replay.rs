use std::collections::BTreeMap;

use oxforms_pal::{
    ActivationReason, CharacterInputEvent, ClickCount, ClipboardOperation, CloseQueryPolicy,
    CloseReason, CloseRequestEvent, CloseRequestOrigin, ControlId, CoordinatePayload,
    CoordinatePoint, CoordinateSpace, DataObjectSnapshot, DpiScale, DropOrPasteOrigin,
    FocusValidationCompletedEvent, FormId, KeyCode, KeyEvent, KeyRepeat, KeyboardModifiers,
    LifecycleReason, LogicalPoint, LogicalRect, MouseButton, MouseButtonEvent, MouseButtons,
    PointerId, PumpFrameExitedEvent, QueryCloseCompletedEvent, RawCoordinateSample, RawDiagnostic,
    RawKeyDiagnostics, ServiceOutcome, ServicePayload, ShowMode, ShowRequestedEvent, UiEvent,
    UiEventId, UiEventKind, UiEventSource, UiEventTarget, UnloadedEvent, WindowHiddenEvent,
    WindowId, WindowShownEvent, UI_EVENT_SCHEMA_VERSION,
};
use serde_json::{json, Value};

use crate::{
    hit_test_control_tree, ControlNode, DirtyRegionSpace, EffectKind, EffectRequest, FocusTarget,
    FormState, InvalidationReason, LifecycleState, PumpTerm, ReducerOutput, StateSummary,
};

pub const W005_TRACE_REPLAY_GOLDEN_TRACE_PATH: &str =
    "docs/evidence/W005_input_interaction_model_exploration/trace-replay/w005-headless-probe-replay.golden.v1.json";
pub const W006_MODAL_FRAME_TRACE_PATH: &str =
    "docs/evidence/W006_control_implementation_rollout/trace-replay/modal-frame-subset.synthetic.v1.json";

const BEAD: &str = "oxforms-0a0.3";
const W006_MODAL_BEAD: &str = "oxforms-0a0.22";
const TRACE_ID: &str = "w005-headless-probe-replay-golden-v1";
const W006_MODAL_TRACE_ID: &str = "w006-modal-frame-subset-synthetic-v1";
const FORM_ID: &str = "form-main";
const WINDOW_ID: &str = "window-main";
const SURFACE_WIDTH: u32 = 260;
const SURFACE_HEIGHT: u32 = 128;
const DPI: f64 = 96.0;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct W005TraceReplayGoldenArtifacts {
    pub trace_json: String,
}

#[must_use]
pub fn build_w005_trace_replay_golden_artifacts() -> W005TraceReplayGoldenArtifacts {
    let mut runner = W005TraceReplayRunner::new();
    runner.run();
    runner.finish()
}

#[must_use]
pub fn build_w006_modal_frame_trace_subset_artifact() -> String {
    let mut runner = W005TraceReplayRunner::new();
    runner.run_w006_modal_frame_subset();
    runner.finish_w006_modal_frame_subset()
}

struct W005TraceReplayRunner {
    state: FormState,
    sequence: u64,
    row_index: u64,
    next_ui_event_id: u64,
    dispatch_index: u64,
    rows: Vec<Value>,
    effect_row_ids: BTreeMap<u64, String>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum EffectCompletionParent {
    None,
    EffectRequestRow,
}

impl W005TraceReplayRunner {
    fn new() -> Self {
        let mut state = FormState::new(FORM_ID);
        state.controls = vec![
            ControlNode::label("label-title", LogicalRect::new(12.0, 12.0, 96.0, 24.0), 0)
                .with_caption("W005"),
            ControlNode::text_box("text-1", LogicalRect::new(12.0, 52.0, 124.0, 28.0), 0, 0),
            ControlNode::command_button("ok", LogicalRect::new(160.0, 52.0, 72.0, 28.0), 0, 1)
                .with_caption("&OK"),
        ];
        state.default_button = Some(ControlId::new("ok"));

        Self {
            state,
            sequence: 1,
            row_index: 1,
            next_ui_event_id: 1,
            dispatch_index: 1,
            rows: Vec::new(),
            effect_row_ids: BTreeMap::new(),
        }
    }

    fn run(&mut self) {
        self.push_script_step(
            "script-0001",
            "show_form_modeless",
            json!({ "form_id": FORM_ID }),
            None,
        );
        self.apply_next_event(show_requested_event);
        self.complete_non_dispatch_effects();
        self.apply_next_event(window_shown_event);
        self.record_lifecycle_pump(
            "showing_modeless",
            "modeless_visible",
            "host_modeless_pump",
            "window_shown_event",
        );
        self.complete_non_dispatch_effects();

        self.push_script_step(
            "script-0002",
            "mouse_click",
            json!({ "form_id": FORM_ID, "control_id": "text-1" }),
            Some(LogicalPoint::new(20.0, 60.0)),
        );
        self.apply_next_event(|event_id| mouse_button_event(event_id, 20.0, 60.0, true));
        self.complete_non_dispatch_effects();
        self.apply_next_event(|event_id| mouse_button_event(event_id, 20.0, 60.0, false));
        self.complete_non_dispatch_effects();

        self.push_script_step(
            "script-0003",
            "type_committed_text",
            json!({ "form_id": FORM_ID, "control_id": "text-1" }),
            None,
        );
        self.apply_next_event(|event_id| character_key_event(event_id, "A", true));
        self.complete_non_dispatch_effects();
        self.apply_next_event(|event_id| character_event(event_id, "A"));
        self.complete_non_dispatch_effects();
        self.apply_next_event(|event_id| character_key_event(event_id, "A", false));
        self.complete_non_dispatch_effects();
        self.apply_next_event(|event_id| character_key_event(event_id, "B", true));
        self.complete_non_dispatch_effects();
        self.apply_next_event(|event_id| character_event(event_id, "B"));
        self.complete_non_dispatch_effects();
        self.apply_next_event(|event_id| character_key_event(event_id, "B", false));
        self.complete_non_dispatch_effects();

        self.push_script_step(
            "script-0004",
            "navigate_textbox",
            json!({ "form_id": FORM_ID, "control_id": "text-1" }),
            None,
        );
        self.apply_next_event(|event_id| navigation_key_event(event_id, KeyCode::ArrowLeft));
        self.complete_non_dispatch_effects();
        self.apply_next_event(|event_id| navigation_key_up_event(event_id, KeyCode::ArrowLeft));
        self.complete_non_dispatch_effects();
        self.apply_next_event(|event_id| navigation_key_event(event_id, KeyCode::Delete));
        self.complete_non_dispatch_effects();
        self.apply_next_event(|event_id| navigation_key_up_event(event_id, KeyCode::Delete));
        self.complete_non_dispatch_effects();
        self.apply_next_event(|event_id| navigation_key_event(event_id, KeyCode::Home));
        self.complete_non_dispatch_effects();
        self.apply_next_event(|event_id| navigation_key_up_event(event_id, KeyCode::Home));
        self.complete_non_dispatch_effects();
        self.apply_next_event(|event_id| navigation_key_event(event_id, KeyCode::End));
        self.complete_non_dispatch_effects();
        self.apply_next_event(|event_id| navigation_key_up_event(event_id, KeyCode::End));
        self.complete_non_dispatch_effects();
        self.apply_next_event(|event_id| navigation_key_event(event_id, KeyCode::Backspace));
        self.complete_non_dispatch_effects();
        self.apply_next_event(|event_id| navigation_key_up_event(event_id, KeyCode::Backspace));
        self.complete_non_dispatch_effects();

        self.push_script_step(
            "script-0005",
            "mouse_click",
            json!({ "form_id": FORM_ID, "control_id": "ok" }),
            Some(LogicalPoint::new(176.0, 64.0)),
        );
        self.apply_next_event(|event_id| mouse_button_event(event_id, 176.0, 64.0, true));
        self.complete_non_dispatch_effects();
        // Clicking "ok" moves focus off "text-1": Exit fires and the focus commit is held
        // pending the veto (oxforms-esq.4). The runtime folds the (uncancelled) Exit
        // readback back as FocusValidationCompleted, which commits the transfer to "ok".
        self.apply_next_event(focus_validation_completed_event);
        self.complete_non_dispatch_effects();
        self.apply_next_event(|event_id| mouse_button_event(event_id, 176.0, 64.0, false));
        self.complete_non_dispatch_effects();

        self.push_script_step(
            "script-0006",
            "close_modeless_form",
            json!({
                "form_id": FORM_ID,
                "origin": "close_button",
                "oracle_evidence": "docs/evidence/W005_input_interaction_model_exploration/captures/interaction-events-20260623T004914Z/modeless-event-log.json",
                "dispatch_blocker": "docs/evidence/W006_control_implementation_rollout/native-fm20-event-dispatch-blocker.md"
            }),
            None,
        );
        self.apply_next_event(close_request_event);
        self.record_lifecycle_pump(
            "active",
            "query_close_pending",
            "close_unload_cancellation",
            "close_request",
        );
        self.complete_non_dispatch_effects();
        self.apply_next_event(query_close_completed_event);
        self.record_lifecycle_pump(
            "query_close_pending",
            "hide_pending",
            "close_unload_cancellation",
            "query_close_completed",
        );
        self.complete_non_dispatch_effects();
        self.apply_next_event(window_hidden_event);
        self.record_lifecycle_pump(
            "hide_pending",
            "unloading",
            "close_unload_cancellation",
            "window_hidden",
        );
        self.complete_non_dispatch_effects();
        self.apply_next_event(unloaded_event);
        self.record_lifecycle_pump("unloading", "hidden", "host_modeless_pump", "unloaded");
    }

    fn run_w006_modal_frame_subset(&mut self) {
        self.push_script_step(
            "script-0001",
            "show_form_modal",
            json!({
                "form_id": FORM_ID,
                "subset": "synthetic_host_neutral_modal_frame",
                "not_live_msforms_parity": true
            }),
            None,
        );
        self.apply_next_event(modal_show_requested_event);
        let show_modal_row = self
            .expect_pending_effect_row_id(|kind| matches!(kind, EffectKind::ShowFormModal { .. }));

        self.record_lifecycle_pump_with_parent(
            "allocated",
            "showing_modal",
            "modal_frame",
            "show_requested_enter_modal_frame",
            Some(show_modal_row.clone()),
            1,
        );
        self.complete_pending_effects_matching(
            |effect| matches!(effect.kind, EffectKind::CreateWindowSurface { .. }),
            |_| "diagnostic_only",
            EffectCompletionParent::EffectRequestRow,
            1,
            |_| modal_subset_diagnostics(),
        );

        self.apply_next_event_with_trace_parent(
            modal_window_shown_event,
            Some(show_modal_row.clone()),
            1,
        );
        self.record_lifecycle_pump_with_parent(
            "showing_modal",
            "modal_visible",
            "modal_frame",
            "window_shown_event",
            Some(show_modal_row.clone()),
            1,
        );

        self.push_script_step_with_parent(
            "script-0002",
            "mouse_click_inside_modal_frame",
            json!({
                "form_id": FORM_ID,
                "control_id": "ok",
                "modal_depth": self.state.pump.nested_modal_depth
            }),
            Some(LogicalPoint::new(176.0, 64.0)),
            Some(show_modal_row.clone()),
            1,
        );
        self.apply_next_event_with_trace_parent(
            |event_id| mouse_button_event(event_id, 176.0, 64.0, true),
            Some(show_modal_row.clone()),
            1,
        );
        self.complete_pending_effects_matching(
            |effect| {
                matches!(
                    effect.kind,
                    EffectKind::FireVbaEvent { .. }
                        | EffectKind::RequestRepaint { .. }
                        | EffectKind::CaptureMouse { .. }
                        | EffectKind::ReleaseMouse { .. }
                        | EffectKind::TransferFocus { .. }
                )
            },
            headless_effect_completion_status,
            EffectCompletionParent::EffectRequestRow,
            2,
            |_| Vec::new(),
        );
        self.apply_next_event_with_trace_parent(
            |event_id| mouse_button_event(event_id, 176.0, 64.0, false),
            Some(show_modal_row.clone()),
            1,
        );
        self.complete_pending_effects_matching(
            |effect| {
                matches!(
                    effect.kind,
                    EffectKind::FireVbaEvent { .. }
                        | EffectKind::RequestRepaint { .. }
                        | EffectKind::CaptureMouse { .. }
                        | EffectKind::ReleaseMouse { .. }
                        | EffectKind::TransferFocus { .. }
                )
            },
            headless_effect_completion_status,
            EffectCompletionParent::EffectRequestRow,
            2,
            |_| Vec::new(),
        );

        self.push_script_step_with_parent(
            "script-0003",
            "pump_frame_exited",
            json!({
                "form_id": FORM_ID,
                "modal_depth": self.state.pump.nested_modal_depth,
                "exit_reason": "synthetic_replay_exit_without_live_window"
            }),
            None,
            Some(show_modal_row.clone()),
            1,
        );
        self.apply_next_event_with_trace_parent(
            pump_frame_exited_event,
            Some(show_modal_row.clone()),
            1,
        );
        self.record_lifecycle_pump_with_parent(
            "modal_visible",
            "modal_visible",
            "host_modeless_pump",
            "pump_frame_exited",
            Some(show_modal_row),
            1,
        );
        self.complete_pending_effects_matching(
            |effect| matches!(effect.kind, EffectKind::ExitModalFrame { .. }),
            |_| "synthetic_pump_frame_exit_recorded",
            EffectCompletionParent::EffectRequestRow,
            2,
            |_| modal_subset_diagnostics(),
        );
        self.complete_pending_effects_matching(
            |effect| {
                matches!(
                    effect.kind,
                    EffectKind::EnterModalFrame { .. } | EffectKind::ShowFormModal { .. }
                )
            },
            |_| "completed_after_pump_frame_exited",
            EffectCompletionParent::EffectRequestRow,
            1,
            |_| modal_subset_diagnostics(),
        );
    }

    fn finish(self) -> W005TraceReplayGoldenArtifacts {
        let artifact = json!({
            "schema": "oxforms.trace_replay.v1",
            "schema_version": 1,
            "trace_id": TRACE_ID,
            "bead": BEAD,
            "artifact_status": "oxforms_golden",
            "scenario": {
                "scenario_id": "w005.oxforms.headless.probe-click-type-click",
                "source_kind": "oxforms_headless",
                "description": "Deterministic headless replay of the W005 Label/TextBox/CommandButton probe path through oxforms-pal UiEvent rows, oxforms-core reduce(), probe display-list emission, and PAL headless render hashing.",
                "not_oracle_evidence": true,
                "input_script": input_script_summary()
            },
            "environment": {
                "source": "oxforms_headless_replay_runner",
                "recorded_at_utc": null,
                "os": {
                    "name": "not_required",
                    "version": null,
                    "is_windows": null
                },
                "host": {
                    "name": "none",
                    "scope_id": null,
                    "requires_excel_or_msforms": false,
                    "requires_live_desktop": false
                },
                "pal": {
                    "input_contract": "crates/oxforms-pal/src/input.rs",
                    "ui_event_schema_version": UI_EVENT_SCHEMA_VERSION
                },
                "display": {
                    "surface_width": SURFACE_WIDTH,
                    "surface_height": SURFACE_HEIGHT,
                    "dpi_x": DPI,
                    "dpi_y": DPI,
                    "scale_x": 1.0,
                    "scale_y": 1.0,
                    "projection": "form_logical_points_to_pal_smoke_fill_rects"
                },
                "runner": {
                    "implementation": "crates/oxforms-core/src/trace_replay.rs",
                    "golden_trace_path": W005_TRACE_REPLAY_GOLDEN_TRACE_PATH
                },
                "path_policy": "canonical_artifact_paths_are_repo_relative"
            },
            "ordering": {
                "sequence_scope": "trace",
                "clock": "logical_tick",
                "nesting_model": "parent_row_id_and_nesting_depth",
                "first_sequence": 1
            },
            "rows": self.rows,
            "artifacts": {
                "screenshots": [],
                "external_files": [
                    {
                        "artifact_id": "golden-trace-json",
                        "role": "committed canonical golden trace generated by the W005 headless replay runner",
                        "storage": "repo_file",
                        "path": W005_TRACE_REPLAY_GOLDEN_TRACE_PATH,
                        "uri_fragment": null,
                        "sha256": null,
                        "notes": "File checksum is recorded in trace-replay/checksums.sha256."
                    }
                ]
            },
            "clean_room": {
                "source": "Repo-authored deterministic OxForms replay over crates/oxforms-pal and crates/oxforms-core W005 probe code.",
                "prohibited": "No Office internals, decompilation, disassembly, non-public source, live Excel/MSForms, or live desktop input were used."
            },
            "warnings": [
                "This golden is OxForms headless regression evidence, not MSForms oracle evidence.",
                "VBA dispatch rows are metadata reconstructed from reducer FireVbaEvent effects; no OxVba or VBA handler is executed by this headless runner.",
                "The render hash is the PAL smoke FillRect projection hash, not text or pixel parity evidence."
            ]
        });

        W005TraceReplayGoldenArtifacts {
            trace_json: pretty_json(&artifact),
        }
    }

    fn finish_w006_modal_frame_subset(self) -> String {
        let artifact = json!({
            "schema": "oxforms.trace_replay.v1",
            "schema_version": 1,
            "trace_id": W006_MODAL_TRACE_ID,
            "bead": W006_MODAL_BEAD,
            "artifact_status": "synthetic_host_neutral_trace_subset",
            "scenario": {
                "scenario_id": "w006.oxforms.synthetic.modal-frame-subset",
                "source_kind": "oxforms_headless",
                "description": "Synthetic host-neutral OxForms modal-frame trace subset exercising ShowFormModal, EnterModalFrame, modal-frame input, PumpFrameExited, ExitModalFrame, modal_depth, parent_row_id, nesting_depth, effect_requested, effect_completed, and lifecycle_pump rows without live windows or MSForms parity claims.",
                "not_oracle_evidence": true,
                "synthetic_host_neutral": true,
                "not_live_msforms_modal_parity": true,
                "input_script": input_script_summary_w006_modal_frame()
            },
            "environment": {
                "source": "oxforms_headless_replay_runner",
                "recorded_at_utc": null,
                "os": {
                    "name": "not_required",
                    "version": null,
                    "is_windows": null
                },
                "host": {
                    "name": "none",
                    "scope_id": null,
                    "requires_excel_or_msforms": false,
                    "requires_live_desktop": false
                },
                "pal": {
                    "input_contract": "crates/oxforms-pal/src/input.rs",
                    "ui_event_schema_version": UI_EVENT_SCHEMA_VERSION,
                    "live_modal_window_runtime": false
                },
                "display": {
                    "surface_width": SURFACE_WIDTH,
                    "surface_height": SURFACE_HEIGHT,
                    "dpi_x": DPI,
                    "dpi_y": DPI,
                    "scale_x": 1.0,
                    "scale_y": 1.0,
                    "projection": "form_logical_points_to_pal_smoke_fill_rects"
                },
                "runner": {
                    "implementation": "crates/oxforms-core/src/trace_replay.rs",
                    "golden_trace_path": W006_MODAL_FRAME_TRACE_PATH
                },
                "path_policy": "canonical_artifact_paths_are_repo_relative"
            },
            "ordering": {
                "sequence_scope": "trace",
                "clock": "logical_tick",
                "nesting_model": "parent_row_id_and_nesting_depth",
                "first_sequence": 1,
                "modal_completion_policy": "ShowFormModal and EnterModalFrame effect_completed rows are emitted only after PumpFrameExited and ExitModalFrame in this synthetic subset."
            },
            "rows": self.rows,
            "artifacts": {
                "screenshots": [],
                "external_files": [
                    {
                        "artifact_id": "w006-modal-frame-subset-trace-json",
                        "role": "committed synthetic host-neutral modal-frame trace subset generated by the OxForms headless replay runner",
                        "storage": "repo_file",
                        "path": W006_MODAL_FRAME_TRACE_PATH,
                        "uri_fragment": null,
                        "sha256": null,
                        "notes": "No live PAL modal window runtime or OxVba caller-side modal blocking/resume is executed by this artifact."
                    }
                ]
            },
            "clean_room": {
                "source": "Repo-authored deterministic OxForms replay over crates/oxforms-pal and crates/oxforms-core modal reducer/effect metadata.",
                "prohibited": "No Office internals, decompilation, disassembly, non-public source, live Excel/MSForms, live modal windows, or live desktop input were used."
            },
            "warnings": [
                "This artifact is synthetic host-neutral OxForms trace/replay evidence, not live MSForms modal parity evidence.",
                "No live modal window pump/runtime behavior is introduced or executed by this runner.",
                "OxVba caller-side UserForm.Show blocking/resume semantics, native FM20-named dispatch, QueryClose mutation, DoEvents, and object-lifetime Terminate timing remain outside this subset.",
                "PAL/effect-runner live modal frame enter/exit completions remain implementation blockers for runtime parity; this runner records replayable rows only."
            ]
        });

        pretty_json(&artifact)
    }

    fn next_event_id(&mut self) -> UiEventId {
        let id = UiEventId(self.next_ui_event_id);
        self.next_ui_event_id += 1;
        id
    }

    fn apply_next_event(&mut self, build: impl FnOnce(UiEventId) -> UiEvent) {
        let event_id = self.next_event_id();
        let event = build(event_id);
        self.apply_event(event);
    }

    fn apply_next_event_with_trace_parent(
        &mut self,
        build: impl FnOnce(UiEventId) -> UiEvent,
        parent_row_id: Option<String>,
        nesting_depth: u32,
    ) -> String {
        let event_id = self.next_event_id();
        let event = build(event_id);
        self.apply_event_with_trace_parent(event, parent_row_id, nesting_depth)
    }

    fn push_script_step(
        &mut self,
        script_step_id: &str,
        action: &str,
        target: Value,
        point: Option<LogicalPoint>,
    ) {
        self.push_script_step_with_parent(script_step_id, action, target, point, None, 0);
    }

    fn push_script_step_with_parent(
        &mut self,
        script_step_id: &str,
        action: &str,
        target: Value,
        point: Option<LogicalPoint>,
        parent_row_id: Option<String>,
        nesting_depth: u32,
    ) {
        let mut payload = json!({
            "script_step_id": script_step_id,
            "action": action,
            "target": target
        });
        if let Some(point) = point {
            payload["coordinates"] = json!([coordinate_point(
                "form_logical",
                "points",
                "form_design_surface_top_left",
                point.x,
                point.y,
                "replay.script",
                "synthetic"
            )]);
        }
        self.push_row(
            "script",
            "input_script_step",
            payload,
            parent_row_id,
            nesting_depth,
        );
    }

    fn apply_event(&mut self, event: UiEvent) {
        self.apply_event_with_trace_parent(event, None, 0);
    }

    fn apply_event_with_trace_parent(
        &mut self,
        event: UiEvent,
        parent_row_id: Option<String>,
        nesting_depth: u32,
    ) -> String {
        let route = route_summary(&self.state, &event);
        let ui_row_id = self.push_row(
            "input",
            "ui_event",
            ui_event_payload(&event, &route),
            parent_row_id.clone(),
            nesting_depth,
        );

        if let Some(route_payload) = route.as_ref().map(RouteSummary::to_payload) {
            self.push_row(
                "routing",
                "routing_decision",
                route_payload,
                parent_row_id.clone(),
                nesting_depth,
            );
        }

        let output = crate::reduce(self.state.clone(), event);
        self.push_reducer_transition(&output, parent_row_id.clone(), nesting_depth);
        self.push_effect_requests(&output.effects, parent_row_id.clone(), nesting_depth);
        self.push_invalidations(&output, parent_row_id, nesting_depth);
        self.state = output.state;
        ui_row_id
    }

    fn push_reducer_transition(
        &mut self,
        output: &ReducerOutput,
        parent_row_id: Option<String>,
        nesting_depth: u32,
    ) {
        self.push_row(
            "reducer",
            "reducer_transition",
            json!({
                "transition_id": transition_id(output.transition.transition_id.0),
                "causal_ui_event_id": ui_event_id(output.transition.causal_ui_event_id.0),
                "before": state_summary_json(&output.transition.before),
                "after": state_summary_json(&output.transition.after),
                "emitted_effect_ids": output
                    .transition
                    .emitted_effect_ids
                    .iter()
                    .map(|id| effect_id(id.0))
                    .collect::<Vec<_>>(),
                "invalidation_ids": output
                    .transition
                    .invalidation_ids
                    .iter()
                    .map(|id| invalidation_id(id.0))
                    .collect::<Vec<_>>()
            }),
            parent_row_id,
            nesting_depth,
        );
    }

    fn push_effect_requests(
        &mut self,
        effects: &[EffectRequest],
        parent_row_id: Option<String>,
        nesting_depth: u32,
    ) {
        for effect in effects {
            let row_id = self.push_row(
                "effect",
                "effect_requested",
                effect_requested_payload(effect),
                parent_row_id.clone(),
                nesting_depth,
            );
            self.effect_row_ids
                .insert(effect.effect_id.0, row_id.clone());
            if matches!(effect.kind, EffectKind::FireVbaEvent { .. }) {
                self.push_vba_dispatch(effect, row_id, nesting_depth + 1);
            }
        }
    }

    fn push_vba_dispatch(
        &mut self,
        effect: &EffectRequest,
        parent_row_id: String,
        nesting_depth: u32,
    ) {
        let EffectKind::FireVbaEvent {
            event_name,
            fact_source,
            arguments,
            cancel_metadata,
        } = &effect.kind
        else {
            return;
        };

        let dispatch_id_value = format!("dispatch-{:04}", self.dispatch_index);
        self.dispatch_index += 1;
        self.push_row(
            "dispatch",
            "vba_dispatch",
            json!({
                "dispatch_id": dispatch_id_value,
                "effect_id": effect_id(effect.effect_id.0),
                "event_name": event_name,
                "target": target_json(&effect.target),
                "fact_source": {
                    "path": fact_source
                        .as_deref()
                        .unwrap_or("docs/specs/FM20_EVENT_FACTS.md"),
                    "event": event_name,
                    "evidence_class": "reducer_effect_metadata"
                },
                "arguments": arguments
                    .iter()
                    .map(|argument| {
                        json!({
                            "name": argument.name,
                            "value": argument.value,
                            "by_ref": argument.by_ref
                        })
                    })
                    .collect::<Vec<_>>(),
                "mutable_helpers": arguments
                    .iter()
                    .filter(|argument| argument.by_ref)
                    .map(|argument| {
                        json!({
                            "name": argument.name,
                            "before": argument.value,
                            "after": argument.value,
                            "mutation_status": "not_executed_headless_replay"
                        })
                    })
                    .collect::<Vec<_>>(),
                "result": {
                    "status": "not_executed_headless_replay",
                    "handler": null,
                    "cancel_metadata": cancel_metadata,
                    "note": "Headless replay records the reducer FireVbaEvent request but does not run OxVba or a VBA handler."
                }
            }),
            Some(parent_row_id),
            nesting_depth,
        );
    }

    fn push_invalidations(
        &mut self,
        output: &ReducerOutput,
        parent_row_id: Option<String>,
        nesting_depth: u32,
    ) {
        for invalidation in &output.invalidations {
            self.push_row(
                "render",
                "invalidation",
                json!({
                    "invalidation_id": invalidation_id(invalidation.invalidation_id.0),
                    "target": target_json(&invalidation.target),
                    "reason": invalidation_reason(invalidation.reason),
                    "regions": invalidation
                        .regions
                        .iter()
                        .map(|region| {
                            let (space, origin) = match region.space {
                                DirtyRegionSpace::DisplayListLogical => (
                                    "display_list_logical",
                                    "form_design_surface_top_left",
                                ),
                                DirtyRegionSpace::FormLogical => (
                                    "form_logical",
                                    "form_design_surface_top_left",
                                ),
                            };
                            json!({
                                "space": space,
                                "unit": "points",
                                "origin": origin,
                                "rect": {
                                    "x": region.rect.x,
                                    "y": region.rect.y,
                                    "width": region.rect.width,
                                    "height": region.rect.height
                                },
                                "dpi": dpi_json(),
                                "source": format!("reducer.{}", transition_id(output.transition.transition_id.0)),
                                "certainty": "observed"
                            })
                        })
                        .collect::<Vec<_>>(),
                    "dirty_subtrees": invalidation
                        .dirty_subtrees
                        .iter()
                        .map(target_json)
                        .collect::<Vec<_>>()
                }),
                parent_row_id.clone(),
                nesting_depth,
            );
        }
    }

    fn complete_non_dispatch_effects(&mut self) {
        self.complete_pending_effects_matching(
            |_| true,
            headless_effect_completion_status,
            EffectCompletionParent::None,
            0,
            |_| Vec::new(),
        );
    }

    fn complete_pending_effects_matching(
        &mut self,
        mut should_complete: impl FnMut(&EffectRequest) -> bool,
        mut status_for: impl FnMut(&EffectRequest) -> &'static str,
        parent: EffectCompletionParent,
        nesting_depth: u32,
        mut diagnostics_for: impl FnMut(&EffectRequest) -> Vec<Value>,
    ) {
        let pending = std::mem::take(&mut self.state.pending_effects);
        let mut remaining = Vec::new();
        for effect in pending {
            if should_complete(&effect) {
                let parent_row_id = match parent {
                    EffectCompletionParent::None => None,
                    EffectCompletionParent::EffectRequestRow => Some(
                        self.effect_row_ids
                            .get(&effect.effect_id.0)
                            .cloned()
                            .expect("effect completion should have a recorded request row"),
                    ),
                };
                self.push_effect_completion(
                    &effect,
                    status_for(&effect),
                    parent_row_id,
                    nesting_depth,
                    diagnostics_for(&effect),
                );
            } else {
                remaining.push(effect);
            }
        }
        self.state.pending_effects = remaining;
    }

    fn push_effect_completion(
        &mut self,
        effect: &EffectRequest,
        status: &str,
        parent_row_id: Option<String>,
        nesting_depth: u32,
        diagnostics: Vec<Value>,
    ) {
        self.push_row(
            "effect",
            "effect_completed",
            json!({
                "effect_id": effect_id(effect.effect_id.0),
                "status": status,
                "result": {
                    "runner": "oxforms-core headless trace replay",
                    "effect_kind": effect_kind_name(&effect.kind)
                },
                "diagnostics": diagnostics
            }),
            parent_row_id,
            nesting_depth,
        );
    }

    fn expect_pending_effect_row_id(
        &self,
        mut matches_kind: impl FnMut(&EffectKind) -> bool,
    ) -> String {
        self.state
            .pending_effects
            .iter()
            .find(|effect| matches_kind(&effect.kind))
            .and_then(|effect| self.effect_row_ids.get(&effect.effect_id.0))
            .cloned()
            .expect("expected pending effect row id")
    }

    fn record_lifecycle_pump(&mut self, before: &str, after: &str, pump_term: &str, cause: &str) {
        self.record_lifecycle_pump_with_parent(before, after, pump_term, cause, None, 0);
    }

    fn record_lifecycle_pump_with_parent(
        &mut self,
        before: &str,
        after: &str,
        pump_term: &str,
        cause: &str,
        parent_row_id: Option<String>,
        nesting_depth: u32,
    ) {
        self.push_row(
            "pump",
            "lifecycle_pump",
            json!({
                "lifecycle_state_before": before,
                "lifecycle_state_after": after,
                "pump_term": pump_term,
                "modal_depth": self.state.pump.nested_modal_depth,
                "active": {
                    "form_id": self.state.active.active_form.as_ref().map(|id| id.0.as_str()),
                    "window_id": self.state.active.active_window.as_ref().map(|id| id.0.as_str()),
                    "focus_owner": self.state.focus_owner.as_ref().map(focus_target_label)
                },
                "close_flow": self.state.close_flow.as_ref().map(|flow| {
                    json!({
                        "origin": close_request_origin(flow.origin),
                        "reason": close_reason(flow.reason),
                        "close_mode": flow.close_mode,
                        "cancelled": flow.cancelled,
                        "awaiting_window_hide_for_unload": flow.awaiting_window_hide_for_unload
                    })
                }),
                "cause": {
                    "runner": cause
                }
            }),
            parent_row_id,
            nesting_depth,
        );
    }

    fn push_row(
        &mut self,
        phase: &str,
        kind: &str,
        payload: Value,
        parent_row_id: Option<String>,
        nesting_depth: u32,
    ) -> String {
        let row_id = format!("row-{:04}", self.row_index);
        self.row_index += 1;
        let logical_tick = self.sequence - 1;
        self.rows.push(json!({
            "row_id": row_id,
            "sequence": self.sequence,
            "logical_tick": logical_tick,
            "parent_row_id": parent_row_id,
            "nesting_depth": nesting_depth,
            "phase": phase,
            "kind": kind,
            "payload": payload
        }));
        self.sequence += 1;
        row_id
    }
}

#[derive(Clone, Debug)]
struct RouteSummary {
    route_kind: &'static str,
    causal_ui_event_id: String,
    selected_target: UiEventTarget,
    control_local: Option<LogicalPoint>,
    capture_owner_before: Option<String>,
    capture_owner_after: Option<String>,
    considered: Vec<Value>,
}

impl RouteSummary {
    fn to_payload(&self) -> Value {
        json!({
            "routing_id": format!("route-for-{}", self.causal_ui_event_id),
            "causal_ui_event_id": self.causal_ui_event_id,
            "route_kind": self.route_kind,
            "selected_target": target_json(&self.selected_target),
            "considered": self.considered,
            "capture_owner_before": self.capture_owner_before,
            "capture_owner_after": self.capture_owner_after
        })
    }
}

fn route_summary(state: &FormState, event: &UiEvent) -> Option<RouteSummary> {
    match &event.kind {
        UiEventKind::MouseDown(payload) | UiEventKind::MouseUp(payload) => {
            let capture_owner_before = state
                .capture_owner
                .as_ref()
                .map(|owner| focus_target_label(&owner.target));
            let point = payload.coordinates.form_logical?;
            let capture_target = state
                .capture_owner
                .as_ref()
                .and_then(|owner| target_for_focus(&owner.target, &state.form_id));
            let hit = hit_test_control_tree(&state.controls, point);
            let selected_target = capture_target
                .clone()
                .or_else(|| {
                    hit.as_ref()
                        .map(|hit| UiEventTarget::control(FORM_ID, hit.control_id.0.clone()))
                })
                .unwrap_or_else(|| UiEventTarget::form(FORM_ID));
            let control_local = hit.as_ref().map(|hit| hit.control_local);
            let capture_owner_after = match &event.kind {
                UiEventKind::MouseDown(_) => selected_target
                    .control_id
                    .as_ref()
                    .map(|control_id| control_id.0.clone()),
                UiEventKind::MouseUp(_) => None,
                _ => unreachable!(),
            };
            Some(RouteSummary {
                route_kind: if capture_target.is_some() {
                    "mouse_capture"
                } else {
                    "mouse_hit_test"
                },
                causal_ui_event_id: ui_event_id(event.event_id.0),
                selected_target,
                control_local,
                capture_owner_before,
                capture_owner_after,
                considered: state
                    .controls
                    .iter()
                    .map(|control| {
                        json!({
                            "control_id": control.control_id.0,
                            "hit": control.contains_form_logical(point),
                            "visible": control.visible,
                            "enabled": control.enabled,
                            "z_order": control.z_order
                        })
                    })
                    .collect(),
            })
        }
        UiEventKind::KeyDown(_) | UiEventKind::KeyUp(_) | UiEventKind::CharacterInput(_) => {
            let selected_target = state
                .focus_owner
                .as_ref()
                .and_then(|focus| target_for_focus(focus, &state.form_id))
                .unwrap_or_else(|| UiEventTarget::form(FORM_ID));
            Some(RouteSummary {
                route_kind: "keyboard_focus_owner",
                causal_ui_event_id: ui_event_id(event.event_id.0),
                selected_target,
                control_local: None,
                capture_owner_before: state
                    .capture_owner
                    .as_ref()
                    .map(|owner| focus_target_label(&owner.target)),
                capture_owner_after: state
                    .capture_owner
                    .as_ref()
                    .map(|owner| focus_target_label(&owner.target)),
                considered: Vec::new(),
            })
        }
        _ => None,
    }
}

fn show_requested_event(event_id: UiEventId) -> UiEvent {
    UiEvent {
        target: target(),
        ..UiEvent::new(
            event_id,
            UiEventSource::Replay,
            UiEventKind::ShowRequested(ShowRequestedEvent {
                form_id: FormId::new(FORM_ID),
                show_mode: ShowMode::Modeless,
                owner: None,
                initial_bounds: Some(LogicalRect::new(
                    0.0,
                    0.0,
                    f64::from(SURFACE_WIDTH),
                    f64::from(SURFACE_HEIGHT),
                )),
                reason: oxforms_pal::LifecycleReason::Replay,
            }),
        )
    }
}

fn modal_show_requested_event(event_id: UiEventId) -> UiEvent {
    UiEvent {
        target: target(),
        ..UiEvent::new(
            event_id,
            UiEventSource::Replay,
            UiEventKind::ShowRequested(ShowRequestedEvent {
                form_id: FormId::new(FORM_ID),
                show_mode: ShowMode::Modal,
                owner: None,
                initial_bounds: Some(LogicalRect::new(
                    0.0,
                    0.0,
                    f64::from(SURFACE_WIDTH),
                    f64::from(SURFACE_HEIGHT),
                )),
                reason: oxforms_pal::LifecycleReason::Replay,
            }),
        )
    }
}

fn window_shown_event(event_id: UiEventId) -> UiEvent {
    UiEvent {
        target: target(),
        ..UiEvent::new(
            event_id,
            UiEventSource::Service,
            UiEventKind::WindowShown(WindowShownEvent {
                form_id: FormId::new(FORM_ID),
                window_id: WindowId::new(WINDOW_ID),
                show_mode: ShowMode::Modeless,
                window_rect: None,
                dpi: Some(DpiScale::new(DPI, DPI)),
            }),
        )
    }
}

fn modal_window_shown_event(event_id: UiEventId) -> UiEvent {
    UiEvent {
        target: target(),
        ..UiEvent::new(
            event_id,
            UiEventSource::Service,
            UiEventKind::WindowShown(WindowShownEvent {
                form_id: FormId::new(FORM_ID),
                window_id: WindowId::new(WINDOW_ID),
                show_mode: ShowMode::Modal,
                window_rect: None,
                dpi: Some(DpiScale::new(DPI, DPI)),
            }),
        )
    }
}

fn close_request_event(event_id: UiEventId) -> UiEvent {
    UiEvent {
        target: target(),
        ..UiEvent::new(
            event_id,
            UiEventSource::Replay,
            UiEventKind::CloseRequest(CloseRequestEvent {
                origin: CloseRequestOrigin::CloseButton,
                reason: CloseReason::User,
                query_policy: CloseQueryPolicy::Query,
                coordinates: None,
            }),
        )
    }
}

fn query_close_completed_event(event_id: UiEventId) -> UiEvent {
    UiEvent {
        target: target(),
        ..UiEvent::new(
            event_id,
            UiEventSource::Service,
            UiEventKind::QueryCloseCompleted(QueryCloseCompletedEvent {
                form_id: FormId::new(FORM_ID),
                reason: CloseReason::User,
                cancelled: false,
                close_mode: Some(0),
                dispatch_diagnostics: vec![RawDiagnostic::text(
                    "oxforms-0a0.3",
                    "native_dispatch_blocker",
                    "QueryClose handler execution is blocked by oxforms-0a0.2; headless replay supplies the uncancelled completion observed in the W005 modeless oracle.",
                )],
            }),
        )
    }
}

fn focus_validation_completed_event(event_id: UiEventId) -> UiEvent {
    UiEvent {
        target: target(),
        ..UiEvent::new(
            event_id,
            UiEventSource::Service,
            UiEventKind::FocusValidationCompleted(FocusValidationCompletedEvent {
                form_id: FormId::new(FORM_ID),
                cancelled: false,
                dispatch_diagnostics: vec![RawDiagnostic::text(
                    "oxforms-esq.4",
                    "focus_validation_foldback",
                    "Exit handler execution is not driven in headless replay; the uncancelled completion supplies the deferred focus commit the W005 modeless oracle shows (focus moves to OkButton).",
                )],
            }),
        )
    }
}

fn window_hidden_event(event_id: UiEventId) -> UiEvent {
    UiEvent {
        target: target(),
        ..UiEvent::new(
            event_id,
            UiEventSource::Service,
            UiEventKind::WindowHidden(WindowHiddenEvent {
                form_id: FormId::new(FORM_ID),
                window_id: WindowId::new(WINDOW_ID),
                reason: LifecycleReason::User,
            }),
        )
    }
}

fn unloaded_event(event_id: UiEventId) -> UiEvent {
    UiEvent {
        target: UiEventTarget::form(FORM_ID),
        ..UiEvent::new(
            event_id,
            UiEventSource::Service,
            UiEventKind::Unloaded(UnloadedEvent {
                form_id: FormId::new(FORM_ID),
                reason: LifecycleReason::User,
            }),
        )
    }
}

fn pump_frame_exited_event(event_id: UiEventId) -> UiEvent {
    UiEvent {
        target: UiEventTarget::form(FORM_ID),
        ..UiEvent::new(
            event_id,
            UiEventSource::Service,
            UiEventKind::PumpFrameExited(PumpFrameExitedEvent {
                modal_depth: 1,
                exit_reason: "synthetic_replay_exit_without_live_window".to_string(),
            }),
        )
    }
}

fn mouse_button_event(event_id: UiEventId, x: f64, y: f64, down: bool) -> UiEvent {
    let payload = MouseButtonEvent {
        pointer_id: Some(PointerId(1)),
        button: MouseButton::Left,
        buttons_down: MouseButtons {
            left: down,
            ..MouseButtons::default()
        },
        modifiers: KeyboardModifiers::default(),
        click_count: ClickCount(1),
        coordinates: CoordinatePayload {
            screen_pixels: None,
            window_rect: None,
            client_pixels: Some(oxforms_pal::PixelPoint::new(x, y)),
            form_logical: Some(LogicalPoint::new(x, y)),
            control_local: None,
            dpi: Some(DpiScale::new(DPI, DPI)),
            raw_samples: vec![RawCoordinateSample {
                space: CoordinateSpace::FormLogical,
                point: CoordinatePoint::new(x, y),
                source: "w005_trace_replay.script".to_string(),
            }],
        },
    };
    UiEvent {
        target: target(),
        ..UiEvent::new(
            event_id,
            UiEventSource::Replay,
            if down {
                UiEventKind::MouseDown(payload)
            } else {
                UiEventKind::MouseUp(payload)
            },
        )
    }
}

fn character_key_event(event_id: UiEventId, text: &str, down: bool) -> UiEvent {
    let payload = KeyEvent {
        key: KeyCode::Character(text.to_string()),
        modifiers: KeyboardModifiers {
            shift: true,
            ..KeyboardModifiers::default()
        },
        repeat: KeyRepeat {
            is_repeat: false,
            repeat_count: Some(1),
        },
        raw: RawKeyDiagnostics {
            virtual_key: Some(0x41),
            scan_code: Some(0x1e),
            native_code: None,
            is_extended: Some(false),
        },
    };
    UiEvent {
        target: target(),
        diagnostics: vec![RawDiagnostic::text(
            "w005_trace_replay",
            "key_source",
            "scripted_normalized_key",
        )],
        ..UiEvent::new(
            event_id,
            UiEventSource::Replay,
            if down {
                UiEventKind::KeyDown(payload)
            } else {
                UiEventKind::KeyUp(payload)
            },
        )
    }
}

fn navigation_key_event(event_id: UiEventId, key: KeyCode) -> UiEvent {
    key_event(event_id, key, true)
}

fn navigation_key_up_event(event_id: UiEventId, key: KeyCode) -> UiEvent {
    key_event(event_id, key, false)
}

fn key_event(event_id: UiEventId, key: KeyCode, down: bool) -> UiEvent {
    let payload = KeyEvent {
        key,
        modifiers: KeyboardModifiers::default(),
        repeat: KeyRepeat {
            is_repeat: false,
            repeat_count: Some(1),
        },
        raw: RawKeyDiagnostics::default(),
    };
    UiEvent {
        target: target(),
        diagnostics: vec![RawDiagnostic::text(
            "w005_trace_replay",
            "key_source",
            "scripted_normalized_key",
        )],
        ..UiEvent::new(
            event_id,
            UiEventSource::Replay,
            if down {
                UiEventKind::KeyDown(payload)
            } else {
                UiEventKind::KeyUp(payload)
            },
        )
    }
}

fn character_event(event_id: UiEventId, text: &str) -> UiEvent {
    UiEvent {
        target: target(),
        ..UiEvent::new(
            event_id,
            UiEventSource::Replay,
            UiEventKind::CharacterInput(CharacterInputEvent {
                text: text.to_string(),
                modifiers: KeyboardModifiers {
                    shift: true,
                    ..KeyboardModifiers::default()
                },
                raw: vec![RawDiagnostic::text(
                    "w005_trace_replay",
                    "text_source",
                    "scripted_committed_text",
                )],
            }),
        )
    }
}

fn target() -> UiEventTarget {
    UiEventTarget {
        form_id: Some(FormId::new(FORM_ID)),
        window_id: Some(WindowId::new(WINDOW_ID)),
        control_id: None,
    }
}

fn target_for_focus(focus: &FocusTarget, form_id: &FormId) -> Option<UiEventTarget> {
    match focus {
        FocusTarget::Form(form) => Some(UiEventTarget::form(form.0.clone())),
        FocusTarget::Control(control) => {
            Some(UiEventTarget::control(form_id.0.clone(), control.0.clone()))
        }
    }
}

fn ui_event_payload(event: &UiEvent, route: &Option<RouteSummary>) -> Value {
    json!({
        "ui_event_id": ui_event_id(event.event_id.0),
        "ui_event_schema_version": event.schema_version,
        "source": ui_event_source(event.source),
        "target": target_json(&event.target),
        "normalized_input": normalized_input_json(&event.kind),
        "coordinates": coordinates_json(&event.kind, route),
        "diagnostics": event
            .diagnostics
            .iter()
            .map(diagnostic_json)
            .collect::<Vec<_>>()
    })
}

fn normalized_input_json(kind: &UiEventKind) -> Value {
    match kind {
        UiEventKind::ShowRequested(payload) => json!({
            "kind": "show_requested",
            "payload": {
                "form_id": payload.form_id.0,
                "show_mode": show_mode(payload.show_mode),
                "owner": payload.owner.as_ref().map(target_json),
                "initial_bounds": payload.initial_bounds.map(rect_json),
                "reason": "replay"
            }
        }),
        UiEventKind::WindowShown(payload) => json!({
            "kind": "window_shown",
            "payload": {
                "form_id": payload.form_id.0,
                "window_id": payload.window_id.0,
                "show_mode": show_mode(payload.show_mode),
                "window_rect": payload.window_rect,
                "dpi": payload.dpi.map(dpi_value_json)
            }
        }),
        UiEventKind::CloseRequest(payload) => json!({
            "kind": "close_request",
            "payload": {
                "origin": close_request_origin(payload.origin),
                "reason": close_reason(payload.reason),
                "query_policy": close_query_policy(payload.query_policy)
            }
        }),
        UiEventKind::QueryCloseCompleted(payload) => json!({
            "kind": "query_close_completed",
            "payload": {
                "form_id": payload.form_id.0,
                "reason": close_reason(payload.reason),
                "cancelled": payload.cancelled,
                "close_mode": payload.close_mode,
                "dispatch_diagnostics": payload
                    .dispatch_diagnostics
                    .iter()
                    .map(diagnostic_json)
                    .collect::<Vec<_>>()
            }
        }),
        UiEventKind::FocusValidationCompleted(payload) => json!({
            "kind": "focus_validation_completed",
            "payload": {
                "form_id": payload.form_id.0,
                "cancelled": payload.cancelled,
                "dispatch_diagnostics": payload
                    .dispatch_diagnostics
                    .iter()
                    .map(diagnostic_json)
                    .collect::<Vec<_>>()
            }
        }),
        UiEventKind::KeyDownSwallowed(payload) => json!({
            "kind": "key_down_swallowed",
            "payload": {
                "form_id": payload.form_id.0,
                "dispatch_diagnostics": payload
                    .dispatch_diagnostics
                    .iter()
                    .map(diagnostic_json)
                    .collect::<Vec<_>>()
            }
        }),
        UiEventKind::WindowHidden(payload) => json!({
            "kind": "window_hidden",
            "payload": {
                "form_id": payload.form_id.0,
                "window_id": payload.window_id.0,
                "reason": lifecycle_reason(payload.reason)
            }
        }),
        UiEventKind::Unloaded(payload) => json!({
            "kind": "unloaded",
            "payload": {
                "form_id": payload.form_id.0,
                "reason": lifecycle_reason(payload.reason)
            }
        }),
        UiEventKind::PumpFrameExited(payload) => json!({
            "kind": "pump_frame_exited",
            "payload": {
                "modal_depth": payload.modal_depth,
                "exit_reason": payload.exit_reason
            }
        }),
        UiEventKind::MouseDown(payload) => mouse_input_json("mouse_down", payload),
        UiEventKind::MouseUp(payload) => mouse_input_json("mouse_up", payload),
        UiEventKind::KeyDown(payload) => key_input_json("key_down", payload),
        UiEventKind::KeyUp(payload) => key_input_json("key_up", payload),
        UiEventKind::CharacterInput(payload) => json!({
            "kind": "character_input",
            "payload": {
                "text": payload.text,
                "modifiers": modifiers_json(payload.modifiers),
                "raw": payload.raw.iter().map(diagnostic_json).collect::<Vec<_>>()
            }
        }),
        UiEventKind::ClipboardResult(payload) => json!({
            "kind": "clipboard_result",
            "payload": {
                "request_id": payload.request_id.0.clone(),
                "operation": clipboard_operation(payload.operation),
                "outcome": service_outcome_json(&payload.outcome),
                "formats": payload.formats.clone(),
                "payload": payload.payload.as_ref().map(|payload| {
                    json!({
                        "content_type": payload.content_type.clone(),
                        "text": payload.text.clone(),
                        "bytes_sha256": payload.bytes_sha256.clone(),
                        "metadata": payload.metadata.iter().map(diagnostic_json).collect::<Vec<_>>()
                    })
                })
            }
        }),
        UiEventKind::DragOver(payload) => json!({
            "kind": "drag_over",
            "payload": {
                "drag_session_id": payload.drag_session_id,
                "coordinates": coordinate_payload_summary_json(&payload.coordinates),
                "modifiers": modifiers_json(payload.modifiers),
                "buttons_down": buttons_json(&payload.buttons_down),
                "drag_state": payload.drag_state,
                "effect": payload.effect,
                "data": data_object_snapshot_json(&payload.data)
            }
        }),
        UiEventKind::DropOrPaste(payload) => json!({
            "kind": "drop_or_paste",
            "payload": {
                "transfer_session_id": payload.transfer_session_id,
                "origin": drop_or_paste_origin(payload.origin),
                "coordinates": coordinate_payload_summary_json(&payload.coordinates),
                "modifiers": modifiers_json(payload.modifiers),
                "action": payload.action,
                "effect": payload.effect,
                "data": data_object_snapshot_json(&payload.data)
            }
        }),
        UiEventKind::Activate(payload) => json!({
            "kind": "activate",
            "payload": {
                "reason": match payload.reason {
                    ActivationReason::WindowShown => "window_shown",
                    ActivationReason::Replay => "replay",
                    _ => "other"
                }
            }
        }),
        _ => json!({
            "kind": "service_result",
            "payload": {
                "unsupported_in_runner": format!("{kind:?}")
            }
        }),
    }
}

fn clipboard_operation(operation: ClipboardOperation) -> &'static str {
    match operation {
        ClipboardOperation::Get => "get",
        ClipboardOperation::Set => "set",
    }
}

fn drop_or_paste_origin(origin: DropOrPasteOrigin) -> &'static str {
    match origin {
        DropOrPasteOrigin::DragDrop => "drag_drop",
        DropOrPasteOrigin::ClipboardPaste => "clipboard_paste",
        DropOrPasteOrigin::Code => "code",
        DropOrPasteOrigin::Replay => "replay",
    }
}

fn data_object_snapshot_json(snapshot: &DataObjectSnapshot) -> Value {
    json!({
        "snapshot_id": snapshot.snapshot_id.0,
        "formats": snapshot.formats,
        "payload": snapshot.payload.as_ref().map(service_payload_json),
        "metadata": snapshot.metadata.iter().map(diagnostic_json).collect::<Vec<_>>()
    })
}

fn service_payload_json(payload: &ServicePayload) -> Value {
    json!({
        "content_type": payload.content_type,
        "text": payload.text,
        "bytes_sha256": payload.bytes_sha256,
        "metadata": payload.metadata.iter().map(diagnostic_json).collect::<Vec<_>>()
    })
}

fn service_outcome_json(outcome: &ServiceOutcome) -> Value {
    match outcome {
        ServiceOutcome::Success => json!({ "status": "success" }),
        ServiceOutcome::Error { kind, message } => {
            json!({ "status": "error", "kind": kind, "message": message })
        }
    }
}

fn mouse_input_json(kind: &str, payload: &MouseButtonEvent) -> Value {
    json!({
        "kind": kind,
        "payload": {
            "pointer_id": payload.pointer_id.map(|id| id.0),
            "button": mouse_button(payload.button),
            "buttons_down": buttons_json(&payload.buttons_down),
            "modifiers": modifiers_json(payload.modifiers),
            "click_count": payload.click_count.0
        }
    })
}

fn key_input_json(kind: &str, payload: &KeyEvent) -> Value {
    json!({
        "kind": kind,
        "payload": {
            "key": key_code(&payload.key),
            "modifiers": modifiers_json(payload.modifiers),
            "repeat": {
                "is_repeat": payload.repeat.is_repeat,
                "repeat_count": payload.repeat.repeat_count
            },
            "raw": {
                "virtual_key": payload.raw.virtual_key,
                "scan_code": payload.raw.scan_code,
                "native_code": payload.raw.native_code,
                "is_extended": payload.raw.is_extended
            }
        }
    })
}

fn coordinate_payload_summary_json(payload: &CoordinatePayload) -> Value {
    json!({
        "screen_pixels": payload.screen_pixels.map(|point| json!({ "x": point.x, "y": point.y })),
        "window_rect": payload.window_rect.map(|rect| json!({
            "x": rect.x,
            "y": rect.y,
            "width": rect.width,
            "height": rect.height
        })),
        "client_pixels": payload.client_pixels.map(|point| json!({ "x": point.x, "y": point.y })),
        "form_logical": payload.form_logical.map(|point| json!({ "x": point.x, "y": point.y })),
        "control_local": payload.control_local.map(|point| json!({ "x": point.x, "y": point.y })),
        "dpi": payload.dpi.map(dpi_value_json),
        "raw_samples": payload.raw_samples.iter().map(|sample| {
            json!({
                "space": coordinate_space(sample.space),
                "point": { "x": sample.point.x, "y": sample.point.y },
                "source": sample.source
            })
        }).collect::<Vec<_>>()
    })
}

fn coordinates_json(kind: &UiEventKind, route: &Option<RouteSummary>) -> Vec<Value> {
    let coordinate_payload = match kind {
        UiEventKind::MouseDown(payload) | UiEventKind::MouseUp(payload) => &payload.coordinates,
        _ => return Vec::new(),
    };

    let mut coordinates = Vec::new();
    if let Some(point) = coordinate_payload.client_pixels {
        coordinates.push(coordinate_point(
            "client_pixels",
            "pixels",
            "window_client_top_left",
            point.x,
            point.y,
            "replay.script",
            "synthetic",
        ));
    }
    if let Some(point) = coordinate_payload.form_logical {
        coordinates.push(coordinate_point(
            "form_logical",
            "points",
            "form_design_surface_top_left",
            point.x,
            point.y,
            "replay.script",
            "synthetic",
        ));
    }
    if let Some(point) = route.as_ref().and_then(|summary| summary.control_local) {
        coordinates.push(coordinate_point(
            "control_local",
            "points",
            "target_control_top_left",
            point.x,
            point.y,
            "router.control_local",
            "derived",
        ));
    }
    for sample in &coordinate_payload.raw_samples {
        coordinates.push(coordinate_point(
            coordinate_space(sample.space),
            "platform",
            "replay_script",
            sample.point.x,
            sample.point.y,
            &sample.source,
            "synthetic",
        ));
    }
    coordinates
}

fn effect_requested_payload(effect: &EffectRequest) -> Value {
    let mut payload = json!({
        "effect_id": effect_id(effect.effect_id.0),
        "effect_kind": effect_kind_name(&effect.kind),
        "cause": {
            "ui_event_id": ui_event_id(effect.cause.ui_event_id.0),
            "transition_id": transition_id(effect.cause.transition_id.0)
        },
        "target": target_json(&effect.target),
        "completion_policy": completion_policy_name(effect.completion_policy)
    });
    if let EffectKind::FireVbaEvent {
        event_name,
        arguments,
        cancel_metadata,
        ..
    } = &effect.kind
    {
        payload["event_name"] = json!(event_name);
        payload["arguments"] = json!(arguments
            .iter()
            .map(|argument| {
                json!({
                    "name": argument.name,
                    "value": argument.value,
                    "by_ref": argument.by_ref
                })
            })
            .collect::<Vec<_>>());
        payload["cancel_metadata"] = json!(cancel_metadata);
    }
    match &effect.kind {
        EffectKind::ShowFormModal { owner, reason } => {
            payload["owner"] = json!(owner.as_ref().map(target_json));
            payload["reason"] = json!(lifecycle_reason(*reason));
        }
        EffectKind::EnterModalFrame { modal_depth } => {
            payload["modal_depth"] = json!(modal_depth);
        }
        EffectKind::ExitModalFrame {
            modal_depth,
            reason,
        } => {
            payload["modal_depth"] = json!(modal_depth);
            payload["reason"] = json!(reason);
        }
        _ => {}
    }
    payload
}

fn headless_effect_completion_status(effect: &EffectRequest) -> &'static str {
    match &effect.kind {
        EffectKind::FireVbaEvent { .. } => "recorded_not_executed",
        EffectKind::RequestRepaint { .. } => "completed_by_headless_render",
        EffectKind::TransferFocus { .. }
        | EffectKind::CaptureMouse { .. }
        | EffectKind::ReleaseMouse { .. }
        | EffectKind::CreateWindowSurface { .. }
        | EffectKind::ShowFormModeless { .. }
        | EffectKind::ScheduleModeless => "diagnostic_only",
        _ => "not_applicable_in_headless_subset",
    }
}

fn modal_subset_diagnostics() -> Vec<Value> {
    vec![
        json!({
            "source": W006_MODAL_BEAD,
            "name": "synthetic_host_neutral_subset",
            "value": "Rows are replay-generated OxForms trace evidence only; no live PAL modal window pump or MSForms modal parity is executed."
        }),
        json!({
            "source": W006_MODAL_BEAD,
            "name": "runtime_blocker",
            "value": "OxVba caller-side modal Show blocking/resume and PAL/effect-runner live modal frame completions remain outside this subset."
        }),
    ]
}

fn state_summary_json(summary: &StateSummary) -> Value {
    let mut payload = json!({
        "lifecycle_state": lifecycle_state(summary.lifecycle_state),
        "pump_term": pump_term(summary.pump_term),
        "nested_modal_depth": summary.nested_modal_depth,
        "focus_owner": summary.focus_owner.as_ref().map(focus_target_json),
        "capture_owner": summary.capture_owner.as_ref().map(focus_target_json),
        "hover_path": summary.hover_path.iter().map(|id| id.0.clone()).collect::<Vec<_>>(),
        "pressed_state": summary.pressed_state.as_ref().map(|pressed| {
            json!({
                "target": focus_target_json(&pressed.target),
                "origin": format!("{:?}", pressed.origin).to_ascii_lowercase(),
                "armed": pressed.armed
            })
        }),
        "active_form": summary.active_form.as_ref().map(|id| id.0.clone()),
        "active_window": summary.active_window.as_ref().map(|id| id.0.clone()),
        "close_flow": summary.close_flow.as_ref().map(|flow| {
            json!({
                "origin": close_request_origin(flow.origin),
                "reason": close_reason(flow.reason),
                "close_mode": flow.close_mode,
                "cancelled": flow.cancelled,
                "awaiting_window_hide_for_unload": flow.awaiting_window_hide_for_unload
            })
        }),
        "text_values": summary.text_values.iter().map(|text| {
            json!({
                "control_id": text.control_id.0,
                "text_len": text.text_len,
                "caret": {
                    "anchor": text.caret.anchor,
                    "active": text.caret.active,
                    "preferred_column": text.caret.preferred_column
                },
                "dirty": text.dirty
            })
        }).collect::<Vec<_>>(),
        "validation_active": summary.validation_active,
        "pending_effect_count": summary.pending_effect_count
    });
    if !summary.check_box_values.is_empty() {
        payload["check_box_values"] = json!(summary
            .check_box_values
            .iter()
            .map(|check_box| {
                json!({
                    "control_id": check_box.control_id.0,
                    "checked": check_box.checked,
                    "dirty": check_box.dirty
                })
            })
            .collect::<Vec<_>>());
    }
    payload
}

fn input_script_summary() -> Vec<Value> {
    vec![
        json!({
            "script_step_id": "script-0001",
            "action": "show_form_modeless",
            "target": { "form_id": FORM_ID }
        }),
        json!({
            "script_step_id": "script-0002",
            "action": "mouse_click",
            "target": { "form_id": FORM_ID, "control_id": "text-1" },
            "point": { "space": "form_logical", "x": 20.0, "y": 60.0 }
        }),
        json!({
            "script_step_id": "script-0003",
            "action": "type_committed_text",
            "target": { "form_id": FORM_ID, "control_id": "text-1" },
            "text": "AB"
        }),
        json!({
            "script_step_id": "script-0004",
            "action": "navigate_textbox",
            "target": { "form_id": FORM_ID, "control_id": "text-1" },
            "keys": ["arrow_left", "delete", "home", "end", "backspace"]
        }),
        json!({
            "script_step_id": "script-0005",
            "action": "mouse_click",
            "target": { "form_id": FORM_ID, "control_id": "ok" },
            "point": { "space": "form_logical", "x": 176.0, "y": 64.0 }
        }),
    ]
}

fn input_script_summary_w006_modal_frame() -> Vec<Value> {
    vec![
        json!({
            "script_step_id": "script-0001",
            "action": "show_form_modal",
            "target": { "form_id": FORM_ID },
            "synthetic_host_neutral": true
        }),
        json!({
            "script_step_id": "script-0002",
            "action": "mouse_click_inside_modal_frame",
            "target": { "form_id": FORM_ID, "control_id": "ok" },
            "point": { "space": "form_logical", "x": 176.0, "y": 64.0 },
            "modal_depth": 1
        }),
        json!({
            "script_step_id": "script-0003",
            "action": "pump_frame_exited",
            "target": { "form_id": FORM_ID },
            "modal_depth": 1,
            "exit_reason": "synthetic_replay_exit_without_live_window"
        }),
    ]
}

fn coordinate_point(
    space: &str,
    unit: &str,
    origin: &str,
    x: f64,
    y: f64,
    source: &str,
    certainty: &str,
) -> Value {
    json!({
        "space": space,
        "unit": unit,
        "origin": origin,
        "point": { "x": x, "y": y },
        "dpi": dpi_json(),
        "source": source,
        "certainty": certainty
    })
}

fn target_json(target: &UiEventTarget) -> Value {
    json!({
        "form_id": target.form_id.as_ref().map(|id| id.0.clone()),
        "window_id": target.window_id.as_ref().map(|id| id.0.clone()),
        "control_id": target.control_id.as_ref().map(|id| id.0.clone())
    })
}

fn focus_target_json(target: &FocusTarget) -> Value {
    match target {
        FocusTarget::Form(form_id) => json!({ "kind": "form", "target": form_id.0 }),
        FocusTarget::Control(control_id) => json!({ "kind": "control", "target": control_id.0 }),
    }
}

fn focus_target_label(target: &FocusTarget) -> String {
    match target {
        FocusTarget::Form(form_id) => form_id.0.clone(),
        FocusTarget::Control(control_id) => control_id.0.clone(),
    }
}

fn diagnostic_json(diagnostic: &RawDiagnostic) -> Value {
    json!({
        "source": diagnostic.source,
        "name": diagnostic.name,
        "value": diagnostic.value
    })
}

fn rect_json(rect: LogicalRect) -> Value {
    json!({
        "space": "form_logical",
        "unit": "points",
        "origin": "form_design_surface_top_left",
        "rect": {
            "x": rect.x,
            "y": rect.y,
            "width": rect.width,
            "height": rect.height
        },
        "dpi": dpi_json(),
        "source": "replay.script",
        "certainty": "synthetic"
    })
}

fn dpi_json() -> Value {
    json!({ "dpi_x": DPI, "dpi_y": DPI })
}

fn dpi_value_json(dpi: DpiScale) -> Value {
    json!({
        "dpi_x": dpi.dpi_x,
        "dpi_y": dpi.dpi_y,
        "scale_x": dpi.scale_x,
        "scale_y": dpi.scale_y
    })
}

fn buttons_json(buttons: &MouseButtons) -> Value {
    json!({
        "left": buttons.left,
        "right": buttons.right,
        "middle": buttons.middle,
        "x1": buttons.x1,
        "x2": buttons.x2,
        "other": buttons.other
    })
}

fn modifiers_json(modifiers: KeyboardModifiers) -> Value {
    json!({
        "shift": modifiers.shift,
        "control": modifiers.control,
        "alt": modifiers.alt,
        "meta": modifiers.meta,
        "platform": modifiers.platform,
        "caps_lock": modifiers.caps_lock,
        "num_lock": modifiers.num_lock,
        "scroll_lock": modifiers.scroll_lock
    })
}

fn ui_event_source(source: UiEventSource) -> &'static str {
    match source {
        UiEventSource::Pal => "pal",
        UiEventSource::HostExtension => "host_extension",
        UiEventSource::Service => "service",
        UiEventSource::Replay => "replay",
        UiEventSource::Oracle => "oracle",
    }
}

fn coordinate_space(space: CoordinateSpace) -> &'static str {
    match space {
        CoordinateSpace::ScreenPixels => "screen_pixels",
        CoordinateSpace::WindowRect => "window_rect",
        CoordinateSpace::ScreenshotPixels => "screenshot_pixels",
        CoordinateSpace::ClientPixels => "client_pixels",
        CoordinateSpace::FormLogical => "form_logical",
        CoordinateSpace::ControlLocal => "control_local",
        CoordinateSpace::DisplayListLogical => "display_list_logical",
        CoordinateSpace::MsformsEventArgs => "msforms_event_args",
        CoordinateSpace::RawDiagnostic => "raw_diagnostic",
    }
}

fn mouse_button(button: MouseButton) -> String {
    match button {
        MouseButton::Left => "left".to_string(),
        MouseButton::Right => "right".to_string(),
        MouseButton::Middle => "middle".to_string(),
        MouseButton::X1 => "x1".to_string(),
        MouseButton::X2 => "x2".to_string(),
        MouseButton::Other(value) => format!("other:{value}"),
    }
}

fn key_code(key: &KeyCode) -> String {
    match key {
        KeyCode::Enter => "enter".to_string(),
        KeyCode::Escape => "escape".to_string(),
        KeyCode::Tab => "tab".to_string(),
        KeyCode::Backspace => "backspace".to_string(),
        KeyCode::Delete => "delete".to_string(),
        KeyCode::ArrowLeft => "arrow_left".to_string(),
        KeyCode::ArrowRight => "arrow_right".to_string(),
        KeyCode::ArrowUp => "arrow_up".to_string(),
        KeyCode::ArrowDown => "arrow_down".to_string(),
        KeyCode::Home => "home".to_string(),
        KeyCode::End => "end".to_string(),
        KeyCode::PageUp => "page_up".to_string(),
        KeyCode::PageDown => "page_down".to_string(),
        KeyCode::Space => "space".to_string(),
        KeyCode::Function(number) => format!("function:{number}"),
        KeyCode::Character(value) => format!("character:{value}"),
        KeyCode::Other(key) => format!("other:{key}"),
        KeyCode::Unidentified => "unidentified".to_string(),
    }
}

fn show_mode(show_mode: ShowMode) -> &'static str {
    match show_mode {
        ShowMode::Modal => "modal",
        ShowMode::Modeless => "modeless",
    }
}

fn close_request_origin(origin: CloseRequestOrigin) -> &'static str {
    match origin {
        CloseRequestOrigin::CloseButton => "close_button",
        CloseRequestOrigin::SystemMenu => "system_menu",
        CloseRequestOrigin::HostRequest => "host_request",
        CloseRequestOrigin::CodeUnload => "code_unload",
        CloseRequestOrigin::OwnerShutdown => "owner_shutdown",
        CloseRequestOrigin::Replay => "replay",
        CloseRequestOrigin::Unknown => "unknown",
    }
}

fn close_reason(reason: CloseReason) -> &'static str {
    match reason {
        CloseReason::User => "user",
        CloseReason::Programmatic => "programmatic",
        CloseReason::HostShutdown => "host_shutdown",
        CloseReason::Error => "error",
        CloseReason::Replay => "replay",
        CloseReason::Unknown => "unknown",
    }
}

fn close_query_policy(policy: CloseQueryPolicy) -> &'static str {
    match policy {
        CloseQueryPolicy::Query => "query",
        CloseQueryPolicy::SkipQuery => "skip_query",
        CloseQueryPolicy::Unknown => "unknown",
    }
}

fn lifecycle_reason(reason: LifecycleReason) -> &'static str {
    match reason {
        LifecycleReason::DefaultInstance => "default_instance",
        LifecycleReason::ShowRequested => "show_requested",
        LifecycleReason::Programmatic => "programmatic",
        LifecycleReason::User => "user",
        LifecycleReason::Host => "host",
        LifecycleReason::Replay => "replay",
        LifecycleReason::Error => "error",
        LifecycleReason::Unknown => "unknown",
    }
}

fn pump_term(term: PumpTerm) -> &'static str {
    match term {
        PumpTerm::HostModelessPump => "host_modeless_pump",
        PumpTerm::ModalFrame => "modal_frame",
        PumpTerm::DoeventsYield => "doevents_yield",
        PumpTerm::VbaDispatchReentrancy => "vba_dispatch_reentrancy",
        PumpTerm::HostCallbackReentrancy => "host_callback_reentrancy",
        PumpTerm::CloseUnloadCancellation => "close_unload_cancellation",
    }
}

fn lifecycle_state(state: LifecycleState) -> &'static str {
    match state {
        LifecycleState::Allocated => "allocated",
        LifecycleState::Loading => "loading",
        LifecycleState::Loaded => "loaded",
        LifecycleState::Initializing => "initializing",
        LifecycleState::Initialized => "initialized",
        LifecycleState::Hidden => "hidden",
        LifecycleState::ShowingModeless => "showing_modeless",
        LifecycleState::ModelessVisible => "modeless_visible",
        LifecycleState::ShowingModal => "showing_modal",
        LifecycleState::ModalVisible => "modal_visible",
        LifecycleState::Active => "active",
        LifecycleState::Deactivated => "deactivated",
        LifecycleState::CloseRequested => "close_requested",
        LifecycleState::QueryClosePending => "query_close_pending",
        LifecycleState::CloseCancelled => "close_cancelled",
        LifecycleState::HidePending => "hide_pending",
        LifecycleState::Unloading => "unloading",
        LifecycleState::Terminated => "terminated",
        LifecycleState::LoadFailed => "load_failed",
        LifecycleState::InitFailed => "init_failed",
        LifecycleState::UnloadBlocked => "unload_blocked",
    }
}

fn invalidation_reason(reason: InvalidationReason) -> &'static str {
    match reason {
        InvalidationReason::InitialShow => "initial_show",
        InvalidationReason::FocusChanged => "focus_changed",
        InvalidationReason::HoverChanged => "hover_changed",
        InvalidationReason::PressedStateChanged => "pressed_state_changed",
        InvalidationReason::CheckBoxValueChanged => "checkbox_value_changed",
        InvalidationReason::CheckBoxPressedChanged => "checkbox_pressed_changed",
        InvalidationReason::TextChanged => "text_changed",
        InvalidationReason::CaptionChanged => "caption_changed",
        InvalidationReason::TextSelectionChanged => "text_selection_changed",
        InvalidationReason::LifecycleChanged => "lifecycle_changed",
        InvalidationReason::CloseStateChanged => "close_state_changed",
        InvalidationReason::Unknown => "unknown",
    }
}

fn completion_policy_name(policy: crate::CompletionPolicy) -> &'static str {
    match policy {
        crate::CompletionPolicy::ImmediateDiagnostic => "immediate_diagnostic",
        crate::CompletionPolicy::PlatformCompletionOrDiagnostic => {
            "platform_completion_or_diagnostic"
        }
        crate::CompletionPolicy::ServiceResultRequired => "service_result_required",
        crate::CompletionPolicy::DispatchResultRequired => "dispatch_result_required",
        crate::CompletionPolicy::WindowShownEventRequired => "window_shown_event_required",
        crate::CompletionPolicy::PumpFrameExitRequired => "pump_frame_exit_required",
        crate::CompletionPolicy::RenderDiagnosticOptional => "render_diagnostic_optional",
    }
}

fn effect_kind_name(kind: &EffectKind) -> &'static str {
    match kind {
        EffectKind::FireVbaEvent { .. } => "fire_vba_event",
        EffectKind::RequestRepaint { .. } => "request_repaint",
        EffectKind::CaptureMouse { .. } => "capture_mouse",
        EffectKind::ReleaseMouse { .. } => "release_mouse",
        EffectKind::TransferFocus { .. } => "transfer_focus",
        EffectKind::StartTimer { .. } => "start_timer",
        EffectKind::StopTimer { .. } => "stop_timer",
        EffectKind::ClipboardGet { .. } => "clipboard_get",
        EffectKind::ClipboardSet { .. } => "clipboard_set",
        EffectKind::SetCursor { .. } => "set_cursor",
        EffectKind::ShowFormModal { .. } => "show_form_modal",
        EffectKind::ShowFormModeless { .. } => "show_form_modeless",
        EffectKind::HideForm { .. } => "hide_form",
        EffectKind::CloseForm { .. } => "close_form",
        EffectKind::UnloadForm { .. } => "unload_form",
        EffectKind::HostCapabilityRequest { .. } => "host_capability_request",
        EffectKind::MaterializeForm { .. } => "materialize_form",
        EffectKind::CreateWindowSurface { .. } => "create_window_surface",
        EffectKind::EnterModalFrame { .. } => "enter_modal_frame",
        EffectKind::ScheduleModeless => "schedule_modeless",
        EffectKind::ExitModalFrame { .. } => "exit_modal_frame",
    }
}

fn ui_event_id(id: u64) -> String {
    format!("ui-{id:04}")
}

fn transition_id(id: u64) -> String {
    format!("transition-{id:04}")
}

fn effect_id(id: u64) -> String {
    format!("effect-{id:04}")
}

fn invalidation_id(id: u64) -> String {
    format!("inv-{id:04}")
}

fn pretty_json(value: &Value) -> String {
    let mut text = serde_json::to_string_pretty(value).expect("golden artifact should serialize");
    text.push('\n');
    text
}

#[cfg(test)]
mod tests {
    use super::*;
    use oxforms_pal::{DragOverEvent, DropOrPasteEvent, ServiceRequestId};

    #[test]
    fn w005_trace_replay_golden_matches_committed_artifacts() {
        let artifacts = build_w005_trace_replay_golden_artifacts();
        assert_eq!(
            artifacts.trace_json,
            include_str!(concat!(
                env!("CARGO_MANIFEST_DIR"),
                "/../../docs/evidence/W005_input_interaction_model_exploration/trace-replay/w005-headless-probe-replay.golden.v1.json"
            ))
        );
    }

    #[test]
    fn w006_modal_frame_trace_subset_matches_committed_artifact() {
        let artifact = build_w006_modal_frame_trace_subset_artifact();
        assert_eq!(
            artifact,
            include_str!(concat!(
                env!("CARGO_MANIFEST_DIR"),
                "/../../docs/evidence/W006_control_implementation_rollout/trace-replay/modal-frame-subset.synthetic.v1.json"
            ))
        );

        let trace: Value = serde_json::from_str(&artifact).expect("trace json should parse");
        assert_eq!(trace["bead"].as_str(), Some(W006_MODAL_BEAD));
        assert_eq!(
            trace["scenario"]["not_live_msforms_modal_parity"].as_bool(),
            Some(true)
        );
        assert_eq!(
            trace["environment"]["pal"]["live_modal_window_runtime"].as_bool(),
            Some(false)
        );

        let rows = trace["rows"].as_array().expect("trace should contain rows");
        let show_request = rows
            .iter()
            .find(|row| {
                row["kind"].as_str() == Some("effect_requested")
                    && row["payload"]["effect_kind"].as_str() == Some("show_form_modal")
            })
            .expect("trace should request ShowFormModal");
        let show_row_id = show_request["row_id"]
            .as_str()
            .expect("show request should have a row id");
        let show_effect_id = show_request["payload"]["effect_id"]
            .as_str()
            .expect("show request should have an effect id");
        assert!(show_request["parent_row_id"].is_null());
        assert_eq!(show_request["nesting_depth"].as_u64(), Some(0));

        let enter_request = rows
            .iter()
            .find(|row| {
                row["kind"].as_str() == Some("effect_requested")
                    && row["payload"]["effect_kind"].as_str() == Some("enter_modal_frame")
            })
            .expect("trace should request EnterModalFrame");
        assert_eq!(enter_request["payload"]["modal_depth"].as_u64(), Some(1));
        let enter_effect_id = enter_request["payload"]["effect_id"]
            .as_str()
            .expect("enter request should have an effect id");

        let pump_exit = rows
            .iter()
            .find(|row| {
                row["kind"].as_str() == Some("ui_event")
                    && row["payload"]["normalized_input"]["kind"].as_str()
                        == Some("pump_frame_exited")
            })
            .expect("trace should contain PumpFrameExited");
        assert_eq!(pump_exit["parent_row_id"].as_str(), Some(show_row_id));
        assert_eq!(pump_exit["nesting_depth"].as_u64(), Some(1));
        assert_eq!(
            pump_exit["payload"]["normalized_input"]["payload"]["modal_depth"].as_u64(),
            Some(1)
        );

        let exit_request = rows
            .iter()
            .find(|row| {
                row["kind"].as_str() == Some("effect_requested")
                    && row["payload"]["effect_kind"].as_str() == Some("exit_modal_frame")
            })
            .expect("trace should request ExitModalFrame");
        let exit_row_id = exit_request["row_id"]
            .as_str()
            .expect("exit request should have a row id");
        let exit_effect_id = exit_request["payload"]["effect_id"]
            .as_str()
            .expect("exit request should have an effect id");
        assert_eq!(exit_request["parent_row_id"].as_str(), Some(show_row_id));
        assert_eq!(exit_request["nesting_depth"].as_u64(), Some(1));
        assert_eq!(exit_request["payload"]["modal_depth"].as_u64(), Some(1));

        let exit_completion = rows
            .iter()
            .find(|row| {
                row["kind"].as_str() == Some("effect_completed")
                    && row["payload"]["effect_id"].as_str() == Some(exit_effect_id)
            })
            .expect("trace should complete ExitModalFrame");
        assert_eq!(exit_completion["parent_row_id"].as_str(), Some(exit_row_id));
        assert_eq!(exit_completion["nesting_depth"].as_u64(), Some(2));

        for (effect_id, parent_row_id) in [
            (show_effect_id, show_row_id),
            (
                enter_effect_id,
                enter_request["row_id"]
                    .as_str()
                    .expect("enter request should have a row id"),
            ),
        ] {
            let completion = rows
                .iter()
                .find(|row| {
                    row["kind"].as_str() == Some("effect_completed")
                        && row["payload"]["effect_id"].as_str() == Some(effect_id)
                })
                .expect("modal effect should complete after PumpFrameExited");
            assert_eq!(completion["parent_row_id"].as_str(), Some(parent_row_id));
            assert_eq!(completion["nesting_depth"].as_u64(), Some(1));
            assert!(
                completion["sequence"]
                    .as_u64()
                    .expect("completion sequence")
                    > pump_exit["sequence"].as_u64().expect("pump sequence")
            );
        }

        assert!(rows.iter().any(|row| {
            row["kind"].as_str() == Some("lifecycle_pump")
                && row["payload"]["pump_term"].as_str() == Some("modal_frame")
                && row["payload"]["modal_depth"].as_u64() == Some(1)
                && row["parent_row_id"].as_str() == Some(show_row_id)
                && row["nesting_depth"].as_u64() == Some(1)
        }));
    }

    #[test]
    fn w006_drag_drop_projection_uses_supported_ui_event_names() {
        let coordinates = CoordinatePayload {
            control_local: Some(LogicalPoint::new(63.0, 15.0)),
            ..CoordinatePayload::default()
        };
        let data = DataObjectSnapshot {
            snapshot_id: ServiceRequestId::new("snapshot-drag-1"),
            formats: vec!["cf_text".to_string()],
            payload: Some(ServicePayload {
                content_type: Some("text/plain".to_string()),
                text: Some("repo_owned_drag_text_seed_v1".to_string()),
                bytes_sha256: None,
                metadata: vec![RawDiagnostic::text(
                    "test",
                    "repo_owned_drag_seed",
                    "repo_owned_drag_text_seed_v1",
                )],
            }),
            metadata: vec![RawDiagnostic::text(
                "policy",
                "live_object_identity",
                "not_recorded",
            )],
        };

        let drag_over = normalized_input_json(&UiEventKind::DragOver(DragOverEvent {
            drag_session_id: "drag-1".to_string(),
            coordinates: coordinates.clone(),
            modifiers: KeyboardModifiers::default(),
            buttons_down: MouseButtons {
                left: true,
                ..MouseButtons::default()
            },
            drag_state: 2,
            effect: 1,
            data: data.clone(),
        }));
        let drop = normalized_input_json(&UiEventKind::DropOrPaste(DropOrPasteEvent {
            transfer_session_id: "drag-1".to_string(),
            origin: DropOrPasteOrigin::DragDrop,
            coordinates,
            modifiers: KeyboardModifiers::default(),
            action: 3,
            effect: 1,
            data,
        }));

        assert_eq!(drag_over["kind"], "drag_over");
        assert_eq!(drop["kind"], "drop_or_paste");
        assert_eq!(
            drop["payload"]["data"]["metadata"][0]["value"]["value"],
            "not_recorded"
        );
    }
}
