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

Minimum scenarios OxForms needs:

1. A modal `UserForm.Show` call can block caller-side VBA execution, enter a
   nested pump frame, and resume only when the modal frame exits through a
   documented hide, close, unload, cancellation, or error completion.
2. A VBA event handler can show a second modal form while an outer modal frame is
   active, preserving parent dispatch/effect context for trace rows.
3. A handler can request `DoEvents`-like yielding, allowing queued input,
   completions, or host callbacks to re-enter the shared loop with parent/nesting
   metadata, then resume deterministically.
4. `QueryClose(Cancel As Integer, CloseMode As Integer)` can carry before/after
   scalar mutation values through native FM20-named dispatch rather than a test
   carrier event.
5. `Terminate` can be dispatched or reported only when OxVba object lifetime,
   default-instance state, and remaining references make the form instance
   terminal.

Expected outputs for OxForms:

- Event dispatch results with handler success/error, before/after scalar and
  helper-object mutation metadata, and enough call-stack context to populate
  `parent_row_id` and `nesting_depth`.
- A modal-show/yield API or runtime hook that lets OxForms effect runners
  produce `EnterModalFrame`, `ExitModalFrame`, `PumpYieldRequested`, and
  `PumpFrameExited` completions without mutating form state outside the reducer.
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
