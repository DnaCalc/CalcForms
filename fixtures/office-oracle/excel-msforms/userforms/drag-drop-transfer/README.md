# W006 OLE Drag/drop Transfer Oracle Fixture

This fixture is a repo-owned Excel/MSForms oracle input for bead
`oxforms-0a0.16`.

It attempts a true OLE/MSForms drag session using public VBA and public FM20
automation surfaces:

- a source `MSForms.Label` creates a public `MSForms.DataObject`;
- the source sets the repo-owned text seed with `DataObject.SetText`;
- the source starts the drag with public `DataObject.StartDrag`;
- a target `MSForms.TextBox` logs `BeforeDragOver` and
  `BeforeDropOrPaste` rows if MSForms raises them.

The target handlers may set `Effect.Value = fmDropEffectCopy` when the
repo-owned text format is present so the fixture can accept the test drop. The
event log records helper values before and after that public handler mutation.

Non-goals:

- no OxForms runtime behavior;
- no private Office internals, decompilation, or disassembly;
- no live COM object identity in evidence artifacts;
- no reuse of the `.13` paste observation as true drag/drop evidence.
