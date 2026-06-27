# W006 Nested Modal And Reentrant Pump Design

Status: design/blocker split, shared ownership contract, first synthetic
modal-frame trace subset complete, nested-modal Office oracle fixture captured
live (42 rows, no oracle blocker remains), and narrowed `Terminate`
object-lifetime oracle evidence captured with explicit blockers.
Beads: `oxforms-0a0.10`, `oxforms-0a0.19`, `oxforms-0a0.20`, `oxforms-0a0.21`, `oxforms-0a0.22`, `oxforms-0a0.25`
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
- OxVba modal/reentrant pump handover:
  `docs/handovers/HANDOVER_OxVba_w006_modal_reentrant_pump.md`.
- W006 nested modal fixture and live capture:
  `fixtures/office-oracle/excel-msforms/userforms/nested-modal-lifecycle/`
  and
  `docs/evidence/W006_control_implementation_rollout/captures/nested-modal-lifecycle-20260627T141239Z/`.
- W006 `Terminate` object-lifetime fixture and capture:
  `fixtures/office-oracle/excel-msforms/userforms/terminate-lifetime/`
  and
  `docs/evidence/W006_control_implementation_rollout/captures/terminate-lifetime-20260623T132422Z/`.

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
- section 9 requires `effect_requested` and `effect_completed` rows to be
  recorded separately because dispatch, modal pumps, host callbacks, and
  services can be reentrant;
- section 11 requires `lifecycle_pump` rows to record pump term, modal depth,
  active form/window, focus owner, close/query/hide/unload/terminate reason,
  cancellation status, and causal row ids;
- section 14 validates parent/nesting relationships and reducer/effect/dispatch
  causal ordering.

## Shared Runtime Ownership Contract

`oxforms-0a0.20` adds this contract before any nested modal or `DoEvents`
runtime work starts:

| Owner | Owns | Must report back as | Must not own |
|---|---|---|---|
| OxVba runtime | VBA call stack, native FM20-named event dispatch, handler reentry, `DoEvents` yield/resume semantics, default-instance identity, reference/object lifetime, `Terminate` eligibility, and `QueryClose` scalar/helper mutation propagation. | `vba_dispatch` rows, dispatch diagnostics, before/after mutation payloads, call-stack parent context, runtime yield/resume diagnostics, and object-lifetime diagnostics that OxForms can turn into normalized lifecycle inputs or effect completions. | `FormState`, display-list state, PAL window state, or private form state mutation. |
| OxForms reducer | The only write path for `FormState`: lifecycle state, pump state, modal depth, active/focus/capture state, close/query/hide/unload state, invalidations, and ordered effect requests. | `reducer_transition`, `effect_requested`, `lifecycle_pump`, and normalized `ui_event` rows. | Direct OxVba calls, direct PAL/window calls, object-lifetime decisions, or call-stack suspension. |
| OxForms effect runner/adapter | Ordered execution of reducer effects, assignment of effect/dispatch ids, completion policy, trace causality, and conversion of OxVba/PAL/host observations into completions or normalized events. | `effect_completed` rows with status, result/error diagnostics, parent effect/dispatch ids, `parent_row_id`, and `nesting_depth`. | Mutating `FormState` without a reducer input, inventing a private dispatch path, or draining effects past an explicit modal/yield/cancellation policy. |
| PAL/window layer | Native window creation/show/hide/destroy, owner/activation/focus diagnostics, platform close notifications, input capture, and delivery of platform input during modeless pumps, modal frames, and yields. | `WindowShown`, `WindowHidden`, platform close/input completions, activation/focus diagnostics, and serializable window/owner metadata. | VBA dispatch, `DoEvents` scheduling, `QueryClose` mutation, `Terminate` eligibility, or direct reducer state writes. |

Consequences:

- A modal `ShowFormModal` effect is not complete to the caller until the
  matching modal frame records `PumpFrameExited` and an `effect_completed`
  row. `EnterModalFrame` and `ExitModalFrame` are lifecycle effects, not a
  forms-owned event loop.
