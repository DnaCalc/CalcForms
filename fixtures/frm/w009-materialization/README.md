# W009 Representative Materialization Fixture

Status: selected-slice fixture for `oxforms-zhz.22` and the W009 representative
intrinsic-control lanes through `oxforms-zhz.49`.

`w009-representative.frm` exercises the current VBA object-model materializer:

- `UserForm` caption and client size;
- `Label`, `TextBox`, two `CommandButton` controls, `CheckBox`,
  `ToggleButton`, `OptionButton`, `ListBox`, `ComboBox`, `Image`,
  `SpinButton`, `ScrollBar`, `TabStrip`, and `MultiPage`;
- geometry stored as `.frm` twips and converted to OxForms point units;
- caption/text/value, tab order, visible/enabled, colors, border style,
  default/cancel button flags;
- one `MSForms.Image` block with a `Picture` reference into
  `w009-representative.frx`.

The later W009 lanes materialize each intrinsic block into its live
`Forms.*.1` control. `TabStrip` and `MultiPage` are intentionally empty in this
selected fixture: the local lanes prove live controls, collection APIs, and
selection behavior, while serialized tab/page item persistence and nested page
controls from `.frm` remain explicit follow-up depth. The fixture also proves
`.frx` indirection, opaque image-handle diagnostics, and a `DrawImage` Scene
primitive with deterministic placeholder rendering. It does not claim real
decoded image pixels or a full MS-OFORMS persistence codec.
