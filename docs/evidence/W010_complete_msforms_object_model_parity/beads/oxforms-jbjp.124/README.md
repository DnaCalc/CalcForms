# Programmatic Text, first Show and redundant SetFocus: partial native observation

`native-focus-updates.json` (Excel 16.0.20527, one owned hidden Excel on a private desktop,
`tools/office-oracle/capture_focus_updates.py`; the same-session sweep in
`../oxforms-jbjp.131/native-round12.json` scenarios 0 to 4 agrees) records the event log after
each step of six TextBox scenarios.

Observed without an activated form window:
- Programmatic `Text` raises Change only (no Enter, Exit, BeforeUpdate or AfterUpdate), whether
  set before Show, while the control is the ActiveControl, or while another control is.
- Assigning the current Text again raises nothing.
- Show leaves the first TextBox as ActiveControl and raises no event. SetFocus on the
  ActiveControl raises nothing, and SetFocus on another control changes ActiveControl without
  Enter or Exit.
- Form.Activate is raised lazily, at the first SetFocus or Text write after Show.
- SetFocus before Show returns without an error or event.

Not resolved: the Run 9 native-trace log with `Qty.BeforeUpdate/AfterUpdate` came from a form
window that was the active window. Activation attempts here (SetForegroundWindow, thread-input
attach, SwitchToThisWindow, WM_ACTIVATE) did not make the private-desktop form foreground, so
Enter/Exit and update events never fired and the dirty/validation policy could not be isolated.
No runtime change was made; the differing preparation logs stay as recorded. Next step needs a
route that activates the owned form window on the private desktop (the earlier input harness).
