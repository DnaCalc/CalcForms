use std::collections::BTreeMap;

use oxforms_pal::{
    render_headless, ActivationReason, CharacterInputEvent, ClickCount, CloseQueryPolicy,
    CloseReason, CloseRequestEvent, CloseRequestOrigin, ControlId, CoordinatePayload,
    CoordinatePoint, CoordinateSpace, DpiScale, FormId, KeyCode, KeyEvent, KeyRepeat,
    KeyboardModifiers, LifecycleReason, LogicalPoint, LogicalRect, LogicalSize, MouseButton,
    MouseButtonEvent, MouseButtons, PointerId, QueryCloseCompletedEvent, RawCoordinateSample,
    RawDiagnostic, RawKeyDiagnostics, ShowMode, ShowRequestedEvent, SurfaceSize, UiEvent,
    UiEventId, UiEventKind, UiEventSource, UiEventTarget, UnloadedEvent, WindowHiddenEvent,
    WindowId, WindowShownEvent, UI_EVENT_SCHEMA_VERSION,
};
use serde_json::{json, Value};

use crate::{
    build_probe_display_list, build_probe_pal_smoke_display_list, hit_test_control_tree,
    ControlNode, DirtyRegionSpace, EffectKind, EffectRequest, FocusTarget, FormState,
    InvalidationReason, LifecycleState, ProbeDisplayList, PumpTerm, ReducerOutput, StateSummary,
};

pub const W005_TRACE_REPLAY_GOLDEN_TRACE_PATH: &str =
    "docs/evidence/W005_input_interaction_model_exploration/trace-replay/w005-headless-probe-replay.golden.v1.json";
pub const W005_TRACE_REPLAY_DISPLAY_LIST_PATH: &str =
    "docs/evidence/W005_input_interaction_model_exploration/trace-replay/w005-headless-probe-display-list.golden.v1.json";

const BEAD: &str = "oxforms-0a0.3";
const TRACE_ID: &str = "w005-headless-probe-replay-golden-v1";
const FORM_ID: &str = "form-main";
const WINDOW_ID: &str = "window-main";
const SURFACE_WIDTH: u32 = 260;
const SURFACE_HEIGHT: u32 = 128;
const DPI: f64 = 96.0;

const FNV_OFFSET_BASIS: u64 = 0xcbf29ce484222325;
const FNV_PRIME: u64 = 0x0000_0100_0000_01b3;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct W005TraceReplayGoldenArtifacts {
    pub trace_json: String,
    pub display_list_json: String,
}

#[must_use]
pub fn build_w005_trace_replay_golden_artifacts() -> W005TraceReplayGoldenArtifacts {
    let mut runner = W005TraceReplayRunner::new();
    runner.run();
    runner.finish()
}

struct W005TraceReplayRunner {
    state: FormState,
    sequence: u64,
    row_index: u64,
    next_ui_event_id: u64,
    dispatch_index: u64,
    display_index: u64,
    render_index: u64,
    rows: Vec<Value>,
    effect_row_ids: BTreeMap<u64, String>,
    display_artifacts: Vec<Value>,
    render_artifacts: Vec<Value>,
    final_display_list: Option<ProbeDisplayList>,
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
            display_index: 1,
            render_index: 1,
            rows: Vec::new(),
            effect_row_ids: BTreeMap::new(),
            display_artifacts: Vec::new(),
            render_artifacts: Vec::new(),
            final_display_list: None,
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
        self.render_probe_surface("initial_window_shown");

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
        self.apply_next_event(|event_id| mouse_button_event(event_id, 176.0, 64.0, false));
        self.complete_non_dispatch_effects();
        self.render_probe_surface("final_after_command_click");

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

    fn finish(self) -> W005TraceReplayGoldenArtifacts {
        let display_list = self
            .final_display_list
            .expect("runner should render at least one display list");
        let display_list_json = pretty_json(&json!(display_list));
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
                    "golden_trace_path": W005_TRACE_REPLAY_GOLDEN_TRACE_PATH,
                    "golden_display_list_path": W005_TRACE_REPLAY_DISPLAY_LIST_PATH
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
                "display_lists": self.display_artifacts,
                "renders": self.render_artifacts,
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
            display_list_json,
        }
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

    fn push_script_step(
        &mut self,
        script_step_id: &str,
        action: &str,
        target: Value,
        point: Option<LogicalPoint>,
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
        self.push_row("script", "input_script_step", payload, None, 0);
    }

    fn apply_event(&mut self, event: UiEvent) {
        let route = route_summary(&self.state, &event);
        self.push_row(
            "input",
            "ui_event",
            ui_event_payload(&event, &route),
            None,
            0,
        );

        if let Some(route_payload) = route.as_ref().map(RouteSummary::to_payload) {
            self.push_row("routing", "routing_decision", route_payload, None, 0);
        }

        let output = crate::reduce(self.state.clone(), event);
        self.push_reducer_transition(&output);
        self.push_effect_requests(&output.effects);
        self.push_invalidations(&output);
        self.state = output.state;
    }

