//! W007 runtime / effect runner.
//!
//! The durable OxForms runtime layer that sits between PAL/window events and an
//! OxVba session. Per frame it: reduces a normalized [`UiEvent`] through
//! `oxforms-core` (`reduce`), drains the resulting effects, dispatches each
//! `FireVbaEvent` by calling the control's **native** OxVba member
//! (`PerformClick`, `ApplyUserText`, …), reads back any VBA-set properties and
//! folds them into reducer state through the reducer-owned
//! [`oxforms_core::sync_control_display_text`], requests repaints, and records
//! trace rows.
//!
//! It deliberately does **not** use the W005 generic [`crate::event_dispatch`]
//! `RaiseDispatch` carrier (that is a smoke shape), and it never mutates
//! `FormState` fields directly — all state writes go through the reducer or the
//! reducer-owned sync. A missing control object, a missing control target, or a
//! malformed return value surfaces as a precise [`RuntimeError`], never a silent
//! no-op.
//!
//! Scope: handler-backed events are natively dispatched — `Click` → `PerformClick`,
//! `Change` → `ApplyUserText`, `KeyDown`/`KeyUp` → `PerformKeyDown`/`PerformKeyUp`
//! and `KeyPress` → `PerformKeyPress` (with the `MSForms.ReturnInteger` KeyCode/
//! KeyAscii readback), `MouseDown`/`MouseUp` → `PerformMouseDown`/`PerformMouseUp`,
//! focus `[Exit]` → `PerformExit` (with the `MSForms.ReturnBoolean` Cancel readback),
//! and the form-level events `QueryClose` → `PerformQueryClose` (with the Cancel
//! readback) and `Initialize`/`Activate`/`Deactivate`/`Terminate` → the matching form
//! `Perform*` (oxforms-esq.2). The remaining reducer-routed FM20 events (e.g.
//! `MouseMove`, or a mouse press on the form background) are still *acknowledged* in
//! the trace ([`RuntimeTraceRow::EventAcknowledged`]) but not natively dispatched yet.
//! This is an explicit, traced non-claim — never a silent default.

use std::collections::{HashMap, VecDeque};

use oxforms_core::{
    reduce, sync_control_display_text, EffectKind, EffectRequest, RenderInvalidation, RuntimeForm,
    ValidationStage,
};
use oxforms_pal::{
    BeforeDropOrPasteCompletedEvent, ClipboardOperation, ClipboardResultEvent, ControlId,
    FocusValidationCompletedEvent, KeyDownSwallowedEvent, QueryCloseCompletedEvent, ServiceOutcome,
    ServicePayload, ServiceRequestId, UiEvent, UiEventId, UiEventKind, UiEventSource,
};
use oxvba_bundle::ProjectMemberKind;
use oxvba_host::ProjectRuntimeSession;
use oxvba_runtime::{ObjectRef, Variant};

/// Upper bound on readback fold-back re-entry per dispatch (see
/// [`RuntimeRunner::dispatch_with_foldback`]). The modeled fold-back paths re-enter at
/// most once; the bound is a defensive guard against a future fold-back cycle.
const MAX_FOLDBACK_ITERATIONS: u32 = 16;

/// A precise runtime failure; never a silent state mutation side channel.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RuntimeError {
    /// An OxVba member invocation failed.
    Invoke { member: String, message: String },
    /// `create_class_instance` failed for the form class.
    CreateForm { class_name: String, message: String },
    /// A member returned a value of an unexpected shape.
    UnexpectedReturn { member: String, detail: String },
    /// A `FireVbaEvent` targeted a control with no materialized binding / VBA object.
    UnknownControl(String),
    /// A `FireVbaEvent` had no control target.
    MissingControlTarget { event_name: String },
    /// A `Change` targeted a control with no text-box state to source the value from.
    MissingTextForChange(String),
    /// Dispatch readback fold-back re-entered the reducer past the iteration bound — a
    /// runaway-loop guard, never expected to trigger for the modeled fold-back paths.
    FoldbackOverflow { iterations: u32 },
}

impl std::fmt::Display for RuntimeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Invoke { member, message } => {
                write!(f, "OxVba invoke `{member}` failed: {message}")
            }
            Self::CreateForm {
                class_name,
                message,
            } => write!(f, "create form class `{class_name}` failed: {message}"),
            Self::UnexpectedReturn { member, detail } => {
                write!(
                    f,
                    "OxVba member `{member}` returned an unexpected value: {detail}"
                )
            }
            Self::UnknownControl(id) => write!(f, "no VBA object bound for control `{id}`"),
            Self::MissingControlTarget { event_name } => {
                write!(f, "FireVbaEvent `{event_name}` has no control target")
            }
            Self::MissingTextForChange(id) => {
                write!(
                    f,
                    "Change for control `{id}` has no text-box state to dispatch"
                )
            }
            Self::FoldbackOverflow { iterations } => {
                write!(
                    f,
                    "dispatch readback fold-back re-entered the reducer {iterations} times (runaway loop)"
                )
            }
        }
    }
}

impl std::error::Error for RuntimeError {}

/// Completion status of a native dispatch. Only `Succeeded` is emitted today: a
/// failed native invoke aborts the step with a precise [`RuntimeError`] rather than
/// recording a completion. A cancelable `Exit` dispatches and its post-handler Cancel is
/// read back into [`NativeDispatchRecord::returned`]; that readback is now folded back as
/// [`UiEventKind::FocusValidationCompleted`] so a veto is honored (focus is held pending
/// until then and retained on veto — oxforms-esq.4), not just recorded.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum DispatchCompletion {
    Succeeded,
}

