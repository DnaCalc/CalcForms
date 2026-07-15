# oxforms-jbjp.3 — MS-OFORMS Persistence/Default Fact Pack

Status: generated, validated, and independently fresh-eyes reviewed

This bead establishes the documented binary-persistence/default baseline for
later W010 parser, resource, serializer, control, and corpus work. It changes no
production VBA or Rust behavior.

## Artifacts

| Artifact | Purpose | Bytes | SHA-256 |
|---|---|---:|---|
| `ms_oforms_persistence_facts.v1.json` | Lossless selected source rows plus normalized persistence/default facts | 6,376,798 | `74166611287b072434013056e00cecf811f361e2c0a26b740074a39a0c3249cb` |
| `checksums.sha256` | Git-tracked evidence coverage and byte-integrity manifest | — | self-excluded by convention |

The fact schema and non-claims are in
[`../../../../specs/MSFORMS_PERSISTENCE_MODEL.md`](../../../../specs/MSFORMS_PERSISTENCE_MODEL.md).
Generator, pins, reviewed semantic digest, validator, and mutation tests are in
[`../../../../../tools/ms-oforms/`](../../../../../tools/ms-oforms/).

## Source identity and selection

- Standard: MS-OFORMS 9.1, 2025-08-19.
- Foundation commit:
  `e6cfe71cfa1ebf07f52d1c7816a637ad5baad78b`.
- Authoritative DOCX SHA-256:
  `7bbbbdc43407524fe2af99c070dfc358cc67404e5224b56d5cdabbc4736c9158`.
- Authoritative PDF SHA-256:
  `37e72c8605244ebd28c2f247f9605d858fb44c194f835867d8b9ecedcb744db4`.
- Canonical-LF normalized segment SHA-256:
  `94639c4bee6f20ef59a904254c640bbe1666cedd0019708891e45b485a314e84`.
- Pin-manifest SHA-256:
  `32d4af439d67d67941f65d118b7a79d3450922224b28c09d5590a88b4a7ddc47`.
- Reviewed semantic SHA-256:
  `5c488d039273bd1aaedd465964e17262863e4d9dfb2fdf2f39b6b581efd7ebbf`.

The original Foundation extraction run recorded `git_dirty: true`; the fact
pack preserves that caveat instead of claiming a clean capture. The published
outputs and every selected input/figure are independently pinned at the clean
Foundation commit above. Validation hashes each expected-commit blob and its
separately clean working-tree path with the declared raw/canonical mode.

The exact 8,024-row selected span runs from `Saving Controls` through all
twenty Appendix A product-behavior notes before `Change Tracking`. Its five
evidence classes keep persistence context, normative structures/defaults and
algorithms, examples, security context, and product behavior distinct.

## Exact coverage

| Dimension | Count |
|---|---:|
| Selected source rows | 8,024 |
| Sections | 292 |
| Tables / logical table rows | 161 / 1,226 |
| Control families / visible controls including Page | 11 / 16 |
| Cached control ids | 16 |
| Non-bitfield record fields | 431 |
| Record sections / aggregate requirements | 90 / 37 |
| Property types / resource formats | 18 / 10 |
| Properties | 98 |
| Documented defaults / mandatory-persist no-default | 95 / 3 |
| Typed default-matrix rows | 107 |
| Property-domain tables / rows | 3 / 8 |
| Bitfields / entries / property masks | 28 / 320 / 15 |
| Enumerations / values | 26 / 132 |
| Algorithm contexts / procedures / worked examples | 1 / 3 / 6 |
| Appendix product-behavior rows | 20 |
| Reserved/unused/undefined/ignored rows | 179 |
| Referenced external standards / occurrences | 22 / 103 |
| Runtime API claims / oracle-only rows | 0 / 0 |

The fifteen property masks are exactly fourteen 32-bit masks plus the 64-bit
MorphData mask. The only mandatory-persist/no-default properties are
`DrawBuffer`, `PageCount`, and `Size`.

## Boundaries

- Persistence facts do not prove runtime signatures, visibility, errors,
  coercions, constructor defaults, or events.
- Appendix A remains documented product behavior, not black-box oracle
  evidence.
- Worked structure examples are source vectors, not passing implementation
  tests.
- Referenced MS-OAUT/MS-DTYP/MS-OLEDS/MS-OSHARED/MS-WMF/MS-EMF/MS-OVBA and
  other standards are inventoried as external dependencies, not silently
  treated as captured.
- Canonical `.frm`/`.frx` export facts remain the strict successor bead `.43`;
  parser/serializer/resource implementation belongs to later beads.

## Verification record

| Check | Result |
|---|---|
| Independent fresh-eyes semantic review | passed; no open findings |
| Static committed validator | passed |
| Exact pinned Foundation commit and all source/index/manifest/figure hashes | passed |
| Fresh source capture compared with committed facts | passed |
| Two independent clean regenerations and byte comparison | passed |
| 34 unit/mutation/provenance tests | passed |
| Repository evidence suite | 35/35 passed |
| Rust format / clippy warnings-denied / workspace tests | passed |
| Checksum manifest and changed-document links | passed |
| Diff hygiene and bead graph/list/ready/sync checks | passed |

The static repository pass does not require Foundation. The owning
source-required gate is:

```powershell
pwsh -File tools/evidence/Test-W010MSOFormsFacts.ps1 -RequireSource
```
