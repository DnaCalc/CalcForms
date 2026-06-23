# OxForms Lifecycle And Pump Model

Status: W005 lifecycle/pump model.
Owning bead: `oxforms-xvx.19`.
Owning workset:
[`W005_input_interaction_model_exploration`](../worksets/W005_input_interaction_model_exploration.md).
Evidence/status note:
[`lifecycle-pump-model.md`](../evidence/W005_input_interaction_model_exploration/lifecycle-pump-model.md).

This document defines the W005 model for `UserForm`-like lifecycle, modal and
modeless pumping, activation, close, hide, unload, terminate, and reentrancy.
It is an architecture contract for downstream fixture, reducer/effects, VBA
dispatch, visible-smoke, trace/replay, and comparison beads. It is not an
implementation of full `UserForm.Show` parity, and it does not claim final
MSForms ordering without live oracle evidence.

## 1. Anchors

- [`INPUT_INTERACTION_MODEL.md`](INPUT_INTERACTION_MODEL.md), sections 3, 7, 8,
  12, 13, and 14.
- [`FM20_EVENT_FACTS.md`](FM20_EVENT_FACTS.md), lifecycle and form-adjacent
  event names and signatures.
- [`COORDINATE_MODEL.md`](COORDINATE_MODEL.md), coordinate spaces used by
  activation, resize, visible-smoke, and oracle artifacts.
- [`FORMS_LIBRARY_SPEC_AND_PLAN.md`](../FORMS_LIBRARY_SPEC_AND_PLAN.md),
  sections 4.3, 8, 9, 10.2, 11/P2, and 12.
- W002 smoke docs and code, which prove only a smoke display-list path and do
  not define input, lifecycle, or pump behavior.

Charter section 3.1 applies directly: temporary smoke APIs and host bindings
must not become durable runtime architecture by convenience or inertia. Lifecycle
and pump behavior must enter OxForms through the same normalized input,
reducer, effects, OxVba dispatch, and trace/replay path as other interaction
behavior, not as private host side channels.

## 2. Evidence Status

Current facts:

- `Initialize`, `Activate`, `Deactivate`, `QueryClose`, `Resize`, and
  `Terminate` are public-doc lifecycle event names recorded in
  [`FM20_EVENT_FACTS.md`](FM20_EVENT_FACTS.md).
- The W005 FM20 type-library capture did not find those lifecycle names as
  source-interface members attached to `UserForm` or `UserForm2`; lifecycle
  DISPIDs, if any, are therefore unknown in the current repo evidence.
- W002 visible smoke opens a short-lived native window and paints a display
  list. It has no normalized input pump, no `UserForm.Show`, and no lifecycle
  event observations.
- W005 live MSForms lifecycle event logs now exist for the interaction fixture:
  the modeless capture from `oxforms-xvx.3` and the modal-show capture from
  `oxforms-xvx.20` both observed `Initialize`, `Activate`, `QueryClose`, and
  `Terminate` rows. They do not settle nested modal, `DoEvents`, hide/unload,
  object-lifetime, or full `UserForm.Show` parity.

This model is therefore a durable W005 architecture model plus downstream
evidence requirements. Ordering statements below are design constraints unless
they are explicitly described as public-doc facts or future oracle observations.

## 3. Lifecycle State

Lifecycle state is part of `FormState.lifecycle_state`. It is per form instance
and must be serializable in traces. Implementations may represent the terms
below as a richer set of facets, for example load phase, visibility/show mode,
activation state, and close/unload phase, rather than as one lossy enum.
Trace rows and docs should still use these names consistently.

