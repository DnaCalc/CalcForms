# W010 Complete MSForms Object-Model Parity Evidence

Status: committed execution baseline through the independently verified
`.frm`/`.frx` export facts (`oxforms-jbjp.43`) and deterministic row-level
parity ledger (`oxforms-jbjp.4`), plus the replay-valid canonical representative
live member-oracle capture (`oxforms-jbjp.5`). W010 remains in progress beyond
that representative slice.

Run 7 [native drawing measurements](beads/oxforms-jbjp.106/README.md) fill 192
missing text rows at 100%/150%. FORMS PARITY is 804 pass / 794 fail, with 712
missing measurements. Raw public OLE drawings replay alongside qualified window
captures; behaviour and remaining spacing coverage are still open.

The next [behaviour/geometry report](beads/oxforms-jbjp.107/README.md) has 975 pass /
635 fail, including 522 missing measurements. It adds independent programmatic
events, actual Tab cycles/interior messages and observed native nested rectangles.

Run 4 ListBox row correction: [`.87` measurements](beads/oxforms-jbjp.87/README.md),
with the same native pixels before/after at both scales and a VM3 batch/clip regression.

This directory indexes the generated facts, oracle captures, differential
artifacts, conformance ledger, and closure evidence for W010. W010 supersedes no
earlier evidence: W005/W006/W008 event captures and W009 representative-control
proofs remain inputs, but they do not constitute full member parity.

## FM20/referenced-typelib Fact Baseline

`oxforms-jbjp.2` generated the complete public metadata baseline under
[`beads/oxforms-jbjp.2/`](beads/oxforms-jbjp.2/). It captures 171 FM20 primary
entries, 37 non-merged dual-interface companions, and the exact 12-node stdole
closure required to resolve every emitted signature, including separate
`Picture` and `IPictureDisp` alias nodes.

The validator reconciles 2,832 functions, 221 variables, 216 implementation
edges, 3,153 parameters, and 1,446 resolved reference occurrences. It also
recomputes the legacy W005 projection: all 51 coclass/source attachments and
376 selected event rows match structurally, with zero unexplained deltas. The
classification `source_binary_changed_structure_same` records the old/new
FM20 file-hash difference without weakening stable public-structure checks.

The ordinary repository evidence pass is Office-independent. The owning bead
also validates the exact installed source/runtime pins and performs two clean
regenerations before byte-comparing the committed artifacts. See
[`../../specs/FM20_TYPELIB_FACT_SCHEMA.md`](../../specs/FM20_TYPELIB_FACT_SCHEMA.md)
for the schema, stable identities, closure algorithm, validator contract, and
non-claims.

## MS-OFORMS Persistence/Default Fact Baseline

`oxforms-jbjp.3` generated the documented binary-persistence/default baseline
under [`beads/oxforms-jbjp.3/`](beads/oxforms-jbjp.3/). It preserves 8,024
source rows from persistence context through all twenty Appendix A notes,
partitioned into normative, example, security, and product-behavior evidence
classes.

The normalized surfaces contain 431 non-bitfield record fields, ninety record
sections with 37 aggregate requirements, all 71 control/common-text record
tables and 16 shared-type tables, 98 properties (95 file-format defaults plus
three mandatory-persist/no-default properties), 107 typed default rows, three
property-domain tables/eight rows, 28 bitfields/320 entries including all
fifteen masks, 26 enumerations/132 values, one algorithm context/three
procedures, six examples, ten expanded resource formats, sixteen cached control
ids, and 179 explicit unknown/reserved/ignored rows. The pack also inventories
22 external standards across 103 occurrences.

Source-required validation checks the exact Foundation commit, hashes every pin
from that commit blob and from its clean working-tree path, then performs two
independent clean regenerations. The static repository validator reconstructs
every derived surface from committed source rows and requires the reviewed
semantic digest. Runtime API and oracle arrays remain empty; worked examples
and Appendix product behavior retain their own non-implementation
classifications. See
[`../../specs/MSFORMS_PERSISTENCE_MODEL.md`](../../specs/MSFORMS_PERSISTENCE_MODEL.md).

## Independent FRM/FRX Export Facts (Closed)

