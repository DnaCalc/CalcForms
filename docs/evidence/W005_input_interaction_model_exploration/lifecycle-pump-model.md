# W005 Lifecycle And Pump Model Status

Status: lifecycle/pump model defined; modeless live MSForms lifecycle
observations captured by `oxforms-xvx.3`; modal-show MSForms lifecycle
observations captured by `oxforms-xvx.20`.
Owning bead: `oxforms-xvx.19`.
Spec: [`../../specs/LIFECYCLE_PUMP_MODEL.md`](../../specs/LIFECYCLE_PUMP_MODEL.md).

This note records the evidence status behind the W005 lifecycle/pump model. It
separates currently available public/local facts, observed modeless MSForms
facts, and the observations that future W005 beads must capture before making
narrower lifecycle or pump claims.

## Current Evidence Inputs

- W005 interaction architecture:
  [`../../specs/INPUT_INTERACTION_MODEL.md`](../../specs/INPUT_INTERACTION_MODEL.md)
- W005 event fact matrix:
  [`../../specs/FM20_EVENT_FACTS.md`](../../specs/FM20_EVENT_FACTS.md)
- W005 coordinate model:
  [`../../specs/COORDINATE_MODEL.md`](../../specs/COORDINATE_MODEL.md)
- W002 visible smoke plan:
  [`../../worksets/W002_initial_windows_rectangle.md`](../../worksets/W002_initial_windows_rectangle.md)
- W002 evidence:
  [`../W002_initial_windows_rectangle.md`](../W002_initial_windows_rectangle.md)
- W002 visible smoke code:
  [`../../../crates/oxforms-pal/examples/visible_rectangle_smoke.rs`](../../../crates/oxforms-pal/examples/visible_rectangle_smoke.rs)
- W002 OxVba adapter smoke code:
  [`../../../crates/oxforms-oxvba-adapter/src/smoke_canvas.rs`](../../../crates/oxforms-oxvba-adapter/src/smoke_canvas.rs)
- W005 modeless interaction capture manifest:
  [`captures/interaction-events-20260623T004914Z/oracle-capture-manifest.json`](captures/interaction-events-20260623T004914Z/oracle-capture-manifest.json)
- W005 modeless event log:
  [`captures/interaction-events-20260623T004914Z/modeless-event-log.json`](captures/interaction-events-20260623T004914Z/modeless-event-log.json)
- W005 modeless run summary:
  [`captures/interaction-events-20260623T004914Z/run-summary.json`](captures/interaction-events-20260623T004914Z/run-summary.json)
- W005 modal interaction capture manifest:
  [`captures/interaction-events-modal-20260623T045300Z/oracle-capture-manifest.json`](captures/interaction-events-modal-20260623T045300Z/oracle-capture-manifest.json)
- W005 modal event log:
  [`captures/interaction-events-modal-20260623T045300Z/modal-event-log.json`](captures/interaction-events-modal-20260623T045300Z/modal-event-log.json)
- W005 modal lifecycle/pump observations:
  [`captures/interaction-events-modal-20260623T045300Z/modal-lifecycle-pump-observations.md`](captures/interaction-events-modal-20260623T045300Z/modal-lifecycle-pump-observations.md)

## Current Facts

- W002 proves a smoke-only rendering path:
  `VBA app project -> OxForms VBA library -> oxforms-oxvba-adapter -> oxforms-pal`.
- W002 does not implement `UserForm.Show`, modal/modeless pumps, input routing,
  lifecycle events, close/query/unload behavior, or MSForms event parity.
- The W005 input spec already requires lifecycle transitions to be represented
  as normalized `UiEvent` rows and `Effects`, not as host side channels.
- The W005 event fact matrix records `Initialize`, `Activate`, `Deactivate`,
  `QueryClose`, `Resize`, and `Terminate` as public-doc lifecycle names.
- The W005 FM20 type-library capture did not find those lifecycle names as
  members of source interfaces attached to `UserForm` or `UserForm2`; lifecycle
  DISPIDs remain unknown in repo evidence.
- The authoritative W005 modeless capture observed `Initialize`, `Activate`,
  `QueryClose`, and `Terminate` rows, with event sequence numbers,
  observed-fact text, assumption text, active/focused control fields,
  close-request context, and zero manual inputs.
- The W005 modeless capture did not settle modal pump behavior and did not
  observe every lifecycle name in the W005 fact matrix.
- The W005 modal capture invoked `ShowW005InteractionOracleModal`, produced
  133 modal run rows, and observed `Initialize`, `Activate`, `QueryClose`, and
  `Terminate` for that run. The fixture tagged visible-form rows
  `show_mode=modal`; initial `Initialize` and final `Terminate` rows remained
  `show_mode=unknown` in fixture output.
- The W005 modal capture observed `QueryClose` with `cancel_before=0`,
  `cancel_after=0`, and `close_mode=0`, followed by an `Exit` row for
  `OracleDefaultButton` and a final `Terminate` row.
- The W005 modal capture did not exercise nested modal forms, DoEvents-like
  yielding, `vba_dispatch_reentrancy`, or `host_callback_reentrancy`; the
  worksheet `nesting_depth` column remained `0` for all modal rows and is not a
  final nested-modal-depth parity claim.

## Remaining Downstream Observations

The modeless and modal MSForms oracle fixture/capture beads captured first live
event logs. Downstream implementation and comparison beads must still capture,
implement, compare, or precisely block:

1. `Initialize`, `Activate`, `Deactivate`, `QueryClose`, `Resize` when
   applicable, and `Terminate` when object lifetime can be observed honestly.
2. Additional modal/nested-modal scenarios beyond the single W005 modal-show
   fixture run.
3. Event sequence numbers, nesting depth, and reentrant dispatch context.
4. Active form/window and active/focused control state at every lifecycle event.
5. Close request origin and `CloseMode`.
6. `QueryClose.Cancel` value before and after handler code.
7. Whether close is cancelled, hidden, unloaded, or terminal.
8. Window bounds, DPI, screenshot/capture metadata, command logs, hashes, and
   manual action notes where automation is incomplete.

Reducer/effects, dispatch, visible-smoke, trace/replay, and comparison beads
must cite the spec instead of inventing local lifecycle behavior.

## Residual Gaps

Live modeless and modal MSForms lifecycle rows exist for the W005 interaction
fixture, but W005 still does not settle full lifecycle or pump parity. The exact
downstream owners are:

- `oxforms-xvx.6`: implement reducer/effects lifecycle and pump state.
- `oxforms-xvx.10`: wire lifecycle event dispatch through the shared OxVba
  event path or file a precise OxVba blocker/handover.
- `oxforms-xvx.11`: route visible Windows show/activate/focus/close signals
  through normalized W005 input and trace them.

Further nested-modal, DoEvents, reentrancy, hide/unload, and object-lifetime
questions should remain explicit follow-up work rather than being inferred from
the single modal fixture capture.
