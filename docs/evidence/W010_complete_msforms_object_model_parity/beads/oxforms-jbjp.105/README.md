# Real workbook data-entry form: measured initial subset

`fixtures/workbooks/data-entry/order-entry.xlsm` is a genuine workbook authored
and saved by the same hidden owned Excel 20232 used for run 6. Five controls are
persisted; its original Initialize handler creates ComboBox, ListBox, two Frame
option groups, a two-page MultiPage and page content. Its own handlers implement
validation, save and cancel. The qualified native FRM/FRX export and exact workbook
hash are retained. No OxVba edits, owner input, security or registration changes.

Native State and Trace match the original handlers running on VM3, including
programmatic ComboBox Change and ListBox Change before Click during Initialize.
The adapter supplies a separate referenced MSForms source project, so qualified
application declarations bind without rewriting their types or procedure bodies.
Current implementation classes are exposed by that source provider; this is not
the final narrowed W010 public facade. Native fractional ClientWidth 8280.001
twips is accepted with finite/range checks and without integer truncation.

The real form exposed overflow in hierarchical node IDs for controls inside Page
inside MultiPage. All containers now delegate allocation to the owning UserForm.
Control IDs exclude slots 900..999 in each thousand; those slots are reserved for
local paint parts. The allocator rejects values above the signed Long paint-part
capacity. Existing container clipping/removal and incremental tests still apply.

The runtime regression also exercises an empty-name save rejection, name/team/
product changes, independent option groups, page switching, Enter/default and
Esc/cancel with normalized in-process input. It explicitly establishes reducer
focus using Tab. Run 7 [adds paired native later observations](../oxforms-jbjp.105.1/README.md)
and exact per-step State/Trace comparisons. The original coverage below remains
historical rather than retroactively claiming broader input or geometry parity.
Initial Show focus, BeforeUpdate veto, full event order, Hide/Show/Unload,
selection/scrolling and geometry remain `.105.1` work. `coverage.json` retains
210 failed missing measurements across all 20 controls plus the form at 100/150;
no screenshots or geometry are invented. `.105` remains open.

`fixture-sha256.json` and `validate_data_entry.py` verify all fixture bytes, the
native code export and these limits. The Rust test imports the actual workbook,
checks that original source survived, compares native initial State/Trace and
runs the later regression. `cleanup.json` records the stopped exact owned handle,
one resumed-session Excel launch and unchanged original comparison workbook.

Fresh review checked form/source project separation, unchanged application
procedures, same-value selection suppression, nested parent/clip tests, reserved
paint-part identities and signed Long limits. Rust: 211 passed, seven existing
ignored; fmt and clippy with warnings denied passed. Aggregate evidence 55/55,
whitespace and bead-cycle checks passed. Missing native rows prevent parity closure.
