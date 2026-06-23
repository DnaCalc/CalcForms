# W005 Input Interaction Model Exploration

Status: `OPEN`
Epic bead: `oxforms-xvx`
Depends on: `W004_text_label_oracle_pixels`
Owning plan bead: `oxforms-54n`

## Purpose

W005 is the first wide interaction workset. W002 proved that a VBA-authored
smoke path can cross the PAL seam and render a rectangle. W003 and W004 put
black-box Excel/MSForms rendering oracles in place, including the first
text-bearing `Label` pixels. The next durable step is not another tiny render
calibration. The next step is to settle how OxForms receives input, routes it
through form/control state, names FM20 event signatures and argument facts,
tracks coordinate spaces, handles form lifecycle/pump effects, fires VBA events,
invalidates rendering, and records all of that as replayable evidence.

The W005 loop is:

```text
real or synthetic input
  -> normalized UiEvent
  -> hit-test / focus / capture / keyboard routing
  -> reducer state transition
  -> explicit Effects
  -> OxVba/VBA event dispatch where required
  -> invalidation + display-list update
  -> trace/replay and comparison evidence
```

The workset is intentionally broad. It explores the full interaction spine
before full control breadth begins. The first controls are probes, not complete
implementations:

- `Label` for non-focus owner-drawn text and mouse event routing.
- `CommandButton` for focus, pressed state, click, accelerators, default, and
  cancel behavior.
- `TextBox` for focus, keyboard/character input, minimal text mutation,
  selection/caret placeholders, and `Change`/validation ordering.

## Why This Scope

Input and event behavior is a compatibility surface as important as pixels.
The top-level spec already names the hard parts: hit-testing, focus/tab,
capture, keyboard routing, accelerators, default/cancel buttons,
focus-to-validation-to-exit ordering, drag/drop, modal/modeless event pumping,
and trace/replay. If those are guessed locally control-by-control, later work
will accrete incompatible shortcuts. W005 exists to make the interaction model
boring, explicit, and testable before the control set expands.

The most dangerous hidden assumptions are event signatures, coordinate origins,
and lifecycle/message-pump behavior. W005 therefore treats those as separate
fact/model lanes before fixture, reducer, dispatch, and visible-smoke work
depends on them.

This is an exploration workset, but not a hand-wavy one. It should leave behind
spec text, code or explicit blockers, Office/MSForms observations, replayable
OxForms traces, and comparison artifacts.

## Non-goals

- No full MSForms control set.
- No complete `Label`, `CommandButton`, or `TextBox` parity claim.
- No complete `.frm` / `.frx` persistence.
- No full `UserForm.Show` parity beyond the smoke/probe surface needed by W005.
- No non-Windows backend implementation.
- No pixel-perfect rendering parity claim.
- No full TextBox editing model: IME, dead keys, rich selection behavior,
  scrolling, password mode, multiline, and clipboard can be follow-up work.
- No complete drag/drop `DataObject` implementation.
- No forms-only event runtime that bypasses the shared OxVba event path.
- No private Office or Windows internals.

## Clean-room Boundary

Allowed:

- public specs and type-library metadata;
- repo-owned fixtures and scripts;
- public Excel/VBIDE automation;
- public Windows APIs, including public input/accessibility/automation APIs for
  test infrastructure;
- black-box Office/MSForms behavior observations;
- committed logs, traces, manifests, screenshots, hashes, and comparison
  artifacts.

Excluded:

- Office binary reverse engineering;
- private implementation details;
- decompilation/disassembly;
- broad event-order rules copied from non-public sources.

## Grounding

Primary spec anchors:

- `docs/FORMS_LIBRARY_SPEC_AND_PLAN.md` decisions D1, D7, D8, D10, D11, and
  D12.
- Section 4.3, reducer state model.
- Section 4.5, trace/replay and evidence architecture.
- Sections 5.3 and 5.4, event/control surface planning.
- Section 6.2, PAL contract surface, especially input and services.
- Section 8, rendering and input model.
- Section 9, runtime integration with the OxVba VM.
- Section 10.2, fidelity strategy.
- Section 11/P2, reducer vertical slice.

Existing evidence anchors:

- W003 Excel/MSForms blank `Label` oracle capture.
- W004 text-bearing `Label` oracle capture:
  `docs/evidence/W004_text_label_oracle_pixels/captures/rectangle-label-text-20260622T191013Z/`.