/// A native OxVba member call made to execute one reducer `FireVbaEvent`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct NativeDispatchRecord {
    pub control_id: ControlId,
    pub event_name: String,
    pub native_member: String,
    pub completion: DispatchCompletion,
    /// Post-handler return value, if the native member returns one.
    pub returned: Option<String>,
}

/// One VBA-originated property folded back into reducer state.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PropertySyncRecord {
    pub control_id: ControlId,
    pub property: String,
    pub value: String,
}

/// A trace row for the W007 runtime path (enough to diagnose the demo).
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RuntimeTraceRow {
    EffectDrained {
        effect_id: u64,
        kind: String,
        target: Option<String>,
    },
    NativeDispatch {
        dispatch_id: u64,
        control_id: String,
        event_name: String,
        native_member: String,
        completion: DispatchCompletion,
        returned: Option<String>,
    },
    PropertySync {
        control_id: String,
        property: String,
        value: String,
    },
    RepaintRequested {
        reason: String,
        invalidation_ids: Vec<u64>,
    },
    /// A reducer-routed FM20 event not yet natively dispatched (e.g. `MouseMove`), or
    /// a mouse press on the form background. Recorded, never silently dropped; the
    /// remaining native event dispatch is a later slice.
    EventAcknowledged {
        event_name: String,
        target: Option<String>,
    },
    /// A control's VBA `Core.Dirty` was set but its `DisplayText` was unchanged — a
    /// non-text property change (geometry/visible/enabled/colors) the W007 slice does
    /// not reconcile yet. Recorded (never silently dropped) before the dirty flag is
    /// consumed; non-text property sync is a later slice.
    PropertyDirtyDeferred { control_id: String },
}

/// The result of dispatching one [`UiEvent`] through the runner.
#[derive(Clone, Debug, Default)]
pub struct RuntimeStep {
    pub repaint_requested: bool,
    pub native_dispatches: Vec<NativeDispatchRecord>,
    pub property_syncs: Vec<PropertySyncRecord>,
    pub invalidations: Vec<RenderInvalidation>,
    pub trace: Vec<RuntimeTraceRow>,
}

/// The runtime/effect runner: owns the OxVba session + the reducer state and bridges
/// the two.
pub struct RuntimeRunner {
    session: ProjectRuntimeSession,
    form: RuntimeForm,
    /// The `UserForm` object — the runtime's Re-render target (`render_frame`).
    user_form: ObjectRef,
    /// The form-document object (the form class hosting the `UserForm_*` handlers and
    /// the form-level `Perform*` dispatch surface) — the target for form-level events.
    form_module: ObjectRef,
    /// VBA object per control (for native member calls), keyed by reducer identity.
    control_objects: HashMap<ControlId, ObjectRef>,
    /// The control's `OxControlCore` object (for Dirty/DisplayText/ClearDirty).
    core_objects: HashMap<ControlId, ObjectRef>,
    /// A host-seeded clipboard override (oxforms-esq.9). When `Some`, a `ClipboardGet` folds
    /// back this text REGARDLESS of the live OS clipboard -- the deterministic test seed.
    clipboard_text: Option<String>,
    /// The live OS clipboard reader (oxforms-esq.16). When no `clipboard_text` seed is set, a
    /// `ClipboardGet` calls this to read the real clipboard. `None` (the default) means no
    /// live reader is wired -- a `ClipboardGet` then folds back nothing (a no-op paste), which
    /// keeps the headless floor deterministic; the desktop bootstrap injects
    /// `oxforms_pal_win::read_clipboard_text` via [`Self::set_clipboard_reader`].
    clipboard_reader: Option<Box<dyn Fn() -> Option<String>>>,
    dispatch_seq: u64,
    trace: Vec<RuntimeTraceRow>,
}

impl RuntimeRunner {
    /// Attach to a prepared OxVba session: create the form instance, build it, and
    /// resolve each materialized control's VBA object + `OxControlCore`. The form
    /// class must build controls whose `Name`s match the materialized `RuntimeForm`
    /// (the binding identity established in oxforms-4pn.4).
    pub fn attach(
        mut session: ProjectRuntimeSession,
        form: RuntimeForm,
        form_class_name: &str,
        build_member: &str,
        form_accessor: &str,
    ) -> Result<Self, RuntimeError> {
        let form_object = session
            .create_class_instance(form_class_name)
            .map_err(|err| RuntimeError::CreateForm {
                class_name: form_class_name.to_string(),
                message: err.message().to_string(),
            })?;

        invoke(
            &mut session,
            form_object.clone(),
            build_member,
            ProjectMemberKind::Method,
            Vec::new(),
        )?;

        let user_form = invoke_object(
            &mut session,
            form_object.clone(),
            form_accessor,
            ProjectMemberKind::PropertyGet,
            Vec::new(),
        )?;

        let mut control_objects = HashMap::new();
        let mut core_objects = HashMap::new();
        for binding in &form.controls {
            let control = invoke_object(
                &mut session,
                user_form.clone(),
                "ControlByName",
                ProjectMemberKind::Method,
                vec![Variant::from_string(binding.name.clone())],
            )?;
            let core = invoke_object(
                &mut session,
                control.clone(),
                "Core",
                ProjectMemberKind::PropertyGet,
                Vec::new(),
            )?;
            control_objects.insert(binding.control_id.clone(), control);
            core_objects.insert(binding.control_id.clone(), core);
        }

        Ok(Self {
            session,
            form,
            user_form,
            form_module: form_object,
            control_objects,
            core_objects,
            clipboard_text: None,
            clipboard_reader: None,
            dispatch_seq: 0,
            trace: Vec::new(),
        })
    }

