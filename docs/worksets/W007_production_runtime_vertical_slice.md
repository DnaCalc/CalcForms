# W007 Production Runtime Vertical Slice

Status: `OPEN`
Epic bead: `oxforms-4pn`
Depends on: `W005_input_interaction_model_exploration`; completed W006
runtime/control spine beads `oxforms-0a0.1`, `oxforms-0a0.3`, and
`oxforms-0a0.4`; W005 visible smoke bead `oxforms-xvx.11`
Planning/bead-graph bead: `oxforms-4pn.1`

## Purpose

W007 creates the first runnable production-shaped OxForms vertical slice. An
OxVba project should load the OxForms VBA library, create a small form with
`Label`, `TextBox`, and `CommandButton` controls, show it in a real Windows
window, accept text and button input, run native VBA event handlers, and update
a `Label` from VBA code.

This is not a full MSForms parity workset. It is the first slice where the
durable runtime shape is visible end to end:

```text
VBA startup and form/control objects
  -> OxVba class construction and native RaiseEvent/WithEvents dispatch
  -> OxForms runtime/effect runner
  -> oxforms-core reducer, effects, and render invalidation (consumed by Re-render)
  -> PAL/window backend: input, window, and Repaint (Scene -> pixels)
  -> trace/evidence
```

The selected entry shape is **Tiny Bootstrap**. A minimal native executable may
load the OxVba project, configure runtime services, invoke the VBA entrypoint,
run the platform loop (the backend-owned OS pump; see
`docs/specs/RENDERING_ARCHITECTURE.md` §16.3), and exit when the runtime reports
no open forms or a fatal diagnostic. It must not contain form or control behavior.

## Start Reading

Before changing W007 behavior, read:

- `CHARTER.md` sections 1, 3, 3.1, 4, 5, and 7.
- `OPERATIONS.md` sections 4, 5, 6, 7, and 10.
- `docs/worksets/W005_input_interaction_model_exploration.md`, especially the
  closure summary and W005 non-claims.
- `docs/worksets/W006_control_implementation_rollout.md`, especially current
  status notes for native event dispatch, TextBox, modeless lifecycle,
  `.frm` loading, and scaffold classification.
- `docs/specs/INPUT_INTERACTION_MODEL.md`.
- `docs/specs/FM20_EVENT_FACTS.md`.
- `docs/specs/COORDINATE_MODEL.md`.
- `docs/specs/LIFECYCLE_PUMP_MODEL.md`.
- `docs/specs/RENDERING_ARCHITECTURE.md`, especially §15 (desktop backend stack —
  the `oxforms-4pn.6` decision) and §16 (render invocation and the frame model).
  §16 is the foundational render/frame model for W007's render-touching beads
  `oxforms-4pn.5`/`.6`/`.7` (Repaint vs Re-render ownership; the resident-Scene
  seam) and is itself owned by `oxforms-4pn.7`.
- `docs/specs/TRACE_REPLAY_SCHEMA.md`.
- `docs/handovers/HANDOVER_OxVba_w005_fm20_event_raise.md` before event-gate
  work.
- `docs/handovers/HANDOVER_OxVba_w006_modal_reentrant_pump.md` before any
  modal, `DoEvents`, or call-stack suspension work.

## Architecture Boundaries

W007 must preserve the charter's VBA-first architecture. The bootstrap is an
entrypoint, not a product framework.

Allowed Tiny Bootstrap responsibilities:

- load the OxVba project closure;
- configure OxVba and OxForms runtime services;
- invoke the configured VBA startup entrypoint;
- run the platform loop (the backend-owned OS message pump, `docs/specs/RENDERING_ARCHITECTURE.md` §16.3);
- exit when no forms remain open or a fatal diagnostic occurs;
- surface diagnostics and trace/evidence paths.

Forbidden Tiny Bootstrap responsibilities:

- hard-code demo controls or form layout;
- mutate form/control state directly;
- dispatch user events through a custom OxForms callback API;
- contain demo-specific form logic;
- bypass `oxforms-core` reducer/effect ownership;
- become a long-term host framework.

Owner boundaries:

- The VBA OxForms library owns MSForms-shaped `UserForm`, `Label`, `TextBox`,
  and `CommandButton` classes, their demo-supported properties, and their event
  declarations.
