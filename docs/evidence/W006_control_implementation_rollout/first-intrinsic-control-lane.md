# W006 First Intrinsic Control Lane

Status: splitter decision for `oxforms-0a0.5`.

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
  documentation facts for the W005 event vocabulary. It already records that
  `Change` applies beyond `TextBox` to check/option/toggle style controls and
  that value-selection controls have a broader `Click` surface, but it does
  not yet curate a CheckBox-specific event/property subset.
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
- keyboard diagnostics and activation: `KeyDown`, `KeyUp`;
- focus/tab participation and any `Enter`/`Exit` exposure as facts,
  assumptions, unknowns, or blockers.

Minimum rendering/state surface:

- a focusable/checkable control state separate from `TextBoxProbeState`;
- boolean checked state;
- pressed/armed state;
- value-change and pressed/focus invalidation;
- serializable display-list intent for caption text, focus indication, box
  glyph, check mark, disabled state, and pressed/normal state.

## W005 Scaffold Classification

For this selected lane:

| Scaffold | Classification | Rationale |
|---|---|---|
| `ControlNode` as a host-neutral reference state shape | Quarantined pending replacement/rename | It is useful test-spine state, but the current name and `ProbeControlKind` coupling are W005-specific and must not become the production control factory by accident. |
| `ControlNode::label`, `ControlNode::command_button`, and `ControlNode::text_box` constructors | Quarantined as non-pattern test infrastructure | They remain fine for W005 regression tests and existing fixtures, but a CheckBox implementation must not simply add another probe constructor and call that parity. |
| `ProbeControlKind` | Replace before or during the CheckBox implementation bead | Adding `CheckBox` to a type named `ProbeControlKind` would blur the W005 probe/non-pattern boundary. |
| `build_probe_display_list` and PAL smoke projection | Quarantined as display-reference test infrastructure | The command vocabulary is useful evidence scaffolding, but the implementation bead must either rename/generalize it or document a narrow test-only use. |
| W005 generic `Dispatched` event carrier | Quarantined as smoke/test infrastructure | Native FM20-named event dispatch remains blocked by `oxforms-0a0.2`; production CheckBox work must not route through the generic carrier as architecture. |
| `load_selected_frm_interaction_state` selected `.frm` loader path | Promoted only as the current selected-fixture projection path | Its unsupported-control reporting, twips-to-points conversion, and metadata-only event hooks are useful. Its Label/TextBox/CommandButton-only support remains a selected subset, not a full persistence codec. |
| W005 trace/replay runner and evidence validators | Promoted as regression/evidence pattern | Later CheckBox work should reuse the same deterministic trace/replay and validation posture, extending schemas or goldens only in a scoped bead. |

## Readiness Checks

Checks run by the splitter bead are recorded in the parent close reason and
commit. The child beads must run their own targeted checks. At minimum, the
readiness bead should validate public fact/fixture paths and the implementation
bead should run `cargo test -p oxforms-core`, relevant trace/replay validation
if touched, `git diff --check`, `br dep cycles`, `br ready --json`, and
`br list --json`, or record exact blockers.
