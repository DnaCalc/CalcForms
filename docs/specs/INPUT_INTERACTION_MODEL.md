# OxForms Input Interaction Model

Status: W005 draft spec surface.
Owning workset: [`W005_input_interaction_model_exploration`](../worksets/W005_input_interaction_model_exploration.md).
Created by bead: `oxforms-xvx.1`.

This document defines the shared interaction vocabulary for W005. It is
self-contained enough for implementation beads to use, but it is not a runtime
implementation and it does not claim final MSForms event-order parity. Unknowns
must remain explicit until public metadata, repo-owned fixtures, or black-box
Office/MSForms observations settle them.

## 1. Source Anchors

This spec refines the top-level architecture rather than replacing it:

- [`FORMS_LIBRARY_SPEC_AND_PLAN.md`](../FORMS_LIBRARY_SPEC_AND_PLAN.md),
  section 4.3, reducer state model.
- [`FORMS_LIBRARY_SPEC_AND_PLAN.md`](../FORMS_LIBRARY_SPEC_AND_PLAN.md),
  section 4.5, trace/replay and evidence architecture.
- [`FORMS_LIBRARY_SPEC_AND_PLAN.md`](../FORMS_LIBRARY_SPEC_AND_PLAN.md),
  sections 5.3 and 5.4, FM20 event bands and capture method.
- [`FORMS_LIBRARY_SPEC_AND_PLAN.md`](../FORMS_LIBRARY_SPEC_AND_PLAN.md),
  section 6.2, PAL contract surface.
- [`FORMS_LIBRARY_SPEC_AND_PLAN.md`](../FORMS_LIBRARY_SPEC_AND_PLAN.md),
  section 8, rendering and input model.
- [`FORMS_LIBRARY_SPEC_AND_PLAN.md`](../FORMS_LIBRARY_SPEC_AND_PLAN.md),
  section 9, runtime integration with the OxVba VM.
- [`FORMS_LIBRARY_SPEC_AND_PLAN.md`](../FORMS_LIBRARY_SPEC_AND_PLAN.md),
  section 10.2, fidelity strategy.
- [`FORMS_LIBRARY_SPEC_AND_PLAN.md`](../FORMS_LIBRARY_SPEC_AND_PLAN.md),
  section 11, P2 reducer vertical slice.
- [`FORMS_LIBRARY_SPEC_AND_PLAN.md`](../FORMS_LIBRARY_SPEC_AND_PLAN.md),
  section 12, open questions and deferred work.

Charter constraints apply: compatibility with MSForms and observed VBA behavior
wins, claims require clean-room evidence, and initial OxForms scaffolds are not
protected API shapes. Operations constraints also apply: behavior changes update
spec/evidence in the same bead, and event or runtime gaps become precise beads
or handovers rather than private shortcuts.

## 2. Scope And Non-goals

This document owns the W005 names and boundaries for:

- normalized `UiEvent` families;
- interaction-relevant `FormState` fields;
- explicit `Effects`;
- reducer, effect, VBA-dispatch, and reentrant-input ordering;
- trace/replay obligations;
- the homes for FM20 event facts, coordinate calibration, and lifecycle/pump
  semantics.

This document does not:

- implement runtime behavior;
- define complete MSForms event ordering;
- define complete TextBox editing, IME, drag/drop, or clipboard behavior;
- define full `UserForm.Show` parity;
- introduce a forms-only event runtime separate from OxVba shared event
  machinery;
- treat W005 probe controls as complete MSForms replacements.

## 3. Core Loop

All input enters the same conceptual loop:

```text
platform input, host input, or service completion
  -> normalize to UiEvent
  -> route by capture, focus, hit-test, lifecycle, and host scope
  -> reduce: FormState + UiEvent -> FormState + Effects + RenderInvalidation
  -> execute effects through PAL, host capabilities, and OxVba event dispatch
  -> feed effect completions and reentrant input back as UiEvent
  -> record trace/replay evidence
```

The reducer is pure with respect to platform APIs and VBA calls. It computes the
next state, requested effects, and render invalidation. Platform operations,
host-extension requests, timers, clipboard operations, and VBA event dispatch are
effects performed by the adapter/effect runner. Any result that can affect
state returns as a later `UiEvent` or effect completion.

