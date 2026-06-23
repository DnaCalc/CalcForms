# OxForms Trace Replay Schema

Status: W005 trace/replay artifact contract with first headless OxForms golden.
Owning bead: `oxforms-xvx.5`.
Owning workset:
[`W005_input_interaction_model_exploration`](../worksets/W005_input_interaction_model_exploration.md).
Machine-readable schema:
[`trace-replay-artifact.v1.schema.json`](../schemas/trace-replay-artifact.v1.schema.json).
Sample artifact:
[`synthetic-click-trace.v1.json`](../evidence/W005_input_interaction_model_exploration/trace-replay/synthetic-click-trace.v1.json).
Headless replay golden:
[`w005-headless-probe-replay.golden.v1.json`](../evidence/W005_input_interaction_model_exploration/trace-replay/w005-headless-probe-replay.golden.v1.json).
Validator:
[`Test-TraceReplaySchema.ps1`](../../tools/trace-replay/Test-TraceReplaySchema.ps1).

This document defines the W005 JSON artifact shape used to record normalized
input, reducer transitions, effects, VBA dispatches, lifecycle/pump activity,
render invalidation, display-list references, render artifact references,
environment metadata, logical ordering, and reentrant nesting. It is an
artifact contract and validation surface. The first `oxforms-xvx.12` replay
runner uses this contract for an OxForms headless golden; this document still
does not define final pass/fail tolerances for MSForms parity.

## 1. Anchors

- [`INPUT_INTERACTION_MODEL.md`](INPUT_INTERACTION_MODEL.md), especially
  sections 4, 8, 10, 12, 13, and 14.
- [`FM20_EVENT_FACTS.md`](FM20_EVENT_FACTS.md), for event names, DISPIDs,
  argument order, scalar values, mutable helper objects, and open ordering
  questions.
- [`COORDINATE_MODEL.md`](COORDINATE_MODEL.md), for coordinate-space names,
  units, origin rules, DPI/scale, rounding, half-open bounds, and raw diagnostic
  preservation.
- [`LIFECYCLE_PUMP_MODEL.md`](LIFECYCLE_PUMP_MODEL.md), for lifecycle state,
  modal/modeless pump terms, close/query/hide/unload separation, and reentrancy
  rules.
- [`crates/oxforms-pal/src/input.rs`](../../crates/oxforms-pal/src/input.rs),
  for the W005 PAL `UiEvent` schema version, source names, target identifiers,
  event family names, coordinate payload families, keyboard/mouse payloads,
  host-extension event rows, and lifecycle event families.
- [`crates/oxforms-core/src/lib.rs`](../../crates/oxforms-core/src/lib.rs), for
  the W005 reducer/effects reference skeleton that consumes PAL input without
  making the PAL own control behavior.
- [`FORMS_LIBRARY_SPEC_AND_PLAN.md`](../FORMS_LIBRARY_SPEC_AND_PLAN.md),
  decision D11 and section 4.5.
- W003/W004 evidence manifests for artifact style and clean-room notes:
  [`W003 oracle-capture-manifest.json`](../evidence/W003_excel_forms_oracle_capture/captures/rectangle-label-20260622T170958Z/oracle-capture-manifest.json)
  and
  [`W004 oracle-capture-manifest.json`](../evidence/W004_text_label_oracle_pixels/captures/rectangle-label-text-20260622T191013Z/oracle-capture-manifest.json).

## 2. Scope And Non-goals

The W005 trace artifact records facts needed for deterministic replay,
debugging, and later comparison:

- input script steps and normalized `UiEvent` rows;
- routing decisions for hit-test, focus, capture, keyboard, lifecycle, and host
  scope;
- reducer transition summaries, not mandatory full-state dumps;
- ordered effect requests and completions;
- VBA event dispatch attempts, arguments, return-helper mutations, and errors;
- lifecycle and pump rows, including nested modal/reentrant activity;
- invalidation rows with named coordinate spaces and dirty reasons;
- display-list references and render artifact references;
- environment metadata and clean-room provenance.

The schema bead deliberately did not:

- decide final parity tolerances, pixel thresholds, SSIM thresholds, event-order
  pass/fail rules, or coordinate epsilon values;
- claim the synthetic sample is MSForms oracle evidence;
- require live Excel, a live PAL window, or OxVba execution;
- allow machine-local absolute paths in canonical sample artifacts.

The downstream `oxforms-xvx.12` runner is implemented as headless OxForms
regression evidence, not as an MSForms comparison oracle.

## 3. File Identity

Canonical W005 trace JSON uses:

```json
{
  "schema": "oxforms.trace_replay.v1",
  "schema_version": 1
}
```

