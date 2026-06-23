# W005 Modeless Interaction Oracle vs Headless Probe

Comparison ID: `interaction-events-modeless-vs-headless-probe`
Bead: `oxforms-xvx.13`; updated by `oxforms-9pr`; checksum pin refreshed by
`oxforms-0a0.8`
Status: observation only

This report relates the authoritative W005 modeless Excel/MSForms interaction
capture to the current OxForms headless probe replay golden. It is not a final
MSForms parity claim, not a pass/fail oracle, and not a screenshot comparison.

## Source Artifacts

MSForms oracle evidence:

- `docs/evidence/W005_input_interaction_model_exploration/captures/interaction-events-20260623T004914Z/oracle-capture-manifest.json`
- `docs/evidence/W005_input_interaction_model_exploration/captures/interaction-events-20260623T004914Z/modeless-event-log.json`
- `docs/evidence/W005_input_interaction_model_exploration/captures/interaction-events-20260623T004914Z/modeless-input-actions.json`
- `docs/evidence/W005_input_interaction_model_exploration/captures/interaction-events-20260623T004914Z/modeless-coordinate-calibration.json`

OxForms evidence:

- `docs/evidence/W005_input_interaction_model_exploration/trace-replay/w005-headless-probe-replay.golden.v1.json`
- `docs/evidence/W005_input_interaction_model_exploration/trace-replay/w005-headless-probe-display-list.golden.v1.json`
- Supporting visible-input evidence:
  `docs/evidence/W005_input_interaction_model_exploration/captures/visible-input-smoke-20260623T035500Z/`

The JSON manifest records exact source hashes.
Its trace-replay checksum-manifest pin was refreshed after the W006 harness
hardening README documentation changed the committed
`trace-replay/checksums.sha256` file.

## Scenario Mapping

The mapping is partial by design. The MSForms capture is a long modeless run
with 21 automated input actions and 1116 event rows. The OxForms headless
golden is a focused four-step script:

1. show modeless;
2. click the TextBox probe;
3. type committed text `A`;
4. click the default CommandButton probe.

The comparison therefore maps only the matching MSForms slices:

| Slice | MSForms rows | OxForms rows | Classification |
|---|---:|---|---|
| Modeless show/Activate | `1..3` | `row-0002`, `row-0010`, `row-0013` | implemented match, with lifecycle gaps below |
| TextBox mouse down/up | `114..115` | `row-0031`, `row-0044` | implemented match |
| TextBox native `Click` | none | none | implemented match with current oracle and FM20 metadata |
| TextBox character `a`/`A` | `157..161` | `row-0052`, `row-0058`, `row-0060`, `row-0072` | implemented match for order; known argument gap |
| CommandButton direct click | `567..569` | `row-0082`, `row-0098`, `row-0100` | implemented match |
| Close/query/terminate | `1114..1116` | none in headless replay | known gap for this comparison |

The other MSForms actions, including label drag, Backspace, Tab, Shift+Tab,
Enter/Escape/default/cancel/accelerators, direct cancel click, double-click
probes, and close, are out of scope for the headless replay golden compared
here.

## Event Order

Implemented matches:

- Both artifacts reach `Activate` on the modeless show path.
- Both record TextBox `MouseDown` before `MouseUp` for the mapped TextBox
  focus click.
- Neither artifact records a native TextBox `Click` dispatch for the mapped
  TextBox focus click. This aligns with `FM20_EVENT_FACTS.md`, which records
  no `Click` member on `MdcTextEvents`/TextBox.
- Both record TextBox `KeyDown`, `KeyPress`, `Change`, and `KeyUp` in that
  order for the first committed character.
- Both record CommandButton `MouseDown`, `MouseUp`, and `Click` in that order
  for a direct button click.

Known gaps:

- MSForms records focus/validation rows such as `BeforeUpdate`, `AfterUpdate`,
  `Exit`, and `Enter` around focus movement. The current replay has only a
  `transfer_focus` effect for this surface.