    fn push_reducer_transition(&mut self, output: &ReducerOutput) {
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
            None,
            0,
        );
    }

    fn push_effect_requests(&mut self, effects: &[EffectRequest]) {
        for effect in effects {
            let row_id = self.push_row(
                "effect",
                "effect_requested",
                effect_requested_payload(effect),
                None,
                0,
            );
            self.effect_row_ids
                .insert(effect.effect_id.0, row_id.clone());
            if matches!(effect.kind, EffectKind::FireVbaEvent { .. }) {
                self.push_vba_dispatch(effect, row_id);
            }
        }
    }

    fn push_vba_dispatch(&mut self, effect: &EffectRequest, parent_row_id: String) {
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
            1,
        );
    }

    fn push_invalidations(&mut self, output: &ReducerOutput) {
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
                None,
                0,
            );
        }

        if !output.invalidations.is_empty() {
            self.render_probe_surface("post_invalidation");
        }
    }

    fn complete_non_dispatch_effects(&mut self) {
        let pending = self.state.pending_effects.clone();
        for effect in pending {
            let status = match effect.kind {
                EffectKind::FireVbaEvent { .. } => "recorded_not_executed",
                EffectKind::RequestRepaint { .. } => "completed_by_headless_render",
                EffectKind::TransferFocus { .. }
                | EffectKind::CaptureMouse { .. }
                | EffectKind::ReleaseMouse { .. }
                | EffectKind::CreateWindowSurface { .. }
                | EffectKind::ShowFormModeless { .. }
                | EffectKind::ScheduleModeless => "diagnostic_only",
                _ => "not_applicable_in_headless_subset",
            };
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
                    "diagnostics": []
                }),
                None,
                0,
            );
        }
        self.state.pending_effects.clear();
    }

    fn record_lifecycle_pump(&mut self, before: &str, after: &str, pump_term: &str, cause: &str) {
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
            None,
            0,
        );
    }

    fn render_probe_surface(&mut self, reason: &str) {
        let display_list = build_probe_display_list(
            &self.state,
            LogicalSize::new(f64::from(SURFACE_WIDTH), f64::from(SURFACE_HEIGHT)),
        );
        let display_json = json!(display_list);
        let display_checksum = checksum_label(&pretty_json(&display_json));
        let display_id = format!("display-list-{:04}", self.display_index);
        self.display_index += 1;

        let pal_display_list = build_probe_pal_smoke_display_list(
            &self.state,
            SurfaceSize::new(SURFACE_WIDTH, SURFACE_HEIGHT),
        );
        let render = render_headless(&pal_display_list)
            .expect("W005 probe PAL smoke display list should render headlessly");
        let render_id = format!("render-{:04}", self.render_index);
        self.render_index += 1;

        let display_path = if reason == "final_after_command_click" {
            Some(W005_TRACE_REPLAY_DISPLAY_LIST_PATH)
        } else {
            None
        };

        self.push_row(
            "render",
            "display_list",
            json!({
                "display_list_id": display_id,
                "producer": "oxforms-core::build_probe_display_list",
                "target": {
                    "form_id": FORM_ID,
                    "window_id": WINDOW_ID
                },
                "coordinate_space": "display_list_logical",
                "command_count": display_list.commands.len(),
                "checksum": display_checksum,
                "reason": reason,
                "artifact_ref": {
                    "artifact_id": display_id,
                    "storage": if display_path.is_some() { "repo_file" } else { "inline_trace_row" },
                    "uri_fragment": null,
                    "path": display_path
                }
            }),
            None,
            0,
        );
        self.push_row(
            "render",
            "render_artifact",
            json!({
                "render_id": render_id,
                "source_display_list_id": display_id,
                "target": {
                    "form_id": FORM_ID,
                    "window_id": WINDOW_ID
                },
                "output_kind": "headless_framebuffer_hash",
                "hash_algorithm": render.diagnostics.hash_algorithm,
                "hash": render.diagnostics.framebuffer_hash.to_string(),
                "width": render.diagnostics.width,
                "height": render.diagnostics.height,
                "command_count": render.diagnostics.command_count,
                "artifact_ref": {
                    "artifact_id": render_id,
                    "storage": "inline_trace_row",
                    "uri_fragment": null,
                    "path": null
                }
            }),
            None,
            0,
        );

        self.display_artifacts.push(json!({
            "artifact_id": display_id,
            "role": format!("{reason} probe display-list reference"),
            "storage": if display_path.is_some() { "repo_file" } else { "inline_trace_row" },
            "path": display_path,
            "uri_fragment": null,
            "sha256": null,
            "notes": "Display-list checksum is recorded in the display_list row; file checksums live in trace-replay/checksums.sha256."
        }));
        self.render_artifacts.push(json!({
            "artifact_id": render_id,
            "role": format!("{reason} PAL smoke headless render hash"),
            "storage": "inline_trace_row",
            "path": null,
            "uri_fragment": null,
            "sha256": null,
            "notes": "The hash is over the PAL FillRect smoke framebuffer and does not include text rendering."
        }));
        self.final_display_list = Some(display_list);
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
    payload
}

fn state_summary_json(summary: &StateSummary) -> Value {
    json!({
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
    })
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
        InvalidationReason::TextChanged => "text_changed",
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

fn checksum_label(text: &str) -> String {
    format!("fnv1a64-json-bytes-v1:{:016x}", fnv1a64(text.as_bytes()))
}

fn fnv1a64(bytes: &[u8]) -> u64 {
    let mut hash = FNV_OFFSET_BASIS;
    for byte in bytes {
        hash ^= u64::from(*byte);
        hash = hash.wrapping_mul(FNV_PRIME);
    }
    hash
}

#[cfg(test)]
mod tests {
    use super::*;

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
        assert_eq!(
            artifacts.display_list_json,
            include_str!(concat!(
                env!("CARGO_MANIFEST_DIR"),
                "/../../docs/evidence/W005_input_interaction_model_exploration/trace-replay/w005-headless-probe-display-list.golden.v1.json"
            ))
        );
    }
}
