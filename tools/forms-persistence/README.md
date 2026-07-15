# Forms-Persistence Fact Tooling

Status: durable W010 evidence tooling for `oxforms-jbjp.43`; the bead remains
in progress until its verification, fresh-eyes review, and commit complete.

This directory captures and validates the independent `.frm`/`.frx` export
facts that later parser, serializer, and resource beads must consume. It does
not implement production persistence behavior.

## Authority profiles

The fact pack keeps three profiles separate:

| Profile | Authority | Permitted use |
|---|---|---|
| `office_vba_userform_export` | Genuine Excel/VBE export produced through public `VBComponent.Export` | Canonical observation for the captured Office VBA UserForm export shape |
| `vb6_frm_export` | Uncaptured in this bead | Reserved as a separate dialect; establishes no facts here |
| `legacy_synthetic_nested` | Existing project-authored nested `Begin`/`End` fixtures and the OxForms canonical extension | Compatibility inventory only; never Office-export authority |

Cross-profile promotion is forbidden. In particular, a nested textual control
block from the legacy synthetic corpus cannot establish that an Excel/VBA
export writes controls that way.

## Preserved Office capture

`Capture-MSFormsExports.ps1` uses Excel `16.0.20131.20112`, VBE `7.01`, and
public `VBComponent.Export` to author and export three transient UserForms. The
capture ran in a 64-bit process on 64-bit Windows with ANSI code page 1252 and
records the Excel executable, FM20 registration, capture tool, capture spec,
requested values, readbacks, success/failure results, and every exported file
hash in `capture_manifest.v2.json`. Requested list items and the actual
`ListCount`/indexed `List` readback are separate manifest fields; request data
is never presented as an observation. `ComboBoxProbe` requested and read back
`red`, `green`, `blue` with count 3; `ListBoxProbe` requested and read back
`alpha`, `beta`, `gamma` with count 3.

Requested control geometry, actual readback geometry, and the comparison result
are likewise separate. Geometry must remain finite, with positive width and
height. Exact equality is required unless the capture spec pins a complete
deterministic readback and basis. The sole pinned normalization is
`ListBoxProbe.Height`: MSForms reads the requested `60.0` points back as
`49.150001525878906` on the frozen host/build; every other geometry field and
control remains exact.

The capture spec freezes the evidence identity: capture date, exact repository
output, Excel executable length/SHA-256/file/product versions, Excel automation
version/build, VBE version, and the expected VBE binary identity. A different
output name or updated Excel executable fails before a staging directory is
created. The output leaf must be exactly
`<YYYYMMDD>-excel-<Excel-file-version>`, and a real run is accepted only on the
frozen UTC date. The manifest records and checks the exact uniquely loaded
`VBE[0-9]*.DLL` module. If discovery cannot establish that identity, the
discovery result is a structured `unknown` with an explicit nonclaim, and this
frozen canonical capture refuses promotion instead of guessing.

After COM activation, the tool resolves and hashes the executable of the
process behind the actual Excel window handle. A different registered COM host
cannot inherit the preflight executable's frozen identity. Staged validation
also re-hashes the loaded VBE bytes and preserves the caveat that a
loaded-module observation does not prove ownership of `VBComponent.Export`.
For Click-to-Run Office, the manifest keeps the module-reported virtual path
separate from the readable binary path. An unreadable Common Files path is
mapped only to the unique matching `vfs/ProgramFilesCommonX64` or
`vfs/ProgramFilesCommonX86` backing file beneath the actual frozen Excel Office
root; the mapping basis and caveat are explicit manifest fields.

For this preserved v2 capture, the actual Excel window resolved to process
`38708` and
`C:\Program Files\Microsoft Office\Root\Office16\EXCEL.EXE` (76,582,128
bytes; SHA-256
`1f653c8b7979fc80bec5a40423e0cd59cb4ad64644558bcab15a24416ce4e33e`). The
loaded module reported
`C:\Program Files\Common Files\Microsoft Shared\VBA\VBA7.1\VBE7.DLL`; its
unique readable Click-to-Run backing was
`C:\Program Files\Microsoft Office\Root\vfs\ProgramFilesCommonX64\Microsoft Shared\VBA\VBA7.1\VBE7.DLL`
(4,487,696 bytes; SHA-256
`a5b35d9ae67788869fe2cb92d410b8fa6f13f374208571eb3ea548850ff50810`).
The manifest records both paths, the deterministic resolution basis, and the
explicit non-ownership caveat.