- A `DoEvents`-like yield starts in OxVba call-stack/runtime semantics. PAL may
  deliver queued input during the yield, but the resulting activity must reenter
  the same `UiEvent -> reducer -> Effects -> completions` path with parent and
  nesting metadata.
- Reentrant dispatch during a modal frame is allowed only when the active
  dispatch/effect context is preserved through `parent_row_id`,
  `nesting_depth`, `vba_dispatch`, `effect_requested`, `effect_completed`, and
  `lifecycle_pump` rows.
- `QueryClose` cancellation is a dispatch/effect completion carrying before and
  after `Cancel` and `CloseMode` values. The reducer decides whether the form
  remains visible, hides, unloads, or exits a modal frame.
- `Unloaded` is logical interaction removal. `Terminated` is recorded only when
  OxVba object-lifetime/default-instance/reference evidence or a replay/oracle
  row says the instance is terminal.

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
- `oxforms-0a0.19` adds a repo-owned Excel/MSForms nested-modal fixture plan
  with an outer modeless UserForm that enters an inner `Show vbModal` form from
  outer button handlers, intended inner hide/unload/system-close paths, outer
  hide/unload paths, and worksheet columns for event sequence, outer/inner
  identity, show mode, active control/window, close origin, `QueryClose`
  `Cancel` before/after, `CloseMode`, parent row, and nesting depth.
- The `oxforms-0a0.19` live Office capture succeeded in
  `nested-modal-lifecycle-20260627T141239Z` after `oxforms-0a0.24` hardened the
  generation path: it exported 42 rows across the outer and inner forms with
  zero blockers. The earlier bounded attempt had timed out before
  `workbook_generated` because the capture set control fonts on the VBIDE
  designer via COM, which left Excel's `SaveAs` falling back to the interactive
  "Save As" dialog; that dialog blocked the COM thread with no exception until
  the external timeout. Design-time control fonts are no longer set during
  generation (matching the pre-existing decision in
  `Open-ExcelUserFormFixture.ps1` that VBIDE design-time font setters are not
  reliably exposed to PowerShell COM); fonts are not load-bearing for lifecycle
  capture, which keys on event rows plus an anchor-label background color.
- The captured surfaces in `nested-modal-lifecycle-20260627T141239Z` are nested
  modal entry (inner rows carry `nesting_depth=1` and `parent_row_id` pointing at
  the outer `BeforeInnerShowModal` row), inner hide, inner unload, inner system
  close, outer hide, outer unload, `QueryClose` `Cancel`/`CloseMode` values, and
  `Terminate`. The following are observed ordering facts for this run only; they
  are not an exhaustive MSForms parity matrix and absence of a row is not a
  negative fact.
- Inner `Me.Hide` fired `BeforeHide`/`AfterHide` and fired NEITHER `QueryClose`
  NOR `Terminate`; the instance stayed alive (hidden) and the outer
  `Show vbModal` call returned (`AfterInnerShowModalReturn`).
- Inner `Unload Me` recorded `BeforeUnload` -> `QueryClose` (`CloseMode=1`, i.e.
  code/vbFormCode) -> `Terminate` -> `AfterUnload`.
- Inner system close (Alt+F4) recorded `QueryClose` with `CloseMode=0`
  (control-menu / user close) -> `Terminate`. The `CloseMode=0` (system) versus
  `CloseMode=1` (code unload) distinction is a concrete observed fact.
- Outer hide then unload recorded `BeforeHide`/`AfterHide`, then `BeforeUnload`
  -> `QueryClose` (`CloseMode=1`) -> `Terminate` -> `AfterUnload`.
- `oxforms-0a0.21` adds a repo-owned Excel/MSForms `Terminate` lifetime
  fixture with explicit `local_ref_state`, `held_ref_state`,
  `default_instance_state`, and `release_phase` worksheet columns. The capture
  at `terminate-lifetime-20260623T132422Z` exported 25 live rows for
  `hide_held_release` and `unload_held_release`.
- In `hide_held_release`, rows 1-12 record modeless show, `Hide`, local
  reference release, held-reference release, and scenario end. No `Terminate`
  row was exported for that scenario in this run; that is an observation of this
  sequence only, not a negative fact about every hidden form.