## Architecture Lanes

### 1. Interaction Spec Surface

W005 should split or add a focused input/interaction spec, expected at:

```text
docs/specs/INPUT_INTERACTION_MODEL.md
```

That spec should define:

- normalized `UiEvent` families;
- interaction-relevant `FormState` fields;
- explicit `Effects`;
- event/effect ordering and reentrancy principles;
- coordinate spaces and conversion expectations;
- trace/replay artifact obligations;
- open questions and deferred surfaces.

### 2. MSForms Event Oracles

W005 needs real MSForms observations for event order and input behavior. The
first fixture should be small but interaction-rich:

- one `UserForm`;
- one `Label`;
- one `CommandButton`;
- one `TextBox`;
- code-behind that logs event names, sequence numbers, arguments where
  available, active/focused control state, text values, key codes/chars, mouse
  coordinates/buttons, and validation-related events where available.

The goal is not exhaustive event parity. The goal is to create a measured event
corpus that informs the reducer/router design and later differential tests.

Current fixture input:
[`../../fixtures/office-oracle/excel-msforms/userforms/interaction-events/`](../../fixtures/office-oracle/excel-msforms/userforms/interaction-events/)
from `oxforms-xvx.2`. Modeless live MSForms event evidence from `oxforms-xvx.3`
lives under
[`../evidence/W005_input_interaction_model_exploration/captures/interaction-events-20260623T004914Z/`](../evidence/W005_input_interaction_model_exploration/captures/interaction-events-20260623T004914Z/).
The earlier `interaction-events-20260623T001238Z` run is retained only as
superseded diagnostic evidence for the pre-repair coordinate bug.
Modal-show capture remains tracked by `oxforms-xvx.20`.

### 3. FM20 Event Signature And Event-Argument Facts

W005 needs a small, cited fact surface before fixtures, traces, and dispatch
code name events. The fact matrix should record:

- event names and source/control applicability;
- DISPIDs where public type-library metadata provides them;
- argument names, types, and `ByRef` status;
- mutable argument semantics for key/mouse/validation events where observed;
- coordinate units/origins for mouse event arguments;
- which facts are public metadata, black-box observation, assumption, or
  unknown;
- the W005 probe subset versus broader FM20 events.

This lane is not runtime code. It prevents later beads from inventing event
signatures in fixture macros, trace schemas, or OxVba dispatch glue.

Current output: [`../specs/FM20_EVENT_FACTS.md`](../specs/FM20_EVENT_FACTS.md),
with raw FM20 type-library evidence under
[`../evidence/W005_input_interaction_model_exploration/`](../evidence/W005_input_interaction_model_exploration/).

### 4. Coordinate Systems And Calibration

W005 should name every coordinate space that crosses an architectural boundary:

- screen pixels;
- window rectangles;
- client pixels;
- form logical space;
- control-local event coordinates;
- PAL/display-list logical units;
- MSForms point/twip-derived values where relevant;
- screenshot crop coordinates and DPI/scale metadata.

The model must state origin conventions, rounding policy, inclusive/exclusive
bounds, raw diagnostic coordinate preservation, and how MSForms event arguments
relate to fixture bounds and screenshots. Later PAL, hit-test, fixture, replay,
visible-smoke, and comparison beads should all use this vocabulary.

Current output: [`../specs/COORDINATE_MODEL.md`](../specs/COORDINATE_MODEL.md),
with calibration evidence and the required follow-on procedure in
[`../evidence/W005_input_interaction_model_exploration/coordinate-calibration.md`](../evidence/W005_input_interaction_model_exploration/coordinate-calibration.md).
The model defines `screen_pixels`, `window_rect`, `screenshot_pixels`,
`client_pixels`, `form_logical`, `control_local`, `display_list_logical`, and
`msforms_event_args`, plus DPI/scale, rounding, half-open bounds,
control-local conversion, raw diagnostic preservation, screenshot relation, and
the MSForms event-argument calibration procedure. Modeless event-argument rows
exist in the `oxforms-xvx.3` capture; modal-show calibration remains tracked by
`oxforms-xvx.20`.

### 5. Form Lifecycle, Modal Pump, And Close/Activation

W005 must make enough lifecycle behavior explicit that it does not get buried
inside a Windows smoke host or VBA dispatch workaround. The model should cover:

