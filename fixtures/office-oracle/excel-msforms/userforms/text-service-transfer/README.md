# W006 Text-service And Transfer Oracle Fixture

This fixture is a repo-owned Excel/MSForms oracle input for bead
`oxforms-0a0.13`.

It observes one focused, text-only clipboard paste attempt against a single-line
`MSForms.TextBox`. The preferred driver is public keyboard input (`Ctrl+V`).
When the desktop session blocks that input, the capture script records the exact
blocker and may use the public MSForms `TextBox.Paste` method as a narrower
paste/DataObject oracle. The fixture logs keyboard, `Change`, `BeforeDragOver`,
and `BeforeDropOrPaste` rows when MSForms raises them. `MSForms.Return*` helper
arguments are logged with before/after `.Value` columns, and `MSForms.DataObject`
observations are limited to public method summaries plus the known repo-owned
clipboard seed text.

Non-goals:

- no OxForms runtime behavior;
- no private Office internals, decompilation, or disassembly;
- no claim that IME/composition, dead-key preedit, or true OLE drag/drop has
  been observed unless a live capture emits those rows.
