# Manifest-driven MSForms member probes

This fixture directory contains declarative inputs for the W010 live
Excel/MSForms oracle. The input manifest selects exact rows from the frozen
`oxforms-jbjp.4` parity ledger and describes control creation, ordered member
probes, native event handlers, requested mutable-argument changes, and required
capture artifacts.

`representative-v1.json` is the closure batch for `oxforms-jbjp.5`. It spans
Label, TextBox, ListBox, CheckBox, and CommandButton and exercises:

- direct early-bound property get, put, and round-trip syntax;
- implicit DISPID-0/default-member get syntax;
- a method call with an explicitly omitted optional trailing argument and a
  call with that argument supplied;
- indexed property get, string-to-numeric and string-to-tristate coercion, and
  an invalid property value recorded in a 22-column result row with exact
  `Err.Number`, `Err.LastDllError`, `Err.Source`, `Err.HelpFile`,
  `Err.HelpContext`, `Erl`, execution stage, worksheet-safe error text, and raw
  UTF-16 code units;
- exact expected `TypeName` and numeric `VarType` for every successful probe;
- native TextBox `Change` and host-attached `Exit` handlers, including
  `MSForms.ReturnBoolean.Value` before/after mutation; each focus trigger pins
  either success or an exact error triplet, so the expected `Cancel=True`
  focus-transfer veto is verified rather than broadly ignored;
- one live screenshot and one design-time `VBComponent.Export` `.frm`/`.frx`
  pair.

The manifest is project-authored probe input. Live worksheet rows, screenshots,
workbooks, and exports are separate MSForms observation artifacts. No OxForms
output path is permitted in this input or in the capture provenance.
The manifest also independently pins the exact repo paths and SHA-256 digests
of the strict FRM and CFB validators before their capture-local snapshots may
be executed during replay.

The manifest does not read the mutable current parity ledger during ordinary
replay. `representative-v1.ledger-slice.json` is the immutable fifteen-row
closure (ten selected member/event rows plus five owner type contracts) frozen
from the exact `.4` ledger identity recorded in the manifest. New probe batches
freeze their own selected-row slice; historical v1 manifests and slices are not
rewritten when the current implementation ledger advances.

Validate and generate without starting Excel:

Python 3.12 or newer is required for junction-aware path-safety checks.

```powershell
python -B tools/office-oracle/msforms_member_oracle.py validate-manifest `
  --manifest fixtures/office-oracle/excel-msforms/member-probes/representative-v1.json

python -B tools/office-oracle/msforms_member_oracle.py generate `
  --manifest fixtures/office-oracle/excel-msforms/member-probes/representative-v1.json `
  --output-dir <fresh-directory>
```

At authoring/capture time, verify that the immutable slice still matches the
declared current source ledger:

```powershell
python -B tools/office-oracle/msforms_member_oracle.py verify-current-ledger-snapshot `
  --manifest fixtures/office-oracle/excel-msforms/member-probes/representative-v1.json
```

Run the live batch into the manifest-declared W010 bead path:

The live runner additionally requires PowerShell 7.2 or newer and an unlocked
Windows desktop session. Microsoft Office and VBA UI language `LCID 1033`
(English - United States) is required and recorded because the manifest pins
both the worksheet-safe display form of English `Err.Description` and its exact
raw UTF-16 code units. The error expectation also pins `Err.Number = 380`,
`Err.LastDllError = 0`, `Err.Source = "Forms.TextBox.1"`,
`Err.HelpFile = "fm20.hlp"`, `Err.HelpContext = 1000380`, and `Erl = 0`; the
promoted canonical capture confirms the complete row. The display form removes
at most one final U+0000 so it can be written to the worksheet; the raw field
preserves that terminal code unit. Before capture, manually set VBE **Tools > Options > General > Error
Trapping** to **Break on Unhandled Errors**, not **Break on All Errors**. The
runner never changes that user-wide setting.

```powershell
pwsh -NoProfile -File tools/office-oracle/Capture-MSFormsMemberOracle.ps1
```

The committed capture is replayed without starting Office by
`tools/evidence/Test-W010MSFormsMemberOracle.ps1`.
The live runner performs source generation, capture replay validation, and
window capture only through byte-pinned capture-local tool copies. Before phase
two may open the workbook, the headless validator checks its exact generated
source plus the strict, direct, one-to-one Excel OPC relationship/content-type
graph. The runner retains a read handle that denies rename/delete, permits
Excel's read/write sharing, and requires the same exact stream hash on both sides
of `Workbooks.Open`; it also rejects a different path or read-only open. All
external child commands are bounded. Each Excel `/safe` process is created
directly with its initial thread suspended, assigned to a kill-on-close Job,
verified as a Job member, and only then resumed. Empty caller and immediate
pre-create process observations plus the sole exact post-create PID, executable
and raw command line, and native `EXCEL7`/`OBJID_NATIVEOM` binding establish
ownership before automation. All owned COM work after launch is
watchdog-bounded. The narrow suspended creation-to-Job-assignment interval is
disclosed rather than claimed as atomic creation-time association.

Replay reads `PROJECTCODEPAGE`, structurally closes PROJECT declarations,
MS-OVBA module records, and VBA-storage streams, requires all
workbook/worksheet code bodies to be empty, and compares the generated
form/runtime sources with the known VBIDE-normalized code persisted in
`vbaProject.bin`.
This does not semantically bind the MS-OFORMS control graph or optional
compiled-cache/p-code execution; those remain explicit `.67` work.

Schema v1 deliberately has a small typed-value vocabulary for the representative
batch. Focus steps must declare `expect.outcome`; an error outcome also requires
the exact signed error number, description, and source. Event handlers are inert
outside the bounded recording window so their mutations cannot obstruct teardown.
Its bead id, output binding, generator, runner, and validator are
shared infrastructure. Later capture beads add scalar rows declaratively and
version the schema/tool when they introduce object returns, putref,
collection targets, Pages/Tabs, HTML host controls, arrays, or additional event
argument types; they do not copy the capture engine or change v1 replay
semantics.
