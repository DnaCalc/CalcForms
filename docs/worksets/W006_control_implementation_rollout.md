# W006 Control Implementation Rollout

Status: `OPEN`
Epic bead: `oxforms-0a0`
Depends on: `W005_input_interaction_model_exploration`
Planning/review gate bead: `oxforms-0a0.9`

## Purpose

W006 carries the W005 interaction spine into implementation work. It is not a
blanket instruction to build all controls at once. Its first executable step is
to harden this rollout: review W005 outputs, pick the first narrow lanes,
confirm dependency order, and make sure each executable bead has enough scope,
evidence expectations, and review instructions to be safely implemented.

The W006 baseline is the W005 loop:

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

W006 should turn that spine into real runtime/control surfaces only through
small reviewed beads. Implementation beads depend on the W006 planning/review
gate so they do not start from the broad residual list alone.

## Start Reading

Before changing W006 behavior, read:

- `CHARTER.md` sections 1, 3, 3.1, 4, 5, and 7.
- `OPERATIONS.md` sections 4, 5, 6, 7, and 10.
- `docs/worksets/W005_input_interaction_model_exploration.md`.
- `docs/specs/INPUT_INTERACTION_MODEL.md`.
- `docs/specs/FM20_EVENT_FACTS.md`.
- `docs/specs/COORDINATE_MODEL.md`.
- `docs/specs/LIFECYCLE_PUMP_MODEL.md`.
- `docs/specs/TRACE_REPLAY_SCHEMA.md`.
- W005 evidence under
  `docs/evidence/W005_input_interaction_model_exploration/`, especially the
  modeless and modal MSForms captures, visible input smoke, headless replay
  golden, event dispatch smoke, and comparison artifact.
- `docs/handovers/HANDOVER_OxVba_w005_fm20_event_raise.md` before any native
  FM20 event dispatch work.

## Doctrine And Non-Claims

W006 inherits the charter's VBA-first, evidence-first, clean-room doctrine. It
may promote W005 probe/reference code only after a bead says what is promoted,
what remains test-only, and what must be replaced or deleted.

W006 does not claim:

- full UserForm parity;
- full intrinsic control parity;
- pixel-perfect rendering parity;
- runtime accessibility semantics;
- native FM20-named OxVba event dispatch;
- complete TextBox editing semantics;
- complete IME, clipboard, paste, drag/drop, or `DataObject` behavior;
- complete `.frm` / `.frx` persistence integration;
- a final pass/fail parity oracle.

Current TextBox status from `oxforms-0a0.1`: implemented-subset for the
host-neutral W005 TextBox probe only. The subset covers committed single-line
text, caret anchor/active selection state, Backspace/Delete, Left/Right/Home/End
navigation, `KeyDown`/`KeyUp` rows, `Change` rows for actual text mutation, and
headless replay evidence. It still does not claim multiline, password mode,
scrolling, IME/composition, dead keys, clipboard shortcuts, menu paste,
rich-format paste/DataObject, drag/drop, full validation ordering, full
selection UI parity, or native FM20-named dispatch. `oxforms-0a0.14` adds only
the first host-neutral text-only paste subset for successful service-origin
`ClipboardResult(Get)` rows with serializable plain text; unsupported formats
remain diagnostic no-ops and live platform clipboard/COM objects stay outside
core `FormState`. `oxforms-0a0.15` adds only the first host-neutral true
drag/drop text subset for serializable `DragOver` and `DropOrPaste` rows:
`BeforeDragOver`/`BeforeDropOrPaste` metadata cites `FM20_EVENT_FACTS.md`, a
plain-text drop can update the target TextBox before `Change` and repaint, and
live platform drag objects plus COM `MSForms.DataObject` instances stay outside
core `FormState`.

Each later bead may claim only the subset it implements and proves with the
checks/evidence named in that bead.

## Dependency Shape