    /// Seed the clipboard text a keyboard Ctrl+V paste reads (oxforms-esq.9). A deterministic
    /// test/host override: when set it takes precedence over any live reader, so the headless
    /// floor never touches the OS clipboard.
    pub fn set_clipboard_text(&mut self, text: impl Into<String>) {
        self.clipboard_text = Some(text.into());
    }

    /// Wire a live OS clipboard reader (oxforms-esq.16). When no `set_clipboard_text` seed is
    /// set, a keyboard Ctrl+V `ClipboardGet` calls this to read the real clipboard; `None`
    /// (the read returns nothing) is folded back as a no-op paste, which the reducer already
    /// handles. The desktop bootstrap injects `oxforms_pal_win::read_clipboard_text`; headless
    /// tests leave it unset so the deterministic floor never performs platform I/O.
    pub fn set_clipboard_reader(&mut self, reader: impl Fn() -> Option<String> + 'static) {
        self.clipboard_reader = Some(Box::new(reader));
    }

    /// Invoke a no-argument `Sub` on the attached form-document module (the class hosting
    /// the `UserForm_*` handlers + the form-level `Perform*` surface). A narrow host/test
    /// affordance for toggling fixture-side state OUTSIDE the event pipeline -- e.g. arming
    /// the W007 `InputField_Exit` veto for the focus-validation conformance tests. It does
    /// not reduce a UI event or touch reducer state; the runtime remains the sole owner of
    /// the dispatch + render VM entries.
    pub fn invoke_form_sub(&mut self, name: &str) -> Result<(), RuntimeError> {
        invoke(
            &mut self.session,
            self.form_module.clone(),
            name,
            ProjectMemberKind::Method,
            Vec::new(),
        )?;
        Ok(())
    }

    /// Re-render the attached form across the `OxForms.Surface` boundary — the §16
    /// Re-render the runtime owns. Invokes the form's VBA `UserForm.Render`, which
    /// self-renders into one batched `ScenePatch` and submits it, advancing the
    /// resident `Scene` the backend repaints. The runtime owns this VM entry
    /// (serialized with [`Self::dispatch`]); the resident `Scene` and its revision live
    /// in the `OxForms.Surface` the session was configured with — the bootstrap reads
    /// that snapshot to drive Repaint. Renders at 96 DPI. The form's `Render` emits an
    /// INCREMENTAL patch after the first frame (oxforms-rq5.2): only the invalidated
    /// controls cross, an unchanged frame does no crossing (no new revision), and a stale
    /// base self-heals to a full rebuild.
    pub fn render_frame(&mut self) -> Result<(), RuntimeError> {
        invoke(
            &mut self.session,
            self.user_form.clone(),
            "Render",
            ProjectMemberKind::Method,
            vec![Variant::from_i32(96), Variant::from_i32(96)],
        )?;
        Ok(())
    }

    /// The current reducer state (read-only).
    #[must_use]
    pub fn form(&self) -> &RuntimeForm {
        &self.form
    }

    /// The accumulated trace across all dispatched events.
    #[must_use]
    pub fn trace(&self) -> &[RuntimeTraceRow] {
        &self.trace
    }

    /// Reduce one normalized event, dispatch its native VBA effects, sync VBA-set
    /// properties back into reducer state, and request repaints. The per-step trace
    /// is folded into the durable trace **even on error**, so a failing dispatch
    /// stays diagnosable.
    pub fn dispatch(&mut self, event: UiEvent) -> Result<RuntimeStep, RuntimeError> {
        let mut step = RuntimeStep::default();
        let result = self.dispatch_with_foldback(event, &mut step);
        self.trace.extend(step.trace.iter().cloned());
        result?;
        Ok(step)
    }

    /// Reduce `event`, drain its effects, then re-reduce any readback fold-back events
    /// (a `QueryClose` `Cancel` re-entering as `QueryCloseCompleted`, …) into the same
    /// step until none remain — so a swallow/veto actually changes reducer state
    /// (oxforms-esq.4), not just the recorded readback. Bounded against runaway
    /// re-entry by [`MAX_FOLDBACK_ITERATIONS`].
    fn dispatch_with_foldback(
        &mut self,
        event: UiEvent,
        step: &mut RuntimeStep,
    ) -> Result<(), RuntimeError> {
        let mut pending = VecDeque::from([event]);
        let mut iterations = 0u32;
        while let Some(event) = pending.pop_front() {
            iterations += 1;
            if iterations > MAX_FOLDBACK_ITERATIONS {
                return Err(RuntimeError::FoldbackOverflow { iterations });
            }
            let output = reduce(self.form.state.clone(), event);
            self.form.state = output.state;
            let mut fold_back = Vec::new();
            self.process(&output.effects, step, &mut fold_back)?;
            for event in fold_back {
                pending.push_back(event);
            }
        }
        Ok(())
    }

