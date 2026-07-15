# MSForms Persistence and Export Fact Models

Status: W010 generated-fact contracts (`oxforms-jbjp.3` committed;
`oxforms-jbjp.43` in progress)

Schema: `oxforms.ms-oforms.persistence-facts.v1`

This document defines the deterministic MS-OFORMS binary-persistence and file-
format-default fact pack, then the independent `.frm`/`.frx` export-fact
contract derived by `oxforms-jbjp.43`. Together they are source contracts for
later parser, resource, serialization, control, and corpus beads. They do not
implement a codec and do not turn a persisted name, default, or export
observation into a callable runtime API claim.

## 1. Authority and pinned provenance

The primary semantic input is the normalized DOCX segment stream published by
Foundation at commit
`e6cfe71cfa1ebf07f52d1c7816a637ad5baad78b`. The underlying standard is
MS-OFORMS revision 9.1, published 2025-08-19.

The pin manifest at `tools/ms-oforms/pinned_sources.v1.json` independently
identifies:

- authoritative DOCX: 1,153,157 bytes,
  `7bbbbdc43407524fe2af99c070dfc358cc67404e5224b56d5cdabbc4736c9158`;
- authoritative PDF: 6,102,384 bytes,
  `37e72c8605244ebd28c2f247f9605d858fb44c194f835867d8b9ecedcb744db4`;
- the Foundation run input index, run manifest, document manifest, normalized
  DOCX segments, and all six selected figures; and
- capture tool commit `cbf24b746e66860242fd7b0d87ffac5d0e71807d`, run id
  `specproc-20260625-051108`, and the original capture's `git_dirty: true`
  caveat.

Raw documents and figures use byte hashes. Text pins use strict canonical UTF-8
bytes: CRLF is converted to LF, while bare CR and invalid UTF-8 fail. This makes
the pin independent of Git checkout newline policy without weakening content
identity. Source-required validation reads every pinned path from the exact
commit with `git show`, applies the same hash mode, and separately requires the
working-tree path to be tracked, clean, contained by Foundation, and identical.
The reviewed pin-manifest SHA-256 is
`32d4af439d67d67941f65d118b7a79d3450922224b28c09d5590a88b4a7ddc47`.

The DOCX segment stream is primary. The PDF extraction is provenance, not a
second semantic input, because merging the two normalized views would duplicate
and fragment facts.

## 2. Selected source universe

The pack preserves a contiguous 8,024-segment span, from `Saving Controls`
through the final Appendix A product-behavior note immediately before `Change
Tracking`. It is partitioned rather than flattened into one evidence class:

| Range | Segments | Evidence class |
|---|---:|---|
| Persistence context | 000631-000702 | documented persistence context |
| Structures, defaults, and algorithms | 000703-006820 | documented normative facts |
| Worked structures/property-bag examples | 006821-008618 | documented example vectors |
| Security considerations | 008619-008620 | documented security context |
| Appendix A | 008621-008654 | documented product behavior |

The selected rows contain 292 headings, 1,834 paragraphs, 5,892 table cells,
six image references, 161 tables, and 1,226 logical table rows. Every row keeps
its segment id, section, heading, source anchor, evidence class, and raw text.
Table cells additionally keep exact table/row/column coordinates. Extracted
blank cells remain explicit `<blank>` rows. Absolute Foundation paths never
enter the generated artifact.

Section numbers are restored by an exact normalized-title match against the
document's table of contents. `Saving Controls` must be the reviewed twenty-
third TOC entry; every selected heading must then consume the immediately next
entry through Appendix A, followed immediately by `Change Tracking`. Missing,
skipped, duplicate, reordered, or unmatched headings fail generation.

## 3. Generated surfaces

The fact pack has exact top-level keys; unknown keys fail validation.

### 3.1 Lossless source and layout rows

- `source_rows`: all 8,024 selected normalized rows;
- `sections`: 292 section spans with category, counts, table ids, and first/last
  segment identity; and
- `table_rows`: 1,226 coordinate-preserving logical rows. Raw merged-cell text
  is retained because the Foundation normalization does not expose Word grid-
  span metadata.