The machine-readable schema lives at
`docs/schemas/trace-replay-artifact.v1.schema.json`. The validator currently
performs structural and semantic checks over committed samples without relying
on an external JSON Schema engine.

Every trace must include:

- `trace_id`: stable artifact id within the repo;
- `bead`: bead that produced or updated the artifact;
- `artifact_status`: for example `synthetic_schema_sample`,
  `oxforms_observation`, `msforms_oracle_observation`, or `comparison_input`;
- `scenario`: script identity and intent;
- `environment`: OS/host/PAL/DPI/path-policy metadata;
- `ordering`: sequence and nesting rules for the rows;
- `rows`: ordered trace rows;
- `artifacts`: display-list and render references;
- `clean_room`: source/prohibited-method notes.

## 4. Path Policy

Canonical artifact references must be repository-relative paths or in-trace
references. A trace may point to command logs that were captured from live
tools, but the canonical sample and normalized artifact identifiers must not
store machine-local absolute paths such as `C:\...`, UNC paths, or rooted POSIX
paths.

Use these path-like fields:

- `path`: repo-relative file path when the artifact is committed as a file;
- `uri_fragment`: JSON pointer or fragment when the artifact is embedded in the
  trace;
- `storage`: `repo_file`, `inline_trace_row`, or `external_uncommitted_note`.

Downstream live capture manifests may preserve the exact command strings needed
to reproduce a run, including absolute output paths where the capture tool
requires them. Those command logs are evidence context, not canonical replay
identifiers.

## 5. Ordering Model

Rows are ordered by a trace-wide integer `sequence` and may also carry a
`logical_tick`. `sequence` is the decisive total order inside one artifact.
`logical_tick` is the replay clock used by synthetic or deterministic runners.
Wall-clock timestamps are environment diagnostics only and must not be required
for deterministic replay.

Every row has:

- `row_id`: stable unique id inside the trace;
- `sequence`: monotonically increasing integer;
- `logical_tick`: integer replay tick, non-decreasing in normal traces;
- `parent_row_id`: `null` for top-level rows, or a prior row id for reentrant
  input, nested dispatch, modal frame activity, or effect completion causality;
- `nesting_depth`: `0` at top level; greater than `0` for reentrant or nested
  rows;
- `phase`: broad phase such as `script`, `input`, `routing`, `reducer`,
  `effect`, `dispatch`, `pump`, `render`, or `evidence`;
- `kind`: one of the row kinds in section 6;
- `payload`: row-specific content.

Reentrant rows must use `parent_row_id` and `nesting_depth`. They must not rely
only on prose. The intended cases are VBA event dispatch reentrancy, nested modal
frames, host callbacks, and effect completions that arrive while another effect
is active.

## 6. Row Kinds

| Kind | Purpose | Required references |
|---|---|---|
| `input_script_step` | Desired logical action, independent of a live desktop. | `script_step_id`, action, source coordinate or target intent when relevant. |
| `ui_event` | Normalized input/service/lifecycle event entering the reducer path. | `ui_event_id`, `ui_event_schema_version`, source, target, PAL-aligned kind. |
| `routing_decision` | Hit-test, focus, capture, keyboard, host, or lifecycle routing. | `causal_ui_event_id`, route kind, selected target, considered candidates where useful. |
| `reducer_transition` | Pure state transition summary. | `transition_id`, `causal_ui_event_id`, before summary, after summary, effect ids, invalidation ids. |
| `effect_requested` | Ordered reducer effect request. | `effect_id`, effect kind, cause, target, completion policy. |
| `effect_completed` | Completion, cancellation, or error for an effect. | `effect_id`, status, result or error diagnostics. |
| `vba_dispatch` | Attempted VBA event dispatch and result. | `dispatch_id`, `effect_id`, event name, fact source, args, mutations, result. |
| `lifecycle_pump` | Lifecycle or modal/modeless pump observation. | lifecycle state, pump term, modal depth, active form/window where known. |
| `invalidation` | Dirty region/subtree produced by reducer/effects. | invalidation id, target, reason, coordinate-space-tagged regions. |
| `display_list` | Display-list batch or command reference. | display list id, producer, coordinate space, command count or checksum. |
| `render_artifact` | Rendered image/hash/screenshot/crop reference. | render id, source display-list id, target, hash or artifact reference. |
| `oracle_annotation` | MSForms observation or uncertainty note attached to rows. | source artifact, classification, linked row ids. |
| `comparison_annotation` | Later comparison classification. | classification, linked OxForms/MSForms rows. |
| `diagnostic` | Unsupported path, validation note, or tool diagnostic. | severity and message. |

The schema allows future row kinds only after this document is updated in the
same bead that introduces them.

