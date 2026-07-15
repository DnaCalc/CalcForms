# oxforms-jbjp.43 — Independent FRM/FRX Export Facts

Status: generated evidence candidate; bead verification, exact fresh-eyes
review, post-review commit, and closure are still in progress

This bead establishes an independent text-export and resource-container fact
surface for later W010 parser, serializer, resource, and corpus work. It changes
no production VBA or Rust behavior.

## Artifacts

| Artifact | Purpose |
|---|---|
| `frm_frx_export_facts.v1.json` | Lossless selected MS-OVBA/MS-VBAL rows, genuine Office export inventory, profile boundaries, property mappings, CFB inventory, and unknown policy |
| [`fixtures/forms-persistence/.../20260715-excel-16.0.20131.20112/`](../../../../../fixtures/forms-persistence/office-vba-userform-export/20260715-excel-16.0.20131.20112/) | Three preserved Excel/VBE `VBComponent.Export` `.frm`/`.frx` pairs and capture manifest |
| [`expected_capture.v1.json`](../../../../../tools/forms-persistence/expected_capture.v1.json) | Independent reviewed semantic digest and exact summary floor |

The schema, authority boundaries, and explicit non-claims are in
[`../../../../specs/MSFORMS_PERSISTENCE_MODEL.md`](../../../../specs/MSFORMS_PERSISTENCE_MODEL.md).
Capture, regeneration, validation, and mutation-test tooling are documented in
[`../../../../../tools/forms-persistence/README.md`](../../../../../tools/forms-persistence/README.md).

## Source identity

- Foundation commit:
  `e6cfe71cfa1ebf07f52d1c7816a637ad5baad78b`.
- MS-OVBA 15.0 DOCX SHA-256:
  `31fb68ac3ef209cb32247a3060ff775cc0517c4120137cb39945690448b46c79`.
- Canonical-LF MS-OVBA segment SHA-256:
  `0841dfad53ba5631fa4a86a34d113bc32f6e16e245e056acec86b519c67a29c8`.
- MS-VBAL DOCX SHA-256:
  `f945507ef43b2ecfcea76d872536ce3566def87c2c3f383d664380533197cfc1`.
- Canonical-LF MS-VBAL segment SHA-256:
  `8035317ea8229f2d2ac7d2157d6d933da433d737429b958545e82d68001b7b6f`.
- Microsoft MS-CFB 12.0 DOCX SHA-256:
  `2d650184072a148ba98ad0b68072fd5ad7780e46f3528d7f263f3127b2dadab5`.
- Canonical-LF MS-CFB selected-row SHA-256:
  `a4292137cbd8933f6b55398dfc9c8cee366d4f65270c4dd849b6b33afe22b765`.
- Local prerequisites: exact `.2` FM20/referenced-typelib facts and exact `.3`
  MS-OFORMS persistence/default facts.

Selected source spans are MS-OVBA rows 651-656, 724-726, 2828-2932, and
5620-5645, plus MS-VBAL rows 1480-1526. They preserve 187 source rows: 22
headings, 135 paragraphs, and 30 table cells.

A separate 83-row MS-CFB selection (80 normative section rows plus three
identity rows) covers sections 2.1-2.8 for header and version fields,
allocation chains, FAT/mini FAT/DIFAT, directory and sibling trees, user
data/slack, and range locking. It is extracted deterministically from the
byte-pinned Microsoft revision 12.0 DOCX; the shorter CFB inventory rules remain
explicitly labeled project interpretations.

## Genuine Office capture

The preserved capture uses public `VBComponent.Export` from an unsaved,
transient, project-authored workbook under Excel `16.0.20131.20112` and VBE
`7.01`. The process and OS are 64-bit; the culture is `en-ZA` and the ANSI code
page is 1252. The capture manifest pins the Excel executable, FM20
registrations, capture script/spec, every requested value and readback, each
failure, and every exported file hash.

The v2 manifest identifies the actual Excel process (`38708`) behind the
automation window and pins its exact executable at
`C:\Program Files\Microsoft Office\Root\Office16\EXCEL.EXE` (76,582,128
bytes; SHA-256
`1f653c8b7979fc80bec5a40423e0cd59cb4ad64644558bcab15a24416ce4e33e`). It
also identifies the uniquely loaded `VBE7.DLL` (4,487,696 bytes; SHA-256
`a5b35d9ae67788869fe2cb92d410b8fa6f13f374208571eb3ea548850ff50810`).
Click-to-Run reported the virtual Common Files module path, while the exact
bytes were read from
`C:\Program Files\Microsoft Office\Root\vfs\ProgramFilesCommonX64\Microsoft Shared\VBA\VBA7.1\VBE7.DLL`;
the reported path is
`C:\Program Files\Common Files\Microsoft Shared\VBA\VBA7.1\VBE7.DLL`.
Both paths, the resolution basis, and the ownership caveat are explicit. This
identifies the loaded binary without claiming that the observation
independently proves which binary owns `VBComponent.Export`.

