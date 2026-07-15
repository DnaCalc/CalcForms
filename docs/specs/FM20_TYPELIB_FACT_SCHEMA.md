# FM20 and referenced-typelib fact schema

Status: generated baseline complete (`oxforms-jbjp.2`)

This specification defines the machine-readable API-shape input used by W010.
It records public COM type-library facts; it does not claim runtime behavior,
VBA coercion/error parity, rendering, or persistence parity. Those claims are
owned by later ledger, oracle, implementation, and corpus beads.

## Artifacts and schemas

| Artifact | Schema |
|---|---|
| `tools/fm20/pinned_typelibs.v1.json` | `oxforms.fm20_typelib_pins.v1` |
| `tools/fm20/pinned_w005_baseline.v1.json` | `oxforms.fm20_w005_baseline_pin.v1` |
| `tools/fm20/expected_capture.v1.json` | `oxforms.fm20_expected_capture.v1` |
| `fm20_typelib_facts.v1.json` | `oxforms.fm20_typelib_facts.v1` |
| `w005_event_reconciliation.v1.json` | `oxforms.fm20_w005_event_reconciliation.v1` |

The two generated artifacts are under
`docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.2/`.
They are canonical UTF-8 JSON without a BOM, with LF line endings, sorted object
keys, two-space indentation, fixed array ordering, and one terminal newline.
No generation timestamp or Python object representation is permitted.

## Independently pinned inputs

Generation is allowed only from these exact inputs:

| Library | File identity | LIBATTR |
|---|---|---|
| MSForms | `FM20.DLL`, 1,763,584 bytes, file version `16.0.20131.20012`, SHA-256 `2c0e732b0e794451659ab0ff4e8489a518dde18a396201ace10bd3409acf90fe` | `{0D452EE1-E08F-101A-852E-02608C4D0BB4}`, 2.0, LCID 0, `SYS_WIN32`, flags 10 |
| stdole | `stdole2.tlb`, 28,672 bytes, file version `10.0.26100.1`, SHA-256 `815d6c50ad934a42800e52faef5207dd9352ab8c386793422682084c8f604c5d` | `{00020430-0000-0000-C000-000000000046}`, 2.0, LCID 0, `SYS_WIN32`, flags 8 |

The pin manifest is independent of the generated facts. It also pins the
capture runtime: 64-bit Python `3.12.10`, pywin32 `309`, and the recorded
Windows platform string. Before traversal, the exporter verifies runtime, file
size, hash, file/product versions, LIBATTR, and the registered stdole
resolution, then reloads and traverses the referenced library from that hashed
registered path. A mismatch fails without writing a partial fact artifact.

The legacy W005 input has a separate independent pin for path, CRLF byte
size/hash, schema, recorded FM20 hash, exact event/lifecycle sets, and census.
A reviewed-capture pin records the expected semantic canonical digest and
decisive counts. A coherently rewritten member row therefore fails even if a
bug also recomputes the digest embedded inside the generated artifact.

## Stable identities and closure

A library identity is:

```text
(normalized LIBID, major, minor, LCID, SYSKIND)
```

A type-view identity is:

```text
(library identity, containing type index, view)
view = primary | dual_interface
```

GUID, name, containing index alone, and raw HREFTYPE are not identities. FM20
duplicates five stdole GUID/name pairs, GUID_NULL occurs on multiple types, and
a dual companion shares its primary's library, index, GUID, and name. Raw
HREFTYPE values are retained only as owner-scoped diagnostics.

The committed closure contains exactly 220 views:

| Scope | Views | Functions | Variables | Implementation edges |
|---|---:|---:|---:|---:|
| FM20 primary entries | 171 | 1,757 | 199 | 177 |
| FM20 dual-interface companions | 37 | 1,067 | 0 | 37 |
| Required stdole closure | 12 | 8 | 22 | 2 |
| Total | 220 | 2,832 | 221 | 216 |

For every FM20 dual dispatch, `GetRefTypeOfImplType(-1)` supplies a separate
`TKIND_INTERFACE` view at the same containing index. Both views remain intact;
they are never merged. Their function counts are not assumed to have a fixed
relationship. The primary record carries the raw `-2` companion link and both
records carry stable cross-links.

External traversal starts with every implementation and typedesc reference,
then follows references transitively. The 11 forward-reachable stdole nodes are
indices `0,1,2,3,4,11,12,13,14,19,35`. A fixed-point reverse-alias rule adds
public alias index 36, `IPictureDisp`, because it targets reached `Picture`
index 35 and the acceptance perimeter explicitly requires both. Every record
therefore declares one or more auditable inclusion reasons:

- `root_primary`;
- `root_dual_companion`;
- `direct_reference`;
- `transitive_reference`; or
- `public_alias_of_reached_type`.

## Fact-pack structure

The root object records schema/version, generator provenance and source-file
hashes, the root library key, complete static OLE flag definitions, libraries,
resolved references, cross-library edge counts, recomputed summary counts, and
a canonical structural SHA-256.