`oxforms-jbjp.43` closed after the independent export-fact surface under
[`beads/oxforms-jbjp.43/`](beads/oxforms-jbjp.43/) passed its full verification
floor and exact fresh-eyes review. The reviewed implementation is commit
`9572f7a`; `oxforms-jbjp.4` now consumes these facts as an immutable input.

The public-source side pins MS-OVBA 15.0 for `VBFrameText` and the fifteen
ordered `DesignerProperties`, and MS-VBAL for the physical class-module
attribute-header/body boundary. The black-box side preserves three genuine
Excel `16.0.20131.20112`/VBE `7.01` `VBComponent.Export` pairs: controlled outer
defaults, outer nondefaults, and an intrinsic/container matrix. The matrix has
sixteen `Controls.Add` instances spanning all fourteen intrinsic families;
structural UserForm and Page observations bring the observed-family universe
to sixteen.

The closed fact surface records:

- three strict authority profiles: genuine Office VBA export, an uncaptured
  separate VB6 profile, and the non-promotable OxForms/legacy synthetic nested
  profile;
- 2,210 `.frm` bytes, 14,920 `.frx` bytes, three resource references, three
  class headers, three opaque code bodies, and eight controlled outer-property
  pairs, including the explicitly failed `RightToLeft = True` readback;
- an observed root `OleObjectBlob` extension kept outside the selected
  normative MS-OVBA `DesignerProperties` grammar;
- an opaque 24-byte FRX prefix followed by embedded CFB, with three roots, four
  storages, 22 streams, 32 physical regions, 62 mini-stream physical regions,
  six explicit byte-region records, strict allocation/ownership validation,
  and complete source-length accounting;
- one applicability-specific mapping for each of the 98 MS-OFORMS properties:
  47 exact-name rows, sixteen contextual-only rows, eighteen documented
  internal-only rows, and seventeen rows without an exact live probe; across
  245 property/family pairs this is 100 exact, 28 contextual, 33 internal, and
  84 unprobed; and
- fifteen unknown classes with an explicit preserve-or-reject policy.

The strict v2 manifest freezes the actual Excel process and uniquely loaded
VBE binary, including the Click-to-Run reported-path/backing-path distinction,
requested/list readback, and the sole pinned geometry normalization
(`ListBoxProbe.Height` `60.0` to `49.150001525878906`). The source-linked
MS-OFORMS projection adds 43 reviewed length/count fields in 15/14/7/5/2 groups,
four codecs, and the complete default/mask/storage-requirement surfaces. Those
normative rows do not decode values from the live FRX corpus.

All ten actual HTML ProgIDs were registered on the capture machine, while
same-build designer `Controls.Add` returned `E_INVALIDARG` (`0x80070057`). The
claim is strictly designer-add rejection on that host/build, not runtime
non-callability.

No FRX control-property value is decoded. No production parser, serializer,
reader, writer, binary codec, runtime API, constructor-default, VB6, or broader
HTML claim is made. See the focused persistence spec for the exact profile and
unknown boundaries.

The reviewed execution graph has 72 strict, atomic child beads. Each child has
an exact evidence path declared in its `br` design field, an explicit
no-temporary-production-scaffolding policy, residual/blocker behavior, and the
owner-mandated fresh-eyes review followed by a bead-scoped commit. The sequence
also contains an independent `.frm`/`.frx` export-fact lane, a precise OxVba
FormModule handover plus later production-integration gate, and separate
supporting-object, real HTML-family, post-HTML shared-band, event, render,
corpus, and stress outcomes. It also explicitly owns the documented intrinsic
global `UserForms` collection and loaded-form registry.

## Deterministic Row-Level Parity Ledger

`oxforms-jbjp.4` establishes the generated raw-contract/current-overlay
inventory under [`beads/oxforms-jbjp.4/`](beads/oxforms-jbjp.4/). The canonical
artifact contains 7,753 addressable rows: 2,452 verified baseline rows, 4,682
gap rows, and 619 unexpected-public rows. Its 20,046 gating dimension cells
make the root `green` value truthfully `false`.

