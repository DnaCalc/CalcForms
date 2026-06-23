# OxForms Operations

How we work in this repo. The process is intentionally light: keep the spec clear,
partition larger pushes with worksets, and execute real work through `br` beads.

## 1. Precedence
When guidance conflicts, authority flows in this order:

1. `CHARTER.md` - mission, values, and scope.
2. `docs/SPEC.md` - spec/design/planning index.
3. `OPERATIONS.md` - this working doctrine.
4. `docs/WORKSET_REGISTER.md` - coarse W### roadmap.
5. `.beads/` via `br` - live atomic execution truth.
6. Evidence, handovers, and supporting docs.

Foundation doctrine and sibling repo specs are important context, but they are
read-only from this repo unless a coordinated handover says otherwise.

## 2. Planning Surfaces

```
CHARTER -> Spec -> Worksets -> Beads -> Evidence
              ^        |          |
              |        |          v
          Handovers <- + ---- discovered work
```

- The **Spec** says what we are building and why.
- **Worksets** (`W###`) are large planned pushes and roadmap history.
- **Beads** are atomic reviewed execution units managed by `br`.
- **Handovers** coordinate requests to sibling repos.
- **Evidence** anchors compatibility, performance, trace/replay, and oracle claims.

## 3. The Spec
The spec document set is indexed by `docs/SPEC.md`.

The first spec document is `docs/FORMS_LIBRARY_SPEC_AND_PLAN.md`. As the project
grows, split detailed surfaces into smaller docs and keep them reachable from the
index.

The spec should be:

- clear enough for a fresh agent to implement from it;
- specific enough to generate checks, traces, examples, or evidence rows;
- honest about unsupported, partial, or host-specific subsets;
- explicit about any temporary scaffold and what deletes, replaces, or quarantines
  it before later implementation treats it as a pattern;
- updated in the same bead as behavior changes.

## 4. Worksets
Worksets are large planned work areas. They live in
`docs/WORKSET_REGISTER.md`.

Naming: `W###_short_name`, for example `W001_repo_bootstrap`.

Each workset entry should include:

- ID and title;
- status: `OPEN`, `IN PROGRESS`, `CLOSED`, or `BLOCKED`;
- depends-on list;
- purpose;
- linked spec sections;
- closure condition;
- initial epic lanes;
- verification shape;
- matching epic bead ID once `.beads/` exists.

The register is a coarse scan, not the execution board. Once beads exist, trust
`br ready --json`, `br list --json`, and `br show <id> --json` for live work.

Adding a non-bootstrap workset normally means creating its epic bead in the same
change. If a workset needs discovery before child beads are obvious, create a
rollout bead under the epic.

## 5. Beads
Beads are the atomic unit of execution and are managed only with `br`.

Agents must not hand-edit `.beads/`. Use non-interactive `br` commands and prefer
`--json` for inspection.

Every executable bead should state:

- one reviewable outcome;
- the smallest useful acceptance check;
- parent epic/workset;
- dependencies;
- touched truth surfaces;
- whether it introduces temporary scaffolding, and the condition under which that
  scaffolding is deleted, replaced, or quarantined as non-pattern test infrastructure;
- residual or blocker behavior if completion is not possible.

### Bead Loop
For each bead:

1. Pick a ready bead: `br ready --json`.
2. Inspect it: `br show <id> --json`.
3. Mark it in progress: `br update <id> --status in_progress --json`.
4. Do the work, keeping edits scoped.
5. Update touched spec/workset/evidence docs.
6. Run relevant checks.
7. Fresh-eyes review: reread, rerun, or use the changed surface as if new and
   actively look for mistakes, omissions, bad assumptions, regressions, and bugs.
   Include an explicit check that temporary bridges, shims, and scaffolds have not
   become implicit architecture.
8. File discovered out-of-scope work as beads before closing.
9. Sync bead state: `br sync --flush-only`.
10. Commit the code/docs/evidence/bead state.
11. Close the bead only when the outcome and acceptance check are satisfied.

Close reasons should name the decisive check or observation, not a ritual
checklist.

## 6. Bead And Workset Semantics
Use precise completion language:

- `implemented` means the scoped behavior is actually implemented for the stated
  parity target.
- `implemented-subset` means only a named subset is implemented.
- `closed` means the work item is complete for its stated scope and required
  checks/evidence are satisfied.
- If remaining accepted scope exists, status remains `in-progress` or a new bead
  captures the residual work.

Support beads can prepare, clarify, or repair a capability lane. A capability lane
closes only when delivery beads have changed or proven the behavior and the
required evidence exists.

## 7. Verification
Run checks appropriate to the touched surface.

Normal floors as they become available:

| Surface | Check |
|---|---|
| Rust crates | `cargo fmt --check`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo test --workspace` |
| VBA library fixtures | OxVba compile/run fixture or targeted harness |
| Rendering | display-list golden, headless render hash/screenshot, or visual diff |
| MSForms behavior | generated fact row plus Office/MSForms oracle where available |
| Evidence artifacts | `pwsh -File tools/Run-EvidenceChecks.ps1` (headless: checksum manifests, trace/replay schema, comparison manifests); per-capture `Test-W0xx*CaptureEvidence.ps1` for live captures |
| Excel RefEdit | non-Excel capability-diagnostic test, synthetic range-selection replay, optional live Excel differential |
| Docs/doctrine | careful read-through, link/path scan, `br` sanity check |

Compatibility claims require reproducible evidence: public spec references,
generated fact rows, harness output, trace/replay artifacts, or black-box Office
observation. Do not use broad prose as the only source of truth for parity.

## 8. Handovers
Use handovers for cross-repo requests. Do not edit sibling repos from this repo.

Handovers live in `docs/handovers/` and are named:

`HANDOVER_<TARGET>_<short_topic>.md`

Keep the format short:

```
Status: Open
Target: <repo>
Ask: <one sentence>
Context: <why this matters>
Evidence: <links / repro / spec section, if useful>
```

Responses are appended to the same file.

## 9. Housekeeping
At workset close, bring touched artifacts to a known state:

- keep and place live docs/code where they belong;
- mark parked or partially superseded artifacts with a short status;
- delete genuinely dead or superseded artifacts.

Reconcile the workset register with the bead epic graph: every active workset
should have a matching epic bead, and obvious status drift should be repaired.

## 10. Git Discipline
Keep commits scoped to one bead or a small coherent set of related docs during
bootstrap. Commit messages should mention the bead ID once beads exist.

`br` never commits for you. After bead mutations, run:

```
br sync --flush-only
git add .beads/ <changed-files>
git commit -m "<message> (<bead-id>)"
```

Do not skip real checks to close a bead. If a check is wrong, fix or track the
check.
