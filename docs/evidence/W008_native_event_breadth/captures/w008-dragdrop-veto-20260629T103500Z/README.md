# W008 Drag-Drop Veto (BeforeDropOrPaste Cancel) Oracle Capture

Capture id: w008-dragdrop-veto-20260629T103500Z
Bead: `oxforms-4f8`
Status: `captured`

Black-box Excel/MSForms evidence for whether a vetoing `BeforeDropOrPaste` (Cancel=True)
suppresses a DRAG-DROP drop (the drag-drop analog of the keyboard-paste veto, esq.17). Not an
OxForms output comparison and not an exhaustive parity claim.

## Facts

- `dragdrop_baseline` (gVetoDrop False): `SourceBox MouseDown(s) -> TargetBox
  BeforeDropOrPaste(Cancel False->False; Action=3; Effect=3; data_object=present) -> TargetBox
  Change(value=OxFormsDragSeed) -> TargetBox Enter -> SourceBox Change(emptied)` -- the drop
  inserts (a MOVE). **Action=3** is fmActionDragDrop, distinct from Action=2 for a keyboard paste.
- `dragdrop_veto` (gVetoDrop True): `SourceBox MouseDown(s) -> TargetBox
  BeforeDropOrPaste(Cancel False->True; Action=3) -> SourceBox Change(emptied)` -- **NO TargetBox
  Change**; the target drop is suppressed.
- **esq.4f8 consumes this:** honor the drag-drop `BeforeDropOrPaste` Cancel=True veto by
  suppressing the target insert + `Change` -- defer the insert until the Cancel readback folds
  back (the same two-stage path as the keyboard paste, esq.17; `reduce_drop_or_paste` currently
  inserts synchronously before `BeforeDropOrPaste`).

## Caveats / non-claims

- The repeated `SourceBox MouseDown` rows per drag are a STEPPED-PRESS computer-use artifact
  (one physical drag, driven as press -> mouse-move steps -> release), not three real presses.
- The vetoed intra-form MOVE-drag still emptied the SOURCE (`SourceBox Change` to empty in both
  scenarios). That is the SOURCE control's move behavior, NOT the drop-target path OxForms models
  (`reduce_drop_or_paste` only inserts into the target); it is recorded but not consumed.

## Driving method (honest provenance)

Driven by computer-use vision on a background-COM-hosted Excel: SourceBox seeded with
`OxFormsDragSeed` + `DragBehavior` enabled at runtime, its text selected (triple-click), then
dragged onto TargetBox (stepped press -> move -> release). Each scenario was a separate
ClearLog -> drive -> export run (per-run sequence restarts at 1). `generated_workbook` is null --
the throwaway workbook was not retained; the fixture sources + `New-W008OracleWorkbook.ps1`
regenerate it deterministically.

## Clean-room Note

Repo-owned fixture sources, public Excel/VBIDE automation, public Windows mouse input, and
worksheet export only. No Office internals, decompilation, disassembly, or OxForms output comparison.