The ledger joins every `.2` FM20/stdole type/member/event/enum fact, the exact
W005 metadata reconciliation, every `.3` and `.43` persistence leaf and
property/family join, the explicit official-documentation UserForm/UserForms
overlay, and the current 37-module OxForms VBA surface. Exact declaration rows
remain separate from coclass and event projections. The 387 exact-owner and 191
logical-family summaries are derived only from rows and cannot override one.

Canonical signatures retain individual source indices and vtable offsets in
addition to complete types, flags, parameters, defaults, and identity. The
hidden non-dispatch IFont adapter surface therefore preserves all 22 ordered
slots and its 200-byte vtable layout instead of pretending it is a VBA source
Property surface. Symmetric array/ParamArray checks, authoritative names and
passing modes, exact documented defaults, enum-value poisoning, module-kind and
creatability checks, scalar/non-`As New` global binding, and fail-closed
documentation inference prevent weaker same-name declarations from turning a
row green.

Strict validation independently pins the complete dynamic VBA dependency
closure plus generator/parser/CLI/test sources and the reviewed expected
digest. Commented or disconnected Rust loader inventories cannot establish an
exposure profile; stale timestamps, alternate-ledger CLI options, arbitrary
export paths, and hard-link aliases cannot bypass the canonical artifact.
Schema names and all numeric schema versions are exact.

The reviewed semantic digest is
`2a63c8acebe038adec22273ecf6dde00d5a60b123ad88289a62629c1553c07c5`.
See [`../../specs/MSFORMS_OBJECT_MODEL_PARITY.md`](../../specs/MSFORMS_OBJECT_MODEL_PARITY.md)
for the row/status/reproducibility contract and the bead evidence README for
the full census, commands, nonclaims, and fresh-eyes repairs.

This is not final host-composed parity. `oxforms-jbjp.5` owns generalized live
oracle capture. `oxforms-jbjp.6` owns container-provided `Control`/`IControl`
extended-control composition for each concrete family, generic host-event
applicability, and the final UserForm/host overlay. Their unresolved work stays
red in the ledger.

## Manifest-Driven Live Member Oracle (Closed)

`oxforms-jbjp.5` closed on 2026-09-21 after the
[closure verification](beads/oxforms-jbjp.5/verification-2026-09-21.md), committed
as `5b70696`, confirmed canonical replay, visual review, 181 passing workspace
tests, and all 41 repository evidence checks. `.6` subsequently started and is
now blocked with its [contract/probe evidence](beads/oxforms-jbjp.6/README.md).

`oxforms-jbjp.5` adds one reusable observation contract rather than a copied
harness per control family. Its project-authored representative manifest and
immutable selected-row ledger slice live under
[`../../../fixtures/office-oracle/excel-msforms/member-probes/`](../../../fixtures/office-oracle/excel-msforms/member-probes/).
The fifteen-row slice freezes ten selected member/event contracts and five
owner type contracts from the exact `.4` ledger bytes. Historical replay reads
that slice, while capture-time authoring separately verifies that it still
matches the declared current ledger.

The v1 representative batch contains five controls (Label, TextBox, ListBox,
CheckBox, and CommandButton), eleven direct early-bound member probes, and two
native event handlers (`Change` and host-attached `Exit`). It covers
property get/put/round-trip, indexed/default get, a method with omitted and
explicit optional arguments, scalar coercion/error shapes, exact successful
`TypeName`/`VarType` expectations, a 22-column exact error row spanning
`Err.Number`, `Err.LastDllError`, `Err.Source`, `Err.HelpFile`,
`Err.HelpContext`, `Erl`, stage, and worksheet-safe/raw-UTF-16 descriptions,
and `MSForms.ReturnBoolean.Value` before/after mutation.
`CallByName` and OxForms outputs are outside the contract.

The promoted canonical capture contains ten successful member rows and one
expected error row. It observes the selected Caption, MaxLength, AddItem,
ListCount, indexed/default-member, Value-coercion, and Value/default-get shapes
with their exact value, `TypeName`, and `VarType` expectations. The invalid
TextBox `MaxLength` write records error 380, last-DLL-error 0, source
`Forms.TextBox.1`, help file `fm20.hlp`, help context 1000380, `Erl` 0, and the
exact English description in worksheet-safe and raw UTF-16 forms. The event log
records one TextBox `Change` bound to the value-write step and one host-attached
TextBox `Exit` bound to the attempted focus transfer. `Exit` changes
`ReturnBoolean.Value` from `False` to `True`, after which that transfer returns
`-2147467259` (`0x80004005`), `Unspecified error.`, source `Forms.Form.1`.

