# W005 Lifecycle And Pump Model Status

Status: lifecycle/pump model defined; live MSForms lifecycle observations are
blocked on downstream oracle fixture/capture beads.
Owning bead: `oxforms-xvx.19`.
Spec: [`../../specs/LIFECYCLE_PUMP_MODEL.md`](../../specs/LIFECYCLE_PUMP_MODEL.md).

This note records the evidence status behind the W005 lifecycle/pump model. It
separates currently available public/local facts from the observations that
future W005 beads must capture before claiming MSForms lifecycle parity.

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
- No live W005 MSForms lifecycle event log exists yet.

## Required Downstream Observations

The MSForms oracle fixture and capture beads (`oxforms-xvx.2` and
`oxforms-xvx.3`) must capture or precisely block:

1. `Initialize`, `Activate`, `Deactivate`, `QueryClose`, `Resize` when
   applicable, and `Terminate` when object lifetime can be observed honestly.
2. Modal and modeless show runs, clearly labeled per run.
3. Event sequence numbers, nesting depth, and reentrant dispatch context.
4. Active form/window and active/focused control state at every lifecycle event.
5. Close request origin and `CloseMode`.
6. `QueryClose.Cancel` value before and after handler code.
7. Whether close is cancelled, hidden, unloaded, or terminal.
8. Window bounds, DPI, screenshot/capture metadata, command logs, hashes, and
   manual action notes where automation is incomplete.

Reducer/effects, dispatch, visible-smoke, trace/replay, and comparison beads
must cite the spec instead of inventing local lifecycle behavior.

## Current Blocker

Live MSForms lifecycle ordering and modal/modeless pump behavior cannot be
settled in this bead because the W005 interaction oracle fixture and capture
beads have not run. The exact downstream owners are:

- `oxforms-xvx.2`: build the MSForms interaction oracle fixture.
- `oxforms-xvx.3`: capture live MSForms interaction event evidence.
- `oxforms-xvx.6`: implement reducer/effects lifecycle and pump state.
- `oxforms-xvx.10`: wire lifecycle event dispatch through the shared OxVba
  event path or file a precise OxVba blocker/handover.
- `oxforms-xvx.11`: route visible Windows show/activate/focus/close signals
  through normalized W005 input and trace them.

This blocker is expected and is already represented by the W005 bead graph, so
`oxforms-xvx.19` does not create an additional follow-up bead.