`oxforms-0a0` is the W006 epic. Its first ready child is
`oxforms-0a0.9`, the planning/review/rollout-hardening bead.

All executable W006 implementation or design beads depend on
`oxforms-0a0.9`. That gate must:

1. reread W005 closure output and this workset;
2. tighten or split any W006 child that is still too broad for review;
3. confirm each child has start-reading pointers, scoped acceptance criteria,
   relevant doc pointers, and the required fresh-eyes review/rework instruction;
4. confirm dependencies prevent implementation work from starting before the
   plan is coherent;
5. keep W006 open.

After the gate closes, implementation lanes can proceed only in their scoped
beads. The first downstream support lanes are native FM20-named event dispatch
and harness/comparison hardening; TextBox editing, lifecycle runtime,
`.frm`/`.frx`, and control-breadth work wait for the support beads they cite.
Broad lifecycle and intrinsic-control residuals are split into explicit design
or splitter beads before any all-surface implementation is attempted.

## Bead Plan

| Bead | Purpose | Depends on | Acceptance Summary |
|---|---|---|---|
| `oxforms-0a0.9` | Review and harden the W006 rollout before implementation starts. | `oxforms-0a0` parent only | W006 doc/register/bead graph are coherent; broad beads are split or tightened; implementation beads are blocked behind the gate; W006 remains open. |
| `oxforms-0a0.8` | Harden W005 interaction harnesses and comparison/oracle validators for future scenarios. | `oxforms-0a0.9` | Harness changes preserve logs, hashes, coordinate tags, source paths, and observation-only comparison posture. |
| `oxforms-0a0.2` | Implement or precisely block native FM20-named event dispatch through OxVba shared machinery. | `oxforms-0a0.9` | Direct event handlers work for a named subset, or exact OxVba blockers/handovers exist; W005 generic carrier stays test-only. |
| `oxforms-0a0.4` | Connect W005 interaction state to canonical `.frm` / `.frx` loading for selected fixtures. | `oxforms-0a0.9`, `oxforms-0a0.8` | Fixture inputs produce equivalent logical control trees for selected scenarios; probe construction is test-only or intentionally replaced. |
| `oxforms-0a0.1` | Implement the first single-line TextBox editing slice: caret movement, selection state representation, Backspace/Delete, and named navigation keys. | `oxforms-0a0.9`, `oxforms-0a0.2`, `oxforms-0a0.8` | The selected single-line editing subset is specified/evidenced; multiline, password, scrolling, IME, clipboard, paste/DataObject, drag/drop, and broad validation remain non-claims or follow-up beads. |
| `oxforms-0a0.3` | Implement or precisely block the first modeless lifecycle close slice. | `oxforms-0a0.9`, `oxforms-0a0.2`, `oxforms-0a0.8` | Modeless show/materialize/window-shown/activate plus close request -> QueryClose -> hide-or-unload flows through normalized events/effects with evidence or blockers; nested modal, DoEvents, broad reentrancy, and object-lifetime Terminate are deferred. |
| `oxforms-0a0.10` | Design nested modal, DoEvents-like yield, reentrant pump, modal completion, and Terminate timing follow-up. | `oxforms-0a0.9`, `oxforms-0a0.3` | Facts, assumptions, unknowns, blockers, and any implementation-ready child beads are separated before broad modal/runtime work begins. |
| `oxforms-0a0.5` | Split the first intrinsic-control implementation lane beyond W005 probes. | `oxforms-0a0.9`, `oxforms-0a0.4`, `oxforms-0a0.8` | First control lane is fact-backed or precisely blocked; implementation work is split into control-specific beads; W005 probe scaffolds are promoted, replaced, deleted, or quarantined intentionally. |
| `oxforms-0a0.11` | Ground the first CheckBox boolean-value lane with public facts, fixture input, oracle evidence, or exact blockers. | `oxforms-0a0.9`, `oxforms-0a0.8` | CheckBox property/event/rendering/state surfaces are named before implementation starts; broad morph-control parity remains deferred. |
| `oxforms-0a0.12` | Implement or precisely block the first MSForms.CheckBox boolean-value reducer/display/.frm slice. | `oxforms-0a0.9`, `oxforms-0a0.8`, `oxforms-0a0.4`, `oxforms-0a0.11` | Only the fact-backed boolean CheckBox subset is implemented; W005 probe scaffolds are replaced/renamed or explicitly quarantined. |
| `oxforms-0a0.6` | Design IME, clipboard, paste, and drag/drop input surfaces. | `oxforms-0a0.9`, `oxforms-0a0.8` | Public facts and assumptions are separated; normalized event/effect/trace extensions are specified or blocked without leaking platform objects into core state. |
| `oxforms-0a0.13` | Capture public `TextBox.Paste`/`BeforeDropOrPaste` oracle facts and precisely block undriven text-service/transfer surfaces. | `oxforms-0a0.6` | Repo-owned fixture evidence separates observations from assumptions; true OLE drag/drop and keyboard/text-service driver gaps were split into explicit follow-ups before runtime parity claims. |
| `oxforms-0a0.14` | Implement or precisely block the first text-only TextBox clipboard paste subset. | `oxforms-0a0.6`, `oxforms-0a0.13` | Platform clipboard objects stay outside core state; focused tests cover accepted text paste, selection replacement, Change/repaint behavior, and unsupported format diagnostics; DataObject/rich paste remains non-claim. |
| `oxforms-0a0.15` | Implement or precisely block the first drag/drop DataObject trace and dispatch subset. | `oxforms-0a0.6`, `oxforms-0a0.13`, `oxforms-0a0.16` | Normalized drag/drop events, data snapshots, dispatch metadata, trace/schema updates, and non-claims are handled together or precisely blocked; `.16` supplies the live OLE drag-session oracle for any true drag/drop facts used here. |
| `oxforms-0a0.16` | Build or precisely block the live OLE drag/drop `DataObject` oracle driver. | `oxforms-0a0.13` | A real drag-session `DataObject` fixture/driver captures `BeforeDragOver` and `BeforeDropOrPaste` facts, or records the exact public-capability blocker; `.13` paste observations remain adjacent evidence, not true drag/drop parity evidence. |
| `oxforms-0a0.17` | Build or precisely block deterministic clipboard shortcut and text-service oracle drivers. | `oxforms-0a0.13` | `Ctrl+V`, IME/composition, and dead-key scenarios are captured with deterministic setup metadata or remain explicit non-claims; clean-room clipboard policy matches `.13`. |
| `oxforms-0a0.7` | Design runtime accessibility semantics beyond W005 diagnostics. | `oxforms-0a0.9`, `oxforms-0a0.8` | Requirements and non-goals are explicit; W005 UIA metadata is not treated as FM20 runtime behavior truth. |