The three `.frm`/`.frx` pairs cover:

- controlled outer defaults and nondefaults, including CP-1252 text, doubled
  quotes, omission observations, and code that resembles designer assignments;
- all fourteen documented intrinsic `Controls.Add` families; and
- structural UserForm and Page instances, nested Frame and MultiPage children,
  TabStrip tabs, list data, and nondefault property probes.

That is sixteen `Controls.Add` instances spanning all fourteen intrinsic
families. Structural UserForm and Page observations bring the observed-family
universe to sixteen. The capture contains 2,210 `.frm` bytes and 14,920 `.frx`
bytes.

All 24 recorded ProgIDs, including all ten actual HTML ProgIDs, were registered
on this capture machine, but the same-build HTML designer `Controls.Add` probes
returned `E_INVALIDARG`
(`0x80070057`). This proves only designer-add rejection in that host/build; it
does not prove runtime non-callability or exclude any HTML typelib row.

To recapture deliberately on a compatible machine with Trust access to the VBA
project object model enabled:

```powershell
pwsh -File tools/forms-persistence/Capture-MSFormsExports.ps1 -SafetyCheckOnly
pwsh -File tools/forms-persistence/Capture-MSFormsExports.ps1 -Force
```

`-SafetyCheckOnly` verifies repository/output path safety and the frozen Excel
executable identity without starting Excel or changing files; the real capture
path additionally enforces the frozen UTC date and loaded VBE identity.
`-Force` never edits or removes the authoritative directory while capture is
underway. It exports into a fresh sibling staging directory, rejects reparse
points in every path component and staged tree, validates the exact file set,
all manifest observation/provenance structures against the capture spec,
source and export hashes, frozen identity, and list provenance, then promotes
by same-parent directory renames. The old directory is first renamed to a
private backup. If an unexpected target appears, it is preserved under a
quarantine name before the authoritative directory is restored. If an
obstruction is itself unsafe to move, the tool reports the explicit backup and
target paths rather than deleting either one.

The focused safety/rollback test also does not start Excel:

```powershell
pwsh -File tools/forms-persistence/tests/Test-CaptureMSFormsExportsSafety.ps1
```

Recapture is not part of the ordinary repository check because the real path
requires Excel and replaces preserved evidence after validation. Review every
resulting hash, requested-versus-readback value, and exporter-identity record
before updating pins.

## Text and binary boundaries

The strict Office text inventory parses the MS-OVBA `VBFrameText` root,
recognizes the normative ordered universe of fifteen `DesignerProperties`, and
records the observed subset with byte and line spans. It then treats the
contiguous class-module `Attribute` header according to MS-VBAL. Every byte
after that header is opaque VBA code; assignment-shaped code is never
reclassified as designer metadata.

The pinned MS-OVBA/MS-VBAL selection contains 187 source rows: 22 headings,
135 paragraphs, and 30 table cells.

The live export adds one root `OleObjectBlob` reference of the form
`"<safe-basename>.frx":<hex-offset>`. This is an observed Office/VBIDE
extension outside the selected normative MS-OVBA `DesignerProperties` grammar.
The tool therefore records it without promoting it into that grammar. The
three captured references are exactly `:0000`; they establish neither a
general lexical-width rule nor any nonzero-offset behavior.

Each captured `.frx` begins with an opaque 24-byte prefix followed by an
embedded MS-CFB file. The CFB inventory validates allocation and stream chains,
hashes every stream, and inventories the prefix, validated CFB logical extent,
free regions, and trailing/residual data so that every source byte is accounted
for under strict ownership checks. The prefix is preserved as bytes; no field
meanings are inferred. No control property value is decoded from FRX in this
bead.

Across the three pairs, that inventory contains three roots, four storages, 22
streams, six logical byte-region records, 32 physical CFB ownership regions,
and 62 physical mini-stream ownership regions. The zero logical free
`mini_regions` count is not a claim that no physical mini sectors exist.

