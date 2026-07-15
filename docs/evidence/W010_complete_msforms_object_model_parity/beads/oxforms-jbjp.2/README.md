# `oxforms-jbjp.2` — exhaustive FM20/referenced-typelib facts

Status: capture and validation complete

This bead establishes W010's public COM metadata baseline. It does not claim
that the captured members, defaults, runtime behavior, rendering, or
persistence are already implemented by OxForms.

## Reviewed inputs

- FM20: 1,763,584-byte `FM20.DLL`, file version `16.0.20131.20012`, SHA-256
  `2c0e732b0e794451659ab0ff4e8489a518dde18a396201ace10bd3409acf90fe`.
- stdole: 28,672-byte `stdole2.tlb`, version `10.0.26100.1`, SHA-256
  `815d6c50ad934a42800e52faef5207dd9352ab8c386793422682084c8f604c5d`.
- Capture runtime: 64-bit Python `3.12.10`, pywin32 `309`, platform
  `Windows-11-10.0.26200-SP0`.
- Legacy W005 event artifact: 1,009,564 CRLF bytes, SHA-256
  `3542ff0f264ea87d6100bf4e3da815b5893cc4f6080a61e03572b0879f01f2e5`.

The independent pins are
[`pinned_typelibs.v1.json`](../../../../../tools/fm20/pinned_typelibs.v1.json),
[`pinned_w005_baseline.v1.json`](../../../../../tools/fm20/pinned_w005_baseline.v1.json),
and
[`expected_capture.v1.json`](../../../../../tools/fm20/expected_capture.v1.json).

## Generated artifacts

| Artifact | Result | SHA-256 |
|---|---|---|
| [`fm20_typelib_facts.v1.json`](fm20_typelib_facts.v1.json) | schema `oxforms.fm20_typelib_facts.v1`; 220 type views; canonical semantic digest `b10c9ef2b21769e9a2d6802297409dde231faab2355a9cf613c7c4a3b0a38b77` | `ff2abf8e3813e207e34f12c6f614070bc67cfd5e70ac7348bcd5ef275bd5582e` |
| [`w005_event_reconciliation.v1.json`](w005_event_reconciliation.v1.json) | schema `oxforms.fm20_w005_event_reconciliation.v1`; 376 exact stable rows; zero structural deltas | `2aeffe80d000902d194f0b0eef65af55833d11877feea4ca630881ca98fc56a0` |

The fact closure reconciles exactly:

| Scope | Views | Functions | Variables | Implementation edges |
|---|---:|---:|---:|---:|
| FM20 primary | 171 | 1,757 | 199 | 177 |
| FM20 dual companions | 37 | 1,067 | 0 | 37 |
| stdole closure | 12 | 8 | 22 | 2 |
| Total | 220 | 2,832 | 221 | 216 |

It also contains 3,153 parameters and 1,446 resolved reference occurrences.
The external closure is the exact 11-node forward graph plus the public reverse
alias `IPictureDisp`; `Picture` and `IPictureDisp` remain distinct nodes.

## W005 reconciliation

The W005 artifact recorded FM20 SHA-256 `e5085d...`, while the pinned current
binary is `2c0e73...`. Comparison therefore excludes capture-local HREFTYPE,
timestamps, paths, and derived labels while retaining public library/type
identity, interface name/GUID, coclass/source flags, DISPID, INVOKEKIND,
FUNCKIND, CALLCONV, function flags, recursive signatures, parameter names,
flags, and defaults.

The result is `source_binary_changed_structure_same`: 51 attachments, 26 unique
source interfaces, 22 selected event names, 376 rows, and 1,206 arguments all
match; there are no unexplained deltas. None of the six checked UserForm host
lifecycle names appears in FM20 source interfaces, which is not evidence
against the separately documented host overlay.

## Verification

| Check | Result |
|---|---|
| Python compile and 10 corruption/provenance unit tests | passed |
| Standard-library-only committed validation (`python -S`) | passed |
| Exact live source/runtime pin validation | passed |
| Two clean regenerations plus committed byte comparison | passed |
| `cargo fmt --check` | passed |
| workspace/all-target clippy with warnings denied | passed |
| `cargo test --workspace` | passed in 252.3 seconds |
| repository evidence validators | 33/33 passed, including this directory's tracked checksum coverage |
| `git diff --check` and changed-document link scan | passed; only expected checkout line-ending notices |
| bead graph/list/ready/sync checks | no cycles; `.2` remained the sole in-progress strict-sequence bead before closure |

Primary commands:

```powershell
python -m unittest discover -s tools/fm20/tests -p 'test_*.py'
python -S tools/fm20/validate_typelib_facts.py
pwsh -File tools/evidence/Test-W010FM20TypeLibFacts.ps1 -RequireSource
pwsh -File tools/Run-EvidenceChecks.ps1
```

## Fresh-eyes review and rework

Independent adversarial review found and the bead corrected substantive first
passes rather than accepting them as evidence:

- all 37 FM20 dual-interface companion views are retained separately;
- complete static OLE flag tables preserve high function bits and unknown-bit
  failure, including legitimate ordinary/source defaults;
- the 12-node stdole closure includes the reverse `IPictureDisp` alias and is
  traversed from the independently hashed registered file;
- raw descriptors, stable inline identities, reference multisets, derived
  maps/names/counts, enums, optional/default states, and exact recursive keys
  are cross-validated rather than trusted;
- a reviewed semantic pin catches coherently rewritten member rows;
- the W005 interface name and artifact/schema/event-set identity are compared,
  not only its source GUID;
- missing pywin32 DLL-entry/MOPS adapters have explicit unavailable states;
- the capture runtime, generator provenance, two-library boundary, and
  cross-platform line-ending rules are pinned; and
- custom evidence paths are forwarded consistently through live regeneration.

The detailed schema, adapter limitations, closure rule, and validation contract
are in
[`FM20_TYPELIB_FACT_SCHEMA.md`](../../../../specs/FM20_TYPELIB_FACT_SCHEMA.md).