### 3.2 Codec and record rows

- `control_families`: eleven persistence-family mappings covering the fifteen
  visible controls plus Page. Mapping prose is linked directly; MorphData
  explicitly expands to CheckBox, ComboBox, ListBox, OptionButton, TextBox, and
  ToggleButton. Lexical member sections remain separate from explicit
  composite dependency roots, so Frame, MultiPage, Page, and UserForm also lead
  consumers to their shared Form, TabStrip, Page, storage, and stream records;
- `cached_control_ids`: all sixteen documented
  `FormEmbeddedActiveXControlCached` ids;
- `record_fields`: 431 non-bitfield fields across control/common-text/property-
  type records, including the ordinary `Depth` and conditional `OptionalType`
  fields in the mixed `FormObjectDepthTypeCount` section. Rows retain ordinal,
  size text, normalized fixed width where possible, requirement operation
  classes, typed deterministic values/subjects and ranges, raw conditions, and
  source;
- `record_sections`: ninety record-owning sections with 37 normalized aggregate
  requirements that do not belong to one field or bit. These include PropMask
  storage gates and TabStrip per-tab array storage/order invariants; and
- `property_types`: eighteen shared property-type sections, of which the ten
  font/picture/string resource formats are expanded in `resource_formats` with
  complete member spans, record fields, rules, six StdPicture payload formats,
  and the Strings compression/count/null-terminator codec contract.

Bitfield fields are excluded from `record_fields` and represented once under
`bitfields`; this prevents two rows from claiming ownership of the same bits.

### 3.3 Masks, flags, and enumerations

`bitfields` contains 28 definitions and 320 ordered entries. Fifteen are
property-presence masks: fourteen are exactly 32 bits and MorphData is exactly
64 bits. Their 221 entries are classified without conflation as 176 separate-
storage presence bits, 33 reserved/unused bits, eight inline-default state
bits, and four correlated-constraint bits. The remaining 99 entries are 74
Boolean flags, 19 reserved/unused ranges, and six packed scalars, including
both four-bit fields of `fmFontPitchAndFamily`. Every entry keeps offset, width,
symbol/name, description, source, and parsed normative requirements where
present. Section- and entry-level qualifier rows retain all 23
`VariousPropertiesBitfield` applicability lists and supplemental rules.

`enumerations` contains 26 definitions and 132 members, including the named
`SITE_TYPE` constant table. Every member keeps its raw numeric text, parsed
integer, meaning, ordinal, and all three source-cell coordinates.
`value_maps` separately types three two-column discriminator/value maps and
their eight values: property-bag `TabFlag`, property-bag `BOOL`, and the two
`FormFont` GUID discriminators.

### 3.4 Properties and defaults

There are exactly 98 top-level persisted property definitions:

- 95 have one documented file-format default; and
- `DrawBuffer`, `PageCount`, and `Size` are mandatory-persist properties with
  no file-format default.

`properties` preserves description, exact normalized applicability, raw
applicability, separate product-behavior markers, constraints, source span,
tables, supporting default rows, and the default/mandatory statement. Three
non-default semantic tables are normalized into eight `value_domain_rows`:
`BoundColumn` and `TextColumn` numeric domains plus control-specific `Value`
semantics and its conditional zero-length rule. Tables 92 through 132 have
exactly one specialized default, enumeration, bitfield, or property-domain
owner.
`default_matrix` expands them into 107 typed rows:

- `explicit_scalar` for one shared documented default;
- `control_specific` for per-control tables;
- `resource_absent` for absent Font/Picture resources; and
- `mandatory_persist_no_default` for the three mandatory properties.

Hex defaults retain raw text plus uppercase hex, unsigned value, width, two's-
complement signed value, every referenced enum symbol, and complete verified
set-flag/source mappings for `SITE_FLAG`, `DX_MODE`, `FormFlags`, and
`VariousPropertiesBitfield`. Booleans, decimals, empty strings, strings,
HIMETRIC sizes/points, and absent Font/Picture/MouseIcon resources use separate
tagged shapes. Per-control table cells such as
`CheckBoxComboBoxListBox...` are segmented only against the exact known control
vocabulary; zero or multiple tokenizations fail, and the concatenated raw cell
is still retained. The same ambiguity rejection applies to the concatenated
set-flag lists in `VariousPropertyBits` defaults.