    /// Drain the reducer effects into `step`, dispatching effects and syncing
    /// properties. Native dispatches whose readback must re-enter the reducer push a
    /// synthesized follow-up event onto `fold_back` (drained by
    /// [`Self::dispatch_with_foldback`]). Separated from [`Self::dispatch`] so the
    /// trace is flushed whether this returns `Ok` or `Err`.
    fn process(
        &mut self,
        effects: &[EffectRequest],
        step: &mut RuntimeStep,
        fold_back: &mut Vec<UiEvent>,
    ) -> Result<(), RuntimeError> {
        for effect in effects {
            let target_label = effect
                .target
                .control_id
                .as_ref()
                .map(|id| id.0.clone())
                .or_else(|| effect.target.form_id.as_ref().map(|id| id.0.clone()));
            match &effect.kind {
                EffectKind::FireVbaEvent { event_name, .. } => {
                    step.trace.push(RuntimeTraceRow::EffectDrained {
                        effect_id: effect.effect_id.0,
                        kind: format!("fire_vba_event:{event_name}"),
                        target: target_label.clone(),
                    });
                    match self.dispatch_fire_vba_event(effect, event_name)? {
                        Some(record) => {
                            step.trace.push(RuntimeTraceRow::NativeDispatch {
                                dispatch_id: self.dispatch_seq,
                                control_id: record.control_id.0.clone(),
                                event_name: record.event_name.clone(),
                                native_member: record.native_member.clone(),
                                completion: record.completion,
                                returned: record.returned.clone(),
                            });
                            // If the readback must change reducer state (e.g. a
                            // QueryClose Cancel), synthesize the follow-up event for
                            // the fold-back loop to re-reduce.
                            if let Some(event) = self.foldback_event(&record) {
                                fold_back.push(event);
                            }
                            step.native_dispatches.push(record);
                        }
                        None => {
                            // Reducer-routed FM20 event with no native dispatch yet
                            // (e.g. MouseMove, or a form-background mouse press):
                            // recorded, not dropped.
                            step.trace.push(RuntimeTraceRow::EventAcknowledged {
                                event_name: event_name.clone(),
                                target: target_label,
                            });
                        }
                    }
                }
                EffectKind::RequestRepaint {
                    invalidation_ids,
                    reason,
                } => {
                    step.repaint_requested = true;
                    step.trace.push(RuntimeTraceRow::RepaintRequested {
                        reason: format!("{reason:?}"),
                        invalidation_ids: invalidation_ids.iter().map(|id| id.0).collect(),
                    });
                }
                EffectKind::ClipboardGet {
                    request_id,
                    formats,
                } => {
                    step.trace.push(RuntimeTraceRow::EffectDrained {
                        effect_id: effect.effect_id.0,
                        kind: "clipboard_get".to_string(),
                        target: target_label,
                    });
                    // Fold the clipboard back as a ClipboardResult so the paste path
                    // (BeforeDropOrPaste -> Change) runs in this same dispatch — the same
                    // readback fold-back idiom as Exit/QueryClose (oxforms-esq.9). Always
                    // folds (empty clipboard -> a no-text result the reducer diagnoses as a
                    // no-op paste) so the reducer's pending paste is always consumed
                    // (oxforms-esq.13).
                    fold_back.push(self.clipboard_get_foldback(request_id, formats));
                }
                other => {
                    // Reducer-internal / not-yet-runtime effects (focus, capture, …):
                    // the reducer already applied them to state; record, do not skip.
                    step.trace.push(RuntimeTraceRow::EffectDrained {
                        effect_id: effect.effect_id.0,
                        kind: effect_kind_label(other).to_string(),
                        target: target_label,
                    });
                }
            }
        }

        self.sync_properties(step)
    }