### `oxforms-0a0.6` Design Outcome

`oxforms-0a0.6` is design-only. It keeps all existing IME/composition, dead-key,
clipboard, paste/DataObject, drag/drop, and full TextBox parity non-claims in
place while reserving implementation-ready surface names in
[`../specs/INPUT_INTERACTION_MODEL.md`](../specs/INPUT_INTERACTION_MODEL.md),
[`../specs/FM20_EVENT_FACTS.md`](../specs/FM20_EVENT_FACTS.md), and
[`../specs/TRACE_REPLAY_SCHEMA.md`](../specs/TRACE_REPLAY_SCHEMA.md).

The design requires platform clipboard objects, drag sessions, IME contexts, and
COM `MSForms.DataObject` instances to stay outside core `FormState`. Future
runtime beads must use normalized value-shaped events, service/effect
completions, serializable data-object snapshots, and focused trace/PAL/core
tests before claiming any of these surfaces. `oxforms-0a0.13` is the
MSForms oracle/evidence gate for the first clipboard/paste and drag/drop
implementation/blocker follow-ups. `oxforms-0a0.13` captured a public
`TextBox.Paste`/`BeforeDropOrPaste` oracle and exact blockers in
[`../evidence/W006_control_implementation_rollout/text-service-transfer-oracle.md`](../evidence/W006_control_implementation_rollout/text-service-transfer-oracle.md):
`oxforms-0a0.14` is unblocked only for a first text-only paste implementation or
blocker that keeps `Ctrl+V`, IME/dead-key behavior, rich formats, and broad
`DataObject` parity as non-claims. `oxforms-0a0.16` later supplied the separate
live drag-session `DataObject` oracle, so `oxforms-0a0.15` is no longer blocked
on absence of true OLE drag/drop evidence; it remains responsible for any
runtime trace/dispatch implementation or precise blocker. After
`oxforms-0a0.15`, the v1 trace validator and `UI_EVENT_SCHEMA_VERSION = 1`
accept only `DragOver`/`drag_over` and `DropOrPaste`/`drop_or_paste` from the
drag/drop family; `TextComposition*`, `PasteRequest`, `DragEnter`, `DragLeave`,
and `create_data_object_snapshot` remain reserved and must update those
contracts in the same change that emits such rows.