- In `unload_held_release`, row 19 records `QueryClose` for
  `close_origin=fixture_unload`, `close_mode=1`, `cancel_before=0`, and
  `cancel_after=0`. Row 20 records `Terminate` before row 21 `AfterUnload`,
  while the fixture columns still say `local_ref_state=held`,
  `held_ref_state=held`, `default_instance_state=not_used`, and
  `release_phase=create_instance`. Rows 22-25 then record local and held
  reference release steps. These columns are fixture state, not private Office
  reference counts.
- `modeless_system_close_held_release`, `modal_hide_return_held_release`, and
  `modal_unload_return_held_release` remain explicit blockers in the same
  capture. The stable row capture used skip flags after local attempts showed
  public automation could not both drive those paths and export the worksheet
  evidence honestly. No timing is claimed for those surfaces.
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
| Nested modal forms | W005 names `modal_frame` and `nested_modal_depth`; the W005 modal capture proves only a single modal run with every row at depth `0`. `TRACE_REPLAY_SCHEMA.md` requires `parent_row_id`, `nesting_depth`, `lifecycle_pump` rows, modal depth, and effect completions. `oxforms-0a0.19` adds a repo-owned two-form fixture, and the live capture `nested-modal-lifecycle-20260627T141239Z` exported 42 rows with no oracle blocker remaining after `oxforms-0a0.24` hardened the generation path. | Each entered modal frame increments modal depth and preserves the outer frame's trace context instead of replacing it. Inner-form input, dispatch results, and effect completions re-enter the same reducer/effect path. | Beyond the observed ordering facts for this run (inner hide return, inner unload, inner system close with `CloseMode=0` versus code unload with `CloseMode=1`, outer hide/unload), exhaustive MSForms ordering for activation/deactivation and modal frame exit across all paths is still not an exhaustive parity matrix; unobserved rows are not negative facts. | Live Office oracle row capture succeeded: 42 rows, no oracle blocker remains. PAL/effect-runner support for first-class modal frame entry/exit is still not implemented, and OxVba must still supply real event dispatch and caller-side `Show` behavior before runtime parity. | `oxforms-0a0.22` implements or blocks a synthetic host-neutral modal-frame trace subset. |
| `DoEvents`-like yield | W005 reserves `PumpYieldRequested` and `doevents_yield`; no W005 or W006 evidence exercises it. `TRACE_REPLAY_SCHEMA.md` can express the yield with `parent_row_id`, `nesting_depth`, `lifecycle_pump`, and `effect_completed` rows. | A yield from VBA/runtime execution returns to the shared event pump with the active dispatch/effect as parent context, then resumes only through a documented completion policy. | Whether live MSForms/Office permits queued form input, timers, modal-frame input, host callbacks, or close/unload work during specific `DoEvents` scenarios is unknown. | OxVba owns VBA call-stack yield/resume semantics and any integration with its runtime scheduler. PAL may deliver input during the yield, but must not mutate form state directly. | `oxforms-0a0.20` defines the shared ownership contract and exact blockers. `oxforms-0a0.23` captures or blocks live `DoEvents` yield oracle evidence. |
| Reentrant dispatch during modal frames | `INPUT_INTERACTION_MODEL.md` requires reentrant input from VBA dispatch, modal pumps, or host callbacks to get nested sequence metadata and re-enter the same `UiEvent` path. Existing trace samples can validate nested rows, but not modal-frame parity. | Dispatch reentrancy is allowed but must be explicit: parent dispatch/effect ids, parent rows, nesting depth, and effect completions are trace data, not prose. | Live ordering when handlers show forms, close forms, call `DoEvents`, mutate `Cancel`, or trigger host callbacks is unknown. | OxVba owns native event dispatch, handler reentry, mutable helper/scalar propagation, and call-stack diagnostics. OxForms core owns reducer serialization and effect ordering. | `oxforms-0a0.20` documents ownership. Later implementation beads must be split by scenario. |
| Modal return/completion policy | `LIFECYCLE_PUMP_MODEL.md` already names `EnterModalFrame`, `ExitModalFrame`, and `PumpFrameExited`; `TRACE_REPLAY_SCHEMA.md` requires effect requests and completions to be separate. | `ShowFormModal` should not complete to the caller until the modal frame exits through a recorded hide, close, unload, cancellation, or error policy. Modeless show remains a scheduling/completion policy, not a nested modal frame. | Exact live MSForms return point for `Me.Hide`, `Unload Me`, close-button/system-menu close, cancelled `QueryClose`, and errors is unknown. | PAL/effect runner must expose modal frame entry/exit completions. OxVba must represent blocked caller-side `Show` and resumed execution without a forms-only loop. | `oxforms-0a0.19` records the fixture and its live capture (`nested-modal-lifecycle-20260627T141239Z`, 42 rows). `oxforms-0a0.20` documents shared ownership. `oxforms-0a0.22` proves or blocks the smallest trace subset. |
| Object-lifetime `Terminate` timing | W005 modeless and modal captures observed final `Terminate` rows, but both fixtures were not designed to isolate held references or exact release timing. `oxforms-0a0.21` adds a narrower fixture: in `terminate-lifetime-20260623T132422Z`, `unload_held_release` observed `Terminate` at row 20 after `QueryClose` row 19 and before `AfterUnload` row 21 while fixture reference-state columns still said local and held refs were `held`; `hide_held_release` exported no `Terminate` row for its explicit release sequence. `oxforms-0a0.3` keeps `Unloaded` separate from `Terminated`. | `Unloaded` is logical interaction removal; `Terminated` should be recorded only when object-lifetime evidence, a live oracle row, or OxVba runtime state says the form instance is terminal. | Exact timing remains unknown for modeless system close, modal hide return, modal unload return, default instances, host shutdown, cancellation, and error paths. The fixture reference-state columns are explicit VBA instrumentation, not private Office reference counts. | OxVba owns object lifetime, default instance behavior, reference release, and `Terminate` dispatch. The W006 capture blocks the modeless system-close and modal-return branches because public automation could not export those rows honestly. OxForms can only model `Terminated` as an input/effect completion. | Residual oracle hardening is tracked by `oxforms-0a0.25` and should start from `terminate-lifetime-20260623T132422Z` blockers; no runtime `Terminate` timing behavior is implemented by this evidence bead. |

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