Persistence defaults are not runtime constructor defaults. For example, this
pack can document Image `PictureSizeMode` or ScrollBar `Max` file defaults
without asserting how a newly created OxForms object must initialize.

### 3.5 Algorithms, examples, product behavior, and unknowns

- `algorithms` distinguishes one complete ClassTable shared-context span from
  three normative procedures: UINT32 property-bag number formatting,
  `DispidRowset`, and `SetRowset`. Preconditions are separate from logical
  steps, and six wrapped DOCX continuation pairs are coalesced while retaining
  both source references;
- `worked_examples` contains six documented example vectors (string
  compression, CommandButton, MultiPage, UserForm, TabStrip, and property-bag
  format), explicitly not implementation-test evidence by themselves;
- `product_behavior` contains all twenty Appendix A notes, each linked one-to-
  one to the exact referenced context/normative/example source row, including
  hidden persistence-only properties and compatibility adjustments, and
  classified as documented product behavior rather than oracle observations;
  and
- `documented_unknowns` contains 179 reserved/unused/undefined/ignored rows,
  with non-exclusive read/write obligations. It distinguishes 155 normative
  constraints from 24 worked-example observations; generic prose using
  “unknown” and enum prose using “ignoring” are deliberately excluded.

The pack inventories 22 referenced external standards across 103 source
occurrences, including mixed-case MSDN/GIF/icon names while excluding the six
internal `[image]` placeholders. Those references are explicit dependency boundaries; this bead
does not pretend to capture MS-OAUT, MS-DTYP, MS-OLEDS, MS-OSHARED, MS-WMF,
MS-EMF, MS-OVBA, or the other referenced formats.

## 4. Determinism and validation

The ordinary validator needs only Python's standard library and committed
files. It performs strict JSON decoding (duplicate keys and non-finite values
fail), requires the fact artifact's exact canonical UTF-8/LF bytes, applies
exact recursive shape checks and contiguous source-row/coordinate checks, then
regenerates every derived surface from `source_rows` and requires exact
type-sensitive canonical equality. Source rows also enforce the exact document-
id segment prefix, kind-compatible anchors, positive table coordinates, the
six-figure census, and the 111 explicit `<blank>` table-cell markers.

Coverage gates freeze the counts above, including 71 control/common-text record
tables, 16 shared-type tables, 41 property/default/enum/flag tables, 15 masks,
16 cached ids, 98 properties, three property-domain tables/eight rows, 26
enum/constant definitions, three value maps, ninety record sections/37
aggregate requirements, one algorithm context/three procedures, six examples,
and twenty linked product-behavior notes. Runtime API and oracle arrays must
remain empty.

The canonical semantic SHA-256 is
`5c488d039273bd1aaedd465964e17262863e4d9dfb2fdf2f39b6b581efd7ebbf`.
`expected_capture.v1.json` independently freezes that digest and the complete
summary, so a coherent rewrite of both raw and derived rows still fails.

Source-required validation additionally checks the exact Foundation commit and
each expected-commit blob, all raw/canonical working-tree pins,
run/index/document-manifest relationships, 9,085-input-
segment continuity, selected range boundaries, table coordinates, and figures.
Export `--check` performs two clean reads and requires both regenerated byte
streams to equal the committed artifact.

## 5. Explicit non-claims

This bead does not:

- define the FM20 callable object model (owned by the `.2` fact pack and later
  parity ledger);
- infer runtime visibility, signatures, coercions, errors, events, or constructor
  defaults from persistence rows;
- claim an OxForms binary codec, `.frm` parser, `.frx` reader, serializer, or
  round-trip corpus exists;
- treat worked examples as passing implementation tests; or
- treat Appendix product behavior as independently observed oracle evidence.

