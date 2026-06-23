# W006 Nested Modal And Reentrant Pump Design

Status: design/blocker split complete.
Bead: `oxforms-0a0.10`
Date: 2026-06-23

This note classifies the lifecycle/pump surfaces deferred from the first
modeless close slice. It is not a runtime implementation and does not claim
full `UserForm.Show`, nested modal, `DoEvents`, reentrant dispatch, modal
return, hide/unload, or object-lifetime `Terminate` parity.

## Source Inputs

- `docs/specs/LIFECYCLE_PUMP_MODEL.md`.
- `docs/specs/INPUT_INTERACTION_MODEL.md` sections 3, 7, 8, 12, and 13.
- `docs/specs/TRACE_REPLAY_SCHEMA.md` sections 5, 9, 11, 14, and 15.
- `docs/evidence/W005_input_interaction_model_exploration/lifecycle-pump-model.md`.
- W005 modeless capture:
  `docs/evidence/W005_input_interaction_model_exploration/captures/interaction-events-20260623T004914Z/`.
- W005 modal capture:
  `docs/evidence/W005_input_interaction_model_exploration/captures/interaction-events-modal-20260623T045300Z/`.
- W006 modeless close subset:
  `docs/evidence/W006_control_implementation_rollout/modeless-lifecycle-close-slice.md`.
- W006 native FM20 event dispatch blocker:
  `docs/evidence/W006_control_implementation_rollout/native-fm20-event-dispatch-blocker.md`.
- OxVba event handover:
  `docs/handovers/HANDOVER_OxVba_w005_fm20_event_raise.md`.

## Durable Requirements

All five deferred surfaces must enter through the W005/W006 interaction spine:

```text
UiEvent -> route/reduce -> Effects -> effect runner -> completion/reentrant UiEvent
```

The reducer remains the only writer of `FormState`. OxVba dispatch, PAL/window
work, host callbacks, modal frames, and service calls run as effects and return
state-changing observations as normalized events or effect completions.

Trace rows must cite and conform to `docs/specs/TRACE_REPLAY_SCHEMA.md`:

- section 5 requires `parent_row_id` and `nesting_depth` for reentrant input,
  nested dispatch, modal frame activity, and effect completion causality;
- section 9 requires effect requests and effect completions to be recorded
  separately because dispatch, modal pumps, host callbacks, and services can be
  reentrant;
- section 11 requires `lifecycle_pump` rows to record pump term, modal depth,
  active form/window, focus owner, close/query/hide/unload/terminate reason,
  cancellation status, and causal row ids;
- section 14 validates parent/nesting relationships and reducer/effect/dispatch
  causal ordering.

## Facts

- `LIFECYCLE_PUMP_MODEL.md` reserves `modal_frame`,
  `nested_modal_depth`, `doevents_yield`, `vba_dispatch_reentrancy`,
  `host_callback_reentrancy`, `PumpYieldRequested`, `PumpFrameExited`,
  `EnterModalFrame`, and `ExitModalFrame` as lifecycle/pump terms and events.
- The W005 public fact matrix records `Initialize`, `Activate`, `Deactivate`,
  `QueryClose`, `Resize`, and `Terminate` as public-doc lifecycle event names,
  while lifecycle DISPIDs remain unknown in current repo evidence.
- The W005 modeless Office/MSForms capture contains 1116 rows. All rows have
  `nesting_depth=0`; row 1 observed `Initialize`, row 3 observed `Activate`,
  row 1114 observed `QueryClose` with `cancel_before=0`, `cancel_after=0`, and
  `close_mode=0`; row 1116 observed `Terminate` after the fixture close tail.
- The W005 modal Office/MSForms capture contains 133 modal-run rows. All rows
  have `nesting_depth=0`; row 1 observed `Initialize`, row 3 observed
  `Activate`, row 131 observed `QueryClose` with `cancel_before=0`,
  `cancel_after=0`, and `close_mode=0`; row 133 observed `Terminate`.
- The W005 modal capture explicitly did not exercise nested modal forms,
  `DoEvents`, `vba_dispatch_reentrancy`, or `host_callback_reentrancy`.
- `oxforms-0a0.3` implements only the first host-neutral modeless close subset:
  `CloseRequest -> FireVbaEvent(QueryClose) -> QueryCloseCompleted ->
  HideForm -> WindowHidden -> UnloadForm -> Unloaded`. It keeps `Unloaded`
  separate from object-lifetime `Terminate`.
- Actual native FM20-named handler dispatch, `QueryClose` cancellation, and
  scalar/helper mutation remain blocked by the OxVba shared event path described
  in `native-fm20-event-dispatch-blocker.md` and
  `HANDOVER_OxVba_w005_fm20_event_raise.md`.

## Surface Classification