The three pairs are:

- `W010OuterDefaults.frm/.frx`;
- `W010OuterNonDefaults.frm/.frx`; and
- `W010IntrinsicMatrix.frm/.frx`.

Together they contain 2,210 `.frm` bytes and 14,920 `.frx` bytes. The matrix
contains sixteen `Controls.Add` instances spanning all fourteen documented
intrinsic families, with a nested Frame child, MultiPage/Page child, TabStrip
tabs, and list/resource data. Structural UserForm and Page observations bring
the observed-family universe to sixteen.

The manifest keeps requested list items separate from the actual `ListCount`
and indexed `List` readback. `ComboBoxProbe` requested and read back
`red`, `green`, `blue` with count 3; `ListBoxProbe` requested and read back
`alpha`, `beta`, `gamma` with count 3. It likewise separates requested and
observed geometry: `ListBoxProbe.Height` is the only pinned normalization,
from the requested `60.0` points to the observed `49.150001525878906`; all
other geometry fields compare exactly.

All 24 recorded ProgIDs, including all ten actual HTML ProgIDs, were registered
on the same machine. The HTML designer `Controls.Add` probes returned
`E_INVALIDARG` (`0x80070057`). The fact pack deliberately limits the claim to
designer-add rejection on this exact host/build; it does not claim runtime
non-callability.

## Three authority profiles

| Profile | Disposition |
|---|---|
| `office_vba_userform_export` | Canonical observation for this captured Office VBA export shape |
| `vb6_frm_export` | Separate uncaptured profile; no VB6 claim |
| `legacy_synthetic_nested` | OxForms extension/project-authored compatibility corpus only |

Cross-profile promotion is forbidden. All six legacy synthetic files are
censused: three parse completely, two are deliberately partial designer-only
fixtures rejected by the complete profile, and one is a non-CFB FRX stub. None
can establish an Office export fact. Their nested textual control blocks are
absent from the genuine Office profile, where the control graph is stored in
FRX CFB data.

## Text grammar and code boundary

The selected MS-OVBA grammar defines fifteen ordered `DesignerProperties`:

`Caption`, `ClientHeight`, `ClientLeft`, `ClientTop`, `ClientWidth`, `Enabled`,
`HelpContextID`, `RightToLeft`, `ShowModal`, `StartUpPosition`, `Tag`,
`TypeInfoVer`, `Visible`, `WhatsThisButton`, and `WhatsThisHelp`.

Only `Enabled = True`, `ShowModal = True`, `TypeInfoVer = 0`,
`Visible = True`, and `WhatsThisButton = False` have explicit defaults in the
selected grammar rows. Eight controlled same-build outer-property pairs are
serialization observations, not runtime constructor-default claims.

Each live file contains an `OleObjectBlob = "<safe-basename>.frx":<hex>` root
property. Because that property is outside the selected normative MS-OVBA
`DesignerProperties` production, the manifest classifies it as an observed
Office/VBIDE extension and does not amend the grammar.

After the designer `End`, the three files contain the same ordered class header:
`VB_Name`, `VB_GlobalNameSpace`, `VB_Creatable`, `VB_PredeclaredId`, and
`VB_Exposed`. MS-VBAL and the byte-exact inventory establish the boundary. The
three remaining code bodies are opaque; assignment-shaped VBA lines remain
code.

## FRX structural inventory

Each `.frx` begins with an opaque 24-byte prefix and an MS-CFB signature at
offset 24. No prefix field is interpreted. The strict CFB inventory covers
three roots, four storages, 22 streams, six explicit `byte_regions` records,
32 physical CFB regions, and 62 physical mini-stream regions. There are zero
logical free `mini_regions` records; that is distinct from the 62 physical
mini-sector ownership records. Allocated structures and streams are validated,
while the prefix, CFB logical extent, and trailing/residual regions account for
the complete source length under strict ownership checks.

