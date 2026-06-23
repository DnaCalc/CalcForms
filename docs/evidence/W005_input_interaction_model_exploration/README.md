# W005 Input Interaction Model Evidence

Status: active evidence directory for W005.
Owning workset: `W005_input_interaction_model_exploration`.

This directory holds raw or generated evidence for W005 input/event facts,
coordinate calibration, lifecycle/pump observations, oracle captures, and
trace/replay artifacts.

## Interaction Oracle Fixture

The repo-owned Excel/MSForms fixture input for `oxforms-xvx.2` lives at
[`../../../fixtures/office-oracle/excel-msforms/userforms/interaction-events/`](../../../fixtures/office-oracle/excel-msforms/userforms/interaction-events/).
It defines one `UserForm` with a `Label`, `TextBox`, default
`CommandButton`, and cancel `CommandButton`, plus code-behind that logs
representative events to worksheet `W005EventLog`.

Current status: the authoritative modeless live Excel/MSForms capture is
[`captures/interaction-events-20260623T004914Z/`](captures/interaction-events-20260623T004914Z/).
It preserves the generated workbook, `W005EventLog` CSV/JSON export,
screenshot/window metadata, coordinate calibration, automated input actions,
command logs, manifest, and SHA-256 hashes. The capture used public Windows
input automation, recorded no manual inputs, and does not compare OxForms
output. `modeless-input-actions.json` records the corrected calibrated
`OracleProbeLabel` center at screenshot pixel `x=104`, `y=95`; the observed
event rows include `OracleProbeLabel` `MouseDown`, `MouseUp`, and `Click`.
The older
[`captures/interaction-events-20260623T001238Z/`](captures/interaction-events-20260623T001238Z/)
run is superseded diagnostic evidence only because its actual injected
label-intended mouse coordinates came from the pre-repair calibration.
Modal-show capture remains tracked by follow-up bead `oxforms-xvx.20`.

## Coordinate Calibration

[`coordinate-calibration.md`](coordinate-calibration.md) records the W003/W004
screenshot geometry facts reused by W005 and defines the smallest follow-on
calibration procedure for MSForms mouse event arguments. The curated coordinate
contract is [`../../specs/COORDINATE_MODEL.md`](../../specs/COORDINATE_MODEL.md).

Current status: screenshot geometry is grounded by W003/W004 manifests and W004
pixel facts. The authoritative modeless W005 capture records a scoped
probe-label calibration (`x=40`, `y=63`, `width=128`, `height=64` in
`screenshot_pixels`, with form origin `x=8`, `y=31`) and its actual automated
input coordinates are derived from that repaired calibration. Modal-show
coordinate capture remains tracked by `oxforms-xvx.20`.

## Lifecycle And Pump Model

[`lifecycle-pump-model.md`](lifecycle-pump-model.md) records the W005
lifecycle/pump evidence status and the required downstream observations for
modal/modeless show, activation, close/query/hide/unload, terminate, and
reentrancy. The curated lifecycle contract is
[`../../specs/LIFECYCLE_PUMP_MODEL.md`](../../specs/LIFECYCLE_PUMP_MODEL.md).

Current status: the architecture model is defined, W002 is explicitly
smoke-only and not lifecycle evidence, and the modeless W005 capture records
live `Initialize`, `Activate`, `QueryClose`, and `Terminate` lifecycle rows
alongside input events. Modal-show pump evidence remains tracked by
`oxforms-xvx.20`.

## Trace Replay

[`trace-replay/`](trace-replay/) holds the W005 trace/replay schema samples and
the `oxforms-xvx.12` headless replay golden. The curated artifact contract is
[`../../specs/TRACE_REPLAY_SCHEMA.md`](../../specs/TRACE_REPLAY_SCHEMA.md), the
machine-readable schema is
[`../../schemas/trace-replay-artifact.v1.schema.json`](../../schemas/trace-replay-artifact.v1.schema.json),
and the validator is
[`../../../tools/trace-replay/Test-TraceReplaySchema.ps1`](../../../tools/trace-replay/Test-TraceReplaySchema.ps1).

