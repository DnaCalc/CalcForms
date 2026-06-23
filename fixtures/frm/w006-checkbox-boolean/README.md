# W006 CheckBox Boolean `.frm` Fixture

This fixture is a narrow canonical `.frm` input for `oxforms-0a0.11` and the
downstream implementation bead `oxforms-0a0.12`.

It contains one small UserForm with two `MSForms.CheckBox` controls:

- `OracleCheckBoxFalse`, with `Value = 0`.
- `OracleCheckBoxTrue`, with `Value = -1`.

The fixture intentionally has no `.frx` references and no picture, icon, list,
or binary resource properties. Coordinates are serialized as twips and must be
converted to point-based `form_logical` values using
`docs/specs/COORDINATE_MODEL.md`: 1 twip = 1/20 point.

Readiness scope:

- `Caption`, boolean `Value`, `Enabled`, `Visible`, `Left`, `Top`, `Width`,
  `Height`, `TabIndex`, and `TabStop`.
- It is fixture input, not MSForms oracle evidence.
- It does not claim `OptionButton`, `ToggleButton`, tri-state/null,
  `ControlSource`, full morph-control persistence, native FM20-named dispatch,
  or pixel-perfect rendering parity.