- The nested modal fixture has recorded live outer/inner form ordering:
  `nested-modal-lifecycle-20260627T141239Z` exported 42 rows with no oracle
  blocker remaining. Follow-up `oxforms-0a0.24` hardened the public
  Office/VBIDE generation path (the design-time control-font COM call that left
  `SaveAs` falling back to the interactive dialog) that had blocked the prior
  attempt.
- A `DoEvents` fixture has not yet recorded yield behavior; this is tracked by
  `oxforms-0a0.23`.
- The Terminate fixture isolated one modeless `Unload` held-reference sequence
  and one `Hide` release sequence, but modeless system close and modal return
  branches remain blocked in `terminate-lifetime-20260623T132422Z`.

## Exact Shared-Support Blockers

| Surface | Missing shared support | Owner | Blocks | Follow-up / evidence |
|---|---|---|---|---|
| `DoEvents`-like yield | Call-stack yield/resume hook that exposes parent dispatch/effect context and resumes deterministically after queued work. | OxVba runtime; PAL only supplies queued input; OxForms records completions. | Runtime `DoEvents` parity and any modal-frame yield implementation. | OxVba handover in `HANDOVER_OxVba_w006_modal_reentrant_pump.md`; OxForms oracle bead `oxforms-0a0.23`. |
| Modal `Show` completion | Caller-side blocked `Show` frame that resumes only after `PumpFrameExited` and matching `effect_completed` rows. | OxVba runtime with OxForms effect-runner completion policy and PAL window completions. | Live modal `ShowFormModal`, nested modal runtime, and caller-side return claims. | Nested modal oracle bead `oxforms-0a0.19`; trace subset bead `oxforms-0a0.22`; OxVba handover. |
| Reentrant dispatch during modal frames | Native event dispatch must preserve parent call/effect ids and allow handler-triggered modal show, close, unload, host callback, or yield rows to reenter the shared path. | OxVba dispatch plus OxForms trace/effect runner. | Reentrant modal runtime and trace/replay parity beyond synthetic rows. | `oxforms-0a0.19`, `oxforms-0a0.22`, and OxVba handover. |
| `QueryClose` mutation | `Cancel As Integer` and `CloseMode As Integer` before/after values through native FM20-named dispatch. | OxVba dispatch/object argument machinery. | Real close cancellation, modal close cancellation, and close-mode parity. | `HANDOVER_OxVba_w005_fm20_event_raise.md`, native dispatch blocker doc, and OxVba modal handover. |
| `Terminate` timing | Default-instance/reference/object-lifetime diagnostics and `Terminate` dispatch only when the form instance is terminal. | OxVba object model/runtime lifetime. | Object-lifetime parity, default-instance behavior, blocked modeless/modal close branches, and any claim that `Unloaded` implies `Terminated`. | `oxforms-0a0.21`, `terminate-lifetime-20260623T132422Z`, and OxVba modal handover. |