Each library records:

- documentation/help metadata and LIBATTR;
- source path, name, size, hash, file version, and product version;
- the declared source type-info count;
- exported primary/view counts and kind censuses; and
- canonically ordered type views.

Each type view records:

- containing index, view, inclusion reasons, name/help metadata, GUID, LCID,
  kind, version, size/alignment/vtable/count fields, type and IDL flags;
- raw and resolved alias types;
- every FUNCDESC, VARDESC, and implemented-type row in source ordinal order;
- default-member and `_NewEnum` indexes;
- derived coclass ordinary-default, source-default, source, and restricted maps;
  and
- dual primary/companion links where applicable.

Each function records its ordinal, DISPID, complete `GetNames` result,
documentation, SCODE array, FUNCKIND, INVOKEKIND, CALLCONV, optional count,
vtable offset, return ELEMDESC, flags, parameters, DLL entry/MOPS when exposed,
and derived default/`_NewEnum` markers. Parameter names are nullable and have an
explicit `reported_by_GetNames` or `not_reported_by_GetNames` state; setter RHS
names omitted by COM are not fabricated.

The pinned pywin32 adapter exposes neither `GetDllEntry` nor `GetMops` on
`PyITypeInfo`. Those fields use an explicit `not_exposed_by_pywin32` state
rather than a null that could be misread as COM metadata absence.

Each parameter and return descriptor records the raw pywin32 ELEMDESC, decoded
parameter flags, a recursive type descriptor, and a tagged default state.
`not_encoded` is distinct from `encoded` null/Boolean/integer/float/string.
The pinned closure contains no `PARAMFLAG_FHASDEFAULT` rows, even where
`PARAMFLAG_FOPT` is present.

Each variable records its ordinal, DISPID, names/help, VARKIND, flags,
ELEMDESC, and an explicitly tagged VARDESC union interpretation:
`instance_offset`, `constant_value`, `static_value_not_exposed`, or
`dispatch_member_no_value`. Enum numeric values are the constant union values,
not their DISPIDs.

Recursive type descriptors preserve scalar VT, pointer target, user-defined
raw HREFTYPE plus stable resolved identity, or C-array element/bounds. The real
stdole `GUID.Data4` row exercises the C-array representation.

Every flag-bearing field is an object with:

```json
{
  "value": 4148,
  "names": ["FUNCFLAG_FBINDABLE", "FUNCFLAG_FDISPLAYBIND", "FUNCFLAG_FDEFAULTBIND", "FUNCFLAG_FIMMEDIATEBIND"],
  "unknown_bits": 0
}
```

The exporter uses complete static OLE Automation tables rather than pywin32's
incomplete constant set. Any unexplained bit fails validation. Source edges may
legitimately be `FDEFAULT|FSOURCE`; an eventful coclass can therefore have an
ordinary default and a source default. No single-default or index-zero-default
assumption is allowed.

Help strings/context and raw help paths are retained. A tokenized help-path
form is also emitted for review. Public pywin32 exposes all metadata used by the
schema but does not expose reserved `dwReserved`/`lpstrSchema` slots; this is a
documented adapter boundary, not silently reconstructed data.

## W005 structural reconciliation

The W005 artifact captured an earlier FM20 binary with SHA-256
`e5085d8229d72180c7f2d8762e1a49fff18a04f0143d7a973ff1fbc6200cb81e`.
The binary hash changed, so the reconciliation compares stable public
structure rather than raw HREFTYPE, capture timestamp, implementation ordinal,
path casing, or derived display labels.

The current projection exactly matches all W005 stable rows:

| Dimension | Count |
|---|---:|
| Coclass/source attachments | 51 |
| Unique source interfaces | 26 |
| Event rows | 376 |
| Selected event names | 22 |
| Arguments | 1,206 |
| Unexplained structural deltas | 0 |

The classification is `source_binary_changed_structure_same`. None of the six
checked UserForm lifecycle overlay names occur in FM20 source interfaces; their
absence does not exclude the public host overlay owned by later W010 beads.

## Validation contract

The committed-artifact validator rejects, among other failures:

- duplicate JSON keys, non-finite numbers, non-canonical bytes, or generator
  source drift;
- wrong pins, source identities, schema versions, censuses, descriptor totals,
  ordinals, or dual links;
- truncated types/functions/variables/implementations/parameters;
- dangling stable references, wrong external edges, missing aliases/enums, or
  the wrong stdole closure;
- unknown flag bits or incorrect flag/role/coclass/default markers; and
- a stale, incomplete, or structurally changed W005 comparison.

The repository-wide evidence runner performs the committed-artifact check with
standard-library Python and without loading Office or pywin32. The owning bead
additionally runs live source checking
and byte-for-byte regeneration:

```powershell
pwsh -File tools/evidence/Test-W010FM20TypeLibFacts.ps1
pwsh -File tools/evidence/Test-W010FM20TypeLibFacts.ps1 -RequireSource
```