This is not binary property decoding: the decoded FRX property-value count is
zero.

## Normative binary contract boundary

The binary contract is a source-linked projection of the pinned `.3`
MS-OFORMS facts, not a decoding of the live opaque FRX bytes. It selects three
object-valued properties, five type layouts, five resource formats, eight
stream-data slots, and fourteen separate-storage presence flags. Its 43
selected length/count fields are grouped as fifteen aggregate record byte
lengths, fourteen string count/compression fields, seven variable-region byte
lengths, five serialized collection counts, and two resource-payload lengths;
four resource-format codecs are preserved.

The same normative projection carries 98 property-default/status records (95
documented defaults and three mandatory-persist/no-default statuses), 107
control-specific default-matrix rows, fifteen property masks with 221 entries,
and 192 storage requirements. Live nondefault object probes and decoded live
object/property values both remain zero. The text corpus observes exactly
three `OleObjectBlob` references at `:0000`; it establishes no general lexical
width and no nonzero-offset rule.

## Exact coverage

| Dimension | Count |
|---|---:|
| Genuine Office `.frm`/`.frx` pairs | 3 |
| Profiles | 3 |
| Source rows (`heading` / `paragraph` / `table_cell`) | 187 (22 / 135 / 30) |
| Normative DesignerProperties | 15 |
| Component headers / opaque code bodies | 3 / 3 |
| Controlled outer-property pairs (`controlled_omission_pairs`) | 8 |
| Resource references | 3 |
| `Controls.Add` instances / intrinsic families / observed families | 16 / 14 / 16 |
| Registered ProgIDs / HTML designer-add rejections | 24 / 10 |
| MS-OFORMS property mappings / family pairs | 98 / 245 |
| Property rows: exact / context / internal / unprobed | 47 / 16 / 18 / 17 |
| Family pairs: exact / context / internal / unprobed | 100 / 28 / 33 / 84 |
| Exact-name rows with full family coverage | 34 |
| CFB roots / storages / streams | 3 / 4 / 22 |
| CFB byte / physical / mini-physical regions | 6 / 32 / 62 |
| Logical free `mini_regions` records | 0 |
| Binary object properties / layouts / formats | 3 / 5 / 5 |
| Binary stream slots / presence flags | 8 / 14 |
| Selected binary fields by group | 43 (15 / 14 / 7 / 5 / 2) |
| Binary codecs / property-default-status records / matrix rows | 4 / 98 / 107 |
| Property masks / mask entries / storage requirements | 15 / 221 / 192 |
| Legacy synthetic files / complete parses | 6 / 3 |
| Unknown preservation classes | 15 |
| Decoded live object/property values / runtime API claims | 0 / 0 |

Probe applicability is family-specific. A property observed on one control
family cannot satisfy an unrelated family's mapping merely because its name is
the same. The controlled-pair count includes `RightToLeft = True`, whose
readback remained false and emitted neither value; it records that failure and
does not promote it into an omission/default rule.

## Unknown policy

The fifteen classes cover unknown outer properties, value lexemes and blocks;
the module attribute header and opaque code body; unsafe resource paths; the
FRX prefix; unknown CFB storages/streams; allocated CFB-sector and mini-sector
slack; unallocated CFB/mini sectors; trailing FRX bytes; and documented
MS-OFORMS unknowns. Each class has an explicit preserve-or-reject write rule.
Lossy normalization and cross-profile promotion are never implicit. Unsafe
resource paths are recorded without being dereferenced.

## Verification gates

Ordinary Foundation-independent committed-artifact check:

```powershell
pwsh -File tools/evidence/Test-W010FrmFrxExportFacts.ps1
```

Exact Foundation source pins plus two-read deterministic regeneration and byte
comparison:

```powershell
pwsh -File tools/evidence/Test-W010FrmFrxExportFacts.ps1 -RequireSource
```

The owning bead must also pass the repository Rust/evidence/hygiene/graph floor
and the exact mandated fresh-eyes review before this README may claim the bead
is closed. The presence of this candidate artifact is not closure evidence.

## Explicit non-claims

This bead does not provide or claim:

- production `.frm` parsing or serialization;
- `.frx` resource reading/writing, binary property decoding, or a codec;
- runtime API, behavior, error, coercion, event, or constructor-default parity;
- an authenticated VB6 export;
- a general `OleObjectBlob` offset width or any nonzero-offset behavior; or
- HTML runtime callability or non-callability beyond the captured
  designer-add result.
