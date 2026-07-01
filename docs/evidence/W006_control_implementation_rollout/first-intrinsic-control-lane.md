# W006 First Intrinsic Control Lane

Status: splitter decision for `oxforms-0a0.5`.

Readiness update: `oxforms-0a0.11` grounds the first CheckBox boolean-value
lane before runtime implementation. Implementation update: `oxforms-0a0.12`
implements the narrow host-neutral reducer/display/`.frm` subset described
below without claiming broader CheckBox or morph-control parity.

## Decision

The first intrinsic-control implementation lane beyond the W005 `Label`,
`CommandButton`, and `TextBox` probes is:

```text
MSForms.CheckBox boolean-value slice
```

This is not the whole morph-control group and does not claim
`OptionButton`, `ToggleButton`, tri-state/null `CheckBox`, list controls,
pixel-perfect rendering, accessibility, or native FM20-named event dispatch.

## Grounding

The lane is safe to split, but not safe to implement as broad parity yet.

Grounding sources reviewed:

- `docs/worksets/W006_control_implementation_rollout.md` keeps control breadth
  behind a splitter bead and says W005 probes must be promoted, replaced,
  deleted, or quarantined intentionally.
- `docs/worksets/W005_input_interaction_model_exploration.md` closes only an
  interaction probe set for `Label`, `CommandButton`, and `TextBox`; it leaves
  full intrinsic-control parity to W006.
- `docs/FORMS_LIBRARY_SPEC_AND_PLAN.md` names the intrinsic controls and says
  the morph group (`TextBox`, `ComboBox`, `ListBox`, `CheckBox`,
  `OptionButton`, `ToggleButton`) is the first P4 breadth group because those
  controls share MS-OFORMS `MorphData` persistence.
- `docs/specs/FM20_EVENT_FACTS.md` records public FM20 type-library and public
  documentation facts for the W005 event vocabulary. `oxforms-0a0.11` extends
  it with a CheckBox-specific boolean-value readiness subset while keeping
  broader check/option/toggle behavior deferred.
- `docs/specs/INPUT_INTERACTION_MODEL.md` defines the shared reducer/effect
  loop, focus/capture/tab routing, `FireVbaEvent`, invalidation, and
  trace/replay obligations that a CheckBox slice must use.
- `docs/evidence/W006_control_implementation_rollout/frm-frx-interaction-slice.md`
  proves the selected `.frm` path can project W005 controls into the
  interaction state model and records unsupported controls rather than
  guessing their shape.
- W003/W004/W005 evidence establishes the current oracle, geometry,
  trace/replay, and comparison posture for the existing probe controls only.

The selected lane should therefore begin with a fact/fixture readiness bead
before any runtime implementation bead writes CheckBox behavior.

## Child Beads

`oxforms-0a0.11` grounds the CheckBox lane with public facts, fixture input, or
precise blockers. It must name the property, event, rendering, and state
surfaces before implementation starts.

`oxforms-0a0.12` implements only the fact-backed boolean CheckBox subset. It is
blocked on `oxforms-0a0.11` and must not implement broad morph-control parity.

Dependency intent:

- `oxforms-0a0.11` depends on the W006 planning gate and harness hardening.
- `oxforms-0a0.12` depends on `oxforms-0a0.11`, the W006 planning gate,
  harness hardening, and the `.frm` interaction slice.

## Required Surfaces

Minimum property surface for the first CheckBox readiness/implementation lane:

- `Caption`;
- `Value`, limited to a boolean true/false subset until tri-state/null facts
  are grounded;
- `Enabled`;
- `Visible`;
- `Left`, `Top`, `Width`, and `Height`, with `.frm` twips converted to
  point-based `form_logical` coordinates;
- `TabIndex`;
- `TabStop`.

Explicitly deferred until facts or follow-up beads say otherwise:

- `TripleState`, null value semantics, and grouped/option behavior;
- `ControlSource`;
- full font, color, border, special-effect, picture, and accelerator-display
  parity;
- all list/morph surfaces that are not needed by a boolean CheckBox.

Minimum event/effect surface to ground before implementation:

- mouse routing: `MouseDown`, `MouseMove`, `MouseUp`;
- activation: `Click`;
- value mutation: `Change`;
- keyboard diagnostics and activation blockers: `KeyDown`, `KeyUp`;
- focus/tab participation and any `Enter`/`Exit` exposure as facts,
  assumptions, unknowns, or blockers.

Minimum rendering/state surface:

- a focusable/checkable control state separate from `TextBoxState`;
- boolean checked state;
- pressed/armed state;
- value-change and pressed/focus invalidation;
- serializable display-list intent for caption text, focus indication, box
  glyph, check mark, disabled state, and pressed/normal state.

