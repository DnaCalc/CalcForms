# OxForms Source References

Status: active reference map
Last updated: 2026-07-15
Owning bead: `oxforms-jbjp.43` (FM20/referenced-typelib and MS-OFORMS binary
default/persistence facts are committed; independent `.frm`/`.frx` export
facts are in progress and not yet a closed-bead claim)

This file names external source-of-truth inputs that OxForms reads but does not
own. Update it whenever a Foundation source mirror or OxVba development baseline
changes.

## Microsoft Forms Runtime And Public Documentation

The installed public type library is the authoritative API-shape input for
W010. Observed on 2026-07-15:

- File: `C:\Program Files\Microsoft Office\root\vfs\System\FM20.DLL`
- Library: Microsoft Forms 2.0 Object Library
- GUID/version: `{0D452EE1-E08F-101A-852E-02608C4D0BB4}`, 2.0
- File version: `16.0.20131.20012`
- Product version: `16.0.20131.0`
- Size: 1,763,584 bytes
- SHA-256:
  `2c0e732b0e794451659ab0ff4e8489a518dde18a396201ace10bd3409acf90fe`
- Census: 171 type infos: 60 coclasses, 64 dispatch interfaces, 42 enums,
  four aliases, and one non-dispatch `IFont` interface.

The W010 fact pack resolves the exact public external closure needed to
interpret FM20 signatures. The only referenced library is stdole:

- File: `C:\Windows\System32\stdole2.tlb`
- Library GUID/version: `{00020430-0000-0000-C000-000000000046}`, 2.0
- LCID/SYSKIND/flags: 0, `SYS_WIN32`, 8 (`FHASDISKIMAGE`)
- File/product version: `10.0.26100.1`
- Size: 28,672 bytes
- SHA-256:
  `815d6c50ad934a42800e52faef5207dd9352ab8c386793422682084c8f604c5d`

Reproducible capture runtime: 64-bit Python `3.12.10`, pywin32 `309`, platform
`Windows-11-10.0.26200-SP0`. The live check rejects runtime drift rather than
allowing host-provenance bytes to change silently. The ordinary committed-fact
validator remains standard-library-only.

The generated closure has 171 FM20 primary entries, 37 FM20 dual-interface
companions, and 12 required stdole types/views. The latter includes distinct
stdole `Picture` and public `IPictureDisp` alias records rather than treating a
display name or GUID alone as a complete identity. Exact pins, schema, capture,
and validation rules are in
[`specs/FM20_TYPELIB_FACT_SCHEMA.md`](specs/FM20_TYPELIB_FACT_SCHEMA.md); the
artifacts and checksums are indexed by
[`evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.2/README.md`](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.2/README.md).

Microsoft's public VBA documentation is the object/host overlay and example
source, not a substitute for the generated typelib ledger:

- [Microsoft Forms reference](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/reference-microsoft-forms)
- [Collections, controls, and objects](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/objects-microsoft-forms)
- [Methods](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/methods-microsoft-forms)
- [Properties](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/properties-microsoft-forms)
- [Events](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/events-microsoft-forms)
- [Add method and intrinsic ProgIDs](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/add-method-microsoft-forms)
- [UserForm object and intrinsic global UserForms collection](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/userform-object)

These pages were reachable and rechecked on 2026-07-15. They enumerate the
fourteen documented intrinsic control families and the three control-owned
collections; the UserForm page additionally defines the intrinsic global
`UserForms` collection with `Count`, default zero-based `Item`, and `Add`; and
the Add page records the `Forms.<Control>.1` ProgIDs and zero-based Page/Tab
insertion behavior. Missing HTML, hidden, versioned, or
exact signature rows in the documentation remain governed by typelib facts and
reproducible oracle captures rather than silently excluded.

## Foundation Forms Specification

The primary clean-room forms specification is **[MS-OFORMS] Office Forms Binary
File Formats**. Read it through the sibling Foundation repository rather than by
adding ad hoc downloads to OxForms.

Foundation reference surfaces:

- Doctrine: `../Foundation/REFERENCE_SPEC_FORMAT_AND_CONFORMANCE.md`
- Seeds: `../Foundation/reference/spec_seeds.csv`
- Mirror index: `../Foundation/reference/index.csv`
- Raw mirror root: `../Foundation/reference/downloads/...`

Observed Foundation state on 2026-07-15:

