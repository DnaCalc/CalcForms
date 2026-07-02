# W006 `.frm` Interaction Slice

Status: historical implemented-subset for `oxforms-0a0.4`, extended by `oxforms-0a0.12`
for the narrow CheckBox boolean-value fixture. The old `oxforms-core` loader and
`ControlNode` projection were later deleted. W009's current selected `.frm/.frx` path is
`vba/oxforms/OxFrmMaterializer.cls`, which materializes directly into the live VBA
`UserForm.Controls.Add` object model.

## Scope

This slice connects a deliberately small canonical `.frm` fixture to the W005
interaction state model in `oxforms-core`.

Input fixture:
`fixtures/frm/w006-interaction-slice/w006-interaction-slice.frm`.

Implemented subset:

- top-level UserForm name, caption, `ClientWidth`, and `ClientHeight`;
- `MSForms.Label`, `MSForms.TextBox`, and `MSForms.CommandButton` child blocks;
- `MSForms.CheckBox` child blocks for the W006 boolean-value lane only;
- `Left`, `Top`, `Width`, and `Height` loaded from twips and converted to
  point-based `form_logical` bounds;
- `Caption`, TextBox `Text`, `Enabled`, `Visible`, `TabIndex`, `TabStop`,
  CommandButton `Default`, and CommandButton `Cancel`;
- CheckBox `Value` limited to explicit boolean tokens `0`, `-1`, `False`, and
  `True`; other `Value` tokens are rejected by this selected slice rather than
  coerced;
- W005 reducer metadata for event-capable controls, marked as reducer effect
  metadata only.

The selected interaction fixture and the W006 CheckBox boolean fixture
intentionally have no `.frx` binary resource references.
The loader detects `.frx` property references and reports them, but it does not
decode binary resources or image data in this bead.

## Coordinate Rule

The conversion follows `docs/specs/COORDINATE_MODEL.md`: W005 uses points as
the canonical MSForms logical unit and `.frm` twip values convert exactly as
1 twip = 1/20 point before layout, hit-testing, or trace comparison.

The fixture reuses the W003/W004/W005 calibration geometry:

- form `ClientWidth = 4800` twips -> `240 pt`;
- form `ClientHeight = 3600` twips -> `180 pt`;
- label `Left = 480`, `Top = 480`, `Width = 1920`, `Height = 960` twips ->
  `x=24`, `y=24`, `width=96`, `height=48` points.

This keeps the selected `.frm` path aligned with the W003/W004 label/text
oracle geometry and the W005 interaction fixture geometry without claiming
pixel parity.

## Probe Scaffold Status

`ControlNode` was the host-neutral reference state shape for this selected
implementation subset. That scaffold is now historical: `oxforms-core` and the
`load_selected_frm_interaction_state` projection were deleted, and W009 uses
`OxFrmMaterializer` to build the live VBA object model instead. Hand-built W005
fixture trees remain historical test/evidence provenance only. The
`ControlNode::label`, `ControlNode::text_box`, `ControlNode::command_button`, and
`ControlNode::check_box` constructors were local helper constructors, not a
canonical persistence API.

The W005 generic `Dispatched` carrier remains smoke/test infrastructure only.
The `.frm` slice records event hook metadata as reducer `FireVbaEvent`
capability for the selected controls; native FM20-named OxVba dispatch remains
blocked by `oxforms-0a0.2`.

## Checks

Historical checks run for this bead:

- `cargo test -p oxforms-core` (historical; the crate was deleted in `oxforms-ih6`)
- `cargo fmt --check`
- `cargo clippy --workspace -- -D warnings`
- `cargo test --workspace`
- `git diff --check`
- `br dep cycles`
- `br ready --json`
- `br list --json`
