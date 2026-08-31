# oxforms-jbjp.5 — Manifest-Driven MSForms Member Oracle

Status: `COMPLETE` — the reusable manifest/generation/replay contract produced
the canonical live Excel/MSForms representative capture, that capture passes
the Office-independent replay gate, and the complete bead survived its required
fresh-eyes review and repository verification floor before the closing commit.

## Outcome

This bead generalizes the Office oracle into one durable, declarative engine
for later W010 behavior-capture beads. A probe manifest binds each public
operation or event to an exact row in the deterministic `.4` parity ledger,
generates direct early-bound VBA, records live Excel/MSForms observations, and
supports strict Office-independent replay of the committed artifacts.

The harness is quarantined under fixture, tool, and evidence paths. It is not
an OxForms production API, runtime bridge, or implementation pattern.

## Contract Surfaces

| Surface | Role |
|---|---|
| [`../../../../../fixtures/office-oracle/excel-msforms/member-probes/representative-v1.json`](../../../../../fixtures/office-oracle/excel-msforms/member-probes/representative-v1.json) | Project-authored representative probe manifest and expectations. |
| [`../../../../../fixtures/office-oracle/excel-msforms/member-probes/representative-v1.ledger-slice.json`](../../../../../fixtures/office-oracle/excel-msforms/member-probes/representative-v1.ledger-slice.json) | Immutable fifteen-row snapshot: ten unique selected member/event contracts plus five owner type contracts. |
| [`../oxforms-jbjp.4/msforms_parity_ledger.v1.json`](../oxforms-jbjp.4/msforms_parity_ledger.v1.json) | Exact source ledger used only for authoring-time snapshot verification, not ordinary historical replay. |
| [`../../../../../tools/office-oracle/msforms_member_oracle.py`](../../../../../tools/office-oracle/msforms_member_oracle.py) | Strict manifest/snapshot validation, deterministic VBA generation, and capture replay. |
| [`../../../../../tools/office-oracle/Capture-MSFormsMemberOracle.ps1`](../../../../../tools/office-oracle/Capture-MSFormsMemberOracle.ps1) | Two-phase private-Excel live capture and atomic promotion after validation. |
| [`../../../../../tools/office-oracle/Capture-Window.ps1`](../../../../../tools/office-oracle/Capture-Window.ps1) | Coordinate screenshot plus exact before/after window-state metadata bracket for the live Excel process. |
| [`../../../../../tools/evidence/Test-W010MSFormsMemberOracle.ps1`](../../../../../tools/evidence/Test-W010MSFormsMemberOracle.ps1) | Office-independent canonical replay, path-policy, adversarial-test, and checksum gate. |
| [`../../../../specs/MSFORMS_OBJECT_MODEL_PARITY.md`](../../../../specs/MSFORMS_OBJECT_MODEL_PARITY.md) | Normative ledger and live member-oracle contract. |

The canonical capture is
[`captures/W010RepresentativeMemberOracleV1/`](captures/W010RepresentativeMemberOracleV1/).
It was atomically promoted only after the complete live run passed capture-local
validation. Hidden or otherwise failed staging directories are diagnostics
only: they are not canonical evidence and must not be committed as successful
observations.

## Representative V1 Batch

The representative manifest constructs five intrinsic controls: Label,
TextBox, ListBox, CheckBox, and CommandButton. Its eleven probe steps cover:

- direct early-bound property get, put, and get-after-put;
- indexed property access and implicit DISPID-0/default-member get;
- `AddItem` with an explicitly omitted optional index and with a supplied
  index;
- scalar string-to-integer and string-to-tristate coercion shapes;
- an invalid property value whose 22-column live row must record exact
  `Err.Number`, `Err.LastDllError`, `Err.Source`, `Err.HelpFile`,
  `Err.HelpContext`, `Erl`, execution stage, worksheet-safe display text, and
  raw UTF-16 code units; and
