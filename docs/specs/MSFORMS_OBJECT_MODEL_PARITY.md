# MSForms object-model parity ledger

Status: deterministic raw-contract/current-overlay baseline established by
`oxforms-jbjp.4`; implementation and host-composed parity remain open

Schema: `oxforms.msforms_parity_ledger.v1`

This specification defines the row-level truth surface used by W010. The
ledger is an inventory and conformance contract, not a claim that OxForms is
already compatible. It keeps each authoritative declaration, public
projection, persistence fact, extracted implementation declaration, and
unresolved behavior visible so later beads can close exact rows without
laundering gaps through prose or aggregate percentages.

## 1. Authority layers

The generator consumes six distinct authority layers. They are joined by
stable identities and explicit references; one layer cannot silently replace
another.

| Layer | Authority | What it can establish |
|---|---|---|
| COM declarations | Pinned W010 `.2` FM20 and referenced-stdole fact pack | Type views, GUIDs, flags, implementation edges, FUNCDESC/VARDESC shapes, DISPIDs, enum values, and ABI layout |
| Legacy event reconciliation | Pinned W010 `.2` W005 reconciliation | Exact structural continuity for the 376 previously selected event rows only |
| Binary persistence | Pinned W010 `.3` MS-OFORMS facts | Documented persistence/default records and explicit documented unknowns |
| Export persistence | Pinned W010 `.43` `.frm`/`.frx` facts | Genuine Office export observations, family applicability, opaque-resource boundaries, and source-linked export contracts |
| Host/public overlay | Reviewed `public_overlay.v1.json` projection of official Microsoft documentation | UserForm/UserForms members, events, and prose capabilities absent from FM20, at only the precision stated by the cited page |
| Current implementation | Deterministic extraction of `OxForms.basproj` and all referenced VBA modules | What the repository presently declares and which clean/manual loader profiles expose it |

FM20/stdole facts remain exact raw contracts even when they cannot be lowered
to legal VBA syntax. MS-OFORMS and `.frm`/`.frx` names do not create callable
API claims. Documentation-shape overlay rows do not acquire invented DISPIDs,
parameter modes, types, defaults, or runtime behavior. Runtime and behavioral
claims require their own oracle or test evidence.

Every input schema discriminator is checked exactly. Numeric schema versions
must be integer `1` rather than a truthy or string substitute. The older
MS-OFORMS pack uses its versioned schema identifier directly in the
`schema_version` field and is checked against that exact string.

## 2. Stable identities and row separation

The canonical type-view identity is inherited from the FM20 fact schema:

```text
(library identity, containing type index, primary | dual_interface)
```

A declaration member is identified by its declaring type-view and MEMID, with
all same-MEMID accessors grouped without losing their individual source
indices. A coclass surface row is a separate projection through one exact
implemented-type edge. An event row is a separate projection through one
exact default-source edge. A dual interface, a shared declaration interface,
and a coclass facade are therefore never merged into one vague member row.

Non-dispatch interfaces remain ABI contracts. Each accessor retains its
FUNCDESC source index and vtable offset in addition to its semantic signature;
each type contract retains alignment, instance size, vtable size, and
function/variable/implementation counts. An accepted ABI-adapter row must
cross-link to the exact declaration and type-layout contracts, and its source
indices and offsets must form the complete ordered interface layout. It is not
compared to an invented VBA Property declaration.

VARDESCs, enum values, host overlay rows, persistence facts, and unexpected
public source declarations have their own row kinds. Their distinct evidence
and exclusion rules remain visible.

## 3. Canonical row contract

Every row has the same common envelope:

- stable `row_id` and `row_kind`;
- `source_authority`, exact internal/external `source_refs`, and declaration
  and facade owner identities where applicable;
- exact public name, MEMID where authoritative, visibility flags,
  disposition, and disposition basis;
- a kind-specific canonical `contract`;
- the matched extracted `actual` declaration or an explicit absence/nonclaim;
- all thirteen conformance dimensions; and
- a derived `row_status`.

The thirteen dimensions are `type_or_declaration`, `bind`, `method`, `get`,
`put`, `putref`, `default_binding`, `error_coercion`, `event`, `render`,
`persistence`, `oracle`, and `tests`. A dimension uses exactly one status:

