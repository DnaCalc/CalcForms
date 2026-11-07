# Real workbook: native later actions

Run 7 observes the original `order-entry.xlsm` at 100% and 150% in the reused
hidden Excel. Ten steps preserve exact State and cumulative Trace: initial,
invalid save, name/team/product changes, independent shipping/payment groups,
review page, valid save and cancel/Hide. Both scales agree. The Rust workbook
test compares every state and event string while running the original handlers.

The fixture is opened read-only and never saved. Only a standard observer module
is added in memory; its reset unloads the previous default instance before each
scenario. Native default Enter exercises empty-name validation. After a native
page change leaves no focused HWND, public MSAA default actions invoke Save and
Cancel. This proves those commands, not native Enter/Escape after that page change.
Runtime normalized Enter/Escape reaches the same commands and exact results.

Native initial focus is NameInput. Run 8 captures initial and repeated Show focus
at both scales in `show-focus` and `show-focus-150`. Runtime Show now establishes
NameInput directly, comparing siblings before entering containers. Runtime Add
appends TabIndex; persisted omitted TabIndex still restores zero. The workbook
test requires immediate Enter without its former preparatory Tab.
The original `.105/coverage.json` is historical and unchanged: its 210 geometry,
input and lifecycle unknowns are not silently converted into passes by these
new State/Trace observations. Broader traversal, BeforeUpdate veto, scrolling,
full lifetime and two-scale geometry remain open in `.105.1`/`.105`.

Replay `python -B tools/office-oracle/validate_order_entry_scenarios.py`.
Fresh review caught and rejected a stale default form before accepting this
capture; strict initial state and invalid-save checks now require a fresh form.

Run 9 adds qualified original-handler input in `run9-validation-key-native`.
Excel's own thread queues characters, Backspace, Tab and Escape to its focused
private-desktop HWND. The empty edited name must produce Name.BeforeUpdate and
Name.Veto while retaining NameInput. A completed name accepts Tab to SaveButton;
Escape focuses CancelButton, Hide/Show retains it, and Unload/new-default Show
returns to NameInput with fresh original State/Trace.

All **308 state, trace and focus fields** match VM3 at both scales. This exposed
two corrected defects: global sorting mixed a child's local TabIndex with root
siblings, and host Show acted on the old held form after Unload. Tab ordering
now sorts siblings before entering their containers; Show refreshes its default
reference before making the form visible (`.95.2`). A synthetic Frame regression
also requires all three children before the next root sibling.

The initial `run9-validation-native` probe posted only a Backspace character,
which did not edit native text. It never reached the intended veto and earns no
credit. The corrected capture verifies empty text and the exact veto/focus state
before accepting a result. Neither original saved handlers nor workbook bytes
were changed. `validate_order_entry_validation.py` replays every qualified field.
The historical 210 unknown table remains; geometry and scrolling remain open.