The independent `.frm`/`.frx` export-fact candidate is described below. Parser,
serialization, resource decoding/writing, and round-trip behavior remain owned
by later W010 beads.

## 6. Independent `.frm`/`.frx` export facts

Schema: `oxforms.forms-persistence.export-facts.v1`

`oxforms-jbjp.43` adds a separate generated fact surface under
`docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.43/`.
The bead remains in progress until all required checks, its exact fresh-eyes
review, and its post-review commit complete. This section records the current
candidate contract rather than claiming closure.

### 6.1 Authority profiles and non-promotion

The export model has three deliberately non-interchangeable profiles:

| Profile | Authority class | What it may establish |
|---|---|---|
| `office_vba_userform_export` | `canonical_for_captured_office_vba_export` | Facts observed in the preserved Excel/VBE `VBComponent.Export` corpus |
| `vb6_frm_export` | `uncaptured_separate_profile` | Nothing in this bead; no authenticated VB6 export was captured |
| `legacy_synthetic_nested` | `oxforms_canonical_extension_and_legacy_synthetic_only` | Compatibility inventory for existing project-authored nested fixtures, never Office-export facts |

Cross-profile promotion is forbidden. A legacy nested textual `Begin`/`End`
control block cannot establish an Office VBA export rule, and an Office root
frame observation cannot silently define the uncaptured VB6 dialect.

### 6.2 Genuine Excel export corpus

The preserved capture was authored in a transient workbook and exported
through the public `VBComponent.Export` method by Excel
`16.0.20131.20112`/VBE `7.01`. The capture environment was 64-bit Windows and a
64-bit process, `en-ZA`, ANSI code page 1252. The manifest pins the Excel
binary, FM20 registrations, capture script and spec, requested and read-back
values, failures, raw files, and hashes.

The v2 manifest resolves the actual automation window to Excel process `38708`
and pins
`C:\Program Files\Microsoft Office\Root\Office16\EXCEL.EXE` (76,582,128
bytes; SHA-256
`1f653c8b7979fc80bec5a40423e0cd59cb4ad64644558bcab15a24416ce4e33e`). It
also pins the uniquely loaded `VBE7.DLL` (4,487,696 bytes; SHA-256
`a5b35d9ae67788869fe2cb92d410b8fa6f13f374208571eb3ea548850ff50810`).
Click-to-Run reported
`C:\Program Files\Common Files\Microsoft Shared\VBA\VBA7.1\VBE7.DLL`, while
the exact bytes came from
`C:\Program Files\Microsoft Office\Root\vfs\ProgramFilesCommonX64\Microsoft Shared\VBA\VBA7.1\VBE7.DLL`.
The reported and backing paths, deterministic resolution basis, and caveat are
all explicit; identifying the loaded binary does not independently prove which
binary owns `VBComponent.Export`.

Three genuine `.frm`/`.frx` pairs separate outer defaults, outer nondefaults,
and an intrinsic/container matrix. The latter contains all fourteen documented
intrinsic `Controls.Add` families plus structural UserForm and Page instances,
with nested Frame and MultiPage children, TabStrip tabs, list data, and broad
nondefault property probes. The current corpus totals sixteen `Controls.Add`
instances spanning all fourteen intrinsic families. Structural UserForm and
Page observations bring the observed-family universe to sixteen. The files
contain 2,210 `.frm` bytes and 14,920 `.frx` bytes.

Requested list items are separate from the actual `ListCount` and indexed
`List` readback. `ComboBoxProbe` requested and read back `red`, `green`,
`blue` with count 3; `ListBoxProbe` requested and read back `alpha`, `beta`,
`gamma` with count 3. Requested and observed geometry are likewise distinct.
The only pinned geometry normalization is `ListBoxProbe.Height`, from requested
`60.0` points to observed `49.150001525878906`; every other captured geometry
field compares exactly.

All 24 recorded ProgIDs, including all ten actual HTML ProgIDs, were registered
on this machine, but the same-build HTML designer `Controls.Add` probes rejected
them with `E_INVALIDARG`
(`0x80070057`). This establishes only designer-add rejection for that
host/build. It is not evidence of runtime non-callability and cannot exclude a
typelib row.

