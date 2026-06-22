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
through form/control state, fires VBA events, invalidates rendering, and records
all of that as replayable evidence.

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

### 3. PAL Normalized Input Contract

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

### 4. Trace And Replay

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

### 5. Reducer And Effects

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

### 6. Hit-test, Focus, Capture, And Tab

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

### 7. Keyboard, Character Input, Accelerators, Default, Cancel

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

### 8. Probe Controls

The three W005 probe controls are interaction probes:

- `Label`: non-focus, mouse-routable, owner-drawn text using W004 evidence as
  input to future fidelity work.
- `CommandButton`: focusable, clickable, pressed/armed state, default/cancel,
  accelerator participation, invalidation.
- `TextBox`: focusable, minimal single-line text value mutation, `Change`
  event effect, caret/selection placeholder state.

Each probe should be marked as partial. The workset must avoid accidentally
declaring these controls implemented as full MSForms replacements.

### 9. OxVba Event Dispatch

OxForms should reuse the shared OxVba event spine. If W005 exposes gaps in
OxVba event delivery, the correct response is a precise blocker or handover,
not a private forms-only event mechanism.

The first useful event smoke should prove at least a documented subset of:

- `Click`;
- `Change`;
- focus enter/exit or a narrower focus event subset;
- keyboard/mouse event handlers if the event spine and fixture surface allow.

### 10. Windows Visible Input Smoke

Headless replay is the primary deterministic test path, but W005 also needs one
real platform input pump. The Windows visible smoke should route real
mouse/keyboard input through the same normalized path and emit trace/evidence.

This is evidence/test infrastructure, not a final host shell.

### 11. Programmatic Driving And Inspection

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

### 12. Differential Comparison

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
| `oxforms-xvx.1` | Define input interaction spec surface | `oxforms-54n` | Linked spec defines UiEvent/FormState/Effects/replay model. |
| `oxforms-xvx.2` | Build MSForms interaction oracle fixtures | `oxforms-54n`, `oxforms-xvx.1` | Repo-owned fixtures log representative Label/Button/TextBox events. |
| `oxforms-xvx.3` | Capture MSForms interaction event oracle evidence | `oxforms-54n`, `oxforms-xvx.2` | Live event evidence or concrete blocker exists. |
| `oxforms-xvx.4` | Define PAL normalized input contract | `oxforms-54n`, `oxforms-xvx.1` | PAL input contract is value-typed, serializable, host-neutral. |
| `oxforms-xvx.5` | Define trace/replay artifact schema and validators | `oxforms-54n`, `oxforms-xvx.1` | Schema and validation path exist for W005 traces. |
| `oxforms-xvx.6` | Implement reducer/effects skeleton | `oxforms-54n`, `oxforms-xvx.4`, `oxforms-xvx.5` | Deterministic reducer/effects skeleton and tests exist. |
| `oxforms-xvx.7` | Implement hit-test, focus, capture, and tab routing core | `oxforms-54n`, `oxforms-xvx.6` | Router tests cover hit/focus/capture/tab basics. |
| `oxforms-xvx.8` | Implement keyboard, char, accelerator, default, cancel routing | `oxforms-54n`, `oxforms-xvx.6` | Keyboard route tests cover chars, default, cancel, accelerators. |
| `oxforms-xvx.9` | Implement Label, CommandButton, TextBox interaction probes | `oxforms-54n`, `oxforms-xvx.7`, `oxforms-xvx.8` | Probe controls participate in input/reducer/render path. |
| `oxforms-xvx.10` | Wire VBA event dispatch smoke for interaction probes | `oxforms-54n`, `oxforms-xvx.9` | Probe effects reach VBA handlers or exact blocker exists. |
| `oxforms-xvx.11` | Add Windows visible input pump smoke | `oxforms-54n`, `oxforms-xvx.9`, `oxforms-xvx.10` | Real Windows input reaches normalized W005 path or blocker exists. |
| `oxforms-xvx.12` | Implement trace/replay runner and golden interaction evidence | `oxforms-54n`, `oxforms-xvx.5`, `oxforms-xvx.9`, `oxforms-xvx.10` | Deterministic W005 interaction script replays and emits evidence. |
| `oxforms-xvx.13` | Compare OxForms interaction trace to MSForms oracle | `oxforms-54n`, `oxforms-xvx.3`, `oxforms-xvx.12` | Observation report relates event oracle to OxForms trace. |
| `oxforms-xvx.15` | Explore Windows automation/inspection for input evidence | `oxforms-54n`, `oxforms-xvx.11` | Decision/prototype/blocker records public automation path. |
| `oxforms-xvx.14` | Closure review and next rollout | `oxforms-54n`, `oxforms-xvx.11`, `oxforms-xvx.13`, `oxforms-xvx.15` | Workset closes only with evidence, residual beads, and review. |

## Dependency Shape

After `oxforms-54n` closes, the first implementation bead is the interaction
spec. From there, oracle fixture work, PAL input contract work, and trace schema
work can proceed with limited coupling. Reducer/effects waits for PAL input and
trace schema. Hit/focus/capture and keyboard routing can run in parallel after
the reducer skeleton. Probe controls wait for both routing lanes. Event
dispatch, visible smoke, trace/replay, comparison, and closure form the final
evidence chain.

## Closure Condition

W005 closes only after all of these are true:

1. The input/interaction spec surface exists and records the W005 architecture
   decisions and open questions.
2. MSForms oracle fixtures and live event evidence exist, or concrete blocker
   beads explain why capture could not complete.
3. PAL/input contract, trace schema, reducer/effects skeleton, and router lanes
   are implemented or precisely blocked.
4. Label, CommandButton, and TextBox probes demonstrate the first interaction
   path without being mislabeled as complete controls.
5. A trace/replay artifact exists for at least one interaction script, or a
   concrete blocker explains the missing prerequisite.
6. A comparison artifact relates OxForms interaction traces to MSForms event
   oracle evidence, without claiming full parity.
7. Public Windows automation/inspection has been accepted, rejected, or filed
   as follow-up evidence infrastructure.
8. Any out-of-scope residuals are filed as beads before closure.

## Verification Shape

| Surface | Check |
|---|---|
| Docs/spec | read-through, path/link scan, `git diff --check` |
| Bead graph | `br dep cycles`, `br ready --json`, `br list --json` |
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
| Event ordering is guessed. | MSForms oracle fixtures and comparison artifacts are required. |
| Visible UI smoke becomes the only verification path. | Trace/replay is canonical; visible smoke is an additional platform check. |
| Public Windows automation is flaky. | Automation is test infrastructure only and must be accepted/rejected based on evidence. |
| OxVba event gaps are bypassed. | Gaps become blockers/handovers, not private forms-only event paths. |
| Probe controls get mistaken for complete controls. | Docs and bead acceptance label them as W005 probes and list missing parity. |