- create/load/initialize and show;
- modal versus modeless pump responsibilities;
- activate/deactivate and active form state;
- close request, query close/cancel, hide, unload, and terminate;
- reentrant input and OxVba event dispatch ordering;
- DoEvents-like yielding and nested modal forms as open questions if not yet
  implemented.

The W005 implementation subset can stay small, but the architecture must leave
a named place for lifecycle effects and oracle observations.

Current output:
[`../specs/LIFECYCLE_PUMP_MODEL.md`](../specs/LIFECYCLE_PUMP_MODEL.md), with
evidence/status notes in
[`../evidence/W005_input_interaction_model_exploration/lifecycle-pump-model.md`](../evidence/W005_input_interaction_model_exploration/lifecycle-pump-model.md).
The model defines lifecycle state, modal/modeless pump terms, lifecycle
`UiEvent`/`Effect` families, close/query/hide/unload separation, reentrancy
rules, W005 probe subset, and downstream fixture/reducer/dispatch/visible-smoke
requirements. It records the modeless lifecycle rows captured by
`oxforms-xvx.3` and the modal-show residual tracked by `oxforms-xvx.20`.

### 6. PAL Normalized Input Contract

The PAL input boundary must remain host/runtime independent, flat,
value-typed, and serializable. The contract should cover:

- mouse move/down/up/double-click/wheel;
- key down/up;
- character input;
- focus in/out and activation/deactivation;
- resize and DPI change;
- close request;
- timer and service completions;
- coordinates with explicit origin;
- modifiers, buttons, click count, wheel delta, and diagnostic raw codes where
  useful.

The PAL does not decide control behavior. It normalizes platform events and
passes them to the reducer path.

Current output: [`../../crates/oxforms-pal/src/input.rs`](../../crates/oxforms-pal/src/input.rs)
defines the W005 `UiEvent` schema/version and host-neutral value types for
coordinates, mouse, keyboard, character input, focus, activation, close, timer,
clipboard, service completion, resize/DPI, lifecycle, and generic
host-extension event rows. Runtime adapter logic remains outside `oxforms-pal`.

### 7. Trace And Replay

Trace/replay is a required output, not a debugging convenience. W005 artifacts
should be able to record:

- input scripts;
- normalized input events;
- reducer transition summaries;
- effects requested and completed;
- fired VBA event names/order/arguments;
- invalidated regions/subtrees;
- display-list or render artifact references;
- hashes/screenshots where useful.

The same conceptual script should be able to run against:

- real MSForms as an oracle, where practical;
- OxForms headless/replay path;
- OxForms visible Windows smoke path.

Current output: [`../specs/TRACE_REPLAY_SCHEMA.md`](../specs/TRACE_REPLAY_SCHEMA.md),
with the machine-readable schema at
[`../schemas/trace-replay-artifact.v1.schema.json`](../schemas/trace-replay-artifact.v1.schema.json),
the schema-only sample at
[`../evidence/W005_input_interaction_model_exploration/trace-replay/synthetic-click-trace.v1.json`](../evidence/W005_input_interaction_model_exploration/trace-replay/synthetic-click-trace.v1.json),
and the validator at
[`../../tools/trace-replay/Test-TraceReplaySchema.ps1`](../../tools/trace-replay/Test-TraceReplaySchema.ps1).
This output defines artifact shape and validation only; the full replay runner
and golden interaction evidence remain scoped to `oxforms-xvx.12`.

### 8. Reducer And Effects

The reducer shape remains:

```text
FormState + UiEvent -> FormState + Effects + RenderInvalidation
```

W005 should implement or explicitly block the first skeleton with:

- focus owner;
- capture owner;
- hover/pressed state;
- active/default/cancel button markers;
- text value and caret/selection placeholder state for the TextBox probe;
- validation state;
- dirty region or dirty subtree markers;
- effect queue and sequence numbers.

Current output: [`../../crates/oxforms-core/src/lib.rs`](../../crates/oxforms-core/src/lib.rs)
contains the W005 host-neutral reducer/model reference skeleton and tests. It
depends on the `oxforms-pal` normalized input/coordinate contract but is not
owned or re-exported by the PAL. This Rust layer is a contract/reference/test
spine and possible future hot-path migration target; the durable runtime
doctrine remains VBA-first.

### 9. Hit-test, Focus, Capture, And Tab

The router should make these decisions explicit:

- which control receives a mouse event;
- how z-order, visibility, enabled state, and bounds affect hit-testing;
- when mouse capture starts and ends;
- what receives move/up events during capture;
- how focus transfers;
- how Tab and Shift-Tab traverse focusable controls;
- how focus changes request invalidation and event effects.

Frame, MultiPage, TabStrip, nested containers, and drag/drop can be deferred,
but the model should leave room for them.

Current implementation from `oxforms-xvx.7`:

- `crates/oxforms-core/src/probe.rs` owns a small serializable probe control
  tree for `Label`, `CommandButton`, and `TextBox` shaped nodes, re-exported
  through `crates/oxforms-core/src/lib.rs`. This remains in the core
  reducer/reference layer; `oxforms-pal` stays only the normalized input/render
  contract surface.
- Hit-testing consumes `form_logical` coordinates and uses
  [`../specs/COORDINATE_MODEL.md`](../specs/COORDINATE_MODEL.md) half-open
  bounds: `left <= x < left + width` and `top <= y < top + height`.
- Hidden or disabled controls are excluded from hit-testing and Tab traversal.
  For overlapping controls, higher `z_order` wins; equal `z_order` breaks by
  later tree order. Nested containers, `Frame`, `MultiPage`, `TabStrip`, and
  drag/drop remain deferred.
- Mouse down routes to the hit control or form background, transfers focus only
  to visible/enabled/focusable controls, starts mouse capture for the routed
  target, and marks a pressed visual state only for `CommandButton` probes.
  Mouse move/up route to the capture owner while capture is active, including
  when the pointer is outside the owner bounds.
- Tab and Shift-Tab traverse only visible/enabled/focusable controls with
  `tab_stop=true`, ordered by `tab_index` with tree order as tie-breaker. This
  is a W005 deterministic subset, not full MSForms `TabIndex` parity.
- Focus changes and pressed-state changes emit explicit repaint invalidations
  and effects. Unit tests cover half-open coordinate boundaries, z-order hit
  selection, hidden/disabled exclusion, focus next/previous, capture during
  press/drag, and reducer trace row serialization.
- Live MSForms modeless evidence for this probe family is under
  [`../evidence/W005_input_interaction_model_exploration/captures/interaction-events-20260623T004914Z/`](../evidence/W005_input_interaction_model_exploration/captures/interaction-events-20260623T004914Z/).
  That capture observes Label/Button/TextBox mouse/focus/key rows and records a
  label drag outside bounds, but it is not a full ordering or modal parity
  oracle. Modal evidence remains tracked by `oxforms-xvx.20`.

### 10. Keyboard, Character Input, Accelerators, Default, Cancel

The keyboard lane should cover:

- key down/up versus character input;
- printable text into the focused TextBox probe;
- Enter routed to a default command where applicable;
- Escape routed to a cancel command where applicable;
- accelerator keys from captions such as `&OK`;
- enough diagnostics for platform key-code uncertainty.

W005 should explicitly defer IME, dead keys, rich editing, clipboard shortcuts,
and full TextBox behavior unless the simplest durable implementation naturally
includes part of them.

Current implementation from `oxforms-xvx.8`:

- `crates/oxforms-core/src/lib.rs` consumes `oxforms-pal` `KeyDown`, `KeyUp`,
  and `CharacterInput` rows in the reducer/reference layer. `oxforms-pal`
  remains only the normalized input/render contract and does not own routing or
  control behavior.
- `KeyDown` and `KeyUp` emit explicit `FireVbaEvent` effects to the focused
  control or the form target, with normalized key/modifier summaries and raw
  virtual-key/scancode/native-code diagnostics preserved as effect arguments.
  `MSForms.ReturnInteger` helper mutation is represented as deferred metadata;
  no helper-object mutation is executed in W005.
- `CharacterInput` represents committed printable text. For a visible/enabled
  focused `TextBox` probe it inserts the text at the placeholder caret,
  advances the caret by byte length for this ASCII-oriented subset, marks the
  text state dirty, and emits `KeyPress`, `Change`, and repaint effects.
  Character input to non-TextBox focus owners and control characters is ignored
  after recording keyboard diagnostics.
- `Enter` routes to `FormState.default_button` when it names a visible/enabled
  `CommandButton` probe; `Escape` routes to `FormState.cancel_button` under the
  same constraints. Routing emits a `Click` effect and pressed-state repaint
  invalidation; the keyboard pressed state is cleared on `KeyUp`.