    /// Execute one reducer `FireVbaEvent`. Returns `Some(record)` when the event maps
    /// to a native control member (`Click` → `PerformClick`, `Change` →
    /// `ApplyUserText`, `KeyDown`/`KeyUp` → `PerformKeyDown`/`PerformKeyUp`, `KeyPress`
    /// → `PerformKeyPress`, `MouseDown`/`MouseUp` → `PerformMouseDown`/
    /// `PerformMouseUp`, `Exit` → `PerformExit`, `Enter` → `PerformEnter`,
    /// `BeforeUpdate`/`AfterUpdate` → `PerformBeforeUpdate`/`PerformAfterUpdate`,
    /// `BeforeDropOrPaste` → `PerformBeforeDropOrPaste`) or, for
    /// form-level events
    /// (`QueryClose`/lifecycle), to the form module's `Perform*` via
    /// [`Self::dispatch_form_event`]; or `None` when it is a reducer-routed FM20 event
    /// still acknowledged but not natively dispatched (e.g. `MouseMove`), or a mouse
    /// press that landed on the form background (no control target). `dispatch_seq`
    /// advances only after a native member call succeeds.
    fn dispatch_fire_vba_event(
        &mut self,
        effect: &EffectRequest,
        event_name: &str,
    ) -> Result<Option<NativeDispatchRecord>, RuntimeError> {
        // Form-level events (form target, no control) dispatch to the form module's
        // Perform* surface, not a control member.
        if matches!(
            event_name,
            "Initialize" | "Activate" | "Deactivate" | "QueryClose" | "Terminate"
        ) {
            return self.dispatch_form_event(effect, event_name);
        }

        if !matches!(
            event_name,
            "Click"
                | "Change"
                | "KeyDown"
                | "KeyUp"
                | "KeyPress"
                | "MouseDown"
                | "MouseUp"
                | "Exit"
                | "Enter"
                | "BeforeUpdate"
                | "AfterUpdate"
                | "BeforeDropOrPaste"
        ) {
            return Ok(None);
        }

        // Mouse events can land on the form background (no control target); acknowledge
        // them without native dispatch there, unlike key events which always have a
        // focused control.
        if matches!(event_name, "MouseDown" | "MouseUp") && effect.target.control_id.is_none() {
            return Ok(None);
        }

        let control_id =
            effect
                .target
                .control_id
                .clone()
                .ok_or_else(|| RuntimeError::MissingControlTarget {
                    event_name: event_name.to_string(),
                })?;
        let control = self
            .control_objects
            .get(&control_id)
            .cloned()
            .ok_or_else(|| RuntimeError::UnknownControl(control_id.0.clone()))?;

        let (native_member, args): (&str, Vec<Variant>) = match event_name {
            "Click" => ("PerformClick", Vec::new()),
            "Change" => {
                // The reducer already updated the text-box value; push it to the VBA
                // control via the user-edit path (sets .Text and raises Change).
                let text = self
                    .form
                    .state
                    .text_boxes
                    .iter()
                    .find(|entry| entry.control_id == control_id)
                    .map(|entry| entry.text.clone())
                    .ok_or_else(|| RuntimeError::MissingTextForChange(control_id.0.clone()))?;
                ("ApplyUserText", vec![Variant::from_string(text)])
            }
            "KeyDown" | "KeyUp" => {
                // KeyCode is the mutable MSForms.ReturnInteger value the handler may
                // swallow; it is absent when the platform supplied no virtual key, in
                // which case we acknowledge without native dispatch.
                let Some(key_code) = effect_arg_i16(effect, "KeyCode") else {
                    return Ok(None);
                };
                let shift = effect_arg_i16(effect, "Shift").unwrap_or(0);
                let member = if event_name == "KeyDown" {
                    "PerformKeyDown"
                } else {
                    "PerformKeyUp"
                };
                (
                    member,
                    vec![Variant::from_i16(key_code), Variant::from_i16(shift)],
                )
            }
            "KeyPress" => {
                // KeyAscii is the mutable MSForms.ReturnInteger value the handler may
                // swallow (set to 0); absent/out-of-range input acknowledges instead.
                let Some(key_ascii) = effect_arg_i16(effect, "KeyAscii") else {
                    return Ok(None);
                };
                ("PerformKeyPress", vec![Variant::from_i16(key_ascii)])
            }
            "MouseDown" | "MouseUp" => {
                // Clean scalar args from the reducer: Button/Shift as Integer masks,
                // X/Y as Single (the FM20 mouse-event signature).
                let button = effect_arg_i16(effect, "Button").unwrap_or(0);
                let shift = effect_arg_i16(effect, "Shift").unwrap_or(0);
                let x = effect_arg_f32(effect, "X").unwrap_or(0.0);
                let y = effect_arg_f32(effect, "Y").unwrap_or(0.0);
                let member = if event_name == "MouseDown" {
                    "PerformMouseDown"
                } else {
                    "PerformMouseUp"
                };
                (
                    member,
                    vec![
                        Variant::from_i16(button),
                        Variant::from_i16(shift),
                        Variant::from_f32(x),
                        Variant::from_f32(y),
                    ],
                )
            }
            "Exit" => {
                // Focus-exit fires on the control losing focus; PerformExit raises
                // [Exit] with a fresh ReturnBoolean Cancel and returns the
                // post-handler value (True when the handler vetoed the focus change).
                ("PerformExit", Vec::new())
            }
            "Enter" => {
                // Focus-enter fires on the control gaining focus; PerformEnter raises
                // Enter (no args, no readback -- Enter is not cancelable) (oxforms-esq.6).
                ("PerformEnter", Vec::new())
            }
            "BeforeUpdate" => {
                // Fires on a dirty data control's focus-out; PerformBeforeUpdate raises
                // BeforeUpdate with a fresh ReturnBoolean Cancel and returns the
                // post-handler value (True = veto). Recorded; honoring the veto is
                // oxforms-esq.11 (oxforms-esq.7 emits only).
                ("PerformBeforeUpdate", Vec::new())
            }
            "AfterUpdate" => {
                // Fires after a committed update; PerformAfterUpdate raises AfterUpdate
                // (no args, no readback) (oxforms-esq.7).
                ("PerformAfterUpdate", Vec::new())
            }
            "BeforeDropOrPaste" => {
                // Fires before a clipboard/drag paste applies; PerformBeforeDropOrPaste
                // raises BeforeDropOrPaste with a fresh ReturnBoolean Cancel + the Action
                // (2 = fmActionPaste) and Shift, returning the post-handler Cancel. The Cancel
                // is folded back as BeforeDropOrPasteCompleted and HONORED (oxforms-esq.17): a
                // veto suppresses the deferred text insert + Change. The Shift arg carries the
                // chord's FM20 mask threaded by the reducer (2 for a keyboard Ctrl+V, esq.13).
                let action = effect_arg_i16(effect, "Action").unwrap_or(2);
                let shift = effect_arg_i16(effect, "Shift").unwrap_or(0);
                (
                    "PerformBeforeDropOrPaste",
                    vec![Variant::from_i16(action), Variant::from_i16(shift)],
                )
            }
            // Unreachable: guarded by the `matches!` above. Kept total without a
            // panic path.
            _ => return Ok(None),
        };

        let result = invoke(
            &mut self.session,
            control,
            native_member,
            ProjectMemberKind::Method,
            args,
        )?;
        self.dispatch_seq += 1;

        // PerformKeyDown/PerformKeyUp return the post-handler KeyCode and
        // PerformKeyPress the post-handler KeyAscii (0 when the handler swallowed the
        // key/character) via the MSForms.ReturnInteger helper. PerformExit and
        // PerformBeforeUpdate return the post-handler Cancel via the MSForms.ReturnBoolean
        // helper (True = vetoed); both are folded back as FocusValidationCompleted and
        // honored by the two-stage focus validation (oxforms-esq.4/esq.11). PerformClick,
        // ApplyUserText, AfterUpdate, and the mouse members return nothing meaningful.
        // PerformBeforeDropOrPaste returns its Cancel too, folded back as
        // BeforeDropOrPasteCompleted and honored by the two-stage paste (oxforms-esq.17).
        let returned = if matches!(event_name, "KeyDown" | "KeyUp" | "KeyPress") {
            result.as_i16().map(|code| code.to_string())
        } else if matches!(event_name, "Exit" | "BeforeUpdate" | "BeforeDropOrPaste") {
            result.as_bool().map(|cancel| cancel.to_string())
        } else {
            None
        };

        Ok(Some(NativeDispatchRecord {
            control_id,
            event_name: event_name.to_string(),
            native_member: native_member.to_string(),
            completion: DispatchCompletion::Succeeded,
            returned,
        }))
    }