- OxVba owns class construction, default/predeclared instance semantics where
  needed, `RaiseEvent`/`WithEvents`, handler dispatch, call-stack reentry, and
  future modal `Show`/`DoEvents` suspension and resume behavior.
- `oxforms-core` owns reducer state, ordered effects, and render invalidation
  (`RequestRepaint`/`RenderInvalidation`) consumed by Re-render
  (`docs/specs/RENDERING_ARCHITECTURE.md` §7/§16); the legacy probe display list is
  scheduled for supersession (`RENDERING_ARCHITECTURE.md` §12 step 6), not the
  runtime render path.
- The OxForms runtime/effect runner owns queues, OxVba dispatch calls, property
  synchronization, effect completions, trace causality, Re-render (`render_frame`:
  the coalesced VBA self-render → `ScenePatch` → resident `Scene` revision, a VM
  entry; `RENDERING_ARCHITECTURE.md` §16), and backend repaint requests; it never
  rasterizes.
- PAL/window backend code owns native window creation, show/hide/destroy,
  physical OS message delivery, input normalization, Repaint (walking the resident
  `Scene` snapshot to pixels on any platform paint signal, never entering VBA;
  `RENDERING_ARCHITECTURE.md` §16), and serializable completions.

If implementation cannot satisfy these boundaries, file a precise blocker or
handover before adding runtime behavior.

## Runtime Event Doctrine

W007 requires native OxVba class events for the runtime path. User-facing form
code should use ordinary VBA handler shape, such as:

```vb
Private Sub OkButton_Click()
    OutputLabel.Caption = "Hello, " & InputTextBox.Text
End Sub
```

The W005 generic `Dispatched` carrier remains test-only infrastructure. It must
not be used as the W007 runtime event path. If OxVba cannot dispatch the W007
class-defined `Click` or `Change` event shape through `RaiseEvent`/`WithEvents`,
W007 blocks on an OxVba fix or a pinned baseline update rather than adding a
second event model inside OxForms.

**Gate status (2026-06-23, `oxforms-4pn.2`):** cleared on OxVba baseline
`366896f`. Native `Click`/`MouseDown`/`MouseUp`/`MouseMove` dispatch through
`Private WithEvents` handlers via `ProjectRuntimeSession.invoke_member_values`
with no generic carrier — see
`crates/oxforms-oxvba-adapter/tests/oxvba_w006_native_fm20_event_gate.rs`. The
prior `oxforms-0a0.2` error-424 blocker did not reproduce. Native `Change`,
keyboard, and `MSForms.Return*` ByRef helper-mutation signatures are now ordinary
implementation work for `oxforms-4pn.3`+.

## Non-Goals

W007 does not claim:

- full `UserForm` parity;
- modal `Show` parity;
- final `DoEvents` parity;
- full TextBox editing, IME, dead-key, rich paste, or drag/drop parity;
- pixel-perfect MSForms rendering;
- runtime accessibility provider behavior;
- full intrinsic-control parity;
- broad `.frm` / `.frx` persistence;
- a final pass/fail parity oracle.

## Bead Plan