- Accelerator routing is derived from probe captions using the first unescaped
  ampersand mnemonic, for example `&OK`. The W005 subset activates the first
  visible/enabled `CommandButton` whose caption mnemonic matches an
  `Alt+Character` `KeyDown`; ambiguity diagnostics and full platform mnemonic
  behavior are deferred.
- Unit tests cover key down/up, printable char input, TextBox mutation,
  non-TextBox/control-character deferral, Enter default routing, Escape cancel
  routing, caption accelerator routing, serialized key diagnostics, and
  trace/effect rows.
- Known gaps remain: IME/composition, dead keys, grapheme-aware selection and
  caret movement, clipboard shortcuts, full TextBox editing, accelerator
  ambiguity/display rules, platform key identity parity, ReturnInteger helper
  mutation, and final MSForms keyboard/default/cancel event-order parity.

### 11. Probe Controls

The three W005 probe controls are interaction probes:

- `Label`: non-focus, mouse-routable, owner-drawn text using W004 evidence as
  input to future fidelity work.
- `CommandButton`: focusable, clickable, pressed/armed state, default/cancel,
  accelerator participation, invalidation.
- `TextBox`: focusable, minimal single-line text value mutation, `Change`
  event effect, caret/selection placeholder state.

Each probe should be marked as partial. The workset must avoid accidentally
declaring these controls implemented as full MSForms replacements.

Current implementation from `oxforms-xvx.9`:

- `crates/oxforms-core/src/lib.rs` and `crates/oxforms-core/src/probe.rs`
  keep the W005 probe behavior in the core reducer/reference layer. The PAL
  remains the normalized input and primitive render contract surface only.
- `Label` probes are visible/enabled hit-test participants, do not take focus,
  route `MouseDown`/`MouseUp`/`Click` effects through capture, and expose their
  caption as a text draw command in the core-owned probe display reference.
- `CommandButton` probes are focusable, participate in Tab traversal,
  mouse/default/cancel/accelerator activation, pressed-state invalidation, and
  `Click` effect generation. The probe display reference records normal versus
  pressed face state, caption text, border, and focus indication.
- `TextBox` probes are focusable, accept committed printable
  `CharacterInput`, update a single-line text value at the placeholder caret,
  emit `KeyPress`/`Change`/repaint effects, and record text, focus, and caret
  placeholder commands in the display reference.
- `build_probe_display_list` emits a serializable W005 reference display list
  with fill, border, text, focus, and caret commands for trace/replay evidence.
  `build_probe_pal_smoke_display_list` projects visible probe faces into the
  existing PAL `FillRect` display-list contract for visual smoke only; text is
  not rendered by the PAL smoke projection.
- Tests cover Label mouse click without focus transfer, TextBox focus and char
  input, CommandButton click activation, default/cancel/accelerator activation
  inherited from `oxforms-xvx.8`, invalidation, trace rows, and display-list
  emission.
- Known gaps remain: full MSForms property surfaces, final event ordering,
  validation/Enter/Exit/BeforeUpdate/AfterUpdate parity, full Label visual
  parity from W004 pixels, complete button theming, full TextBox editing,
  selection, IME/composition, dead keys, scrolling, password mode, multiline,
  clipboard, drag/drop, and real OxVba event dispatch.

### 12. OxVba Event Dispatch

OxForms should reuse the shared OxVba event spine. If W005 exposes gaps in
OxVba event delivery, the correct response is a precise blocker or handover,
not a private forms-only event mechanism.

The first useful event smoke should prove at least a documented subset of:

- `Click`;
- `Change`;
- focus enter/exit or a narrower focus event subset;
- keyboard/mouse event handlers if the event spine and fixture surface allow.

Current output from `oxforms-xvx.10`:

- `crates/oxforms-oxvba-adapter/src/event_dispatch.rs` translates
  `oxforms-core` `EffectKind::FireVbaEvent` requests into traceable dispatch
  requests for the adapter layer. It does not execute VBA directly and does not
  create a forms-only runtime.
- `crates/oxforms-oxvba-adapter/tests/oxvba_w005_event_dispatch_smoke.rs`
  replays a small W005 reducer scenario through `MouseDown`, `MouseUp`,
  `Click`, `KeyDown`, `KeyPress`, `Change`, and `KeyUp` effects. The smoke
  invokes a VBA class method that raises a normal `Dispatched` event; an
  attached `WithEvents` handler records the original W005 event names, targets,
  order, and serialized arguments.