## 7. Normalized UiEvent Rows

`ui_event` row payloads use a PAL-aligned normalized input shape:

- `ui_event_schema_version` must match `UI_EVENT_SCHEMA_VERSION` in
  `crates/oxforms-pal/src/input.rs` for the emitting code path.
- `source` uses the PAL source names: `pal`, `host_extension`, `service`,
  `replay`, or `oracle`.
- `target` carries optional `form_id`, `window_id`, and `control_id` hints. The
  reducer/router still owns final routing unless the event is explicitly a
  host-extension event.
- `kind` uses the `UiEventKind` serde names from the PAL contract, such as
  `mouse_down`, `key_down`, `character_input`, `show_requested`,
  `query_close_completed`, or `pump_yield_requested`.
- `payload` carries the family-specific value fields.
- `coordinates` is a trace-level array of tagged coordinate values when the
  event carries a coordinate payload.

The trace schema may add evidence fields around the PAL value shape, but it
must not rename PAL event families locally. If a later PAL version changes a
name, the trace schema version must change or an explicit versioning note must
be recorded.

## 8. Coordinate Payloads

Every coordinate value in a trace must name one of the coordinate spaces from
`COORDINATE_MODEL.md`:

- `screen_pixels`
- `window_rect`
- `screenshot_pixels`
- `client_pixels`
- `form_logical`
- `control_local`
- `display_list_logical`
- `msforms_event_args`
- `raw_diagnostic`

Coordinate objects use:

```json
{
  "space": "control_local",
  "unit": "points",
  "origin": "target_control_top_left",
  "point": { "x": 12.0, "y": 8.0 },
  "dpi": { "dpi_x": 96.0, "dpi_y": 96.0 },
  "source": "router.control_local",
  "certainty": "derived"
}
```

Rectangle objects use the same `space`, `unit`, `origin`, `dpi`, `source`, and
`certainty` fields plus `rect`. Rectangles use the half-open bounds convention
from `COORDINATE_MODEL.md`.

Coordinates may be outside a control during capture. Do not clamp negative or
out-of-bounds `control_local` or `msforms_event_args` values before logging.

## 9. Reducer And Effects

Reducer transition rows summarize:

- the causal `ui_event_id`;
- relevant state before and after, such as focus owner, capture owner,
  lifecycle state, pressed state, text value summary, validation state, and
  modal depth;
- emitted effect ids in order;
- invalidation ids in order;
- unsupported or unknown behavior as diagnostics, not hidden behavior.

Effect rows use effect names from `INPUT_INTERACTION_MODEL.md` and
`LIFECYCLE_PUMP_MODEL.md`, including:

- `fire_vba_event`
- `request_repaint`
- `capture_mouse`
- `release_mouse`
- `transfer_focus`
- `start_timer`
- `stop_timer`
- `clipboard_get`
- `clipboard_set`
- `set_cursor`
- `show_form_modal`
- `show_form_modeless`
- `hide_form`
- `close_form`
- `unload_form`
- `host_capability_request`
- lifecycle effects such as `materialize_form`, `create_window_surface`,
  `enter_modal_frame`, `schedule_modeless`, and `exit_modal_frame`.

The trace records effect requests separately from effect completions because VBA
dispatch, modal pumps, host callbacks, and platform services can be reentrant.

## 10. VBA Dispatch Rows

`vba_dispatch` rows must cite `FM20_EVENT_FACTS.md` when they name FM20 event
arguments. Each dispatch row records:

- `dispatch_id`;
- `effect_id` that requested dispatch;
- `event_name`;
- `target`;
- `fact_source`, including file path and optional event row label;
- `arguments`, in dispatch order;
- `mutable_helpers`, recording before/after values for `MSForms.Return*`
  helper objects;
- scalar ByRef values where public docs and observations establish them, such
  as `QueryClose.Cancel`;
- dispatch result, including skipped/missing-handler/error diagnostics.

Known uncertain event-order behavior remains evidence-gated. Trace rows preserve
what happened; comparison artifacts later classify differences without this
schema defining final parity pass/fail.

## 11. Lifecycle And Pump Rows

Lifecycle/pump rows use the state and pump terms from
`LIFECYCLE_PUMP_MODEL.md`. They record:

- lifecycle state before and after where known;
- pump term, for example `host_modeless_pump`, `modal_frame`,
  `vba_dispatch_reentrancy`, `host_callback_reentrancy`, or
  `close_unload_cancellation`;
- modal depth;
- active form/window and focus owner where known;
- close/query/hide/unload/terminate reason and cancellation status where
  applicable;
- causal row ids for nested/reentrant activity.

`Show`, close, hide, unload, and terminate must remain separate trace concepts.
Do not collapse them into one row merely because a smoke path happens to do so.

