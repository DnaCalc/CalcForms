# oxforms-jbjp.4 — Generated MSForms parity ledger

Status: deterministic raw-contract/current-overlay inventory complete and
truthfully red; final verification and post-review commit are recorded by the
owning bead

This bead turns the pinned W010 declaration and persistence baselines plus the
current public host overlay and extracted OxForms VBA surface into one
row-addressable execution contract. It changes no production VBA or Rust
behavior. The schema, authority rules, status semantics, and nonclaims are in
[`../../../../specs/MSFORMS_OBJECT_MODEL_PARITY.md`](../../../../specs/MSFORMS_OBJECT_MODEL_PARITY.md).

## Artifacts

| Artifact | Purpose |
|---|---|
| `msforms_parity_ledger.v1.json` | Canonical 7,753-row ledger (`oxforms.msforms_parity_ledger.v1`) |
| [`../../../../../tools/msforms-parity/expected_ledger.v1.json`](../../../../../tools/msforms-parity/expected_ledger.v1.json) | Independently reviewed output census and semantic digest |
| [`../../../../../tools/msforms-parity/pinned_inputs.v1.json`](../../../../../tools/msforms-parity/pinned_inputs.v1.json) | Complete input/generator/parser/test/source dependency pin set |
| `checksums.sha256` | Byte hashes for the committed artifact and this README |

The canonical semantic digest is
`2a63c8acebe038adec22273ecf6dde00d5a60b123ad88289a62629c1553c07c5`.
The canonical extracted-source-surface digest is
`6566f30de60a399131ebe9549f51bb9667054aff1488c79d192d7fa297c3e6f5`;
the ordered ledger-input digest is
`5ab145dcf6529158b4a855bab91b0bc1db46f67fd0c0f13962b59c662ca42eaf`.
The checksum file records the separately computed artifact byte hash.

## Exact output census

| Result | Count |
|---|---:|
| Total rows | 7,753 |
| Verified rows | 2,452 |
| Gap rows | 4,682 |
| Unexpected-public rows | 619 |
| Gating dimension cells | 20,046 |
| Exact owner rollups | 387 |
| Reviewed logical-family rollups | 191 |
| Root `green` | `false` |

The row-kind census is:

| Row kind | Count | Row kind | Count |
|---|---:|---|---:|
| `type_contract` | 220 | `declaration_member` | 1,849 |
| `declaration_variable` | 30 | `enum_value` | 191 |
| `surface_member` | 1,794 | `abi_adapter_member` | 14 |
| `event_projection` | 380 | `host_event_attachment` | 10 |
| `overlay_type` | 1 | `overlay_global_binding` | 1 |
| `overlay_capability` | 1 | `overlay_member` | 21 |
| `overlay_event` | 6 | `persistence_property` | 98 |
| `persistence_family_property` | 245 | `persistence_ms_oforms_fact` | 1,431 |
| `persistence_frm_frx_fact` | 823 | `persistence_aggregate` | 19 |
| `unexpected_public_type` | 12 | `unexpected_public_member` | 583 |
| `unexpected_public_nested_member` | 24 |  |  |

These counts are strict retention floors, not progress targets. A coherent
same-count substitution still fails the expected digest and independent input
pins.

## Joined authority surfaces

The ledger consumes and cross-links:

- all 220 FM20/stdole type views, 2,832 FUNCDESC occurrences, 221 VARDESCs,
  216 implementation edges, enum values, flags, aliases, dual companions, and
  referenced-type closure from `oxforms-jbjp.2`;
- the exact 376-row W005 event metadata reconciliation, leaving only the four
  separately retained SpinButton/SpinButton2 SpinUp/SpinDown rows outside that
  legacy subset;
- all 1,431 selected MS-OFORMS leaf facts, 823 `.frm`/`.frx` leaf facts, 98
  property joins, 245 property/family joins, and nineteen non-gating
  persistence aggregates from `oxforms-jbjp.3` and `.43`;
- the explicit official-documentation overlay for the intrinsic global
  `UserForms` binding/collection and UserForm host members/events; and
- all 37 basproj modules, 832 public declarations, 114 public events, 25 enum
  constants, nine UDT fields, and the clean/manual exposure profiles extracted
  from the current repository.

Exact declaration contracts remain separate from coclass/event projections.
Restricted members, dual companions, stdole dependencies, hidden/versioned
identities, persistence unknowns, and documentation inferences stay present;
they are classified rather than discarded.

## Fail-closed comparisons

The generator and adversarial suite establish the following boundaries:

- type identity includes class/standard-module kind and effective creatability
  for each live loader profile; explicit `VB_Exposed` governs class exposure,
  procedural modules remain exported unless `Option Private Module`, explicit
  `VB_Creatable` overrides manifest or forced-loader defaults, and exact
  basproj `Instancing` overrides exported-class-header `Instancing`; recognized
  `MultiUse`/`SingleUse`/`Global*` values add clean-profile creatability and
  `Global*` values add global-namespace behavior, while ambiguous same-name
  declarations remain red;
- signatures compare symmetric array shape, ParamArray, optionality,
  authoritative parameter names, unambiguous passing mode, return type, and
  exact encoded/documented defaults;