- Evidence is recorded at
  [`../evidence/W005_input_interaction_model_exploration/event-dispatch-smoke.v1.json`](../evidence/W005_input_interaction_model_exploration/event-dispatch-smoke.v1.json).
  The smoke preserves mouse `Button`/`Shift`/`X`/`Y` metadata from reducer
  mouse effects, preserves keyboard `key`/normalized `modifiers`/repeat/raw
  diagnostics for `KeyDown`/`KeyUp`, and preserves `KeyPress` mutable-helper
  placeholder metadata in dispatch trace rows. The smoke intentionally has no
  public event-specific OxVba variant converter; native FM20 keyboard
  signatures such as `KeyDown(KeyCode, Shift)` remain blocked with native
  FM20-named event dispatch.
- Native FM20-named event procedures such as a direct `Click`/`MouseDown`
  source remain blocked in the current OxVba package-session shape; the exact
  handover is
  [`../handovers/HANDOVER_OxVba_w005_fm20_event_raise.md`](../handovers/HANDOVER_OxVba_w005_fm20_event_raise.md).
  The generic `Dispatched` carrier is test infrastructure only and must not
  become the durable forms event runtime.

### 13. Windows Visible Input Smoke

Headless replay is the primary deterministic test path, but W005 also needs one
real platform input pump. The Windows visible smoke should route real
mouse/keyboard input through the same normalized path and emit trace/evidence.

This is evidence/test infrastructure, not a final host shell.

Current output from `oxforms-xvx.11`:

- `crates/oxforms-core/examples/w005_visible_input_smoke.rs` opens the W005
  probe surface with a Windows native `minifb` window and routes platform mouse,
  key, character, activation/show/resize, and close signals into
  `oxforms-pal` `UiEvent` rows consumed by `oxforms-core::reduce`.
- `tools/w005-visible-input/Invoke-W005VisibleInputSmoke.ps1` is the evidence
  driver. It builds the example, captures window metadata/screenshot with the
  existing public Windows capture helper, drives public `user32` mouse input,
  `System.Windows.Forms.SendKeys` text input, and a public `WM_CLOSE`, then
  validates the emitted trace.
- Evidence lives at
  [`../evidence/W005_input_interaction_model_exploration/captures/visible-input-smoke-20260623T035500Z/`](../evidence/W005_input_interaction_model_exploration/captures/visible-input-smoke-20260623T035500Z/).
  The trace records 18 normalized input rows, 43 reducer effects, `Click`,
  `KeyPress`, `Change`, and `QueryClose` effects, final TextBox text `ab`,
  window screenshot, rendered frame artifact, command logs, manifest, and
  checksums.
- The smoke uses a deliberate test projection where unscaled `minifb`
  `client_pixels` map 1:1 to `form_logical`; the driver records real
  `screen_pixels` and derived `client_pixels` in `visible-input-actions.json`.
  This is coordinate-translation evidence for the W005 path, not an MSForms
  DPI/chrome parity claim.
- The visible smoke remains auxiliary evidence/test infrastructure. Headless
  reducer tests and the `oxforms-xvx.12` trace/replay runner remain the
  deterministic verification path.

### 14. Programmatic Driving And Inspection

W005 should decide whether public Windows tooling can help drive or inspect
interaction scenarios:

- Windows UI Automation;
- `SendInput`;
- accessibility APIs;
- active-window/focus inspection;
- screenshot/window metadata helpers.

This lane must remain outside runtime architecture. It may become evidence
infrastructure if it proves stable enough, but trace/replay remains the
canonical deterministic path.

### 15. Differential Comparison

The final comparison artifact should relate MSForms event oracle evidence to
OxForms trace/replay evidence. It should classify differences as:

- implemented match;
- known OxForms gap;
- oracle uncertainty;
- out of W005 scope;
- follow-up bead filed.

It is an observation artifact, not a final pass/fail parity oracle.

## Bead Plan