## 12. Invalidation, Display Lists, And Render Artifacts

Invalidation rows must name dirty regions or subtrees and their coordinate
space. Display-list rows must name the display-list coordinate space, producer,
target, command count, and either an inline artifact reference or a committed
artifact path/checksum.

Render artifact rows must name:

- `render_id`;
- source `display_list_id`;
- render target;
- output kind such as `hash`, `screenshot`, `crop`, or `headless_framebuffer`;
- hash algorithm and hash where available;
- artifact reference, or `null` when the sample only establishes schema shape.

The schema supports render references. It does not require that this bead
produce real rendered pixels.

## 13. Environment Metadata

Every trace records:

- source kind: `synthetic`, `oxforms_headless`, `oxforms_visible`,
  `msforms_oracle`, or `comparison`;
- OS/platform metadata or `synthetic` when no platform was used;
- PAL input schema version and path to the PAL input contract;
- host metadata, with host-extension scope when relevant;
- DPI/scale metadata for coordinate conversion;
- command/tool provenance for live captures where applicable;
- clean-room source/prohibited-method notes.

Use `null` or explicit `unknown` values for fields not available in synthetic
or blocked artifacts. Do not invent platform facts.

## 14. Validator And Sample

`tools/trace-replay/Test-TraceReplaySchema.ps1` validates a committed trace
artifact and the machine-readable schema. Its default target is the synthetic
sample; pass `-TracePath` for the `oxforms-xvx.12` golden. It checks:

- schema id/version;
- required top-level sections;
- required row kinds;
- unique, increasing row sequences;
- valid parent/nesting relationships;
- PAL-aligned `ui_event` kinds and source names;
- required coordinate-space tags;
- reducer/effect/VBA dispatch causal ordering;
- display-list and render artifact references;
- existing repo-relative artifact paths when a display/render artifact path is
  present;
- explicit clean-room source/prohibited-method notes;
- absence of machine-local absolute paths in the canonical sample.

The original sample is synthetic and intentionally small. Its purpose is to lock
the artifact vocabulary. The `oxforms-xvx.12` golden is generated by
`crates/oxforms-core/examples/w005_trace_replay.rs` and checks the implemented
probe reducer path against committed output.

## 15. Downstream Contracts

- `oxforms-xvx.6` reducer/effects work lives in the host-neutral
  `oxforms-core` model/reference crate and must emit or test transition/effect
  rows that conform to this schema.
- `oxforms-xvx.10` VBA dispatch smoke must populate `vba_dispatch` rows using
  `FM20_EVENT_FACTS.md`.
- `oxforms-xvx.11` visible smoke must populate PAL coordinate diagnostics and
  lifecycle/pump rows using `COORDINATE_MODEL.md` and
  `LIFECYCLE_PUMP_MODEL.md`. Its current evidence is
  [`../evidence/W005_input_interaction_model_exploration/captures/visible-input-smoke-20260623T035500Z/`](../evidence/W005_input_interaction_model_exploration/captures/visible-input-smoke-20260623T035500Z/):
  an `oxforms_visible`-style smoke trace, action log, screenshot, rendered
  frame artifact, command logs, manifest, and checksums. This artifact is not
  the full replay-runner golden trace scoped to `oxforms-xvx.12`.
- `oxforms-xvx.12` replay runner/golden evidence cites this schema. The runner
  is implemented in `crates/oxforms-core/src/trace_replay.rs`, its command is
  `cargo run -p oxforms-core --example w005_trace_replay -- --check`, and its
  committed golden trace is
  [`w005-headless-probe-replay.golden.v1.json`](../evidence/W005_input_interaction_model_exploration/trace-replay/w005-headless-probe-replay.golden.v1.json).
  Runner-specific checks do not change the v1 artifact identity because the row
  contract is unchanged.
- `oxforms-xvx.13` comparison artifacts should link rows by `row_id`,
  `ui_event_id`, `effect_id`, `dispatch_id`, `display_list_id`, and
  `render_id`, then classify differences as observations rather than final
  parity verdicts.

## 16. Remaining Unknowns

- Whether later W005 traces need full state snapshots or whether transition
  summaries plus selected state facets remain sufficient.
- Whether the `oxforms-xvx.12` runner-side script format should become a
  separate reusable input file once more scenarios exist.
- Exact display-list serialization once richer drawing commands land beyond the
  W002 rectangle smoke.
- How host-extension payloads for Excel `RefEdit` name workbook/sheet/range
  identities without requiring live Excel for replay.
- Which additional lifecycle ordering rows live MSForms evidence will require
  after `oxforms-xvx.2` and `oxforms-xvx.3`.
