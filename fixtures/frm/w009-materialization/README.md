# W009 Representative Materialization Fixture

Status: selected-slice fixture for `oxforms-zhz.22`.

`w009-representative.frm` exercises the current VBA object-model materializer:

- `UserForm` caption and client size;
- `Label`, `TextBox`, two `CommandButton` controls, and `CheckBox`;
- geometry stored as `.frm` twips and converted to OxForms point units;
- caption/text/value, tab order, visible/enabled, colors, border style,
  default/cancel button flags;
- one `MSForms.Image` block with a `Picture` reference into
  `w009-representative.frx`.

The Image control itself is not materialized yet; `oxforms-zhz.22` records the
image block and `.frx` reference metadata so `oxforms-zhz.28` can consume the
binary/image lane without reviving the deleted Rust-side form projection.
