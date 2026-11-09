# Enter/Exit/Update events cannot be measured on a private desktop (round 13)

`native-round13.json`, `../oxforms-jbjp.133/native-round13c.json` and `native-round13d.json` (Excel 16.0.20527, one
owned Excel each, on private desktops, guard output 0 windows and 0 foreground hits on the owner desktop).

What was tried, in order, and what each showed:

1. `Application.Visible = True` on the private desktop (13). `GetForegroundWindow` stays 0: a desktop that is not the
   input desktop has no foreground window, whoever owns the windows.
2. Activating from inside Excel's own UI thread (13b/13c): a macro declares `SetActiveWindow`/`SetFocus` and calls them
   on the form's `ThunderDFrame`. This works: the thread's active window and focus window both equal the form window
   (`activeAfter` and `focus` equal `hwnd`; `foreground=0`). `Form.Activate` is raised, at the activation call.
3. With the form active that way, the six `.124` scenarios (13c) and posted Tab keys (13d) were repeated. Programmatic
   `SetFocus` and posted Tab both move `ActiveControl`, and none raises Enter, Exit, BeforeUpdate or AfterUpdate. Posted
   `WM_CHAR` to the focused window does not edit the TextBox (Text stays empty), so a user-edit (dirty) baseline cannot
   be built either.

Reading: the thread-level active window is not enough for MSForms to raise focus and update events; they need the form
to be the real foreground window of an input desktop, which a private desktop never has. The Run 9 trace with
`Qty.BeforeUpdate/AfterUpdate` came from such a window. So on a private desktop the update-event policy cannot be
isolated, and `.124` is recorded as: programmatic Text raises Change only (unchanged), same-value Text and redundant
SetFocus are silent (unchanged), Form.Activate is lazy (unchanged), and Enter/Exit/Update events are not observable
here. No runtime change. The remaining route is an interactive session on an input desktop, which the hard rules forbid
for this lane.
