# W006 Control Implementation Rollout

Status: `OPEN`
Epic bead: `oxforms-0a0`
Depends on: `W005_input_interaction_model_exploration`
Planning/review gate bead: `oxforms-0a0.9`

## Purpose

W006 carries the W005 interaction spine into implementation work. It is not a
blanket instruction to build all controls at once. Its first executable step is
to harden this rollout: review W005 outputs, pick the first narrow lanes,
confirm dependency order, and make sure each executable bead has enough scope,
evidence expectations, and review instructions to be safely implemented.

The W006 baseline is the W005 loop:

```text
real or synthetic input
  -> normalized UiEvent
  -> hit-test / focus / capture / keyboard routing
  -> reducer state transition
  -> explicit Effects
  -> OxVba/VBA event dispatch where required
  -> invalidation + display-list update
  -> trace/replay and comparison evidence
```

W006 should turn that spine into real runtime/control surfaces only through
small reviewed beads. Implementation beads depend on the W006 planning/review
gate so they do not start from the broad residual list alone.

## Start Reading

Before changing W006 behavior, read:

- `CHARTER.md` sections 1, 3, 3.1, 4, 5, and 7.
- `OPERATIONS.md` sections 4, 5, 6, 7, and 10.
- `docs/worksets/W005_input_interaction_model_exploration.md`.
- `docs/specs/INPUT_INTERACTION_MODEL.md`.
- `docs/specs/FM20_EVENT_FACTS.md`.
- `docs/specs/COORDINATE_MODEL.md`.
- `docs/specs/LIFECYCLE_PUMP_MODEL.md`.
- `docs/specs/TRACE_REPLAY_SCHEMA.md`.
- W005 evidence under
  `docs/evidence/W005_input_interaction_model_exploration/`, especially the
  modeless and modal MSForms captures, visible input smoke, headless replay
  golden, event dispatch smoke, and comparison artifact.
- `docs/handovers/HANDOVER_OxVba_w005_fm20_event_raise.md` before any native
  FM20 event dispatch work.

## Doctrine And Non-Claims

W006 inherits the charter's VBA-first, evidence-first, clean-room doctrine. It
may promote W005 probe/reference code only after a bead says what is promoted,
what remains test-only, and what must be replaced or deleted.

W006 does not claim:

- full UserForm parity;
- full intrinsic control parity;
- pixel-perfect rendering parity;
- runtime accessibility semantics;
- native FM20-named OxVba event dispatch;
- complete TextBox editing semantics;
- complete IME, clipboard, paste, drag/drop, or `DataObject` behavior;
- complete `.frm` / `.frx` persistence integration;
- a final pass/fail parity oracle.

Each later bead may claim only the subset it implements and proves with the
checks/evidence named in that bead.

## Dependency Shape

`oxforms-0a0` is the W006 epic. Its first ready child is
`oxforms-0a0.9`, the planning/review/rollout-hardening bead.

All executable W006 implementation or design beads depend on
`oxforms-0a0.9`. That gate must:

1. reread W005 closure output and this workset;
2. tighten or split any W006 child that is still too broad for review;
3. confirm each child has start-reading pointers, scoped acceptance criteria,
   relevant doc pointers, and the required fresh-eyes review/rework instruction;
4. confirm dependencies prevent implementation work from starting before the
   plan is coherent;
5. keep W006 open.

After the gate closes, implementation lanes can proceed only in their scoped
beads. Some lanes may still need additional ordering discovered by
`oxforms-0a0.9`; those dependencies should be added before the relevant work
starts.

## Bead Plan

| Bead | Purpose | Depends on | Acceptance Summary |
|---|---|---|---|
| `oxforms-0a0.9` | Review and harden the W006 rollout before implementation starts. | `oxforms-0a0` parent only | W006 doc/register/bead graph are coherent; broad beads are split or tightened; implementation beads are blocked behind the gate; W006 remains open. |
| `oxforms-0a0.8` | Harden W005 interaction harnesses and comparison/oracle validators for future scenarios. | `oxforms-0a0.9` | Harness changes preserve logs, hashes, coordinate tags, source paths, and observation-only comparison posture. |
| `oxforms-0a0.2` | Implement or precisely block native FM20-named event dispatch through OxVba shared machinery. | `oxforms-0a0.9` | Direct event handlers work for a named subset, or exact OxVba blockers/handovers exist; W005 generic carrier stays test-only. |
| `oxforms-0a0.4` | Connect W005 interaction state to canonical `.frm` / `.frx` loading for selected fixtures. | `oxforms-0a0.9` | Fixture inputs produce equivalent logical control trees for selected scenarios; probe construction is test-only or intentionally replaced. |
| `oxforms-0a0.1` | Extend TextBox editing from the W005 committed-character subset. | `oxforms-0a0.9` | Caret, selection, deletion/backspace, and chosen mode semantics are specified and evidenced for the selected subset. |
| `oxforms-0a0.3` | Implement lifecycle, modal/nested pump, and close semantics for a named subset. | `oxforms-0a0.9` | Behavior flows through normalized events, reducer effects, and OxVba/PAL completions with replay/oracle evidence or precise blockers. |
| `oxforms-0a0.5` | Plan and implement additional intrinsic-control lanes beyond W005 probes. | `oxforms-0a0.9` | Selected control subset is fact-backed; W005 probe scaffolds are promoted, replaced, deleted, or quarantined intentionally. |
| `oxforms-0a0.6` | Design IME, clipboard, paste, and drag/drop input surfaces. | `oxforms-0a0.9` | Public facts and assumptions are separated; normalized event/effect/trace extensions are specified or blocked without leaking platform objects into core state. |
| `oxforms-0a0.7` | Design runtime accessibility semantics beyond W005 diagnostics. | `oxforms-0a0.9` | Requirements and non-goals are explicit; W005 UIA metadata is not treated as FM20 runtime behavior truth. |

## Closure Conditions

W006 closes only when:

1. the planning/review gate has closed and all executable W006 beads are either
   completed, precisely blocked, or moved into later worksets with clear bead
   state;
2. selected W006 runtime/control lanes have implementation or blocker evidence
   matching their scoped acceptance criteria;
3. W005 probe/reference scaffolds have been promoted, replaced, deleted, or
   quarantined as non-pattern test infrastructure;
4. any broadened parity claim is backed by public facts, reproducible
   black-box observations, trace/replay artifacts, tests, or explicit blockers;
5. W006 docs/register/beads agree about remaining scope and next work;
6. no W006 implementation bead remains open but accepted as "done" by prose.

Do not close W006 from the planning/review gate. Do not close W006 from a single
implementation lane unless the whole workset closure condition is actually met.

## Verification Shape

| Surface | Check |
|---|---|
| Docs/workset/register | read-through, path/link scan, `git diff --check` |
| Bead graph | `br dep cycles`, `br ready --json`, `br list --json` |
| Runtime/control lanes | targeted Rust/OxVba/fixture checks named by the touched bead |
| Evidence/oracles | Office/MSForms capture, replay/golden validation, checksum validation, or exact blocker |
| Trace/replay/comparison | schema validator, replay runner, comparison validator where touched |
| Clean-room posture | review public facts vs assumptions and check that no private implementation details or temporary W005 shortcuts became architecture |

