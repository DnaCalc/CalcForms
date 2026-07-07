# W009 Representative Materialization Fixture

Status: selected-slice fixture for `oxforms-zhz.22` and the representative Image lane
`oxforms-zhz.28`.

`w009-representative.frm` exercises the current VBA object-model materializer:

- `UserForm` caption and client size;
- `Label`, `TextBox`, two `CommandButton` controls, `CheckBox`, and `Image`;
- geometry stored as `.frm` twips and converted to OxForms point units;
- caption/text/value, tab order, visible/enabled, colors, border style,
  default/cancel button flags;
- one `MSForms.Image` block with a `Picture` reference into
  `w009-representative.frx`.

`oxforms-zhz.28` now materializes the Image block into a live `Forms.Image.1`
control. The fixture proves `.frx` indirection, opaque image-handle diagnostics,
and a `DrawImage` Scene primitive with deterministic placeholder rendering. It
does not claim real decoded image pixels or a full MS-OFORMS persistence codec.