    /// Dispatch a form-level FM20 event (form target, no control) to the form module's
    /// `Perform*` surface. `QueryClose` reads back the post-handler `Cancel` (an
    /// `Integer` via the `ReturnInteger` helper — nonzero/`True` = vetoed); the
    /// lifecycle events (`Initialize`/`Activate`/`Deactivate`/`Terminate`) take no args
    /// and return nothing. The `Cancel` veto is recorded in
    /// [`NativeDispatchRecord::returned`] AND folded back into the reducer close flow as
    /// [`UiEventKind::QueryCloseCompleted`] (see [`Self::foldback_event`]); the focus
    /// `Exit` and swallowed-`KeyDown` readbacks are likewise honored via fold-back
    /// (oxforms-esq.4), so none of these three is a recorded-not-honored boundary.
    fn dispatch_form_event(
        &mut self,
        effect: &EffectRequest,
        event_name: &str,
    ) -> Result<Option<NativeDispatchRecord>, RuntimeError> {
        let (native_member, args, reads_cancel): (&str, Vec<Variant>, bool) = match event_name {
            "Initialize" => ("PerformInitialize", Vec::new(), false),
            "Activate" => ("PerformActivate", Vec::new(), false),
            "Deactivate" => ("PerformDeactivate", Vec::new(), false),
            "Terminate" => ("PerformTerminate", Vec::new(), false),
            "QueryClose" => {
                let close_mode = effect_arg_i16(effect, "CloseMode").unwrap_or(0);
                (
                    "PerformQueryClose",
                    vec![Variant::from_i16(close_mode)],
                    true,
                )
            }
            // Unreachable: guarded by the `matches!` at the dispatch entry.
            _ => return Ok(None),
        };

        let result = invoke(
            &mut self.session,
            self.form_module.clone(),
            native_member,
            ProjectMemberKind::Method,
            args,
        )?;
        self.dispatch_seq += 1;

        let returned = if reads_cancel {
            result.as_i16().map(|cancel| cancel.to_string())
        } else {
            None
        };

        Ok(Some(NativeDispatchRecord {
            // Form-level events have no control; a sentinel marks the form as target.
            control_id: ControlId::new("<form>"),
            event_name: event_name.to_string(),
            native_member: native_member.to_string(),
            completion: DispatchCompletion::Succeeded,
            returned,
        }))
    }

