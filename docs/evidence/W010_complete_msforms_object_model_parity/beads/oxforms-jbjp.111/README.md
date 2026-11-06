# FORMS PARITY: measured setter and Enter corrections

**1,089 pass / 521 fail, including 428 missing measurements.** Run 7 has filled
476 of the original 904 missing rows. All 34 targeted behaviour failures now
match the existing independent native observations. W010 remains red.
The 1,610 rows include twelve nested text rows introduced with `.107`; the
original run-6 report had 1,598. Missing-row progress is counted separately.

Programmatic Boolean changes raise Change then Click (only a newly selected
OptionButton clicks); deselected peers change first. ComboBox ListIndex raises
Change then Click. TabStrip, MultiPage, SpinButton and ScrollBar changed setters
raise Change. Repeated assignments stay quiet, and range user-only events retain
their original order. No-default Enter leaves Boolean controls unchanged; Space
activation and form default/cancel routing retain their existing paths.

`runtime/` contains fresh headless VM3 transcripts against the unchanged native
`.107`/`.109` cases. `comparison.json` pins those native references, the eight
changed VBA classes and runtime binary. The inherited image captures are the
earlier coarse guard, not freshly captured pixels for this build. The separate
behaviour runtime hash makes that distinction explicit. Native ListBox scrolling
and TopIndex failures remain visible; missing measurements do not gain credit.

`measured_behaviour.rs` compares literal native setter and Enter/Escape traces;
`workbook_data_entry.rs` checks the original workbook's full State/Trace after
each measured action. The source ledger is regenerated for changed source hashes
without claiming additional full-library members. Replay with
`python -B tools/office-oracle/validate_setter_reference.py`.

Fresh review checked same-value suppression, peer notification order, the
programmatic/user boundary, original workbook handlers and unchanged native
transcripts. Validation passed: 213 Rust tests, seven existing ignored, fmt,
clippy with warnings denied, 37 oracle unit tests, 59/59 aggregate evidence,
staged transcript hashes, whitespace and bead cycles. The exact source-census
hash was refreshed after its first run correctly rejected the previous hash;
its declaration counts and strict assertions remain unchanged.
`cleanup.json` records both stopped owned Excel processes and the owned runtime,
two sequential launches, unchanged workbook and the remaining desktop-handle
release error. The helper error supplies no hidden success or parity credit.