### 6.3 Normative VBFrame text and the Office extension

Pinned MS-OVBA 15.0 rows define `VBFrameText`, the root designer GUID/name, and
the exact ordered universe of fifteen `DesignerProperties`. Together with the
pinned MS-VBAL boundary rows, the export-fact source selection contains 187
rows: 22 headings, 135 paragraphs, and 30 table cells. The ordered universe
is:

1. `Caption`
2. `ClientHeight`
3. `ClientLeft`
4. `ClientTop`
5. `ClientWidth`
6. `Enabled`
7. `HelpContextID`
8. `RightToLeft`
9. `ShowModal`
10. `StartUpPosition`
11. `Tag`
12. `TypeInfoVer`
13. `Visible`
14. `WhatsThisButton`
15. `WhatsThisHelp`

The selected normative rows supply explicit grammar defaults only for
`Enabled = True`, `ShowModal = True`, `TypeInfoVer = 0`, `Visible = True`, and
`WhatsThisButton = False`; a missing declared default for another row is not a
runtime-default claim. The manifest keeps the normative grammar and the live
occurrence inventory separate. Eight same-build controlled pairs record
serialization observations, including the failed `RightToLeft = True`
readback; they are not constructor-default claims.

The Office export also writes one root `OleObjectBlob` lexeme. The three live
observations are exactly `"<safe-basename>.frx":0000`. They establish no
general lexical width and no nonzero-offset behavior. That property is not in
the selected normative MS-OVBA `DesignerProperties` production. It is
therefore an observed Office/VBIDE extension, not a grammar amendment. The
Office profile contains no nested textual control blocks; the captured control
graph resides inside the referenced FRX data.

### 6.4 Class header and code boundary

Pinned MS-VBAL rows establish the physical module-header/body separation. In
each preserved export, the designer root ends before a contiguous ordered
header of `VB_Name`, `VB_GlobalNameSpace`, `VB_Creatable`,
`VB_PredeclaredId`, and `VB_Exposed` attributes. All remaining bytes are an
opaque VBA code body. A line such as `Caption = "..."` after that boundary is
code and must never be parsed as designer metadata.

The three captured headers and three opaque code bodies have exact byte/line
spans and hashes. Office text is inventoried in code page 1252 with CRLF, so a
parser cannot obtain byte-exact preservation by assuming UTF-8.

### 6.5 FRX and CFB boundary

Every captured `.frx` begins with exactly 24 opaque bytes before an embedded
MS-CFB signature. No meaning is assigned to a prefix field. The fact pack
validates the CFB header, FAT/DIFAT/miniFAT and directory chains, stream bounds,
and source coverage, then inventories every stream, storage, free region,
mini-stream region, and trailing region.

Those structural requirements are bound to Microsoft's authoritative MS-CFB
revision 12.0 DOCX (2024-04-23), not merely to a project-authored summary. A
deterministic standard-library extractor pins 80 exact normalized rows across
sections 2.1-2.8 plus three identity rows. The shorter rules carried in the
fact pack are explicitly project interpretations with source-row links. Source `SHOULD` requirements
and OxForms' stricter evidence policy remain distinct.

The current corpus contains three CFB roots, four storages, 22 streams, six
explicit logical `byte_regions` records, 32 physical CFB ownership regions,
and 62 physical mini-stream ownership regions. There are zero logical free
`mini_regions` records; that is not a claim that no physical mini sectors
exist. Prefix bytes, the validated CFB logical extent, and trailing/residual
regions account for the complete captured FRX length under strict ownership
checks. This is structural inventory only: the pack decodes zero live FRX
control-property values and specifies no live-derived binary codec.

### 6.6 Normative binary contract boundary

The binary contract is a normative, source-linked projection of the pinned
`.3` MS-OFORMS fact pack. It is not derived by decoding the live opaque FRX
bytes. The object-valued surface contains three properties, five type layouts,
five resource formats, eight stream-data slots, and fourteen separate-storage
presence flags.

