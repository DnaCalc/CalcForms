# MSForms Persistence and Default Fact Model

Status: W010 generated-fact contract (`oxforms-jbjp.3`)

Schema: `oxforms.ms-oforms.persistence-facts.v1`

This document defines the deterministic MS-OFORMS binary-persistence and file-
format-default fact pack. It is the source contract for later parser, resource,
serialization, control, and corpus beads. It does not implement a codec and it
does not turn a persisted name or default into a callable runtime API claim.

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

Canonical `.frm`/`.frx` export facts are the strict next bead (`.43`). Parser,
serialization, and resource implementations remain owned by their later W010
beads.
