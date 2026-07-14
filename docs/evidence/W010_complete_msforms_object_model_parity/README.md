# W010 Complete MSForms Object-Model Parity Evidence

Status: planning baseline (`oxforms-jbjp.1`)

This directory indexes the generated facts, oracle captures, differential
artifacts, conformance ledger, and closure evidence for W010. W010 supersedes no
earlier evidence: W005/W006/W008 event captures and W009 representative-control
proofs remain inputs, but they do not constitute full member parity.

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