The deterministic generator/replayer and two-phase Excel capture runner are in
[`../../../tools/office-oracle/`](../../../tools/office-oracle/). A capture must
preserve the normalized manifest, generated VBA, workbook and worksheet rows,
screenshot/window-process binding, genuine Office `.frm`/`.frx` export,
environment/binary observations, capture-local tool snapshots, logs, README,
and full-tree checksums. Source generation, capture replay validation, and
window capture execute only from capture-local snapshots whose exact bytes
match their source digests and required self-digests. Before phase two opens the
workbook, the headless validator checks its generated source and strict OPC/VBA
structure; the runner then requires identical workbook hashes immediately
before and after `Workbooks.Open`. External child commands are bounded. Each
Excel `/safe` process is created directly with its initial thread suspended,
assigned to a kill-on-close Job, verified as a Job member, and only then
resumed. Empty caller and immediate pre-create process observations plus the
sole post-create PID, exact executable/command line, and native
`EXCEL7`/`OBJID_NATIVEOM` binding establish ownership before automation. The
narrow suspended creation-to-Job-assignment interval is disclosed rather than
claimed atomic. All owned COM work after launch is watchdog-bounded, and the
retained Job is the final process-tree cleanup backstop.

Both phases record three exact-PID isolation checkpoints. They require an
enabled `XLMAIN`, reject unexpected visible modal/disabled roots and foreign
workbooks, and record startup paths, Protected View, Excel AddIns/AddIns2, and
loaded XLLs. In this safe-mode capture `Application.COMAddIns` returned exact
`0x800A03EC`; the COM-add-in inventory is therefore explicitly incomplete and
the capture makes no COM-add-in connection-state claim. Its empty recorded
array is not evidence of absence.

Office-independent replay validates the capture's strict formats and causal
timeline, exact result value/type expectations, exact generated source bytes,
strict direct/one-to-one OPC relationships and content types, structurally
closed PROJECT/module-table/VBA-storage metadata, empty host-document code, and
decompressed workbook VBA-source equality after narrow known VBIDE
normalization. It also checks bounded worksheet/JSON table equality and the
independent manifest pins before executing the capture-local FRM/CFB validator
snapshots. V1 inventories but does not decode the persisted MS-OFORMS control
graph or prove optional compiled-cache/p-code execution equivalence; exhaustive
corpus bead `oxforms-jbjp.67` owns semantic control-graph binding plus rejection
or execution-semantic binding of the compiled-cache/p-code surface.

The canonical run recorded Microsoft Office and VBA UI language `LCID 1033`
(English - United States), stabilizing the worksheet-safe display form and
exact raw UTF-16 code units of English `Err.Description`. The display field
removes at most one terminal U+0000 for worksheet storage; the raw field
preserves it. VBE **Error Trapping** had to be set manually to **Break on
Unhandled Errors** before capture; the runner did not change that user-wide
setting.

The bead-specific contract and commands are documented in
[`beads/oxforms-jbjp.5/README.md`](beads/oxforms-jbjp.5/README.md). The promoted
canonical evidence is
[`beads/oxforms-jbjp.5/captures/W010RepresentativeMemberOracleV1/`](beads/oxforms-jbjp.5/captures/W010RepresentativeMemberOracleV1/),
and `tools/evidence/Test-W010MSFormsMemberOracle.ps1` passes its canonical
Office-independent replay gate. Only rows present in that replay-valid capture
are observations; the declarative manifest, a failed staging run, or the
absence of an event/result row cannot establish an additional MSForms fact.

## Planning Audit

The planning audit used only public/type-library metadata, public
specifications/documentation, reproducible repository inspection, and existing
black-box evidence.

- Installed FM20 source:
  `C:\Program Files\Microsoft Office\root\vfs\System\FM20.DLL`