## 4. Common Identifiers And Metadata

The exact Rust/VBA representation is future work, but W005 artifacts should use
these names consistently:

- `FormId`: stable trace identifier for a form instance.
- `ControlId`: stable trace identifier for a control instance.
- `WindowId`: PAL/window identifier when a form has a visible surface.
- `HostScopeId`: host-extension scope, for example an Excel workbook/window
  context supplied by an extension layer.
- `UiEventId`: monotonically increasing input/service event sequence number
  within one trace.
- `EffectId`: monotonically increasing effect sequence number within one trace.
- `DispatchId`: sequence number for an attempted VBA event dispatch.
- `ReplayRunId`: trace run identifier used in artifacts.

Every `UiEvent`, `Effect`, and trace row should carry:

- schema version;
- sequence number;
- parent sequence or nesting depth when produced by reentrant dispatch or a
  nested pump;
- source kind: `pal`, `host_extension`, `service`, `replay`, or `oracle`;
- target form/window where known;
- monotonic timestamp or logical replay tick;
- diagnostics sufficient to preserve raw platform or host data without making
  that raw data the portable contract.

## 5. Normalized UiEvent

`UiEvent` is the platform-independent input and service language consumed by
the router/reducer. A `UiEvent` may have a preferred target from the adapter, but
the reducer/router owns final control routing unless the event is explicitly a
host-extension event whose host scope is the target.

### 5.1 Portable PAL Event Families

These families are portable PAL input or service events. They must stay free of
OxVba adapter types and host-specific object handles.

| Family | Required payload | Notes |
|---|---|---|
| `MouseMove` | pointer id if available, buttons currently down, modifiers, named coordinate payload, raw diagnostics | Routed through capture when capture exists, otherwise through hit-test. |
| `MouseDown` | button, buttons currently down, modifiers, click count if available, named coordinate payload, raw diagnostics | May request focus transfer, capture, pressed state, and VBA mouse events. |
| `MouseUp` | button, buttons currently down, modifiers, named coordinate payload, raw diagnostics | During capture, routed to capture owner even if the pointer is outside bounds. |
| `MouseDoubleClick` | button, modifiers, click count, named coordinate payload, raw diagnostics | W005 must preserve enough down/up/click diagnostics to compare with MSForms observations; exact synthesis rules are open. |
| `MouseWheel` | horizontal/vertical deltas, delta unit, modifiers, named coordinate payload, raw diagnostics | Wheel routing remains an open parity question until observed. |
| `KeyDown` | canonical key, modifiers, repeat count or auto-repeat flag, raw virtual/scancode diagnostics | Does not imply printable text by itself. |
| `KeyUp` | canonical key, modifiers, raw virtual/scancode diagnostics | Should be traceable even when no control handles it. |
| `CharacterInput` | text scalar or short text segment, modifiers if meaningful, raw diagnostics | Represents committed character input from the platform; IME/composition is deferred. |
| `FocusIn` | form/window focus target, reason when available, raw diagnostics | Represents platform focus entering an OxForms surface. |
| `FocusOut` | losing form/window, optional gaining target, reason when available | Does not by itself decide control-level validation; reducer/effects do that. |
| `Activate` | form/window, activation reason, previous active form/window if known | Used to update active form/window state. |
| `Deactivate` | form/window, next active form/window if known | Used to update active form/window state. |
| `CloseRequest` | form/window, origin such as system menu, close button, host request, or replay | Begins close/query/unload flow; does not directly destroy state. |
| `TimerFired` | timer id, logical tick, drift diagnostics if available | Timers are created/stopped by effects. |
| `ClipboardResult` | request id, operation, success/error, serializable data metadata | Produced by clipboard effects; actual `DataObject` detail is deferred. |
| `ServiceResult` | request id, service kind, success/error, serializable payload metadata | Covers PAL service completions that are not otherwise specialized. |
| `DpiChanged` | old/new scale or DPI, affected window/form, suggested bounds if supplied | Coordinate conversions must name old and new spaces. |
| `Resize` | window/client size, form logical size if known, DPI/scale, raw diagnostics | May request layout and repaint invalidation. |

