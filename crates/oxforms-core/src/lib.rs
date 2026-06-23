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

mod frm;
mod probe;
mod trace_replay;

use serde::{Deserialize, Serialize};

pub use frm::{
    load_selected_frm_interaction_state, FrmControlEventHooks, FrmControlRecord, FrmFrxReference,
    FrmInteractionModel, FrmLoadError, FrmUnsupportedRecord, COORDINATE_MODEL_SPEC_PATH,
};
pub use probe::{hit_test_control_tree, ControlKind, ControlNode, HitTestResult};
pub use trace_replay::{
    build_w005_trace_replay_golden_artifacts, build_w006_modal_frame_trace_subset_artifact,
    W005_TRACE_REPLAY_DISPLAY_LIST_PATH, W005_TRACE_REPLAY_GOLDEN_TRACE_PATH,
    W006_MODAL_FRAME_TRACE_PATH,
};

use oxforms_pal::{
    CharacterInputEvent, ClipboardOperation, ClipboardResultEvent, CloseQueryPolicy, CloseReason,
    CloseRequestEvent, CloseRequestOrigin, Color, ControlId, DataObjectSnapshot, DisplayList,
    DragOverEvent, DropOrPasteEvent, DropOrPasteOrigin, FormId, HostScopeId, KeyCode, KeyEvent,
    KeyRepeat, KeyboardModifiers, LifecycleReason, LogicalPoint, LogicalRect, LogicalSize,
    MouseButton, MouseButtonEvent, MouseMoveEvent, PointerId, QueryCloseCompletedEvent,
    RawKeyDiagnostics, Rect as PalRect, ServiceOutcome, ShowMode, ShowRequestedEvent, SurfaceSize,
    UiEvent, UiEventId, UiEventKind, UiEventTarget, WindowId, WindowShownEvent,
};