## CheckBox Boolean-Value Readiness

Status: ready for the narrow implementation bead `oxforms-0a0.12`, with
blockers and non-claims below.

### Public Facts

- `MSForms.CheckBox` is a distinct intrinsic control in the morph/data group,
  but this lane does not implement the whole morph group.
- Microsoft Learn `CheckBox control` describes selected and unselected states as
  Yes/True/On and No/False/Off, says `Value` is the CheckBox default property,
  and says `Click` is the CheckBox default event.
- Microsoft Learn `TripleState property` says `TripleState=False` supports only
  `True` and `False` through the UI, while `TripleState=True` allows `Null`.
  This lane uses only the boolean subset and does not implement `Null`.
- The committed public FM20 type-library metadata under
  `docs/evidence/W005_input_interaction_model_exploration/fm20_typelib_w005_events.json`
  contains coclass `CheckBox` with source interface `MdcCheckBoxEvents`.
- `docs/specs/FM20_EVENT_FACTS.md` now curates the CheckBox boolean-value event
  subset for `MouseDown`, `MouseMove`, `MouseUp`, `Click`, `Change`, `KeyDown`,
  `KeyUp`, and focus participation blockers for `Enter`/`Exit`.
- `docs/specs/COORDINATE_MODEL.md` requires `.frm` twips to convert exactly to
  point-based `form_logical` coordinates, and mouse event `X`/`Y` arguments to
  stay target-local `msforms_event_args` points when dispatch rows are emitted.
- `docs/specs/TRACE_REPLAY_SCHEMA.md` requires future CheckBox traces to record
  normalized input, routing decisions, reducer transitions, ordered effects,
  dispatch rows, invalidations, display-list references, and exact blockers as
  rows or diagnostics rather than hidden behavior.

### Fixture Input

Repo-owned fixture input:
`fixtures/frm/w006-checkbox-boolean/w006-checkbox-boolean.frm`.

The fixture contains:

- form `OxFormsW006CheckBoxBooleanForm`;
- `OracleCheckBoxFalse` with `Caption = "Unchecked"` and `Value = 0`;
- `OracleCheckBoxTrue` with `Caption = "Checked"` and `Value = -1`;
- `Enabled = -1`, `Visible = -1`, `TabStop = -1`, explicit `TabIndex`, and
  twip `Left`/`Top`/`Width`/`Height` for both controls;
- no `.frx` references and no binary resource properties.

The fixture is readiness input, not MSForms oracle output. `Value = 0` and
`Value = -1` follow the existing repo fixture convention for serialized boolean
properties and are constrained here to the public-doc boolean `False`/`True`
subset. `oxforms-0a0.12` should parse only this boolean subset or record an
exact blocker; it must not infer tri-state/null behavior from this fixture.

### Implementation Surface For `oxforms-0a0.12`

Status: implemented-subset in `crates/oxforms-core`.

Property surface:

- load `Begin MSForms.CheckBox` blocks from the selected `.frm` fixture path;
- `Caption`;
- `Value` limited to boolean false/true tokens only. The selected loader accepts
  `0`, `-1`, `False`, and `True`, and rejects other tokens such as `1` instead
  of silently inventing coercion behavior;
- `Enabled`;
- `Visible`;
- `Left`, `Top`, `Width`, and `Height` converted from twips to
  `form_logical` points;
- `TabIndex`;
- `TabStop`.

State surface:

- checkable/focusable control state separate from `TextBoxState`;
- boolean checked value;
- pressed/armed state for pointer activation; keyboard pressed/toggle behavior
  remains blocked below;
- focus/tab participation for visible, enabled, focusable CheckBox controls;
- invalidation reasons `checkbox_value_changed`, `checkbox_pressed_changed`,
  and existing `focus_changed` focus visual invalidation.

Event/effect surface:

- mouse routing/effects: `MouseDown`, `MouseMove`, `MouseUp`;
- activation: `Click` on an inside mouse release after capture;
- value mutation: `Change` when the boolean value toggles;
- keyboard diagnostics: `KeyDown`, `KeyUp`;
- keyboard value toggle remains blocked because exact Space/Enter activation
  behavior and ordering are not live-oracle grounded in this repo;
- `Enter`/`Exit`: focus participation may be modeled for routing, but native
  CheckBox dispatch is blocked until CheckBox-specific exposure of generic
  `ControlEvents` is observed or implemented through shared OxVba machinery.

Rendering/display-list surface:

- serializable display-list intent for the CheckBox box glyph, check mark,
  caption text, focus indication, disabled state, pressed state, and normal
  state;