The contract selects 43 explicit length/count fields: fifteen aggregate record
byte lengths, fourteen string count/compression fields, seven variable-region
byte lengths, five serialized collection counts, and two resource-payload
lengths. Four source-linked resource-format codecs accompany the selection.
The normative omission/default projection contains 98 property-default/status
records (95 documented defaults and three mandatory-persist/no-default
statuses), 107 control-specific default-matrix rows, fifteen property masks
with 221 entries, and 192 storage requirements. Live nondefault object probes
and decoded live object/property values both remain zero; none of these
normative projections is a claim that a live FRX value was decoded.

### 6.7 MS-OFORMS property mapping coverage

The generator requires exactly one evidence-classification row for each of the
98 properties from the independent `.3` MS-OFORMS pack:

| Evidence classification | Count |
|---|---:|
| `live_public_property_probe_exact_name` | 47 |
| `live_context_only_not_exact_property_probe` | 16 |
| `documented_internal_structure_only` | 18 |
| `documented_no_exact_live_probe` | 17 |

Those property rows expand to 245 property/family pairs:

| Family-pair status | Count |
|---|---:|
| `exact_name_live_probe` | 100 |
| `context_only_not_exact_probe` | 28 |
| `documented_internal_only` | 33 |
| `unprobed` | 84 |

Exactly 34 exact-name property rows cover every applicable family. Probe
applicability is control-family-specific; a same-named property on an unrelated
family cannot satisfy a row. The classifications expose where live evidence
exists and where it does not. They do not decode the CFB data, infer a runtime
property, or convert a documented persistence field into a callable member.

### 6.8 Unknown preservation and rejection

Fifteen unknown classes make loss behavior explicit. Text classes cover
unknown outer properties/value lexemes/blocks, module attributes and opaque
code, and unsafe external-resource paths. Binary classes cover the 24-byte
prefix, unknown CFB storages/streams, allocated CFB-sector and mini-sector
slack, unallocated CFB and mini sectors, trailing FRX bytes, and MS-OFORMS
documented unknowns.

Readers preserve exact bytes, order, spans, and hierarchy where the class
allows it. Writers either reproduce that material or reject a lossy rewrite.
Cross-profile blocks are rejected rather than normalized. Rooted, traversal,
drive, UNC, alternate-stream, and non-basename resource paths are inventoried
without dereferencing and are rejected for writing.

### 6.9 Determinism and validation

The generator and validator live in `tools/forms-persistence/`. Canonical JSON
is UTF-8/LF, sorted and timestamp-free, with no absolute checkout paths. Strict
loading rejects duplicate keys and non-finite numbers. The validator rebuilds
derived surfaces, verifies pinned local inputs and every fixture hash, checks
text and CFB byte coverage, freezes the reviewed summary through
`expected_capture.v1.json`, and rejects use of synthetic fixtures as Office
authority.

Ordinary Foundation-independent committed-artifact checks:

```powershell
python -B tools/forms-persistence/validate_frm_frx_facts.py
python -B tools/forms-persistence/extract_ms_cfb_selected_rows.py
pwsh -File tools/evidence/Test-W010FrmFrxExportFacts.ps1
```

Generation always reads the pinned Foundation sources. The source-required gate
checks the exact clean Foundation commit, hashes the pinned MS-OVBA/MS-VBAL
commit blobs and working-tree copies, performs fresh regeneration, and
byte-compares the committed artifact:

```powershell
python -B tools/forms-persistence/export_frm_frx_facts.py --check
pwsh -File tools/evidence/Test-W010FrmFrxExportFacts.ps1 -RequireSource
```

### 6.10 Export-fact non-claims

The `.43` fact surface makes no claim of:

- a production `.frm` parser or serializer;
- an `.frx` reader, writer, binary property decoder, or codec;
- runtime API, behavior, error, coercion, event, or constructor-default parity;
- VB6 export grammar or compatibility;
- a general `OleObjectBlob` offset width or any nonzero-offset behavior; or
- HTML runtime callability/non-callability beyond the exact recorded
  same-build designer-add result.
