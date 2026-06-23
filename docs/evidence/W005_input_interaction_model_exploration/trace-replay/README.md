# W005 Trace Replay Evidence

Status: schema/sample evidence plus headless replay golden for W005.

This directory holds W005 trace/replay artifacts and samples. The curated schema
contract is [`../../../specs/TRACE_REPLAY_SCHEMA.md`](../../../specs/TRACE_REPLAY_SCHEMA.md).

## Current Artifacts

- [`synthetic-click-trace.v1.json`](synthetic-click-trace.v1.json) is a small
  synthetic trace that validates the v1 schema and exercises the required row
  families: normalized input, coordinate tags, reducer transition, effect
  request/completion, VBA dispatch, lifecycle/pump, invalidation, display-list
  reference, render reference, and reentrant nesting.
- [`reducer-skeleton-transition-log.v1.json`](reducer-skeleton-transition-log.v1.json)
  is a synthetic `oxforms-xvx.6` transition log showing the first
  `oxforms-core` reducer/model skeleton's ordered
  focus/capture/effect/invalidation output for a CommandButton-shaped mouse
  down. It consumes the `oxforms-pal` normalized input contract, but the PAL
  does not own or re-export reducer behavior. This is trace-schema integration
  evidence only; it is not a replay-runner golden trace.
- [`w005-headless-probe-replay.golden.v1.json`](w005-headless-probe-replay.golden.v1.json)
  is the `oxforms-xvx.12` deterministic OxForms golden trace. It replays a
  repo-authored script through the W005 headless probe path: show modeless,
  click the TextBox probe, type committed text `A`, and click the default
  `CommandButton` probe. The trace records normalized input events, routing
  decisions, reducer transition summaries, effect request/completion rows, VBA
  dispatch metadata reconstructed from `FireVbaEvent` effects, invalidation,
  probe display-list references, PAL smoke render hashes, and clean-room/path
  policy metadata. It does not require Excel/MSForms, OxVba execution, or a live
  desktop.
- [`w005-headless-probe-display-list.golden.v1.json`](w005-headless-probe-display-list.golden.v1.json)
  is the final core-owned probe display-list snapshot emitted by the same
  runner. It records fill, border, text, focus, and caret placeholder commands
  for the implemented W005 probe subset. Text rendering remains a display-list
  reference only; the PAL smoke render hash covers the current `FillRect`
  projection.
- [`checksums.sha256`](checksums.sha256) records SHA-256 hashes for committed
  trace-replay evidence files in this directory.

`oxforms-xvx.8` extends the reducer test surface, not this historical JSON
sample. Keyboard assertions in `crates/oxforms-core` now cover serialized
`KeyDown`/`KeyUp` effect diagnostics, printable `CharacterInput` TextBox
mutation, `KeyPress`/`Change` effects, Enter default routing, Escape cancel
routing, and `Alt+Character` caption accelerators. The full replay-runner
golden trace remains scoped to `oxforms-xvx.12`.

`oxforms-xvx.9` also extends the reducer test surface rather than this
historical JSON sample. Probe assertions in `crates/oxforms-core` now cover
Label mouse click routing, TextBox focus and committed character input,
CommandButton activation, render invalidation, a serializable core-owned probe
display reference with text/focus/caret placeholders, and a PAL `FillRect`
smoke projection. The full replay-runner golden trace remains scoped to
`oxforms-xvx.12`.

The synthetic samples are not Office/MSForms oracle evidence and are not
OxForms runtime traces. The headless replay golden is OxForms regression
evidence for the implemented W005 subset only; it is not an MSForms parity
claim and does not define global comparison tolerances.

## Validation

Run from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\trace-replay\Test-TraceReplaySchema.ps1
```

The validator checks the committed schema and sample for required sections,
logical ordering, coordinate-space tags, effect and VBA-dispatch causality,
display/render references, and absence of machine-local absolute paths in the
canonical sample.

Validate the `oxforms-xvx.12` golden trace:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\trace-replay\Test-TraceReplaySchema.ps1 -TracePath docs\evidence\W005_input_interaction_model_exploration\trace-replay\w005-headless-probe-replay.golden.v1.json
```

Check that the runner still emits the committed golden artifacts:

```powershell
cargo run -p oxforms-core --example w005_trace_replay -- --check
```

The focused Rust regression check is:

```powershell
cargo test -p oxforms-core w005_trace_replay_golden_matches_committed_artifacts
```

Regenerate into a review directory when an intentional behavior change updates
the golden:

```powershell
cargo run -p oxforms-core --example w005_trace_replay -- --write-dir docs\evidence\W005_input_interaction_model_exploration\trace-replay
git diff -- docs\evidence\W005_input_interaction_model_exploration\trace-replay
```

Validate the committed checksum file from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\evidence\Test-ChecksumManifest.ps1 -Directory docs\evidence\W005_input_interaction_model_exploration\trace-replay -GitTrackedOnly
```

Checksum entries are relative to this directory and use forward slashes for
nested paths.