- HEAD: `e6cfe71cfa1ebf07f52d1c7816a637ad5baad78b`
- Worktree: no file changes; local branch was two commits ahead of
  `origin/master`.
- The official normalized MS-OFORMS run is committed at
  `../Foundation/reference/runs/20260625-ms-oforms-official-pass-01/outputs/`.
  Its README records 25,491 segments, 56,319 sentences, 13,115 spec items, 587
  conformance candidates, and zero pending extraction items.
- The published Foundation worktree is clean, but the run manifest records the
  original extraction tool worktree as `git_dirty: true`. OxForms preserves
  that capture caveat and independently pins every consumed artifact.

Pinned MS-OFORMS artifacts:

| Artifact | Path from OxForms | Revision | SHA-256 |
|---|---|---|---|
| Authoritative DOCX | `../Foundation/reference/downloads/officeprotocoldocs-f5hpbjgea6b8gneq.b02.azurefd.net/files/MS-OFORMS/[MS-OFORMS]-250819.docx` | 9.1, 2025-08-19 | `7bbbbdc43407524fe2af99c070dfc358cc67404e5224b56d5cdabbc4736c9158` |
| Authoritative PDF | `../Foundation/reference/downloads/officeprotocoldocs-f5hpbjgea6b8gneq.b02.azurefd.net/files/MS-OFORMS/[MS-OFORMS].pdf` | 9.1, 2025-08-19 | `37e72c8605244ebd28c2f247f9605d858fb44c194f835867d8b9ecedcb744db4` |
| Normalized DOCX segments | `../Foundation/reference/runs/20260625-ms-oforms-official-pass-01/outputs/docs/ms-oforms-ms-oforms-250819-7bbbbdc4/segments.jsonl` | canonical LF UTF-8, 9,085 rows | `94639c4bee6f20ef59a904254c640bbe1666cedd0019708891e45b485a314e84` |
| Run input index | `../Foundation/reference/runs/20260625-ms-oforms-official-pass-01/inputs/index.csv` | canonical LF UTF-8 | `ad45dfabc0921a6b13c0347ade06e50b92d4d47eecab4e6a888b3391e94ddb0d` |
| Run manifest | `../Foundation/reference/runs/20260625-ms-oforms-official-pass-01/outputs/run_manifest.json` | canonical LF UTF-8 | `b58b08dbdc183ecec14c122aea34283634f2e0eaba10967d6a38c4c07cd9efdc` |
| Document manifest | `../Foundation/reference/runs/20260625-ms-oforms-official-pass-01/outputs/docs/ms-oforms-ms-oforms-250819-7bbbbdc4/document_manifest.json` | canonical LF UTF-8 | `eaa7889f3d06be45c48c794ede082fd4a5290772f330f2306b3087d64a652ea7` |

Online seed:

- `https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-oforms/9c79701a-8c3e-4429-a139-b60ac3a1d50a`

OxForms uses MS-OFORMS for serialized form/control property facts, enums,
defaults, appearance vocabulary, and persistence matrices. The in-document
binary codec remains OxDoc scope; OxForms meets OxDoc at `.frm` / `.frx`.

`oxforms-jbjp.3` preserves the exact 8,024-row persistence span from `Saving
Controls` through all twenty Appendix A product-behavior notes. The generated
pack contains 431 non-bitfield record fields, 98 properties (95 defaults plus
three mandatory-persist/no-default rows), ninety record sections/37 aggregate
requirements, 28 bitfields/320 entries including 15 property masks, 26
enum/constant definitions, three discriminator/value maps, three property-
domain tables/eight rows, one shared algorithm context/three procedures, and
explicit normative-versus-example unknown and 22-standard/103-occurrence
external-reference boundaries. Schema, pins, and evidence are in
[`specs/MSFORMS_PERSISTENCE_MODEL.md`](specs/MSFORMS_PERSISTENCE_MODEL.md) and
[`evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.3/README.md`](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.3/README.md).

Foundation text pins use canonical LF UTF-8 bytes and reject bare CR; raw
DOCX/PDF/figure pins remain byte-for-byte. Each pin is also hashed from its
exact Foundation commit blob, independently of the clean working-tree copy.
This avoids checkout-dependent CRLF hashes without weakening source identity.
The PDF is provenance only: the DOCX segments are the single semantic input,
avoiding duplicate/fragmented facts.