pub const PROBE_DISPLAY_LIST_SCHEMA_VERSION: u16 = 1;
pub const CHECKBOX_DISPLAY_LIST_SCHEMA_VERSION: u16 = 2;

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
    pub keyboard: KeyboardState,
    pub active: ActiveState,
    pub lifecycle: LifecycleState,
    pub pump: PumpState,
    pub close_flow: Option<CloseFlowState>,
    pub text_boxes: Vec<TextBoxProbeState>,
    pub check_boxes: Vec<CheckBoxState>,
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
            keyboard: KeyboardState::default(),
            lifecycle: LifecycleState::Allocated,
            pump: PumpState::default(),
            close_flow: None,
            text_boxes: Vec::new(),
            check_boxes: Vec::new(),
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

    pub fn ensure_check_box(&mut self, control_id: ControlId) -> &mut CheckBoxState {
        if let Some(index) = self
            .check_boxes
            .iter()
            .position(|entry| entry.control_id == control_id)
        {
            return &mut self.check_boxes[index];
        }

        self.check_boxes.push(CheckBoxState::new(control_id));
        self.check_boxes
            .last_mut()
            .expect("check box entry was just pushed")
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

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct CloseFlowState {
    pub origin: CloseRequestOrigin,
    pub reason: CloseReason,
    pub close_mode: Option<i32>,
    pub cancelled: Option<bool>,
    pub awaiting_window_hide_for_unload: bool,
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

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct CheckBoxState {
    pub control_id: ControlId,
    pub checked: bool,
    pub dirty: bool,
    pub edit_sequence: u64,
}

impl CheckBoxState {
    #[must_use]
    pub fn new(control_id: ControlId) -> Self {
        Self {
            control_id,
            checked: false,
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

#[derive(Clone, Debug, Default, Eq, PartialEq, Serialize, Deserialize)]
pub struct KeyboardState {
    pub last_key_down: Option<KeyEventSummary>,
    pub last_key_up: Option<KeyEventSummary>,
    pub last_character_input: Option<CharacterInputSummary>,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct KeyEventSummary {
    pub key: KeyCode,
    pub modifiers: KeyboardModifiers,
    pub repeat: KeyRepeat,
    pub raw: RawKeyDiagnostics,
}

impl From<&KeyEvent> for KeyEventSummary {
    fn from(event: &KeyEvent) -> Self {
        Self {
            key: event.key.clone(),
            modifiers: event.modifiers,
            repeat: event.repeat,
            raw: event.raw,
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct CharacterInputSummary {
    pub text_len: usize,
    pub modifiers: KeyboardModifiers,
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
    CheckBoxValueChanged,
    CheckBoxPressedChanged,
    TextChanged,
    TextSelectionChanged,
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
    pub close_flow: Option<CloseFlowState>,
    pub text_values: Vec<TextValueSummary>,
    pub check_box_values: Vec<CheckBoxValueSummary>,
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

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct CheckBoxValueSummary {
    pub control_id: ControlId,
    pub checked: bool,
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
            close_flow: state.close_flow.clone(),
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
            check_box_values: state
                .check_boxes
                .iter()
                .map(|check_box| CheckBoxValueSummary {
                    control_id: check_box.control_id.clone(),
                    checked: check_box.checked,
                    dirty: check_box.dirty,
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

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ProbeDisplayList {
    pub schema_version: u16,
    pub form_id: FormId,
    pub surface: LogicalSize,
    pub commands: Vec<ProbeDisplayCommand>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", content = "payload", rename_all = "snake_case")]
pub enum ProbeDisplayCommand {
    FillRect {
        target: UiEventTarget,
        rect: LogicalRect,
        color: ProbeColor,
        role: ProbeDisplayRole,
    },
    StrokeRect {
        target: UiEventTarget,
        rect: LogicalRect,
        color: ProbeColor,
        role: ProbeDisplayRole,
    },
    DrawText {
        target: UiEventTarget,
        rect: LogicalRect,
        text: String,
        color: ProbeColor,
        role: ProbeDisplayRole,
    },
    CheckMark {
        target: UiEventTarget,
        rect: LogicalRect,
        color: ProbeColor,
        role: ProbeDisplayRole,
    },
    Caret {
        target: UiEventTarget,
        x: f64,
        y: f64,
        height: f64,
        caret_index: usize,
        color: ProbeColor,
    },
    FocusRect {
        target: UiEventTarget,
        rect: LogicalRect,
        color: ProbeColor,
    },
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct ProbeColor {
    pub red: u8,
    pub green: u8,
    pub blue: u8,
    pub alpha: u8,
}

impl ProbeColor {
    #[must_use]
    pub const fn rgba(red: u8, green: u8, blue: u8, alpha: u8) -> Self {
        Self {
            red,
            green,
            blue,
            alpha,
        }
    }

    #[must_use]
    pub const fn to_pal_color(self) -> Color {
        Color::rgba(self.red, self.green, self.blue, self.alpha)
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProbeDisplayRole {
    LabelFace,
    LabelText,
    CommandButtonFace,
    CommandButtonPressedFace,
    CommandButtonText,
    TextBoxFace,
    TextBoxText,
    CheckBoxFace,
    CheckBoxPressedFace,
    CheckBoxText,
    CheckBoxGlyph,
    CheckBoxCheckMark,
    Border,
    DisabledOverlay,
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
        UiEventKind::KeyUp(payload) => {
            reduce_key_up(&mut state, &mut context, payload);
        }
        UiEventKind::ClipboardResult(payload) => {
            reduce_clipboard_result(&mut state, &mut context, payload);
        }
        UiEventKind::DragOver(payload) => {
            reduce_drag_over(&mut state, &mut context, payload);
        }
        UiEventKind::DropOrPaste(payload) => {
            reduce_drop_or_paste(&mut state, &mut context, payload);
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
                if state
                    .close_flow
                    .as_ref()
                    .is_some_and(|flow| flow.awaiting_window_hide_for_unload)
                {
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
                } else {
                    state.lifecycle = LifecycleState::Hidden;
                }
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
                state.lifecycle = LifecycleState::Hidden;
                if state.pump.nested_modal_depth == 0 {
                    state.pump.term = PumpTerm::HostModelessPump;
                }
                state.close_flow = None;
            }
        }
        UiEventKind::Terminated(payload) => {
            if payload.form_id == state.form_id {
                state.lifecycle = LifecycleState::Terminated;
                state.close_flow = None;
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

#[must_use]
pub fn build_probe_display_list(state: &FormState, surface: LogicalSize) -> ProbeDisplayList {
    let mut commands = Vec::new();
    for control in visible_controls_in_paint_order(&state.controls) {
        let target = UiEventTarget::control(state.form_id.0.clone(), control.control_id.0.clone());
        let is_focused = state
            .focus_owner
            .as_ref()
            .and_then(FocusTarget::as_control_id)
            == Some(&control.control_id);
        let is_pressed = state
            .pressed_state
            .as_ref()
            .and_then(|pressed| pressed.target.as_control_id())
            == Some(&control.control_id);

        let face_role = match (control.kind, is_pressed) {
            (ControlKind::CheckBox, true) => ProbeDisplayRole::CheckBoxPressedFace,
            (ControlKind::CheckBox, false) => ProbeDisplayRole::CheckBoxFace,
            (ControlKind::CommandButton, true) => ProbeDisplayRole::CommandButtonPressedFace,
            (ControlKind::CommandButton, false) => ProbeDisplayRole::CommandButtonFace,
            (ControlKind::Label, _) => ProbeDisplayRole::LabelFace,
            (ControlKind::TextBox, _) => ProbeDisplayRole::TextBoxFace,
        };
        commands.push(ProbeDisplayCommand::FillRect {
            target: target.clone(),
            rect: control.bounds,
            color: probe_face_color(control.kind, is_pressed, control.enabled),
            role: face_role,
        });
        commands.push(ProbeDisplayCommand::StrokeRect {
            target: target.clone(),
            rect: control.bounds,
            color: ProbeColor::rgba(0x64, 0x64, 0x64, 0xff),
            role: ProbeDisplayRole::Border,
        });

        if control.kind == ControlKind::CheckBox {
            let glyph_rect = check_box_glyph_rect(control.bounds);
            commands.push(ProbeDisplayCommand::FillRect {
                target: target.clone(),
                rect: glyph_rect,
                color: ProbeColor::rgba(0xff, 0xff, 0xff, 0xff),
                role: ProbeDisplayRole::CheckBoxGlyph,
            });
            commands.push(ProbeDisplayCommand::StrokeRect {
                target: target.clone(),
                rect: glyph_rect,
                color: ProbeColor::rgba(0x32, 0x32, 0x32, 0xff),
                role: ProbeDisplayRole::CheckBoxGlyph,
            });
            if check_box_state(state, &control.control_id).is_some_and(|entry| entry.checked) {
                commands.push(ProbeDisplayCommand::CheckMark {
                    target: target.clone(),
                    rect: inset_rect(glyph_rect, 2.0, 2.0),
                    color: probe_text_color(control.kind, control.enabled),
                    role: ProbeDisplayRole::CheckBoxCheckMark,
                });
            }
        }

        let text = display_text_for_control(state, control);
        if !text.is_empty() {
            let role = match control.kind {
                ControlKind::CheckBox => ProbeDisplayRole::CheckBoxText,
                ControlKind::Label => ProbeDisplayRole::LabelText,
                ControlKind::CommandButton => ProbeDisplayRole::CommandButtonText,
                ControlKind::TextBox => ProbeDisplayRole::TextBoxText,
            };
            commands.push(ProbeDisplayCommand::DrawText {
                target: target.clone(),
                rect: text_rect_for_control(control),
                text,
                color: probe_text_color(control.kind, control.enabled),
                role,
            });
        }

        if !control.enabled {
            commands.push(ProbeDisplayCommand::FillRect {
                target: target.clone(),
                rect: control.bounds,
                color: ProbeColor::rgba(0xf0, 0xf0, 0xf0, 0x80),
                role: ProbeDisplayRole::DisabledOverlay,
            });
        }

        if is_focused && control.kind != ControlKind::Label {
            commands.push(ProbeDisplayCommand::FocusRect {
                target: target.clone(),
                rect: inset_rect(control.bounds, 2.0, 2.0),
                color: ProbeColor::rgba(0x00, 0x00, 0x00, 0xff),
            });
        }

        if is_focused && control.kind == ControlKind::TextBox {
            if let Some(text_box) = text_box_state(state, &control.control_id) {
                let x = caret_x(control.bounds, text_box.caret.active);
                commands.push(ProbeDisplayCommand::Caret {
                    target,
                    x,
                    y: control.bounds.y + 3.0,
                    height: (control.bounds.height - 6.0).max(1.0),
                    caret_index: text_box.caret.active,
                    color: ProbeColor::rgba(0x00, 0x00, 0x00, 0xff),
                });
            }
        }
    }

    ProbeDisplayList {
        schema_version: display_list_schema_version(state),
        form_id: state.form_id.clone(),
        surface,
        commands,
    }
}

fn display_list_schema_version(state: &FormState) -> u16 {
    if state
        .controls
        .iter()
        .any(|control| control.kind == ControlKind::CheckBox)
    {
        CHECKBOX_DISPLAY_LIST_SCHEMA_VERSION
    } else {
        PROBE_DISPLAY_LIST_SCHEMA_VERSION
    }
}

#[must_use]
pub fn build_probe_pal_smoke_display_list(state: &FormState, surface: SurfaceSize) -> DisplayList {
    let mut display_list = DisplayList::new(surface);
    for command in build_probe_display_list(
        state,
        LogicalSize::new(f64::from(surface.width), f64::from(surface.height)),
    )
    .commands
    {
        let ProbeDisplayCommand::FillRect {
            rect, color, role, ..
        } = command
        else {
            continue;
        };

        if matches!(role, ProbeDisplayRole::DisabledOverlay) {
            continue;
        }

        if let Some(rect) = pal_rect_from_logical(rect) {
            display_list = display_list.with_fill_rect(rect, color.to_pal_color());
        }
    }

    display_list
}

fn visible_controls_in_paint_order(controls: &[ControlNode]) -> Vec<&ControlNode> {
    let mut controls = controls
        .iter()
        .enumerate()
        .filter(|(_, control)| control.visible)
        .collect::<Vec<_>>();
    controls.sort_by_key(|(index, control)| (control.z_order, *index));
    controls
        .into_iter()
        .map(|(_, control)| control)
        .collect::<Vec<_>>()
}

fn display_text_for_control(state: &FormState, control: &ControlNode) -> String {
    match control.kind {
        ControlKind::CheckBox | ControlKind::Label | ControlKind::CommandButton => {
            control.caption.clone()
        }
        ControlKind::TextBox => text_box_state(state, &control.control_id)
            .map(|text_box| text_box.text.clone())
            .unwrap_or_default(),
    }
}

fn text_box_state<'a>(
    state: &'a FormState,
    control_id: &ControlId,
) -> Option<&'a TextBoxProbeState> {
    state
        .text_boxes
        .iter()
        .find(|entry| entry.control_id == *control_id)
}

fn check_box_state<'a>(state: &'a FormState, control_id: &ControlId) -> Option<&'a CheckBoxState> {
    state
        .check_boxes
        .iter()
        .find(|entry| entry.control_id == *control_id)
}

fn probe_face_color(kind: ControlKind, is_pressed: bool, is_enabled: bool) -> ProbeColor {
    if !is_enabled {
        return ProbeColor::rgba(0xd9, 0xd9, 0xd9, 0xff);
    }

    match kind {
        ControlKind::CheckBox if is_pressed => ProbeColor::rgba(0xe8, 0xe8, 0xe8, 0xff),
        ControlKind::CheckBox => ProbeColor::rgba(0xf8, 0xf8, 0xf8, 0xff),
        ControlKind::Label => ProbeColor::rgba(0x20, 0x70, 0xc0, 0xff),
        ControlKind::CommandButton if is_pressed => ProbeColor::rgba(0xb8, 0xc7, 0xdd, 0xff),
        ControlKind::CommandButton => ProbeColor::rgba(0xdc, 0xdc, 0xdc, 0xff),
        ControlKind::TextBox => ProbeColor::rgba(0xff, 0xff, 0xff, 0xff),
    }
}

fn probe_text_color(kind: ControlKind, is_enabled: bool) -> ProbeColor {
    if !is_enabled {
        return ProbeColor::rgba(0x80, 0x80, 0x80, 0xff);
    }

    match kind {
        ControlKind::Label => ProbeColor::rgba(0xff, 0xff, 0xff, 0xff),
        ControlKind::CheckBox | ControlKind::CommandButton | ControlKind::TextBox => {
            ProbeColor::rgba(0x00, 0x00, 0x00, 0xff)
        }
    }
}

fn text_rect_for_control(control: &ControlNode) -> LogicalRect {
    if control.kind == ControlKind::CheckBox {
        let left = control.bounds.x + 22.0;
        LogicalRect::new(
            left,
            control.bounds.y + 1.0,
            (control.bounds.x + control.bounds.width - left - 2.0).max(1.0),
            (control.bounds.height - 2.0).max(1.0),
        )
    } else {
        inset_rect(control.bounds, 4.0, 3.0)
    }
}

fn check_box_glyph_rect(bounds: LogicalRect) -> LogicalRect {
    let size = bounds.height.clamp(6.0, 13.0);
    LogicalRect::new(
        bounds.x + 3.0,
        bounds.y + ((bounds.height - size) / 2.0),
        size,
        size,
    )
}

fn inset_rect(rect: LogicalRect, dx: f64, dy: f64) -> LogicalRect {
    LogicalRect::new(
        rect.x + dx,
        rect.y + dy,
        (rect.width - (dx * 2.0)).max(1.0),
        (rect.height - (dy * 2.0)).max(1.0),
    )
}

fn caret_x(bounds: LogicalRect, caret_index: usize) -> f64 {
    let approximate_cell_width = 6.0;
    let left_padding = 4.0;
    let right_padding = 3.0;
    let max_x = (bounds.x + bounds.width - right_padding).max(bounds.x + left_padding);
    (bounds.x + left_padding + (caret_index as f64 * approximate_cell_width)).min(max_x)
}

fn pal_rect_from_logical(rect: LogicalRect) -> Option<PalRect> {
    let x = round_to_i32(rect.x)?;
    let y = round_to_i32(rect.y)?;
    let width = round_to_i32(rect.width.max(1.0))?;
    let height = round_to_i32(rect.height.max(1.0))?;
    if width <= 0 || height <= 0 {
        return None;
    }

    Some(PalRect::new(x, y, width, height))
}

fn round_to_i32(value: f64) -> Option<i32> {
    if !value.is_finite() {
        return None;
    }

    let rounded = value.round();
    if rounded < f64::from(i32::MIN) || rounded > f64::from(i32::MAX) {
        return None;
    }

    Some(rounded as i32)
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
        queue_mouse_move_event(state, context, target, payload, &route);
        return;
    }

    let next_hover = route.control_id.clone().into_iter().collect::<Vec<_>>();

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

    queue_mouse_move_event(state, context, target, payload, &route);
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
    queue_mouse_event(
        state,
        context,
        effect_target.clone(),
        "MouseDown",
        payload,
        &route,
    );

    if route.has_pressed_visual {
        state.pressed_state = Some(PressedState {
            target,
            origin: PressedOrigin::Mouse,
            armed: true,
        });
        let reason = route
            .control_id
            .as_ref()
            .map_or(InvalidationReason::PressedStateChanged, |control_id| {
                pressed_invalidation_reason(state, control_id)
            });
        let invalidation_id = context.push_invalidation(state, effect_target.clone(), reason);
        context.push_effect(
            state,
            effect_target,
            EffectKind::RequestRepaint {
                invalidation_ids: vec![invalidation_id],
                reason,
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
    queue_mouse_event(
        state,
        context,
        effect_target.clone(),
        "MouseUp",
        payload,
        &route,
    );

    if captured_target.is_some() && route.is_inside_pressed_target && route.supports_click_event {
        queue_vba_event(state, context, effect_target.clone(), "Click");
        if let Some(control_id) = route
            .control_id
            .as_ref()
            .filter(|control_id| is_check_box_control(state, control_id))
            .cloned()
        {
            toggle_check_box(state, context, control_id);
        }
    }

    if pressed_target.is_some() {
        let reason = route
            .control_id
            .as_ref()
            .map_or(InvalidationReason::PressedStateChanged, |control_id| {
                pressed_invalidation_reason(state, control_id)
            });
        let invalidation_id = context.push_invalidation(state, effect_target.clone(), reason);
        context.push_effect(
            state,
            effect_target,
            EffectKind::RequestRepaint {
                invalidation_ids: vec![invalidation_id],
                reason,
            },
            CompletionPolicy::RenderDiagnosticOptional,
        );
    }
}

fn reduce_key_down(state: &mut FormState, context: &mut ReducerContext<'_>, payload: &KeyEvent) {
    state.keyboard.last_key_down = Some(KeyEventSummary::from(payload));
    let keyboard_target = keyboard_event_target(state);
    queue_key_event(state, context, keyboard_target, "KeyDown", payload);

    match &payload.key {
        KeyCode::Tab => reduce_tab_key_down(state, context, payload.modifiers.shift),
        KeyCode::Backspace
        | KeyCode::Delete
        | KeyCode::ArrowLeft
        | KeyCode::ArrowRight
        | KeyCode::Home
        | KeyCode::End => reduce_text_box_editing_key_down(state, context, payload),
        KeyCode::Enter => {
            if let Some(control_id) = state.default_button.clone() {
                activate_command_button(
                    state,
                    context,
                    &control_id,
                    PressedOrigin::KeyboardDefault,
                );
            }
        }
        KeyCode::Escape => {
            if let Some(control_id) = state.cancel_button.clone() {
                activate_command_button(state, context, &control_id, PressedOrigin::KeyboardCancel);
            }
        }
        KeyCode::Character(character) if payload.modifiers.alt => {
            if let Some(control_id) = accelerator_command_button(state, character) {
                activate_command_button(state, context, &control_id, PressedOrigin::Accelerator);
            }
        }
        _ => {}
    }
}

fn reduce_text_box_editing_key_down(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    payload: &KeyEvent,
) {
    let Some(control_id) = focused_text_box_control_id(state) else {
        return;
    };
    let text_box = state.ensure_text_box(control_id.clone());
    let before_text = text_box.text.clone();
    let before_caret = text_box.caret.clone();

    match payload.key {
        KeyCode::Backspace => {
            delete_text_box_backwards(text_box);
        }
        KeyCode::Delete => {
            delete_text_box_forwards(text_box);
        }
        KeyCode::ArrowLeft => {
            move_text_box_caret_left(text_box, payload.modifiers.shift);
        }
        KeyCode::ArrowRight => {
            move_text_box_caret_right(text_box, payload.modifiers.shift);
        }
        KeyCode::Home => {
            move_text_box_caret_to(text_box, 0, payload.modifiers.shift);
        }
        KeyCode::End => {
            move_text_box_caret_to(text_box, text_box.text.len(), payload.modifiers.shift);
        }
        _ => return,
    }

    let text_changed = text_box.text != before_text;
    let caret_changed = text_box.caret != before_caret;
    if !text_changed && !caret_changed {
        return;
    }

    if text_changed {
        text_box.dirty = true;
        text_box.edit_sequence += 1;
    }

    let target = UiEventTarget::control(state.form_id.0.clone(), control_id.0.clone());
    if text_changed {
        queue_vba_event(state, context, target.clone(), "Change");
    }
    let reason = if text_changed {
        InvalidationReason::TextChanged
    } else {
        InvalidationReason::TextSelectionChanged
    };
    let invalidation_id = context.push_invalidation(state, target.clone(), reason);
    context.push_effect(
        state,
        target,
        EffectKind::RequestRepaint {
            invalidation_ids: vec![invalidation_id],
            reason,
        },
        CompletionPolicy::RenderDiagnosticOptional,
    );
}

fn reduce_key_up(state: &mut FormState, context: &mut ReducerContext<'_>, payload: &KeyEvent) {
    state.keyboard.last_key_up = Some(KeyEventSummary::from(payload));
    let keyboard_target = keyboard_event_target(state);
    queue_key_event(state, context, keyboard_target, "KeyUp", payload);

    let Some(pressed_state) = state.pressed_state.clone() else {
        return;
    };

    if !matches!(
        pressed_state.origin,
        PressedOrigin::KeyboardDefault | PressedOrigin::KeyboardCancel | PressedOrigin::Accelerator
    ) {
        return;
    }

    state.pressed_state = None;
    if let Some(target) = target_for_focus(&pressed_state.target, &state.form_id) {
        let invalidation_id = context.push_invalidation(
            state,
            target.clone(),
            InvalidationReason::PressedStateChanged,
        );
        context.push_effect(
            state,
            target,
            EffectKind::RequestRepaint {
                invalidation_ids: vec![invalidation_id],
                reason: InvalidationReason::PressedStateChanged,
            },
            CompletionPolicy::RenderDiagnosticOptional,
        );
    }
}

fn reduce_tab_key_down(state: &mut FormState, context: &mut ReducerContext<'_>, reverse: bool) {
    let Some(next_focus) = next_tab_focus_target(
        &state.controls,
        state
            .focus_owner
            .as_ref()
            .and_then(FocusTarget::as_control_id),
        reverse,
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

fn activate_command_button(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    control_id: &ControlId,
    origin: PressedOrigin,
) -> bool {
    let Some(control) = find_control(state, control_id) else {
        return false;
    };
    if control.kind != ControlKind::CommandButton || !control.visible || !control.enabled {
        return false;
    }

    let target = FocusTarget::Control(control_id.clone());
    let effect_target = UiEventTarget::control(state.form_id.0.clone(), control_id.0.clone());
    state.pressed_state = Some(PressedState {
        target,
        origin,
        armed: true,
    });
    queue_vba_event(state, context, effect_target.clone(), "Click");
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
    true
}

fn toggle_check_box(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    control_id: ControlId,
) -> bool {
    if !is_check_box_control(state, &control_id) {
        return false;
    }

    let check_box = state.ensure_check_box(control_id.clone());
    check_box.checked = !check_box.checked;
    check_box.dirty = true;
    check_box.edit_sequence += 1;

    let target = UiEventTarget::control(state.form_id.0.clone(), control_id.0.clone());
    queue_vba_event(state, context, target.clone(), "Change");
    let invalidation_id = context.push_invalidation(
        state,
        target.clone(),
        InvalidationReason::CheckBoxValueChanged,
    );
    context.push_effect(
        state,
        target,
        EffectKind::RequestRepaint {
            invalidation_ids: vec![invalidation_id],
            reason: InvalidationReason::CheckBoxValueChanged,
        },
        CompletionPolicy::RenderDiagnosticOptional,
    );
    true
}

fn is_check_box_control(state: &FormState, control_id: &ControlId) -> bool {
    find_control(state, control_id).is_some_and(|control| {
        control.kind == ControlKind::CheckBox && control.visible && control.enabled
    })
}

fn pressed_invalidation_reason(state: &FormState, control_id: &ControlId) -> InvalidationReason {
    if is_check_box_control(state, control_id) {
        InvalidationReason::CheckBoxPressedChanged
    } else {
        InvalidationReason::PressedStateChanged
    }
}

#[derive(Clone, Debug)]
struct RoutedMouseTarget {
    control_id: Option<ControlId>,
    focus_target: FocusTarget,
    effect_target: UiEventTarget,
    form_logical: Option<oxforms_pal::LogicalPoint>,
    control_local: Option<oxforms_pal::LogicalPoint>,
    can_receive_focus: bool,
    has_pressed_visual: bool,
    from_capture: bool,
    is_inside_pressed_target: bool,
    supports_click_event: bool,
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
        let control_local = coordinates
            .form_logical
            .and_then(|point| control.map(|control| control.form_to_control_local(point)));
        let supports_click_event = control.is_none_or(probe_control_supports_click_event);
        return Some(RoutedMouseTarget {
            control_id: capture.target.as_control_id().cloned(),
            focus_target: capture.target.clone(),
            effect_target: target,
            form_logical: coordinates.form_logical,
            control_local,
            can_receive_focus: false,
            has_pressed_visual: false,
            from_capture: true,
            is_inside_pressed_target,
            supports_click_event,
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
                form_logical: Some(hit.form_logical),
                control_local: Some(hit.control_local),
                can_receive_focus: control.can_receive_focus(),
                has_pressed_visual: matches!(
                    control.kind,
                    ControlKind::CommandButton | ControlKind::CheckBox
                ),
                from_capture: false,
                is_inside_pressed_target: true,
                supports_click_event: probe_control_supports_click_event(control),
            });
        }
        return Some(RoutedMouseTarget {
            control_id: None,
            focus_target: FocusTarget::Form(state.form_id.clone()),
            effect_target: UiEventTarget::form(state.form_id.0.clone()),
            form_logical: Some(point),
            control_local: None,
            can_receive_focus: false,
            has_pressed_visual: false,
            from_capture: false,
            is_inside_pressed_target: false,
            supports_click_event: true,
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
            form_logical: coordinates.form_logical,
            control_local: coordinates.control_local,
            can_receive_focus: true,
            has_pressed_visual: event.target.control_id.is_some(),
            from_capture: false,
            is_inside_pressed_target: true,
            supports_click_event: true,
        });
    }

    None
}

fn probe_control_supports_click_event(control: &ControlNode) -> bool {
    matches!(
        control.kind,
        ControlKind::CheckBox | ControlKind::Label | ControlKind::CommandButton
    )
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

fn keyboard_event_target(state: &FormState) -> UiEventTarget {
    state
        .focus_owner
        .as_ref()
        .and_then(|target| target_for_focus(target, &state.form_id))
        .unwrap_or_else(|| UiEventTarget::form(state.form_id.0.clone()))
}

fn accelerator_command_button(state: &FormState, character: &str) -> Option<ControlId> {
    let normalized = character.chars().next()?.to_uppercase().next()?;
    state
        .controls
        .iter()
        .filter(|control| {
            control.kind == ControlKind::CommandButton && control.visible && control.enabled
        })
        .find(|control| control.accelerator_key() == Some(normalized))
        .map(|control| control.control_id.clone())
}

fn focused_text_box_control_id(state: &FormState) -> Option<ControlId> {
    let control_id = state.focus_owner.as_ref()?.as_control_id()?;
    let control = find_control(state, control_id)?;
    if control.kind == ControlKind::TextBox && control.visible && control.enabled {
        Some(control_id.clone())
    } else {
        None
    }
}

fn event_or_focused_text_box_control_id(state: &FormState, event: &UiEvent) -> Option<ControlId> {
    if let Some(control_id) = &event.target.control_id {
        if is_text_box_control(state, control_id) {
            return Some(control_id.clone());
        }
    }

    focused_text_box_control_id(state)
}

fn is_text_box_control(state: &FormState, control_id: &ControlId) -> bool {
    find_control(state, control_id).is_some_and(|control| {
        control.kind == ControlKind::TextBox && control.visible && control.enabled
    })
}

fn reduce_character_input(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    payload: &CharacterInputEvent,
) {
    state.keyboard.last_character_input = Some(CharacterInputSummary {
        text_len: payload.text.len(),
        modifiers: payload.modifiers,
    });
    if payload.text.is_empty() || payload.text.chars().any(char::is_control) {
        return;
    }

    let Some(control_id) = focused_text_box_control_id(state) else {
        return;
    };

    insert_text_box_text(state, &control_id, &payload.text);

    let target = UiEventTarget::control(state.form_id.0.clone(), control_id.0.clone());
    queue_character_event(state, context, target.clone(), payload);
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

fn reduce_drag_over(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    payload: &DragOverEvent,
) {
    let Some(control_id) = event_or_focused_text_box_control_id(state, context.event) else {
        queue_data_transfer_diagnostic(state, context, &payload.data, "no_textbox_target");
        return;
    };
    let target = UiEventTarget::control(state.form_id.0.clone(), control_id.0.clone());
    queue_before_drag_over_event(state, context, target, payload);
}

fn reduce_drop_or_paste(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    payload: &DropOrPasteEvent,
) {
    if payload.origin != DropOrPasteOrigin::DragDrop {
        queue_data_transfer_diagnostic(
            state,
            context,
            &payload.data,
            "unsupported_drop_or_paste_origin",
        );
        return;
    }

    if !data_formats_include_plain_text(&payload.data.formats) {
        queue_data_transfer_diagnostic(state, context, &payload.data, "unsupported_data_format");
        return;
    }

    let Some(text) = payload
        .data
        .payload
        .as_ref()
        .and_then(|payload| payload.text.as_deref())
    else {
        queue_data_transfer_diagnostic(state, context, &payload.data, "missing_text_payload");
        return;
    };

    if text.is_empty() || text.chars().any(char::is_control) {
        queue_data_transfer_diagnostic(state, context, &payload.data, "unsupported_text_payload");
        return;
    }

    let Some(control_id) = event_or_focused_text_box_control_id(state, context.event) else {
        queue_data_transfer_diagnostic(state, context, &payload.data, "no_textbox_target");
        return;
    };

    insert_text_box_text(state, &control_id, text);

    let target = UiEventTarget::control(state.form_id.0.clone(), control_id.0.clone());
    queue_before_drop_or_paste_drag_event(state, context, target.clone(), payload);
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

fn reduce_clipboard_result(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    payload: &ClipboardResultEvent,
) {
    if payload.operation != ClipboardOperation::Get {
        queue_clipboard_diagnostic(state, context, payload, "unsupported_clipboard_operation");
        return;
    }

    if !matches!(&payload.outcome, ServiceOutcome::Success) {
        queue_clipboard_diagnostic(state, context, payload, "clipboard_get_failed");
        return;
    }

    if !data_formats_include_plain_text(&payload.formats) {
        queue_clipboard_diagnostic(state, context, payload, "unsupported_clipboard_format");
        return;
    }

    let Some(text) = payload
        .payload
        .as_ref()
        .and_then(|payload| payload.text.as_deref())
    else {
        queue_clipboard_diagnostic(state, context, payload, "missing_text_payload");
        return;
    };

    if text.is_empty() || text.chars().any(char::is_control) {
        queue_clipboard_diagnostic(state, context, payload, "unsupported_text_payload");
        return;
    }

    let Some(control_id) = focused_text_box_control_id(state) else {
        queue_clipboard_diagnostic(state, context, payload, "no_focused_textbox");
        return;
    };

    insert_text_box_text(state, &control_id, text);

    let target = UiEventTarget::control(state.form_id.0.clone(), control_id.0.clone());
    queue_before_drop_or_paste_event(state, context, target.clone(), payload);
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

fn insert_text_box_text(state: &mut FormState, control_id: &ControlId, text: &str) {
    let text_box = state.ensure_text_box(control_id.clone());
    delete_selected_text(text_box);
    let insert_at = clamp_to_char_boundary(&text_box.text, text_box.caret.active);
    text_box.text.insert_str(insert_at, text);
    let next_caret = insert_at + text.len();
    text_box.caret.anchor = next_caret;
    text_box.caret.active = next_caret;
    text_box.dirty = true;
    text_box.edit_sequence += 1;
}

fn data_formats_include_plain_text(formats: &[String]) -> bool {
    formats.iter().any(|format| {
        matches!(
            format.to_ascii_lowercase().as_str(),
            "text" | "text/plain" | "unicode_text" | "cf_unicode_text" | "cf_text"
        )
    })
}

fn queue_clipboard_diagnostic(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    payload: &ClipboardResultEvent,
    reason: &str,
) {
    let target = context.event.target.clone();
    context.push_effect(
        state,
        target,
        EffectKind::HostCapabilityRequest {
            host_namespace: "oxforms-core".to_string(),
            capability: "clipboard_text_paste_diagnostic".to_string(),
            host_scope_id: None,
            payload_summary: Some(format!(
                "request_id={}; reason={reason}; operation={:?}; formats={}",
                payload.request_id.0,
                payload.operation,
                payload.formats.join(",")
            )),
        },
        CompletionPolicy::ImmediateDiagnostic,
    );
}

fn queue_data_transfer_diagnostic(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    snapshot: &DataObjectSnapshot,
    reason: &str,
) {
    let target = context.event.target.clone();
    context.push_effect(
        state,
        target,
        EffectKind::HostCapabilityRequest {
            host_namespace: "oxforms-core".to_string(),
            capability: "drag_drop_data_transfer_diagnostic".to_string(),
            host_scope_id: None,
            payload_summary: Some(format!(
                "snapshot_id={}; reason={reason}; formats={}",
                snapshot.snapshot_id.0,
                snapshot.formats.join(",")
            )),
        },
        CompletionPolicy::ImmediateDiagnostic,
    );
}

fn delete_text_box_backwards(text_box: &mut TextBoxProbeState) {
    if delete_selected_text(text_box) {
        return;
    }
    let active = clamp_to_char_boundary(&text_box.text, text_box.caret.active);
    if active == 0 {
        collapse_text_box_caret(text_box, 0);
        return;
    }
    let previous = previous_char_boundary(&text_box.text, active);
    text_box.text.replace_range(previous..active, "");
    collapse_text_box_caret(text_box, previous);
}

fn delete_text_box_forwards(text_box: &mut TextBoxProbeState) {
    if delete_selected_text(text_box) {
        return;
    }
    let active = clamp_to_char_boundary(&text_box.text, text_box.caret.active);
    if active >= text_box.text.len() {
        collapse_text_box_caret(text_box, text_box.text.len());
        return;
    }
    let next = next_char_boundary(&text_box.text, active);
    text_box.text.replace_range(active..next, "");
    collapse_text_box_caret(text_box, active);
}

fn delete_selected_text(text_box: &mut TextBoxProbeState) -> bool {
    let (start, end) = selected_range(&text_box.text, &text_box.caret);
    if start == end {
        collapse_text_box_caret(text_box, start);
        return false;
    }
    text_box.text.replace_range(start..end, "");
    collapse_text_box_caret(text_box, start);
    true
}

fn move_text_box_caret_left(text_box: &mut TextBoxProbeState, extend_selection: bool) {
    if !extend_selection && text_box.caret.anchor != text_box.caret.active {
        let (start, _) = selected_range(&text_box.text, &text_box.caret);
        collapse_text_box_caret(text_box, start);
        return;
    }
    let active = clamp_to_char_boundary(&text_box.text, text_box.caret.active);
    let next = previous_char_boundary(&text_box.text, active);
    move_text_box_caret_to(text_box, next, extend_selection);
}

fn move_text_box_caret_right(text_box: &mut TextBoxProbeState, extend_selection: bool) {
    if !extend_selection && text_box.caret.anchor != text_box.caret.active {
        let (_, end) = selected_range(&text_box.text, &text_box.caret);
        collapse_text_box_caret(text_box, end);
        return;
    }
    let active = clamp_to_char_boundary(&text_box.text, text_box.caret.active);
    let next = next_char_boundary(&text_box.text, active);
    move_text_box_caret_to(text_box, next, extend_selection);
}

fn move_text_box_caret_to(
    text_box: &mut TextBoxProbeState,
    position: usize,
    extend_selection: bool,
) {
    let next = clamp_to_char_boundary(&text_box.text, position);
    if extend_selection {
        text_box.caret.anchor = clamp_to_char_boundary(&text_box.text, text_box.caret.anchor);
        text_box.caret.active = next;
    } else {
        collapse_text_box_caret(text_box, next);
    }
    text_box.caret.preferred_column = None;
}

fn collapse_text_box_caret(text_box: &mut TextBoxProbeState, position: usize) {
    let position = clamp_to_char_boundary(&text_box.text, position);
    text_box.caret.anchor = position;
    text_box.caret.active = position;
    text_box.caret.preferred_column = None;
}

fn selected_range(text: &str, caret: &TextCaretState) -> (usize, usize) {
    let anchor = clamp_to_char_boundary(text, caret.anchor);
    let active = clamp_to_char_boundary(text, caret.active);
    if anchor <= active {
        (anchor, active)
    } else {
        (active, anchor)
    }
}

fn previous_char_boundary(text: &str, position: usize) -> usize {
    let position = clamp_to_char_boundary(text, position);
    if position == 0 {
        return 0;
    }
    text[..position]
        .char_indices()
        .last()
        .map_or(0, |(index, _)| index)
}

fn next_char_boundary(text: &str, position: usize) -> usize {
    let position = clamp_to_char_boundary(text, position);
    if position >= text.len() {
        return text.len();
    }
    text[position..]
        .char_indices()
        .nth(1)
        .map_or(text.len(), |(offset, _)| position + offset)
}

fn clamp_to_char_boundary(text: &str, position: usize) -> usize {
    let mut position = position.min(text.len());
    while position > 0 && !text.is_char_boundary(position) {
        position -= 1;
    }
    position
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
    state.pump.term = PumpTerm::CloseUnloadCancellation;
    let query_policy = payload.query_policy;
    let close_mode = close_mode_for_origin(payload.origin);
    state.close_flow = Some(CloseFlowState {
        origin: payload.origin,
        reason: payload.reason,
        close_mode,
        cancelled: None,
        awaiting_window_hide_for_unload: false,
    });

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
                            value: close_mode
                                .map(|value| value.to_string())
                                .unwrap_or_else(|| "unknown".to_string()),
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
    if payload.form_id != state.form_id
        || state.lifecycle != LifecycleState::QueryClosePending
        || state.close_flow.is_none()
    {
        return;
    }

    let target = UiEventTarget::form(payload.form_id.0.clone());
    if let Some(flow) = &mut state.close_flow {
        flow.cancelled = Some(payload.cancelled);
        flow.reason = payload.reason;
        if payload.close_mode.is_some() {
            flow.close_mode = payload.close_mode;
        }
    }
    if payload.cancelled {
        state.lifecycle = LifecycleState::CloseCancelled;
        state.pump.term = PumpTerm::HostModelessPump;
        state.close_flow = None;
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

    state.lifecycle = LifecycleState::HidePending;
    if let Some(flow) = &mut state.close_flow {
        flow.awaiting_window_hide_for_unload = true;
    }
    context.push_effect(
        state,
        target,
        EffectKind::HideForm {
            reason: LifecycleReason::User,
        },
        CompletionPolicy::PlatformCompletionOrDiagnostic,
    );
}

fn close_mode_for_origin(origin: CloseRequestOrigin) -> Option<i32> {
    match origin {
        CloseRequestOrigin::CloseButton | CloseRequestOrigin::SystemMenu => Some(0),
        CloseRequestOrigin::CodeUnload => Some(1),
        CloseRequestOrigin::OwnerShutdown => Some(2),
        CloseRequestOrigin::HostRequest
        | CloseRequestOrigin::Replay
        | CloseRequestOrigin::Unknown => None,
    }
}

fn queue_key_event(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    target: UiEventTarget,
    event_name: &str,
    payload: &KeyEvent,
) {
    context.push_effect(
        state,
        target,
        EffectKind::FireVbaEvent {
            event_name: event_name.to_string(),
            fact_source: Some("docs/specs/FM20_EVENT_FACTS.md".to_string()),
            arguments: key_event_arguments(payload),
            cancel_metadata: Some(
                "KeyCode is modeled as an MSForms.ReturnInteger helper placeholder; helper mutation is deferred in W005."
                    .to_string(),
            ),
        },
        CompletionPolicy::DispatchResultRequired,
    );
}

fn queue_character_event(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    target: UiEventTarget,
    payload: &CharacterInputEvent,
) {
    context.push_effect(
        state,
        target,
        EffectKind::FireVbaEvent {
            event_name: "KeyPress".to_string(),
            fact_source: Some("docs/specs/FM20_EVENT_FACTS.md".to_string()),
            arguments: vec![
                EffectArgument {
                    name: "text".to_string(),
                    value: payload.text.clone(),
                    by_ref: false,
                },
                EffectArgument {
                    name: "key_ascii_placeholder".to_string(),
                    value: payload.text.chars().next().map_or(0, u32::from).to_string(),
                    by_ref: true,
                },
                EffectArgument {
                    name: "modifiers".to_string(),
                    value: modifier_summary(payload.modifiers),
                    by_ref: false,
                },
            ],
            cancel_metadata: Some(
                "KeyAscii/KeyANSI ReturnInteger mutation and IME composition are deferred in W005."
                    .to_string(),
            ),
        },
        CompletionPolicy::DispatchResultRequired,
    );
}

fn queue_before_drop_or_paste_event(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    target: UiEventTarget,
    payload: &ClipboardResultEvent,
) {
    context.push_effect(
        state,
        target,
        EffectKind::FireVbaEvent {
            event_name: "BeforeDropOrPaste".to_string(),
            fact_source: Some("docs/specs/FM20_EVENT_FACTS.md".to_string()),
            arguments: vec![
                EffectArgument {
                    name: "Cancel".to_string(),
                    value: "False".to_string(),
                    by_ref: true,
                },
                EffectArgument {
                    name: "Action".to_string(),
                    value: "2".to_string(),
                    by_ref: false,
                },
                EffectArgument {
                    name: "Data".to_string(),
                    value: format!(
                        "clipboard_text_payload:{}; formats={}",
                        payload.request_id.0,
                        payload.formats.join(",")
                    ),
                    by_ref: false,
                },
                EffectArgument {
                    name: "X".to_string(),
                    value: "0".to_string(),
                    by_ref: false,
                },
                EffectArgument {
                    name: "Y".to_string(),
                    value: "0".to_string(),
                    by_ref: false,
                },
                EffectArgument {
                    name: "Effect".to_string(),
                    value: "0".to_string(),
                    by_ref: true,
                },
                EffectArgument {
                    name: "Shift".to_string(),
                    value: "0".to_string(),
                    by_ref: false,
                },
            ],
            cancel_metadata: Some(
                "Text-only clipboard paste subset: Data is a serializable payload summary; live MSForms.DataObject, Ctrl+V ordering, rich formats, and Action mutation remain non-claims."
                    .to_string(),
            ),
        },
        CompletionPolicy::DispatchResultRequired,
    );
}

fn queue_before_drag_over_event(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    target: UiEventTarget,
    payload: &DragOverEvent,
) {
    let point = msforms_event_point(&payload.coordinates);
    context.push_effect(
        state,
        target,
        EffectKind::FireVbaEvent {
            event_name: "BeforeDragOver".to_string(),
            fact_source: Some("docs/specs/FM20_EVENT_FACTS.md".to_string()),
            arguments: vec![
                EffectArgument {
                    name: "Cancel".to_string(),
                    value: "False".to_string(),
                    by_ref: true,
                },
                EffectArgument {
                    name: "Data".to_string(),
                    value: data_object_snapshot_summary(&payload.data, "drag_session"),
                    by_ref: false,
                },
                EffectArgument {
                    name: "X".to_string(),
                    value: point.x.to_string(),
                    by_ref: false,
                },
                EffectArgument {
                    name: "Y".to_string(),
                    value: point.y.to_string(),
                    by_ref: false,
                },
                EffectArgument {
                    name: "DragState".to_string(),
                    value: payload.drag_state.to_string(),
                    by_ref: false,
                },
                EffectArgument {
                    name: "Effect".to_string(),
                    value: payload.effect.to_string(),
                    by_ref: true,
                },
                EffectArgument {
                    name: "Shift".to_string(),
                    value: fm20_shift_state(payload.modifiers).to_string(),
                    by_ref: false,
                },
            ],
            cancel_metadata: Some(format!(
                "W006 drag/drop subset: cites FM20_EVENT_FACTS.md BeforeDragOver; Data is serializable snapshot {}; helper result boundary Cancel False->False, Effect {}->{} when dispatch is not executed by core; live MSForms.DataObject/platform drag objects remain adapter-owned.",
                payload.data.snapshot_id.0, payload.effect, payload.effect
            )),
        },
        CompletionPolicy::DispatchResultRequired,
    );
}

fn queue_before_drop_or_paste_drag_event(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    target: UiEventTarget,
    payload: &DropOrPasteEvent,
) {
    let point = msforms_event_point(&payload.coordinates);
    context.push_effect(
        state,
        target,
        EffectKind::FireVbaEvent {
            event_name: "BeforeDropOrPaste".to_string(),
            fact_source: Some("docs/specs/FM20_EVENT_FACTS.md".to_string()),
            arguments: vec![
                EffectArgument {
                    name: "Cancel".to_string(),
                    value: "False".to_string(),
                    by_ref: true,
                },
                EffectArgument {
                    name: "Action".to_string(),
                    value: payload.action.to_string(),
                    by_ref: false,
                },
                EffectArgument {
                    name: "Data".to_string(),
                    value: data_object_snapshot_summary(&payload.data, "drop_or_paste"),
                    by_ref: false,
                },
                EffectArgument {
                    name: "X".to_string(),
                    value: point.x.to_string(),
                    by_ref: false,
                },
                EffectArgument {
                    name: "Y".to_string(),
                    value: point.y.to_string(),
                    by_ref: false,
                },
                EffectArgument {
                    name: "Effect".to_string(),
                    value: payload.effect.to_string(),
                    by_ref: true,
                },
                EffectArgument {
                    name: "Shift".to_string(),
                    value: fm20_shift_state(payload.modifiers).to_string(),
                    by_ref: false,
                },
            ],
            cancel_metadata: Some(format!(
                "W006 drag/drop subset: cites FM20_EVENT_FACTS.md BeforeDropOrPaste; Data is serializable snapshot {}; helper result boundary Cancel False->False, Effect {}->{} when dispatch is not executed by core; Action mutation remains a non-claim.",
                payload.data.snapshot_id.0, payload.effect, payload.effect
            )),
        },
        CompletionPolicy::DispatchResultRequired,
    );
}

fn msforms_event_point(coordinates: &oxforms_pal::CoordinatePayload) -> LogicalPoint {
    coordinates
        .control_local
        .or(coordinates.form_logical)
        .unwrap_or(LogicalPoint::new(0.0, 0.0))
}

fn data_object_snapshot_summary(snapshot: &DataObjectSnapshot, role: &str) -> String {
    let metadata = snapshot
        .metadata
        .iter()
        .map(|entry| format!("{}:{}", entry.source, entry.name))
        .collect::<Vec<_>>()
        .join(",");
    format!(
        "{role}_data_snapshot:{}; formats={}; payload_text_present={}; metadata={}",
        snapshot.snapshot_id.0,
        snapshot.formats.join(","),
        snapshot
            .payload
            .as_ref()
            .and_then(|payload| payload.text.as_ref())
            .is_some(),
        metadata
    )
}

fn fm20_shift_state(modifiers: KeyboardModifiers) -> i32 {
    let mut shift = 0;
    if modifiers.shift {
        shift |= 1;
    }
    if modifiers.control {
        shift |= 2;
    }
    if modifiers.alt {
        shift |= 4;
    }
    shift
}

fn queue_mouse_event(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    target: UiEventTarget,
    event_name: &str,
    payload: &MouseButtonEvent,
    route: &RoutedMouseTarget,
) {
    context.push_effect(
        state,
        target,
        EffectKind::FireVbaEvent {
            event_name: event_name.to_string(),
            fact_source: Some("docs/specs/FM20_EVENT_FACTS.md".to_string()),
            arguments: mouse_event_arguments(
                payload.button,
                payload.modifiers,
                route.control_local.or(route.form_logical),
            ),
            cancel_metadata: None,
        },
        CompletionPolicy::DispatchResultRequired,
    );
}

fn queue_mouse_move_event(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    target: UiEventTarget,
    payload: &MouseMoveEvent,
    route: &RoutedMouseTarget,
) {
    context.push_effect(
        state,
        target,
        EffectKind::FireVbaEvent {
            event_name: "MouseMove".to_string(),
            fact_source: Some("docs/specs/FM20_EVENT_FACTS.md".to_string()),
            arguments: mouse_event_arguments(
                primary_mouse_button(&payload.buttons_down),
                payload.modifiers,
                route.control_local.or(route.form_logical),
            ),
            cancel_metadata: None,
        },
        CompletionPolicy::DispatchResultRequired,
    );
}

fn mouse_event_arguments(
    button: MouseButton,
    modifiers: KeyboardModifiers,
    point: Option<oxforms_pal::LogicalPoint>,
) -> Vec<EffectArgument> {
    let point = point.unwrap_or_else(|| oxforms_pal::LogicalPoint::new(0.0, 0.0));
    vec![
        EffectArgument {
            name: "Button".to_string(),
            value: fm_button_mask(button).to_string(),
            by_ref: false,
        },
        EffectArgument {
            name: "Shift".to_string(),
            value: fm_shift_mask(modifiers).to_string(),
            by_ref: false,
        },
        EffectArgument {
            name: "X".to_string(),
            value: point.x.to_string(),
            by_ref: false,
        },
        EffectArgument {
            name: "Y".to_string(),
            value: point.y.to_string(),
            by_ref: false,
        },
    ]
}

fn primary_mouse_button(buttons: &oxforms_pal::MouseButtons) -> MouseButton {
    if buttons.left {
        MouseButton::Left
    } else if buttons.right {
        MouseButton::Right
    } else if buttons.middle {
        MouseButton::Middle
    } else if buttons.x1 {
        MouseButton::X1
    } else if buttons.x2 {
        MouseButton::X2
    } else {
        MouseButton::Other(buttons.other.first().copied().unwrap_or_default())
    }
}

fn fm_button_mask(button: MouseButton) -> i16 {
    match button {
        MouseButton::Left => 1,
        MouseButton::Right => 2,
        MouseButton::Middle => 4,
        MouseButton::X1 => 8,
        MouseButton::X2 => 16,
        MouseButton::Other(value) => i16::try_from(value).unwrap_or(i16::MAX),
    }
}

fn fm_shift_mask(modifiers: KeyboardModifiers) -> i16 {
    i16::from(modifiers.shift)
        | (i16::from(modifiers.control) << 1)
        | (i16::from(modifiers.alt) << 2)
}

fn key_event_arguments(payload: &KeyEvent) -> Vec<EffectArgument> {
    let mut arguments = vec![
        EffectArgument {
            name: "key".to_string(),
            value: key_code_summary(&payload.key),
            by_ref: true,
        },
        EffectArgument {
            name: "modifiers".to_string(),
            value: modifier_summary(payload.modifiers),
            by_ref: false,
        },
        EffectArgument {
            name: "repeat".to_string(),
            value: payload.repeat.repeat_count.map_or_else(
                || payload.repeat.is_repeat.to_string(),
                |count| count.to_string(),
            ),
            by_ref: false,
        },
    ];

    if let Some(virtual_key) = payload.raw.virtual_key {
        arguments.push(EffectArgument {
            name: "raw_virtual_key".to_string(),
            value: virtual_key.to_string(),
            by_ref: false,
        });
    }
    if let Some(scan_code) = payload.raw.scan_code {
        arguments.push(EffectArgument {
            name: "raw_scan_code".to_string(),
            value: scan_code.to_string(),
            by_ref: false,
        });
    }
    if let Some(native_code) = payload.raw.native_code {
        arguments.push(EffectArgument {
            name: "raw_native_code".to_string(),
            value: native_code.to_string(),
            by_ref: false,
        });
    }

    arguments
}

fn key_code_summary(key: &KeyCode) -> String {
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
        KeyCode::Character(character) => format!("character:{character}"),
        KeyCode::Other(key) => format!("other:{key}"),
        KeyCode::Unidentified => "unidentified".to_string(),
    }
}

fn modifier_summary(modifiers: KeyboardModifiers) -> String {
    let mut active = Vec::new();
    if modifiers.shift {
        active.push("shift");
    }
    if modifiers.control {
        active.push("control");
    }
    if modifiers.alt {
        active.push("alt");
    }
    if modifiers.meta {
        active.push("meta");
    }
    if modifiers.platform {
        active.push("platform");
    }
    if active.is_empty() {
        "none".to_string()
    } else {
        active.join("+")
    }
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
        ActivationEvent, ActivationReason, CharacterInputEvent, ClickCount, ClipboardOperation,
        ClipboardResultEvent, CloseRequestEvent, CloseRequestOrigin, CoordinatePayload,
        DataObjectSnapshot, DragOverEvent, DropOrPasteEvent, DropOrPasteOrigin, KeyCode, KeyRepeat,
        KeyboardModifiers, LogicalPoint, MouseButton, MouseButtonEvent, MouseButtons,
        RawCoordinateSample, RawDiagnostic, RawKeyDiagnostics, ServiceOutcome, ServicePayload,
        ServiceRequestId, ShowRequestedEvent, UiEventSource, UnloadedEvent, WindowHiddenEvent,
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
        assert_eq!(hit.kind, ControlKind::CommandButton);
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
            vec![
                "fire_vba_event:KeyDown",
                "transfer_focus",
                "request_repaint"
            ]
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
        state.controls = vec![ControlNode::text_box(
            "text-1",
            LogicalRect::new(0.0, 0.0, 80.0, 18.0),
            0,
            0,
        )];
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
            vec![
                "fire_vba_event:KeyPress",
                "fire_vba_event:Change",
                "request_repaint"
            ]
        );
        assert_eq!(output.transition.invalidation_ids, vec![InvalidationId(1)]);
    }

    #[test]
    fn textbox_navigation_keys_move_caret_without_change_effect() {
        let mut state = FormState::new("form-main");
        state.controls = vec![ControlNode::text_box(
            "text-1",
            LogicalRect::new(0.0, 0.0, 80.0, 18.0),
            0,
            0,
        )];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
        let text_box = state.ensure_text_box(ControlId::new("text-1"));
        text_box.text = "ABC".to_string();
        text_box.caret.anchor = 3;
        text_box.caret.active = 3;

        let left = reduce(
            state,
            key_down_event(UiEventId(71), KeyCode::ArrowLeft, false),
        );
        let text_box = left
            .state
            .text_boxes
            .iter()
            .find(|entry| entry.control_id == ControlId::new("text-1"))
            .expect("text box state should exist");
        assert_eq!(text_box.text, "ABC");
        assert_eq!(text_box.caret.anchor, 2);
        assert_eq!(text_box.caret.active, 2);
        assert_eq!(
            effect_names(&left.effects),
            vec!["fire_vba_event:KeyDown", "request_repaint"]
        );
        assert_eq!(
            left.invalidations[0].reason,
            InvalidationReason::TextSelectionChanged
        );

        let home = reduce(
            left.state,
            key_down_event(UiEventId(72), KeyCode::Home, false),
        );
        let text_box = home
            .state
            .text_boxes
            .iter()
            .find(|entry| entry.control_id == ControlId::new("text-1"))
            .expect("text box state should exist");
        assert_eq!(text_box.caret.anchor, 0);
        assert_eq!(text_box.caret.active, 0);

        let end = reduce(
            home.state,
            key_down_event(UiEventId(73), KeyCode::End, false),
        );
        let text_box = end
            .state
            .text_boxes
            .iter()
            .find(|entry| entry.control_id == ControlId::new("text-1"))
            .expect("text box state should exist");
        assert_eq!(text_box.caret.anchor, 3);
        assert_eq!(text_box.caret.active, 3);
    }

    #[test]
    fn textbox_shift_navigation_represents_selection_and_character_input_replaces_it() {
        let mut state = FormState::new("form-main");
        state.controls = vec![ControlNode::text_box(
            "text-1",
            LogicalRect::new(0.0, 0.0, 80.0, 18.0),
            0,
            0,
        )];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
        let text_box = state.ensure_text_box(ControlId::new("text-1"));
        text_box.text = "ABC".to_string();
        text_box.caret.anchor = 3;
        text_box.caret.active = 3;

        let selected = reduce(
            state,
            key_down_event(UiEventId(74), KeyCode::ArrowLeft, true),
        );
        let text_box = selected
            .state
            .text_boxes
            .iter()
            .find(|entry| entry.control_id == ControlId::new("text-1"))
            .expect("text box state should exist");
        assert_eq!(text_box.caret.anchor, 3);
        assert_eq!(text_box.caret.active, 2);

        let typed = reduce(
            selected.state,
            UiEvent::new(
                UiEventId(75),
                UiEventSource::Replay,
                UiEventKind::CharacterInput(CharacterInputEvent {
                    text: "Z".to_string(),
                    modifiers: KeyboardModifiers::default(),
                    raw: Vec::new(),
                }),
            ),
        );
        let text_box = typed
            .state
            .text_boxes
            .iter()
            .find(|entry| entry.control_id == ControlId::new("text-1"))
            .expect("text box state should exist");
        assert_eq!(text_box.text, "ABZ");
        assert_eq!(text_box.caret.anchor, 3);
        assert_eq!(text_box.caret.active, 3);
        assert_eq!(
            effect_names(&typed.effects),
            vec![
                "fire_vba_event:KeyPress",
                "fire_vba_event:Change",
                "request_repaint"
            ]
        );
    }

    #[test]
    fn clipboard_text_result_pastes_into_focused_textbox_and_emits_change_repaint() {
        let mut state = FormState::new("form-main");
        state.controls = vec![ControlNode::text_box(
            "text-1",
            LogicalRect::new(0.0, 0.0, 80.0, 18.0),
            0,
            0,
        )];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
        state.ensure_text_box(ControlId::new("text-1"));

        let output = reduce(
            state,
            clipboard_get_text_event(UiEventId(91), "clip-1", "PASTE", &["text/plain"]),
        );

        let text_box = output
            .state
            .text_boxes
            .iter()
            .find(|entry| entry.control_id == ControlId::new("text-1"))
            .expect("text box state should exist");
        assert_eq!(text_box.text, "PASTE");
        assert_eq!(text_box.caret.anchor, 5);
        assert_eq!(text_box.caret.active, 5);
        assert!(text_box.dirty);
        assert_eq!(text_box.edit_sequence, 1);
        assert_eq!(
            effect_names(&output.effects),
            vec![
                "fire_vba_event:BeforeDropOrPaste",
                "fire_vba_event:Change",
                "request_repaint"
            ]
        );
        assert_eq!(
            output.invalidations[0].reason,
            InvalidationReason::TextChanged
        );
    }

    #[test]
    fn clipboard_text_result_replaces_textbox_selection() {
        let mut state = FormState::new("form-main");
        state.controls = vec![ControlNode::text_box(
            "text-1",
            LogicalRect::new(0.0, 0.0, 80.0, 18.0),
            0,
            0,
        )];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
        let text_box = state.ensure_text_box(ControlId::new("text-1"));
        text_box.text = "ABCDE".to_string();
        text_box.caret.anchor = 1;
        text_box.caret.active = 4;

        let output = reduce(
            state,
            clipboard_get_text_event(UiEventId(92), "clip-2", "xy", &["cf_unicode_text"]),
        );

        let text_box = output
            .state
            .text_boxes
            .iter()
            .find(|entry| entry.control_id == ControlId::new("text-1"))
            .expect("text box state should exist");
        assert_eq!(text_box.text, "AxyE");
        assert_eq!(text_box.caret.anchor, 3);
        assert_eq!(text_box.caret.active, 3);
        assert_eq!(
            effect_names(&output.effects),
            vec![
                "fire_vba_event:BeforeDropOrPaste",
                "fire_vba_event:Change",
                "request_repaint"
            ]
        );
    }

    #[test]
    fn clipboard_result_with_unsupported_format_records_diagnostic_without_mutation() {
        let mut state = FormState::new("form-main");
        state.controls = vec![ControlNode::text_box(
            "text-1",
            LogicalRect::new(0.0, 0.0, 80.0, 18.0),
            0,
            0,
        )];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
        let text_box = state.ensure_text_box(ControlId::new("text-1"));
        text_box.text = "ABC".to_string();
        text_box.caret.anchor = 3;
        text_box.caret.active = 3;

        let output = reduce(
            state,
            UiEvent {
                target: UiEventTarget::control("form-main", "text-1"),
                ..UiEvent::new(
                    UiEventId(93),
                    UiEventSource::Service,
                    UiEventKind::ClipboardResult(ClipboardResultEvent {
                        request_id: ServiceRequestId::new("clip-image"),
                        operation: ClipboardOperation::Get,
                        outcome: ServiceOutcome::Success,
                        formats: vec!["image/png".to_string()],
                        payload: None,
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
        assert_eq!(text_box.text, "ABC");
        assert_eq!(text_box.edit_sequence, 0);
        assert!(output.invalidations.is_empty());
        assert_eq!(
            effect_names(&output.effects),
            vec!["host_capability_request"]
        );
        let EffectKind::HostCapabilityRequest {
            capability,
            payload_summary,
            ..
        } = &output.effects[0].kind
        else {
            panic!("expected clipboard diagnostic effect");
        };
        assert_eq!(capability, "clipboard_text_paste_diagnostic");
        assert!(payload_summary
            .as_ref()
            .is_some_and(|summary| summary.contains("unsupported_clipboard_format")));
    }

    #[test]
    fn drag_over_dispatches_before_drag_over_with_snapshot_metadata() {
        let mut state = FormState::new("form-main");
        state.controls = vec![ControlNode::text_box(
            "text-1",
            LogicalRect::new(0.0, 0.0, 120.0, 24.0),
            0,
            0,
        )];

        let output = reduce(
            state,
            UiEvent {
                target: UiEventTarget::control("form-main", "text-1"),
                ..UiEvent::new(
                    UiEventId(94),
                    UiEventSource::Pal,
                    UiEventKind::DragOver(drag_over_event("drag-1", 2, 1, &["cf_text"])),
                )
            },
        );

        assert_eq!(
            effect_names(&output.effects),
            vec!["fire_vba_event:BeforeDragOver"]
        );
        let EffectKind::FireVbaEvent {
            event_name,
            fact_source,
            arguments,
            cancel_metadata,
        } = &output.effects[0].kind
        else {
            panic!("expected BeforeDragOver dispatch effect");
        };
        assert_eq!(event_name, "BeforeDragOver");
        assert_eq!(
            fact_source.as_deref(),
            Some("docs/specs/FM20_EVENT_FACTS.md")
        );
        assert_eq!(
            arguments
                .iter()
                .map(|argument| argument.name.as_str())
                .collect::<Vec<_>>(),
            vec!["Cancel", "Data", "X", "Y", "DragState", "Effect", "Shift"]
        );
        assert_eq!(arguments[2].value, "63");
        assert_eq!(arguments[3].value, "15");
        assert_eq!(arguments[4].value, "2");
        assert_eq!(arguments[5].value, "1");
        assert!(cancel_metadata.as_ref().is_some_and(|metadata| metadata
            .contains("Cancel False->False")
            && metadata.contains("Effect 1->1")
            && metadata
                .contains("live MSForms.DataObject/platform drag objects remain adapter-owned")));
    }

    #[test]
    fn drop_or_paste_drag_text_inserts_and_dispatches_before_change() {
        let mut state = FormState::new("form-main");
        state.controls = vec![ControlNode::text_box(
            "text-1",
            LogicalRect::new(0.0, 0.0, 120.0, 24.0),
            0,
            0,
        )];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
        state.ensure_text_box(ControlId::new("text-1"));

        let output = reduce(
            state,
            UiEvent {
                target: UiEventTarget::control("form-main", "text-1"),
                ..UiEvent::new(
                    UiEventId(95),
                    UiEventSource::Pal,
                    UiEventKind::DropOrPaste(drop_or_paste_drag_event(
                        "drag-1",
                        "repo_owned_drag_text_seed_v1",
                        3,
                        1,
                        &["cf_text"],
                    )),
                )
            },
        );

        let text_box = output
            .state
            .text_boxes
            .iter()
            .find(|entry| entry.control_id == ControlId::new("text-1"))
            .expect("text box state should exist");
        assert_eq!(text_box.text, "repo_owned_drag_text_seed_v1");
        assert_eq!(text_box.caret.active, "repo_owned_drag_text_seed_v1".len());
        assert_eq!(text_box.edit_sequence, 1);
        assert_eq!(
            effect_names(&output.effects),
            vec![
                "fire_vba_event:BeforeDropOrPaste",
                "fire_vba_event:Change",
                "request_repaint"
            ]
        );
        let EffectKind::FireVbaEvent {
            event_name,
            arguments,
            cancel_metadata,
            ..
        } = &output.effects[0].kind
        else {
            panic!("expected BeforeDropOrPaste dispatch effect");
        };
        assert_eq!(event_name, "BeforeDropOrPaste");
        assert_eq!(
            arguments
                .iter()
                .map(|argument| argument.name.as_str())
                .collect::<Vec<_>>(),
            vec!["Cancel", "Action", "Data", "X", "Y", "Effect", "Shift"]
        );
        assert_eq!(arguments[1].value, "3");
        assert!(arguments[2].value.contains("drop_or_paste_data_snapshot"));
        assert_eq!(arguments[3].value, "63");
        assert_eq!(arguments[4].value, "15");
        assert_eq!(arguments[5].value, "1");
        assert!(cancel_metadata
            .as_ref()
            .is_some_and(|metadata| metadata.contains("Action mutation remains a non-claim")));
    }

    #[test]
    fn drop_or_paste_non_drag_origins_are_diagnostic_noops() {
        for origin in [
            DropOrPasteOrigin::ClipboardPaste,
            DropOrPasteOrigin::Code,
            DropOrPasteOrigin::Replay,
        ] {
            let mut state = FormState::new("form-main");
            state.controls = vec![ControlNode::text_box(
                "text-1",
                LogicalRect::new(0.0, 0.0, 120.0, 24.0),
                0,
                0,
            )];
            state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
            let text_box = state.ensure_text_box(ControlId::new("text-1"));
            text_box.text = "ABC".to_string();
            text_box.caret.anchor = 3;
            text_box.caret.active = 3;

            let output = reduce(
                state,
                UiEvent {
                    target: UiEventTarget::control("form-main", "text-1"),
                    ..UiEvent::new(
                        UiEventId(196),
                        UiEventSource::Pal,
                        UiEventKind::DropOrPaste(drop_or_paste_event_with_origin(
                            "non-drag-origin",
                            origin,
                            "repo_owned_drag_text_seed_v1",
                            3,
                            1,
                            &["cf_text"],
                        )),
                    )
                },
            );

            let text_box = output
                .state
                .text_boxes
                .iter()
                .find(|entry| entry.control_id == ControlId::new("text-1"))
                .expect("text box state should exist");
            assert_eq!(text_box.text, "ABC");
            assert_eq!(text_box.caret.active, 3);
            assert_eq!(text_box.edit_sequence, 0);
            assert!(output.invalidations.is_empty());
            assert_eq!(
                effect_names(&output.effects),
                vec!["host_capability_request"]
            );
            let EffectKind::HostCapabilityRequest {
                capability,
                payload_summary,
                ..
            } = &output.effects[0].kind
            else {
                panic!("expected drag/drop diagnostic effect");
            };
            assert_eq!(capability, "drag_drop_data_transfer_diagnostic");
            assert!(payload_summary
                .as_ref()
                .is_some_and(|summary| summary.contains("unsupported_drop_or_paste_origin")));
        }
    }

    #[test]
    fn drop_or_paste_replay_source_with_drag_origin_still_replays_drag_drop() {
        let mut state = FormState::new("form-main");
        state.controls = vec![ControlNode::text_box(
            "text-1",
            LogicalRect::new(0.0, 0.0, 120.0, 24.0),
            0,
            0,
        )];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
        state.ensure_text_box(ControlId::new("text-1"));

        let output = reduce(
            state,
            UiEvent {
                target: UiEventTarget::control("form-main", "text-1"),
                ..UiEvent::new(
                    UiEventId(197),
                    UiEventSource::Replay,
                    UiEventKind::DropOrPaste(drop_or_paste_drag_event(
                        "drag-replay",
                        "repo_owned_drag_text_seed_v1",
                        3,
                        1,
                        &["cf_text"],
                    )),
                )
            },
        );

        let text_box = output
            .state
            .text_boxes
            .iter()
            .find(|entry| entry.control_id == ControlId::new("text-1"))
            .expect("text box state should exist");
        assert_eq!(text_box.text, "repo_owned_drag_text_seed_v1");
        assert_eq!(text_box.edit_sequence, 1);
        assert_eq!(
            effect_names(&output.effects),
            vec![
                "fire_vba_event:BeforeDropOrPaste",
                "fire_vba_event:Change",
                "request_repaint"
            ]
        );
    }

    #[test]
    fn drop_or_paste_unsupported_format_records_diagnostic_without_mutation() {
        let mut state = FormState::new("form-main");
        state.controls = vec![ControlNode::text_box(
            "text-1",
            LogicalRect::new(0.0, 0.0, 120.0, 24.0),
            0,
            0,
        )];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
        let text_box = state.ensure_text_box(ControlId::new("text-1"));
        text_box.text = "ABC".to_string();
        text_box.caret.anchor = 3;
        text_box.caret.active = 3;

        let output = reduce(
            state,
            UiEvent {
                target: UiEventTarget::control("form-main", "text-1"),
                ..UiEvent::new(
                    UiEventId(96),
                    UiEventSource::Pal,
                    UiEventKind::DropOrPaste(drop_or_paste_drag_event(
                        "drag-image",
                        "ignored",
                        3,
                        1,
                        &["image/png"],
                    )),
                )
            },
        );

        let text_box = output
            .state
            .text_boxes
            .iter()
            .find(|entry| entry.control_id == ControlId::new("text-1"))
            .expect("text box state should exist");
        assert_eq!(text_box.text, "ABC");
        assert_eq!(text_box.edit_sequence, 0);
        assert!(output.invalidations.is_empty());
        assert_eq!(
            effect_names(&output.effects),
            vec!["host_capability_request"]
        );
        let EffectKind::HostCapabilityRequest {
            capability,
            payload_summary,
            ..
        } = &output.effects[0].kind
        else {
            panic!("expected drag/drop diagnostic effect");
        };
        assert_eq!(capability, "drag_drop_data_transfer_diagnostic");
        assert!(payload_summary
            .as_ref()
            .is_some_and(|summary| summary.contains("unsupported_data_format")));
    }

    #[test]
    fn textbox_backspace_and_delete_emit_change_only_when_text_mutates() {
        let mut state = FormState::new("form-main");
        state.controls = vec![ControlNode::text_box(
            "text-1",
            LogicalRect::new(0.0, 0.0, 80.0, 18.0),
            0,
            0,
        )];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
        let text_box = state.ensure_text_box(ControlId::new("text-1"));
        text_box.text = "ABC".to_string();
        text_box.caret.anchor = 2;
        text_box.caret.active = 2;

        let backspace = reduce(
            state,
            key_down_event(UiEventId(76), KeyCode::Backspace, false),
        );
        let text_box = backspace
            .state
            .text_boxes
            .iter()
            .find(|entry| entry.control_id == ControlId::new("text-1"))
            .expect("text box state should exist");
        assert_eq!(text_box.text, "AC");
        assert_eq!(text_box.caret.active, 1);
        assert_eq!(
            effect_names(&backspace.effects),
            vec![
                "fire_vba_event:KeyDown",
                "fire_vba_event:Change",
                "request_repaint"
            ]
        );

        let delete = reduce(
            backspace.state,
            key_down_event(UiEventId(77), KeyCode::Delete, false),
        );
        let text_box = delete
            .state
            .text_boxes
            .iter()
            .find(|entry| entry.control_id == ControlId::new("text-1"))
            .expect("text box state should exist");
        assert_eq!(text_box.text, "A");
        assert_eq!(text_box.caret.active, 1);
        assert_eq!(
            effect_names(&delete.effects),
            vec![
                "fire_vba_event:KeyDown",
                "fire_vba_event:Change",
                "request_repaint"
            ]
        );
    }

    #[test]
    fn w005_probe_controls_route_input_and_emit_probe_display_list() {
        let mut state = w005_probe_form_state();
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
        state.ensure_text_box(ControlId::new("text-1"));

        let label_down = reduce(
            state,
            UiEvent::new(
                UiEventId(60),
                UiEventSource::Replay,
                UiEventKind::MouseDown(mouse_button_event_at(true, 8.0, 8.0)),
            ),
        );
        assert_eq!(
            label_down.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("text-1")))
        );
        assert_eq!(
            effect_names(&label_down.effects),
            vec!["capture_mouse", "fire_vba_event:MouseDown"]
        );

        let label_up = reduce(
            label_down.state,
            UiEvent::new(
                UiEventId(61),
                UiEventSource::Replay,
                UiEventKind::MouseUp(mouse_button_event_at(false, 8.0, 8.0)),
            ),
        );
        assert_eq!(
            effect_names(&label_up.effects),
            vec![
                "release_mouse",
                "fire_vba_event:MouseUp",
                "fire_vba_event:Click"
            ]
        );

        let text_down = reduce(
            label_up.state,
            UiEvent::new(
                UiEventId(62),
                UiEventSource::Replay,
                UiEventKind::MouseDown(mouse_button_event_at(true, 8.0, 28.0)),
            ),
        );
        assert_eq!(
            text_down.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("text-1")))
        );
        let text_up = reduce(
            text_down.state,
            UiEvent::new(
                UiEventId(66),
                UiEventSource::Replay,
                UiEventKind::MouseUp(mouse_button_event_at(false, 8.0, 28.0)),
            ),
        );
        assert_eq!(
            effect_names(&text_up.effects),
            vec!["release_mouse", "fire_vba_event:MouseUp"]
        );
        let typed = reduce(
            text_up.state,
            UiEvent::new(
                UiEventId(63),
                UiEventSource::Replay,
                UiEventKind::CharacterInput(CharacterInputEvent {
                    text: "A".to_string(),
                    modifiers: KeyboardModifiers::default(),
                    raw: Vec::new(),
                }),
            ),
        );
        assert_eq!(
            text_box_state(&typed.state, &ControlId::new("text-1"))
                .map(|entry| entry.text.as_str()),
            Some("A")
        );
        assert_eq!(
            effect_names(&typed.effects),
            vec![
                "fire_vba_event:KeyPress",
                "fire_vba_event:Change",
                "request_repaint"
            ]
        );

        let display_list = build_probe_display_list(&typed.state, LogicalSize::new(120.0, 80.0));
        let encoded =
            serde_json::to_string_pretty(&display_list).expect("display list should serialize");
        assert!(encoded.contains("draw_text"));
        assert!(encoded.contains("OxForms"));
        assert!(encoded.contains("\"A\""));
        assert!(encoded.contains("caret"));
        assert!(encoded.contains("focus_rect"));

        let button_down = reduce(
            typed.state,
            UiEvent::new(
                UiEventId(64),
                UiEventSource::Replay,
                UiEventKind::MouseDown(mouse_button_event_at(true, 8.0, 52.0)),
            ),
        );
        let button_up = reduce(
            button_down.state,
            UiEvent::new(
                UiEventId(65),
                UiEventSource::Replay,
                UiEventKind::MouseUp(mouse_button_event_at(false, 8.0, 52.0)),
            ),
        );
        assert_eq!(
            effect_names(&button_up.effects),
            vec![
                "release_mouse",
                "fire_vba_event:MouseUp",
                "fire_vba_event:Click",
                "request_repaint"
            ]
        );
    }

    #[test]
    fn probe_display_list_records_pressed_focus_text_and_pal_smoke_fills() {
        let mut state = w005_probe_form_state();
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
        let text_box = state.ensure_text_box(ControlId::new("text-1"));
        text_box.text = "Hi".to_string();
        text_box.caret.anchor = 2;
        text_box.caret.active = 2;
        state.pressed_state = Some(PressedState {
            target: FocusTarget::Control(ControlId::new("ok")),
            origin: PressedOrigin::Mouse,
            armed: true,
        });

        let display_list = build_probe_display_list(&state, LogicalSize::new(120.0, 80.0));
        assert_eq!(
            display_list.schema_version,
            PROBE_DISPLAY_LIST_SCHEMA_VERSION
        );
        assert_eq!(
            display_list
                .commands
                .iter()
                .filter(|command| matches!(command, ProbeDisplayCommand::DrawText { .. }))
                .count(),
            3
        );
        assert!(display_list.commands.iter().any(|command| matches!(
            command,
            ProbeDisplayCommand::FillRect {
                role: ProbeDisplayRole::CommandButtonPressedFace,
                ..
            }
        )));
        assert!(display_list.commands.iter().any(|command| matches!(
            command,
            ProbeDisplayCommand::Caret {
                target,
                caret_index: 2,
                ..
            } if target.control_id == Some(ControlId::new("text-1"))
        )));

        let pal_display_list =
            build_probe_pal_smoke_display_list(&state, SurfaceSize::new(120, 80));
        assert_eq!(pal_display_list.commands.len(), 3);
        pal_display_list
            .validate()
            .expect("PAL smoke display list should validate");
    }

    #[test]
    fn checkbox_mouse_click_toggles_boolean_value_and_emits_event_effects() {
        let mut state = FormState::new("form-main");
        state.controls =
            vec![
                ControlNode::check_box("agree", LogicalRect::new(0.0, 0.0, 96.0, 18.0), 0, 0)
                    .with_caption("Agree"),
            ];
        state.ensure_check_box(ControlId::new("agree"));

        let down = reduce(
            state,
            UiEvent::new(
                UiEventId(80),
                UiEventSource::Replay,
                UiEventKind::MouseDown(mouse_button_event_at(true, 5.0, 5.0)),
            ),
        );

        assert_eq!(
            down.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("agree")))
        );
        assert_eq!(
            down.state
                .pressed_state
                .as_ref()
                .map(|pressed| &pressed.target),
            Some(&FocusTarget::Control(ControlId::new("agree")))
        );
        assert_eq!(
            effect_names(&down.effects),
            vec![
                "transfer_focus",
                "request_repaint",
                "capture_mouse",
                "fire_vba_event:MouseDown",
                "request_repaint"
            ]
        );
        assert_eq!(
            down.invalidations
                .iter()
                .map(|invalidation| invalidation.reason)
                .collect::<Vec<_>>(),
            vec![
                InvalidationReason::FocusChanged,
                InvalidationReason::CheckBoxPressedChanged,
            ]
        );

        let up = reduce(
            down.state,
            UiEvent::new(
                UiEventId(81),
                UiEventSource::Replay,
                UiEventKind::MouseUp(mouse_button_event_at(false, 5.0, 5.0)),
            ),
        );

        assert!(up.state.capture_owner.is_none());
        assert!(up.state.pressed_state.is_none());
        assert_eq!(
            check_box_state(&up.state, &ControlId::new("agree")).map(|entry| entry.checked),
            Some(true)
        );
        assert_eq!(
            effect_names(&up.effects),
            vec![
                "release_mouse",
                "fire_vba_event:MouseUp",
                "fire_vba_event:Click",
                "fire_vba_event:Change",
                "request_repaint",
                "request_repaint"
            ]
        );
        assert_eq!(
            up.invalidations
                .iter()
                .map(|invalidation| invalidation.reason)
                .collect::<Vec<_>>(),
            vec![
                InvalidationReason::CheckBoxValueChanged,
                InvalidationReason::CheckBoxPressedChanged,
            ]
        );
        assert!(up.transition.after.check_box_values[0].checked);
    }

    #[test]
    fn checkbox_keyboard_shape_emits_key_events_but_does_not_claim_toggle_ordering() {
        let mut state = FormState::new("form-main");
        state.controls = vec![ControlNode::check_box(
            "agree",
            LogicalRect::new(0.0, 0.0, 96.0, 18.0),
            0,
            0,
        )];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("agree")));
        state.ensure_check_box(ControlId::new("agree"));

        let down = reduce(state, key_down_event(UiEventId(82), KeyCode::Space, false));
        assert_eq!(effect_names(&down.effects), vec!["fire_vba_event:KeyDown"]);
        assert_eq!(
            check_box_state(&down.state, &ControlId::new("agree")).map(|entry| entry.checked),
            Some(false)
        );

        let up = reduce(down.state, key_up_event(UiEventId(83), KeyCode::Space));
        assert_eq!(effect_names(&up.effects), vec!["fire_vba_event:KeyUp"]);
        assert_eq!(
            check_box_state(&up.state, &ControlId::new("agree")).map(|entry| entry.checked),
            Some(false)
        );
    }

    #[test]
    fn checkbox_display_list_serializes_glyph_check_caption_focus_disabled_and_pressed_intent() {
        let mut state = FormState::new("form-main");
        state.controls = vec![
            ControlNode::check_box("agree", LogicalRect::new(0.0, 0.0, 96.0, 18.0), 0, 0)
                .with_caption("Agree"),
            ControlNode::check_box("disabled", LogicalRect::new(0.0, 24.0, 96.0, 18.0), 1, 1)
                .with_caption("Disabled")
                .disabled(),
        ];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("agree")));
        state.pressed_state = Some(PressedState {
            target: FocusTarget::Control(ControlId::new("agree")),
            origin: PressedOrigin::Mouse,
            armed: true,
        });
        state.ensure_check_box(ControlId::new("agree")).checked = true;
        state.ensure_check_box(ControlId::new("disabled")).checked = true;

        let display_list = build_probe_display_list(&state, LogicalSize::new(120.0, 60.0));
        let encoded =
            serde_json::to_string_pretty(&display_list).expect("display list should serialize");

        assert_eq!(
            display_list.schema_version,
            CHECKBOX_DISPLAY_LIST_SCHEMA_VERSION
        );
        assert!(encoded.contains("check_box_pressed_face"));
        assert!(encoded.contains("check_box_glyph"));
        assert!(encoded.contains("check_box_check_mark"));
        assert!(encoded.contains("check_box_text"));
        assert!(encoded.contains("Agree"));
        assert!(encoded.contains("Disabled"));
        assert!(encoded.contains("focus_rect"));
        assert!(encoded.contains("disabled_overlay"));
    }

    #[test]
    fn character_input_ignores_non_textbox_focus_and_control_characters() {
        let mut state = FormState::new("form-main");
        state.controls = vec![ControlNode::command_button(
            "ok",
            LogicalRect::new(0.0, 0.0, 80.0, 18.0),
            0,
            0,
        )];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("ok")));

        let output = reduce(
            state,
            UiEvent::new(
                UiEventId(51),
                UiEventSource::Replay,
                UiEventKind::CharacterInput(CharacterInputEvent {
                    text: "\r".to_string(),
                    modifiers: KeyboardModifiers::default(),
                    raw: Vec::new(),
                }),
            ),
        );

        assert!(output.effects.is_empty());
        assert!(output.state.text_boxes.is_empty());
        assert_eq!(
            output
                .state
                .keyboard
                .last_character_input
                .as_ref()
                .map(|input| input.text_len),
            Some(1)
        );
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
    fn modeless_close_query_completion_hides_before_unload() {
        let state = FormState::new("form-main");
        let close = reduce(
            state,
            UiEvent {
                target: UiEventTarget {
                    form_id: Some(FormId::new("form-main")),
                    window_id: Some(WindowId::new("window-main")),
                    control_id: None,
                },
                ..UiEvent::new(
                    UiEventId(22),
                    UiEventSource::Pal,
                    UiEventKind::CloseRequest(CloseRequestEvent {
                        origin: CloseRequestOrigin::CloseButton,
                        reason: CloseReason::User,
                        query_policy: CloseQueryPolicy::Query,
                        coordinates: None,
                    }),
                )
            },
        );

        assert_eq!(close.state.lifecycle, LifecycleState::QueryClosePending);
        assert_eq!(close.state.pump.term, PumpTerm::CloseUnloadCancellation);
        assert_eq!(
            close
                .state
                .close_flow
                .as_ref()
                .and_then(|flow| flow.close_mode),
            Some(0)
        );
        assert_eq!(
            effect_names(&close.effects),
            vec!["fire_vba_event:QueryClose"]
        );
        let EffectKind::FireVbaEvent { arguments, .. } = &close.effects[0].kind else {
            panic!("close request should ask the shared event path to fire QueryClose");
        };
        assert_eq!(arguments[1].name, "CloseMode");
        assert_eq!(arguments[1].value, "0");

        let queried = reduce(
            close.state,
            UiEvent {
                target: UiEventTarget::form("form-main"),
                ..UiEvent::new(
                    UiEventId(23),
                    UiEventSource::Service,
                    UiEventKind::QueryCloseCompleted(QueryCloseCompletedEvent {
                        form_id: FormId::new("form-main"),
                        reason: CloseReason::User,
                        cancelled: false,
                        close_mode: Some(0),
                        dispatch_diagnostics: vec![RawDiagnostic::text(
                            "oxforms-0a0.3",
                            "native_dispatch_blocker",
                            "QueryClose handler execution is blocked by oxforms-0a0.2.",
                        )],
                    }),
                )
            },
        );

        assert_eq!(queried.state.lifecycle, LifecycleState::HidePending);
        assert_eq!(effect_names(&queried.effects), vec!["hide_form"]);
        assert!(queried
            .state
            .close_flow
            .as_ref()
            .is_some_and(|flow| flow.awaiting_window_hide_for_unload));

        let hidden = reduce(
            queried.state,
            UiEvent {
                target: UiEventTarget {
                    form_id: Some(FormId::new("form-main")),
                    window_id: Some(WindowId::new("window-main")),
                    control_id: None,
                },
                ..UiEvent::new(
                    UiEventId(24),
                    UiEventSource::Service,
                    UiEventKind::WindowHidden(WindowHiddenEvent {
                        form_id: FormId::new("form-main"),
                        window_id: WindowId::new("window-main"),
                        reason: LifecycleReason::User,
                    }),
                )
            },
        );

        assert_eq!(hidden.state.lifecycle, LifecycleState::Unloading);
        assert_eq!(effect_names(&hidden.effects), vec!["unload_form"]);

        let unloaded = reduce(
            hidden.state,
            UiEvent {
                target: UiEventTarget::form("form-main"),
                ..UiEvent::new(
                    UiEventId(25),
                    UiEventSource::Service,
                    UiEventKind::Unloaded(UnloadedEvent {
                        form_id: FormId::new("form-main"),
                        reason: LifecycleReason::User,
                    }),
                )
            },
        );

        assert_eq!(unloaded.state.lifecycle, LifecycleState::Hidden);
        assert_eq!(unloaded.state.pump.term, PumpTerm::HostModelessPump);
        assert_eq!(unloaded.state.close_flow, None);
        assert_ne!(unloaded.state.lifecycle, LifecycleState::Terminated);
    }

    #[test]
    fn foreign_query_close_completion_does_not_authorize_hide() {
        let pending = reduce(
            FormState::new("form-main"),
            UiEvent {
                target: UiEventTarget {
                    form_id: Some(FormId::new("form-main")),
                    window_id: Some(WindowId::new("window-main")),
                    control_id: None,
                },
                ..UiEvent::new(
                    UiEventId(26),
                    UiEventSource::Pal,
                    UiEventKind::CloseRequest(CloseRequestEvent {
                        origin: CloseRequestOrigin::CloseButton,
                        reason: CloseReason::User,
                        query_policy: CloseQueryPolicy::Query,
                        coordinates: None,
                    }),
                )
            },
        );

        let output = reduce(
            pending.state,
            query_close_completed_event(UiEventId(27), "other-form", false),
        );

        assert_eq!(output.state.lifecycle, LifecycleState::QueryClosePending);
        assert_eq!(effect_names(&output.effects), Vec::<String>::new());
        assert!(output.state.close_flow.is_some());
    }

    #[test]
    fn stale_query_close_completion_without_close_flow_does_not_authorize_hide() {
        let mut state = FormState::new("form-main");
        state.lifecycle = LifecycleState::QueryClosePending;

        let output = reduce(
            state,
            query_close_completed_event(UiEventId(28), "form-main", false),
        );

        assert_eq!(output.state.lifecycle, LifecycleState::QueryClosePending);
        assert_eq!(output.state.close_flow, None);
        assert_eq!(effect_names(&output.effects), Vec::<String>::new());
    }

    #[test]
    fn cancelled_query_close_consumes_pending_close_authority() {
        let pending = reduce(
            FormState::new("form-main"),
            UiEvent {
                target: UiEventTarget {
                    form_id: Some(FormId::new("form-main")),
                    window_id: Some(WindowId::new("window-main")),
                    control_id: None,
                },
                ..UiEvent::new(
                    UiEventId(29),
                    UiEventSource::Pal,
                    UiEventKind::CloseRequest(CloseRequestEvent {
                        origin: CloseRequestOrigin::CloseButton,
                        reason: CloseReason::User,
                        query_policy: CloseQueryPolicy::Query,
                        coordinates: None,
                    }),
                )
            },
        );

        let cancelled = reduce(
            pending.state,
            query_close_completed_event(UiEventId(30), "form-main", true),
        );

        assert_eq!(cancelled.state.lifecycle, LifecycleState::CloseCancelled);
        assert_eq!(cancelled.state.close_flow, None);
        assert_eq!(effect_names(&cancelled.effects), vec!["request_repaint"]);

        let stale = reduce(
            cancelled.state,
            query_close_completed_event(UiEventId(31), "form-main", false),
        );

        assert_eq!(stale.state.lifecycle, LifecycleState::CloseCancelled);
        assert_eq!(stale.state.close_flow, None);
        assert_eq!(effect_names(&stale.effects), Vec::<String>::new());
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
    fn key_down_and_key_up_are_routed_to_focused_control_with_diagnostics() {
        let mut state = FormState::new("form-main");
        state.controls = vec![ControlNode::text_box(
            "text-1",
            LogicalRect::new(0.0, 0.0, 80.0, 18.0),
            0,
            0,
        )];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));

        let down = reduce(
            state,
            UiEvent::new(
                UiEventId(40),
                UiEventSource::Replay,
                UiEventKind::KeyDown(oxforms_pal::KeyEvent {
                    key: oxforms_pal::KeyCode::Character("A".to_string()),
                    modifiers: KeyboardModifiers {
                        shift: true,
                        ..KeyboardModifiers::default()
                    },
                    repeat: KeyRepeat::default(),
                    raw: RawKeyDiagnostics {
                        virtual_key: Some(0x41),
                        scan_code: Some(0x1e),
                        native_code: None,
                        is_extended: Some(false),
                    },
                }),
            ),
        );

        assert_eq!(effect_names(&down.effects), vec!["fire_vba_event:KeyDown"]);
        assert_eq!(
            down.effects[0].target,
            UiEventTarget::control("form-main", "text-1")
        );
        let encoded = serde_json::to_string(&down.effects).expect("key effect should serialize");
        assert!(encoded.contains("raw_virtual_key"));
        assert!(encoded.contains("character:A"));

        let up = reduce(
            down.state,
            UiEvent::new(
                UiEventId(41),
                UiEventSource::Replay,
                UiEventKind::KeyUp(oxforms_pal::KeyEvent {
                    key: oxforms_pal::KeyCode::Character("A".to_string()),
                    modifiers: KeyboardModifiers::default(),
                    repeat: KeyRepeat::default(),
                    raw: RawKeyDiagnostics::default(),
                }),
            ),
        );

        assert_eq!(effect_names(&up.effects), vec!["fire_vba_event:KeyUp"]);
        assert!(up.state.keyboard.last_key_up.is_some());
    }

    #[test]
    fn enter_routes_to_default_command_button_and_key_up_releases_pressed_state() {
        let mut state = FormState::new("form-main");
        state.controls = vec![
            ControlNode::text_box("text-1", LogicalRect::new(0.0, 0.0, 80.0, 18.0), 0, 0),
            ControlNode::command_button("ok", LogicalRect::new(0.0, 24.0, 64.0, 20.0), 0, 1),
        ];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
        state.default_button = Some(ControlId::new("ok"));

        let down = reduce(state, key_down_event(UiEventId(52), KeyCode::Enter, false));

        assert_eq!(
            effect_names(&down.effects),
            vec![
                "fire_vba_event:KeyDown",
                "fire_vba_event:Click",
                "request_repaint"
            ]
        );
        assert_eq!(
            down.effects[1].target,
            UiEventTarget::control("form-main", "ok")
        );
        assert_eq!(
            down.state
                .pressed_state
                .as_ref()
                .map(|pressed| pressed.origin),
            Some(PressedOrigin::KeyboardDefault)
        );

        let up = reduce(down.state, key_up_event(UiEventId(53), KeyCode::Enter));
        assert_eq!(
            effect_names(&up.effects),
            vec!["fire_vba_event:KeyUp", "request_repaint"]
        );
        assert!(up.state.pressed_state.is_none());
    }

    #[test]
    fn escape_routes_to_cancel_command_button() {
        let mut state = FormState::new("form-main");
        state.controls = vec![
            ControlNode::text_box("text-1", LogicalRect::new(0.0, 0.0, 80.0, 18.0), 0, 0),
            ControlNode::command_button("cancel", LogicalRect::new(0.0, 24.0, 64.0, 20.0), 0, 1),
        ];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
        state.cancel_button = Some(ControlId::new("cancel"));

        let output = reduce(state, key_down_event(UiEventId(54), KeyCode::Escape, false));

        assert_eq!(
            effect_names(&output.effects),
            vec![
                "fire_vba_event:KeyDown",
                "fire_vba_event:Click",
                "request_repaint"
            ]
        );
        assert_eq!(
            output.effects[1].target,
            UiEventTarget::control("form-main", "cancel")
        );
        assert_eq!(
            output
                .state
                .pressed_state
                .as_ref()
                .map(|pressed| pressed.origin),
            Some(PressedOrigin::KeyboardCancel)
        );
    }

    #[test]
    fn alt_character_routes_to_caption_accelerator_command_button() {
        let mut state = FormState::new("form-main");
        state.controls = vec![
            ControlNode::text_box("text-1", LogicalRect::new(0.0, 0.0, 80.0, 18.0), 0, 0),
            ControlNode::command_button("ok", LogicalRect::new(0.0, 24.0, 64.0, 20.0), 0, 1)
                .with_caption("&OK"),
            ControlNode::command_button("other", LogicalRect::new(72.0, 24.0, 64.0, 20.0), 0, 2)
                .with_caption("O&ther"),
        ];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));

        let output = reduce(
            state,
            UiEvent::new(
                UiEventId(55),
                UiEventSource::Replay,
                UiEventKind::KeyDown(oxforms_pal::KeyEvent {
                    key: KeyCode::Character("o".to_string()),
                    modifiers: KeyboardModifiers {
                        alt: true,
                        ..KeyboardModifiers::default()
                    },
                    repeat: KeyRepeat::default(),
                    raw: RawKeyDiagnostics::default(),
                }),
            ),
        );

        assert_eq!(
            effect_names(&output.effects),
            vec![
                "fire_vba_event:KeyDown",
                "fire_vba_event:Click",
                "request_repaint"
            ]
        );
        assert_eq!(
            output.effects[1].target,
            UiEventTarget::control("form-main", "ok")
        );
        assert_eq!(
            output
                .state
                .pressed_state
                .as_ref()
                .map(|pressed| pressed.origin),
            Some(PressedOrigin::Accelerator)
        );
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

    fn key_up_event(event_id: UiEventId, key: KeyCode) -> UiEvent {
        UiEvent::new(
            event_id,
            UiEventSource::Replay,
            UiEventKind::KeyUp(oxforms_pal::KeyEvent {
                key,
                modifiers: KeyboardModifiers::default(),
                repeat: KeyRepeat::default(),
                raw: RawKeyDiagnostics::default(),
            }),
        )
    }

    fn clipboard_get_text_event(
        event_id: UiEventId,
        request_id: &str,
        text: &str,
        formats: &[&str],
    ) -> UiEvent {
        UiEvent {
            target: UiEventTarget::control("form-main", "text-1"),
            ..UiEvent::new(
                event_id,
                UiEventSource::Service,
                UiEventKind::ClipboardResult(ClipboardResultEvent {
                    request_id: ServiceRequestId::new(request_id),
                    operation: ClipboardOperation::Get,
                    outcome: ServiceOutcome::Success,
                    formats: formats.iter().map(|format| (*format).to_string()).collect(),
                    payload: Some(ServicePayload {
                        content_type: Some("text/plain".to_string()),
                        text: Some(text.to_string()),
                        bytes_sha256: None,
                        metadata: vec![RawDiagnostic::text(
                            "test",
                            "clipboard_seed",
                            "repo_owned_text_seed_v1",
                        )],
                    }),
                }),
            )
        }
    }

    fn drag_over_event(
        drag_session_id: &str,
        drag_state: i32,
        effect: i32,
        formats: &[&str],
    ) -> DragOverEvent {
        DragOverEvent {
            drag_session_id: drag_session_id.to_string(),
            coordinates: drag_drop_coordinates(),
            modifiers: KeyboardModifiers::default(),
            buttons_down: MouseButtons {
                left: true,
                ..MouseButtons::default()
            },
            drag_state,
            effect,
            data: drag_data_snapshot(drag_session_id, "repo_owned_drag_text_seed_v1", formats),
        }
    }

    fn drop_or_paste_drag_event(
        transfer_session_id: &str,
        text: &str,
        action: i32,
        effect: i32,
        formats: &[&str],
    ) -> DropOrPasteEvent {
        drop_or_paste_event_with_origin(
            transfer_session_id,
            DropOrPasteOrigin::DragDrop,
            text,
            action,
            effect,
            formats,
        )
    }

    fn drop_or_paste_event_with_origin(
        transfer_session_id: &str,
        origin: DropOrPasteOrigin,
        text: &str,
        action: i32,
        effect: i32,
        formats: &[&str],
    ) -> DropOrPasteEvent {
        DropOrPasteEvent {
            transfer_session_id: transfer_session_id.to_string(),
            origin,
            coordinates: drag_drop_coordinates(),
            modifiers: KeyboardModifiers::default(),
            action,
            effect,
            data: drag_data_snapshot(transfer_session_id, text, formats),
        }
    }

    fn drag_data_snapshot(snapshot_id: &str, text: &str, formats: &[&str]) -> DataObjectSnapshot {
        DataObjectSnapshot {
            snapshot_id: ServiceRequestId::new(format!("snapshot-{snapshot_id}")),
            formats: formats.iter().map(|format| (*format).to_string()).collect(),
            payload: Some(ServicePayload {
                content_type: Some("text/plain".to_string()),
                text: Some(text.to_string()),
                bytes_sha256: None,
                metadata: vec![RawDiagnostic::text(
                    "test",
                    "repo_owned_drag_seed",
                    "repo_owned_drag_text_seed_v1",
                )],
            }),
            metadata: vec![
                RawDiagnostic::text("oracle", "data_object_get_format_1", "true"),
                RawDiagnostic::text("policy", "live_object_identity", "not_recorded"),
            ],
        }
    }

    fn drag_drop_coordinates() -> CoordinatePayload {
        let mut coordinates = CoordinatePayload {
            control_local: Some(LogicalPoint::new(63.0, 15.0)),
            ..CoordinatePayload::default()
        };
        coordinates.raw_samples.push(RawCoordinateSample {
            space: oxforms_pal::CoordinateSpace::MsformsEventArgs,
            point: oxforms_pal::CoordinatePoint::new(63.0, 15.0),
            source: "oxforms-0a0.16".to_string(),
        });
        coordinates
    }

    fn query_close_completed_event(event_id: UiEventId, form_id: &str, cancelled: bool) -> UiEvent {
        UiEvent {
            target: UiEventTarget::form(form_id),
            ..UiEvent::new(
                event_id,
                UiEventSource::Service,
                UiEventKind::QueryCloseCompleted(QueryCloseCompletedEvent {
                    form_id: FormId::new(form_id),
                    reason: CloseReason::User,
                    cancelled,
                    close_mode: Some(0),
                    dispatch_diagnostics: Vec::new(),
                }),
            )
        }
    }

    fn w005_probe_form_state() -> FormState {
        let mut state = FormState::new("form-main");
        state.controls = vec![
            ControlNode::label("label", LogicalRect::new(4.0, 4.0, 60.0, 16.0), 0)
                .with_caption("OxForms"),
            ControlNode::text_box("text-1", LogicalRect::new(4.0, 24.0, 80.0, 18.0), 0, 0),
            ControlNode::command_button("ok", LogicalRect::new(4.0, 48.0, 44.0, 20.0), 0, 1)
                .with_caption("&OK"),
        ];
        state.default_button = Some(ControlId::new("ok"));
        state
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