The CFB requirements are not sourced from project paraphrase alone. Microsoft
MS-CFB revision 12.0 is preserved byte-for-byte at
`reference/ms-cfb/[MS-CFB]-240423.docx`; 80 exact rows spanning sections
2.1-2.8 plus three identity rows are normalized into
`reference/ms-cfb/ms_cfb_selected_rows.v1.jsonl`.
`extract_ms_cfb_selected_rows.py` verifies the official DOCX hash, deterministic
WordprocessingML extraction, row selection, and committed JSONL bytes. The
separate `ms_cfb_selected_rules.v1.json` labels its shorter inventory rules as
project interpretations and binds each interpretation group to those source
rows.

## Normative binary contract

The binary contract is a source-linked projection of the pinned `.3`
MS-OFORMS fact pack. It is deliberately separate from the live opaque FRX
evidence and does not imply that any live value was decoded. The projection
contains three object-valued properties, five type layouts, five resource
formats, eight stream-data slots, and fourteen separate-storage presence
flags.

It selects 43 length/count fields in five groups: fifteen aggregate record
byte lengths, fourteen string count/compression fields, seven variable-region
byte lengths, five serialized collection counts, and two resource-payload
lengths. Four resource-format codecs accompany those fields. The omission and
default surface contains 98 property-default/status records (95 documented
defaults and three mandatory-persist/no-default statuses), 107 control-specific
default-matrix rows, fifteen property masks with 221 entries, and 192 storage
requirements. Live nondefault object probes and decoded live object/property
values both remain zero.

## Property and unknown coverage

The generator creates exactly one mapping for each of the 98 independently
generated MS-OFORMS properties:

| Classification | Count |
|---|---:|
| Exact-name live public property probe | 47 |
| Live context only, not an exact property probe | 16 |
| Documented internal structure only | 18 |
| Documented with no exact live probe | 17 |

Those 98 property rows expand to 245 property/family pairs:

| Family-pair status | Count |
|---|---:|
| Exact-name live probe | 100 |
| Context only, not an exact probe | 28 |
| Documented internal only | 33 |
| Unprobed | 84 |

Exactly 34 exact-name property rows have full coverage across every applicable
family. These rows and pairs state what evidence exists; they do not decode
binary property values or create runtime API claims.

Fifteen unknown classes cover outer properties/value lexemes/blocks, the
module header and code body, unsafe resource paths, the FRX prefix, unknown CFB
storages and streams, allocated CFB-sector and mini-sector slack, unallocated
CFB and mini sectors, trailing bytes, and documented MS-OFORMS unknowns. Each
class has an explicit preserve-or-reject write rule. Unsafe rooted, traversal,
drive, UNC, alternate-stream, or non-basename resource paths are inventoried
but never dereferenced.

## Generate and validate

The ordinary Foundation-independent commands use only Python's standard
library and committed files:

```powershell
python -B tools/forms-persistence/validate_frm_frx_facts.py
python -B tools/forms-persistence/extract_ms_cfb_selected_rows.py
pwsh -File tools/evidence/Test-W010FrmFrxExportFacts.ps1
```

Generation and `--check` read the pinned Foundation sources. The source-required
commands verify the exact clean Foundation commit and pinned MS-OVBA/MS-VBAL
blobs; `--check` regenerates twice and byte-compares the committed artifact:

```powershell
python -B tools/forms-persistence/export_frm_frx_facts.py
python -B tools/forms-persistence/export_frm_frx_facts.py --check
python -B tools/forms-persistence/validate_frm_frx_facts.py --require-sources
pwsh -File tools/evidence/Test-W010FrmFrxExportFacts.ps1 -RequireSource
```

`expected_capture.v1.json` independently freezes the reviewed summary and
semantic digest. Strict JSON loading rejects duplicate keys and non-finite
numbers. Canonical output is UTF-8/LF with sorted keys, no timestamps, and no
absolute checkout paths.

## Explicit non-claims

This tooling does not claim:

- a production `.frm` parser, serializer, `.frx` reader/writer, or codec;
- decoded FRX control-property values;
- runtime properties, methods, errors, coercions, or constructor defaults;
- a captured or authenticated VB6 export dialect;
- a general `OleObjectBlob` offset width or any nonzero-offset behavior; or
- broader HTML callability/non-callability beyond the recorded designer-add
  result on the one captured host/build.