### 5.2 Host-extension Event Families

Host-extension events are normalized, serializable events supplied by an
extension layer. They are not part of the portable PAL contract and must not
place host object identities inside core `FormState` except as opaque,
replayable handles owned by a host capability.

The required family is `HostExtensionEvent` with:

- host namespace, for example `excel`;
- capability name, for example `refedit.selection`;
- event kind, for example selection update, commit, cancel, host focus lost, or
  host focus restored;
- `HostScopeId`;
- target `FormId` or `ControlId` when known;
- serializable payload such as reference text, sheet/workbook identifiers, or an
  opaque host token;
- raw diagnostics separated from portable payload.

Future Excel `RefEdit` selection events must use this lane. They may request
host capabilities through effects, but core OxForms must still be able to replay
the normalized host event sequence without live Excel.

### 5.3 Deferred Or Specialized Families

Drag/drop and paste are in the top-level event bands but are not W005's first
implementation target. Their future events should still follow this model:
serializable input or service events enter the reducer; host or platform data
objects stay behind capability/service effects; observations distinguish public
metadata, black-box evidence, assumptions, and unknowns.

## 6. Interaction FormState

`FormState` is the complete logical state needed to decide interaction behavior
and render invalidation. W005 implementations may store these fields in a more
structured model, but traces and docs should use these names.

| Field | Meaning |
|---|---|
| `active_form` | The form currently active within the OxForms interaction scope, if any. |
| `active_window` | PAL window that currently owns platform activation for an OxForms surface. |
| `focus_owner` | `ControlId` or form-level focus target that receives keyboard and character input. |
| `focus_history` | Last meaningful focus owner per form/scope, used for restoration and diagnostics. |
| `capture_owner` | Control/form currently receiving captured mouse move/up events, plus capture reason/button. |
| `hover_path` | Hit-test path currently under the pointer when no capture overrides routing. |
| `pressed_state` | Button/control press or armed state, including pointer/key origin where relevant. |
| `tab_order` | Ordered focus traversal list with enabled/visible/focusable filtering inputs. |
| `default_button` | Command button candidate for Enter/default activation. |
| `cancel_button` | Command button candidate for Escape/cancel activation. |
| `accelerator_index` | Mapping from normalized accelerator key to candidate controls, including ambiguity diagnostics. |
| `keyboard_state` | Modifiers, key-repeat diagnostics, and current key routing context needed by W005. |
| `text_selection` | TextBox-probe caret/selection anchor, active end, and selection direction. |
| `text_value_state` | TextBox-probe value/text dirty state and minimal edit history needed for `Change`. |
| `validation_state` | Pending/active validation, cancelability, and last validation result for focus transfer. |
| `lifecycle_state` | Per-form create/load/initialize/show/hide/close/unload/pump state; section 12 owns terms. |
| `pump_state` | Modal/modeless/nested-pump state and reentrancy depth; section 12 owns terms. |
| `dirty_regions` | Dirty rectangles in a named coordinate space. |
| `dirty_subtrees` | Control/layout subtrees requiring layout or display-list refresh. |
| `pending_effects` | Ordered effects not yet completed, with causal event/effect ids. |
| `trace_counters` | Sequence counters for deterministic trace rows and replay diagnostics. |
| `oracle_annotations` | Optional non-runtime evidence annotations used only in oracle/comparison artifacts. |

The W005 probe subset must include enough state for:

- `Label`: hit-testability, hover diagnostics, mouse event routing, text render
  invalidation, and no focus ownership by default.
- `CommandButton`: focusability, pressed/armed state, click/default/cancel
  activation, accelerator participation, and invalidation.
- `TextBox`: focusability, minimal single-line text value mutation,
  caret/selection placeholders, character input, `Change` effect, and validation
  participation.

## 7. Effects

`Effects` are ordered requests emitted by the reducer and executed outside the
pure state transition. Every effect must have an `EffectId`, a causal
`UiEventId` or parent `EffectId`, a target, and a traceable completion policy.

