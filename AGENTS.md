# AGENTS.md - OxForms

Thin startup instructions for agents working in this repo.

## Start Here
Read in this order:

1. `CHARTER.md`
2. `OPERATIONS.md`
3. `docs/SPEC.md`
4. `docs/WORKSET_REGISTER.md`
5. `br ready --json` and `br list --json` for live execution state

## Repo Boundary
- You may read sibling repos under `..` for context: especially `OxVba`,
  `OxDoc`, `Foundation`, and DNA Calc hosts.
- Do not write outside this repo. Use `docs/handovers/` for cross-repo asks.

## Execution
- Substantive work happens as beads managed by `br`.
- Never hand-edit `.beads/`.
- Update spec/workset/evidence docs in the same bead as behavior changes.
- Run the relevant checks that exist for the touched area.
- Do a fresh-eyes review before closing a bead.
- File newly discovered out-of-scope work as beads before closing the current one.

## Build And Test
The workspace is bootstrapping. Until buildable crates/fixtures exist, use the
useful checks available: read-through, path/link scans, `br` sanity checks, and
spec consistency review.

As code lands, keep this list current:

| Check | Command |
|---|---|
| Rust format | `cargo fmt --check` |
| Rust lint | `cargo clippy --workspace --all-targets -- -D warnings` |
| Rust tests | `cargo test --workspace` |
| Evidence validators | `pwsh -File tools/Run-EvidenceChecks.ps1` |
| Bead graph | `br dep cycles` and `br ready --json` |

Enable the pre-commit hook once per clone so whitespace/EOF and the Rust lint
floor are enforced before commit:

```
git config core.hooksPath .githooks
```

## Safety
- Do not run destructive git or filesystem operations unless explicitly asked.
- Keep changes scoped to the bead in hand.
- Do not weaken or skip checks to make work look complete.