- `VB_UserMemId` and canonical default/_NewEnum identity are checked on every
  explicit member; pinned OxVba recognizes only `VB_UserMemId=0`, so matching
  arbitrary nonzero DISPIDs and `_NewEnum=-4` stay partial;
- unresolved enum expressions cannot leak a stale implicit value into later
  constants;
- the intrinsic `UserForms` binding must be one scalar, non-`As New`, public
  standard-module variable rather than a same-name class or array;
- overlay inference never satisfies an exact source-shape check; in particular,
  undocumented Item/Add parameter/return details remain unresolved;
- every raw FUNCDESC signature exposes its source index and vtable offset, and
  the fourteen hidden non-dispatch IFont adapter rows cross-link all 22 ordered
  slots (`24` through `192`) to the exact 200-byte interface vtable layout;
- the exact basproj SDK, library/project identity, unconditional item shape,
  unnamespaced exact XML lexical subset, raw exported-class header,
  UTF-8/no-lone-CR VBA text, physical Attribute/default-member spelling,
  supported `Option Private Module` and `Def*` boundaries,
  public-by-default `Declare`, and absence of conditional compilation are
  fail-closed;
- every input/internal manifest schema and numeric schema version is exact and
  Boolean-as-integer laundering is rejected; and
- every public source declaration is consumed once or emitted as an
  unexpected-public row.

Manual Rust loader exposure cannot be asserted by policy prose or textual
coincidence. The validator tokenizes comments and literals safely, requires the
reviewed live inventory-to-bind/session path and complete executable token
identity, reconciles tuple names/kinds/paths with parsed `VB_Name` identity,
and proves the reviewed files remain the default targets of explicitly named
workspace-member crates. The root baseline and every direct loader `oxvba-*`
dependency must retain the exact reviewed repository/revision, and root Cargo
patch/replace overrides, repo-local Cargo config, package features,
target-specific dependency paths, and alternate OxVba build/dev dependencies
are rejected. Default-run/build-script redirects and renamed dependency aliases
are also rejected. The production adapter path, manifest, public module, and
complete runtime token stream are pinned through the `OxRuntime` attach/session
handoff. The same live attributes binding must flow through
`module_unit`/`unit`; source attributes, module kind, and `Option Private
Module` are then applied with OxVba's actual precedence.

## Strict artifact trust

The exporter can write only this literal reviewed artifact path and uses an
atomic replacement, preventing arbitrary-path or hard-link overwrite. The
validator always validates this canonical artifact before any optional
additional ledger; an alternate file cannot bypass a missing or corrupt
canonical artifact.

The pin manifest covers the nineteen semantic ledger inputs, all dynamically
extracted VBA modules, both Rust loader sources, the root and two loader Cargo
manifests, the production adapter manifest plus `lib.rs`/`runtime.rs`,
generator/parser/CLI code, expected manifest, adversarial tests, and evidence
wrappers. Its dependency
closure is recomputed from a fresh basproj extraction. The strict cache key is
content-derived from the raw pin and expected manifests, every current pinned
hash, and that fresh source digest; timestamps cannot preserve a stale pass.

## Truthful red boundary

This artifact is deliberately not green. Its 4,682 gap rows and 619
unexpected-public rows are the execution inventory for successors, not a
failure to complete this infrastructure bead. No summary is allowed to hide
them.

This bead makes no claim of:

- generalized live property/method oracle coverage (`oxforms-jbjp.5`);
- FM20 `Control`/`IControl` extended-control aggregation on each concrete
  intrinsic family, generic Enter/Exit/BeforeUpdate/AfterUpdate applicability,
  or the final host/UserForm projection (`oxforms-jbjp.6`);
- complete callable behavior, error/coercion parity, native event semantics,
  rendering parity, or persistence round trips; or
- a production parser, serializer, resource codec, or decoded live FRX
  property value.

Those claims remain row-level successor work. A blocker remains gating and an
authoritative exclusion remains visible.

## Regeneration and validation

From the repository root:

```powershell
python -B -m unittest discover -s tools/msforms-parity/tests -p 'test_*.py'
python -B tools/msforms-parity/export_parity_ledger.py --check
python -B tools/msforms-parity/validate_parity_ledger.py
pwsh -File tools/evidence/Test-W010MSFormsParityLedger.ps1
pwsh -File tools/Run-EvidenceChecks.ps1
```

The owner also ran `cargo fmt --check`, workspace clippy with warnings denied,
workspace tests with a sufficient timeout, `git diff --check`, path/link
inspection, `br dep cycles`, `br ready --json`, `br list --json`, and
`br sync --flush-only` before the post-review commit.

## Fresh-eyes review

The required fresh-eyes pass challenged the ledger as an adversary rather than
accepting matching counts. Issues found and reworked included signature
array/passing/default/name fidelity; default-member attributes; enum poisoning;
global-binding laundering; type kind/creatability; overlay inferences and
authority precision; row-derived family summaries; strict cache and CLI path
trust; pin dependency closure; dead/commented Rust loader evidence; exact
non-dispatch vtable slots/layout; and fail-closed schema versions.

After each repair, focused mutation tests were added and the live tree was
reviewed again. The regenerated artifact, full adversarial verification floor,
and last independent closure review all passed. That final review found no
remaining blunders, mistakes, errors, oversights, omissions, logical issues,
problems, misconceptions, confusion, or bugs in this bead's scoped work.