| Effect | Required payload | Completion behavior |
|---|---|---|
| `FireVbaEvent` | target object/control, event name, argument list, ByRef or mutable-helper metadata, cancel metadata, fact-source reference when known | Executed through OxVba shared event machinery. Completion records success/error and scalar ByRef or helper-object mutations. |
| `RequestRepaint` | dirty region/subtree, reason, target window/form | May complete immediately as scheduled or later when renderer reports diagnostics. |
| `CaptureMouse` | target control/form, pointer/button/reason | Completion records success/failure; platform capture loss returns as input/service event. |
| `ReleaseMouse` | target control/form, reason | Completion records success/failure and final capture owner. |
| `TransferFocus` | from target, to target, reason, validation policy | May emit `FireVbaEvent` effects for focus/validation ordering and later completion/cancel handling. |
| `StartTimer` | timer id or purpose, interval, repeat policy | Completion is later `TimerFired` events. |
| `StopTimer` | timer id or purpose | Completion records whether a timer was active. |
| `ClipboardGet` | request id, requested formats | Completion is `ClipboardResult`. |
| `ClipboardSet` | request id, serializable data formats | Completion is `ClipboardResult`. |
| `SetCursor` | cursor kind, target scope, reason | Completion may be immediate or diagnostic-only. |
| `ShowFormModal` | form id, owner, initial bounds/state, reason | Enters lifecycle/pump model; nested input is recorded with parent/nesting metadata. |
| `ShowFormModeless` | form id, owner/host scope, initial bounds/state, reason | Returns after scheduling modeless display. |
| `HideForm` | form id, reason | Completion records visibility/lifecycle state. |
| `CloseForm` | form id, close reason, query policy | May cause query/close/unload event effects before destruction. |
| `UnloadForm` | form id, reason | Completion records terminal lifecycle state. |
| `HostCapabilityRequest` | host namespace, capability, target, serializable request payload | Completion is `HostExtensionEvent` or `ServiceResult`; no private host objects enter core state. |

Effects may be batched, but ordering must remain observable. A later
implementation can optimize representation only if trace output preserves the
logical order required for replay and comparison.

## 8. Reducer And Reentrancy Ordering

W005 uses these ordering principles until evidence refines them:

1. Assign a `UiEventId` before routing.
2. Preserve raw platform/host diagnostics in the event record before converting
   coordinates, key codes, or host payloads.
3. Resolve capture and focus before hit-test where capture/focus rules require
   it; otherwise hit-test against the current control tree and visibility/enabled
   state.
4. Run one pure reducer transaction:
   `FormState + UiEvent -> FormState + Effects + RenderInvalidation`.
5. Append render invalidation and effects to the trace in the order emitted by
   the reducer.
6. Execute effects outside the reducer through the PAL, host capability layer,
   or OxVba shared event dispatcher.
7. Record effect completions, VBA dispatch results, scalar ByRef mutations,
   mutable-helper-object mutations, service results, and errors as trace rows.
   If they affect state, feed them back as normalized events or reducer inputs.
8. If VBA dispatch, a modal pump, or a host callback produces reentrant input,
   assign nested sequence metadata and re-enter the same `UiEvent` path. Reentrant
   code must not mutate `FormState` outside the reducer.
9. Do not encode final MSForms parity rules for ordering without evidence. Known
   uncertain areas include focus/validation/exit, click versus double-click,
   keydown/keypress/change, default/cancel activation, close/query/unload, and
   modal/modeless pump behavior.

The effect runner may stop draining the current effect queue only for an
explicit lifecycle/pump transition, cancellation/error policy, or documented
host/runtime blocker. Such behavior must appear in trace output.

## 9. FM20 Event Fact Home

`oxforms-xvx.17` owns the W005 FM20/MSForms event signature and argument fact
surface. The curated spec home is
[`FM20_EVENT_FACTS.md`](FM20_EVENT_FACTS.md). Generated/raw evidence belongs
under `docs/evidence/W005_input_interaction_model_exploration/`, starting with
[`fm20_typelib_w005_events.json`](../evidence/W005_input_interaction_model_exploration/fm20_typelib_w005_events.json).

The fact matrix must use these columns or direct equivalents:

- FM20 event name;
- source kind and control applicability;
- public metadata source or observation source;
- DISPID where public type-library metadata provides it;
- argument names;
- argument types;
- ByVal/ByRef status;
- mutation/cancel semantics;
- coordinate argument space and units;
- ordering facts if observed;
- W005 probe subset status;
- unknowns and assumptions separated from observed facts.

At minimum, the W005 fact lane should cover the event names called out by the
workset and top-level event bands: `Click`, `DblClick`, `Change`, `Enter`,
`Exit`, `KeyDown`, `KeyUp`, `KeyPress`, `MouseDown`, `MouseUp`, `MouseMove`,
`BeforeUpdate`, `AfterUpdate`, `Error`, `DropButtonClick`, `BeforeDragOver`,
and `BeforeDropOrPaste`, plus form lifecycle events needed by section 12.

Fixture, trace, and dispatch beads must cite the fact matrix when naming event
arguments. If public metadata or tooling is missing, that bead must file a
precise blocker rather than inventing signatures.

## 10. Coordinate Model And Calibration Home

`oxforms-xvx.18` owns the detailed coordinate model and calibration evidence.
The curated spec home is
[`COORDINATE_MODEL.md`](COORDINATE_MODEL.md), with calibration evidence and the
smallest follow-on calibration procedure in
[`coordinate-calibration.md`](../evidence/W005_input_interaction_model_exploration/coordinate-calibration.md).
PAL, fixture, hit-test, trace, screenshot, visible-smoke, and comparison work
must cite those documents instead of inventing local coordinate fields.

Every coordinate-bearing event or artifact must name its coordinate space:

- `screen_pixels`: desktop pixels reported by the platform or screenshot tool.
- `window_rect`: outer PAL/top-level window rectangle in `screen_pixels`.
- `screenshot_pixels`: committed PNG/crop pixels, currently top-level window
  pixels for W003/W004 captures.
- `client_pixels`: window client-area pixel space.
- `form_logical`: W005 logical layout space, currently MSForms points for
  fixture geometry.
- `control_local`: logical point coordinates relative to the receiving
  control's bounds origin.
- `display_list_logical`: renderer/display-list logical units, using W005
  logical points unless a later spec explicitly retags a command.
- `msforms_event_args`: live MSForms event `Single` point arguments, preserved
  separately from derived OxForms coordinates.

W005 coordinate facts must also define:

- origin convention for every space;
- DPI/scale metadata;
- conversion ownership at each boundary;
- rounding policy;
- inclusive/exclusive rectangle bounds;
- raw diagnostic coordinate preservation;
- relation between MSForms mouse event arguments, fixture control bounds, and
  captured screenshots.

`COORDINATE_MODEL.md` defines the conversion ownership, DPI/scale rules,
rounding policy, half-open bounds convention, raw diagnostic preservation,
control-local conversion, screenshot relation, and MSForms event argument
calibration procedure. New trace schemas must avoid vague `x`/`y` or `pixels`
fields; use the named spaces above or explicitly mark a coordinate as
unresolved.

## 11. Portable PAL Input Versus Host-extension Input

Portable PAL input is the cross-platform contract for window, pointer,
keyboard, character, focus, activation, resize/DPI, timer, clipboard, and
service-completion events. It is value-typed, serializable, host-neutral, and
free of OxVba or Office object references.

Host-extension input is injected by a host/extension layer and must identify its
host namespace and capability. Excel `RefEdit` is the motivating case: range
selection updates, commit/cancel, host focus changes, and focus restoration are
normalized as `HostExtensionEvent` rows and host capability completions. Core
OxForms may request capabilities and consume normalized results, but it must not
hardcode Excel into the portable PAL or intrinsic FM20 model.

Replay must be possible without the live host by supplying the same normalized
host-extension event sequence.

## 12. Lifecycle And Pump Semantics Home

`oxforms-xvx.19` owns the detailed lifecycle, modal/modeless pump, activation,
close, query, hide, unload, and terminate model. The expected curated spec home
is [`LIFECYCLE_PUMP_MODEL.md`](LIFECYCLE_PUMP_MODEL.md), with evidence/status
notes under
[`lifecycle-pump-model.md`](../evidence/W005_input_interaction_model_exploration/lifecycle-pump-model.md).
That model is the required source for W005 fixture, reducer/effects, VBA event
dispatch, visible-smoke, trace/replay, and comparison lifecycle behavior.