| State | Meaning | Allowed next state examples |
|---|---|---|
| `allocated` | A form object exists, but designer/runtime state has not been loaded. | `loading`, `terminated` on construction failure or abandoned instance. |
| `loading` | The runtime is materializing controls, properties, and any required form module state. | `loaded`, `load_failed`. |
| `loaded` | The logical form/control tree exists, but initialization handlers have not completed for this instance. | `initializing`, `unloading`. |
| `initializing` | `Initialize` event dispatch is active or pending. | `initialized`, `init_failed`, `unloading`. |
| `initialized` | Initialization completed; the form may be hidden or be shown later. | `showing_modeless`, `showing_modal`, `unloading`. |
| `hidden` | The form remains loaded/initialized but has no visible active surface. | `showing_modeless`, `showing_modal`, `unloading`. |
| `showing_modeless` | A visible surface is being created or has become visible for modeless show. | `modeless_visible`, `hide_pending`, `close_requested`. |
| `modeless_visible` | The form is visible and serviced by the host/modeless pump. | `active`, `deactivated`, `hide_pending`, `close_requested`. |
| `showing_modal` | A visible surface is being created for a modal show and a modal frame is being entered. | `modal_visible`, `hide_pending`, `close_requested`. |
| `modal_visible` | The form is visible inside a modal pump frame. | `active`, `deactivated`, `hide_pending`, `close_requested`. |
| `active` | This form/window is the active OxForms surface in the current interaction scope; preserve the underlying modal/modeless visibility facet. | `deactivated`, `hide_pending`, `close_requested`. |
| `deactivated` | The form remains visible but is not the active OxForms surface; preserve the underlying modal/modeless visibility facet. | `active`, `hide_pending`, `close_requested`. |
| `close_requested` | A close request has entered the reducer but query-close dispatch has not completed. | `query_close_pending`, `hide_pending`, `unloading`. |
| `query_close_pending` | `QueryClose` event dispatch is active or pending and can cancel the close. | `close_cancelled`, `hide_pending`, `unloading`. |
| `close_cancelled` | The close was cancelled and the form remains loaded; visibility/activation return to the prior visible state where possible. | `active`, `deactivated`, `modeless_visible`, `modal_visible`, `close_requested`. |
| `hide_pending` | A hide transition has been requested but platform visibility/effect completion has not been recorded. | `hidden`, `unloading`. |
| `unloading` | Unload has started; terminal cleanup and `Terminate` timing are being resolved. | `terminated`, `unload_blocked`. |
| `terminated` | The form instance is terminal for OxForms interaction state. | none. |

`load_failed`, `init_failed`, and `unload_blocked` are diagnostic states for
trace/evidence rows. They should become precise errors or blocker beads before
code claims production behavior.

## 4. Pump State

Pump state is part of `FormState.pump_state`. It names how a form is serviced,
not who owns a platform window.

| Pump term | Meaning |
|---|---|
| `host_modeless_pump` | The host or top-level application pump is running and delivers modeless input as normalized `UiEvent` rows. |
| `modal_frame` | A nested pump frame entered for a modal form. It continues to receive PAL input, service completions, and OxVba dispatch results through the shared loop. |
| `nested_modal_depth` | Integer depth for modal frames. Depth `0` means no active OxForms modal frame. |
| `doevents_yield` | A controlled yield from VBA/runtime execution back into the shared event pump. W005 records the concept but does not implement final `DoEvents` parity. |
| `vba_dispatch_reentrancy` | Reentrant input or effects produced while a VBA event handler is executing. |
| `host_callback_reentrancy` | Reentrant input or effects produced by a host capability callback, such as a future Excel `RefEdit` capability. |
| `close_unload_cancellation` | Temporary pump state while close/query/unload effects decide whether a form remains visible, becomes hidden, or terminates. |

Modal and modeless pumping use the same logical event path:

```text
UiEvent -> route/reduce -> Effects -> effect runner -> completion/reentrant UiEvent
```

A modal frame may block the caller's `Show` effect completion, but it must not
mutate form state outside the reducer. A modeless show schedules visibility and
returns control to the caller after the show effects reach their documented
completion point.

## 5. Lifecycle Inputs

Lifecycle-sensitive behavior enters as normalized `UiEvent` rows or effect
completions. W005 should use these event names in traces and future code:

