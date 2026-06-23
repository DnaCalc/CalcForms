//! Deterministic W005 reducer/effects skeleton.
//!
//! The reducer owns logical state transitions only. It records explicit,
//! serializable effects for PAL work, host-capability work, and VBA-compatible
//! event-dispatch requests. Adapters and effect runners outside this crate
//! perform those operations later and feed completions back as normalized
//! [`UiEvent`] rows from `oxforms-pal`.
//!
//! This crate is a host-neutral reference/model layer for W005 and future
//! reducer tests. It is not the final VBA runtime implementation; VBA remains
//! the primary control/runtime home unless profiling and evidence justify a
//! hot-path Rust migration behind the same reducer/effects contract.

#![forbid(unsafe_code)]

mod probe;

use serde::{Deserialize, Serialize};

pub use probe::{hit_test_control_tree, ControlNode, HitTestResult, ProbeControlKind};

use oxforms_pal::{
    CharacterInputEvent, CloseQueryPolicy, CloseRequestEvent, ControlId, FormId, HostScopeId,
    KeyCode, KeyEvent, LifecycleReason, LogicalRect, MouseButton, MouseButtonEvent, MouseMoveEvent,
    PointerId, QueryCloseCompletedEvent, ShowMode, ShowRequestedEvent, UiEvent, UiEventId,
    UiEventKind, UiEventTarget, WindowId, WindowShownEvent,
};

#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct EffectId(pub u64);

#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct InvalidationId(pub u64);

#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct TransitionId(pub u64);

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct FormState {
    pub form_id: FormId,
    pub controls: Vec<ControlNode>,
    pub focus_owner: Option<FocusTarget>,
    pub focus_history: Vec<FocusTarget>,
    pub capture_owner: Option<CaptureOwner>,
    pub hover_path: Vec<ControlId>,
    pub pressed_state: Option<PressedState>,
    pub default_button: Option<ControlId>,
    pub cancel_button: Option<ControlId>,
    pub active: ActiveState,
    pub lifecycle: LifecycleState,
    pub pump: PumpState,
    pub text_boxes: Vec<TextBoxProbeState>,
    pub validation: ValidationState,
    pub dirty: DirtyState,
    pub pending_effects: Vec<EffectRequest>,
    pub trace_counters: TraceCounters,
}

impl FormState {
    #[must_use]
    pub fn new(form_id: impl Into<String>) -> Self {
        let form_id = FormId::new(form_id);
        Self {
            active: ActiveState {
                active_form: None,
                active_window: None,
                modal_owner: None,
            },
            form_id,
            controls: Vec::new(),
            focus_owner: None,
            focus_history: Vec::new(),
            capture_owner: None,
            hover_path: Vec::new(),
            pressed_state: None,
            default_button: None,
            cancel_button: None,
            lifecycle: LifecycleState::Allocated,
            pump: PumpState::default(),
            text_boxes: Vec::new(),
            validation: ValidationState::default(),
            dirty: DirtyState::default(),
            pending_effects: Vec::new(),
            trace_counters: TraceCounters::default(),
        }
    }

    pub fn ensure_text_box(&mut self, control_id: ControlId) -> &mut TextBoxProbeState {
        if let Some(index) = self
            .text_boxes
            .iter()
            .position(|entry| entry.control_id == control_id)
        {
            return &mut self.text_boxes[index];
        }

        self.text_boxes.push(TextBoxProbeState::new(control_id));
        self.text_boxes
            .last_mut()
            .expect("text box entry was just pushed")
    }

    fn next_effect_id(&mut self) -> EffectId {
        self.trace_counters.next_effect += 1;
        EffectId(self.trace_counters.next_effect)
    }

    fn next_invalidation_id(&mut self) -> InvalidationId {
        self.trace_counters.next_invalidation += 1;
        InvalidationId(self.trace_counters.next_invalidation)
    }