- Library identity: Microsoft Forms 2.0 Object Library,
  `{0D452EE1-E08F-101A-852E-02608C4D0BB4}`, version 2.0
- File version: `16.0.20131.20012`
- SHA-256:
  `2C0E732B0E794451659AB0FF4E8489A518DDE18A396201ACE10BD3409ACF90FE`
- Census: 171 type infos, 60 coclasses, 64 dispatch interfaces, 42 enums,
  four aliases, and `IFont`.
- Existing W005 event-subset source SHA-256:
  `E5085D8229D72180C7F2D8762E1A49FFF18A04F0143D7A973FF1FBC6200CB81E`.
  The W010 fact-pack bead owns a reproducible structural comparison rather than
  assuming file-hash equality.
- The full fact-pack schema must also resolve external public types referenced
  by FM20, including stdole `Picture`/`IPictureDisp`; a 171-type FM20-only dump
  is insufficient for signature parity.
- MS-OFORMS is the binary Office forms/default source, not the text `.frm`
  grammar or `.frx` export-offset specification. `oxforms-jbjp.43` keeps that
  independent fact universe in a generated manifest derived from preserved
  real exports and pinned MS-OVBA/MS-VBAL rows, before parser/serializer
  implementation.

Representative mechanical gaps found before W010:

| Control | FM20 unique member names | Current public names, including internal helpers | Missing names |
|---|---:|---:|---:|
| Label | 53 | 12 | 45 |
| CommandButton | 52 | 19 | 42 |
| TextBox | 85 | 38 | 71 |
| ListBox | 70 | 28 | 55 |
| ComboBox | 96 | 25 | 82 |
| CheckBox | 60 | 20 | 51 |
| OptionButton | 60 | 22 | 50 |
| ToggleButton | 60 | 20 | 51 |
| Frame | 74 | 13 | 65 |
| Image | 42 | 18 | 33 |
| ScrollBar | 42 | 15 | 30 |
| SpinButton | 40 | 15 | 29 |
| TabStrip | 54 | 16 | 45 |
| MultiPage | 48 | 19 | 39 |

These counts are diagnostic only. The generated ledger created by
`oxforms-jbjp.4`, not this table, becomes execution truth.

## Planning Fresh-Eyes Review

Three independent read-only reviews checked the workset, live bead graph,
sources/hashes, links, scope coverage, and closure semantics. The first pass
found and the planning bead corrected seven substantive issues:

- broad rollups were split into 72 atomic executable outcomes;
- the known OxVba FormModule gap gained a precise handover and a later
  production integration gate;
- epic closure now covers every accepted callable full-library row, including
  HTML/versioned and callable hidden/designer-band rows;
- FM20 fact capture now resolves referenced typelibs such as stdole
  `IPictureDisp`, and `.frm`/`.frx` export facts have an independent lane; and
- every child now declares exact planned truth surfaces, a no-temporary-
  production-scaffolding policy, residual/blocker behavior, and the full
  verification command floor in `br`;
- the ten HTML implementation lanes use the actual FM20 family names, followed
  by a shared `Control`/`Controls` conformance bead; and
- the public `UserForms` collection has a dedicated owner, while the external
  FormModule integration gate is late enough not to stall independent work.

The reviewers otherwise confirmed the FM20/Foundation/OxVba identities and
hashes, W008/W009 closure state, exact mandated note text, link/path integrity,
and preservation of the unrelated `.gitignore` edit.

## Baseline Verification

| Check | Result |
|---|---|
| `cargo fmt --check` | passed |
| clippy, workspace/all targets, warnings denied | passed |
| `.43` targeted/source-required wrapper | 110 tests passed; 2 platform skips |
| evidence validators | 37/37 passed |
| `git diff --check` | passed; unrelated user `.gitignore` edit excluded from the commit |
| bead dependency cycles | none |
| workspace Rust tests | passed |

The `.43` evidence runner, source-required validation, promotion-safety suite,
Rust floor, graph checks, and independent fresh-eyes review are complete. Later
beads add their artifacts here and extend the repository evidence runner with
deterministic validators. A dashboard summary is never a substitute for a
generated member row and its test/evidence anchors.