| UiEvent family | Required payload | Notes |
|---|---|---|
| `FormInstanceRequested` | `FormId`, requested class/form name, owner/host scope, show mode if known | May originate from `UserForm.Show`, a default instance access, replay, or test fixture setup. |
| `FormLoaded` | `FormId`, load source, control tree summary, diagnostics | Completion of materialization; does not imply `Initialize` already ran. |
| `FormLoadFailed` | `FormId`, error kind, diagnostics | Diagnostic path; downstream implementation must not pretend the form was shown. |
| `ShowRequested` | `FormId`, `modal` or `modeless`, owner form/window/host scope, initial bounds, reason | Produces show/window/pump effects. |
| `WindowShown` | `FormId`, `WindowId`, show mode, bounds, DPI/scale, visibility diagnostics | Effect completion from PAL/window adapter. |
| `Activate` | `FormId`, `WindowId`, previous active form/window if known, reason | Updates active form/window state. |
| `Deactivate` | `FormId`, `WindowId`, next active form/window if known, reason | Updates active/deactivated state; exact MSForms unload interaction remains evidence-gated. |
| `HideRequested` | `FormId`, reason | Produces hide effects; does not terminate the form by itself. |
| `WindowHidden` | `FormId`, `WindowId`, reason, diagnostics | Completion of hide effect. |
| `CloseRequest` | `FormId`, `WindowId`, origin, close reason, raw diagnostics | Begins query-close/close/unload flow; never destroys state directly. |
| `QueryCloseCompleted` | `FormId`, close reason, cancelled flag, event dispatch diagnostics | Produced after `QueryClose` dispatch. |
| `UnloadRequested` | `FormId`, reason, query policy | Produces unload/terminate effects. |
| `Unloaded` | `FormId`, reason, remaining-reference diagnostics if available | Logical unload completed; `Terminate` timing may depend on object lifetime evidence. |
| `Terminated` | `FormId`, reason, diagnostics | Terminal lifecycle observation. |
| `PumpYieldRequested` | source dispatch/effect id, reason | Represents `DoEvents`-like yield or host idle callback entering the pump. |
| `PumpFrameExited` | modal depth, exit reason, return/cancel diagnostics | Completes a modal show frame or records abnormal exit. |

Raw platform messages and host callbacks may be preserved in diagnostics, but
they are not the portable lifecycle contract.

## 6. Lifecycle Effects

Lifecycle behavior is requested through `Effects` and performed outside the
pure reducer. The effect runner owns platform and OxVba calls; completions come
back as `UiEvent` rows.

| Effect | Required payload | Completion |
|---|---|---|
| `MaterializeForm` | form class/name, default-instance flag, owner/host scope, source project/module ids | `FormLoaded` or `FormLoadFailed`. |
| `FireVbaEvent(Initialize)` | form target, no args, fact-source `FM20_EVENT_FACTS.md` public-doc row | Dispatch result; state changes from handlers reenter through normalized events/effect completions. |
| `CreateWindowSurface` | form id, owner window/host scope, initial bounds in named coordinate space, caption/style diagnostics | `WindowShown` once visible or diagnostic failure. |
| `EnterModalFrame` | form id, owner, modal depth, causal show event/effect id | Nested pump starts; completion is `PumpFrameExited`. |
| `ScheduleModeless` | form id, owner/host scope, causal show event/effect id | Modeless integration is armed under `host_modeless_pump`. |
| `FireVbaEvent(Activate)` | form target, no args | Dispatch result; activation state changes remain reducer-owned. |
| `FireVbaEvent(Deactivate)` | form target, no args | Dispatch result; evidence must check unload behavior before final claims. |
| `FireVbaEvent(Resize)` | form target, no args | Optional in W005 visible smoke when resize occurs. |
| `HideWindowSurface` | form/window id, reason | `WindowHidden`. |
| `FireVbaEvent(QueryClose)` | form target, `Cancel As Integer`, `CloseMode As Integer`, close origin | `QueryCloseCompleted` with before/after scalar values and dispatch diagnostics. |
| `DestroyWindowSurface` | form/window id, reason | `Unloaded` or platform diagnostic completion, depending on implementation stage. |
| `FireVbaEvent(Terminate)` | form target, no args | Dispatch result; terminal state only after object-lifetime evidence says it is appropriate. |
| `ExitModalFrame` | form id, modal depth, close/hide reason | `PumpFrameExited`. |

Downstream code may split these effects into smaller typed effects, but traces
must preserve this logical ordering and causal chain.

## 7. Show Semantics For W005

W005 recognizes two show modes:

- `ShowFormModeless`: schedule or create a visible form and return after
  modeless show effects reach their completion policy.
- `ShowFormModal`: create a visible form and enter a `modal_frame` whose exit
  is driven by hide, close, unload, or an error/cancellation policy.

Minimal W005 show path:

1. `FormInstanceRequested` enters the shared input path.
2. The reducer requests `MaterializeForm` if the instance is not loaded.
3. `FormLoaded` causes an `Initialize` event effect if initialization is still
   pending.
4. `ShowRequested` requests window creation and either `ScheduleModeless` or
   `EnterModalFrame`.
5. `WindowShown` and `Activate` update visible/active state through the reducer.
6. `Activate` dispatch is requested through OxVba's shared event path.

Open ordering questions:

- Whether live MSForms fires `Initialize` at first default-instance access, at
  first show, or another point for each scenario W005 will exercise.
- Exact ordering among `Initialize`, `Show`, window visibility, `Activate`, and
  first paint.
- Whether `Resize` fires during initial show and what minimum geometry changes
  trigger it.