Lifecycle state names should cover:

- `allocated`, `loading`, `loaded`, `initializing`, `initialized`, `hidden`;
- `showing_modeless`, `modeless_visible`, `showing_modal`, `modal_visible`;
- `active`, `deactivated`;
- `close_requested`, `query_close_pending`, `close_cancelled`;
- `hide_pending`, `unloading`, and `terminated`.

Pump terms should cover:

- `host_modeless_pump`;
- `modal_frame`;
- `nested_modal_depth`;
- `doevents_yield`;
- `vba_dispatch_reentrancy`;
- `host_callback_reentrancy`;
- `close_unload_cancellation`.

Lifecycle and pump transitions are represented as `UiEvent` inputs and
`Effects`, not as private host side channels. Unknown MSForms orderings remain
evidence-gated in `LIFECYCLE_PUMP_MODEL.md` until oracle fixture/capture beads
settle them.

## 13. Trace And Replay Obligations

Trace/replay is an architectural output of W005, not a debug afterthought.
The curated W005 artifact contract is
[`TRACE_REPLAY_SCHEMA.md`](TRACE_REPLAY_SCHEMA.md), with a machine-readable
schema at
[`trace-replay-artifact.v1.schema.json`](../schemas/trace-replay-artifact.v1.schema.json),
a synthetic schema sample at
[`synthetic-click-trace.v1.json`](../evidence/W005_input_interaction_model_exploration/trace-replay/synthetic-click-trace.v1.json),
and a validator at
[`Test-TraceReplaySchema.ps1`](../../tools/trace-replay/Test-TraceReplaySchema.ps1).
W005 artifacts must preserve these families:

- input script: the intended logical scenario, independent of a live desktop;
- normalized input event log: `UiEvent` rows and raw diagnostics;
- routing log: capture/focus/hit-test decisions where useful;
- reducer transition log: state summary before/after, not necessarily full
  state dumps;
- effects log: requested effects, effect completions, errors, and cancellations;
- VBA event log: event names, dispatch order, arguments, scalar ByRef
  mutations, mutable-helper-object mutations, and dispatch errors where
  applicable;
- invalidation log: dirty regions/subtrees and reasons;
- display-list references: command batch ids, checksums, and render target
  metadata;
- rendered evidence: optional hashes, screenshots, crops, or comparison inputs;
- oracle annotations: MSForms observation rows and uncertainty classifications;
- comparison report: observed match, known OxForms gap, oracle uncertainty, or
  out-of-scope classification.

Trace artifacts must avoid machine-local absolute paths except in command logs
where unavoidable. Serializable host-extension payloads should be sufficient for
replay without live Excel or another host.

## 14. Downstream Bead Contracts

- `oxforms-xvx.17` creates or updates the FM20 event fact home named in section
  9 and links the fact matrix from this spec.
- `oxforms-xvx.18` creates or updates the coordinate model home named in section
  10 and links coordinate conversion and calibration evidence.
- `oxforms-xvx.19` creates or updates the lifecycle/pump home named in section
  12 and links lifecycle, modal/modeless, activation, close, and pump evidence
  status.
- `oxforms-xvx.2` and `oxforms-xvx.3` use sections 9, 10, and 12 to build and
  capture MSForms oracle fixtures, including separate `msforms_event_args`,
  fixture point geometry, screenshot/window metadata, and raw input coordinates.
- `oxforms-xvx.4` uses sections 5, 10, and 11 to define the PAL normalized input
  contract.
- `oxforms-xvx.5` uses sections 4, 8, 10, 12, and 13 to define
  [`TRACE_REPLAY_SCHEMA.md`](TRACE_REPLAY_SCHEMA.md), the v1 schema, validator,
  and synthetic sample with explicit coordinate-space tags, event/effect/VBA
  dispatch ordering, lifecycle/pump rows, and reentrant nesting.
- `oxforms-xvx.6` places the W005 reducer/effects reference skeleton in
  [`../../crates/oxforms-core/src/lib.rs`](../../crates/oxforms-core/src/lib.rs).
  That crate consumes the `oxforms-pal` input contract but keeps control
  behavior out of the PAL. It is a Rust contract/reference/test spine, not a
  replacement for the VBA-first runtime doctrine.
