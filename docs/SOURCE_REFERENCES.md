# OxForms Source References

Status: active reference map
Last updated: 2026-07-15
Owning bead: `oxforms-jbjp.3` (FM20/referenced-typelib and MS-OFORMS binary
default/persistence facts complete; canonical `.frm`/`.frx` export capture
continues in `.43`)

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