- no pixel-perfect MSForms theming, font metrics, accelerator-display parity, or
  native control painting claim.

Trace/replay surface:

- future CheckBox goldens must use the row families in
  `docs/specs/TRACE_REPLAY_SCHEMA.md`;
- dispatch rows must cite `docs/specs/FM20_EVENT_FACTS.md`;
- if native dispatch remains blocked, rows must record the blocker rather than
  routing production behavior through the W005 generic `Dispatched` carrier.

### Assumptions

- A CheckBox can be made visible, enabled, focusable, and tab-participating in
  the selected fixture using the same `.frm` boolean-token convention already
  used by W006 `TabStop`, `Default`, and `Cancel` fixture properties.
- The first implementation can treat `Value = 0` as false and `Value = -1` as
  true for the selected boolean lane, while rejecting or blocking other tokens
  until broader coercion facts are grounded.
- The first display-list reference can be an intent model for a box/check/caption
  control rather than an MSForms pixel oracle.

### Unknowns And Blockers

- Exact `Click` versus `Change` ordering for CheckBox user activation is not
  live-oracle grounded in this repo.
- Exact Space/Enter keyboard activation behavior and ordering are not
  live-oracle grounded in this repo.
- Exact CheckBox `Enter`/`Exit` native handler exposure is blocked by the generic
  `ControlEvents` mapping unknown recorded in `docs/specs/FM20_EVENT_FACTS.md`.
- Native FM20-named dispatch is blocked by `oxforms-0a0.2`; production CheckBox
  work must not rely on the W005 generic `Dispatched` carrier.
- Tri-state/null behavior, including programmatic `Null`, is outside this lane.
- `ControlSource` and data binding behavior are outside this lane.
- Full `MorphData` persistence, font/color/picture/border/special-effect parity,
  accelerator-display parity, runtime accessibility semantics, and pixel-perfect
  rendering are outside this lane.
- No CheckBox-specific live MSForms oracle capture exists yet under
  `docs/evidence/`; `oxforms-0a0.12` may implement the public-fact-backed
  reducer/display subset but must keep final ordering and visual parity
  non-claims explicit.

## W005 Scaffold Classification

For this selected lane:

| Scaffold | Classification | Rationale |
|---|---|---|
| `ControlNode` as a host-neutral reference state shape | Still selected-subset infrastructure | `oxforms-0a0.12` keeps this shape but adds first-class `CheckBoxState` rather than storing boolean value in TextBox state or fixture-only metadata. |
| `ControlNode::label`, `ControlNode::command_button`, and `ControlNode::text_box` constructors | Quarantined as non-pattern test infrastructure | They remain fine for W005 regression tests and existing fixtures. `ControlNode::check_box` is a local constructor for the selected CheckBox slice, not a full persistence/control factory API. |
| `ProbeControlKind` | Replaced by `ControlKind` in `oxforms-0a0.12` | The enum no longer names W005 probes before CheckBox is added. This is a scoped architectural rename, not a claim that all `ControlKind` variants are complete MSForms implementations. |
| `build_probe_display_list` and PAL smoke projection | Quarantined as display-reference test infrastructure | `oxforms-0a0.12` extends the serializable display intent for CheckBox and uses display-list schema version 2 only when CheckBox commands are present. The PAL smoke projection remains W005 fill-rect test infrastructure, not native control painting or pixel parity. |
| W005 generic `Dispatched` event carrier | Quarantined as smoke/test infrastructure | Native FM20-named event dispatch remains blocked by `oxforms-0a0.2`; production CheckBox work must not route through the generic carrier as architecture. |
| `load_selected_frm_interaction_state` selected `.frm` loader path | Promoted only as the current selected-fixture projection path | Its unsupported-control reporting, twips-to-points conversion, and metadata-only event hooks are useful. Its Label/TextBox/CommandButton-only support remains a selected subset, not a full persistence codec. |
| W005 trace/replay runner and evidence validators | Promoted as regression/evidence pattern | Later CheckBox work should reuse the same deterministic trace/replay and validation posture, extending schemas or goldens only in a scoped bead. |

## Readiness Checks

Checks run by the splitter bead are recorded in the parent close reason and
commit. The child beads must run their own targeted checks. At minimum, the
readiness bead should validate public fact/fixture paths and the implementation
bead originally ran `cargo test -p oxforms-core` plus relevant trace/replay validation
if touched. After `oxforms-ih6`, `oxforms-core` is deleted; new control work should run the
adapter/VBA-reducer tests that cover the touched lane, `git diff --check`, `br dep cycles`,
`br ready --json`, and `br list --json`, or record exact blockers.
