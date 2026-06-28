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

mod controls;
mod frm;
mod runtime;
mod trace_replay;

use serde::{Deserialize, Serialize};

pub use controls::{hit_test_control_tree, ControlKind, ControlNode, HitTestResult};
pub use frm::{
    load_selected_frm_interaction_state, FrmControlEventHooks, FrmControlRecord, FrmFrxReference,
    FrmInteractionModel, FrmLoadError, FrmUnsupportedRecord, COORDINATE_MODEL_SPEC_PATH,
};
pub use runtime::{
    materialize_form_from_frm, materialize_w007_demo_form, RuntimeControlBinding, RuntimeForm,
    W007_DEMO_FORM_FRM,
};
pub use trace_replay::{
    build_w005_trace_replay_golden_artifacts, build_w006_modal_frame_trace_subset_artifact,
    W005_TRACE_REPLAY_GOLDEN_TRACE_PATH, W006_MODAL_FRAME_TRACE_PATH,
};

use oxforms_pal::{
    CharacterInputEvent, ClipboardOperation, ClipboardResultEvent, CloseQueryPolicy, CloseReason,
    CloseRequestEvent, CloseRequestOrigin, ControlId, DataObjectSnapshot, DragOverEvent,
    DropOrPasteEvent, DropOrPasteOrigin, FocusValidationCompletedEvent, FormId, HostScopeId,
    KeyCode, KeyDownSwallowedEvent, KeyEvent, KeyRepeat, KeyboardModifiers, LifecycleReason,
    LogicalPoint, LogicalRect, MouseButton, MouseButtonEvent, MouseMoveEvent, PointerId,
    QueryCloseCompletedEvent, RawKeyDiagnostics, ServiceOutcome, ShowMode, ShowRequestedEvent,
    UiEvent, UiEventId, UiEventKind, UiEventTarget, WindowId, WindowShownEvent,
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
    /// A mouse press deferred through a focus validation, replayed on commit after the
    /// gaining control's `Enter` (oxforms-esq.10). `None` outside a focus-changing click.
    pub pending_mouse_press: Option<PendingMousePress>,
    pub default_button: Option<ControlId>,
    pub cancel_button: Option<ControlId>,
    pub keyboard: KeyboardState,
    pub active: ActiveState,
    pub lifecycle: LifecycleState,
    pub pump: PumpState,
    pub close_flow: Option<CloseFlowState>,
    pub text_boxes: Vec<TextBoxState>,
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
            pending_mouse_press: None,
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

    pub fn ensure_text_box(&mut self, control_id: ControlId) -> &mut TextBoxState {
        if let Some(index) = self
            .text_boxes
            .iter()
            .position(|entry| entry.control_id == control_id)
        {
            return &mut self.text_boxes[index];
        }

        self.text_boxes.push(TextBoxState::new(control_id));
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

/// Reducer-owned sync of a VBA-originated display-text change into [`FormState`].
///
/// The W007 runtime effect runner reads a control's text from its VBA object (after
/// a handler may have changed it) and calls this to fold the change back into the
/// reducer state — it never mutates `FormState` fields directly. The text lands in
/// the control's caption (Label/CommandButton/CheckBox) or text-box value (TextBox).
/// Returns a [`RenderInvalidation`] (also recorded in `state.dirty`) when the text
/// actually changed, so the runner can request a repaint; returns `None` (no-op) for
/// an unchanged value or an unknown control id.
#[must_use]
pub fn sync_control_display_text(
    state: &mut FormState,
    control_id: &ControlId,
    text: &str,
) -> Option<RenderInvalidation> {
    let kind = state
        .controls
        .iter()
        .find(|control| &control.control_id == control_id)?
        .kind;

    let changed = match kind {
        ControlKind::TextBox => {
            let entry = state.ensure_text_box(control_id.clone());
            if entry.text == text {
                false
            } else {
                entry.text = text.to_string();
                // Caret to end. Sufficient for VBA-originated caption/value writeback
                // (the W007 path); a future full text-box writeback slice that must
                // preserve a user selection will need to carry caret/selection too.
                let caret = text.len();
                entry.caret = TextCaretState {
                    anchor: caret,
                    active: caret,
                    preferred_column: None,
                };
                entry.dirty = true;
                entry.edit_sequence += 1;
                true
            }
        }
        ControlKind::Label | ControlKind::CommandButton | ControlKind::CheckBox => {
            let node = state
                .controls
                .iter_mut()
                .find(|control| &control.control_id == control_id)?;
            if node.caption == text {
                false
            } else {
                node.caption = text.to_string();
                true
            }
        }
    };

    if !changed {
        return None;
    }

    let invalidation_id = state.next_invalidation_id();
    let reason = match kind {
        ControlKind::TextBox => InvalidationReason::TextChanged,
        ControlKind::Label | ControlKind::CommandButton | ControlKind::CheckBox => {
            InvalidationReason::CaptionChanged
        }
    };
    let target = UiEventTarget::control(state.form_id.0.clone(), control_id.0.clone());
    let invalidation = RenderInvalidation {
        invalidation_id,
        target: target.clone(),
        reason,
        regions: Vec::new(),
        dirty_subtrees: vec![target],
    };
    state.dirty.invalidations.push(invalidation.clone());
    Some(invalidation)
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

/// A mouse press deferred through a focus validation (oxforms-esq.10). When a
/// focus-CHANGING click begins a cancelable `Exit` validation, the press (capture +
/// `MouseDown` + pressed visual) is held here and replayed by
/// [`reduce_focus_validation_completed`] AFTER the gaining control's `Enter`, so the
/// order is `Exit` -> `Enter` -> `MouseDown` (the W005 modeless oracle).
///
/// On a vetoed `Exit` the press STILL replays (`Exit` -> `MouseDown`, focus unchanged, no
/// `Enter`) -- the press is the original physical input, not part of the focus transfer.
/// Whether a vetoing `Exit` should instead ABSORB the click is unoracled (the W005 capture
/// has only non-vetoing focus-changing clicks) and is tracked on oxforms-esq.11.
///
/// Invariant: at most one press is outstanding -- it is set only alongside
/// [`begin_focus_validation`] (gated on `validation.pending.is_none()`) and taken only by
/// the matching [`reduce_focus_validation_completed`], whose `Exit` readback the runtime
/// folds back within the same dispatch. A debug assertion in `reduce_mouse_down` guards it.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct PendingMousePress {
    pub target: FocusTarget,
    pub effect_target: UiEventTarget,
    pub control_id: Option<ControlId>,
    pub pointer_id: Option<PointerId>,
    pub button: MouseButton,
    pub modifiers: KeyboardModifiers,
    pub point: Option<oxforms_pal::LogicalPoint>,
    pub has_pressed_visual: bool,
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
pub struct TextBoxState {
    pub control_id: ControlId,
    pub text: String,
    pub caret: TextCaretState,
    pub dirty: bool,
    pub edit_sequence: u64,
}

impl TextBoxState {
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
    /// Set when a `KeyDown` handler swallowed the key (`KeyCode -> 0`), folded back via
    /// [`UiEventKind::KeyDownSwallowed`]; the next `CharacterInput` consumes it and
    /// suppresses its `KeyPress`/`Change` (oxforms-esq.4). Cleared on consumption, on the
    /// next `KeyUp`, and at the start of the next `KeyDown`.
    pub suppress_next_character_input: bool,
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
    /// Why focus is moving, carried from the originating event so the deferred commit
    /// (on [`ValidationResult::Passed`]) emits `TransferFocus` with the faithful reason
    /// (oxforms-esq.4).
    pub reason: FocusTransferReason,
    /// When set, the gaining control is also activated (Clicked) once the transfer
    /// commits -- a default-button `Enter` transfers focus to the button and then fires
    /// its `Click` (oxforms-esq.6). A vetoed `Exit` therefore suppresses the `Click` too.
    pub activate_on_commit: bool,
    /// Which cancelable handler is currently in flight (oxforms-esq.11). A dirty data
    /// control validates in two stages -- `BeforeUpdate` first, then `Exit` -- so the
    /// folded-back `Cancel` is routed to the right gate; a clean control begins at `Exit`.
    pub stage: ValidationStage,
}

/// Which cancelable validation handler is in flight on a focus-out. MSForms validates a
/// dirty data control in TWO stages: `BeforeUpdate` fires first and its `Cancel` gates
/// whether the value commits; only then does `Exit` fire and gate the focus move. A clean
/// control skips straight to `Exit` (oxforms-esq.11).
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ValidationStage {
    /// `BeforeUpdate` is in flight: a veto (`Cancel=True`) suppresses `AfterUpdate`,
    /// `Exit`, and the focus move, and keeps the value dirty (uncommitted). A pass commits
    /// the value (`AfterUpdate`) and advances to the `Exit` stage.
    BeforeUpdate,
    /// `Exit` is in flight: a veto keeps focus on the leaving control (and absorbs any
    /// focus-changing mouse press); a pass commits the deferred focus transfer
    /// (oxforms-esq.4).
    Exit,
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
    CaptionChanged,
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
        UiEventKind::FocusValidationCompleted(payload) => {
            reduce_focus_validation_completed(&mut state, &mut context, payload);
        }
        UiEventKind::KeyDownSwallowed(payload) => {
            reduce_key_down_swallowed(&mut state, payload);
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
                // The VBA-visible teardown event fires before the lifecycle reaches
                // Terminated (the W006 nested-modal oracle: QueryClose -> Terminate).
                let target = UiEventTarget::form(state.form_id.0.clone());
                queue_vba_event(&mut state, &mut context, target, "Terminate");
                state.lifecycle = LifecycleState::Terminated;
                state.close_flow = None;
            }
        }
        UiEventKind::PumpYieldRequested(_) => {
            state.pump.term = PumpTerm::DoeventsYield;
            state.pump.reentrancy_depth = event.nesting_depth;
        }
        UiEventKind::PumpFrameExited(payload) => {
            // Derive the new modal depth from our own tracked state, not from the
            // payload: a stale or off-by-one PumpFrameExited.modal_depth must not
            // silently desync nested modal tracking (oxforms-mau). The frame being
            // exited is the current tracked depth; after exit we drop one level
            // (saturating at 0). The payload's modal_depth is a cross-check only —
            // on mismatch we still trust tracked state but annotate the exit reason
            // so the divergence is observable in the effect trace.
            let exited_depth = state.pump.nested_modal_depth;
            state.pump.nested_modal_depth = exited_depth.saturating_sub(1);
            state.pump.term = if state.pump.nested_modal_depth == 0 {
                PumpTerm::HostModelessPump
            } else {
                PumpTerm::ModalFrame
            };
            let reason = if payload.modal_depth == exited_depth {
                payload.exit_reason.clone()
            } else {
                format!(
                    "{} [modal_depth cross-check mismatch: payload={}, tracked={}]",
                    payload.exit_reason, payload.modal_depth, exited_depth
                )
            };
            let target = UiEventTarget::form(state.form_id.0.clone());
            context.push_effect(
                &mut state,
                target,
                EffectKind::ExitModalFrame {
                    modal_depth: exited_depth,
                    reason,
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

/// Read accessors for control value state. Used by the reducer unit tests to assert
/// textbox/checkbox values after a transition (the probe display path that also read
/// them retired in oxforms-rq5.1).
#[cfg(test)]
fn text_box_state<'a>(state: &'a FormState, control_id: &ControlId) -> Option<&'a TextBoxState> {
    state
        .text_boxes
        .iter()
        .find(|entry| entry.control_id == *control_id)
}

#[cfg(test)]
fn check_box_state<'a>(state: &'a FormState, control_id: &ControlId) -> Option<&'a CheckBoxState> {
    state
        .check_boxes
        .iter()
        .find(|entry| entry.control_id == *control_id)
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

    // The mouse press (capture + MouseDown + pressed visual), captured so it can be
    // replayed after a deferred focus commit (oxforms-esq.10).
    let press = PendingMousePress {
        target: target.clone(),
        effect_target: effect_target.clone(),
        control_id: route.control_id.clone(),
        pointer_id: payload.pointer_id,
        button: payload.button,
        modifiers: payload.modifiers,
        point: route.control_local.or(route.form_logical),
        has_pressed_visual: route.has_pressed_visual,
    };

    if route.can_receive_focus
        && previous_focus.as_ref() != Some(&target)
        && state.validation.pending.is_none()
    {
        match focusable_losing_control(state, &previous_focus) {
            // Focus-CHANGING click: MSForms fires a cancelable Exit on the leaving control
            // before focus moves (oxforms-esq.4). Defer BOTH the focus commit AND the mouse
            // press until the Exit veto resolves, so on commit the order is Enter (enterer)
            // then MouseDown -- matching the W005 modeless oracle's Exit -> Enter -> MouseDown
            // on a focus-changing click (seq 565-567/626-628/868-870/983-985) -- and a vetoed
            // Exit absorbs the press entirely (oxforms-esq.10).
            Some(losing_id) => {
                begin_focus_validation(
                    state,
                    context,
                    &losing_id,
                    previous_focus.clone(),
                    target.clone(),
                    FocusTransferReason::Mouse,
                    false,
                );
                // At most one press is outstanding: begin_focus_validation is gated on
                // validation.pending.is_none() (above), and the matching completion takes
                // both together. A stale press here would mean a fold-back was dropped.
                debug_assert!(
                    state.pending_mouse_press.is_none(),
                    "a deferred mouse press was already outstanding (dropped fold-back?)"
                );
                state.pending_mouse_press = Some(press);
                return;
            }
            // No control to veto (initial focus / from the form): commit synchronously, so
            // the in-line press below already fires after the gaining control's Enter.
            None => commit_focus_transfer(
                state,
                context,
                previous_focus.clone(),
                &target,
                &effect_target,
                FocusTransferReason::Mouse,
            ),
        }
    }

    // No focus change (same control / non-focusable target), or a synchronous commit: the
    // press proceeds in-line. A press during an already-pending validation also lands here
    // (the runtime's Exit foldback resolves that validation within the same dispatch, so
    // MouseUp/Click never observes a pending state).
    apply_mouse_press(state, context, &press);
}

/// Apply a mouse press: take mouse capture, emit `MouseDown`, and (for a control with a
/// pressed visual) arm the pressed state + repaint. Shared by the synchronous press path
/// and the deferred replay on a focus-validation commit (oxforms-esq.10).
fn apply_mouse_press(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    press: &PendingMousePress,
) {
    state.capture_owner = Some(CaptureOwner {
        target: press.target.clone(),
        pointer_id: press.pointer_id,
        button: Some(press.button),
        reason: CaptureReason::MousePress,
    });
    context.push_effect(
        state,
        press.effect_target.clone(),
        EffectKind::CaptureMouse {
            pointer_id: press.pointer_id,
            button: Some(press.button),
            reason: CaptureReason::MousePress,
        },
        CompletionPolicy::PlatformCompletionOrDiagnostic,
    );
    context.push_effect(
        state,
        press.effect_target.clone(),
        EffectKind::FireVbaEvent {
            event_name: "MouseDown".to_string(),
            fact_source: Some("docs/specs/FM20_EVENT_FACTS.md".to_string()),
            arguments: mouse_event_arguments(press.button, press.modifiers, press.point),
            cancel_metadata: None,
        },
        CompletionPolicy::DispatchResultRequired,
    );

    if press.has_pressed_visual {
        state.pressed_state = Some(PressedState {
            target: press.target.clone(),
            origin: PressedOrigin::Mouse,
            armed: true,
        });
        let reason = press
            .control_id
            .as_ref()
            .map_or(InvalidationReason::PressedStateChanged, |control_id| {
                pressed_invalidation_reason(state, control_id)
            });
        let invalidation_id = context.push_invalidation(state, press.effect_target.clone(), reason);
        context.push_effect(
            state,
            press.effect_target.clone(),
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
        // MSForms fires the CheckBox value Change BEFORE Click (oracle-confirmed
        // value-change-first ordering: the value toggles, then Change fires, then
        // Click fires, both handlers seeing the new value -- oxforms-p41, live
        // capture checkbox-click-change-20260627T162407Z). The toggle (which
        // queues Change) therefore runs before the Click event is queued.
        if let Some(control_id) = route
            .control_id
            .as_ref()
            .filter(|control_id| is_check_box_control(state, control_id))
            .cloned()
        {
            toggle_check_box(state, context, control_id);
        }
        queue_vba_event(state, context, effect_target.clone(), "Click");
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
    // A new keystroke begins: clear any stale swallow flag left by a prior swallowed
    // KeyDown whose paired CharacterInput/KeyUp never arrived (oxforms-esq.4).
    state.keyboard.suppress_next_character_input = false;
    let keyboard_target = keyboard_event_target(state);

    // A Space (or Enter, when no default button consumes it) on a focused CheckBox
    // toggles the value and fires Change then Click BEFORE the KeyDown: MSForms
    // dispatches the value-change activation ahead of the key event, so the value is
    // already toggled at KeyDown handler entry (oracle-confirmed value-first ordering
    // Change -> Click -> KeyDown -> KeyUp; checkbox-keyboard-toggle capture rows 2-5
    // (Space) / 6-9 (Enter) -- oxforms-esq.8).
    if let Some(control_id) = keyboard_toggle_check_box(state, payload) {
        let effect_target = UiEventTarget::control(state.form_id.0.clone(), control_id.0.clone());
        toggle_check_box(state, context, control_id);
        queue_vba_event(state, context, effect_target, "Click");
    }

    queue_key_event(state, context, keyboard_target, "KeyDown", payload);

    // Ctrl+V on a focused TextBox routes to the clipboard paste path. The V KeyDown
    // requests the clipboard (ClipboardGet); the host folds the result back as a
    // ClipboardResult, which fires BeforeDropOrPaste(Paste) -> Change AFTER this
    // KeyDown (oracle order; ctrlv-keyboard-ordering rows 2-7 -- oxforms-esq.9).
    //
    // Setting suppress_next_character_input is DEFENSIVE here, not the esq.4 1:1 contract:
    // a Ctrl chord delivers no printable WM_CHAR (the OS yields a control char, already
    // dropped by reduce_character_input), so the flag is normally cleared unconsumed by
    // the trailing KeyUp. It guards the edge of a platform that does emit a printable 'v'
    // for the chord, which must NOT type into the box on top of the paste.
    if let Some(control_id) = keyboard_paste_text_box(state, payload) {
        queue_clipboard_paste_request(state, context, &control_id);
        state.keyboard.suppress_next_character_input = true;
    }

    match &payload.key {
        KeyCode::Tab => reduce_tab_key_down(state, context, payload.modifiers.shift),
        KeyCode::Backspace
        | KeyCode::Delete
        | KeyCode::ArrowLeft
        | KeyCode::ArrowRight
        | KeyCode::Home
        | KeyCode::End => reduce_text_box_editing_key_down(state, context, payload),
        KeyCode::Enter => {
            if let Some(button_id) = state.default_button.clone() {
                let button_target = FocusTarget::Control(button_id.clone());
                let previous_focus = state.focus_owner.clone();
                // A default-button Enter transfers focus to the button (Exit on the
                // focused control, then Enter on the button) before its Click; the Click
                // is activated when the transfer commits (oxforms-esq.6). When focus is
                // already the button -- or there is nothing to leave / a pending
                // validation -- it Clicks in place as before. NOTE: held-Enter (OS
                // auto-repeat) behavior is UNCAPTURED here -- unlike the CheckBox toggle
                // (gated on !is_repeat, esq.12), a button may auto-repeat its activation, so
                // this arm stays repeat-blind pending a held-default-button-Enter capture
                // (oxforms-esq.15). A non-activatable default
                // button (hidden/disabled) does NOT transfer: it falls through to
                // activate_command_button, which no-ops -- so no spurious Exit/focus move.
                let button_activatable = find_control(state, &button_id).is_some_and(|control| {
                    control.kind == ControlKind::CommandButton && control.visible && control.enabled
                });
                let losing = if button_activatable
                    && state.validation.pending.is_none()
                    && previous_focus.as_ref() != Some(&button_target)
                {
                    focusable_losing_control(state, &previous_focus)
                } else {
                    None
                };
                if let Some(losing_id) = losing {
                    begin_focus_validation(
                        state,
                        context,
                        &losing_id,
                        previous_focus,
                        button_target,
                        FocusTransferReason::Keyboard,
                        true,
                    );
                } else {
                    activate_command_button(
                        state,
                        context,
                        &button_id,
                        PressedOrigin::KeyboardDefault,
                    );
                }
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
    // A swallowed key with no paired character (e.g. an arrow) ends here; clear the flag
    // so it never suppresses a later, unrelated character (oxforms-esq.4).
    state.keyboard.suppress_next_character_input = false;
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

    // A pending validation must resolve before another focus change begins (in the
    // runtime the Exit readback folds back within the same dispatch, so this never
    // persists across external events).
    if state.validation.pending.is_some() {
        return;
    }

    match focusable_losing_control(state, &previous_focus) {
        // MSForms fires a cancelable Exit on the leaving control before focus moves;
        // hold the focus commit until the veto is known (oxforms-esq.4).
        Some(losing_id) => begin_focus_validation(
            state,
            context,
            &losing_id,
            previous_focus.clone(),
            next_target.clone(),
            FocusTransferReason::Keyboard,
            false,
        ),
        // No control to veto (initial focus / from the form): commit synchronously.
        None => commit_focus_transfer(
            state,
            context,
            previous_focus.clone(),
            &next_target,
            &effect_target,
            FocusTransferReason::Keyboard,
        ),
    }
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

/// The focused, interactive CheckBox a keyboard toggle key activates: Space always,
/// or Enter when no default button consumes it. MSForms toggles such a CheckBox's
/// value and fires Change then Click BEFORE the KeyDown (value-first), so the caller
/// must run the toggle ahead of the KeyDown event (oxforms-esq.8).
///
/// Held-key (auto-repeat) toggle COUNT is captured (oxforms-esq.12): holding Space on a
/// focused CheckBox toggles it EXACTLY ONCE -- a 1.0s and a 2.5s hold produced the identical
/// single Change/Click (docs/evidence/W008_native_event_breadth/captures/
/// w008-held-key-20260628T213500Z/, `held_space_checkbox`). So an OS auto-repeat KeyDown
/// (`KeyRepeat.is_repeat`) must NOT re-toggle: only the first (non-repeat) KeyDown toggles.
/// Only the COUNT is consumed -- that held capture's intra-press ORDER diverges from esq.8's
/// value-first discrete-press order (it logged KeyDown -> KeyUp -> Change -> Click) and is
/// UNSETTLED; esq.8's value-first ordering (Change/Click before KeyDown) stands for discrete
/// presses and is what the toggle path below still emits. (The held default-button Enter is
/// uncaptured -- a button may auto-repeat its activation differently -- so that arm is left
/// repeat-blind, tracked by oxforms-esq.15.)
fn keyboard_toggle_check_box(state: &FormState, payload: &KeyEvent) -> Option<ControlId> {
    let control_id = state.focus_owner.as_ref()?.as_control_id()?;
    if !is_check_box_control(state, control_id) {
        return None;
    }
    // An OS auto-repeat (held key) does NOT re-toggle: MSForms toggles once per physical
    // press (oxforms-esq.12 held_space_checkbox). The repeat KeyDown still fires as an event
    // (that is not gated here); only the toggle is suppressed.
    if payload.repeat.is_repeat {
        return None;
    }
    // Only a bare keystroke toggles. The capture injected unmodified Space/Enter
    // (Shift=0, no Ctrl/Alt); a modifier-chorded Space/Enter stays inert (it still
    // emits KeyDown/KeyUp, as before esq.8) -- MSForms does not toggle a CheckBox on
    // a chorded key and the capture never exercises one (oxforms-esq.8). Lock states
    // (Caps/Num/Scroll) are not chords, so they do not gate the toggle.
    let modifiers = &payload.modifiers;
    if modifiers.shift || modifiers.control || modifiers.alt || modifiers.meta || modifiers.platform
    {
        return None;
    }
    match payload.key {
        KeyCode::Space => Some(control_id.clone()),
        KeyCode::Enter if state.default_button.is_none() => Some(control_id.clone()),
        _ => None,
    }
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

/// The focused, interactive TextBox a keyboard paste chord targets: Ctrl+V with no
/// other chord modifier (the capture recorded Shift=2, i.e. Ctrl only). The V KeyDown
/// routes to the clipboard paste path -- it requests the clipboard (ClipboardGet) and
/// the host folds the result back as a ClipboardResult, which fires
/// BeforeDropOrPaste(Paste) then Change AFTER the KeyDown (oracle order;
/// ctrlv-keyboard-ordering rows 2-7 -- oxforms-esq.9).
fn keyboard_paste_text_box(state: &FormState, payload: &KeyEvent) -> Option<ControlId> {
    let modifiers = &payload.modifiers;
    if !modifiers.control
        || modifiers.shift
        || modifiers.alt
        || modifiers.meta
        || modifiers.platform
    {
        return None;
    }
    let KeyCode::Character(character) = &payload.key else {
        return None;
    };
    if !character.eq_ignore_ascii_case("v") {
        return None;
    }
    focused_text_box_control_id(state)
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
    if state.keyboard.suppress_next_character_input {
        // The paired KeyDown swallowed the key (KeyCode -> 0, folded back as
        // KeyDownSwallowed): drop this character's KeyPress/Change and its insertion
        // (oxforms-esq.4). The keyboard swallow path is 1:1 -- one swallowed KeyDown arms
        // exactly the single character it would have produced (the platform delivers one
        // character per keystroke) -- so dropping the whole CharacterInput is correct.
        // Multi-character payloads (IME/composition) do not pair with a swallowed KeyDown
        // and are cleared off this flag by the intervening focus/KeyUp resets.
        state.keyboard.suppress_next_character_input = false;
        return;
    }
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

/// Request the clipboard for a keyboard Ctrl+V paste (oxforms-esq.9). The host folds
/// the result back as a `ClipboardResult`, which drives [`reduce_clipboard_result`]
/// (BeforeDropOrPaste(Paste) -> Change with the pasted text), the same fold-back idiom
/// the Exit/QueryClose readbacks use. No text is touched here -- the paste applies when
/// the result returns.
fn queue_clipboard_paste_request(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    control_id: &ControlId,
) {
    let target = UiEventTarget::control(state.form_id.0.clone(), control_id.0.clone());
    context.push_effect(
        state,
        target,
        EffectKind::ClipboardGet {
            request_id: format!("keyboard-paste-{}", context.event.event_id.0),
            formats: vec!["cf_unicode_text".to_string(), "text/plain".to_string()],
        },
        CompletionPolicy::ServiceResultRequired,
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

fn delete_text_box_backwards(text_box: &mut TextBoxState) {
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

fn delete_text_box_forwards(text_box: &mut TextBoxState) {
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

fn delete_selected_text(text_box: &mut TextBoxState) -> bool {
    let (start, end) = selected_range(&text_box.text, &text_box.caret);
    if start == end {
        collapse_text_box_caret(text_box, start);
        return false;
    }
    text_box.text.replace_range(start..end, "");
    collapse_text_box_caret(text_box, start);
    true
}

fn move_text_box_caret_left(text_box: &mut TextBoxState, extend_selection: bool) {
    if !extend_selection && text_box.caret.anchor != text_box.caret.active {
        let (start, _) = selected_range(&text_box.text, &text_box.caret);
        collapse_text_box_caret(text_box, start);
        return;
    }
    let active = clamp_to_char_boundary(&text_box.text, text_box.caret.active);
    let next = previous_char_boundary(&text_box.text, active);
    move_text_box_caret_to(text_box, next, extend_selection);
}

fn move_text_box_caret_right(text_box: &mut TextBoxState, extend_selection: bool) {
    if !extend_selection && text_box.caret.anchor != text_box.caret.active {
        let (_, end) = selected_range(&text_box.text, &text_box.caret);
        collapse_text_box_caret(text_box, end);
        return;
    }
    let active = clamp_to_char_boundary(&text_box.text, text_box.caret.active);
    let next = next_char_boundary(&text_box.text, active);
    move_text_box_caret_to(text_box, next, extend_selection);
}

fn move_text_box_caret_to(text_box: &mut TextBoxState, position: usize, extend_selection: bool) {
    let next = clamp_to_char_boundary(&text_box.text, position);
    if extend_selection {
        text_box.caret.anchor = clamp_to_char_boundary(&text_box.text, text_box.caret.anchor);
        text_box.caret.active = next;
    } else {
        collapse_text_box_caret(text_box, next);
    }
    text_box.caret.preferred_column = None;
}

fn collapse_text_box_caret(text_box: &mut TextBoxState, position: usize) {
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
                "KeyCode is the mutable MSForms.ReturnInteger helper (the by_ref KeyCode arg). For KeyDown the dispatching runtime applies the helper mutation and reads back the post-handler KeyCode via control.PerformKeyDown (oxforms-esq.2); folding that value back into reducer state, and KeyUp readback, remain deferred."
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
                    name: "KeyAscii".to_string(),
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
                "KeyAscii is the mutable MSForms.ReturnInteger value (the by_ref KeyAscii arg). The dispatching runtime applies the helper and reads back the post-handler KeyAscii via control.PerformKeyPress (oxforms-esq.2); folding it back into reducer state and IME composition remain deferred. The clean-room library spells it KeyAscii (MS Learn uses KeyANSI)."
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
                    // Shift is hardcoded 0 because the synthesized ClipboardResult carries
                    // no modifier context. The oracle ctrlv row 4 shows Shift=2 (Ctrl) for a
                    // keyboard Ctrl+V; threading the chord's fm20 shift through the clipboard
                    // round-trip is deferred to oxforms-esq.13 (the gap test asserts the
                    // event-NAME order only, so it does not pin this arg).
                    name: "Shift".to_string(),
                    value: "0".to_string(),
                    by_ref: false,
                },
            ],
            cancel_metadata: Some(
                "Text-only clipboard paste subset: Data is a serializable payload summary; live MSForms.DataObject, the Ctrl+V Shift=2 modifier context, rich formats, and Action mutation remain non-claims (oxforms-esq.13)."
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
            name: "Shift".to_string(),
            value: fm_shift_mask(payload.modifiers).to_string(),
            by_ref: false,
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
        // Dispatch-ready, mutable KeyCode: the VK is the MSForms KeyCode, modeled
        // as the by_ref MSForms.ReturnInteger helper value the runtime passes to
        // control.PerformKeyDown and reads back (oxforms-esq.2). Kept distinct from
        // the descriptive summary `key` arg above.
        arguments.push(EffectArgument {
            name: "KeyCode".to_string(),
            value: virtual_key.to_string(),
            by_ref: true,
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

/// The leaving control id when it both is a control and still exists -- i.e. when a
/// cancelable `Exit` must fire and gate the focus change (oxforms-esq.4). Returns `None`
/// for initial focus (`from` is `None`) or focus moving from the form itself, where there
/// is nothing to veto and the focus change commits synchronously.
fn focusable_losing_control(
    state: &FormState,
    previous_focus: &Option<FocusTarget>,
) -> Option<ControlId> {
    match previous_focus {
        Some(FocusTarget::Control(id)) if find_control(state, id).is_some() => Some(id.clone()),
        _ => None,
    }
}

/// Commit a focus transfer to `target`: record history, set the owner, and emit the
/// `TransferFocus` + `FocusChanged` repaint effects. Shared by the synchronous path
/// (nothing to veto) and the deferred commit ([`reduce_focus_validation_completed`]) once
/// a vetoable `Exit` has passed (oxforms-esq.4).
fn commit_focus_transfer(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    from: Option<FocusTarget>,
    target: &FocusTarget,
    effect_target: &UiEventTarget,
    reason: FocusTransferReason,
) {
    // A focus change abandons any armed key-swallow: a swallow only pairs with the same
    // control's immediately-following character (oxforms-esq.4).
    state.keyboard.suppress_next_character_input = false;
    state.focus_history.push(target.clone());
    state.focus_owner = Some(target.clone());
    context.push_effect(
        state,
        effect_target.clone(),
        EffectKind::TransferFocus {
            from,
            to: target.clone(),
            reason,
            validation_policy: ValidationPolicy::RequestCancelable,
        },
        CompletionPolicy::DispatchResultRequired,
    );
    // MSForms fires Enter on the gaining control after focus moves -- Exit (leaver) then
    // Enter (enterer) (oxforms-esq.6).
    queue_focus_enter_event(state, context, target);
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

/// Begin a cancelable focus change: fire `Exit` on the leaving control and record the
/// pending validation WITHOUT committing the focus owner. The commit is deferred to
/// [`reduce_focus_validation_completed`], driven by the runtime folding the `Exit`
/// handler's `Cancel` readback back as [`UiEventKind::FocusValidationCompleted`]
/// (oxforms-esq.4); a vetoing `Exit` (`Cancel = True`) therefore retains focus.
fn begin_focus_validation(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    losing_control_id: &ControlId,
    from: Option<FocusTarget>,
    to: FocusTarget,
    reason: FocusTransferReason,
    activate_on_commit: bool,
) {
    // Focus is leaving this control: abandon any armed key-swallow (it only pairs with
    // this control's immediately-following character) (oxforms-esq.4).
    state.keyboard.suppress_next_character_input = false;
    // Two-stage focus-out validation (oxforms-esq.11): a dirty data control fires
    // BeforeUpdate FIRST and waits on its Cancel before AfterUpdate/Exit; a clean control
    // skips straight to the Exit stage. AfterUpdate (the committed signal) + Exit fire on
    // the BeforeUpdate pass; esq.6's Enter + the deferred focus commit ride the Exit pass.
    let stage = if control_is_dirty(state, losing_control_id) {
        queue_before_update_event(state, context, losing_control_id);
        ValidationStage::BeforeUpdate
    } else {
        queue_focus_exit_event(state, context, losing_control_id);
        ValidationStage::Exit
    };
    state.validation.pending = Some(ValidationRequest {
        from,
        to: Some(to),
        cancelable: true,
        reason,
        activate_on_commit,
        stage,
    });
    state.validation.active = true;
}

/// Fold a focus-leaving validation handler's `Cancel` readback back into reducer state
/// (oxforms-esq.4/esq.11). Routes by the in-flight [`ValidationStage`]: a `BeforeUpdate`
/// completion gates the value commit, an `Exit` completion gates the focus move. The
/// runtime synthesizes this from the post-handler readback (for BOTH `BeforeUpdate` and
/// `Exit` dispatches), so the pure reducer never needs the live `Cancel` to progress;
/// mirrors [`reduce_query_close_completed`].
fn reduce_focus_validation_completed(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    payload: &FocusValidationCompletedEvent,
) {
    if payload.form_id != state.form_id {
        return;
    }
    let Some(request) = state.validation.pending.take() else {
        return;
    };
    match request.stage {
        ValidationStage::BeforeUpdate => {
            reduce_before_update_completed(state, context, request, payload.cancelled)
        }
        ValidationStage::Exit => reduce_exit_completed(state, context, request, payload.cancelled),
    }
}

/// Stage one of the two-stage focus-out validation: the dirty control's `BeforeUpdate`
/// `Cancel` came back (oxforms-esq.11). A veto suppresses everything past it -- no
/// `AfterUpdate`, `Exit`, `Enter`, or focus move -- keeps the value dirty (it was never
/// committed), and absorbs any deferred focus-changing press; focus stays on the leaving
/// control. A pass commits the value (`AfterUpdate` clears dirty), fires `Exit`, and
/// advances to the `Exit` stage (the deferred press + `validation.active` are carried
/// forward for the `Exit` completion). Oracle: [`docs/specs/FM20_EVENT_FACTS.md`] +
/// `W008.../before_update_veto` rows 28-30 (a vetoing BeforeUpdate suppresses
/// AfterUpdate/Exit/Enter, focus stays).
fn reduce_before_update_completed(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    request: ValidationRequest,
    cancelled: bool,
) {
    if cancelled {
        state.validation.active = false;
        // The value is NOT committed: leave the control dirty so a later focus-out refires
        // BeforeUpdate. Absorb any deferred focus-changing press (the click is eaten).
        state.pending_mouse_press = None;
        state.validation.last_result = Some(ValidationResult::Cancelled);
        return;
    }
    // BeforeUpdate passed: commit the value (AfterUpdate + clear dirty), then Exit. The
    // leaving control is the validation subject (`request.from`).
    if let Some(FocusTarget::Control(losing_id)) = request.from.as_ref() {
        let losing_id = losing_id.clone();
        queue_after_update_event(state, context, &losing_id);
        queue_focus_exit_event(state, context, &losing_id);
    }
    // Still in flight: advance to the Exit stage, keeping the deferred press and the
    // active flag for the Exit completion.
    state.validation.pending = Some(ValidationRequest {
        stage: ValidationStage::Exit,
        ..request
    });
}

/// Stage two of the focus-out validation: the `Exit` `Cancel` came back (oxforms-esq.4).
/// A veto retains focus on the leaving control and ABSORBS any focus-changing mouse press
/// -- a vetoing `Exit` eats the click entirely (no `MouseDown`/`MouseUp`/`Click` on the
/// clicked control). Oracle:
/// `docs/evidence/W008_native_event_breadth/captures/w008-veto-click-20260628T213100Z/`
/// `w008-veto-click-event-log.csv` -- `veto_exit_click` row 9 (TextBox1 `Exit` Cancel
/// False->True, focus stays, ZERO events on the clicked TextBox2) vs `nonveto_click_baseline`
/// rows 3-6 (Exit -> TextBox2 Enter -> MouseDown -> MouseUp). This
/// unifies with the keyboard default-button `Enter` whose `Click` rides `activate_on_commit`
/// (pass-only) and is likewise suppressed on a veto -- both are transfer consequences. A
/// pass runs the deferred [`commit_focus_transfer`] (+ the gaining control's `Enter`,
/// esq.6) and then replays the deferred press, so the order is `Exit -> Enter -> MouseDown`
/// (oxforms-esq.10).
fn reduce_exit_completed(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    request: ValidationRequest,
    cancelled: bool,
) {
    state.validation.active = false;
    // The deferred focus-changing press is cleared from state either way: dropped (absorbed)
    // on a veto, replayed after Enter on a pass. Keyboard validations set no pending press.
    let pending_press = state.pending_mouse_press.take();

    if cancelled {
        state.validation.last_result = Some(ValidationResult::Cancelled);
        return;
    }

    state.validation.last_result = Some(ValidationResult::Passed);
    if let Some(to) = request.to {
        if let Some(effect_target) = target_for_focus(&to, &state.form_id) {
            commit_focus_transfer(
                state,
                context,
                request.from,
                &to,
                &effect_target,
                request.reason,
            );
            // A default-button Enter transfers focus to the button and then fires its Click,
            // after the gaining control's Enter (oxforms-esq.6).
            if request.activate_on_commit {
                if let FocusTarget::Control(control_id) = &to {
                    activate_command_button(
                        state,
                        context,
                        control_id,
                        PressedOrigin::KeyboardDefault,
                    );
                }
            }
        }
    }
    // Replay the deferred press AFTER the gaining control's Enter: Exit -> Enter -> MouseDown
    // (oxforms-esq.10).
    if let Some(press) = pending_press {
        apply_mouse_press(state, context, &press);
    }
}

/// Fold a `KeyDown` handler's `KeyCode -> 0` swallow readback back into reducer state
/// (oxforms-esq.4): arm the keyboard to suppress the paired character. The next
/// `CharacterInput` consumes the flag and drops its `KeyPress`/`Change`. Synthesized by
/// the runtime from the post-handler readback (see [`UiEventKind::KeyDownSwallowed`]).
fn reduce_key_down_swallowed(state: &mut FormState, payload: &KeyDownSwallowedEvent) {
    if payload.form_id != state.form_id {
        return;
    }
    state.keyboard.suppress_next_character_input = true;
}

/// Emit the FM20 focus `Enter` event on the control gaining focus, after the transfer
/// commits (MSForms order: Exit on the leaver, then Enter on the enterer). `Enter` takes
/// no arguments and is not cancelable, so there is no readback (oxforms-esq.6). The form
/// itself has no `Enter`, so a `Form` focus target is a no-op.
fn queue_focus_enter_event(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    target: &FocusTarget,
) {
    let FocusTarget::Control(control_id) = target else {
        return;
    };
    let event_target = UiEventTarget::control(state.form_id.0.clone(), control_id.0.clone());
    context.push_effect(
        state,
        event_target,
        EffectKind::FireVbaEvent {
            event_name: "Enter".to_string(),
            fact_source: Some("docs/specs/FM20_EVENT_FACTS.md".to_string()),
            arguments: Vec::new(),
            cancel_metadata: None,
        },
        CompletionPolicy::DispatchResultRequired,
    );
}

/// Whether a focus-leaving control has an uncommitted edit (a dirty data control). This
/// gates the `BeforeUpdate`/`AfterUpdate` validation stage (oxforms-esq.7/esq.11): a dirty
/// control validates in two stages, a clean one fires only `Exit`.
///
/// Scope (oxforms-esq.7): `TextBox` only. A dirty CheckBox (or another committable data
/// control) losing focus does NOT yet count here -- there is no oracle for focus-out after
/// a CheckBox toggle, and the `dirty` gate is the sticky "edited-since" flag rather than
/// net-value-vs-baseline (an edit-then-revert still reads dirty). Both refinements (CheckBox
/// update events; an `OldValue` baseline) are tracked on oxforms-esq.14.
fn control_is_dirty(state: &FormState, control_id: &ControlId) -> bool {
    state
        .text_boxes
        .iter()
        .any(|entry| entry.control_id == *control_id && entry.dirty)
}

/// Emit the FM20 `BeforeUpdate` event on a dirty data control losing focus -- the FIRST of
/// the two-stage focus-out validation (oxforms-esq.11). MSForms fires this before `Exit`
/// on a committable focus-out (oxforms-esq.7). `BeforeUpdate` carries a mutable `Cancel`
/// (`ReturnBoolean`) read back via `PerformBeforeUpdate`; the runtime folds it back as
/// [`UiEventKind::FocusValidationCompleted`] (stage `BeforeUpdate`), where a veto suppresses
/// `AfterUpdate`/`Exit`/`Enter` + keeps focus and a pass advances to `AfterUpdate` + `Exit`
/// (see [`reduce_before_update_completed`]). The caller ([`begin_focus_validation`]) gates
/// this on [`control_is_dirty`].
fn queue_before_update_event(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    losing_control_id: &ControlId,
) {
    let target = UiEventTarget::control(state.form_id.0.clone(), losing_control_id.0.clone());
    context.push_effect(
        state,
        target,
        EffectKind::FireVbaEvent {
            event_name: "BeforeUpdate".to_string(),
            fact_source: Some("docs/specs/FM20_EVENT_FACTS.md".to_string()),
            arguments: vec![EffectArgument {
                name: "Cancel".to_string(),
                value: "False".to_string(),
                by_ref: true,
            }],
            cancel_metadata: Some(
                "BeforeUpdate Cancel is the mutable MSForms.ReturnBoolean helper; the dispatching runtime reads the post-handler value back via PerformBeforeUpdate (True = veto) and folds it back as FocusValidationCompleted (stage BeforeUpdate). A veto suppresses AfterUpdate/Exit/Enter and keeps the value dirty (oxforms-esq.11)."
                    .to_string(),
            ),
        },
        CompletionPolicy::DispatchResultRequired,
    );
}

/// Emit the FM20 `AfterUpdate` event on a control whose `BeforeUpdate` passed, and commit
/// the value by clearing the dirty flag -- the SECOND half of stage one (oxforms-esq.11).
/// `AfterUpdate` is the committed signal and is not cancelable (no readback). Clearing
/// dirty here -- only on a non-vetoing `BeforeUpdate` -- is what makes a vetoed
/// `BeforeUpdate` correctly keep the value dirty/uncommitted, and stops a later focus-out
/// without a fresh edit from refiring `BeforeUpdate`/`AfterUpdate`.
fn queue_after_update_event(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    losing_control_id: &ControlId,
) {
    let target = UiEventTarget::control(state.form_id.0.clone(), losing_control_id.0.clone());
    context.push_effect(
        state,
        target,
        EffectKind::FireVbaEvent {
            event_name: "AfterUpdate".to_string(),
            fact_source: Some("docs/specs/FM20_EVENT_FACTS.md".to_string()),
            arguments: Vec::new(),
            cancel_metadata: None,
        },
        CompletionPolicy::DispatchResultRequired,
    );
    if let Some(entry) = state
        .text_boxes
        .iter_mut()
        .find(|entry| entry.control_id == *losing_control_id)
    {
        entry.dirty = false;
    }
}

/// Emit the FM20 focus `Exit` event on the control losing focus, before the focus
/// transfer (MSForms order: Exit on the old control, then focus moves). Carries a
/// mutable `Cancel` modeled as the by_ref `ReturnBoolean` helper; the dispatching runtime
/// reads the post-handler value back via `PerformExit` and folds it back as
/// [`UiEventKind::FocusValidationCompleted`], so a veto is honored: the focus commit is
/// held pending in [`begin_focus_validation`] until then (oxforms-esq.4).
fn queue_focus_exit_event(
    state: &mut FormState,
    context: &mut ReducerContext<'_>,
    losing_control_id: &ControlId,
) {
    let target = UiEventTarget::control(state.form_id.0.clone(), losing_control_id.0.clone());
    context.push_effect(
        state,
        target,
        EffectKind::FireVbaEvent {
            event_name: "Exit".to_string(),
            fact_source: Some("docs/specs/FM20_EVENT_FACTS.md".to_string()),
            arguments: vec![EffectArgument {
                name: "Cancel".to_string(),
                value: "False".to_string(),
                by_ref: true,
            }],
            cancel_metadata: Some(
                "Exit Cancel is the mutable MSForms.ReturnBoolean helper (the by_ref Cancel arg). The dispatching runtime reads back the post-handler Cancel via control.PerformExit (oxforms-esq.2) and folds it back as FocusValidationCompleted (oxforms-esq.4): focus is held pending until then, so a veto (Cancel=True) retains focus on this control."
                    .to_string(),
            ),
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
        PumpFrameExitedEvent, RawCoordinateSample, RawDiagnostic, RawKeyDiagnostics,
        ServiceOutcome, ServicePayload, ServiceRequestId, ShowRequestedEvent, UiEventSource,
        UnloadedEvent, WindowHiddenEvent,
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
                "fire_vba_event:Enter",
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
                EffectId(5),
                EffectId(6)
            ]
        );
        assert_eq!(
            output.transition.invalidation_ids,
            vec![InvalidationId(1), InvalidationId(2)]
        );
        assert_eq!(output.transition.after.pending_effect_count, 6);
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
            vec![EffectId(7), EffectId(8), EffectId(9), EffectId(10)]
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

        // Tab off text-1 fires Exit on the losing control and holds the focus commit
        // pending the veto -- it does not commit synchronously (oxforms-esq.4).
        let tabbed = reduce(state, key_down_event(UiEventId(43), KeyCode::Tab, false));
        assert_eq!(
            tabbed.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("text-1"))),
            "focus stays on the leaving control until the Exit veto is known"
        );
        assert_eq!(
            effect_names(&tabbed.effects),
            vec!["fire_vba_event:KeyDown", "fire_vba_event:Exit"]
        );
        assert_eq!(
            tabbed.effects[1].target,
            UiEventTarget::control("form-main", "text-1")
        );
        let pending = tabbed
            .state
            .validation
            .pending
            .as_ref()
            .expect("Tab arms a pending focus validation");
        assert_eq!(pending.to, Some(FocusTarget::Control(ControlId::new("ok"))));

        // The Exit did not veto: the folded-back completion commits the deferred transfer.
        let committed = reduce(
            tabbed.state,
            focus_validation_completed_event(UiEventId(143), false),
        );
        assert_eq!(
            committed.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("ok")))
        );
        assert_eq!(
            effect_names(&committed.effects),
            vec!["transfer_focus", "fire_vba_event:Enter", "request_repaint"]
        );
        assert!(committed.state.validation.pending.is_none());

        // Shift+Tab back: same deferred shape, then the uncancelled completion returns
        // focus to text-1.
        let shift_tabbed = reduce(
            committed.state,
            key_down_event(UiEventId(44), KeyCode::Tab, true),
        );
        assert_eq!(
            shift_tabbed.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("ok"))),
            "focus is held pending until the completion"
        );
        let back = reduce(
            shift_tabbed.state,
            focus_validation_completed_event(UiEventId(144), false),
        );
        assert_eq!(
            back.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("text-1")))
        );
    }

    #[test]
    fn vetoed_focus_validation_keeps_focus_and_uncancelled_commits() {
        let mut state = FormState::new("form-main");
        state.controls = vec![
            ControlNode::text_box("text-1", LogicalRect::new(0.0, 0.0, 40.0, 18.0), 0, 0),
            ControlNode::command_button("ok", LogicalRect::new(0.0, 24.0, 40.0, 18.0), 0, 1),
        ];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));

        // Mouse-press OkButton: Exit fires on text-1 and the focus commit is held pending
        // the veto -- focus does not move and no transfer_focus is emitted yet.
        let pressed = reduce(
            state,
            UiEvent::new(
                UiEventId(70),
                UiEventSource::Replay,
                UiEventKind::MouseDown(mouse_button_event_at(true, 5.0, 30.0)),
            ),
        );
        assert_eq!(
            pressed.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("text-1")))
        );
        assert!(pressed.state.validation.pending.is_some());
        // esq.10: a focus-changing click also defers the press -- only Exit fires now
        // (no MouseDown/capture until the validation commits).
        assert!(pressed.state.pending_mouse_press.is_some());
        assert_eq!(effect_names(&pressed.effects), vec!["fire_vba_event:Exit"]);

        // A vetoing Exit (Cancel = True) keeps focus on text-1 and commits nothing.
        let vetoed = reduce(
            pressed.state.clone(),
            focus_validation_completed_event(UiEventId(71), true),
        );
        assert_eq!(
            vetoed.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("text-1")))
        );
        assert!(vetoed.state.validation.pending.is_none());
        assert_eq!(
            vetoed.state.validation.last_result,
            Some(ValidationResult::Cancelled)
        );
        // esq.11 (oracle: W008 w008-veto-click-20260628T213100Z, veto_exit_click row 9):
        // a vetoing Exit ABSORBS the focus-changing click -- focus stays, no Enter, and the
        // deferred press is dropped (NO MouseDown/capture). The clicked control fires nothing.
        assert_eq!(effect_names(&vetoed.effects), Vec::<String>::new());
        assert!(vetoed.state.pending_mouse_press.is_none());

        // From the same pending state, an un-vetoed completion commits the transfer to ok.
        let committed = reduce(
            pressed.state,
            focus_validation_completed_event(UiEventId(72), false),
        );
        assert_eq!(
            committed.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("ok")))
        );
        // esq.10: the deferred press replays AFTER the gaining control's Enter, so the
        // committed order is Exit (already fired) -> Enter -> MouseDown.
        assert_eq!(
            effect_names(&committed.effects),
            vec![
                "transfer_focus",
                "fire_vba_event:Enter",
                "request_repaint",
                "capture_mouse",
                "fire_vba_event:MouseDown",
                "request_repaint",
            ]
        );
        assert!(committed.state.pending_mouse_press.is_none());
        assert_eq!(
            committed.state.validation.last_result,
            Some(ValidationResult::Passed)
        );
    }

    #[test]
    fn dirty_focus_changing_click_carries_press_across_stages_then_exit_veto_absorbs() {
        // The cross-stage carry (oxforms-esq.11): a DIRTY control's focus-changing click
        // defers the mouse press, validates BeforeUpdate (stage 1), and on its PASS re-arms
        // at the Exit stage carrying the deferred press forward; a then-vetoing Exit must
        // DROP that carried press (absorb the click) and keep focus.
        let mut state = FormState::new("form-main");
        state.controls = vec![
            ControlNode::text_box("text-1", LogicalRect::new(0.0, 0.0, 40.0, 18.0), 0, 0),
            ControlNode::command_button("ok", LogicalRect::new(0.0, 24.0, 40.0, 18.0), 0, 1),
        ];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
        state.ensure_text_box(ControlId::new("text-1")).dirty = true;

        // Focus-changing press on ok off the dirty text-1: only BeforeUpdate fires; the
        // press is deferred and focus is held pending at the BeforeUpdate stage.
        let pressed = reduce(
            state,
            UiEvent::new(
                UiEventId(80),
                UiEventSource::Replay,
                UiEventKind::MouseDown(mouse_button_event_at(true, 5.0, 30.0)),
            ),
        );
        assert_eq!(
            effect_names(&pressed.effects),
            vec!["fire_vba_event:BeforeUpdate"]
        );
        assert_eq!(
            pressed
                .state
                .validation
                .pending
                .as_ref()
                .map(|request| request.stage),
            Some(ValidationStage::BeforeUpdate)
        );
        assert!(pressed.state.pending_mouse_press.is_some());
        assert_eq!(
            pressed.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("text-1")))
        );
        assert!(
            text_box_state(&pressed.state, &ControlId::new("text-1"))
                .expect("text-1 state")
                .dirty
        );

        // BeforeUpdate passes: AfterUpdate (clears dirty) + Exit fire; the validation re-arms
        // at the Exit stage and -- critically -- the deferred press survives the boundary.
        let after_before_update = reduce(
            pressed.state,
            focus_validation_completed_event(UiEventId(81), false),
        );
        assert_eq!(
            effect_names(&after_before_update.effects),
            vec!["fire_vba_event:AfterUpdate", "fire_vba_event:Exit"]
        );
        assert_eq!(
            after_before_update
                .state
                .validation
                .pending
                .as_ref()
                .map(|request| request.stage),
            Some(ValidationStage::Exit)
        );
        assert!(
            after_before_update.state.pending_mouse_press.is_some(),
            "the deferred press must survive the BeforeUpdate -> Exit stage boundary"
        );
        assert!(
            !text_box_state(&after_before_update.state, &ControlId::new("text-1"))
                .expect("text-1 state")
                .dirty
        );

        // The Exit then VETOES: focus stays on text-1, the carried press is DROPPED (absorb),
        // and nothing fires on the clicked control.
        let vetoed = reduce(
            after_before_update.state,
            focus_validation_completed_event(UiEventId(82), true),
        );
        assert_eq!(
            vetoed.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("text-1")))
        );
        assert_eq!(effect_names(&vetoed.effects), Vec::<String>::new());
        assert!(vetoed.state.pending_mouse_press.is_none());
        assert!(vetoed.state.validation.pending.is_none());
        assert_eq!(
            vetoed.state.validation.last_result,
            Some(ValidationResult::Cancelled)
        );
    }

    #[test]
    fn swallowed_keydown_suppresses_the_paired_character_input() {
        let mut state = FormState::new("form-main");
        state.controls = vec![ControlNode::text_box(
            "text-1",
            LogicalRect::new(0.0, 0.0, 80.0, 18.0),
            0,
            0,
        )];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
        state.ensure_text_box(ControlId::new("text-1"));

        // Fold back a swallowed KeyDown (KeyCode -> 0): arms the suppress flag.
        let swallowed = reduce(state, key_down_swallowed_event(UiEventId(80)));
        assert!(swallowed.state.keyboard.suppress_next_character_input);

        // The paired character is dropped: no insertion, no KeyPress/Change.
        let typed = reduce(
            swallowed.state,
            UiEvent::new(
                UiEventId(81),
                UiEventSource::Replay,
                UiEventKind::CharacterInput(CharacterInputEvent {
                    text: "A".to_string(),
                    modifiers: KeyboardModifiers::default(),
                    raw: Vec::new(),
                }),
            ),
        );
        assert!(typed.effects.is_empty());
        assert_eq!(
            text_box_state(&typed.state, &ControlId::new("text-1"))
                .map(|entry| entry.text.as_str()),
            Some("")
        );
        assert!(
            !typed.state.keyboard.suppress_next_character_input,
            "the swallow flag is consumed by the suppressed character"
        );

        // A subsequent un-swallowed character inserts normally.
        let typed2 = reduce(
            typed.state,
            UiEvent::new(
                UiEventId(82),
                UiEventSource::Replay,
                UiEventKind::CharacterInput(CharacterInputEvent {
                    text: "B".to_string(),
                    modifiers: KeyboardModifiers::default(),
                    raw: Vec::new(),
                }),
            ),
        );
        assert_eq!(
            effect_names(&typed2.effects),
            vec![
                "fire_vba_event:KeyPress",
                "fire_vba_event:Change",
                "request_repaint"
            ]
        );
        assert_eq!(
            text_box_state(&typed2.state, &ControlId::new("text-1"))
                .map(|entry| entry.text.as_str()),
            Some("B")
        );
    }

    #[test]
    fn focus_change_disarms_a_stale_key_swallow() {
        let mut state = FormState::new("form-main");
        state.controls = vec![
            ControlNode::text_box("text-1", LogicalRect::new(0.0, 0.0, 80.0, 18.0), 0, 0),
            ControlNode::text_box("text-2", LogicalRect::new(0.0, 24.0, 80.0, 18.0), 1, 1),
        ];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
        state.ensure_text_box(ControlId::new("text-1"));
        state.ensure_text_box(ControlId::new("text-2"));

        // Arm a swallow on text-1, then leave it via a MOUSE press on text-2 before the
        // paired character arrives. The mouse path does not clear the flag at KeyDown
        // entry, so a surviving flag would leak; begin_focus_validation must disarm it at
        // the focus boundary (oxforms-esq.4).
        let armed = reduce(state, key_down_swallowed_event(UiEventId(90)));
        assert!(armed.state.keyboard.suppress_next_character_input);

        let pressed = reduce(
            armed.state,
            UiEvent::new(
                UiEventId(91),
                UiEventSource::Replay,
                UiEventKind::MouseDown(mouse_button_event_at(true, 5.0, 30.0)),
            ),
        );
        assert!(
            !pressed.state.keyboard.suppress_next_character_input,
            "leaving the control disarms the stale swallow"
        );

        // After committing focus to text-2, a character there inserts normally -- the
        // stale swallow does not bleed across the focus change.
        let committed = reduce(
            pressed.state,
            focus_validation_completed_event(UiEventId(92), false),
        );
        assert_eq!(
            committed.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("text-2")))
        );
        let typed = reduce(
            committed.state,
            UiEvent::new(
                UiEventId(93),
                UiEventSource::Replay,
                UiEventKind::CharacterInput(CharacterInputEvent {
                    text: "Z".to_string(),
                    modifiers: KeyboardModifiers::default(),
                    raw: Vec::new(),
                }),
            ),
        );
        assert_eq!(
            text_box_state(&typed.state, &ControlId::new("text-2"))
                .map(|entry| entry.text.as_str()),
            Some("Z")
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

    fn focused_text_box_form() -> FormState {
        let mut state = FormState::new("form-main");
        state.controls = vec![ControlNode::text_box(
            "text-1",
            LogicalRect::new(0.0, 0.0, 80.0, 18.0),
            0,
            0,
        )];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
        state.ensure_text_box(ControlId::new("text-1"));
        state
    }

    fn ctrl_v_key_down(event_id: UiEventId, modifiers: KeyboardModifiers) -> UiEvent {
        UiEvent::new(
            event_id,
            UiEventSource::Replay,
            UiEventKind::KeyDown(oxforms_pal::KeyEvent {
                key: KeyCode::Character("v".to_string()),
                modifiers,
                repeat: KeyRepeat::default(),
                raw: RawKeyDiagnostics::default(),
            }),
        )
    }

    #[test]
    fn ctrl_v_keydown_requests_clipboard_then_pastes_on_the_folded_result() {
        // The V KeyDown fires first, then requests the clipboard (ClipboardGet); the
        // host folds the result back as a ClipboardResult that drives the existing paste
        // path (BeforeDropOrPaste -> Change), matching the oracle's V KeyDown ->
        // BeforeDropOrPaste -> Change order (ctrlv-keyboard-ordering -- oxforms-esq.9).
        let down = reduce(
            focused_text_box_form(),
            ctrl_v_key_down(
                UiEventId(70),
                KeyboardModifiers {
                    control: true,
                    ..KeyboardModifiers::default()
                },
            ),
        );
        assert_eq!(
            effect_names(&down.effects),
            vec!["fire_vba_event:KeyDown", "clipboard_get"]
        );
        // The paired KeyPress is suppressed -- a Ctrl chord carries no character.
        assert!(down.state.keyboard.suppress_next_character_input);

        // The request_id encodes the originating event id; the folded-back result paste
        // inserts the clipboard text and fires BeforeDropOrPaste -> Change.
        let pasted = reduce(
            down.state,
            clipboard_get_text_event(UiEventId(71), "keyboard-paste-70", "Seed", &["text/plain"]),
        );
        assert_eq!(
            effect_names(&pasted.effects),
            vec![
                "fire_vba_event:BeforeDropOrPaste",
                "fire_vba_event:Change",
                "request_repaint"
            ]
        );
        let text_box = pasted
            .state
            .text_boxes
            .iter()
            .find(|entry| entry.control_id == ControlId::new("text-1"))
            .expect("text box state");
        assert_eq!(text_box.text, "Seed");
    }

    #[test]
    fn non_bare_ctrl_v_and_plain_v_do_not_request_the_clipboard() {
        // Only a bare Ctrl+V on a focused TextBox pastes. A plain 'v' types normally, and
        // a chorded Ctrl+Shift+V / Ctrl+Alt+V is left to other handling (oxforms-esq.9).
        for modifiers in [
            KeyboardModifiers::default(),
            KeyboardModifiers {
                control: true,
                shift: true,
                ..KeyboardModifiers::default()
            },
            KeyboardModifiers {
                control: true,
                alt: true,
                ..KeyboardModifiers::default()
            },
        ] {
            let down = reduce(
                focused_text_box_form(),
                ctrl_v_key_down(UiEventId(73), modifiers),
            );
            assert_eq!(
                effect_names(&down.effects),
                vec!["fire_vba_event:KeyDown"],
                "{modifiers:?} must not request the clipboard"
            );
            assert!(!down.state.keyboard.suppress_next_character_input);
        }
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
    fn w005_probe_controls_route_input() {
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

        // Pressing the button moves focus off text-1: the commit is held pending the Exit
        // veto (oxforms-esq.4), so fold the uncancelled completion back to commit focus to
        // "ok" before the release, mirroring the runtime's foldback.
        let button_down = reduce(
            typed.state,
            UiEvent::new(
                UiEventId(64),
                UiEventSource::Replay,
                UiEventKind::MouseDown(mouse_button_event_at(true, 8.0, 52.0)),
            ),
        );
        assert_eq!(
            button_down.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("text-1"))),
            "focus is held on text-1 until the Exit veto resolves"
        );
        assert!(button_down.state.validation.pending.is_some());
        // text-1 is dirty (typed "A"), so the focus-out validates in two stages
        // (oxforms-esq.11): the BeforeUpdate-stage completion fires AfterUpdate/Exit and
        // stays pending (now at the Exit stage), focus still held on text-1.
        let after_before_update = reduce(
            button_down.state,
            focus_validation_completed_event(UiEventId(640), false),
        );
        assert_eq!(
            after_before_update.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("text-1"))),
            "focus stays on text-1 through the BeforeUpdate stage"
        );
        assert!(after_before_update.state.validation.pending.is_some());
        // The Exit-stage completion commits the transfer to "ok".
        let focus_committed = reduce(
            after_before_update.state,
            focus_validation_completed_event(UiEventId(641), false),
        );
        assert_eq!(
            focus_committed.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("ok")))
        );
        assert!(focus_committed.state.validation.pending.is_none());

        let button_up = reduce(
            focus_committed.state,
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
                "fire_vba_event:Enter",
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
        // Oracle-confirmed (oxforms-p41, capture checkbox-click-change-20260627T162407Z):
        // MSForms fires the value Change before Click (value-change-first), so the
        // toggle's Change + repaint precede the Click event.
        assert_eq!(
            effect_names(&up.effects),
            vec![
                "release_mouse",
                "fire_vba_event:MouseUp",
                "fire_vba_event:Change",
                "request_repaint",
                "fire_vba_event:Click",
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

    fn focused_check_box_form() -> FormState {
        let mut state = FormState::new("form-main");
        state.controls = vec![ControlNode::check_box(
            "agree",
            LogicalRect::new(0.0, 0.0, 96.0, 18.0),
            0,
            0,
        )];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("agree")));
        state.ensure_check_box(ControlId::new("agree"));
        state
    }

    #[test]
    fn checkbox_space_toggles_value_first_change_click_before_keydown() {
        // MSForms fires Change -> Click -> KeyDown -> KeyUp for a Space toggle, with the
        // value already flipped at KeyDown entry (checkbox-keyboard-toggle capture rows
        // 2-5 -- oxforms-esq.8).
        let down = reduce(
            focused_check_box_form(),
            key_down_event(UiEventId(82), KeyCode::Space, false),
        );
        assert_eq!(
            effect_names(&down.effects),
            vec![
                "fire_vba_event:Change",
                "request_repaint",
                "fire_vba_event:Click",
                "fire_vba_event:KeyDown",
            ]
        );
        assert_eq!(
            check_box_state(&down.state, &ControlId::new("agree")).map(|entry| entry.checked),
            Some(true)
        );

        let up = reduce(down.state, key_up_event(UiEventId(83), KeyCode::Space));
        assert_eq!(effect_names(&up.effects), vec!["fire_vba_event:KeyUp"]);
        // The value stays toggled across the KeyUp (value_at_keyup: True).
        assert_eq!(
            check_box_state(&up.state, &ControlId::new("agree")).map(|entry| entry.checked),
            Some(true)
        );
    }

    #[test]
    fn checkbox_enter_toggles_when_no_default_button_consumes_it() {
        // Enter on a focused CheckBox toggles it the same way as Space when there is no
        // default button to take the Enter (checkbox-keyboard-toggle capture rows 6-9).
        let down = reduce(
            focused_check_box_form(),
            key_down_event(UiEventId(90), KeyCode::Enter, false),
        );
        assert_eq!(
            effect_names(&down.effects),
            vec![
                "fire_vba_event:Change",
                "request_repaint",
                "fire_vba_event:Click",
                "fire_vba_event:KeyDown",
            ]
        );
        assert_eq!(
            check_box_state(&down.state, &ControlId::new("agree")).map(|entry| entry.checked),
            Some(true)
        );
    }

    #[test]
    fn checkbox_modifier_chorded_space_and_enter_do_not_toggle() {
        // The capture injected unmodified Space/Enter only; a modifier-chorded key on a
        // focused CheckBox stays inert (KeyDown/KeyUp, no value change) -- esq.8 must not
        // extrapolate toggle-on-chord past the oracle.
        for modifiers in [
            KeyboardModifiers {
                control: true,
                ..KeyboardModifiers::default()
            },
            KeyboardModifiers {
                shift: true,
                ..KeyboardModifiers::default()
            },
            KeyboardModifiers {
                alt: true,
                ..KeyboardModifiers::default()
            },
        ] {
            for key in [KeyCode::Space, KeyCode::Enter] {
                let output = reduce(
                    focused_check_box_form(),
                    UiEvent::new(
                        UiEventId(99),
                        UiEventSource::Replay,
                        UiEventKind::KeyDown(oxforms_pal::KeyEvent {
                            key: key.clone(),
                            modifiers,
                            repeat: KeyRepeat::default(),
                            raw: RawKeyDiagnostics::default(),
                        }),
                    ),
                );
                assert_eq!(
                    effect_names(&output.effects),
                    vec!["fire_vba_event:KeyDown"],
                    "chorded {key:?} with {modifiers:?} must emit only KeyDown, no toggle"
                );
                assert_eq!(
                    check_box_state(&output.state, &ControlId::new("agree"))
                        .map(|entry| entry.checked),
                    Some(false)
                );
            }
        }
    }

    #[test]
    fn checkbox_held_space_auto_repeat_does_not_re_toggle() {
        // Held Space toggles a focused CheckBox EXACTLY ONCE: the first (non-repeat) KeyDown
        // flips the value (Change/Click), and OS auto-repeat KeyDowns (KeyRepeat.is_repeat)
        // must NOT re-toggle -- the repeat KeyDown still fires as an event but the value and
        // Change/Click do not multiply (oxforms-esq.12 oracle w008-held-key held_space_checkbox:
        // a 1.0s and a 2.5s hold produced the identical single Change/Click).
        let first = reduce(
            focused_check_box_form(),
            key_down_event(UiEventId(120), KeyCode::Space, false),
        );
        assert_eq!(
            check_box_state(&first.state, &ControlId::new("agree")).map(|entry| entry.checked),
            Some(true),
            "the first Space KeyDown toggles the value"
        );

        // An auto-repeat Space KeyDown: only KeyDown fires, no second Change/Click, value held.
        let repeated = reduce(
            first.state,
            UiEvent::new(
                UiEventId(121),
                UiEventSource::Replay,
                UiEventKind::KeyDown(oxforms_pal::KeyEvent {
                    key: KeyCode::Space,
                    modifiers: KeyboardModifiers::default(),
                    repeat: KeyRepeat {
                        is_repeat: true,
                        repeat_count: Some(1),
                    },
                    raw: RawKeyDiagnostics::default(),
                }),
            ),
        );
        assert_eq!(
            effect_names(&repeated.effects),
            vec!["fire_vba_event:KeyDown"],
            "an auto-repeat Space emits only KeyDown -- no re-toggle (no Change/Click)"
        );
        assert_eq!(
            check_box_state(&repeated.state, &ControlId::new("agree")).map(|entry| entry.checked),
            Some(true),
            "the value stays toggled once across the held-key auto-repeat"
        );
    }

    #[test]
    fn checkbox_enter_defers_to_a_default_button_instead_of_toggling() {
        // When a default button claims Enter, the focused CheckBox is NOT toggled; the
        // default-button activation path (oxforms-esq.6) owns the keystroke. The
        // checkbox-keyboard-toggle capture had no default button, so this composes the
        // esq.6 default-button-Enter fact with the esq.8 toggle gate rather than being
        // constrained by that capture directly.
        let mut state = focused_check_box_form();
        state.controls.push(ControlNode::command_button(
            "ok",
            LogicalRect::new(0.0, 24.0, 80.0, 18.0),
            1,
            1,
        ));
        state.default_button = Some(ControlId::new("ok"));

        let down = reduce(state, key_down_event(UiEventId(91), KeyCode::Enter, false));
        // No Change/Click on the CheckBox; the value is untouched.
        assert_eq!(
            check_box_state(&down.state, &ControlId::new("agree")).map(|entry| entry.checked),
            Some(false)
        );
        assert!(
            !effect_names(&down.effects)
                .iter()
                .any(|name| name == "fire_vba_event:Change"),
            "a default-button Enter must not toggle the focused CheckBox"
        );
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
    fn pump_frame_exited_tracks_two_level_nested_modal_depth() {
        // Enter two nested modal frames, then exit them; depth must follow the
        // reducer's own tracked state, not the payload (oxforms-mau).
        let mut state = FormState::new("form-main");
        for id in [30u64, 31u64] {
            state = reduce(
                state,
                UiEvent {
                    target: UiEventTarget::form("form-main"),
                    ..UiEvent::new(
                        UiEventId(id),
                        UiEventSource::Replay,
                        UiEventKind::ShowRequested(ShowRequestedEvent {
                            form_id: FormId::new("form-main"),
                            show_mode: ShowMode::Modal,
                            owner: None,
                            initial_bounds: None,
                            reason: LifecycleReason::Replay,
                        }),
                    )
                },
            )
            .state;
        }
        assert_eq!(state.pump.nested_modal_depth, 2);
        assert_eq!(state.pump.term, PumpTerm::ModalFrame);

        // Exit the inner frame: depth 2 -> 1, still inside a modal frame.
        let inner_exit = reduce(
            state,
            UiEvent::new(
                UiEventId(32),
                UiEventSource::Replay,
                UiEventKind::PumpFrameExited(PumpFrameExitedEvent {
                    modal_depth: 2,
                    exit_reason: "inner exit".to_string(),
                }),
            ),
        );
        assert_eq!(inner_exit.state.pump.nested_modal_depth, 1);
        assert_eq!(inner_exit.state.pump.term, PumpTerm::ModalFrame);
        let inner_effect = inner_exit
            .effects
            .iter()
            .find_map(|effect| match &effect.kind {
                EffectKind::ExitModalFrame {
                    modal_depth,
                    reason,
                } => Some((*modal_depth, reason.clone())),
                _ => None,
            })
            .expect("exit_modal_frame effect");
        // payload matched tracked depth -> exit carries tracked depth, reason verbatim.
        assert_eq!(inner_effect.0, 2);
        assert_eq!(inner_effect.1, "inner exit");

        // Exit the outer frame: depth 1 -> 0, back to the host modeless pump.
        let outer_exit = reduce(
            inner_exit.state,
            UiEvent::new(
                UiEventId(33),
                UiEventSource::Replay,
                UiEventKind::PumpFrameExited(PumpFrameExitedEvent {
                    modal_depth: 1,
                    exit_reason: "outer exit".to_string(),
                }),
            ),
        );
        assert_eq!(outer_exit.state.pump.nested_modal_depth, 0);
        assert_eq!(outer_exit.state.pump.term, PumpTerm::HostModelessPump);
    }

    #[test]
    fn pump_frame_exited_derives_depth_from_tracked_state_on_payload_mismatch() {
        // A single modal frame is active (tracked depth 1).
        let shown = reduce(
            FormState::new("form-main"),
            UiEvent {
                target: UiEventTarget::form("form-main"),
                ..UiEvent::new(
                    UiEventId(40),
                    UiEventSource::Replay,
                    UiEventKind::ShowRequested(ShowRequestedEvent {
                        form_id: FormId::new("form-main"),
                        show_mode: ShowMode::Modal,
                        owner: None,
                        initial_bounds: None,
                        reason: LifecycleReason::Replay,
                    }),
                )
            },
        );
        assert_eq!(shown.state.pump.nested_modal_depth, 1);

        // A stale / off-by-one payload claims depth 5. Tracked state wins: depth
        // drops 1 -> 0 and the mismatch is recorded on the exit reason rather than
        // silently desyncing nested modal tracking (oxforms-mau).
        let exited = reduce(
            shown.state,
            UiEvent::new(
                UiEventId(41),
                UiEventSource::Replay,
                UiEventKind::PumpFrameExited(PumpFrameExitedEvent {
                    modal_depth: 5,
                    exit_reason: "stale exit".to_string(),
                }),
            ),
        );
        assert_eq!(exited.state.pump.nested_modal_depth, 0);
        assert_eq!(exited.state.pump.term, PumpTerm::HostModelessPump);
        let (modal_depth, reason) = exited
            .effects
            .iter()
            .find_map(|effect| match &effect.kind {
                EffectKind::ExitModalFrame {
                    modal_depth,
                    reason,
                } => Some((*modal_depth, reason.clone())),
                _ => None,
            })
            .expect("exit_modal_frame effect");
        assert_eq!(
            modal_depth, 1,
            "exit depth is derived from tracked state, not the payload"
        );
        assert!(
            reason.contains("cross-check mismatch")
                && reason.contains("payload=5")
                && reason.contains("tracked=1"),
            "exit reason must record the payload/tracked mismatch: {reason}"
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

        assert_eq!(rows.len(), 9);
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

        // A default-button Enter transfers focus to the button: KeyDown then Exit on the
        // text box, with the commit (and the button's Click) held pending the veto
        // (oxforms-esq.6 on the esq.4 deferred-focus model).
        let down = reduce(state, key_down_event(UiEventId(52), KeyCode::Enter, false));
        assert_eq!(
            effect_names(&down.effects),
            vec!["fire_vba_event:KeyDown", "fire_vba_event:Exit"]
        );
        assert_eq!(
            down.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("text-1"))),
            "focus is held pending the Exit veto"
        );

        // The Exit did not veto: focus commits to ok (Enter on the gaining button) and
        // then the button is Clicked -- KeyDown, Exit, Enter, Click matches the oracle
        // default_button_enter ordering.
        let committed = reduce(
            down.state,
            focus_validation_completed_event(UiEventId(152), false),
        );
        assert_eq!(
            committed.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("ok")))
        );
        assert_eq!(
            effect_names(&committed.effects),
            vec![
                "transfer_focus",
                "fire_vba_event:Enter",
                "request_repaint",
                "fire_vba_event:Click",
                "request_repaint"
            ]
        );
        assert_eq!(
            committed
                .state
                .pressed_state
                .as_ref()
                .map(|pressed| pressed.origin),
            Some(PressedOrigin::KeyboardDefault)
        );
        let click = committed
            .effects
            .iter()
            .find(|effect| {
                matches!(&effect.kind, EffectKind::FireVbaEvent { event_name, .. } if event_name == "Click")
            })
            .expect("Click effect");
        assert_eq!(click.target, UiEventTarget::control("form-main", "ok"));

        let up = reduce(committed.state, key_up_event(UiEventId(53), KeyCode::Enter));
        assert_eq!(
            effect_names(&up.effects),
            vec!["fire_vba_event:KeyUp", "request_repaint"]
        );
        assert!(up.state.pressed_state.is_none());
    }

    #[test]
    fn disabled_default_button_enter_does_not_transfer_focus() {
        let mut state = FormState::new("form-main");
        state.controls = vec![
            ControlNode::text_box("text-1", LogicalRect::new(0.0, 0.0, 80.0, 18.0), 0, 0),
            ControlNode::command_button("ok", LogicalRect::new(0.0, 24.0, 64.0, 20.0), 0, 1)
                .disabled(),
        ];
        state.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
        state.default_button = Some(ControlId::new("ok"));

        // A non-activatable (disabled) default button does not activate on Enter: no Exit,
        // no focus transfer, no Click -- only the KeyDown fires and focus stays put
        // (oxforms-esq.6).
        let down = reduce(state, key_down_event(UiEventId(56), KeyCode::Enter, false));
        assert_eq!(effect_names(&down.effects), vec!["fire_vba_event:KeyDown"]);
        assert_eq!(
            down.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("text-1")))
        );
        assert!(down.state.validation.pending.is_none());
    }

    #[test]
    fn dirty_focus_out_fires_before_update_after_update_before_exit() {
        let controls = || {
            vec![
                ControlNode::text_box("text-1", LogicalRect::new(0.0, 0.0, 80.0, 18.0), 0, 0),
                ControlNode::text_box("text-2", LogicalRect::new(0.0, 24.0, 80.0, 18.0), 1, 1),
            ]
        };

        // A dirty (edited) data control validates in TWO stages (oxforms-esq.11): the Tab
        // fires only KeyDown -> BeforeUpdate; the BeforeUpdate-stage completion then fires
        // AfterUpdate -> Exit; the Exit-stage completion fires Enter on the deferred commit.
        let mut dirty = FormState::new("form-main");
        dirty.controls = controls();
        dirty.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
        dirty.ensure_text_box(ControlId::new("text-1")).dirty = true;
        let tab = reduce(dirty, key_down_event(UiEventId(57), KeyCode::Tab, false));
        assert_eq!(
            effect_names(&tab.effects),
            vec!["fire_vba_event:KeyDown", "fire_vba_event:BeforeUpdate"]
        );
        // The value is NOT committed until AfterUpdate, so it stays dirty across stage one.
        assert!(
            text_box_state(&tab.state, &ControlId::new("text-1"))
                .expect("text-1 state")
                .dirty
        );

        // BeforeUpdate passes: AfterUpdate (commits + clears dirty) then Exit fire next.
        let after_before_update = reduce(
            tab.state,
            focus_validation_completed_event(UiEventId(157), false),
        );
        assert_eq!(
            effect_names(&after_before_update.effects),
            vec!["fire_vba_event:AfterUpdate", "fire_vba_event:Exit"]
        );
        assert!(
            !text_box_state(&after_before_update.state, &ControlId::new("text-1"))
                .expect("text-1 state")
                .dirty,
            "AfterUpdate committed the value: dirty is cleared so a later focus-out does not refire"
        );

        // Exit passes: the deferred commit fires Enter and moves focus to text-2.
        let committed = reduce(
            after_before_update.state,
            focus_validation_completed_event(UiEventId(257), false),
        );
        assert_eq!(
            effect_names(&committed.effects),
            vec!["transfer_focus", "fire_vba_event:Enter", "request_repaint"]
        );
        assert_eq!(
            committed.state.focus_owner,
            Some(FocusTarget::Control(ControlId::new("text-2")))
        );

        // A clean (unedited) control fires only Exit on focus-out -- no BeforeUpdate/
        // AfterUpdate.
        let mut clean = FormState::new("form-main");
        clean.controls = controls();
        clean.focus_owner = Some(FocusTarget::Control(ControlId::new("text-1")));
        let tab_clean = reduce(clean, key_down_event(UiEventId(58), KeyCode::Tab, false));
        assert_eq!(
            effect_names(&tab_clean.effects),
            vec!["fire_vba_event:KeyDown", "fire_vba_event:Exit"]
        );
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

    fn focus_validation_completed_event(event_id: UiEventId, cancelled: bool) -> UiEvent {
        UiEvent::new(
            event_id,
            UiEventSource::Service,
            UiEventKind::FocusValidationCompleted(FocusValidationCompletedEvent {
                form_id: FormId::new("form-main"),
                cancelled,
                dispatch_diagnostics: Vec::new(),
            }),
        )
    }

    fn key_down_swallowed_event(event_id: UiEventId) -> UiEvent {
        UiEvent::new(
            event_id,
            UiEventSource::Service,
            UiEventKind::KeyDownSwallowed(KeyDownSwallowedEvent {
                form_id: FormId::new("form-main"),
                dispatch_diagnostics: Vec::new(),
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
