# FORMS PARITY: real greeter input measurements

**1,166 pass / 452 fail; 378 missing measurements.** The [replay](forms-parity.md)
fills forty previously missing rows: Tab order, hit target, Enter and Escape for
five controls at both scales. All forty match. Other metrics remain unknown.

The unchanged genuine greeter workbook is opened in the existing owned private
Excel. Separate MouseDown observers preserve its original handlers; the original
form source is restored in memory after capture, and workbook bytes stay unchanged.
Two complete native Tab cycles must repeat. Public IAccessible rectangles
provide interior points, and only the exact owned HWND receives messages.
Enter/Escape observations retain original before/after State and cumulative event
deltas. Native signatures are checked against the public FM20 facts before use.

The Rust differential imports the original saved workbook, appends the same
separate observers and checks both scales' full cycles, hits, before/after states
and ordered event deltas. Fresh review checked source preservation, closed and
repeated cycles, accessible containment, unchanged native image hashes and that
only the forty explicitly observed missing facts were filled.

The comparison inherits window pixels and all other measurements from `.112`;
its new credit comes from independent native input and fresh logical VM3 replay.
The native owner snapshot is from the live capture; final cleanup is recorded
separately in `.108/cleanup-run8.json`. No global input or security change occurred.

Validation: 225 Rust tests pass, seven existing ignored; fmt/clippy and all
64 evidence checks pass, including the unchanged 95 ledger and 55 oracle unit
tests. Local links, whitespace and the bead graph were reviewed.