Current status: the `oxforms-xvx.12` runner in
`crates/oxforms-core/src/trace_replay.rs` and
`crates/oxforms-core/examples/w005_trace_replay.rs` deterministically replays a
show/click/type/click script through the host-neutral W005 probe path without
Excel/MSForms, OxVba execution, or live desktop input. The golden trace
[`trace-replay/w005-headless-probe-replay.golden.v1.json`](trace-replay/w005-headless-probe-replay.golden.v1.json)
records normalized input events, routing decisions, reducer transition
summaries, requested and completed effects, VBA dispatch metadata reconstructed
from `FireVbaEvent` effects, invalidation, display-list references, PAL smoke
render hashes, and clean-room/path-policy metadata. The final display-list
snapshot is
[`trace-replay/w005-headless-probe-display-list.golden.v1.json`](trace-replay/w005-headless-probe-display-list.golden.v1.json),
and [`trace-replay/checksums.sha256`](trace-replay/checksums.sha256) records
SHA-256 hashes for the committed trace-replay evidence files.

The earlier synthetic schema-only trace validates and records the v1 artifact
row families. The `oxforms-xvx.6` reducer sample cites the host-neutral
`crates/oxforms-core/src/lib.rs` reducer/model skeleton while retaining
`crates/oxforms-pal/src/input.rs` as the PAL input contract. These synthetic
samples remain schema integration evidence, not live MSForms oracle evidence.

The `oxforms-xvx.8` reducer tests add keyboard trace/effect coverage in
`crates/oxforms-core`: `KeyDown`/`KeyUp` dispatch effects with normalized
key/modifier/raw diagnostics, committed printable `CharacterInput` routed to a
focused TextBox probe with `KeyPress`/`Change`/repaint effects, `Enter`
default-button routing, `Escape` cancel-button routing, and `Alt+Character`
caption accelerators such as `&OK`. The known deferred keyboard evidence
surfaces are IME/composition, dead keys, selection/caret granularity,
clipboard shortcuts, platform key identity parity, `ReturnInteger` helper
mutation, accelerator ambiguity/display behavior, and final event-order parity
against live MSForms captures.

The `oxforms-xvx.9` reducer tests add the first W005 probe-control render
reference in `crates/oxforms-core`: Label mouse routing without focus transfer,
TextBox focus plus committed character mutation, CommandButton mouse
activation, invalidation, serialized probe display-list commands for fill,
border, text, focus, and caret placeholders, and a PAL `FillRect` smoke
projection that uses the existing PAL display-list contract. These tests are
code-level trace/replay preparation only; they are not an Office/MSForms visual
parity claim and do not replace the full replay-runner golden evidence scoped
to `oxforms-xvx.12`.

## Event Dispatch Smoke

[`event-dispatch-smoke.v1.json`](event-dispatch-smoke.v1.json) records the
`oxforms-xvx.10` implemented subset. The smoke consumes reducer
`FireVbaEvent` effects for `MouseDown`, `MouseUp`, `Click`, `KeyDown`,
`KeyPress`, `Change`, and `KeyUp`, translates them through
`crates/oxforms-oxvba-adapter`, and verifies that VBA handler code observes the
event order and serialized argument metadata through OxVba
`RaiseEvent`/`WithEvents`.

The adapter intentionally exposes only the generic W005 carrier conversion used
by this smoke. Mouse rows preserve the FM20-style `Button`/`Shift`/`X`/`Y`
metadata that `oxforms-core` already emits. Keyboard `KeyDown`/`KeyUp` rows
preserve normalized `key`/`modifiers`/repeat/raw diagnostics and do not
fabricate a native FM20 `Shift` argument until native FM20-named event dispatch
is implemented.

The smoke uses one generic `Dispatched` carrier event as test infrastructure.
Direct FM20-named event raises are not claimed as implemented; the OxVba gap is
tracked in
[`../../handovers/HANDOVER_OxVba_w005_fm20_event_raise.md`](../../handovers/HANDOVER_OxVba_w005_fm20_event_raise.md).