## Closure Conditions

Current `oxforms-0a0.2` status: blocked in OxForms by the shared OxVba event
path. The attempted native scalar subset (`MouseDown`, `MouseUp`, `MouseMove`,
and `Click`) is documented in
[`../evidence/W006_control_implementation_rollout/native-fm20-event-dispatch-blocker.md`](../evidence/W006_control_implementation_rollout/native-fm20-event-dispatch-blocker.md),
and the OxVba handover remains
[`../handovers/HANDOVER_OxVba_w005_fm20_event_raise.md`](../handovers/HANDOVER_OxVba_w005_fm20_event_raise.md).
The W005 `Dispatched` carrier remains smoke/test infrastructure only.

Current `oxforms-0a0.3` status: implemented-subset in the host-neutral core
reducer with the same OxVba dispatch blocker for real `QueryClose`
handler/cancellation semantics. The reducer models close-flow state and ordered
effects for modeless close-button/system-menu
`CloseRequest -> QueryClose -> HideForm -> WindowHidden -> UnloadForm ->
Unloaded`, maps that close origin to `CloseMode=0`, and keeps `Unloaded`
separate from object-lifetime `Terminate`. Evidence is recorded in
[`../evidence/W006_control_implementation_rollout/modeless-lifecycle-close-slice.md`](../evidence/W006_control_implementation_rollout/modeless-lifecycle-close-slice.md).

Current `oxforms-0a0.4` status: implemented-subset in the host-neutral core
loader/projection path. The selected fixture
[`../../fixtures/frm/w006-interaction-slice/w006-interaction-slice.frm`](../../fixtures/frm/w006-interaction-slice/w006-interaction-slice.frm)
loads a small UserForm with Label, TextBox, default CommandButton, and cancel
CommandButton controls into the same W005 `FormState`/`ControlNode` logical
tree used by hit-test, focus/tab, default/cancel, accelerator, text, and event
effect tests. Twips are converted to point-based `form_logical` coordinates per
[`../specs/COORDINATE_MODEL.md`](../specs/COORDINATE_MODEL.md). `.frx` binary
resource decoding is not implemented in this bead; the loader detects and
reports `.frx` property references, and the selected fixture intentionally has
none. Evidence and scaffold classification are recorded in
[`../evidence/W006_control_implementation_rollout/frm-frx-interaction-slice.md`](../evidence/W006_control_implementation_rollout/frm-frx-interaction-slice.md).