- exact expected `TypeName` and numeric `VarType`, plus recorded object/array
  flags, for every successful result.

The two event contracts are TextBox `Change`, causally bound to its value-write
step, and host-attached TextBox `Exit`, bound to the attempted focus
transfer. The latter records `Cancel.Value` before and after the requested
`False` to `True` mutation and pins the resulting canceled `SetFocus` outcome as
`0x80004005`, `Unspecified error.`, source `Forms.Form.1`; arbitrary focus
errors remain fatal. Unlike `BeforeUpdate`, `Exit` does not depend on a
user-edit dirty flag, so the generated programmatic focus transfer is the
direct trigger under test. Mutable `MSForms.Return*` helpers are object-valued
arguments; plain scalar mutation is allowed only for a real `ByRef` parameter.
Generated handlers check the bounded recording flag before observing or mutating
arguments, and both normal and failure teardown disable recording before unload.

Every probe/event binding is checked against the immutable ledger slice for
stable row id, exact owner/member, accessor, signature, parameter order, and
default-member status. The manifest's ProgID must map to the same FM20 owner.
`CallByName` is forbidden; generated calls are visible direct VBA syntax.

## Canonical Observations

The promoted capture records 11 member-result rows: ten successes and the one
expected error. The successful rows confirm:

- Label `Caption` round-trips as `String`/`VarType 8` with value
  `Live MSForms round-trip`;
- TextBox `MaxLength` coerces the supplied value to `Long`/`VarType 3` value
  `12`;
- ListBox `AddItem` accepts both an omitted index and an explicit index, the
  first addition produces `ListCount = 1`, and indexed `List` reads `head` as
  `String`/`VarType 8`;
- TextBox `Value` round-trips and its implicit default get both return
  `event payload` as `String`/`VarType 8`;
- CheckBox `Value` returns `True` as `Boolean`/`VarType 11`; and
- CommandButton `Caption` reads `Focus target` as `String`/`VarType 8`.

The invalid TextBox `MaxLength` write records error `380` (`0x0000017C`) at
the set stage, `Err.LastDllError = 0`, source `Forms.TextBox.1`, help file
`fm20.hlp`, help context `1000380`, `Erl = 0`, and the exact English
description plus its raw UTF-16 code units including terminal U+0000.

The event timeline records exactly one TextBox `Change`, causally bound to
`TextValueForEvents`, and exactly one host-attached TextBox `Exit`, causally
bound to `AttemptExitTransfer`. The `Exit` handler changes
`MSForms.ReturnBoolean.Value` from `False` to `True`; the attempted transfer to
the CommandButton then returns `-2147467259` (`0x80004005`), description
`Unspecified error.`, source `Forms.Form.1`.

The observation was made with x64 Excel `16.0.20228.20190`, VBE
`7.01.1158`, and FM20 `16.0.20228.20014`, under the binary hashes and platform
identity recorded in `oracle-capture-manifest.json`. Those identities bind this
capture; they do not claim internal ownership of the observed behavior.

## Capture And Replay Contract

The live runner uses two directly created Excel `/safe` processes. Each phase
requires empty caller and immediate pre-create PID observations, pins the sole
registered executable, creates its initial thread suspended, assigns the
process to a kill-on-close Job, verifies membership, and only then resumes it.
The narrow suspended creation-to-assignment interval is disclosed rather than
claimed as atomic creation-time association; functional tests prove completed-
launch root/descendant kill-on-close and abrupt-supervisor cleanup. The hidden
build phase creates the UserForm through public VBIDE automation, exports the
genuine `.frm`/`.frx` pair, saves the macro workbook, and exits. Before the
visible phase may open the
workbook, the Office-independent validator checks its exact generated sources
and strict OPC/VBA package graph, including complete
PROJECT/module-table/VBA-storage closure and empty host-document code. The
runner then holds the exact non-renamable file object through
`Workbooks.Open`, permits only the read/write sharing Excel needs, and requires
identical hashes from that retained stream immediately before and after the
open. It also rejects a different returned path or a read-only workbook. Only
then does the visible phase execute the ordered probes, capture the exact
UserForm by caption, class, process id, start time, and executable, save
worksheet observations, and exit. The post-create PID observation must contain
only the retained process. Exact `EXCEL7`/`OBJID_NATIVEOM` binding and the raw
OS command line parsed as executable plus sole `/safe` argument prevent
cross-process attachment. This protects unrelated user workbooks. The
coordinate-based PNG is bracketed immediately before and after `CopyFromScreen`
by exact caption/class/PID/start/path/bounds/visibility/foreground observations;
it requires visual review and is not proof of an HWND-owned surface.

