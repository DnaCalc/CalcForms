# Modal Lifecycle And Pump Observations

Capture id: `interaction-events-modal-20260623T045300Z`
Bead: `oxforms-xvx.20`

## Observed Facts

- The capture driver invoked the repo-owned Excel macro
  `ShowW005InteractionOracleModal` after clearing `W005EventLog`.
- `modal-event-log.json` and `modal-event-log.csv` contain 133 worksheet rows
  from the generated workbook's VBA handlers for the modal run.
- Modal run event rows include `Initialize`, `Activate`, `MouseMove`,
  `MouseDown`, `MouseUp`, `Click`, `Enter`, `Exit`, `BeforeUpdate`,
  `AfterUpdate`, `KeyDown`, `KeyPress`, `KeyUp`, `Change`, `QueryClose`, and
  `Terminate`.
- Modal run event rows that occur while the form is visible are tagged
  `show_mode=modal` by the fixture. The initial `Initialize` and final
  `Terminate` rows are tagged `show_mode=unknown` by the fixture.
- The modal close path observed `QueryClose` with `cancel_before=0`,
  `cancel_after=0`, and `close_mode=0`, followed by an `Exit` row for
  `OracleDefaultButton` and a final `Terminate` row.
- `modal-input-actions.json` records automated public Windows input. The
  `manual_inputs` arrays in the action log and event log are empty.

## Lifecycle/Pump Vocabulary

- `modal_frame`: supported as the W005 vocabulary label for this capture's show
  mode because the driven macro is the modal-show fixture macro and the event
  rows are tagged `show_mode=modal`.
- `nested_modal_depth`: no nested modal form was exercised by this fixture. The
  worksheet `nesting_depth` column remained `0` for all modal rows; this capture
  does not prove final nested modal depth semantics.
- `host_modeless_pump`: present only in the modeless baseline run in the same
  directory; it is not the classification for the modal event log.
- `vba_dispatch_reentrancy`, `host_callback_reentrancy`, and
  `doevents_yield`: not exercised by this capture.

## Assumptions

- The fixture's `show_mode=modal` tag is treated as an observation emitted by
  repo-owned VBA code while real Excel/MSForms handled the modal form. It is not
  an OxForms behavior claim.
- The public automation helper drove the visible modal window from a separate
  PowerShell job; that helper is evidence infrastructure, not runtime
  architecture.

## Non-claims

- This capture does not claim exhaustive MSForms lifecycle or event parity.
- This capture does not compare OxForms output.
- This capture does not establish nested modal form behavior.
