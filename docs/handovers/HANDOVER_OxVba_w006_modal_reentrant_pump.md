Status: Open
Target: OxVba
Ask: Define, implement, or precisely block the shared OxVba runtime support that OxForms needs for modal `UserForm.Show`, `DoEvents`-like yielding, reentrant event dispatch, `QueryClose` mutation, and `Terminate` object-lifetime timing.

Context: `oxforms-0a0.10` classified the W006 lifecycle/pump follow-up in
`docs/evidence/W006_control_implementation_rollout/nested-modal-reentrant-pump-design.md`.
OxForms can model lifecycle state, emit effects, and record trace rows, but it
must not create a forms-owned event loop or private event-dispatch path. The
missing shared runtime behavior belongs at the OxVba call-stack/event/object
lifetime boundary and must return state-changing observations to OxForms through
normal effect completions or normalized events.

OxForms W006 update (`oxforms-0a0.20`, 2026-06-23): the owner boundary is now
documented as:

- OxVba owns VBA call-stack suspension/resume, native FM20-named event
  dispatch, handler reentry, `QueryClose` scalar/helper mutation propagation,
  default-instance identity, object reference/lifetime state, and `Terminate`
  eligibility.
- OxForms owns pure reducer state, ordered effect requests, effect completions,
  and trace causality.
- PAL/window code owns native surfaces and returns serializable window/input
  completions; it does not dispatch VBA or mutate forms state.

Minimum scenarios OxForms needs:

| Scenario | Inputs OxForms can provide | Expected OxVba/runtime completion | Evidence paths needed by OxForms |
|---|---|---|---|
| Modal `UserForm.Show` caller completion | `ShowFormModal` / `EnterModalFrame` effect with form id, owner form/window/host scope, initial bounds, modal depth, and causal show effect id. | Caller-side VBA execution blocks while the modal frame is active, then resumes only after a documented hide, close, unload, cancellation, or error exit. OxForms needs `PumpFrameExited`, `effect_completed(show_form_modal)`, exit reason, return/error diagnostics, and parent call/effect context. | `docs/evidence/W006_control_implementation_rollout/nested-modal-reentrant-pump-design.md`; future `oxforms-0a0.19` nested modal oracle evidence; future `oxforms-0a0.22` host-neutral modal trace subset. |
| Nested modal show from a handler | Native event dispatch context for an outer form handler, then a second modal show request triggered by that handler. | Inner modal work preserves outer dispatch/effect context, records nested depth, and resumes the outer handler/frame in a deterministic order after the inner frame exits. | `oxforms-0a0.19` must capture or block outer/inner ordering, active form/window/control, close origin, `QueryClose` values, and any hide/unload/Terminate rows. |
| `DoEvents`-like yield from a handler | Active dispatch/effect id, handler call site, reason, and queued input/service action where the fixture can drive one. | Runtime yields to the shared pump, allows queued input, service completions, host callbacks, or modal-frame activity to reenter with parent/nesting metadata, then resumes the original handler with success/error diagnostics. | New OxForms bead `oxforms-0a0.23` must capture or block modeless and modal-frame `DoEvents` yield evidence. |
| Reentrant dispatch during a modal frame | Active modal depth plus native event dispatch that can show forms, close/hide/unload forms, call `DoEvents`, or trigger host callbacks. | Each reentrant row exposes enough call-stack context for `parent_row_id` and `nesting_depth`; dispatch result rows include success/error and mutation metadata. | `docs/specs/TRACE_REPLAY_SCHEMA.md` sections 5, 9, and 11; `oxforms-0a0.19`; `oxforms-0a0.22`. |
| `QueryClose` mutation | `FireVbaEvent(QueryClose)` with `Cancel As Integer`, `CloseMode As Integer`, close origin, form target, and fact-source reference. | Native FM20-named handler dispatch returns success/error plus before/after `Cancel` and `CloseMode` values so OxForms can emit `QueryCloseCompleted(cancelled=...)`. | Existing blocker `docs/evidence/W006_control_implementation_rollout/native-fm20-event-dispatch-blocker.md`; existing handover `HANDOVER_OxVba_w005_fm20_event_raise.md`; future modal close evidence from `oxforms-0a0.19`. |
| `Terminate` object lifetime | Form instance id, default-instance flag if known, unload/hide/modal-return reason, and remaining-reference diagnostics where OxForms has them. | OxVba dispatches or reports `Terminate` only when runtime object lifetime, default-instance state, and remaining references make the instance terminal. Logical `Unloaded` remains distinct. | Future `oxforms-0a0.21` object-lifetime oracle evidence. |

Expected outputs for OxForms:

- Event dispatch results with handler success/error, before/after scalar and
  helper-object mutation metadata, and enough call-stack context to populate
  `parent_row_id` and `nesting_depth`.
- A modal-show/yield API or runtime hook that lets OxForms effect runners
  produce `EnterModalFrame`, `ExitModalFrame`, `PumpYieldRequested`, and
  `PumpFrameExited` completions without mutating form state outside the reducer.
- Traceable `effect_completed` rows for dispatch, modal-show, yield, hide, close,
  unload, and error completions.
- Object-lifetime diagnostics or callbacks that distinguish logical `Unloaded`
  from actual `Terminate`.

Evidence:

- W006 classification:
  `docs/evidence/W006_control_implementation_rollout/nested-modal-reentrant-pump-design.md`.
- Existing native event blocker:
  `docs/evidence/W006_control_implementation_rollout/native-fm20-event-dispatch-blocker.md`.
- Existing event-dispatch handover:
  `docs/handovers/HANDOVER_OxVba_w005_fm20_event_raise.md`.
- Trace obligations:
  `docs/specs/TRACE_REPLAY_SCHEMA.md` sections 5, 9, and 11.
- DoEvents yield oracle follow-up:
  `oxforms-0a0.23`.
