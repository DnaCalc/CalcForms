# OxForms Workset Register

Worksets are coarse planned pushes. Live execution truth is in `.beads/` through
`br`; this register is the roadmap and history.

Status values: `OPEN`, `IN PROGRESS`, `CLOSED`, `BLOCKED`.

| ID | Title | Status | Epic bead | Depends on | Purpose | Spec sections | Closure condition | Initial lanes | Verification |
|---|---|---|---|---|---|---|---|---|---|
| `W001_repo_bootstrap` | Repository bootstrap and first spec import | `IN PROGRESS` | `oxforms-rzk` | none | Create the standalone OxForms repo with root doctrine, bead store, workset register, and the first spec document imported from OxVba planning. | `docs/SPEC.md`, `docs/FORMS_LIBRARY_SPEC_AND_PLAN.md`, `docs/SOURCE_REFERENCES.md` | Root docs exist; `.beads/` initialized; W001 epic and bootstrap child bead exist; spec paths are adjusted for the standalone repo; Foundation MS-OFORMS and OxVba baseline pointers are explicit. | docs/doctrine seed; spec import; source-reference baseline; bead initialization | read-through; path/link scan; `git diff --check`; `br ready --json`; `br dep cycles` |
| `W002_initial_windows_rectangle` | Initial Windows PAL rectangle smoke | `OPEN` | `oxforms-dwm` | `W001_repo_bootstrap` | Prove the first executable OxForms vertical slice: VBA emits a minimal display-list command, Rust PAL renders a rectangle headlessly, and a Windows visible smoke path paints the same command. | `docs/worksets/W002_initial_windows_rectangle.md`, `docs/FORMS_LIBRARY_SPEC_AND_PLAN.md`, `docs/SOURCE_REFERENCES.md` | Rust headless renderer has a stable rectangle diagnostic/hash; OxVba-driven VBA smoke reaches the PAL seam with the same rectangle command; Windows visible smoke exists or has a concrete blocker bead; evidence and fresh-eyes review are recorded. | workset plan; workspace scaffold; display-list/headless renderer; OxVba VBA smoke; Windows visible smoke; evidence/review | read-through; path/link scan; `cargo fmt --check`; `cargo clippy --workspace -- -D warnings`; `cargo test --workspace`; targeted rectangle smoke; `br dep cycles`; `br ready --json` |