| Status | Meaning |
|---|---|
| `verified` | The cited evidence decisively satisfies this exact dimension |
| `implemented_unverified` | A compatible implementation shape exists, but decisive proof is absent |
| `partial` | Some required shape/evidence exists but differs, is ambiguous, or is incomplete |
| `missing` | The required implementation or proof is absent |
| `blocked` | A precise external blocker prevents the proof; this is still gating |
| `excluded_authoritative` | An authoritative rule excludes this dimension from the callable facade |
| `not_applicable` | This dimension has no meaning for this row kind |

Every dimension carries a nonempty basis. A verified dimension must have a
concrete evidence reference. `missing`, `partial`, `implemented_unverified`,
and `blocked` are gating. Unexpected public types/members have the distinct
row status `unexpected_public`; they cannot be made green by adding an
unrelated canonical row.

The root `green` value is derived only from rows and is false whenever a gating
dimension or unexpected-public row remains. Summaries never feed back into row
status.

## 4. Signature and VBA-source comparison

Canonical signatures retain the raw function source index, vtable offset,
MEMID, documentation/GetNames names, invocation kind, function kind, calling
convention, flags, optional-parameter count, complete parameter and return
typedescs, defaults, SCODE array, and default/_NewEnum identity. Each signature
has its own structural digest.

Source lowering is deliberately fail-closed:

- parameter and return counts/types and array shape are symmetric checks;
- `ParamArray` is derived only from the canonical `cParamsOpt == -1` rule;
- optionality is derived from exact parameter flags;
- parameter names are compared only when GetNames reported them;
- ByVal/ByRef is compared only when COM flags and array rules encode it
  unambiguously;
- encoded or documented defaults compare exactly, with only an explicitly
  written symbolic-and-numeric form such as `vbModal (1)` admitting those two
  spellings;
- quoted string defaults preserve case and internal whitespace;
- `VB_UserMemId` is checked case-insensitively on every explicit declaration,
  and inline `Default` cannot bless a canonically nondefault member; pinned
  OxVba recognizes only `VB_UserMemId=0` as a default-member marker, so
  arbitrary nonzero DISPIDs and `_NewEnum=-4` remain partial even when their
  source values equal the canonical typelib values; and
- ambiguous owners, wrong module kinds, wrong creatability, unresolved enum
  expressions, `As New`, array/scalar mismatches, and documentation inferences
  remain partial or missing.

Restricted declarations and dual companions are retained but may be excluded
only through their authoritative flags/view rules. Native-pointer signatures
and non-dispatch ABI shapes become explicit adapter obligations rather than
fabricated VBA syntax.

## 5. Extracted implementation surface

`vba_surface.py` parses the basproj and every referenced `.bas`/`.cls` file in
project order. It retains module identity and kind, exposure/creatability
metadata, declarations, variables (including `As New` and array shape),
events, properties, multiline signatures, bracketed names, optional and
ParamArray parameters, Implements clauses, enum constants, UDT fields, member
attributes, and stable source declaration/member ids.

Clean-project exposure is derived from the exact OxVba SDK/project identity and
source-over-basproj module metadata precedence. The exact six `Instancing`
values are retained from the exported class header, with exact basproj
`Instancing` taking precedence when present. `MultiUse`, `SingleUse`, and their
`Global*` variants add creatability after the source-over-basproj
`VB_Creatable` decision; the two `Global*` values also add global-namespace
behavior. Manual loader profiles are
accepted only when the reviewed Rust executable token stream, live
inventory-to-bind/session path, Cargo default target, package identity, and
root-workspace membership all agree. The root baseline and every direct
`oxvba-*` loader dependency must retain the reviewed OxVba repository and
revision, with no root Cargo patch/replace override, repo-local Cargo config,
package feature table, target-specific dependency table, or alternate OxVba
build/dev dependency path. Explicit source `VB_Exposed` governs
class exposure and `VB_Creatable` overrides forced creatability; procedural
modules remain exported unless `Option Private Module`, which prevents
cross-project exposure for either kind. Comments, string literals,
dead functions, cfg gates, shadowed manifests/programs, alternate targets, and
policy prose cannot assert an effective loader surface.