    /// Synthesize the follow-up `UiEvent` (if any) that a native dispatch's readback
    /// must re-enter the reducer as, so a swallow/veto actually changes reducer state
    /// (oxforms-esq.4) rather than only being recorded:
    ///   * a `QueryClose` `Cancel` re-enters as `QueryCloseCompleted`, so a nonzero
    ///     (vetoing) Cancel drives the reducer to `CloseCancelled` instead of hiding;
    ///   * a `BeforeUpdate` or `Exit` `Cancel` re-enters as `FocusValidationCompleted`,
    ///     routed by the reducer's in-flight [`ValidationStage`] -- a vetoing `BeforeUpdate`
    ///     suppresses the value commit (AfterUpdate/Exit/Enter) and a vetoing `Exit`
    ///     retains focus instead of committing the deferred transfer (oxforms-esq.11);
    ///   * a swallowed `KeyDown` (`KeyCode -> 0`) re-enters as `KeyDownSwallowed`, so the
    ///     paired `KeyPress`/`Change` (the following `CharacterInput`) is suppressed;
    ///   * a `BeforeDropOrPaste` `Cancel` re-enters as `BeforeDropOrPasteCompleted` (when a
    ///     paste is in flight), so a vetoing paste suppresses the deferred text insert +
    ///     `Change` instead of only being recorded (oxforms-esq.17).
    fn foldback_event(&self, record: &NativeDispatchRecord) -> Option<UiEvent> {
        match record.event_name.as_str() {
            "QueryClose" => {
                let flow = self.form.state.close_flow.as_ref()?;
                let cancelled = record
                    .returned
                    .as_deref()
                    .and_then(|value| value.parse::<i32>().ok())
                    .is_some_and(|value| value != 0);
                Some(UiEvent::new(
                    UiEventId(0),
                    UiEventSource::Service,
                    UiEventKind::QueryCloseCompleted(QueryCloseCompletedEvent {
                        form_id: self.form.form_id.clone(),
                        reason: flow.reason,
                        cancelled,
                        close_mode: flow.close_mode,
                        dispatch_diagnostics: Vec::new(),
                    }),
                ))
            }
            "BeforeUpdate" | "Exit" => {
                // Two-stage focus-out validation (oxforms-esq.4/esq.11): the reducer set
                // validation.pending when it fired this handler and held the next step; fold
                // the post-handler Cancel (ReturnBoolean -> "true"/"false") back as
                // FocusValidationCompleted so the reducer's staged gate sees the veto
                // (BeforeUpdate gates the value commit; Exit gates the focus move). The
                // reducer routes by its OWN pending stage, so this synthesizes the same event
                // for both; the stage guard only ensures we fold at the stage actually in
                // flight (BeforeUpdate is only emitted at its stage, Exit at its).
                let pending = self.form.state.validation.pending.as_ref()?;
                let expected = if record.event_name == "BeforeUpdate" {
                    ValidationStage::BeforeUpdate
                } else {
                    ValidationStage::Exit
                };
                if pending.stage != expected {
                    return None;
                }
                let cancelled = record.returned.as_deref() == Some("true");
                Some(UiEvent::new(
                    UiEventId(0),
                    UiEventSource::Service,
                    UiEventKind::FocusValidationCompleted(FocusValidationCompletedEvent {
                        form_id: self.form.form_id.clone(),
                        cancelled,
                        dispatch_diagnostics: Vec::new(),
                    }),
                ))
            }
            "KeyDown" => {
                // A swallowed KeyDown reads back KeyCode 0 (ReturnInteger); fold it back so
                // the paired character is suppressed. An un-swallowed KeyDown (nonzero
                // KeyCode) needs no follow-up.
                let swallowed = record
                    .returned
                    .as_deref()
                    .and_then(|value| value.parse::<i32>().ok())
                    .is_some_and(|value| value == 0);
                if !swallowed {
                    return None;
                }
                Some(UiEvent::new(
                    UiEventId(0),
                    UiEventSource::Service,
                    UiEventKind::KeyDownSwallowed(KeyDownSwallowedEvent {
                        form_id: self.form.form_id.clone(),
                        dispatch_diagnostics: Vec::new(),
                    }),
                ))
            }
            "BeforeDropOrPaste" => {
                // Two-stage paste/drop (oxforms-esq.17 + oxforms-4f8): the reducer fired
                // BeforeDropOrPaste with the target value still unchanged and stashed
                // pending_paste_commit; fold the post-handler Cancel (ReturnBoolean ->
                // "true"/"false") back as BeforeDropOrPasteCompleted so a veto (Cancel=True)
                // suppresses the deferred insert + Change and a pass commits it. Gated on the
                // reducer actually having a paste in flight -- BOTH the keyboard Ctrl+V path
                // (reduce_clipboard_result, esq.17) and the drag-drop path (reduce_drop_or_paste,
                // 4f8) now set pending_paste_commit, so both are honored.
                self.form.state.pending_paste_commit.as_ref()?;
                let cancelled = record.returned.as_deref() == Some("true");
                Some(UiEvent::new(
                    UiEventId(0),
                    UiEventSource::Service,
                    UiEventKind::BeforeDropOrPasteCompleted(BeforeDropOrPasteCompletedEvent {
                        form_id: self.form.form_id.clone(),
                        cancelled,
                        dispatch_diagnostics: Vec::new(),
                    }),
                ))
            }
            _ => None,
        }
    }

    /// Synthesize the `ClipboardResult` that completes a `ClipboardGet` (the keyboard
    /// Ctrl+V paste fold-back, oxforms-esq.9). ALWAYS folds a result so every request is
    /// answered and the reducer's pending paste is consumed (oxforms-esq.13): the
    /// `set_clipboard_text` seed (if any) wins; otherwise the wired live OS clipboard reader
    /// (oxforms-esq.16) supplies the text; with neither, the result carries no text payload,
    /// which the reducer diagnoses as a no-op paste (no `BeforeDropOrPaste`/`Change`). The
    /// desktop bootstrap wires [`Self::set_clipboard_reader`]; headless tests leave it unset.
    fn clipboard_get_foldback(&self, request_id: &str, formats: &[String]) -> UiEvent {
        let text = self
            .clipboard_text
            .clone()
            .or_else(|| self.clipboard_reader.as_ref().and_then(|read| read()));
        let payload = text.map(|text| ServicePayload {
            content_type: Some("text/plain".to_string()),
            text: Some(text),
            bytes_sha256: None,
            metadata: Vec::new(),
        });
        UiEvent::new(
            UiEventId(0),
            UiEventSource::Service,
            UiEventKind::ClipboardResult(ClipboardResultEvent {
                request_id: ServiceRequestId::new(request_id),
                operation: ClipboardOperation::Get,
                outcome: ServiceOutcome::Success,
                formats: formats.to_vec(),
                payload,
            }),
        )
    }