Current `oxforms-0a0.5` status: splitter-complete for the first
intrinsic-control lane. The selected lane is the `MSForms.CheckBox`
boolean-value slice, grounded by the morph-control planning in the top-level
spec, W005 event/reducer/trace facts, and the W006 `.frm` projection path, but
runtime implementation is split into `oxforms-0a0.11` and `oxforms-0a0.12`.
Scaffold classification and required surfaces are recorded in
[`../evidence/W006_control_implementation_rollout/first-intrinsic-control-lane.md`](../evidence/W006_control_implementation_rollout/first-intrinsic-control-lane.md).

Current `oxforms-0a0.11` status: readiness grounded for the first
`MSForms.CheckBox` boolean-value lane. The curated subset is recorded in
[`../specs/FM20_EVENT_FACTS.md`](../specs/FM20_EVENT_FACTS.md), and the
fixture input
[`../../fixtures/frm/w006-checkbox-boolean/w006-checkbox-boolean.frm`](../../fixtures/frm/w006-checkbox-boolean/w006-checkbox-boolean.frm)
contains checked and unchecked boolean cases with no `.frx` dependency.
`oxforms-0a0.12` remains responsible for implementation and must keep
tri-state/null, `ControlSource`, native FM20-named dispatch, broad morph-control
parity, and pixel-perfect rendering as non-claims unless separate beads ground
them.

Current `oxforms-0a0.12` status: implemented-subset in the host-neutral
`oxforms-core` reducer/display/selected `.frm` path. The loader projects
`Begin MSForms.CheckBox` controls from the W006 boolean fixture with `Caption`,
boolean-only `Value`, enabled/visible state, tab participation, and twip-to-point
geometry; `Value` tokens outside `0`, `-1`, `False`, and `True` remain blocked.
Reducer state uses first-class `CheckBoxState`, mouse down/up routes
`MouseDown`, `MouseUp`, `Click`, and value-changing `Change` effects, and
display-list intent serializes the box glyph, check mark, caption, focus,
disabled, pressed, and normal state. Keyboard `KeyDown`/`KeyUp` diagnostics are
emitted for focused CheckBox controls, but Space/Enter value-toggle behavior
remains blocked pending live-oracle ordering evidence. Native FM20-named
dispatch remains blocked by `oxforms-0a0.2`, and pixel-perfect rendering,
tri-state/null, `ControlSource`, accessibility, OptionButton/ToggleButton, and
broad morph-control parity remain non-claims.

Current `oxforms-0a0.13` status: live Office/MSForms evidence plus exact
blockers for deferred text-service and data-transfer surfaces. Evidence is
recorded in
[`../evidence/W006_control_implementation_rollout/text-service-transfer-oracle.md`](../evidence/W006_control_implementation_rollout/text-service-transfer-oracle.md)
and capture
[`../evidence/W006_control_implementation_rollout/captures/text-service-transfer-20260623T084627Z/`](../evidence/W006_control_implementation_rollout/captures/text-service-transfer-20260623T084627Z/).
The observed public MSForms `TextBox.Paste` path raises `BeforeDropOrPaste`
before `Change`, records `Cancel` and `Effect` helper before/after values, and
records a public `DataObject` text-format summary for the repo-owned seed. The
current desktop session blocks `Ctrl+V` keyboard driving, IME/composition,
dead-key preedit, and true OLE drag/drop; follow-up beads `oxforms-0a0.16` and
`oxforms-0a0.17` track those oracle-driver gaps.

Current `oxforms-0a0.14` status: implemented-subset in the host-neutral
`oxforms-core` reducer/PAL event contract. The PAL `ClipboardResult` event can
carry an optional serializable text payload. The reducer accepts only successful
get results with plain-text formats for the currently focused visible/enabled
TextBox, replaces the selection, emits `BeforeDropOrPaste` metadata before
`Change`, and requests repaint. Unsupported formats, missing or failed payloads,
non-get operations, unfocused targets, and control-character payloads are
diagnostic no-ops. This is not a live clipboard adapter, not a COM
`DataObject`, not a `Ctrl+V` shortcut-ordering claim, and not rich-format/menu
paste or true drag/drop parity.