| Bead | Purpose | Depends on | Acceptance Summary |
|---|---|---|---|
| `oxforms-54n` | Define W005 workset and rollout | W004 closed | Workset doc, register row, and bead graph exist. |
| `oxforms-xvx.16` | Fresh-eyes review workset and bead graph | `oxforms-54n` | Plan gaps are corrected before implementation starts. |
| `oxforms-xvx.1` | Define input interaction spec surface | `oxforms-54n`, `oxforms-xvx.16` | Linked spec defines UiEvent/FormState/Effects/replay model. |
| `oxforms-xvx.17` | Establish FM20 event signature and argument facts | `oxforms-54n`, `oxforms-xvx.1` | Event fact matrix names signatures/arguments/unknowns for W005 probes. |
| `oxforms-xvx.18` | Define coordinate model and calibration evidence | `oxforms-54n`, `oxforms-xvx.1` | Coordinate spaces, units, origins, DPI, and calibration path are explicit. |
| `oxforms-xvx.19` | Define form lifecycle and modal pump model | `oxforms-54n`, `oxforms-xvx.1` | Lifecycle, show/pump, activation, close, and reentrancy model exists. |
| `oxforms-xvx.2` | Build MSForms interaction oracle fixtures | `oxforms-54n`, `oxforms-xvx.1`, `oxforms-xvx.17`, `oxforms-xvx.18`, `oxforms-xvx.19` | Repo-owned fixtures log representative Label/Button/TextBox events. |
| `oxforms-xvx.3` | Capture MSForms interaction event oracle evidence | `oxforms-54n`, `oxforms-xvx.2` | Modeless live event evidence or concrete blocker exists. |
| `oxforms-xvx.20` | Capture modal MSForms interaction oracle evidence | `oxforms-xvx`, `oxforms-xvx.3` | Modal event evidence or precise blocker exists without altering modeless capture evidence. |
| `oxforms-xvx.4` | Define PAL normalized input contract | `oxforms-54n`, `oxforms-xvx.1`, `oxforms-xvx.18` | PAL input contract is value-typed, serializable, host-neutral. |
| `oxforms-xvx.5` | Define trace/replay artifact schema and validators | `oxforms-54n`, `oxforms-xvx.1`, `oxforms-xvx.17`, `oxforms-xvx.18` | Schema, validation path, and synthetic schema sample exist for W005 traces. |
| `oxforms-xvx.6` | Implement reducer/effects skeleton | `oxforms-54n`, `oxforms-xvx.4`, `oxforms-xvx.5`, `oxforms-xvx.19` | Deterministic reducer/effects skeleton and tests exist. |
| `oxforms-xvx.7` | Implement hit-test, focus, capture, and tab routing core | `oxforms-54n`, `oxforms-xvx.6`, `oxforms-xvx.18` | Router tests cover hit/focus/capture/tab basics. |
| `oxforms-xvx.8` | Implement keyboard, char, accelerator, default, cancel routing | `oxforms-54n`, `oxforms-xvx.6` | Keyboard route tests cover chars, default, cancel, accelerators. |
| `oxforms-xvx.9` | Implement Label, CommandButton, TextBox interaction probes | `oxforms-54n`, `oxforms-xvx.7`, `oxforms-xvx.8` | Probe controls participate in input/reducer/render path. |
| `oxforms-xvx.10` | Wire VBA event dispatch smoke for interaction probes | `oxforms-54n`, `oxforms-xvx.9`, `oxforms-xvx.17`, `oxforms-xvx.19` | Probe effects reach VBA handlers or exact blocker exists. |
| `oxforms-xvx.11` | Add Windows visible input pump smoke | `oxforms-54n`, `oxforms-xvx.9`, `oxforms-xvx.10`, `oxforms-xvx.18`, `oxforms-xvx.19` | Real Windows input reaches normalized W005 path or blocker exists, with coordinate translation evidence. |
| `oxforms-xvx.12` | Implement trace/replay runner and golden interaction evidence | `oxforms-54n`, `oxforms-xvx.5`, `oxforms-xvx.9`, `oxforms-xvx.10`, `oxforms-xvx.18` | Deterministic W005 interaction script replays and emits coordinate-tagged evidence. |
| `oxforms-xvx.13` | Compare OxForms interaction trace to MSForms oracle | `oxforms-54n`, `oxforms-xvx.3`, `oxforms-xvx.12`, `oxforms-xvx.18` | Observation report relates event oracle to OxForms trace and classifies coordinate differences using the shared vocabulary. |
| `oxforms-xvx.15` | Explore Windows automation/inspection for input evidence | `oxforms-54n`, `oxforms-xvx.11` | Decision/prototype/blocker records public automation path. |
| `oxforms-xvx.14` | Closure review and next rollout | `oxforms-54n`, `oxforms-xvx.11`, `oxforms-xvx.13`, `oxforms-xvx.15` | Workset closes only with evidence, residual beads, and review. |