The runner neither mutates nor quits a pre-existing/user Excel process and does
not change any persistent user setting. Transient application properties on
each private instance are changed only after ownership is proved, and `Quit` is
never called before that proof. Source
generation, capture replay validation, and window capture execute only from
their staging-capture tool snapshots. The runner verifies each snapshot's exact
bytes against its source and requires the recorded digest as the tool's
self-digest. Executable script snapshots remain held open read-only, with
write/delete sharing denied, from the final stream-based hash through child
completion. The window tool also holds and revalidates the complete validated
evidence-root-to-output directory identity chain across PNG/manifest writes so a
concurrent rename-then-junction substitution fails closed. External child
commands have finite time bounds. After direct creation, Job membership, and
native binding, all owned COM work in that phase is watchdog-bounded. Each
phase records three complete exact-PID isolation checkpoints: an enabled
`XLMAIN` with no unexpected visible modal or disabled root, exact workbook
disposition, startup paths, zero Protected View windows, no open Excel
AddIns/AddIns2, and no loaded XLL. If safe-mode
`Application.COMAddIns` returns exact `0x800A03EC`, its inventory is explicitly
incomplete and the capture makes no COM-add-in connection-state claim. An empty
recorded array is not absence proof. Each Excel watchdog waits for an `ARMED`
handshake and revalidates the exact PID, start time, and executable on every poll
and again immediately before terminating that private process; identity drift
fails closed, and only the expected terminal reason is accepted. The retained
Job stays alive through COM teardown and exact process-exit verification, then
is deterministically disposed as the final process-tree backstop.

Because the manifest pins both the worksheet-safe display form and exact raw
UTF-16 code units of English `Err.Description`, capture requires Microsoft
Office and VBA UI language `LCID 1033` (English - United States); the runner
checked and recorded it. The captured row confirms `Err.Number = 380`,
`Err.LastDllError = 0`, `Err.Source = "Forms.TextBox.1"`,
`Err.HelpFile = "fm20.hlp"`, `Err.HelpContext = 1000380`, and `Erl = 0`. The
display form removes at most one final U+0000 for worksheet storage, while the
raw field preserves it. VBE **Error Trapping**
must already be set manually to **Break on Unhandled Errors**, not **Break on
All Errors**. The runner never changes that user-wide setting.

A promoted capture must preserve:

- the normalized manifest and immutable source-ledger binding;
- deterministic generated VBA and form source;
- result and event rows with one contiguous sequence/timeline;
- workbook, screenshot, selected-window metadata, and real Office exports;
- environment plus loaded Excel/VBE/FM20 identity observations;
- capture-local snapshots and hashes of the combined generator/replayer, runner,
  window tool, and strict FRM/CFB validators, with the executable generator/
  replayer and window snapshots byte-pinned before use and FRM/CFB bound to
  independent source-path and digest pins in the manifest;
- command, progress, standard-output, and standard-error logs;
- capture README and full-tree checksums.