- The headless replay does not include close; the MSForms capture records
  `QueryClose`, `Exit`, and `Terminate`. The visible smoke has QueryClose-path
  evidence but not Terminate parity.

## Arguments And Metadata

Implemented matches:

- Mapped mouse rows preserve left-button and `Shift=0` metadata on both sides.
- The CommandButton direct-click sequence uses the expected no-argument `Click`
  event shape on both sides.

Known gaps:

- MSForms TextBox click rows record `msforms_event_args` `X=36`, `Y=12`;
  OxForms records `control_local` `X=8`, `Y=8` because the replay uses a
  different probe geometry and target point.
- MSForms OK-button rows record `X=36`, `Y=12`; OxForms records `X=16`, `Y=12`
  for its synthetic OK probe geometry.
- MSForms typed lowercase `a` through SendKeys and records `KeyCode=65`,
  `KeyAscii=97`, `Shift=0`. OxForms typed uppercase `A` and records normalized
  shift diagnostics plus `key_ascii_placeholder=65`.
- MSForms rows are live VBA handler observations. OxForms `vba_dispatch` rows
  are reconstructed from reducer `FireVbaEvent` effects and have status
  `not_executed_headless_replay`.

Uncertain oracle:

- This mapped slice does not settle mutation semantics for
  `MSForms.ReturnInteger` helper arguments. The capture does record
  cancel-before/after values for validation and close rows, but those are not
  exercised by the headless replay script.

## Coordinates

Both evidence sets use the W005 coordinate vocabulary. The MSForms capture
preserves screenshot calibration, screen/input coordinates, fixture geometry,
and live `msforms_event_args`. The OxForms replay preserves synthetic
`client_pixels`, `form_logical`, `control_local`, display-list coordinates, and
render metadata.

This comparison does not claim coordinate parity. The MSForms modeless
calibration derives a 96 DPI point scale and form origin `x=8`, `y=31` from the
scoped label border. The headless replay uses synthetic 1:1 client/form
coordinates.

## Lifecycle And Rendering

MSForms modeless evidence includes `Initialize`, `Activate`, `QueryClose`, and
`Terminate`. Modal evidence now exists separately at
`docs/evidence/W005_input_interaction_model_exploration/captures/interaction-events-modal-20260623T045300Z/`.
This comparison remains modeless-only and does not settle modal or nested pump
parity.

OxForms replay records lifecycle/pump state for modeless visibility and records
display-list/invalidation/render-hash rows. MSForms evidence records a
screenshot and event log, not a display-list or invalidation stream, so no
render diff is attempted.

The visible smoke capture is supporting evidence that real Windows input enters
the W005 path and reaches TextBox text mutation, CommandButton click effects,
and QueryClose. It is not used as the main comparison trace because it is not
the same scripted scenario as the headless golden.

## Follow-Ups

- `oxforms-xvx.20`: completed modal MSForms interaction oracle capture; not
  part of this modeless comparison artifact.
- `oxforms-xvx.21`: completed evidence hygiene follow-up for ignored `.log`
  command files referenced by the modeless capture manifest.

`oxforms-9pr` resolves the earlier TextBox `Click` mismatch by removing the
unsupported native TextBox `Click` dispatch from the OxForms headless replay.

## Validation

Run from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\evidence\Test-W005InteractionComparison.ps1 -ManifestPath docs\evidence\W005_input_interaction_model_exploration\comparisons\interaction-events-modeless-vs-headless-probe.json
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\trace-replay\Test-TraceReplaySchema.ps1 -TracePath docs\evidence\W005_input_interaction_model_exploration\trace-replay\w005-headless-probe-replay.golden.v1.json
cargo run -p oxforms-core --example w005_trace_replay -- --check
```

## Clean-Room Note

This comparison uses repo-owned fixtures and OxForms traces, public
Excel/VBIDE automation output, public Windows input/capture metadata, and
committed public FM20 type-library facts. It uses no Office internals,
decompilation, disassembly, or non-public source.