Current `oxforms-0a0.15` status: implemented-subset in the host-neutral
`oxforms-pal`/`oxforms-core` reducer and trace projection surfaces. The PAL now
has value-shaped `DragOver` and `DropOrPaste` events with serializable
`DataObjectSnapshot` summaries. The reducer emits `BeforeDragOver` metadata for
drag-over rows, accepts only plain-text drag/drop snapshots for visible/enabled
TextBox targets, emits `BeforeDropOrPaste` metadata before `Change`, and records
helper-result boundaries in dispatch metadata when dispatch is attempted by the
headless/core path. Unsupported formats, missing text payloads, unsupported
text, and missing TextBox targets are diagnostic no-ops. The trace validator now
accepts `drag_over` and `drop_or_paste`; `drag_enter`, `drag_leave`,
`paste_request`, IME/composition rows, and `create_data_object_snapshot` remain
reserved. This is not rich-format `DataObject` parity, not cross-application
drag parity, not cancellation/mutation breadth, not final MSForms ordering, and
not native FM20-named OxVba dispatch.

Current `oxforms-0a0.16` status: live Office/MSForms true OLE drag/drop oracle
captured in
[`../evidence/W006_control_implementation_rollout/ole-drag-drop-transfer-oracle.md`](../evidence/W006_control_implementation_rollout/ole-drag-drop-transfer-oracle.md).
The repo-owned fixture uses public `MSForms.DataObject.SetText` and
`StartDrag`, public `user32 SendInput` mouse input, and target TextBox handlers
that log `BeforeDragOver` and `BeforeDropOrPaste` with X/Y, Shift,
DragState/Action, public DataObject summaries, and before/after `Cancel` and
`Effect` helper values. The capture stores no live COM object identity or
private Office implementation detail, and `.13` paste observations remain
separate adjacent evidence. Rich formats, cancellation/mutation breadth,
cross-application drags, and full drag/drop parity remain non-claims.

W006 closes only when:

1. the planning/review gate has closed and all executable W006 beads are either
   completed, precisely blocked, or moved into later worksets with clear bead
   state;
2. selected W006 runtime/control lanes have implementation or blocker evidence
   matching their scoped acceptance criteria;
3. W005 probe/reference scaffolds have been promoted, replaced, deleted, or
   quarantined as non-pattern test infrastructure;
4. any broadened parity claim is backed by public facts, reproducible
   black-box observations, trace/replay artifacts, tests, or explicit blockers;
5. W006 docs/register/beads agree about remaining scope and next work;
6. no W006 implementation bead remains open but accepted as "done" by prose.

Do not close W006 from the planning/review gate. Do not close W006 from a single
implementation lane unless the whole workset closure condition is actually met.

## Verification Shape

| Surface | Check |
|---|---|
| Docs/workset/register | read-through, path/link scan, `git diff --check` |
| Bead graph | `br dep cycles`, `br ready --json`, `br list --json` |
| Runtime/control lanes | targeted Rust/OxVba/fixture checks named by the touched bead |
| Evidence/oracles | Office/MSForms capture, replay/golden validation, checksum validation, or exact blocker |
| Trace/replay/comparison | schema validator, replay runner, comparison validator where touched |
| Visible smoke evidence | committed-capture validator plus checksum validation when visible-smoke artifacts or driver assumptions are touched |
| Clean-room posture | review public facts vs assumptions and check that no private implementation details or temporary W005 shortcuts became architecture |

`oxforms-0a0.8` hardens the W005 evidence validators as support
infrastructure for later W006 scenarios. The comparison validator remains
observation-only and rejects pass/fail verdict fields; the visible-smoke
validator checks committed evidence manifests, command logs, coordinate
vocabulary, hashes, and clean-room non-claims without opening a live window.