Replay reads the immutable slice rather than the mutable current ledger and
verifies the recorded source roles and hashes of the capture-local tool
snapshots. It refuses to import a capture-local FRM/CFB validator until its
role, source path, and digest match the project-authored manifest pins. It
validates strict JSON, paths, generated bytes, exact
result/error/event/type expectations, event trigger causality, strict direct
and one-to-one OPC relationships/namespaces/content types, MS-OVBA
`PROJECTCODEPAGE`, complete PROJECT/module-table/VBA-storage closure, empty
workbook/worksheet code bodies, known-VBIDE-normalized form/runtime source
equality, exact bounded worksheet dimensions/content, PNG chunks and compressed
stream, window/process binding, strict FRM/FRX inventories, artifact uniqueness,
and checksum coverage. Replay does not start Office and does not require the
captured external binary versions to remain installed.

V1 does not yet decode the persisted MS-OFORMS control graph inside the
workbook/export CFB. That semantic full-control-graph binding remains explicit
acceptance work in exhaustive corpus bead `oxforms-jbjp.67`; it is not inferred
from the structural inventory here. V1 also inventories but does not prove the
execution equivalence of optional `__SRP_*` compiled-cache/p-code streams;
`.67` must reject those streams or bind their execution semantics to generated
source before source-preserving VBA-stomp resistance can be claimed.

## Commands

Headless manifest and deterministic-generation checks:

```powershell
python -B tools/office-oracle/msforms_member_oracle.py validate-manifest `
  --manifest fixtures/office-oracle/excel-msforms/member-probes/representative-v1.json
python -B tools/office-oracle/msforms_member_oracle.py verify-current-ledger-snapshot `
  --manifest fixtures/office-oracle/excel-msforms/member-probes/representative-v1.json
pwsh -NoProfile -File tools/office-oracle/Capture-MSFormsMemberOracle.ps1 -DryRun
```

Live capture requires Python 3.12 or newer, PowerShell 7.2 or newer, Windows,
Excel/VBE project access, Microsoft Office and VBA UI language `LCID 1033`
(English - United States), and an unlocked desktop session capable of
displaying and capturing the UserForm. First manually set VBE **Tools > Options
> General > Error Trapping** to **Break on Unhandled Errors**, not **Break on
All Errors**; the runner will not change it:

```powershell
pwsh -NoProfile -File tools/office-oracle/Capture-MSFormsMemberOracle.ps1
```

Replay the canonical capture without starting Office:

```powershell
pwsh -NoProfile -File tools/evidence/Test-W010MSFormsMemberOracle.ps1 `
  -RequireCurrentLedgerSnapshot
```

That command passes against the promoted canonical capture, including its
current-ledger authoring snapshot, Office-independent replay, adversarial
mutation suite, path policy, and full-tree checksum gate.

## Closure Gate

The representative live batch produced the canonical capture; its live rows
match the independently authored exact success/coercion/error/event/type
expectations, and the Office-independent replay gate passes. The complete bead
then passed its required fresh-eyes review and repository verification floor;
all issues raised by those reviews were reworked before the closing commit.

The bead's mandatory pre-closure condition is:

> After completing the bead work, check over everything again with fresh eyes,
> looking for any blunders, mistakes, errors, oversights, omissions, logical
> issues, problems, misconceptions, confusion, bugs, etc. and rework
> accordingly. After there are no more issues raised by such a review, do a
> commit of the work. Then proceed with the next bead in the list.

For this execution, the user's later checkpoint instruction controls the handoff:
after `.5` passes review, commit and close it, then pause for a stock-take. Leave
`.6` untouched until the user explicitly resumes the work.

## Nonclaims

- This engine and its captures observe Excel/MSForms only; they do not
  establish or compare OxForms runtime behavior.
- The representative batch proves reusable harness capabilities, not exhaustive
  full-library behavior coverage.
- A project-authored expectation is not an observation, and a missing row is
  unobserved rather than negative evidence.
- V1 is scalar and control-targeted. Object returns, putref, arrays,
  collection targets, Pages/Tabs, HTML-host construction, and additional event
  argument shapes require a backward-compatible schema branch.
- No Office internals, decompilation, disassembly, private source, or unrelated
  user Excel process is part of the evidence path.
