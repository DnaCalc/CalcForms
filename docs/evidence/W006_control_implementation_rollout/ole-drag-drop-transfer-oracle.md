# W006 OLE Drag/drop Transfer Oracle

Status: live Office/MSForms true drag/drop evidence for `oxforms-0a0.16`.

Capture:
[`captures/ole-drag-drop-transfer-20260623T093507Z/`](captures/ole-drag-drop-transfer-20260623T093507Z/).

Fixture:
[`../../../fixtures/office-oracle/excel-msforms/userforms/drag-drop-transfer/`](../../../fixtures/office-oracle/excel-msforms/userforms/drag-drop-transfer/).

Validator:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\evidence\Test-W006OleDragDropEvidence.ps1 -CaptureDir docs\evidence\W006_control_implementation_rollout\captures\ole-drag-drop-transfer-20260623T093507Z
```

## Public Facts

- `docs/specs/FM20_EVENT_FACTS.md` records public `BeforeDragOver` and
  `BeforeDropOrPaste` signatures for TextBox targets, including target-local
  `X`/`Y`, `Shift`, `DragState` or `Action`, `MSForms.DataObject`, and mutable
  `Cancel`/`Effect` helpers.
- The installed public FM20 type library exposes
  `MSForms.DataObject.StartDrag(OKEffect)`. The fixture uses this public method
  from repo-owned VBA after setting the repo-owned text seed with public
  `DataObject.SetText`.
- `docs/specs/INPUT_INTERACTION_MODEL.md` section 5.4 keeps platform drag
  sessions and live COM `MSForms.DataObject` instances outside OxForms core
  state; this evidence is an oracle input, not runtime architecture.

## Observed Facts

The capture generated a repo-owned Excel/MSForms workbook, opened a modeless
`MSForms.UserForm`, and drove public `user32 SendInput` mouse input from a
source `MSForms.Label` to a target single-line `MSForms.TextBox`.

The source label handled `MouseDown`, created a public `MSForms.DataObject`,
set the repo-owned seed `repo_owned_drag_text_seed_v1`, and called public
`DataObject.StartDrag fmDropEffectCopy`.

Live MSForms rows observed:

- `StartDragAttempt` source fixture row before target drag/drop rows;
- multiple `BeforeDragOver` rows before one `BeforeDropOrPaste` row;
- `BeforeDropOrPaste` before `Change`;
- target `BeforeDragOver` rows include `X = 63`, `Y = 15`, `Shift = 0`, and
  `DragState` values `0` then `2`;
- target `BeforeDropOrPaste` includes `X = 63`, `Y = 15`, `Shift = 0`, and
  `Action = 3`;
- `Cancel` helper before/after stayed `False` -> `False`;
- `Effect` helper before/after was `1` -> `1` after the fixture accepted the
  repo-owned text drop by setting `Effect.Value = fmDropEffectCopy`;
- `DataObject` was present and public `GetFormat(1) = True`;
- text payload was identified only as the repo-owned drag seed id;
- final target TextBox `Text`/`Value` equals the repo-owned drag seed.

The event log deliberately stores no live COM object identity, no platform drag
object identity, and no unexpected payload text.

## Non-claims

- This capture is not an exhaustive MSForms drag/drop parity claim.
- The fixture mutates `Effect.Value` to accept the repo-owned text drop; it does
  not prove passive/default target behavior.
- Rich data formats, cross-application drag sources, rejected drops, cancellation
  behavior, modifier combinations, and handler mutation variations remain
  unobserved.
- This capture itself does not implement OxForms runtime drag/drop behavior.
  `oxforms-0a0.15` separately implements only the first host-neutral
  text-drop subset using serializable `drag_over` and `drop_or_paste` rows.
- Paste observations from `oxforms-0a0.13` remain adjacent evidence only and are
  not mixed with this true drag/drop oracle.

## Downstream Impact

`oxforms-0a0.15` implements a first drag/drop DataObject trace and dispatch
subset from this oracle: value-shaped `DragOver`/`DropOrPaste` rows, serializable
data snapshots, target-local coordinates, `BeforeDragOver`/`BeforeDropOrPaste`
metadata, and helper-result boundaries for the accepted repo-owned text drop.
Broad DataObject parity, rich formats, cancellation/mutation breadth,
cross-application drags, and final runtime parity remain non-claims unless later
beads implement and test those named subsets.

## Follow-up Beads

- `oxforms-k1i`: harden `Capture-Window.ps1` against transient
  `CopyFromScreen` invalid-handle failures observed during later reruns. This
  does not block `.16` because the committed capture and checksum/evidence
  validators pass.
