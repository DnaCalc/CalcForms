# W008 CheckBox / Edit-Revert Dirty Focus-Out Oracle Capture

Capture id: w008-checkbox-update-20260629T003700Z
Bead: `oxforms-esq.14`
Status: `captured`

Black-box Excel/MSForms evidence for two esq.14 questions: (1) does a dirty CheckBox fire
BeforeUpdate/AfterUpdate before Exit on focus-out, and (2) does an edit-then-revert (net value
unchanged) still fire BeforeUpdate/AfterUpdate? Not an OxForms output comparison and not an
exhaustive parity claim.

## Facts

- `checkbox_dirty_focus_out`: a toggled (dirty) CheckBox losing focus fires
  `BeforeUpdate -> AfterUpdate -> Exit`, exactly like a TextBox. Full row order: TextBox1 Exit
  (clean, no BeforeUpdate) -> CheckBox1 Enter(False) -> Change(Value True) -> Click(Value True)
  -> BeforeUpdate(Cancel False) -> AfterUpdate -> Exit(Cancel False) -> TextBox2 Enter. A
  CheckBox DOES expose Enter/Exit/BeforeUpdate/AfterUpdate (previously unknown for
  MdcCheckBoxEvents). The mouse toggle order is value-first Change -> Click (matches p41).
  **esq.14 consumes this:** the two-stage focus-out validation now treats a dirty CheckBox like
  a dirty TextBox.
- `edit_revert_focus_out`: typing a char then Backspacing back to the value-at-focus-gain
  (net change = none) STILL fires `BeforeUpdate -> AfterUpdate` on focus-out:
  KeyDown(231=VK_PACKET) -> Change(X) -> KeyUp -> KeyDown(8=Backspace) -> Change(empty) -> KeyUp
  -> BeforeUpdate(False) -> AfterUpdate -> Exit -> TextBox2 Enter. **esq.14 consumes this:**
  MSForms uses the sticky edited-since flag, NOT a net-value-vs-baseline gate, so the OxForms
  sticky dirty flag (esq.7) is already faithful and the OldValue/net-value refinement is a
  NON-GOAL (dropped).

## Driving method (honest provenance)

Driven by computer-use vision (precise clicks + keystrokes) on a background-COM-hosted Excel.
Each scenario was a separate ClearLog -> Show -> SetW008Scenario* -> drive -> export run, so the
per-run worksheet sequence restarts at 1 (the `scenario` column distinguishes the runs). The
edit-revert keystroke was injected via VK_PACKET (KeyCode 231), a computer-use type() artifact --
the load-bearing facts are the Change/BeforeUpdate/AfterUpdate firings, not the KeyCode value.
`generated_workbook` is null -- the throwaway workbook was not retained; the fixture sources +
`tools/office-oracle/New-W008OracleWorkbook.ps1` regenerate it deterministically.

Two event-log provenance notes: (1) `observed_facts.row_count` counts ALL CSV rows including the
per-run Initialize + TextBox1 Enter setup rows (empty `scenario`); `scenario_summaries`
enumerate only the scenario-tagged rows (seq >= 3). (2) The `notes` column is POST-CAPTURE author
annotation -- the fixture logger writes it empty; the captured fields are
sequence/scenario/control_name/event_name/arg_name/arg_before/arg_after/focus_owner_after/value_after.

## Clean-room Note

Repo-owned fixture sources, public Excel/VBIDE automation, public Windows input, and worksheet
export only. No Office internals, decompilation, disassembly, or OxForms output comparison.