# W006 Interaction `.frm` Slice Fixture

This fixture is a deliberately small canonical `.frm` input for
`oxforms-0a0.4`. It mirrors the W005 interaction oracle geometry for
`Label`, `TextBox`, and `CommandButton` controls while avoiding `.frx` binary
resources.

Coordinates in this file are serialized as twips. The `oxforms-core` selected
loader converts them to point-based `form_logical` values using the rule in
`docs/specs/COORDINATE_MODEL.md`: 1 twip = 1/20 point.

The fixture is not a full `.frm` corpus and does not claim complete persistence
or native FM20 event dispatch parity.
