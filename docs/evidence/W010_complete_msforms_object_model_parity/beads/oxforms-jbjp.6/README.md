# .6 — Exact facade contract and runtime boundary

Status: **BLOCKED; not complete**. Observations dated 2026-09-21 UTC.

The [facade specification](../../../../specs/MSFORMS_FACADE_CONTRACT.md)
records the unchanged-project target, including Microsoft-supplied controls
beyond MSForms and excluding third-party controls. `oxforms-tst7` owns the
additional Microsoft-library inventory. This bead retains the MSForms scope.

## Delivered contract and diagnostics

- `msforms_facade_ledger.v1.json` references the exact immutable `.4` ledger
  rather than changing `.5`'s historical capture input. It maps 183 primary
  type contracts and 3,632 primary member contracts with exact names, owners,
  invocation kinds and signature digests. Dual/ABI identities remain in `.4`.
- There are 2,652 Control-site projections across all 50 FCONTROL coclasses
  plus Page: 357 restricted declarations and 2,295 unresolved applicability
  rows. Native-member collisions preserve both authorities.
- All 51 candidate owners have four generic host-event rows: 204 total,
  ten prior observed attachments and 194 unresolved. Observations grant no
  implementation/event-ordering credit.
- All nineteen named hidden/designer-band members remain accepted pending
  live observations. The discovery generator produces separate get and put
  probes for 38 accessors, plus the eleven existing representative probes.
- Fourteen documented intrinsic ProgIDs are recorded; other construction
  identities remain unresolved rather than inferred from class names.
- The contract specifies a single non-public `OxFormsRuntime.Dispatch` host
  capability. No production runtime shim or additional public API was added.

## Executable outcomes

The Rust fixture uses two distinct VBA projects. It proves qualified MSForms
reference/name binding, explicit members, same-library Friend calls and the
compiler/runtime's distinction between Let and Set with object identity. The
setter fixture is explicitly synthetic and is not an MSForms public type.
It does not prove production reference substitution or full control behavior.
An unqualified referenced `Label` default-member read also succeeds; only the
qualified `MSForms.Label` declaration reproduces D006-01 in this comparison.

Two pinned-OxVba discrepancies prevent acceptance:

| Requirement | Expected | Observed |
|---|---|---|
| Qualified cross-project scalar default member | Omitted Caption reads the String value | Error 13: cannot convert Object to String |
| Internal Friend boundary | Referencing client cannot invoke the member | External call succeeds and returns 107 |

`oxforms-o0fp` owns the [OxVba handover](../../../../handovers/HANDOVER_OxVba_w010_facade_binding.md).
Tests named `discrepancy_*` assert these observed failures. A passing discrepancy
test is not a compatibility pass. The [discrepancy register](DISCREPANCIES.md)
keeps all outstanding proof visible.

## Live Office outcome

The capture was attempted before and after the user resolved normal Excel
startup and closed Excel. The isolated safe-mode process still displayed an
owned `NUIDialog` titled Microsoft Excel with a disabled root window. The
shared `.5` harness refused automation and cleaned up only its owned process.
No live probe macro ran, no workbook reached pre-open verification, and none of
the 38 hidden-accessor observations were obtained.

[Recorded attempts](blocked-capture-attempts.json) preserve the failures.
The [window diagnostic](captures/startup-diagnostic/window-capture-manifest.json)
found the exact owned dialog but could not bring it to the foreground for a
screenshot. UI Automation did not supply a root element in this execution
context, so the dialog text is unknown. Do not infer licensing, crash recovery
or any other particular cause from its generic title.

The durable discovery tooling reuses `.5`'s isolated process lifecycle,
watchdogs, generated result/error/event recording and strict decompressed-source
workbook validator. Generation and old-output regression are tested. Its new
live path still requires a successful capture and review. As with `.5`, it does
not claim persisted-control-graph or compiled-p-code execution equivalence;
those remain `.67` obligations. Output alone never promotes an applicability row.

## Commands

```powershell
python -B tools/msforms-parity/facade_contract.py
pwsh -File tools/evidence/Test-W010MSFormsFacadeContract.ps1
cargo test -p oxforms-oxvba-adapter --test oxvba_w010_facade_contract -- --nocapture
pwsh -File tools/office-oracle/Capture-MSFormsFacadeProbe.ps1 -CaptureName designer-band-20260921
```

The capture requires all user Excel work saved and Excel closed, VBIDE trust,
an English Office UI and an accessible interactive desktop. It preserves failed
staging output and refuses to overwrite an existing promoted capture. Once it
works, run `msforms_facade_probe.py replay <capture-directory>`, review the
source/workbook/results and visible screenshot, and add accessor-specific
acceptance decisions. A failed setter is not automatically an excluded member.

## Review and closure

Fresh-eyes review corrected a mistaken test assumption that TextBox.Value has
putref; its raw contract does not. The shared-accessor shape check now uses
Label.Picture, and the runtime setter mechanism probe has an explicitly
synthetic name. Review also rejected treating a generic binder error as proof
of visibility: the discrepancy now executes the external call and verifies
the actual leak. Historical `.5` generated source remains byte-identical.

No production code, sibling repository or historical `.4`/`.5` artifact was
changed. All additions are durable specification, discovery or test material.
The bead remains blocked until the named live probes and OxVba requirements
are satisfied. Final review also corrected the Event/native-ABI source mappings
and added the successful unqualified reference comparison for D006-01.

## Verification results

| Check | Result |
|---|---|
| `cargo fmt --check` | Passed |
| `cargo clippy --workspace --all-targets -- -D warnings` | Passed |
| `cargo test --workspace` | 186 passed, zero failures; seven pre-existing ignored tests; 23 test/doc summaries |
| Final targeted Rust facade probes | Five passed: three mechanism checks and two confirmed discrepancy observations |
| Facade contract tests | Ten passed, including owner coverage, anti-promotion, exact accessors, Event/ABI mapping and byte-identical `.5` generation |
| `tools/Run-EvidenceChecks.ps1` | 43/43 passed, including `.4`, canonical `.5` replay and `.6` obligations/checksums |
| Local Markdown links and `git diff --check` | Passed |
| Bead dependency cycles / ready / list / sync | No cycles; state read and flushed; `.6` remains blocked |
| Required live hidden-accessor acceptance | **Blocked** before any macro ran |
| Required qualified default-member/internal visibility acceptance | **Blocked**, D006-01 and D006-02 |

The suite's existing ignored tests are performance/evidence-generation runs,
not newly skipped facade acceptance. No failing acceptance test was turned into
a passing conformance claim; the discrepancy tests and blocked rows explicitly
retain the unmet requirements. Logs are local under
`target/oxforms-jbjp.6-verification/` and are not committed evidence artifacts.