## Synthetic Modal-frame Trace Subset

`oxforms-0a0.22` adds the first host-neutral replay artifact for a modal frame:

- Trace:
  `docs/evidence/W006_control_implementation_rollout/trace-replay/modal-frame-subset.synthetic.v1.json`.
- Generator/check CLI:
  `cargo run -p oxforms-core --example w006_modal_frame_trace -- --check`.
- Focused Rust pin:
  `cargo test -p oxforms-core w006_modal_frame_trace_subset_matches_committed_artifact`.
- Schema validation:
  `tools/trace-replay/Test-TraceReplaySchema.ps1 -TracePath docs/evidence/W006_control_implementation_rollout/trace-replay/modal-frame-subset.synthetic.v1.json`.

The trace records `ShowFormModal`, `EnterModalFrame`, a synthetic click while
the modal frame is active, `PumpFrameExited`, `ExitModalFrame`,
`lifecycle_pump`, `effect_requested`, and `effect_completed` rows. The
modal-frame activity uses `parent_row_id` and `nesting_depth` under the
`show_form_modal` effect request, and `lifecycle_pump` rows carry
`modal_depth=1` while the modal frame is active. The `ShowFormModal` and
`EnterModalFrame` completion rows are emitted only after the synthetic
`PumpFrameExited` and `ExitModalFrame` rows.

This subset is synthetic and host-neutral. It does not create live modal
windows, run Excel/MSForms, execute OxVba, block or resume caller-side VBA,
implement `DoEvents`, or claim nested modal/MSForms parity. Missing live
support remains explicit:

- PAL/effect-runner support for first-class live modal frame enter/exit
  completions.
- PAL/window diagnostics for owner/activation/deactivation during modal frames.
- OxVba caller-side modal `UserForm.Show` blocking/resume semantics.
- OxVba native FM20-named dispatch, `QueryClose` mutation, `DoEvents`, and
  remaining object-lifetime `Terminate` evidence beyond the narrowed W006
  unload observation.

## Child Beads Filed

| Bead | Purpose |
|---|---|
| `oxforms-0a0.19` | Capture or precisely block nested modal lifecycle oracle evidence. |
| `oxforms-0a0.20` | Define the shared OxVba/OxForms/PAL ownership contract for modal frames, `DoEvents`, reentrancy, modal completion, and `Terminate`. |
| `oxforms-0a0.21` | Capture or precisely block `UserForm.Terminate` object-lifetime oracle evidence. |
| `oxforms-0a0.22` | Implement or precisely block the first host-neutral modal-frame trace/replay subset. |
| `oxforms-0a0.23` | Capture or precisely block live `DoEvents`-like yield oracle evidence. |
| `oxforms-0a0.25` | Harden or precisely re-block W006 `Terminate` modeless system-close and modal-return oracle capture paths. |

## Non-claims

- No broad modal runtime behavior is implemented by this bead.
- No private forms-owned event loop is introduced or authorized.
- No `DoEvents`, nested modal, reentrant dispatch, modal return, hide/unload,
  or broad `Terminate` parity is claimed.
- No live Office/MSForms evidence is treated as a pass/fail oracle for OxForms
  output in this bead.