## Windows Visible Input Smoke

[`captures/visible-input-smoke-20260623T035500Z/`](captures/visible-input-smoke-20260623T035500Z/)
records the `oxforms-xvx.11` Windows visible input pump smoke. The smoke opens
a small native `minifb` surface from
`crates/oxforms-core/examples/w005_visible_input_smoke.rs`, drives public
Windows input through `tools/w005-visible-input/Invoke-W005VisibleInputSmoke.ps1`,
and writes `visible-input-trace.json`, `visible-input-actions.json`, a window
screenshot, a rendered frame artifact, command logs, manifest, and checksums.

Observed coverage in the committed capture:

- 18 normalized `UiEvent` rows entered the W005 path.
- 43 reducer effects were emitted.
- public `user32` mouse input reached Label, TextBox, and CommandButton probe
  hit/focus/click routing.
- `System.Windows.Forms.SendKeys` character input reached the TextBox probe and
  left final text `ab`.
- public `PostMessageW(WM_CLOSE)` closed the smoke window after an attempted
  Alt+F4 and produced a normalized `CloseRequest` with `QueryClose` effect.
- coordinate evidence records driver-side `screen_pixels` and `client_pixels`
  plus smoke-side normalized `client_pixels` and `form_logical` payloads.

This capture is W005 evidence/test infrastructure only. It does not claim final
`UserForm.Show`, MSForms coordinate/DPI, lifecycle, rendering, or host parity,
and it does not replace headless reducer tests or the deterministic
`oxforms-xvx.12` trace/replay runner.

## FM20 Type-library Event Capture

`fm20_typelib_w005_events.json` is a generated subset of public FM20 type
library metadata captured for bead `oxforms-xvx.17`.

Source:

- Path: `C:\Program Files\Microsoft Office\root\vfs\System\FM20.DLL`
- Library: `MSForms`, "Microsoft Forms 2.0 Object Library"
- Library GUID: `{0D452EE1-E08F-101A-852E-02608C4D0BB4}`
- Version: `2.0`
- SHA-256:
  `E5085D8229D72180C7F2D8762E1A49FFF18A04F0143D7A973FF1FBC6200CB81E`

PowerShell provenance probe, runnable from this repo root:

```powershell
@'
import pythoncom

tlb = pythoncom.LoadTypeLib(
    r'C:\Program Files\Microsoft Office\root\vfs\System\FM20.DLL'
)
print(tlb.GetDocumentation(-1))
print(tlb.GetLibAttr())
'@ | python -
```

The committed JSON was generated by walking FM20 coclasses, selecting source
interfaces, and retaining W005-relevant event members and arguments. It is raw
evidence, not the curated contract. The curated W005 contract is
[`../../specs/FM20_EVENT_FACTS.md`](../../specs/FM20_EVENT_FACTS.md).

PowerShell coverage check for the required W005 event names, using the committed
JSON `rows` array:

```powershell
@'
import json
from pathlib import Path

required = {
    'Click',
    'DblClick',
    'Change',
    'Enter',
    'Exit',
    'KeyDown',
    'KeyUp',
    'KeyPress',
    'MouseDown',
    'MouseUp',
    'MouseMove',
    'BeforeUpdate',
    'AfterUpdate',
    'Error',
    'DropButtonClick',
    'BeforeDragOver',
    'BeforeDropOrPaste',
}

path = Path(
    'docs/evidence/W005_input_interaction_model_exploration/'
    'fm20_typelib_w005_events.json'
)
data = json.loads(path.read_text(encoding='utf-8'))
found = {row['event_name'] for row in data['rows']}
missing = sorted(required - found)
print(f'rows={len(data["rows"])}')
print(f'required_found={sorted(required & found)}')
print(f'required_missing={missing}')
if missing:
    raise SystemExit(1)
'@ | python -
```