- `oxforms-xvx.7` through `oxforms-xvx.13` use the reducer/effects, routing,
  probe, dispatch, smoke, replay, coordinate, and comparison vocabulary here.
  `oxforms-xvx.7` implements the first core routing subset in
  `crates/oxforms-core/src/lib.rs` and `crates/oxforms-core/src/probe.rs`:
  half-open `form_logical` hit-testing for Label/CommandButton/TextBox probe
  nodes, z-order and hidden/disabled filtering, focus transfer only to
  visible/enabled/focusable controls, capture-owner mouse move/up routing,
  CommandButton pressed-state invalidation, and deterministic Tab/Shift-Tab
  traversal by `tab_index` plus tree-order tie-break. This is a W005 probe
  model, not full MSForms tab-order, container, drag/drop, or modal parity.
- `oxforms-xvx.8` extends that core reducer/reference subset with keyboard
  routing: `KeyDown`/`KeyUp` effects to focused control/form targets,
  printable committed `CharacterInput` insertion into focused TextBox probes
  with `KeyPress`/`Change`/repaint effects, `Enter` default-button routing,
  `Escape` cancel-button routing, and `Alt+Character` caption accelerators
  derived from the first unescaped `&` in CommandButton probe captions. The
  effects preserve normalized key/modifier summaries and raw key diagnostics
  for later comparison. This is not a final MSForms keyboard ordering claim;
  IME/composition, dead keys, grapheme/selection behavior, clipboard shortcuts,
  accelerator ambiguity/display behavior, platform key identity parity, and
  `MSForms.ReturnInteger` helper mutation remain deferred.

If a downstream bead discovers a contradiction in this document, it should
update this spec in the same bead as the corrected behavior or file a focused
blocker before proceeding.

## 15. Open Questions

W005 should keep these open until the named fact/model/evidence beads resolve
or precisely block them:

- Remaining FM20 event unknowns after
  [`FM20_EVENT_FACTS.md`](FM20_EVENT_FACTS.md): per-probe exposure of generic
  `ControlEvents`, the `KeyAscii`/`KeyANSI` spelling discrepancy, exact
  mutation effects for `MSForms.Return*` helper arguments, and lifecycle DISPIDs
  not found in the captured FM20 source interfaces.
- Exact live MSForms mouse coordinate rounding and target-local relation to
  screenshot pixels under DPI scaling, pending the calibration procedure in
  [`COORDINATE_MODEL.md`](COORDINATE_MODEL.md).
- Event ordering for focus transfer, validation, `Enter`, `Exit`,
  `BeforeUpdate`, `AfterUpdate`, `Change`, `Click`, `DblClick`, keyboard events,
  default button activation, and cancel button activation.
- Whether platform double-click messages should be normalized as distinct
  `MouseDoubleClick` events, synthesized from down/up/click sequences, or both
  with explicit diagnostics.
- Live MSForms lifecycle order for create/load/initialize/show/activate,
  resize/deactivate, close/query/hide/unload/terminate, modal/modeless show,
  nested modal forms, and DoEvents-like yielding as detailed in
  [`LIFECYCLE_PUMP_MODEL.md`](LIFECYCLE_PUMP_MODEL.md).
- How much TextBox editing belongs in W005 beyond simple single-line character
  insertion, caret movement placeholders, selection placeholders, and `Change`.
- How clipboard shortcuts and `DataObject` behavior should be represented before
  full drag/drop and paste work.
- How IME, dead keys, composed text, and platform text services enter the
  portable model.
- How platform key identity, accelerator ambiguity/display state, and
  `ReturnInteger` helper mutation should be modeled once live MSForms keyboard
  ordering evidence is compared against OxForms traces.
- Exact host-extension payloads for Excel `RefEdit`, including host `Range`
  object return, reference string return, activation/focus restoration, and
  cancel behavior.
- Future trace serialization changes after
  [`TRACE_REPLAY_SCHEMA.md`](TRACE_REPLAY_SCHEMA.md) v1, including any runner
  extensions needed by `oxforms-xvx.12`.