- Exact modal return value/observable completion point for caller-side VBA.

W005 must not encode answers to those questions as compatibility claims until
oracle evidence records them.

## 8. Activation And Focus

Activation is form/window-level and focus is control/form-level. They interact
but must remain separate fields in `FormState`.

- `active_form` and `active_window` are updated from `Activate`/`Deactivate`
  `UiEvent` rows.
- `focus_owner` changes through focus routing and `TransferFocus` effects.
- Activation may request `FireVbaEvent(Activate)` or
  `FireVbaEvent(Deactivate)` effects.
- Focus transfer may request `Enter`, `Exit`, `BeforeUpdate`, and
  `AfterUpdate` effects using the event fact matrix.
- A deactivated form can still have a remembered `focus_history` for restoration
  diagnostics.

The W005 oracle fixture must log both active form/window and focused/active
control state when lifecycle events fire. The visible smoke must record platform
activation/focus diagnostics separately from reducer-owned focus decisions.

## 9. Close, QueryClose, Hide, Unload, Terminate

Close is a cancellable lifecycle flow, not a direct destruction operation.

Minimal W005 close flow:

1. Platform close button, system menu, host request, replay script, or VBA
   `Unload` request enters as `CloseRequest`, `HideRequested`, or
   `UnloadRequested` with a reason.
2. If the close policy requires query, the reducer requests
   `FireVbaEvent(QueryClose)` with scalar `Cancel` and `CloseMode` arguments.
3. `QueryCloseCompleted(cancelled=true)` returns the form to a visible state
   where possible and records `close_cancelled`.
4. `QueryCloseCompleted(cancelled=false)` proceeds to hide/unload effects.
5. Hide makes the form non-visible but does not prove termination.
6. Unload removes the logical form from active interaction. `Terminate` is a
   separate event/effect whose exact timing is evidence-gated because public
   docs tie it to object reference lifetime.
7. Modal forms exit their modal frame through `ExitModalFrame` after hide/unload
   reaches the documented completion point for the implemented subset.

The model deliberately separates:

- close request origin;
- `QueryClose` cancel result;
- visibility (`hidden` versus visible);
- logical unload;
- terminal object lifetime.

Downstream code must not collapse those into one "destroy window" branch.

## 10. Reentrancy Rules

Reentrant lifecycle behavior is expected and must be traceable.

Rules:

1. A VBA event handler may show another form, hide/unload the current form,
   request `DoEvents`-like yielding, or trigger host callbacks.
2. Reentrant input receives new `UiEventId` values with parent/nesting metadata.
3. Nested modal forms increment `nested_modal_depth`; they do not replace the
   outer modal frame's trace context.
4. The reducer remains the only writer of `FormState`.
5. Effect completions that arrive during VBA dispatch are recorded with their
   causal `DispatchId`/`EffectId` and fed back through the shared event path.
6. If a handler cancels close/query/focus transfer, the cancellation is a
   reducer input/effect completion, not a side-channel mutation.
7. Errors or unsupported runtime behavior must become explicit trace rows and,
   when blocking implementation, precise beads or handovers.

W005 does not implement final `DoEvents` semantics. It reserves
`PumpYieldRequested` and `doevents_yield` so later runtime work has a named
place to integrate without inventing a forms-only loop.

## 11. W005 Probe Subset

The W005 probe subset is intentionally small:

- lifecycle states: `allocated`, `loading`, `loaded`, `initializing`,
  `initialized`, `hidden`, `showing_modeless`, `modeless_visible`,
  `showing_modal`, `modal_visible`, `active`, `deactivated`,
  `close_requested`, `query_close_pending`, `close_cancelled`,
  `hide_pending`, `unloading`, and `terminated`;
- pump terms: `host_modeless_pump`, `modal_frame`, `nested_modal_depth`,
  `vba_dispatch_reentrancy`, `host_callback_reentrancy`, and
  `close_unload_cancellation`;
- events/effects: form materialization, `Initialize`, show modal/modeless,
  activation/deactivation, optional resize logging, close request,
  `QueryClose`, hide, unload, modal frame exit, and terminal diagnostics;
- evidence: event sequence numbers, active form/window, focus owner,
  close-origin/close-mode, query-close cancel before/after values, modal depth,
  dispatch nesting, and window/DPI/bounds metadata.

Deferred from the W005 first implementation:

- full `UserForm.Show` parity;
- final `DoEvents` parity;
- exact object-lifetime/`Terminate` timing;
- multiple owner-window policies and task-modal/application-modal distinctions;
- full dynamic `AddControl`/`RemoveControl`, `Layout`, `Scroll`, and `Zoom`;
- Excel `RefEdit` range-selection lifecycle beyond host-extension event shape;
- complete validation/focus ordering beyond the probe controls.

## 12. Fixture And Smoke Requirements

`oxforms-xvx.2` and `oxforms-xvx.3` MSForms oracle work must log:

- `Initialize`, `Activate`, `Deactivate`, `QueryClose`, `Resize` when observed,
  and `Terminate` when the fixture can observe object lifetime without guessing;
- event sequence number and nesting depth;
- show mode (`modal` or `modeless`) for each run;
- active form/window and active/focused control state at every lifecycle event;
- close origin and `CloseMode`;
- `QueryClose` `Cancel` value before and after handler code;
- whether a close was cancelled, hidden, unloaded, or terminated;
- window bounds, DPI, screenshot/capture metadata, and coordinate-space tags
  from [`COORDINATE_MODEL.md`](COORDINATE_MODEL.md);
- raw stdout/stderr, command logs, workbook/fixture hashes, and manual action
  notes if input is not fully automated.

`oxforms-xvx.6` reducer/effects work must:

- store `lifecycle_state` and `pump_state`;
- emit lifecycle effects instead of calling OxVba/PAL directly;
- preserve sequence, cause, nesting, and cancellation metadata;
- represent modal/modeless completion policy without creating a private
  forms-only pump.

`oxforms-xvx.10` VBA dispatch smoke work must:

- use OxVba's shared event machinery for lifecycle events;
- file a precise blocker or handover if `Initialize`, `Activate`,
  `Deactivate`, `QueryClose`, `Resize`, or `Terminate` cannot be dispatched
  through the shared path;
- avoid direct Rust callbacks into form code as an architecture shortcut.

`oxforms-xvx.11` visible input smoke work must:

- route platform show/activate/focus/close signals into normalized `UiEvent`
  rows;
- record modal depth, active window/form, close request origin, and window/DPI
  diagnostics;
- stay evidence/test infrastructure, not a production host shell.

Current `oxforms-xvx.11` status: implemented for the W005 visible smoke subset.
The committed capture at
[`../evidence/W005_input_interaction_model_exploration/captures/visible-input-smoke-20260623T035500Z/`](../evidence/W005_input_interaction_model_exploration/captures/visible-input-smoke-20260623T035500Z/)
records modeless show/window/activate/resize rows, active
`host_modeless_pump`, public Windows mouse/key/character input, and a public
platform close request that enters the reducer as `CloseRequest` and emits
`QueryClose`. The smoke does not claim modal pump, hide/unload/terminate, or
final `UserForm.Show` parity.

## 13. Blockers And Follow-up Rules

Do not implement a forms-only event loop, private callback path, direct
state-mutating host workaround, or preserved temporary integration path to
satisfy lifecycle behavior.
If implementation hits missing shared runtime support, file a precise blocker
or handover bead. Expected blocker categories are:

- OxVba cannot materialize form modules/default instances needed for a lifecycle
  fixture.
- OxVba shared event dispatch cannot call the required UserForm event handler
  names or carry `QueryClose` scalar mutation/cancel values.
- The host/PAL layer has no first-class modal frame or modeless scheduling
  effect runner entry point.
- Live Office/MSForms automation cannot capture lifecycle logs reproducibly.
- Trace schema cannot represent nested pump, dispatch, and effect completion
  ordering.

The blocker must name the missing owner, the minimal scenario that fails, and
the downstream bead it blocks.

## 14. Remaining Unknowns

- Exact live MSForms ordering for default instance creation, load,
  `Initialize`, first show, first paint, `Resize`, and `Activate`.
- Whether `Activate`/`Deactivate` fire for every W005 modal/modeless transition
  and what happens during unload.
- Exact `QueryClose` `CloseMode` values for system close button, code-driven
  unload, owner/host shutdown, modal close, and replay-driven close.
- Whether `QueryClose.Cancel` scalar mutation is visible by ordinary assignment
  exactly as public docs describe in all W005 scenarios.
- Exact hide versus unload behavior for modal return and modeless visibility.
- Exact `Terminate` timing relative to unload and remaining object references.
- How `DoEvents` interacts with modal frames, nested forms, pending effects, and
  host callbacks.
- Which lifecycle DISPIDs, if any, are used outside the captured FM20 source
  interfaces.
