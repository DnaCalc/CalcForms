# W007 runtime form materialization slice (oxforms-4pn.4)

Records how the W007 demo form/control tree becomes first-class runtime state, and
the scaffold-classification decision taken in this bead.

Current-code note: this is historical W007 evidence. The `oxforms-core` `.frm` materialization path
described here was deleted in `oxforms-ih6`. W009 replaced the direction with a selected-slice VBA
materializer, `OxFrmMaterializer`, which builds the live `UserForm.Controls.Add` object model for
current controls and records `.frx` image-reference metadata. It is still not the full persistence
codec. Current sample/runtime forms remain VBA form-document fixtures driven by `OxRuntime` unless a
test explicitly exercises `OxFrmMaterializer`.

## What this slice delivers

- **Canonical demo form as a `.frm`.** `fixtures/frm/w007-demo/w007-greeter.frm`
  defines the greeter: `InputField` (`MSForms.TextBox`), `OkButton`
  (`MSForms.CommandButton`, `Default = -1`), `OutputLabel` (`MSForms.Label`). Its
  twip geometry maps (÷20) to the same points the VBA render fixture uses
  (form 200×120; InputField 12,12,120,18; OkButton 140,12,48,20; OutputLabel
  12,44,176,18), so the materialized tree and the VBA-authored form describe one form.

- **First-class materialization entry.** `oxforms_core::runtime::materialize_form_from_frm`
  (and the `materialize_w007_demo_form` wrapper) is the production path: it reuses the
  selected-`.frm` loader (`crate::frm`) and projects a `RuntimeForm` carrying the
  reducer `FormState` plus a `RuntimeControlBinding` per control. Runtime code obtains
  a control tree only through this entry; it never hand-builds `ControlNode`s.

- **Binding identity.** Each binding's `control_id` equals the control `name`, which is
  the VBA control's `Name`. So a reducer `ControlId` and a VBA control resolve to the
  same control on both sides of the boundary — the contract the effect runner
  (`oxforms-4pn.5`) and the VBA demo (`oxforms-4pn.8`) rely on for event dispatch and
  property sync. The demo control names (`InputField`/`OkButton`/`OutputLabel`) match
  the VBA object-model fixtures.

## Scaffold classification (acceptance criterion #2)

- `crates/oxforms-core/src/probe.rs` was **renamed to `controls.rs`** (the reducer
  control-policy model: `ControlNode`/`ControlKind`/`hit_test_control_tree`, kept per
  `docs/specs/RENDERING_ARCHITECTURE.md` §9). The "probe" filename was a misnomer; it
  is reducer policy, not rendering.
- The `ControlNode::label`/`text_box`/`command_button`/`check_box` constructors are
  **explicitly quarantined** as low-level builders: the legitimate callers are the
  `.frm` loader, tests, and the W005/W006 trace-replay evidence builders + examples
  (evidence/demo scaffolds). Runtime code must materialize via `materialize_form_from_frm`.
- `TextBoxProbeState` was **renamed to `TextBoxState`** to match `CheckBoxState`; the
  "probe" qualifier was a leftover now that the type is first-class reducer state
  surfaced through `RuntimeForm.state`.
- The `oxforms-core` probe *render* path (`build_probe_display_list`/`ProbeDisplay*`/
  `ProbeColor`) is a separate concern, slated for deletion in `oxforms-rq5.1`; it is
  not touched here.

## Diagnostics (acceptance criterion #3)

Materialization reports rather than silently defaults the cases that affect W007:

- Unsupported control types → `RuntimeForm.unsupported` (the supported subset still
  materializes); `.frx` resource references → `RuntimeForm.frx_references` (detected,
  not decoded — binary decode remains a non-claim).
- A **present-but-malformed** numeric geometry/extent value, a non-VB6 boolean flag
  (`Default`/`Cancel`/`Visible`/`Enabled`/`TabStop`/CheckBox `Value`), a negative
  `TabIndex`, or a **duplicate control name** is a precise `FrmLoadError` (with line),
  not a silent `0`/default/shadow control. An absent property keeps its documented
  default.

Non-claims (unchanged): `.frx` binary decode, full designer persistence, and the
broad MSForms property surface beyond the selected slice.

## Tests

`crates/oxforms-core/src/runtime.rs` tests cover: the demo tree (ids/kinds/geometry/
default button/coordinate model), binding identities matching the VBA control names,
the binding property/event surface (`default`/`cancel`/`focusable`/`event_names`),
routing through the materialized `FormState` (focus + Enter→Click on the default
button), and the diagnostics above (unsupported control, `.frx` reference,
duplicate name, malformed geometry, out-of-lane boolean propagating through the
materialization boundary).