## Dependency Shape

After `oxforms-xvx.16` closes, the first implementation bead is the interaction
spec. From there, event signature facts, coordinate model/calibration, and
lifecycle/pump model work can proceed in parallel. Oracle fixture work waits for
those facts so it logs the right things. PAL input waits for coordinates. Trace
schema waits for event and coordinate facts. Reducer/effects waits for PAL,
trace schema, and lifecycle. Hit/focus/capture and keyboard routing can run in
parallel after the reducer skeleton, with hit/focus also tied directly to the
coordinate model. Probe controls wait for both routing lanes. Event dispatch,
visible smoke, trace/replay, comparison, automation inspection, and closure form
the final evidence chain. The trace/replay runner, visible smoke, and comparison
also cite the coordinate model directly so screenshot/input translation,
coordinate-tagged replay evidence, and coordinate-difference classification do
not rely only on transitive dependencies.

## Closure Condition

W005 closes only after all of these are true:

1. The input/interaction spec surface exists and records the W005 architecture
   decisions and open questions.
2. FM20/MSForms event signature facts exist for the W005 probe subset, or a
   concrete blocker explains the missing public evidence/tooling.
3. Coordinate model/calibration evidence exists for W005 input and screenshot
   comparison paths, or a concrete blocker explains the missing prerequisite.
4. Lifecycle/modal pump semantics for the W005 subset are modeled, evidenced,
   or precisely blocked.
5. MSForms oracle fixtures and live event evidence exist, or concrete blocker
   beads explain why capture could not complete.
6. PAL/input contract, trace schema, reducer/effects skeleton, and router lanes
   are implemented or precisely blocked.
7. Label, CommandButton, and TextBox probes demonstrate the first interaction
   path without being mislabeled as complete controls.
8. A trace/replay artifact exists for at least one interaction script, or a
   concrete blocker explains the missing prerequisite.
9. A comparison artifact relates OxForms interaction traces to MSForms event
   oracle evidence, without claiming full parity.
10. Public Windows automation/inspection has been accepted, rejected, or filed
   as follow-up evidence infrastructure.
11. Any out-of-scope residuals are filed as beads before closure.

## Verification Shape

| Surface | Check |
|---|---|
| Docs/spec | read-through, path/link scan, `git diff --check` |
| Bead graph | `br dep cycles`, `br ready --json`, `br list --json` |
| Event facts | public metadata/evidence citation review; unknowns separated from facts |
| Coordinates/lifecycle | calibration/lifecycle notes reviewed against oracle and smoke paths |
| Rust crates | `cargo fmt --check`, `cargo clippy --workspace -- -D warnings`, `cargo test --workspace` where touched |
| VBA/OxVba | targeted OxVba fixture compile/run where available |
| Office/MSForms oracle | fixture dry run, live Excel capture where possible, checksum validation |
| Trace/replay | schema validator, replay runner, golden artifact check |
| Windows input smoke | targeted visible smoke command, logs/screenshots/traces |
| Comparison artifact | manifest/report validator if present |

## Risks And Controls

| Risk | Control |
|---|---|
| W005 becomes too tiny and only calibrates text. | Scope explicitly covers input, focus, capture, keyboard, events, trace/replay, oracles, and probes. |
| W005 becomes too broad to close. | Probe controls are partial, and closure requires blockers/follow-up beads for deferred surfaces. |
| Agents implement local event shortcuts. | Spec surface and reducer/effects contract land before controls. |
| Event signatures or ordering are guessed. | FM20 event fact matrix, MSForms oracle fixtures, and comparison artifacts are required. |
| Coordinate origins drift between PAL, MSForms, screenshots, and hit-testing. | Coordinate model and calibration evidence land before dependent implementation beads. |
| Lifecycle and modal pump behavior hides in a smoke host. | Lifecycle/pump model lands before reducer, dispatch, and visible-smoke beads. |
| Visible UI smoke becomes the only verification path. | Trace/replay is canonical; visible smoke is an additional platform check. |
| Public Windows automation is flaky. | Automation is test infrastructure only and must be accepted/rejected based on evidence. |
| OxVba event gaps are bypassed. | Gaps become blockers/handovers, not private forms-only event paths. |
| Probe controls get mistaken for complete controls. | Docs and bead acceptance label them as W005 probes and list missing parity. |