    fn next_transition_id(&mut self) -> TransitionId {
        self.trace_counters.next_transition += 1;
        TransitionId(self.trace_counters.next_transition)
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", content = "target", rename_all = "snake_case")]
pub enum FocusTarget {
    Form(FormId),
    Control(ControlId),
}

impl FocusTarget {
    #[must_use]
    pub fn from_event_target(target: &UiEventTarget, default_form: &FormId) -> Self {
        match &target.control_id {
            Some(control_id) => Self::Control(control_id.clone()),
            None => Self::Form(
                target
                    .form_id
                    .clone()
                    .unwrap_or_else(|| default_form.clone()),
            ),
        }
    }

    #[must_use]
    pub fn as_control_id(&self) -> Option<&ControlId> {
        match self {
            Self::Form(_) => None,
            Self::Control(control_id) => Some(control_id),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct CaptureOwner {
    pub target: FocusTarget,
    pub pointer_id: Option<PointerId>,
    pub button: Option<MouseButton>,
    pub reason: CaptureReason,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CaptureReason {
    MousePress,
    Drag,
    PlatformCompletion,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct PressedState {
    pub target: FocusTarget,
    pub origin: PressedOrigin,
    pub armed: bool,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PressedOrigin {
    Mouse,
    KeyboardDefault,
    KeyboardCancel,
    Accelerator,
}

#[derive(Clone, Debug, Default, Eq, PartialEq, Serialize, Deserialize)]
pub struct ActiveState {
    pub active_form: Option<FormId>,
    pub active_window: Option<WindowId>,
    pub modal_owner: Option<UiEventTarget>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LifecycleState {
    Allocated,
    Loading,
    Loaded,
    Initializing,
    Initialized,
    Hidden,
    ShowingModeless,
    ModelessVisible,
    ShowingModal,
    ModalVisible,
    Active,
    Deactivated,
    CloseRequested,
    QueryClosePending,
    CloseCancelled,
    HidePending,
    Unloading,
    Terminated,
    LoadFailed,
    InitFailed,
    UnloadBlocked,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct PumpState {
    pub term: PumpTerm,
    pub nested_modal_depth: u32,
    pub reentrancy_depth: u32,
}

impl Default for PumpState {
    fn default() -> Self {
        Self {
            term: PumpTerm::HostModelessPump,
            nested_modal_depth: 0,
            reentrancy_depth: 0,
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PumpTerm {
    HostModelessPump,
    ModalFrame,
    DoeventsYield,
    VbaDispatchReentrancy,
    HostCallbackReentrancy,
    CloseUnloadCancellation,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct TextBoxProbeState {
    pub control_id: ControlId,
    pub text: String,
    pub caret: TextCaretState,
    pub dirty: bool,
    pub edit_sequence: u64,
}

impl TextBoxProbeState {
    #[must_use]
    pub fn new(control_id: ControlId) -> Self {
        Self {
            control_id,
            text: String::new(),
            caret: TextCaretState::default(),
            dirty: false,
            edit_sequence: 0,
        }
    }
}

#[derive(Clone, Debug, Default, Eq, PartialEq, Serialize, Deserialize)]
pub struct TextCaretState {
    pub anchor: usize,
    pub active: usize,
    pub preferred_column: Option<usize>,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct ValidationState {
    pub pending: Option<ValidationRequest>,
    pub active: bool,
    pub last_result: Option<ValidationResult>,
}

impl Default for ValidationState {
    fn default() -> Self {
        Self {
            pending: None,
            active: false,
            last_result: Some(ValidationResult::Unknown),
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct ValidationRequest {
    pub from: Option<FocusTarget>,
    pub to: Option<FocusTarget>,
    pub cancelable: bool,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ValidationResult {
    Passed,
    Cancelled,
    Failed,
    Unknown,
}

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct DirtyState {
    pub invalidations: Vec<RenderInvalidation>,
    pub subtrees: Vec<UiEventTarget>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct RenderInvalidation {
    pub invalidation_id: InvalidationId,
    pub target: UiEventTarget,
    pub reason: InvalidationReason,
    pub regions: Vec<DirtyRegion>,
    pub dirty_subtrees: Vec<UiEventTarget>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DirtyRegion {
    pub space: DirtyRegionSpace,
    pub rect: LogicalRect,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DirtyRegionSpace {
    DisplayListLogical,
    FormLogical,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum InvalidationReason {
    InitialShow,
    FocusChanged,
    HoverChanged,
    PressedStateChanged,
    TextChanged,
    LifecycleChanged,
    CloseStateChanged,
    Unknown,
}

#[derive(Clone, Debug, Default, Eq, PartialEq, Serialize, Deserialize)]
pub struct TraceCounters {
    pub next_transition: u64,
    pub next_effect: u64,
    pub next_invalidation: u64,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct EffectRequest {
    pub effect_id: EffectId,
    pub cause: EffectCause,
    pub target: UiEventTarget,
    pub kind: EffectKind,
    pub completion_policy: CompletionPolicy,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct EffectCause {
    pub ui_event_id: UiEventId,
    pub transition_id: TransitionId,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", content = "payload", rename_all = "snake_case")]
pub enum EffectKind {
    /// Request a later VBA-compatible event dispatch.
    ///
    /// `oxforms-core` records the request only; it does not execute VBA or
    /// depend on OxVba runtime types.
    FireVbaEvent {
        event_name: String,
        fact_source: Option<String>,
        arguments: Vec<EffectArgument>,
        cancel_metadata: Option<String>,
    },
    RequestRepaint {
        invalidation_ids: Vec<InvalidationId>,
        reason: InvalidationReason,
    },
    CaptureMouse {
        pointer_id: Option<PointerId>,
        button: Option<MouseButton>,
        reason: CaptureReason,
    },
    ReleaseMouse {
        reason: CaptureReason,
    },
    TransferFocus {
        from: Option<FocusTarget>,
        to: FocusTarget,
        reason: FocusTransferReason,
        validation_policy: ValidationPolicy,
    },
    StartTimer {
        timer_id: String,
        interval_millis: u64,
        repeats: bool,
    },
    StopTimer {
        timer_id: String,
    },
    ClipboardGet {
        request_id: String,
        formats: Vec<String>,
    },
    ClipboardSet {
        request_id: String,
        formats: Vec<String>,
    },
    SetCursor {
        cursor: CursorKind,
        reason: String,
    },
    ShowFormModal {
        owner: Option<UiEventTarget>,
        reason: LifecycleReason,
    },
    ShowFormModeless {
        owner: Option<UiEventTarget>,
        reason: LifecycleReason,
    },
    HideForm {
        reason: LifecycleReason,
    },
    CloseForm {
        query_policy: CloseQueryPolicy,
    },
    UnloadForm {
        reason: LifecycleReason,
    },
    HostCapabilityRequest {
        host_namespace: String,
        capability: String,
        host_scope_id: Option<HostScopeId>,
        payload_summary: Option<String>,
    },
    MaterializeForm {
        form_class_name: String,
        default_instance: bool,
    },
    CreateWindowSurface {
        show_mode: ShowMode,
        initial_bounds: Option<LogicalRect>,
    },
    EnterModalFrame {
        modal_depth: u32,
    },
    ScheduleModeless,
    ExitModalFrame {
        modal_depth: u32,
        reason: String,
    },
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct EffectArgument {
    pub name: String,
    pub value: String,
    pub by_ref: bool,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CompletionPolicy {
    ImmediateDiagnostic,
    PlatformCompletionOrDiagnostic,
    ServiceResultRequired,
    DispatchResultRequired,
    WindowShownEventRequired,
    PumpFrameExitRequired,
    RenderDiagnosticOptional,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FocusTransferReason {
    Mouse,
    Keyboard,
    Programmatic,
    WindowActivation,
    Replay,
    Unknown,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ValidationPolicy {
    Skip,
    RequestCancelable,
    RequestNonCancelable,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CursorKind {
    Default,
    IBeam,
    Hand,
    Wait,
    Crosshair,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ReducerOutput {
    pub state: FormState,
    pub transition: ReducerTransition,
    pub effects: Vec<EffectRequest>,
    pub invalidations: Vec<RenderInvalidation>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ReducerTransition {
    pub transition_id: TransitionId,
    pub causal_ui_event_id: UiEventId,
    pub before: StateSummary,
    pub after: StateSummary,
    pub emitted_effect_ids: Vec<EffectId>,
    pub invalidation_ids: Vec<InvalidationId>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct StateSummary {
    pub lifecycle_state: LifecycleState,
    pub pump_term: PumpTerm,
    pub nested_modal_depth: u32,
    pub focus_owner: Option<FocusTarget>,
    pub capture_owner: Option<FocusTarget>,
    pub hover_path: Vec<ControlId>,
    pub pressed_state: Option<PressedState>,
    pub active_form: Option<FormId>,
    pub active_window: Option<WindowId>,
    pub text_values: Vec<TextValueSummary>,
    pub validation_active: bool,
    pub pending_effect_count: usize,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct TextValueSummary {
    pub control_id: ControlId,
    pub text_len: usize,
    pub caret: TextCaretState,
    pub dirty: bool,
}

impl StateSummary {
    #[must_use]
    pub fn from_state(state: &FormState) -> Self {
        Self {
            lifecycle_state: state.lifecycle,
            pump_term: state.pump.term,
            nested_modal_depth: state.pump.nested_modal_depth,
            focus_owner: state.focus_owner.clone(),
            capture_owner: state
                .capture_owner
                .as_ref()
                .map(|capture| capture.target.clone()),
            hover_path: state.hover_path.clone(),
            pressed_state: state.pressed_state.clone(),
            active_form: state.active.active_form.clone(),
            active_window: state.active.active_window.clone(),
            text_values: state
                .text_boxes
                .iter()
                .map(|text_box| TextValueSummary {
                    control_id: text_box.control_id.clone(),
                    text_len: text_box.text.len(),
                    caret: text_box.caret.clone(),
                    dirty: text_box.dirty,
                })
                .collect(),
            validation_active: state.validation.active,
            pending_effect_count: state.pending_effects.len(),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ReducerTraceRow {
    pub row_id: String,
    pub sequence: u64,
    pub logical_tick: u64,
    pub parent_row_id: Option<String>,
    pub nesting_depth: u32,
    pub phase: TracePhase,
    pub kind: TraceRowKind,
    pub payload: ReducerTracePayload,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TracePhase {
    Reducer,
    Effect,
    Render,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TraceRowKind {
    ReducerTransition,
    EffectRequested,
    Invalidation,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(untagged)]
pub enum ReducerTracePayload {
    ReducerTransition(Box<ReducerTransition>),
    EffectRequested(Box<EffectRequest>),
    Invalidation(Box<RenderInvalidation>),
}

#[must_use]
pub fn reduce(mut state: FormState, event: UiEvent) -> ReducerOutput {
    let before = StateSummary::from_state(&state);
    let transition_id = state.next_transition_id();
    let mut context = ReducerContext {
        event: &event,
        transition_id,
        effects: Vec::new(),
        invalidations: Vec::new(),
    };

    match &event.kind {
        UiEventKind::MouseMove(payload) => reduce_mouse_move(&mut state, &mut context, payload),
        UiEventKind::MouseDown(payload) => reduce_mouse_down(&mut state, &mut context, payload),
        UiEventKind::MouseUp(payload) => reduce_mouse_up(&mut state, &mut context, payload),
        UiEventKind::CharacterInput(payload) => {
            reduce_character_input(&mut state, &mut context, payload);
        }
        UiEventKind::KeyDown(payload) => {
            reduce_key_down(&mut state, &mut context, payload);
        }
        UiEventKind::Activate(payload) => {
            state.active.active_form = event.target.form_id.clone().or_else(|| {
                payload
                    .next
                    .as_ref()
                    .and_then(|target| target.form_id.clone())
            });
            state.active.active_window = event.target.window_id.clone().or_else(|| {
                payload
                    .next
                    .as_ref()
                    .and_then(|target| target.window_id.clone())
            });
            state.lifecycle = LifecycleState::Active;
            let target = event_target_or_form(&state, &event);
            queue_vba_event(&mut state, &mut context, target, "Activate");
        }
        UiEventKind::Deactivate(payload) => {
            state.active.active_form = payload
                .next
                .as_ref()
                .and_then(|target| target.form_id.clone());
            state.active.active_window = payload
                .next
                .as_ref()
                .and_then(|target| target.window_id.clone());
            state.lifecycle = LifecycleState::Deactivated;
            let target = event_target_or_form(&state, &event);
            queue_vba_event(&mut state, &mut context, target, "Deactivate");
        }
        UiEventKind::FormInstanceRequested(payload) => {
            state.lifecycle = LifecycleState::Loading;
            let target = UiEventTarget::form(payload.form_id.0.clone());
            context.push_effect(
                &mut state,
                target,
                EffectKind::MaterializeForm {
                    form_class_name: payload.form_class_name.clone(),
                    default_instance: matches!(payload.reason, LifecycleReason::DefaultInstance),
                },
                CompletionPolicy::ServiceResultRequired,
            );
        }
        UiEventKind::FormLoaded(payload) => {
            state.lifecycle = LifecycleState::Initializing;
            let target = UiEventTarget::form(payload.form_id.0.clone());
            queue_vba_event(&mut state, &mut context, target, "Initialize");
        }
        UiEventKind::FormLoadFailed(payload) => {
            if payload.form_id == state.form_id {
                state.lifecycle = LifecycleState::LoadFailed;
            }
        }
        UiEventKind::ShowRequested(payload) => {
            reduce_show_requested(&mut state, &mut context, payload)
        }
        UiEventKind::WindowShown(payload) => reduce_window_shown(&mut state, &mut context, payload),
        UiEventKind::HideRequested(payload) => {
            state.lifecycle = LifecycleState::HidePending;
            let target = UiEventTarget::form(payload.form_id.0.clone());
            context.push_effect(
                &mut state,
                target,
                EffectKind::HideForm {
                    reason: payload.reason,
                },
                CompletionPolicy::PlatformCompletionOrDiagnostic,
            );
        }
        UiEventKind::WindowHidden(payload) => {
            if payload.form_id == state.form_id {
                state.lifecycle = LifecycleState::Hidden;
            }
        }
        UiEventKind::CloseRequest(payload) => {
            reduce_close_request(&mut state, &mut context, payload)
        }
        UiEventKind::QueryCloseCompleted(payload) => {
            reduce_query_close_completed(&mut state, &mut context, payload);
        }
        UiEventKind::UnloadRequested(payload) => {
            state.lifecycle = LifecycleState::Unloading;
            let target = UiEventTarget::form(payload.form_id.0.clone());
            context.push_effect(
                &mut state,
                target,
                EffectKind::UnloadForm {
                    reason: payload.reason,
                },
                CompletionPolicy::PlatformCompletionOrDiagnostic,
            );
        }
        UiEventKind::Unloaded(payload) => {
            if payload.form_id == state.form_id {
                state.lifecycle = LifecycleState::Terminated;
            }
        }
        UiEventKind::Terminated(payload) => {
            if payload.form_id == state.form_id {
                state.lifecycle = LifecycleState::Terminated;
            }
        }
        UiEventKind::PumpYieldRequested(_) => {
            state.pump.term = PumpTerm::DoeventsYield;
            state.pump.reentrancy_depth = event.nesting_depth;
        }
        UiEventKind::PumpFrameExited(payload) => {
            state.pump.nested_modal_depth = payload.modal_depth.saturating_sub(1);
            state.pump.term = if state.pump.nested_modal_depth == 0 {
                PumpTerm::HostModelessPump
            } else {
                PumpTerm::ModalFrame
            };
            let target = UiEventTarget::form(state.form_id.0.clone());
            context.push_effect(
                &mut state,
                target,
                EffectKind::ExitModalFrame {
                    modal_depth: payload.modal_depth,
                    reason: payload.exit_reason.clone(),
                },
                CompletionPolicy::ImmediateDiagnostic,
            );
        }
        _ => {}
    }

    let effects = context.effects;
    let invalidations = context.invalidations;

    state.pending_effects.extend(effects.iter().cloned());
    state
        .dirty
        .invalidations
        .extend(invalidations.iter().cloned());
    for invalidation in &invalidations {
        state
            .dirty
            .subtrees
            .extend(invalidation.dirty_subtrees.iter().cloned());
    }
    let after = StateSummary::from_state(&state);

    let transition = ReducerTransition {
        transition_id,
        causal_ui_event_id: event.event_id,
        before,
        after,
        emitted_effect_ids: effects.iter().map(|effect| effect.effect_id).collect(),
        invalidation_ids: invalidations
            .iter()
            .map(|invalidation| invalidation.invalidation_id)
            .collect(),
    };

    ReducerOutput {
        state,
        transition,
        effects,
        invalidations,
    }
}

#[must_use]
pub fn transition_trace_rows(
    transition: &ReducerTransition,
    effects: &[EffectRequest],
    invalidations: &[RenderInvalidation],
    first_sequence: u64,
    logical_tick: u64,
) -> Vec<ReducerTraceRow> {
    let mut rows = Vec::with_capacity(1 + effects.len() + invalidations.len());
    let mut sequence = first_sequence;
    rows.push(ReducerTraceRow {
        row_id: format!("transition-row-{}", transition.transition_id.0),
        sequence,
        logical_tick,
        parent_row_id: None,
        nesting_depth: 0,
        phase: TracePhase::Reducer,
        kind: TraceRowKind::ReducerTransition,
        payload: ReducerTracePayload::ReducerTransition(Box::new(transition.clone())),
    });

    for effect in effects {
        sequence += 1;
        rows.push(ReducerTraceRow {
            row_id: format!("effect-row-{}", effect.effect_id.0),
            sequence,
            logical_tick,
            parent_row_id: None,
            nesting_depth: 0,
            phase: TracePhase::Effect,
            kind: TraceRowKind::EffectRequested,
            payload: ReducerTracePayload::EffectRequested(Box::new(effect.clone())),
        });
    }

    for invalidation in invalidations {
        sequence += 1;
        rows.push(ReducerTraceRow {
            row_id: format!("invalidation-row-{}", invalidation.invalidation_id.0),
            sequence,
            logical_tick: logical_tick + 1,
            parent_row_id: None,
            nesting_depth: 0,
            phase: TracePhase::Render,
            kind: TraceRowKind::Invalidation,
            payload: ReducerTracePayload::Invalidation(Box::new(invalidation.clone())),
        });
    }

    rows
}

struct ReducerContext<'event> {
    event: &'event UiEvent,
    transition_id: TransitionId,
    effects: Vec<EffectRequest>,
    invalidations: Vec<RenderInvalidation>,
}

impl ReducerContext<'_> {
    fn push_effect(
        &mut self,
        state: &mut FormState,
        target: UiEventTarget,
        kind: EffectKind,
        completion_policy: CompletionPolicy,
    ) {
        self.effects.push(EffectRequest {
            effect_id: state.next_effect_id(),
            cause: EffectCause {
                ui_event_id: self.event.event_id,
                transition_id: self.transition_id,
            },
            target,
            kind,
            completion_policy,
        });
    }

    fn push_invalidation(
        &mut self,
        state: &mut FormState,
        target: UiEventTarget,
        reason: InvalidationReason,
    ) -> InvalidationId {
        let invalidation_id = state.next_invalidation_id();
        self.invalidations.push(RenderInvalidation {
            invalidation_id,
            target: target.clone(),
            reason,
            regions: Vec::new(),
            dirty_subtrees: vec![target],
        });
        invalidation_id
    }
}

fn reduce_mouse_move(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    payload: &MouseMoveEvent,
) {
    let Some(route) = route_mouse_event(state, context.event, &payload.coordinates) else {
        return;
    };
    let target = route.effect_target.clone();

    if route.from_capture {
        queue_vba_event(state, context, target, "MouseMove");
        return;
    }

    let next_hover = route.control_id.into_iter().collect::<Vec<_>>();

    if state.hover_path != next_hover {
        state.hover_path = next_hover;
        let invalidation_id =
            context.push_invalidation(state, target.clone(), InvalidationReason::HoverChanged);
        context.push_effect(
            state,
            target.clone(),
            EffectKind::RequestRepaint {
                invalidation_ids: vec![invalidation_id],
                reason: InvalidationReason::HoverChanged,
            },
            CompletionPolicy::RenderDiagnosticOptional,
        );
    }

    if target.control_id.is_none() && target.form_id.is_none() && target.window_id.is_none() {
        return;
    }

    queue_vba_event(state, context, target, "MouseMove");
}

fn reduce_mouse_down(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    payload: &MouseButtonEvent,
) {
    let Some(route) = route_mouse_event(state, context.event, &payload.coordinates) else {
        return;
    };
    let target = route.focus_target.clone();
    let effect_target = route.effect_target.clone();
    let previous_focus = state.focus_owner.clone();

    if route.can_receive_focus && previous_focus.as_ref() != Some(&target) {
        state.focus_history.push(target.clone());
        state.focus_owner = Some(target.clone());
        context.push_effect(
            state,
            effect_target.clone(),
            EffectKind::TransferFocus {
                from: previous_focus,
                to: target.clone(),
                reason: FocusTransferReason::Mouse,
                validation_policy: ValidationPolicy::RequestCancelable,
            },
            CompletionPolicy::DispatchResultRequired,
        );
        let invalidation_id = context.push_invalidation(
            state,
            effect_target.clone(),
            InvalidationReason::FocusChanged,
        );
        context.push_effect(
            state,
            effect_target.clone(),
            EffectKind::RequestRepaint {
                invalidation_ids: vec![invalidation_id],
                reason: InvalidationReason::FocusChanged,
            },
            CompletionPolicy::RenderDiagnosticOptional,
        );
    }

    state.capture_owner = Some(CaptureOwner {
        target: target.clone(),
        pointer_id: payload.pointer_id,
        button: Some(payload.button),
        reason: CaptureReason::MousePress,
    });

    context.push_effect(
        state,
        effect_target.clone(),
        EffectKind::CaptureMouse {
            pointer_id: payload.pointer_id,
            button: Some(payload.button),
            reason: CaptureReason::MousePress,
        },
        CompletionPolicy::PlatformCompletionOrDiagnostic,
    );
    queue_vba_event(state, context, effect_target.clone(), "MouseDown");

    if route.has_pressed_visual {
        state.pressed_state = Some(PressedState {
            target,
            origin: PressedOrigin::Mouse,
            armed: true,
        });
        let invalidation_id = context.push_invalidation(
            state,
            effect_target.clone(),
            InvalidationReason::PressedStateChanged,
        );
        context.push_effect(
            state,
            effect_target,
            EffectKind::RequestRepaint {
                invalidation_ids: vec![invalidation_id],
                reason: InvalidationReason::PressedStateChanged,
            },
            CompletionPolicy::RenderDiagnosticOptional,
        );
    }
}

fn reduce_mouse_up(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    payload: &MouseButtonEvent,
) {
    let Some(route) = route_mouse_event(state, context.event, &payload.coordinates) else {
        return;
    };
    let effect_target = route.effect_target.clone();
    let captured_target = state
        .capture_owner
        .as_ref()
        .map(|capture| capture.target.clone());
    let pressed_target = state
        .pressed_state
        .as_ref()
        .map(|pressed| pressed.target.clone());

    if state.capture_owner.take().is_some() {
        context.push_effect(
            state,
            effect_target.clone(),
            EffectKind::ReleaseMouse {
                reason: CaptureReason::MousePress,
            },
            CompletionPolicy::PlatformCompletionOrDiagnostic,
        );
    }

    state.pressed_state = None;
    queue_vba_event(state, context, effect_target.clone(), "MouseUp");

    if captured_target.is_some() && route.is_inside_pressed_target {
        queue_vba_event(state, context, effect_target.clone(), "Click");
    }

    if pressed_target.is_some() {
        let invalidation_id = context.push_invalidation(
            state,
            effect_target.clone(),
            InvalidationReason::PressedStateChanged,
        );
        context.push_effect(
            state,
            effect_target,
            EffectKind::RequestRepaint {
                invalidation_ids: vec![invalidation_id],
                reason: InvalidationReason::PressedStateChanged,
            },
            CompletionPolicy::RenderDiagnosticOptional,
        );
    }
}

fn reduce_key_down(state: &mut FormState, context: &mut ReducerContext<'_>, payload: &KeyEvent) {
    if payload.key != KeyCode::Tab {
        return;
    }

    let Some(next_focus) = next_tab_focus_target(
        &state.controls,
        state
            .focus_owner
            .as_ref()
            .and_then(FocusTarget::as_control_id),
        payload.modifiers.shift,
    ) else {
        return;
    };
    let next_target = FocusTarget::Control(next_focus.control_id.clone());
    let previous_focus = state.focus_owner.clone();
    if previous_focus.as_ref() == Some(&next_target) {
        return;
    }

    let effect_target =
        UiEventTarget::control(state.form_id.0.clone(), next_focus.control_id.0.clone());
    state.focus_history.push(next_target.clone());
    state.focus_owner = Some(next_target.clone());
    context.push_effect(
        state,
        effect_target.clone(),
        EffectKind::TransferFocus {
            from: previous_focus,
            to: next_target,
            reason: FocusTransferReason::Keyboard,
            validation_policy: ValidationPolicy::RequestCancelable,
        },
        CompletionPolicy::DispatchResultRequired,
    );
    let invalidation_id = context.push_invalidation(
        state,
        effect_target.clone(),
        InvalidationReason::FocusChanged,
    );
    context.push_effect(
        state,
        effect_target,
        EffectKind::RequestRepaint {
            invalidation_ids: vec![invalidation_id],
            reason: InvalidationReason::FocusChanged,
        },
        CompletionPolicy::RenderDiagnosticOptional,
    );
}

#[derive(Clone, Debug)]
struct RoutedMouseTarget {
    control_id: Option<ControlId>,
    focus_target: FocusTarget,
    effect_target: UiEventTarget,
    can_receive_focus: bool,
    has_pressed_visual: bool,
    from_capture: bool,
    is_inside_pressed_target: bool,
}

fn route_mouse_event(
    state: &FormState,
    event: &UiEvent,
    coordinates: &oxforms_pal::CoordinatePayload,
) -> Option<RoutedMouseTarget> {
    if let Some(capture) = &state.capture_owner {
        let target = target_for_focus(&capture.target, &state.form_id)?;
        let control = capture
            .target
            .as_control_id()
            .and_then(|control_id| find_control(state, control_id));
        let is_inside_pressed_target = coordinates.form_logical.is_none_or(|point| {
            control.is_some_and(|control| control.contains_form_logical(point))
        });
        return Some(RoutedMouseTarget {
            control_id: capture.target.as_control_id().cloned(),
            focus_target: capture.target.clone(),
            effect_target: target,
            can_receive_focus: false,
            has_pressed_visual: false,
            from_capture: true,
            is_inside_pressed_target,
        });
    }

    if let Some(point) = coordinates.form_logical {
        if let Some(hit) = hit_test_control_tree(&state.controls, point) {
            let control = find_control(state, &hit.control_id)
                .expect("hit test result must refer to a control from the same tree");
            return Some(RoutedMouseTarget {
                control_id: Some(hit.control_id.clone()),
                focus_target: FocusTarget::Control(hit.control_id.clone()),
                effect_target: UiEventTarget::control(
                    state.form_id.0.clone(),
                    hit.control_id.0.clone(),
                ),
                can_receive_focus: control.can_receive_focus(),
                has_pressed_visual: control.kind == ProbeControlKind::CommandButton,
                from_capture: false,
                is_inside_pressed_target: true,
            });
        }
        return Some(RoutedMouseTarget {
            control_id: None,
            focus_target: FocusTarget::Form(state.form_id.clone()),
            effect_target: UiEventTarget::form(state.form_id.0.clone()),
            can_receive_focus: false,
            has_pressed_visual: false,
            from_capture: false,
            is_inside_pressed_target: false,
        });
    }

    if state.controls.is_empty()
        && (event.target.form_id.is_some()
            || event.target.window_id.is_some()
            || event.target.control_id.is_some())
    {
        let target = FocusTarget::from_event_target(&event.target, &state.form_id);
        return Some(RoutedMouseTarget {
            control_id: event.target.control_id.clone(),
            focus_target: target,
            effect_target: event_target_or_form(state, event),
            can_receive_focus: true,
            has_pressed_visual: event.target.control_id.is_some(),
            from_capture: false,
            is_inside_pressed_target: true,
        });
    }

    None
}

fn find_control<'a>(state: &'a FormState, control_id: &ControlId) -> Option<&'a ControlNode> {
    state
        .controls
        .iter()
        .find(|control| control.control_id == *control_id)
}

fn next_tab_focus_target<'a>(
    controls: &'a [ControlNode],
    current: Option<&ControlId>,
    reverse: bool,
) -> Option<&'a ControlNode> {
    let mut candidates = controls
        .iter()
        .enumerate()
        .filter(|(_, control)| control.participates_in_tab_order())
        .collect::<Vec<_>>();
    candidates.sort_by_key(|(index, control)| (control.tab_index, *index));

    if candidates.is_empty() {
        return None;
    }

    let current_index = current
        .and_then(|current| {
            candidates
                .iter()
                .position(|(_, control)| control.control_id == *current)
        })
        .unwrap_or_else(|| if reverse { 0 } else { candidates.len() - 1 });
    let next_index = if reverse {
        current_index
            .checked_sub(1)
            .unwrap_or_else(|| candidates.len() - 1)
    } else {
        (current_index + 1) % candidates.len()
    };

    Some(candidates[next_index].1)
}

fn reduce_character_input(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    payload: &CharacterInputEvent,
) {
    let Some(focus_owner) = state.focus_owner.clone() else {
        return;
    };
    let Some(control_id) = focus_owner.as_control_id().cloned() else {
        return;
    };

    let text_box = state.ensure_text_box(control_id.clone());
    let insert_at = text_box.caret.active.min(text_box.text.len());
    text_box.text.insert_str(insert_at, &payload.text);
    let next_caret = insert_at + payload.text.len();
    text_box.caret.anchor = next_caret;
    text_box.caret.active = next_caret;
    text_box.dirty = true;
    text_box.edit_sequence += 1;

    let target = UiEventTarget::control(state.form_id.0.clone(), control_id.0.clone());
    queue_vba_event(state, context, target.clone(), "Change");
    let invalidation_id =
        context.push_invalidation(state, target.clone(), InvalidationReason::TextChanged);
    context.push_effect(
        state,
        target,
        EffectKind::RequestRepaint {
            invalidation_ids: vec![invalidation_id],
            reason: InvalidationReason::TextChanged,
        },
        CompletionPolicy::RenderDiagnosticOptional,
    );
}

fn reduce_show_requested(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    payload: &ShowRequestedEvent,
) {
    let target = UiEventTarget::form(payload.form_id.0.clone());
    state.active.modal_owner = payload.owner.clone();

    match payload.show_mode {
        ShowMode::Modeless => {
            state.lifecycle = LifecycleState::ShowingModeless;
            context.push_effect(
                state,
                target.clone(),
                EffectKind::CreateWindowSurface {
                    show_mode: ShowMode::Modeless,
                    initial_bounds: payload.initial_bounds,
                },
                CompletionPolicy::WindowShownEventRequired,
            );
            context.push_effect(
                state,
                target.clone(),
                EffectKind::ShowFormModeless {
                    owner: payload.owner.clone(),
                    reason: payload.reason,
                },
                CompletionPolicy::ImmediateDiagnostic,
            );
            context.push_effect(
                state,
                target,
                EffectKind::ScheduleModeless,
                CompletionPolicy::ImmediateDiagnostic,
            );
        }
        ShowMode::Modal => {
            state.lifecycle = LifecycleState::ShowingModal;
            state.pump.term = PumpTerm::ModalFrame;
            state.pump.nested_modal_depth += 1;
            context.push_effect(
                state,
                target.clone(),
                EffectKind::CreateWindowSurface {
                    show_mode: ShowMode::Modal,
                    initial_bounds: payload.initial_bounds,
                },
                CompletionPolicy::WindowShownEventRequired,
            );
            context.push_effect(
                state,
                target.clone(),
                EffectKind::ShowFormModal {
                    owner: payload.owner.clone(),
                    reason: payload.reason,
                },
                CompletionPolicy::PumpFrameExitRequired,
            );
            context.push_effect(
                state,
                target,
                EffectKind::EnterModalFrame {
                    modal_depth: state.pump.nested_modal_depth,
                },
                CompletionPolicy::PumpFrameExitRequired,
            );
        }
    }
}

fn reduce_window_shown(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    payload: &WindowShownEvent,
) {
    state.active.active_form = Some(payload.form_id.clone());
    state.active.active_window = Some(payload.window_id.clone());
    state.lifecycle = match payload.show_mode {
        ShowMode::Modal => LifecycleState::ModalVisible,
        ShowMode::Modeless => LifecycleState::ModelessVisible,
    };
    let target = UiEventTarget {
        form_id: Some(payload.form_id.clone()),
        window_id: Some(payload.window_id.clone()),
        control_id: None,
    };
    queue_vba_event(state, context, target.clone(), "Activate");
    let invalidation_id =
        context.push_invalidation(state, target.clone(), InvalidationReason::InitialShow);
    context.push_effect(
        state,
        target,
        EffectKind::RequestRepaint {
            invalidation_ids: vec![invalidation_id],
            reason: InvalidationReason::InitialShow,
        },
        CompletionPolicy::RenderDiagnosticOptional,
    );
}

fn reduce_close_request(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    payload: &CloseRequestEvent,
) {
    let target = event_target_or_form(state, context.event);
    state.lifecycle = LifecycleState::CloseRequested;
    let query_policy = payload.query_policy;

    match query_policy {
        CloseQueryPolicy::Query | CloseQueryPolicy::Unknown => {
            state.lifecycle = LifecycleState::QueryClosePending;
            context.push_effect(
                state,
                target,
                EffectKind::FireVbaEvent {
                    event_name: "QueryClose".to_string(),
                    fact_source: Some("docs/specs/FM20_EVENT_FACTS.md".to_string()),
                    arguments: vec![
                        EffectArgument {
                            name: "Cancel".to_string(),
                            value: "0".to_string(),
                            by_ref: true,
                        },
                        EffectArgument {
                            name: "CloseMode".to_string(),
                            value: format!("{:?}", payload.origin),
                            by_ref: false,
                        },
                    ],
                    cancel_metadata: Some("query_close_cancelable".to_string()),
                },
                CompletionPolicy::DispatchResultRequired,
            );
        }
        CloseQueryPolicy::SkipQuery => {
            context.push_effect(
                state,
                target,
                EffectKind::CloseForm { query_policy },
                CompletionPolicy::PlatformCompletionOrDiagnostic,
            );
        }
    }
}

fn reduce_query_close_completed(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    payload: &QueryCloseCompletedEvent,
) {
    let target = UiEventTarget::form(payload.form_id.0.clone());
    if payload.cancelled {
        state.lifecycle = LifecycleState::CloseCancelled;
        let invalidation_id =
            context.push_invalidation(state, target.clone(), InvalidationReason::CloseStateChanged);
        context.push_effect(
            state,
            target,
            EffectKind::RequestRepaint {
                invalidation_ids: vec![invalidation_id],
                reason: InvalidationReason::CloseStateChanged,
            },
            CompletionPolicy::RenderDiagnosticOptional,
        );
        return;
    }

    state.lifecycle = LifecycleState::Unloading;
    context.push_effect(
        state,
        target,
        EffectKind::UnloadForm {
            reason: LifecycleReason::User,
        },
        CompletionPolicy::PlatformCompletionOrDiagnostic,
    );
}

fn queue_vba_event(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    target: UiEventTarget,
    event_name: &str,
) {
    context.push_effect(
        state,
        target,
        EffectKind::FireVbaEvent {
            event_name: event_name.to_string(),
            fact_source: Some("docs/specs/FM20_EVENT_FACTS.md".to_string()),
            arguments: Vec::new(),
            cancel_metadata: None,
        },
        CompletionPolicy::DispatchResultRequired,
    );
}

fn event_target_or_form(state: &FormState, event: &UiEvent) -> UiEventTarget {
    if event.target.form_id.is_some()
        || event.target.window_id.is_some()
        || event.target.control_id.is_some()
    {
        return event.target.clone();
    }

    UiEventTarget::form(state.form_id.0.clone())
}

fn target_for_focus(target: &FocusTarget, default_form: &FormId) -> Option<UiEventTarget> {
    match target {
        FocusTarget::Form(form_id) => Some(UiEventTarget::form(form_id.0.clone())),
        FocusTarget::Control(control_id) => Some(UiEventTarget::control(
            default_form.0.clone(),
            control_id.0.clone(),
        )),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use oxforms_pal::{
        ActivationEvent, ActivationReason, CharacterInputEvent, ClickCount, KeyCode, KeyRepeat,
        KeyboardModifiers, LogicalPoint, MouseButton, MouseButtonEvent, MouseButtons,
        RawKeyDiagnostics, ShowRequestedEvent, UiEventSource,
    };

    #[test]
    fn mouse_down_records_focus_capture_effects_and_invalidation_in_order() {
        let state = FormState::new("form-main");
        let event = UiEvent {
            target: UiEventTarget::control("form-main", "command-ok"),
            ..UiEvent::new(
                UiEventId(1),
                UiEventSource::Replay,
                UiEventKind::MouseDown(MouseButtonEvent {
                    pointer_id: Some(PointerId(1)),
                    button: MouseButton::Left,
                    buttons_down: MouseButtons {
                        left: true,
                        ..MouseButtons::default()
                    },
                    modifiers: KeyboardModifiers::default(),
                    click_count: ClickCount(1),
                    coordinates: Default::default(),
                }),
            )
        };

        let output = reduce(state, event);

        assert_eq!(output.transition.transition_id, TransitionId(1));
        assert_eq!(output.transition.causal_ui_event_id, UiEventId(1));
        assert_eq!(
            output.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("command-ok")))
        );
        assert_eq!(
            output
                .state
                .capture_owner
                .as_ref()
                .map(|capture| &capture.target),
            Some(&FocusTarget::Control(ControlId::new("command-ok")))
        );
        assert_eq!(
            output
                .state
                .pressed_state
                .as_ref()
                .map(|pressed| &pressed.target),
            Some(&FocusTarget::Control(ControlId::new("command-ok")))
        );
        assert_eq!(
            effect_names(&output.effects),
            vec![
                "transfer_focus",
                "request_repaint",
                "capture_mouse",
                "fire_vba_event:MouseDown",
                "request_repaint"
            ]
        );
        assert_eq!(
            output.transition.emitted_effect_ids,
            vec![
                EffectId(1),
                EffectId(2),
                EffectId(3),
                EffectId(4),
                EffectId(5)
            ]
        );
        assert_eq!(
            output.transition.invalidation_ids,
            vec![InvalidationId(1), InvalidationId(2)]
        );
        assert_eq!(output.transition.after.pending_effect_count, 5);
        assert_eq!(output.state.pending_effects, output.effects);
    }

    #[test]
    fn mouse_up_releases_capture_and_requests_click_dispatch_effects() {
        let state = reduce(
            FormState::new("form-main"),
            UiEvent {
                target: UiEventTarget::control("form-main", "command-ok"),
                ..UiEvent::new(
                    UiEventId(1),
                    UiEventSource::Replay,
                    UiEventKind::MouseDown(mouse_button_event(true)),
                )
            },
        )
        .state;

        let output = reduce(
            state,
            UiEvent {
                target: UiEventTarget::control("form-main", "command-ok"),
                ..UiEvent::new(
                    UiEventId(2),
                    UiEventSource::Replay,
                    UiEventKind::MouseUp(mouse_button_event(false)),
                )
            },
        );

        assert!(output.state.capture_owner.is_none());
        assert!(output.state.pressed_state.is_none());
        assert_eq!(
            effect_names(&output.effects),
            vec![
                "release_mouse",
                "fire_vba_event:MouseUp",
                "fire_vba_event:Click",
                "request_repaint"
            ]
        );
        assert_eq!(
            output.transition.emitted_effect_ids,
            vec![EffectId(6), EffectId(7), EffectId(8), EffectId(9)]
        );
        assert_eq!(output.transition.invalidation_ids, vec![InvalidationId(3)]);
    }

    #[test]
    fn hit_test_uses_half_open_form_logical_bounds_and_control_local_points() {
        let controls = vec![ControlNode::label(
            "label",
            LogicalRect::new(24.0, 24.0, 96.0, 48.0),
            0,
        )];

        let top_left =
            hit_test_control_tree(&controls, LogicalPoint::new(24.0, 24.0)).expect("top-left hit");
        assert_eq!(top_left.control_id, ControlId::new("label"));
        assert_eq!(top_left.control_local, LogicalPoint::new(0.0, 0.0));

        assert!(hit_test_control_tree(&controls, LogicalPoint::new(119.999, 71.999)).is_some());
        assert!(hit_test_control_tree(&controls, LogicalPoint::new(120.0, 71.999)).is_none());
        assert!(hit_test_control_tree(&controls, LogicalPoint::new(119.999, 72.0)).is_none());
    }

    #[test]
    fn hit_test_selects_topmost_z_order_and_excludes_hidden_or_disabled_controls() {
        let controls = vec![
            ControlNode::label("bottom", LogicalRect::new(0.0, 0.0, 50.0, 50.0), 0),
            ControlNode::command_button("top", LogicalRect::new(0.0, 0.0, 50.0, 50.0), 2, 0),
            ControlNode::text_box("disabled", LogicalRect::new(0.0, 0.0, 50.0, 50.0), 4, 1)
                .disabled(),
            ControlNode::command_button("hidden", LogicalRect::new(0.0, 0.0, 50.0, 50.0), 5, 2)
                .hidden(),
        ];

        let hit =
            hit_test_control_tree(&controls, LogicalPoint::new(10.0, 10.0)).expect("visible hit");
        assert_eq!(hit.control_id, ControlId::new("top"));
        assert_eq!(hit.kind, ProbeControlKind::CommandButton);
    }

    #[test]
    fn mouse_down_on_label_routes_mouse_but_does_not_take_focus_or_pressed_state() {
        let mut state = FormState::new("form-main");
        state.controls = vec![ControlNode::label(
            "label",
            LogicalRect::new(10.0, 10.0, 20.0, 20.0),
            0,
        )];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));

        let output = reduce(
            state,
            UiEvent::new(
                UiEventId(41),
                UiEventSource::Replay,
                UiEventKind::MouseDown(mouse_button_event_at(true, 15.0, 15.0)),
            ),
        );

        assert_eq!(
            output.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("text-1")))
        );
        assert_eq!(
            output
                .state
                .capture_owner
                .as_ref()
                .map(|capture| &capture.target),
            Some(&FocusTarget::Control(ControlId::new("label")))
        );
        assert!(output.state.pressed_state.is_none());
        assert_eq!(
            effect_names(&output.effects),
            vec!["capture_mouse", "fire_vba_event:MouseDown"]
        );

        let output = reduce(
            output.state,
            UiEvent::new(
                UiEventId(42),
                UiEventSource::Replay,
                UiEventKind::MouseUp(mouse_button_event_at(false, 15.0, 15.0)),
            ),
        );
        assert_eq!(
            effect_names(&output.effects),
            vec![
                "release_mouse",
                "fire_vba_event:MouseUp",
                "fire_vba_event:Click"
            ]
        );
        assert!(output.invalidations.is_empty());
    }

    #[test]
    fn tab_and_shift_tab_traverse_visible_enabled_focusable_controls() {
        let mut state = FormState::new("form-main");
        state.controls = vec![
            ControlNode::label("label", LogicalRect::new(0.0, 0.0, 20.0, 10.0), 0),
            ControlNode::text_box("text-1", LogicalRect::new(0.0, 20.0, 40.0, 10.0), 0, 0),
            ControlNode::command_button("disabled", LogicalRect::new(0.0, 40.0, 40.0, 10.0), 0, 1)
                .disabled(),
            ControlNode::command_button("ok", LogicalRect::new(0.0, 60.0, 40.0, 10.0), 0, 2),
        ];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));

        let output = reduce(state, key_down_event(UiEventId(43), KeyCode::Tab, false));
        assert_eq!(
            output.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("ok")))
        );
        assert_eq!(
            effect_names(&output.effects),
            vec!["transfer_focus", "request_repaint"]
        );

        let output = reduce(
            output.state,
            key_down_event(UiEventId(44), KeyCode::Tab, true),
        );
        assert_eq!(
            output.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("text-1")))
        );
    }

    #[test]
    fn capture_routes_mouse_move_and_mouse_up_to_press_owner_outside_bounds() {
        let mut state = FormState::new("form-main");
        state.controls = vec![ControlNode::command_button(
            "ok",
            LogicalRect::new(10.0, 10.0, 20.0, 20.0),
            0,
            0,
        )];
        let state = reduce(
            state,
            UiEvent::new(
                UiEventId(45),
                UiEventSource::Replay,
                UiEventKind::MouseDown(mouse_button_event_at(true, 15.0, 15.0)),
            ),
        )
        .state;

        let move_output = reduce(
            state,
            UiEvent::new(
                UiEventId(46),
                UiEventSource::Replay,
                UiEventKind::MouseMove(mouse_move_event_at(80.0, 80.0)),
            ),
        );
        assert_eq!(
            effect_names(&move_output.effects),
            vec!["fire_vba_event:MouseMove"]
        );
        assert_eq!(
            move_output.effects[0].target,
            UiEventTarget::control("form-main", "ok")
        );

        let up_output = reduce(
            move_output.state,
            UiEvent::new(
                UiEventId(50),
                UiEventSource::Replay,
                UiEventKind::MouseUp(mouse_button_event_at(false, 80.0, 80.0)),
            ),
        );
        assert!(up_output.state.capture_owner.is_none());
        assert_eq!(
            effect_names(&up_output.effects),
            vec!["release_mouse", "fire_vba_event:MouseUp", "request_repaint"]
        );
        assert_eq!(
            up_output.effects[1].target,
            UiEventTarget::control("form-main", "ok")
        );
    }

    #[test]
    fn mouse_move_routes_even_when_hover_target_is_unchanged() {
        let mut state = FormState::new("form-main");
        state.controls = vec![ControlNode::text_box(
            "text-1",
            LogicalRect::new(10.0, 10.0, 20.0, 20.0),
            0,
            0,
        )];

        let first = reduce(
            state,
            UiEvent::new(
                UiEventId(48),
                UiEventSource::Replay,
                UiEventKind::MouseMove(mouse_move_event_at(15.0, 15.0)),
            ),
        );
        assert_eq!(first.invalidations.len(), 1);
        assert_eq!(
            effect_names(&first.effects),
            vec!["request_repaint", "fire_vba_event:MouseMove"]
        );

        let second = reduce(
            first.state,
            UiEvent::new(
                UiEventId(49),
                UiEventSource::Replay,
                UiEventKind::MouseMove(mouse_move_event_at(16.0, 16.0)),
            ),
        );
        assert!(second.invalidations.is_empty());
        assert_eq!(
            effect_names(&second.effects),
            vec!["fire_vba_event:MouseMove"]
        );
    }

    #[test]
    fn routed_trace_rows_include_focus_and_pressed_invalidations() {
        let mut state = FormState::new("form-main");
        state.controls = vec![ControlNode::command_button(
            "ok",
            LogicalRect::new(10.0, 10.0, 20.0, 20.0),
            0,
            0,
        )];
        let output = reduce(
            state,
            UiEvent::new(
                UiEventId(47),
                UiEventSource::Replay,
                UiEventKind::MouseDown(mouse_button_event_at(true, 15.0, 15.0)),
            ),
        );

        let rows = transition_trace_rows(
            &output.transition,
            &output.effects,
            &output.invalidations,
            10,
            5,
        );
        let encoded =
            serde_json::to_string_pretty(&rows).expect("routing trace rows should serialize");

        assert_eq!(output.invalidations.len(), 2);
        assert!(encoded.contains("focus_changed"));
        assert!(encoded.contains("pressed_state_changed"));
        assert!(encoded.contains("request_repaint"));
    }

    #[test]
    fn character_input_updates_textbox_probe_and_emits_change_effect() {
        let mut state = FormState::new("form-main");
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
        state.ensure_text_box(ControlId::new("text-1"));

        let output = reduce(
            state,
            UiEvent {
                target: UiEventTarget::control("form-main", "text-1"),
                ..UiEvent::new(
                    UiEventId(9),
                    UiEventSource::Replay,
                    UiEventKind::CharacterInput(CharacterInputEvent {
                        text: "A".to_string(),
                        modifiers: KeyboardModifiers::default(),
                        raw: Vec::new(),
                    }),
                )
            },
        );

        let text_box = output
            .state
            .text_boxes
            .iter()
            .find(|entry| entry.control_id == ControlId::new("text-1"))
            .expect("text box state should exist");
        assert_eq!(text_box.text, "A");
        assert_eq!(text_box.caret.active, 1);
        assert!(text_box.dirty);
        assert_eq!(
            effect_names(&output.effects),
            vec!["fire_vba_event:Change", "request_repaint"]
        );
        assert_eq!(output.transition.invalidation_ids, vec![InvalidationId(1)]);
    }

    #[test]
    fn lifecycle_show_requested_keeps_platform_work_as_effects() {
        let state = FormState::new("form-main");
        let output = reduce(
            state,
            UiEvent {
                target: UiEventTarget::form("form-main"),
                ..UiEvent::new(
                    UiEventId(20),
                    UiEventSource::Replay,
                    UiEventKind::ShowRequested(ShowRequestedEvent {
                        form_id: FormId::new("form-main"),
                        show_mode: ShowMode::Modal,
                        owner: Some(UiEventTarget::form("owner-form")),
                        initial_bounds: Some(LogicalRect::new(0.0, 0.0, 240.0, 180.0)),
                        reason: LifecycleReason::Replay,
                    }),
                )
            },
        );

        assert_eq!(output.state.lifecycle, LifecycleState::ShowingModal);
        assert_eq!(output.state.pump.term, PumpTerm::ModalFrame);
        assert_eq!(output.state.pump.nested_modal_depth, 1);
        assert_eq!(
            effect_names(&output.effects),
            vec![
                "create_window_surface",
                "show_form_modal",
                "enter_modal_frame"
            ]
        );
    }

    #[test]
    fn activation_effect_is_explicit_and_serializable() {
        let output = reduce(
            FormState::new("form-main"),
            UiEvent {
                target: UiEventTarget {
                    form_id: Some(FormId::new("form-main")),
                    window_id: Some(WindowId::new("window-main")),
                    control_id: None,
                },
                ..UiEvent::new(
                    UiEventId(21),
                    UiEventSource::Pal,
                    UiEventKind::Activate(ActivationEvent {
                        reason: ActivationReason::WindowShown,
                        previous: None,
                        next: Some(UiEventTarget::form("form-main")),
                    }),
                )
            },
        );

        let encoded =
            serde_json::to_string(&output.effects).expect("effects should serialize to JSON");
        assert!(encoded.contains("fire_vba_event"));
        assert!(encoded.contains("Activate"));
        assert_eq!(
            output.state.active.active_form,
            Some(FormId::new("form-main"))
        );
        assert_eq!(
            output.state.active.active_window,
            Some(WindowId::new("window-main"))
        );
    }

    #[test]
    fn transition_log_rows_match_trace_schema_vocabulary() {
        let output = reduce(
            FormState::new("form-main"),
            UiEvent {
                target: UiEventTarget::control("form-main", "command-ok"),
                ..UiEvent::new(
                    UiEventId(30),
                    UiEventSource::Replay,
                    UiEventKind::MouseDown(mouse_button_event(true)),
                )
            },
        );

        let rows = transition_trace_rows(
            &output.transition,
            &output.effects,
            &output.invalidations,
            3,
            2,
        );
        let encoded =
            serde_json::to_string_pretty(&rows).expect("transition rows should serialize");

        assert_eq!(rows.len(), 8);
        assert!(encoded.contains("reducer_transition"));
        assert!(encoded.contains("effect_requested"));
        assert!(encoded.contains("invalidation"));
        assert!(encoded.contains("dirty_subtrees"));
    }

    #[test]
    fn reducer_skeleton_trace_sample_remains_parseable_as_historical_artifact() {
        let sample = include_str!(
            "../../../docs/evidence/W005_input_interaction_model_exploration/trace-replay/reducer-skeleton-transition-log.v1.json"
        );
        let trace: serde_json::Value =
            serde_json::from_str(sample).expect("reducer skeleton trace sample should parse");
        let transition = trace["rows"]
            .as_array()
            .expect("trace rows should be an array")
            .iter()
            .find(|row| row["row_id"] == "row-0004")
            .expect("row-0004 reducer transition should exist");
        let payload = &transition["payload"];

        assert_eq!(payload["before"]["pending_effect_count"].as_u64(), Some(0));
        assert_eq!(
            payload["after"]["pending_effect_count"].as_u64(),
            payload["emitted_effect_ids"]
                .as_array()
                .map(|ids| ids.len() as u64)
        );
    }

    #[test]
    fn unused_keyboard_shape_does_not_gain_hidden_behavior() {
        let event = UiEvent::new(
            UiEventId(40),
            UiEventSource::Replay,
            UiEventKind::KeyDown(oxforms_pal::KeyEvent {
                key: oxforms_pal::KeyCode::Enter,
                modifiers: KeyboardModifiers::default(),
                repeat: KeyRepeat::default(),
                raw: RawKeyDiagnostics::default(),
            }),
        );

        let output = reduce(FormState::new("form-main"), event);

        assert!(output.effects.is_empty());
        assert!(output.invalidations.is_empty());
        assert!(output.state.pending_effects.is_empty());
    }

    fn mouse_button_event(left_down: bool) -> MouseButtonEvent {
        MouseButtonEvent {
            pointer_id: Some(PointerId(1)),
            button: MouseButton::Left,
            buttons_down: MouseButtons {
                left: left_down,
                ..MouseButtons::default()
            },
            modifiers: KeyboardModifiers::default(),
            click_count: ClickCount(1),
            coordinates: Default::default(),
        }
    }

    fn mouse_button_event_at(left_down: bool, x: f64, y: f64) -> MouseButtonEvent {
        MouseButtonEvent {
            coordinates: oxforms_pal::CoordinatePayload {
                form_logical: Some(LogicalPoint::new(x, y)),
                ..Default::default()
            },
            ..mouse_button_event(left_down)
        }
    }

    fn mouse_move_event_at(x: f64, y: f64) -> MouseMoveEvent {
        MouseMoveEvent {
            pointer_id: Some(PointerId(1)),
            buttons_down: MouseButtons {
                left: true,
                ..MouseButtons::default()
            },
            modifiers: KeyboardModifiers::default(),
            coordinates: oxforms_pal::CoordinatePayload {
                form_logical: Some(LogicalPoint::new(x, y)),
                ..Default::default()
            },
        }
    }

    fn key_down_event(event_id: UiEventId, key: KeyCode, shift: bool) -> UiEvent {
        UiEvent::new(
            event_id,
            UiEventSource::Replay,
            UiEventKind::KeyDown(oxforms_pal::KeyEvent {
                key,
                modifiers: KeyboardModifiers {
                    shift,
                    ..KeyboardModifiers::default()
                },
                repeat: KeyRepeat::default(),
                raw: RawKeyDiagnostics::default(),
            }),
        )
    }

    fn effect_names(effects: &[EffectRequest]) -> Vec<String> {
        effects
            .iter()
            .map(|effect| match &effect.kind {
                EffectKind::FireVbaEvent { event_name, .. } => {
                    format!("fire_vba_event:{event_name}")
                }
                EffectKind::RequestRepaint { .. } => "request_repaint".to_string(),
                EffectKind::CaptureMouse { .. } => "capture_mouse".to_string(),
                EffectKind::ReleaseMouse { .. } => "release_mouse".to_string(),
                EffectKind::TransferFocus { .. } => "transfer_focus".to_string(),
                EffectKind::StartTimer { .. } => "start_timer".to_string(),
                EffectKind::StopTimer { .. } => "stop_timer".to_string(),
                EffectKind::ClipboardGet { .. } => "clipboard_get".to_string(),
                EffectKind::ClipboardSet { .. } => "clipboard_set".to_string(),
                EffectKind::SetCursor { .. } => "set_cursor".to_string(),
                EffectKind::ShowFormModal { .. } => "show_form_modal".to_string(),
                EffectKind::ShowFormModeless { .. } => "show_form_modeless".to_string(),
                EffectKind::HideForm { .. } => "hide_form".to_string(),
                EffectKind::CloseForm { .. } => "close_form".to_string(),
                EffectKind::UnloadForm { .. } => "unload_form".to_string(),
                EffectKind::HostCapabilityRequest { .. } => "host_capability_request".to_string(),
                EffectKind::MaterializeForm { .. } => "materialize_form".to_string(),
                EffectKind::CreateWindowSurface { .. } => "create_window_surface".to_string(),
                EffectKind::EnterModalFrame { .. } => "enter_modal_frame".to_string(),
                EffectKind::ScheduleModeless => "schedule_modeless".to_string(),
                EffectKind::ExitModalFrame { .. } => "exit_modal_frame".to_string(),
            })
            .collect()
    }
}
