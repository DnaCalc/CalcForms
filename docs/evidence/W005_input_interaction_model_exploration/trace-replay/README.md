# W005 Trace Replay Evidence

Status: schema/sample evidence for `oxforms-xvx.5`.

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
  `oxforms-pal` reducer skeleton's ordered focus/capture/effect/invalidation
  output for a CommandButton-shaped mouse down. It is trace-schema integration
  evidence only; it is not a replay-runner golden trace.

The sample is not Office/MSForms oracle evidence and is not an OxForms runtime
trace. It exists to keep downstream W005 traces from inventing local artifact
shapes before the replay runner exists.

## Validation

Run from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\trace-replay\Test-TraceReplaySchema.ps1
```

The validator checks the committed schema and sample for required sections,
logical ordering, coordinate-space tags, effect and VBA-dispatch causality,
display/render references, and absence of machine-local absolute paths in the
canonical sample.