| Surface | Facts | Assumptions For Design | Unknowns | Blockers / Owners | Follow-up |
|---|---|---|---|---|---|
| Nested modal forms | W005 names `modal_frame` and `nested_modal_depth`; the W005 modal capture proves only a single modal run with every row at depth `0`. `TRACE_REPLAY_SCHEMA.md` requires `parent_row_id`, `nesting_depth`, `lifecycle_pump` rows, modal depth, and effect completions. | Each entered modal frame increments modal depth and preserves the outer frame's trace context instead of replacing it. Inner-form input, dispatch results, and effect completions re-enter the same reducer/effect path. | Live MSForms ordering for outer `Show`, inner `Show`, activation/deactivation, `QueryClose`, hide/unload, modal frame exit, and caller-side return is not known. | Office oracle evidence is missing. PAL/effect-runner support for first-class modal frame entry/exit is not implemented. OxVba must supply real event dispatch and caller-side `Show` behavior before runtime parity. | `oxforms-0a0.19` captures or blocks nested modal oracle evidence. `oxforms-0a0.22` implements or blocks a synthetic host-neutral modal-frame trace subset. |
| `DoEvents`-like yield | W005 reserves `PumpYieldRequested` and `doevents_yield`; no W005 or W006 evidence exercises it. `TRACE_REPLAY_SCHEMA.md` can express the yield with parent/nesting metadata and effect completion rows. | A yield from VBA/runtime execution returns to the shared event pump with the active dispatch/effect as parent context, then resumes only through a documented completion policy. | Whether live MSForms/Office permits queued form input, timers, modal-frame input, host callbacks, or close/unload work during specific `DoEvents` scenarios is unknown. | OxVba owns VBA call-stack yield/resume semantics and any integration with its runtime scheduler. PAL may deliver input during the yield, but must not mutate form state directly. | `oxforms-0a0.20` defines the shared ownership contract and exact blockers. |
| Reentrant dispatch during modal frames | `INPUT_INTERACTION_MODEL.md` requires reentrant input from VBA dispatch, modal pumps, or host callbacks to get nested sequence metadata and re-enter the same `UiEvent` path. Existing trace samples can validate nested rows, but not modal-frame parity. | Dispatch reentrancy is allowed but must be explicit: parent dispatch/effect ids, parent rows, nesting depth, and effect completions are trace data, not prose. | Live ordering when handlers show forms, close forms, call `DoEvents`, mutate `Cancel`, or trigger host callbacks is unknown. | OxVba owns native event dispatch, handler reentry, mutable helper/scalar propagation, and call-stack diagnostics. OxForms core owns reducer serialization and effect ordering. | `oxforms-0a0.20` documents ownership. Later implementation beads must be split by scenario. |
| Modal return/completion policy | `LIFECYCLE_PUMP_MODEL.md` already names `EnterModalFrame`, `ExitModalFrame`, and `PumpFrameExited`; `TRACE_REPLAY_SCHEMA.md` requires effect requests and completions to be separate. | `ShowFormModal` should not complete to the caller until the modal frame exits through a recorded hide, close, unload, cancellation, or error policy. Modeless show remains a scheduling/completion policy, not a nested modal frame. | Exact live MSForms return point for `Me.Hide`, `Unload Me`, close-button/system-menu close, cancelled `QueryClose`, and errors is unknown. | PAL/effect runner must expose modal frame entry/exit completions. OxVba must represent blocked caller-side `Show` and resumed execution without a forms-only loop. | `oxforms-0a0.19` gathers oracle ordering. `oxforms-0a0.20` documents shared ownership. `oxforms-0a0.22` proves or blocks the smallest trace subset. |
| Object-lifetime `Terminate` timing | W005 modeless and modal captures observed final `Terminate` rows, but both fixtures were not designed to isolate held references or exact release timing. `oxforms-0a0.3` keeps `Unloaded` separate from `Terminated`. | `Unloaded` is logical interaction removal; `Terminated` should be recorded only when object-lifetime evidence or OxVba runtime state says the form instance is terminal. | Exact timing relative to `Hide`, `Unload`, modal return, default instances, held references, and reference release is unknown. | OxVba owns object lifetime, default instance behavior, reference release, and `Terminate` dispatch. OxForms can only model `Terminated` as an input/effect completion. | `oxforms-0a0.21` captures or blocks object-lifetime oracle evidence. |

## Ownership Blockers

OxVba blockers:

- Native FM20-named event dispatch for lifecycle events, including
  `Initialize`, `Activate`, `Deactivate`, `QueryClose`, `Resize`, and
  `Terminate`.
- `QueryClose` `Cancel` and `CloseMode` scalar/helper mutation semantics.
- Runtime support for a `DoEvents`-like yield that can expose parent dispatch
  context and resume execution deterministically.
- Caller-side modal `Show` blocking/resume semantics, including nested modal
  calls from handlers.
- Object lifetime/default-instance/reference tracking sufficient to dispatch or
  report `Terminate` honestly.

PAL/effect-runner blockers:

- First-class modal frame enter/exit effects with completions.
- Window ownership/activation/deactivation diagnostics for nested modal frames.
- Input delivery during modal frames and yields as normalized `UiEvent` rows.
- Hide/close/unload/window-destroy completions that do not directly mutate
  reducer state.

Oracle/evidence blockers:

- A nested modal fixture has not yet recorded outer/inner form ordering.
- A `DoEvents` fixture has not yet recorded yield behavior.
- A Terminate fixture has not yet isolated held-reference and release timing.

## Child Beads Filed

| Bead | Purpose |
|---|---|
| `oxforms-0a0.19` | Capture or precisely block nested modal lifecycle oracle evidence. |
| `oxforms-0a0.20` | Define the shared OxVba/OxForms/PAL ownership contract for modal frames, `DoEvents`, reentrancy, modal completion, and `Terminate`. |
| `oxforms-0a0.21` | Capture or precisely block `UserForm.Terminate` object-lifetime oracle evidence. |
| `oxforms-0a0.22` | Implement or precisely block the first host-neutral modal-frame trace/replay subset. |

## Non-claims

- No broad modal runtime behavior is implemented by this bead.
- No private forms-owned event loop is introduced or authorized.
- No `DoEvents`, nested modal, reentrant dispatch, modal return, hide/unload,
  or `Terminate` parity is claimed.
- No live Office/MSForms evidence is treated as a pass/fail oracle for OxForms
  output in this bead.