Adjacent Foundation source for that boundary:

- **[MS-OVBA] Office VBA File Format Structure**
  - `../Foundation/reference/downloads/learn.microsoft.com/en-us/openspecs/office_file_formats/ms-ovba/b39ac32f-0ce1-4533-9297-2ff3ff62c9ec.md`
  - Index hash: `de6157f4b4a5e2c0806837176cb8cfd32ffadb86ac08b06276bd5e3c31d656e4`

## Independent `.frm`/`.frx` Export Sources

`oxforms-jbjp.43` does not treat MS-OFORMS as the text-export grammar. It pins
the adjacent MS-OVBA and MS-VBAL sources at the same Foundation commit and
combines them with a preserved public-automation Excel export. The current
fact candidate remains subject to the bead's verification, fresh-eyes review,
and post-review commit.

Pinned MS-OVBA inputs:

| Artifact | Path from OxForms | Revision | SHA-256 |
|---|---|---|---|
| Authoritative DOCX | `../Foundation/reference/downloads/officeprotocoldocs-f5hpbjgea6b8gneq.b02.azurefd.net/files/MS-OVBA/[MS-OVBA]-260519.docx` | 15.0, 2026-05-19 | `31fb68ac3ef209cb32247a3060ff775cc0517c4120137cb39945690448b46c79` |
| Authoritative PDF | `../Foundation/reference/downloads/officeprotocoldocs-f5hpbjgea6b8gneq.b02.azurefd.net/files/MS-OVBA/[MS-OVBA].pdf` | 15.0, 2026-05-19 | `6ca91a091da9b7a550e52ea60808fc78b676a3e96101a80990f75911619768c3` |
| Normalized segments | `../Foundation/reference/runs/20260624-ms-ovba-official-pass-01/outputs/docs/ms-ovba-ms-ovba-260519-31fb68ac/segments.jsonl` | canonical LF UTF-8 | `0841dfad53ba5631fa4a86a34d113bc32f6e16e245e056acec86b519c67a29c8` |

The selected MS-OVBA rows are 651-656 (module-identifier/newline grammar),
724-726 (designer storage/VBFrame relationship), 2828-2932 (normative
`VBFrameText` and the fifteen ordered `DesignerProperties`), and 5620-5645
(worked VBFrame example).
The DOCX segment stream is semantic input; the PDF is provenance only.

Pinned MS-VBAL inputs:

| Artifact | Path from OxForms | Release | SHA-256 |
|---|---|---|---|
| Authoritative DOCX | `../Foundation/reference/downloads/officeprotocoldocs-f5hpbjgea6b8gneq.b02.azurefd.net/files/MS-VBAL/[MS-VBAL]-250520.docx` | 2025-05-20 | `f945507ef43b2ecfcea76d872536ce3566def87c2c3f383d664380533197cfc1` |
| Normalized segments | `../Foundation/reference/runs/20260301-ms-vbal-webref-compare-v5-latest/outputs/docs/discovered-ms-vbal-250520-f945507e/segments.jsonl` | canonical LF UTF-8 | `8035317ea8229f2d2ac7d2157d6d933da433d737429b958545e82d68001b7b6f` |

Selected MS-VBAL rows 1480-1526 establish the physical class-module
attribute-header/body boundary. The export inventory applies that boundary
byte-exactly and leaves the remaining VBA body opaque.

Public documentation anchors:

- [MS-OVBA VBFrame](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-ovba/76ecef26-5e1c-4729-8074-c76584e25b6b)
- [MS-VBAL module representation](https://learn.microsoft.com/en-us/openspecs/microsoft_general_purpose_programming_languages/ms-vbal/4599fae2-3f41-4e70-968e-2398741f446b)
- [VBE `Export` method](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/export-method-vba-add-in-object-model)

Pinned MS-CFB inputs for the embedded FRX compound file:

| Artifact | Path from OxForms | Revision | SHA-256 |
|---|---|---|---|
| Authoritative Microsoft DOCX | `reference/ms-cfb/[MS-CFB]-240423.docx` | 12.0, 2024-04-23 | `2d650184072a148ba98ad0b68072fd5ad7780e46f3528d7f263f3127b2dadab5` |
| Normalized selected rows | `reference/ms-cfb/ms_cfb_selected_rows.v1.jsonl` | canonical UTF-8/LF, 83 rows | `a4292137cbd8933f6b55398dfc9c8cee366d4f65270c4dd849b6b33afe22b765` |
| Deterministic extractor | `tools/forms-persistence/extract_ms_cfb_selected_rows.py` | standard-library OOXML extraction | `86b05363a0edf4826877a710ed75a37fc5f3369ddd53470035a097c57647845c` |

The selected rows cover header/version fields, general chains, FAT, mini FAT,
DIFAT, directory entries and sibling trees, arbitrary user data and sector
slack, and the range-lock sector. Exact Microsoft wording remains distinct from
the project interpretations in `ms_cfb_selected_rules.v1.json`. In particular,
the source says the minor version `SHOULD` be `0x003E`, permits either color for
the sibling-less Root Entry, and lists no classical equal-black-height
invariant; stricter inventory policy is labeled separately rather than
attributed to Microsoft.

### Preserved Excel/VBE export

The genuine Office corpus is under
`fixtures/forms-persistence/office-vba-userform-export/20260715-excel-16.0.20131.20112/`.
It was generated from project-authored form content in an unsaved transient
workbook through public `VBComponent.Export`:

- Excel executable: `C:\Program Files\Microsoft Office\Root\Office16\EXCEL.EXE`;
- file/product version: `16.0.20131.20112`;
- executable size/SHA-256: 76,582,128 bytes,
  `1f653c8b7979fc80bec5a40423e0cd59cb4ad64644558bcab15a24416ce4e33e`;
- VBE automation version `7.01`, AccessVBOM enabled, component type 3;
- unique loaded Excel-process module `VBE7.DLL`, reported at
  `C:\Program Files\Common Files\Microsoft Shared\VBA\VBA7.1\VBE7.DLL` and
  byte-pinned through its unique readable Click-to-Run backing path under
  `C:\Program Files\Microsoft Office\Root\vfs\ProgramFilesCommonX64\`:
  4,487,696 bytes, file/product version `7.01.1153`, SHA-256
  `a5b35d9ae67788869fe2cb92d410b8fa6f13f374208571eb3ea548850ff50810`;
- 64-bit Windows/process, `en-ZA`, ANSI code page 1252; and
- strict v2 capture manifest:
  `fixtures/forms-persistence/office-vba-userform-export/20260715-excel-16.0.20131.20112/capture_manifest.v2.json`
  (114,100 bytes, SHA-256
  `08f3fd3e00cbb9cc8467906fd37f57056279d7f1c4efc337ed1ec2789c6683dd`).

The module attribution proves exact loaded-process binary identity, not which
binary implements `VBComponent.Export`. The manifest separately preserves
requested and read-back list items and geometry. Fifteen controls retain exact
requested geometry; the sole pinned normalization is `ListBoxProbe.Height`,
`60.0` requested to `49.150001525878906` read back.

The three captured pairs comprise 2,210 `.frm` bytes and 14,920 `.frx` bytes.
They contain sixteen `Controls.Add` instances spanning all fourteen intrinsic
families; structural UserForm and Page observations bring the observed-family
universe to sixteen. All ten HTML ProgIDs were registered, but same-build
designer adds returned only the
bounded observation `E_INVALIDARG` (`0x80070057`); this is not runtime
non-callability evidence.

The selected normative MS-OVBA grammar has fifteen ordered
`DesignerProperties`. The live export's root `OleObjectBlob` reference is kept
as an observed Office/VBIDE extension rather than promoted into that grammar.
Each FRX has an opaque 24-byte prefix before embedded CFB data; no prefix-field
or binary property meaning is inferred. The strict inventory partitions every
source byte through 32 physical regions and 62 mini-stream physical regions,
covering three roots, four storages and 22 streams.

The fact pack contains 187 pinned MS-OVBA/MS-VBAL source rows and classifies all
98 MS-OFORMS properties into 47 exact-name live rows, sixteen contextual-only
rows, eighteen documented internal-structure-only rows, and seventeen rows
without an exact live probe. Across the 245 property/family pairs, the counts
are 100 exact-name, 28 contextual-only, 33 internal-only, and 84 unprobed; 34
exact-name rows cover every applicable family.

The separate normative MS-OFORMS projection pins three object-valued
properties, five type layouts, five resource formats, eight stream-data slots,
fourteen presence flags, and 43 reviewed binary length/count fields grouped
15/14/7/5/2 with four governing codecs. Omission/default evidence covers all 98
properties, the 107-row control-specific matrix, fifteen masks with 221 entries,
and 192 storage requirements. Live decoded FRX property/object values remain
zero. The three textual resource observations are exact `:0000` references;
they establish no general nonzero-offset or lexical-length rule.

Full schema, profile separation, unknown preserve/reject policy, tooling, and
non-claims are in
[`specs/MSFORMS_PERSISTENCE_MODEL.md`](specs/MSFORMS_PERSISTENCE_MODEL.md),
[`../tools/forms-persistence/README.md`](../tools/forms-persistence/README.md),
and
[`evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.43/README.md`](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.43/README.md).

## OxVba Development Baseline

OxForms depends on OxVba, but the sibling `../OxVba` checkout is under active
development and may contain unrelated local artifacts. Do not use a floating
sibling path as a shared stable input.

Current committed OxForms baseline (authoritative in workspace manifests):

- Repo: `https://github.com/DnaCalc/OxVba.git`
- Commit: `8f1aeccc683c4d41621bf137574b8a4d11bd9845`
- Commit subject: `clippy: document unsafe blocks in oxvba-hal native ByRef marshaling`
- Commit date: 2026-07-01
- Branch relation observed on 2026-07-15: the pinned commit is an ancestor of
  `origin/master`.
- The sibling checkout was at `870ff78f39d241a9b150703a370927f8ca4eafef`
  with an unrelated untracked `artifacts/windows-x64/excel-vba-oracle/`
  directory. That mutable checkout is context only and is not the committed
  dependency baseline.

Why this baseline rather than a release tag:

- The workspace package version alone is not a sufficient compatibility
  baseline; the exact git revision is pinned in every consuming manifest.
- This revision includes the VM3/OxIR, project/reference, COM, event,
  default-member, native-body, array-performance, and host-object work used by
  the current OxForms runtime.

Committed Rust manifests use pinned git dependencies:

```toml
[dependencies]
oxvba-project = { git = "https://github.com/DnaCalc/OxVba.git", rev = "8f1aeccc683c4d41621bf137574b8a4d11bd9845" }
oxvba-host = { git = "https://github.com/DnaCalc/OxVba.git", rev = "8f1aeccc683c4d41621bf137574b8a4d11bd9845" }
oxvba-symbol = { git = "https://github.com/DnaCalc/OxVba.git", rev = "8f1aeccc683c4d41621bf137574b8a4d11bd9845" }
oxvba-bind = { git = "https://github.com/DnaCalc/OxVba.git", rev = "8f1aeccc683c4d41621bf137574b8a4d11bd9845" }
oxvba-bundle = { git = "https://github.com/DnaCalc/OxVba.git", rev = "8f1aeccc683c4d41621bf137574b8a4d11bd9845" }
oxvba-runtime = { git = "https://github.com/DnaCalc/OxVba.git", rev = "8f1aeccc683c4d41621bf137574b8a4d11bd9845" }
```

Use local `../OxVba` path overrides only for explicitly coordinated cross-repo
development and keep them out of committed shared manifests unless that bead is
about the coordinated dependency change.

Known forms integration boundary in this baseline:

- `../OxVba/docs/evidence/language/MS_VBAL_MODULE_PROJECT_REQUIREMENTS.csv` row
  `MODPROJ-030` still marks form-module lifecycle and UserForm integration as
  `planned` / `forms-deferred`.
- `oxvba-symbol` has `ModuleKind::Form`, but `oxvba-project` `.basproj` parsing
  currently exposes `<Module>`, `<ClassModule>`, and `<DocumentModule>` only.
- OxForms should track form-module materialization, default-instance exposure,
  designer-declared control members, and event handler wiring as OxVba
  integration closure work rather than papering over the gap locally. W010 now
  owns a precise handover in `oxforms-jbjp.44` and a separate production
  integration gate in `oxforms-jbjp.57`; local `.frm` parsing/serialization can
  proceed, but `.57` stays open or precisely blocked until the upstream contract
  is actually delivered and consumed.

## Baseline Update Procedure

When changing either baseline:

1. Record the old and new commit or artifact hash in this file.
2. Note the sibling repo worktree status used for the decision.
3. Update the relevant spec/workset/evidence surfaces in the same bead.
4. Run the checks available for the touched surfaces.
5. Add or update handovers when the source-of-truth repo must act.
