# Member-oracle closure verification, 2026-09-21

Bead: `oxforms-jbjp.5`.

Reviewed implementation and canonical capture: commit `00b81f9`.
The implementation and evidence README were already committed, but the live
bead still had status `in_progress`. This check reconciles that status only
after replay, repository verification, and a fresh-eyes review.

The live observation remains the preserved 2026-08-24 capture at
[`captures/W010RepresentativeMemberOracleV1/`](captures/W010RepresentativeMemberOracleV1/).
This verification replays that capture without starting Office; it is not a
new observation against the currently installed Office version. No captured
artifact, fixture expectation, source pin, or production behavior was changed.

## Verification

Environment: Windows, Python 3.12.10, PowerShell 7.6.5, rustc 1.94.1,
Cargo 1.94.1.

| Check | Result |
|---|---|
| `pwsh -NoProfile -File tools/evidence/Test-W010MSFormsMemberOracle.ps1 -RequireCurrentLedgerSnapshot` | Passed: adversarial tests, exact current-ledger slice, manifest, output-path policy, process watchdog/containment, runner syntax and no-Excel dry run, canonical replay, and all 27 checksum entries. |
| `cargo fmt --check` | Passed. |
| `cargo clippy --workspace --all-targets -- -D warnings` | Passed. |
| `cargo test --workspace` | Passed: 181 tests, zero failures, seven pre-existing ignored performance/evidence generators; 22 test/doc-test summaries. |
| `pwsh -NoProfile -File tools/Run-EvidenceChecks.ps1` | Passed: 41/41 checks, including all committed checksum manifests. |
| Local Markdown links in the bead/evidence/fixture READMEs, focused parity spec, and this report | Passed; no broken paths. |
| `git diff --check` | Passed. |
| `br dep cycles` | No dependency cycles. |
| `br ready --json` and `br list --json --limit 0` | Before closure: no ready bead; `.5` is the sole in-progress bead, and `.6` depends on it. |

## Fresh-eyes review

- Compared the acceptance criteria with the manifest, generated direct VBA,
  preserved result/event rows, capture log, and replay rules. The batch covers
  five control families, ten successful member results, one exact error, and
  two events. Optional arguments, indexed/default access, scalar coercion,
  error details, and mutable `ReturnBoolean.Value` are represented.
- Inspected the preserved PNG. The complete titled UserForm is visible with
  the expected label caption, TextBox value, `head`/`tail` list order, checked
  CheckBox, and focus-target button; no dialog or other window covers the
  fixture. This is a visual check of the recorded screenshot, not a new live
  capture or a claim of OxForms rendering parity.
- Reviewed event recording and teardown: generated handlers check the
  recording flag before mutation, teardown disables it, and replay binds each
  event to the correct trigger window and exact before/after arguments.
- Reviewed the capture/replay handoff and existing adversarial coverage:
  exact generated source, retained checksum-bound bytes, workbook/JSON table
  agreement, FRM/FRX ownership, validator pins, process identity, expected
  shutdown, and cleanup failures. The process tests exercised disposable
  processes without starting Excel.
- Checked the architecture boundary: the oracle remains under tools,
  fixtures, and evidence. A search of production `crates/` and `vba/` found
  no references to the member-oracle engine, runner, or representative capture.
  No temporary bridge or scaffold became a production dependency.
- Confirmed that incomplete COM-add-in inventory, persisted control-graph
  semantics, compiled-cache execution equivalence, and broader value/control
  support remain explicit limitations. Existing bead `oxforms-jbjp.67` owns
  control-graph and compiled-cache validation; `.6` owns control-site and
  host-event applicability. No new out-of-scope work was identified.

The review found no additional defect within `.5`'s representative-harness
scope. All required repository checks passed; the representative-harness
acceptance criteria are satisfied.

## Handoff

Verification was committed as `5b70696` before `br close oxforms-jbjp.5`.
The bead is now closed; its reason records the decisive replay and repository
checks. The canonical capture and production implementation remain unchanged.
`br sync --flush-only` is clean, the graph remains acyclic, and `br ready`
now lists `.6`. Comparing the exported bead records confirms that only `.5`
changed. The final closure-document scan checked 29 local links without a
broken path.

The handoff stops at the requested stock-take. `.6` remains open and untouched;
starting it requires the user's explicit resumption after that checkpoint.
