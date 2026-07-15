# W010 Complete MSForms Object-Model Parity Evidence

Status: execution baseline through MS-OFORMS persistence/default capture
(`oxforms-jbjp.3`)

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

The reviewed execution graph has 72 strict, atomic child beads. Each child has
an exact evidence path declared in its `br` design field, an explicit
no-temporary-production-scaffolding policy, residual/blocker behavior, and the
owner-mandated fresh-eyes review followed by a bead-scoped commit. The sequence
also contains an independent `.frm`/`.frx` export-fact lane, a precise OxVba
FormModule handover plus later production-integration gate, and separate
supporting-object, real HTML-family, post-HTML shared-band, event, render,
corpus, and stress outcomes. It also explicitly owns the documented intrinsic
global `UserForms` collection and loaded-form registry.

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
- MS-OFORMS is the binary Office forms/default source, not the text `.frm` grammar
  or `.frx` export-offset specification. `oxforms-jbjp.43` independently derives
  that accepted persistence universe from preserved real exports and public
  sources before parser/serializer implementation.

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
| evidence validators | 31/31 passed |
| `git diff --check` | no content error; pre-existing `.gitignore` line-ending warning only |
| bead dependency cycles | none |
| workspace Rust tests | not a pass: initial 300-second budget expired in `oxvba_reducer_cmdbutton` without a reported assertion failure |

Later beads add their artifacts here and extend the repository evidence runner
with deterministic validators. A dashboard summary is never a substitute for a
generated member row and its test/evidence anchors.
