# Genuine inventory workbook: complete field comparison

[The saved workbook](../../../../../fixtures/workbooks/inventory/inventory.xlsm)
contains six designer controls and original qualified MSForms code that creates
a 23-row ListBox. No application handler is replaced or rewritten in the fixture.
The importer loads the same workbook bytes and executes those handlers on VM3.

Native captures reuse the one hidden Excel at both scales. Sixteen steps cover
initial focus and immediate Enter, two PageDown operations, invalid zero/text
quantities, successful totals 5/195/230, last-row and repeat assignments, Escape,
Hide and reshow. Source, workbook/export hashes and independent observer code
are retained. Observations never save changes back to the fixture.

The [complete comparison](comparison.md) is **316 matching fields / 4 failures**,
with full_parity_claimed=false. It compares every State component, cumulative
Trace and focus field. The earlier [before report](before/comparison.md) retained sixteen TopIndex
failures and four focus failures. A first-Show viewport correction now requires
all sixteen State and cumulative Trace results to match native exactly. Default
Tahoma 8.25 exposes complete rows while public Height remains unchanged; a
private library hook initializes that effective viewport once. Height changes
refresh it, including internal Core changes. Same-value height stays quiet;
painting, clipping and row hit testing share the effective viewport.

Four failures still retain native CancelButton focus versus runtime SubmitButton
after Escape/reshow (.123). Every focus field remains compared, with no ignored
fields or full parity assertion. The independent report recomputes all native
differences; the Rust test also directly requires every original native State
and Trace result. Full IntegralHeight property/rounding behavior stays in .118.

The runtime capture is a headless logical replay with StubShaper. Both native
scales agree; this supplies no pixel, font, geometry or general lifecycle claim.
The main authored-window headline remains separate in `.122`.
Native viewport mode probes record IntegralHeight true/false and geometry
without assuming one formula explains earlier static-control observations.

Fresh review checked original source preservation, all sixteen steps, exact
numeric totals, error propagation, repeated setter quietness, source hashes and
that the before report and all four remaining focus failures stay visible. Run `inventory_reference.py` to replay.

Validation: 225 Rust tests pass, seven existing ignored; fmt/clippy and all
64 evidence checks pass, including the unchanged 95 ledger and 55 oracle unit
tests. Local links, whitespace and the bead graph were reviewed.