Every extracted public declaration must be consumed by exactly one accepted
canonical match or emitted as an unexpected-public row. Enum/UDT members are
matched individually; an unresolved enum expression poisons later implicit
values until a new numeric anchor is found.

## 6. Persistence rows and nonclaims

The ledger preserves every reviewed MS-OFORMS leaf and every reviewed
`.frm`/`.frx` fact as an addressable row, plus the 98 property joins and 245
property/family applicability joins used by later implementation work.
Aggregates are derived convenience rows only.

These rows do not claim a production parser, serializer, codec, decoded live
FRX property, runtime constructor default, callable member, or round trip.
Unknown/reserved/ignored and profile-specific observations stay explicit.
Later behavior can become verified only when the corresponding row cites a
decisive implementation test or oracle.

## 7. Owner and logical-family summaries

`owner_families` groups rows by their exact facade-owner identity and never
merges different coclasses or type views. `families` is a reviewed logical
rollup for execution planning; for example, the FM20 UserForm identity, the
host overlay, and the Form persistence family can appear together. Both
summaries contain row-derived counts plus deterministic owner/facade identity
sets; the rows remain the sole detailed inventory. Neither summary can
override, exclude, or green a row.

## 8. Reproducibility and CLI trust

The committed artifact is deterministic UTF-8 JSON with LF endings,
schema/insertion-ordered object keys, two-space indentation, and one terminal
newline. Its
`canonical_sha256` covers the semantic `inputs`, extracted source-surface
digest, rows, and summary. The file byte hash is recorded separately in the
evidence README and checksum file.

`pinned_inputs.v1.json` independently pins every ledger input, generator,
parser, CLI, test, evidence wrapper, both Rust loader sources, the production
adapter manifest/module/runtime handoff, root/crate Cargo manifests, and every
VBA module used by dynamic extraction. UTF-8 text hashes use
canonical LF normalization; binary inputs would use raw bytes. The pin
dependency closure is recomputed from the current basproj extraction, so a
newly referenced module cannot evade review.

`expected_ledger.v1.json` independently freezes the reviewed row counts,
status counts, source-surface digest, input digest, and canonical digest. The
strict cache key includes the raw pin and expected-manifest hashes, every
current pinned-file hash, and a fresh extracted-source digest; file timestamps
cannot authorize a stale result.

The exporter writes only the literal reviewed artifact path, uses atomic
replacement, and refuses path redirection. The validator always checks that
canonical artifact first. An optional additional ledger is diagnostic only
and cannot bypass a missing or corrupt canonical artifact.

## 9. Closure boundary and successors

`oxforms-jbjp.4` closes when this raw-contract/current-overlay inventory is
complete, reproducible, internally cross-linked, adversarially tested, and
truthfully red. It does not close W010 parity.

- `oxforms-jbjp.5` owns generalized live property/method oracle capture.
- `oxforms-jbjp.6` owns FM20 `Control`/`IControl` container-site composition,
  per-concrete-control extended-member projections, generic
  Enter/Exit/BeforeUpdate/AfterUpdate applicability, and the final
  UserForm/host overlay expansion.
- Later implementation beads own callable behavior, errors/coercions, native
  events, rendering, and persistence/round-trip proof.

The current ledger must therefore remain red until those row-level obligations
are genuinely implemented and verified. A precise blocker or nonclaim is
valuable evidence, but it is never completed parity.

## 10. Verification

The focused checks are:

```powershell
python -B -m unittest discover -s tools/msforms-parity/tests -p 'test_*.py'
python -B tools/msforms-parity/export_parity_ledger.py --check
python -B tools/msforms-parity/validate_parity_ledger.py
pwsh -File tools/evidence/Test-W010MSFormsParityLedger.ps1
```

Repository closure additionally requires Rust format, clippy with warnings
denied, workspace tests, the full evidence runner, diff/path/link hygiene, and
bead graph checks. Mutation tests cover coherent row rewrites, authority
substitution, signature and default drift, loader/comment/dataflow laundering,
ABI slot drift, schema/version drift, enum and type-identity ambiguity,
unexpected-public suppression, alternate-artifact bypass, and stale-cache or
hard-link overwrite attempts.