    /// After dispatch, fold any VBA-set control text back into reducer state. For each
    /// control whose VBA `Core.Dirty` is set (a handler changed a property): pull its
    /// `DisplayText` and sync it (reducer-owned), requesting a repaint when the text
    /// actually changed; or, when only a non-text property changed (DisplayText
    /// unchanged), record a `PropertyDirtyDeferred` non-claim. Either way the VBA
    /// dirty flag is then consumed (`ClearDirty`).
    fn sync_properties(&mut self, step: &mut RuntimeStep) -> Result<(), RuntimeError> {
        let control_ids: Vec<ControlId> = self
            .form
            .controls
            .iter()
            .map(|binding| binding.control_id.clone())
            .collect();

        for control_id in control_ids {
            let core = self
                .core_objects
                .get(&control_id)
                .cloned()
                .ok_or_else(|| RuntimeError::UnknownControl(control_id.0.clone()))?;

            let dirty = invoke_bool(
                &mut self.session,
                core.clone(),
                "Dirty",
                ProjectMemberKind::PropertyGet,
                Vec::new(),
            )?;
            if !dirty {
                continue;
            }

            let text = invoke_string(
                &mut self.session,
                core.clone(),
                "DisplayText",
                ProjectMemberKind::PropertyGet,
                Vec::new(),
            )?;

            if let Some(invalidation) =
                sync_control_display_text(&mut self.form.state, &control_id, &text)
            {
                step.property_syncs.push(PropertySyncRecord {
                    control_id: control_id.clone(),
                    property: "DisplayText".to_string(),
                    value: text.clone(),
                });
                step.trace.push(RuntimeTraceRow::PropertySync {
                    control_id: control_id.0.clone(),
                    property: "DisplayText".to_string(),
                    value: text,
                });
                step.repaint_requested = true;
                step.trace.push(RuntimeTraceRow::RepaintRequested {
                    reason: format!("{:?}", invalidation.reason),
                    invalidation_ids: vec![invalidation.invalidation_id.0],
                });
                step.invalidations.push(invalidation);
            } else {
                // Dirty but DisplayText unchanged: a non-text property changed
                // (geometry/visible/enabled/colors), which the W007 slice does not
                // reconcile yet. Record the deferral before consuming the flag —
                // never a silent drop. Non-text property sync is a later slice.
                step.trace.push(RuntimeTraceRow::PropertyDirtyDeferred {
                    control_id: control_id.0.clone(),
                });
            }

            // Consume the VBA-side dirty flag now that the change is reconciled
            // (DisplayText synced) or recorded (non-text deferral).
            invoke(
                &mut self.session,
                core,
                "ClearDirty",
                ProjectMemberKind::Method,
                Vec::new(),
            )?;
        }

        Ok(())
    }
}

/// A short, stable label for an effect recorded in the trace (the reducer already
/// applied the effect to state; the runner only records it for diagnostics).
fn effect_kind_label(kind: &EffectKind) -> &'static str {
    match kind {
        EffectKind::FireVbaEvent { .. } => "fire_vba_event",
        EffectKind::RequestRepaint { .. } => "request_repaint",
        EffectKind::TransferFocus { .. } => "transfer_focus",
        EffectKind::CaptureMouse { .. } => "capture_mouse",
        EffectKind::ReleaseMouse { .. } => "release_mouse",
        EffectKind::StartTimer { .. } | EffectKind::StopTimer { .. } => "timer",
        EffectKind::ClipboardGet { .. } | EffectKind::ClipboardSet { .. } => "clipboard",
        EffectKind::SetCursor { .. } => "set_cursor",
        EffectKind::HostCapabilityRequest { .. } => "host_capability_request",
        _ => "other_effect",
    }
}

/// Look up a `FireVbaEvent` argument value by name (the reducer emits typed,
/// dispatch-ready args such as `KeyCode` and `Shift` alongside descriptive ones).
fn effect_argument<'a>(effect: &'a EffectRequest, name: &str) -> Option<&'a str> {
    match &effect.kind {
        EffectKind::FireVbaEvent { arguments, .. } => arguments
            .iter()
            .find(|arg| arg.name == name)
            .map(|arg| arg.value.as_str()),
        _ => None,
    }
}

/// Parse a `FireVbaEvent` argument as the `Integer` (`i16`) shape the native
/// control members expect. Returns `None` when absent or out of `Integer` range.
fn effect_arg_i16(effect: &EffectRequest, name: &str) -> Option<i16> {
    effect_argument(effect, name)
        .and_then(|value| value.parse::<i32>().ok())
        .and_then(|value| i16::try_from(value).ok())
}

/// Parse a `FireVbaEvent` argument as the `Single` (`f32`) shape the native mouse
/// members expect for the `X`/`Y` coordinates. Returns `None` when absent or
/// unparseable.
fn effect_arg_f32(effect: &EffectRequest, name: &str) -> Option<f32> {
    effect_argument(effect, name).and_then(|value| value.parse::<f32>().ok())
}

fn invoke(
    session: &mut ProjectRuntimeSession,
    object: ObjectRef,
    member: &str,
    kind: ProjectMemberKind,
    args: Vec<Variant>,
) -> Result<Variant, RuntimeError> {
    session
        .invoke_member_values(object, member, Some(kind), args)
        .map_err(|err| RuntimeError::Invoke {
            member: member.to_string(),
            message: err.message().to_string(),
        })
}

fn invoke_object(
    session: &mut ProjectRuntimeSession,
    object: ObjectRef,
    member: &str,
    kind: ProjectMemberKind,
    args: Vec<Variant>,
) -> Result<ObjectRef, RuntimeError> {
    invoke(session, object, member, kind, args)?
        .as_object_ref()
        .ok_or_else(|| RuntimeError::UnexpectedReturn {
            member: member.to_string(),
            detail: "expected an object reference".to_string(),
        })
}

fn invoke_bool(
    session: &mut ProjectRuntimeSession,
    object: ObjectRef,
    member: &str,
    kind: ProjectMemberKind,
    args: Vec<Variant>,
) -> Result<bool, RuntimeError> {
    invoke(session, object, member, kind, args)?
        .as_bool()
        .ok_or_else(|| RuntimeError::UnexpectedReturn {
            member: member.to_string(),
            detail: "expected a boolean".to_string(),
        })
}

fn invoke_string(
    session: &mut ProjectRuntimeSession,
    object: ObjectRef,
    member: &str,
    kind: ProjectMemberKind,
    args: Vec<Variant>,
) -> Result<String, RuntimeError> {
    let value = invoke(session, object, member, kind, args)?;
    value
        .as_bstr()
        .map(|text| text.to_string())
        .ok_or_else(|| RuntimeError::UnexpectedReturn {
            member: member.to_string(),
            detail: "expected a string".to_string(),
        })
}