| Bead | Purpose | Depends on | Acceptance Summary |
|---|---|---|---|
| `oxforms-4pn.1` | Define W007 workset and bead graph. | `oxforms-4pn` parent only | Workset doc, register row, epic, child beads, dependency graph, and review instructions exist. |
| `oxforms-4pn.2` | Prove native OxVba class event gate. | `oxforms-4pn.1` | `Click` and `Change` class events work through native `RaiseEvent`/`WithEvents`, or an exact OxVba blocker/baseline update exists. |
| `oxforms-4pn.3` | Implement minimal VBA object model slice. | `oxforms-4pn.2` | Demo-supported `UserForm`, `Label`, `TextBox`, and `CommandButton` classes/properties/events exist without custom callback APIs. |
| `oxforms-4pn.4` | Materialize the demo form into runtime state. | `oxforms-4pn.3`, `oxforms-0a0.4` | Form/control tree has stable ids, geometry, properties, and binding metadata without relying on test-only probe construction. |
| `oxforms-4pn.5` | Implement runtime effect runner. | `oxforms-4pn.2`, `oxforms-4pn.3`, `oxforms-4pn.4`, `oxforms-0a0.1`, `oxforms-0a0.3` | Runtime drains effects, invokes OxVba, syncs properties, marks invalidations and requests repaint, and emits trace/completion rows; the runtime owns Re-render (`render_frame`: coalesced VBA self-render → `ScenePatch` → resident `Scene` revision, `RENDERING_ARCHITECTURE.md` §16), whose body lands via `4pn.7`/`rq5.2`. |
| `oxforms-4pn.6` | Implement Windows backend behind PAL contracts. | `oxforms-4pn.5`, `oxforms-xvx.11` | Backend creates a real window, normalizes input, Repaints the resident `Scene` (walks it to pixels, including text) on platform paint signals without entering VBA, and returns serializable completions. |
| `oxforms-4pn.7` | Add tiny bootstrap executable. | `oxforms-4pn.5`, `oxforms-4pn.6` | Bootstrap loads project, invokes VBA startup, runs the platform loop, exits cleanly, and remains free of control logic. |
| `oxforms-4pn.8` | Add runnable OxVba forms demo. | `oxforms-4pn.3`, `oxforms-4pn.4`, `oxforms-4pn.7` | Demo accepts typed text, handles button click in VBA, updates label, and documents run command/subset. |
| `oxforms-4pn.9` | Verify runnable slice and capture evidence. | `oxforms-4pn.6`, `oxforms-4pn.7`, `oxforms-4pn.8` | Headless/runtime and visible Windows evidence prove or precisely block the W007 slice and record architecture review. |

`oxforms-4pn.1` is expected to close in the bead-creation commit. The first
implementation gate after that is `oxforms-4pn.2`; no runtime implementation
bead should proceed until native OxVba class events are proven or precisely
blocked.

## Closure Condition

W007 closes only when:

1. native OxVba class event dispatch works for the W007 subset, or the workset
   is explicitly reclassified as blocked with downstream beads reconciled;
2. the minimal VBA object model slice exists for the demo-supported
   `UserForm`, `Label`, `TextBox`, and `CommandButton` surface;
3. the W007 form/control tree is materialized into first-class runtime state;
4. the runtime/effect runner drains reducer effects, invokes OxVba event code,
   syncs changed VBA properties, produces a resident `Scene` revision and requests
   a backend repaint, and emits trace rows;
5. the Windows backend shows a real window, normalizes input, renders text and
   control state, and returns completions;
6. the tiny bootstrap can load and run the demo without hard-coded controls or
   demo-specific state;
7. the demo lets a user type text, click a button, and see a label update from
   VBA handler code;
8. headless/runtime and visible evidence exist, or visible execution is
   precisely blocked with headless/runtime proof preserved;
9. all docs/register/bead state agree about remaining non-claims and follow-up
   work.

## Verification Shape

| Surface | Check |
|---|---|
| Docs/workset/register | read-through, path/link scan, `git diff --check` |
| Bead graph | `br dep cycles`, `br ready --json`, `br list --json` |
| Rust crates | `cargo fmt --check`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo test --workspace` |
| OxVba event gate | targeted class event fixture through pinned or updated OxVba baseline |
| VBA library | OxVba compile/run fixture or targeted harness |
| Runtime/effect runner | headless test proving TextBox input, button click, native VBA handler, Label update, and a resident-`Scene` revision/repaint request |
| Windows backend | visible run with logs, trace, screenshot/frame artifact, or exact blocker |
| Evidence | checksums, command logs, trace validation, and clean-room non-claim review |

## Risks And Controls

| Risk | Control |
|---|---|
| Tiny bootstrap turns into a native host framework. | W007 docs and beads list allowed/forbidden responsibilities, and the final evidence bead reviews for leakage. |
| Event gaps are bypassed with a custom callback model. | `oxforms-4pn.2` gates runtime work on native OxVba class events. |
| W005 smoke dispatch becomes runtime architecture. | W007 forbids the generic `Dispatched` carrier outside test infrastructure. |
| Form/control state is mutated outside the reducer. | Runtime bead must return state changes through normalized events/effect completions and property sync. |
| Backend grows control behavior. | Windows backend bead accepts only window/input/render responsibilities. |
| Demo is too synthetic. | Demo must read `TextBox.Text` and set `Label.Caption` in VBA handler code. |
| Rendering is mistaken for pixel parity. | W007 documents visible text rendering as functional, not pixel-perfect FM20 parity. |
