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
