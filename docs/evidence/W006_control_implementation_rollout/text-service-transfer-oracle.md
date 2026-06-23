# W006 Text-service Transfer Oracle

Status: live Office/MSForms evidence plus exact blockers for `oxforms-0a0.13`.

Capture:
[`captures/text-service-transfer-20260623T084627Z/`](captures/text-service-transfer-20260623T084627Z/).

Fixture:
[`../../../fixtures/office-oracle/excel-msforms/userforms/text-service-transfer/`](../../../fixtures/office-oracle/excel-msforms/userforms/text-service-transfer/).

Validator:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\evidence\Test-W006TextServiceTransferEvidence.ps1 -CaptureDir docs\evidence\W006_control_implementation_rollout\captures\text-service-transfer-20260623T084627Z
```

## Public Facts

- `docs/specs/FM20_EVENT_FACTS.md` records the public
  `BeforeDropOrPaste` signature for `TextBox`: `Cancel` as
  `MSForms.ReturnBoolean`, `Action` as `MSForms.fmAction`,
  `Data` as `MSForms.DataObject`, `X`/`Y` as `Single`, `Effect` as
  `MSForms.ReturnEffect`, and `Shift` as `Integer`.
- `docs/specs/INPUT_INTERACTION_MODEL.md` section 5.4 keeps clipboard,
  `DataObject`, IME, dead-key, paste, and drag/drop runtime behavior gated by
  live evidence or exact blockers.
- `docs/specs/TRACE_REPLAY_SCHEMA.md` requires evidence for these deferred
  surfaces to stay diagnostic/oracle-only until schemas and validators accept
  new runtime row names.

## Observed Facts

The capture generated a repo-owned Excel/MSForms workbook, set the Windows
clipboard to the repo-owned text seed `repo_owned_text_seed_v1`, opened a
modeless `MSForms.UserForm`, and attempted to drive paste into a focused
single-line `MSForms.TextBox`.

The desktop session blocked the public `Ctrl+V` keyboard driver:
`SetForegroundWindow` returned `False`, and
`System.Windows.Forms.SendKeys.SendWait("^v")` failed with access denied. This
is an input-driver blocker, not an MSForms behavior fact.

The capture then used the public MSForms `TextBox.Paste` method as a narrower
paste/DataObject oracle. Live MSForms rows observed:

- `BeforeDropOrPaste` before `Change`;
- `BeforeDropOrPaste.X = 0`, `Y = 0`, `Shift = 0`;
- `Action = 2`;
- `Cancel` helper before/after: `False` -> `False`;
- `Effect` helper before/after: `0` -> `0`;
- `DataObject` present, public `GetFormat(1) = True`;
- text payload identified only as the repo-owned seed id;
- final TextBox `Text`/`Value` equals the repo-owned seed.

The event log deliberately stores no live COM object identity and no unexpected
clipboard payload text.

## Blockers And Non-claims

- `Ctrl+V` clipboard-shortcut ordering remains blocked by the current desktop
  input-driver failure. No `KeyDown`/`KeyPress`/`KeyUp` ordering or
  `ReturnInteger` interaction is claimed for clipboard shortcuts.
- IME/composition is not observed. No composition, preedit, commit, cancel,
  helper mutation, or TextBox value behavior is claimed.
- Dead-key preedit is not observed. No dead-key ordering or committed-text
  behavior is claimed.
- True OLE drag/drop is not observed in this `.13` paste run. Later bead
  `oxforms-0a0.16` captures a separate true drag/drop oracle in
  [`ole-drag-drop-transfer-oracle.md`](ole-drag-drop-transfer-oracle.md).
- `BeforeDragOver` was not observed in this run. That is a non-claim, not a
  negative fact about MSForms.
- The public `TextBox.Paste` observation is not evidence that keyboard shortcut
  paste, menu paste, rich-format paste, or true drag/drop has the same ordering.

## Follow-up Beads

- `oxforms-0a0.16`: closed by the separate live OLE drag/drop
  `DataObject` oracle in
  [`ole-drag-drop-transfer-oracle.md`](ole-drag-drop-transfer-oracle.md).
- `oxforms-0a0.17`: build or precisely block a deterministic clipboard
  shortcut and text-service oracle driver for `Ctrl+V`, IME/composition, and
  dead keys.

## Downstream Impact

`oxforms-0a0.14` implements a first host-neutral text-only paste subset using
the observed public `TextBox.Paste`/`BeforeDropOrPaste -> Change` fact shape.
The implementation accepts only normalized service `ClipboardResult(Get)` rows
with serializable plain text for the focused single-line TextBox, emits
`BeforeDropOrPaste` metadata before `Change`, replaces the selection, and
requests repaint. It does not use the live platform clipboard or a COM
`MSForms.DataObject` inside `oxforms-core`; unsupported formats are diagnostic
no-ops.

The `.14` subset keeps `Ctrl+V` shortcut ordering, IME/dead-key behavior, menu
paste, rich formats, true drag/drop, broad `DataObject` parity,
`BeforeDropOrPaste.Action` mutation, handler cancellation behavior, and native
FM20-named OxVba dispatch as non-claims unless `oxforms-0a0.17` or another bead
adds evidence and implementation.

`oxforms-0a0.15` is no longer blocked on the absence of a live drag/drop oracle:
`oxforms-0a0.16` supplies separate true drag/drop evidence. `.15` may still use
this bead's paste `DataObject` facts only as adjacent evidence; it must use the
`.16` capture for `BeforeDragOver`, drag-session `DataObject`, drop-effect, and
drop-ordering facts.
